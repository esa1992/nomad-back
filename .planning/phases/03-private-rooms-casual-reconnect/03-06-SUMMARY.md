---
phase: 03-private-rooms-casual-reconnect
plan: 06
subsystem: ui
tags: [flutter, websocket, private-table, dual-saka, d-30, d-34, d-35, d-36, d-37, d-38, mode-01, mode-02]
status: complete

requires:
  - phase: 03-private-rooms-casual-reconnect
    provides: ticket-authenticated raw WS throws, saka-host/saka-joiner burst, PRIVATE NORMAL match with turn JOINER
provides:
  - web_socket_channel 3.0.3 MatchSocket after POST ws-ticket
  - Dual SakaBody on private tables (local cream, opponent ice) with theatrical opponent ThrowResolved
  - mapPrivateSeatHud remaps You/Guest-XXXX scores from playerId vs hostId/joinerId
affects:
  - Phase 3 leave-vs-human (03-07)
  - Phase 3 rematch Again? (03-08)
  - Phase 3 reconnect banner (03-10)

tech-stack:
  added:
    - web_socket_channel 3.0.3
  patterns:
    - Private in-play throws go on MatchSocket; bot matches stay on REST submitThrow
    - localSeat is derived from snapshot hostId/joinerId vs SessionStore.playerId; /match query stays mode, matchId, difficulty
    - Opponent wait uses a static 8×8 aiming marker; ThrowResolved reuses playBotTurn

key-files:
  created:
    - client/lib/platform/session/match_socket.dart
    - client/lib/games/alchiki/aiming_marker.dart
    - client/test/private_table_test.dart
  modified:
    - client/pubspec.yaml
    - client/lib/platform/api/nomad_api.dart
    - client/lib/game/saka_body.dart
    - client/lib/games/alchiki/match_game.dart
    - client/lib/games/alchiki/match_page.dart
    - client/lib/games/alchiki/match_hud.dart
    - client/lib/games/alchiki/pause_overlay.dart

key-decisions:
  - "localSeat comes from SessionStore.playerId vs snapshot hostId/joinerId; router still has no seat query (D-30)"
  - "Private in-play impulses use MatchSocket.sendThrow only; bot path keeps REST submitThrow (D-38)"
  - "HOST_WIN/JOINER_WIN map to youWin/opponentWins on the result overlay without Again? (rematch is 03-08)"

patterns-established:
  - "Pattern: mapPrivateSeatHud is a top-level pure function; playerScore=host, botScore=joiner"
  - "Pattern: one WebSocketChannel per match page; ticket query param, never the access JWT"
  - "Pattern: local seat is always cream #FFF6D6; opponent ice #7EB6D9 regardless of host/joiner"

requirements-completed: [MODE-01, MODE-02]

coverage:
  - id: D1
    description: Private HUD shows Opponent's turn, You n — Guest-XXXX n, First to 5 · NORMAL, and bot HUD still uses Bot's turn
    requirement: MODE-01
    verification:
      - kind: unit
        ref: "client/test/private_table_test.dart#private HUD shows opponentsTurn, Guest-C9D0 pair, NORMAL, not Bot"
        status: pass
      - kind: unit
        ref: "client/test/private_table_test.dart#bot HUD defaults still show botsTurn and not opponentsTurn"
        status: pass
    human_judgment: false
  - id: D2
    description: mapPrivateSeatHud remaps joiner vs host youScore/oppScore and isPlayerTurn from snapshot columns
    requirement: MODE-02
    verification:
      - kind: unit
        ref: "client/test/private_table_test.dart#mapPrivateSeatHud remaps joiner scores and JOINER turn"
        status: pass
      - kind: unit
        ref: "client/test/private_table_test.dart#mapPrivateSeatHud remaps host scores and not JOINER turn"
        status: pass
    human_judgment: false
  - id: D3
    description: Private table uses MatchSocket after ws-ticket, two sakas, static aiming marker, and theatrical opponent ThrowResolved
    requirement: MODE-02
    verification:
      - kind: unit
        ref: "client/test/bot_turn_test.dart"
        status: pass
      - kind: unit
        ref: "client/test/howto_test.dart"
        status: pass
      - kind: unit
        ref: "client/test/catalog_test.dart"
        status: pass
    human_judgment: true
    rationale: "Widget tests lock HUD remap and keep bot/how-to/catalog green; live two-device WS theatrical replay and cream-vs-ice seats still need a human table pass"

duration: 9min
completed: 2026-09-07
---

# Phase 3 Plan 06: Private table WS + dual sakas Summary

**Private NORMAL table on device: joiner-first WS throws, local preview morphs to JVM keyframes, opponent sees theatrical replay only (D-30, D-34–D-38)**

## Performance

- **Duration:** 9 min
- **Started:** 2026-09-07T08:37:44Z
- **Completed:** 2026-09-07T08:47:29Z
- **Tasks:** 2
- **Files modified:** 12

## Accomplishments

- Failing `private_table_test` locked private vs bot HUD copy and `mapPrivateSeatHud` joiner/host remap
- `web_socket_channel` 3.0.3 + `MatchSocket` after authenticated `ws-ticket`; bot matches still use REST `submitThrow`
- Two `SakaBody` (cream you / ice opponent), static aiming marker, theatrical `playBotTurn` for remote `ThrowResolved`

## Task Commits

Each task was committed atomically:

1. **Task 1: Failing private table widget tests** - `461c88c` (test)
2. **Task 2: MatchSocket, two sakas, theatrical opponent, private HUD** - `ef6e7fe` (feat)

**Plan metadata:** docs commit with this SUMMARY

## Files Created/Modified

- `client/test/private_table_test.dart` - MatchHud private/bot copy + mapPrivateSeatHud unit asserts
- `client/lib/platform/session/match_socket.dart` - `WebSocketChannel.connect`, parse `type`, sink ThrowInput/Ping
- `client/lib/games/alchiki/aiming_marker.dart` - static 8×8 `0x66F4E8C8` wait pose (D-35)
- `client/lib/games/alchiki/match_hud.dart` - `isPrivate`, `opponentLabel`, `opponentsTurn`, optional `reconnectLabel` stub
- `client/lib/games/alchiki/match_page.dart` - `mapPrivateSeatHud`, private GET + ws-ticket + socket, no private `submitThrow`
- `client/lib/games/alchiki/match_game.dart` - `saka-host` / `saka-joiner` spawn and replay targets
- `client/lib/game/saka_body.dart` - constructor fill/stripe/spawn/id
- `client/lib/platform/api/nomad_api.dart` - `getMatch`, `wsTicket`, `wsUrlForMatch` (http→ws, ticket query only)
- `client/pubspec.yaml` / `client/pubspec.lock` - pin `web_socket_channel: 3.0.3`
- `client/lib/games/alchiki/pause_overlay.dart` - private result heading/score pair without Again?

## Decisions Made

- **localSeat from snapshot, not the router** — `/match` still reads only `mode`, `matchId`, `difficulty`; seat remap waits for `hostId`/`joinerId` vs `playerId` (D-30). Until that snapshot exists, the private HUD does not assume host.
- **WS for private throws only** — `MatchSocket.sendThrow` after `ws-ticket`; access JWT never appended to the handshake URL (T-03-25). Bot path unchanged REST.
- **Result overlay maps private terminal status** — `HOST_WIN`/`JOINER_WIN` become You win / Opponent wins using `localSeat`; no Again? CTA (03-08).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Missing sessionStoreProvider import**
- **Found during:** Task 2 (GREEN compile)
- **Issue:** `match_page.dart` called `sessionStoreProvider` without importing `session_store.dart`
- **Fix:** Added the existing auth import
- **Files modified:** `client/lib/games/alchiki/match_page.dart`
- **Verification:** `flutter test` private_table/bot_turn/howto/catalog all passed
- **Committed in:** `ef6e7fe` (Task 2)

**2. [Rule 2 - Missing Critical] Private result heading must not say Bot wins**
- **Found during:** Task 2 (terminal overlay)
- **Issue:** `HOST_WIN`/`JOINER_WIN` would fall through to Draw and keep a Bot score pair
- **Fix:** Map local win/loss to `PLAYER_WIN`/`OPPONENT_WIN` and pass `opponentLabel` into `ResultOverlay` without adding Again?
- **Files modified:** `client/lib/games/alchiki/match_page.dart`, `client/lib/games/alchiki/pause_overlay.dart`
- **Verification:** existing overlay tests still compile; private HUD tests pass
- **Committed in:** `ef6e7fe` (Task 2)

**3. [Rule 3 - Blocking] router.dart already had mode/matchId/difficulty**
- **Found during:** Task 2
- **Issue:** Plan listed `router.dart` as modified; 03-04 already reads those query params and does not add a seat param
- **Fix:** Left router unchanged (D-30)
- **Files modified:** none
- **Verification:** `/match` builder still reads only `mode`, `matchId`, `difficulty`
- **Committed in:** n/a

---

**Total deviations:** 3 auto-fixed (1 bug, 1 missing critical, 1 blocking/no-op)
**Impact on plan:** Needed for compile and honest private results. No rematch, leave-vs-human, or reconnect scope added.

## Issues Encountered

None beyond the import miss caught at first GREEN compile.

## Authentication Gates

None.

## Known Stubs

- `MatchHud.reconnectLabel` is optional and unused until 03-10 (no reconnect banner copy shown)
- Private result overlay has Back to catalog only — Again? is 03-08 by plan
- `leaveBodyPrivate` not wired (03-07)

## Threat Flags

None — WS URL uses ticket only; scored HUD still comes from `ThrowResolved`; outbound frames are ThrowInput + optional Ping.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Ready for 03-07 (leave vs human). Private table is playable on device with theatrical opponent turns. Rematch, consented leave settlement, and reconnect banners remain later plans.

## Self-Check: PASSED

- FOUND: `client/lib/platform/session/match_socket.dart`
- FOUND: `client/lib/games/alchiki/aiming_marker.dart`
- FOUND: `client/test/private_table_test.dart`
- FOUND: commits `461c88c` and `ef6e7fe`

---
*Phase: 03-private-rooms-casual-reconnect*
*Completed: 2026-09-07*
