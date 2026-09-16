---
phase: 01-alchiki-physics-prototype
verified: 2026-09-06T11:20:00Z
status: passed
score: 10/10 must-haves verified
behavior_unverified: 0
overrides_applied: 0
---

# Phase 1: Alchiki Physics Prototype Verification Report

**Phase Goal:** A player on a mid-range Android device can aim, hold-to-throw, and knock bones with readable physics, and the same throw is scored only from a JVM keyframe buffer
**Verified:** 2026-09-06T11:20:00Z
**Status:** passed
**Re-verification:** No — initial verification
**Mode:** mvp (ROADMAP goal is outcome-form; PLAN restated the same slots as a valid user story — `user-story.validate` = true)

## User Flow Coverage

User story: «As a player on a mid-range Android device, I want to aim, hold-to-throw, and knock bones with readable physics, so that the same throw is scored only from a JVM keyframe buffer.»

| Step | Expected | Evidence | Status |
|------|----------|----------|--------|
| Open sandbox | Single parlor screen, no login/catalog | `client/lib/main.dart` `MaterialApp(home: SandboxPage)`; no router/login in `client/lib` | ✓ |
| Aim | Drag around the saka rotates a fixed-length cream arrow | `TableDragLayer` → `AimController.updateFromWorldPoint`; `AimArrow` length 0.42 m, `#F4E8C8` | ✓ |
| Hold to throw | Hold Throw charges 150–1100 ms; meter fills; hold-at-max pulses | `sandbox_page.dart` Listener + clamp; `throw_input_test` clamp 50→150 passed | ✓ |
| Knock bones | Release applies zero-g impulse; six disks collide with mass/spin/friction | `SakaBody.applyThrowImpulse`; Forge2D `gravity: Vector2.zero()`; bone/saka friction 0.30 restitution 0.38 | ✓ |
| Settle preview | After sleep or 1.2 s, `preview N` and `+1`; not mid-roll | `computeSettled` + `_applyPreviewAfterSettle` only after settle; `pocket_settle_test` 1.2 s | ✓ |
| Replay + score | Replay interpolates JVM frames; `scored` from file `pocketedCount` only | `KeyframePlayer.applyFrame` test passed; `AuthorityScore.readPocketedCount` test passed | ✓ |
| Outcome | Same throw scored only from a JVM keyframe buffer | Client writes `throw_input.json` only; HUD `_scored` set solely in `_startReplay` from `AuthorityScore` | ✓ |

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | ------- | ---------- | -------------- |
| 1 | On a mid-range Android device the player can aim, hold-to-throw, and knock target bones with readable mass, collisions, rotation, friction, and restitution at about 60 FPS | ✓ VERIFIED | Code path is complete (aim + Hold Throw + Forge2D disks + `FpsTextComponent`). Owner human-check APPROVED 2026-09-06: `flutter run --profile`, Flame FPS ≥ 55 during aim + throw + settle + Replay. Code does not contradict that approval. |
| 2 | The same throw input can be replayed from a closed dyn4j keyframe buffer; the demo never accepts a client-authored score | ✓ VERIFIED | `Dyn4jBurstSim` emits keyframes; `HarnessMain` writes `ThrowResolved`. `BurstSimTest#outputHasNoClientPosesField` exit 0. Client `AuthorityScore` has no Forge2D rest-pose argument. `_scored` is assigned only from `readPocketedCount` or cleared to null on Reset. |
| 3 | SandboxApp is a single MaterialApp/SandboxPage with no login, catalog, or router | ✓ VERIFIED | `main.dart` home is `SandboxPage`. Grep of `client/lib` finds no login/catalog/`go_router`. |
| 4 | Player aims with a fixed-length arrow and charges Hold Throw 150–1100 ms with a visible meter; release applies a zero-g impulse along the aim vector | ✓ VERIFIED | `AimArrow.lengthM = 0.42`; `ThrowInput.impulseFromHoldMs` lerp; `SakaBody.applyLinearImpulse`; `flutter test --name "holdMs 50 clamps to 150"` passed. |
| 5 | Physics steps use a 1/60 accumulator with max 4 catch-up, never frame delta | ✓ VERIFIED | `PhysicsStepper.step = 1/60`, `maxCatchUp = 4`; `FixedDtWorld.update` calls `stepper.tick(dt, physicsWorld.stepDt)`. `flutter test --name "catch-up cap is 4"` passed. |
| 6 | Felt circle `#1B6B3A`, brighter saka, 2.5D `scale.y` 0.86, six hex bones with readable materials | ✓ VERIFIED | `FeltCircle.fill = 0xFF1B6B3A`; `presentationScaleY = 0.86`; `seed1Bones` b1–b6; saka `#FFF6D6` + stripe; bones `#D4A574` + tick `#6B4423`. |
| 7 | After sleep or 1.2 s settle, preview and `+1` appear (not mid-roll); saka-out shows `saka out · 0`; Reset Table restores the cluster, clears preview, sets `scored —`, cancels Replay | ✓ VERIFIED | `_applyPreviewAfterSettle` only after `computeSettled`; Reset calls `cancelReplay`, `snapToSpawn`, `_scored = null`. `pocket_settle_test` covers fully-outside and 1.2 s timeout. |
| 8 | Same ThrowInput JSON burst-simulates in dyn4j 6 to sleep or 1.2 s; `pocketedCount`/`sakaOut` come from rest poses; `HarnessMain` writes `ThrowResolved`; golden is that CLI shape | ✓ VERIFIED | `pom.xml` dyn4j 6.0.0, no Spring. `setGravity(0,0)`, step 1/60, 72-step cap. Golden has 25 keyframes, `settleReason: timeout`, `pocketedCount` from file (0 on this fixture). Input `pocketedCount: 99` is ignored (named JUnit passed). |
| 9 | Replay interpolates JVM keyframes (keyframes win); `scored {n}` equals file `pocketedCount`; Replay allowed only on last-input match or baked golden | ✓ VERIFIED | `startReplay` / `_advanceReplay` call `applyFrame` after the world step and zero velocities. `flutter test --name "applyFrame lerps…"` and `"scored value equals ThrowResolved.pocketedCount"` passed. `allowsReplay` is golden-or-last-input only. |
| 10 | Hold / Reset / Replay meet UI-SPEC colors, 48 dp targets, English copy; harness is Spring-free Java 21; ThrowInput keys match; forge2d 0.14 / flame_forge2d 0.19 locked | ✓ VERIFIED | Buttons labeled Hold Throw / Reset Table / Replay Throw; accent `#F0B429` on Hold/Replay/meter/rim; minHeight 48. `mvnw.cmd` + `maven.compiler.release` 21. Shared keys: `schemaVersion`, `yUp`, `aimAngleRad`, `holdMs`, `seed`, `tableId`. `pubspec.yaml` pins `forge2d: 0.14.2`, `flame_forge2d: 0.19.3+7`. Owner approved UI-SPEC colors 2026-09-06. |

**Score:** 10/10 truths verified (0 present, behavior-unverified)

Wave-1/Wave-2 PLAN truths that said client tests / `BurstSimTest` must **fail** were RED gates. They are superseded by later GREEN plans and are not current phase-end must-haves.

### Required Artifacts

`gsd-tools query verify.artifacts` could not parse PLAN YAML lists (formatter warning: artifacts/key_links parsed as 0 items). Existence, substance, and wiring were checked by hand.

| Artifact | Expected | Status | Details |
| -------- | ----------- | ------ | ------- |
| `client/lib/main.dart` | SandboxApp entry | ✓ VERIFIED | Exists, `SandboxPage` home, wired |
| `client/lib/sandbox_page.dart` | Hold / Reset / Replay overlays | ✓ VERIFIED | Substantive HUD + charge + authority score |
| `client/lib/input/throw_input.dart` | Clamp + impulse | ✓ VERIFIED | Wired from page + saka + tests |
| `client/lib/game/physics_stepper.dart` | Fixed-dt accumulator | ✓ VERIFIED | Used by `FixedDtWorld` |
| `client/lib/game/alchiki_sandbox_game.dart` | Zero-g Forge2D sandbox | ✓ VERIFIED | Spawn, throw, settle, replay |
| `client/lib/game/bone_body.dart` | Six disk bones | ✓ VERIFIED | `boneMassKg`, hex ids |
| `client/lib/replay/authority_score.dart` | File-only scored reader | ✓ VERIFIED | `pocketedCount` only |
| `client/lib/replay/keyframe_player.dart` | Closed-buffer lerp | ✓ VERIFIED | `applyFrame` used by game |
| `client/lib/replay/throw_resolved.dart` | Parse + replay gate | ✓ VERIFIED | Caps 40/8, golden match |
| `scripts/dev-env.ps1` | JAVA_HOME / ANDROID_HOME | ✓ VERIFIED | Sets both + Flutter PATH |
| `scripts/replay.ps1` | adb ↔ `exec:java` | ✓ VERIFIED | pull / `mvnw exec:java` / push |
| `harness/pom.xml` | Spring-free dyn4j 6 | ✓ VERIFIED | No Spring parent |
| `harness/mvnw.cmd` | Maven Wrapper | ✓ VERIFIED | Present |
| `harness/.../Dyn4jBurstSim.java` | Authority burst | ✓ VERIFIED | `setGravity`, pocket from rest |
| `harness/.../HarnessMain.java` | CLI writer | ✓ VERIFIED | parse → simulate → write |
| `harness/.../BurstSimTest.java` | PROTO-02 automation | ✓ VERIFIED | Named test passed |
| `client/assets/replays/golden_input.json` | Fixture `1.0471975512` | ✓ VERIFIED | Matches golden input |
| `client/assets/replays/golden_throw.json` | Baked JVM dump | ✓ VERIFIED | 25 keyframes, CLI-shaped JSON |
| `client/test/throw_input_test.dart` | Clamp/impulse | ✓ VERIFIED | Named test passed |
| `client/test/replay_score_test.dart` | Authority contract | ✓ VERIFIED | Named tests passed |
| `client/test/pocket_settle_test.dart` | Pocket + 1.2 s | ✓ VERIFIED | `isFullyOutside` + `computeSettled` |

### Key Link Verification

| From | To | Via | Status | Details |
| ---- | --- | --- | ------ | ------- |
| `sandbox_page.dart` | `throw_input.dart` | Hold release builds `ThrowInput` and `game.throwSaka` | WIRED | `_releaseCharge` |
| `alchiki_sandbox_game.dart` | `physics_stepper.dart` | `FixedDtWorld` ticks stepper then `stepDt` | WIRED | `stepper.tick(dt, physicsWorld.stepDt)` |
| `sandbox_page.dart` | `alchiki_sandbox_game.dart` | Reset → `resetTable`; Replay → `startReplay` | WIRED | settle callback updates preview |
| `felt_circle.dart` | `bone_body.dart` | Rim flash when a target first exits | WIRED | `felt.flashRim(200)` from `_flashNewlyPocketedBones` |
| `HarnessMain.java` | `Dyn4jBurstSim.java` | CLI reads ThrowInput and writes `simulate()` | WIRED | `Dyn4jBurstSim.simulate(input)` |
| `golden_throw.json` | `HarnessMain.java` | File carries `pocketedCount` + keyframes | WIRED | Schema matches `ThrowResolved.toJson` |
| `authority_score.dart` | `golden_throw.json` | `readPocketedCount` uses file field only | WIRED | Parse → `resolved.pocketedCount` |
| `keyframe_player.dart` | `alchiki_sandbox_game.dart` | Replay applies JVM transforms | WIRED | `KeyframePlayer.applyFrame` in `startReplay` / `_advanceReplay` |
| `BurstSimTest.java` | `Dyn4jBurstSim` / `ThrowInput` | `simulate` + shared JSON keys | WIRED | Fixture uses `aimAngleRad` |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| -------- | ------------- | ------ | ------------------ | ------ |
| Sandbox scored HUD | `_scored` | `AuthorityScore.readPocketedCount(ThrowResolved)` | File `pocketedCount` (golden or imported JVM JSON) | ✓ FLOWING |
| Sandbox preview HUD | `_preview` / `game.previewCount` | Forge2D rest poses after settle | Local disk positions via `isFullyOutside` | ✓ FLOWING (labeled preview) |
| Replay poses | body `setTransform` | `ThrowResolved.keyframes` | Closed JVM buffer (25 frames in golden) | ✓ FLOWING |
| Harness `pocketedCount` | `scoreFromRestPoses` | dyn4j world centers vs circle | Distance test, ignores input score keys | ✓ FLOWING |
| Debug FPS | `game.debugFps` | Flame `FpsTextComponent` | Runtime FPS, not a hardcoded 60 | ✓ FLOWING |

Hollow-prop check: Replay/Reset/Hold are not passed empty lists. Golden `pocketedCount: 0` is a real dyn4j result for this aim (saka misses the hex), not an empty stub.

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| -------- | ------- | ------ | ------ |
| scored = file `pocketedCount` | `flutter test test/replay_score_test.dart --name "scored value equals ThrowResolved.pocketedCount"` | +1 passed | ✓ PASS |
| applyFrame lerp/nlerp | `flutter test test/replay_score_test.dart --name "applyFrame lerps position"` | +1 passed | ✓ PASS |
| holdMs clamp | `flutter test test/throw_input_test.dart --name "holdMs 50 clamps"` | +1 passed | ✓ PASS |
| stepper catch-up 4 | `flutter test test/physics_stepper_test.dart --name "catch-up cap is 4"` | +1 passed | ✓ PASS |
| harness ignores client score | `mvnw.cmd -q test -Dtest=BurstSimTest#outputHasNoClientPosesField` | exit 0 | ✓ PASS |

### Probe Execution

| Probe | Command | Result | Status |
| ----- | ------- | ------ | ------ |
| — | No `scripts/*/tests/probe-*.sh` and no probe declared in PLAN/SUMMARY | N/A | SKIP |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
| ----------- | ---------- | ----------- | ------ | -------- |
| PROTO-01 | 01-01, 01-02, 01-03, 01-05, 01-06 | Aim, hold-to-throw, knock bones with readable physics at ~60 FPS on mid-range Android | ✓ SATISFIED | Client sandbox + owner device approval 2026-09-06 + FPS HUD |
| PROTO-02 | 01-01, 01-04, 01-05, 01-06 | Same throw simulated by headless JVM dyn4j harness; closed keyframe buffer; no client-authored score | ✓ SATISFIED | Harness CLI + golden + Replay + `AuthorityScore` + named JUnit |

Orphaned requirements mapped to Phase 1 but missing from plans: none. REQUIREMENTS.md Phase 1 IDs are only PROTO-01 and PROTO-02.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| ---- | ---- | ------- | -------- | ------ |
| `client/lib/game/alchiki_sandbox_game.dart` | 17 | `initializeForge2D()` empty | ℹ️ Info | Intentional 0.19 fallback (pubspec comment). Not a TBD/FIXME. |
| `client/assets/replays/golden_throw.json` | — | Bones stay at spawn; `pocketedCount` 0 | ℹ️ Info | Golden aim misses the hex. Buffer is still a real dyn4j dump (moving saka, 25 frames). Live device throws are the knock proof. |
| PLAN frontmatter | — | `gsd-tools` could not parse `must_haves.artifacts` / `key_links` | ℹ️ Info | Manual verification used instead. Does not block the goal. |

Debt-marker scan (`TBD` / `FIXME` / `XXX`) on phase Dart/Java/scripts: no matches.

Prohibition check: client must not author scores — no `pocketedCount` writer in `client/lib` except parsing JVM JSON. forge2d 0.14 / flame_forge2d 0.19 locked in `pubspec.yaml`. No Spring/Postgres in `harness/`.

### Human Verification Required

None pending.

Harvested `<human-check>` from `01-05-PLAN.md` (device FPS, Replay scored from `ThrowResolved`, UI-SPEC colors) was already **APPROVED 2026-09-06 by owner** and recorded in `01-05-SUMMARY.md`. Code inspection does not contradict that approval, so the items are not re-opened.

### Gaps Summary

No blocking gaps. Phase goal holds in the codebase: a playable Flutter/Forge2D sandbox plus a Spring-free dyn4j harness, with HUD `scored` readable only from a JVM `ThrowResolved` keyframe buffer.

Confirmation-bias notes (non-blocking): `BurstSimTest.timeoutStillScores` uses the default 1.2 s timeout (does not force a distinct no-sleep path); the timeout branch still exists in `Dyn4jBurstSim` (`settleReason` timeout, 72-step cap). Golden fixture does not pocket bones; that does not undo PROTO-02.

---

_Verified: 2026-09-06T11:20:00Z_
_Verifier: Claude (gsd-verifier)_
