package com.nomadgames.economy;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import com.nomadgames.analytics.EventSink;
import com.nomadgames.economy.ShopCatalog.ShopSkuView;
import com.nomadgames.economy.internal.InventoryLoadoutJdbc;
import com.nomadgames.economy.internal.InventoryLoadoutJdbc.CatalogSkuRow;
import com.nomadgames.economy.internal.InventoryLoadoutJdbc.FreeDefaultSku;
import com.nomadgames.economy.internal.InventoryLoadoutJdbc.SkuPriceRow;
import com.nomadgames.economy.internal.SoftPurchaseJdbc;
import com.nomadgames.economy.internal.SoftPurchaseJdbc.SoftPurchaseRow;
import com.nomadgames.economy.internal.WalletLedgerJdbc;
import com.nomadgames.economy.internal.WalletLedgerJdbc.LedgerRow;
import com.nomadgames.economy.internal.WalletLedgerJdbc.WalletBalanceRow;

@Service
public class EconomyService {

    private static final String SOFT_PURCHASE_REASON = "SOFT_PURCHASE";

    private final WalletLedgerJdbc wallets;
    private final InventoryLoadoutJdbc inventoryLoadout;
    private final SoftPurchaseJdbc softPurchases;
    private final EventSink events;

    public EconomyService(
            WalletLedgerJdbc wallets,
            InventoryLoadoutJdbc inventoryLoadout,
            SoftPurchaseJdbc softPurchases,
            EventSink events) {
        this.wallets = wallets;
        this.inventoryLoadout = inventoryLoadout;
        this.softPurchases = softPurchases;
        this.events = events;
    }

    @Transactional
    public void ensureDefaults(UUID playerId) {
        wallets.ensureWalletRows(playerId);
        java.time.OffsetDateTime now = java.time.OffsetDateTime.now();
        for (FreeDefaultSku sku : inventoryLoadout.freeDefaults()) {
            inventoryLoadout.grantInventoryIfAbsent(playerId, sku.id(), now);
            inventoryLoadout.equipIfAbsent(playerId, sku.slot(), sku.id());
        }
    }

    @Transactional
    public WalletView getWallet(UUID playerId) {
        ensureDefaults(playerId);
        return readWallet(playerId);
    }

    /** JWT player catalog with owned/equipped flags; guests allowed (D-51). */
    @Transactional
    public ShopCatalog listCatalog(UUID playerId) {
        ensureDefaults(playerId);
        List<ShopSkuView> skus = new ArrayList<>();
        for (CatalogSkuRow row : inventoryLoadout.listCatalogForPlayer(playerId)) {
            skus.add(new ShopSkuView(
                    row.id(),
                    row.slot(),
                    row.nameKey(),
                    row.priceCoins(),
                    row.priceGems(),
                    row.owned(),
                    row.equipped(),
                    row.free()));
        }
        return new ShopCatalog(List.copyOf(skus));
    }

    /**
     * Soft-currency purchase: lock wallet → funds check → soft_purchases → ledger debit → inventory
     * (D-58, D-59). Idempotent on client key; never writes purchases IAP table (D-60). Ignores any
     * client balance/coinsDelta (ECON-04).
     */
    @Transactional
    public PurchaseResult purchase(UUID playerId, String skuId, String idempotencyKey) {
        if (skuId == null || skuId.isBlank()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "skuId required");
        }
        if (idempotencyKey == null || idempotencyKey.isBlank() || idempotencyKey.length() > 128) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "idempotencyKey required");
        }
        ensureDefaults(playerId);

        Optional<SoftPurchaseRow> prior = softPurchases.findByIdempotencyKey(idempotencyKey);
        if (prior.isPresent()) {
            SoftPurchaseRow row = prior.get();
            if (!row.playerId().equals(playerId)) {
                throw new ResponseStatusException(HttpStatus.CONFLICT, "idempotency_key");
            }
            return resultFor(playerId, row.skuId());
        }

        SkuPriceRow sku = inventoryLoadout
                .findSku(skuId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "sku"));

        if (inventoryLoadout.owns(playerId, skuId)) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "already_owned");
        }

        boolean gemsPrice = sku.priceGems() > 0;
        String currency = gemsPrice ? "GEMS" : "COINS";
        long price = gemsPrice ? sku.priceGems() : sku.priceCoins();
        if (price <= 0) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "not purchasable");
        }

        long balance = wallets.lockBalance(playerId, currency);
        // Post-lock owns re-check: concurrent same-SKU buys with different keys (CR-01 / D-59).
        if (inventoryLoadout.owns(playerId, skuId)) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "already_owned");
        }
        if (balance < price) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "insufficient_funds");
        }

        boolean inserted = softPurchases.insertIfAbsent(
                UUID.randomUUID(), playerId, skuId, idempotencyKey, java.time.OffsetDateTime.now());
        if (!inserted) {
            Optional<SoftPurchaseRow> raced = softPurchases.findByIdempotencyKey(idempotencyKey);
            if (raced.isPresent()) {
                SoftPurchaseRow row = raced.get();
                if (!row.playerId().equals(playerId)) {
                    throw new ResponseStatusException(HttpStatus.CONFLICT, "idempotency_key");
                }
                return resultFor(playerId, row.skuId());
            }
            // UNIQUE (player_id, sku_id) conflict under a different key — already owned (CR-01).
            throw new ResponseStatusException(HttpStatus.CONFLICT, "already_owned");
        }

        wallets.creditIfAbsent(
                        playerId,
                        currency,
                        -price,
                        SOFT_PURCHASE_REASON,
                        "soft:" + idempotencyKey,
                        UUID.randomUUID())
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.CONFLICT, "idempotency_key"));

        inventoryLoadout.grantInventoryIfAbsent(playerId, skuId, java.time.OffsetDateTime.now());
        events.emit("ITEM_PURCHASED", playerId, null, Map.of("skuId", skuId, "currency", currency, "price", price));
        return resultFor(playerId, skuId);
    }

    /**
     * Equip an owned SKU into its slot (D-55, D-56). Never leaves an empty slot — free defaults
     * remain equippable; switching is equip-another. Unowned SKUs rejected (T-04-18).
     */
    @Transactional
    public EquipResult equip(UUID playerId, String slot, String skuId) {
        if (slot == null || slot.isBlank()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "slot required");
        }
        if (skuId == null || skuId.isBlank()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "skuId required");
        }
        ensureDefaults(playerId);

        SkuPriceRow sku = inventoryLoadout
                .findSku(skuId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "sku"));
        if (!slot.equals(sku.slot())) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "slot_mismatch");
        }
        if (!inventoryLoadout.owns(playerId, skuId)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "not_owned");
        }
        inventoryLoadout.equipSlot(playerId, slot, skuId);
        return new EquipResult(slot, skuId);
    }

    /** Seven-slot map slot→skuId for presentation (D-56). */
    @Transactional
    public Map<String, String> getLoadout(UUID playerId) {
        ensureDefaults(playerId);
        return Map.copyOf(inventoryLoadout.loadoutMap(playerId));
    }

    /**
     * Sync match grant inside the caller's settle TX (D-45). Unique idempotency_key → re-read prior.
     * Uses ON CONFLICT DO NOTHING so Postgres does not abort the settle transaction (D-58).
     */
    @Transactional
    public RewardGrant grantMatchRewards(MatchRewardCommand cmd) {
        ensureDefaults(cmd.playerId());
        String coinsKey = MatchRewardTable.idempotencyKey(cmd.matchId(), cmd.playerId());
        String gemsKey = MatchRewardTable.gemsIdempotencyKey(cmd.matchId(), cmd.playerId());
        if (wallets.findByIdempotencyKey(coinsKey).isPresent()) {
            return readPriorGrant(coinsKey, gemsKey);
        }
        int coins = MatchRewardTable.coins(cmd.outcome(), cmd.difficulty(), cmd.humanMatch());
        int gems = MatchRewardTable.gems(
                cmd.outcome(), cmd.difficulty(), cmd.humanMatch(), cmd.matchId(), cmd.playerId());
        if (wallets.creditIfAbsent(
                        cmd.playerId(),
                        "COINS",
                        coins,
                        MatchRewardTable.MATCH_REWARD,
                        coinsKey,
                        UUID.randomUUID())
                .isEmpty()) {
            return readPriorGrant(coinsKey, gemsKey);
        }
        if (gems > 0) {
            wallets.creditIfAbsent(
                    cmd.playerId(),
                    "GEMS",
                    gems,
                    MatchRewardTable.MATCH_REWARD,
                    gemsKey,
                    UUID.randomUUID());
        }
        return new RewardGrant(coins, gems);
    }

    private PurchaseResult resultFor(UUID playerId, String skuId) {
        WalletView wallet = readWallet(playerId);
        return new PurchaseResult(skuId, inventoryLoadout.owns(playerId, skuId), wallet.coins(), wallet.gems());
    }

    private WalletView readWallet(UUID playerId) {
        int coins = 0;
        int gems = 0;
        for (WalletBalanceRow row : wallets.balances(playerId)) {
            if ("COINS".equals(row.currency())) {
                coins = Math.toIntExact(row.balance());
            } else if ("GEMS".equals(row.currency())) {
                gems = Math.toIntExact(row.balance());
            }
        }
        return new WalletView(coins, gems);
    }

    private RewardGrant readPriorGrant(String coinsKey, String gemsKey) {
        int coins = wallets.findByIdempotencyKey(coinsKey)
                .map(LedgerRow::delta)
                .map(Math::toIntExact)
                .orElse(0);
        int gems = wallets.findByIdempotencyKey(gemsKey)
                .map(LedgerRow::delta)
                .map(Math::toIntExact)
                .orElse(0);
        return new RewardGrant(coins, gems);
    }
}
