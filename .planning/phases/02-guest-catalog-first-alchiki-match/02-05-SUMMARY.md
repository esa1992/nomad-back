---
phase: 02-guest-catalog-first-alchiki-match
plan: 05
subsystem: match-rules
tags: [alchiki-rules, turn-clock, first-to-5, pause-overlay, leave-match]

requires:
  - phase: 02-guest-catalog-first-alchiki-match
    provides: REST throw authority (02-04); how-to fromPause (02-03); lifted match table (02-08)
provides:
  - AlchikiRules first-to-5 / 8 turns / 4:00 / 5:00 / 20s resolver
  - Single forfeitExpiredPlayerTurn; duplicate empty auto-POST is a no-op
  - POST /v1/matches/{id}/leave → BOT_WIN
  - MatchHud clocks from server Instants; Pause / Leave confirm / Result without rematch
affects:
  - 02-06 ScriptedBot afterPlayerHalfIfInPlay hook
  - Phase 3 rematch / rated forfeit

tech-stack:
  added: []
  patterns:
    - AlchikiRules.resolve order: hard cap, first-to-5, 8 turns each, 4:00, else IN_PLAY
    - tickClocks / expired POST / empty auto-POST share forfeitExpiredPlayerTurn
    - Leave is consented BOT_WIN; result has Back to catalog only

key-files:
  created:
    - backend/src/main/java/com/nomadgames/games/alchiki/AlchikiRules.java
    - backend/src/main/java/com/nomadgames/games/alchiki/MatchStatus.java
    - backend/src/main/java/com/nomadgames/session/LeaveResponse.java
    - backend/src/test/java/com/nomadgames/games/alchiki/AlchikiRulesTest.java
    - client/lib/games/alchiki/match_hud.dart
    - client/lib/games/alchiki/pause_overlay.dart
    - client/test/match_rules_hud_test.dart
  modified:
    - backend/src/main/java/com/nomadgames/session/MatchService.java
    - backend/src/main/java/com/nomadgames/session/MatchController.java
    - backend/src/main/java/com/nomadgames/session/MatchSnapshot.java
    - backend/src/main/java/com/nomadgames/session/internal/MatchEntity.java
    - backend/src/test/java/com/nomadgames/session/ThrowAuthorityIT.java
    - client/lib/games/alchiki/match_page.dart
    - client/lib/platform/api/nomad_api.dart
    - client/lib/platform/router.dart

key-decisions:
  - "AlchikiRules.resolve uses primitives / MatchClockState so games does not import session.MatchSnapshot"
  - "Empty POST is the forfeit/auto-POST path; a later valid impulse is a real throw after the new 20s deadline"
  - "Clock ticker starts only after startMatch succeeds so howto_test pumpAndSettle is not trapped"
  - "fromPause accepts 1 and true; Pause pushes /howto/alchiki?fromPause=1 without clearing seen"

patterns-established:
  - "Pattern: one forfeitExpiredPlayerTurn writer; GET tickClocks and empty POST share it"
  - "Pattern: afterPlayerHalfIfInPlay stays empty until 02-06 ScriptedBot"
  - "Pattern: result overlay has no rematch CTA (D-24)"

requirements-completed: [ALCH-03]

coverage:
  - id: D1
    description: First-to-5, 8 turns each, 4:00 match limit, and 5:00 hard cap resolve on the server
    requirement: ALCH-03
    verification:
      - kind: unit
        ref: "backend/src/test/java/com/nomadgames/games/alchiki/AlchikiRulesTest.java#resolveTable"
        status: pass
    human_judgment: false
  - id: D2
    description: 20s turn timeout forfeits once (displayedScore 0); duplicate empty POST does not increment playerTurns
    requirement: ALCH-03
    verification:
      - kind: integration
        ref: "backend/src/test/java/com/nomadgames/session/ThrowAuthorityIT.java#getThenPostSameDeadlineDoesNotIncrementPlayerTurnsTwice"
        status: pass
    human_judgment: false
  - id: D3
    description: POST /v1/matches/{id}/leave returns BOT_WIN
    requirement: ALCH-03
    verification:
      - kind: integration
        ref: "backend/src/test/java/com/nomadgames/session/ThrowAuthorityIT.java#leaveMatchReturnsBotWin"
        status: pass
    human_judgment: false
  - id: D4
    description: Match HUD shows You/Bot, First to 5, turn and match clocks, and Pause
    requirement: ALCH-03
    verification:
      - kind: automated_ui
        ref: "client/test/match_rules_hud_test.dart#match HUD shows you, bot, firstToFive, clocks, and pause"
        status: pass
    human_judgment: false
  - id: D5
    description: How to play from pause shows The circle and Back to match without clearing seen
    requirement: ALCH-03
    verification:
      - kind: automated_ui
        ref: "client/test/match_rules_hud_test.dart#fromPause how-to shows howtoCircleTitle and backToMatch"
        status: pass
    human_judgment: false
  - id: D6
    description: Pause / leave confirm / result overlay match 02-UI-SPEC (no rematch)
    verification: []
    human_judgment: true
    rationale: Widget tests lock copy keys; overlay dp, scrim, and destructive confirm still need owner visual UAT

duration: 20min
completed: 2026-09-06
status: complete
---

# Phase 2 Plan 05: Match Clocks Pause Leave Result Summary

**Server-authoritative first-to-5 / 8 turns / 4:00 / 5:00 / 20s clocks with a single forfeit path, pause how-to reopen, leave→BOT_WIN, and a rematch-free result overlay**

## Performance

- **Duration:** 20 min
- **Started:** 2026-09-06T16:59:00Z
- **Completed:** 2026-09-06T17:19:00Z
- **Tasks:** 2
- **Files modified:** 15

## Accomplishments

- A guest can finish a short match under published clocks (first to 5, else highest after 8 turns each or 4:00, hard cap 5:00)
- Turn timeout forfeits once (saka stays, displayedScore 0); GET tickClocks and a later empty POST do not double-increment playerTurns
- Pause opens Resume, How to play (`fromPause=1`, does not clear seen), and Leave match with destructive confirm that POSTs `/leave` → BOT_WIN
- Result overlay is You win / Bot wins / Draw plus Back to catalog — no rematch
- `afterPlayerHalfIfInPlay` stays empty so botScore remains 0 until 02-06

## Task Commits

Each task was committed atomically:

1. **Task 1: Write failing match-rules tests** - `543dee6` (test)
2. **Task 2: Server clocks plus pause, leave, and result** - `618603e` (feat)

**Plan metadata:** pending docs(02-05) complete match clocks plan

## Files Created/Modified

- `backend/src/main/java/com/nomadgames/games/alchiki/AlchikiRules.java` - FIRST_TO / TURNS_EACH / clocks and resolve order
- `backend/src/main/java/com/nomadgames/games/alchiki/MatchStatus.java` - IN_PLAY / PLAYER_WIN / BOT_WIN / DRAW
- `backend/src/main/java/com/nomadgames/session/MatchService.java` - tickClocks, forfeitExpiredPlayerTurn, leave, empty afterPlayerHalfIfInPlay
- `backend/src/main/java/com/nomadgames/session/MatchController.java` - GET /{id} and POST /{id}/leave
- `backend/src/main/java/com/nomadgames/session/MatchSnapshot.java` - turns and epoch clock fields
- `backend/src/main/java/com/nomadgames/session/LeaveResponse.java` - `{ match: snapshot }`
- `backend/src/test/java/com/nomadgames/games/alchiki/AlchikiRulesTest.java` - table-driven ALCH-03 cases
- `backend/src/test/java/com/nomadgames/session/ThrowAuthorityIT.java` - expired GET/POST no-op and leave
- `client/lib/games/alchiki/match_hud.dart` - You/Bot, firstToFive, clocks, turn banner
- `client/lib/games/alchiki/pause_overlay.dart` - Pause, LeaveConfirm, ResultOverlay
- `client/lib/games/alchiki/match_page.dart` - server clocks, auto-POST forfeit, pause/leave/result
- `client/lib/platform/api/nomad_api.dart` - leaveMatch and clock fields on MatchStart
- `client/lib/platform/router.dart` - fromPause=1 or true
- `client/test/match_rules_hud_test.dart` - HUD clocks and fromPause Back to match

## Decisions Made

- `AlchikiRules.resolve` takes primitives / `MatchClockState` so the games module does not import `session.MatchSnapshot` (avoids a session↔games cycle)
- Empty `/throws` body is the forfeit and duplicate auto-POST path; a later POST with aim+hold is a real throw after the new 20s deadline
- The HUD clock ticker starts only after `startMatch` succeeds so how-to `pumpAndSettle` is not trapped
- Pause How to play pushes `/howto/alchiki?fromPause=1`; the router accepts `1` and `true`

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] AlchikiRules must not import MatchSnapshot**
- **Found during:** Task 2 GREEN — session already consumes games via AlchikiEngine's GameEngine types
- **Issue:** `resolve(MatchSnapshot)` would make games → session while MatchService imports AlchikiRules (session → games)
- **Fix:** Resolve via primitives / `MatchClockState`; MatchService calls the primitive overload
- **Files modified:** `AlchikiRules.java`, `AlchikiRulesTest.java`, `MatchService.java`
- **Verification:** AlchikiRulesTest 12/12 pass
- **Committed in:** `618603e`

**2. [Rule 3 - Blocking] Periodic clock timer would hang howto_test pumpAndSettle**
- **Found during:** Task 2 GREEN
- **Issue:** `Timer.periodic` in `initState` keeps scheduling frames even when startMatch fails
- **Fix:** Start the ticker only after a successful `startMatch`
- **Files modified:** `client/lib/games/alchiki/match_page.dart`
- **Verification:** `flutter test test/howto_test.dart` passed
- **Committed in:** `618603e`

**3. [Rule 3 - Blocking] Jackson databind is not on the backend compile classpath**
- **Found during:** Task 2 GREEN compile
- **Issue:** `ObjectMapper` import failed under Spring Boot 4.1
- **Fix:** Detect a valid impulse with `"aimAngleRad"` / `"holdMs"` string contains
- **Files modified:** `MatchService.java`
- **Verification:** ThrowAuthorityIT 7/7 pass
- **Committed in:** `618603e`

---

**Total deviations:** 3 auto-fixed (3 blocking)
**Impact on plan:** Required for Modulith-safe rules, existing how-to tests, and compile. No rematch, no ScriptedBot.

## Issues Encountered

- Spring Boot 4.1 backend compile does not see `com.fasterxml.jackson.databind` as a direct import; impulse detection stayed string-based.
- Flame + a 200ms clock ticker both prevent `pumpAndSettle`; HUD tests use `pump()`, and the ticker is gated on a live match.

## Authentication Gates

None

## Known Stubs

- `afterPlayerHalfIfInPlay` is intentionally empty — 02-06 fills it with ScriptedBot; botScore stays 0 so a player can still reach first-to-5
- ScriptedBot is not implemented (out of this plan)

These stubs do not block ALCH-03 on the published clocks.

## Threat Flags

None — GET tickClocks and POST /leave are the plan `<threat_model>` mitigations (T-02-17, T-02-18). Client clocks remain display-only.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Ready for 02-06 ScriptedBot on `afterPlayerHalfIfInPlay`. Do not add rematch or rated forfeit. forge2d stays 0.14.2.

## TDD Gate Compliance

- RED commit `543dee6` `test(02-05): add failing test for match rules and HUD` — compile failed on missing AlchikiRules / MatchStart clock fields
- GREEN commit `618603e` `feat(02-05): implement match clocks, pause, leave, and result` — AlchikiRulesTest + ThrowAuthorityIT + match_rules_hud + match_hold + howto + replay_score passed

## Self-Check: PASSED

- FOUND: AlchikiRules.java, MatchService.java, MatchController.java, match_hud.dart, pause_overlay.dart, AlchikiRulesTest.java, match_rules_hud_test.dart, 02-05-SUMMARY.md
- FOUND: 543dee6 test(02-05), 618603e feat(02-05)
