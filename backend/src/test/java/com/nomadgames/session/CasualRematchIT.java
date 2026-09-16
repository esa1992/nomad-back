package com.nomadgames.session;

import static org.hamcrest.Matchers.not;
import static org.hamcrest.Matchers.nullValue;
import static org.springframework.http.MediaType.APPLICATION_JSON;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

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

/**
 * Wave 0 Nyquist stubs for MODE-05 CASUAL rematch (greens in 05-05 after createCasualMatch in 05-02).
 */
@SpringBootTest(
        classes = NomadGamesApplication.class,
        properties = "nomad.jwt.secret=test-jwt-secret-that-is-32-bytes!!")
@AutoConfigureMockMvc
@Testcontainers
class CasualRematchIT {

    @Container
    @ServiceConnection
    static PostgreSQLContainer postgres = new PostgreSQLContainer("postgres:18");

    @Autowired
    MockMvc mockMvc;

    @Test
    void casualRematchCreatesCasualMatch() throws Exception {
        StartedCasualMatch finished = finishCasualViaLeave();

        mockMvc.perform(post("/v1/matches/" + finished.matchId() + "/rematch")
                        .header("Authorization", "Bearer " + finished.hostToken())
                        .contentType(APPLICATION_JSON)
                        .content("{\"accept\":true}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.accepted").value(true))
                .andExpect(jsonPath("$.matchId").value(nullValue()));

        MvcResult second = mockMvc.perform(post("/v1/matches/" + finished.matchId() + "/rematch")
                        .header("Authorization", "Bearer " + finished.joinerToken())
                        .contentType(APPLICATION_JSON)
                        .content("{\"accept\":true}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.accepted").value(true))
                .andExpect(jsonPath("$.matchId").value(not(finished.matchId())))
                .andReturn();
        String newMatchId = JsonPath.read(second.getResponse().getContentAsString(), "$.matchId").toString();

        mockMvc.perform(get("/v1/matches/" + newMatchId).header("Authorization", "Bearer " + finished.hostToken()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.mode").value("CASUAL"))
                .andExpect(jsonPath("$.hostId").value(finished.hostId()))
                .andExpect(jsonPath("$.joinerId").value(finished.joinerId()));
    }

    @Test
    void casualRematchRequiresSeat() throws Exception {
        StartedCasualMatch finished = finishCasualViaLeave();
        String third = mintAccessToken();

        mockMvc.perform(post("/v1/matches/" + finished.matchId() + "/rematch")
                        .header("Authorization", "Bearer " + third)
                        .contentType(APPLICATION_JSON)
                        .content("{\"accept\":true}"))
                .andExpect(status().isForbidden());
    }

    /** Pair via casual queue then leave — RED until /v1/matchmaking/casual + createCasualMatch exist. */
    private StartedCasualMatch finishCasualViaLeave() throws Exception {
        Guest host = mintGuest();
        Guest joiner = mintGuest();

        mockMvc.perform(post("/v1/matchmaking/casual")
                        .header("Authorization", "Bearer " + host.token())
                        .contentType(APPLICATION_JSON)
                        .content("{}"))
                .andExpect(status().isOk());

        MvcResult paired = mockMvc.perform(post("/v1/matchmaking/casual")
                        .header("Authorization", "Bearer " + joiner.token())
                        .contentType(APPLICATION_JSON)
                        .content("{}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("MATCHED"))
                .andExpect(jsonPath("$.matchId").exists())
                .andReturn();
        String matchId = JsonPath.read(paired.getResponse().getContentAsString(), "$.matchId").toString();

        mockMvc.perform(get("/v1/matches/" + matchId).header("Authorization", "Bearer " + host.token()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.mode").value("CASUAL"));

        mockMvc.perform(post("/v1/matches/" + matchId + "/leave")
                        .header("Authorization", "Bearer " + joiner.token()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.match.status").value("HOST_WIN"));

        return new StartedCasualMatch(matchId, host.token(), joiner.token(), host.playerId(), joiner.playerId());
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

    private record StartedCasualMatch(
            String matchId, String hostToken, String joinerToken, String hostId, String joinerId) {}
}
