---
phase: 03-private-rooms-casual-reconnect
plan: 10
subsystem: client-session
tags: [reconnect, rejoin, flutter-secure-storage, match-socket, sess-02, d-41]

requires:
  - phase: 03-private-rooms-casual-reconnect
    provides: 30s private seat hold, rotating reconnect token, POST rejoin RejoinSnapshot
provides:
  - SessionStore reconnectToken + reconnectMatchId + reconnectLocalSeat in FlutterSecureStorage
  - Isolate-alive MatchSocket auto-retry with a fresh ws-ticket
  - Opponent HUD reconnecting banner with frozen clocks
  - Process-death Rejoin overlay from splash/catalog cold start
affects:
  - Phase 3 UAT two-device kill-app rejoin
  - Ranked reconnect budget (SESS-03, out of phase)

tech-stack:
  added: []
  patterns:
    - Reconnect bundle lives beside refresh in FlutterSecureStorage, never SharedPreferences
    - Cold start (token+matchId, no live socket) shows Rejoin overlay; isolate-alive drop auto-retries silently
    - NomadApi.rejoin(storedMatchId, storedToken) then new ws-ticket then MatchSocket.connect; full snapshot not a client delta

key-files:
  created:
    - client/test/reconnect_overlay_test.dart
  modified:
    - client/lib/platform/auth/session_store.dart
    - client/lib/platform/api/nomad_api.dart
    - client/lib/platform/session/match_socket.dart
    - client/lib/platform/splash_page.dart
    - client/lib/catalog/catalog_page.dart
    - client/lib/games/alchiki/match_page.dart
    - client/lib/games/alchiki/match_hud.dart
    - client/lib/games/alchiki/pause_overlay.dart
    - client/lib/games/alchiki/match_game.dart

key-decisions:
  - "Reconnect token, matchId, and localSeat live in FlutterSecureStorage beside refresh, not SharedPreferences"
  - "Cold start with stored token+matchId routes splash/catalog to /match?mode=private&matchId= and shows Rejoin overlay; isolate-alive auto-retry skips Rejoin"
  - "NomadApi.rejoin uses persisted matchId; token alone cannot rejoin (D-41)"
  - "Displayed grace is server secondsLeft capped at 30s; client does not invent a longer window"

patterns-established:
  - "Pattern: persistReconnect on ws-ticket / successful rejoin; clearReconnect only on consented leave, rematch reject, or grace expiry"
  - "Pattern: Rejoin overlay heading reconnecting(ss) + accent Rejoin match, no Back to catalog"

requirements-completed: [SESS-02]

coverage:
  - id: D1
    description: SessionStore.memory persistReconnect round-trips token, matchId, and localSeat in secure storage keys
    requirement: SESS-02
    verification:
      - kind: unit
        ref: "client/test/reconnect_overlay_test.dart#SessionStore.memory persistReconnect round-trips token, matchId, and localSeat"
        status: pass
    human_judgment: false
  - id: D2
    description: Rejoin overlay finds Rejoin match and omits Back to catalog
    requirement: SESS-02
    verification:
      - kind: unit
        ref: "client/test/reconnect_overlay_test.dart#Rejoin overlay finds Rejoin match and does not find Back to catalog"
        status: pass
    human_judgment: false
  - id: D3
    description: Opponent HUD-style banner finds Reconnecting with wood 88% panel
    requirement: SESS-02
    verification:
      - kind: unit
        ref: "client/test/reconnect_overlay_test.dart#HUD-style banner finds Reconnecting"
        status: pass
    human_judgment: false
  - id: D4
    description: Cold start from splash or catalog with stored reconnectToken+matchId opens private match Rejoin overlay
    requirement: SESS-02
    verification:
      - kind: unit
        ref: "client/test/reconnect_overlay_test.dart#cold start splash with reconnectMatchId opens Rejoin match not catalog"
        status: pass
      - kind: unit
        ref: "client/test/reconnect_overlay_test.dart#cold start catalog with persistReconnect finds Rejoin match"
        status: pass
    human_judgment: false
  - id: D5
    description: Server 30s grace and rejoin snapshot still green; client consumes POST rejoin as-is
    requirement: SESS-02
    verification:
      - kind: integration
        ref: "backend/src/test/java/com/nomadgames/session/ReconnectIT.java"
        status: pass
    human_judgment: false
  - id: D6
    description: Two guests kill-app within 30s then relaunch shows Rejoin match and restores the full table
    requirement: SESS-02
    verification: []
    human_judgment: true
    rationale: Requires two physical/guest devices, process death (not only airplane mode), and visual UAT of the 30s banner plus Rejoin overlay

duration: 9min
completed: 2026-09-07
status: complete
---

# Phase 3 Plan 10: Client Casual Reconnect Summary

**Private client auto-retries while alive, stores token+matchId+localSeat in FlutterSecureStorage, shows the opponent reconnecting timer, and after process death lands on Rejoin from splash/catalog against the 30s server grace**

## Performance

- **Duration:** 9 min
- **Started:** 2026-09-07T09:44:26Z
- **Completed:** 2026-09-07T09:53:31Z
- **Tasks:** 2
- **Files modified:** 10

## Accomplishments

- Reconnect bundle (`reconnectToken`, `reconnectMatchId`, `reconnectLocalSeat`) stored beside refresh in FlutterSecureStorage; `clear()` also wipes it
- Isolate-alive MatchSocket drop requests a new ws-ticket and reconnects without the Rejoin overlay
- Opponent HUD shows `reconnecting(ss)` on a wood 88% panel; displayed clocks freeze during grace
- Process death: splash/catalog with a stored bundle go to `/match?mode=private&matchId=` and show Rejoin match (no Back to catalog)
- Rejoin POSTs stored matchId+token, persists the rotated token, mints a new ws-ticket, connects MatchSocket, and applies the 03-09 RejoinSnapshot

## Task Commits

Each task was committed atomically:

1. **Task 1: Failing reconnect overlay tests** - `0cd9bb6` (test)
2. **Task 2: Secure token, auto-retry, banner, Rejoin overlay** - `9f914e0` (feat)

**Plan metadata:** docs commit via gsd-tools after this SUMMARY

_Note: TDD tasks may have multiple commits (test → feat → refactor)_

## Files Created/Modified

- `client/test/reconnect_overlay_test.dart` - Rejoin overlay, HUD banner, persistReconnect, splash/catalog cold start
- `client/lib/platform/auth/session_store.dart` - persistReconnect / readers / clearReconnect
- `client/lib/platform/api/nomad_api.dart` - `rejoin(matchId, token)` + ws-ticket reconnectToken
- `client/lib/platform/session/match_socket.dart` - close incoming stream on socket done so auto-retry can fire
- `client/lib/platform/splash_page.dart` - after mint/resume, token+matchId → private Rejoin route
- `client/lib/catalog/catalog_page.dart` - same redirect on start so `/` cannot skip Rejoin
- `client/lib/games/alchiki/match_page.dart` - Rejoin overlay, persist on ticket, auto-retry, OpponentDropped freeze, clearReconnect on leave/reject/expiry
- `client/lib/games/alchiki/pause_overlay.dart` - Rejoin overlay (accent Rejoin match, no catalog CTA)
- `client/lib/games/alchiki/match_hud.dart` - reconnecting banner via `l10n.reconnecting`
- `client/lib/games/alchiki/match_game.dart` - applySakaPose for RejoinSnapshot saka poses

## Decisions Made

- Token+matchId+localSeat in FlutterSecureStorage beside refresh (CONTEXT discretion, T-03-39) — SharedPreferences would leak the seat bearer
- MatchPage init with stored token+matchId and no live socket shows Rejoin; `_startPrivateMatch` after lobby/rematch still auto-connects (D-41 process-death vs isolate-alive)
- `NomadApi.rejoin` always sends the persisted matchId with the token; overlay timer starts at 30s and never exceeds SESS-02
- clearReconnect only on consented Pause leave, rematch reject, and grace expiry — catalog render does not wipe the bundle

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] Apply RejoinSnapshot saka poses on MatchGame**
- **Found during:** Task 2 (Secure token, auto-retry, banner, Rejoin overlay)
- **Issue:** Plan file list omitted `match_game.dart`, but a full RejoinSnapshot includes both saka poses; without `applySakaPose` the table would spawn at rim defaults after process death
- **Fix:** Added `AlchikiMatchGame.applySakaPose` and apply pending poses/last throw after GameWidget attach
- **Files modified:** `client/lib/games/alchiki/match_game.dart`, `client/lib/games/alchiki/match_page.dart`
- **Verification:** reconnect_overlay_test + rematch_page_test still pass
- **Committed in:** `9f914e0` (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (1 missing critical)
**Impact on plan:** Required to apply the 03-09 snapshot contract. No scope creep (no Ranked, Stick Pull, or bot-fill).

## Issues Encountered

None

## Authentication Gates

None

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Phase 3 client reconnect is in place against the 03-09 30s grace
- Human UAT still needed: two guests create → join → Ready → throw → kill dropped app within 30s → relaunch shows Rejoin match
- Ranked reconnect budget and Stick Pull policy stay out

## TDD Gate Compliance

- RED: `0cd9bb6` `test(03-10): add failing test for reconnect overlay`
- GREEN: `9f914e0` `feat(03-10): implement client reconnect token and Rejoin overlay`

## Self-Check: PASSED

- Key files exist on disk
- Commits `0cd9bb6` and `9f914e0` present in git log
- Acceptance greps: reconnectMatchId (session_store, splash, catalog), rejoinMatch (pause_overlay), reconnecting (match_hud), rejoin (nomad_api / match_page)
- `flutter test test/reconnect_overlay_test.dart` plus guest_mint/rematch/join/catalog/private_table passed
- ReconnectIT,LeaveIT: Tests run 5, Failures 0

---
*Phase: 03-private-rooms-casual-reconnect*
*Completed: 2026-09-07*
