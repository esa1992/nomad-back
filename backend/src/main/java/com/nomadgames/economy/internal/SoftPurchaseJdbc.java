package com.nomadgames.economy.internal;

import java.time.OffsetDateTime;
import java.util.Optional;
import java.util.UUID;

import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Component;

@Component
public class SoftPurchaseJdbc {

    private final JdbcClient jdbc;

    public SoftPurchaseJdbc(JdbcClient jdbc) {
        this.jdbc = jdbc;
    }

    /**
     * Insert soft purchase; returns false when idempotency_key OR (player_id, sku_id) already
     * exists (CR-01 / D-59 — ON CONFLICT DO NOTHING covers both uniques).
     */
    public boolean insertIfAbsent(UUID id, UUID playerId, String skuId, String idempotencyKey, OffsetDateTime createdAt) {
        int inserted = jdbc.sql(
                        """
                        INSERT INTO soft_purchases (id, player_id, sku_id, idempotency_key, created_at)
                        VALUES (:id, :playerId, :skuId, :idempotencyKey, :createdAt)
                        ON CONFLICT DO NOTHING
                        """)
                .param("id", id)
                .param("playerId", playerId)
                .param("skuId", skuId)
                .param("idempotencyKey", idempotencyKey)
                .param("createdAt", createdAt)
                .update();
        return inserted > 0;
    }

    public Optional<SoftPurchaseRow> findByIdempotencyKey(String idempotencyKey) {
        return jdbc.sql(
                        """
                        SELECT player_id, sku_id FROM soft_purchases
                        WHERE idempotency_key = :key
                        """)
                .param("key", idempotencyKey)
                .query((rs, rowNum) -> new SoftPurchaseRow(
                        (UUID) rs.getObject("player_id"), rs.getString("sku_id")))
                .optional();
    }

    public record SoftPurchaseRow(UUID playerId, String skuId) {}
}
