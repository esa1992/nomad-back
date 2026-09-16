package com.nomadgames.matchmaking;

import static org.springframework.http.MediaType.APPLICATION_JSON;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.UUID;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;

import javax.sql.DataSource;

import org.hamcrest.Matchers;
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

@SpringBootTest(
        classes = NomadGamesApplication.class,
        properties = {
            "nomad.jwt.secret=test-jwt-secret-that-is-32-bytes!!",
            "nomad.guest.mint-limit-per-minute=100"
        })
@AutoConfigureMockMvc
@Testcontainers
class RoomIT {

    @Container
    @ServiceConnection
    static PostgreSQLContainer postgres = new PostgreSQLContainer("postgres:18");

    @Autowired
    MockMvc mockMvc;

    @Autowired
    DataSource dataSource;

    @Autowired
    RoomService roomService;

    @Test
    void createReturnsCode() throws Exception {
        String token = mintAccessToken();

        mockMvc.perform(post("/v1/rooms")
                        .header("Authorization", "Bearer " + token)
                        .contentType(APPLICATION_JSON)
                        .content("{}"))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.roomId").exists())
                .andExpect(jsonPath("$.code").value(Matchers.matchesPattern("[A-HJ-NP-Z2-9]{4,6}")))
                .andExpect(jsonPath("$.hostLabel").value(Matchers.matchesPattern("Guest-[0-9a-fA-F]{4}")));
    }

    @Test
    void createWithoutBearerIsUnauthorized() throws Exception {
        mockMvc.perform(post("/v1/rooms").contentType(APPLICATION_JSON).content("{}"))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void joinByCodeSitsInLobby() throws Exception {
        String hostToken = mintAccessToken();
        MvcResult created = mockMvc.perform(post("/v1/rooms")
                        .header("Authorization", "Bearer " + hostToken)
                        .contentType(APPLICATION_JSON)
                        .content("{}"))
                .andExpect(status().isCreated())
                .andReturn();
        String code = JsonPath.read(created.getResponse().getContentAsString(), "$.code");
        String roomId = JsonPath.read(created.getResponse().getContentAsString(), "$.roomId").toString();

        String joinerToken = mintAccessToken();
        mockMvc.perform(post("/v1/rooms/join")
                        .header("Authorization", "Bearer " + joinerToken)
                        .contentType(APPLICATION_JSON)
                        .content("{\"code\":\"" + code + "\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.joinerLabel").value(Matchers.matchesPattern("Guest-[0-9a-fA-F]{4}")))
                .andExpect(jsonPath("$.status").value("LOBBY"))
                .andExpect(jsonPath("$.matchId").value(Matchers.nullValue()))
                .andExpect(jsonPath("$.code").doesNotExist());

        mockMvc.perform(get("/v1/rooms/" + roomId).header("Authorization", "Bearer " + joinerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").doesNotExist())
                .andExpect(jsonPath("$.joinerLabel").value(Matchers.matchesPattern("Guest-[0-9a-fA-F]{4}")))
                .andExpect(jsonPath("$.status").value("LOBBY"));

        mockMvc.perform(get("/v1/rooms/" + roomId).header("Authorization", "Bearer " + hostToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(code))
                .andExpect(jsonPath("$.joinerLabel").exists());
    }

    @Test
    void joinUnknownCodeIs404() throws Exception {
        String token = mintAccessToken();
        mockMvc.perform(post("/v1/rooms/join")
                        .header("Authorization", "Bearer " + token)
                        .contentType(APPLICATION_JSON)
                        .content("{\"code\":\"ZZZZZ\"}"))
                .andExpect(status().isNotFound());
    }

    @Test
    void joinStartedRoomIs409() throws Exception {
        String hostToken = mintAccessToken();
        MvcResult created = createRoom(hostToken);
        String roomId = JsonPath.read(created.getResponse().getContentAsString(), "$.roomId").toString();
        String code = JsonPath.read(created.getResponse().getContentAsString(), "$.code");
        setRoomStatus(roomId, "STARTED");

        String joinerToken = mintAccessToken();
        mockMvc.perform(post("/v1/rooms/join")
                        .header("Authorization", "Bearer " + joinerToken)
                        .contentType(APPLICATION_JSON)
                        .content("{\"code\":\"" + code + "\"}"))
                .andExpect(status().isConflict());
    }

    @Test
    void joinClosedRoomIs410() throws Exception {
        String hostToken = mintAccessToken();
        MvcResult created = createRoom(hostToken);
        String roomId = JsonPath.read(created.getResponse().getContentAsString(), "$.roomId").toString();
        String code = JsonPath.read(created.getResponse().getContentAsString(), "$.code");
        setRoomStatus(roomId, "CLOSED");

        String joinerToken = mintAccessToken();
        mockMvc.perform(post("/v1/rooms/join")
                        .header("Authorization", "Bearer " + joinerToken)
                        .contentType(APPLICATION_JSON)
                        .content("{\"code\":\"" + code + "\"}"))
                .andExpect(status().isGone());
    }

    @Test
    void bothReadyStartsJoinerTurn() throws Exception {
        String hostToken = mintAccessToken();
        MvcResult created = createRoom(hostToken);
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
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.bothReady").value(false))
                .andExpect(jsonPath("$.matchId").value(Matchers.nullValue()));

        mockMvc.perform(get("/v1/rooms/" + roomId).header("Authorization", "Bearer " + hostToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.matchId").value(Matchers.nullValue()))
                .andExpect(jsonPath("$.status").value("LOBBY"));

        MvcResult bothReady = mockMvc.perform(post("/v1/rooms/" + roomId + "/ready")
                        .header("Authorization", "Bearer " + joinerToken)
                        .contentType(APPLICATION_JSON)
                        .content("{}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.bothReady").value(true))
                .andExpect(jsonPath("$.matchId").exists())
                .andReturn();
        String matchId = JsonPath.read(bothReady.getResponse().getContentAsString(), "$.matchId").toString();

        mockMvc.perform(get("/v1/matches/" + matchId).header("Authorization", "Bearer " + joinerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.turn").value("JOINER"))
                .andExpect(jsonPath("$.difficulty").value("NORMAL"))
                .andExpect(jsonPath("$.mode").value("PRIVATE"));
    }

    @Test
    void hostLeaveCloses() throws Exception {
        String hostToken = mintAccessToken();
        MvcResult created = createRoom(hostToken);
        String roomId = JsonPath.read(created.getResponse().getContentAsString(), "$.roomId").toString();
        String code = JsonPath.read(created.getResponse().getContentAsString(), "$.code");

        mockMvc.perform(post("/v1/rooms/" + roomId + "/leave")
                        .header("Authorization", "Bearer " + hostToken)
                        .contentType(APPLICATION_JSON)
                        .content("{}"))
                .andExpect(status().isOk());

        String joinerToken = mintAccessToken();
        mockMvc.perform(post("/v1/rooms/join")
                        .header("Authorization", "Bearer " + joinerToken)
                        .contentType(APPLICATION_JSON)
                        .content("{\"code\":\"" + code + "\"}"))
                .andExpect(status().isGone());
    }

    @Test
    void idleTtlCloses() throws Exception {
        String hostToken = mintAccessToken();
        MvcResult created = createRoom(hostToken);
        String roomId = JsonPath.read(created.getResponse().getContentAsString(), "$.roomId").toString();
        String code = JsonPath.read(created.getResponse().getContentAsString(), "$.code");

        new JdbcTemplate(dataSource)
                .update(
                        "UPDATE rooms SET idle_expires_at = now() - interval '1 second' WHERE id = ?",
                        UUID.fromString(roomId));
        roomService.closeExpiredLobbies();

        String joinerToken = mintAccessToken();
        mockMvc.perform(post("/v1/rooms/join")
                        .header("Authorization", "Bearer " + joinerToken)
                        .contentType(APPLICATION_JSON)
                        .content("{\"code\":\"" + code + "\"}"))
                .andExpect(status().isGone());
    }

    @Test
    void concurrentBothReadyCreatesOneMatch() throws Exception {
        String hostToken = mintAccessToken();
        MvcResult created = createRoom(hostToken);
        String roomId = JsonPath.read(created.getResponse().getContentAsString(), "$.roomId").toString();
        String code = JsonPath.read(created.getResponse().getContentAsString(), "$.code");

        String joinerToken = mintAccessToken();
        mockMvc.perform(post("/v1/rooms/join")
                        .header("Authorization", "Bearer " + joinerToken)
                        .contentType(APPLICATION_JSON)
                        .content("{\"code\":\"" + code + "\"}"))
                .andExpect(status().isOk());

        JdbcTemplate jdbc = new JdbcTemplate(dataSource);
        UUID hostId = jdbc.queryForObject(
                "SELECT host_id FROM rooms WHERE id = ?", UUID.class, UUID.fromString(roomId));
        UUID joinerId = jdbc.queryForObject(
                "SELECT joiner_id FROM rooms WHERE id = ?", UUID.class, UUID.fromString(roomId));

        CountDownLatch start = new CountDownLatch(1);
        ExecutorService pool = Executors.newFixedThreadPool(2);
        try {
            Future<MvcResult> hostReady = pool.submit(() -> {
                start.await();
                return mockMvc.perform(post("/v1/rooms/" + roomId + "/ready")
                                .header("Authorization", "Bearer " + hostToken)
                                .contentType(APPLICATION_JSON)
                                .content("{}"))
                        .andReturn();
            });
            Future<MvcResult> joinerReady = pool.submit(() -> {
                start.await();
                return mockMvc.perform(post("/v1/rooms/" + roomId + "/ready")
                                .header("Authorization", "Bearer " + joinerToken)
                                .contentType(APPLICATION_JSON)
                                .content("{}"))
                        .andReturn();
            });
            start.countDown();
            MvcResult hostResult = hostReady.get(30, TimeUnit.SECONDS);
            MvcResult joinerResult = joinerReady.get(30, TimeUnit.SECONDS);

            assertEquals(200, hostResult.getResponse().getStatus());
            assertEquals(200, joinerResult.getResponse().getStatus());

            Object hostMatchId = JsonPath.read(hostResult.getResponse().getContentAsString(), "$.matchId");
            Object joinerMatchId = JsonPath.read(joinerResult.getResponse().getContentAsString(), "$.matchId");
            assertNotNull(hostMatchId);
            assertNotNull(joinerMatchId);
            assertEquals(hostMatchId.toString(), joinerMatchId.toString());

            boolean hostBothReady = JsonPath.read(hostResult.getResponse().getContentAsString(), "$.bothReady");
            boolean joinerBothReady = JsonPath.read(joinerResult.getResponse().getContentAsString(), "$.bothReady");
            assertTrue(hostBothReady || joinerBothReady);

            mockMvc.perform(get("/v1/matches/" + hostMatchId).header("Authorization", "Bearer " + joinerToken))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.turn").value("JOINER"))
                    .andExpect(jsonPath("$.mode").value("PRIVATE"))
                    .andExpect(jsonPath("$.difficulty").value("NORMAL"));

            Integer inPlay = jdbc.queryForObject(
                    "SELECT COUNT(*) FROM matches WHERE host_id = ? AND joiner_id = ? AND status = 'IN_PLAY'",
                    Integer.class,
                    hostId,
                    joinerId);
            assertEquals(1, inPlay);
        } finally {
            pool.shutdownNow();
        }
    }

    @Test
    void concurrentJoinSeatsOneJoiner() throws Exception {
        String hostToken = mintAccessToken();
        MvcResult created = createRoom(hostToken);
        String roomId = JsonPath.read(created.getResponse().getContentAsString(), "$.roomId").toString();
        String code = JsonPath.read(created.getResponse().getContentAsString(), "$.code");

        String guestA = mintAccessToken();
        String guestB = mintAccessToken();

        CountDownLatch start = new CountDownLatch(1);
        ExecutorService pool = Executors.newFixedThreadPool(2);
        try {
            Future<MvcResult> first = pool.submit(() -> {
                start.await();
                return mockMvc.perform(post("/v1/rooms/join")
                                .header("Authorization", "Bearer " + guestA)
                                .contentType(APPLICATION_JSON)
                                .content("{\"code\":\"" + code + "\"}"))
                        .andReturn();
            });
            Future<MvcResult> second = pool.submit(() -> {
                start.await();
                return mockMvc.perform(post("/v1/rooms/join")
                                .header("Authorization", "Bearer " + guestB)
                                .contentType(APPLICATION_JSON)
                                .content("{\"code\":\"" + code + "\"}"))
                        .andReturn();
            });
            start.countDown();
            MvcResult firstResult = first.get(30, TimeUnit.SECONDS);
            MvcResult secondResult = second.get(30, TimeUnit.SECONDS);

            int statusA = firstResult.getResponse().getStatus();
            int statusB = secondResult.getResponse().getStatus();
            int oks = (statusA == 200 ? 1 : 0) + (statusB == 200 ? 1 : 0);
            int conflicts = (statusA == 409 ? 1 : 0) + (statusB == 409 ? 1 : 0);
            assertEquals(1, oks);
            assertEquals(1, conflicts);

            MvcResult winner = statusA == 200 ? firstResult : secondResult;
            Object joinerLabel = JsonPath.read(winner.getResponse().getContentAsString(), "$.joinerLabel");
            assertNotNull(joinerLabel);

            UUID seated = new JdbcTemplate(dataSource)
                    .queryForObject("SELECT joiner_id FROM rooms WHERE id = ?", UUID.class, UUID.fromString(roomId));
            assertNotNull(seated);
        } finally {
            pool.shutdownNow();
        }
    }

    @Test
    void stickPullRoomKickoffCreatesStickPullMatch() throws Exception {
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

        String game = new JdbcTemplate(dataSource)
                .queryForObject("SELECT game FROM matches WHERE id = ?", String.class, UUID.fromString(matchId));
        assertEquals("STICK_PULL", game);
    }

    @Test
    void createRoomWithoutGameDefaultsAlchiki() throws Exception {
        String hostToken = mintAccessToken();
        MvcResult created = createRoom(hostToken);
        String roomId = JsonPath.read(created.getResponse().getContentAsString(), "$.roomId").toString();

        String game = new JdbcTemplate(dataSource)
                .queryForObject("SELECT game FROM rooms WHERE id = ?", String.class, UUID.fromString(roomId));
        assertEquals("ALCHIKI", game);
    }

    @Test
    void createRoomRejectsUnknownGame() throws Exception {
        String hostToken = mintAccessToken();
        mockMvc.perform(post("/v1/rooms")
                        .header("Authorization", "Bearer " + hostToken)
                        .contentType(APPLICATION_JSON)
                        .content("{\"game\":\"CHESS\"}"))
                .andExpect(status().isBadRequest());
    }

    @Test
    void joinDoesNotStart() throws Exception {
        String hostToken = mintAccessToken();
        MvcResult created = createRoom(hostToken);
        String roomId = JsonPath.read(created.getResponse().getContentAsString(), "$.roomId").toString();
        String code = JsonPath.read(created.getResponse().getContentAsString(), "$.code");

        String joinerToken = mintAccessToken();
        mockMvc.perform(post("/v1/rooms/join")
                        .header("Authorization", "Bearer " + joinerToken)
                        .contentType(APPLICATION_JSON)
                        .content("{\"code\":\"" + code + "\"}"))
                .andExpect(status().isOk());

        mockMvc.perform(get("/v1/rooms/" + roomId).header("Authorization", "Bearer " + joinerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.matchId").value(Matchers.nullValue()))
                .andExpect(jsonPath("$.status").value("LOBBY"));
    }

    private MvcResult createRoom(String token) throws Exception {
        return mockMvc.perform(post("/v1/rooms")
                        .header("Authorization", "Bearer " + token)
                        .contentType(APPLICATION_JSON)
                        .content("{}"))
                .andExpect(status().isCreated())
                .andReturn();
    }

    private void setRoomStatus(String roomId, String status) {
        new JdbcTemplate(dataSource)
                .update("UPDATE rooms SET status = ? WHERE id = ?", status, UUID.fromString(roomId));
    }

    private String mintAccessToken() throws Exception {
        MvcResult minted = mockMvc.perform(post("/v1/identity/guest").contentType(APPLICATION_JSON).content("{}"))
                .andExpect(status().isCreated())
                .andReturn();
        return JsonPath.read(minted.getResponse().getContentAsString(), "$.accessToken");
    }
}
