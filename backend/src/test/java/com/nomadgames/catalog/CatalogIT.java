package com.nomadgames.catalog;

import static org.springframework.http.MediaType.APPLICATION_JSON;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.hamcrest.Matchers;
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
class CatalogIT {

    @Container
    @ServiceConnection
    static PostgreSQLContainer postgres = new PostgreSQLContainer("postgres:18");

    @Autowired
    MockMvc mockMvc;

    @Test
    void catalogWithoutBearerIsUnauthorized() throws Exception {
        mockMvc.perform(get("/v1/catalog")).andExpect(status().isUnauthorized());
    }

    @Test
    void catalogWithGuestAccessReturnsAlchikiPlayable() throws Exception {
        String access = mintAccessToken();

        mockMvc.perform(get("/v1/catalog").header("Authorization", "Bearer " + access))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.tiles").isArray())
                .andExpect(jsonPath("$.tiles[?(@.id=='alchiki')].status").value(Matchers.hasItem("PLAYABLE")));
    }

    @Test
    void stickPullTileIsPlayable() throws Exception {
        // CAT-02 — Wave 0 RED until catalog flips stick_pull to PLAYABLE (06-02)
        String access = mintAccessToken();

        mockMvc.perform(get("/v1/catalog").header("Authorization", "Bearer " + access))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.tiles[?(@.id=='stick_pull')].status").value(Matchers.hasItem("PLAYABLE")));
    }

    @Test
    void catalogComingSoonTileIsMoreGames() throws Exception {
        String access = mintAccessToken();

        mockMvc.perform(get("/v1/catalog").header("Authorization", "Bearer " + access))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.tiles[?(@.id=='more_games')].status").value(Matchers.hasItem("COMING_SOON")));
    }

    private String mintAccessToken() throws Exception {
        MvcResult minted = mockMvc.perform(post("/v1/identity/guest").contentType(APPLICATION_JSON).content("{}"))
                .andExpect(status().isCreated())
                .andReturn();
        return JsonPath.read(minted.getResponse().getContentAsString(), "$.accessToken");
    }
}
