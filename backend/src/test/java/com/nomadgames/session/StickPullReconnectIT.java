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
import java.util.concurrent.CompletionStage;
import java.util.concurrent.CopyOnWriteArrayList;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;

import org.hamcrest.Matchers;
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

/**
 * SESS-04 Stick Pull 8s forfeit / no bot-fill (D-86, D-87, T-06-02).
 * Alchiki path stays 30s via ReconnectPolicy.graceSeconds(game) (D-86).
 */
@SpringBootTest(
        classes = NomadGamesApplication.class,
        webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT,
        properties = "nomad.jwt.secret=test-jwt-secret-that-is-32-bytes!!")
@AutoConfigureMockMvc
@Testcontainers
class StickPullReconnectIT {

    @Container
    @ServiceConnection
    static PostgreSQLContainer postgres = new PostgreSQLContainer("postgres:18");

    @Autowired
    MockMvc mockMvc;

    @LocalServerPort
    int port;

    @Test
    void stickPullGraceIsEightSeconds() throws Exception {
        // SESS-04 / D-86: OpponentDropped secondsLeft ∈ [1,8] for STICK_PULL
        Seats seats = bothReadyStickPull();
        String hostTicket = wsTicket(seats.hostToken(), seats.matchId());
        String joinerTicket = wsTicket(seats.joinerToken(), seats.matchId());

        CollectingListener host = connect(seats.matchId(), hostTicket);
        CollectingListener joiner = connect(seats.matchId(), joinerTicket);
        joiner.socket.sendClose(1001, "drop");
        String dropped = host.awaitType("OpponentDropped");
        int secondsLeft = ((Number) JsonPath.read(dropped, "$.secondsLeft")).intValue();
        if (secondsLeft < 1 || secondsLeft > 8) {
            throw new AssertionError("OpponentDropped secondsLeft must be in [1,8], got " + secondsLeft);
        }

        // Dropped seat projection (same pattern as ReconnectIT.getMatchExposesRemainingGrace)
        mockMvc.perform(get("/v1/matches/" + seats.matchId())
                        .header("Authorization", "Bearer " + seats.joinerToken()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.reconnectSecondsLeft").isNumber())
                .andExpect(jsonPath("$.reconnectSecondsLeft")
                        .value(Matchers.allOf(Matchers.greaterThanOrEqualTo(1), Matchers.lessThanOrEqualTo(8))));
        closeQuietly(host);
    }

    @Test
    void graceExpiryForfeitsNoBotFill() throws Exception {
        // D-86 / D-87: remaining human wins; no StickPullBot spawned into dropped seat
        Seats seats = bothReadyStickPull();
        String hostTicket = wsTicket(seats.hostToken(), seats.matchId());
        String joinerTicket = wsTicket(seats.joinerToken(), seats.matchId());

        CollectingListener host = connect(seats.matchId(), hostTicket);
        CollectingListener joiner = connect(seats.matchId(), joinerTicket);
        joiner.socket.sendClose(1001, "drop");
        host.awaitType("OpponentDropped");

        Thread.sleep(9_000);

        mockMvc.perform(get("/v1/matches/" + seats.matchId())
                        .header("Authorization", "Bearer " + seats.hostToken()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("HOST_WIN"))
                .andExpect(jsonPath("$.status").value(Matchers.not("BOT_WIN")))
                .andExpect(jsonPath("$.status").value(Matchers.not("IN_PLAY")))
                .andExpect(jsonPath("$.joinerId").exists())
                .andExpect(jsonPath("$.mode").value(Matchers.not("BOT")));
        closeQuietly(host);
    }

    @Test
    void privateThresholdSettleMapsHostJoinerWin() throws Exception {
        // CR-01: natural threshold settle must be HOST_WIN/JOINER_WIN (not PLAYER/BOT) + asymmetric grants
        Seats seats = bothReadyStickPull();
        String hostTicket = wsTicket(seats.hostToken(), seats.matchId());
        String joinerTicket = wsTicket(seats.joinerToken(), seats.matchId());

        CollectingListener host = connect(seats.matchId(), hostTicket);
        CollectingListener joiner = connect(seats.matchId(), joinerTicket);
        awaitCountdownGo(host);

        for (int i = 0; i < 150; i++) {
            host.socket.sendText(
                    "{\"type\":\"TapInput\",\"schemaVersion\":1,\"clientSeq\":" + (i + 1) + "}", true);
            Thread.sleep(110);
            if (host.messages.stream().anyMatch(m -> m.contains("MatchSettled"))) {
                break;
            }
        }
        host.awaitType("MatchSettled", 20);

        MvcResult hostSnap = mockMvc.perform(get("/v1/matches/" + seats.matchId())
                        .header("Authorization", "Bearer " + seats.hostToken()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("HOST_WIN"))
                .andExpect(jsonPath("$.coinsGranted").value(Matchers.greaterThan(0)))
                .andReturn();
        int hostCoins = ((Number) JsonPath.read(hostSnap.getResponse().getContentAsString(), "$.coinsGranted"))
                .intValue();

        MvcResult joinerSnap = mockMvc.perform(get("/v1/matches/" + seats.matchId())
                        .header("Authorization", "Bearer " + seats.joinerToken()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("HOST_WIN"))
                .andReturn();
        int joinerCoins = ((Number) JsonPath.read(joinerSnap.getResponse().getContentAsString(), "$.coinsGranted"))
                .intValue();
        if (hostCoins <= joinerCoins) {
            throw new AssertionError(
                    "HOST_WIN must grant host more coins than joiner, host=" + hostCoins + " joiner=" + joinerCoins);
        }
        closeQuietly(host, joiner);
    }

    @Test
    void alchikiGraceStillThirty() throws Exception {
        // After graceFor(game) refactor, Alchiki path still 30s (SESS-02 regression lock)
        Seats seats = bothReadyAlchiki();
        String hostTicket = wsTicket(seats.hostToken(), seats.matchId());
        String joinerTicket = wsTicket(seats.joinerToken(), seats.matchId());

        CollectingListener host = connect(seats.matchId(), hostTicket);
        CollectingListener joiner = connect(seats.matchId(), joinerTicket);
        joiner.socket.sendClose(1001, "drop");
        host.awaitType("OpponentDropped");

        // Dropped seat (joiner) sees remaining grace — same projection as ReconnectIT.getMatchExposesRemainingGrace
        mockMvc.perform(get("/v1/matches/" + seats.matchId())
                        .header("Authorization", "Bearer " + seats.joinerToken()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.reconnectSecondsLeft").isNumber())
                .andExpect(jsonPath("$.reconnectSecondsLeft")
                        .value(Matchers.allOf(Matchers.greaterThanOrEqualTo(1), Matchers.lessThanOrEqualTo(30))));
        closeQuietly(host);
    }

    /** Pair via STICK_PULL private room (rooms.game + createStickPullHumanMatch from 06-04). */
    private Seats bothReadyStickPull() throws Exception {
        String hostToken = mintAccessToken();
        MvcResult created = mockMvc.perform(post("/v1/rooms")
                        .header("Authorization", "Bearer " + hostToken)
                        .contentType(APPLICATION_JSON)
                        .content("{\"game\":\"STICK_PULL\"}"))
                .andExpect(status().isCreated())
                .andReturn();
        String roomId = JsonPath.read(created.getResponse().getContentAsString(), "$.roomId").toString();
        String code = JsonPath.read(created.getResponse().getContentAsString(), "$.code");

        String joinerToken = mintAccessToken();
        mockMvc.perform(post("/v1/rooms/join")
                        .header("Authorization", "Bearer " + joinerToken)
                        .contentType(APPLICATION_JSON)
                        .content("{\"code\":\"" + code + "\"}"))
                .andExpect(status().isOk());

        mockMvc.perform(post("/v1/rooms/" + roomId + "/ready")
                        .header("Authorization", "Bearer " + hostToken)
                        .contentType(APPLICATION_JSON)
                        .content("{}"))
                .andExpect(status().isOk());

        MvcResult bothReady = mockMvc.perform(post("/v1/rooms/" + roomId + "/ready")
                        .header("Authorization", "Bearer " + joinerToken)
                        .contentType(APPLICATION_JSON)
                        .content("{}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.bothReady").value(true))
                .andExpect(jsonPath("$.matchId").exists())
                .andReturn();
        String matchId = JsonPath.read(bothReady.getResponse().getContentAsString(), "$.matchId").toString();

        // Stick Pull human matches use WS + StickState (no Alchiki bonesLeft)
        mockMvc.perform(get("/v1/matches/" + matchId).header("Authorization", "Bearer " + hostToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("IN_PLAY"))
                .andExpect(jsonPath("$.mode").value("PRIVATE"))
                .andExpect(jsonPath("$.bonesLeft").isEmpty());

        return new Seats(hostToken, joinerToken, matchId);
    }

    private Seats bothReadyAlchiki() throws Exception {
        String hostToken = mintAccessToken();
        MvcResult created = mockMvc.perform(post("/v1/rooms")
                        .header("Authorization", "Bearer " + hostToken)
                        .contentType(APPLICATION_JSON)
                        .content("{}"))
                .andExpect(status().isCreated())
                .andReturn();
        String roomId = JsonPath.read(created.getResponse().getContentAsString(), "$.roomId").toString();
        String code = JsonPath.read(created.getResponse().getContentAsString(), "$.code");

        String joinerToken = mintAccessToken();
        mockMvc.perform(post("/v1/rooms/join")
                        .header("Authorization", "Bearer " + joinerToken)
                        .contentType(APPLICATION_JSON)
                        .content("{\"code\":\"" + code + "\"}"))
                .andExpect(status().isOk());

        mockMvc.perform(post("/v1/rooms/" + roomId + "/ready")
                        .header("Authorization", "Bearer " + hostToken)
                        .contentType(APPLICATION_JSON)
                        .content("{}"))
                .andExpect(status().isOk());

        MvcResult bothReady = mockMvc.perform(post("/v1/rooms/" + roomId + "/ready")
                        .header("Authorization", "Bearer " + joinerToken)
                        .contentType(APPLICATION_JSON)
                        .content("{}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.bothReady").value(true))
                .andExpect(jsonPath("$.matchId").exists())
                .andReturn();
        String matchId = JsonPath.read(bothReady.getResponse().getContentAsString(), "$.matchId").toString();
        return new Seats(hostToken, joinerToken, matchId);
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
        if (!listener.opened.await(2, TimeUnit.SECONDS)) {
            throw new AssertionError("websocket did not open");
        }
        return listener;
    }

    private String mintAccessToken() throws Exception {
        MvcResult minted = mockMvc.perform(post("/v1/identity/guest").contentType(APPLICATION_JSON).content("{}"))
                .andExpect(status().isCreated())
                .andReturn();
        return JsonPath.read(minted.getResponse().getContentAsString(), "$.accessToken");
    }

    private static void closeQuietly(CollectingListener... listeners) {
        for (CollectingListener listener : listeners) {
            try {
                listener.socket.sendClose(WebSocket.NORMAL_CLOSURE, "done");
            } catch (RuntimeException ignored) {
                // test teardown
            }
        }
    }

    private record Seats(String hostToken, String joinerToken, String matchId) {}

    static final class CollectingListener implements WebSocket.Listener {
        final List<String> messages = new CopyOnWriteArrayList<>();
        final StringBuilder partial = new StringBuilder();
        final CountDownLatch opened = new CountDownLatch(1);
        WebSocket socket;

        @Override
        public void onOpen(WebSocket webSocket) {
            opened.countDown();
            webSocket.request(1);
        }

        @Override
        public CompletionStage<?> onText(WebSocket webSocket, CharSequence data, boolean last) {
            partial.append(data);
            if (last) {
                messages.add(partial.toString());
                partial.setLength(0);
            }
            webSocket.request(1);
            return null;
        }

        String awaitType(String type) throws InterruptedException {
            return awaitType(type, 8);
        }

        String awaitType(String type, int timeoutSeconds) throws InterruptedException {
            long deadline = System.nanoTime() + TimeUnit.SECONDS.toNanos(timeoutSeconds);
            while (System.nanoTime() < deadline) {
                for (String message : new ArrayList<>(messages)) {
                    if (message.contains("\"" + type + "\"") || message.contains("\"type\":\"" + type + "\"")) {
                        return message;
                    }
                }
                Thread.sleep(50);
            }
            throw new AssertionError("timed out waiting for " + type + " in " + messages);
        }
    }

    private static void awaitCountdownGo(CollectingListener listener) throws InterruptedException {
        long deadline = System.nanoTime() + TimeUnit.SECONDS.toNanos(8);
        while (System.nanoTime() < deadline) {
            for (String message : new ArrayList<>(listener.messages)) {
                if (message.contains("Countdown") && message.contains("\"GO\"")) {
                    return;
                }
            }
            Thread.sleep(50);
        }
        throw new AssertionError("timed out waiting for Countdown GO in " + listener.messages);
    }
}
