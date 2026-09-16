---
phase: 07-bind-ranked-ship
plan: 01
subsystem: testing
tags: [nyquist, wave0, bind, ranked, glicko, boards, analytics, flutter_test, testcontainers]

requires:
  - phase: 06-stick-pull
    provides: StickPullSimTest harness; CasualQueueIT / ReconnectIT patterns; Stick Pull catalog live
  - phase: 05-casual-quick-match-profile
    provides: Casual queue + profile Wave 0→GREEN pattern for IT stubs
  - phase: 02-guest-catalog-first-alchiki-match
    provides: GuestIdentityIT mint/refresh harness
provides:
  - "Wave 0 RED BindIT locking AUTH-02…04 + D-93 adopt trio"
  - "Wave 0 RED Glicko2Test locking MODE-04 / D-104 defaults + scores"
  - "Wave 0 RED RankedQueueIT locking guest 403 + RANKED pair"
  - "Wave 0 RED RankedSettleIT locking SoftElo isolation + Alchiki 0.5/0.5"
  - "Wave 0 RED RankedReconnectIT locking 18/12 grace + pause budget forfeit"
  - "Wave 0 RED BoardsIT locking LEAD-01…03"
  - "Wave 0 RED EventSinkIT locking ANLT-01 nine event types"
  - "Wave 0 RED StickPullSimTest.rankedFalseStart locking D-100"
  - "Wave 0 RED Flutter bind/boards/ranked search/reconnect HUD stubs"
affects:
  - 07-02 bind credentials
  - 07-03 login logout adopt
  - 07-04 ranked queue glicko
  - 07-05 ranked reconnect
  - 07-06 boards
  - 07-07 analytics CI
  - 07-08 ranked settle alchiki
  - 07-09 flutter ranked boards
  - 07-10 flutter bind soft-lock

tech-stack:
  added: []
  patterns:
    - "Wave 0 Nyquist stubs call future endpoints with andExpect success → RED 404 until later plans"
    - "Pure unit Wave 0 stubs use Assertions.fail with locked method names until production types exist"
    - "Client Wave 0 pumps NomadApp at future routes and asserts 07-UI-SPEC EN copy"

key-files:
  created:
    - backend/src/test/java/com/nomadgames/identity/BindIT.java
    - backend/src/test/java/com/nomadgames/rating/Glicko2Test.java
    - backend/src/test/java/com/nomadgames/matchmaking/RankedQueueIT.java
    - backend/src/test/java/com/nomadgames/session/RankedSettleIT.java
    - backend/src/test/java/com/nomadgames/session/RankedReconnectIT.java
    - backend/src/test/java/com/nomadgames/rating/BoardsIT.java
    - backend/src/test/java/com/nomadgames/analytics/EventSinkIT.java
    - client/test/bind_sheet_test.dart
    - client/test/boards_test.dart
    - client/test/ranked_search_test.dart
    - client/test/reconnect_hud_test.dart
  modified:
    - backend/src/test/java/com/nomadgames/games/stickpull/StickPullSimTest.java
    - .planning/phases/07-bind-ranked-ship/07-VALIDATION.md

key-decisions:
  - "Wave 0 only — no BindService, RankedQueueService, Glicko2 production class, EventSink, CI, or Flutter bind/boards UI"
  - "BindIT/RankedQueueIT/BoardsIT use GuestIdentityIT/CasualQueueIT SpringBootTest + postgres:18 harness"
  - "Glicko2Test/RankedSettleIT/RankedReconnectIT/EventSinkIT use fail() stubs so suite locks names without production packages"
  - "Flutter stubs assert 07-UI-SPEC EN strings (bindSheetTitle, rankedSearchingBody, pauseBudgetGone, boardsTitle)"

patterns-established:
  - "Phase 7 Wave 0 mirrors Phase 5/6: MockMvc future endpoints RED 404; unit fail() for unshipped packages"
  - "07-VALIDATION Wave 0 Gaps checkboxes mark stub files created RED; TokenService.rotate + CI remain open"

requirements-completed: [AUTH-02, AUTH-03, AUTH-04, MODE-04, SESS-03, LEAD-01, LEAD-02, LEAD-03, ANLT-01]

coverage:
  - id: D1
    description: "BindIT method names lock AUTH-02…04 + D-93 adopt contracts (RED until 07-02/07-03)"
    requirement: AUTH-02
    verification:
      - kind: integration
        ref: "backend/.../BindIT.java#loginNeverSumsOntoNonEmptyTarget"
        status: fail
    human_judgment: false
  - id: D2
    description: "Glicko2Test locks MODE-04 / D-104 defaults + win/loss/draw scores (RED until 07-04)"
    requirement: MODE-04
    verification:
      - kind: unit
        ref: "backend/.../Glicko2Test.java#defaultsMatchStack"
        status: fail
    human_judgment: false
  - id: D3
    description: "RankedQueueIT locks guest 403 + RANKED pair no-bot (RED until 07-04)"
    requirement: MODE-04
    verification:
      - kind: integration
        ref: "backend/.../RankedQueueIT.java#guestRejected"
        status: fail
    human_judgment: false
  - id: D4
    description: "RankedSettleIT locks SoftElo isolation + Alchiki 0.5/0.5 (RED until 07-04/07-08)"
    requirement: MODE-04
    verification:
      - kind: unit
        ref: "backend/.../RankedSettleIT.java#rankedSettleUpdatesGlickoNotSoftElo"
        status: fail
    human_judgment: false
  - id: D5
    description: "RankedReconnectIT locks SESS-03 18/12 grace + pause budget forfeit (RED until 07-05)"
    requirement: SESS-03
    verification:
      - kind: unit
        ref: "backend/.../RankedReconnectIT.java#rankedAlchikiGraceIsEighteenSeconds"
        status: fail
    human_judgment: false
  - id: D6
    description: "BoardsIT locks LEAD-01…03 bound-only skill boards (RED until 07-06)"
    requirement: LEAD-01
    verification:
      - kind: integration
        ref: "backend/.../BoardsIT.java#guestsExcluded"
        status: fail
    human_judgment: false
  - id: D7
    description: "EventSinkIT locks ANLT-01 nine event types (RED until 07-07)"
    requirement: ANLT-01
    verification:
      - kind: unit
        ref: "backend/.../EventSinkIT.java#emitsRegisteredOnBind"
        status: fail
    human_judgment: false
  - id: D8
    description: "Flutter Wave 0 stubs lock bind/boards/ranked search/reconnect HUD UI-SPEC keys (RED)"
    requirement: AUTH-02
    verification:
      - kind: automated_ui
        ref: "client/test/bind_sheet_test.dart#bindSheetTitle"
        status: fail
    human_judgment: false

duration: 12min
completed: 2026-09-14
status: complete
---

# Phase 7 Plan 01: Wave 0 Bind/Ranked Nyquist RED Stubs Summary

**Wave 0 failing IT/unit/widget stubs lock AUTH-02…04, MODE-04, SESS-03, LEAD-01…03, ANLT-01 before any bind/Ranked production code**

## Performance

- **Duration:** 12 min
- **Started:** 2026-09-14T17:14:04+06:00
- **Completed:** 2026-09-14T17:26:00+06:00
- **Tasks:** 2
- **Files modified:** 13

## Accomplishments
- Backend Wave 0: BindIT, Glicko2Test, RankedQueueIT, RankedSettleIT, RankedReconnectIT, BoardsIT, EventSinkIT + StickPullSimTest.rankedFalseStart
- Client Wave 0: bind_sheet_test, boards_test, ranked_search_test, reconnect_hud_test asserting 07-UI-SPEC EN keys
- 07-VALIDATION Wave 0 Gaps marked stub-created RED (including explicit RankedSettleIT row)

## Task Commits

Each task was committed atomically:

1. **Task 1: Scaffold backend Wave 0 RED ITs and Glicko unit stubs** - `36dbad9` (test)
2. **Task 2: Scaffold Flutter Wave 0 RED widget stubs and mark VALIDATION** - `3e3365a` (test)

**Plan metadata:** `cffd46a` (docs: complete plan)

_Note: TDD tasks may have multiple commits (test → feat → refactor)_

## Files Created/Modified
- `backend/src/test/java/com/nomadgames/identity/BindIT.java` - AUTH-02…04 + D-93 adopt RED MockMvc stubs
- `backend/src/test/java/com/nomadgames/rating/Glicko2Test.java` - MODE-04/D-104 unit fail stubs
- `backend/src/test/java/com/nomadgames/matchmaking/RankedQueueIT.java` - guest 403 + RANKED pair RED stubs
- `backend/src/test/java/com/nomadgames/session/RankedSettleIT.java` - SoftElo isolation + draw 0.5/0.5 fail stubs
- `backend/src/test/java/com/nomadgames/session/RankedReconnectIT.java` - 18/12 grace + pause budget fail stubs
- `backend/src/test/java/com/nomadgames/rating/BoardsIT.java` - LEAD boards RED MockMvc stubs
- `backend/src/test/java/com/nomadgames/analytics/EventSinkIT.java` - ANLT-01 nine-event fail stubs
- `backend/src/test/java/com/nomadgames/games/stickpull/StickPullSimTest.java` - rankedFalseStart D-100 stub
- `client/test/bind_sheet_test.dart` - bindSheetTitle / soft-lock / D-92 funnel
- `client/test/boards_test.dart` - boardsTitle + season/all-time
- `client/test/ranked_search_test.dart` - rankedSearchingBody; no bot/invite (D-98)
- `client/test/reconnect_hud_test.dart` - pauseBudgetGone / leaveRankedBody
- `.planning/phases/07-bind-ranked-ship/07-VALIDATION.md` - Wave 0 stubs marked created RED

## Decisions Made
- Wave 0 only — no BindService, RankedQueueService, Glicko2 production class, EventSink, CI workflow, or Flutter bind/boards UI
- BindIT/RankedQueueIT/BoardsIT mirror CasualQueueIT SpringBootTest + postgres:18; settle/reconnect/analytics/Glicko unit stubs use fail() until packages exist
- Flutter stubs pump NomadApp at `/boards`, `/matchmaking?mode=ranked`, `/profile` and assert 07-UI-SPEC EN copy

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None — targeted Maven suite 24/24 failures (0 errors); Flutter stubs 0/11 passed as expected RED.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Wave 0 method names locked for 07-02…07-10 to turn RED→GREEN
- Production bind/Ranked/Glicko/boards/EventSink/CI must not land until their plans
- Open VALIDATION gaps: TokenService.rotate bound claim; CI workflow meta

## Self-Check: PASSED
- FOUND: BindIT.java, Glicko2Test.java, RankedQueueIT.java, RankedSettleIT.java, RankedReconnectIT.java, BoardsIT.java, EventSinkIT.java
- FOUND: bind_sheet_test.dart, boards_test.dart, ranked_search_test.dart, reconnect_hud_test.dart
- FOUND: commits 36dbad9, 3e3365a

---
*Phase: 07-bind-ranked-ship*
*Completed: 2026-09-14*
