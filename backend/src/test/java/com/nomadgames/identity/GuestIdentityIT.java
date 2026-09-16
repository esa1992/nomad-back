package com.nomadgames.identity;

import static org.springframework.http.MediaType.APPLICATION_JSON;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.util.UUID;

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

@SpringBootTest(
        classes = NomadGamesApplication.class,
        properties = "nomad.jwt.secret=test-jwt-secret-that-is-32-bytes!!")
@AutoConfigureMockMvc
@Testcontainers
class GuestIdentityIT {

    @Container
    @ServiceConnection
    static PostgreSQLContainer postgres = new PostgreSQLContainer("postgres:18");

    @Autowired
    MockMvc mockMvc;

    @Test
    void guestMintReturnsTokensWithoutUsername() throws Exception {
        MvcResult minted = mockMvc.perform(post("/v1/identity/guest").contentType(APPLICATION_JSON).content("{}"))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.playerId").isString())
                .andExpect(jsonPath("$.accessToken").isNotEmpty())
                .andExpect(jsonPath("$.refreshToken").isNotEmpty())
                .andExpect(jsonPath("$.guest").value(true))
                .andExpect(jsonPath("$.username").doesNotExist())
                .andReturn();

        UUID.fromString(JsonPath.read(minted.getResponse().getContentAsString(), "$.playerId"));
    }

    @Test
    void refreshRotatesAndRejectsReplay() throws Exception {
        MvcResult minted = mockMvc.perform(post("/v1/identity/guest").contentType(APPLICATION_JSON).content("{}"))
                .andExpect(status().isCreated())
                .andReturn();
        String firstRefresh = JsonPath.read(minted.getResponse().getContentAsString(), "$.refreshToken");

        MvcResult rotated = mockMvc.perform(post("/v1/identity/refresh")
                        .contentType(APPLICATION_JSON)
                        .content("{\"refreshToken\":\"" + firstRefresh + "\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.accessToken").isNotEmpty())
                .andExpect(jsonPath("$.refreshToken").isNotEmpty())
                .andReturn();
        String secondRefresh = JsonPath.read(rotated.getResponse().getContentAsString(), "$.refreshToken");
        if (firstRefresh.equals(secondRefresh)) {
            throw new AssertionError("refresh token must rotate");
        }

        mockMvc.perform(post("/v1/identity/refresh")
                        .contentType(APPLICATION_JSON)
                        .content("{\"refreshToken\":\"" + firstRefresh + "\"}"))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void guestMintIgnoresForgedExtraKeys() throws Exception {
        mockMvc.perform(post("/v1/identity/guest")
                        .contentType(APPLICATION_JSON)
                        .content(
                                "{\"deviceId\":\"forged-ad-id\",\"username\":\"hacker\",\"guest\":false,\"playerId\":\"00000000-0000-0000-0000-000000000001\"}"))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.guest").value(true))
                .andExpect(jsonPath("$.username").doesNotExist())
                .andExpect(jsonPath("$.playerId").value(org.hamcrest.Matchers.not("00000000-0000-0000-0000-000000000001")));
    }

    @Test
    void actuatorHealthIsReachableWithoutBearer() throws Exception {
        mockMvc.perform(get("/actuator/health")).andExpect(status().isOk());
    }
}
