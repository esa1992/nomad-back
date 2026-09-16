-- CR-01 / ECON-05 / D-59: one soft purchase row per player+SKU (idempotency_key alone insufficient)
ALTER TABLE soft_purchases
    ADD CONSTRAINT soft_purchases_player_sku_uq UNIQUE (player_id, sku_id);
