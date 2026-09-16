---
phase: 07-bind-ranked-ship
reviewed: 2026-09-14T15:46:00Z
depth: standard
files_reviewed: 28
files_reviewed_list:
  - backend/src/main/java/com/nomadgames/identity/BindService.java
  - backend/src/main/java/com/nomadgames/identity/AuthService.java
  - backend/src/main/java/com/nomadgames/identity/TokenService.java
  - backend/src/main/java/com/nomadgames/identity/GuestController.java
  - backend/src/main/java/com/nomadgames/identity/SecurityConfig.java
  - backend/src/main/java/com/nomadgames/identity/PasswordConfig.java
  - backend/src/main/java/com/nomadgames/identity/internal/LoginRateLimiter.java
  - backend/src/main/java/com/nomadgames/matchmaking/RankedQueueService.java
  - backend/src/main/java/com/nomadgames/matchmaking/RankedMatchmakingController.java
  - backend/src/main/java/com/nomadgames/session/MatchService.java
  - backend/src/main/java/com/nomadgames/session/internal/ReconnectPolicy.java
  - backend/src/main/java/com/nomadgames/session/internal/MatchSessionRegistry.java
  - backend/src/main/java/com/nomadgames/session/internal/MatchWebSocketHandler.java
  - backend/src/main/java/com/nomadgames/rating/RatingService.java
  - backend/src/main/java/com/nomadgames/rating/SeasonService.java
  - backend/src/main/java/com/nomadgames/rating/BoardsService.java
  - backend/src/main/java/com/nomadgames/rating/BoardsController.java
  - backend/src/main/java/com/nomadgames/rating/internal/Glicko2.java
  - backend/src/main/java/com/nomadgames/analytics/EventSink.java
  - backend/src/main/java/com/nomadgames/analytics/internal/AnalyticsJdbc.java
  - backend/src/main/java/com/nomadgames/analytics/AppStartedEmitter.java
  - backend/src/main/java/com/nomadgames/games/stickpull/StickPullSim.java
  - backend/src/main/java/com/nomadgames/profile/ProfileService.java
  - backend/src/main/resources/db/migration/V11__credentials_bind.sql
  - backend/src/main/resources/db/migration/V12__glicko_ratings.sql
  - backend/src/main/resources/db/migration/V13__analytics_events.sql
  - compose.prod.yaml
  - client/lib/platform/api/nomad_api.dart
findings:
  critical: 1
  warning: 6
  info: 3
  total: 10
status: issues_found
---

# Phase 7: Code Review Report

**Reviewed:** 2026-09-14T15:46:00Z
**Depth:** standard
**Files Reviewed:** 28
**Status:** issues_found

## Narrative Findings (AI reviewer)

## Summary

Advisory standard review of Phase 7 Bind / Ranked / Ship production paths (bind+adopt, JWT guest claim, Ranked gate, pause budget, Glicko settle, EventSink, ASVS L1). **TokenService.rotate correctly reads `player.isGuest()` from DB**, Ranked/Boards guest enqueue/read is rejected via JWT `guest` claim (fail-closed on null), pause-budget accrual + next-drop forfeit matches D-102, SoftElo stays Casual-only, and EventSink catches failures so settle TX is not rolled back.

Primary ship blocker: **unauthenticated `guestPlayerId` on permitAll login enables guest progress theft and refresh revocation (IDOR)** — ASVS L1 authorization gap on the D-93 adopt contract.

## Critical Issues

### CR-01: Login adopt accepts unproven `guestPlayerId` (guest wallet IDOR / session kill)

**File:** `backend/src/main/java/com/nomadgames/identity/AuthService.java:54-88`
**Also:** `backend/src/main/java/com/nomadgames/identity/GuestController.java:66-72` (`/v1/identity/login` is `permitAll`)
**Issue:** `login` is unauthenticated. Any caller who knows a victim guest UUID (visible in match/seat payloads, casual opponents, etc.) and credentials for an **empty** bound account can `adopt=import` and overwrite that bound account’s wallets/cosmetics with the victim’s balances, then `revokeAll(guestPlayerId)`. `adopt=drop` alone revokes the victim’s refresh tokens with no proof of guest session possession. Client “probe” UX does not mitigate this — the server never binds `guestPlayerId` to a presented guest access/refresh token.
**Fix:** Require proof of control of the guest session before import/drop (and ideally before emitting adopt hints that confirm a guest exists):

```java
// e.g. require Authorization: Bearer <guest access> whose sub == guestPlayerId
// OR body.guestRefreshToken that rotates/hashes to a live refresh row for guestPlayerId
private void requireGuestPossession(UUID guestPlayerId, String guestAccessOrRefresh) {
    // validate token → subject/playerId must equal guestPlayerId and player.isGuest()
}
```

Reject import/drop when possession proof is missing (`401`/`403`). Keep wallet never-sum rules unchanged.

## Warnings

### WR-01: Adopt import abandons guest incompletely (dual-spend window)

**File:** `backend/src/main/java/com/nomadgames/identity/AuthService.java:81-84`, `142-204`
**Issue:** After `adopt=import`, guest wallets/inventory remain intact; only refresh rows are revoked. Victim access JWT remains valid up to ~15 minutes, so both bound copy and original guest balances can be spent. D-93 “abandon guest device row” is only partially implemented.
**Fix:** After successful copy, zero or lock the guest economy (wallets=0 / mark player abandoned) and revoke access by also rotating/blacklisting or deleting guest player usability; at minimum `revokeAll` plus clear wallet/inventory for `guestId` in the same TX.

### WR-02: Login rate limit trusts client `X-Forwarded-For` (ASVS L1 bypass)

**File:** `backend/src/main/java/com/nomadgames/identity/GuestController.java:85-90`
**Also:** `backend/src/main/java/com/nomadgames/identity/internal/LoginRateLimiter.java:29-42`
**Issue:** `clientIp` prefers the first `X-Forwarded-For` hop unconditionally. Without a trusted-proxy gate, attackers spoof a new IP per attempt and bypass the 20/min stuffing limit (T-07-09).
**Fix:** Use `request.getRemoteAddr()` unless behind a configured trusted proxy (`server.forward-headers-strategy` / explicit allowlist), or take the rightmost trusted hop only.

### WR-03: `compose.prod.yaml` ships default Postgres credentials

**File:** `compose.prod.yaml:11-13`, `31-35`
**Issue:** PROD compose hard-codes `POSTGRES_PASSWORD: nomad` and injects the same into the app. JWT secret is correctly required from the host, but DB credentials fail ASVS L1 stored-secrets hygiene for a “prod” topology.
**Fix:** Require host env for DB password (same pattern as `NOMAD_JWT_SECRET:?…`) and do not commit a real default.

### WR-04: Ranked bound gate is JWT-claim-only (no DB re-check)

**File:** `backend/src/main/java/com/nomadgames/matchmaking/RankedMatchmakingController.java:56-61`
**Also:** `backend/src/main/java/com/nomadgames/session/MatchService.java:287-288` (`createRankedMatch` never asserts bound players)
**Issue:** Guests are blocked only by access-token `guest` claim. `RankedQueueService` / `createRankedMatch` never verify `players.guest=false` (or credentials row) for either seat. Defense-in-depth gap if a stale/mis-issued claim ever appears; peer eligibility is entirely implicit.
**Fix:** In `enqueue` (and optionally `createRankedMatch`), load both player rows (or credentials) and reject if `isGuest()`; keep controller claim check as the fast path.

### WR-05: `all_time_rating` overwritten by season Glicko after soft-reset

**File:** `backend/src/main/java/com/nomadgames/rating/RatingService.java:74-82`
**Also:** `backend/src/main/java/com/nomadgames/rating/SeasonService.java:125-127`
**Issue:** Soft-reset correctly copies prior `all_time_*`, but each Ranked settle does `setAllTimeRating(next.r())` where `next` is computed from **season** rating (post soft-reset). That collapses `all_time_rating` toward the season ladder. Boards currently rank `all_time_peak` (so LEAD UI is OK), but the `all_time_rating` column is no longer a coherent all-time Glicko state.
**Fix:** Maintain a separate all-time Glicko triple (or update `all_time_rating` from prior all-time rating/RD/σ, not from season `next.r()`), and keep `all_time_peak = max(peak, all_time_rating)`.

### WR-06: No password maximum length (Argon2 DoS)

**File:** `backend/src/main/java/com/nomadgames/identity/BindService.java:49-51`
**Also:** `backend/src/main/java/com/nomadgames/identity/AuthService.java:55-62`
**Issue:** Bind enforces `length >= 8` only; login accepts any non-null password. Oversized password bodies force expensive Argon2id work per attempt (ASVS L1 DoS), partially mitigated by IP rate limit but still costly per request.
**Fix:** Reject passwords longer than a fixed cap (e.g. 72–128 chars) on bind and login before `matches`/`encode`.

## Info

### IN-01: EventSink scrub is key-name only (narrow PII denylist)

**File:** `backend/src/main/java/com/nomadgames/analytics/EventSink.java:56-72`
**Issue:** Scrub drops keys containing `password`/`token`/`secret` only. Current call sites mostly emit UUIDs/enums (good for T-07-25), but `username`/`email`/`authorization`/`cookie` would pass through if added later. `toLowerCase()` without `Locale.ROOT` is a minor i18n edge case.
**Fix:** Expand denylist (`user`, `email`, `auth`, `cookie`, `bearer`) and use `toLowerCase(Locale.ROOT)`; prefer allowlisted attr schemas per event type.

### IN-02: Pause-budget griefing path looks correctly closed

**File:** `backend/src/main/java/com/nomadgames/session/MatchService.java:677-720`, `861-876`
**Issue:** No defect found for D-102: aggregate `pauseUsedMs` accrues on rejoin/WS `clearSeatDrop`/settle; once budget exhausted, **next** `markDropped` forfeits immediately without bot-fill. Flapping disconnects still consume budget as intended.
**Fix:** None required; keep IT coverage on budget→immediate forfeit.

### IN-03: `TokenService.rotate` guest claim is DB-backed (focus item OK)

**File:** `backend/src/main/java/com/nomadgames/identity/TokenService.java:72-88`
**Issue:** None. Rotate loads `PlayerEntity` and calls `issue(id, player.isGuest())`, so bind/login flipping `guest=false` is reflected on refresh (AUTH-03). Bind path does not wallet-merge (AUTH-02 / D-93 bind half OK).
**Fix:** None.

---

_Reviewed: 2026-09-14T15:46:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
