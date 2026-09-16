---
phase: 03-private-rooms-casual-reconnect
plan: 04
subsystem: matchmaking
tags: [rooms, ready, host-alive, idle-ttl, private-match, joiner-first, mode-02, d-27, d-29, d-30, d-31, d-14]

requires:
  - phase: 03-private-rooms-casual-reconnect
    provides: POST /v1/rooms + join-by-code LOBBY seats (03-02, 03-03); GameEngine.startPrivate; guest JWT
provides:
  - POST /v1/rooms/{id}/ready starts a PRIVATE NORMAL match only when both seats Ready
  - createPrivateMatch with turn JOINER and difficulty NORMAL (client cannot pick)
  - Host leave CLOSES the code immediately; 1 Hz closer at 10 min idle
  - Lobby Ready / Leave lobby chrome and how-to skip after both Ready
affects:
  - Phase 3 WebSocket throws and two-saka table (03-05/03-06)
  - Private leave/forfeit must not write BOT_WIN (03-07)

tech-stack:
  added: []
  patterns:
    - Both Ready is server-owned; RoomService calls MatchService.createPrivateMatch
    - playerScore column = host, botScore column = joiner on PRIVATE snapshots
    - GET match uses requireSeat (host or joiner) for PRIVATE; BOT keeps requireOwner

key-files:
  created:
    - backend/src/main/resources/db/migration/V4__match_seats.sql
    - client/test/lobby_ready_test.dart
  modified:
    - backend/src/main/java/com/nomadgames/session/MatchService.java
    - backend/src/main/java/com/nomadgames/session/internal/MatchEntity.java
    - backend/src/main/java/com/nomadgames/session/MatchSnapshot.java
    - backend/src/main/java/com/nomadgames/matchmaking/RoomService.java
    - backend/src/main/java/com/nomadgames/matchmaking/RoomController.java
    - backend/src/test/java/com/nomadgames/matchmaking/RoomIT.java
    - client/lib/rooms/lobby_page.dart
    - client/lib/howto/alchiki_howto_page.dart
    - client/lib/platform/router.dart
    - client/lib/platform/api/nomad_api.dart
    - client/lib/games/alchiki/match_page.dart

key-decisions:
  - "Ready POST returns RoomLobbyResponse with bothReady; match starts only when both flags true and joiner_id is set (D-27)"
  - "createPrivateMatch hard-codes PRIVATE/NORMAL/turn JOINER; playerScore column is host, botScore is joiner (D-30, D-31)"
  - "Host leave CLOSES the lobby immediately; 1 Hz closer kills LOBBY rows past idle_expires_at (D-29)"
  - "GET match uses requireSeat so the joiner can read turn JOINER; third guests get 403 (T-03-15)"
  - "Private /match shows a wood Starting… scaffold and does not POST bot startMatch; throws stay 03-06"

patterns-established:
  - "Pattern: Ready is one-way; UI disables after local tap; server starts only when both flags true"
  - "Pattern: Host Leave lobby uses pause-style confirm; joiner Leave lobby POSTs immediately"
  - "Pattern: After matchId, unseen how-to then /match?mode=private&matchId=; seen skips the pager (D-14)"

requirements-completed: [MODE-02]

coverage:
  - id: D1
    description: Match does not start on join or one Ready; both Ready creates a PRIVATE NORMAL match with turn JOINER
    requirement: MODE-02
    verification:
      - kind: integration
        ref: "backend/src/test/java/com/nomadgames/matchmaking/RoomIT.java#bothReadyStartsJoinerTurn"
        status: pass
      - kind: integration
        ref: "backend/src/test/java/com/nomadgames/matchmaking/RoomIT.java#joinDoesNotStart"
        status: pass
    human_judgment: false
  - id: D2
    description: Host leave while LOBBY closes the code immediately (join 410)
    requirement: MODE-02
    verification:
      - kind: integration
        ref: "backend/src/test/java/com/nomadgames/matchmaking/RoomIT.java#hostLeaveCloses"
        status: pass
    human_judgment: false
  - id: D3
    description: 10 minute idle TTL closer CLOSES LOBBY rows (join 410)
    requirement: MODE-02
    verification:
      - kind: integration
        ref: "backend/src/test/java/com/nomadgames/matchmaking/RoomIT.java#idleTtlCloses"
        status: pass
    human_judgment: false
  - id: D4
    description: Lobby Ready is disabled until a joiner sits; host Leave lobby confirms Leave this room?
    requirement: MODE-02
    verification:
      - kind: automated_ui
        ref: "client/test/lobby_ready_test.dart#Ready is disabled when no joiner sits"
        status: pass
      - kind: automated_ui
        ref: "client/test/lobby_ready_test.dart#host Leave lobby opens Leave this room? confirm"
        status: pass
    human_judgment: false
  - id: D5
    description: howto.alchiki.seen skips the pager and routes to /match?mode=private
    requirement: MODE-02
    verification:
      - kind: automated_ui
        ref: "client/test/lobby_ready_test.dart#howto.alchiki.seen skips pager and goes to mode=private"
        status: pass
      - kind: automated_ui
        ref: "client/test/howto_test.dart"
        status: pass
    human_judgment: false
  - id: D6
    description: Bot POST /v1/matches and ThrowAuthorityIT stay green; ModularityTest stays acyclic
    verification:
      - kind: integration
        ref: "backend/src/test/java/com/nomadgames/session/ThrowAuthorityIT.java"
        status: pass
      - kind: unit
        ref: "backend/src/test/java/com/nomadgames/ModularityTest.java"
        status: pass
    human_judgment: false

duration: 9min
completed: 2026-09-07
status: complete
---

# Phase 3 Plan 04: Both Ready + Host-Alive TTL Summary

**Both Ready creates a joiner-first PRIVATE NORMAL match; host leave and 10 min idle kill the code**

## Performance

- **Duration:** 9 min
- **Started:** 2026-09-07T08:11:20Z
- **Completed:** 2026-09-07T08:19:59Z
- **Tasks:** 2
- **Files modified:** 17

## Accomplishments

- `POST /v1/rooms/{id}/ready` is one-way; one Ready does not create a match; both Ready calls `createPrivateMatch` with turn JOINER, difficulty NORMAL, mode PRIVATE (D-27, D-30, D-31)
- Host `POST /v1/rooms/{id}/leave` while LOBBY sets CLOSED immediately so join is 410; `@Scheduled` 1 Hz closer CLOSES LOBBY rows past `idle_expires_at` (D-29)
- Lobby Ready is accent only when a joiner sits; host Leave lobby confirms `Leave this room?`; `howto.alchiki.seen` skips the pager to `/match?mode=private&matchId=` (D-14)
- `V4__match_seats.sql` adds `host_id` / `joiner_id`; GET match uses `requireSeat` so the joiner can read the snapshot (T-03-15)

## Task Commits

Each task was committed atomically:

1. **Task 1: Failing Ready, host-alive, TTL, and lobby chrome tests** - `a51565e` (test)
2. **Task 2: Seats, Ready, TTL, lobby chrome, how-to skip** - `8b5ff1c` (feat)

**Plan metadata:** docs commit after this file

_Note: TDD tasks may have multiple commits (test → feat → refactor)_

## Files Created/Modified

- `backend/src/main/resources/db/migration/V4__match_seats.sql` - nullable host/joiner seats on matches
- `backend/src/main/java/com/nomadgames/session/MatchService.java` - `createPrivateMatch` + `requireSeat` on GET
- `backend/src/main/java/com/nomadgames/session/internal/MatchEntity.java` - hostId/joinerId columns and overload
- `backend/src/main/java/com/nomadgames/session/MatchSnapshot.java` - mode, difficulty, seats, Guest-XXXX labels
- `backend/src/main/java/com/nomadgames/matchmaking/RoomService.java` - ready, leave, `closeExpiredLobbies`
- `backend/src/main/java/com/nomadgames/matchmaking/RoomController.java` - POST ready and leave
- `backend/src/test/java/com/nomadgames/matchmaking/RoomIT.java` - bothReady, hostLeave, idleTtl, joinDoesNotStart
- `client/lib/rooms/lobby_page.dart` - Ready CTA, host confirm, closed chrome, how-to skip
- `client/lib/howto/alchiki_howto_page.dart` - mode + matchId query params
- `client/lib/platform/router.dart` - `/match` reads mode and matchId
- `client/lib/platform/api/nomad_api.dart` - `readyRoom` / `leaveRoom` / `bothReady`
- `client/lib/games/alchiki/match_page.dart` - private Starting… scaffold, no bot startMatch
- `client/test/lobby_ready_test.dart` - Ready disabled, host leave confirm, how-to skip

## Decisions Made

- Ready response reuses `RoomLobbyResponse` plus `bothReady`; the client does not pick turn or difficulty
- PRIVATE snapshots reuse `playerScore`/`botScore` as host/joiner so bot REST stay compatible
- Private `/match` does not attach Flame or POST `/v1/matches`; wood `Starting…` until 03-06
- `@EnableScheduling` on `NomadGamesApplication` so the 1 Hz idle closer runs

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] NomadApi.readyRoom / leaveRoom and RoomLobby.bothReady**
- **Found during:** Task 1 (failing tests)
- **Issue:** Plan claimed `readyRoom` / `leaveRoom` already existed; widget tests could not stub them
- **Fix:** Added thin POST wrappers and `bothReady` on `RoomLobby` so RED tests compile
- **Files modified:** `client/lib/platform/api/nomad_api.dart`
- **Verification:** `flutter test test/lobby_ready_test.dart` (RED then GREEN)
- **Committed in:** `a51565e` (Task 1)

**2. [Rule 3 - Blocking] AlchikiMatchPage mode/matchId + Starting… scaffold**
- **Found during:** Task 2
- **Issue:** `match_page.dart` was not in `files_modified`, but `/match?mode=private&matchId=` would call bot `startMatch`
- **Fix:** Optional `mode`/`matchId`; skip bot create; show `startingMatch`
- **Files modified:** `client/lib/games/alchiki/match_page.dart`, `client/lib/platform/router.dart`
- **Verification:** `lobby_ready_test` how-to skip asserts `mode=private`; `howto_test` still green
- **Committed in:** `8b5ff1c` (Task 2)

---

**Total deviations:** 2 auto-fixed (2 blocking)
**Impact on plan:** Required for TDD compile and to keep bot `POST /v1/matches` off the private route. No scope creep into WS throws or rematch.

## Issues Encountered

None

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Ready for 03-05 (WebSocket / in-play throws). Private match rows exist with joiner-first turn; do not migrate bot throws to WS. Two-saka client table and reconnect remain later plans.

## Self-Check: PASSED

- V4, MatchService.createPrivateMatch, RoomService closer, lobby_page, lobby_ready_test, RoomIT, howto mode=private present on disk
- Commits `a51565e` and `8b5ff1c` in git log `--grep=03-04`
- RoomIT (10) + ThrowAuthorityIT (12) + ModularityTest (1) BUILD SUCCESS; flutter lobby_ready + howto + join_code all passed

---
*Phase: 03-private-rooms-casual-reconnect*
*Completed: 2026-09-07*
