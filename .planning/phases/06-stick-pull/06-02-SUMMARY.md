---
phase: 06-stick-pull
plan: 02
subsystem: ui
tags: [catalog, howto, stick-pull, flutter, spring, CAT-02, STICK-05, i18n]

requires:
  - phase: 06-stick-pull
    provides: Wave 0 RED CatalogIT.stickPullTileIsPlayable + howto_stick_pull_test + catalog Stick Pull CTA stubs
  - phase: 02-guest-catalog-first-alchiki-match
    provides: _AlchikiTile chrome, HowToSeenStore, /howto/alchiki pager pattern
provides:
  - "CatalogService stick_pull PLAYABLE (CAT-02)"
  - "_StickPullTile with QM / Play Stick Pull / Create Stick Pull room + EASY/NORMAL/HARD chips"
  - "lastStickPullBotDifficultyProvider separate from Alchiki"
  - "StickPullHowToPage five-card EN+RU pager at /howto/stick-pull"
  - "howto.stickpull.seen dedicated seen key (D-84, D-85)"
affects:
  - 06-03 StickPullSim / bot match start from how-to gate
  - 06-04 private/QM server game column for Stick Pull CTAs
  - 06-05 Stick Pull match HUD pause → how-to reopen

tech-stack:
  added: []
  patterns:
    - "Stick Pull catalog tile mirrors _AlchikiTile felt band + accent QM; third outline CTA Create Stick Pull room"
    - "Bot chip memory is per-game Notifier (lastStickPullBotDifficultyProvider) — never clobber Alchiki"
    - "How-to seen keys are per-title SharedPreferencesAsync bools; markStickPullSeen must not clear Alchiki"

key-files:
  created:
    - client/lib/howto/stick_pull_howto_page.dart
  modified:
    - backend/src/main/java/com/nomadgames/catalog/CatalogService.java
    - client/lib/catalog/catalog_page.dart
    - client/lib/catalog/catalog_models.dart
    - client/lib/howto/howto_seen_store.dart
    - client/lib/platform/router.dart
    - client/lib/l10n/app_en.arb
    - client/lib/l10n/app_ru.arb
    - client/test/catalog_test.dart
    - client/test/howto_stick_pull_test.dart

key-decisions:
  - "Stick Pull how-to diagrams are inline CustomPaint parlor-hex stubs in stick_pull_howto_page — no new asset pack this plan"
  - "howto_seen_store Stick Pull APIs shipped in Task 1 so catalog gate compiles before the pager route exists"
  - "Match after Skip still routes to AlchikiMatchPage with game=stickPull query until 06-03 owns Stick Pull match UI"

patterns-established:
  - "Catalog playable second title: else-if stick_pull PLAYABLE → _StickPullTile; more_games stays Coming Soon"
  - "Stick Pull how-to route mirrors /howto/alchiki query params (difficulty, fromPause, mode, matchId) plus game=stickPull on exit"

requirements-completed: [CAT-02, STICK-05]

coverage:
  - id: D1
    description: "CatalogIT stick_pull PLAYABLE; more_games Coming Soon (CAT-02)"
    requirement: CAT-02
    verification:
      - kind: integration
        ref: "backend/src/test/java/com/nomadgames/catalog/CatalogIT.java#stickPullTileIsPlayable"
        status: pass
    human_judgment: false
  - id: D2
    description: "Catalog Stick Pull tile shows Quick Match, Play Stick Pull, Create Stick Pull room; Coming Soon only on More games"
    requirement: CAT-02
    verification:
      - kind: automated_ui
        ref: "client/test/catalog_test.dart#Stick Pull tile shows Quick Match Play Stick Pull and Create Stick Pull room"
        status: pass
    human_judgment: false
  - id: D3
    description: "Five-card Stick Pull how-to EN+RU with Skip → howto.stickpull.seen (STICK-05)"
    requirement: STICK-05
    verification:
      - kind: automated_ui
        ref: "client/test/howto_stick_pull_test.dart#Play Stick Pull opens pager with Sit opposite and Skip on card 1"
        status: pass
    human_judgment: false

duration: 27min
completed: 2026-09-14
status: complete
---

# Phase 6 Plan 02: Catalog PLAYABLE + Stick Pull How-To Summary

**Stick Pull is PLAYABLE on the catalog with bot chips and three CTAs, gated by a skippable five-card EN+RU how-to that persists `howto.stickpull.seen` without touching Alchiki.**

## Performance

- **Duration:** 27 min
- **Started:** 2026-09-14T06:18:32Z
- **Completed:** 2026-09-14T06:45:11Z
- **Tasks:** 2/2
- **Files modified:** 12

## Accomplishments

- Server catalog flips `stick_pull` to PLAYABLE; CatalogIT CAT-02 green
- `_StickPullTile` ships Quick Match, Play Stick Pull, Create Stick Pull room + EASY/NORMAL/HARD chips on a separate difficulty provider
- `/howto/stick-pull` five-card pager with Skip / Next / accent Play Stick Pull; STICK-05 widget tests green

## Task Commits

Each task was committed atomically:

1. **Task 1: Catalog PLAYABLE + Stick Pull tile CTAs** - `367f93c` (feat)
2. **Task 2: Stick Pull how-to pager + seen store** - `b485eae` (feat)

**Plan metadata:** `72d2e2c` (docs: complete plan)

## Files Created/Modified

- `backend/.../CatalogService.java` — stick_pull → PLAYABLE
- `client/lib/catalog/catalog_page.dart` — `_StickPullTile` + how-to gate + Stick Pull QM/create handlers
- `client/lib/catalog/catalog_models.dart` — playable local snapshot + `lastStickPullBotDifficultyProvider`
- `client/lib/howto/howto_seen_store.dart` — `howto.stickpull.seen` APIs
- `client/lib/howto/stick_pull_howto_page.dart` — five-card pager + static diagrams
- `client/lib/platform/router.dart` — `/howto/stick-pull`
- `client/lib/l10n/app_en.arb` / `app_ru.arb` — CTA + how-to strings
- `client/test/catalog_test.dart` / `howto_stick_pull_test.dart` — CAT-02 / STICK-05 greens

## Decisions Made

- Inline CustomPaint how-to diagrams (parlor hexes) instead of new image assets
- Stick Pull seen helpers landed with Task 1 so the Play Stick Pull gate compiles before the pager route
- Post-how-to `/match?game=stickPull` still mounts AlchikiMatchPage until 06-03

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Catalog regression tests expected one Easy / Quick Match / two Coming Soon**
- **Found during:** Task 1 (Catalog PLAYABLE + Stick Pull tile CTAs)
- **Issue:** Promoting Stick Pull added a second chip row and QM CTA; Coming Soon count dropped to one
- **Fix:** Updated catalog_test expectations to `findsNWidgets(2)` for Easy/selected chips/Quick Match and `findsOneWidget` for Coming Soon
- **Files modified:** `client/test/catalog_test.dart`
- **Verification:** `flutter test test/catalog_test.dart` all passed
- **Committed in:** `367f93c`

**2. [Rule 2 - Missing critical]** Stick Pull seen APIs needed for catalog gate before Task 2 pager
- **Found during:** Task 1
- **Issue:** `_playStickPull` must call `isStickPullSeen` but store APIs were listed only under Task 2
- **Fix:** Added `stickPullSeenKey` / `isStickPullSeen` / `markStickPullSeen` in Task 1; Task 2 consumed them from the pager
- **Files modified:** `client/lib/howto/howto_seen_store.dart`
- **Verification:** Catalog + how-to tests green
- **Committed in:** `367f93c` (APIs) / `b485eae` (pager usage)

**3. [Rule 1 - Bug] Wave 0 howto_stick_pull_test did not inject HowToSeenStore; Play CTA off-screen**
- **Found during:** Task 2
- **Issue:** Memory store was unused; Skip could not assert seen; Play Stick Pull sat below 600px viewport
- **Fix:** Extended HowToSeenStore memory subclass + provider override; `ensureVisible` before catalog tap
- **Files modified:** `client/test/howto_stick_pull_test.dart`
- **Verification:** `flutter test test/howto_stick_pull_test.dart` all passed
- **Committed in:** `b485eae`

**Total deviations:** 3 auto-fixed (Rule 1 ×2, Rule 2 ×1)
**Impact on plan:** Required for green CAT-02/STICK-05; no scope creep into sim/HUD/WS.

## Issues Encountered

None beyond the deviations above.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Catalog + how-to gate ready for 06-03 StickPullSim / bot match start
- Create Stick Pull room / QM still use existing Alchiki room/queue APIs with `game=stickPull` query — server game column greens in 06-04
- Leave StickPullSim/Bot/reconnect RED stubs for later plans

## Self-Check: PASSED

- FOUND: `backend/src/main/java/com/nomadgames/catalog/CatalogService.java`
- FOUND: `client/lib/howto/stick_pull_howto_page.dart`
- FOUND: `client/lib/howto/howto_seen_store.dart` (`howto.stickpull.seen`)
- FOUND: commit `367f93c`
- FOUND: commit `b485eae`

---
*Phase: 06-stick-pull*
*Completed: 2026-09-14*
