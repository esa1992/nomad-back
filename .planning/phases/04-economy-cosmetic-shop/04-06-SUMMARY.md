---
phase: 04-economy-cosmetic-shop
plan: 06
subsystem: ui
tags: [flutter, wallet-chip, gen-l10n, dio, go_router]

requires:
  - phase: 04-economy-cosmetic-shop
    provides: GET /v1/wallet returning server COINS/GEMS (04-01)
provides:
  - "Read-only dual wallet chip on catalog from NomadApi.fetchWallet"
  - "04-UI-SPEC Copywriting Contract ARB keys EN+RU"
  - "/shop wood placeholder route (shopTitle)"
  - "shop_wallet_test + catalog_test green"
affects:
  - 04-03 shop shelf grid
  - 04-02 result reward lines (ARB keys)
  - 04-04 soft purchase UI (chip remains display-only)

tech-stack:
  added: []
  patterns:
    - "Parallel Future.wait catalog+wallet with independent error surfaces"
    - "WalletChip display-only; balances never authorize buys (D-48)"

key-files:
  created:
    - client/lib/shop/wallet_chip.dart
    - client/test/shop_wallet_test.dart
  modified:
    - client/lib/l10n/app_en.arb
    - client/lib/l10n/app_ru.arb
    - client/lib/catalog/catalog_page.dart
    - client/lib/platform/api/nomad_api.dart
    - client/lib/platform/router.dart
    - client/test/catalog_test.dart

key-decisions:
  - "Parallel Future.wait for catalog+wallet so a failed wallet Future is never unhandled before await"
  - "catalog_test stubs fetchWallet to 0/0 so Dio does not inflate the catalog layout in widget tests"

patterns-established:
  - "WalletChip: wood fill, 1dp cream outline, Label 14, height 48, Semantics a11y, not a button"
  - "Catalog header trailing cluster: [WalletChip] [Shop outline] [EN] [RU]"

requirements-completed: [ECON-04]

coverage:
  - id: D1
    description: "Catalog shows COINS|GEMS chip from fake fetchWallet"
    requirement: ECON-04
    verification:
      - kind: automated_ui
        ref: "client/test/shop_wallet_test.dart#catalog shows wallet chip COINS/GEMS after fake fetchWallet"
        status: pass
    human_judgment: false
  - id: D2
    description: "Catalog shows Shop entry label"
    requirement: ECON-04
    verification:
      - kind: automated_ui
        ref: "client/test/shop_wallet_test.dart#catalog shows Shop entry label"
        status: pass
    human_judgment: false
  - id: D3
    description: "Wallet failure shows errorWallet without blocking catalog tiles or Shop"
    requirement: ECON-04
    verification:
      - kind: automated_ui
        ref: "client/test/shop_wallet_test.dart#wallet failure shows errorWallet without blocking tiles"
        status: pass
    human_judgment: false
  - id: D4
    description: "Existing catalog CTAs still find Play Alchiki / Create room"
    verification:
      - kind: automated_ui
        ref: "client/test/catalog_test.dart"
        status: pass
    human_judgment: false

duration: 18min
completed: 2026-09-10
status: complete
---

# Phase 4 Plan 06: Catalog Wallet Chip Summary

**Read-only COINS|GEMS catalog chip via NomadApi.fetchWallet, full 04-UI-SPEC ARB EN+RU, and /shop placeholder**

## Performance

- **Duration:** 18 min
- **Started:** 2026-09-10T13:40:35Z
- **Completed:** 2026-09-10T13:58:00Z
- **Tasks:** 2
- **Files modified:** 9

## Accomplishments

- Catalog header shows server wallet chip (display-only; D-48 / ECON-04)
- All 04-UI-SPEC Copywriting Contract keys landed in `app_en.arb` / `app_ru.arb`
- Wood Shop outline → `/shop` placeholder Scaffold titled `shopTitle`
- `shop_wallet_test` + `catalog_test` green

## Task Commits

Each task was committed atomically:

1. **Task 1: Failing shop_wallet_test + ARB keys** - `c355f6d` (test)
2. **Task 2: WalletChip + fetchWallet + catalog header** - `220bbd8` (feat)

**Plan metadata:** `e504b8f` (docs: complete plan)

## Files Created/Modified

- `client/lib/shop/wallet_chip.dart` - Read-only dual balance chip
- `client/test/shop_wallet_test.dart` - Chip + Shop + wallet-error coverage
- `client/lib/l10n/app_en.arb` / `app_ru.arb` - Phase 4 copywriting keys
- `client/lib/platform/api/nomad_api.dart` - `WalletBalance` + `fetchWallet` GET /v1/wallet
- `client/lib/catalog/catalog_page.dart` - Parallel wallet fetch, chip, Shop entry, errorWallet banner
- `client/lib/platform/router.dart` - `/shop` placeholder
- `client/test/catalog_test.dart` - Stub `fetchWallet` for layout stability

## Decisions Made

- Use `Future.wait` with per-call try/catch so a rejected wallet Future is never an unhandled async error while catalog is still loading
- Keep balances out of `FlutterSecureStorage`; chip is projection only (T-04-19 / T-04-20)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Unhandled wallet Future rejection before await**
- **Found during:** Task 2 (wallet failure widget test)
- **Issue:** Starting `fetchWallet()` then awaiting catalog first left a completed-with-error Future unhandled in the test zone
- **Fix:** Parallel `Future.wait` with independent try/catch per call
- **Files modified:** `client/lib/catalog/catalog_page.dart`
- **Verification:** `shop_wallet_test` wallet-failure case passes
- **Committed in:** `220bbd8` (Task 2)

**2. [Rule 3 - Blocking] catalog_test hit real Dio for wallet**
- **Found during:** Task 2 (catalog_test Stick Pull layout warning)
- **Issue:** New `fetchWallet` on catalog load caused connection failures / error banner and pushed Stick Pull off-screen in default 800×600 tests
- **Fix:** Override `fetchWallet` to return `0/0` in `_LocalCatalogApi`
- **Files modified:** `client/test/catalog_test.dart`
- **Verification:** `catalog_test` all green
- **Committed in:** `220bbd8` (Task 2)

---

**Total deviations:** 2 auto-fixed (1 bug, 1 blocking)
**Impact on plan:** Required for correct parallel load and existing catalog tests; no scope creep.

## Issues Encountered

None beyond the auto-fixed deviations above.

## Known Stubs

- `/shop` route is an intentional wood placeholder titled `shopTitle` — full shelf/grid is plan 04-03

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Catalog wallet chrome ready for shop grid (04-03) and purchase flows (04-04)
- ARB reward/price keys ready for result overlay (04-02)

---
*Phase: 04-economy-cosmetic-shop*
*Completed: 2026-09-10*

## Self-Check: PASSED
