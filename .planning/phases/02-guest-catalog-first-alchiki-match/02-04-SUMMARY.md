---
phase: 02-guest-catalog-first-alchiki-match
plan: 04
subsystem: session
tags: [dyn4j, rest, match, throw-authority, spring-boot, testcontainers]

requires:
  - phase: 02-guest-catalog-first-alchiki-match
    provides: Guest mint and Bearer JWT from 02-02; Spring-free harness Dyn4jBurstSim from Phase 1
provides:
  - POST /v1/matches BOT start with D-19 bone counts 5/6/7
  - POST /v1/matches/{id}/throws scoring only from Dyn4jBurstSim.simulate(input, bones_left)
  - spawnForBoneCount initial cluster and spawnRemaining leftover bones plus saka
affects:
  - 02-05 match clocks and first-to-5
  - 02-06 scripted bot turn
  - 02-08 client table lift and keyframe replay

tech-stack:
  added: []
  patterns:
    - Match path simulate(ThrowInput, remainingBoneIds) calls spawnRemaining, never spawnForBoneCount
    - ThrowInput.parse ignores score-like keys; displayedScore is server-authored
    - games.alchiki wraps harness types; session SPI stays JSON + session DTOs

key-files:
  created:
    - backend/src/main/resources/db/migration/V2__matches.sql
    - backend/src/main/java/com/nomadgames/session/GameEngine.java
    - backend/src/main/java/com/nomadgames/session/MatchService.java
    - backend/src/main/java/com/nomadgames/session/MatchController.java
    - backend/src/main/java/com/nomadgames/games/alchiki/AlchikiEngine.java
    - backend/src/test/java/com/nomadgames/session/ThrowAuthorityIT.java
  modified:
    - harness/src/main/java/com/nomadgames/alchiki/proto/Dyn4jBurstSim.java
    - harness/src/test/java/com/nomadgames/alchiki/proto/BurstSimTest.java

key-decisions:
  - "EASY target ids are b1-b5 (drop b6) so D-19 bone count is 5; A1 drop b5+b6 would be 4"
  - "Match simulate(input, remainingBoneIds) scales hold impulse 3x; proto simulate(input) stays 1x"
  - "On sleep, the rest keyframe replaces the last frame when KEYFRAME_CAP is full (WR-02)"
  - "GameEngine.applyThrow takes raw JSON; session does not import harness proto types"

patterns-established:
  - "Pattern: AlchikiEngine maps ThrowResolved to PlayerThrowView including displayedScore"
  - "Pattern: OPEN ApplicationModule on com.nomadgames.alchiki so Modulith accepts harness proto"
  - "Pattern: applyThrow keeps turn PLAYER this plan; ScriptedBot is 02-06"

requirements-completed: [ALCH-02, ALCH-05, SESS-01]

coverage:
  - id: D1
    description: Forged client score-like keys on POST /throws are ignored; displayedScore comes from dyn4j
    requirement: SESS-01
    verification:
      - kind: integration
        ref: "backend/src/test/java/com/nomadgames/session/ThrowAuthorityIT.java#forgedClientScoreIsIgnoredOnThrow"
        status: pass
    human_judgment: false
  - id: D2
    description: EASY/NORMAL/HARD matches start with 5/6/7 target boneIds
    requirement: ALCH-02
    verification:
      - kind: integration
        ref: "backend/src/test/java/com/nomadgames/session/ThrowAuthorityIT.java#boneCountFollowsDifficulty"
        status: pass
    human_judgment: false
  - id: D3
    description: Throw1 pockets an id; throw2 keyframes, pocketedIds, and bonesLeft omit that id
    requirement: ALCH-02
    verification:
      - kind: integration
        ref: "backend/src/test/java/com/nomadgames/session/ThrowAuthorityIT.java#secondThrowOmitsPocketedIdFromScoreAndKeyframes"
        status: pass
      - kind: unit
        ref: "harness/src/test/java/com/nomadgames/alchiki/proto/BurstSimTest.java#simulateRemainingOmitsDroppedIdsFromKeyframesAndPockets"
        status: pass
    human_judgment: false
  - id: D4
    description: sakaOut with pocketedCount 2 yields displayedScore 0; sleep path writes a rest keyframe
    requirement: ALCH-05
    verification:
      - kind: unit
        ref: "harness/src/test/java/com/nomadgames/alchiki/proto/BurstSimTest.java#constructedSakaOutWithPocketsHasDisplayedScoreZero"
        status: pass
      - kind: unit
        ref: "harness/src/test/java/com/nomadgames/alchiki/proto/BurstSimTest.java#sleepPathWritesFinalKeyframe"
        status: pass
    human_judgment: false

duration: 25min
completed: 2026-09-06
status: complete
---

# Phase 2 Plan 04: REST Throw Authority Summary

**REST match start and throw where displayedScore is authored only from dyn4j rest poses, leftover bones respawn via spawnRemaining(bones_left), and forged client scores are ignored**

## Performance

- **Duration:** 25 min
- **Started:** 2026-09-06T15:08:32Z
- **Completed:** 2026-09-06T15:33:26Z
- **Tasks:** 2
- **Files modified:** 19

## Accomplishments

- Guest Bearer can POST `/v1/matches` (BOT EASY/NORMAL/HARD) and POST `/v1/matches/{id}/throws` with ThrowInput only
- `Dyn4jBurstSim.spawnForBoneCount` builds the A1 initial cluster (5/6/7); throw 2+ uses `simulate(input, remainingBoneIds)` / `spawnRemaining`
- Pocketed target ids leave `bones_left` and cannot score again; saka-out adds 0 via `displayedScore()`
- WR-02 sleep path writes (or replaces) a rest keyframe; WR-03 asserts `resolved().displayedScore()`

## Task Commits

Each task was committed atomically:

1. **Task 1: Write failing throw-authority tests** - `31fd1d2` (test)
2. **Task 2: Harness spawn variants and REST throw authority** - `50b8ec8` (feat)

**Plan metadata:** pending docs(02-04) complete REST throw authority plan

## Files Created/Modified

- `harness/src/main/java/com/nomadgames/alchiki/proto/Dyn4jBurstSim.java` - spawnForBoneCount, spawnRemaining, match simulate overload, sleep rest keyframe
- `harness/src/test/java/com/nomadgames/alchiki/proto/BurstSimTest.java` - 5/7 radii, leftover spawn, sleep keyframe, displayedScore 0, canned pocket
- `backend/src/main/resources/db/migration/V2__matches.sql` - matches row with bones_left jsonb and clocks
- `backend/src/main/java/com/nomadgames/session/MatchController.java` - POST /v1/matches and /throws
- `backend/src/main/java/com/nomadgames/session/MatchService.java` - ownership/turn 409, persist score and bones_left
- `backend/src/main/java/com/nomadgames/games/alchiki/AlchikiEngine.java` - harness simulate wrapper
- `backend/src/test/java/com/nomadgames/session/ThrowAuthorityIT.java` - forged score, bone counts, two-throw leftover

## Decisions Made

- EASY lists b1–b5 (drop only b6) so D-19 is 5 bones; dropping b5+b6 would be 4 and fail ThrowAuthorityIT
- Match leftover simulate scales hold impulse 3× because proto impulse cannot pocket a 1.40 m circle from the seed-1 hex; `simulate(ThrowInput)` stays 1× for harness CLI
- Sleep rest keyframe replaces the last captured frame when the 40-frame cap is already full
- `GameEngine.applyThrow` takes raw JSON so `session` does not import harness proto types; `com.nomadgames.alchiki` is an OPEN Modulith module
- After a player throw, turn stays PLAYER — ScriptedBot is 02-06

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] Match-path impulse scale**
- **Found during:** Task 2 GREEN — canned throw never pocketed
- **Issue:** Max proto impulse moves a seed-1 bone ~0.74 m; pocketing needs >1.45 m
- **Fix:** `simulate(input, remainingBoneIds)` multiplies hold impulse by 3.0; proto `simulate(input)` unchanged
- **Files modified:** `Dyn4jBurstSim.java`
- **Verification:** BurstSimTest.cannedThrowPocketsAtLeastOneEasyBone and ThrowAuthorityIT two-throw pass
- **Committed in:** `50b8ec8`

**2. [Rule 1 - Bug] EASY bone count vs A1 drop-two**
- **Found during:** Task 2 GREEN
- **Issue:** Dropping b5+b6 yields 4 targets; D-19 and ThrowAuthorityIT require 5
- **Fix:** EASY keeps b1–b5 (drops b6 only); HARD still adds center b7
- **Files modified:** `Dyn4jBurstSim.java`, `BurstSimTest.java`
- **Verification:** ThrowAuthorityIT.boneCountFollowsDifficulty
- **Committed in:** `50b8ec8`

**3. [Rule 1 - Bug] Sleep keyframe after KEYFRAME_CAP**
- **Found during:** Task 2 GREEN
- **Issue:** A 5 s settle fills 40 frames before sleep, so WR-02 could not append a rest frame
- **Fix:** On sleep, replace the last keyframe when the cap is full
- **Files modified:** `Dyn4jBurstSim.java`
- **Verification:** BurstSimTest.sleepPathWritesFinalKeyframe
- **Committed in:** `50b8ec8`

**4. [Rule 3 - Blocking] Modulith harness package**
- **Found during:** Task 2 GREEN
- **Issue:** `com.nomadgames.alchiki.proto` on the classpath looked like a closed `alchiki` module
- **Fix:** OPEN `@ApplicationModule` on `com.nomadgames.alchiki`; session SPI no longer references proto types
- **Files modified:** `package-info.java`, `GameEngine.java`, `AlchikiEngine.java`
- **Verification:** ModularityTest.modulesShouldVerify
- **Committed in:** `50b8ec8`

---

**Total deviations:** 4 auto-fixed (1 missing critical, 2 bugs, 1 blocking)
**Impact on plan:** Required for ALCH-02 pocketing and Modulith verify. No client table lift, catalog GET, or ScriptedBot.

## Issues Encountered

- Seed-1 + TableConstants cannot pocket on the proto impulse path; match leftover path is playable only with the 3× scale. 02-08 must use the same match simulate path (or the same scale) for local preview to agree with keyframes.

## Authentication Gates

None

## Known Stubs

- Bot half of the turn is not run (02-06). `turn` stays `PLAYER` after a throw so ThrowAuthorityIT can POST throw2.
- Match clocks are stored (20s / 4:00 / 5:00) but not ticked or enforced (02-05).
- Client table lift and GET /v1/catalog are 02-08 / 02-07.

These stubs do not block SESS-01 / ALCH-02 / ALCH-05 on the REST path.

## Threat Flags

None — POST /throws, ownership 409, ThrowInput.parse ignore-unknown, and leftover spawn are the plan `<threat_model>` mitigations (T-02-12, T-02-13, T-02-15, T-02-25).

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Ready for 02-05 clocks and 02-06 ScriptedBot on this REST match row. Do not lift the Flame table here (02-08). Catalog GET/client mint is 02-07.

## TDD Gate Compliance

- RED commit `31fd1d2` `test(02-04): add failing test for throw authority` — harness test-compile failed (missing spawnForBoneCount / spawnRemaining)
- GREEN commit `50b8ec8` `feat(02-04): implement REST throw authority` — BurstSimTest + ThrowAuthorityIT + GuestIdentityIT + ModularityTest passed

## Self-Check: PASSED

- FOUND: Dyn4jBurstSim.java, MatchController.java, AlchikiEngine.java, MatchService.java, ThrowAuthorityIT.java, V2__matches.sql, 02-04-SUMMARY.md
- FOUND: 31fd1d2 test(02-04), 50b8ec8 feat(02-04)
