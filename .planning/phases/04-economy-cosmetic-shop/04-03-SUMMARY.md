---
phase: 04-economy-cosmetic-shop
plan: 03
subsystem: economy
tags: [shop-catalog, flutter, jdbcclient, spring, felt-preview, gen-l10n]

requires:
  - phase: 04-economy-cosmetic-shop
    provides: cosmetic_skus seed + inventory/loadout defaults (04-01)
  - phase: 04-economy-cosmetic-shop
    provides: WalletChip + /shop placeholder + shop ARB keys (04-06)
provides:
  - "GET /v1/shop/catalog flat SKU list with owned/equipped/free"
  - "ShopPage Shop|Owned + seven category chips + SKU grid"
  - "ShopDetailPage static felt preview (#1B6B3A) + Buy/Equip chrome"
  - "EconomyIT.catalogHasSevenCategories + shop_wallet_test green"
affects:
  - 04-04 soft purchases
  - 04-05 equip/loadout

tech-stack:
  added: []
  patterns:
    - "Flat ShopCatalog.skus + client groups by slot (D-52)"
    - "Empty/error shop never invents local SKUs (D-50 / T-04-08)"

key-files:
  created:
    - backend/src/main/java/com/nomadgames/economy/ShopCatalog.java
    - client/lib/shop/shop_page.dart
    - client/lib/shop/shop_detail_page.dart
  modified:
    - backend/src/main/java/com/nomadgames/economy/EconomyController.java
    - backend/src/main/java/com/nomadgames/economy/EconomyService.java
    - backend/src/main/java/com/nomadgames/economy/internal/InventoryLoadoutJdbc.java
    - backend/src/test/java/com/nomadgames/economy/EconomyIT.java
    - client/lib/platform/api/nomad_api.dart
    - client/lib/platform/router.dart
    - client/lib/l10n/app_en.arb
    - client/lib/l10n/app_ru.arb
    - client/test/shop_wallet_test.dart

key-decisions:
  - "Catalog API returns flat skus[]; client groups by locked slot order"
  - "Buy/Equip buttons visible per state matrix but network deferred to 04-04/04-05"
  - "Detail uses Navigator push (not ?sku=) to keep shelf segment/category in memory"

patterns-established:
  - "InventoryLoadoutJdbc.listCatalogForPlayer LEFT JOIN inventory + loadout"
  - "skuDisplayName / skuThemeSwatch helpers shared by shelf and detail"

requirements-completed: [ECON-02]

coverage:
  - id: D1
    description: "GET /v1/shop/catalog covers all seven ECON-02 slots with free defaults"
    requirement: ECON-02
    verification:
      - kind: integration
        ref: "backend/.../EconomyIT.java#catalogHasSevenCategories"
        status: pass
    human_judgment: false
  - id: D2
    description: "Tap Shop opens /shop with Owned segment and Saka color category"
    requirement: ECON-02
    verification:
      - kind: automated_ui
        ref: "client/test/shop_wallet_test.dart#tap Shop opens /shop with Owned segment and category label"
        status: pass
    human_judgment: false
  - id: D3
    description: "Shop empty/error paths show Retry and never invent local stock"
    requirement: ECON-02
    verification:
      - kind: automated_ui
        ref: "client/test/shop_wallet_test.dart#shop error/empty Retry"
        status: pass
    human_judgment: false
  - id: D4
    description: "Static felt preview disk #1B6B3A on shop detail"
    requirement: ECON-02
    verification:
      - kind: other
        ref: "client/lib/shop/shop_detail_page.dart Color(0xFF1B6B3A)"
        status: pass
    human_judgment: false

duration: 12min
completed: 2026-09-10
status: complete
---

# Phase 4 Plan 03: Shop Browse Summary

**Guest `/shop` browse with seven ECON-02 categories, server catalog, and static felt preview detail (Buy/Equip chrome deferred for network).**

## Performance

- **Duration:** 12 min
- **Started:** 2026-09-10T08:10:55Z
- **Completed:** 2026-09-10T08:22:00Z
- **Tasks:** 2
- **Files modified:** 16

## Accomplishments

- GET `/v1/shop/catalog` returns thin SKU set covering all seven slots with free defaults and owned/equipped flags for JWT guests
- `/shop` replaced placeholder with Shop|Owned segments, locked category chips, 2-col grid; detail shows felt disk preview
- Empty/error surfaces use `emptyShop*` / `errorShop` + Retry; no local fake stock; no IAP chrome

## Task Commits

Each task was committed atomically:

1. **Task 1: Failing shop catalog IT + shop_wallet route tests** - `9f848b7` (test)
2. **Task 2: GET shop catalog + /shop shelf and detail** - `97da75b` (feat)

**Plan metadata:** `0752996` (docs: complete plan; follow-up STATE position if needed)

## Files Created/Modified

- `backend/.../ShopCatalog.java` — flat catalog DTO
- `backend/.../EconomyController.java` — GET `/v1/shop/catalog`
- `backend/.../EconomyService.java` — `listCatalog` + ensureDefaults
- `backend/.../InventoryLoadoutJdbc.java` — catalog JOIN query
- `backend/.../EconomyIT.java` — `catalogHasSevenCategories`
- `client/lib/shop/shop_page.dart` — shelf UI
- `client/lib/shop/shop_detail_page.dart` — felt preview + Buy/Equip chrome
- `client/lib/platform/api/nomad_api.dart` — `fetchShopCatalog`
- `client/lib/platform/router.dart` — `/shop` → `ShopPage`
- `client/lib/l10n/app_*.arb` — SKU display names EN+RU
- `client/test/shop_wallet_test.dart` — shelf + empty/error coverage

## Decisions Made

- Flat `skus[]` response; Flutter groups by locked slot order (D-52)
- Buy/Equip UI states match owned/free/equipped from catalog; POST wiring left to 04-04/04-05
- Detail via `Navigator.push` so shelf keeps in-memory segment/category

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing critical functionality] Stub ShopCatalog types for RED overrides**
- **Found during:** Task 1 (failing shop catalog IT + shop_wallet route tests)
- **Issue:** Flutter RED tests needed overridable `fetchShopCatalog` before Task 2 wired Dio
- **Fix:** Added `ShopCatalog`/`ShopSku` models + stub method in Task 1; Task 2 replaced stub with real GET
- **Files modified:** `client/lib/platform/api/nomad_api.dart`
- **Verification:** RED flutter failures then GREEN after Task 2
- **Committed in:** `9f848b7` / `97da75b`

**Total deviations:** 1 auto-fixed (Rule 2)
**Impact on plan:** Necessary for compilable RED tests; no scope creep.

## Issues Encountered

None

## Known Stubs

| File | Stub | Reason |
|------|------|--------|
| `client/lib/shop/shop_detail_page.dart` | Buy `onTap` no-op | Soft purchase TX in 04-04 |
| `client/lib/shop/shop_detail_page.dart` | Equip `onTap` no-op | Equip/loadout API in 04-05 |

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Browse vertical slice ready. 04-04 can wire POST purchase; 04-05 equip. forge2d pins untouched; no IAP UI.

## Self-Check: PASSED

- FOUND: `backend/src/main/java/com/nomadgames/economy/ShopCatalog.java`
- FOUND: `client/lib/shop/shop_page.dart`
- FOUND: `client/lib/shop/shop_detail_page.dart`
- FOUND: commit `9f848b7`
- FOUND: commit `97da75b`

---
*Phase: 04-economy-cosmetic-shop*
*Completed: 2026-09-10*
