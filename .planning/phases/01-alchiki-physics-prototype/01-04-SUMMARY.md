---
phase: 01-alchiki-physics-prototype
plan: 04
subsystem: harness
tags: [dyn4j, maven, junit, java21, throw-resolved, keyframes, proto-02]

requires:
  - phase: 01-alchiki-physics-prototype
    provides: RED BurstSimTest, Maven Wrapper, seed-1 hex lock from 01-03
provides:
  - Green BurstSimTest with dyn4j 6 burst-to-rest and pocketedCount from rest poses
  - Spring-free HarnessMain CLI writing ThrowResolved JSON
  - golden_input.json fixture and CLI-baked golden_throw.json
affects:
  - 01-05 Replay Throw / scored HUD interpolating JVM keyframes

tech-stack:
  added:
    - org.codehaus.mojo:exec-maven-plugin:3.5.1
  patterns:
    - Authority pocketedCount written only by Dyn4jBurstSim from rest poses
    - Hand-written JSON (no Jackson/Gson); CLI files only, no Spring
    - Seed-1 coordinates pasted in Java to match 01-03

key-files:
  created:
    - harness/src/main/java/com/nomadgames/alchiki/proto/TableConstants.java
    - harness/src/main/java/com/nomadgames/alchiki/proto/Keyframe.java
    - harness/src/main/java/com/nomadgames/alchiki/proto/ThrowResolved.java
    - harness/src/main/java/com/nomadgames/alchiki/proto/JsonSupport.java
    - harness/src/main/java/com/nomadgames/alchiki/proto/HarnessMain.java
    - client/assets/replays/golden_input.json
    - client/assets/replays/golden_throw.json
  modified:
    - harness/src/main/java/com/nomadgames/alchiki/proto/ThrowInput.java
    - harness/src/main/java/com/nomadgames/alchiki/proto/Dyn4jBurstSim.java
    - harness/pom.xml
    - client/pubspec.yaml

key-decisions:
  - "TableConstants copied from RESEARCH Shared ThrowInput table only; hold clamp 150-1100 stays on ThrowInput"
  - "Seed-1 hex pasted in Dyn4jBurstSim to match 01-03; no client layout helper"
  - "pocketedCount is raw pocketed bone count; displayedScore is 0 when sakaOut"
  - "Fixture aim 60deg from (0,-1.15) times out at 1.2s with pocketedCount 0 — still a valid authority dump"

patterns-established:
  - "Pattern: mvnw exec:java ThrowInput path → ThrowResolved path"
  - "Pattern: golden_throw.json is CLI output, never hand-edited poses"

requirements-completed: [PROTO-02]

coverage:
  - id: D1
    description: BurstSimTest green — fixture ThrowInput burst-simulates to a closed keyframe buffer with pocketedCount from dyn4j rest poses
    requirement: PROTO-02
    verification:
      - kind: unit
        ref: "harness/src/test/java/com/nomadgames/alchiki/proto/BurstSimTest.java#fixtureThrowProducesKeyframesAndScore"
        status: pass
      - kind: unit
        ref: "harness/src/test/java/com/nomadgames/alchiki/proto/BurstSimTest.java#timeoutStillScores"
        status: pass
      - kind: unit
        ref: "harness/src/test/java/com/nomadgames/alchiki/proto/BurstSimTest.java#outputHasNoClientPosesField"
        status: pass
      - kind: other
        ref: "harness/mvnw.cmd -q test -Dtest=BurstSimTest"
        status: pass
    human_judgment: false
  - id: D2
    description: HarnessMain CLI writes golden_throw.json from golden_input.json with keyframes and pocketedCount
    requirement: PROTO-02
    verification:
      - kind: other
        ref: "harness/mvnw.cmd -q exec:java -Dexec.args=../client/assets/replays/golden_input.json ../client/assets/replays/golden_throw.json"
        status: pass
    human_judgment: false
  - id: D3
    description: Spring-free harness — no Spring parent, no HTTP/WebSocket; client still has no score-submit API
    requirement: PROTO-02
    verification:
      - kind: other
        ref: "Select-String harness/pom.xml spring-boot-starter-parent (no match); HarnessMain has no bind port"
        status: pass
    human_judgment: false

duration: 28min
completed: 2026-09-06
status: complete
---

# Phase 1 Plan 04: dyn4j Burst Sim + Golden JSON Summary

**Spring-free dyn4j 6 burst-to-rest CLI writes closed keyframes and pocketedCount from rest poses only**

## Performance

- **Duration:** 28 min
- **Started:** 2026-09-06T02:20:00Z
- **Completed:** 2026-09-06T02:48:00Z
- **Tasks:** 2
- **Files modified:** 11

## Accomplishments

- BurstSimTest is green: fixture `ThrowInput` burst-simulates in a zero-g dyn4j 6 world (dt 1/60, Y-up meters) until sleep or 1.2s
- `pocketedCount` / `sakaOut` / `pocketedIds` come from dyn4j rest poses; input score-like keys are ignored (D-10)
- `HarnessMain` + `exec-maven-plugin` write `client/assets/replays/golden_throw.json` from `golden_input.json` (CLI-baked, not hand-edited poses)
- Client still has no API to submit a score; `golden_throw.json` is registered for 01-05 Replay

## Task Commits

Each task was committed atomically:

1. **Task 1: Green BurstSimTest with dyn4j burst-to-rest** - `589852a` (feat)
2. **Task 2: HarnessMain CLI writes golden_throw.json** - `7db2198` (feat)

**Plan metadata:** pending this docs commit

_Note: RED BurstSimTest lived in 01-06 (`4f225d2`). This plan is the GREEN path._

## Files Created/Modified

- `harness/src/main/java/com/nomadgames/alchiki/proto/TableConstants.java` - RESEARCH Shared ThrowInput table (circleRadiusM 1.40, masses, damping, impulse range)
- `harness/src/main/java/com/nomadgames/alchiki/proto/ThrowInput.java` - parse clamp 150–1100, reject non-finite aim, schemaVersion 1, yUp true
- `harness/src/main/java/com/nomadgames/alchiki/proto/Keyframe.java` - tMs + bodies (id, x, y, angle); cap 8 bodies
- `harness/src/main/java/com/nomadgames/alchiki/proto/ThrowResolved.java` - authority JSON writer; pocketedCount only here
- `harness/src/main/java/com/nomadgames/alchiki/proto/JsonSupport.java` - finite-number checks and hand-written escape
- `harness/src/main/java/com/nomadgames/alchiki/proto/Dyn4jBurstSim.java` - setGravity(0,0), setStepFrequency(1/60), seed-1 hex including 0.19053
- `harness/src/main/java/com/nomadgames/alchiki/proto/HarnessMain.java` - two-path CLI, exit non-zero on bad schema/aim/I/O
- `harness/pom.xml` - exec-maven-plugin 3.5.1; still no Spring parent
- `client/assets/replays/golden_input.json` - fixture aimAngleRad 1.0471975512, tableId alchiki-proto-v1
- `client/assets/replays/golden_throw.json` - CLI dump; keyframes.length 25; pocketedCount 0; settleReason timeout
- `client/pubspec.yaml` - assets/replays/golden_throw.json

## Decisions Made

- Copied TableConstants from RESEARCH Shared ThrowInput table only; did not read `table_constants.dart`
- Pasted 01-03 seed-1 coordinates in Java: saka (0.0, -1.15); b1–b6 at r=0.22 with 0.19053
- `Dyn4jBurstSim.Result` wraps `ThrowResolved` so BurstSimTest accessors stay stable
- Fixture 60° throw from (0.0, -1.15) misses the hex (saka ends ~0.60, -0.11); authority score is 0 and settleReason is timeout — valid PROTO-02 dump for 01-05 Replay

## Deviations from Plan

None - plan executed exactly as written.

`JsonSupport.java` is a small hand-written JSON helper implied by “no Jackson/Gson”; not a scope change.

---

**Total deviations:** 0 auto-fixed
**Impact on plan:** None

## Issues Encountered

Fixture impulse at aim 1.047 rad does not collide with the locked hex, so golden `pocketedCount` is 0 and bodies stay awake through the 1.2s cap. Tests require `keyframes.size() >= 3` and `pocketedCount >= 0`, which pass. 01-05 Replay should treat this golden as a motion track, not a scoring demo of knocked bones.

## Authentication Gates

None.

## Known Stubs

None — `Dyn4jBurstSim.simulate` steps dyn4j and writes real keyframes; `ThrowInput.parse` clamps and rejects.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Ready for 01-05 (Replay interpolates `golden_throw.json`; HUD `scored` reads `ThrowResolved.pocketedCount` only). Do not invent a client hex layout or hand-edit golden poses.

## TDD Gate Compliance

- RED: `4f225d2` `test(01-06): add failing BurstSimTest for dyn4j burst` (prior plan)
- GREEN: `589852a` `feat(01-04): implement dyn4j burst-to-rest`

---
*Phase: 01-alchiki-physics-prototype*
*Completed: 2026-09-06*

## Self-Check: PASSED

- FOUND: `harness/src/main/java/com/nomadgames/alchiki/proto/TableConstants.java`
- FOUND: `harness/src/main/java/com/nomadgames/alchiki/proto/Dyn4jBurstSim.java`
- FOUND: `harness/src/main/java/com/nomadgames/alchiki/proto/HarnessMain.java`
- FOUND: `client/assets/replays/golden_input.json`
- FOUND: `client/assets/replays/golden_throw.json`
- FOUND: commit `589852a`
- FOUND: commit `7db2198`
- VERIFY: `mvnw.cmd -q test -Dtest=BurstSimTest` exits 0
- VERIFY: `mvnw.cmd -q exec:java` wrote golden_throw.json with keyframes + pocketedCount

