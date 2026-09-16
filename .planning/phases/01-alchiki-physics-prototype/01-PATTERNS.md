# Phase 1: Alchiki Physics Prototype - Pattern Map

**Mapped:** 2026-09-06
**Files analyzed:** 27
**Analogs found:** 0 / 27

Greenfield confirmed: `nomad-game` has planning docs only. No `client/`, `harness/`, Dart, Java, Gradle, or pubspec exists. Do **not** invent fictional in-repo excerpts. Planner must copy from `01-RESEARCH.md` (and Flame / dyn4j first-party snippets cited there), then create the trees below.

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `client/pubspec.yaml` | config | file-I/O | — | none (greenfield) |
| `client/lib/main.dart` | component | event-driven | — | none (greenfield) |
| `client/lib/sandbox_page.dart` | component | event-driven | — | none (greenfield) |
| `client/lib/game/alchiki_sandbox_game.dart` | component | event-driven | — | none (greenfield) |
| `client/lib/game/felt_circle.dart` | component | event-driven | — | none (greenfield) |
| `client/lib/game/saka_body.dart` | component | event-driven | — | none (greenfield) |
| `client/lib/game/bone_body.dart` | component | event-driven | — | none (greenfield) |
| `client/lib/game/physics_stepper.dart` | utility | transform | — | none (greenfield) |
| `client/lib/input/aim_controller.dart` | controller | event-driven | — | none (greenfield) |
| `client/lib/input/throw_input.dart` | model | transform | — | none (greenfield) |
| `client/lib/schema/table_constants.dart` | config | transform | — | none (greenfield) |
| `client/lib/replay/throw_resolved.dart` | model | file-I/O | — | none (greenfield) |
| `client/lib/replay/keyframe_player.dart` | service | streaming | — | none (greenfield) |
| `client/lib/replay/authority_score.dart` | utility | transform | — | none (greenfield) |
| `client/assets/replays/golden_throw.json` | config | file-I/O | — | none (greenfield) |
| `client/test/throw_input_test.dart` | test | transform | — | none (greenfield) |
| `client/test/physics_stepper_test.dart` | test | transform | — | none (greenfield) |
| `client/test/replay_score_test.dart` | test | transform | — | none (greenfield) |
| `harness/pom.xml` | config | file-I/O | — | none (greenfield) |
| `harness/mvnw` + `harness/mvnw.cmd` | config | file-I/O | — | none (greenfield) |
| `harness/src/main/java/com/nomadgames/alchiki/proto/ThrowInput.java` | model | transform | — | none (greenfield) |
| `harness/src/main/java/com/nomadgames/alchiki/proto/TableConstants.java` | config | transform | — | none (greenfield) |
| `harness/src/main/java/com/nomadgames/alchiki/proto/Keyframe.java` | model | transform | — | none (greenfield) |
| `harness/src/main/java/com/nomadgames/alchiki/proto/ThrowResolved.java` | model | file-I/O | — | none (greenfield) |
| `harness/src/main/java/com/nomadgames/alchiki/proto/Dyn4jBurstSim.java` | service | batch | — | none (greenfield) |
| `harness/src/main/java/com/nomadgames/alchiki/proto/HarnessMain.java` | controller | file-I/O | — | none (greenfield) |
| `harness/src/test/java/com/nomadgames/alchiki/proto/BurstSimTest.java` | test | batch | — | none (greenfield) |

Implied (not named in the tree, required by Wave 0 tests / schema): `throw_resolved.dart`, `authority_score.dart`. Optional later (do not block Phase 1): `scripts/replay.ps1` for adb pull/run/push.

`flutter create` will also emit `client/android/**` scaffold. Treat those as tool output, not pattern-mapped product files.

## Pattern Assignments

Every file below is **no analog / greenfield**. Copy the RESEARCH excerpts cited — they are the only in-repo patterns.

---

### `client/pubspec.yaml` (config, file-I/O)

**Analog:** none (greenfield)

**Core pattern** — RESEARCH.md Standard Stack install (lines 130–137):

```bash
flutter create --org com.nomadgames --platforms=android,ios client
cd client
flutter pub add flame:1.38.2
flutter pub add flame_forge2d:0.20.0
flutter pub add forge2d:0.15.1
```

Pin only those three pubs. Do **not** add `go_router`, `flutter_riverpod`, `dio`, `web_socket_channel`, `flutter_secure_storage`. Do **not** install npm `flame` / `forge2d` (wrong registry).

---

### `client/lib/main.dart` (component, event-driven)

**Analog:** none (greenfield)

**Core pattern** — RESEARCH.md Pattern 1 (lines 264–276):

```dart
// Source: 01-RESEARCH.md Pattern 1 / docs.flame-engine.org GameWidget.controlled
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SandboxApp());
}

class SandboxApp extends StatelessWidget {
  const SandboxApp({super.key});
  @override
  Widget build(BuildContext context) => const MaterialApp(home: SandboxPage());
}
```

Instantiate the `Forge2DGame` **once** (not inside `build`). Call `initializeForge2D()` before the first `World`. No router, no login shell.

---

### `client/lib/sandbox_page.dart` (component, event-driven)

**Analog:** none (greenfield)

**Core pattern** — RESEARCH.md Pattern 1 + D-04: one `Scaffold` / `Stack` with `GameWidget.controlled` plus Flutter overlays. Flame owns the table. Flutter owns Hold / Reset / Replay / power meter / debug HUD text that is not in world space.

Hold button is a Flutter widget (`Listener` / `GestureDetector`), **not** a Flame component. Charge window 150–1100 ms, hold-at-max, visible meter. After settle: pocketed **preview** label (local, debug) vs **scored** (from JVM file only).

---

### `client/lib/game/alchiki_sandbox_game.dart` (component, event-driven)

**Analog:** none (greenfield)

**Imports pattern** (expected, from RESEARCH stack — not copied from repo):

```dart
import 'package:flame/components.dart';
import 'package:flame_forge2d/flame_forge2d.dart';
```

**Core pattern** — RESEARCH.md Pattern 2 (lines 288–294) + Pitfall 1:

```dart
await initializeForge2D();
// 0.15 World() defaults to (0, -10) — table-top MUST pass zero.
final world = World(gravity: Vector2.zero());
```

Subclass `Forge2DGame`. Override world step so frame `dt` never reaches `physicsWorld.step` (0.20 `Forge2DWorld.update` does exactly that — Pitfall 1). Use `PhysicsStepper` accumulator, then `physicsWorld.step(1 / 60, subStepCount: 4)`. Camera is 2.5D presentation only (`scale.y ≈ 0.86` on a render layer). Do not squash colliders. Add `FpsTextComponent` on the viewfinder.

**API trap:** Flame Forge2D docs still show 0.19 `FixtureDef` / `createFixture`. 0.20 uses `body.createShape(...)`, `metersToPixels`, `initializeForge2D()`.

---

### `client/lib/game/felt_circle.dart` (component, event-driven)

**Analog:** none (greenfield)

**Core pattern:** Flame render component, not a collider. Felt-colored circle radius = `TableConstants.circleRadiusM` (1.40 m). Contrasting rim that can flash when a bone exits. Physics circle stays circular; tilt is render-only (RESEARCH Pattern / 2.5D, line 493–495).

---

### `client/lib/game/saka_body.dart` (component, event-driven)

**Analog:** none (greenfield)

**Core pattern** — RESEARCH.md Pattern 2 + Pitfall 5:

```dart
saka.applyLinearImpulse(aimDir * impulseFromHold(holdMs), wake: true);
```

Circle body, brighter distinct material, mass `sakaMassKg` (0.12), radius `sakaRadiusM` (0.07). Meters, Y-up. After Reset: wake / `setAtRest(false)` before the next throw. Do not start bodies asleep.

---

### `client/lib/game/bone_body.dart` (component, event-driven)

**Analog:** none (greenfield)

**Core pattern:** Same disk recipe as saka, six instances (D-01). Mass `boneMassKg` (0.055), radius `boneRadiusM` (0.055). Visible spin via angular velocity + angular damping 0.85. Pocket test (discretion table): entire disk outside when `distance(center, origin) > circleR + bodyR`.

---

### `client/lib/game/physics_stepper.dart` (utility, transform)

**Analog:** none (greenfield)

**Core pattern** — RESEARCH.md Code Examples (lines 409–427):

```dart
class PhysicsStepper {
  static const step = 1 / 60;
  static const maxCatchUp = 4;
  double acc = 0;

  void tick(double frameDt, void Function(double dt) stepWorld) {
    acc += frameDt;
    var n = 0;
    while (acc >= step && n < maxCatchUp) {
      stepWorld(step);
      acc -= step;
      n++;
    }
    if (n == maxCatchUp) acc = 0; // prevent spiral of death
  }
}
```

Never call `stepWorld(frameDt)`. Same `1/60` as dyn4j `Settings.setStepFrequency(1.0 / 60.0)` (period, not 60).

---

### `client/lib/input/aim_controller.dart` (controller, event-driven)

**Analog:** none (greenfield)

**Core pattern:** Drag around the saka rotates an aiming arrow in world space. Canonical angle: **CCW from +X, Y-up meters** (Pitfall 3). Convert only in the renderer (`drawY = -y`). No slingshot, no aim-assist line that lengthens with cosmetics. Separate from hold/power.

---

### `client/lib/input/throw_input.dart` (model, transform)

**Analog:** none (greenfield)

**Validation pattern** — RESEARCH.md Shared schema + Security V5 (lines 499–511, 728–729):

```json
{
  "schemaVersion": 1,
  "yUp": true,
  "aimAngleRad": 1.0471975512,
  "holdMs": 640,
  "seed": 1,
  "tableId": "alchiki-proto-v1"
}
```

Clamp `holdMs` → `[150, 1100]`. `aimAngleRad` must be finite; reject NaN/Inf. `schemaVersion` must be 1. Ignore unknown fields. Hand-written DTO + `dart:convert` — no Freezed.

**Impulse formula** (lines 432–437) — same constants as Java:

```dart
double impulseFromHoldMs(int holdMs) {
  final t = ((holdMs.clamp(150, 1100) - 150) / (1100 - 150));
  return impulseMinNs + t * (impulseMaxNs - impulseMinNs);
}
```

---

### `client/lib/schema/table_constants.dart` (config, transform)

**Analog:** none (greenfield)

**Core pattern:** Byte-for-byte semantic match with `TableConstants.java`. RESEARCH.md table (lines 514–529): `circleRadiusM=1.40`, `sakaRadiusM=0.07`, `boneRadiusM=0.055`, `sakaMassKg=0.12`, `boneMassKg=0.055`, `friction=0.30`, `restitution=0.38`, `linearDamping=1.15`, `angularDamping=0.85`, `impulseMinNs=0.06`, `impulseMaxNs=0.38`, `physicsHz=60`, `keyframeHz=20`, `settleTimeoutS=1.2`, `boneCount=6`. Embed the same object in every `ThrowResolved`.

---

### `client/lib/replay/throw_resolved.dart` (model, file-I/O)

**Analog:** none (greenfield) — implied DTO (RESEARCH Wave 0 + schema)

**Core pattern:** Parse harness JSON only. Cap keyframe count (~40) and body count (8). Reject NaN. Never write `pocketedCount` from Dart poses. Replay matching: run only if `ThrowResolved.input` equals the last committed `ThrowInput` (or the baked golden). Mismatch → disable Replay and keep `scored` blank.

---

### `client/lib/replay/keyframe_player.dart` (service, streaming)

**Analog:** none (greenfield)

**Core pattern** — RESEARCH.md Replay lerp (lines 465–480):

```dart
void applyFrame(double tMs, List<Kf> kfs) {
  final i = lastIndexWhere(kfs, (k) => k.tMs <= tMs);
  final a = kfs[i];
  final b = kfs[min(i + 1, kfs.length - 1)];
  final u = (b.tMs == a.tMs) ? 1.0 : (tMs - a.tMs) / (b.tMs - a.tMs);
  for (final body in bodies) {
    body.setTransform(
      lerp(a[body.id], b[body.id], u),
      lerpAngle(a[body.id].angle, b[body.id].angle, u),
    );
  }
}
```

Closed-buffer snapshot interpolation (Gaffer), **not** a live 60 Hz authority stream. When local preview diverges, **keyframes win**. Do not lockstep Forge2D against dyn4j.

---

### `client/lib/replay/authority_score.dart` (utility, transform)

**Analog:** none (greenfield) — implied by `replay_score_test.dart`

**Core pattern** — Pitfall 8: two labels. `preview` = local Forge2D settle (debug). `scored` = `ThrowResolved.pocketedCount` from the JVM file only. Helper returns `null` / blank if no matching JVM file. Never mix a client-written score field into harness output.

---

### `client/assets/replays/golden_throw.json` (config, file-I/O)

**Analog:** none (greenfield)

**Core pattern:** Produced by the harness CLI, **not** hand-edited poses. Shape = `ThrowResolved` (RESEARCH lines 533–548). Ship so Replay works on first install. Device handoff otherwise: `adb pull` `throw_input.json` → `mvnw exec:java` → `adb push` or drop onto `assets/replays/`. No REST.

---

### `client/test/throw_input_test.dart` (test, transform)

**Analog:** none (greenfield)

**Testing pattern** — RESEARCH Validation (lines 697, 677): `flutter test test/throw_input_test.dart`. Assert clamp 150–1100, impulse monotonic in hold window, reject non-finite aim.

---

### `client/test/physics_stepper_test.dart` (test, transform)

**Analog:** none (greenfield)

**Testing pattern** — RESEARCH line 698: accumulator never steps with raw frame `dt`. Same step count for simulated 30 vs 60 FPS frame times (catch-up cap respected).

---

### `client/test/replay_score_test.dart` (test, transform)

**Analog:** none (greenfield)

**Testing pattern** — RESEARCH line 699: HUD score helper reads only `ThrowResolved.pocketedCount`. Forged client `pocketedCount` / rest poses must not become `scored`.

---

### `harness/pom.xml` (config, file-I/O)

**Analog:** none (greenfield)

**Core pattern** — RESEARCH.md lines 139–158. **No** `spring-boot-starter-parent`. Java 21, dyn4j **6.0.0** (docs still show stale 5.0.2), JUnit Jupiter **6.1.3** test scope only. Do not add Jackson/Gson unless the schema grows — hand-written JSON.

---

### `harness/mvnw` + `harness/mvnw.cmd` (config, file-I/O)

**Analog:** none (greenfield)

**Core pattern:** Generate Maven Wrapper 3.9.x so the machine without global `mvn` can build. Do not create a nested `.git` inside `nomad-game`.

---

### `ThrowInput.java` (model, transform)

**Analog:** none (greenfield)

**Validation:** Same clamp / finite-angle / `schemaVersion == 1` as Dart. Fields: `aimAngleRad`, `holdMs`, `seed`, `tableId`, `yUp`, `schemaVersion`. No `pocketedCount` on input. Ignore unknown JSON keys.

---

### `TableConstants.java` (config, transform)

**Analog:** none (greenfield)

**Core pattern:** Duplicate of `client/lib/schema/table_constants.dart` values (RESEARCH table 514–529). Both engines: meters, Y-up, gravity `(0,0)`, `physicsHz=60`.

---

### `Keyframe.java` + `ThrowResolved.java` (model, file-I/O)

**Analog:** none (greenfield)

**Core pattern** — RESEARCH `ThrowResolved` JSON (lines 533–548). Harness is the **only** writer of `pocketedCount`, `sakaOut`, `settleReason`, `keyframes`. No `finalTransforms` / client pose field. `yUp: true` on every file.

---

### `Dyn4jBurstSim.java` (service, batch)

**Analog:** none (greenfield)

**Core pattern** — RESEARCH.md Pattern 3 + dyn4j burst (lines 312–325, 444–461):

```java
world.setGravity(new Vector2(0, 0));
settings.setStepFrequency(1.0 / 60.0);
settings.setAtRestDetectionEnabled(true);
saka.applyImpulse(new Vector2(Math.cos(aim) * j, Math.sin(aim) * j));

boolean timeout = false;
for (int i = 0; i < 72; i++) { // 1.2s at 60 Hz
  world.step(1);
  if (i % 3 == 0) frames.add(capture((i + 1) * (1000 / 60), world)); // 20 Hz
  if (allAtRest(world)) break;
  if (i == 71) timeout = true;
}
int pocketed = countFullyOutside(world, CIRCLE_R);
boolean sakaOut = isFullyOutside(saka, CIRCLE_R);
int score = sakaOut ? 0 : pocketed;
```

dyn4j `World()` defaults to earth gravity — must `setGravity(0,0)`. `applyImpulse` wakes by spec. Score from rest poses after sleep **or** 1.2 s timeout (still emit frames + score).

---

### `HarnessMain.java` (controller, file-I/O)

**Analog:** none (greenfield)

**Core pattern:** CLI only — `java -jar` / `mvnw -q exec:java -Dexec.args="throw_input.json throw_resolved.json"`. Read input file, run `Dyn4jBurstSim`, write `ThrowResolved` JSON. No Spring, no HTTP, no WebSocket. JDK `java.nio.file` + hand-written JSON.

---

### `BurstSimTest.java` (test, batch)

**Analog:** none (greenfield)

**Testing pattern** — RESEARCH lines 680–684, 700:

- Fixture `ThrowInput` → `keyframes.length >= 3` and a set `pocketedCount` / `sakaOut`
- `timeoutStillScores` — 1.2 s path still emits frames + score
- `outputHasNoClientPosesField` — harness never reads a score field from input
- Deterministic enough to assert score + frame count (not bit-identical vs Forge2D)

Command: `mvnw -q test -Dtest=BurstSimTest`

## Shared Patterns

### No authentication
**Source:** CONTEXT D-02 / RESEARCH Security Domain
**Apply to:** Entire phase
No login, sessions, JWT, or “auth for later.” Single-player sandbox.

### Authority / anti-tamper score
**Source:** CONTEXT D-09–D-10, RESEARCH Pitfall 8 + STRIDE table
**Apply to:** `Dyn4jBurstSim`, `ThrowResolved`, `authority_score.dart`, `keyframe_player.dart`, HUD
Harness is the only writer of `pocketedCount`. Replay interpolates JVM frames only. Client may preview locally; if they diverge, keyframes win. No API that accepts a client score.

### Input validation (ASVS V5)
**Source:** RESEARCH Security Domain (lines 720–738)
**Apply to:** `throw_input.dart`, `ThrowInput.java`, Replay JSON parse
Clamp `holdMs` `[150, 1100]`; reject non-finite `aimAngleRad`; `schemaVersion` must be 1; ignore unknown fields; never `eval` JSON; cap keyframe/body counts.

### Shared physics contract (both engines)
**Source:** RESEARCH Architecture + Pitfalls 1–4
**Apply to:** `alchiki_sandbox_game.dart`, `physics_stepper.dart`, `Dyn4jBurstSim.java`, both `TableConstants`
- Gravity **zero** (Forge2D 0.15 and dyn4j both default to earth gravity)
- Fixed `dt = 1/60`, never frame time
- MKS meters; circle 1.2–1.6 m; do not use pixels as physics units
- Canonical space: Y-up, +X right, angle CCW from +X; convert only in Flutter draw
- Linear damping 0.9–1.4, angular 0.7–1.0, restitution 0.30–0.45, friction 0.25–0.40; hard cap 1.2 s

### Error / fallback handling
**Source:** RESEARCH Pitfall 6 + Environment
**Apply to:** client toolchain / `pubspec.yaml`
Forge2D 0.15.1 + flame_forge2d 0.20.0 first. If native assets / NDK fail after a documented install, drop to `forge2d` 0.14.x + `flame_forge2d` 0.19.3+7 in the **same** Flame app. Do not switch to Unity/Godot. Do not scaffold Spring “so the harness looks like production.”

### Logging / HUD
**Source:** RESEARCH FPS HUD (lines 483–491) + D-02
**Apply to:** `alchiki_sandbox_game.dart`, `sandbox_page.dart`
`FpsTextComponent` is the game-loop FPS source of truth. Flutter text for body count, settle flag, physics Hz, last `holdMs`, `preview` vs `scored`. PROTO-01 evidence is `flutter run --profile` on a mid-range device (emulator alone is not the FPS gate).

### Dual DTO, no codegen
**Source:** RESEARCH Don't Hand-Roll + Shared schema
**Apply to:** all `ThrowInput` / `TableConstants` / `ThrowResolved` files
Hand-written Dart + Java types. `dart:convert` / JDK string JSON. Keep types boring for a future `games/alchiki` seam. Do not wire REST, WebSocket, Spring Modulith, or Postgres in this phase.

## No Analog Found

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `client/pubspec.yaml` | config | file-I/O | No Flutter app in repo |
| `client/lib/main.dart` | component | event-driven | No Dart sources |
| `client/lib/sandbox_page.dart` | component | event-driven | No Flutter widgets |
| `client/lib/game/alchiki_sandbox_game.dart` | component | event-driven | No Flame/Forge2D game |
| `client/lib/game/felt_circle.dart` | component | event-driven | No render components |
| `client/lib/game/saka_body.dart` | component | event-driven | No physics bodies |
| `client/lib/game/bone_body.dart` | component | event-driven | No physics bodies |
| `client/lib/game/physics_stepper.dart` | utility | transform | No stepper util |
| `client/lib/input/aim_controller.dart` | controller | event-driven | No input controllers |
| `client/lib/input/throw_input.dart` | model | transform | No Dart DTOs |
| `client/lib/schema/table_constants.dart` | config | transform | No shared constants |
| `client/lib/replay/throw_resolved.dart` | model | file-I/O | No Replay DTOs |
| `client/lib/replay/keyframe_player.dart` | service | streaming | No interpolation player |
| `client/lib/replay/authority_score.dart` | utility | transform | No score helper |
| `client/assets/replays/golden_throw.json` | config | file-I/O | No assets tree |
| `client/test/*.dart` (3 files) | test | transform | No `flutter_test` suite |
| `harness/pom.xml` | config | file-I/O | No Maven module |
| `harness/mvnw*` | config | file-I/O | No wrapper |
| `ThrowInput.java` | model | transform | No Java sources |
| `TableConstants.java` | config | transform | No Java sources |
| `Keyframe.java` | model | transform | No Java sources |
| `ThrowResolved.java` | model | file-I/O | No Java sources |
| `Dyn4jBurstSim.java` | service | batch | No dyn4j harness |
| `HarnessMain.java` | controller | file-I/O | No CLI entry |
| `BurstSimTest.java` | test | batch | No JUnit suite |

Planner substitute: `01-RESEARCH.md` sections Architecture Patterns, Code Examples, Shared ThrowInput schema, Validation Architecture, Security Domain.

## Metadata

**Analog search scope:** repo root (`nomad-game`); globs `*.{dart,java,kt,gradle,xml,yaml}`, `client/**`, `harness/**`, `.cursor/rules`, `.cursor/skills`, `.agents/skills`, `.claude/**`
**Files scanned:** 18 planning markdown/json files; **0** product source files
**Project rules / skills:** none under the working tree (no `.cursor/rules`, no project skills)
**Pattern extraction date:** 2026-09-06
**Research stand-in:** `.planning/phases/01-alchiki-physics-prototype/01-RESEARCH.md`
