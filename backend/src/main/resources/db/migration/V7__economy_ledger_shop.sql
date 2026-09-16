-- Economy ledger + cosmetic shop shell (ECON-04 / ECON-05 / D-58 / D-60)
-- Dual wallets, append-only ledger, soft purchases, empty IAP purchases UNIQUE,
-- thin cosmetic SKU seed for seven ECON-02 slots + inventory/loadout.

CREATE TABLE wallets (
    player_id UUID NOT NULL REFERENCES players (id),
    currency VARCHAR(16) NOT NULL,
    balance BIGINT NOT NULL,
    PRIMARY KEY (player_id, currency),
    CONSTRAINT wallets_currency_chk CHECK (currency IN ('COINS', 'GEMS')),
    CONSTRAINT wallets_balance_nonneg CHECK (balance >= 0)
);

CREATE TABLE wallet_ledger (
    id UUID PRIMARY KEY,
    player_id UUID NOT NULL REFERENCES players (id),
    currency VARCHAR(16) NOT NULL,
    delta BIGINT NOT NULL,
    balance_after BIGINT NOT NULL,
    reason VARCHAR(64) NOT NULL,
    idempotency_key VARCHAR(128) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL,
    CONSTRAINT wallet_ledger_currency_chk CHECK (currency IN ('COINS', 'GEMS')),
    CONSTRAINT wallet_ledger_idempotency_key_uq UNIQUE (idempotency_key)
);

CREATE TABLE soft_purchases (
    id UUID PRIMARY KEY,
    player_id UUID NOT NULL REFERENCES players (id),
    sku_id VARCHAR(64) NOT NULL,
    idempotency_key VARCHAR(128) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL,
    CONSTRAINT soft_purchases_idempotency_key_uq UNIQUE (idempotency_key)
);

-- Empty IAP shell: UNIQUE (provider, token); zero seed rows (D-60 / ECON-05)
CREATE TABLE purchases (
    provider VARCHAR(16) NOT NULL,
    token VARCHAR(512) NOT NULL,
    player_id UUID NULL,
    sku_id VARCHAR(64) NULL,
    state VARCHAR(32) NULL,
    created_at TIMESTAMPTZ NOT NULL,
    PRIMARY KEY (provider, token)
);

CREATE TABLE cosmetic_skus (
    id VARCHAR(64) PRIMARY KEY,
    slot VARCHAR(32) NOT NULL,
    theme VARCHAR(32) NOT NULL,
    name_key VARCHAR(64) NOT NULL,
    price_coins INT NOT NULL DEFAULT 0,
    price_gems INT NOT NULL DEFAULT 0,
    free_default BOOLEAN NOT NULL DEFAULT FALSE,
    CONSTRAINT cosmetic_skus_slot_chk CHECK (slot IN (
        'saka_color', 'saka_material', 'saka_ornament', 'trail', 'table_fx', 'victory', 'stick_pull'
    )),
    CONSTRAINT cosmetic_skus_price_nonneg CHECK (price_coins >= 0 AND price_gems >= 0)
);

CREATE TABLE inventory (
    player_id UUID NOT NULL REFERENCES players (id),
    sku_id VARCHAR(64) NOT NULL REFERENCES cosmetic_skus (id),
    acquired_at TIMESTAMPTZ NOT NULL,
    PRIMARY KEY (player_id, sku_id)
);

CREATE TABLE loadout (
    player_id UUID NOT NULL REFERENCES players (id),
    slot VARCHAR(32) NOT NULL,
    sku_id VARCHAR(64) NOT NULL REFERENCES cosmetic_skus (id),
    PRIMARY KEY (player_id, slot),
    CONSTRAINT loadout_slot_chk CHECK (slot IN (
        'saka_color', 'saka_material', 'saka_ornament', 'trail', 'table_fx', 'victory', 'stick_pull'
    ))
);

-- Thin seed: 1 free default per slot + paid PRES-02 themes (~17 SKUs)
INSERT INTO cosmetic_skus (id, slot, theme, name_key, price_coins, price_gems, free_default) VALUES
    ('saka_color_default', 'saka_color', 'default', 'skuSakaColorDefault', 0, 0, TRUE),
    ('saka_color_gold', 'saka_color', 'gold', 'skuSakaColorGold', 120, 0, FALSE),
    ('saka_color_neon', 'saka_color', 'neon', 'skuSakaColorNeon', 180, 0, FALSE),

    ('saka_material_default', 'saka_material', 'default', 'skuSakaMaterialDefault', 0, 0, TRUE),
    ('saka_material_ice', 'saka_material', 'ice', 'skuSakaMaterialIce', 150, 0, FALSE),
    ('saka_material_fire', 'saka_material', 'fire', 'skuSakaMaterialFire', 200, 0, FALSE),

    ('saka_ornament_default', 'saka_ornament', 'default', 'skuSakaOrnamentDefault', 0, 0, TRUE),
    ('saka_ornament_space', 'saka_ornament', 'space', 'skuSakaOrnamentSpace', 220, 0, FALSE),
    ('saka_ornament_knot', 'saka_ornament', 'knot', 'skuSakaOrnamentKnot', 160, 0, FALSE),

    ('trail_default', 'trail', 'default', 'skuTrailDefault', 0, 0, TRUE),
    ('trail_gold', 'trail', 'gold', 'skuTrailGold', 140, 0, FALSE),

    ('table_fx_default', 'table_fx', 'default', 'skuTableFxDefault', 0, 0, TRUE),
    ('table_fx_neon', 'table_fx', 'neon', 'skuTableFxNeon', 250, 0, FALSE),

    ('victory_default', 'victory', 'default', 'skuVictoryDefault', 0, 0, TRUE),
    ('victory_fire', 'victory', 'fire', 'skuVictoryFire', 0, 8, FALSE),

    ('stick_pull_default', 'stick_pull', 'default', 'skuStickPullDefault', 0, 0, TRUE),
    ('stick_pull_ice', 'stick_pull', 'ice', 'skuStickPullIce', 300, 0, FALSE);
