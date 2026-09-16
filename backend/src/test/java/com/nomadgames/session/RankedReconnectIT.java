package com.nomadgames.session;

import static org.springframework.http.MediaType.APPLICATION_JSON;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.WebSocket;
import java.time.Duration;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.CompletionStage;
import java.util.concurrent.CopyOnWriteArrayList;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;

import org.hamcrest.Matchers;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.server.LocalServerPort;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.postgresql.PostgreSQLContainer;

import com.jayway.jsonpath.JsonPath;
import com.nomadgames.NomadGamesApplication;
import com.nomadgames.matchmaking.RankedQueueService;
import com.nomadgames.matchmaking.internal.JoinRateLimiter;
import com.nomadgames.session.internal.MatchSessionRegistry;
import com.nomadgames.session.internal.MatchSessionRegistry.LiveMatch;
import com.nomadgames.session.internal.ReconnectPolicy;

/**
 * SESS-03 Ranked reconnect: grace 18/12 + pause budgets 45/20 (D-101…D-103).
 */
@SpringBootTest(
        classes = NomadGamesApplication.class,
        webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT,
        properties = {
            "nomad.jwt.secret=test-jwt-secret-that-is-32-bytes!!",
            "nomad.guest.mint-limit-per-minute=100"
        })
@AutoConfigureMockMvc
@Testcontainers
class RankedReconnectIT {

    @Container
    @ServiceConnection
    static PostgreSQLContainer postgres = new PostgreSQLContainer("postgres:18");

    @Autowired
    MockMvc mockMvc;

    @Autowired
    JoinRateLimiter joinRateLimiter;

    @Autowired
    RankedQueueService rankedQueue;

    @Autowired
    MatchSessionRegistry sessions;

    @LocalServerPort
    int port;

    @BeforeEach
    void resetSharedState() {
        joinRateLimiter.reset();
        rankedQueue.reset();
    }

    @Test
    void rankedAlchikiGraceIsEighteenSeconds() throws Exception {
        // D-101: Ranked Alchiki OpponentDropped secondsLeft ∈ [1,18]
        Seats seats = pairRanked("ALCHIKI");
        String hostTicket = wsTicket(seats.hostToken(), seats.matchId());
        String joinerTicket = wsTicket(seats.joinerToken(), seats.matchId());

        CollectingListener host = connect(seats.matchId(), hostTicket);
        CollectingListener joiner = connect(seats.matchId(), joinerTicket);
        joiner.socket.sendClose(1001, "drop");
        String dropped = host.awaitType("OpponentDropped");
        int secondsLeft = ((Number) JsonPath.read(dropped, "$.secondsLeft")).intValue();
        if (secondsLeft < 1 || secondsLeft > 18) {
            throw new AssertionError("OpponentDropped secondsLeft must be in [1,18], got " + secondsLeft);
        }

        mockMvc.perform(get("/v1/matches/" + seats.matchId())
                        .header("Authorization", "Bearer " + seats.joinerToken()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.mode").value("RANKED"))
                .andExpect(jsonPath("$.reconnectSecondsLeft").isNumber())
                .andExpect(jsonPath("$.reconnectSecondsLeft")
                        .value(Matchers.allOf(Matchers.greaterThanOrEqualTo(1), Matchers.lessThanOrEqualTo(18))));
        closeQuietly(host);
    }

    @Test
    void rankedStickPullGraceIsTwelveSeconds() throws Exception {
        // D-101: Ranked Stick Pull OpponentDropped secondsLeft ∈ [1,12]
        Seats seats = pairRanked("STICK_PULL");
        String hostTicket = wsTicket(seats.hostToken(), seats.matchId());
        String joinerTicket = wsTicket(seats.joinerToken(), seats.matchId());

        CollectingListener host = connect(seats.matchId(), hostTicket);
        CollectingListener joiner = connect(seats.matchId(), joinerTicket);
        joiner.socket.sendClose(1001, "drop");
        String dropped = host.awaitType("OpponentDropped");
        int secondsLeft = ((Number) JsonPath.read(dropped, "$.secondsLeft")).intValue();
        if (secondsLeft < 1 || secondsLeft > 12) {
            throw new AssertionError("OpponentDropped secondsLeft must be in [1,12], got " + secondsLeft);
        }

        mockMvc.perform(get("/v1/matches/" + seats.matchId())
                        .header("Authorization", "Bearer " + seats.joinerToken()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.mode").value("RANKED"))
                .andExpect(jsonPath("$.reconnectSecondsLeft").isNumber())
                .andExpect(jsonPath("$.reconnectSecondsLeft")
                        .value(Matchers.allOf(Matchers.greaterThanOrEqualTo(1), Matchers.lessThanOrEqualTo(12))));
        closeQuietly(host);
    }

    @Test
    void pauseBudgetExhaustedImmediateForfeit() throws Exception {
        // D-102 / D-103: after pause budget used, next drop → 0s rated forfeit (no bot-fill)
        Seats seats = pairRanked("ALCHIKI");
        String hostTicket = wsTicket(seats.hostToken(), seats.matchId());
        String joinerTicket = wsTicket(seats.joinerToken(), seats.matchId());

        CollectingListener host = connect(seats.matchId(), hostTicket);
        CollectingListener joiner = connect(seats.matchId(), joinerTicket);

        UUID matchId = UUID.fromString(seats.matchId());
        LiveMatch live = sessions.live(matchId);
        if (live == null) {
            throw new AssertionError("LiveMatch missing after ws connect");
        }
        long budgetMs = ReconnectPolicy.pauseBudgetSeconds("RANKED", "ALCHIKI") * 1000L;
        live.pauseUsedMs = budgetMs;
        live.pauseBudgetGone = true;

        joiner.socket.sendClose(1001, "drop").get(5, TimeUnit.SECONDS);

        // Poll server SoT — do not rely solely on WS frame ordering vs TX commit.
        String status = null;
        for (int i = 0; i < 40; i++) {
            MvcResult snap = mockMvc.perform(get("/v1/matches/" + seats.matchId())
                            .header("Authorization", "Bearer " + seats.hostToken()))
                    .andExpect(status().isOk())
                    .andReturn();
            status = JsonPath.read(snap.getResponse().getContentAsString(), "$.status");
            if (!"IN_PLAY".equals(status)) {
                break;
            }
            Thread.sleep(100);
        }
        if (!"HOST_WIN".equals(status)) {
            throw new AssertionError(
                    "budget-exhausted drop must settle HOST_WIN (no bot-fill); status="
                            + status
                            + " pauseUsedMs="
                            + live.pauseUsedMs
                            + " hostMsgs="
                            + host.messages);
        }
        mockMvc.perform(get("/v1/matches/" + seats.matchId())
                        .header("Authorization", "Bearer " + seats.hostToken()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("HOST_WIN"))
                .andExpect(jsonPath("$.status").value(Matchers.not("BOT_WIN")))
                .andExpect(jsonPath("$.mode").value("RANKED"))
                .andExpect(jsonPath("$.joinerId").exists());
        closeQuietly(host);
    }

    @Test
    void casualGracePolicyUnchanged() {
        // T-07-20: Casual / private stay 30s Alchiki and 8s Stick Pull
        if (ReconnectPolicy.graceSeconds("PRIVATE", "ALCHIKI") != 30) {
            throw new AssertionError("PRIVATE ALCHIKI grace must stay 30");
        }
        if (ReconnectPolicy.graceSeconds("CASUAL", "STICK_PULL") != 8) {
            throw new AssertionError("CASUAL STICK_PULL grace must stay 8");
        }
        if (ReconnectPolicy.graceSeconds("RANKED", "ALCHIKI") != 18) {
            throw new AssertionError("RANKED ALCHIKI grace must be 18");
        }
        if (ReconnectPolicy.graceSeconds("RANKED", "STICK_PULL") != 12) {
            throw new AssertionError("RANKED STICK_PULL grace must be 12");
        }
    }

    private Seats pairRanked(String game) throws Exception {
        String suffix = Long.toString(System.nanoTime() % 1_000_000, 36);
        String a = bindAndAccess("rca" + suffix);
        String b = bindAndAccess("rcb" + suffix);

        mockMvc.perform(post("/v1/matchmaking/ranked")
                        .header("Authorization", "Bearer " + a)
                        .contentType(APPLICATION_JSON)
                        .content("{\"game\":\"" + game + "\"}"))
                .andExpect(status().isOk());

        MvcResult second = mockMvc.perform(post("/v1/matchmaking/ranked")
                        .header("Authorization", "Bearer " + b)
                        .contentType(APPLICATION_JSON)
                        .content("{\"game\":\"" + game + "\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("MATCHED"))
                .andExpect(jsonPath("$.mode").value("RANKED"))
                .andExpect(jsonPath("$.matchId").exists())
                .andReturn();

        String matchId = JsonPath.read(second.getResponse().getContentAsString(), "$.matchId").toString();
        return new Seats(a, b, matchId);
    }

    private String bindAndAccess(String username) throws Exception {
        String guest = mintAccessToken();
        MvcResult bound = mockMvc.perform(post("/v1/identity/bind")
                        .header("Authorization", "Bearer " + guest)
                        .contentType(APPLICATION_JSON)
                        .content("{\"username\":\"" + username + "\",\"password\":\"password12\"}"))
                .andExpect(status().isOk())
                .andReturn();
        return JsonPath.read(bound.getResponse().getContentAsString(), "$.accessToken");
    }

    private String mintAccessToken() throws Exception {
        MvcResult minted = mockMvc.perform(post("/v1/identity/guest").contentType(APPLICATION_JSON).content("{}"))
                .andExpect(status().isCreated())
                .andReturn();
        return JsonPath.read(minted.getResponse().getContentAsString(), "$.accessToken");
    }

    private String wsTicket(String token, String matchId) throws Exception {
        MvcResult minted = mockMvc.perform(post("/v1/matches/" + matchId + "/ws-ticket")
                        .header("Authorization", "Bearer " + token)
                        .contentType(APPLICATION_JSON)
                        .content("{}"))
                .andExpect(status().isOk())
                .andReturn();
        return JsonPath.read(minted.getResponse().getContentAsString(), "$.ticket");
    }

    private CollectingListener connect(String matchId, String ticket) throws Exception {
        CollectingListener listener = new CollectingListener();
        HttpClient client = HttpClient.newHttpClient();
        listener.socket = client.newWebSocketBuilder()
                .connectTimeout(Duration.ofSeconds(5))
                .buildAsync(
                        URI.create("ws://127.0.0.1:" + port + "/v1/matches/" + matchId + "/ws?ticket=" + ticket),
                        listener)
                .get(5, TimeUnit.SECONDS);
        return listener;
    }

    private static void closeQuietly(CollectingListener... listeners) {
        for (CollectingListener listener : listeners) {
            if (listener == null || listener.socket == null) {
                continue;
            }
            try {
                listener.socket.sendClose(1000, "done").get(2, TimeUnit.SECONDS);
            } catch (Exception ignored) {
                // test teardown
            }
        }
    }

    private record Seats(String hostToken, String joinerToken, String matchId) {}

    private static final class CollectingListener implements WebSocket.Listener {
        final List<String> messages = new CopyOnWriteArrayList<>();
        private final List<CountDownLatch> waiters = new ArrayList<>();
        WebSocket socket;

        @Override
        public void onOpen(WebSocket webSocket) {
            webSocket.request(1);
        }

        @Override
        public CompletionStage<?> onText(WebSocket webSocket, CharSequence data, boolean last) {
            messages.add(data.toString());
            synchronized (waiters) {
                waiters.forEach(CountDownLatch::countDown);
            }
            webSocket.request(1);
            return null;
        }

        String awaitType(String type) throws InterruptedException {
            return awaitType(type, 5);
        }

        String awaitType(String type, int seconds) throws InterruptedException {
            long deadline = System.nanoTime() + TimeUnit.SECONDS.toNanos(seconds);
            while (System.nanoTime() < deadline) {
                for (String message : messages) {
                    if (message.contains("\"type\":\"" + type + "\"")) {
                        return message;
                    }
                }
                CountDownLatch latch = new CountDownLatch(1);
                synchronized (waiters) {
                    waiters.add(latch);
                }
                latch.await(200, TimeUnit.MILLISECONDS);
            }
            throw new AssertionError("Timed out waiting for " + type + "; saw " + messages);
        }
    }
}
