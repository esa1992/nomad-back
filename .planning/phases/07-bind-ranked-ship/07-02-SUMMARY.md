---
phase: 07-bind-ranked-ship
plan: 02
subsystem: auth
tags: [bind, argon2id, credentials, flyway, AUTH-02, jwt]

requires:
  - phase: 07-bind-ranked-ship
    provides: Wave 0 BindIT RED stubs for bindKeepsPlayerIdNoSum / usernameTaken409 / usernameInvalid400
  - phase: 02-guest-catalog-first-alchiki-match
    provides: Guest mint + JWT + GuestSessionResponse + wallets defaults
provides:
  - "POST /v1/identity/bind on same playerId with Argon2id credentials"
  - "Flyway V11 credentials.username + password_hash (case-insensitive unique)"
  - "PasswordConfig DelegatingPasswordEncoder id argon2@SpringSecurity_v5_8"
affects:
  - 07-03 login logout TokenService.rotate
  - 07-09 flutter bind sheet
  - 07-10 soft-lock funnel

tech-stack:
  added:
    - org.bouncycastle:bcprov-jdk18on:1.85
  patterns:
    - "Bind keeps playerId; never economy merge/sum (D-93)"
    - "Argon2id via DelegatingPasswordEncoder idForEncode argon2@SpringSecurity_v5_8 (D-94)"

key-files:
  created:
    - backend/src/main/resources/db/migration/V11__credentials_bind.sql
    - backend/src/main/java/com/nomadgames/identity/PasswordConfig.java
    - backend/src/main/java/com/nomadgames/identity/BindService.java
    - backend/src/main/java/com/nomadgames/identity/BindRequest.java
    - backend/src/main/java/com/nomadgames/identity/internal/CredentialEntity.java
    - backend/src/main/java/com/nomadgames/identity/internal/CredentialRepository.java
  modified:
    - backend/src/main/java/com/nomadgames/identity/GuestController.java
    - backend/src/main/java/com/nomadgames/identity/internal/PlayerEntity.java
    - backend/pom.xml
    - backend/src/test/java/com/nomadgames/identity/BindIT.java

key-decisions:
  - "Argon2id DelegatingPasswordEncoder id argon2@SpringSecurity_v5_8; declare bcprov-jdk18on 1.85 after encode smoke failed without BC"
  - "SecurityConfig unchanged — bind stays under anyRequest().authenticated(); login permitAll deferred to 07-03"
  - "Username 3–20 [A-Za-z0-9_]; uniqueness LOWER(username) index; password min 8; no EventSink REGISTERED yet"

patterns-established:
  - "BindService.bind(playerId, username, password) → CredentialEntity + player.setGuest(false) + tokens.issue(..., false)"
  - "409 username_taken / already_bound; 400 username|password validation via ResponseStatusException"

requirements-completed: [AUTH-02]

coverage:
  - id: D1
    description: "Guest bind keeps same playerId and wallet balances (AUTH-02 / D-93 no-sum)"
    requirement: AUTH-02
    verification:
      - kind: integration
        ref: "backend/.../BindIT.java#bindKeepsPlayerIdNoSum"
        status: pass
    human_judgment: false
  - id: D2
    description: "Duplicate username returns 409"
    requirement: AUTH-02
    verification:
      - kind: integration
        ref: "backend/.../BindIT.java#usernameTaken409"
        status: pass
    human_judgment: false
  - id: D3
    description: "Invalid username charset/length and password < 8 return 400"
    requirement: AUTH-02
    verification:
      - kind: integration
        ref: "backend/.../BindIT.java#usernameInvalid400"
        status: pass
    human_judgment: false

duration: 6min
completed: 2026-09-14
status: complete
---

# Phase 07 Plan 02: Guest Bind + Argon2id Summary

**Guest POST /v1/identity/bind attaches username+Argon2id password to the same playerId without wallet merge.**

## Performance

- **Duration:** 6 min
- **Started:** 2026-09-14T11:29:44Z
- **Completed:** 2026-09-14T11:35:30Z
- **Tasks:** 1
- **Files modified:** 10

## Accomplishments

- Flyway V11 adds `credentials.username` + `password_hash` with case-insensitive unique index
- `PasswordConfig` ships Argon2id `DelegatingPasswordEncoder` (`argon2@SpringSecurity_v5_8`) with BouncyCastle 1.85
- `BindService` + authenticated `POST /v1/identity/bind` keep playerId, set `guest=false`, never touch economy merge
- BindIT `bindKeepsPlayerIdNoSum`, `usernameTaken409`, `usernameInvalid400` green

## Task Commits

Each task was committed atomically:

1. **Task 1 (RED): Expand BindIT invalid cases** - `a61b8ae` (test)
2. **Task 1 (GREEN): Credentials + Argon2 BindService + POST bind** - `93251a0` (feat)

**Plan metadata:** `e8ba19d` (docs: complete plan); `78c203a` / `028792d` (STATE sync)

## Files Created/Modified

- `backend/src/main/resources/db/migration/V11__credentials_bind.sql` - username + password_hash + LOWER unique index
- `backend/src/main/java/com/nomadgames/identity/PasswordConfig.java` - Argon2id DelegatingPasswordEncoder bean
- `backend/src/main/java/com/nomadgames/identity/BindService.java` - transactional same-playerId bind
- `backend/src/main/java/com/nomadgames/identity/BindRequest.java` - username/password body
- `backend/src/main/java/com/nomadgames/identity/internal/CredentialEntity.java` - JPA credentials row
- `backend/src/main/java/com/nomadgames/identity/internal/CredentialRepository.java` - existsByUsernameIgnoreCase
- `backend/src/main/java/com/nomadgames/identity/GuestController.java` - POST /v1/identity/bind
- `backend/src/main/java/com/nomadgames/identity/internal/PlayerEntity.java` - public getId/isGuest/setGuest
- `backend/pom.xml` - bcprov-jdk18on 1.85
- `backend/src/test/java/com/nomadgames/identity/BindIT.java` - charset + short password 400 cases

## Decisions Made

- Declared explicit `bcprov-jdk18on:1.85` after Argon2 encode threw `NoClassDefFoundError` without it (RESEARCH A1)
- Left `SecurityConfig` permit list unchanged — bind is authenticated by default; login `permitAll` is 07-03
- Skipped EventSink `REGISTERED` emit (analytics plan later); bind correctness does not require it

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing critical] Added BouncyCastle for Argon2 runtime**
- **Found during:** Task 1 GREEN
- **Issue:** `Argon2PasswordEncoder.encode` failed with `NoClassDefFoundError: Argon2Parameters$Builder` — Boot BOM does not manage `bcprov-jdk18on`
- **Fix:** Added `org.bouncycastle:bcprov-jdk18on:1.85` to `backend/pom.xml`
- **Files modified:** `backend/pom.xml`
- **Commit:** `93251a0`

## TDD Gate Compliance

- RED: `a61b8ae` test commit (expanded invalid cases; Wave 0 stubs already failed 404)
- GREEN: `93251a0` feat commit after BindIT three methods passed

## Threat Mitigations

| Threat | Disposition | Evidence |
|--------|-------------|----------|
| T-07-04 Spoofing (password storage) | mitigate | Argon2id DelegatingPasswordEncoder; min length 8; username charset/length |
| T-07-05 Elevation (wallet sum) | mitigate | Same playerId only; BindIT no-sum; no economy merge calls |
| T-07-06 Information (logs) | mitigate | BindService does not log password or password_hash |

## Known Stubs

- BindIT login/logout/adopt methods remain RED until 07-03 (`loginThenRefreshBound`, `logoutMintsGuest`, adopt trio)
- Flutter bind sheet deferred to 07-09

## Self-Check: PASSED

- FOUND: `backend/src/main/java/com/nomadgames/identity/BindService.java`
- FOUND: `backend/src/main/java/com/nomadgames/identity/PasswordConfig.java`
- FOUND: `backend/src/main/resources/db/migration/V11__credentials_bind.sql`
- FOUND: commit `a61b8ae`
- FOUND: commit `93251a0`
