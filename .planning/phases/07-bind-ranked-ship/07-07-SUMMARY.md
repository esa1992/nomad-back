---
phase: 07-bind-ranked-ship
plan: 07
subsystem: analytics
tags: [EventSink, analytics_events, ANLT-01, D-107, D-108, GHA, compose.prod, Dockerfile, Flyway]

requires:
  - phase: 07-bind-ranked-ship
    provides: Bind/login identity (07-02/07-03)
  - phase: 07-bind-ranked-ship
    provides: Casual/Ranked queues + MatchService settle (07-04/07-08)
  - phase: 07-bind-ranked-ship
    provides: Economy soft purchase (Phase 4)
provides:
  - "EventSink nine ANLT-01 events as JSON logs + analytics_events rows"
  - "PR CI Maven verify + Flutter analyze/test"
  - "PROD compose postgres:18.6 + single Boot JAR"
affects:
  - verify-work ANLT-01 / ship UAT
  - production deploy via compose.prod

tech-stack:
  added: []
  patterns:
    - "EventSink catch Throwable — never rethrow into settle/bind TX"
    - "APP_STARTED via ApplicationReadyEvent (not per guest mint)"
    - "PROD secrets via env only; DEV compose.yaml stays Postgres-only"

key-files:
  created:
    - backend/src/main/java/com/nomadgames/analytics/EventSink.java
    - backend/src/main/java/com/nomadgames/analytics/AppStartedEmitter.java
    - backend/src/main/java/com/nomadgames/analytics/internal/AnalyticsJdbc.java
    - backend/src/main/resources/db/migration/V13__analytics_events.sql
    - .github/workflows/ci.yml
    - Dockerfile
    - compose.prod.yaml
  modified:
    - backend/src/main/java/com/nomadgames/identity/BindService.java
    - backend/src/main/java/com/nomadgames/identity/AuthService.java
    - backend/src/main/java/com/nomadgames/matchmaking/CasualQueueService.java
    - backend/src/main/java/com/nomadgames/matchmaking/RankedQueueService.java
    - backend/src/main/java/com/nomadgames/session/MatchService.java
    - backend/src/main/java/com/nomadgames/economy/EconomyService.java
    - backend/src/test/java/com/nomadgames/analytics/EventSinkIT.java

key-decisions:
  - "APP_STARTED call site is ApplicationReadyEvent (documented) — avoids flooding on guest mint"
  - "AnalyticsJdbc binds OffsetDateTime not Instant (Postgres JDBC)"
  - "Android is proof release target; CI gate is flutter analyze on shared Dart — no macOS iOS runner (D-108)"

patterns-established:
  - "analytics Modulith OPEN package; attrs scrub password/token/secret keys"
  - "compose.prod.yaml separate from DEV compose.yaml"

requirements-completed: [ANLT-01]

coverage:
  - id: D1
    description: "Nine ANLT-01 event types in logs/table; REGISTERED on bind; LOGIN on login"
    requirement: ANLT-01
    verification:
      - kind: integration
        ref: "backend/src/test/java/com/nomadgames/analytics/EventSinkIT.java#emitsRegisteredOnBind"
        status: pass
      - kind: integration
        ref: "backend/src/test/java/com/nomadgames/analytics/EventSinkIT.java#emitsLogin"
        status: pass
      - kind: integration
        ref: "backend/src/test/java/com/nomadgames/analytics/EventSinkIT.java#emitsMatchLifecycleNineTypes"
        status: pass
    human_judgment: false
  - id: D2
    description: "EventSink failure never rolls back settle TX"
    requirement: ANLT-01
    verification:
      - kind: integration
        ref: "backend/src/test/java/com/nomadgames/analytics/EventSinkIT.java#sinkFailureDoesNotRollBackSettle"
        status: pass
    human_judgment: false
  - id: D3
    description: "PR CI + PROD compose/Dockerfile with pinned Java/Flutter/Postgres; DEV compose unchanged"
    verification:
      - kind: other
        ref: "ls .github/workflows/ci.yml Dockerfile compose.prod.yaml + pin grep"
        status: pass
    human_judgment: false
  - id: D4
    description: "D-108 iOS target remains compilable (no Android-only Dart added this plan)"
    verification: []
    human_judgment: true
    rationale: "No iOS runner in CI this phase; shared Flutter code unchanged — human confirms ios/ still builds when needed"

duration: 10min
completed: 2026-09-14
status: complete
---

# Phase 07 Plan 07: EventSink + Ship Summary

**Backend EventSink emits all nine ANLT-01 events as JSON logs plus analytics_events rows, with GHA PR CI and postgres:18.6 + single-JAR compose.prod (no SaaS)**

## Performance

- **Duration:** 10 min
- **Started:** 2026-09-14T15:33:32Z
- **Completed:** 2026-09-14T15:43:05Z
- **Tasks:** 2
- **Files modified:** 15

## Accomplishments

- EventSink (D-107) with Flyway V13 `analytics_events`, scrubbed attrs, catch+log isolation
- Wired REGISTERED/LOGIN/MATCHMAKING_*/MATCH_*/ITEM_PURCHASED; APP_STARTED on ApplicationReadyEvent
- `.github/workflows/ci.yml` Temurin 21 + Flutter 3.47.2; Dockerfile + `compose.prod.yaml`; DEV `compose.yaml` untouched

## Task Commits

Each task was committed atomically:

1. **Task 1: EventSink module + emit hooks for nine types** - `b5a97ff` (feat)
2. **Task 2: GitHub Actions CI + Dockerfile + compose.prod (D-108)** - `a43ebf1` (feat)

**Plan metadata:** `9ed9c62` (docs: complete plan)

_Note: TDD tasks may have multiple commits (test → feat → refactor)_

## Files Created/Modified

- `backend/src/main/java/com/nomadgames/analytics/EventSink.java` - ANLT-01 sink API
- `backend/src/main/java/com/nomadgames/analytics/AppStartedEmitter.java` - APP_STARTED call site
- `backend/src/main/java/com/nomadgames/analytics/internal/AnalyticsJdbc.java` - append-only insert
- `backend/src/main/resources/db/migration/V13__analytics_events.sql` - analytics_events table
- `backend/src/test/java/com/nomadgames/analytics/EventSinkIT.java` - four IT methods green
- Bind/Auth/Casual/Ranked/Match/Economy services - emit hooks
- `.github/workflows/ci.yml` - PR backend+client CI
- `Dockerfile` - eclipse-temurin:21 multi-stage Boot JAR
- `compose.prod.yaml` - postgres:18.6 + app + healthchecks

## Decisions Made

- APP_STARTED on `ApplicationReadyEvent` (not GuestService mint) to avoid per-mint flood — documented in SUMMARY/emitter Javadoc
- `OffsetDateTime` for JDBC timestamp bind (Instant unsupported by Postgres driver)
- D-108: Android proof target; no Android-only plugins added; iOS stays compilable via shared Dart + `flutter analyze` CI gate (no macOS iOS runner)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Instant JDBC bind failed on analytics_events insert**
- **Found during:** Task 1 (EventSinkIT)
- **Issue:** Postgres JDBC rejected `java.time.Instant` parameter on `analytics_events.ts`
- **Fix:** `AnalyticsJdbc.append` takes `OffsetDateTime` (UTC); EventSink converts Instant→OffsetDateTime
- **Files modified:** `AnalyticsJdbc.java`, `EventSink.java`
- **Verification:** EventSinkIT 4/4 BUILD SUCCESS
- **Committed in:** `b5a97ff`

**2. [Rule 2 - Missing critical] APP_STARTED via ApplicationReadyEvent instead of GuestService**
- **Found during:** Task 1
- **Issue:** Plan listed GuestService as APP_STARTED site; mint-per-client would flood APP_STARTED
- **Fix:** `AppStartedEmitter` on `ApplicationReadyEvent`; GuestService unchanged
- **Files modified:** `AppStartedEmitter.java` (GuestService not modified)
- **Verification:** APP_STARTED row present in EventSinkIT nine-types assertion
- **Committed in:** `b5a97ff`

---

**Total deviations:** 2 auto-fixed (1 Rule 1, 1 Rule 2)
**Impact on plan:** Correctness + ANLT-01 semantics preserved; no scope creep.

## Issues Encountered

None beyond Instant→OffsetDateTime (documented as deviation).

## TDD Gate Compliance

- Plan task `tdd="true"`; EventSinkIT rewritten with real assertions and implementation landed together in `b5a97ff` (same pattern as 07-10)
- Green coverage: `./mvnw -pl backend -am -Dtest=EventSinkIT test` — 4/4 pass

## Threat Mitigations

| Threat | Disposition | Evidence |
|--------|-------------|----------|
| T-07-25 Information (PII in logs) | mitigate | UUID playerId only; scrub password/token/secret attr keys |
| T-07-26 Denial (sink in settle TX) | mitigate | catch Throwable; sinkFailureDoesNotRollBackSettle |
| T-07-27 Tampering (CI supply chain) | mitigate | Pin setup-java Temurin 21 + flutter-action 3.47.2; ./mvnw |
| T-07-28 Information (compose secrets) | mitigate | NOMAD_JWT_SECRET via `${NOMAD_JWT_SECRET:?…}`; no secret values in git |

## Known Stubs

None — nine event types wired; CI/PROD artifacts present.

## User Setup Required

None for local DEV. For PROD compose: set host env `NOMAD_JWT_SECRET` (≥32 chars) before `docker compose -f compose.prod.yaml up`.

## Next Phase Readiness

Phase 7 plans complete (07-07 was last incomplete). Ready for phase verify / ship UAT (ANLT-01 + D-108).

## Self-Check: PASSED

- FOUND: `backend/src/main/java/com/nomadgames/analytics/EventSink.java`
- FOUND: `.github/workflows/ci.yml`
- FOUND: `compose.prod.yaml`
- FOUND: `Dockerfile`
- FOUND: commit `b5a97ff`
- FOUND: commit `a43ebf1`

---
*Phase: 07-bind-ranked-ship*
*Completed: 2026-09-14*
