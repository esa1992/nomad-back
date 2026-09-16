package com.nomadgames.session;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.springframework.http.MediaType.APPLICATION_JSON;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.util.Map;
import java.util.UUID;

import javax.sql.DataSource;

import org.junit.jupiter.api.BeforeEach;
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
import com.nomadgames.matchmaking.RankedQueueService;
import com.nomadgames.matchmaking.internal.JoinRateLimiter;

/**
 * MODE-04 Ranked settle: Glicko updates, SoftElo untouched (D-104); Alchiki draw 0.5/0.5.
 */
@SpringBootTest(
        classes = NomadGamesApplication.class,
        properties = {
            "nomad.jwt.secret=test-jwt-secret-that-is-32-bytes!!",
            "nomad.guest.mint-limit-per-minute=100"
        })
@AutoConfigureMockMvc
@Testcontainers
class RankedSettleIT {

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
    RankedQueueService rankedQueue;

    @BeforeEach
    void resetSharedState() {
        joinRateLimiter.reset();
        rankedQueue.reset();
    }

    @Test
    void rankedSettleUpdatesGlickoNotSoftElo() throws Exception {
        Bound a = bind("settle_glicko_a");
        Bound b = bind("settle_glicko_b");
        String matchId = pairRanked(a.token(), b.token(), "ALCHIKI");

        mockMvc.perform(post("/v1/matches/" + matchId + "/leave")
                        .header("Authorization", "Bearer " + a.token()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.match.status").value("JOINER_WIN"));

        JdbcTemplate jdbc = new JdbcTemplate(dataSource);
        Integer softA = jdbc.queryForObject(
                "SELECT soft_rating FROM players WHERE id = ?", Integer.class, a.playerId());
        Integer softB = jdbc.queryForObject(
                "SELECT soft_rating FROM players WHERE id = ?", Integer.class, b.playerId());
        assertEquals(1000, softA);
        assertEquals(1000, softB);

        Map<String, Object> rowA = jdbc.queryForMap(
                """
                SELECT rating, rd, all_time_matches FROM glicko_ratings
                WHERE player_id = ? AND game = 'ALCHIKI'
                ORDER BY season_key DESC LIMIT 1
                """,
                a.playerId());
        Map<String, Object> rowB = jdbc.queryForMap(
                """
                SELECT rating, rd, all_time_matches FROM glicko_ratings
                WHERE player_id = ? AND game = 'ALCHIKI'
                ORDER BY season_key DESC LIMIT 1
                """,
                b.playerId());
        double ratingA = ((Number) rowA.get("rating")).doubleValue();
        double ratingB = ((Number) rowB.get("rating")).doubleValue();
        assertTrue(ratingA < 1500.0, "leaver (loss) Glicko drops");
        assertTrue(ratingB > 1500.0, "remaining (win) Glicko rises");
        assertEquals(1, ((Number) rowA.get("all_time_matches")).intValue());
        assertEquals(1, ((Number) rowB.get("all_time_matches")).intValue());
        assertNotEquals(ratingA, ratingB);
    }

    @Test
    void alchikiDrawHalfScores() throws Exception {
        Bound a = bind("settle_draw_a");
        Bound b = bind("settle_draw_b");
        String matchId = pairRanked(a.token(), b.token(), "ALCHIKI");

        JdbcTemplate jdbc = new JdbcTemplate(dataSource);
        jdbc.update(
                """
                UPDATE matches SET status = 'DRAW', player_score = 0, bot_score = 0,
                  player_turns = 8, bot_turns = 8 WHERE id = ?
                """,
                UUID.fromString(matchId));

        mockMvc.perform(get("/v1/matches/" + matchId).header("Authorization", "Bearer " + a.token()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("DRAW"));

        Map<String, Object> rowA = jdbc.queryForMap(
                """
                SELECT rating, rd, all_time_matches FROM glicko_ratings
                WHERE player_id = ? AND game = 'ALCHIKI'
                ORDER BY season_key DESC LIMIT 1
                """,
                a.playerId());
        Map<String, Object> rowB = jdbc.queryForMap(
                """
                SELECT rating, rd, all_time_matches FROM glicko_ratings
                WHERE player_id = ? AND game = 'ALCHIKI'
                ORDER BY season_key DESC LIMIT 1
                """,
                b.playerId());
        assertEquals(1500.0, ((Number) rowA.get("rating")).doubleValue(), 1e-3);
        assertEquals(1500.0, ((Number) rowB.get("rating")).doubleValue(), 1e-3);
        assertTrue(((Number) rowA.get("rd")).doubleValue() < 350.0);
        assertTrue(((Number) rowB.get("rd")).doubleValue() < 350.0);
        assertEquals(1, ((Number) rowA.get("all_time_matches")).intValue());
        assertEquals(1, ((Number) rowB.get("all_time_matches")).intValue());
    }

    private String pairRanked(String tokenA, String tokenB, String game) throws Exception {
        mockMvc.perform(post("/v1/matchmaking/ranked")
                        .header("Authorization", "Bearer " + tokenA)
                        .contentType(APPLICATION_JSON)
                        .content("{\"game\":\"" + game + "\"}"))
                .andExpect(status().isOk());
        MvcResult second = mockMvc.perform(post("/v1/matchmaking/ranked")
                        .header("Authorization", "Bearer " + tokenB)
                        .contentType(APPLICATION_JSON)
                        .content("{\"game\":\"" + game + "\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.matchId").exists())
                .andReturn();
        return JsonPath.read(second.getResponse().getContentAsString(), "$.matchId").toString();
    }

    private Bound bind(String username) throws Exception {
        MvcResult minted = mockMvc.perform(post("/v1/identity/guest").contentType(APPLICATION_JSON).content("{}"))
                .andExpect(status().isCreated())
                .andReturn();
        String guest = JsonPath.read(minted.getResponse().getContentAsString(), "$.accessToken");
        String playerId = JsonPath.read(minted.getResponse().getContentAsString(), "$.playerId").toString();
        MvcResult bound = mockMvc.perform(post("/v1/identity/bind")
                        .header("Authorization", "Bearer " + guest)
                        .contentType(APPLICATION_JSON)
                        .content("{\"username\":\"" + username + "\",\"password\":\"password12\"}"))
                .andExpect(status().isOk())
                .andReturn();
        String token = JsonPath.read(bound.getResponse().getContentAsString(), "$.accessToken");
        return new Bound(token, UUID.fromString(playerId));
    }

    private record Bound(String token, UUID playerId) {}
}
