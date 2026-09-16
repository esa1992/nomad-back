---
phase: 07-bind-ranked-ship
plan: 03
subsystem: auth
tags: [login, logout, refresh, adopt, D-93, AUTH-03, AUTH-04, argon2id, jwt]

requires:
  - phase: 07-bind-ranked-ship
    provides: BindService + Argon2id credentials + BindIT AUTH-02 greens (07-02)
  - phase: 07-bind-ranked-ship
    provides: Wave 0 BindIT RED stubs for login/logout/adopt (07-01)
provides:
  - "POST /v1/identity/login permitAll with Argon2 verify + LoginRateLimiter"
  - "TokenService.rotate loads PlayerEntity.isGuest() into JWT claim"
  - "POST /v1/identity/logout revokes refresh and mints guest session"
  - "D-93 adopt=none|import|drop never-sum / empty import / drop-guest"
affects:
  - 07-09 flutter bind sheet
  - 07-10 soft-lock sign-in logout UI
  - 07-07 EventSink LOGIN emit site

tech-stack:
  added: []
  patterns:
    - "rotate guest claim from DB only (never hardcode true)"
    - "adopt contract: none hint / import empty-target / drop revoke-only"
    - "LoginRateLimiter per-IP window (T-07-09)"

key-files:
  created:
    - backend/src/main/java/com/nomadgames/identity/AuthService.java
    - backend/src/main/java/com/nomadgames/identity/LoginRequest.java
    - backend/src/main/java/com/nomadgames/identity/AdoptHint.java
    - backend/src/main/java/com/nomadgames/identity/internal/LoginRateLimiter.java
  modified:
    - backend/src/main/java/com/nomadgames/identity/TokenService.java
    - backend/src/main/java/com/nomadgames/identity/TokenPair.java
    - backend/src/main/java/com/nomadgames/identity/GuestController.java
    - backend/src/main/java/com/nomadgames/identity/GuestSessionResponse.java
    - backend/src/main/java/com/nomadgames/identity/SecurityConfig.java
    - backend/src/main/java/com/nomadgames/identity/internal/RefreshTokenRepository.java
    - backend/src/main/resources/application.yaml

key-decisions:
  - "Logout endpoint mints GuestSessionResponse (server-side) so BindIT logoutMintsGuest greens; Flutter still clears storage in 07-10"
  - "TokenPair includes guest boolean so refresh JSON exposes DB-backed claim for AUTH-03"
  - "Import eligibility is matches==0 AND (no ledger debit AND no soft_purchases); wallet balance alone does not block import"
  - "adopt=none with guestPlayerId returns adoptHint IMPORT_ELIGIBLE|DROP_REQUIRED for 07-10 sheets"

patterns-established:
  - "AuthService.login(username, password, guestPlayerId, adopt) → GuestSessionResponse guest=false"
  - "tokens.revokeAll(playerId) via RefreshTokenRepository.deleteByPlayerId"
  - "Empty import overwrites bound wallets then copies inventory/loadout; never SUM"

requirements-completed: [AUTH-03, AUTH-04]

coverage:
  - id: D1
    description: "Bound login + refresh keeps guest=false claim (AUTH-03)"
    requirement: AUTH-03
    verification:
      - kind: integration
        ref: "backend/.../BindIT.java#loginThenRefreshBound"
        status: pass
    human_judgment: false
  - id: D2
    description: "Logout revokes refresh; bound credentials remain loginable; response is guest session (AUTH-04)"
    requirement: AUTH-04
    verification:
      - kind: integration
        ref: "backend/.../BindIT.java#logoutMintsGuest"
        status: pass
    human_judgment: false
  - id: D3
    description: "adopt=none never sums guest wallets onto non-empty bound (D-93)"
    requirement: AUTH-03
    verification:
      - kind: integration
        ref: "backend/.../BindIT.java#loginNeverSumsOntoNonEmptyTarget"
        status: pass
    human_judgment: false
  - id: D4
    description: "Empty-target adopt=import copies guest wallets onto bound (D-93)"
    requirement: AUTH-03
    verification:
      - kind: integration
        ref: "backend/.../BindIT.java#loginEmptyTargetImportsGuest"
        status: pass
    human_judgment: false
  - id: D5
    description: "adopt=drop revokes guest refresh and leaves bound balances intact (D-93)"
    requirement: AUTH-04
    verification:
      - kind: integration
        ref: "backend/.../BindIT.java#loginDropGuestLeavesBoundIntact"
        status: pass
    human_judgment: false

duration: 6min
completed: 2026-09-14
status: complete
---

# Phase 07 Plan 03: Login / Rotate / Logout + D-93 Adopt Summary

**Bound login with Argon2, DB-backed refresh guest claim, logout mint, and never-sum adopt=none|import|drop contract (AUTH-03/04, D-93).**

## Performance

- **Duration:** 6 min
- **Started:** 2026-09-14T11:40:07Z
- **Completed:** 2026-09-14T11:46:16Z
- **Tasks:** 2
- **Files modified:** 11

## Accomplishments

- `TokenService.rotate` loads `PlayerEntity.isGuest()` instead of hardcoding `true` (AUTH-03)
- `POST /v1/identity/login` (permitAll) + `LoginRateLimiter`; bad password → 401
- `POST /v1/identity/logout` revokes all refresh rows and returns a newly minted guest session (AUTH-04)
- D-93 adopt: never-sum on none/drop; empty-target import copies wallets/cosmetics once; non-eligible import → 409 `import_not_eligible`; `adoptHint` on adopt=none
- BindIT `loginThenRefreshBound`, `logoutMintsGuest`, `loginNeverSumsOntoNonEmptyTarget`, `loginEmptyTargetImportsGuest`, `loginDropGuestLeavesBoundIntact` green

## Task Commits

Each task was committed atomically:

1. **Task 1: Login, TokenService.rotate guest-from-DB, logout revoke** - `fe06f2b` (feat)
2. **Task 2: D-93 adopt contract — never-sum / empty import / drop guest** - `4203bf0` (feat)

**Plan metadata:** `2b5f7f0` (docs: complete plan)

## Files Created/Modified

- `backend/src/main/java/com/nomadgames/identity/AuthService.java` - login + logout + adopt
- `backend/src/main/java/com/nomadgames/identity/LoginRequest.java` - username/password/guestPlayerId/adopt
- `backend/src/main/java/com/nomadgames/identity/AdoptHint.java` - NONE | IMPORT_ELIGIBLE | DROP_REQUIRED
- `backend/src/main/java/com/nomadgames/identity/internal/LoginRateLimiter.java` - per-IP login window
- `backend/src/main/java/com/nomadgames/identity/TokenService.java` - rotate from DB; revokeAll
- `backend/src/main/java/com/nomadgames/identity/TokenPair.java` - guest field on refresh response
- `backend/src/main/java/com/nomadgames/identity/GuestController.java` - login + logout routes
- `backend/src/main/java/com/nomadgames/identity/GuestSessionResponse.java` - optional adoptHint
- `backend/src/main/java/com/nomadgames/identity/SecurityConfig.java` - login permitAll
- `backend/src/main/java/com/nomadgames/identity/internal/RefreshTokenRepository.java` - deleteByPlayerId
- `backend/src/main/resources/application.yaml` - login-limit-per-minute

## Decisions Made

- Logout mints guest on the server to match BindIT `logoutMintsGuest` (`$.guest=true`); client clear+catalog routing remains 07-10
- `TokenPair` exposes `guest` so refresh JSON matches AUTH-03 BindIT assertion
- Import gate is matches==0 and no ledger debit / soft purchase rows (wallet balance alone is not a blocker)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] Server-side guest mint on logout**
- **Found during:** Task 1 (logoutMintsGuest)
- **Issue:** Plan prose said client mints after logout (07-10), but BindIT expects logout HTTP 200 with `guest=true`
- **Fix:** `AuthService.logout` revokes refresh then calls `GuestService.createGuest()`
- **Files modified:** `AuthService.java`, `GuestController.java`
- **Verification:** BindIT#logoutMintsGuest pass
- **Committed in:** `fe06f2b`

**2. [Rule 2 - Missing Critical] TokenPair.guest for refresh claim**
- **Found during:** Task 1 (loginThenRefreshBound)
- **Issue:** Refresh returned only access/refresh tokens; BindIT asserts `$.guest` on rotate response
- **Fix:** Added `guest` boolean to `TokenPair` from `issue(...)`
- **Files modified:** `TokenPair.java`, `TokenService.java`
- **Verification:** BindIT#loginThenRefreshBound pass
- **Committed in:** `fe06f2b`

---

**Total deviations:** 2 auto-fixed (Rule 2)
**Impact on plan:** Required for BindIT contract / AUTH-03–04; no scope creep into Flutter UI.

## Issues Encountered

None blocking. Reactor `./mvnw -pl backend -am -Dtest=...` still runs Wave 0 RED stubs in other packages; targeted BindIT filters are green.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Backend AUTH-03/04 + D-93 ready for Flutter soft-lock / Sign in (07-10) and bind sheet (07-09)
- Client `NomadApi.refresh()` still hardcodes `guest: true` — fix when wiring bound sessions in 07-10
- Ranked / boards / EventSink plans remain independent

## Known Stubs

None in this plan's deliverables — login/logout/adopt paths are wired; no placeholder wallet merge.

## Self-Check: PASSED

- AuthService, TokenService, LoginRequest, AdoptHint, 07-03-SUMMARY.md present
- Commits `fe06f2b` and `4203bf0` present
- TokenService.rotate uses `player.isGuest()`; AuthService enforces adopt + `import_not_eligible`

---
*Phase: 07-bind-ranked-ship*
*Completed: 2026-09-14*
