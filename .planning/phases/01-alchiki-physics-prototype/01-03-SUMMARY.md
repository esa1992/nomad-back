---
phase: 01-alchiki-physics-prototype
plan: 03
subsystem: game
tags: [flutter, flame, forge2d, bones, settle, preview, reset-table]

requires:
  - phase: 01-alchiki-physics-prototype
    provides: Zero-g felt table with aim arrow, Hold Throw, ThrowInput, TableConstants
provides:
  - Six seed-1 hex bones (b1–b6) with readable disk collisions and spin
  - Settle-then-preview HUD, floating +1, saka-out · 0
  - Reset Table snap/wake and debug HUD (fps / bodies / settled)
affects:
  - 01-04 Dyn4jBurstSim seed-1 layout
  - 01-05 Replay Throw and scored HUD

tech-stack:
  added: []
  patterns:
    - FixtureDef disks (Wave 1 lock: forge2d 0.14.2 / flame_forge2d 0.19.3+7)
    - computeSettled(sleep OR settleTimeoutS 1.2) then freeze
    - preview is local feel only; scored stays em-dash

key-files:
  created:
    - client/lib/game/bone_body.dart
    - client/test/pocket_settle_test.dart
  modified:
    - client/lib/game/alchiki_sandbox_game.dart
    - client/lib/game/felt_circle.dart
    - client/lib/sandbox_page.dart
    - client/lib/game/saka_body.dart

key-decisions:
  - "Keep FixtureDef / createFixture; do not upgrade to flame_forge2d 0.20 createShape"
  - "Seed-1 hex locked: saka (0.0, -1.15); b1–b6 at r=0.22 with 0.19053 so 01-04 matches"
  - "preview updates only after settle; scored remains — until 01-05"

patterns-established:
  - "Pattern 1: isFullyOutside(center, circleR, bodyR) shared by game and pocket_settle_test"
  - "computeSettled(allDynamicSleeping, simTimeS) is true on sleep or t >= 1.2"
  - "Reset Table snaps poses, wakes bodies, clears preview/+1; next throw requires reset"

requirements-completed: [PROTO-01]

coverage:
  - id: D1
    description: Six target bones spawn at locked seed-1 hex points with disk mass/friction/restitution and a spin tick
    requirement: PROTO-01
    verification:
      - kind: unit
        ref: "client/test/pocket_settle_test.dart#origin is not fully outside the circle"
        status: pass
      - kind: other
        ref: "grep alchiki_sandbox_game.dart boneCount b1 0.19053; bone_body.dart boneMassKg D4A574"
        status: pass
    human_judgment: true
    rationale: "Unit tests cover the pocket predicate, not that six BodyComponents exist at the hex points on device."
  - id: D2
    description: Rim flashes #F0B429 for 200 ms when a target first becomes fully outside; saka exit does not flash-for-score
    requirement: PROTO-01
    verification:
      - kind: other
        ref: "grep felt_circle.dart F0B429; dart analyze lib (no issues)"
        status: pass
    human_judgment: true
    rationale: "Flash timing and saka-vs-target distinction need a human throw on the parlor table."
  - id: D3
    description: After sleep or 1.2s settle, preview N and cream +1 appear; mid-roll scoring does not; saka-out shows saka out · 0
    requirement: PROTO-01
    verification:
      - kind: unit
        ref: "client/test/pocket_settle_test.dart#computeSettled is true at 1.2s even if bodies are awake"
        status: pass
      - kind: unit
        ref: "client/test/pocket_settle_test.dart#computeSettled is false at 1.19s if bodies are awake"
        status: pass
      - kind: unit
        ref: "client/test/pocket_settle_test.dart#computeSettled is true when all dynamic bodies sleep"
        status: pass
    human_judgment: true
    rationale: "computeSettled is unit-tested; floating +1, preview HUD, and saka-out copy need a human after a throw."
  - id: D4
    description: Reset Table snaps the hex cluster, wakes bodies, clears preview, scored stays —, Hold disabled until reset; debug HUD shows fps/bodies/settled
    requirement: PROTO-01
    verification:
      - kind: unit
        ref: "client/test/widget_test.dart#SandboxApp shows empty-state copy"
        status: pass
      - kind: other
        ref: "grep sandbox_page.dart Reset Table preview settled saka out; alchiki_sandbox_game.dart FpsTextComponent settleTimeoutS"
        status: pass
    human_judgment: true
    rationale: "Widget test only asserts empty-state copy. Reset snap, Hold lock, and debug HUD need a human on the sandbox."

duration: 9min
completed: 2026-09-06
status: complete
---

# Phase 1 Plan 03: Six bones + settle preview + Reset Table Summary

**Six FixtureDef target bones on the locked seed-1 hex, settle-then-preview (sleep or 1.2s), Reset Table snap/wake, and a fps/bodies/settled debug HUD — scored stays an em-dash**

## Performance

- **Duration:** 9 min
- **Started:** 2026-09-06T02:01:07Z
- **Completed:** 2026-09-06T02:10:12Z
- **Tasks:** 2/2
- **Files modified:** 6

## Accomplishments

- BoneBody disks (mass 0.055 kg, fill #D4A574, tick #6B4423) spawn at locked seed-1 hex b1–b6; saka stays at (0.0, -1.15)
- Felt rim flashes #F0B429 for 200 ms when a target first satisfies fully-outside; saka exit does not flash
- After all dynamic sleep or `settleTimeoutS` 1.2 s, poses freeze; `preview {n}` and cream `+1` appear; `saka out · 0` if the saka left
- Reset Table (secondary #241810, 48dp) snaps and wakes the cluster, clears preview/+1, scored stays `—`; Hold Throw stays disabled until reset
- Debug HUD (88% #241810) shows `fps {n}`, `bodies {n}`, `settled yes|no`; `FpsTextComponent` on the viewfinder

## Task Commits

Each task was committed atomically:

1. **Task 1 RED: pocket fully-outside tests** - `06ef313` (test)
2. **Task 1 GREEN: six seed-1 bones and rim flash** - `95991f1` (feat)
3. **Task 2 RED: settle timeout tests** - `1c8b541` (test)
4. **Task 2 GREEN: settle preview and Reset Table** - `9230f2d` (feat)

**Plan metadata:** pending docs commit after this file

_Note: TDD tasks produced RED then GREEN commits_

## Files Created/Modified

- `client/lib/game/bone_body.dart` - Disk bones, `isFullyOutside`, snap-to-spawn
- `client/test/pocket_settle_test.dart` - Pocket fully-outside and `computeSettled` unit tests
- `client/lib/game/alchiki_sandbox_game.dart` - Seed-1 hex spawn, settle/freeze/preview/+1, Reset Table, `FpsTextComponent`
- `client/lib/game/felt_circle.dart` - `flashRim(200)` accent stroke
- `client/lib/game/saka_body.dart` - `snapToSpawn` wake
- `client/lib/sandbox_page.dart` - Reset Table, preview/scored HUD, saka-out, debug HUD, Hold lock

## Decisions Made

- Wave 1 pins stay (forge2d 0.14.2 + flame_forge2d 0.19.3+7). Plan text asked for 0.20 `createShape`; used FixtureDef like 01-02
- Seed-1 meters Y-up locked for 01-04: saka (0.0, -1.15); b1 (0.22, 0.0); b2 (0.11, 0.19053); b3 (-0.11, 0.19053); b4 (-0.22, 0.0); b5 (-0.11, -0.19053); b6 (0.11, -0.19053)
- `preview` is local Forge2D feel only; `scored —` until 01-05 Replay; throw_input.json still has no pocketedCount

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] flame_forge2d 0.20 createShape does not compile on Wave 1 pins**
- **Found during:** Task 1
- **Issue:** Plan asked for 0.20 `createShape`. Locked stack is FixtureDef / `createFixture` / `stepDt`
- **Fix:** BoneBody matches SakaBody FixtureDef recipe (density from `boneMassKg` / area)
- **Files modified:** `client/lib/game/bone_body.dart`
- **Verification:** `dart analyze lib` no issues; pocket tests green
- **Committed in:** `95991f1`

**2. [Rule 3 - Blocking] flutter analyze LSP crash**
- **Found during:** Task 1 verify
- **Issue:** `flutter analyze` aborted with truncated LSP JSON (same as 01-02)
- **Fix:** Used `dart analyze` on touched files / `lib`
- **Files modified:** none
- **Verification:** `dart analyze lib` — No issues found
- **Committed in:** n/a (tooling only)

---

**Total deviations:** 2 auto-fixed (2 blocking)
**Impact on plan:** Required to compile on the locked 0.19 stack and to finish verify. No first-to-5, bots, Replay, or JVM score write.

## TDD Gate Compliance

Tasks are `tdd="true"` on a `type: execute` plan.

- RED: `06ef313` `test(01-03): add failing test for pocket fully-outside`
- GREEN: `95991f1` `feat(01-03): implement six seed-1 bones and rim flash`
- RED: `1c8b541` `test(01-03): add failing test for settle timeout`
- GREEN: `9230f2d` `feat(01-03): implement settle preview and Reset Table`

No missing RED/GREEN gates.

## Issues Encountered

- `flutter analyze` crashed the analysis server once (truncated LSP JSON). `dart analyze lib` reported no issues.

## Known Stubs

Intentional, out of this plan:

| File | Stub | Reason |
|------|------|--------|
| Replay Throw button | present, always disabled | 01-05 |
| `scored —` | never copied from preview | D-10 / 01-05 |
| `client/lib/replay/authority_score.dart` | still returns clientPocketedCount | Keep `replay_score_test` red until 01-05 |

## Authentication Gates

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Ready for 01-04 (dyn4j BurstSim on the same seed-1 hex) and 01-05 (Replay Throw / scored)
- Client still cannot author scored
- Keep forge2d 0.14 / flame_forge2d 0.19 until MSVC or an Android 0.15 APK restore
- Do not treat PROTO-01 as device-complete — no mid-range profile FPS yet

## Threat Flags

None — preview stays labeled `preview`; scored remains em-dash; throw_input.json still serializes only schemaVersion, yUp, aimAngleRad, holdMs, seed, tableId (T-01-01). No new packages (T-01-SC).

## Self-Check: PASSED

- FOUND: `client/lib/game/bone_body.dart`, `client/lib/game/alchiki_sandbox_game.dart`, `client/lib/game/felt_circle.dart`, `client/lib/sandbox_page.dart`, `client/lib/game/saka_body.dart`, `client/test/pocket_settle_test.dart`
- FOUND: commit `06ef313`, commit `95991f1`, commit `1c8b541`, commit `9230f2d`
- `flutter test test/pocket_settle_test.dart test/throw_input_test.dart test/physics_stepper_test.dart` exit 0; `dart analyze lib` no issues; greps for Reset Table, preview, settleTimeoutS, FpsTextComponent, seed-1 0.19053, isFullyOutside, computeSettled succeeded

---
*Phase: 01-alchiki-physics-prototype*
*Completed: 2026-09-06*
