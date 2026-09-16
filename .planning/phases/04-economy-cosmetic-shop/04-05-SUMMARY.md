---
phase: 04-economy-cosmetic-shop
plan: 05
subsystem: economy
tags: [equip, loadout, cosmetics, presentation-only, spring, flutter, forge2d]

requires:
  - phase: 04-economy-cosmetic-shop
    provides: soft purchase + inventory ownership (04-04)
  - phase: 04-economy-cosmetic-shop
    provides: shop catalog browse + ShopDetailPage chrome (04-03)
provides:
  - "POST /v1/shop/equip + GET /v1/loadout with ownership checks"
  - "Match create / snapshot seat loadout maps (local/host/joiner)"
  - "Client Equip CTA → Equipped; AlchikiMatchGame paint-only SKU fills"
  - "EconomyIT.equipOnCreate green"
affects:
  - phase-4 UAT (equip → next match look)
  - Stick Pull Phase 6 (stick_pull slot stored, ignored on Alchiki)

tech-stack:
  added: []
  patterns:
    - "Equip upserts loadout slot; never empty (D-55)"
    - "Server loadout on match create/rejoin; client paints at construction only (D-56/D-57)"
    - "SakaBody FixtureDef stays on TableConstants; SKU→Color fill/stripe only (D-54)"

key-files:
  created:
    - backend/src/main/java/com/nomadgames/economy/EquipRequest.java
    - backend/src/main/java/com/nomadgames/economy/EquipResult.java
  modified:
    - backend/src/main/java/com/nomadgames/economy/EconomyController.java
    - backend/src/main/java/com/nomadgames/economy/EconomyService.java
    - backend/src/main/java/com/nomadgames/economy/internal/InventoryLoadoutJdbc.java
    - backend/src/main/java/com/nomadgames/session/MatchService.java
    - backend/src/main/java/com/nomadgames/session/MatchSnapshot.java
    - backend/src/main/java/com/nomadgames/session/MatchCreatedResponse.java
    - backend/src/test/java/com/nomadgames/economy/EconomyIT.java
    - client/lib/platform/api/nomad_api.dart
    - client/lib/shop/shop_detail_page.dart
    - client/lib/games/alchiki/match_game.dart
    - client/lib/games/alchiki/match_page.dart
    - client/test/shop_wallet_test.dart

key-decisions:
  - "Loadout JDBC stays on InventoryLoadoutJdbc (no separate LoadoutJdbc) per 04-01 combine decision"
  - "MatchCreatedResponse.localLoadout for bot create; MatchSnapshot carries local/host/joiner maps for private/rejoin"
  - "Client recreates AlchikiMatchGame after startMatch/snapshot so paints apply at bout start only"

patterns-established:
  - "POST /v1/shop/equip {slot,skuId} → EquipResult; GET /v1/loadout → flat slot→sku map"
  - "fillForSku / stripeForLoadout map presentation SKUs; stick_pull ignored on Alchiki table"

requirements-completed: [ECON-03]

coverage:
  - id: D1
    description: "Equip owned SKU; GET loadout and bot match create include sku"
    requirement: ECON-03
    verification:
      - kind: integration
        ref: "backend/.../EconomyIT.java#equipOnCreate"
        status: pass
    human_judgment: false
  - id: D2
    description: "cosmetic_skus has no mass/friction gameplay columns"
    requirement: ECON-03
    verification:
      - kind: integration
        ref: "backend/.../EconomyIT.java#equipOnCreate"
        status: pass
    human_judgment: false
  - id: D3
    description: "Shop detail Equip CTA calls API and shows Equipped"
    requirement: ECON-03
    verification:
      - kind: automated_ui
        ref: "client/test/shop_wallet_test.dart#detail Equip calls equipSku then shows Equipped"
        status: pass
    human_judgment: false
  - id: D4
    description: "Match table applies presentation paints; physics feel unchanged (owner live check)"
    requirement: ECON-03
    verification: []
    human_judgment: true
    rationale: "Live table feel vs paint-only cannot be fully proven by widget/IT alone"

# Metrics
duration: 15min
completed: 2026-09-10
status: complete
---

# Phase 04 Plan 05: Equip Loadout + Presentation Paints Summary

**Server-authoritative equip/loadout on match create with presentation-only SakaBody fill/stripe paints (ECON-03, D-54–D-57)**

## Performance

- **Duration:** 15 min
- **Started:** 2026-09-10T08:47:27Z
- **Completed:** 2026-09-10T09:02:00Z
- **Tasks:** 3
- **Files modified:** 14

## Accomplishments

- EconomyIT.equipOnCreate: buy gold → equip → GET loadout → bot create includes `localLoadout.saka_color`
- POST `/v1/shop/equip` + GET `/v1/loadout`; MatchService attaches seat loadout maps on create/snapshot (covers rematch/rejoin GET)
- Shop Equip CTA → Equipped; AlchikiMatchGame maps SKU→fill/stripe at construction; FixtureDef still uses TableConstants; forge2d 0.14.2 / flame_forge2d 0.19.3+7 unchanged

## Task Commits

Each task was committed atomically:

1. **Task 1: Failing equipOnCreate IT** - `e2177b4` (test)
2. **Task 2: Equip REST + match create loadout attach** - `f5be92b` (feat)
3. **Task 3: Client equip CTA + presentation-only paints** - `9ada403` (feat)

**Plan metadata:** `d194ab1` (docs: complete plan; STATE follow-up may amend)

## Files Created/Modified

- `backend/.../EquipRequest.java` / `EquipResult.java` - equip body/result
- `backend/.../EconomyController.java` - `/v1/shop/equip`, `/v1/loadout`
- `backend/.../EconomyService.java` - equip + getLoadout
- `backend/.../InventoryLoadoutJdbc.java` - equipSlot + loadoutMap
- `backend/.../MatchCreatedResponse.java` / `MatchSnapshot.java` - loadout maps
- `backend/.../MatchService.java` - attach loadouts on create/snapshot
- `backend/.../EconomyIT.java` - equipOnCreate
- `client/.../nomad_api.dart` - equipSku + loadout parse on MatchStart
- `client/.../shop_detail_page.dart` - Equip / Equipped / errorEquip retry
- `client/.../match_game.dart` / `match_page.dart` - start-only paints from server loadout
- `client/test/shop_wallet_test.dart` - Equip CTA widget test

## Decisions Made

- Kept loadout helpers on `InventoryLoadoutJdbc` (plan listed optional `LoadoutJdbc`; prior phase combined inventory+loadout)
- Bot create exposes `localLoadout`; private snapshots expose `hostLoadout` / `joinerLoadout` / viewer `localLoadout`
- Client rebuilds `AlchikiMatchGame` after match create/snapshot so cosmetics never swap mid-throw

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] Loadout JDBC on InventoryLoadoutJdbc instead of new LoadoutJdbc**
- **Found during:** Task 2
- **Issue:** Plan `files_modified` listed `LoadoutJdbc.java`, but 04-01/04-04 established a single `InventoryLoadoutJdbc`
- **Fix:** Extended `InventoryLoadoutJdbc` with `equipSlot` / `loadoutMap` (no new class)
- **Files modified:** `InventoryLoadoutJdbc.java`
- **Verification:** EconomyIT.equipOnCreate + ModularityTest green
- **Committed in:** `f5be92b`

---

**Total deviations:** 1 auto-fixed (Rule 2)
**Impact on plan:** Correctness preserved; no new package/module surface.

## Issues Encountered

None

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Phase 4 cosmetic loop closed: grant → shop → buy → equip → next match presentation
- Owner UAT still needed for live table paint feel (coverage D4)
- Stick Pull skins persist in loadout for Phase 6; Alchiki ignores stick slot

## TDD Gate Compliance

- RED: `e2177b4` test(04-05): failing equipOnCreate
- GREEN: `f5be92b` feat server equip/loadout; `9ada403` feat client paints

## Self-Check: PASSED

- FOUND: EconomyIT.equipOnCreate, EconomyController `/v1/shop/equip`, MatchCreatedResponse.localLoadout, match_game fillForSku, saka_body TableConstants.friction, pubspec forge2d 0.14.2 / flame_forge2d 0.19.3+7
- FOUND commits: e2177b4, f5be92b, 9ada403

---
*Phase: 04-economy-cosmetic-shop*
*Completed: 2026-09-10*
