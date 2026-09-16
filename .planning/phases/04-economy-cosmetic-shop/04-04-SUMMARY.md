---
phase: 04-economy-cosmetic-shop
plan: 04
subsystem: economy
tags: [soft-purchase, idempotency, jdbcclient, spring, flutter-shop, wallet]

requires:
  - phase: 04-economy-cosmetic-shop
    provides: wallets + soft_purchases schema + WalletLedgerJdbc (04-01)
  - phase: 04-economy-cosmetic-shop
    provides: shop catalog browse + ShopDetailPage chrome (04-03)
provides:
  - "POST /v1/shop/purchases soft-currency buy with client idempotency key"
  - "SoftPurchaseJdbc + FOR UPDATE wallet debit TX (no IAP purchases table)"
  - "ShopDetailPage Buy CTA with Random.secure idempotency keys"
  - "EconomyIT guestPurchase / purchaseIdempotent / forgedBalanceRejected / insufficientFundsNoPartialGrant"
affects:
  - 04-05 equip/loadout
  - wallet chip refresh after buy

tech-stack:
  added: []
  patterns:
    - "SELECT wallets FOR UPDATE → soft_purchases ON CONFLICT → ledger debit → inventory"
    - "Client Random.secure hex idempotencyKey; reuse in-flight, new key after hard failure"

key-files:
  created:
    - backend/src/main/java/com/nomadgames/economy/internal/SoftPurchaseJdbc.java
    - backend/src/main/java/com/nomadgames/economy/PurchaseRequest.java
    - backend/src/main/java/com/nomadgames/economy/PurchaseResult.java
  modified:
    - backend/src/main/java/com/nomadgames/economy/EconomyController.java
    - backend/src/main/java/com/nomadgames/economy/EconomyService.java
    - backend/src/main/java/com/nomadgames/economy/internal/WalletLedgerJdbc.java
    - backend/src/main/java/com/nomadgames/economy/internal/InventoryLoadoutJdbc.java
    - backend/src/test/java/com/nomadgames/economy/EconomyIT.java
    - client/lib/platform/api/nomad_api.dart
    - client/lib/shop/shop_detail_page.dart

key-decisions:
  - "Insufficient funds returns HTTP 409 with reason insufficient_funds (not 402)"
  - "Ledger debit uses soft:{clientKey} so soft_purchases and wallet_ledger keys stay distinct strings"
  - "Inventory writes stay on InventoryLoadoutJdbc (no separate InventoryJdbc class)"

patterns-established:
  - "Soft purchase TX: lockBalance FOR UPDATE then soft_purchases insertIfAbsent then creditIfAbsent negative delta"
  - "ShopDetailPage ConsumerStatefulWidget owns in-flight idempotency key for double-tap safety"

requirements-completed: [ECON-02, ECON-04, ECON-05]

coverage:
  - id: D1
    description: "Guest soft buy debits COINS and grants inventory without IAP purchases rows"
    requirement: ECON-02
    verification:
      - kind: integration
        ref: "backend/.../EconomyIT.java#guestPurchase"
        status: pass
    human_judgment: false
  - id: D2
    description: "Same idempotencyKey twice does not double-spend"
    requirement: ECON-05
    verification:
      - kind: integration
        ref: "backend/.../EconomyIT.java#purchaseIdempotent"
        status: pass
    human_judgment: false
  - id: D3
    description: "Forged client balance/coinsDelta ignored; charge from DB only"
    requirement: ECON-04
    verification:
      - kind: integration
        ref: "backend/.../EconomyIT.java#forgedBalanceRejected"
        status: pass
    human_judgment: false
  - id: D4
    description: "Insufficient funds is 409 with no inventory or wallet change"
    requirement: ECON-05
    verification:
      - kind: integration
        ref: "backend/.../EconomyIT.java#insufficientFundsNoPartialGrant"
        status: pass
    human_judgment: false
  - id: D5
    description: "Detail Buy CTA calls purchaseSku and refreshes owned/wallet locally"
    requirement: ECON-02
    verification:
      - kind: other
        ref: "client/lib/shop/shop_detail_page.dart#_buy → NomadApi.purchaseSku"
        status: pass
    human_judgment: false

duration: 18min
completed: 2026-09-10
status: complete
---

# Phase 4 Plan 04: Soft Purchase Idempotency Summary

**Guests buy paid cosmetics via POST `/v1/shop/purchases` with client idempotency keys; wallet row-lock + soft_purchases UNIQUE prevent double-spend without touching the empty IAP `purchases` table.**

## Performance

- **Duration:** 18 min
- **Started:** 2026-09-10T08:21:00Z
- **Completed:** 2026-09-10T08:45:00Z
- **Tasks:** 2
- **Files modified:** 10

## Accomplishments

- Soft purchase TX: `FOR UPDATE` wallet → funds check → `soft_purchases` → ledger debit → inventory; duplicate key returns prior success
- Buy CTA on shop detail uses `Random.secure` hex keys (no uuid package); maps 409 `insufficient_funds` to l10n
- EconomyIT purchase suite + ModularityTest + shop_wallet_test green; IAP `purchases` stays unused for soft path (D-60)

## Task Commits

Each task was committed atomically:

1. **Task 1: Failing purchase ITs** - `b8cdcb2` (test)
2. **Task 2: Soft purchase TX + Buy CTA** - `4dd2f3c` (feat)

**Plan metadata:** `83a7bcf` (docs: complete plan)

## Files Created/Modified

- `backend/.../SoftPurchaseJdbc.java` — idempotent soft_purchases insert/find
- `backend/.../EconomyService.java` — `purchase(...)` TX (D-59)
- `backend/.../EconomyController.java` — POST `/v1/shop/purchases`
- `backend/.../WalletLedgerJdbc.java` — `lockBalance` FOR UPDATE
- `backend/.../InventoryLoadoutJdbc.java` — `findSku` / `owns`
- `backend/.../EconomyIT.java` — four purchase ITs
- `client/.../nomad_api.dart` — `purchaseSku` + `PurchaseResult`
- `client/.../shop_detail_page.dart` — Buy wired with in-flight key reuse

## Decisions Made

- 409 + `insufficient_funds` reason for broke wallets (planner lock vs 402)
- Ledger idempotency key prefixed `soft:` to keep ledger keys distinct from soft_purchases row keys
- Inventory helpers live on existing `InventoryLoadoutJdbc` (plan listed InventoryJdbc; avoided duplicate class)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Duplicate JDBC helpers from parallel edits**
- **Found during:** Task 2 compile
- **Issue:** `findSku`/`owns`/`lockBalance` were duplicated after concurrent edits
- **Fix:** Collapsed to single implementations; `SkuPriceRow` includes `slot` for future equip
- **Files modified:** `InventoryLoadoutJdbc.java`, `WalletLedgerJdbc.java`
- **Verification:** EconomyIT + ModularityTest BUILD SUCCESS
- **Committed in:** `4dd2f3c`

**2. [Rule 2 - Missing critical] No separate InventoryJdbc**
- **Found during:** Task 2
- **Issue:** Plan listed `InventoryJdbc.java`; inventory already owned by `InventoryLoadoutJdbc`
- **Fix:** Extended `InventoryLoadoutJdbc` with `findSku`/`owns` instead of a new class
- **Files modified:** `InventoryLoadoutJdbc.java`
- **Verification:** guestPurchase inventory assert green
- **Committed in:** `4dd2f3c`

**Total deviations:** 2 auto-fixed
**Impact on plan:** Same TX behavior; fewer files; no scope creep.

## Issues Encountered

None blocking.

## Known Stubs

| File | Stub | Reason |
|------|------|--------|
| `client/lib/shop/shop_detail_page.dart` | Equip `onTap` no-op | Equip/loadout API in 04-05 |

## Threat Flags

None beyond plan register (T-04-11…14 mitigated by UNIQUE key + FOR UPDATE + JWT playerId + ignore forge fields).

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Spend loop closed. 04-05 can wire Equip/loadout. forge2d untouched; no IAP UI; guests allowed (D-51).

## Self-Check: PASSED

- FOUND: `backend/src/main/java/com/nomadgames/economy/internal/SoftPurchaseJdbc.java`
- FOUND: `backend/src/main/java/com/nomadgames/economy/EconomyController.java` (`/v1/shop/purchases`)
- FOUND: `client/lib/shop/shop_detail_page.dart` (`purchaseSku`)
- FOUND: commit `b8cdcb2`
- FOUND: commit `4dd2f3c`

---
*Phase: 04-economy-cosmetic-shop*
*Completed: 2026-09-10*
