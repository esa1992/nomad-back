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

@SpringBootTest(
        classes = NomadGamesApplication.class,
        webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT,
        properties = "nomad.jwt.secret=test-jwt-secret-that-is-32-bytes!!")
@AutoConfigureMockMvc
@Testcontainers
class ReconnectIT {

    @Container
    @ServiceConnection
    static PostgreSQLContainer postgres = new PostgreSQLContainer("postgres:18");

    @Autowired
    MockMvc mockMvc;

    @LocalServerPort
    int port;

    @Test
    void rejoinWithin30sReturnsFullSnapshot() throws Exception {
        Seats seats = bothReady();
        String joinerReconnect = reconnectToken(seats.joinerToken, seats.matchId);
        String hostTicket = wsTicket(seats.hostToken, seats.matchId);
        String joinerTicket = wsTicket(seats.joinerToken, seats.matchId);

        MvcResult before = mockMvc.perform(get("/v1/matches/" + seats.matchId)
                        .header("Authorization", "Bearer " + seats.joinerToken))
                .andExpect(status().isOk())
                .andReturn();
        long originalDeadline = ((Number) JsonPath.read(
                        before.getResponse().getContentAsString(), "$.turnDeadlineEpochMs"))
                .longValue();
        long originalRemaining = originalDeadline - System.currentTimeMillis();

        CollectingListener host = connect(seats.matchId, hostTicket);
        CollectingListener joiner = connect(seats.matchId, joinerTicket);
        joiner.socket.sendClose(1001, "drop");
        host.awaitType("OpponentDropped");

        Thread.sleep(2_000);

        MvcResult rejoined = mockMvc.perform(post("/v1/matches/" + seats.matchId + "/rejoin")
                        .header("Authorization", "Bearer " + seats.joinerToken)
                        .contentType(APPLICATION_JSON)
                        .content("{\"token\":\"" + joinerReconnect + "\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.match.status").value("IN_PLAY"))
                .andExpect(jsonPath("$.match.status").value(Matchers.not("BOT_WIN")))
                .andExpect(jsonPath("$.match.bonesLeft").isArray())
                .andExpect(jsonPath("$.match.bonesLeft").isNotEmpty())
                .andExpect(jsonPath("$.match.playerScore").exists())
                .andExpect(jsonPath("$.match.botScore").exists())
                .andExpect(jsonPath("$.match.turnDeadlineEpochMs").isNumber())
                .andReturn();

        long newDeadline = ((Number) JsonPath.read(
                        rejoined.getResponse().getContentAsString(), "$.match.turnDeadlineEpochMs"))
                .longValue();
        long now = System.currentTimeMillis();
        if (newDeadline <= now) {
            throw new AssertionError("turnDeadline must be in the future after rejoin, got " + newDeadline);
        }
        long newRemaining = newDeadline - now;
        if (newRemaining < originalRemaining - 1_500) {
            throw new AssertionError(
                    "clocks must pause during grace; remaining was "
                            + originalRemaining
                            + "ms then "
                            + newRemaining
                            + "ms after a 2s drop");
        }
        closeQuietly(host);
    }

    @Test
    void tokenRotateAndExpire() throws Exception {
        Seats seats = bothReady();
        String firstToken = reconnectToken(seats.joinerToken, seats.matchId);
        String hostTicket = wsTicket(seats.hostToken, seats.matchId);
        String joinerTicket = wsTicket(seats.joinerToken, seats.matchId);

        CollectingListener host = connect(seats.matchId, hostTicket);
        CollectingListener joiner = connect(seats.matchId, joinerTicket);
        joiner.socket.sendClose(1001, "drop");
        host.awaitType("OpponentDropped");

        MvcResult firstRejoin = mockMvc.perform(post("/v1/matches/" + seats.matchId + "/rejoin")
                        .header("Authorization", "Bearer " + seats.joinerToken)
                        .contentType(APPLICATION_JSON)
                        .content("{\"token\":\"" + firstToken + "\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.reconnectToken").isNotEmpty())
                .andReturn();
        String rotated = JsonPath.read(firstRejoin.getResponse().getContentAsString(), "$.reconnectToken");
        if (firstToken.equals(rotated)) {
            throw new AssertionError("reconnect token must rotate");
        }

        mockMvc.perform(post("/v1/matches/" + seats.matchId + "/rejoin")
                        .header("Authorization", "Bearer " + seats.joinerToken)
                        .contentType(APPLICATION_JSON)
                        .content("{\"token\":\"" + firstToken + "\"}"))
                .andExpect(status().isUnauthorized());

        String joinerTicket2 = wsTicket(seats.joinerToken, seats.matchId);
        CollectingListener joiner2 = connect(seats.matchId, joinerTicket2);
        host.messages.clear();
        joiner2.socket.sendClose(1001, "drop");
        host.awaitType("OpponentDropped");

        Thread.sleep(31_000);

        mockMvc.perform(post("/v1/matches/" + seats.matchId + "/rejoin")
                        .header("Authorization", "Bearer " + seats.joinerToken)
                        .contentType(APPLICATION_JSON)
                        .content("{\"token\":\"" + rotated + "\"}"))
                .andExpect(status().is(Matchers.anyOf(Matchers.is(409), Matchers.is(410))));

        mockMvc.perform(get("/v1/matches/" + seats.matchId)
                        .header("Authorization", "Bearer " + seats.hostToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("HOST_WIN"))
                .andExpect(jsonPath("$.status").value(Matchers.not("BOT_WIN")))
                .andExpect(jsonPath("$.status").value(Matchers.not("IN_PLAY")));
        closeQuietly(host);
    }

    @Test
    void consentedLeaveHasNoGrace() throws Exception {
        Seats seats = bothReady();
        String joinerReconnect = reconnectToken(seats.joinerToken, seats.matchId);

        mockMvc.perform(post("/v1/matches/" + seats.matchId + "/leave")
                        .header("Authorization", "Bearer " + seats.joinerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.match.status").value("HOST_WIN"));

        mockMvc.perform(post("/v1/matches/" + seats.matchId + "/rejoin")
                        .header("Authorization", "Bearer " + seats.joinerToken)
                        .contentType(APPLICATION_JSON)
                        .content("{\"token\":\"" + joinerReconnect + "\"}"))
                .andExpect(status().is(Matchers.anyOf(Matchers.is(409), Matchers.is(410), Matchers.is(401))));

        mockMvc.perform(get("/v1/matches/" + seats.matchId)
                        .header("Authorization", "Bearer " + seats.hostToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("HOST_WIN"))
                .andExpect(jsonPath("$.status").value(Matchers.not("IN_PLAY")));
    }

    /**
     * Alchiki / PRIVATE reconnect grace stays 30s (SESS-02, D-86 default).
     * ReconnectPolicy.graceSeconds(game) returns 30 for ALCHIKI — Stick Pull is 8s
     * (see StickPullReconnectIT). Do not tighten this upper bound to 8.
     */
    @Test
    void getMatchExposesRemainingGrace() throws Exception {
        Seats seats = bothReady();
        String hostTicket = wsTicket(seats.hostToken, seats.matchId);
        String joinerTicket = wsTicket(seats.joinerToken, seats.matchId);
        CollectingListener host = connect(seats.matchId, hostTicket);
        CollectingListener joiner = connect(seats.matchId, joinerTicket);
        joiner.socket.sendClose(1001, "drop");
        host.awaitType("OpponentDropped");

        mockMvc.perform(get("/v1/matches/" + seats.matchId)
                        .header("Authorization", "Bearer " + seats.joinerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.reconnectSecondsLeft").isNumber())
                .andExpect(jsonPath("$.reconnectSecondsLeft")
                        .value(Matchers.allOf(Matchers.greaterThanOrEqualTo(1), Matchers.lessThanOrEqualTo(30))));
        closeQuietly(host);
    }

    @Test
    void staleCloseAfterReplacementKeepsSeat() throws Exception {
        Seats seats = bothReady();
        String joinerReconnect = reconnectToken(seats.joinerToken, seats.matchId);
        String hostTicket = wsTicket(seats.hostToken, seats.matchId);
        String joinerTicket = wsTicket(seats.joinerToken, seats.matchId);

        CollectingListener host = connect(seats.matchId, hostTicket);
        CollectingListener joiner = connect(seats.matchId, joinerTicket);
        joiner.socket.sendClose(1001, "drop");
        host.awaitType("OpponentDropped");

        mockMvc.perform(post("/v1/matches/" + seats.matchId + "/rejoin")
                        .header("Authorization", "Bearer " + seats.joinerToken)
                        .contentType(APPLICATION_JSON)
                        .content("{\"token\":\"" + joinerReconnect + "\"}"))
                .andExpect(status().isOk());

        String joinerTicket2 = wsTicket(seats.joinerToken, seats.matchId);
        CollectingListener joiner2 = connect(seats.matchId, joinerTicket2);
        try {
            joiner.socket.sendClose(1001, "stale");
        } catch (RuntimeException ignored) {
            // original listener may already be gone
        }
        Thread.sleep(2_000);

        mockMvc.perform(get("/v1/matches/" + seats.matchId)
                        .header("Authorization", "Bearer " + seats.hostToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("IN_PLAY"))
                .andExpect(jsonPath("$.status").value(Matchers.not("HOST_WIN")));
        closeQuietly(host, joiner2);
    }

    /**
     * SESS-02 for mode CASUAL — Wave 0 RED until createCasualMatch + isHumanPvP (05-02).
     * Mirrors rejoinWithin30sReturnsFullSnapshot but expects match.mode == CASUAL.
     */
    @Test
    void casualRejoinWithinGrace() throws Exception {
        Seats seats = bothReadyCasual();
        String joinerReconnect = reconnectToken(seats.joinerToken, seats.matchId);
        String hostTicket = wsTicket(seats.hostToken, seats.matchId);
        String joinerTicket = wsTicket(seats.joinerToken, seats.matchId);

        mockMvc.perform(get("/v1/matches/" + seats.matchId)
                        .header("Authorization", "Bearer " + seats.joinerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.mode").value("CASUAL"));

        CollectingListener host = connect(seats.matchId, hostTicket);
        CollectingListener joiner = connect(seats.matchId, joinerTicket);
        joiner.socket.sendClose(1001, "drop");
        host.awaitType("OpponentDropped");

        mockMvc.perform(post("/v1/matches/" + seats.matchId + "/rejoin")
                        .header("Authorization", "Bearer " + seats.joinerToken)
                        .contentType(APPLICATION_JSON)
                        .content("{\"token\":\"" + joinerReconnect + "\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.match.status").value("IN_PLAY"))
                .andExpect(jsonPath("$.match.mode").value("CASUAL"))
                .andExpect(jsonPath("$.match.bonesLeft").isArray())
                .andExpect(jsonPath("$.match.bonesLeft").isNotEmpty());
        closeQuietly(host);
    }

    @Test
    void handshakeClearsSeatGrace() throws Exception {
        Seats seats = bothReady();
        String hostTicket = wsTicket(seats.hostToken, seats.matchId);
        String joinerTicket = wsTicket(seats.joinerToken, seats.matchId);

        CollectingListener host = connect(seats.matchId, hostTicket);
        CollectingListener joiner = connect(seats.matchId, joinerTicket);
        joiner.socket.sendClose(1001, "drop");
        host.awaitType("OpponentDropped");

        mockMvc.perform(get("/v1/matches/" + seats.matchId)
                        .header("Authorization", "Bearer " + seats.joinerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.reconnectSecondsLeft").isNumber())
                .andExpect(jsonPath("$.reconnectSecondsLeft")
                        .value(Matchers.allOf(Matchers.greaterThanOrEqualTo(1), Matchers.lessThanOrEqualTo(30))));

        String joinerTicket2 = wsTicket(seats.joinerToken, seats.matchId);
        CollectingListener joiner2 = connect(seats.matchId, joinerTicket2);

        mockMvc.perform(get("/v1/matches/" + seats.matchId)
                        .header("Authorization", "Bearer " + seats.joinerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.reconnectSecondsLeft").value(Matchers.nullValue()));

        mockMvc.perform(get("/v1/matches/" + seats.matchId)
                        .header("Authorization", "Bearer " + seats.hostToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("IN_PLAY"))
                .andExpect(jsonPath("$.status").value(Matchers.not("HOST_WIN")));

        Thread.sleep(2_000);

        mockMvc.perform(get("/v1/matches/" + seats.matchId)
                        .header("Authorization", "Bearer " + seats.hostToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("IN_PLAY"))
                .andExpect(jsonPath("$.status").value(Matchers.not("HOST_WIN")));
        closeQuietly(host, joiner2);
    }

    private String reconnectToken(String accessToken, String matchId) throws Exception {
        MvcResult minted = mockMvc.perform(post("/v1/matches/" + matchId + "/ws-ticket")
                        .header("Authorization", "Bearer " + accessToken)
                        .contentType(APPLICATION_JSON)
                        .content("{}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.reconnectToken").isNotEmpty())
                .andReturn();
        return JsonPath.read(minted.getResponse().getContentAsString(), "$.reconnectToken");
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

    private Seats bothReady() throws Exception {
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

    /** Pair two guests via casual queue — RED until /v1/matchmaking/casual exists (05-02). */
    private Seats bothReadyCasual() throws Exception {
        String hostToken = mintAccessToken();
        String joinerToken = mintAccessToken();

        mockMvc.perform(post("/v1/matchmaking/casual")
                        .header("Authorization", "Bearer " + hostToken)
                        .contentType(APPLICATION_JSON)
                        .content("{}"))
                .andExpect(status().isOk());

        MvcResult paired = mockMvc.perform(post("/v1/matchmaking/casual")
                        .header("Authorization", "Bearer " + joinerToken)
                        .contentType(APPLICATION_JSON)
                        .content("{}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("MATCHED"))
                .andExpect(jsonPath("$.mode").value("CASUAL"))
                .andExpect(jsonPath("$.matchId").exists())
                .andReturn();
        String matchId = JsonPath.read(paired.getResponse().getContentAsString(), "$.matchId").toString();
        return new Seats(hostToken, joinerToken, matchId);
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
            long deadline = System.nanoTime() + TimeUnit.SECONDS.toNanos(8);
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
}
