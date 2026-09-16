---
phase: 02-guest-catalog-first-alchiki-match
plan: 08
subsystem: match-table
tags: [flutter, flame, forge2d, hold-throw, keyframe-replay, displayed-score]

requires:
  - phase: 02-guest-catalog-first-alchiki-match
    provides: REST startMatch/submitThrow (02-04); how-to gate to /match (02-03); splash mint (02-07)
provides:
  - AlchikiMatchPage holdEnabled gated on game.isLoaded
  - AlchikiMatchGame startTurn/resetSakaToRim at (0,-1.15) without resurrecting pocketed ids
  - ThrowResolved.sakaOut + displayedScore and AuthorityScore.displayedScore
  - TableConstants.matchTableId alchiki-match-v1
affects:
  - 02-05 match clocks and pause overlay
  - 02-06 scripted bot turn on the same table

tech-stack:
  added: []
  patterns:
    - holdEnabled = game.isLoaded && !throwing && !settled && !replaying && isPlayerTurn
    - HUD scored reads AuthorityScore.displayedScore from the REST body after keyframes start
    - After replay, resetSakaToRim snaps saka to SakaBody.spawn and drops pocketed bone ids

key-files:
  created:
    - client/lib/games/alchiki/match_page.dart
    - client/lib/games/alchiki/match_game.dart
    - client/test/match_hold_test.dart
  modified:
    - client/lib/replay/throw_resolved.dart
    - client/lib/replay/authority_score.dart
    - client/lib/schema/table_constants.dart
    - client/lib/platform/api/nomad_api.dart
    - client/lib/platform/router.dart
    - client/test/replay_score_test.dart

key-decisions:
  - "GameWidget attaches only after startMatch succeeds so howto_test pumpAndSettle is not trapped by the Flame ticker"
  - "Pocketed bones are removed from the bones list immediately; Flame removeFromParent is deferred and would leave isMounted true"
  - "submitThrow injects last ThrowInput into playerThrow JSON because PlayerThrowView has no input field"
  - "HUD first-to-5 line is First to 5 · {difficulty} so 02-03 howto_test still finds First to 5 · EASY"

patterns-established:
  - "Pattern: CR-01 holdEnabled requires game.isLoaded; throwSaka returns if !isLoaded"
  - "Pattern: CR-02 scored = displayedScore(); preview never copies into scored"
  - "Pattern: startTurn/resetSakaToRim after playerThrow keyframes; pocketed ids stay gone"

requirements-completed: [ALCH-01, ALCH-02, ALCH-05]

coverage:
  - id: D1
    description: Hold Throw is disabled until AlchikiMatchGame.isLoaded (CR-01)
    requirement: ALCH-01
    verification:
      - kind: automated_ui
        ref: "client/test/match_hold_test.dart#Hold Throw is not enabled before AlchikiMatchGame.isLoaded"
        status: pass
    human_judgment: false
  - id: D2
    description: Guest can aim, hold 150-1100 ms, and submit ThrowInput via POST /throws
    requirement: ALCH-01
    verification:
      - kind: automated_ui
        ref: "client/test/match_hold_test.dart#Hold Throw is not enabled before AlchikiMatchGame.isLoaded"
        status: pass
    human_judgment: true
    rationale: Widget test locks the isLoaded gate and Hold Throw chrome; a live aim+hold+REST turn is still owner UAT
  - id: D3
    description: HUD scored uses displayedScore; sakaOut true with pocketedCount 2 yields 0 (CR-02)
    requirement: ALCH-05
    verification:
      - kind: unit
        ref: "client/test/replay_score_test.dart#sakaOut true with pocketedCount 2 yields displayedScore 0"
        status: pass
    human_judgment: false
  - id: D4
    description: After keyframe replay, saka is at (0,-1.15) and pocketed bone ids stay gone
    requirement: ALCH-02
    verification:
      - kind: automated_ui
        ref: "client/test/match_hold_test.dart#after keyframe replay, saka is at -1.15 and pocketed bone stays gone"
        status: pass
    human_judgment: false
  - id: D5
    description: Felt table chrome (aim arrow, Hold Throw, power meter) matches Phase 1 palette on the match route
    verification: []
    human_judgment: true
    rationale: Automated tests assert Hold Throw copy and rim reset, not exact overlay dp or accent pulse

duration: 10min
completed: 2026-09-06
status: complete
---

# Phase 2 Plan 08: Lifted Match Table Summary

**Phase 1 Forge2D table lifted into AlchikiMatchPage with Hold Throw gated on isLoaded, REST displayedScore HUD, and rim reset at (0,-1.15)**

## Performance

- **Duration:** 10 min
- **Started:** 2026-09-06T16:47:14Z
- **Completed:** 2026-09-06T16:57:01Z
- **Tasks:** 2
- **Files modified:** 9

## Accomplishments

- Guest can open `/match`, start a BOT match, and complete an aim + Hold Throw + release turn
- Hold Throw stays disabled until `game.isLoaded`; `throwSaka` returns immediately when not loaded (CR-01)
- HUD `scored` reads `AuthorityScore.displayedScore` / `ThrowResolved.displayedScore` from the REST body; `sakaOut` with pockets is 0 (CR-02)
- After keyframe replay, `startTurn`/`resetSakaToRim` puts the saka at `(0,-1.15)` and does not resurrect pocketed bone ids
- `TableConstants.matchTableId` is `alchiki-match-v1`; proto `tableId` stays for the harness CLI

## Task Commits

Each task was committed atomically:

1. **Task 1: Write failing hold and rim-reset tests** - `3d72453` (test)
2. **Task 2: Lifted match table with rim reset** - `679cee8` (feat)

**Plan metadata:** pending docs(02-08) complete lifted match table plan

## Files Created/Modified

- `client/test/match_hold_test.dart` - CR-01 isLoaded hold gate and ALCH-05 rim-reset case
- `client/test/replay_score_test.dart` - parameterized `sakaOut` and displayedScore 0 case
- `client/lib/games/alchiki/match_page.dart` - Match chrome, Hold Throw, submitThrow, scored HUD
- `client/lib/games/alchiki/match_game.dart` - Lifted Forge2D table, applyPlayerThrow, resetSakaToRim
- `client/lib/replay/throw_resolved.dart` - required `sakaOut`, `pocketedIds`, `displayedScore()`
- `client/lib/replay/authority_score.dart` - `displayedScore` for match HUD
- `client/lib/schema/table_constants.dart` - `matchTableId = alchiki-match-v1`
- `client/lib/platform/api/nomad_api.dart` - `startMatch` and `submitThrow`
- `client/lib/platform/router.dart` - `/match` builds `AlchikiMatchPage`

## Decisions Made

- GameWidget mounts only after `startMatch` succeeds so how-to `pumpAndSettle` is not trapped by the Flame ticker
- Pocketed bones are dropped from the `bones` list immediately; Flame `removeFromParent` leaves `isMounted` true until the next tick
- `submitThrow` injects the last `ThrowInput` into `playerThrow` JSON because the server view has no `input` field
- The first-to-5 HUD line is `First to 5 · {difficulty}` so 02-03 howto_test still finds `First to 5 · EASY`

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Pocketed bone stayed mounted after removeFromParent**
- **Found during:** Task 2 GREEN — rim-reset case
- **Issue:** Flame defers `removeFromParent`, so `bone.isMounted` stayed true and `b1` was still in `bones`
- **Fix:** Drop pocketed ids from the `bones` list immediately, then remove the component
- **Files modified:** `client/lib/games/alchiki/match_game.dart`
- **Verification:** `flutter test test/match_hold_test.dart` passed
- **Committed in:** `679cee8`

**2. [Rule 3 - Blocking] Flame ticker would hang howto_test pumpAndSettle**
- **Found during:** Task 2 GREEN
- **Issue:** Replacing the wood `/match` placeholder with a live `GameWidget` would prevent `pumpAndSettle` from completing
- **Fix:** Attach `GameWidget` only after `startMatch` succeeds; howto tests use a catalog stub that does not start a match
- **Files modified:** `client/lib/games/alchiki/match_page.dart`
- **Verification:** `flutter test test/howto_test.dart test/catalog_test.dart` passed
- **Committed in:** `679cee8`

---

**Total deviations:** 2 auto-fixed (1 bug, 1 blocking)
**Impact on plan:** Required for ALCH-05 rim-reset assertions and to keep 02-03 howto_test green. No clocks or bot turn.

## Issues Encountered

- Flame `removeFromParent` is not synchronous; the rim-reset test required dropping ids from the live `bones` list.
- howto_test still asserts the 02-01 placeholder string `First to 5 · EASY`; the match HUD keeps that exact line.

## Authentication Gates

None

## Known Stubs

- Pause only toggles a local `_paused` flag — full pause/leave/result chrome is 02-05
- Bot half of the turn is not animated; Hold is hidden when `turn == BOT` but 02-06 owns the bot throw
- Match clocks are not shown or ticked (02-05)
- `GameWidget` is not mounted until `startMatch` succeeds, so a failed start shows the error banner on wood without felt

These stubs do not block ALCH-01 / ALCH-02 / ALCH-05 on the lifted table.

## Threat Flags

None — scored HUD and rim reset are the plan `<threat_model>` mitigations (T-02-14, T-02-24). `POST /v1/matches` and `/throws` already exist from 02-04.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Ready for 02-05 clocks/pause and 02-06 ScriptedBot on this lifted table. forge2d stays 0.14.2.

## TDD Gate Compliance

- RED commit `3d72453` `test(02-08): add failing test for hold and rim-reset` — compile failed on missing `AlchikiMatchPage` / `displayedScore`
- GREEN commit `679cee8` `feat(02-08): implement lifted match table with rim reset` — match_hold + replay_score + catalog + howto passed

## Self-Check: PASSED

- FOUND: match_page.dart, match_game.dart, throw_resolved.dart, authority_score.dart, table_constants.dart, nomad_api.dart, router.dart, match_hold_test.dart, 02-08-SUMMARY.md
- FOUND: 3d72453 test(02-08), 679cee8 feat(02-08)
