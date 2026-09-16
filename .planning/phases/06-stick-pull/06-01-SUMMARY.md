---
phase: 06-stick-pull
plan: 01
subsystem: testing
tags: [nyquist, wave0, stick-pull, stamina, reconnect, catalog, flutter_test, testcontainers, junit]

requires:
  - phase: 05-casual-quick-match-profile
    provides: CasualQueueIT / ReconnectIT harness; catalog Quick Match patterns
  - phase: 03-private-rooms-casual-reconnect
    provides: ReconnectIT WS CollectingListener; 30s Alchiki grace
provides:
  - "Wave 0 RED StickPullSimTest locking STICK-01…04 / D-88 / D-89 / D-91"
  - "Wave 0 RED StickPullBotTest locking BOT-02 jitter envelopes"
  - "Wave 0 RED StickPullIT locking Countdown/TapInput/MatchSettled WS path"
  - "Wave 0 RED StickPullReconnectIT locking SESS-04 8s forfeit + no bot-fill"
  - "Wave 0 RED CatalogIT.stickPullTileIsPlayable + CasualQueueIT isolation"
  - "Wave 0 RED Flutter howto_stick_pull_test + catalog Stick Pull CTAs"
affects:
  - 06-02 catalog PLAYABLE + how-to ARB/route
  - 06-03 StickPullSim / StickPullBot / MatchService STICK_PULL
  - 06-04 rooms.game + per-game casual FIFO
  - 06-05 ReconnectPolicy.graceFor + Stick Pull match UI

tech-stack:
  added: []
  patterns:
    - "Wave 0 pure-unit stubs use Assertions.fail with locked method names until production types exist"
    - "Wave 0 ITs assert future STICK_PULL createMatch / rooms.game / WS frames → RED 400 until later plans"
    - "Client Wave 0 pumps NomadApp and asserts 06-UI-SPEC EN copy (howtoStickSitTitle → Sit opposite)"

key-files:
  created:
    - backend/src/test/java/com/nomadgames/games/stickpull/StickPullSimTest.java
    - backend/src/test/java/com/nomadgames/games/stickpull/StickPullBotTest.java
    - backend/src/test/java/com/nomadgames/session/StickPullIT.java
    - backend/src/test/java/com/nomadgames/session/StickPullReconnectIT.java
    - client/test/howto_stick_pull_test.dart
  modified:
    - backend/src/test/java/com/nomadgames/catalog/CatalogIT.java
    - backend/src/test/java/com/nomadgames/matchmaking/CasualQueueIT.java
    - backend/src/test/java/com/nomadgames/session/ReconnectIT.java
    - client/test/catalog_test.dart

key-decisions:
  - "Wave 0 only — no StickPullSim, Catalog PLAYABLE flip, MatchService STICK_PULL branching, or Flutter Stick Pull match UI"
  - "StickPullSimTest/BotTest use fail() stubs so suite compiles without production stickpull package"
  - "alchikiGraceStillThirty stays green today as SESS-02 regression lock; Stick Pull 8s stubs stay RED"

patterns-established:
  - "StickPullIT / StickPullReconnectIT copy ReconnectIT RANDOM_PORT + CollectingListener"
  - "CatalogIT.stickPullTileIsPlayable replaces COMING_SOON expectation for stick_pull; more_games stays COMING_SOON"

requirements-completed: [CAT-02, STICK-01, STICK-02, STICK-03, STICK-04, STICK-05, BOT-02, SESS-04]

coverage:
  - id: D1
    description: "StickPullSimTest method names lock STICK-01…04 stamina/clamp/clock (RED until 06-03)"
    requirement: STICK-01
    verification:
      - kind: unit
        ref: "backend/.../StickPullSimTest.java#softBandFullForce"
        status: fail
    human_judgment: false
  - id: D2
    description: "StickPullBotTest locks BOT-02 EASY/NORMAL/HARD mean TPS + pauses (RED until 06-03)"
    requirement: BOT-02
    verification:
      - kind: unit
        ref: "backend/.../StickPullBotTest.java#easyMeanTpsInBand"
        status: fail
    human_judgment: false
  - id: D3
    description: "StickPullIT locks Countdown/TapInput/MatchSettled WS path (RED until 06-03)"
    requirement: STICK-01
    verification:
      - kind: integration
        ref: "backend/.../StickPullIT.java#countdownThenTapMovesMarker"
        status: fail
    human_judgment: false
  - id: D4
    description: "StickPullReconnectIT locks SESS-04 8s forfeit + no bot-fill (RED until 06-05)"
    requirement: SESS-04
    verification:
      - kind: integration
        ref: "backend/.../StickPullReconnectIT.java#stickPullGraceIsEightSeconds"
        status: fail
    human_judgment: false
  - id: D5
    description: "CatalogIT.stickPullTileIsPlayable + CasualQueueIT isolation (RED until 06-02 / 06-04)"
    requirement: CAT-02
    verification:
      - kind: integration
        ref: "backend/.../CatalogIT.java#stickPullTileIsPlayable"
        status: fail
    human_judgment: false
  - id: D6
    description: "Flutter howto_stick_pull_test + catalog Stick Pull CTAs (RED until 06-02)"
    requirement: STICK-05
    verification:
      - kind: automated_ui
        ref: "client/test/howto_stick_pull_test.dart#Sit opposite"
        status: fail
    human_judgment: false

duration: 25min
completed: 2026-09-14
status: complete
---

# Phase 6 Plan 01: Wave 0 Stick Pull Nyquist RED Stubs Summary

**Failing IT/unit/widget stubs lock CAT-02, STICK-01…05, BOT-02, and SESS-04 before any Stick Pull production code.**

## Performance

- **Duration:** 25 min
- **Started:** 2026-09-14T05:47:48Z
- **Completed:** 2026-09-14T06:12:00Z
- **Tasks:** 2/2
- **Files modified:** 9

## Accomplishments

- Backend Wave 0: `StickPullSimTest`, `StickPullBotTest`, `StickPullIT`, `StickPullReconnectIT`, CatalogIT PLAYABLE flip, CasualQueueIT game isolation, ReconnectIT Alchiki-30s comment
- Client Wave 0: `howto_stick_pull_test` (five cards / Skip / `howto.stickpull.seen`) and catalog Stick Pull CTA assertions
- Targeted Surefire (29 tests, 18–19 failures) and Flutter (+8/−5) stay RED as required — no production StickPullSim, catalog flip, or match UI

## Task Commits

Each task was committed atomically:

1. **Task 1: Backend Wave 0 unit and IT stubs** - `712bd78` (test)
2. **Task 2: Client Wave 0 widget stubs** - `0ccf675` (test)

**Plan metadata:** `d3dee32` (docs: complete plan)

## Files Created/Modified

- `backend/.../stickpull/StickPullSimTest.java` — STICK-01…04 fail stubs
- `backend/.../stickpull/StickPullBotTest.java` — BOT-02 fail stubs
- `backend/.../session/StickPullIT.java` — Countdown/Tap/settle WS RED
- `backend/.../session/StickPullReconnectIT.java` — 8s forfeit + Alchiki 30s lock
- `backend/.../catalog/CatalogIT.java` — `stickPullTileIsPlayable`
- `backend/.../matchmaking/CasualQueueIT.java` — `stickPullEnqueueIsolatedFromAlchiki`
- `backend/.../session/ReconnectIT.java` — Alchiki 30s grace comment
- `client/test/howto_stick_pull_test.dart` — STICK-05 how-to RED
- `client/test/catalog_test.dart` — Stick Pull CTAs RED

## Decisions Made

- Wave 0 only — no StickPullSim, Catalog PLAYABLE production flip, MatchService branching, or Flutter Stick Pull match UI
- Pure-unit stubs use `Assertions.fail` so the suite compiles without a production `stickpull` package
- `alchikiGraceStillThirty` is intentionally green today as an Alchiki regression lock

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] alchikiGraceStillThirty used host token instead of dropped joiner**
- **Found during:** Task 1 verification
- **Issue:** GET as host after drop had no `reconnectSecondsLeft` (ReconnectIT uses joiner)
- **Fix:** Assert grace on joiner token like `ReconnectIT.getMatchExposesRemainingGrace`
- **Files modified:** `StickPullReconnectIT.java`
- **Verification:** `StickPullReconnectIT#alchikiGraceStillThirty` BUILD SUCCESS alone
- **Committed in:** `712bd78` (part of task commit)

---

**Total deviations:** 1 auto-fixed (Rule 1)
**Impact on plan:** Correctness-only; no scope creep.

## Issues Encountered

None beyond the grace-token projection fix above.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- 06-02 can green CatalogIT + how-to ARB/route/widget stubs
- 06-03 greens StickPullSim/Bot unit + StickPullIT
- 06-04 greens CasualQueueIT isolation + rooms.game
- 06-05 greens StickPullReconnectIT 8s path

## Self-Check: PASSED

- FOUND: StickPullSimTest.java, StickPullBotTest.java, StickPullIT.java, StickPullReconnectIT.java, howto_stick_pull_test.dart
- FOUND: commits 712bd78, 0ccf675
- CatalogIT contains `stickPullTileIsPlayable`; stubs contain `softBandFullForce`, `easyMeanTpsInBand`, `countdownThenTapMovesMarker`, `stickPullGraceIsEightSeconds`, `howtoStickSitTitle`

---
*Phase: 06-stick-pull*
*Completed: 2026-09-14*
