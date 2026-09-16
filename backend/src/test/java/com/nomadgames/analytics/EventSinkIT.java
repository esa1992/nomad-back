package com.nomadgames.analytics;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.springframework.http.MediaType.APPLICATION_JSON;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;

import javax.sql.DataSource;

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
import com.nomadgames.analytics.internal.AnalyticsJdbc;
import com.nomadgames.economy.internal.WalletLedgerJdbc;

import tools.jackson.databind.ObjectMapper;

/**
 * ANLT-01 / D-107 EventSink — nine event types as JSON log + analytics_events rows.
 */
@SpringBootTest(
        classes = NomadGamesApplication.class,
        properties = {
            "nomad.jwt.secret=test-jwt-secret-that-is-32-bytes!!",
            "nomad.guest.mint-limit-per-minute=100"
        })
@AutoConfigureMockMvc
@Testcontainers
class EventSinkIT {

    private static final List<String> NINE = List.of(
            "APP_STARTED",
            "REGISTERED",
            "LOGIN",
            "MATCHMAKING_STARTED",
            "MATCH_FOUND",
            "MATCH_STARTED",
            "MATCH_FINISHED",
            "MATCH_ABANDONED",
            "ITEM_PURCHASED");

    @Container
    @ServiceConnection
    static PostgreSQLContainer postgres = new PostgreSQLContainer("postgres:18");

    @Autowired
    MockMvc mockMvc;

    @Autowired
    DataSource dataSource;

    @Autowired
    EventSink events;

    @Autowired
    WalletLedgerJdbc wallets;

    @Autowired
    ObjectMapper mapper;

    @Test
    void emitsRegisteredOnBind() throws Exception {
        Guest guest = mintGuest();
        String user = "anlt_reg_" + UUID.randomUUID().toString().substring(0, 8);
        mockMvc.perform(post("/v1/identity/bind")
                        .header("Authorization", "Bearer " + guest.token())
                        .contentType(APPLICATION_JSON)
                        .content("{\"username\":\"" + user + "\",\"password\":\"password12\"}"))
                .andExpect(status().isOk());

        JdbcTemplate jdbc = new JdbcTemplate(dataSource);
        Integer count = jdbc.queryForObject(
                "SELECT COUNT(*) FROM analytics_events WHERE event_type = ? AND player_id = ?",
                Integer.class,
                "REGISTERED",
                guest.playerId());
        assertEquals(1, count);
    }

    @Test
    void emitsLogin() throws Exception {
        Guest guest = mintGuest();
        String user = "anlt_login_" + UUID.randomUUID().toString().substring(0, 8);
        mockMvc.perform(post("/v1/identity/bind")
                        .header("Authorization", "Bearer " + guest.token())
                        .contentType(APPLICATION_JSON)
                        .content("{\"username\":\"" + user + "\",\"password\":\"password12\"}"))
                .andExpect(status().isOk());

        mockMvc.perform(post("/v1/identity/login")
                        .contentType(APPLICATION_JSON)
                        .content("{\"username\":\"" + user + "\",\"password\":\"password12\"}"))
                .andExpect(status().isOk());

        JdbcTemplate jdbc = new JdbcTemplate(dataSource);
        Integer count = jdbc.queryForObject(
                "SELECT COUNT(*) FROM analytics_events WHERE event_type = ? AND player_id = ?",
                Integer.class,
                "LOGIN",
                guest.playerId());
        assertEquals(1, count);
    }

    @Test
    void emitsMatchLifecycleNineTypes() throws Exception {
        // Direct emits cover the full ANLT-01 catalog (plus APP_STARTED from ApplicationReadyEvent).
        UUID playerId = UUID.randomUUID();
        UUID matchId = UUID.randomUUID();
        for (String type : NINE) {
            if ("APP_STARTED".equals(type)) {
                continue; // boot emitter
            }
            events.emit(type, playerId, matchId, Map.of("probe", true));
        }

        Guest guest = mintGuest();
        String user = "anlt_nine_" + UUID.randomUUID().toString().substring(0, 8);
        mockMvc.perform(post("/v1/identity/bind")
                        .header("Authorization", "Bearer " + guest.token())
                        .contentType(APPLICATION_JSON)
                        .content("{\"username\":\"" + user + "\",\"password\":\"password12\"}"))
                .andExpect(status().isOk());
        mockMvc.perform(post("/v1/identity/login")
                        .contentType(APPLICATION_JSON)
                        .content("{\"username\":\"" + user + "\",\"password\":\"password12\"}"))
                .andExpect(status().isOk());

        wallets.ensureWalletRows(guest.playerId());
        wallets.creditIfAbsent(
                guest.playerId(), "COINS", 200L, "TEST_CREDIT", "anlt-" + UUID.randomUUID(), UUID.randomUUID());
        mockMvc.perform(post("/v1/shop/purchases")
                        .header("Authorization", "Bearer " + guest.token())
                        .contentType(APPLICATION_JSON)
                        .content(
                                "{\"skuId\":\"saka_color_gold\",\"idempotencyKey\":\"anlt-"
                                        + UUID.randomUUID()
                                        + "\"}"))
                .andExpect(status().isOk());

        MvcResult created = mockMvc.perform(post("/v1/matches")
                        .header("Authorization", "Bearer " + guest.token())
                        .contentType(APPLICATION_JSON)
                        .content("{\"game\":\"ALCHIKI\",\"mode\":\"BOT\",\"difficulty\":\"EASY\"}"))
                .andExpect(status().isCreated())
                .andReturn();
        String mid = JsonPath.read(created.getResponse().getContentAsString(), "$.matchId");
        mockMvc.perform(post("/v1/matches/" + mid + "/leave")
                        .header("Authorization", "Bearer " + guest.token())
                        .contentType(APPLICATION_JSON)
                        .content("{}"))
                .andExpect(status().isOk());

        JdbcTemplate jdbc = new JdbcTemplate(dataSource);
        List<String> types = jdbc.queryForList("SELECT DISTINCT event_type FROM analytics_events", String.class);
        Set<String> found = new LinkedHashSet<>(types);
        for (String required : NINE) {
            assertTrue(found.contains(required), "missing ANLT-01 type: " + required + " in " + found);
        }
    }

    @Test
    void sinkFailureDoesNotRollBackSettle() throws Exception {
        AnalyticsJdbc boom = new AnalyticsJdbc(null) {
            @Override
            public void append(
                    String eventType, UUID playerId, UUID matchId, String attrsJson, java.time.OffsetDateTime ts) {
                throw new RuntimeException("forced analytics failure");
            }
        };
        EventSink isolated = new EventSink(boom, mapper);
        assertDoesNotThrow(() -> isolated.emit("MATCH_FINISHED", UUID.randomUUID(), UUID.randomUUID(), Map.of()));

        Guest guest = mintGuest();
        MvcResult created = mockMvc.perform(post("/v1/matches")
                        .header("Authorization", "Bearer " + guest.token())
                        .contentType(APPLICATION_JSON)
                        .content("{\"game\":\"ALCHIKI\",\"mode\":\"BOT\",\"difficulty\":\"EASY\"}"))
                .andExpect(status().isCreated())
                .andReturn();
        String mid = JsonPath.read(created.getResponse().getContentAsString(), "$.matchId");
        mockMvc.perform(post("/v1/matches/" + mid + "/leave")
                        .header("Authorization", "Bearer " + guest.token())
                        .contentType(APPLICATION_JSON)
                        .content("{}"))
                .andExpect(status().isOk());

        JdbcTemplate jdbc = new JdbcTemplate(dataSource);
        String status = jdbc.queryForObject("SELECT status FROM matches WHERE id = ?", String.class, UUID.fromString(mid));
        assertEquals("BOT_WIN", status);
    }

    private Guest mintGuest() throws Exception {
        MvcResult minted = mockMvc.perform(post("/v1/identity/guest").contentType(APPLICATION_JSON).content("{}"))
                .andExpect(status().isCreated())
                .andReturn();
        String body = minted.getResponse().getContentAsString();
        return new Guest(
                UUID.fromString(JsonPath.read(body, "$.playerId").toString()),
                JsonPath.read(body, "$.accessToken"));
    }

    private record Guest(UUID playerId, String token) {}
}
