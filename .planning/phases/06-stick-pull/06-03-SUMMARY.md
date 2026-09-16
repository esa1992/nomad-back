---
phase: 06-stick-pull
plan: 03
subsystem: games
tags: [stick-pull, stamina, TapInput, Flame, websocket, bot, StickPullSim]

requires:
  - phase: 06-stick-pull
    provides: Wave 0 RED StickPullSimTest/BotTest/StickPullIT; catalog PLAYABLE + how-to (06-01/06-02)
provides:
  - "Authoritative StickPullSim + StickPullBot + MatchService STICK_PULL BOT lifecycle"
  - "WS TapInput / Countdown / StickState / TapResolved path"
  - "Flutter StickPullMatchPage Flame 1D lane + stamina HUD + bot rematch"
affects:
  - 06-04 rooms.game + casual FIFO game discriminator
  - 06-05 Stick Pull 8s reconnect + ice skin polish

tech-stack:
  added: []
  patterns:
    - "games.stickpull beside Alchiki — no new Modulith module or GameEngine for tug"
    - "Server Instant.now() re-timestamp + 200ms bucket clamp ≤2; suspect log only"
    - "StickPullRuntime @Scheduled 50ms drives countdown/bot/StickState; MatchService branches on game"

key-files:
  created:
    - backend/src/main/java/com/nomadgames/games/stickpull/StickPullConstants.java
    - backend/src/main/java/com/nomadgames/games/stickpull/StickPullPhase.java
    - backend/src/main/java/com/nomadgames/games/stickpull/StickPullSim.java
    - backend/src/main/java/com/nomadgames/games/stickpull/StickPullBot.java
    - backend/src/main/java/com/nomadgames/games/stickpull/StickPullRuntime.java
    - client/lib/games/stick_pull/stick_pull_game.dart
    - client/lib/games/stick_pull/stick_pull_ws.dart
    - client/lib/games/stick_pull/stick_pull_match_page.dart
  modified:
    - backend/src/main/java/com/nomadgames/session/MatchService.java
    - backend/src/main/java/com/nomadgames/session/MatchCreatedResponse.java
    - backend/src/main/java/com/nomadgames/session/internal/MatchWebSocketHandler.java
    - backend/src/test/java/com/nomadgames/games/stickpull/StickPullSimTest.java
    - backend/src/test/java/com/nomadgames/games/stickpull/StickPullBotTest.java
    - backend/src/test/java/com/nomadgames/session/StickPullIT.java
    - client/lib/platform/router.dart
    - client/lib/platform/api/nomad_api.dart
    - client/lib/l10n/app_en.arb
    - client/lib/l10n/app_ru.arb

key-decisions:
  - "SOFT_FORCE 0.012, WIN_THRESHOLD ±0.85, clock 30s, burst 1.5s, recovery 320ms, hard clamp 10/s"
  - "BOT Stick Pull uses WS tickets (issueWsTicket allowlist) — Alchiki BOT stays REST throws"
  - "MatchCreatedResponse.game added so StickPullIT can assert STICK_PULL"
  - "Ice skin / private-QM / 8s reconnect deferred to 06-04/06-05"

patterns-established:
  - "StickPullRuntime heap sessions + Spring @Scheduled tick for COUNTDOWN→LIVE→SETTLE"
  - "TapInput beside ThrowInput in MatchWebSocketHandler; requireSeat for T-06-04"
  - "Client marker only from StickState/TapResolved; haptics on GO + threshold only"

requirements-completed: [STICK-01, STICK-02, STICK-03, STICK-04, BOT-02]

coverage:
  - id: D1
    description: "StickPullSim soft/burst/exhaust/clamp/suspect/clock settle"
    requirement: STICK-04
    verification:
      - kind: unit
        ref: "backend/.../StickPullSimTest.java"
        status: pass
    human_judgment: false
  - id: D2
    description: "StickPullBot EASY/NORMAL/HARD mean TPS + EASY pauses"
    requirement: BOT-02
    verification:
      - kind: unit
        ref: "backend/.../StickPullBotTest.java"
        status: pass
    human_judgment: false
  - id: D3
    description: "StickPullIT Countdown/TapInput/MatchSettled WS bot path"
    requirement: STICK-01
    verification:
      - kind: integration
        ref: "backend/.../StickPullIT.java"
        status: pass
    human_judgment: false
  - id: D4
    description: "Stick Pull match page Flame HUD + tap zone (bot rematch)"
    requirement: STICK-01
    verification:
      - kind: other
        ref: "dart analyze lib/games/stick_pull"
        status: pass
    human_judgment: false

duration: 30min
completed: 2026-09-14
status: complete
---

# Phase 6 Plan 03: Stick Pull Bot Vertical Slice Summary

**Authoritative StickPullSim + bot scheduler + WS TapInput with Flame/Flutter bot match HUD (STICK-01…04, BOT-02).**

## Performance

- **Duration:** 30 min
- **Started:** 2026-09-14T06:48:00Z
- **Completed:** 2026-09-14T07:16:00Z
- **Tasks:** 2
- **Files modified:** 20

## Accomplishments

- Shipped `com.nomadgames.games.stickpull` sim/bot/runtime with yolo locks (force 0.012, threshold ±0.85, 30s clock, 10/s clamp).
- BOT `STICK_PULL` createMatch + WS countdown/tap/settle; StickPullSimTest, StickPullBotTest, StickPullIT green.
- Client `/match?game=stickPull` StickPullMatchPage: countdown, stamina bars, 96dp tap zone, false-start toast, bot Play again.

## Task Commits

1. **Task 1: StickPullSim + StickPullBot + MatchService BOT path** - `ec48df9` (feat)
2. **Task 2: Stick Pull match page Flame + HUD + bot rematch** - `8a7921b` (feat)

**Plan metadata:** `0d08c56` (docs: complete plan)

## Files Created/Modified

- `StickPullSim.java` / `StickPullBot.java` / `StickPullRuntime.java` — authority + bot jitter + lifecycle
- `MatchService.java` / `MatchWebSocketHandler.java` — STICK_PULL BOT create, applyTap, TapInput
- `stick_pull_match_page.dart` / `stick_pull_game.dart` / `stick_pull_ws.dart` — presentation
- ARB EN/RU — countdown/falseStart/stickClock/errorStickPullStart/stickTapHint

## Decisions Made

- WS tickets enabled for Stick Pull BOT only (Alchiki bot remains REST).
- Default wood shaft paint; ice accents wait for 06-05.
- Private/QM game column and 8s reconnect left for 06-04/06-05.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] StickPullIT MatchSettled await too short for 30s clock**
- **Found during:** Task 1
- **Issue:** Wave 0 awaitType used 8s; D-89 default live clock is 30s plus ~4s countdown.
- **Fix:** Overload `awaitType(type, timeoutSeconds)` and wait 45s for MatchSettled.
- **Files modified:** `StickPullIT.java`
- **Verification:** StickPullIT green
- **Committed in:** `ec48df9`

**2. [Rule 2 - Correctness] MatchCreatedResponse lacked game field**
- **Found during:** Task 1
- **Issue:** StickPullIT asserts `$.game` = STICK_PULL.
- **Fix:** Added `game` to `MatchCreatedResponse` / `toCreated`.
- **Files modified:** `MatchCreatedResponse.java`, `MatchService.java`
- **Committed in:** `ec48df9`

## Threat Flags

None beyond plan mitigations (T-06-01 clamp/re-timestamp, T-06-04 seat check, T-06-07 server settle, T-06-08 suspect log).

## Known Stubs

None that block the bot vertical slice. Private/QM Stick Pull and 8s reconnect remain out of scope for 06-03.

## Self-Check: PASSED

- FOUND: StickPullSim.java, StickPullBot.java, StickPullRuntime.java, stick_pull_match_page.dart
- FOUND: commits ec48df9, 8a7921b
- FOUND: StickPullSimTest/BotTest/StickPullIT green; dart analyze stick_pull clean
