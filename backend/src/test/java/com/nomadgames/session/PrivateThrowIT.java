package com.nomadgames.session;

import static org.springframework.http.MediaType.APPLICATION_JSON;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.WebSocket;
import java.time.Duration;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.CompletionStage;
import java.util.concurrent.CopyOnWriteArrayList;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;

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
class PrivateThrowIT {

    static final String POCKETING_THROW =
            """
            {
              "schemaVersion": 1,
              "yUp": true,
              "aimAngleRad": 1.3962634015954636,
              "holdMs": 640,
              "seed": 1,
              "tableId": "alchiki-match-v1"
            }
            """;

    static final String THROW_INPUT_FRAME =
            """
            {
              "type": "ThrowInput",
              "schemaVersion": 1,
              "yUp": true,
              "aimAngleRad": 1.3962634015954636,
              "holdMs": 640,
              "seed": 1,
              "tableId": "alchiki-match-v1"
            }
            """;

    static final String FORGED_THROW_FRAME =
            """
            {
              "type": "ThrowInput",
              "schemaVersion": 1,
              "yUp": true,
              "aimAngleRad": 1.3962634015954636,
              "holdMs": 640,
              "seed": 1,
              "tableId": "alchiki-match-v1",
              "pocketedCount": 99,
              "score": 99,
              "displayedScore": 99,
              "winner": "HOST"
            }
            """;

    @Container
    @ServiceConnection
    static PostgreSQLContainer postgres = new PostgreSQLContainer("postgres:18");

    @Autowired
    MockMvc mockMvc;

    @LocalServerPort
    int port;

    @Test
    void wsTicketRequired() throws Exception {
        Seats seats = bothReady();

        mockMvc.perform(post("/v1/matches/" + seats.matchId + "/ws-ticket").contentType(APPLICATION_JSON).content("{}"))
                .andExpect(status().isUnauthorized());

        mockMvc.perform(post("/v1/matches/" + seats.matchId + "/ws-ticket")
                        .header("Authorization", "Bearer " + seats.joinerToken)
                        .contentType(APPLICATION_JSON)
                        .content("{}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.ticket").exists())
                .andExpect(jsonPath("$.expiresAt").exists());
    }

    @Test
    void joinerThrowBroadcastsThrowResolvedToBothSeats() throws Exception {
        Seats seats = bothReady();
        String hostTicket = wsTicket(seats.hostToken, seats.matchId);
        String joinerTicket = wsTicket(seats.joinerToken, seats.matchId);

        CollectingListener host = connect(seats.matchId, hostTicket);
        CollectingListener joiner = connect(seats.matchId, joinerTicket);
        joiner.socket.sendText(THROW_INPUT_FRAME, true);

        String hostFrame = host.awaitType("ThrowResolved");
        String joinerFrame = joiner.awaitType("ThrowResolved");
        if (!hostFrame.contains("ThrowResolved") || !joinerFrame.contains("ThrowResolved")) {
            throw new AssertionError("both seats must receive ThrowResolved");
        }
        Number hostScore = JsonPath.read(hostFrame, "$.playerThrow.displayedScore");
        Number joinerScore = JsonPath.read(joinerFrame, "$.playerThrow.displayedScore");
        if (hostScore.intValue() != joinerScore.intValue()) {
            throw new AssertionError("both seats must see the same displayedScore");
        }
        closeQuietly(host, joiner);
    }

    @Test
    void forgedScoreKeysOnSocketAreIgnored() throws Exception {
        Seats seats = bothReady();
        String hostTicket = wsTicket(seats.hostToken, seats.matchId);
        String joinerTicket = wsTicket(seats.joinerToken, seats.matchId);

        CollectingListener host = connect(seats.matchId, hostTicket);
        CollectingListener joiner = connect(seats.matchId, joinerTicket);
        joiner.socket.sendText(FORGED_THROW_FRAME, true);

        String resolved = joiner.awaitType("ThrowResolved");
        Number displayed = JsonPath.read(resolved, "$.playerThrow.displayedScore");
        if (displayed.intValue() == 99) {
            throw new AssertionError("displayedScore must come from dyn4j, not the WS payload");
        }
        closeQuietly(host, joiner);
    }

    @Test
    void hostThrowOnJoinerTurnSendsError() throws Exception {
        Seats seats = bothReady();
        String hostTicket = wsTicket(seats.hostToken, seats.matchId);
        String joinerTicket = wsTicket(seats.joinerToken, seats.matchId);

        CollectingListener host = connect(seats.matchId, hostTicket);
        CollectingListener joiner = connect(seats.matchId, joinerTicket);
        host.socket.sendText(THROW_INPUT_FRAME, true);

        String error = host.awaitType("Error");
        String message = JsonPath.read(error, "$.message");
        if (message == null || !message.toLowerCase().contains("not your turn")) {
            throw new AssertionError("expected not-your-turn error, got: " + error);
        }
        closeQuietly(host, joiner);
    }

    @Test
    void restThrowsOnPrivateMatchIsConflict() throws Exception {
        Seats seats = bothReady();

        mockMvc.perform(post("/v1/matches/" + seats.matchId + "/throws")
                        .header("Authorization", "Bearer " + seats.joinerToken)
                        .contentType(APPLICATION_JSON)
                        .content(POCKETING_THROW))
                .andExpect(status().isConflict());
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
