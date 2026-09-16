package com.nomadgames.matchmaking;

import static org.hamcrest.Matchers.nullValue;
import static org.springframework.http.MediaType.APPLICATION_JSON;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import javax.sql.DataSource;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.postgresql.PostgreSQLContainer;

import com.jayway.jsonpath.JsonPath;
import com.nomadgames.NomadGamesApplication;
import com.nomadgames.economy.MatchRewardTable;
import com.nomadgames.matchmaking.internal.JoinRateLimiter;

/**
 * Wave 0 Nyquist stubs for MODE-03 casual queue (greens in 05-02).
 * Endpoints under /v1/matchmaking/casual are not shipped yet — expect RED.
 */
@SpringBootTest(
        classes = NomadGamesApplication.class,
        properties = {
            "nomad.jwt.secret=test-jwt-secret-that-is-32-bytes!!",
            "nomad.guest.mint-limit-per-minute=100"
        })
@AutoConfigureMockMvc
@Testcontainers
class CasualQueueIT {

    @Container
    @ServiceConnection
    static PostgreSQLContainer postgres = new PostgreSQLContainer("postgres:18");

    @Autowired
    MockMvc mockMvc;

    @Autowired
    DataSource dataSource;

    @Autowired
    JoinRateLimiter joinRateLimiter;

    @Autowired
    CasualQueueService casualQueue;

    @BeforeEach
    void resetSharedState() {
        joinRateLimiter.reset();
        casualQueue.reset();
    }

    @Test
    void twoPlayersPair() throws Exception {
        String a = mintAccessToken();
        String b = mintAccessToken();

        MvcResult first = mockMvc.perform(post("/v1/matchmaking/casual")
                        .header("Authorization", "Bearer " + a)
                        .contentType(APPLICATION_JSON)
                        .content("{}"))
                .andExpect(status().isOk())
                .andReturn();

        MvcResult second = mockMvc.perform(post("/v1/matchmaking/casual")
                        .header("Authorization", "Bearer " + b)
                        .contentType(APPLICATION_JSON)
                        .content("{}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("MATCHED"))
                .andExpect(jsonPath("$.mode").value("CASUAL"))
                .andExpect(jsonPath("$.matchId").exists())
                .andReturn();

        String matchId = JsonPath.read(second.getResponse().getContentAsString(), "$.matchId").toString();

        mockMvc.perform(get("/v1/matchmaking/casual").header("Authorization", "Bearer " + a))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("MATCHED"))
                .andExpect(jsonPath("$.matchId").value(matchId))
                .andExpect(jsonPath("$.mode").value("CASUAL"));

        // First enqueue may have been SEARCHING; after pair both share matchId.
        Object firstMatch = JsonPath.read(first.getResponse().getContentAsString(), "$.matchId");
        if (firstMatch != null) {
            org.junit.jupiter.api.Assertions.assertEquals(matchId, firstMatch.toString());
        }
    }

    @Test
    void singlePlayerStaysSearching() throws Exception {
        String token = mintAccessToken();

        mockMvc.perform(post("/v1/matchmaking/casual")
                        .header("Authorization", "Bearer " + token)
                        .contentType(APPLICATION_JSON)
                        .content("{}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("SEARCHING"))
                .andExpect(jsonPath("$.matchId").value(nullValue()));

        mockMvc.perform(get("/v1/matchmaking/casual").header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("SEARCHING"))
                .andExpect(jsonPath("$.matchId").value(nullValue()));
    }

    @Test
    void dequeueClearsTicket() throws Exception {
        String token = mintAccessToken();

        mockMvc.perform(post("/v1/matchmaking/casual")
                        .header("Authorization", "Bearer " + token)
                        .contentType(APPLICATION_JSON)
                        .content("{}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("SEARCHING"));

        mockMvc.perform(delete("/v1/matchmaking/casual").header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("IDLE"));

        mockMvc.perform(get("/v1/matchmaking/casual").header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("IDLE"));
    }

    @Test
    void rejectEnqueueWhileInPlay() throws Exception {
        // Seed an IN_PLAY human seat via private room, then casual enqueue must 409 (T-5-05).
        Seats seats = bothReadyPrivate();

        mockMvc.perform(post("/v1/matchmaking/casual")
                        .header("Authorization", "Bearer " + seats.hostToken())
                        .contentType(APPLICATION_JSON)
                        .content("{}"))
                .andExpect(status().isConflict());
    }

    @Test
    void enqueueRateLimited() throws Exception {
        String token = mintAccessToken();
        int lastStatus = 0;
        for (int i = 0; i < 40; i++) {
            lastStatus = mockMvc.perform(post("/v1/matchmaking/casual")
                            .header("Authorization", "Bearer " + token)
                            .contentType(APPLICATION_JSON)
                            .content("{}"))
                    .andReturn()
                    .getResponse()
                    .getStatus();
            if (lastStatus == 429) {
                break;
            }
        }
        org.junit.jupiter.api.Assertions.assertEquals(
                429, lastStatus, "flood enqueue must eventually 429 (T-5-01)");
    }

    @Test
    void reEnqueueAfterMatchEndsClearsStaleMatched() throws Exception {
        // CR-01: MATCHED tickets must not stick after the casual match leaves IN_PLAY.
        String a = mintAccessToken();
        String b = mintAccessToken();

        mockMvc.perform(post("/v1/matchmaking/casual")
                        .header("Authorization", "Bearer " + a)
                        .contentType(APPLICATION_JSON)
                        .content("{}"))
                .andExpect(status().isOk());
        MvcResult paired = mockMvc.perform(post("/v1/matchmaking/casual")
                        .header("Authorization", "Bearer " + b)
                        .contentType(APPLICATION_JSON)
                        .content("{}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("MATCHED"))
                .andExpect(jsonPath("$.matchId").exists())
                .andReturn();
        String oldMatchId = JsonPath.read(paired.getResponse().getContentAsString(), "$.matchId").toString();

        mockMvc.perform(post("/v1/matches/" + oldMatchId + "/leave")
                        .header("Authorization", "Bearer " + a))
                .andExpect(status().isOk());

        mockMvc.perform(post("/v1/matchmaking/casual")
                        .header("Authorization", "Bearer " + a)
                        .contentType(APPLICATION_JSON)
                        .content("{}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("SEARCHING"))
                .andExpect(jsonPath("$.matchId").value(nullValue()));

        MvcResult again = mockMvc.perform(post("/v1/matchmaking/casual")
                        .header("Authorization", "Bearer " + b)
                        .contentType(APPLICATION_JSON)
                        .content("{}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("MATCHED"))
                .andExpect(jsonPath("$.matchId").exists())
                .andReturn();
        String newMatchId = JsonPath.read(again.getResponse().getContentAsString(), "$.matchId").toString();
        org.junit.jupiter.api.Assertions.assertNotEquals(
                oldMatchId, newMatchId, "re-queue after leave must not reuse finished matchId");
    }

    @Test
    void stickPullEnqueueIsolatedFromAlchiki() throws Exception {
        // D-79 — Wave 0 RED until per-game FIFO (06-04): STICK_PULL never pairs with ALCHIKI waiter
        String alchiki = mintAccessToken();
        String stickPull = mintAccessToken();

        mockMvc.perform(post("/v1/matchmaking/casual")
                        .header("Authorization", "Bearer " + alchiki)
                        .contentType(APPLICATION_JSON)
                        .content("{\"game\":\"ALCHIKI\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("SEARCHING"))
                .andExpect(jsonPath("$.matchId").value(nullValue()));

        mockMvc.perform(post("/v1/matchmaking/casual")
                        .header("Authorization", "Bearer " + stickPull)
                        .contentType(APPLICATION_JSON)
                        .content("{\"game\":\"STICK_PULL\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("SEARCHING"))
                .andExpect(jsonPath("$.matchId").value(nullValue()))
                .andExpect(jsonPath("$.game").value("STICK_PULL"));

        mockMvc.perform(get("/v1/matchmaking/casual").header("Authorization", "Bearer " + alchiki))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("SEARCHING"))
                .andExpect(jsonPath("$.matchId").value(nullValue()));
    }

    @Test
    void casualSettleGrantsMatchPrivatePath() throws Exception {
        // RESEARCH Q1 LOCKED: CASUAL PvP settle uses humanMatch=true same as PRIVATE.
        // Greens in 05-02 after createCasualMatch + grant path rename.
        String a = mintAccessToken();
        String b = mintAccessToken();

        mockMvc.perform(post("/v1/matchmaking/casual")
                        .header("Authorization", "Bearer " + a)
                        .contentType(APPLICATION_JSON)
                        .content("{}"))
                .andExpect(status().isOk());
        MvcResult paired = mockMvc.perform(post("/v1/matchmaking/casual")
                        .header("Authorization", "Bearer " + b)
                        .contentType(APPLICATION_JSON)
                        .content("{}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("MATCHED"))
                .andExpect(jsonPath("$.matchId").exists())
                .andReturn();
        String matchId = JsonPath.read(paired.getResponse().getContentAsString(), "$.matchId").toString();

        MvcResult settled = mockMvc.perform(post("/v1/matches/" + matchId + "/leave")
                        .header("Authorization", "Bearer " + a))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.match.coinsGranted").exists())
                .andReturn();

        int coinsGranted = JsonPath.read(settled.getResponse().getContentAsString(), "$.match.coinsGranted");
        int expected = MatchRewardTable.coins("LOSS", "NORMAL", true);
        // Winner path may differ; assert humanMatch=true table is used (not bot path).
        org.junit.jupiter.api.Assertions.assertTrue(
                coinsGranted == MatchRewardTable.coins("WIN", "NORMAL", true)
                        || coinsGranted == expected
                        || coinsGranted == MatchRewardTable.coins("DRAW", "NORMAL", true),
                "CASUAL settle must use humanMatch=true grant path, got " + coinsGranted);
    }

    private Seats bothReadyPrivate() throws Exception {
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

    private record Seats(String hostToken, String joinerToken, String matchId) {}
}
