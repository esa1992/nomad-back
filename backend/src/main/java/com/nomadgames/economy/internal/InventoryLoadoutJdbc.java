package com.nomadgames.economy.internal;

import java.time.OffsetDateTime;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Component;

@Component
public class InventoryLoadoutJdbc {

    private final JdbcClient jdbc;

    public InventoryLoadoutJdbc(JdbcClient jdbc) {
        this.jdbc = jdbc;
    }

    public List<FreeDefaultSku> freeDefaults() {
        return jdbc.sql(
                        """
                        SELECT id, slot FROM cosmetic_skus
                        WHERE free_default = TRUE
                        ORDER BY slot
                        """)
                .query((rs, rowNum) -> new FreeDefaultSku(rs.getString("id"), rs.getString("slot")))
                .list();
    }

    public Optional<SkuPriceRow> findSku(String skuId) {
        return jdbc.sql(
                        """
                        SELECT id, slot, price_coins, price_gems, free_default
                        FROM cosmetic_skus WHERE id = :skuId
                        """)
                .param("skuId", skuId)
                .query((rs, rowNum) -> new SkuPriceRow(
                        rs.getString("id"),
                        rs.getString("slot"),
                        rs.getInt("price_coins"),
                        rs.getInt("price_gems"),
                        rs.getBoolean("free_default")))
                .optional();
    }

    public boolean owns(UUID playerId, String skuId) {
        return jdbc.sql(
                        """
                        SELECT 1 FROM inventory
                        WHERE player_id = :playerId AND sku_id = :skuId
                        """)
                .param("playerId", playerId)
                .param("skuId", skuId)
                .query(Integer.class)
                .optional()
                .isPresent();
    }

    public void grantInventoryIfAbsent(UUID playerId, String skuId, OffsetDateTime acquiredAt) {
        jdbc.sql(
                        """
                        INSERT INTO inventory (player_id, sku_id, acquired_at)
                        VALUES (:playerId, :skuId, :acquiredAt)
                        ON CONFLICT (player_id, sku_id) DO NOTHING
                        """)
                .param("playerId", playerId)
                .param("skuId", skuId)
                .param("acquiredAt", acquiredAt)
                .update();
    }

    public void equipIfAbsent(UUID playerId, String slot, String skuId) {
        jdbc.sql(
                        """
                        INSERT INTO loadout (player_id, slot, sku_id)
                        VALUES (:playerId, :slot, :skuId)
                        ON CONFLICT (player_id, slot) DO NOTHING
                        """)
                .param("playerId", playerId)
                .param("slot", slot)
                .param("skuId", skuId)
                .update();
    }

    /** Upsert loadout slot (equip-another; never leaves an empty slot — D-55). */
    public void equipSlot(UUID playerId, String slot, String skuId) {
        jdbc.sql(
                        """
                        INSERT INTO loadout (player_id, slot, sku_id)
                        VALUES (:playerId, :slot, :skuId)
                        ON CONFLICT (player_id, slot) DO UPDATE SET sku_id = EXCLUDED.sku_id
                        """)
                .param("playerId", playerId)
                .param("slot", slot)
                .param("skuId", skuId)
                .update();
    }

    public Map<String, String> loadoutMap(UUID playerId) {
        List<LoadoutRow> rows = jdbc.sql(
                        """
                        SELECT slot, sku_id FROM loadout
                        WHERE player_id = :playerId
                        ORDER BY slot
                        """)
                .param("playerId", playerId)
                .query((rs, rowNum) -> new LoadoutRow(rs.getString("slot"), rs.getString("sku_id")))
                .list();
        Map<String, String> out = new LinkedHashMap<>();
        for (LoadoutRow row : rows) {
            out.put(row.slot(), row.skuId());
        }
        return out;
    }

    public Optional<String> freeDefaultSkuId(String slot) {
        return jdbc.sql(
                        """
                        SELECT id FROM cosmetic_skus
                        WHERE slot = :slot AND free_default = TRUE
                        LIMIT 1
                        """)
                .param("slot", slot)
                .query(String.class)
                .optional();
    }

    public List<CatalogSkuRow> listCatalogForPlayer(UUID playerId) {
        return jdbc.sql(
                        """
                        SELECT s.id, s.slot, s.name_key, s.price_coins, s.price_gems, s.free_default,
                               (i.sku_id IS NOT NULL) AS owned,
                               (l.sku_id IS NOT NULL) AS equipped
                        FROM cosmetic_skus s
                        LEFT JOIN inventory i
                          ON i.sku_id = s.id AND i.player_id = :playerId
                        LEFT JOIN loadout l
                          ON l.sku_id = s.id AND l.player_id = :playerId AND l.slot = s.slot
                        ORDER BY s.slot, s.free_default DESC, s.id
                        """)
                .param("playerId", playerId)
                .query(
                        (rs, rowNum) -> new CatalogSkuRow(
                                rs.getString("id"),
                                rs.getString("slot"),
                                rs.getString("name_key"),
                                rs.getInt("price_coins"),
                                rs.getInt("price_gems"),
                                rs.getBoolean("owned"),
                                rs.getBoolean("equipped"),
                                rs.getBoolean("free_default")))
                .list();
    }

    public record FreeDefaultSku(String id, String slot) {}

    public record SkuPriceRow(String id, String slot, int priceCoins, int priceGems, boolean free) {}

    public record LoadoutRow(String slot, String skuId) {}

    public record CatalogSkuRow(
            String id,
            String slot,
            String nameKey,
            int priceCoins,
            int priceGems,
            boolean owned,
            boolean equipped,
            boolean free) {}
}
