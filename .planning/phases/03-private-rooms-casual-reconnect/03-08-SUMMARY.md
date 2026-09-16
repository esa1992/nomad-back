---
phase: 03-private-rooms-casual-reconnect
plan: 08
subsystem: session
tags: [rematch, play-again, dual-accept, rematch-ready, mode-05, d-43, d-30]
status: complete

requires:
  - phase: 03-private-rooms-casual-reconnect
    provides: PRIVATE terminal HOST_WIN/JOINER_WIN, requireSeat, ws-ticket, MatchSocket, ResultOverlay localSeat
provides:
  - POST/GET /v1/matches/{id}/rematch with 10s heap dual-accept window
  - RematchReady on finished-match sockets plus GET poll so both seats receive the new matchId
  - Bot Play again one-tap and private Again? re-attach via ws-ticket + GameWidget
affects:
  - Phase 3 reconnect grace (03-09/03-10)
  - Casual rematch later (MODE-05 casual half)

tech-stack:
  added: []
  patterns:
    - Heap RematchWindow on MatchSessionRegistry; first accept has null matchId; second createPrivateMatch joiner-first
    - RematchReady { matchId, turn: JOINER } on old sockets; GET rematch is the first-accepter poll
    - MatchSocket.debugConnect + stub for widget tests without a live WS

key-files:
  created:
    - backend/src/test/java/com/nomadgames/session/RematchIT.java
    - backend/src/main/java/com/nomadgames/session/RematchRequest.java
    - backend/src/main/java/com/nomadgames/session/RematchAcceptResponse.java
    - backend/src/main/java/com/nomadgames/session/RematchPollResponse.java
    - client/test/rematch_page_test.dart
  modified:
    - backend/src/main/java/com/nomadgames/session/MatchController.java
    - backend/src/main/java/com/nomadgames/session/MatchService.java
    - backend/src/main/java/com/nomadgames/session/internal/MatchSessionRegistry.java
    - client/lib/games/alchiki/pause_overlay.dart
    - client/lib/games/alchiki/match_page.dart
    - client/lib/platform/api/nomad_api.dart
    - client/lib/platform/session/match_socket.dart
    - client/test/rematch_overlay_test.dart

key-decisions:
  - "Private rematch is a new PRIVATE NORMAL match with the same two seats; joiner throws first (D-30, D-43)"
  - "First accept returns matchId null; second accept creates the match, returns matchId, broadcasts RematchReady; GET rematch is the poll path (D-43)"
  - "Bot Play again POSTs /v1/matches at the same difficulty with no dual accept; how-to is skipped because the player is already on the table"

patterns-established:
  - "Pattern: 10s rematch window lives on heap keyed by finished matchId (A3 — lost on restart)"
  - "Pattern: both seats close the old MatchSocket, POST ws-ticket on the new id, connect, re-attach GameWidget"

requirements-completed: [MODE-05]

coverage:
  - id: D1
    description: Bot result overlay shows one-tap Play again and Bot scores, no 10s clock
    requirement: MODE-05
    verification:
      - kind: unit
        ref: "client/test/rematch_overlay_test.dart#bot ResultOverlay finds Play again and Bot"
        status: pass
    human_judgment: false
  - id: D2
    description: Private result overlay shows Again? and Opponent wins, never Bot wins
    requirement: MODE-05
    verification:
      - kind: unit
        ref: "client/test/rematch_overlay_test.dart#private ResultOverlay finds Again? and Opponent wins and does not find Bot wins"
        status: pass
    human_judgment: false
  - id: D3
    description: Dual accept creates a new matchId with turn JOINER and the same host/joiner seats
    requirement: MODE-05
    verification:
      - kind: integration
        ref: "backend/src/test/java/com/nomadgames/session/RematchIT.java#bothAcceptCreatesNewMatchJoinerTurn"
        status: pass
    human_judgment: false
  - id: D4
    description: First accepter POST has no matchId; after second accept GET rematch returns the new matchId
    requirement: MODE-05
    verification:
      - kind: integration
        ref: "backend/src/test/java/com/nomadgames/session/RematchIT.java#firstAccepterPollsNewMatchId"
        status: pass
    human_judgment: false
  - id: D5
    description: After dual accept both seats POST ws-ticket on the new matchId and get 200
    requirement: MODE-05
    verification:
      - kind: integration
        ref: "backend/src/test/java/com/nomadgames/session/RematchIT.java#bothSeatsTicketNewMatch"
        status: pass
    human_judgment: false
  - id: D6
    description: One accept then expired window; second accept 409/410; no new IN_PLAY row
    requirement: MODE-05
    verification:
      - kind: integration
        ref: "backend/src/test/java/com/nomadgames/session/RematchIT.java#timeoutDoesNotCreate"
        status: pass
    human_judgment: false
  - id: D7
    description: Private Again? yields a new matchId then wsTicket(newId) and GameWidget re-attach
    requirement: MODE-05
    verification:
      - kind: unit
        ref: "client/test/rematch_page_test.dart#private ResultOverlay Again? then getRematch yields new matchId and GameWidget"
        status: pass
    human_judgment: false
  - id: D8
    description: Private rematch clock, waiting-for-name, and timeout-to-catalog feel right on two real devices
    requirement: MODE-05
    verification: []
    human_judgment: true
    rationale: "10s dual accept across two seats, RematchReady vs poll race, and overlay copy are not fully covered by single-process widget/IT tests"

duration: 24min
completed: 2026-09-07
---

# Phase 3 Plan 08: Rematch dual accept Summary

**Bot Play again is one-tap POST /v1/matches; private Again? is a 10s dual accept that creates a new joiner-first matchId, broadcasts RematchReady, and both seats re-attach via ws-ticket (MODE-05, D-43, D-30)**

## Performance

- **Duration:** 24 min
- **Started:** 2026-09-07T09:00:22Z
- **Completed:** 2026-09-07T09:23:55Z
- **Tasks:** 2
- **Files modified:** 13

## Accomplishments

- `RematchIT` locks dual accept, first-accepter GET poll, both-seat ws-ticket on the new id, and timeout with no new IN_PLAY row
- `POST/GET /v1/matches/{id}/rematch` with a 10s heap window; second accept calls `createPrivateMatch` (JOINER first) and broadcasts `RematchReady` on the finished-match sockets
- Result overlay: bot **Play again**; private **Again?** + `rematchClock`; both seats close the old socket, `wsTicket(newId)`, `MatchSocket.connect`, re-attach `GameWidget`

## Task Commits

Each task was committed atomically:

1. **Task 1: Failing rematch tests** - `a6b014d` (test)
2. **Task 2: Rematch REST and result overlay CTAs** - `6a2d9bd` (feat)

**Plan metadata:** docs commit with this SUMMARY

## Files Created/Modified

- `backend/src/test/java/com/nomadgames/session/RematchIT.java` - dual accept, poll, both-seat ticket, timeout
- `backend/src/main/java/com/nomadgames/session/MatchController.java` - POST and GET rematch
- `backend/src/main/java/com/nomadgames/session/MatchService.java` - accept/reject/poll + RematchReady broadcast
- `backend/src/main/java/com/nomadgames/session/internal/MatchSessionRegistry.java` - heap `rematchWindows`
- `backend/src/main/java/com/nomadgames/session/RematchRequest.java` - `{ accept }`
- `backend/src/main/java/com/nomadgames/session/RematchAcceptResponse.java` - accepted, matchId, rematchSeconds, turn
- `backend/src/main/java/com/nomadgames/session/RematchPollResponse.java` - seats, seconds, matchId, expired
- `client/lib/platform/api/nomad_api.dart` - `rematch` + `getRematch`
- `client/lib/platform/session/match_socket.dart` - `debugConnect` + `stub` for tests
- `client/lib/games/alchiki/pause_overlay.dart` - Play again / Again? / rematchClock
- `client/lib/games/alchiki/match_page.dart` - bot Play again; private accept/poll/RematchReady re-attach
- `client/test/rematch_overlay_test.dart` - Play again vs Again?
- `client/test/rematch_page_test.dart` - wsTicket(newId) + GameWidget after Again?

## Decisions Made

- **New match, same seats, joiner first** — rematch never copies bot difficulty into a PRIVATE table (D-31); `createPrivateMatch` keeps JOINER turn (D-30).
- **MatchId delivery** — first POST returns `matchId: null`; second POST returns the new id and broadcasts `RematchReady`; GET rematch is the poll path so the first accepter is not stuck (D-43).
- **Bot is not dual-accept** — Play again calls existing `startMatch(difficulty)` and re-attaches the table; how-to is skipped because the player is already past it.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] MatchSocket.debugConnect + stub for widget tests**
- **Found during:** Task 2 (private rematch page test)
- **Issue:** `AlchikiMatchPage` always `MatchSocket.connect`s; a live WS cannot run in `flutter_test`.
- **Fix:** Test hook `MatchSocket.debugConnect` and `MatchSocket.stub()` so the page can attach and rematch without a server.
- **Files modified:** `client/lib/platform/session/match_socket.dart`, `client/test/rematch_page_test.dart`
- **Verification:** `flutter test test/rematch_page_test.dart` pass
- **Committed in:** `6a2d9bd` (Task 2)

**2. [Rule 1 - Bug] Closing the old socket blocked rematch re-attach**
- **Found during:** Task 2
- **Issue:** `await` on stub stream `close()`/`cancel()` never completed under the test clock, so `wsTicket(newId)` never ran.
- **Fix:** Cancel/close the previous socket without awaiting the stream; `close()` does not await `StreamController.close()`.
- **Files modified:** `client/lib/platform/session/match_socket.dart`, `client/lib/games/alchiki/match_page.dart`
- **Verification:** rematch_page_test `wsTicketCalls` contains `new-match-id`
- **Committed in:** `6a2d9bd` (Task 2)

**3. [Rule 2 - Missing Critical] IgnorePointer on GameWidget while the result overlay is up**
- **Found during:** Task 2
- **Issue:** Flame `GameWidget` sits under the overlay in the stack but can steal taps; Again? must remain the hit target.
- **Fix:** `IgnorePointer(ignoring: _isTerminal || _paused)` around the table.
- **Files modified:** `client/lib/games/alchiki/match_page.dart`
- **Verification:** rematch_page_test taps Again? (`rematchCalls > 0`)
- **Committed in:** `6a2d9bd` (Task 2)

---

**Total deviations:** 3 auto-fixed (1 blocking, 1 bug, 1 missing critical)
**Impact on plan:** Required for a playable rematch and green widget tests. No Ranked rematch, no bot-fill, no 30s reconnect.

## Issues Encountered

`find.byType(GameWidget)` does not match Flame `GameWidget.controlled` (`GameWidget<AlchikiMatchGame>`). The page test asserts via a `GameWidget` runtimeType predicate.

## Authentication Gates

None

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Ready for 03-09 (server reconnect 30s grace). Rematch is not reconnect: consented leave and rematch reject still go to catalog; unexpected WS close must not be treated as leave (already 03-07).

---

*Phase: 03-private-rooms-casual-reconnect*
*Completed: 2026-09-07*

## Self-Check: PASSED

- FOUND: `backend/src/test/java/com/nomadgames/session/RematchIT.java`
- FOUND: `client/test/rematch_overlay_test.dart`
- FOUND: `client/test/rematch_page_test.dart`
- FOUND: `backend/src/main/java/com/nomadgames/session/MatchController.java`
- FOUND: `backend/src/main/java/com/nomadgames/session/MatchService.java`
- FOUND: `client/lib/games/alchiki/pause_overlay.dart`
- FOUND: `client/lib/games/alchiki/match_page.dart`
- FOUND commits: `a6b014d` test(03-08), `6a2d9bd` feat(03-08)
