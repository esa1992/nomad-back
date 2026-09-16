---
phase: 07-bind-ranked-ship
reviewed: 2026-09-15T01:40:00Z
depth: standard
files_reviewed: 31
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
  - backend/src/main/resources/db/migration/V14__glicko_all_time_rd_sigma.sql
  - compose.prod.yaml
  - client/lib/platform/api/nomad_api.dart
  - client/lib/profile/sign_in_sheet.dart
  - client/lib/platform/auth/bind_api.dart
findings:
  critical: 0
  warning: 0
  info: 3
  total: 3
status: clean
---

# Phase 7: Code Review Report

**Reviewed:** 2026-09-15T01:40:00Z
**Depth:** standard
**Files Reviewed:** 31
**Status:** clean

## Narrative Findings (AI reviewer)

## Summary

Iteration-2 re-review after CR-01 and WR-01…WR-06 fixes (`32764a7`…`d09968c`). Prior Critical/Warning items are **resolved**. No new Critical or Warning defects found in the fixed paths or adjacent Phase-7 sources. BindIT covers IDOR 401 and refresh-token possession; Flutter login sends Bearer + `guestRefreshToken` when `guestPlayerId` is set; Sign-In UI is guest-only so bound sessions do not mis-send non-guest IDs as adopt targets.

All reviewed files meet quality standards for Critical/Warning severity. Residual notes below are Info-only.

### Prior finding disposition

| ID | Disposition | Evidence |
|----|-------------|----------|
| CR-01 | **resolved** | `TokenService.requireGuestPossession` + `AuthService.login` gate; BindIT `loginAdoptWithoutGuestPossessionIsUnauthorized` / `loginAdoptAcceptsGuestRefreshPossession` |
| WR-01 | **resolved** | `abandonGuestEconomy` zeros wallets + deletes inventory/loadout before `revokeAll` in same TX |
| WR-02 | **resolved** | `GuestController.clientIp` uses only `request.getRemoteAddr()` |
| WR-03 | **resolved** | `compose.prod.yaml` requires `${NOMAD_POSTGRES_PASSWORD:?…}` |
| WR-04 | **resolved** | `RankedQueueService.requireBoundPlayer` + `MatchService.requireBoundSeat` DB `isGuest` checks |
| WR-05 | **resolved** | Separate all-time Glicko triple (`all_time_rd`/`all_time_sigma`); settle updates both ladders; soft-reset copies all-time intact |
| WR-06 | **resolved** | `MAX_PASSWORD_LENGTH=128` on bind and login before Argon2 |

## Info

### IN-01: EventSink scrub is still key-name only (narrow PII denylist)

**File:** `backend/src/main/java/com/nomadgames/analytics/EventSink.java:56-72`
**Issue:** Scrub still drops only keys containing `password`/`token`/`secret`. Current call sites emit UUIDs/enums (safe for T-07-25), but `username`/`email`/`authorization`/`cookie` would pass if added later. `toLowerCase()` without `Locale.ROOT` remains a minor i18n edge case.
**Fix:** Expand denylist (`user`, `email`, `auth`, `cookie`, `bearer`) and use `toLowerCase(Locale.ROOT)`; prefer allowlisted attr schemas per event type.

### IN-02: Client should omit `guestPlayerId` unless session is guest

**File:** `client/lib/profile/sign_in_sheet.dart:64-70`
**Also:** `client/lib/platform/api/nomad_api.dart:540-549`
**Issue:** Sign-In always forwards `session.playerId()` as `guestPlayerId`. Profile gates Sign-In to guests today, so this is safe in-product; a future entry point for bound sessions would 401 on possession/`not_a_guest`.
**Fix:** Only pass `guestPlayerId` (and possession headers) when `await session.isGuest()` is true.

### IN-03: Abandoned guest access JWT remains valid until TTL

**File:** `backend/src/main/java/com/nomadgames/identity/AuthService.java:94-96`
**Also:** `backend/src/main/java/com/nomadgames/identity/TokenService.java:38`
**Issue:** After `adopt=import`, economy is cleared and refresh revoked, but the guest access JWT (~15 min TTL) is not denylisted. Dual-spend of *copied* balances is closed; residual is limited to non-economy guest API use until expiry.
**Fix:** Optional access denylist / `guest=false` + abandoned flag if product requires immediate hard-kill of the guest device row.

---

_Reviewed: 2026-09-15T01:40:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
_Iteration: 2 (re-review after fixes)_
