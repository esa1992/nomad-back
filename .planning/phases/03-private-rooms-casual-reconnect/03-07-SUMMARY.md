---
phase: 03-private-rooms-casual-reconnect
plan: 07
subsystem: session
tags: [leave, forfeit, host-win, joiner-win, sess-05, d-44, pause-confirm]
status: complete

requires:
  - phase: 03-private-rooms-casual-reconnect
    provides: PRIVATE IN_PLAY match after both Ready, requireSeat, HOST_WIN/JOINER_WIN statuses, private HUD localSeat
provides:
  - Consented leave forfeits immediately with 0s grace (SESS-05, D-41 leave half)
  - PRIVATE leave awards remaining seat HOST_WIN or JOINER_WIN, never BOT_WIN (D-44)
  - leaveBodyPrivate Pause confirm vs human; result heading youWin/opponentWins by localSeat
affects:
  - Phase 3 rematch Again? (03-08)
  - Phase 3 reconnect grace (03-09) — unexpected WS close is not leave

tech-stack:
  added: []
  patterns:
    - leaveMatch branches on mode: BOT IN_PLAY stays BOT_WIN; PRIVATE uses requireSeat
    - WS close code 4000 calls leaveMatch; other closes do not
    - LeaveConfirm optional body; ResultOverlay maps HOST_WIN/JOINER_WIN via localSeat

key-files:
  created:
    - backend/src/test/java/com/nomadgames/session/LeaveIT.java
    - client/test/rematch_overlay_test.dart
  modified:
    - backend/src/main/java/com/nomadgames/session/MatchService.java
    - backend/src/main/java/com/nomadgames/session/internal/MatchWebSocketHandler.java
    - client/lib/games/alchiki/pause_overlay.dart
    - client/lib/games/alchiki/match_page.dart

key-decisions:
  - "PRIVATE leave uses requireSeat; remaining seat HOST_WIN/JOINER_WIN never BOT_WIN (D-44)"
  - "WS close code 4000 calls leaveMatch; unexpected close does not (D-41, D-44)"
  - "LeaveConfirm optional body; match_page passes leaveBodyPrivate vs human; result headings use localSeat vs HOST_WIN/JOINER_WIN"

patterns-established:
  - "Pattern: consented leave is REST POST /leave plus WS close 4000; neither starts 30s grace"
  - "Pattern: already-terminal leave returns the existing snapshot (02-09 carry)"

requirements-completed: [SESS-05]

coverage:
  - id: D1
    description: Joiner POST /leave on an IN_PLAY PRIVATE match returns HOST_WIN and never BOT_WIN
    requirement: SESS-05
    verification:
      - kind: integration
        ref: "backend/src/test/java/com/nomadgames/session/LeaveIT.java#privateLeaveOpponentWins"
        status: pass
    human_judgment: false
  - id: D2
    description: Already-terminal HOST_WIN leave returns the existing snapshot (02-09 carry)
    requirement: SESS-05
    verification:
      - kind: integration
        ref: "backend/src/test/java/com/nomadgames/session/LeaveIT.java#privateLeaveWhenAlreadyHostWinPreserves"
        status: pass
    human_judgment: false
  - id: D3
    description: Bot IN_PLAY leave still records BOT_WIN; PLAYER_WIN/DRAW preserve
    requirement: SESS-05
    verification:
      - kind: integration
        ref: "backend/src/test/java/com/nomadgames/session/ThrowAuthorityIT.java#leaveMatchReturnsBotWin"
        status: pass
      - kind: integration
        ref: "backend/src/test/java/com/nomadgames/session/ThrowAuthorityIT.java#leaveAfterPlayerWinPreservesPlayerWin"
        status: pass
    human_judgment: false
  - id: D4
    description: Pause Leave confirm vs human shows leaveBodyPrivate; HOST_WIN for joiner is Opponent wins, never Bot wins
    requirement: SESS-05
    verification:
      - kind: unit
        ref: "client/test/rematch_overlay_test.dart#private LeaveConfirm shows leaveBodyPrivate and not Bot"
        status: pass
      - kind: unit
        ref: "client/test/rematch_overlay_test.dart#private ResultOverlay HOST_WIN for joiner is opponentWins, never Bot wins"
        status: pass
    human_judgment: false
  - id: D5
    description: WS close code 4000 is consented leave; unexpected close is not leave (0s grace, no reconnect banner)
    requirement: SESS-05
    verification: []
    human_judgment: true
    rationale: "Handler 4000 → leaveMatch is code-reviewed; unexpected close vs 30s hold is 03-09 and needs a two-client drop/leave UAT"

duration: 9min
completed: 2026-09-07
---

# Phase 3 Plan 07: Consented leave forfeit Summary

**Consented leave ends IN_PLAY immediately: bot stays BOT_WIN, human remaining seat HOST_WIN/JOINER_WIN, never a bot-win label on a PRIVATE row (SESS-05, D-44)**

## Performance

- **Duration:** 9 min
- **Started:** 2026-09-07T08:50:08Z
- **Completed:** 2026-09-07T08:59:00Z
- **Tasks:** 2
- **Files modified:** 6

## Accomplishments

- `LeaveIT` locks joiner leave → `HOST_WIN` and already-terminal preserve
- `leaveMatch` branches on mode; `requireSeat` for PRIVATE; `MatchSettled` broadcast when sockets exist
- Pause confirm keeps Stay / Leave match; vs human body is `leaveBodyPrivate`; result headings `youWin`/`opponentWins` from local seat vs `HOST_WIN`/`JOINER_WIN`

## Task Commits

Each task was committed atomically:

1. **Task 1: Failing private leave tests** - `c869639` (test)
2. **Task 2: Branch leaveMatch and private confirm copy** - `da0c1b8` (feat)

**Plan metadata:** docs commit with this SUMMARY

## Files Created/Modified

- `backend/src/test/java/com/nomadgames/session/LeaveIT.java` - RoomIT-style both-Ready then joiner POST `/leave`
- `client/test/rematch_overlay_test.dart` - `leaveBodyPrivate` and `Opponent wins` / no Bot wins
- `backend/src/main/java/com/nomadgames/session/MatchService.java` - mode branch, requireSeat, MatchSettled broadcast
- `backend/src/main/java/com/nomadgames/session/internal/MatchWebSocketHandler.java` - close code 4000 → leaveMatch
- `client/lib/games/alchiki/pause_overlay.dart` - optional LeaveConfirm body; HOST_WIN/JOINER_WIN headings
- `client/lib/games/alchiki/match_page.dart` - private confirm copy; raw status + localSeat into ResultOverlay

## Decisions Made

- **PRIVATE remaining seat wins** — joiner leave → `HOST_WIN`; host leave → `JOINER_WIN`; bot IN_PLAY path unchanged `BOT_WIN` so ThrowAuthorityIT stays green (D-44).
- **Close 4000 is leave** — handler calls `leaveMatch`; unexpected close does not, so 03-09 can still hold the seat 30s (D-41, D-44).
- **Confirm stays** — Leave match is not immediate before Pause confirm; private body is `leaveBodyPrivate`. Again? rematch CTA stays 03-08.

## Deviations from Plan

None - plan executed exactly as written.

---

**Total deviations:** 0 auto-fixed
**Impact on plan:** None

## Issues Encountered

None

## Authentication Gates

None

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Ready for 03-08 (bot Play again + private 10s dual rematch). Reconnect grace remains 03-09; consented leave must not start the 30s hold.

---

*Phase: 03-private-rooms-casual-reconnect*
*Completed: 2026-09-07*

## Self-Check: PASSED

- FOUND: `backend/src/test/java/com/nomadgames/session/LeaveIT.java`
- FOUND: `client/test/rematch_overlay_test.dart`
- FOUND: `backend/src/main/java/com/nomadgames/session/MatchService.java`
- FOUND: `backend/src/main/java/com/nomadgames/session/internal/MatchWebSocketHandler.java`
- FOUND: `client/lib/games/alchiki/pause_overlay.dart`
- FOUND: `client/lib/games/alchiki/match_page.dart`
- FOUND commits: `c869639` test(03-07), `da0c1b8` feat(03-07)
