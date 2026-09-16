---
phase: 04-economy-cosmetic-shop
plan: 01
subsystem: economy
tags: [jdbcclient, flyway, wallet, ledger, spring-modulith, testcontainers]

requires:
  - phase: 02-guest-catalog-first-alchiki-match
    provides: Guest mint JWT + CatalogIT Testcontainers pattern
  - phase: 03-private-rooms-casual-reconnect
    provides: RoomController JWT subject pattern; V6 migrations
provides:
  - "GET /v1/wallet returning server COINS/GEMS (start 0/0)"
  - "Flyway V7 wallets, ledger, soft_purchases, empty purchases UNIQUE, SKU/inventory/loadout"
  - "EconomyService.ensureDefaults hooked from GuestService mint"
  - "EconomyIT wallet + purchasesTableUnique green"
affects:
  - 04-02 match reward grants
  - 04-03 shop catalog
  - 04-04 soft purchases
  - 04-05 equip/loadout

tech-stack:
  added: []
  patterns:
    - "JdbcClient named-param writers in economy.internal (never JPA mutate balance)"
    - "identity → economy one-way ensureDefaults after players.flush()"
    - "Empty purchases PRIMARY KEY (provider, token) with zero seed rows"

key-files:
  created:
    - backend/src/main/resources/db/migration/V7__economy_ledger_shop.sql
    - backend/src/main/java/com/nomadgames/economy/EconomyController.java
    - backend/src/main/java/com/nomadgames/economy/EconomyService.java
    - backend/src/main/java/com/nomadgames/economy/WalletView.java
    - backend/src/main/java/com/nomadgames/economy/internal/WalletLedgerJdbc.java
    - backend/src/main/java/com/nomadgames/economy/internal/InventoryLoadoutJdbc.java
    - backend/src/test/java/com/nomadgames/economy/EconomyIT.java
  modified:
    - backend/src/main/java/com/nomadgames/identity/GuestService.java

key-decisions:
  - "Flush PlayerEntity before ensureDefaults so JdbcClient wallet inserts see players FK in the same TX"
  - "Use OffsetDateTime for inventory acquired_at JdbcClient binds (Instant lacks SQL type mapping)"
  - "Thin seed: 17 SKUs across seven ECON-02 slots (7 free defaults + paid PRES-02 themes; one GEMS showcase)"

patterns-established:
  - "Economy Modulith package with internal *Jdbc helpers owning all wallet/inventory SQL"
  - "GET /v1/wallet reads JWT subject only; query/body balance fields ignored"

requirements-completed: [ECON-04, ECON-05]

coverage:
  - id: D1
    description: "Guest mint then GET /v1/wallet returns coins=0 gems=0 from Postgres"
    requirement: ECON-04
    verification:
      - kind: integration
        ref: "backend/.../EconomyIT.java#walletReturnsZeroBalances"
        status: pass
    human_judgment: false
  - id: D2
    description: "GET /v1/wallet without Bearer is 401"
    requirement: ECON-04
    verification:
      - kind: integration
        ref: "backend/.../EconomyIT.java#walletWithoutBearerIsUnauthorized"
        status: pass
    human_judgment: false
  - id: D3
    description: "purchases table exists empty with UNIQUE (provider, token)"
    requirement: ECON-05
    verification:
      - kind: integration
        ref: "backend/.../EconomyIT.java#purchasesTableUnique"
        status: pass
    human_judgment: false
  - id: D4
    description: "Forged wallet query params ignored on GET /v1/wallet"
    requirement: ECON-04
    verification:
      - kind: integration
        ref: "backend/.../EconomyIT.java#forgedBalanceRejected"
        status: pass
    human_judgment: false
  - id: D5
    description: "Spring Modulith verifies with economy package (identity→economy allowed)"
    verification:
      - kind: unit
        ref: "backend/.../ModularityTest.java#modulesShouldVerify"
        status: pass
    human_judgment: false

duration: 8min
completed: 2026-09-10
status: complete
---

# Phase 4 Plan 01: Economy Wallet Foundation Summary

**Dual-wallet GET /v1/wallet from Postgres via JdbcClient, empty IAP purchases UNIQUE shell, and mint-time ensureDefaults for free loadout**

## Performance

- **Duration:** 8 min
- **Started:** 2026-09-10T07:27:41Z
- **Completed:** 2026-09-10T07:35:30Z
- **Tasks:** 2
- **Files modified:** 8

## Accomplishments

- Wave 0 EconomyIT RED then green for wallet 0/0, 401 without Bearer, empty purchases UNIQUE
- Flyway V7 ships wallets, append-only ledger, soft_purchases, empty purchases, cosmetic_skus (~17), inventory, loadout
- Guest mint flushes player then calls economy.ensureDefaults; GET /v1/wallet reads JWT subject only (ECON-04 / ECON-05)

## Task Commits

1. **Task 1: Failing EconomyIT wallet + purchases stubs** - `37afea8` (test)
2. **Task 2: V7 schema + EconomyService wallet + ensureDefaults** - `bb5fbb7` (feat)

**Plan metadata:** `845eed5` (docs: complete plan)

## Files Created/Modified

- `backend/src/test/java/com/nomadgames/economy/EconomyIT.java` - Wallet + purchases UNIQUE ITs
- `backend/src/main/resources/db/migration/V7__economy_ledger_shop.sql` - Economy schema + thin SKU seed
- `backend/src/main/java/com/nomadgames/economy/EconomyController.java` - GET /v1/wallet
- `backend/src/main/java/com/nomadgames/economy/EconomyService.java` - ensureDefaults + getWallet
- `backend/src/main/java/com/nomadgames/economy/WalletView.java` - coins/gems DTO
- `backend/src/main/java/com/nomadgames/economy/internal/WalletLedgerJdbc.java` - JdbcClient wallet rows
- `backend/src/main/java/com/nomadgames/economy/internal/InventoryLoadoutJdbc.java` - free default inventory/loadout
- `backend/src/main/java/com/nomadgames/identity/GuestService.java` - mint-time ensureDefaults after flush

## Decisions Made

- Flush JPA player before JDBC ensureDefaults so FK inserts succeed in the same transaction
- Bind inventory timestamps as OffsetDateTime for JdbcClient/PostgreSQL
- Nested MatchRewardCommand / RewardGrant records reserved in EconomyService for 04-02

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] players.flush() before ensureDefaults**
- **Found during:** Task 2 (GuestService mint hook)
- **Issue:** JdbcClient INSERT into wallets failed FK because JPA had not flushed the new player row
- **Fix:** Call `players.flush()` after `players.save` before `economy.ensureDefaults`
- **Files modified:** `GuestService.java`
- **Verification:** EconomyIT wallet tests pass
- **Committed in:** `bb5fbb7`

**2. [Rule 1 - Bug] Instant → OffsetDateTime for inventory acquired_at**
- **Found during:** Task 2 (ensureDefaults inventory insert)
- **Issue:** PostgreSQL driver could not map `java.time.Instant` via JdbcClient
- **Fix:** Use `OffsetDateTime.now()` for acquired_at binds
- **Files modified:** `EconomyService.java`, `InventoryLoadoutJdbc.java`
- **Verification:** EconomyIT green
- **Committed in:** `bb5fbb7`

---

**Total deviations:** 2 auto-fixed (1 blocking, 1 bug)
**Impact on plan:** Required for mint-time ensureDefaults correctness; no scope creep.

## Issues Encountered

None beyond the auto-fixes above.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Ready for 04-02 match reward grants (ledger writers + MatchService hooks)
- Shop catalog / purchase / equip plans can build on V7 SKUs and ensureDefaults inventory
- forge2d pins unchanged; no Flutter edits this plan

## Self-Check: PASSED

- FOUND: V7__economy_ledger_shop.sql, EconomyController, EconomyService, WalletLedgerJdbc, InventoryLoadoutJdbc, EconomyIT, GuestService ensureDefaults
- FOUND commits: 37afea8, bb5fbb7

---
*Phase: 04-economy-cosmetic-shop*
*Completed: 2026-09-10*
