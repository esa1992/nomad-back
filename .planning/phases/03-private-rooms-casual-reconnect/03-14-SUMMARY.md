---
phase: 03-private-rooms-casual-reconnect
plan: 14
subsystem: client-session
tags: [reconnect, rejoin, isolate-alive, 409, handshake, clearSeatDrop, sess-02, d-41, gap-closure]
status: complete

requires:
  - phase: 03-private-rooms-casual-reconnect
    provides: Isolate-alive POST /rejoin then ticket; one socket per seat (03-13)
provides:
  - Isolate-alive rejoin 409 while GET match is IN_PLAY keeps the rotating token and resumes via ws-ticket
  - Only HTTP 410 is treated as grace-gone
  - Retry loop success requires a new MatchSocket instance
  - Handshake after registry.add clears that playerId's seat grace without rotating the token
affects:
  - VERIFICATION truth 4 / CR-01 isolate-alive 409-as-expiry
  - Phase 3 UAT isolate-alive blip rejoin
  - Ranked reconnect budget (SESS-03, out of phase)

tech-stack:
  added: []
  patterns:
    - Only HTTP gone (410) clearsReconnect; conflict plus IN_PLAY tickets a new socket
    - Isolate-alive retry treats the pre-rejoin MatchSocket as still lost until identity changes
    - Ticket handshake clearSeatDrop unfreezes that seat after registry.add

key-files:
  created: []
  modified:
    - client/test/reconnect_overlay_test.dart
    - backend/src/test/java/com/nomadgames/session/ReconnectIT.java
    - client/lib/games/alchiki/match_page.dart
    - backend/src/main/java/com/nomadgames/session/MatchService.java
    - backend/src/main/java/com/nomadgames/session/internal/MatchWebSocketHandler.java

key-decisions:
  - "Only HTTP 410 is grace-gone; 409 plus GET IN_PLAY keeps the rotating token and mints a ws-ticket"
  - "Retry loop exits as success only when _socket is a different non-null instance and _rejoinError is false"
  - "Handshake after registry.add calls clearSeatDrop for ATTR_PLAYER_ID without rotating the reconnect token"

patterns-established:
  - "Pattern: living-client seat-not-dropped 409 is not expiry; GET match then ticket-connect while IN_PLAY"
  - "Pattern: dead MatchSocket plus false _rejoinError cannot stop isolate-alive retries"
  - "Pattern: consumed ws-ticket handshake clears that seat's grace so delayed markDropped cannot re-freeze it"

requirements-completed: [SESS-02]

coverage:
  - id: D1
    description: Isolate-alive first rejoin 409 while IN_PLAY keeps the token, hides Rejoin overlay, and reaches wsTicket
    requirement: SESS-02
    verification:
      - kind: unit
        ref: "client/test/reconnect_overlay_test.dart#isolate-alive first rejoin 409 keeps token then tickets and hides Rejoin match"
        status: pass
    human_judgment: false
  - id: D2
    description: Isolate-alive always-200 rejoin path and overlay remaining-12 still pass
    requirement: SESS-02
    verification:
      - kind: unit
        ref: "client/test/reconnect_overlay_test.dart#isolate-alive socket drop POSTs rejoin then wsTicket and hides Rejoin match"
        status: pass
      - kind: unit
        ref: "client/test/reconnect_overlay_test.dart#process-death overlay seeds reconnecting padded 12 from reconnectSecondsLeft not a fresh 30"
        status: pass
    human_judgment: false
  - id: D3
    description: Handshake after add clears that seat's grace; GET reconnectSecondsLeft is null; match stays IN_PLAY
    requirement: SESS-02
    verification:
      - kind: integration
        ref: "backend/src/test/java/com/nomadgames/session/ReconnectIT.java#handshakeClearsSeatGrace"
        status: pass
    human_judgment: false
  - id: D4
    description: Existing rejoin snapshot, token rotate/expiry HOST_WIN, consented leave, stale-close, rematch, and leave tests stay green; grace remains 30s with no bot-fill
    requirement: SESS-02
    verification:
      - kind: integration
        ref: "backend/src/test/java/com/nomadgames/session/ReconnectIT.java#rejoinWithin30sReturnsFullSnapshot"
        status: pass
      - kind: integration
        ref: "backend/src/test/java/com/nomadgames/session/ReconnectIT.java#tokenRotateAndExpire"
        status: pass
      - kind: integration
        ref: "backend/src/test/java/com/nomadgames/session/ReconnectIT.java#consentedLeaveHasNoGrace"
        status: pass
      - kind: integration
        ref: "backend/src/test/java/com/nomadgames/session/ReconnectIT.java#staleCloseAfterReplacementKeepsSeat"
        status: pass
      - kind: unit
        ref: "client/test/rematch_page_test.dart#private ResultOverlay Again? then getRematch yields new matchId and GameWidget"
        status: pass
    human_judgment: false

duration: 12min
completed: 2026-09-08
---

# Phase 3 Plan 14: Isolate-Alive 409 Gap Closure Summary

**Living private client treats only HTTP 410 as grace expiry; a 409 while GET match is IN_PLAY keeps the rotating token and resumes via a new ws-ticket; handshake after registry.add clears that seat's grace so delayed markDropped cannot re-freeze it**

## Performance

- **Duration:** 12 min
- **Started:** 2026-09-08T10:48:00Z
- **Completed:** 2026-09-08T10:56:39Z
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments

- Isolate-alive `_rejoinMatch` maps only status 410 to `_onGraceExpiredDropped`; status 409 GETs the stored match and, while IN_PLAY, mints a ws-ticket and connects without `clearReconnect`
- `_reconnectPrivateSocket` captures the lost `MatchSocket` and returns as success only when `_socket` is a different non-null instance and `_rejoinError` is false
- `MatchService.clearSeatDrop` nulls that playerId's grace (no token rotate, no REST route); `afterConnectionEstablished` calls it after `registry.add`

## Task Commits

1. **Task 1: Failing isolate-alive 409 and handshake-clears-grace tests** - `44da89e` (test)
2. **Task 2: 409 IN_PLAY resume, retry-loop identity, handshake clearSeatDrop** - `ebef447` (feat)

**Plan metadata:** pending `docs(03-14)` commit

## Files Created/Modified

- `client/test/reconnect_overlay_test.dart` - Isolate-alive first-rejoin 409 stub plus keep-token assertions
- `backend/src/test/java/com/nomadgames/session/ReconnectIT.java` - `handshakeClearsSeatGrace` (ticket connect, no POST rejoin)
- `client/lib/games/alchiki/match_page.dart` - 410-only expiry, 409 IN_PLAY ticket-connect, socket identity retry
- `backend/src/main/java/com/nomadgames/session/MatchService.java` - `clearSeatDrop` for the handshake playerId
- `backend/src/main/java/com/nomadgames/session/internal/MatchWebSocketHandler.java` - `registry.add` then `clearSeatDrop`

## Decisions Made

- On rejoin 409, GET match; terminal statuses apply the snapshot; IN_PLAY keeps the token and uses the existing ticket-then-listen attach path
- GET failure on conflict sets `_rejoinError` and does not invent HOST_WIN or JOINER_WIN
- Handshake `clearSeatDrop` is wrapped in `ResponseStatusException` catch so a missing match cannot abort the open socket (same shape as `markDropped`)
- Grace stays 30s; PRIVATE expiry still HOST_WIN/JOINER_WIN; no bot-fill; Forge2D not reopened; CR-02/CR-05 out of scope

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing error handling] Handshake clearSeatDrop catch**
- **Found during:** Task 2
- **Issue:** `requireSeat` can throw 404/403; an uncaught exception in `afterConnectionEstablished` would drop a just-opened ticket socket
- **Fix:** Catch `ResponseStatusException` around `clearSeatDrop`, matching `afterConnectionClosed` / `markDropped`
- **Files modified:** `backend/src/main/java/com/nomadgames/session/internal/MatchWebSocketHandler.java`
- **Verification:** `ReconnectIT#handshakeClearsSeatGrace` plus existing reconnect ITs green
- **Committed in:** `ebef447`

**Total deviations:** 1 auto-fixed (Rule 2)
**Impact on plan:** Necessary for handshake correctness (T-03-53). No scope creep.

## Issues Encountered

PowerShell parsed unquoted `-Dtest=A,B,C` as multiple arguments; re-ran Maven with a quoted `-Dtest` list.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Phase 3 plans 1–14 all have SUMMARYs; remaining VERIFICATION.md `gaps:` item (isolate-alive 409-as-expiry) is closed in source
- CR-02 private clock forfeit and CR-05 Flutter WS close 4000 remain out of this plan by design
- Ranked reconnect budget (SESS-03) stays Phase 7
## Self-Check: PASSED

- SUMMARY, match_page, MatchService, MatchWebSocketHandler, reconnect_overlay_test, ReconnectIT exist on disk
- Commits `44da89e` (test) and `ebef447` (feat) present in git log

---
*Phase: 03-private-rooms-casual-reconnect*
*Completed: 2026-09-08*
