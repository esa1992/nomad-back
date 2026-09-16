---
phase: 02-guest-catalog-first-alchiki-match
reviewed: 2026-09-07T03:32:00Z
depth: standard
plan: 09
files_reviewed: 2
files_reviewed_list:
  - backend/src/main/java/com/nomadgames/session/MatchService.java
  - backend/src/test/java/com/nomadgames/session/ThrowAuthorityIT.java
findings:
  critical: 0
  warning: 0
  info: 0
  total: 0
status: clean
prior_review_residual:
  critical: 0
  warning: 7
  info: 4
cr01_leave_rewrite: closed
forge2d_015: not_reopened
---

# Phase 2: Code Review Report

**Reviewed:** 2026-09-07T03:32:00Z (02-09 advisory, SESS-01 leaveMatch)
**Depth:** standard
**Files Reviewed:** 2
**Status:** clean

## Narrative Findings (AI reviewer)

## Summary

Advisory review of gap-closure plan 02-09 only (`leaveMatch` IN_PLAY guard). **CR-01 is closed:** `POST /v1/matches/{id}/leave` no longer rewrites a persisted `PLAYER_WIN` or `DRAW` to `BOT_WIN`.

`MatchService.leaveMatch` (lines 70–78) returns `LeaveResponse(snapshot(match))` with no `setStatus`/`save` when status is not `IN_PLAY`; an `IN_PLAY` owner leave still persists `BOT_WIN`. `MatchController.leave` remains a one-line delegate. `ThrowAuthorityIT.leaveAfterPlayerWinPreservesPlayerWin` and `leaveAfterDrawPreservesDraw` seed terminal status via parameterized JDBC and assert 200 + unchanged `$.match.status`. `leaveMatchReturnsBotWin` still covers consented IN_PLAY forfeit.

No new critical/high findings in this slice. Forge2D 0.15 was not reopened.

Prior 2026-09-06 warnings WR-01–WR-07 and info IN-01–IN-04 remain out of 02-09 scope (clocks, leftover spawn, empty table, guest mint, `@Version`, SessionStore). They are kept below so they are not lost.

All reviewed 02-09 files meet the leave-authority contract. No issues found in this slice.

## Closed this review (02-09)

### CR-01 CLOSED: POST /leave rewrites a finished match result (SESS-01)

**File:** `backend/src/main/java/com/nomadgames/session/MatchService.java:70-78`
**Also:** `backend/src/test/java/com/nomadgames/session/ThrowAuthorityIT.java:297-329,338-344`
**Was:** `leaveMatch` always wrote `BOT_WIN` with no `IN_PLAY` guard, so a client could replace a server-decided `PLAYER_WIN`/`DRAW`.
**Now:** After `requireOwner`, non-`IN_PLAY` returns the current snapshot without persist; `IN_PLAY` still sets `BOT_WIN` and saves. Early return does not mutate the entity (no dirty flush of a new outcome). ITs lock PLAYER_WIN and DRAW. Sequential POST `/leave` after a finished row cannot un-decide SESS-01.

```java
@Transactional
public LeaveResponse leaveMatch(UUID playerId, UUID matchId) {
    MatchEntity match = requireOwner(playerId, matchId);
    if (!MatchStatus.IN_PLAY.name().equals(match.getStatus())) {
        return new LeaveResponse(snapshot(match));
    }
    match.setStatus(MatchStatus.BOT_WIN.name());
    matches.save(match);
    return new LeaveResponse(snapshot(match));
}
```

Concurrent throw+leave lost-update without `@Version` remains prior WR-06, not a reopen of this sequential rewrite hole.

---

## Prior findings still open (2026-09-06, out of 02-09 scope)

These were not re-litigated. Do not treat them as 02-09 regressions.

## Warnings

### WR-01: Scoring still applies after matchDeadline / hardCap

**File:** `backend/src/main/java/com/nomadgames/session/MatchService.java:78-103`
**Also:** `backend/src/main/java/com/nomadgames/session/MatchService.java:106-114`
**Issue:** `applyThrow` checks only `IN_PLAY` and the 20s turn clock, then adds `displayedScore` and increment turns, then `resolve()`. `tickClocks` (GET) only forfeits an expired player turn — it never calls `AlchikiRules.resolve` for `matchDeadline` (4:00) or `hardCap` (5:00). A throw at 4:01 or 5:01 still pockets bones and changes the result, then ends. ALCH-03 says first-to-5 **or** highest after 8 turns / 4:00, hard cap 5:00. The official client never GETs, so a sitting match stays `IN_PLAY` past both caps until the next POST.
**Fix:** At the start of `applyThrow` and in `tickClocks`, if `AlchikiRules.resolve(...)` is no longer `IN_PLAY`, persist that status and return a no-op throw/snapshot **before** `engine.applyThrow`.

### WR-02: Leftover spawn contract diverges from the match table (hex reseed + 3× vs rest + 1×)

**File:** `harness/src/main/java/com/nomadgames/alchiki/proto/Dyn4jBurstSim.java:23-24,75-82,109-125`
**Also:** `client/lib/games/alchiki/match_game.dart:179-190`, `client/lib/game/saka_body.dart:43-50`
**Issue:** Match simulate always uses `spawnRemaining` (including throw 1) and `MATCH_IMPULSE_SCALE = 3.0`. Leftover targets are placed back on the seed-1 hex (b7 at origin); saka at `(0,-1.15)`. The Flutter match table only `resetSakaToRim()` — leftover bones stay at the last keyframe rest pose — and `SakaBody.applyThrowImpulse` uses the proto 1× hold curve. 02-04-SUMMARY required 02-08 to use the same match simulate path/scale so preview agrees with keyframes. It did not. Aiming at leftover-at-rest produces a local preview that the replay will snap off the hex. Pocketed IDs are correctly omitted (`spawnRemaining` + `bones_left.removeAll`); this is not a re-score hole.
**Fix:** Either (a) have the client reset leftover bones to the same seed-1 coordinates and apply the same 3× match impulse before local preview, or (b) stop reseeding leftover bones on the server and simulate from last rest poses (then drop the 3× hack). Do not keep both contracts.

### WR-03: Empty leftover set never terminates the match

**File:** `backend/src/main/java/com/nomadgames/games/alchiki/AlchikiRules.java:16-39`
**Also:** `backend/src/main/java/com/nomadgames/session/MatchService.java:93-101,138-158`
**Issue:** When every target is pocketed, `bones_left` is empty and `spawnRemaining` places only saka. `resolve()` still requires first-to-5, 8 turns each, or a clock. On EASY the table has 5 bones; a 3–2 finish with an empty circle cannot reach 5. Player and bot keep throwing at an empty table until 8/8 or 4:00. ALCH-03 implied scoring ends when bones leave.
**Fix:**
```java
if (bonesLeft.isEmpty()) {
    return byScore(playerScore, botScore);
}
```
Call this from `resolveAndContinue` after leftover removal (pass `bonesLeft.size()` into `resolve`).

### WR-04: Device clock ahead of server deadlocks the player turn

**File:** `client/lib/games/alchiki/match_page.dart:129-140,359-369,389-418`
**Also:** `backend/src/main/java/com/nomadgames/session/MatchService.java:86-91`
**Issue:** `_turnExpired` uses `DateTime.now()` vs the server epoch deadline. If the device clock is ahead, `_maybeAutoForfeit` POSTs `{}` while the server turn is still live. `hasValidImpulse` is false and `expiredAtStart` is false, so the server no-ops (no `playerTurns++`, no bot). Client sets `_forfeitSent = true` and does not clear it unless the deadline changes. `holdEnabled` stays false because `_turnExpired` is still true. The player cannot throw and will not auto-POST again when the real deadline arrives. Match stays `IN_PLAY` until Leave.
**Fix:** Treat a forfeit as sent only when `result.playerTurns` increased or status left `IN_PLAY`. If the server returns the same turn/deadline, clear `_forfeitSent` and keep Hold enabled. Prefer server remaining-ms (`turnDeadlineEpochMs - DateTime.now()` is fine only after a clock-offset estimate, or poll GET).

### WR-05: Guest mint rate limit trusts client X-Forwarded-For

**File:** `backend/src/main/java/com/nomadgames/identity/GuestController.java:38-43`
**Also:** `backend/src/main/java/com/nomadgames/identity/internal/GuestMintRateLimiter.java:28-41`
**Issue:** `clientIp` prefers `X-Forwarded-For` first hop with no trusted-proxy check. Any caller can send a unique header per request and bypass the 20/min mint cap (`T-02-06`). That farms unlimited guest JWTs and `/v1/matches` rows (no per-player IN_PLAY cap).
**Fix:** Use `request.getRemoteAddr()` unless an explicit trusted proxy list is configured; if a proxy is required, take XFF only from that hop. Keep the in-process limiter as a secondary brake.

### WR-06: Throws are not idempotent and matches have no optimistic lock

**File:** `backend/src/main/java/com/nomadgames/session/internal/MatchEntity.java:16-18`
**Also:** `backend/src/main/java/com/nomadgames/session/MatchService.java:83-85,174`, `client/lib/games/alchiki/match_page.dart:426-449`
**Issue:** `MatchEntity` has no `@Version`. `turn` is set to `PLAYER` at create and never flipped to `BOT` (bot half is inline), so the `409 not your turn` guard never fires. Two concurrent POSTs both apply a player+bot half (lost update or two halves, depending on commit order). Client `_retryThrow` resubmits the last input after a transport error even if the first POST already committed — a second real turn, not a forged score, but it changes the SESS-01 result.
**Fix:** Add `@Version` and reject stale updates with 409. Require a client `throwSeq` / idempotency key equal to `playerTurns + 1`. Retry only when the server still reports the same `playerTurns`.

### WR-07: Session persist failure drops the guest identity

**File:** `client/lib/platform/auth/session_store.dart:31-41,55-64`
**Also:** `client/lib/platform/splash_page.dart:62-65`
**Issue:** `_write` / `clear` swallow all plugin errors. Mint can succeed in memory (`NomadApi.accessToken`) while refresh never hits secure storage. Next cold start sees `playerId` missing (or stale) and mints a new guest, or loops splash↔catalog 401 if `clear` failed and `playerId` is stuck without a refresh token. AUTH-01 “reach a first match without username” breaks across process death.
**Fix:** Surface persist failure to splash (`errorGuestMint` + Retry). On `clear` failure, also wipe in-memory keys and force remint. Tests should keep `SessionStore.memory()`.

## Info

### IN-01: Client HUD ignores `playerThrow.displayedScore` and gates on `allowsReplay`

**File:** `client/lib/replay/throw_resolved.dart:38-39,160-166`
**Also:** `client/lib/platform/api/nomad_api.dart:341-358`, `client/lib/games/alchiki/match_page.dart:409`
**Issue:** REST already authors `displayedScore`. The client parser injects `input` (PlayerThrowView has none), then `displayedScore()` recomputes `sakaOut ? 0 : pocketedCount` and `allowsReplay` can return null (forfeit path shows `scored —`). Running totals still come from `match.playerScore` / `botScore`.
**Fix:** Prefer the server `displayedScore` field when present; skip `allowsReplay` on the match REST path.

### IN-02: `_matchFromThrow` drops `botTurns`

**File:** `client/lib/games/alchiki/match_page.dart:372-386`
**Also:** `client/lib/platform/api/nomad_api.dart:55-80`
**Issue:** `ThrowSubmitResult` has no `botTurns`; the client copies the pre-throw value (usually 0). Unused for win detection today (`status` is server-authored) but will lie if anything later reads `_match.botTurns`.
**Fix:** Add `botTurns` to the parse path and copy `result.botTurns`.

### IN-03: Token rotate always re-issues `guest=true`

**File:** `backend/src/main/java/com/nomadgames/identity/TokenService.java:66-78`
**Issue:** `rotate` calls `issue(existing.getPlayerId(), true)` regardless of `players.guest`. Fine while AUTH-02 is unbuilt; it will stamp bound accounts as guests after refresh.
**Fix:** Load `PlayerEntity.guest` (or store it on the refresh row) before `issue`.

### IN-04: `hasValidImpulse` is a substring gate, not a schema check

**File:** `backend/src/main/java/com/nomadgames/session/MatchService.java:187-191`
**Issue:** Presence of `"aimAngleRad"` and `"holdMs"` only decides forfeit vs parse. A body that mentions those keys inside another string still reaches `ThrowInput.parse` (400) or clamps a missing `holdMs` to 150. Not a score inject, but the forfeit vs throw branch is easy to misread.
**Fix:** Delete the substring check; `try { ThrowInput.parse(rawJson) } catch { treat as no impulse }`.

---

_Reviewed: 2026-09-07T03:32:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
_Scope: 02-09 leaveMatch IN_PLAY guard only_
_CR-01: closed_
_Forge2D 0.15: not reopened_
