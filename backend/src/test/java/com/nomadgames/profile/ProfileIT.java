package com.nomadgames.profile;

import static org.hamcrest.Matchers.matchesPattern;
import static org.springframework.http.MediaType.APPLICATION_JSON;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.util.UUID;

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

/**
 * PROF-01…03 + XP/Elo split (server-authored profile projection).
 */
@SpringBootTest(
        classes = NomadGamesApplication.class,
        properties = "nomad.jwt.secret=test-jwt-secret-that-is-32-bytes!!")
@AutoConfigureMockMvc
@Testcontainers
class ProfileIT {

    @Container
    @ServiceConnection
    static PostgreSQLContainer postgres = new PostgreSQLContainer("postgres:18");

    @Autowired
    MockMvc mockMvc;

    @Autowired
    DataSource dataSource;

    /** Same canned throw BurstSimTest / EconomyIT use. */
    static final String POCKETING_THROW =
            """
            {
              "schemaVersion": 1,
              "yUp": true,
              "aimAngleRad": 1.5707963267948966,
              "holdMs": 640,
              "seed": 1,
              "tableId": "alchiki-match-v1"
            }
            """;

    @Test
    void profileReturnsGuestDefaults() throws Exception {
        String token = mintAccessToken();

        mockMvc.perform(get("/v1/profile").header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.displayName").value("Guest"))
                .andExpect(jsonPath("$.subtitle").value(matchesPattern("Guest-[0-9a-fA-F]{4}")))
                .andExpect(jsonPath("$.avatarPreset").value("avatar_01"))
                .andExpect(jsonPath("$.level").value(1))
                .andExpect(jsonPath("$.xp").value(0))
                .andExpect(jsonPath("$.rating").value(1000))
                .andExpect(jsonPath("$.bestRating").value(1000))
                .andExpect(jsonPath("$.games.stickPull.wins").value(0))
                .andExpect(jsonPath("$.games.stickPull.losses").value(0))
                .andExpect(jsonPath("$.games.stickPull.noMatchesYet").value(true));
    }

    @Test
    void putAvatarAllowList() throws Exception {
        String token = mintAccessToken();

        mockMvc.perform(put("/v1/profile/avatar")
                        .header("Authorization", "Bearer " + token)
                        .contentType(APPLICATION_JSON)
                        .content("{\"avatarPreset\":\"avatar_03\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.avatarPreset").value("avatar_03"));

        mockMvc.perform(put("/v1/profile/avatar")
                        .header("Authorization", "Bearer " + token)
                        .contentType(APPLICATION_JSON)
                        .content("{\"avatarPreset\":\"evil_path\"}"))
                .andExpect(status().isBadRequest());
    }

    @Test
    void xpIncrementsOnBotSettleRatingUnchanged() throws Exception {
        String token = mintAccessToken();
        String matchId = createBotMatch(token, "EASY");

        new JdbcTemplate(dataSource)
                .update("UPDATE matches SET player_score = 5 WHERE id = ?", UUID.fromString(matchId));

        mockMvc.perform(post("/v1/matches/" + matchId + "/throws")
                        .header("Authorization", "Bearer " + token)
                        .contentType(APPLICATION_JSON)
                        .content(POCKETING_THROW))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.match.status").value("PLAYER_WIN"));

        mockMvc.perform(get("/v1/profile").header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.xp").value(Matchers.greaterThan(0)))
                .andExpect(jsonPath("$.rating").value(1000));
    }

    @Test
    void eloUpdatesOnCasualSettleOnly() throws Exception {
        Guest a = mintGuest();
        Guest b = mintGuest();

        mockMvc.perform(post("/v1/matchmaking/casual")
                        .header("Authorization", "Bearer " + a.token())
                        .contentType(APPLICATION_JSON)
                        .content("{}"))
                .andExpect(status().isOk());
        MvcResult paired = mockMvc.perform(post("/v1/matchmaking/casual")
                        .header("Authorization", "Bearer " + b.token())
                        .contentType(APPLICATION_JSON)
                        .content("{}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.matchId").exists())
                .andReturn();
        String casualMatchId = JsonPath.read(paired.getResponse().getContentAsString(), "$.matchId").toString();

        mockMvc.perform(post("/v1/matches/" + casualMatchId + "/leave")
                        .header("Authorization", "Bearer " + a.token()))
                .andExpect(status().isOk());

        MvcResult profileA = mockMvc.perform(get("/v1/profile").header("Authorization", "Bearer " + a.token()))
                .andExpect(status().isOk())
                .andReturn();
        MvcResult profileB = mockMvc.perform(get("/v1/profile").header("Authorization", "Bearer " + b.token()))
                .andExpect(status().isOk())
                .andReturn();
        int ratingA = JsonPath.read(profileA.getResponse().getContentAsString(), "$.rating");
        int ratingB = JsonPath.read(profileB.getResponse().getContentAsString(), "$.rating");
        org.junit.jupiter.api.Assertions.assertTrue(
                ratingA != 1000 || ratingB != 1000, "CASUAL PvP settle must move soft_rating (A2)");

        // Private settle must not move soft_rating.
        Seats privateSeats = bothReadyPrivate();
        mockMvc.perform(post("/v1/matches/" + privateSeats.matchId() + "/leave")
                        .header("Authorization", "Bearer " + privateSeats.joinerToken()))
                .andExpect(status().isOk());

        mockMvc.perform(get("/v1/profile").header("Authorization", "Bearer " + privateSeats.hostToken()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.rating").value(1000));
    }

    @Test
    void profileSelfOnly() throws Exception {
        Guest self = mintGuest();
        Guest other = mintGuest();

        mockMvc.perform(get("/v1/profile").header("Authorization", "Bearer " + self.token()))
                .andExpect(status().isOk());

        // No public GET by other playerId (T-5-06).
        mockMvc.perform(get("/v1/profile/" + other.playerId()).header("Authorization", "Bearer " + self.token()))
                .andExpect(status().isNotFound());
    }

    private String createBotMatch(String access, String difficulty) throws Exception {
        MvcResult created = mockMvc.perform(post("/v1/matches")
                        .header("Authorization", "Bearer " + access)
                        .contentType(APPLICATION_JSON)
                        .content("{\"game\":\"ALCHIKI\",\"mode\":\"BOT\",\"difficulty\":\"" + difficulty + "\"}"))
                .andExpect(status().isCreated())
                .andReturn();
        return JsonPath.read(created.getResponse().getContentAsString(), "$.matchId").toString();
    }

    private Seats bothReadyPrivate() throws Exception {
        Guest host = mintGuest();
        MvcResult created = mockMvc.perform(post("/v1/rooms")
                        .header("Authorization", "Bearer " + host.token())
                        .contentType(APPLICATION_JSON)
                        .content("{}"))
                .andExpect(status().isCreated())
                .andReturn();
        String roomId = JsonPath.read(created.getResponse().getContentAsString(), "$.roomId").toString();
        String code = JsonPath.read(created.getResponse().getContentAsString(), "$.code");

        Guest joiner = mintGuest();
        mockMvc.perform(post("/v1/rooms/join")
                        .header("Authorization", "Bearer " + joiner.token())
                        .contentType(APPLICATION_JSON)
                        .content("{\"code\":\"" + code + "\"}"))
                .andExpect(status().isOk());

        mockMvc.perform(post("/v1/rooms/" + roomId + "/ready")
                        .header("Authorization", "Bearer " + host.token())
                        .contentType(APPLICATION_JSON)
                        .content("{}"))
                .andExpect(status().isOk());

        MvcResult bothReady = mockMvc.perform(post("/v1/rooms/" + roomId + "/ready")
                        .header("Authorization", "Bearer " + joiner.token())
                        .contentType(APPLICATION_JSON)
                        .content("{}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.matchId").exists())
                .andReturn();
        String matchId = JsonPath.read(bothReady.getResponse().getContentAsString(), "$.matchId").toString();
        return new Seats(host.token(), joiner.token(), matchId);
    }

    private String mintAccessToken() throws Exception {
        return mintGuest().token();
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

    private record Seats(String hostToken, String joinerToken, String matchId) {}
}
