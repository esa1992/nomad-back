package com.nomadgames.matchmaking;

import static org.springframework.http.MediaType.APPLICATION_JSON;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

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
import com.nomadgames.matchmaking.internal.JoinRateLimiter;

/**
 * MODE-04 Ranked queue — guest 403 + RANKED pair (D-96…D-98).
 */
@SpringBootTest(
        classes = NomadGamesApplication.class,
        properties = {
            "nomad.jwt.secret=test-jwt-secret-that-is-32-bytes!!",
            "nomad.guest.mint-limit-per-minute=100"
        })
@AutoConfigureMockMvc
@Testcontainers
class RankedQueueIT {

    @Container
    @ServiceConnection
    static PostgreSQLContainer postgres = new PostgreSQLContainer("postgres:18");

    @Autowired
    MockMvc mockMvc;

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
    void guestRejected() throws Exception {
        // MODE-04 / D-96 / D-97: guest JWT enqueue → 403
        String guest = mintAccessToken();
        mockMvc.perform(post("/v1/matchmaking/ranked")
                        .header("Authorization", "Bearer " + guest)
                        .contentType(APPLICATION_JSON)
                        .content("{\"game\":\"ALCHIKI\"}"))
                .andExpect(status().isForbidden());
    }

    @Test
    void pairCreatesRanked() throws Exception {
        // D-98: two bound players → mode=RANKED match; no bot path
        String a = bindAndAccess("ranked_pair_a");
        String b = bindAndAccess("ranked_pair_b");

        mockMvc.perform(post("/v1/matchmaking/ranked")
                        .header("Authorization", "Bearer " + a)
                        .contentType(APPLICATION_JSON)
                        .content("{\"game\":\"ALCHIKI\"}"))
                .andExpect(status().isOk());

        MvcResult second = mockMvc.perform(post("/v1/matchmaking/ranked")
                        .header("Authorization", "Bearer " + b)
                        .contentType(APPLICATION_JSON)
                        .content("{\"game\":\"ALCHIKI\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("MATCHED"))
                .andExpect(jsonPath("$.mode").value("RANKED"))
                .andExpect(jsonPath("$.matchId").exists())
                .andExpect(jsonPath("$.difficulty").doesNotExist())
                .andReturn();

        String matchId = JsonPath.read(second.getResponse().getContentAsString(), "$.matchId").toString();
        mockMvc.perform(org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get(
                                "/v1/matches/" + matchId)
                        .header("Authorization", "Bearer " + a))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.mode").value("RANKED"))
                .andExpect(jsonPath("$.difficulty").doesNotExist());
    }

    private String bindAndAccess(String username) throws Exception {
        String guest = mintAccessToken();
        MvcResult bound = mockMvc.perform(post("/v1/identity/bind")
                        .header("Authorization", "Bearer " + guest)
                        .contentType(APPLICATION_JSON)
                        .content("{\"username\":\"" + username + "\",\"password\":\"password12\"}"))
                .andExpect(status().isOk())
                .andReturn();
        return JsonPath.read(bound.getResponse().getContentAsString(), "$.accessToken");
    }

    private String mintAccessToken() throws Exception {
        MvcResult minted = mockMvc.perform(post("/v1/identity/guest").contentType(APPLICATION_JSON).content("{}"))
                .andExpect(status().isCreated())
                .andReturn();
        return JsonPath.read(minted.getResponse().getContentAsString(), "$.accessToken");
    }
}
