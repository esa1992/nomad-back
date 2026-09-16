---
phase: 01-alchiki-physics-prototype
plan: 06
subsystem: harness
tags: [maven, dyn4j, junit, java21, throw-input, burst-sim, red-test]

requires:
  - phase: 01-alchiki-physics-prototype
    provides: scripts/dev-env.ps1 Corretto 21 JAVA_HOME and PROTO-01 ThrowInput keys
provides:
  - Spring-free Maven Wrapper 3.9.11 harness with dyn4j 6.0.0 and JUnit Jupiter 6.1.3
  - ThrowInput.java stub matching client schemaVersion/yUp/aimAngleRad/holdMs/seed/tableId
  - Compiling RED BurstSimTest that fails on empty Dyn4jBurstSim.simulate
affects:
  - 01-04 green dyn4j burst, ThrowResolved, HarnessMain, golden JSON

tech-stack:
  added:
    - org.dyn4j:dyn4j:6.0.0
    - org.junit.jupiter:junit-jupiter:6.1.3
    - Maven Wrapper 3.9.11 (wrapper 3.3.2 only-script)
  patterns:
    - Spring-free Maven module (no parent POM, no Jackson/Gson)
    - Hand-written JSON key extract for ThrowInput
    - RED BurstSimTest before 01-04 green burst

key-files:
  created:
    - harness/pom.xml
    - harness/mvnw
    - harness/mvnw.cmd
    - harness/.mvn/wrapper/maven-wrapper.properties
    - harness/.gitignore
    - harness/src/main/java/com/nomadgames/alchiki/proto/ThrowInput.java
    - harness/src/main/java/com/nomadgames/alchiki/proto/Dyn4jBurstSim.java
    - harness/src/test/java/com/nomadgames/alchiki/proto/BurstSimTest.java
  modified: []

key-decisions:
  - "Maven Wrapper 3.9.11 via maven-wrapper-plugin 3.3.2 only-script; no global mvn"
  - "Dyn4jBurstSim.Result stays nested so TableConstants/ThrowResolved remain 01-04 files"
  - "ThrowInput.parse extracts shared keys only; no clamp or non-finite rejection yet"

patterns-established:
  - "Pattern: harness/ is a plain Maven jar with maven.compiler.release 21"
  - "BurstSimTest RED fails on AssertionFailedError for keyframes.size() >= 3"

requirements-completed: [PROTO-01, PROTO-02]

coverage:
  - id: D1
    description: Spring-free Maven harness with Wrapper 3.9.11, dyn4j 6.0.0, JUnit Jupiter 6.1.3, Java 21
    requirement: PROTO-02
    verification:
      - kind: other
        ref: "Select-String harness/pom.xml org.dyn4j 6.0.0 junit-jupiter maven.compiler.release; Test-Path harness/mvnw.cmd"
        status: pass
      - kind: other
        ref: "harness/mvnw.cmd -q compile"
        status: pass
    human_judgment: false
  - id: D2
    description: ThrowInput.java keys match client contract (schemaVersion, yUp, aimAngleRad, holdMs, seed, tableId)
    requirement: PROTO-01
    verification:
      - kind: unit
        ref: "harness/src/test/java/com/nomadgames/alchiki/proto/BurstSimTest.java#fixtureThrowProducesKeyframesAndScore parses 1.0471975512 / holdMs 640"
        status: pass
    human_judgment: false
  - id: D3
    description: BurstSimTest compiles and fails RED on unimplemented dyn4j burst / pocketedCount
    requirement: PROTO-02
    verification:
      - kind: unit
        ref: "harness/mvnw.cmd -q test -Dtest=BurstSimTest (AssertionFailedError expected closed keyframe buffer)"
        status: pass
    human_judgment: false

duration: 5min
completed: 2026-09-06
status: complete
---

# Phase 1 Plan 06: Maven Wrapper + RED BurstSimTest Summary

**Spring-free Maven Wrapper 3.9.11 harness with dyn4j 6.0.0 stubs and a compiling BurstSimTest that fails on empty keyframes**

## Performance

- **Duration:** 5 min
- **Started:** 2026-09-06T01:54:13Z
- **Completed:** 2026-09-06T01:59:00Z
- **Tasks:** 2
- **Files modified:** 8

## Accomplishments

- Created `harness/` as a Spring-free Java 21 Maven module (D-02, D-11) with dyn4j 6.0.0 and JUnit Jupiter 6.1.3
- Generated Maven Wrapper 3.9.11 so `harness/mvnw.cmd` builds without a global `mvn`
- Added `ThrowInput.java` with the PROTO-01 client keys and a parse stub that ignores score-like fields
- Added empty `Dyn4jBurstSim.simulate` plus a RED `BurstSimTest` that fails on JUnit assertions, not compile errors

## Task Commits

Each task was committed atomically:

1. **Task 1: Spring-free Maven Wrapper and Java stubs** - `9a72146` (feat)
2. **Task 2: Failing BurstSimTest (RED)** - `4f225d2` (test)

**Plan metadata:** pending this docs commit

_Note: BurstSimTest is intentionally RED. Green burst-sim is 01-04._

## Files Created/Modified

- `harness/pom.xml` - Spring-free module; dyn4j 6.0.0; junit-jupiter 6.1.3; maven.compiler.release 21
- `harness/mvnw` / `harness/mvnw.cmd` - Maven Wrapper 3.3.2 only-script
- `harness/.mvn/wrapper/maven-wrapper.properties` - distributionUrl Apache Maven 3.9.11
- `harness/.gitignore` - ignores `target/`
- `harness/src/main/java/com/nomadgames/alchiki/proto/ThrowInput.java` - shared keys + hand-written JSON parse
- `harness/src/main/java/com/nomadgames/alchiki/proto/Dyn4jBurstSim.java` - empty simulate stub
- `harness/src/test/java/com/nomadgames/alchiki/proto/BurstSimTest.java` - fixture, timeoutStillScores, outputHasNoClientPosesField

## Decisions Made

- Generated Wrapper from a temporary Apache Maven 3.9.11 zip + `maven-wrapper-plugin:3.3.2:wrapper` because global `mvn` is missing
- Nested `Dyn4jBurstSim.Result` instead of adding `ThrowResolved.java` / `TableConstants.java` (those belong to 01-04)
- Added maven-surefire-plugin 3.5.3 so JUnit Jupiter 6 actually executes under the wrapper
- `ThrowInput.parse` does not clamp holdMs or reject non-finite aim yet (01-04)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] ThrowInput key lookup skipped values**
- **Found during:** Task 2 (RED BurstSimTest)
- **Issue:** `findKey` returned the index after `:`, then `readRawValue` looked for a second colon and parsed `schemaVersion` as 0
- **Fix:** `findValueStart` returns the first non-whitespace character of the value
- **Files modified:** `harness/src/main/java/com/nomadgames/alchiki/proto/ThrowInput.java`
- **Verification:** fixture test now fails on `keyframes.size() >= 3`, not `schemaVersion`
- **Committed in:** `4f225d2` (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (1 bug)
**Impact on plan:** Required so RED asserts unimplemented burst, not a broken fixture parse. No scope creep.

## Issues Encountered

None beyond the parser index bug above.

## Authentication Gates

None.

## Known Stubs

Intentional for this RED plan; 01-04 owns the green path:

- `Dyn4jBurstSim.simulate` returns zero keyframes and `pocketedCount` 0 — plan forbids implementing burst-sim here
- `ThrowInput.parse` does not clamp holdMs or reject NaN/Inf aim — 01-04 matches the Dart client

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Ready for 01-04 (green `Dyn4jBurstSim`, `ThrowResolved`, `HarnessMain`, golden JSON). 01-03 can proceed in parallel (client bones/Reset). Do not treat BurstSimTest green as this plan's job.

---
*Phase: 01-alchiki-physics-prototype*
*Completed: 2026-09-06*

## Self-Check: PASSED

- FOUND: `harness/pom.xml`
- FOUND: `harness/mvnw.cmd`
- FOUND: `harness/src/main/java/com/nomadgames/alchiki/proto/ThrowInput.java`
- FOUND: `harness/src/main/java/com/nomadgames/alchiki/proto/Dyn4jBurstSim.java`
- FOUND: `harness/src/test/java/com/nomadgames/alchiki/proto/BurstSimTest.java`
- FOUND: commit `9a72146`
- FOUND: commit `4f225d2`
- VERIFY: `mvnw.cmd -q test -Dtest=BurstSimTest` exits non-zero with `AssertionFailedError` / `expected:`
