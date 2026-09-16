---
phase: 07-bind-ranked-ship
fixed_at: 2026-09-15T01:35:00Z
review_path: .planning/phases/07-bind-ranked-ship/07-REVIEW.md
iteration: 1
findings_in_scope: 7
fixed: 7
skipped: 0
status: all_fixed
---

# Phase 7: Code Review Fix Report

**Fixed at:** 2026-09-15T01:35:00Z
**Source review:** `.planning/phases/07-bind-ranked-ship/07-REVIEW.md`
**Iteration:** 1

**Summary:**
- Findings in scope: 7
- Fixed: 7
- Skipped: 0

**BindIT:** passed — 10 tests, 0 failures (Surefire `TEST-com.nomadgames.identity.BindIT.xml`)

## Fixed Issues

### CR-01: Login adopt accepts unproven `guestPlayerId` (guest wallet IDOR / session kill)

**Files modified:** `backend/src/main/java/com/nomadgames/identity/AuthService.java`, `backend/src/main/java/com/nomadgames/identity/GuestController.java`, `backend/src/main/java/com/nomadgames/identity/LoginRequest.java`, `backend/src/main/java/com/nomadgames/identity/TokenService.java`, `backend/src/test/java/com/nomadgames/identity/BindIT.java`, `client/lib/platform/api/nomad_api.dart`
**Commit:** `32764a7`
**Status:** fixed: requires human verification
**Applied fix:** Login adopt now requires guest possession via `Authorization: Bearer` guest access (`sub` + `guest` claim + DB `isGuest`) or body `guestRefreshToken` mapped to that guest. Flutter login sends Bearer + refresh when `guestPlayerId` is set. BindIT covers IDOR 401 and refresh-token possession.

### WR-01: Adopt import abandons guest incompletely (dual-spend window)

**Files modified:** `backend/src/main/java/com/nomadgames/identity/AuthService.java`
**Commit:** `b2e16ca`
**Status:** fixed: requires human verification
**Applied fix:** After `adopt=import` copy, zero guest wallets and delete inventory/loadout in the same TX before `revokeAll`.

### WR-02: Login rate limit trusts client `X-Forwarded-For` (ASVS L1 bypass)

**Files modified:** `backend/src/main/java/com/nomadgames/identity/GuestController.java`
**Commit:** `2c7f3ab`
**Status:** fixed
**Applied fix:** `clientIp` uses only `request.getRemoteAddr()` (no blind XFF trust).

### WR-03: `compose.prod.yaml` ships default Postgres credentials

**Files modified:** `compose.prod.yaml`
**Commit:** `4cd4063`
**Status:** fixed
**Applied fix:** `POSTGRES_PASSWORD` / datasource passwords require `${NOMAD_POSTGRES_PASSWORD:?…}` like JWT secret.

### WR-04: Ranked bound gate is JWT-claim-only (no DB re-check)

**Files modified:** `backend/src/main/java/com/nomadgames/matchmaking/RankedQueueService.java`, `backend/src/main/java/com/nomadgames/session/MatchService.java`
**Commit:** `31604b8`
**Status:** fixed: requires human verification
**Applied fix:** `RankedQueueService.enqueue` and `MatchService.createRankedMatch` reject seats when DB `players.guest=true` (fail-closed).

### WR-05: `all_time_rating` overwritten by season Glicko after soft-reset

**Files modified:** `backend/src/main/resources/db/migration/V14__glicko_all_time_rd_sigma.sql`, `backend/src/main/java/com/nomadgames/rating/internal/GlickoRatingEntity.java`, `backend/src/main/java/com/nomadgames/rating/RatingService.java`, `backend/src/main/java/com/nomadgames/rating/SeasonService.java`
**Commit:** `5821d69`
**Status:** fixed: requires human verification
**Applied fix:** Added `all_time_rd` / `all_time_sigma`; settle updates a separate all-time Glicko triple; soft-reset copies the all-time triple intact.

### WR-06: No password maximum length (Argon2 DoS)

**Files modified:** `backend/src/main/java/com/nomadgames/identity/BindService.java`, `backend/src/main/java/com/nomadgames/identity/AuthService.java`
**Commit:** `d09968c`
**Status:** fixed
**Applied fix:** Reject passwords longer than 128 chars on bind (400) and login (400) before Argon2.

---

_Fixed: 2026-09-15T01:35:00Z_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
