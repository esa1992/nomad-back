package com.nomadgames.session;

import static org.springframework.http.MediaType.APPLICATION_JSON;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.util.List;
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

@SpringBootTest(
        classes = NomadGamesApplication.class,
        properties = "nomad.jwt.secret=test-jwt-secret-that-is-32-bytes!!")
@AutoConfigureMockMvc
@Testcontainers
class ThrowAuthorityIT {

    /** Same canned throw BurstSimTest.cannedThrowPocketsAtLeastOneEasyBone proves. */
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

    @Container
    @ServiceConnection
    static PostgreSQLContainer postgres = new PostgreSQLContainer("postgres:18");

    @Autowired
    MockMvc mockMvc;

    @Autowired
    DataSource dataSource;

    @Test
    void forgedClientScoreIsIgnoredOnThrow() throws Exception {
        String token = mintAccessToken();
        String matchId = createMatch(token, "EASY");

        String forged = POCKETING_THROW.replaceFirst("\\}\\s*$", "")
                + """
                  ,
                  "pocketedCount": 99,
                  "score": 99,
                  "displayedScore": 99,
                  "winner": "BOT"
                  }
                  """;

        MvcResult thrown = mockMvc.perform(post("/v1/matches/" + matchId + "/throws")
                        .header("Authorization", "Bearer " + token)
                        .contentType(APPLICATION_JSON)
                        .content(forged))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.playerThrow.displayedScore").exists())
                .andExpect(jsonPath("$.playerThrow.displayedScore").value(Matchers.not(99)))
                .andExpect(jsonPath("$.winner").doesNotExist())
                .andExpect(jsonPath("$.score").doesNotExist())
                .andReturn();

        String body = thrown.getResponse().getContentAsString();
        Number displayed = JsonPath.read(body, "$.playerThrow.displayedScore");
        if (displayed.intValue() == 99) {
            throw new AssertionError("displayedScore must come from dyn4j, not the request");
        }
    }

    @Test
    void boneCountFollowsDifficulty() throws Exception {
        String token = mintAccessToken();
        assertBoneCount(createMatchBody(token, "EASY"), 5);
        assertBoneCount(createMatchBody(token, "NORMAL"), 6);
        assertBoneCount(createMatchBody(token, "HARD"), 7);
    }

    @Test
    void secondThrowOmitsPocketedIdFromScoreAndKeyframes() throws Exception {
        String token = mintAccessToken();
        String matchId = createMatch(token, "EASY");

        MvcResult first = mockMvc.perform(post("/v1/matches/" + matchId + "/throws")
                        .header("Authorization", "Bearer " + token)
                        .contentType(APPLICATION_JSON)
                        .content(POCKETING_THROW))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.playerThrow.pocketedIds").isArray())
                .andReturn();

        List<String> pocketed = JsonPath.read(first.getResponse().getContentAsString(), "$.playerThrow.pocketedIds");
        if (pocketed == null || pocketed.isEmpty()) {
            throw new AssertionError("throw1 must pocket at least one id");
        }
        String pocketedId = pocketed.get(0);

        MvcResult second = mockMvc.perform(post("/v1/matches/" + matchId + "/throws")
                        .header("Authorization", "Bearer " + token)
                        .contentType(APPLICATION_JSON)
                        .content(POCKETING_THROW))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.playerThrow.pocketedIds", Matchers.not(Matchers.hasItem(pocketedId))))
                .andExpect(jsonPath("$.match.bonesLeft", Matchers.not(Matchers.hasItem(pocketedId))))
                .andReturn();

        String body = second.getResponse().getContentAsString();
        List<String> secondPockets = JsonPath.read(body, "$.playerThrow.pocketedIds");
        if (secondPockets.contains(pocketedId)) {
            throw new AssertionError("throw2 must not re-pocket " + pocketedId);
        }
        List<String> bonesLeft = JsonPath.read(body, "$.match.bonesLeft");
        if (bonesLeft.contains(pocketedId)) {
            throw new AssertionError("bonesLeft must omit " + pocketedId);
        }
        List<String> frameIds = JsonPath.read(body, "$.playerThrow.keyframes[*].bodies[*].id");
        if (frameIds.contains(pocketedId)) {
            throw new AssertionError("throw2 keyframes must omit " + pocketedId);
        }
    }

    @Test
    void expiredTurnPostReturnsDisplayedScoreZeroWithoutImpulse() throws Exception {
        String token = mintAccessToken();
        String matchId = createMatch(token, "EASY");
        expireTurnDeadline(matchId);

        mockMvc.perform(post("/v1/matches/" + matchId + "/throws")
                        .header("Authorization", "Bearer " + token)
                        .contentType(APPLICATION_JSON)
                        .content("{}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.playerThrow.displayedScore").value(0))
                .andExpect(jsonPath("$.match.playerTurns").value(1));
    }

    @Test
    void getAfterTurnDeadlineAppliesTickClocksForfeit() throws Exception {
        String token = mintAccessToken();
        String matchId = createMatch(token, "EASY");
        expireTurnDeadline(matchId);

        mockMvc.perform(get("/v1/matches/" + matchId).header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.playerTurns").value(1))
                .andExpect(jsonPath("$.playerScore").value(0))
                .andExpect(jsonPath("$.status").value("IN_PLAY"));
    }

    @Test
    void getThenPostSameDeadlineDoesNotIncrementPlayerTurnsTwice() throws Exception {
        String token = mintAccessToken();
        String matchId = createMatch(token, "EASY");
        expireTurnDeadline(matchId);

        mockMvc.perform(get("/v1/matches/" + matchId).header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.playerTurns").value(1));

        mockMvc.perform(post("/v1/matches/" + matchId + "/throws")
                        .header("Authorization", "Bearer " + token)
                        .contentType(APPLICATION_JSON)
                        .content("{}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.match.playerTurns").value(1))
                .andExpect(jsonPath("$.playerThrow.displayedScore").value(0));
    }

    @Test
    void nonTerminalPlayerThrowIncludesBotThrowAndIgnoresForgedBotScore() throws Exception {
        String token = mintAccessToken();
        String matchId = createMatch(token, "EASY");

        String forged = POCKETING_THROW.replaceFirst("\\}\\s*$", "")
                + """
                  ,
                  "botScore": 99,
                  "botThrow": { "displayedScore": 99 }
                  }
                  """;

        MvcResult thrown = mockMvc.perform(post("/v1/matches/" + matchId + "/throws")
                        .header("Authorization", "Bearer " + token)
                        .contentType(APPLICATION_JSON)
                        .content(forged))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.botThrow.input.aimAngleRad").exists())
                .andExpect(jsonPath("$.botThrow.keyframes").isArray())
                .andExpect(jsonPath("$.match.botScore").value(Matchers.not(99)))
                .andReturn();

        String body = thrown.getResponse().getContentAsString();
        Number botScore = JsonPath.read(body, "$.match.botScore");
        if (botScore.intValue() == 99) {
            throw new AssertionError("forged botScore must not change match.botScore");
        }
    }

    @Test
    void botThrowOmitsIdsPocketedByPlayer() throws Exception {
        String token = mintAccessToken();
        String matchId = createMatch(token, "EASY");

        MvcResult first = mockMvc.perform(post("/v1/matches/" + matchId + "/throws")
                        .header("Authorization", "Bearer " + token)
                        .contentType(APPLICATION_JSON)
                        .content(POCKETING_THROW))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.playerThrow.pocketedIds").isArray())
                .andExpect(jsonPath("$.botThrow.keyframes").isArray())
                .andReturn();

        String body = first.getResponse().getContentAsString();
        List<String> pocketed = JsonPath.read(body, "$.playerThrow.pocketedIds");
        if (pocketed == null || pocketed.isEmpty()) {
            throw new AssertionError("throw1 must pocket at least one id");
        }
        String pocketedId = pocketed.get(0);
        List<String> botPockets = JsonPath.read(body, "$.botThrow.pocketedIds");
        if (botPockets != null && botPockets.contains(pocketedId)) {
            throw new AssertionError("botThrow.pocketedIds must omit " + pocketedId);
        }
        List<String> bonesLeft = JsonPath.read(body, "$.match.bonesLeft");
        if (bonesLeft.contains(pocketedId)) {
            throw new AssertionError("match.bonesLeft must omit " + pocketedId);
        }
        List<String> frameIds = JsonPath.read(body, "$.botThrow.keyframes[*].bodies[*].id");
        if (frameIds.contains(pocketedId)) {
            throw new AssertionError("botThrow keyframes must omit " + pocketedId);
        }
    }

    @Test
    void forfeitThenBotThenDuplicatePostDoesNotAttachSecondBotThrow() throws Exception {
        String token = mintAccessToken();
        String matchId = createMatch(token, "EASY");
        expireTurnDeadline(matchId);

        MvcResult forfeited = mockMvc.perform(post("/v1/matches/" + matchId + "/throws")
                        .header("Authorization", "Bearer " + token)
                        .contentType(APPLICATION_JSON)
                        .content("{}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.match.playerTurns").value(1))
                .andExpect(jsonPath("$.match.status").value("IN_PLAY"))
                .andExpect(jsonPath("$.botThrow.input.aimAngleRad").exists())
                .andReturn();

        Object firstBot = JsonPath.read(forfeited.getResponse().getContentAsString(), "$.botThrow");
        if (firstBot == null) {
            throw new AssertionError("forfeit while IN_PLAY must attach botThrow");
        }

        MvcResult duplicate = mockMvc.perform(post("/v1/matches/" + matchId + "/throws")
                        .header("Authorization", "Bearer " + token)
                        .contentType(APPLICATION_JSON)
                        .content("{}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.match.playerTurns").value(1))
                .andReturn();

        String dupBody = duplicate.getResponse().getContentAsString();
        Object secondBot;
        try {
            secondBot = JsonPath.read(dupBody, "$.botThrow");
        } catch (RuntimeException missing) {
            secondBot = null;
        }
        if (secondBot != null) {
            throw new AssertionError("duplicate auto-POST must not attach a second botThrow");
        }
    }

    @Test
    void leaveMatchReturnsBotWin() throws Exception {
        String token = mintAccessToken();
        String matchId = createMatch(token, "EASY");

        mockMvc.perform(post("/v1/matches/" + matchId + "/leave")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.match.status").value("BOT_WIN"));
    }

    @Test
    void leaveAfterPlayerWinPreservesPlayerWin() throws Exception {
        String token = mintAccessToken();
        String matchId = createMatch(token, "EASY");
        setMatchStatus(matchId, "PLAYER_WIN");

        mockMvc.perform(post("/v1/matches/" + matchId + "/leave")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.match.status").value("PLAYER_WIN"));
    }

    @Test
    void leaveAfterDrawPreservesDraw() throws Exception {
        String token = mintAccessToken();
        String matchId = createMatch(token, "EASY");
        setMatchStatus(matchId, "DRAW");

        mockMvc.perform(post("/v1/matches/" + matchId + "/leave")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.match.status").value("DRAW"));
    }

    private void expireTurnDeadline(String matchId) {
        new JdbcTemplate(dataSource)
                .update(
                        "UPDATE matches SET turn_deadline = now() - interval '1 second' WHERE id = ?",
                        UUID.fromString(matchId));
    }

    private void setMatchStatus(String matchId, String status) {
        new JdbcTemplate(dataSource)
                .update(
                        "UPDATE matches SET status = ? WHERE id = ?",
                        status,
                        UUID.fromString(matchId));
    }

    private String mintAccessToken() throws Exception {
        MvcResult minted = mockMvc.perform(post("/v1/identity/guest").contentType(APPLICATION_JSON).content("{}"))
                .andExpect(status().isCreated())
                .andReturn();
        return JsonPath.read(minted.getResponse().getContentAsString(), "$.accessToken");
    }

    private String createMatch(String token, String difficulty) throws Exception {
        return JsonPath.read(createMatchBody(token, difficulty), "$.matchId");
    }

    private String createMatchBody(String token, String difficulty) throws Exception {
        MvcResult created = mockMvc.perform(post("/v1/matches")
                        .header("Authorization", "Bearer " + token)
                        .contentType(APPLICATION_JSON)
                        .content("{\"game\":\"ALCHIKI\",\"mode\":\"BOT\",\"difficulty\":\"" + difficulty + "\"}"))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.status").value("IN_PLAY"))
                .andExpect(jsonPath("$.difficulty").value(difficulty))
                .andExpect(jsonPath("$.playerScore").value(0))
                .andExpect(jsonPath("$.botScore").value(0))
                .andExpect(jsonPath("$.turn").value("PLAYER"))
                .andReturn();
        return created.getResponse().getContentAsString();
    }

    private static void assertBoneCount(String body, int expected) {
        List<String> boneIds = JsonPath.read(body, "$.boneIds");
        if (boneIds.size() != expected) {
            throw new AssertionError("expected " + expected + " bones, got " + boneIds.size());
        }
    }
}
