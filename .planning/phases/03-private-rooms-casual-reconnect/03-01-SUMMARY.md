---
phase: 03-private-rooms-casual-reconnect
plan: 01
subsystem: session
tags: [modulith, game-engine-spi, match-status, sess-05, d-38, d-44]

requires:
  - phase: 02-guest-catalog-first-alchiki-match
    provides: Bot MatchService + AlchikiEngine GameEngine SPI + AlchikiRules + failing ModularityTest cycle
provides:
  - Session-owned MatchStatus including HOST_WIN and JOINER_WIN
  - Expanded GameEngine SPI (startPrivate, nextBotThrow, resolve, clocks)
  - Acyclic games → session; MatchService has zero games.alchiki imports
  - Bot leave while IN_PLAY still BOT_WIN
affects:
  - Phase 3 rooms / private leave / rematch (HOST_WIN JOINER_WIN vocabulary)
  - ModularityTest stays the cycle gate for later session types

tech-stack:
  added: []
  patterns:
    - games implements session.GameEngine only; session never imports games types
    - AlchikiEngine.resolve maps private PLAYER_WIN/BOT_WIN onto HOST_WIN/JOINER_WIN
    - ScriptedBot stays in games.alchiki.internal; nextBotThrow is the session seam

key-files:
  created:
    - backend/src/main/java/com/nomadgames/session/MatchStatus.java
    - backend/src/main/java/com/nomadgames/session/ScoreClock.java
    - backend/src/main/java/com/nomadgames/session/PrivateTable.java
    - backend/src/test/java/com/nomadgames/games/alchiki/AlchikiEngineSpiTest.java
  modified:
    - backend/src/main/java/com/nomadgames/session/GameEngine.java
    - backend/src/main/java/com/nomadgames/session/MatchService.java
    - backend/src/main/java/com/nomadgames/games/alchiki/AlchikiEngine.java
    - backend/src/main/java/com/nomadgames/games/alchiki/AlchikiRules.java
    - backend/src/test/java/com/nomadgames/games/alchiki/AlchikiRulesTest.java

key-decisions:
  - "Private resolve reuses AlchikiRules first-to-5 then maps PLAYER_WIN→HOST_WIN and BOT_WIN→JOINER_WIN instead of duplicating clock math in session"
  - "MatchService bot ScoreClock.privateMatch is always false so leave/throw still settle PLAYER_WIN/BOT_WIN/DRAW"
  - "Task 1 retargeted MatchService off games.alchiki.MatchStatus so deleting the games enum still compiles"

patterns-established:
  - "Pattern: settlement enum lives in session; games imports session.MatchStatus (allowed direction)"
  - "Pattern: bot orchestration (nextBotThrow, resolve, turnClock/matchLimit/hardCap, forfeitThrowIfExpired) goes through GameEngine"

requirements-completed: [SESS-05]

coverage:
  - id: D1
    description: ModularityTest verify() is green; session never imports games.alchiki types
    requirement: SESS-05
    verification:
      - kind: unit
        ref: "backend/src/test/java/com/nomadgames/ModularityTest.java#modulesShouldVerify"
        status: pass
    human_judgment: false
  - id: D2
    description: Session MatchStatus includes IN_PLAY, PLAYER_WIN, BOT_WIN, DRAW, HOST_WIN, JOINER_WIN
    requirement: SESS-05
    verification:
      - kind: unit
        ref: "backend/src/test/java/com/nomadgames/games/alchiki/AlchikiRulesTest.java#sessionMatchStatusDeclaresHostAndJoinerWin"
        status: pass
    human_judgment: false
  - id: D3
    description: Bot leave while IN_PLAY still records BOT_WIN; ThrowAuthorityIT and AlchikiRulesTest stay green
    requirement: SESS-05
    verification:
      - kind: integration
        ref: "backend/src/test/java/com/nomadgames/session/ThrowAuthorityIT.java#leaveMatchReturnsBotWin"
        status: pass
      - kind: unit
        ref: "backend/src/test/java/com/nomadgames/games/alchiki/AlchikiRulesTest.java#resolveTable"
        status: pass
    human_judgment: false
  - id: D4
    description: startPrivate returns NORMAL six bone ids plus saka-host and saka-joiner
    requirement: SESS-05
    verification:
      - kind: unit
        ref: "backend/src/test/java/com/nomadgames/games/alchiki/AlchikiEngineSpiTest.java#startPrivateUsesNormalBonesAndSakaHostJoinerIds"
        status: pass
    human_judgment: false
  - id: D5
    description: MatchService bot path uses engine.nextBotThrow/resolve/clocks with no games imports
    requirement: SESS-05
    verification:
      - kind: integration
        ref: "mvnw -pl backend -am test -Dtest=ModularityTest,AlchikiRulesTest,ThrowAuthorityIT,ScriptedBotTest"
        status: pass
      - kind: unit
        ref: "backend/src/test/java/com/nomadgames/games/alchiki/AlchikiEngineSpiTest.java#nextBotThrowReturnsBotThrowViewForEasyLeftovers"
        status: pass
    human_judgment: false

duration: 6min
completed: 2026-09-07
status: complete
---

# Phase 3 Plan 01: Cycle Break + Session MatchStatus Summary

**Session-owned MatchStatus with HOST_WIN/JOINER_WIN and an acyclic GameEngine SPI so MatchService never imports games types**

## Performance

- **Duration:** 6 min
- **Started:** 2026-09-07T07:21:58Z
- **Completed:** 2026-09-07T07:28:00Z
- **Tasks:** 2
- **Files modified:** 9

## Accomplishments

- Moved settlement enum into `session.MatchStatus` and added `HOST_WIN` / `JOINER_WIN` (D-44) without changing FIRST_TO, TURNS_EACH, or clock Durations
- Expanded `GameEngine` with `startPrivate`, `nextBotThrow`, `resolve`, `forfeitThrowIfExpired`, and Duration accessors; `AlchikiEngine` is still the only `@Component` implementor
- Rewrote bot orchestration in `MatchService` onto the SPI; `ModularityTest` is green; `ThrowAuthorityIT` leave-while-IN_PLAY still returns `BOT_WIN`

## Task Commits

Each task was committed atomically (TDD RED then GREEN):

1. **Task 1 RED: session MatchStatus test** - `9d4aa51` (test)
2. **Task 1 GREEN: move MatchStatus into session** - `f2db439` (feat)
3. **Task 2 RED: GameEngine private SPI test** - `13e5bd1` (test)
4. **Task 2 GREEN: expand SPI and drop games imports** - `454b52f` (feat)

**Plan metadata:** `4567d55` (docs: complete plan)

## TDD Gate Compliance

- RED commits exist: `9d4aa51`, `13e5bd1`
- GREEN commits exist after RED: `f2db439`, `454b52f`
- Sequence is RED → GREEN per task

## Files Created/Modified

- `backend/src/main/java/com/nomadgames/session/MatchStatus.java` - Session-owned settlement enum including HOST_WIN/JOINER_WIN
- `backend/src/main/java/com/nomadgames/session/ScoreClock.java` - Clock snapshot for GameEngine.resolve
- `backend/src/main/java/com/nomadgames/session/PrivateTable.java` - NORMAL bones plus saka-host / saka-joiner ids
- `backend/src/main/java/com/nomadgames/session/GameEngine.java` - Expanded SPI
- `backend/src/main/java/com/nomadgames/session/MatchService.java` - Bot path uses engine only; no games.alchiki imports
- `backend/src/main/java/com/nomadgames/games/alchiki/AlchikiEngine.java` - Implements full SPI; ScriptedBot.nextThrow lives here
- `backend/src/main/java/com/nomadgames/games/alchiki/AlchikiRules.java` - Return type is session.MatchStatus
- `backend/src/test/java/com/nomadgames/games/alchiki/AlchikiRulesTest.java` - Imports session enum; HOST_WIN/JOINER_WIN assertion
- `backend/src/test/java/com/nomadgames/games/alchiki/AlchikiEngineSpiTest.java` - startPrivate, private resolve map, clocks, nextBotThrow
- Deleted `backend/src/main/java/com/nomadgames/games/alchiki/MatchStatus.java` (moved)

## Decisions Made

- Private `resolve` wraps `AlchikiRules.resolve` and remaps `PLAYER_WIN`→`HOST_WIN`, `BOT_WIN`→`JOINER_WIN`; DRAW and IN_PLAY stay. Avoids duplicating first-to-5 / 8-turn / 4m / 5m math in session.
- Bot matches always pass `ScoreClock.privateMatch=false` so existing PLAYER_WIN/BOT_WIN/DRAW strings are unchanged on REST.
- `startPrivate()` documents NORMAL six bones and saka-host / saka-joiner only; two-body spawn stays 03-05.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Retargeted MatchService off the deleted games enum**
- **Found during:** Task 1 (Move MatchStatus into session)
- **Issue:** Plan forbids editing MatchService in Task 1, but deleting `games.alchiki.MatchStatus` breaks compilation of `MatchService`'s games import, so `AlchikiRulesTest` cannot run.
- **Fix:** Removed `import com.nomadgames.games.alchiki.MatchStatus` so the same-package session enum is used. No bot-orchestration rewrite until Task 2.
- **Files modified:** `backend/src/main/java/com/nomadgames/session/MatchService.java`
- **Verification:** `AlchikiRulesTest` 13 tests pass
- **Committed in:** `f2db439` (Task 1 GREEN)

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** Required for Task 1 verification after the enum move. No scope creep; rooms/WebSocket/rematch/reconnect were not added.

## Issues Encountered

None. PowerShell requires quoting Maven `-D` properties (`.failIfNoSpecifiedTests` is otherwise parsed as a lifecycle phase); not a product deviation.

## Authentication Gates

None

## Known Stubs

None - no placeholder settlement, empty bot throws, or unwired SPI methods.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Ready for 03-02. Two-player types can grow on a green `ModularityTest`. Private rooms, WebSocket, rematch, and 30s reconnect remain later plans. Private leave must still write HOST_WIN/JOINER_WIN rather than BOT_WIN (D-44 human half).

## Self-Check: PASSED

- FOUND: `backend/src/main/java/com/nomadgames/session/MatchStatus.java`
- FOUND: `backend/src/main/java/com/nomadgames/session/GameEngine.java`
- FOUND: `backend/src/main/java/com/nomadgames/session/ScoreClock.java`
- FOUND: `backend/src/main/java/com/nomadgames/session/PrivateTable.java`
- MISSING (intentional delete): `backend/src/main/java/com/nomadgames/games/alchiki/MatchStatus.java`
- FOUND commits: `9d4aa51`, `f2db439`, `13e5bd1`, `454b52f`
- Verification: ModularityTest, AlchikiRulesTest, AlchikiEngineSpiTest, ScriptedBotTest, ThrowAuthorityIT all pass

---
*Phase: 03-private-rooms-casual-reconnect*
*Completed: 2026-09-07*
