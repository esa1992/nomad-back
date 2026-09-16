---
phase: 05-casual-quick-match-profile
plan: 05
subsystem: ui
tags: [flutter, rematch, casual, createCasualMatch, RematchWindow, MODE-05]

requires:
  - phase: 05-casual-quick-match-profile
    provides: createCasualMatch + isHumanPvP + Wave 0 CasualRematchIT stubs
  - phase: 03-private-rooms-casual-reconnect
    provides: RematchWindow dual-accept + private Again? overlay
provides:
  - "acceptRematch → createCasualMatch when finished mode is CASUAL"
  - "Play again on casual result → /match/rematch-wait (not private Again?)"
  - "RematchWaitingPage 10s poll + Cancel rematch → catalog"
  - "Green CasualRematchIT + RematchIT + casual_rematch_test + rematch_overlay_test"
affects:
  - 05-06 profile
  - 05-07 avatar chip
  - phase UAT MODE-05

tech-stack:
  added: []
  patterns:
    - "acceptRematch branches createCasualMatch vs createPrivateMatch by finished mode"
    - "requirePrivateTerminal allows isHumanPvP terminals (seat-bound T-05-04)"
    - "Casual rematch chrome: dedicated wood route; private keeps overlay Again?"

key-files:
  created:
    - client/lib/games/alchiki/rematch_waiting_page.dart
  modified:
    - backend/src/main/java/com/nomadgames/session/MatchService.java
    - client/lib/games/alchiki/match_page.dart
    - client/lib/games/alchiki/pause_overlay.dart
    - client/lib/platform/router.dart
    - client/lib/l10n/app_en.arb
    - client/lib/l10n/app_ru.arb

key-decisions:
  - "RematchWaitingPage POSTs accept on init after navigation so result overlay leaves immediately (D-73)"
  - "Existing NomadApi.rematch/getRematch reused — no new client API surface"
  - "requirePrivateTerminal widened to isHumanPvP so CASUAL terminals open RematchWindow"

patterns-established:
  - "Casual rematch: Play again label + rematch-wait route; private: Again? + overlay timer"
  - "Dual-accept create branch keyed off finished match mode, seats from RematchWindow only"

requirements-completed: [MODE-05]

coverage:
  - id: D1
    description: "CASUAL dual-accept mints a new CASUAL match with the same seats"
    requirement: MODE-05
    verification:
      - kind: integration
        ref: "backend/.../CasualRematchIT.java#casualRematchCreatesCasualMatch"
        status: pass
    human_judgment: false
  - id: D2
    description: "Non-seat JWT cannot accept rematch (T-05-04)"
    requirement: MODE-05
    verification:
      - kind: integration
        ref: "backend/.../CasualRematchIT.java#casualRematchRequiresSeat"
        status: pass
    human_judgment: false
  - id: D3
    description: "Private rematch dual-accept still creates PRIVATE tables"
    requirement: MODE-05
    verification:
      - kind: integration
        ref: "backend/.../RematchIT.java"
        status: pass
    human_judgment: false
  - id: D4
    description: "Rematch-wait shows Waiting for rematch; Cancel rematch returns to catalog"
    requirement: MODE-05
    verification:
      - kind: automated_ui
        ref: "client/test/casual_rematch_test.dart#playAgainOpensRematchWait"
        status: pass
      - kind: automated_ui
        ref: "client/test/casual_rematch_test.dart#cancelRematchReturnsCatalog"
        status: pass
    human_judgment: false
  - id: D5
    description: "Private ResultOverlay still shows Again? not Play again chrome"
    requirement: MODE-05
    verification:
      - kind: automated_ui
        ref: "client/test/rematch_overlay_test.dart"
        status: pass
    human_judgment: false

duration: 6min
completed: 2026-09-11
status: complete
---

# Phase 5 Plan 05: Casual Rematch Summary

**CASUAL dual-accept rematch mints createCasualMatch tables with Play again → rematch-wait (10s), private Again? unchanged**

## Performance

- **Duration:** 6 min
- **Started:** 2026-09-11T11:06:21Z
- **Completed:** 2026-09-11T11:12:00Z
- **Tasks:** 2
- **Files modified:** 10

## Accomplishments

- `acceptRematch` calls `createCasualMatch` when the finished match is CASUAL; PRIVATE still uses `createPrivateMatch`
- Rematch eligibility accepts human PvP terminals (`isHumanPvP`) while staying seat-bound
- Casual result **Play again** leaves for `/match/rematch-wait`; waiting page polls RematchWindow and Cancel returns to catalog
- Private rematch overlay chrome (Again?) and RematchIT remain green

## Task Commits

Each task was committed atomically:

1. **Task 1: Backend CASUAL rematch createCasualMatch** - `4e97325` (feat)
2. **Task 2: Play again + rematch-waiting page** - `3fbdaab` (feat)

**Plan metadata:** `53af104` (docs: complete plan)

## Files Created/Modified

- `backend/src/main/java/com/nomadgames/session/MatchService.java` - CASUAL rematch create branch + human terminal eligibility
- `client/lib/games/alchiki/rematch_waiting_page.dart` - Wood waiting route, 10s clock, Cancel rematch
- `client/lib/games/alchiki/match_page.dart` - Casual Play again → rematch-wait
- `client/lib/games/alchiki/pause_overlay.dart` - Comment clarifies casual vs private rematch chrome
- `client/lib/platform/router.dart` - `/match/rematch-wait` route
- `client/lib/l10n/app_en.arb` / `app_ru.arb` (+ generated) - `rematchWaitingTitle`, `cancelRematch`

## Decisions Made

- Waiting page owns the rematch POST after navigation so the result overlay exits immediately (D-73)
- Reused existing `NomadApi.rematch` / `getRematch` — no new endpoints
- Widened `requirePrivateTerminal` to `isHumanPvP` so CASUAL settle can open a RematchWindow

## Deviations from Plan

None - plan executed exactly as written.

(Eligibility widen for CASUAL was specified in the plan action: rematch uses `isHumanPvP` so CASUAL terminals open RematchWindow.)

## Issues Encountered

None

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- MODE-05 casual rematch vertical slice complete
- Ready for 05-06 profile / 05-07 avatar chip
- Private rematch path intact for regression

## Self-Check: PASSED

- FOUND: MatchService.java, rematch_waiting_page.dart, CasualRematchIT.java, casual_rematch_test.dart, 05-05-SUMMARY.md
- FOUND commits: 4e97325, 3fbdaab
- contains createCasualMatch / cancelRematch / casualRematchCreatesCasualMatch / playAgainOpensRematchWait

---
*Phase: 05-casual-quick-match-profile*
*Completed: 2026-09-11*
