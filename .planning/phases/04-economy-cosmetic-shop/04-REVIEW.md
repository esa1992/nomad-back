---
phase: 04-economy-cosmetic-shop
reviewed: 2026-09-10T09:53:00Z
depth: standard
files_reviewed: 30
files_reviewed_list:
  - backend/src/main/resources/db/migration/V7__economy_ledger_shop.sql
  - backend/src/main/java/com/nomadgames/economy/EconomyController.java
  - backend/src/main/java/com/nomadgames/economy/EconomyService.java
  - backend/src/main/java/com/nomadgames/economy/WalletView.java
  - backend/src/main/java/com/nomadgames/economy/ShopCatalog.java
  - backend/src/main/java/com/nomadgames/economy/PurchaseRequest.java
  - backend/src/main/java/com/nomadgames/economy/PurchaseResult.java
  - backend/src/main/java/com/nomadgames/economy/EquipRequest.java
  - backend/src/main/java/com/nomadgames/economy/EquipResult.java
  - backend/src/main/java/com/nomadgames/economy/MatchRewardTable.java
  - backend/src/main/java/com/nomadgames/economy/MatchRewardCommand.java
  - backend/src/main/java/com/nomadgames/economy/RewardGrant.java
  - backend/src/main/java/com/nomadgames/economy/internal/WalletLedgerJdbc.java
  - backend/src/main/java/com/nomadgames/economy/internal/SoftPurchaseJdbc.java
  - backend/src/main/java/com/nomadgames/economy/internal/InventoryLoadoutJdbc.java
  - backend/src/main/java/com/nomadgames/identity/GuestService.java
  - backend/src/main/java/com/nomadgames/session/MatchService.java
  - backend/src/main/java/com/nomadgames/session/MatchSnapshot.java
  - backend/src/main/java/com/nomadgames/session/MatchCreatedResponse.java
  - client/lib/platform/api/nomad_api.dart
  - client/lib/shop/shop_page.dart
  - client/lib/shop/shop_detail_page.dart
  - client/lib/shop/wallet_chip.dart
  - client/lib/catalog/catalog_page.dart
  - client/lib/platform/router.dart
  - client/lib/games/alchiki/match_game.dart
  - client/lib/games/alchiki/match_page.dart
  - client/lib/games/alchiki/pause_overlay.dart
  - client/lib/l10n/app_en.arb
  - client/lib/l10n/app_ru.arb
findings:
  critical: 2
  warning: 2
  info: 2
  total: 6
status: issues_found
advisory: true
---

# Phase 4: Code Review Report

**Reviewed:** 2026-09-10T09:53:00Z
**Depth:** standard
**Files Reviewed:** 30
**Status:** issues_found (advisory — do not block phase)

## Summary

Phase 4 economy ledger, soft purchase, match grants, shop UI, and presentation-only cosmetics were reviewed with focus on ledger correctness, purchase idempotency, client balance forgery, physics isolation, and empty IAP shell.

**What holds:** GET `/v1/wallet` and `PurchaseRequest` ignore client balance fields (ECON-04); soft buys never write `purchases`; IAP table ships empty with UNIQUE `(provider, token)`; same-key soft-purchase idempotency and match-grant `ON CONFLICT` keys look sound; cosmetics map to paint only (`SakaBody` FixtureDef stays on `TableConstants`).

**Key concerns:** concurrent soft buys of the same SKU with different idempotency keys can double-debit; `creditIfAbsent` updates wallet from a non-locked read-modify-write, racing soft purchase vs match grant.

## Critical Issues

### CR-01: Same-SKU soft buy with different keys double-debits

**File:** `backend/src/main/java/com/nomadgames/economy/EconomyService.java:104-142`
**Issue:** `owns()` is checked **before** `lockBalance`. Two concurrent `POST /v1/shop/purchases` for the same `skuId` with different `idempotencyKey` values can both pass the ownership check, both insert into `soft_purchases` (unique only on key, not `(player_id, sku_id)`), and both debit the wallet. Inventory `ON CONFLICT DO NOTHING` still leaves a single owned row while the player is charged twice. Realistic trigger: client network timeout clears the in-flight key (see WR-02) and retries with a new key while the first request is still open or completing.
**Fix:** Re-check ownership after the wallet lock; reject if already owned. Prefer a DB uniqueness / upsert strategy so a second soft row cannot commit for the same SKU:

```java
long balance = wallets.lockBalance(playerId, currency);
if (inventoryLoadout.owns(playerId, skuId)) {
    throw new ResponseStatusException(HttpStatus.CONFLICT, "already_owned");
}
if (balance < price) {
    throw new ResponseStatusException(HttpStatus.CONFLICT, "insufficient_funds");
}
// optionally: UNIQUE (player_id, sku_id) on soft_purchases + handle conflict as already_owned
```

### CR-02: Wallet `creditIfAbsent` lost-update race (unlocked RMW)

**File:** `backend/src/main/java/com/nomadgames/economy/internal/WalletLedgerJdbc.java:79-114`
**Issue:** `creditIfAbsent` reads `balance()` **without** `FOR UPDATE`, computes `after = current + delta`, then `UPDATE wallets SET balance = :balance`. Soft purchase locks via `lockBalance` first, but `grantMatchRewards` does not. Under Postgres READ COMMITTED, a non-locking `SELECT` does not wait on a `FOR UPDATE` row lock, so a match-grant TX can compute `balance_after` from a stale committed balance while a soft-purchase TX holds the lock, then overwrite the wallet on unlock — dropping either the debit or the grant from `wallets.balance` while both ledger rows exist (ledger/wallet divergence).
**Fix:** Always lock the wallet row inside `creditIfAbsent` (or use relative update):

```java
public Optional<Long> creditIfAbsent(...) {
    long current = lockBalance(playerId, currency); // SELECT ... FOR UPDATE
    long after = current + delta;
    if (after < 0) {
        throw new IllegalStateException("wallet underflow");
    }
    int inserted = jdbc.sql(""" ... ON CONFLICT (idempotency_key) DO NOTHING """).update();
    if (inserted == 0) {
        return Optional.empty();
    }
    jdbc.sql("""
            UPDATE wallets SET balance = balance + :delta
            WHERE player_id = :playerId AND currency = :currency
            """)
            .param("delta", delta)
            .param("playerId", playerId)
            .param("currency", currency)
            .update();
    return Optional.of(after);
}
```

## Warnings

### WR-01: Idempotent soft replay ignores requested `skuId`

**File:** `backend/src/main/java/com/nomadgames/economy/EconomyService.java:91-98`
**Issue:** When `idempotencyKey` already exists for this player, the handler returns `resultFor(playerId, row.skuId())` and does not verify that the new request's `skuId` matches the stored purchase. Reusing a key for a different SKU yields a successful response for the original SKU (confusing client state; weakens idempotency contract).
**Fix:** If `prior` exists and `!skuId.equals(row.skuId())`, return `409` with reason `idempotency_key` (or `sku_mismatch`).

### WR-02: Client drops idempotency key on any failure (enables CR-01)

**File:** `client/lib/shop/shop_detail_page.dart:124-144`
**Issue:** On `NomadApiException` and generic catch, `_inFlightKey` is cleared. After a transport timeout where the server may have committed (or still be committing), a retry generates a **new** key. Same-key replay is the safe path; new keys plus CR-01 produce double spend. Comment claims “new key after hard failure,” but network errors are not hard application failures.
**Fix:** Keep `_inFlightKey` across transient/network failures; only clear it after a definitive success, `already_owned`, or `insufficient_funds`. Optionally map `already_owned` to success UI.

## Info

### IN-01: IAP `purchases` shell correctly empty / unused

**File:** `backend/src/main/resources/db/migration/V7__economy_ledger_shop.sql:36-45`
**Issue:** None — advisory confirmation. Table exists with PRIMARY KEY `(provider, token)`, zero seed rows; no Java writers under `com.nomadgames` insert into `purchases`. Soft path uses `soft_purchases` only (D-60 / ECON-05).
**Fix:** N/A — keep IAP writers out of Phase 4.

### IN-02: Cosmetics stay presentation-only on Alchiki

**File:** `client/lib/games/alchiki/match_game.dart:67-115` / `client/lib/game/saka_body.dart:33-50`
**Issue:** None — advisory confirmation. SKU helpers only produce `Color` fills/stripes/trail tint; `SakaBody` density/friction/restitution/radius remain `TableConstants`. `stick_pull` unused on Alchiki. Matches ECON-03 / D-54.
**Fix:** N/A.

---

_Reviewed: 2026-09-10T09:53:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
_Advisory: true (do not block)_
