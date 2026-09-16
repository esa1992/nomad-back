---
phase: 03-private-rooms-casual-reconnect
plan: 13
subsystem: client-session
tags: [reconnect, rejoin, isolate-alive, remaining-grace, match-session-registry, sess-02, d-41, gap-closure]
status: complete

requires:
  - phase: 03-private-rooms-casual-reconnect
    provides: POST /rejoin rotating token, process-death overlay, isolate-alive ticket-only retry (03-09, 03-10)
provides:
  - Isolate-alive onDone POSTs /rejoin with stored token then persist rotated token then ws-ticket
  - GET match reconnectSecondsLeft (0–30) seeds Rejoin overlay remaining grace
  - One WebSocket decorator per playerId; stale close skips markDropped while hasOpenSeat
affects:
  - VERIFICATION truth 4 / CR-01 / WR-01 isolate-alive rejoin
  - Phase 3 UAT two-device kill-app and blip rejoin
  - Ranked reconnect budget (SESS-03, out of phase)

tech-stack:
  added: []
  patterns:
    - Isolate-alive retry shares _rejoinMatch with the overlay CTA (rejoin then ticket then connect)
    - Overlay secondsLeft is server remaining grace capped at 30, not a fresh local 30s
    - MatchSessionRegistry.add replaces the seat decorator; afterConnectionClosed skips markDropped while hasOpenSeat

key-files:
  created:
    - backend/src/test/java/com/nomadgames/session/internal/MatchSessionRegistryTest.java
  modified:
    - client/test/reconnect_overlay_test.dart
    - backend/src/test/java/com/nomadgames/session/ReconnectIT.java
    - client/lib/games/alchiki/match_page.dart
    - client/lib/platform/api/nomad_api.dart
    - backend/src/main/java/com/nomadgames/session/MatchSnapshot.java
    - backend/src/main/java/com/nomadgames/session/MatchService.java
    - backend/src/main/java/com/nomadgames/session/internal/MatchSessionRegistry.java
    - backend/src/main/java/com/nomadgames/session/internal/MatchWebSocketHandler.java

key-decisions:
  - "Isolate-alive onDone POSTs /rejoin via the same _rejoinMatch helper as the overlay CTA (stored matchId+token, persist rotated token, then ws-ticket)"
  - "Overlay countdown seeds from GET match reconnectSecondsLeft clamped 0..30, not DateTime.now()+30"
  - "MatchSessionRegistry.add replaces the decorator for ATTR_PLAYER_ID; afterConnectionClosed skips markDropped while hasOpenSeat"

patterns-established:
  - "Pattern: living-client blip = POST rejoin then ticket then connect; process-death overlay does not POST until Rejoin match is tapped"
  - "Pattern: one live socket per playerId per match; stale close cannot restart grace on a replaced seat"
  - "Pattern: GET match remaining grace is only the caller's dropped seat, capped at ReconnectPolicy.GRACE_SECONDS (30)"

requirements-completed: [SESS-02]

coverage:
  - id: D1
    description: Isolate-alive socket drop POSTs /rejoin then a later ws-ticket and does not show Rejoin match
    requirement: SESS-02
    verification:
      - kind: unit
        ref: "client/test/reconnect_overlay_test.dart#isolate-alive socket drop POSTs rejoin then wsTicket and hides Rejoin match"
        status: pass
    human_judgment: false
  - id: D2
    description: Process-death overlay seeds reconnecting padded 12 from server reconnectSecondsLeft, not a fresh local 30
    requirement: SESS-02
    verification:
      - kind: unit
        ref: "client/test/reconnect_overlay_test.dart#process-death overlay seeds reconnecting padded 12 from reconnectSecondsLeft not a fresh 30"
        status: pass
      - kind: integration
        ref: "backend/src/test/java/com/nomadgames/session/ReconnectIT.java#getMatchExposesRemainingGrace"
        status: pass
    human_judgment: false
  - id: D3
    description: One decorator per playerId; stale close after replacement keeps the match IN_PLAY
    requirement: SESS-02
    verification:
      - kind: unit
        ref: "backend/src/test/java/com/nomadgames/session/internal/MatchSessionRegistryTest.java#oneDecoratorPerPlayerId_hasOpenSeatAfterStaleRemove"
        status: pass
      - kind: integration
        ref: "backend/src/test/java/com/nomadgames/session/ReconnectIT.java#staleCloseAfterReplacementKeepsSeat"
        status: pass
    human_judgment: false
  - id: D4
    description: Existing rejoin snapshot, token rotate/expiry HOST_WIN, consented leave, rematch, and leave tests stay green; grace remains 30s with no bot-fill
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
      - kind: unit
        ref: "client/test/rematch_page_test.dart#private ResultOverlay Again? then getRematch yields new matchId and GameWidget"
        status: pass
    human_judgment: false

duration: 10min
completed: 2026-09-08
---

# Phase 3 Plan 13: Isolate-Alive Rejoin Gap Closure Summary

**Living private client POSTs /rejoin on a socket blip, persists the rotated token, then mints a ws-ticket; overlay countdown is server remaining grace capped at 30s; one decorator per seat so stale close cannot freeze a replaced seat**

## Performance

- **Duration:** 10 min
- **Started:** 2026-09-08T09:45:17Z
- **Completed:** 2026-09-08T09:55:15Z
- **Tasks:** 2
- **Files modified:** 9

## Accomplishments

- Isolate-alive `onDone` now shares `_rejoinMatch` (POST `/rejoin` → persist rotated token → ws-ticket → `MatchSocket.connect`) and keeps the Rejoin overlay hidden
- `_onSocketLost` returns immediately during `_enteringRematch` or consented leave so rematch/leave cannot `markDropped` a healthy row
- Process-death overlay GETs `/v1/matches/{id}` and seeds `secondsLeft` from `reconnectSecondsLeft` clamped 0..30
- `MatchSessionRegistry.add` replaces the decorator for `ATTR_PLAYER_ID`; `afterConnectionClosed` skips `markDropped` while `hasOpenSeat` is true; close 4000 still `leaveMatch`

## Task Commits

1. **Task 1: Failing isolate-alive rejoin and remaining-grace tests** - `889e734` (test)
2. **Task 2: POST rejoin on blip, one seat socket, server remaining overlay** - `4faf233` (feat)

**Plan metadata:** pending `docs(03-13)` commit

## Files Created/Modified

- `client/test/reconnect_overlay_test.dart` - Isolate-alive rejoin count + overlay remaining-12 cases
- `backend/src/test/java/com/nomadgames/session/ReconnectIT.java` - `getMatchExposesRemainingGrace`, `staleCloseAfterReplacementKeepsSeat`
- `backend/src/test/java/com/nomadgames/session/internal/MatchSessionRegistryTest.java` - One decorator per playerId + `hasOpenSeat` after stale remove
- `client/lib/games/alchiki/match_page.dart` - Shared rejoin helper, rematch onDone gate, overlay remaining seed
- `client/lib/platform/api/nomad_api.dart` - Optional `MatchStart.reconnectSecondsLeft` parsed from GET match
- `backend/src/main/java/com/nomadgames/session/MatchSnapshot.java` - Trailing `Integer reconnectSecondsLeft`
- `backend/src/main/java/com/nomadgames/session/MatchService.java` - Caller remaining grace from LiveMatch deadlines, cap 30
- `backend/src/main/java/com/nomadgames/session/internal/MatchSessionRegistry.java` - Replace-on-add + `hasOpenSeat`
- `backend/src/main/java/com/nomadgames/session/internal/MatchWebSocketHandler.java` - Skip `markDropped` while seat socket remains

## Decisions Made

- Isolate-alive retry uses the overlay `_rejoinMatch` path so ticket-only retry cannot return
- Overlay boot GETs match remaining; it does not POST rejoin until the player taps Rejoin match (token is one-time)
- Remaining seconds are only the caller's grace (requireSeat); opponent banner still uses `OpponentDropped.secondsLeft`
- Grace stays 30s; PRIVATE expiry still HOST_WIN/JOINER_WIN; no bot-fill; Forge2D not reopened

## Deviations from Plan

None - plan executed exactly as written.

**Total deviations:** 0 auto-fixed
**Impact on plan:** None

## Issues Encountered

None

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Phase 3 plans 1–13 all have SUMMARYs; ready for `/gsd-verify-work` on the private-room + reconnect surface
- CR-02 private clock forfeit and CR-05 Flutter WS close 4000 remain out of this plan by design
- Ranked reconnect budget (SESS-03) stays Phase 7

## Self-Check: PASSED

- SUMMARY, match_page, nomad_api, MatchSnapshot, MatchService, MatchSessionRegistry, MatchWebSocketHandler, reconnect_overlay_test, ReconnectIT, MatchSessionRegistryTest exist on disk
- Commits `889e734` (test) and `4faf233` (feat) present in git log --grep=03-13

---
*Phase: 03-private-rooms-casual-reconnect*
*Completed: 2026-09-08*
