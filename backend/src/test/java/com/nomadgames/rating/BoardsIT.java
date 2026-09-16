package com.nomadgames.rating;

import static org.springframework.http.MediaType.APPLICATION_JSON;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.util.UUID;

import org.hamcrest.Matchers;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.postgresql.PostgreSQLContainer;

import com.jayway.jsonpath.JsonPath;
import com.nomadgames.NomadGamesApplication;

/**
 * LEAD-01…03 bound-only skill boards (greens in 07-06).
 */
@SpringBootTest(
        classes = NomadGamesApplication.class,
        properties = {
            "nomad.jwt.secret=test-jwt-secret-that-is-32-bytes!!",
            "nomad.guest.mint-limit-per-minute=100"
        })
@AutoConfigureMockMvc
@Testcontainers
class BoardsIT {

    @Container
    @ServiceConnection
    static PostgreSQLContainer postgres = new PostgreSQLContainer("postgres:18");

    @Autowired
    MockMvc mockMvc;

    @Autowired
    JdbcClient jdbc;

    @Autowired
    SeasonService seasons;

    @Test
    void guestRejected() throws Exception {
        Minted guest = mint();
        mockMvc.perform(get("/v1/boards").header("Authorization", "Bearer " + guest.access())
                        .param("game", "ALCHIKI")
                        .param("scope", "all_time"))
                .andExpect(status().isForbidden());
    }

    @Test
    void guestsExcluded() throws Exception {
        // LEAD-01…03 / D-106: guests never appear on boards; bound-only
        Bound bound = bind("boards_bound_01");
        Minted guest = mint();
        // Guest with inflated peak must still be filtered out
        seedRating(guest.playerId(), "ALCHIKI", seasons.currentSeasonKey(), 1900, 1900);
        seedRating(bound.playerId(), "ALCHIKI", seasons.currentSeasonKey(), 1510, 1510);

        mockMvc.perform(get("/v1/boards").header("Authorization", "Bearer " + bound.access())
                        .param("game", "ALCHIKI")
                        .param("scope", "all_time"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.entries[*].guest").value(Matchers.not(Matchers.hasItem(true))))
                .andExpect(jsonPath("$.entries[*].playerId")
                        .value(Matchers.not(Matchers.hasItem(guest.playerId().toString()))));
    }

    @Test
    void filterByGame() throws Exception {
        // LEAD-01: boards filtered by game discriminator
        Bound bound = bind("boards_game_01");
        seedRating(bound.playerId(), "STICK_PULL", seasons.currentSeasonKey(), 1520, 1520);
        seedRating(bound.playerId(), "ALCHIKI", seasons.currentSeasonKey(), 1600, 1600);

        mockMvc.perform(get("/v1/boards").header("Authorization", "Bearer " + bound.access())
                        .param("game", "STICK_PULL")
                        .param("scope", "all_time"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.game").value("STICK_PULL"))
                .andExpect(jsonPath("$.entries[0].rating").value(1520));
    }

    @Test
    void seasonVsAllTime() throws Exception {
        // LEAD-02: scope=season|all_time (assert this player — shared IT DB may have other seeded rows)
        Bound bound = bind("boards_scope_01");
        seedRating(bound.playerId(), "ALCHIKI", seasons.currentSeasonKey(), 1505, 1610);

        mockMvc.perform(get("/v1/boards").header("Authorization", "Bearer " + bound.access())
                        .param("game", "ALCHIKI")
                        .param("scope", "season"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.scope").value("season"))
                .andExpect(jsonPath("$.entries[?(@.username=='boards_scope_01')].rating")
                        .value(Matchers.hasItem(1505)));

        mockMvc.perform(get("/v1/boards").header("Authorization", "Bearer " + bound.access())
                        .param("game", "ALCHIKI")
                        .param("scope", "all_time"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.scope").value("all_time"))
                .andExpect(jsonPath("$.entries[?(@.username=='boards_scope_01')].rating")
                        .value(Matchers.hasItem(1610)));
    }

    @Test
    void neverOrderByCoins() throws Exception {
        // LEAD-03 / D-106: skill boards never order by coins/gems
        Bound richLowSkill = bind("boards_rich_01");
        Bound poorHighSkill = bind("boards_skill_01");
        setWallet(richLowSkill.playerId(), 999_999, 0);
        setWallet(poorHighSkill.playerId(), 0, 0);
        seedRating(richLowSkill.playerId(), "ALCHIKI", seasons.currentSeasonKey(), 1400, 1400);
        seedRating(poorHighSkill.playerId(), "ALCHIKI", seasons.currentSeasonKey(), 1700, 1700);

        MvcResult boards = mockMvc.perform(get("/v1/boards").header("Authorization", "Bearer " + poorHighSkill.access())
                        .param("game", "ALCHIKI")
                        .param("scope", "all_time"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.entries").isArray())
                .andExpect(jsonPath("$.entries[0].rating").value(1700))
                .andExpect(jsonPath("$.entries[0].playerId").value(poorHighSkill.playerId().toString()))
                .andReturn();
        String body = boards.getResponse().getContentAsString();
        if (body.contains("\"orderBy\":\"coins\"") || body.contains("\"sortedBy\":\"coins\"")) {
            throw new AssertionError("boards must never order by coins: " + body);
        }
        if (body.contains("coins") || body.contains("gems")) {
            throw new AssertionError("boards response must not expose wallet fields: " + body);
        }
    }

    private void seedRating(UUID playerId, String game, String seasonKey, double rating, double peak) {
        jdbc.sql(
                        """
                        INSERT INTO glicko_ratings (
                          player_id, game, season_key, rating, rd, sigma, matches,
                          all_time_rating, all_time_peak, all_time_matches, updated_at)
                        VALUES (
                          :playerId, :game, :seasonKey, :rating, 350, 0.06, 1,
                          :peak, :peak, 1, now())
                        ON CONFLICT (player_id, game, season_key) DO UPDATE SET
                          rating = EXCLUDED.rating,
                          all_time_rating = EXCLUDED.all_time_rating,
                          all_time_peak = EXCLUDED.all_time_peak,
                          all_time_matches = EXCLUDED.all_time_matches,
                          updated_at = now()
                        """)
                .param("playerId", playerId)
                .param("game", game)
                .param("seasonKey", seasonKey)
                .param("rating", rating)
                .param("peak", peak)
                .update();
    }

    private void setWallet(UUID playerId, int coins, int gems) {
        jdbc.sql(
                        """
                        INSERT INTO wallets (player_id, currency, balance)
                        VALUES (:playerId, 'COINS', :coins)
                        ON CONFLICT (player_id, currency) DO UPDATE SET balance = EXCLUDED.balance
                        """)
                .param("playerId", playerId)
                .param("coins", coins)
                .update();
        jdbc.sql(
                        """
                        INSERT INTO wallets (player_id, currency, balance)
                        VALUES (:playerId, 'GEMS', :gems)
                        ON CONFLICT (player_id, currency) DO UPDATE SET balance = EXCLUDED.balance
                        """)
                .param("playerId", playerId)
                .param("gems", gems)
                .update();
    }

    private Bound bind(String username) throws Exception {
        Minted guest = mint();
        MvcResult bound = mockMvc.perform(post("/v1/identity/bind")
                        .header("Authorization", "Bearer " + guest.access())
                        .contentType(APPLICATION_JSON)
                        .content("{\"username\":\"" + username + "\",\"password\":\"password12\"}"))
                .andExpect(status().isOk())
                .andReturn();
        String body = bound.getResponse().getContentAsString();
        String access = JsonPath.read(body, "$.accessToken");
        UUID playerId = UUID.fromString(JsonPath.read(body, "$.playerId"));
        return new Bound(access, playerId);
    }

    private Minted mint() throws Exception {
        MvcResult minted = mockMvc.perform(post("/v1/identity/guest").contentType(APPLICATION_JSON).content("{}"))
                .andExpect(status().isCreated())
                .andReturn();
        String body = minted.getResponse().getContentAsString();
        return new Minted(
                JsonPath.read(body, "$.accessToken"),
                UUID.fromString(JsonPath.read(body, "$.playerId")));
    }

    private record Bound(String access, UUID playerId) {}

    private record Minted(String access, UUID playerId) {}
}
