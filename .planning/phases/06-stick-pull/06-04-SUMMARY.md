---
phase: 06-stick-pull
plan: 04
subsystem: matchmaking
tags: [stick-pull, rooms, casual-queue, game-discriminator, rematch, FIFO]

requires:
  - phase: 06-stick-pull
    provides: StickPullSim + bot WS path (06-03); catalog PLAYABLE + how-to (06-01/06-02)
provides:
  - "V10 rooms.game + server allowlist ALCHIKI|STICK_PULL"
  - "Per-game casual FIFO isolation + Stick Pull human private/casual matches"
  - "Rematch preserves STICK_PULL (D-80)"
  - "Client QM/room/fallback Stick Pull discriminator wiring"
affects:
  - 06-05 Stick Pull 8s reconnect + ice skin polish

tech-stack:
  added: []
  patterns:
    - "GameDiscriminator.normalize allowlist on rooms create and casual enqueue (T-06-03)"
    - "ConcurrentHashMap<String, ConcurrentLinkedQueue> per-game FIFO (D-79)"
    - "createStickPullHumanMatch reuses StickPullRuntime from 06-03 bot path"

key-files:
  created:
    - backend/src/main/resources/db/migration/V10__rooms_game.sql
    - backend/src/main/java/com/nomadgames/matchmaking/GameDiscriminator.java
    - backend/src/main/java/com/nomadgames/matchmaking/CreateRoomRequest.java
    - backend/src/main/java/com/nomadgames/matchmaking/EnqueueCasualRequest.java
  modified:
    - backend/src/main/java/com/nomadgames/matchmaking/CasualQueueService.java
    - backend/src/main/java/com/nomadgames/matchmaking/RoomService.java
    - backend/src/main/java/com/nomadgames/session/MatchService.java
    - client/lib/platform/api/nomad_api.dart
    - client/lib/matchmaking/searching_page.dart
    - client/lib/matchmaking/fallback_page.dart
    - client/lib/rooms/lobby_page.dart
    - client/lib/catalog/catalog_page.dart

key-decisions:
  - "Shared Create room (Alchiki tile) omits game → server default ALCHIKI (D-78)"
  - "Stick Pull fallback Play vs bot uses lastStickPullBotDifficultyProvider"
  - "8s reconnect grace unchanged — deferred to 06-05"

patterns-established:
  - "Room kickoff and rematch read persisted room.getGame() / match.getGame(), not client guess"
  - "Searching/fallback thread ?game=stickPull query through router to Stick Pull how-to/match"

requirements-completed: [CAT-02, STICK-01, BOT-02]

coverage:
  - id: D1
    description: "Per-game FIFO: STICK_PULL waiter never pairs with ALCHIKI"
    requirement: STICK-01
    verification:
      - kind: integration
        ref: "backend/.../CasualQueueIT.java#stickPullEnqueueIsolatedFromAlchiki"
        status: pass
    human_judgment: false
  - id: D2
    description: "Stick Pull private room both-ready mints match.game STICK_PULL"
    requirement: STICK-01
    verification:
      - kind: integration
        ref: "backend/.../RoomIT.java#stickPullRoomKickoffCreatesStickPullMatch"
        status: pass
    human_judgment: false
  - id: D3
    description: "Client catalog Stick Pull QM and Create room pass STICK_PULL discriminator"
    requirement: CAT-02
    verification:
      - kind: automated_ui
        ref: "client/test/catalog_test.dart"
        status: pass
    human_judgment: false
  - id: D4
    description: "Matchmaking searching/fallback routes unchanged for Alchiki; Stick Pull paths wired"
    requirement: BOT-02
    verification:
      - kind: automated_ui
        ref: "client/test/matchmaking_test.dart"
        status: pass
    human_judgment: false

duration: 35min
completed: 2026-09-14
status: complete
---

# Phase 6 Plan 04: Stick Pull Online Modes Summary

**Private rooms and Casual Quick Match with server-validated game discriminator, per-game FIFO isolation, and rematch that preserves STICK_PULL (D-78…D-80, T-06-03).**

## Performance

- **Duration:** 35 min
- **Started:** 2026-09-14T07:26:00Z
- **Completed:** 2026-09-14T08:01:00Z
- **Tasks:** 2
- **Files modified:** 22

## Accomplishments

- V10 `rooms.game` + `GameDiscriminator` allowlist; Stick Pull room kickoff and casual enqueue mint `STICK_PULL` human matches via `StickPullRuntime`.
- Per-game FIFO in `CasualQueueService`; `stickPullEnqueueIsolatedFromAlchiki` green; rematch threads `match.getGame()` (D-80).
- Client passes `STICK_PULL` on catalog QM/Create room; searching/fallback/lobby route Stick Pull how-to and match with `game=stickPull`.

## Task Commits

1. **Task 1: rooms.game + per-game FIFO + rematch game thread**
   - `bfd46b8` (test): RoomIT stick pull kickoff tests
   - `6f500d7` (feat): backend V10, FIFO, MatchService human Stick Pull
2. **Task 2: Client QM / room / fallback Stick Pull discriminator** - `c79f0ae` (feat)

**Plan metadata:** `45c27a7` (docs: complete plan)

## Files Created/Modified

- `V10__rooms_game.sql` / `GameDiscriminator.java` — server-side game allowlist
- `CasualQueueService.java` — per-game FIFO map; response includes `game`
- `MatchService.java` — `createStickPullHumanMatch`, rematch game thread
- `nomad_api.dart` / `searching_page.dart` / `fallback_page.dart` / `lobby_page.dart` — client discriminator

## Decisions Made

- Alchiki shared Create room and QM omit game body → default `ALCHIKI` for backward compat.
- Stick Pull fallback bot uses `lastStickPullBotDifficultyProvider`; invite friend creates `STICK_PULL` room when in Stick Pull queue context.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Test stubs missing optional `game` param on NomadApi overrides**
- **Found during:** Task 2 verification
- **Issue:** `catalog_test.dart` / `matchmaking_test.dart` overrides failed to compile after `createRoom({game})` / `enqueueCasual({game})`.
- **Fix:** Added `{String game = 'ALCHIKI'}` to stub overrides; `startMatch` stub got `game` param from 06-03.
- **Files modified:** `client/test/catalog_test.dart`, `client/test/matchmaking_test.dart`
- **Committed in:** `c79f0ae`

## Threat Flags

None beyond plan mitigations (T-06-03 allowlist, T-06-09 FIFO isolation).

## Known Stubs

- Stick Pull 8s reconnect forfeit (SESS-04 / D-86) intentionally deferred to 06-05 — Alchiki 30s grace unchanged.

## Self-Check: PASSED

- FOUND: V10__rooms_game.sql, GameDiscriminator.java, CasualQueueService.java
- FOUND: commits bfd46b8, 6f500d7, c79f0ae
- FOUND: CasualQueueIT/RoomIT/StickPullIT green; catalog_test + matchmaking_test green
