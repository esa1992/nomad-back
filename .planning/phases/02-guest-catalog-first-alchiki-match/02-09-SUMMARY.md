---
phase: 02-guest-catalog-first-alchiki-match
plan: 09
subsystem: session
tags: [leave, sess-01, match-authority, bot-win, d-23]

requires:
  - phase: 02-guest-catalog-first-alchiki-match
    provides: IN_PLAY leave → BOT_WIN (02-05); applyThrow no-ops when status is not IN_PLAY (02-04)
provides:
  - leaveMatch writes BOT_WIN only while IN_PLAY
  - POST /leave after PLAYER_WIN or DRAW returns 200 with unchanged status
  - ThrowAuthorityIT leave-after-terminal proofs
affects:
  - Phase 3 rematch / reconnect (finished match rows stay honest)
  - Phase 2 SESS-01 verification gap closure

tech-stack:
  added: []
  patterns:
    - leaveMatch IN_PLAY-only forfeit; terminal statuses return LeaveResponse(snapshot) with no persist
    - IT seeds terminal status via JdbcTemplate UPDATE matches SET status, not five physics throws

key-files:
  created: []
  modified:
    - backend/src/main/java/com/nomadgames/session/MatchService.java
    - backend/src/test/java/com/nomadgames/session/ThrowAuthorityIT.java

key-decisions:
  - "leaveMatch returns HTTP 200 with the existing LeaveResponse snapshot when status is not IN_PLAY (not 409), matching applyThrow"
  - "ThrowAuthorityIT seeds PLAYER_WIN/DRAW with setMatchStatus JDBC UPDATE; AlchikiRules still owns how those statuses are produced in play"

patterns-established:
  - "Pattern: MatchService no-ops mutating writes when match.status is not IN_PLAY (applyThrow and leaveMatch)"
  - "Pattern: consented IN_PLAY leave remains BOT_WIN; a second leave after BOT_WIN is idempotent"

requirements-completed: [SESS-01]

coverage:
  - id: D1
    description: POST /leave after PLAYER_WIN returns 200 and leaves match.status PLAYER_WIN
    requirement: SESS-01
    verification:
      - kind: integration
        ref: "backend/src/test/java/com/nomadgames/session/ThrowAuthorityIT.java#leaveAfterPlayerWinPreservesPlayerWin"
        status: pass
    human_judgment: false
  - id: D2
    description: POST /leave after DRAW returns 200 and leaves match.status DRAW
    requirement: SESS-01
    verification:
      - kind: integration
        ref: "backend/src/test/java/com/nomadgames/session/ThrowAuthorityIT.java#leaveAfterDrawPreservesDraw"
        status: pass
    human_judgment: false
  - id: D3
    description: IN_PLAY owner leave still records BOT_WIN
    requirement: SESS-01
    verification:
      - kind: integration
        ref: "backend/src/test/java/com/nomadgames/session/ThrowAuthorityIT.java#leaveMatchReturnsBotWin"
        status: pass
    human_judgment: false
  - id: D4
    description: Full ThrowAuthorityIT class stays green after the leave IN_PLAY guard
    requirement: SESS-01
    verification:
      - kind: integration
        ref: "mvnw -pl backend -am test -Dtest=ThrowAuthorityIT"
        status: pass
    human_judgment: false

duration: 4min
completed: 2026-09-07
status: complete
---

# Phase 2 Plan 09: Leave After Terminal Status Summary

**POST /v1/matches/{id}/leave writes BOT_WIN only while IN_PLAY; PLAYER_WIN and DRAW survive a client leave (SESS-01 / D-23)**

## Performance

- **Duration:** 4 min
- **Started:** 2026-09-07T03:26:07Z
- **Completed:** 2026-09-07T03:29:27Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- `MatchService.leaveMatch` returns the current snapshot without `setStatus`/`save` when the row is not `IN_PLAY`
- Consented leave on an `IN_PLAY` match still persists `BOT_WIN` (02-05 behavior kept)
- `ThrowAuthorityIT.leaveAfterPlayerWinPreservesPlayerWin` and `leaveAfterDrawPreservesDraw` prove a finished result cannot become `BOT_WIN`
- Full `ThrowAuthorityIT` (12 tests) exits 0, including `leaveMatchReturnsBotWin`

## Task Commits

Each task was committed atomically:

1. **Task 1: Fail leave-after-terminal ITs** - `00a84cb` (test)
2. **Task 2: Guard leaveMatch on IN_PLAY** - `eced56f` (feat)

**Plan metadata:** pending docs(02-09) complete leave-authority gap plan

## Files Created/Modified

- `backend/src/test/java/com/nomadgames/session/ThrowAuthorityIT.java` - `setMatchStatus` plus leave-after-PLAYER_WIN and leave-after-DRAW ITs
- `backend/src/main/java/com/nomadgames/session/MatchService.java` - IN_PLAY gate on `leaveMatch`

## Decisions Made

- Terminal leave is HTTP 200 + unchanged `LeaveResponse.match.status`, not 409, so leave stays consistent with `applyThrow` and `{ match: snapshot }`
- IT seeding uses `JdbcTemplate UPDATE matches SET status = ?` next to `expireTurnDeadline`; no extra Testcontainers, no Flyway, no five-throw path to first-to-5
- Already-`BOT_WIN` leave is covered by the same IN_PLAY gate (idempotent); no third RED test because that case would already pass

## Deviations from Plan

None - plan executed exactly as written.

**Total deviations:** 0 auto-fixed
**Impact on plan:** None.

## Issues Encountered

None

## Authentication Gates

None

## TDD Gate Compliance

- RED: `00a84cb` `test(02-09): add failing test for leave after terminal status` — both named methods failed `expected:<PLAYER_WIN|DRAW> but was:<BOT_WIN>`
- GREEN: `eced56f` `feat(02-09): guard leaveMatch on IN_PLAY only` — `ThrowAuthorityIT` 12/12 pass
- REFACTOR: skipped (implementation is the minimal `applyThrow` mirror)

## Known Stubs

None. `leaveMatch` returns a live snapshot; no placeholder status or empty match payload.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- SESS-01 leave hole closed; Phase 2 plans 01–09 all have summaries
- Ready for `/gsd-verify-work 02` (device UAT for BOT-03 / PRES-02 still human)
- Do not reopen Forge2D 0.15; no rooms, shop, Ranked, or Stick Pull playable in this slice

## Self-Check: PASSED

- FOUND: `backend/src/main/java/com/nomadgames/session/MatchService.java`
- FOUND: `backend/src/test/java/com/nomadgames/session/ThrowAuthorityIT.java`
- FOUND: `00a84cb` test(02-09)
- FOUND: `eced56f` feat(02-09)
- Verify: `mvnw -pl backend -am test -Dtest=ThrowAuthorityIT` → Tests run: 12, Failures: 0

---
*Phase: 02-guest-catalog-first-alchiki-match*
*Completed: 2026-09-07*
