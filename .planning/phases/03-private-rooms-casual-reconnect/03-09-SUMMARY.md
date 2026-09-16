---
phase: 03-private-rooms-casual-reconnect
plan: 09
subsystem: session
tags: [reconnect, rejoin, grace-30s, rotating-token, snapshot, sess-02, d-41, d-42]
status: complete

requires:
  - phase: 03-private-rooms-casual-reconnect
    provides: PRIVATE IN_PLAY ws-ticket, unexpected close is not leave, HOST_WIN/JOINER_WIN leave
provides:
  - 30s private seat hold with paused clocks and OpponentDropped
  - Rotating SHA-256 reconnect token plus POST /v1/matches/{id}/rejoin full RejoinSnapshot
  - Grace-expiry remaining-player win with no bot-fill
affects:
  - Phase 3 Flutter auto-retry / Rejoin overlay (03-10)
  - Ranked reconnect budget (SESS-03, out of phase)

tech-stack:
  added: []
  patterns:
    - Opaque 32-byte reconnect token, SHA-256 at rest on matches, rotate on successful rejoin
    - Heap LiveMatch freeze of remaining turn/match/hardCap durations; rewrite clocks as now+remaining on rejoin
    - REST POST rejoin then existing ws-ticket + raw WS (not a client delta)

key-files:
  created:
    - backend/src/main/resources/db/migration/V5__reconnect_tokens.sql
    - backend/src/main/java/com/nomadgames/session/internal/ReconnectPolicy.java
    - backend/src/test/java/com/nomadgames/session/ReconnectIT.java
    - backend/src/main/java/com/nomadgames/session/RejoinSnapshot.java
    - backend/src/main/java/com/nomadgames/session/RejoinRequest.java
  modified:
    - backend/src/main/java/com/nomadgames/session/internal/MatchEntity.java
    - backend/src/main/java/com/nomadgames/session/internal/MatchSessionRegistry.java
    - backend/src/main/java/com/nomadgames/session/internal/MatchWebSocketHandler.java
    - backend/src/main/java/com/nomadgames/session/MatchController.java
    - backend/src/main/java/com/nomadgames/session/MatchService.java
    - backend/src/main/java/com/nomadgames/session/WsTicketResponse.java

key-decisions:
  - "Casual private reconnect grace is 30 seconds with clocks frozen for DISCONNECTED seats (SESS-02, D-41)"
  - "Rejoin is REST POST /v1/matches/{id}/rejoin then a new ws-ticket; response is a full RejoinSnapshot, never a client delta (D-41)"
  - "Grace expiry awards HOST_WIN/JOINER_WIN to the remaining human; never nextBotThrow on a PRIVATE row (D-42)"
  - "Heap-only live freeze and plaintext tokens: a JVM restart mid-match cannot resume (A3)"

patterns-established:
  - "Pattern: unexpected WS close calls markDropped (30s); close 4000 / REST leave still 0s forfeit"
  - "Pattern: reconnect token plaintext is issued on ws-ticket for 03-10 storage; hash columns nullable for BOT"

requirements-completed: [SESS-02]

coverage:
  - id: D1
    description: Rejoin within 30s returns IN_PLAY full snapshot with bones/scores and a future turnDeadline (clocks paused)
    requirement: SESS-02
    verification:
      - kind: integration
        ref: "backend/src/test/java/com/nomadgames/session/ReconnectIT.java#rejoinWithin30sReturnsFullSnapshot"
        status: pass
    human_judgment: false
  - id: D2
    description: Reconnect token rotates on use; replay of the old token is 401
    requirement: SESS-02
    verification:
      - kind: integration
        ref: "backend/src/test/java/com/nomadgames/session/ReconnectIT.java#tokenRotateAndExpire"
        status: pass
    human_judgment: false
  - id: D3
    description: After 30s grace the remaining player is HOST_WIN and rejoin is 409/410; no bot-fill
    requirement: SESS-02
    verification:
      - kind: integration
        ref: "backend/src/test/java/com/nomadgames/session/ReconnectIT.java#tokenRotateAndExpire"
        status: pass
    human_judgment: false
  - id: D4
    description: Consented leave has 0s grace and does not leave a rejoinable seat
    requirement: SESS-02
    verification:
      - kind: integration
        ref: "backend/src/test/java/com/nomadgames/session/ReconnectIT.java#consentedLeaveHasNoGrace"
        status: pass
    human_judgment: false
  - id: D5
    description: LeaveIT private leave still immediate opponent win; ThrowAuthorityIT still passes
    requirement: SESS-02
    verification:
      - kind: integration
        ref: "backend/src/test/java/com/nomadgames/session/LeaveIT.java#privateLeaveOpponentWins"
        status: pass
    human_judgment: false

duration: 20min
completed: 2026-09-07
---

# Phase 3 Plan 09: Server 30s reconnect Summary

**Private unexpected drop holds the seat 30s with paused clocks; rejoin rotates a SHA-256 token and applies a full RejoinSnapshot; grace expiry is remaining-player HOST_WIN/JOINER_WIN with no bot-fill (SESS-02, D-41, D-42)**

## Performance

- **Duration:** 20 min
- **Started:** 2026-09-07T09:26:38Z
- **Completed:** 2026-09-07T09:46:00Z
- **Tasks:** 2
- **Files modified:** 11

## Accomplishments

- `ReconnectIT` locks 30s snapshot rejoin, token rotate + replay 401, grace-expiry remaining win, and 0s consented leave
- `ReconnectPolicy` grace is 30 seconds; V5 stores `host_reconnect_token_hash` / `joiner_reconnect_token_hash` (nullable for BOT)
- Unexpected WS close `markDropped` + `OpponentDropped`; `POST /v1/matches/{id}/rejoin` returns full `RejoinSnapshot` then a new ws-ticket; close 4000 / REST leave stay immediate forfeit

## Task Commits

Each task was committed atomically:

1. **Task 1: Failing ReconnectIT** - `1299710` (test)
2. **Task 2: 30s seat hold, snapshot rejoin, grace expiry** - `b5a8bb1` (feat)

**Plan metadata:** docs commit with this SUMMARY

## Files Created/Modified

- `backend/src/test/java/com/nomadgames/session/ReconnectIT.java` - snapshot, rotate/expiry, consented leave
- `backend/src/main/resources/db/migration/V5__reconnect_tokens.sql` - BYTEA hash columns on matches
- `backend/src/main/java/com/nomadgames/session/internal/ReconnectPolicy.java` - 30s grace, mint/hash/rotate, freeze clocks
- `backend/src/main/java/com/nomadgames/session/internal/MatchEntity.java` - hash columns + match/hardCap setters
- `backend/src/main/java/com/nomadgames/session/internal/MatchSessionRegistry.java` - heap `LiveMatch` freeze, plaintext, last throw
- `backend/src/main/java/com/nomadgames/session/internal/MatchWebSocketHandler.java` - unexpected close → `markDropped`
- `backend/src/main/java/com/nomadgames/session/MatchController.java` - `POST /{id}/rejoin`
- `backend/src/main/java/com/nomadgames/session/MatchService.java` - issue tokens, freeze, rejoin snapshot, 1 Hz expiry win
- `backend/src/main/java/com/nomadgames/session/WsTicketResponse.java` - plaintext `reconnectToken` for 03-10
- `backend/src/main/java/com/nomadgames/session/RejoinRequest.java` - `{ token }`
- `backend/src/main/java/com/nomadgames/session/RejoinSnapshot.java` - type, match, last throw, saka poses, rotated token

## Decisions Made

- **30s not a longer window** — `ReconnectPolicy.GRACE_SECONDS = 30` (SESS-02 / D-41). Ranked budget and Stick Pull policy stay out.
- **REST rejoin then ticket** — `POST /rejoin` validates the rotating token and returns a full snapshot; the client then mints a new ws-ticket (plan pick, 03-10 will call this).
- **No bot-fill** — grace housekeeping sets `HOST_WIN`/`JOINER_WIN` only; it never calls `nextBotThrow` on a PRIVATE row (D-42).
- **A3 heap live session** — freeze durations and plaintext tokens live on the JVM `LiveMatch`. Hashes persist in Postgres, but a server restart mid-match cannot resume paused clocks or re-issue the original plaintext. Documented; not a silent resume.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Second OpponentDropped await reused the first frame**
- **Found during:** Task 2 (`tokenRotateAndExpire`)
- **Issue:** Host `CollectingListener` still held the first `OpponentDropped` after the successful rejoin, so the second drop wait could return immediately.
- **Fix:** `host.messages.clear()` before the second unexpected close.
- **Files modified:** `backend/src/test/java/com/nomadgames/session/ReconnectIT.java`
- **Verification:** `ReconnectIT#tokenRotateAndExpire` pass
- **Committed in:** `b5a8bb1` (Task 2)

---

**Total deviations:** 1 auto-fixed (1 bug)
**Impact on plan:** Required for honest 30s expiry coverage. No Flutter overlay, no Ranked/Stick Pull reconnect, no Forge2D reopen.

## Issues Encountered

None

## Authentication Gates

None

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Ready for 03-10 (Flutter auto-retry, HUD reconnecting banner, SessionStore token, Rejoin overlay). Server contract: 30s grace, `reconnectToken` on ws-ticket, `POST /rejoin` full snapshot, 0s consented leave. Client must not invent a longer window or bot-fill a friend’s seat.

A3: do not expect a dropped private match to survive a JVM restart.

---

*Phase: 03-private-rooms-casual-reconnect*
*Completed: 2026-09-07*

## Self-Check: PASSED

- FOUND: `backend/src/main/java/com/nomadgames/session/internal/ReconnectPolicy.java`
- FOUND: `backend/src/test/java/com/nomadgames/session/ReconnectIT.java`
- FOUND: `backend/src/main/resources/db/migration/V5__reconnect_tokens.sql`
- FOUND: `backend/src/main/java/com/nomadgames/session/MatchController.java`
- FOUND: `.planning/phases/03-private-rooms-casual-reconnect/03-09-SUMMARY.md`
- FOUND commits: `1299710` test(03-09), `b5a8bb1` feat(03-09)
