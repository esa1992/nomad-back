package com.nomadgames.identity;

import static org.springframework.http.MediaType.APPLICATION_JSON;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

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

/**
 * Wave 0 Nyquist stubs for AUTH-02…04 / D-93 bind+login+logout (greens in 07-02 / 07-03).
 * Endpoints under /v1/identity/bind|login|logout are not shipped yet — expect RED.
 */
@SpringBootTest(
        classes = NomadGamesApplication.class,
        properties = {
            "nomad.jwt.secret=test-jwt-secret-that-is-32-bytes!!",
            "nomad.guest.mint-limit-per-minute=100"
        })
@AutoConfigureMockMvc
@Testcontainers
class BindIT {

    @Container
    @ServiceConnection
    static PostgreSQLContainer postgres = new PostgreSQLContainer("postgres:18");

    @Autowired
    MockMvc mockMvc;

    @Autowired
    DataSource dataSource;

    @Test
    void bindKeepsPlayerIdNoSum() throws Exception {
        // AUTH-02 / D-93: bind keeps same playerId; wallets/cosmetics unchanged
        Guest guest = mintGuest();
        MvcResult beforeWallet = mockMvc.perform(get("/v1/wallet").header("Authorization", "Bearer " + guest.token()))
                .andExpect(status().isOk())
                .andReturn();
        int coinsBefore = JsonPath.read(beforeWallet.getResponse().getContentAsString(), "$.coins");
        int gemsBefore = JsonPath.read(beforeWallet.getResponse().getContentAsString(), "$.gems");

        MvcResult bound = mockMvc.perform(post("/v1/identity/bind")
                        .header("Authorization", "Bearer " + guest.token())
                        .contentType(APPLICATION_JSON)
                        .content("{\"username\":\"nomad_bind_01\",\"password\":\"password12\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.playerId").value(guest.playerId()))
                .andExpect(jsonPath("$.guest").value(false))
                .andReturn();
        String access = JsonPath.read(bound.getResponse().getContentAsString(), "$.accessToken");

        mockMvc.perform(get("/v1/wallet").header("Authorization", "Bearer " + access))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.coins").value(coinsBefore))
                .andExpect(jsonPath("$.gems").value(gemsBefore));
    }

    @Test
    void usernameTaken409() throws Exception {
        // AUTH-02: second bind same username → 409
        Guest first = mintGuest();
        mockMvc.perform(post("/v1/identity/bind")
                        .header("Authorization", "Bearer " + first.token())
                        .contentType(APPLICATION_JSON)
                        .content("{\"username\":\"taken_user_01\",\"password\":\"password12\"}"))
                .andExpect(status().isOk());

        Guest second = mintGuest();
        mockMvc.perform(post("/v1/identity/bind")
                        .header("Authorization", "Bearer " + second.token())
                        .contentType(APPLICATION_JSON)
                        .content("{\"username\":\"taken_user_01\",\"password\":\"password12\"}"))
                .andExpect(status().isConflict());
    }

    @Test
    void usernameInvalid400() throws Exception {
        // ASVS V5: username length outside 3–20 or illegal charset → 400; password < 8 → 400
        Guest guest = mintGuest();
        mockMvc.perform(post("/v1/identity/bind")
                        .header("Authorization", "Bearer " + guest.token())
                        .contentType(APPLICATION_JSON)
                        .content("{\"username\":\"ab\",\"password\":\"password12\"}"))
                .andExpect(status().isBadRequest());

        mockMvc.perform(post("/v1/identity/bind")
                        .header("Authorization", "Bearer " + guest.token())
                        .contentType(APPLICATION_JSON)
                        .content("{\"username\":\"bad-name!\",\"password\":\"password12\"}"))
                .andExpect(status().isBadRequest());

        mockMvc.perform(post("/v1/identity/bind")
                        .header("Authorization", "Bearer " + guest.token())
                        .contentType(APPLICATION_JSON)
                        .content("{\"username\":\"valid_user\",\"password\":\"short\"}"))
                .andExpect(status().isBadRequest());
    }

    @Test
    void passwordLongerThan128Rejected400() throws Exception {
        // WR-06 / T-07-04: password max 128 on bind and login before Argon2 (DoS)
        String oversized = "a".repeat(129);
        Guest guest = mintGuest();
        mockMvc.perform(post("/v1/identity/bind")
                        .header("Authorization", "Bearer " + guest.token())
                        .contentType(APPLICATION_JSON)
                        .content("{\"username\":\"pw_max_bound\",\"password\":\"" + oversized + "\"}"))
                .andExpect(status().isBadRequest());

        mockMvc.perform(post("/v1/identity/bind")
                        .header("Authorization", "Bearer " + guest.token())
                        .contentType(APPLICATION_JSON)
                        .content("{\"username\":\"pw_max_bound\",\"password\":\"password12\"}"))
                .andExpect(status().isOk());

        mockMvc.perform(post("/v1/identity/login")
                        .contentType(APPLICATION_JSON)
                        .content("{\"username\":\"pw_max_bound\",\"password\":\"" + oversized + "\"}"))
                .andExpect(status().isBadRequest());
    }

    @Test
    void loginThenRefreshBound() throws Exception {
        // AUTH-03: login + rotate yields guest=false claim (TokenService.rotate loads PlayerEntity.isGuest)
        Guest guest = mintGuest();
        mockMvc.perform(post("/v1/identity/bind")
                        .header("Authorization", "Bearer " + guest.token())
                        .contentType(APPLICATION_JSON)
                        .content("{\"username\":\"bound_refresh\",\"password\":\"password12\"}"))
                .andExpect(status().isOk());

        MvcResult loggedIn = mockMvc.perform(post("/v1/identity/login")
                        .contentType(APPLICATION_JSON)
                        .content("{\"username\":\"bound_refresh\",\"password\":\"password12\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.guest").value(false))
                .andReturn();
        String refresh = JsonPath.read(loggedIn.getResponse().getContentAsString(), "$.refreshToken");

        mockMvc.perform(post("/v1/identity/refresh")
                        .contentType(APPLICATION_JSON)
                        .content("{\"refreshToken\":\"" + refresh + "\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.guest").value(false));
    }

    @Test
    void logoutMintsGuest() throws Exception {
        // AUTH-04 / D-95: logout revokes refresh; new guest mint; bound credential row intact
        Guest guest = mintGuest();
        MvcResult bound = mockMvc.perform(post("/v1/identity/bind")
                        .header("Authorization", "Bearer " + guest.token())
                        .contentType(APPLICATION_JSON)
                        .content("{\"username\":\"logout_user\",\"password\":\"password12\"}"))
                .andExpect(status().isOk())
                .andReturn();
        String access = JsonPath.read(bound.getResponse().getContentAsString(), "$.accessToken");
        String refresh = JsonPath.read(bound.getResponse().getContentAsString(), "$.refreshToken");

        mockMvc.perform(post("/v1/identity/logout")
                        .header("Authorization", "Bearer " + access)
                        .contentType(APPLICATION_JSON)
                        .content("{}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.guest").value(true));

        mockMvc.perform(post("/v1/identity/refresh")
                        .contentType(APPLICATION_JSON)
                        .content("{\"refreshToken\":\"" + refresh + "\"}"))
                .andExpect(status().isUnauthorized());

        mockMvc.perform(post("/v1/identity/login")
                        .contentType(APPLICATION_JSON)
                        .content("{\"username\":\"logout_user\",\"password\":\"password12\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.guest").value(false));
    }

    @Test
    void loginNeverSumsOntoNonEmptyTarget() throws Exception {
        // D-93: guest+bound both have progress; adopt=none/drop never sums wallets
        Guest boundGuest = mintGuest();
        mockMvc.perform(post("/v1/identity/bind")
                        .header("Authorization", "Bearer " + boundGuest.token())
                        .contentType(APPLICATION_JSON)
                        .content("{\"username\":\"nonsum_bound\",\"password\":\"password12\"}"))
                .andExpect(status().isOk());
        seedNonEmptyProgress(boundGuest.playerId());

        Guest deviceGuest = mintGuest();
        seedNonEmptyProgress(deviceGuest.playerId());
        MvcResult boundWallet = mockMvc.perform(get("/v1/wallet")
                        .header("Authorization", "Bearer " + loginAccess("nonsum_bound", "password12")))
                .andExpect(status().isOk())
                .andReturn();
        int coinsBefore = JsonPath.read(boundWallet.getResponse().getContentAsString(), "$.coins");

        mockMvc.perform(post("/v1/identity/login")
                        .header("Authorization", "Bearer " + deviceGuest.token())
                        .contentType(APPLICATION_JSON)
                        .content("{\"username\":\"nonsum_bound\",\"password\":\"password12\","
                                + "\"guestPlayerId\":\"" + deviceGuest.playerId() + "\",\"adopt\":\"none\"}"))
                .andExpect(status().isOk());

        mockMvc.perform(get("/v1/wallet")
                        .header("Authorization", "Bearer " + loginAccess("nonsum_bound", "password12")))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.coins").value(coinsBefore));
    }

    @Test
    void loginEmptyTargetImportsGuest() throws Exception {
        // D-93: bound matches==0 and spend==0; adopt=import copies guest progress once
        Guest boundGuest = mintGuest();
        mockMvc.perform(post("/v1/identity/bind")
                        .header("Authorization", "Bearer " + boundGuest.token())
                        .contentType(APPLICATION_JSON)
                        .content("{\"username\":\"import_bound\",\"password\":\"password12\"}"))
                .andExpect(status().isOk());

        Guest deviceGuest = mintGuest();
        seedNonEmptyProgress(deviceGuest.playerId());
        MvcResult guestWallet = mockMvc.perform(get("/v1/wallet")
                        .header("Authorization", "Bearer " + deviceGuest.token()))
                .andExpect(status().isOk())
                .andReturn();
        int guestCoins = JsonPath.read(guestWallet.getResponse().getContentAsString(), "$.coins");

        MvcResult imported = mockMvc.perform(post("/v1/identity/login")
                        .header("Authorization", "Bearer " + deviceGuest.token())
                        .contentType(APPLICATION_JSON)
                        .content("{\"username\":\"import_bound\",\"password\":\"password12\","
                                + "\"guestPlayerId\":\"" + deviceGuest.playerId() + "\",\"adopt\":\"import\"}"))
                .andExpect(status().isOk())
                .andReturn();
        String access = JsonPath.read(imported.getResponse().getContentAsString(), "$.accessToken");

        mockMvc.perform(get("/v1/wallet").header("Authorization", "Bearer " + access))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.coins").value(guestCoins));
    }

    @Test
    void loginDropGuestLeavesBoundIntact() throws Exception {
        // D-93: adopt=drop revokes guest refresh; bound balances unchanged
        Guest boundGuest = mintGuest();
        mockMvc.perform(post("/v1/identity/bind")
                        .header("Authorization", "Bearer " + boundGuest.token())
                        .contentType(APPLICATION_JSON)
                        .content("{\"username\":\"drop_bound\",\"password\":\"password12\"}"))
                .andExpect(status().isOk());
        seedNonEmptyProgress(boundGuest.playerId());
        int coinsBefore = walletCoins(loginAccess("drop_bound", "password12"));

        Guest deviceGuest = mintGuest();
        seedNonEmptyProgress(deviceGuest.playerId());
        String guestRefresh = deviceGuest.refresh();

        mockMvc.perform(post("/v1/identity/login")
                        .header("Authorization", "Bearer " + deviceGuest.token())
                        .contentType(APPLICATION_JSON)
                        .content("{\"username\":\"drop_bound\",\"password\":\"password12\","
                                + "\"guestPlayerId\":\"" + deviceGuest.playerId() + "\",\"adopt\":\"drop\"}"))
                .andExpect(status().isOk());

        mockMvc.perform(post("/v1/identity/refresh")
                        .contentType(APPLICATION_JSON)
                        .content("{\"refreshToken\":\"" + guestRefresh + "\"}"))
                .andExpect(status().isUnauthorized());

        org.junit.jupiter.api.Assertions.assertEquals(
                coinsBefore, walletCoins(loginAccess("drop_bound", "password12")));
    }

    @Test
    void loginAdoptWithoutGuestPossessionIsUnauthorized() throws Exception {
        // CR-01: guestPlayerId alone must not allow import/drop (IDOR)
        Guest boundGuest = mintGuest();
        mockMvc.perform(post("/v1/identity/bind")
                        .header("Authorization", "Bearer " + boundGuest.token())
                        .contentType(APPLICATION_JSON)
                        .content("{\"username\":\"idor_bound\",\"password\":\"password12\"}"))
                .andExpect(status().isOk());

        Guest victim = mintGuest();
        seedNonEmptyProgress(victim.playerId());

        mockMvc.perform(post("/v1/identity/login")
                        .contentType(APPLICATION_JSON)
                        .content("{\"username\":\"idor_bound\",\"password\":\"password12\","
                                + "\"guestPlayerId\":\"" + victim.playerId() + "\",\"adopt\":\"import\"}"))
                .andExpect(status().isUnauthorized());

        mockMvc.perform(post("/v1/identity/login")
                        .contentType(APPLICATION_JSON)
                        .content("{\"username\":\"idor_bound\",\"password\":\"password12\","
                                + "\"guestPlayerId\":\"" + victim.playerId() + "\",\"adopt\":\"drop\"}"))
                .andExpect(status().isUnauthorized());

        // Victim refresh still works — drop did not revoke without possession
        mockMvc.perform(post("/v1/identity/refresh")
                        .contentType(APPLICATION_JSON)
                        .content("{\"refreshToken\":\"" + victim.refresh() + "\"}"))
                .andExpect(status().isOk());
    }

    @Test
    void loginAdoptAcceptsGuestRefreshPossession() throws Exception {
        Guest boundGuest = mintGuest();
        mockMvc.perform(post("/v1/identity/bind")
                        .header("Authorization", "Bearer " + boundGuest.token())
                        .contentType(APPLICATION_JSON)
                        .content("{\"username\":\"refresh_prove\",\"password\":\"password12\"}"))
                .andExpect(status().isOk());

        Guest deviceGuest = mintGuest();
        seedNonEmptyProgress(deviceGuest.playerId());
        int guestCoins = walletCoins(deviceGuest.token());

        MvcResult imported = mockMvc.perform(post("/v1/identity/login")
                        .contentType(APPLICATION_JSON)
                        .content("{\"username\":\"refresh_prove\",\"password\":\"password12\","
                                + "\"guestPlayerId\":\"" + deviceGuest.playerId() + "\","
                                + "\"guestRefreshToken\":\"" + deviceGuest.refresh() + "\","
                                + "\"adopt\":\"import\"}"))
                .andExpect(status().isOk())
                .andReturn();
        String access = JsonPath.read(imported.getResponse().getContentAsString(), "$.accessToken");

        mockMvc.perform(get("/v1/wallet").header("Authorization", "Bearer " + access))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.coins").value(guestCoins));
    }

    private void seedNonEmptyProgress(String playerId) {
        JdbcTemplate jdbc = new JdbcTemplate(dataSource);
        jdbc.update(
                "UPDATE wallets SET balance = balance + 50 WHERE player_id = ?::uuid AND currency = 'COINS'",
                playerId);
    }

    private int walletCoins(String access) throws Exception {
        MvcResult wallet = mockMvc.perform(get("/v1/wallet").header("Authorization", "Bearer " + access))
                .andExpect(status().isOk())
                .andReturn();
        return JsonPath.read(wallet.getResponse().getContentAsString(), "$.coins");
    }

    private String loginAccess(String username, String password) throws Exception {
        MvcResult loggedIn = mockMvc.perform(post("/v1/identity/login")
                        .contentType(APPLICATION_JSON)
                        .content("{\"username\":\"" + username + "\",\"password\":\"" + password + "\"}"))
                .andExpect(status().isOk())
                .andReturn();
        return JsonPath.read(loggedIn.getResponse().getContentAsString(), "$.accessToken");
    }

    private Guest mintGuest() throws Exception {
        MvcResult minted = mockMvc.perform(post("/v1/identity/guest").contentType(APPLICATION_JSON).content("{}"))
                .andExpect(status().isCreated())
                .andReturn();
        String body = minted.getResponse().getContentAsString();
        return new Guest(
                JsonPath.read(body, "$.playerId").toString(),
                JsonPath.read(body, "$.accessToken"),
                JsonPath.read(body, "$.refreshToken"));
    }

    private record Guest(String playerId, String token, String refresh) {}
}
