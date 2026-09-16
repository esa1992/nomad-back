---
phase: 02-guest-catalog-first-alchiki-match
plan: 02
subsystem: auth
tags: [spring-boot, jwt, flyway, postgres, modulith, testcontainers, identity]

requires:
  - phase: 02-guest-catalog-first-alchiki-match
    provides: Catalog home and localized shell (02-01); identity is independent of catalog UI
provides:
  - POST /v1/identity/guest mint with playerId, accessToken, refreshToken, guest true and no username
  - POST /v1/identity/refresh rotation with SHA-256 refresh at rest
  - Spring Boot 4.1.1 Modulith backend module depending on Spring-free harness
affects:
  - 02-07 client splash mint and GET /v1/catalog
  - 02-04 REST-scored match (Bearer required)
  - Phase 7 bind (empty credentials table reserved)

tech-stack:
  added:
    - Spring Boot 4.1.1
    - Spring Modulith 2.1.1
    - spring-boot-starter-webmvc / security / oauth2-resource-server / data-jpa / flyway / validation / actuator
    - flyway-database-postgresql
    - NimbusJwtEncoder / NimbusJwtDecoder HS256
    - Testcontainers 2.0.5 PostgreSQL 18
    - postgres:18.6 Compose
  patterns:
    - First-party HS256 issuer (no issuer-uri / JWKS)
    - Opaque rotating refresh hashed SHA-256 in Postgres
    - Modulith public API in identity/; internals in identity/internal/
    - In-process per-IP guest mint rate limit

key-files:
  created:
    - pom.xml
    - backend/pom.xml
    - backend/src/main/java/com/nomadgames/NomadGamesApplication.java
    - backend/src/main/java/com/nomadgames/identity/GuestController.java
    - backend/src/main/java/com/nomadgames/identity/GuestService.java
    - backend/src/main/java/com/nomadgames/identity/TokenService.java
    - backend/src/main/java/com/nomadgames/identity/SecurityConfig.java
    - backend/src/main/resources/db/migration/V1__identity.sql
    - backend/src/test/java/com/nomadgames/identity/GuestIdentityIT.java
    - backend/src/test/java/com/nomadgames/ModularityTest.java
    - compose.yaml
  modified:
    - harness/pom.xml

key-decisions:
  - "In-process per-IP guest mint rate limit is 20/min; no Bucket4j or Redis"
  - "Refresh is URL-safe Base64 of 32 random bytes; only SHA-256 is stored"
  - "Optional Docker Compose support uses BOM artifact spring-boot-docker-compose"
  - "Harness surefire.failIfNoSpecifiedTests=false so -pl backend -am -Dtest= reaches backend"

patterns-established:
  - "Pattern: NimbusJwtEncoder.withSecretKey().algorithm(HS256) plus matching decoder macAlgorithm"
  - "Pattern: Flyway owns DDL; spring.jpa.hibernate.ddl-auto=validate"
  - "Pattern: PermitAll only POST /v1/identity/guest, POST /v1/identity/refresh, /actuator/health"

requirements-completed: [AUTH-01]

coverage:
  - id: D1
    description: POST /v1/identity/guest returns 201 with playerId UUID, accessToken, refreshToken, guest true and no username field
    requirement: AUTH-01
    verification:
      - kind: integration
        ref: "backend/src/test/java/com/nomadgames/identity/GuestIdentityIT.java#guestMintReturnsTokensWithoutUsername"
        status: pass
    human_judgment: false
  - id: D2
    description: POST /v1/identity/refresh rotates the refresh token and rejects replay of the old token
    requirement: AUTH-01
    verification:
      - kind: integration
        ref: "backend/src/test/java/com/nomadgames/identity/GuestIdentityIT.java#refreshRotatesAndRejectsReplay"
        status: pass
    human_judgment: false
  - id: D3
    description: Forged extra JSON keys on guest POST are ignored
    requirement: AUTH-01
    verification:
      - kind: integration
        ref: "backend/src/test/java/com/nomadgames/identity/GuestIdentityIT.java#guestMintIgnoresForgedExtraKeys"
        status: pass
    human_judgment: false
  - id: D4
    description: GET /actuator/health is reachable without a Bearer token
    verification:
      - kind: integration
        ref: "backend/src/test/java/com/nomadgames/identity/GuestIdentityIT.java#actuatorHealthIsReachableWithoutBearer"
        status: pass
    human_judgment: false
  - id: D5
    description: Spring Modulith ApplicationModules.verify() passes; identity does not depend on catalog or games.alchiki
    verification:
      - kind: unit
        ref: "backend/src/test/java/com/nomadgames/ModularityTest.java#modulesShouldVerify"
        status: pass
    human_judgment: false

duration: 12min
completed: 2026-09-06
status: complete
---

# Phase 2 Plan 02: Guest Identity Backend Summary

**First-party HS256 access JWT (15m) plus opaque rotating refresh hashed SHA-256 in PostgreSQL 18, minted by POST /v1/identity/guest with no username field**

## Performance

- **Duration:** 12 min
- **Started:** 2026-09-06T14:19:17Z
- **Completed:** 2026-09-06T14:31:41Z
- **Tasks:** 2
- **Files modified:** 26

## Accomplishments

- Repo-root Maven aggregator plus `backend/` Spring Boot 4.1.1 Modulith module depending on Spring-free `harness/`
- Guest mint returns `playerId`, `accessToken`, `refreshToken`, `guest: true` and never a username
- Refresh rotates on every use; replay of the previous refresh is 401
- Flyway `V1__identity.sql` creates `players`, `refresh_tokens`, and empty `credentials`; JPA `ddl-auto=validate`
- In-process per-IP rate limit on guest mint; PermitAll only guest, refresh, and `/actuator/health`

## Task Commits

Each task was committed atomically:

1. **Task 1: Write failing guest identity tests** - `b91be41` (test)
2. **Task 2: Guest mint and refresh on the server** - `9b95e57` (feat)

**Plan metadata:** pending docs(02-02) complete guest identity plan

## Files Created/Modified

- `pom.xml` - Aggregator (harness + backend)
- `backend/pom.xml` - Boot 4.1.1 parent, BOM-managed starters, Modulith 2.1.1, Testcontainers PostgreSQL
- `mvnw` / `mvnw.cmd` / `.mvn/wrapper/maven-wrapper.properties` - Copied from harness
- `backend/src/test/java/com/nomadgames/identity/GuestIdentityIT.java` - Mint, rotate, ignore-extra-keys, health
- `backend/src/test/java/com/nomadgames/ModularityTest.java` - `ApplicationModules.verify()`
- `backend/src/main/java/com/nomadgames/NomadGamesApplication.java` - Spring Boot entry
- `backend/src/main/java/com/nomadgames/identity/GuestController.java` - POST guest + refresh
- `backend/src/main/java/com/nomadgames/identity/GuestService.java` - Inserts `players(guest=true)`
- `backend/src/main/java/com/nomadgames/identity/TokenService.java` - Nimbus HS256 + hashed refresh
- `backend/src/main/java/com/nomadgames/identity/SecurityConfig.java` - PermitAll + resource-server decoder
- `backend/src/main/resources/db/migration/V1__identity.sql` - Identity schema
- `backend/src/main/resources/application.yaml` / `application-dev.yaml` - Datasource via env; local JWT secret
- `compose.yaml` - `postgres:18.6` db/user/password `nomad`
- `harness/pom.xml` - `surefire.failIfNoSpecifiedTests=false` so `-am -Dtest=` does not fail the harness

## Decisions Made

- Guest mint rate limit is in-process, 20 requests per IP per minute (T-02-06); no extra rate-limit library
- Refresh token on the wire is URL-safe Base64 of 32 random bytes; only SHA-256 is persisted
- Optional Compose support uses official BOM artifact `spring-boot-docker-compose` (Boot 4.1 has no `starter-docker-compose`)
- Internal JPA types are `public` for Java visibility from `identity/`; Modulith still treats `internal/` as hidden from other modules

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Harness Surefire fail-if-no-tests**
- **Found during:** Task 1 verify / Task 2 GREEN
- **Issue:** `mvnw -pl backend -am test -Dtest=GuestIdentityIT,ModularityTest` failed on harness with "No tests matching pattern"
- **Fix:** Set `surefire.failIfNoSpecifiedTests=false` on the Spring-free harness POM
- **Files modified:** `harness/pom.xml`
- **Verification:** Same Maven command exits 0 after GREEN
- **Committed in:** `9b95e57`

**2. [Rule 1 - Bug] GuestMintRateLimiter constructor selection**
- **Found during:** Task 2
- **Issue:** Two constructors made Spring Boot 4 fail with "No default constructor found"
- **Fix:** Single `@Value` constructor; `Clock.systemUTC()` inline
- **Files modified:** `backend/src/main/java/com/nomadgames/identity/internal/GuestMintRateLimiter.java`
- **Verification:** GuestIdentityIT 4 tests pass
- **Committed in:** `9b95e57`

---

**Total deviations:** 2 auto-fixed (1 blocking, 1 bug)
**Impact on plan:** Required for the plan verify command and context startup. No scope creep. Catalog/match/bind not added.

## Issues Encountered

- Docker Desktop was installed but the engine pipe was down. Started `Docker Desktop.exe` and waited until `docker version` showed Engine 29.7.2, then Testcontainers `postgres:18` (PG 18.6) started cleanly.

## Authentication Gates

None

## Known Stubs

- `credentials` table is empty by design so Phase 7 can attach a password without rewriting PKs. No bind route in this plan.
- Client splash mint and GET `/v1/catalog` remain 02-07.

These stubs do not block AUTH-01 server half: guest mint and refresh work without a username field.

## User Setup Required

None - no external service configuration required. Local DEV uses Compose `postgres:18.6` and `application-dev.yaml` JWT secret.

## Next Phase Readiness

Ready for remaining Wave 2/3 plans. Catalog GET and client mint are 02-07. Do not add match, shop, Redis, or bind here.

## TDD Gate Compliance

- RED commit `b91be41` `test(02-02): add failing test for guest identity` — Maven failed (missing `NomadGamesApplication` / no matching harness tests)
- GREEN commit `9b95e57` `feat(02-02): implement guest mint and refresh` — GuestIdentityIT + ModularityTest passed against Testcontainers PG 18

## Self-Check: PASSED

- FOUND: NomadGamesApplication.java, V1__identity.sql, GuestController.java, GuestIdentityIT.java, ModularityTest.java, 02-02-SUMMARY.md
- FOUND: b91be41 test(02-02), 9b95e57 feat(02-02)

---
*Phase: 02-guest-catalog-first-alchiki-match*
*Completed: 2026-09-06*
