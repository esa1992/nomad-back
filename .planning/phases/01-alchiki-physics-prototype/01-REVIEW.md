---
phase: 01-alchiki-physics-prototype
reviewed: 2026-09-06T11:10:00Z
depth: standard
files_reviewed: 28
files_reviewed_list:
  - client/lib/main.dart
  - client/lib/sandbox_page.dart
  - client/lib/input/throw_input.dart
  - client/lib/input/aim_controller.dart
  - client/lib/schema/table_constants.dart
  - client/lib/game/physics_stepper.dart
  - client/lib/game/alchiki_sandbox_game.dart
  - client/lib/game/felt_circle.dart
  - client/lib/game/saka_body.dart
  - client/lib/game/bone_body.dart
  - client/lib/replay/authority_score.dart
  - client/lib/replay/throw_resolved.dart
  - client/lib/replay/keyframe_player.dart
  - client/test/throw_input_test.dart
  - client/test/physics_stepper_test.dart
  - client/test/replay_score_test.dart
  - client/test/pocket_settle_test.dart
  - client/test/widget_test.dart
  - harness/src/main/java/com/nomadgames/alchiki/proto/HarnessMain.java
  - harness/src/main/java/com/nomadgames/alchiki/proto/Dyn4jBurstSim.java
  - harness/src/main/java/com/nomadgames/alchiki/proto/ThrowResolved.java
  - harness/src/main/java/com/nomadgames/alchiki/proto/ThrowInput.java
  - harness/src/main/java/com/nomadgames/alchiki/proto/Keyframe.java
  - harness/src/main/java/com/nomadgames/alchiki/proto/JsonSupport.java
  - harness/src/main/java/com/nomadgames/alchiki/proto/TableConstants.java
  - harness/src/test/java/com/nomadgames/alchiki/proto/BurstSimTest.java
  - scripts/replay.ps1
  - scripts/dev-env.ps1
findings:
  critical: 2
  warning: 6
  info: 3
  total: 11
status: issues_found
---

# Phase 1: Code Review Report

**Reviewed:** 2026-09-06T11:10:00Z
**Depth:** standard
**Files Reviewed:** 28
**Status:** issues_found

## Narrative Findings (AI reviewer)

## Summary

Reviewed the Phase 1 Alchiki sandbox (Flutter/Flame 0.19 + forge2d 0.14), the Spring-free Maven dyn4j harness, and the two PowerShell toolchain scripts. The client does not write `pocketedCount` into `throw_input.json`, and the harness ignores input score-like keys — that D-10 half is intact. Two ship-blocking defects remain: Hold Throw can crash if released before Forge2D `onLoad`, and HUD `scored` reads raw `pocketedCount` while dropping authority `sakaOut` / `displayedScore()` (D-08). Additional warnings cover settle-clock drift vs the 72-step JVM cap, sleep keyframes that omit the scored rest pose, a tautological BurstSim assertion, the first-match JSON scanner, sticky invalid import state, and unquoted `replay.ps1` paths.

## Critical Issues

### CR-01: Hold Throw can crash before Forge2D onLoad

**File:** `client/lib/sandbox_page.dart:131-132`
**Also:** `client/lib/game/alchiki_sandbox_game.dart:293-299`, `client/lib/game/saka_body.dart:43-49`
**Issue:** `_holdEnabled` is true as soon as the Flutter overlay builds (`_settled` starts false). `GameWidget` loads `AlchikiSandboxGame` asynchronously. A press/release of Hold Throw before `onLoad` assigns `late final SakaBody saka` throws `LateInitializationError`. If `saka` is assigned but not yet mounted, `saka.body.applyLinearImpulse` throws on the uninitialized `body`. Debug HUD already guards `isLoaded`; the throw path does not. First-launch / slow emulator load makes this reachable.
**Fix:**
```dart
bool get _holdEnabled =>
    game.isLoaded && !_throwing && !_settled && !_replaying;

void throwSaka(ThrowInput input) {
  if (!isLoaded) {
    return;
  }
  cancelReplay();
  throwing = true;
  tableSettled = false;
  simTimeS = 0;
  aimLocked = true;
  saka.applyThrowImpulse(input);
}
```

### CR-02: HUD scored ignores authority saka-out (D-08)

**File:** `client/lib/replay/authority_score.dart:8-19`
**Also:** `client/lib/replay/throw_resolved.dart:60-91`, `client/lib/sandbox_page.dart:321-327`, `harness/src/main/java/com/nomadgames/alchiki/proto/ThrowResolved.java:59-62`
**Issue:** RESEARCH / 01-04 define the display rule as `sakaOut ? 0 : pocketedCount` (`ThrowResolved.displayedScore()`). The Dart parser never reads `sakaOut`. `AuthorityScore.readPocketedCount` returns raw `pocketedCount`. After Replay of a JVM buffer with `sakaOut: true` and `pocketedCount: 2`, HUD shows `scored 2` instead of `0`. The on-screen `saka out · 0` banner is copied from local Forge2D preview (`game.sakaOut`), not from the file, so Replay can disagree with both the banner and D-08. Client is not writing a score, but it is displaying the wrong authority value.
**Fix:**
```dart
// throw_resolved.dart — parse and store sakaOut
final sakaOut = json['sakaOut'];
if (sakaOut is! bool) {
  throw const FormatException('sakaOut must be a boolean');
}

// authority_score.dart
return resolved.sakaOut ? 0 : resolved.pocketedCount;
```
Also drive the `saka out · 0` banner from `resolved.sakaOut` when Replay starts, and add a replay test with `sakaOut: true, pocketedCount: 2` expecting scored `0`.

## Warnings

### WR-01: Settle timeout advances on frame dt, not physics steps

**File:** `client/lib/game/alchiki_sandbox_game.dart:135-136`
**Issue:** `simTimeS += dt` uses the render/frame delta. `computeSettled` then freezes at `simTimeS >= 1.2`. The harness caps at `round(settleTimeoutS * 60)` = 72 fixed 1/60 steps. At 30 FPS a 1.2s wall clock yields ~54 physics steps; preview freezes early vs dyn4j. At a hitch followed by catch-up (max 4 steps) the clocks diverge the other way. D-09's 1.2s timeout is simulation time on the JVM and wall/frame time on the client.
**Fix:** Increment `simTimeS` by `PhysicsStepper.step` once per actual `stepWorld` call (report the step count from `FixedDtWorld` / `PhysicsStepper`), never by raw `dt`.

### WR-02: Sleep path omits the rest-pose keyframe used for scoring

**File:** `harness/src/main/java/com/nomadgames/alchiki/proto/Dyn4jBurstSim.java:95-105`
**Issue:** A 20 Hz sample is stored only when `(i + 1) % 3 == 0`. On `allAtRest` the loop breaks without a final `capture`. The pad at lines 103–105 runs only when `frames.size() < 3`. `scoreFromRestPoses` still uses live rest positions, so `pocketedCount` can reflect a bone that is not outside on the last keyframe. Replay then ends 1–2 steps short of the scored poses. The golden fixture times out at step 72 (which is on-cadence), so BurstSimTest never sees this.
**Fix:**
```java
if (allAtRest(bodies)) {
    settleReason = "sleep";
    int tMs = (int) Math.round(stepsRun * (1000.0 / TableConstants.physicsHz));
    if (frames.size() < KEYFRAME_CAP) {
        frames.add(capture(tMs, bodies));
    }
    break;
}
```

### WR-03: BurstSimTest saka-out assertion is a tautology

**File:** `harness/src/test/java/com/nomadgames/alchiki/proto/BurstSimTest.java:35-37`
**Issue:** `assertEquals(0, result.sakaOut() ? 0 : result.pocketedCount())` inside `if (result.sakaOut())` always compares `0` to `0`. It never calls `displayedScore()` and the 60° fixture typically does not set `sakaOut`. D-08 is untested on the harness side; the client suite also has no `sakaOut: true` case (see CR-02).
**Fix:**
```java
if (result.sakaOut()) {
    assertEquals(0, result.resolved().displayedScore());
}
```
Add a dedicated throw (or constructed `ThrowResolved`) that sets `sakaOut` true with `pocketedCount > 0` and asserts `displayedScore() == 0`.

### WR-04: ThrowInput JSON scanner is first-match, not object-structured

**File:** `harness/src/main/java/com/nomadgames/alchiki/proto/ThrowInput.java:174-188`
**Issue:** `findValueStart` scans the raw string for `"key"` then `:`. The first syntactic hit wins. A value that embeds `"schemaVersion": 2` (escaped text), a duplicate key (JSON last-wins, this parser first-wins), or a wrapped document can reject a valid input or clamp the wrong `holdMs`. The harness correctly ignores score-like field *names* only when they are not the first `"holdMs"` / `"seed"` match.
**Fix:** Walk only the top-level object (brace depth 1) when locating keys, or reject any input that is not a single flat object. Keep ignoring unknown keys after a successful top-level read.

### WR-05: replay.ps1 passes unquoted host paths into adb and Maven exec.args

**File:** `scripts/replay.ps1:23-41`
**Issue:** `$inputLocal` / `$outputLocal` are built from the repo root and passed unquoted to `adb pull` / `adb push`. Maven gets a single `-Dexec.args=$inputLocal $outputLocal` string that the exec plugin splits on spaces. A root path with spaces (or extra Maven tokens) breaks the handoff or mis-parses arguments. `dev-env.ps1` itself is fine (`$ErrorActionPreference = 'Stop'`, Join-Path).
**Fix:**
```powershell
adb pull "$deviceDocs/throw_input.json" "$inputLocal"
$execArgs = '"{0}" "{1}"' -f $inputLocal, $outputLocal
& .\mvnw.cmd -q exec:java "-Dexec.args=$execArgs"
adb push "$outputLocal" "$deviceDocs/throw_resolved.json"
```

### WR-06: Corrupt import stamps mtime and disables Replay on the last good buffer

**File:** `client/lib/sandbox_page.dart:260-283`
**Issue:** `_importedMtime = mtime` is set before `ThrowResolved.parse`. A `FormatException` then sets `_replayError = invalid` without clearing `_resolved`. `_replayReady` requires `error != invalid`, so Replay stays dead until the file's mtime changes, even though the golden / last good buffer is still in memory. The 250 ms poll will not retry the same bad file.
**Fix:** Parse first; assign `_importedMtime` only on success. On `FormatException`, keep the last good `_resolved` and show the banner without forcing `_replayReady` false if `allowsReplay` still holds for that buffer — or clear the sticky `invalid` once a good buffer exists.

## Info

### IN-01: seed is serialized but never applied

**File:** `client/lib/game/alchiki_sandbox_game.dart:47-56`
**Also:** `harness/src/main/java/com/nomadgames/alchiki/proto/Dyn4jBurstSim.java:24-33`
**Issue:** Both engines always spawn the locked seed-1 hex. `ThrowInput.seed` is written and compared for Replay equality but does not change layout. A future non-1 seed will match Replay and still simulate seed-1.
**Fix:** Reject `seed != 1` in parse for this prototype, or branch spawn on `seed`.

### IN-02: Java hold clamp constants are duplicated outside TableConstants

**File:** `harness/src/main/java/com/nomadgames/alchiki/proto/ThrowInput.java:10-11`
**Issue:** `HOLD_MS_MIN/MAX` are copies of the Dart `TableConstants` values, not fields on Java `TableConstants`. A one-sided edit silently desyncs clamp vs the client.
**Fix:** Move 150/1100 onto `TableConstants` and have both `ThrowInput` classes read them.

### IN-03: PlusOnePopup allocates an undisposed TextPainter every render

**File:** `client/lib/game/alchiki_sandbox_game.dart:338-352`
**Issue:** `TextPainter` is created in `render` and never disposed. Not a scoring or crash bug; it is a resource leak on a 0.9s popup.
**Fix:** Cache and `dispose()` one `TextPainter` on the component, or use Flame `TextComponent`.

---

_Reviewed: 2026-09-06T11:10:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
