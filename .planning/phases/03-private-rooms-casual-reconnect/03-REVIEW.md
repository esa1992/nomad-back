---
phase: 03-private-rooms-casual-reconnect
reviewed: 2026-09-08T11:03:00Z
depth: standard
files_reviewed: 5
files_reviewed_list:
  - client/lib/games/alchiki/match_page.dart
  - client/test/reconnect_overlay_test.dart
  - backend/src/main/java/com/nomadgames/session/MatchService.java
  - backend/src/main/java/com/nomadgames/session/internal/MatchWebSocketHandler.java
  - backend/src/test/java/com/nomadgames/session/ReconnectIT.java
findings:
  critical: 0
  warning: 5
  info: 1
  total: 6
status: issues
---

# Phase 3: Code Review Report

**Reviewed:** 2026-09-08T11:03:00Z
**Depth:** standard
**Files Reviewed:** 5
**Status:** issues

## Summary

Re-review after gap-closure 03-14 (isolate-alive 409 IN_PLAY). Scope is the five 03-14 files. Locks that still hold: `ReconnectPolicy.GRACE_SECONDS = 30`, no bot-fill on PRIVATE, raw WS (no STOMP), forge2d not touched.

**CR-01 is closed in source.** `_rejoinMatch` maps only HTTP 410 to `_onGraceExpiredDropped`. Status 409 GETs the stored match; terminal statuses apply the snapshot; `IN_PLAY` keeps the rotating token and resumes via `_attachPrivateSocket` (ws-ticket then connect). `_reconnectPrivateSocket` captures the lost `MatchSocket` and returns as success only when `_socket` is a different non-null instance and `_rejoinError` is false. `MatchService.clearSeatDrop` nulls that `playerId`'s grace without rotating the token; `afterConnectionEstablished` calls it after `registry.add`. Widget test `isolate-alive first rejoin 409 keeps token then tickets` and `ReconnectIT#handshakeClearsSeatGrace` lock both holes.

**CR-02 and CR-05 remain out of 03-14 by design.** They are still present in the reviewed files and are filed as warnings, not blockers for this slice.

New 03-14 regression: overlay Rejoin on 409 `match settled` applies the snapshot but leaves `_showRejoin` true, so `ResultOverlay` stays gated off until the local countdown hits 0.

## Narrative Findings (AI reviewer)

## Warnings

### WR-01: Overlay remaining grace still invents 30s when GET fails or field is null

**File:** `client/lib/games/alchiki/match_page.dart:398-406`
**Issue:** Process-death overlay seeds `_rejoinSecondsAtShow` from `reconnectSecondsLeft` on the happy path. If `getMatch` throws, `remaining = 30`. If the snapshot omits the field (`?? 30`), a cold start whose WS close has not yet `markDropped` (or whose match already settled and cleared drops) shows a full local 30s. Cap 0..30 is correct when the server value is present (`MatchService.remainingGraceSeconds` 656–678).
**Fix:** On GET failure, keep overlay but treat remaining as unknown (disable the padded countdown or show Rejoin without a fake 00:30). If `reconnectSecondsLeft` is null, do not default to 30 — retry GET or show the overlay without a timer until grace exists.

### WR-02: Private turn and match clocks never settle unless someone throws (CR-02, out of 03-14)

**File:** `backend/src/main/java/com/nomadgames/session/MatchService.java:243-301`
**Issue:** Confirmed still present; 03-14 explicitly skipped it. Bot `applyThrow` / `tickClocks` forfeit when `turn == PLAYER`. `applyPrivateThrow` never calls `forfeitThrowIfExpired`. `tickClocks` ignores `HOST` / `JOINER`. `getMatch` calls `tickClocks` but that is a no-op for private turns. Client HUD disables Hold Throw when `_turnExpired` and `_maybeAutoForfeit` returns immediately for `_isPrivate` (`match_page.dart:1073-1081`). After 20s the current seat cannot throw, the other seat is not on turn, match deadline never evaluates. Table stuck until Pause → Leave. A modified client that still sends `ThrowInput` after expiry scores on the server.
**Fix:** In `applyPrivateThrow`, if the turn expired, record a 0-score forfeit, increment that seat's turns, flip HOST/JOINER, `resolve(privateScoreClock)`, broadcast. Drive the same path from a 1 Hz tick (or `getMatch`) for HOST/JOINER, not only PLAYER.

```java
Instant now = Instant.now();
if (engine.forfeitThrowIfExpired(now, match.getTurnDeadline())) {
    if (joinerTurn) {
        match.setBotTurns(match.getBotTurns() + 1);
        match.setTurn("HOST");
    } else {
        match.setPlayerTurns(match.getPlayerTurns() + 1);
        match.setTurn("JOINER");
    }
    match.setTurnDeadline(now.plus(engine.turnClock()));
    match.setStatus(engine.resolve(privateScoreClock(match), now).name());
    matches.save(match);
    return new PrivateThrowResult(forfeitThrowView(), snapshot(match));
}
```

### WR-03: Every private WS CONFLICT is `not_your_turn`

**File:** `backend/src/main/java/com/nomadgames/session/internal/MatchWebSocketHandler.java:160-165`
**Issue:** Unchanged. `codeFor` maps all `409` to `not_your_turn`, including `opponent reconnecting`, `match settled`, and `not a private match`. After a freeze the client can retry a throw the server is correctly refusing during grace.
**Fix:** Pass `ex.getReason()` (or a dedicated code) through: `opponent_reconnecting`, `match_settled`, `not_your_turn`.

### WR-04: Consented leave is REST-only; a failed leave becomes a reconnect drop (CR-05, out of 03-14)

**File:** `client/lib/games/alchiki/match_page.dart:1178-1203`
**Issue:** Confirmed still present; 03-14 explicitly skipped WS close 4000. D-41/D-44: close code 4000 is consented leave; other closes are 30s hold. `_leaveMatch` sets `_consentedLeave`, POSTs `/leave`, then **always** `_goCatalog()`, including when the POST throws. Dispose then closes the socket with the default code (`MatchSocket.close` has no 4000 argument). If REST leave failed or raced, the server runs `markDropped` instead of `leaveMatch` — 30s grace, not an immediate loss. Handler support for 4000 (`MatchWebSocketHandler.java:112-117`) is still unused by the product client.
**Fix:** Close the socket with code 4000 before or together with REST leave; do not navigate to catalog if leave failed while IN_PLAY. `MatchSocket.close` should accept a close code.

```dart
await _socket?.close(code: 4000);
final MatchStart left = await api.leaveMatch(match.matchId);
```

### WR-05: Overlay 409 match-settled applies snapshot but keeps Rejoin overlay

**File:** `client/lib/games/alchiki/match_page.dart:645-658`
**Issue:** 03-14 regression, distinct from closed CR-01. Server `rejoin()` throws **409 `match settled`** when status is already not `IN_PLAY` (scheduler already wrote `HOST_WIN`/`JOINER_WIN`). Only in-flight expiry during `rejoin` is 410. `_resumeAfterRejoinConflict` correctly applies the terminal snapshot and returns, but it does not set `_showRejoin = false` and does not `clearReconnect`. `ResultOverlay` is gated on `_isTerminal && !_showRejoin` (`match_page.dart:1477`), so the player keeps seeing Rejoin match. Before 03-14 every 409 called `_onGraceExpiredDropped`, which hid the overlay. Isolate-alive is unaffected (`_showRejoin` is already false). Process-death after grace expiry: boot often seeds 30s via WR-01 (`reconnectSecondsLeft` is null after `clearDrops`), tap Rejoin no longer escapes, user waits for the local timer to call `_onGraceExpiredDropped`.
**Fix:** On terminal GET after 409, hide overlay, clear the rotating token, then return.

```dart
if (snap.status == 'HOST_WIN' ||
    snap.status == 'JOINER_WIN' ||
    snap.status == 'PLAYER_WIN' ||
    snap.status == 'BOT_WIN' ||
    snap.status == 'DRAW') {
  await _applyPrivateSnapshot(snap);
  await ref.read(sessionStoreProvider).clearReconnect();
  if (mounted) {
    setState(() {
      _showRejoin = false;
      _rejoinError = false;
    });
  }
  return;
}
```

## Info

### IN-01: Both-drop grace expiry still treats the joiner as the expired seat first

**File:** `backend/src/main/java/com/nomadgames/session/MatchService.java:408-419`
**Issue:** If both seats expire on the same tick, `settleExpiredDrop(match, joinerExpired ? false : true)` awards `HOST_WIN`. PRIVATE never `BOT_WIN` here (correct); simultaneous expiry is still host-favored rather than DRAW / earlier deadline.
**Fix:** If both expired, `DRAW`, or compare `hostGraceDeadline` vs `joinerGraceDeadline` and expire only the earlier one.

---

### Prior CR / WR disposition

| ID | Prior | Now |
|----|-------|-----|
| CR-01 | 409→expiry + markDropped-before-add | **Closed** — 410-only expiry; 409 + GET `IN_PLAY` tickets a new socket; identity retry; handshake `clearSeatDrop` |
| CR-02 | Private clocks never forfeit | **Warning (WR-02)** — out of 03-14; still in `MatchService` |
| CR-03 | Concurrent Ready lost-update | Closed (not in this file list) |
| CR-04 | Dual rematch double-create | Closed (not in this file list) |
| CR-05 | Leave REST-only; no WS 4000 | **Warning (WR-04)** — out of 03-14; still in `match_page` / unused handler 4000 |
| WR-01 | Overlay invents 30s | **Still warning** |
| WR-03 | All WS 409 → `not_your_turn` | **Still warning** |
| WR-05 | — | **New** — overlay 409 settled leaves Rejoin up |

### CR-01 source check (03-14)

**Does CR-01 still falsify SESS-02?** No.

1. `match_page.dart:624-630` — only `statusCode == 410` calls `_onGraceExpiredDropped`; `409` calls `_resumeAfterRejoinConflict`.
2. `_resumeAfterRejoinConflict` (`645-674`) GETs match; terminal statuses apply snapshot; `IN_PLAY` does not `clearReconnect`; GET failure sets `_rejoinError` and does not invent `HOST_WIN`/`JOINER_WIN`.
3. `_reconnectPrivateSocket` (`491-497`) captures `lost` before `_rejoinMatch` and returns only when `_socket != null && !identical(_socket, lost) && !_rejoinError`.
4. `MatchService.clearSeatDrop` (`379-397`) nulls that seat's grace, unfreezes if last drop, does not rotate the token, no REST mapping (`MatchController` has no such route).
5. `MatchWebSocketHandler.afterConnectionEstablished` (`46-53`) `registry.add` then `clearSeatDrop(ATTR_PLAYER_ID)` inside `ResponseStatusException` catch.
6. Tests: `reconnect_overlay_test.dart` isolate-alive 409 keeps token + later `wsTicket`; `ReconnectIT#handshakeClearsSeatGrace` tickets without POST rejoin, `reconnectSecondsLeft` JSON null, status stays `IN_PLAY`.

---

_Reviewed: 2026-09-08T11:03:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
