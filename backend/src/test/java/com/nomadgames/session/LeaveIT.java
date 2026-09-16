package com.nomadgames.session;

import static org.springframework.http.MediaType.APPLICATION_JSON;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
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

@SpringBootTest(
        classes = NomadGamesApplication.class,
        properties = "nomad.jwt.secret=test-jwt-secret-that-is-32-bytes!!")
@AutoConfigureMockMvc
@Testcontainers
class LeaveIT {

    @Container
    @ServiceConnection
    static PostgreSQLContainer postgres = new PostgreSQLContainer("postgres:18");

    @Autowired
    MockMvc mockMvc;

    @Autowired
    DataSource dataSource;

    @Test
    void privateLeaveOpponentWins() throws Exception {
        StartedPrivateMatch started = startPrivateMatch();

        mockMvc.perform(post("/v1/matches/" + started.matchId + "/leave")
                        .header("Authorization", "Bearer " + started.joinerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.match.status").value("HOST_WIN"))
                .andExpect(jsonPath("$.match.status").value(Matchers.not("BOT_WIN")));
    }

    @Test
    void privateLeaveWhenAlreadyHostWinPreserves() throws Exception {
        StartedPrivateMatch started = startPrivateMatch();
        setMatchStatus(started.matchId, "HOST_WIN");

        mockMvc.perform(post("/v1/matches/" + started.matchId + "/leave")
                        .header("Authorization", "Bearer " + started.joinerToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.match.status").value("HOST_WIN"));
    }

    private StartedPrivateMatch startPrivateMatch() throws Exception {
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
        return new StartedPrivateMatch(matchId, hostToken, joinerToken);
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

    private record StartedPrivateMatch(String matchId, String hostToken, String joinerToken) {}
}
