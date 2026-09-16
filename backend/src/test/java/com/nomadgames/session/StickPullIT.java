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

/**
 * Wave 0 Nyquist stubs for STICK-01 / BOT-02 Stick Pull WS match path (greens in 06-03).
 * Harness mirrors ReconnectIT / ThrowAuthorityIT — no production StickPullSim this plan.
 */
@SpringBootTest(
        classes = NomadGamesApplication.class,
        webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT,
        properties = "nomad.jwt.secret=test-jwt-secret-that-is-32-bytes!!")
@AutoConfigureMockMvc
@Testcontainers
class StickPullIT {

    @Container
    @ServiceConnection
    static PostgreSQLContainer postgres = new PostgreSQLContainer("postgres:18");

    @Autowired
    MockMvc mockMvc;

    @LocalServerPort
    int port;

    @Test
    void countdownThenTapMovesMarker() throws Exception {
        // STICK-01: BOT (or human) STICK_PULL match — Countdown then TapInput moves marker
        String token = mintAccessToken();
        String matchId = createStickPullBot(token, "EASY");
        String ticket = wsTicket(token, matchId);

        CollectingListener listener = connect(matchId, ticket);
        listener.awaitType("Countdown");

        listener.socket.sendText("{\"type\":\"TapInput\",\"schemaVersion\":1,\"clientSeq\":1}", true);
        String stickState = listener.awaitType("StickState");
        if (!stickState.contains("marker") && !stickState.contains("position")) {
            throw new AssertionError("TapInput after GO must move marker via StickState: " + stickState);
        }
        closeQuietly(listener);
    }

    @Test
    void preGoTapIgnored() throws Exception {
        // D-90: pre-GO TapInput accepted=false / no force
        String token = mintAccessToken();
        String matchId = createStickPullBot(token, "EASY");
        String ticket = wsTicket(token, matchId);

        CollectingListener listener = connect(matchId, ticket);
        listener.socket.sendText("{\"type\":\"TapInput\",\"schemaVersion\":1,\"clientSeq\":1}", true);
        String resolved = listener.awaitType("TapResolved");
        if (!resolved.contains("\"accepted\":false") && !resolved.contains("\"accepted\": false")) {
            throw new AssertionError("pre-GO TapInput must be accepted=false: " + resolved);
        }
        closeQuietly(listener);
    }

    @Test
    void botMatchSettles() throws Exception {
        // BOT-02 path: EASY bot match reaches terminal + MatchSettled
        String token = mintAccessToken();
        String matchId = createStickPullBot(token, "EASY");
        String ticket = wsTicket(token, matchId);

        CollectingListener listener = connect(matchId, ticket);
        listener.awaitType("MatchSettled", 45);
        mockMvc.perform(org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get(
                                "/v1/matches/" + matchId)
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value(org.hamcrest.Matchers.anyOf(
                        org.hamcrest.Matchers.is("PLAYER_WIN"),
                        org.hamcrest.Matchers.is("BOT_WIN"),
                        org.hamcrest.Matchers.is("DRAW"))));
        closeQuietly(listener);
    }

    private String createStickPullBot(String token, String difficulty) throws Exception {
        MvcResult created = mockMvc.perform(post("/v1/matches")
                        .header("Authorization", "Bearer " + token)
                        .contentType(APPLICATION_JSON)
                        .content("{\"game\":\"STICK_PULL\",\"mode\":\"BOT\",\"difficulty\":\""
                                + difficulty
                                + "\"}"))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.game").value("STICK_PULL"))
                .andExpect(jsonPath("$.status").value("IN_PLAY"))
                .andReturn();
        return JsonPath.read(created.getResponse().getContentAsString(), "$.matchId").toString();
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
}
