package com.nomadgames.economy;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.springframework.http.MediaType.APPLICATION_JSON;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.time.Instant;
import java.util.UUID;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.atomic.AtomicReference;

import javax.sql.DataSource;

import org.hamcrest.Matchers;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;
import org.springframework.web.server.ResponseStatusException;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.postgresql.PostgreSQLContainer;

import com.jayway.jsonpath.JsonPath;
import com.nomadgames.NomadGamesApplication;
import com.nomadgames.economy.internal.WalletLedgerJdbc;
import com.nomadgames.session.MatchService;
import com.nomadgames.session.internal.MatchSessionRegistry;
import com.nomadgames.session.internal.MatchSessionRegistry.LiveMatch;

@SpringBootTest(
        classes = NomadGamesApplication.class,
        properties = "nomad.jwt.secret=test-jwt-secret-that-is-32-bytes!!")
@AutoConfigureMockMvc
@Testcontainers
class EconomyIT {

    @Container
    @ServiceConnection
    static PostgreSQLContainer postgres = new PostgreSQLContainer("postgres:18");

    @Autowired
    MockMvc mockMvc;

    @Autowired
    DataSource dataSource;

    @Autowired
    MatchService matchService;

    @Autowired
    MatchSessionRegistry sessions;

    @Autowired
    WalletLedgerJdbc wallets;

    @Autowired
    EconomyService economy;

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

    @Test
    void matchGrantIdempotent() throws Exception {
        String access = mintAccessToken();
        String matchId = createBotMatch(access, "EASY");

        new JdbcTemplate(dataSource)
                .update(
                        "UPDATE matches SET player_score = 5 WHERE id = ?",
                        UUID.fromString(matchId));

        MvcResult settled = mockMvc.perform(post("/v1/matches/" + matchId + "/throws")
                        .header("Authorization", "Bearer " + access)
                        .contentType(APPLICATION_JSON)
                        .content(POCKETING_THROW))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.match.status").value("PLAYER_WIN"))
                .andExpect(jsonPath("$.match.coinsGranted").value(Matchers.greaterThan(0)))
                .andReturn();

        int coinsGranted = JsonPath.read(settled.getResponse().getContentAsString(), "$.match.coinsGranted");
        assertTrue(coinsGranted > 0, "win path must grant COINS");

        MvcResult walletAfter = mockMvc.perform(get("/v1/wallet").header("Authorization", "Bearer " + access))
                .andExpect(status().isOk())
                .andReturn();
        int coinsAfterFirst = JsonPath.read(walletAfter.getResponse().getContentAsString(), "$.coins");

        // Replay leave on terminal match must not double-credit (idempotent MATCH_REWARD key).
        mockMvc.perform(post("/v1/matches/" + matchId + "/leave")
                        .header("Authorization", "Bearer " + access))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.match.coinsGranted").value(coinsGranted));

        mockMvc.perform(get("/v1/wallet").header("Authorization", "Bearer " + access))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.coins").value(coinsAfterFirst));
    }

    @Test
    void leaveAndDropGrant() throws Exception {
        String leaveAccess = mintAccessToken();
        String leaveMatchId = createBotMatch(leaveAccess, "EASY");

        mockMvc.perform(post("/v1/matches/" + leaveMatchId + "/leave")
                        .header("Authorization", "Bearer " + leaveAccess))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.match.status").value("BOT_WIN"))
                .andExpect(jsonPath("$.match.coinsGranted").value(Matchers.greaterThan(0)));

        Seats seats = bothReadyPrivate();
        MvcResult snap = mockMvc.perform(get("/v1/matches/" + seats.matchId())
                        .header("Authorization", "Bearer " + seats.hostToken()))
                .andExpect(status().isOk())
                .andReturn();
        String joinerId = JsonPath.read(snap.getResponse().getContentAsString(), "$.joinerId").toString();

        matchService.markDropped(UUID.fromString(joinerId), UUID.fromString(seats.matchId()));
        LiveMatch live = sessions.live(UUID.fromString(seats.matchId()));
        assertTrue(live != null && live.joinerDropped(), "joiner must be in reconnect grace");
        live.joinerGraceDeadline = Instant.now().minusSeconds(1);
        matchService.expireReconnectGraces();

        mockMvc.perform(get("/v1/matches/" + seats.matchId())
                        .header("Authorization", "Bearer " + seats.hostToken()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("HOST_WIN"))
                .andExpect(jsonPath("$.coinsGranted").value(Matchers.greaterThan(0)));
    }

    @Test
    void walletReturnsZeroBalances() throws Exception {
        String access = mintAccessToken();

        mockMvc.perform(get("/v1/wallet").header("Authorization", "Bearer " + access))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.coins").value(0))
                .andExpect(jsonPath("$.gems").value(0));
    }

    @Test
    void walletWithoutBearerIsUnauthorized() throws Exception {
        mockMvc.perform(get("/v1/wallet")).andExpect(status().isUnauthorized());
    }

    @Test
    void purchasesTableUnique() {
        JdbcTemplate jdbc = new JdbcTemplate(dataSource);

        Integer seedRows = jdbc.queryForObject("SELECT COUNT(*) FROM purchases", Integer.class);
        assertEquals(0, seedRows, "purchases must ship empty (ECON-05 / D-60)");

        jdbc.update(
                "INSERT INTO purchases (provider, token, player_id, sku_id, state, created_at) VALUES (?, ?, NULL, NULL, NULL, NOW())",
                "PLAY",
                "tok-a");

        assertThrows(
                DuplicateKeyException.class,
                () -> jdbc.update(
                        "INSERT INTO purchases (provider, token, player_id, sku_id, state, created_at) VALUES (?, ?, NULL, NULL, NULL, NOW())",
                        "PLAY",
                        "tok-a"));
    }

    @Test
    void forgedBalanceRejected() throws Exception {
        Guest guest = mintGuest();
        economy.ensureDefaults(guest.playerId());
        creditCoins(guest.playerId(), 200);

        // Wallet GET must ignore forged query balance params (ECON-04).
        mockMvc.perform(get("/v1/wallet")
                        .param("coins", "9999")
                        .param("gems", "9999")
                        .param("balance", "9999")
                        .header("Authorization", "Bearer " + guest.access()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.coins").value(200))
                .andExpect(jsonPath("$.gems").value(0));

        // Soft purchase ignores forged balance / coinsDelta in body (ECON-04 / ThrowAuthorityIT spirit).
        String key = "forge-purchase-" + UUID.randomUUID();
        mockMvc.perform(post("/v1/shop/purchases")
                        .header("Authorization", "Bearer " + guest.access())
                        .contentType(APPLICATION_JSON)
                        .content(
                                """
                                {
                                  "skuId": "saka_color_gold",
                                  "idempotencyKey": "%s",
                                  "coins": 9999,
                                  "gems": 9999,
                                  "balance": 9999,
                                  "coinsDelta": 5000
                                }
                                """
                                        .formatted(key)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.owned").value(true))
                .andExpect(jsonPath("$.coins").value(80));

        mockMvc.perform(get("/v1/wallet").header("Authorization", "Bearer " + guest.access()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.coins").value(80));
    }

    @Test
    void guestPurchase() throws Exception {
        Guest guest = mintGuest();
        economy.ensureDefaults(guest.playerId());
        creditCoins(guest.playerId(), 200);

        String key = "guest-buy-" + UUID.randomUUID();
        mockMvc.perform(post("/v1/shop/purchases")
                        .header("Authorization", "Bearer " + guest.access())
                        .contentType(APPLICATION_JSON)
                        .content(
                                """
                                {"skuId":"saka_color_gold","idempotencyKey":"%s"}
                                """
                                        .formatted(key)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.owned").value(true))
                .andExpect(jsonPath("$.skuId").value("saka_color_gold"))
                .andExpect(jsonPath("$.coins").value(80));

        Integer owned = new JdbcTemplate(dataSource)
                .queryForObject(
                        "SELECT COUNT(*) FROM inventory WHERE player_id = ? AND sku_id = ?",
                        Integer.class,
                        guest.playerId(),
                        "saka_color_gold");
        assertEquals(1, owned);

        Integer softRows = new JdbcTemplate(dataSource)
                .queryForObject(
                        "SELECT COUNT(*) FROM soft_purchases WHERE player_id = ? AND sku_id = ?",
                        Integer.class,
                        guest.playerId(),
                        "saka_color_gold");
        assertEquals(1, softRows);

        Integer iapRows = new JdbcTemplate(dataSource)
                .queryForObject(
                        "SELECT COUNT(*) FROM purchases WHERE player_id = ?",
                        Integer.class,
                        guest.playerId());
        assertEquals(0, iapRows, "soft buys must not write purchases IAP table (D-60)");
    }

    @Test
    void purchaseIdempotent() throws Exception {
        Guest guest = mintGuest();
        economy.ensureDefaults(guest.playerId());
        creditCoins(guest.playerId(), 200);

        String key = "idem-" + UUID.randomUUID();
        String body =
                """
                {"skuId":"saka_color_gold","idempotencyKey":"%s"}
                """
                        .formatted(key);

        mockMvc.perform(post("/v1/shop/purchases")
                        .header("Authorization", "Bearer " + guest.access())
                        .contentType(APPLICATION_JSON)
                        .content(body))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.coins").value(80));

        mockMvc.perform(post("/v1/shop/purchases")
                        .header("Authorization", "Bearer " + guest.access())
                        .contentType(APPLICATION_JSON)
                        .content(body))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.owned").value(true))
                .andExpect(jsonPath("$.coins").value(80));

        Integer ledgerDebits = new JdbcTemplate(dataSource)
                .queryForObject(
                        """
                        SELECT COUNT(*) FROM wallet_ledger
                        WHERE player_id = ? AND currency = 'COINS' AND delta < 0
                        """,
                        Integer.class,
                        guest.playerId());
        assertEquals(1, ledgerDebits, "same idempotencyKey must debit once");
    }

    @Test
    void insufficientFundsNoPartialGrant() throws Exception {
        Guest guest = mintGuest();
        economy.ensureDefaults(guest.playerId());

        Integer invBefore = inventoryCount(guest.playerId(), "saka_color_gold");
        mockMvc.perform(get("/v1/wallet").header("Authorization", "Bearer " + guest.access()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.coins").value(0));

        mockMvc.perform(post("/v1/shop/purchases")
                        .header("Authorization", "Bearer " + guest.access())
                        .contentType(APPLICATION_JSON)
                        .content(
                                """
                                {"skuId":"saka_color_gold","idempotencyKey":"broke-%s"}
                                """
                                        .formatted(UUID.randomUUID())))
                .andExpect(status().isConflict())
                .andExpect(status().reason(Matchers.containsString("insufficient_funds")));

        assertEquals(invBefore, inventoryCount(guest.playerId(), "saka_color_gold"));
        mockMvc.perform(get("/v1/wallet").header("Authorization", "Bearer " + guest.access()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.coins").value(0));
    }

    @Test
    void catalogHasSevenCategories() throws Exception {
        String access = mintAccessToken();

        MvcResult catalog = mockMvc.perform(get("/v1/shop/catalog").header("Authorization", "Bearer " + access))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.skus").isArray())
                .andReturn();

        String body = catalog.getResponse().getContentAsString();
        java.util.List<String> slots = JsonPath.read(body, "$.skus[*].slot");
        assertTrue(slots.contains("saka_color"), "catalog must include saka_color");
        assertTrue(slots.contains("saka_material"), "catalog must include saka_material");
        assertTrue(slots.contains("saka_ornament"), "catalog must include saka_ornament");
        assertTrue(slots.contains("trail"), "catalog must include trail");
        assertTrue(slots.contains("table_fx"), "catalog must include table_fx");
        assertTrue(slots.contains("victory"), "catalog must include victory");
        assertTrue(slots.contains("stick_pull"), "catalog must include stick_pull");

        java.util.List<Boolean> frees = JsonPath.read(body, "$.skus[?(@.free == true)].free");
        assertTrue(frees.size() >= 7, "thin set must include free defaults for each slot");
    }

    /**
     * CR-01: concurrent same-SKU soft buys with distinct idempotency keys must debit once
     * and leave a single soft_purchases / inventory row (ECON-05 / D-59).
     */
    @Test
    void sameSkuDifferentKeys() throws Exception {
        Guest guest = mintGuest();
        economy.ensureDefaults(guest.playerId());
        creditCoins(guest.playerId(), 300);

        String key1 = "same-sku-a-" + UUID.randomUUID();
        String key2 = "same-sku-b-" + UUID.randomUUID();
        CountDownLatch ready = new CountDownLatch(2);
        CountDownLatch start = new CountDownLatch(1);
        CountDownLatch done = new CountDownLatch(2);
        AtomicInteger successes = new AtomicInteger();
        AtomicInteger alreadyOwned = new AtomicInteger();
        AtomicReference<Throwable> unexpected = new AtomicReference<>();

        ExecutorService pool = Executors.newFixedThreadPool(2);
        for (String key : new String[] {key1, key2}) {
            pool.submit(() -> {
                try {
                    ready.countDown();
                    start.await(30, TimeUnit.SECONDS);
                    economy.purchase(guest.playerId(), "saka_color_gold", key);
                    successes.incrementAndGet();
                } catch (ResponseStatusException e) {
                    if (e.getStatusCode().value() == 409 && "already_owned".equals(e.getReason())) {
                        alreadyOwned.incrementAndGet();
                    } else {
                        unexpected.compareAndSet(null, e);
                    }
                } catch (Throwable t) {
                    unexpected.compareAndSet(null, t);
                } finally {
                    done.countDown();
                }
            });
        }
        assertTrue(ready.await(30, TimeUnit.SECONDS), "workers ready");
        start.countDown();
        assertTrue(done.await(60, TimeUnit.SECONDS), "workers finished");
        pool.shutdownNow();
        if (unexpected.get() != null) {
            throw new AssertionError("unexpected purchase failure", unexpected.get());
        }

        assertEquals(2, successes.get() + alreadyOwned.get(), "both attempts must resolve");
        assertTrue(successes.get() >= 1, "at least one purchase must succeed");

        JdbcTemplate jdbc = new JdbcTemplate(dataSource);
        Integer softRows = jdbc.queryForObject(
                "SELECT COUNT(*) FROM soft_purchases WHERE player_id = ? AND sku_id = ?",
                Integer.class,
                guest.playerId(),
                "saka_color_gold");
        assertEquals(1, softRows, "at most one soft_purchases row per player+sku (CR-01)");

        Integer owned = inventoryCount(guest.playerId(), "saka_color_gold");
        assertEquals(1, owned);

        Integer ledgerDebits = jdbc.queryForObject(
                """
                SELECT COUNT(*) FROM wallet_ledger
                WHERE player_id = ? AND currency = 'COINS' AND delta < 0 AND reason = 'SOFT_PURCHASE'
                """,
                Integer.class,
                guest.playerId());
        assertEquals(1, ledgerDebits, "wallet debited exactly once for same SKU");

        mockMvc.perform(get("/v1/wallet").header("Authorization", "Bearer " + guest.access()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.coins").value(180)); // 300 - 120
    }

    /**
     * CR-02: concurrent soft debit and match grant must keep wallets.balance equal to sum of
     * ledger deltas (no lost update from unlocked creditIfAbsent RMW).
     */
    @Test
    void grantVsPurchaseRace() throws Exception {
        // One guest + multiple paid SKUs avoids guest-mint rate limits while still racing often.
        String[] skus = {
            "saka_color_gold",
            "saka_color_neon",
            "saka_material_ice",
            "saka_material_fire",
            "saka_ornament_space",
            "saka_ornament_knot",
            "trail_gold",
            "table_fx_neon",
            "stick_pull_ice"
        };
        Guest guest = mintGuest();
        economy.ensureDefaults(guest.playerId());
        creditCoins(guest.playerId(), 5000);

        JdbcTemplate jdbc = new JdbcTemplate(dataSource);
        for (int round = 0; round < skus.length; round++) {
            String skuId = skus[round];
            UUID matchId = UUID.randomUUID();
            String buyKey = "grant-vs-buy-" + round + "-" + UUID.randomUUID();
            CountDownLatch ready = new CountDownLatch(2);
            CountDownLatch start = new CountDownLatch(1);
            CountDownLatch done = new CountDownLatch(2);
            AtomicReference<Throwable> unexpected = new AtomicReference<>();

            ExecutorService pool = Executors.newFixedThreadPool(2);
            pool.submit(() -> {
                try {
                    ready.countDown();
                    start.await(30, TimeUnit.SECONDS);
                    economy.purchase(guest.playerId(), skuId, buyKey);
                } catch (Throwable t) {
                    unexpected.compareAndSet(null, t);
                } finally {
                    done.countDown();
                }
            });
            pool.submit(() -> {
                try {
                    ready.countDown();
                    start.await(30, TimeUnit.SECONDS);
                    economy.grantMatchRewards(
                            new MatchRewardCommand(matchId, guest.playerId(), "WIN", "EASY", false));
                } catch (Throwable t) {
                    unexpected.compareAndSet(null, t);
                } finally {
                    done.countDown();
                }
            });
            assertTrue(ready.await(30, TimeUnit.SECONDS), "round " + round + " ready");
            start.countDown();
            assertTrue(done.await(60, TimeUnit.SECONDS), "round " + round + " finished");
            pool.shutdownNow();
            if (unexpected.get() != null) {
                throw new AssertionError("round " + round + " unexpected", unexpected.get());
            }

            Long wallet = jdbc.queryForObject(
                    "SELECT balance FROM wallets WHERE player_id = ? AND currency = 'COINS'",
                    Long.class,
                    guest.playerId());
            Long ledgerSum = jdbc.queryForObject(
                    """
                    SELECT COALESCE(SUM(delta), 0) FROM wallet_ledger
                    WHERE player_id = ? AND currency = 'COINS'
                    """,
                    Long.class,
                    guest.playerId());
            assertEquals(ledgerSum, wallet, "round " + round + ": wallet must equal ledger sum (CR-02)");

            Integer softDebits = jdbc.queryForObject(
                    """
                    SELECT COUNT(*) FROM wallet_ledger
                    WHERE player_id = ? AND currency = 'COINS' AND reason = 'SOFT_PURCHASE'
                      AND idempotency_key = ?
                    """,
                    Integer.class,
                    guest.playerId(),
                    "soft:" + buyKey);
            assertEquals(1, softDebits, "round " + round + ": soft debit ledger present");

            Integer matchCredits = jdbc.queryForObject(
                    """
                    SELECT COUNT(*) FROM wallet_ledger
                    WHERE player_id = ? AND currency = 'COINS' AND reason = 'MATCH_REWARD'
                      AND idempotency_key = ?
                    """,
                    Integer.class,
                    guest.playerId(),
                    MatchRewardTable.idempotencyKey(matchId, guest.playerId()));
            assertEquals(1, matchCredits, "round " + round + ": match grant ledger present");
        }
    }

    @Test
    void equipOnCreate() throws Exception {
        Guest guest = mintGuest();
        economy.ensureDefaults(guest.playerId());
        creditCoins(guest.playerId(), 200);

        mockMvc.perform(post("/v1/shop/purchases")
                        .header("Authorization", "Bearer " + guest.access())
                        .contentType(APPLICATION_JSON)
                        .content(
                                """
                                {"skuId":"saka_color_gold","idempotencyKey":"equip-buy-%s"}
                                """
                                        .formatted(UUID.randomUUID())))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.owned").value(true));

        mockMvc.perform(post("/v1/shop/equip")
                        .header("Authorization", "Bearer " + guest.access())
                        .contentType(APPLICATION_JSON)
                        .content(
                                """
                                {"slot":"saka_color","skuId":"saka_color_gold"}
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.slot").value("saka_color"))
                .andExpect(jsonPath("$.skuId").value("saka_color_gold"));

        mockMvc.perform(get("/v1/loadout").header("Authorization", "Bearer " + guest.access()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.saka_color").value("saka_color_gold"));

        mockMvc.perform(post("/v1/matches")
                        .header("Authorization", "Bearer " + guest.access())
                        .contentType(APPLICATION_JSON)
                        .content("{\"game\":\"ALCHIKI\",\"mode\":\"BOT\",\"difficulty\":\"EASY\"}"))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.localLoadout.saka_color").value("saka_color_gold"));

        JdbcTemplate jdbc = new JdbcTemplate(dataSource);
        Integer massCol = jdbc.queryForObject(
                """
                SELECT COUNT(*) FROM information_schema.columns
                WHERE table_name = 'cosmetic_skus' AND column_name IN ('mass', 'friction', 'restitution', 'density')
                """,
                Integer.class);
        assertEquals(0, massCol, "cosmetic_skus must not have gameplay mass/friction columns (ECON-03)");
    }

    private String mintAccessToken() throws Exception {
        return mintGuest().access();
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

    private void creditCoins(UUID playerId, long amount) {
        wallets.ensureWalletRows(playerId);
        wallets.creditIfAbsent(
                playerId,
                "COINS",
                amount,
                "TEST_CREDIT",
                "test-credit-" + playerId + "-" + UUID.randomUUID(),
                UUID.randomUUID());
    }

    private Integer inventoryCount(UUID playerId, String skuId) {
        return new JdbcTemplate(dataSource)
                .queryForObject(
                        "SELECT COUNT(*) FROM inventory WHERE player_id = ? AND sku_id = ?",
                        Integer.class,
                        playerId,
                        skuId);
    }

    private record Guest(UUID playerId, String access) {}

    private String createBotMatch(String token, String difficulty) throws Exception {
        MvcResult created = mockMvc.perform(post("/v1/matches")
                        .header("Authorization", "Bearer " + token)
                        .contentType(APPLICATION_JSON)
                        .content("{\"game\":\"ALCHIKI\",\"mode\":\"BOT\",\"difficulty\":\"" + difficulty + "\"}"))
                .andExpect(status().isCreated())
                .andReturn();
        return JsonPath.read(created.getResponse().getContentAsString(), "$.matchId");
    }

    private Seats bothReadyPrivate() throws Exception {
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
                .andExpect(jsonPath("$.matchId").exists())
                .andReturn();
        String matchId = JsonPath.read(bothReady.getResponse().getContentAsString(), "$.matchId").toString();
        return new Seats(hostToken, joinerToken, matchId);
    }

    private record Seats(String hostToken, String joinerToken, String matchId) {}
}
