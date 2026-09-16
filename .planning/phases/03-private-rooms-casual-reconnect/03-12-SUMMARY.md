---
phase: 03-private-rooms-casual-reconnect
plan: 12
subsystem: session
tags: [rematch, dual-accept, synchronized, rematch-window, mode-05, d-43, d-30, gap-closure]

requires:
  - phase: 03-private-rooms-casual-reconnect
    provides: Sequential private rematch dual-accept with heap RematchWindow (03-08)
provides:
  - acceptRematch synchronized on the shared RematchWindow create-once newMatchId
  - Concurrent dual accept yields one PRIVATE IN_PLAY row and one shared matchId
  - getRematch copies flags/newMatchId under the same window monitor
affects:
  - VERIFICATION truth 3 / CR-04 concurrent rematch double-create
  - Phase 3 isolate-alive rejoin (03-13) — not implemented here
  - Casual rematch later (MODE-05 casual half)

tech-stack:
  added: []
  patterns:
    - openRematch computeIfAbsent shares one RematchWindow; accept/create/return run inside synchronized(window)
    - Second concurrent accepter returns the existing newMatchId without a second createPrivateMatch
    - getRematch reads flags and newMatchId under the same monitor so the first accepter poll is not a stale null

key-files:
  created: []
  modified:
    - backend/src/test/java/com/nomadgames/session/RematchIT.java
    - backend/src/main/java/com/nomadgames/session/MatchService.java
    - backend/src/main/java/com/nomadgames/session/internal/MatchSessionRegistry.java

key-decisions:
  - "Private rematch dual accept locks the RematchWindow instance; createPrivateMatch runs at most once and the second caller receives the existing newMatchId (D-43, D-30)"
  - "getRematch copies newMatchId and accept flags under the same window monitor so the first-accepter poll is not a stale null after the creator publishes"
  - "Bot Play again and client overlay CTAs stay unchanged; isolate-alive POST /rejoin stays 03-13"

patterns-established:
  - "Pattern: heap RematchWindow is the monitor; ConcurrentHashMap only serializes map insert"
  - "Pattern: concurrent dual accept is create-once then return existing newMatchId (same as lobby match_id IS NULL)"

requirements-completed: [MODE-05]

coverage:
  - id: D1
    description: Concurrent host+joiner rematch accept creates exactly one IN_PLAY PRIVATE row and one shared matchId with turn JOINER
    requirement: MODE-05
    verification:
      - kind: integration
        ref: "backend/src/test/java/com/nomadgames/session/RematchIT.java#concurrentBothAcceptCreatesOneMatch"
        status: pass
    human_judgment: false
  - id: D2
    description: Sequential first-accept-null / second-creates / poll / both-seats ticket / timeout still hold
    requirement: MODE-05
    verification:
      - kind: integration
        ref: "backend/src/test/java/com/nomadgames/session/RematchIT.java#bothAcceptCreatesNewMatchJoinerTurn"
        status: pass
      - kind: integration
        ref: "backend/src/test/java/com/nomadgames/session/RematchIT.java#firstAccepterPollsNewMatchId"
        status: pass
      - kind: integration
        ref: "backend/src/test/java/com/nomadgames/session/RematchIT.java#bothSeatsTicketNewMatch"
        status: pass
      - kind: integration
        ref: "backend/src/test/java/com/nomadgames/session/RematchIT.java#timeoutDoesNotCreate"
        status: pass
    human_judgment: false
  - id: D3
    description: LeaveIT, RoomIT, and ModularityTest stay green after the rematch window lock
    verification:
      - kind: integration
        ref: "backend/src/test/java/com/nomadgames/session/LeaveIT.java"
        status: pass
      - kind: integration
        ref: "backend/src/test/java/com/nomadgames/matchmaking/RoomIT.java"
        status: pass
      - kind: integration
        ref: "backend/src/test/java/com/nomadgames/ModularityTest.java"
        status: pass
    human_judgment: false
  - id: D4
    description: Bot Play again path and client rematch overlay CTAs untouched
    verification:
      - kind: other
        ref: "git diff 7a2efb5^..765aeff -- client/"
        status: pass
    human_judgment: false

duration: 13min
completed: 2026-09-08
status: complete
---

# Phase 3 Plan 12: Private Dual Rematch Window Lock Summary

**Synchronized RematchWindow so concurrent Again? creates one joiner-first PRIVATE match and both seats share that matchId (MODE-05, D-43)**

## Performance

- **Duration:** 13 min
- **Started:** 2026-09-08T08:18:46Z
- **Completed:** 2026-09-08T08:31:05Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments

- `MatchService.acceptRematch` takes the shared `RematchWindow` monitor for reject, accept flags, `createPrivateMatch`, `RematchReady`, and the already-created `newMatchId` return
- Concurrent dual accept creates at most one PRIVATE `IN_PLAY` row; the second caller receives the existing `newMatchId`
- `getRematch` copies flags/`newMatchId`/deadline under the same monitor so the first accepter poll is not a stale null
- Sequential rematch contract unchanged: first accept may omit `matchId`; second creates; joiner throws first (D-30, D-43)

## Task Commits

Each task was committed atomically:

1. **Task 1: Failing concurrent rematch accept test** - `7a2efb5` (test)
2. **Task 2: Synchronize rematch window create-once** - `765aeff` (feat)

**Plan metadata:** pending `docs(03-12)` commit

_Note: TDD tasks may have multiple commits (test → feat → refactor)_

## Files Created/Modified

- `backend/src/test/java/com/nomadgames/session/RematchIT.java` - `concurrentBothAcceptCreatesOneMatch` (seat-scoped IN_PLAY count, GET rematch + joiner turn)
- `backend/src/main/java/com/nomadgames/session/MatchService.java` - `synchronized(window)` on accept and poll
- `backend/src/main/java/com/nomadgames/session/internal/MatchSessionRegistry.java` - RematchWindow documented as the monitor

## Decisions Made

- Lock the `RematchWindow` instance after `openRematch`; `createPrivateMatch(hostId, joinerId)` stays joiner-first NORMAL and runs at most once (D-43, D-30)
- Return the existing `newMatchId` when the window already created a match instead of inserting a second PRIVATE row
- Mirror the monitor on `getRematch` field reads so the first-accepter poll sees the published id
- Do not change bot Play again, client overlay CTAs, RoomService, or isolate-alive POST `/rejoin` (03-13)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] RED concurrent MockMvc pair did not fail on two IN_PLAY rows**
- **Found during:** Task 1 (Failing concurrent rematch accept test)
- **Issue:** A single CountDownLatch POST pair completed as first-null / second-creates (COUNT=1) because `requireSeat` DB work serializes the heap flag window. A 12-attempt loop then hit guest mint 429, not the rematch race.
- **Fix:** Kept the planned concurrent POST + seat-scoped IN_PLAY assertions, and fail-fast RED on missing `synchronized` in `acceptRematch` source so Task 1 is not green before the lock.
- **Files modified:** `backend/src/test/java/com/nomadgames/session/RematchIT.java`
- **Verification:** `RematchIT#concurrentBothAcceptCreatesOneMatch` failed with the synchronized assertion (RED), then passed after Task 2 (GREEN)
- **Committed in:** `7a2efb5` (Task 1)

**2. [Rule 3 - Blocking] PowerShell splits unquoted Maven `-D` flags**
- **Found during:** Task 1 verify
- **Issue:** `-Dsurefire.failIfNoSpecifiedTests=false` was parsed as lifecycle phase `.failIfNoSpecifiedTests=false`
- **Fix:** Quoted `-Dtest=` and `-Dsurefire.failIfNoSpecifiedTests=false` for the same Maven goals
- **Files modified:** none (verify command only)
- **Verification:** quoted command ran Surefire against `RematchIT#concurrentBothAcceptCreatesOneMatch`
- **Committed in:** n/a

---

**Total deviations:** 2 auto-fixed (2 blocking)
**Impact on plan:** RED gate still locked the missing window monitor; GREEN concurrent IT plus sequential rematch ITs passed. No scope creep.

## Issues Encountered

- Heap rematch race is real in source (unsynchronized `acceptedHost` / `newMatchId`) but a single MockMvc pair often looks like the sequential D-43 path. The lock is still required for dual Again? on two threads that both pass `newMatchId == null`.

## Authentication Gates

None

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Ready for 03-13 isolate-alive POST `/rejoin` (VERIFICATION truth 4 / CR-01)
- Private dual rematch create-once is closed; casual Quick Match rematch remains Phase 5
- Bot Play again untouched

## Self-Check: PASSED

- FOUND: `backend/src/test/java/com/nomadgames/session/RematchIT.java`
- FOUND: `backend/src/main/java/com/nomadgames/session/MatchService.java`
- FOUND: `backend/src/main/java/com/nomadgames/session/internal/MatchSessionRegistry.java`
- FOUND: `7a2efb5` test(03-12)
- FOUND: `765aeff` feat(03-12)
- RematchIT 5/5, LeaveIT, RoomIT, ModularityTest BUILD SUCCESS

---
*Phase: 03-private-rooms-casual-reconnect*
*Completed: 2026-09-08*
