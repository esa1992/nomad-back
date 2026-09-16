---
phase: 03-private-rooms-casual-reconnect
plan: 11
subsystem: matchmaking
tags: [rooms, pessimistic-lock, version, concurrent-ready, concurrent-join, mode-02, d-27, d-30, gap-closure]

requires:
  - phase: 03-private-rooms-casual-reconnect
    provides: Sequential both-Ready kickoff and unlocked findByCode/findById (03-04)
provides:
  - PESSIMISTIC_WRITE findByIdForUpdate / findByCodeForUpdate on the lobby row
  - rooms.version optimistic column (T-03-42)
  - Concurrent both-Ready creates exactly one PRIVATE NORMAL match with turn JOINER
  - Concurrent join seats exactly one guest; the other gets 409
affects:
  - Phase 3 rematch sync (03-12) and isolate-alive rejoin (03-13) — not implemented here
  - VERIFICATION truth 2 / CR-03 concurrent Ready lost-update

tech-stack:
  added: []
  patterns:
    - Join/ready/leave load the lobby row under PESSIMISTIC_WRITE; GET stays unlocked
    - createPrivateMatch only while both ready flags are true, joiner_id is set, and match_id is null
    - Ready does a second locked look so the first both-tap response can pick up the partner's kickoff matchId

key-files:
  created:
    - backend/src/main/resources/db/migration/V6__room_version.sql
  modified:
    - backend/src/main/java/com/nomadgames/matchmaking/internal/RoomEntity.java
    - backend/src/main/java/com/nomadgames/matchmaking/internal/RoomRepository.java
    - backend/src/main/java/com/nomadgames/matchmaking/RoomService.java
    - backend/src/test/java/com/nomadgames/matchmaking/RoomIT.java

key-decisions:
  - "Join, ready, and leave load the lobby row with PESSIMISTIC_WRITE; GET /v1/rooms/{id} stays on unlocked findById (D-27, T-03-40, T-03-41)"
  - "createPrivateMatch runs only when both ready flags are true, joiner_id is set, and match_id is still null so both-tap cannot mint two matches (D-27, D-30)"
  - "Ready follows the flag write with a second locked look so concurrent both-tap responses share the same matchId"
  - "Idle closer locks each expired lobby by id so @Version does not abort the 1 Hz TTL (D-29, T-03-42)"

patterns-established:
  - "Pattern: mutating lobby paths use ForUpdate; read-only GET does not"
  - "Pattern: kickoff is create-once behind match_id IS NULL under the row lock"

requirements-completed: [MODE-02]

coverage:
  - id: D1
    description: Simultaneous Ready creates exactly one PRIVATE NORMAL matchId with turn JOINER
    requirement: MODE-02
    verification:
      - kind: integration
        ref: "backend/src/test/java/com/nomadgames/matchmaking/RoomIT.java#concurrentBothReadyCreatesOneMatch"
        status: pass
      - kind: integration
        ref: "backend/src/test/java/com/nomadgames/matchmaking/RoomIT.java#bothReadyStartsJoinerTurn"
        status: pass
    human_judgment: false
  - id: D2
    description: Two guests joining the same code at once seat exactly one joiner; the other receives 409
    requirement: MODE-02
    verification:
      - kind: integration
        ref: "backend/src/test/java/com/nomadgames/matchmaking/RoomIT.java#concurrentJoinSeatsOneJoiner"
        status: pass
    human_judgment: false
  - id: D3
    description: Sequential RoomIT host leave and 10 min idle TTL still close the code
    requirement: MODE-02
    verification:
      - kind: integration
        ref: "backend/src/test/java/com/nomadgames/matchmaking/RoomIT.java#hostLeaveCloses"
        status: pass
      - kind: integration
        ref: "backend/src/test/java/com/nomadgames/matchmaking/RoomIT.java#idleTtlCloses"
        status: pass
    human_judgment: false
  - id: D4
    description: LeaveIT, RematchIT, and ModularityTest stay green after the lobby lock
    verification:
      - kind: integration
        ref: "backend/src/test/java/com/nomadgames/session/LeaveIT.java"
        status: pass
      - kind: integration
        ref: "backend/src/test/java/com/nomadgames/session/RematchIT.java"
        status: pass
      - kind: unit
        ref: "backend/src/test/java/com/nomadgames/ModularityTest.java"
        status: pass
    human_judgment: false

duration: 9min
completed: 2026-09-08
status: complete
---

# Phase 3 Plan 11: Concurrent Ready/Join Lock Summary

**PESSIMISTIC_WRITE plus rooms.version so simultaneous Ready creates one joiner-first PRIVATE NORMAL match**

## Performance

- **Duration:** 9 min
- **Started:** 2026-09-08T08:06:05Z
- **Completed:** 2026-09-08T08:15:27Z
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments

- `RoomRepository.findByIdForUpdate` / `findByCodeForUpdate` lock the lobby row; join, ready, and leave use them so `host_ready` / `joiner_ready` / `joiner_id` / `match_id` cannot lost-update (MODE-02, D-27)
- Flyway `V6__room_version.sql` and `@Version` on `RoomEntity` reject unlocked lost-updates (T-03-42)
- Concurrent both-Ready creates exactly one `IN_PLAY` PRIVATE NORMAL match with turn JOINER; concurrent join seats one guest and returns 409 to the other (D-30, D-31, D-32)
- Sequential `bothReadyStartsJoinerTurn`, `hostLeaveCloses`, `idleTtlCloses`, LeaveIT, RematchIT, and ModularityTest stay green

## Task Commits

Each task was committed atomically:

1. **Task 1: Failing concurrent Ready and join tests** - `c0247a7` (test)
2. **Task 2: Lock lobby row and create match once** - `811c896` (feat)

**Plan metadata:** docs commit after this file

_Note: TDD tasks may have multiple commits (test → feat → refactor)_

## Files Created/Modified

- `backend/src/main/resources/db/migration/V6__room_version.sql` - `rooms.version BIGINT NOT NULL DEFAULT 0`
- `backend/src/main/java/com/nomadgames/matchmaking/internal/RoomEntity.java` - jakarta `@Version` field
- `backend/src/main/java/com/nomadgames/matchmaking/internal/RoomRepository.java` - `PESSIMISTIC_WRITE` ForUpdate finders
- `backend/src/main/java/com/nomadgames/matchmaking/RoomService.java` - locked join/ready/leave; create-once kickoff; per-row idle closer
- `backend/src/test/java/com/nomadgames/matchmaking/RoomIT.java` - concurrent both-Ready and double-join ITs; test mint limit 100

## Decisions Made

- Join uses `findByCodeForUpdate`; ready/leave use `findByIdForUpdate` via `requireSeat`; GET stays on unlocked `findById`
- Kickoff calls `createPrivateMatch` only when both flags are true, `joinerId` is set, and `matchId` is still null
- After the Ready flag write, a second locked transaction picks up a partner kickoff so both concurrent 200 bodies share the same `matchId`
- The 1 Hz idle closer lists expired ids then locks each row; it does not start the match on join and does not touch rematch (03-12) or isolate-alive rejoin (03-13)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] Second locked Ready look**
- **Found during:** Task 2
- **Issue:** A single locked transaction serializes like sequential Ready: the first POST returns `matchId` null even though the waiting partner then creates the match. The plan's concurrent IT requires both 200 bodies to carry the same non-null `matchId`.
- **Fix:** After the flag write, if status is still LOBBY and `matchId` is null, load `findByIdForUpdate` again and `kickoffIfBothReady`.
- **Files modified:** `backend/src/main/java/com/nomadgames/matchmaking/RoomService.java`
- **Verification:** `RoomIT#concurrentBothReadyCreatesOneMatch` and `bothReadyStartsJoinerTurn` pass
- **Committed in:** `811c896` (Task 2)

**2. [Rule 3 - Blocking] Guest mint limit in RoomIT**
- **Found during:** Task 2 verification
- **Issue:** Two extra concurrent tests mint enough guests to hit `nomad.guest.mint-limit-per-minute` default 20; `joinUnknownCodeIs404` then got HTTP 429 on mint.
- **Fix:** Set `nomad.guest.mint-limit-per-minute=100` on `RoomIT` `@SpringBootTest` properties. Production limiter unchanged.
- **Files modified:** `backend/src/test/java/com/nomadgames/matchmaking/RoomIT.java`
- **Verification:** RoomIT 12/12 green
- **Committed in:** `811c896` (Task 2)

**3. [Rule 2 - Missing Critical] Idle closer locks per row**
- **Found during:** Task 2
- **Issue:** `@Version` made the unlocked 1 Hz `closeExpiredLobbies` throw `ObjectOptimisticLockingFailureException` when it raced Ready/join/leave (scheduler ERROR during RoomIT).
- **Fix:** List expired ids, then `findByIdForUpdate` each row and close only if still LOBBY and past TTL (D-29).
- **Files modified:** `backend/src/main/java/com/nomadgames/matchmaking/RoomService.java`
- **Verification:** `RoomIT#idleTtlCloses` pass; scheduler no longer fails the suite
- **Committed in:** `811c896` (Task 2)

---

**Total deviations:** 3 auto-fixed (2 missing critical, 1 blocking)
**Impact on plan:** Required for concurrent both-tap matchId, RoomIT mint budget, and TTL closer under `@Version`. No rematch sync, no isolate-alive rejoin, no Forge2D reopen.

## Authentication Gates

None

## Known Stubs

None — concurrent Ready/join paths persist a real `matchId` / `joiner_id`; no placeholder lobby data.

## Issues Encountered

None remaining. RED `concurrentBothReadyCreatesOneMatch` failed on null `matchId` before the lock; GREEN after Task 2.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Ready for 03-12 (synchronize rematch window). Do not implement isolate-alive rejoin (03-13) in that plan. Concurrent Ready/join kickoff is closed for VERIFICATION truth 2 / CR-03.

## Self-Check: PASSED

- `V6__room_version.sql`, `RoomEntity` `@Version`, `RoomRepository` ForUpdate finders, `RoomService` ForUpdate join/ready/leave, `RoomIT` concurrent methods present on disk
- Commits `c0247a7` and `811c896` in git log `--grep=03-11`
- RoomIT 12/12, LeaveIT 2/2, RematchIT 4/4, ModularityTest 1/1 BUILD SUCCESS

---
*Phase: 03-private-rooms-casual-reconnect*
*Completed: 2026-09-08*
