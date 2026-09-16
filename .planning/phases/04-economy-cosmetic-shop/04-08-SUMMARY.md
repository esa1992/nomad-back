---
phase: 04-economy-cosmetic-shop
plan: 08
subsystem: economy
tags: [soft-purchase, wallet-ledger, flyway, postgres, race-condition, idempotency, ECON-04, ECON-05]

requires:
  - phase: 04-economy-cosmetic-shop/04-04
    provides: Soft purchase path, WalletLedgerJdbc.creditIfAbsent, EconomyIT baseline
provides:
  - "UNIQUE (player_id, sku_id) on soft_purchases (V8)"
  - "Post-lock owns re-check on soft buy (CR-01)"
  - "Locked + relative creditIfAbsent (CR-02)"
  - "EconomyIT sameSkuDifferentKeys + grantVsPurchaseRace"
affects:
  - 04-economy-cosmetic-shop verification
  - match grant and soft purchase concurrency

tech-stack:
  added: []
  patterns:
    - "Post-lock ownership re-check before soft_purchases insert"
    - "ON CONFLICT DO NOTHING covering all uniques on soft_purchases"
    - "creditIfAbsent: FOR UPDATE then balance = balance + delta"

key-files:
  created:
    - backend/src/main/resources/db/migration/V8__soft_purchase_sku_unique.sql
  modified:
    - backend/src/main/java/com/nomadgames/economy/EconomyService.java
    - backend/src/main/java/com/nomadgames/economy/internal/WalletLedgerJdbc.java
    - backend/src/main/java/com/nomadgames/economy/internal/SoftPurchaseJdbc.java
    - backend/src/test/java/com/nomadgames/economy/EconomyIT.java

key-decisions:
  - "CR-01: keep early owns fast-path; mandatory owns re-check after lockBalance; map player+sku insert conflict to already_owned"
  - "CR-02: creditIfAbsent always lockBalance then relative UPDATE balance = balance + delta"
  - "SoftPurchaseJdbc uses ON CONFLICT DO NOTHING (no target) so both idempotency_key and player_sku uniques are covered"

patterns-established:
  - "Wallet mutations that compute from current balance must lock the wallets row first"
  - "Same-SKU soft buy safety is DB unique + post-lock owns, not client idempotency alone"

requirements-completed: [ECON-04, ECON-05]

coverage:
  - id: D1
    description: Concurrent same-SKU soft buys with different keys debit once and leave one soft_purchases row
    requirement: ECON-05
    verification:
      - kind: integration
        ref: backend/src/test/java/com/nomadgames/economy/EconomyIT.java#sameSkuDifferentKeys
        status: pass
    human_judgment: false
  - id: D2
    description: Concurrent match grant and soft debit keep wallets.balance equal to sum of COINS ledger deltas
    requirement: ECON-04
    verification:
      - kind: integration
        ref: backend/src/test/java/com/nomadgames/economy/EconomyIT.java#grantVsPurchaseRace
        status: pass
    human_judgment: false
  - id: D3
    description: Existing purchase/grant idempotency and forged-balance rejection remain green
    requirement: ECON-04
    verification:
      - kind: integration
        ref: "mvnw -pl backend -am test -Dtest=EconomyIT,ModularityTest"
        status: pass
    human_judgment: false

duration: 8min
completed: 2026-09-10
status: complete
---

# Phase 04 Plan 08: Soft-buy SKU lock + locked creditIfAbsent Summary

**Post-lock owns + V8 UNIQUE (player_id, sku_id) stop same-SKU double-debit; creditIfAbsent locks and applies relative wallet updates so match grants cannot overwrite soft debits**

## Performance

- **Duration:** 8 min
- **Started:** 2026-09-10T11:23:30Z
- **Completed:** 2026-09-10T11:31:00Z
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments

- Soft buys of the same SKU with distinct idempotency keys debit the wallet once and leave a single `soft_purchases` / inventory row (CR-01)
- `creditIfAbsent` takes `FOR UPDATE` then `balance = balance + delta`, eliminating unlocked RMW lost updates vs soft purchase (CR-02)
- Flyway V8 applied in IT; IAP `purchases` table remains unused; existing EconomyIT + ModularityTest green

## Task Commits

Each task was committed atomically:

1. **Task 1: Failing EconomyIT for same-SKU keys and grant race** - `90f9dea` (test)
2. **Task 2: Post-lock owns, V8 SKU unique, locked creditIfAbsent** - `9268064` (feat)

**Plan metadata:** `c7afb64` (docs: complete plan)

_Note: TDD tasks use test в†’ feat commit pair_

## Files Created/Modified

- `backend/src/main/resources/db/migration/V8__soft_purchase_sku_unique.sql` - UNIQUE (player_id, sku_id) on soft_purchases
- `backend/src/main/java/com/nomadgames/economy/EconomyService.java` - owns after lockBalance; map SKU unique conflict to already_owned
- `backend/src/main/java/com/nomadgames/economy/internal/WalletLedgerJdbc.java` - locked relative creditIfAbsent
- `backend/src/main/java/com/nomadgames/economy/internal/SoftPurchaseJdbc.java` - ON CONFLICT DO NOTHING for all uniques
- `backend/src/test/java/com/nomadgames/economy/EconomyIT.java` - sameSkuDifferentKeys + grantVsPurchaseRace

## Decisions Made

- Kept the early owns check as a fast path; post-lock owns is mandatory for CR-01
- Soft insert conflicts: same idempotency key в†’ idempotent replay; player+sku unique without key match в†’ 409 already_owned (no second debit)
- creditIfAbsent always locks even when purchase already called lockBalance (same TX re-lock is safe)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] grantVsPurchaseRace mint storm hit guest 429**
- **Found during:** Task 2 (GREEN verification)
- **Issue:** 40 concurrent guest mints tripped identity rate limit (HTTP 429), failing the race test and poisoning later EconomyIT cases
- **Fix:** One guest, nine paid SKUs across rounds; assert per-round ledger keys; still exercises CR-02 concurrency
- **Files modified:** backend/src/test/java/com/nomadgames/economy/EconomyIT.java
- **Verification:** EconomyIT + ModularityTest BUILD SUCCESS
- **Committed in:** 9268064 (Task 2)

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** Necessary to keep IT suite green under guest rate limits; race coverage retained

## Issues Encountered

- Guest mint rate limit (429) when looping 40 guests in grantVsPurchaseRace вЂ” resolved by single-guest multi-SKU rounds

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Phase 4 gap closure for CR-01/CR-02 complete; ledger races mitigated
- WR-01/WR-02 left out of scope per plan; IAP purchases still empty shell
- Ready for phase verification / next milestone work

## TDD Gate Compliance

- RED: `90f9dea` test(04-08) вЂ” sameSkuDifferentKeys and grantVsPurchaseRace failed on pre-fix code
- GREEN: `9268064` feat(04-08) вЂ” full EconomyIT + ModularityTest pass

## Self-Check: PASSED

- FOUND: V8__soft_purchase_sku_unique.sql
- FOUND: EconomyService post-lock owns + SoftPurchaseJdbc ON CONFLICT DO NOTHING
- FOUND: WalletLedgerJdbc lockBalance + relative UPDATE in creditIfAbsent
- FOUND: commits 90f9dea, 9268064

---
*Phase: 04-economy-cosmetic-shop*
*Completed: 2026-09-10*
