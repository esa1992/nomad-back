package com.nomadgames.session;

import static org.hamcrest.Matchers.anyOf;
import static org.hamcrest.Matchers.is;
import static org.hamcrest.Matchers.not;
import static org.hamcrest.Matchers.nullValue;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.springframework.http.MediaType.APPLICATION_JSON;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.lang.reflect.Field;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.Instant;
import java.util.LinkedHashSet;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;

import javax.sql.DataSource;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.postgresql.PostgreSQLContainer;

import com.jayway.jsonpath.JsonPath;
import com.nomadgames.NomadGamesApplication;
import com.nomadgames.session.internal.MatchSessionRegistry;

@SpringBootTest(
        classes = NomadGamesApplication.class,
        properties = "nomad.jwt.secret=test-jwt-secret-that-is-32-bytes!!")
@AutoConfigureMockMvc
@Testcontainers
class RematchIT {

    @Container
    @ServiceConnection
    static PostgreSQLContainer postgres = new PostgreSQLContainer("postgres:18");

    @Autowired
    MockMvc mockMvc;

    @Autowired
    DataSource dataSource;

    @Autowired
    MatchSessionRegistry sessions;

    @Test
    void bothAcceptCreatesNewMatchJoinerTurn() throws Exception {
        StartedPrivateMatch started = finishPrivateViaLeave();

        mockMvc.perform(post("/v1/matches/" + started.matchId + "/rematch")
                        .header("Authorization", "Bearer " + started.hostToken)
                        .contentType(APPLICATION_JSON)
                        .content("{\"accept\":true}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.accepted").value(true))
                .andExpect(jsonPath("$.matchId").value(nullValue()));

        MvcResult second = mockMvc.perform(post("/v1/matches/" + started.matchId + "/rematch")
                        .header("Authorization", "Bearer " + started.joinerToken)
                        .contentType(APPLICATION_JSON)
                        .content("{\"accept\":true}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.accepted").value(true))
                .andExpect(jsonPath("$.matchId").value(not(started.matchId)))
                .andExpect(jsonPath("$.turn").value("JOINER"))
                .andReturn();
        String newMatchId = JsonPath.read(second.getResponse().getContentAsString(), "$.matchId").toString();

        mockMvc.perform(get("/v1/matches/" + newMatchId).header("Authorization", "Bearer " + started.hostToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.mode").value("PRIVATE"))
                .andExpect(jsonPath("$.turn").value("JOINER"))
                .andExpect(jsonPath("$.hostId").value(started.hostId))
                .andExpect(jsonPath("$.joinerId").value(started.joinerId));
    }

    @Test
    void firstAccepterPollsNewMatchId() throws Exception {
        StartedPrivateMatch started = finishPrivateViaLeave();

        mockMvc.perform(post("/v1/matches/" + started.matchId + "/rematch")
                        .header("Authorization", "Bearer " + started.hostToken)
                        .contentType(APPLICATION_JSON)
                        .content("{\"accept\":true}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.accepted").value(true))
                .andExpect(jsonPath("$.matchId").value(nullValue()));

        mockMvc.perform(get("/v1/matches/" + started.matchId + "/rematch")
                        .header("Authorization", "Bearer " + started.hostToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.acceptedHost").value(true))
                .andExpect(jsonPath("$.acceptedJoiner").value(false))
                .andExpect(jsonPath("$.matchId").value(nullValue()))
                .andExpect(jsonPath("$.expired").value(false));

        MvcResult second = mockMvc.perform(post("/v1/matches/" + started.matchId + "/rematch")
                        .header("Authorization", "Bearer " + started.joinerToken)
                        .contentType(APPLICATION_JSON)
                        .content("{\"accept\":true}"))
                .andExpect(status().isOk())
                .andReturn();
        String newMatchId = JsonPath.read(second.getResponse().getContentAsString(), "$.matchId").toString();

        mockMvc.perform(get("/v1/matches/" + started.matchId + "/rematch")
                        .header("Authorization", "Bearer " + started.hostToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.matchId").value(newMatchId));
    }

    @Test
    void bothSeatsTicketNewMatch() throws Exception {
        StartedPrivateMatch started = finishPrivateViaLeave();

        mockMvc.perform(post("/v1/matches/" + started.matchId + "/rematch")
                        .header("Authorization", "Bearer " + started.hostToken)
                        .contentType(APPLICATION_JSON)
                        .content("{\"accept\":true}"))
                .andExpect(status().isOk());

        MvcResult second = mockMvc.perform(post("/v1/matches/" + started.matchId + "/rematch")
                        .header("Authorization", "Bearer " + started.joinerToken)
                        .contentType(APPLICATION_JSON)
                        .content("{\"accept\":true}"))
                .andExpect(status().isOk())
                .andReturn();
        String newMatchId = JsonPath.read(second.getResponse().getContentAsString(), "$.matchId").toString();

        mockMvc.perform(post("/v1/matches/" + newMatchId + "/ws-ticket")
                        .header("Authorization", "Bearer " + started.hostToken)
                        .contentType(APPLICATION_JSON)
                        .content("{}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.ticket").exists());

        mockMvc.perform(post("/v1/matches/" + newMatchId + "/ws-ticket")
                        .header("Authorization", "Bearer " + started.joinerToken)
                        .contentType(APPLICATION_JSON)
                        .content("{}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.ticket").exists());
    }

    @Test
    void timeoutDoesNotCreate() throws Exception {
        StartedPrivateMatch started = finishPrivateViaLeave();
        int inPlayBefore = countInPlay();

        mockMvc.perform(post("/v1/matches/" + started.matchId + "/rematch")
                        .header("Authorization", "Bearer " + started.hostToken)
                        .contentType(APPLICATION_JSON)
                        .content("{\"accept\":true}"))
                .andExpect(status().isOk());

        expireRematchWindow(started.matchId);

        mockMvc.perform(get("/v1/matches/" + started.matchId + "/rematch")
                        .header("Authorization", "Bearer " + started.hostToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.expired").value(true));

        mockMvc.perform(post("/v1/matches/" + started.matchId + "/rematch")
                        .header("Authorization", "Bearer " + started.joinerToken)
                        .contentType(APPLICATION_JSON)
                        .content("{\"accept\":true}"))
                .andExpect(status().is(anyOf(is(409), is(410))));

        if (countInPlay() != inPlayBefore) {
            throw new AssertionError("timeout must not create a new IN_PLAY row");
        }
    }

    @Test
    void concurrentBothAcceptCreatesOneMatch() throws Exception {
        String acceptRematch = acceptRematchSource();
        if (!acceptRematch.contains("synchronized")) {
            throw new AssertionError("acceptRematch must synchronized(window) so dual Again? cannot mint two PRIVATE rows");
        }

        StartedPrivateMatch started = finishPrivateViaLeave();
        CountDownLatch start = new CountDownLatch(1);
        ExecutorService pool = Executors.newFixedThreadPool(2);
        try {
            Future<MvcResult> hostAccept = pool.submit(() -> {
                start.await();
                return mockMvc.perform(post("/v1/matches/" + started.matchId + "/rematch")
                                .header("Authorization", "Bearer " + started.hostToken)
                                .contentType(APPLICATION_JSON)
                                .content("{\"accept\":true}"))
                        .andReturn();
            });
            Future<MvcResult> joinerAccept = pool.submit(() -> {
                start.await();
                return mockMvc.perform(post("/v1/matches/" + started.matchId + "/rematch")
                                .header("Authorization", "Bearer " + started.joinerToken)
                                .contentType(APPLICATION_JSON)
                                .content("{\"accept\":true}"))
                        .andReturn();
            });
            start.countDown();
            MvcResult hostResult = hostAccept.get(30, TimeUnit.SECONDS);
            MvcResult joinerResult = joinerAccept.get(30, TimeUnit.SECONDS);

            assertEquals(200, hostResult.getResponse().getStatus());
            assertEquals(200, joinerResult.getResponse().getStatus());

            Set<String> matchIds = new LinkedHashSet<>();
            collectMatchId(matchIds, hostResult.getResponse().getContentAsString());
            collectMatchId(matchIds, joinerResult.getResponse().getContentAsString());

            MvcResult poll = mockMvc.perform(get("/v1/matches/" + started.matchId + "/rematch")
                            .header("Authorization", "Bearer " + started.hostToken))
                    .andExpect(status().isOk())
                    .andReturn();
            collectMatchId(matchIds, poll.getResponse().getContentAsString());

            assertEquals(1, matchIds.size());
            String newMatchId = matchIds.iterator().next();
            assertNotEquals(started.matchId, newMatchId);

            Integer inPlay = new JdbcTemplate(dataSource)
                    .queryForObject(
                            "SELECT COUNT(*) FROM matches WHERE host_id = ? AND joiner_id = ? AND status = 'IN_PLAY'",
                            Integer.class,
                            UUID.fromString(started.hostId),
                            UUID.fromString(started.joinerId));
            assertEquals(1, inPlay);

            mockMvc.perform(get("/v1/matches/" + newMatchId)
                            .header("Authorization", "Bearer " + started.joinerToken))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.turn").value("JOINER"));
        } finally {
            pool.shutdownNow();
        }
    }

    private static String acceptRematchSource() throws Exception {
        Path source = Path.of("src/main/java/com/nomadgames/session/MatchService.java");
        String text = Files.readString(source);
        int start = text.indexOf("public RematchAcceptResponse acceptRematch");
        int end = text.indexOf("public RematchPollResponse getRematch");
        if (start < 0 || end < 0 || end <= start) {
            throw new AssertionError("could not locate acceptRematch in MatchService.java");
        }
        return text.substring(start, end);
    }

    private static void collectMatchId(Set<String> matchIds, String body) {
        Object matchId = JsonPath.read(body, "$.matchId");
        if (matchId != null) {
            matchIds.add(matchId.toString());
        }
    }

    private StartedPrivateMatch finishPrivateViaLeave() throws Exception {
        StartedPrivateMatch started = startPrivateMatch();
        mockMvc.perform(post("/v1/matches/" + started.matchId + "/leave")
                        .header("Authorization", "Bearer " + started.joinerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.match.status").value("HOST_WIN"));
        return started;
    }

    private StartedPrivateMatch startPrivateMatch() throws Exception {
        Guest host = mintGuest();
        MvcResult created = mockMvc.perform(post("/v1/rooms")
                        .header("Authorization", "Bearer " + host.token)
                        .contentType(APPLICATION_JSON)
                        .content("{}"))
                .andExpect(status().isCreated())
                .andReturn();
        String roomId = JsonPath.read(created.getResponse().getContentAsString(), "$.roomId").toString();
        String code = JsonPath.read(created.getResponse().getContentAsString(), "$.code");

        Guest joiner = mintGuest();
        mockMvc.perform(post("/v1/rooms/join")
                        .header("Authorization", "Bearer " + joiner.token)
                        .contentType(APPLICATION_JSON)
                        .content("{\"code\":\"" + code + "\"}"))
                .andExpect(status().isOk());

        mockMvc.perform(post("/v1/rooms/" + roomId + "/ready")
                        .header("Authorization", "Bearer " + host.token)
                        .contentType(APPLICATION_JSON)
                        .content("{}"))
                .andExpect(status().isOk());

        MvcResult bothReady = mockMvc.perform(post("/v1/rooms/" + roomId + "/ready")
                        .header("Authorization", "Bearer " + joiner.token)
                        .contentType(APPLICATION_JSON)
                        .content("{}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.bothReady").value(true))
                .andExpect(jsonPath("$.matchId").exists())
                .andReturn();
        String matchId = JsonPath.read(bothReady.getResponse().getContentAsString(), "$.matchId").toString();
        return new StartedPrivateMatch(matchId, host.token, joiner.token, host.playerId, joiner.playerId);
    }

    private int countInPlay() {
        Integer count = new JdbcTemplate(dataSource)
                .queryForObject("SELECT COUNT(*) FROM matches WHERE status = 'IN_PLAY'", Integer.class);
        return count == null ? 0 : count;
    }

    @SuppressWarnings("unchecked")
    private void expireRematchWindow(String matchId) throws Exception {
        Field field = MatchSessionRegistry.class.getDeclaredField("rematchWindows");
        field.setAccessible(true);
        Map<UUID, Object> windows = (Map<UUID, Object>) field.get(sessions);
        Object window = windows.get(UUID.fromString(matchId));
        if (window == null) {
            throw new AssertionError("expected rematch window after first accept");
        }
        Field deadline = window.getClass().getDeclaredField("deadline");
        deadline.setAccessible(true);
        deadline.set(window, Instant.EPOCH);
    }

    private Guest mintGuest() throws Exception {
        MvcResult minted = mockMvc.perform(post("/v1/identity/guest").contentType(APPLICATION_JSON).content("{}"))
                .andExpect(status().isCreated())
                .andReturn();
        String body = minted.getResponse().getContentAsString();
        return new Guest(
                JsonPath.read(body, "$.accessToken"),
                JsonPath.read(body, "$.playerId").toString());
    }

    private record Guest(String token, String playerId) {}

    private record StartedPrivateMatch(
            String matchId, String hostToken, String joinerToken, String hostId, String joinerId) {}
}
