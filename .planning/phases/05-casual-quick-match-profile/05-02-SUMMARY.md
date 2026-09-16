---
phase: 05-casual-quick-match-profile
plan: 02
subsystem: api
tags: [matchmaking, casual, createCasualMatch, humanMatch, FIFO, SESS-02, MODE-03]

requires:
  - phase: 05-casual-quick-match-profile
    provides: Wave 0 RED CasualQueueIT + ReconnectIT.casualRejoinWithinGrace stubs
  - phase: 03-private-rooms-casual-reconnect
    provides: createPrivateMatch / JoinRateLimiter / WS reconnect plumbing
  - phase: 04-economy-cosmetic-shop
    provides: MatchRewardTable private/human grant column
provides:
  - "createCasualMatch + isHumanPvP for CASUAL seats"
  - "In-process CasualQueueService FIFO pair-on-enqueue REST /v1/matchmaking/casual"
  - "afterTerminal humanMatch=true for PRIVATE and CASUAL (BOT false)"
  - "Green CasualQueueIT + ReconnectIT.casualRejoinWithinGrace"
affects:
  - 05-03 Searching UI
  - 05-04 fallback CTAs
  - 05-05 casual rematch

tech-stack:
  added: []
  patterns:
    - "isHumanPvP(mode) gates WS/leave/rejoin/seat/grants for PRIVATE||CASUAL"
    - "In-process ConcurrentLinkedQueue + ConcurrentHashMap pair-on-enqueue under monitor"
    - "MatchRewardCommand.humanMatch renamed from privateMatch (RESEARCH Q1)"

key-files:
  created:
    - backend/src/main/java/com/nomadgames/matchmaking/CasualQueueService.java
    - backend/src/main/java/com/nomadgames/matchmaking/CasualMatchmakingController.java
    - backend/src/main/java/com/nomadgames/matchmaking/CasualQueueResponse.java
  modified:
    - backend/src/main/java/com/nomadgames/session/MatchService.java
    - backend/src/main/java/com/nomadgames/session/internal/MatchRepository.java
    - backend/src/main/java/com/nomadgames/matchmaking/internal/JoinRateLimiter.java
    - backend/src/main/java/com/nomadgames/economy/MatchRewardCommand.java
    - backend/src/main/java/com/nomadgames/economy/MatchRewardTable.java
    - backend/src/main/java/com/nomadgames/economy/EconomyService.java
    - backend/src/test/java/com/nomadgames/matchmaking/CasualQueueIT.java

key-decisions:
  - "DELETE /casual returns 200 IDLE body (IT contract) rather than bare 204"
  - "JoinRateLimiter.reset + CasualQueueService.reset clear shared IT state between methods"
  - "Rematch create branch stays private-only until 05-05"

patterns-established:
  - "createHumanMatch(host, joiner, mode) shared by createPrivateMatch and createCasualMatch"
  - "humanMatch grant flag derived from isHumanPvP(mode) only — never client-supplied"

requirements-completed: [MODE-03, SESS-02]

coverage:
  - id: D1
    description: "Two guests pair into one CASUAL NORMAL match via createCasualMatch"
    requirement: MODE-03
    verification:
      - kind: integration
        ref: "backend/.../CasualQueueIT.java#twoPlayersPair"
        status: pass
    human_judgment: false
  - id: D2
    description: "CASUAL reuses private WS/seat/reconnect; 30s rejoin works (SESS-02)"
    requirement: SESS-02
    verification:
      - kind: integration
        ref: "backend/.../ReconnectIT.java#casualRejoinWithinGrace"
        status: pass
    human_judgment: false
  - id: D3
    description: "CASUAL settle grants use humanMatch=true same table as PRIVATE"
    requirement: MODE-03
    verification:
      - kind: integration
        ref: "backend/.../CasualQueueIT.java#casualSettleGrantsMatchPrivatePath"
        status: pass
    human_judgment: false
  - id: D4
    description: "Enqueue rate-limited; reject while IN_PLAY human seat"
    requirement: MODE-03
    verification:
      - kind: integration
        ref: "backend/.../CasualQueueIT.java#enqueueRateLimited"
        status: pass
    human_judgment: false

duration: 25min
completed: 2026-09-11
status: complete
---

# Phase 05 Plan 02: Backend Quick Match Summary

**In-process FIFO casual queue pairs guests into CASUAL matches with humanMatch settle grants and 30s rejoin**

## Performance

- **Duration:** 25 min
- **Started:** 2026-09-11T10:31:59Z
- **Completed:** 2026-09-11T10:57:00Z
- **Tasks:** 2
- **Files modified:** 10

## Accomplishments
- `createCasualMatch` + `isHumanPvP` generalize private WS/leave/rejoin/seat for CASUAL
- REST `/v1/matchmaking/casual` POST/GET/DELETE with JoinRateLimiter and IN_PLAY reject
- Economy `privateMatch` renamed to `humanMatch`; CASUAL settle parity with private table

## Task Commits

Each task was committed atomically:

1. **Task 1: createCasualMatch + isHumanPvP + FIFO queue** - `dea4cc1` (feat)
2. **Task 2: afterTerminal humanMatch grants for CASUAL** - `21f72c4` (feat)

**Plan metadata:** `fa82496` (docs: complete plan)

## Files Created/Modified
- `CasualQueueService.java` / `CasualMatchmakingController.java` / `CasualQueueResponse.java` — FIFO enqueue/pair/poll/dequeue
- `MatchService.java` — createCasualMatch, isHumanPvP guards, humanMatch afterTerminal
- `MatchRepository.java` — existsInPlayHumanSeat query
- `JoinRateLimiter.java` — reset() for IT isolation
- `MatchRewardCommand` / `MatchRewardTable` / `EconomyService` — humanMatch rename
- `CasualQueueIT.java` — BeforeEach resets limiter + queue

## Decisions Made
- Follow CasualQueueIT DELETE → 200 IDLE (not plan prose 204)
- Add reset() on limiter and queue so flood/SEARCHING state does not leak across IT methods
- Keep requirePrivateTerminal / rematch create on PRIVATE only (05-05 owns CASUAL rematch)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] JoinRateLimiter.reset for IT isolation**
- **Found during:** Task 1 (enqueueRateLimited poisoned sibling tests via shared 127.0.0.1 window)
- **Issue:** Flood test filled IP bucket; later CasualQueueIT / room-join paths returned 429
- **Fix:** Added `JoinRateLimiter.reset()` and `@BeforeEach` clear in CasualQueueIT
- **Files modified:** JoinRateLimiter.java, CasualQueueIT.java
- **Verification:** CasualQueueIT 6/6 green
- **Committed in:** dea4cc1 (Task 1)

**2. [Rule 1 - Bug] CasualQueueService.reset for heap FIFO leak**
- **Found during:** Task 1 (singlePlayerStaysSearching got MATCHED against orphan SEARCHING peer)
- **Issue:** In-process queue survives between SpringBootTest methods
- **Fix:** `CasualQueueService.reset()` cleared in same `@BeforeEach`
- **Files modified:** CasualQueueService.java, CasualQueueIT.java
- **Verification:** singlePlayerStaysSearching green
- **Committed in:** dea4cc1 (Task 1)

**3. [Rule 2 - Missing Critical] afterTerminal human path in Task 1**
- **Found during:** Task 1 (CasualQueueIT includes casualSettleGrantsMatchPrivatePath)
- **Issue:** Task 1 verify suite required settle grants before Task 2 rename
- **Fix:** Drove dual-seat grants from `isHumanPvP` in Task 1; Task 2 renamed flag to humanMatch
- **Files modified:** MatchService.java (then economy rename in Task 2)
- **Verification:** casualSettleGrantsMatchPrivatePath + EconomyIT green
- **Committed in:** dea4cc1 / 21f72c4

---

**Total deviations:** 3 auto-fixed (2 missing critical, 1 bug)
**Impact on plan:** Necessary for IT correctness and MODE-03 settle; no scope creep beyond plan files.

## Issues Encountered
- PowerShell muffles Maven exit codes; used Surefire output for BUILD SUCCESS/FAILURE
- Parent git repo requires `nomad-game/` path prefixes on commit

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Backend Quick Match path ready for 05-03 Searching UI and catalog CTA
- CASUAL rematch create branch intentionally deferred to 05-05

## Self-Check: PASSED
- FOUND: CasualQueueService, CasualMatchmakingController, createCasualMatch, isHumanPvP, humanMatch
- FOUND: commits dea4cc1, 21f72c4

---
*Phase: 05-casual-quick-match-profile*
*Completed: 2026-09-11*
