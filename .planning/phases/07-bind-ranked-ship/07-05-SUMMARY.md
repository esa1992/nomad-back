---
phase: 07-bind-ranked-ship
plan: 05
subsystem: session
tags: [ranked, reconnect, pause-budget, SESS-03, D-101, D-102, D-103, flutter, spring]

requires:
  - phase: 07-bind-ranked-ship
    provides: Ranked queue + createRankedMatch (07-04)
  - phase: 07-bind-ranked-ship
    provides: Glicko settle on Ranked terminal (07-08)
  - phase: 03-private-rooms-casual-reconnect
    provides: ReconnectPolicy grace + LiveMatch freeze (SESS-02)
provides:
  - "ReconnectPolicy mode+game grace Ranked 18/12; Casual 30/8"
  - "Ranked pause budgets 45/20 with pauseUsedMs → immediate rated forfeit"
  - "HUD pauseBudgetGone + leaveRankedBody; server timer caps"
affects:
  - 07-06 / 07-07 remaining phase plans
  - UAT reconnect grace tuning

tech-stack:
  added: []
  patterns:
    - "graceSeconds(mode, game) + pauseBudgetSeconds(mode, game)"
    - "LiveMatch.pauseUsedMs accrue while any seat in grace"
    - "Client display clamp only — server SoT secondsLeft / pauseBudgetGone"

key-files:
  created:
    - backend/src/test/java/com/nomadgames/session/RankedReconnectIT.java
    - client/lib/games/shared/reconnect_banner.dart
    - client/lib/games/stick_pull/stick_pull_hud.dart
  modified:
    - backend/src/main/java/com/nomadgames/session/internal/ReconnectPolicy.java
    - backend/src/main/java/com/nomadgames/session/internal/MatchSessionRegistry.java
    - backend/src/main/java/com/nomadgames/session/MatchService.java
    - backend/src/main/java/com/nomadgames/session/MatchSnapshot.java
    - client/lib/games/alchiki/match_hud.dart
    - client/lib/games/alchiki/match_page.dart
    - client/lib/games/stick_pull/stick_pull_match_page.dart
    - client/lib/l10n/app_en.arb
    - client/lib/l10n/app_ru.arb
    - client/test/reconnect_hud_test.dart

key-decisions:
  - "pauseUsedMs accrues while any seat is in grace; budget check on next drop"
  - "MatchSnapshot.pauseBudgetGone NON_NULL only when true"
  - "Client graceCap Ranked Alchiki 18 / Stick 12 — display clamp only"

patterns-established:
  - "ReconnectBanner shared chrome for Alchiki HUD + Stick Pull"
  - "Ranked leave confirm uses leaveRankedBody (rated loss)"

requirements-completed: [SESS-03]

coverage:
  - id: D1
    description: "Ranked Alchiki reconnect grace ≤18s"
    requirement: SESS-03
    verification:
      - kind: integration
        ref: "backend/src/test/java/com/nomadgames/session/RankedReconnectIT.java#rankedAlchikiGraceIsEighteenSeconds"
        status: pass
    human_judgment: false
  - id: D2
    description: "Ranked Stick Pull reconnect grace ≤12s"
    requirement: SESS-03
    verification:
      - kind: integration
        ref: "backend/src/test/java/com/nomadgames/session/RankedReconnectIT.java#rankedStickPullGraceIsTwelveSeconds"
        status: pass
    human_judgment: false
  - id: D3
    description: "Pause budget exhausted → immediate rated forfeit, no bot-fill"
    requirement: SESS-03
    verification:
      - kind: integration
        ref: "backend/src/test/java/com/nomadgames/session/RankedReconnectIT.java#pauseBudgetExhaustedImmediateForfeit"
        status: pass
    human_judgment: false
  - id: D4
    description: "Casual grace regression 30/8 unchanged"
    requirement: SESS-03
    verification:
      - kind: integration
        ref: "backend/src/test/java/com/nomadgames/session/ReconnectIT.java + StickPullReconnectIT"
        status: pass
    human_judgment: false
  - id: D5
    description: "HUD pauseBudgetGone + leaveRankedBody + Ranked timer caps"
    requirement: SESS-03
    verification:
      - kind: automated_ui
        ref: "client/test/reconnect_hud_test.dart"
        status: pass
    human_judgment: false

duration: 25min
completed: 2026-09-14
status: complete
---

# Phase 07 Plan 05: Ranked reconnect 18s/12s + pause budgets Summary

**Ranked reconnect enforces Alchiki 18s / Stick Pull 12s grace with 45s/20s pause budgets, rated forfeit without bot-fill, and HUD copy driven by server timers (SESS-03 / D-101…D-103).**

## Performance

- **Duration:** 25 min
- **Started:** 2026-09-14T14:48:05Z
- **Completed:** 2026-09-14T15:12:45Z
- **Tasks:** 2
- **Files modified:** 18

## Accomplishments

- Extended `ReconnectPolicy` with mode+game grace and Ranked pause budgets; Casual stays 30/8
- `LiveMatch.pauseUsedMs` accrues during grace; next drop after budget → immediate rated forfeit (Glicko via existing `afterTerminal`)
- Flutter HUD shows server-capped reconnect timers, `pauseBudgetGone`, and `leaveRankedBody` on Ranked leave

## Task Commits

Each task was committed atomically:

1. **Task 1: Ranked grace + pause budget forfeit on server** - `b3f04c5` (feat)
2. **Task 2: Ranked reconnect HUD + leave rated-loss copy** - `5fa6e03` (feat)

**Plan metadata:** `949f0f4` (docs: complete plan)

## Files Created/Modified

- `backend/.../ReconnectPolicy.java` - mode+game grace + pauseBudgetSeconds
- `backend/.../MatchSessionRegistry.java` - pauseUsedMs / pauseBudgetGone on LiveMatch
- `backend/.../MatchService.java` - accrue + budget forfeit path in markDropped
- `backend/.../MatchSnapshot.java` - pauseBudgetGone projection
- `backend/.../RankedReconnectIT.java` - SESS-03 integration coverage
- `client/lib/games/shared/reconnect_banner.dart` - shared reconnect chrome
- `client/lib/games/stick_pull/stick_pull_hud.dart` - Stick Pull reconnect wrapper
- `client/lib/games/alchiki/match_*.dart` + stick_pull_match_page - caps + leave copy
- `client/lib/l10n/app_*.arb` - pauseBudgetGone, leaveRankedBody EN/RU
- `client/test/reconnect_hud_test.dart` - UI-SPEC key assertions

## Decisions Made

- Aggregate pause accrues while any seat is in grace; budget gate runs on the *next* disconnect
- `pauseBudgetGone` omitted from JSON unless true (`NON_NULL`)
- Client graceCap is display-only; forfeit timing remains server SoT

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Shorten RankedReconnectIT bind usernames**
- **Found during:** Task 1
- **Issue:** NanoTime usernames exceeded BindService `^[A-Za-z0-9_]{3,20}$` → HTTP 400
- **Fix:** Use short unique `rca`/`rcb` + base36 suffix
- **Files modified:** `RankedReconnectIT.java`
- **Committed in:** `b3f04c5`

**2. [Rule 1 - Bug] Poll GET after budget forfeit instead of WS-only await**
- **Found during:** Task 1 (`pauseBudgetExhaustedImmediateForfeit`)
- **Issue:** MatchSettled could race TX commit; GET briefly still IN_PLAY
- **Fix:** Poll match status until HOST_WIN (or fail with host message dump)
- **Files modified:** `RankedReconnectIT.java`
- **Committed in:** `b3f04c5`

---

**Total deviations:** 2 auto-fixed (1 blocking, 1 bug)
**Impact on plan:** Required for green ITs; no scope creep.

## Issues Encountered

None beyond the deviations above.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- SESS-03 closed for Ranked reconnect + pause budgets
- Remaining incomplete plans in phase 7: 07-06, 07-07

## Self-Check: PASSED

- FOUND: `backend/src/main/java/com/nomadgames/session/internal/ReconnectPolicy.java`
- FOUND: `backend/src/test/java/com/nomadgames/session/RankedReconnectIT.java`
- FOUND: `client/lib/games/shared/reconnect_banner.dart`
- FOUND: `client/test/reconnect_hud_test.dart`
- FOUND: commit `b3f04c5`
- FOUND: commit `5fa6e03`

---
*Phase: 07-bind-ranked-ship*
*Completed: 2026-09-14*
