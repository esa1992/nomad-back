# Phase 1: Alchiki Physics Prototype - Research

**Researched:** 2026-09-05
**Domain:** Flutter/Flame/Forge2D client feel + headless JVM dyn4j keyframe harness
**Confidence:** MEDIUM (first-party pages fetched; seam tags `webfetch` LOW / `websearch --verified` MEDIUM; no Context7; machine missing Flutter/Android SDK)

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

#### Prototype product shape
- **D-01:** Prototype is a **sandbox table**, not a first-to-5 match, not a catalog, not vs-bot. Six target bones start in the circle. After physics settle, show pocketed count and a **Reset** that restores the cluster. Repeat throws until the feel is proven.
- **D-02:** No login, guest bind, shop, bots, rooms, how-to cards, Stick Pull, or i18n screens. A debug HUD (FPS, body count, settle flag) is allowed.
- **D-03:** iOS compile is **not** required to pass the gate. Android (emulator + mid-range device if available) is the proof target. Keep the Flutter project capable of iOS later; do not spend Phase 1 on Xcode shipping.

#### Aim and throw
- **D-04:** Controls match the original product spec, not 8 Ball Pool. Player **rotates an aiming arrow** (drag around the saka). A **separate hold button** charges power by hold duration. Release throws. No drag-back slingshot, no aim-assist line that lengthens with cosmetics (there are no cosmetics yet).
- **D-05:** Charge window ~0.15–1.1s; holding past max stays at max (no overcharge penalty). Visible power meter required so the throw reads as skill.
- **D-06:** Camera is **2.5D**: top-down circle with a slight tilt. Physics stay 2D (disk/capsule colliders). Gravity of the physics world is zero (table-top).

#### Board look (prototype fidelity)
- **D-07:** Not gray cubes, not the full art pipeline. **Readable parlor table:** felt-colored circle, contrasting rim that can flash when a bone exits, disk/capsule bones with visible spin, a brighter distinct saka. Placeholder materials are fine if mass, collisions, rotation, friction, and restitution are obvious.
- **D-08:** Scoring presentation: floating +1 only **after settle**, not mid-roll. Saka leaving the circle scores 0 and returns on Reset / next throw setup.

#### Authority proof
- **D-09:** Client Forge2D may simulate locally for **feel and optional preview**. Authority is **dyn4j on the JVM**. Same `ThrowInput` `{ aimAngle, holdMs }` (plus seed/table constants) goes to a **headless harness** that burst-simulates to sleep (~1.2s timeout) and emits a **closed keyframe buffer**.
- **D-10:** After a throw, the device must offer **Replay** that interpolates those JVM keyframes. The demo **must not** accept a client-authored score or rest poses. Overlay or morph from local preview onto the keyframe replay is allowed; when they diverge, **keyframes win**.
- **D-11:** Do **not** lockstep Forge2D against dyn4j. Fixed physics `dt` (1/60 or 1/120), never `dt = frameTime`. Prototype family = production family: Flutter 3.47 + Flame + Forge2D + dyn4j 6. If the gate fails, change stack **in this phase**, not after accounts exist.

### Claude's Discretion
- Exact masses, friction, restitution, saka vs bone size, keyframe rate, JSON vs binary frame schema, JUnit vs CLI harness layout, NDK/Forge2D 0.15 vs 0.14 Dart fallback, HUD layout, Reset animation — planner/researcher decide, as long as D-01–D-11 hold.
- Mid-range Android: treat as a typical 2022–2024 Snapdragon 6/7 class or equivalent emulator profile; do not require a flagship.

### Deferred Ideas (OUT OF SCOPE)
- First-to-5 match clock, turn order, static how-to cards, EASY/NORMAL/HARD bots — Phase 2
- iOS device proof / App Store packaging — later phases
- Full nomadic art pack, cosmetics, trails, victory animations — Phase 4+
- WebSocket match session, reconnect, private rooms — Phase 3
- Stick Pull — Phase 6
- Bind / Ranked / Glicko-2 — Phase 7

None extra from this discussion — stayed inside the prototype gate.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| PROTO-01 | On a mid-range Android device the player can aim, hold-to-throw, and knock target bones with readable mass, collisions, rotation, friction, and restitution at about 60 FPS | Flame `GameWidget` + `Forge2DGame` zero-g disks; separate Flutter Hold button; fixed `dt` accumulator; `FpsTextComponent` + profile-mode overlay; readable felt/saka/spin |
| PROTO-02 | The same throw input can be simulated by a headless JVM dyn4j harness that emits a closed keyframe buffer the Flutter client can interpolate (no client-authored score) | Shared `ThrowInput` JSON; Maven CLI/JUnit (no Spring); `World.step` burst to `isAtRest` or 1.2s; Replay interpolates JVM frames only; HUD authority score from `ThrowResolved` |
</phase_requirements>

## Summary

Phase 1 is a **walking skeleton for a new game**, not a CRUD app. Create two sibling trees and nothing else: a single-screen Flutter sandbox (aim arrow + hold button + Reset + Replay) and a **plain Maven Java module** that burst-simulates the same `ThrowInput` in dyn4j 6 and writes a closed keyframe JSON. Do not scaffold Spring Boot, Modulith, Postgres, REST, or WebSocket.

Forge2D 0.15 / `flame_forge2d` 0.20 is the feel engine (native Box2D v3). It is **not** the scorer. dyn4j 6.0.0 is the authority. Both worlds must use **meters, Y-up, gravity zero, fixed 1/60 s steps**. The default Flame docs page for Forge2D still describes the 0.19 `Fixture` API — treat that page as stale. Follow pub.dev 0.20 + the 0.20 `Forge2DWorld` source (`physicsWorld.step(dt, subStepCount:)`).

This Windows machine has **Corretto 21** installed but **no Flutter, Android SDK, NDK, or Maven on PATH**. Wave 0 must install the client toolchain or the gate cannot be executed. If Forge2D 0.15 native assets fail, drop to `forge2d` 0.14 + `flame_forge2d` 0.19.x in the same Flame app — do not switch to Unity.

**Primary recommendation:** One `GameWidget` sandbox (no `go_router`), Forge2D 0.15 with a **fixed-dt accumulator** (do not pass frame `dt` into `World.step`), and a Spring-free Maven harness that emits JSON keyframes Flame interpolates. Score on screen after Replay comes only from that JVM file.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Aim arrow + hold-to-throw feel | Browser / Client (Flutter/Flame) | — | Input and local Forge2D preview live on device |
| Readable 2.5D parlor render | Browser / Client | CDN / Static (placeholder sprites) | Camera tilt + felt/saka are presentation only |
| ~60 FPS proof | Browser / Client | — | Flame game loop + Flutter profile overlay on Android |
| Local settle preview (+1 after sleep) | Browser / Client | — | Feel only; must be labeled preview |
| Authority simulate-to-rest | API / Backend (headless JVM process) | — | dyn4j owns rest poses and pocketed count |
| Closed keyframe buffer | API / Backend | Browser / Client (Replay) | JVM writes; Flutter interpolates, never authors |
| Shared `ThrowInput` / table constants | Both (schema file) | — | Same JSON contract; no lockstep |
| Score displayed as gate result | API / Backend | Browser / Client (read-only) | Client must not submit or persist a score |
| Persistence / auth / catalog | — | — | Out of scope (D-02) |

## Project Constraints (from .claude/.cursor/rules)

Actionable directives the planner must honor:

- **Prototype gate:** Do not build identity, catalog, shop, or ranked until this physics stack is proven. If the gate fails, reopen the stack here.
- **Authority:** Backend (here: JVM harness) is source of truth. Client does not decide outcome, score, rating, or balances.
- **Platform:** One Flutter client for Android + iOS later; Phase 1 ships Android proof only.
- **Architecture (later):** Modular monolith with `games/alchiki/` — keep `ThrowInput` + keyframe types boring and reusable. Do not wire the monolith in this phase.
- **Team:** One developer + AI agents — keep the slice thin.
- **Git:** Do not create a nested `.git` inside `nomad-game`.
- **Art:** Colorful nomadic/Asian direction; Phase 1 uses a readable subset (felt + bright saka), not shop skins.
- **GSD workflow:** Implementation edits belong under a GSD execute command; this research file is the planning artifact.

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Flutter SDK | **3.47.0** (Dart **3.13**) | Android client | Current stable. [CITED: docs.flutter.dev/release/release-notes] [CITED: flutter.dev/blog/whats-new-in-flutter-3-47] |
| Flame | **1.38.2** | Game loop, camera, `FpsTextComponent`, overlays | Current pub.dev. Widgets are not a 60 FPS clock. [CITED: pub.dev/packages/flame] |
| forge2d | **0.15.1** | Client Box2D v3 via FFI/native assets | Current pub.dev. Zero-g: `World(gravity: Vector2.zero())`. [CITED: pub.dev/packages/forge2d] |
| flame_forge2d | **0.20.0** | Flame ↔ Forge2D 0.15 bridge | Breaking adapt to Flutter 3.47 + Box2D v3. Do not mix with forge2d 0.14. [CITED: pub.dev/packages/flame_forge2d] |
| Eclipse Temurin / Corretto JDK | **21** | Harness + tests | LTS. Machine already has Corretto 21.0.11. [VERIFIED: local `java -version`] |
| dyn4j | **6.0.0** | Authority solver | Maven Central current. Headless, no JNI. [CITED: central.sonatype.com/artifact/org.dyn4j/dyn4j] |
| JUnit Jupiter | **6.1.3** | Harness tests | Current Maven Central aggregator. [CITED: central.sonatype.com/artifact/org.junit.jupiter/junit-jupiter] |
| Maven Wrapper | 3.9.x wrapper | Build harness without global `mvn` | Global Maven is missing on this machine. [VERIFIED: `mvn` MISSING] |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Flutter widgets (`Stack`, `Listener`, `GestureDetector`) | SDK | Hold / Reset / Replay / power meter | Always — hold button is **not** a Flame component (D-04) |
| `dart:convert` | SDK | `ThrowInput` / `ThrowResolved` JSON | Always. No Freezed / code-gen. |
| Java 21 `java.nio.file` + hand-written JSON | JDK | Harness I/O | Always. Do **not** add Jackson/Gson unless a schema grows. |
| `flame_forge2d` 0.19.3+7 + `forge2d` 0.14.x | pub.dev | Pure-Dart fallback | Only if 0.15 native assets / NDK block week 1 |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Forge2D 0.15 native | forge2d 0.14 Dart port | Same Flame app; slower; use only if NDK/MSVC fail |
| Plain Maven harness | Spring Boot 4.1.1 | Forbidden this phase (D-11 / CONTEXT) |
| JSON keyframes | Binary / protobuf | JSON is debuggable and matches “boring serializable”; binary later if size hurts |
| File Replay handoff | localhost HTTP | CONTEXT: no REST/WS unless a tiny CLI needs Java. Files + golden asset are enough |
| JUnit only | CLI only | Use **both**: JUnit for determinism, CLI for dumping frames the device imports |

**Do not add in this phase:** `go_router`, `flutter_riverpod`, `dio`, `web_socket_channel`, `flutter_secure_storage`, Spring Boot, Spring Modulith, PostgreSQL, Flyway, Redis.

**Installation (after Wave 0 toolchain):**

```bash
# Client — after Flutter 3.47 is on PATH
flutter create --org com.nomadgames --platforms=android,ios client
cd client
flutter pub add flame:1.38.2
flutter pub add flame_forge2d:0.20.0
flutter pub add forge2d:0.15.1
```

```xml
<!-- harness/pom.xml — NO spring-boot-starter-parent -->
<properties>
  <maven.compiler.release>21</maven.compiler.release>
  <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
</properties>
<dependencies>
  <dependency>
    <groupId>org.dyn4j</groupId>
    <artifactId>dyn4j</artifactId>
    <version>6.0.0</version>
  </dependency>
  <dependency>
    <groupId>org.junit.jupiter</groupId>
    <artifactId>junit-jupiter</artifactId>
    <version>6.1.3</version>
    <scope>test</scope>
  </dependency>
</dependencies>
```

**Version verification (this session):** Flutter 3.47.0 current stable [CITED: docs.flutter.dev/release/release-notes]. Flame 1.38.2 published ~9 days ago [CITED: pub.dev/packages/flame]. forge2d 0.15.1 [CITED: pub.dev/packages/forge2d]. flame_forge2d 0.20.0 (2026-08-17, “Adapt to Flutter 3.47”) [CITED: github.com/flame-engine/flame/releases/tag/flame_forge2d-v0.20.0]. dyn4j 6.0.0 on Maven Central [CITED: central.sonatype.com/artifact/org.dyn4j/dyn4j]. JUnit Jupiter 6.1.3 [CITED: central.sonatype.com/artifact/org.junit.jupiter/junit-jupiter].

**Docs trap:** `docs.flame-engine.org/latest/bridge_packages/flame_forge2d/forge2d.html` still documents `FixtureDef` / `createFixture` / default zoom 10. That is the **0.19** API. 0.20 uses `body.createShape(...)`, `initializeForge2D()`, `metersToPixels`, and `physicsWorld.step(dt, subStepCount:)`. [CITED: pub.dev/packages/flame_forge2d] [CITED: github.com/flame-engine/flame/issues/3952] [CITED: packages/flame_forge2d/lib/forge2d_world.dart]

## Package Legitimacy Audit

> Gate was executed as `gsd-tools query package-legitimacy check --ecosystem npm flame forge2d`. That is the **wrong ecosystem**. npm `flame` is Infinite Red’s IR package (SUS, 82/wk). npm `forge2d` does not exist (SLOP). **Do not install those npm packages.**

Phase packages live on **pub.dev** (Dart) and **Maven Central** (Java). First-party publishers: `flame-engine.org`, `org.dyn4j`, `org.junit.jupiter`.

| Package | Registry | Age | Downloads | Source Repo | Verdict | Disposition |
|---------|----------|-----|-----------|-------------|---------|-------------|
| flame 1.38.2 | pub.dev | years (engine) | high (Flame org) | github.com/flame-engine/flame | OK (official) | Approved |
| forge2d 0.15.1 | pub.dev | rewrite 2026 | Flame org | github.com/flame-engine/forge2d | OK (official) | Approved |
| flame_forge2d 0.20.0 | pub.dev | 2026-08-17 | Flame org | github.com/flame-engine/flame | OK (official) | Approved |
| org.dyn4j:dyn4j 6.0.0 | Maven Central | ~1 month at 6.0.0; project since 2010 | established | github.com/dyn4j/dyn4j | OK (official) | Approved |
| org.junit.jupiter:junit-jupiter 6.1.3 | Maven Central | current JUnit | established | github.com/junit-team/junit-framework | OK (official) | Approved |
| npm `flame` / npm `forge2d` | npm | n/a | n/a | n/a | SLOP/SUS | **REMOVED — wrong registry** |

**Packages removed due to [SLOP] verdict:** npm names only (never recommended).
**Packages flagged as suspicious [SUS]:** none of the pub.dev / Maven packages above.

No Node `postinstall` scripts apply. Dart native assets compile C via build hooks (Forge2D 0.15) — that is documented first-party behavior, not a hidden postinstall. [CITED: pub.dev/packages/forge2d]

## Architecture Patterns

### System Architecture Diagram

```
PLAYER (Android)
  drag around saka ──► AimArrow (Flame, world space)
  press/hold/release ──► Flutter Hold button (widget overlay)
           │
           ▼
  ThrowInput { aimAngleRad, holdMs, seed, tableId }
           │
     ┌─────┴──────────────────────────┐
     ▼                                ▼
 Forge2D local world              JVM harness (CLI / JUnit)
 gravity = 0                      World.setGravity(0,0)
 fixed dt 1/60                    World.step(1) in a loop
 disks + damping                  same TableConstants
 optional preview motion          burst until all isAtRest()
                                  or simTime >= 1.2s
     │                                │
     │ local preview poses            ▼
     │ (feel only)               ThrowResolved.json
     │                           keyframes[] + pocketedCount
     │                           + sakaOut + settleReason
     │                                │
     └──────── Replay ◄───────────────┘
               Flame interpolates JVM frames
               HUD "scored" reads pocketedCount from file
               if local preview diverges → keyframes win
```

No lockstep. No client `finalTransforms`. No HTTP.

### Recommended Project Structure

```
nomad-game/
├── client/                          # Flutter app (no go_router)
│   ├── pubspec.yaml
│   ├── lib/
│   │   ├── main.dart                # MaterialApp → SandboxPage only
│   │   ├── sandbox_page.dart        # Stack: GameWidget + Hold/Reset/Replay + HUD
│   │   ├── game/
│   │   │   ├── alchiki_sandbox_game.dart   # Forge2DGame, gravity 0
│   │   │   ├── felt_circle.dart
│   │   │   ├── saka_body.dart
│   │   │   ├── bone_body.dart
│   │   │   └── physics_stepper.dart        # fixed-dt accumulator
│   │   ├── input/
│   │   │   ├── aim_controller.dart
│   │   │   └── throw_input.dart            # Dart DTO + clamp
│   │   ├── replay/
│   │   │   └── keyframe_player.dart
│   │   └── schema/
│   │       └── table_constants.dart        # MUST match Java
│   └── assets/replays/golden_throw.json    # baked JVM dump
└── harness/                         # Maven, no Spring
    ├── pom.xml
    ├── mvnw / mvnw.cmd
    ├── src/main/java/com/nomadgames/alchiki/proto/
    │   ├── ThrowInput.java
    │   ├── TableConstants.java
    │   ├── Keyframe.java
    │   ├── ThrowResolved.java
    │   ├── Dyn4jBurstSim.java
    │   └── HarnessMain.java         # java -jar / exec:java
    └── src/test/java/.../BurstSimTest.java
```

Keep future production seams (`games/alchiki`) in mind, but do **not** create `backend/` Spring packages this phase.

### Pattern 1: Single-screen Flame inside Flutter widgets

**What:** `runApp` → one `Scaffold` → `GameWidget.controlled` plus Flutter overlays. Flame owns the table. Flutter owns Hold / Reset / Replay / power meter / debug HUD text that is not in world space.

**When to use:** Always in Phase 1. A catalog router is Phase 2.

**Example:**

```dart
// Source: docs.flame-engine.org/latest/flame/game.html (GameWidget.controlled)
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

Instantiate the game **once** (not inside `build`). [CITED: docs.flame-engine.org/latest/flame/game.html]

### Pattern 2: Zero-g disks + hold impulse

**What:** Table-top world, no gravity. Saka and bones are circles. Hold duration maps to a linear impulse along the aim unit vector. Damping drains energy so bodies sleep.

**When to use:** PROTO-01 feel.

**Example:**

```dart
// Source: pub.dev/packages/forge2d (World + step). Gravity MUST be explicit.
await initializeForge2D();
final world = World(gravity: Vector2.zero()); // 0.15 default is (0, -10)
saka.applyLinearImpulse(aimDir * impulseFromHold(holdMs), wake: true);
world.step(1 / 60, subStepCount: 4);
```

```java
// Source: dyn4j.org/pages/getting-started.html + javadoc 6.0.0 PhysicsBody
World world = new World();
world.setGravity(new Vector2(0.0, 0.0)); // default is EARTH_GRAVITY
saka.applyImpulse(new Vector2(ix, iy));  // immediate; wakes body
world.step(1);                           // one fixed step
```

[CITED: pub.dev/packages/forge2d] [CITED: dyn4j.org/pages/getting-started.html] [CITED: javadoc.io dyn4j 6.0.0 PhysicsBody]

### Pattern 3: Headless burst-sim-to-rest + keyframes

**What:** After applying the same impulse, step a fixed number of times, sample poses at `keyframeHz`, stop when every dynamic body `isAtRest()` or `simTime >= 1.2`.

**When to use:** PROTO-02 harness.

```java
// Source: dyn4j.org/pages/advanced.html (headless World.step loop)
double t = 0;
double dt = 1.0 / 60.0;
List<Keyframe> frames = new ArrayList<>();
frames.add(capture(0, world));
while (t < 1.2) {
  world.step(1);
  t += dt;
  if (sampleTick(t)) frames.add(capture((int) Math.round(t * 1000), world));
  if (allAtRest(world)) break;
}
// score from rest poses, then write ThrowResolved
```

[CITED: dyn4j.org/pages/advanced.html] [CITED: javadoc.io dyn4j 6.0.0 Body / PhysicsBody.isAtRest]

### Pattern 4: Closed-buffer Replay (Gaffer interpolation as playback)

**What:** Flame `update` lerps `x,y` and nlerps angle between JVM keyframes. This is snapshot interpolation on a **closed** buffer, not a live 60 Hz authority stream. [CITED: gafferongames.com/post/snapshot_interpolation — via PITFALLS.md]

**When to use:** Replay button and golden asset.

### Anti-Patterns to Avoid

- **`physicsWorld.step(frameDt)`:** 0.20 `Forge2DWorld.update` does exactly this. Override with an accumulator or feel/damping will couple to FPS (flame#2750 family). [CITED: flame-engine/flame packages/flame_forge2d/lib/forge2d_world.dart] [CITED: github.com/flame-engine/flame/issues/2750]
- **Lockstep Forge2D ↔ dyn4j:** Two engines, two float models. D-11 forbids it.
- **Pixels as physics units:** Box2D and dyn4j are MKS. Pixel worlds look sluggish and break sleep tolerances. [CITED: pub.dev/packages/forge2d Units] [CITED: dyn4j.org/pages/getting-started.html]
- **Bare `World()` gravity:** Forge2D 0.15 defaults to `(0,-10)`; dyn4j defaults to earth gravity. Table-top **must** set zero. [CITED: pub.dev/packages/forge2d] [CITED: dyn4j.org/pages/advanced.html]
- **Scaffold Spring Boot “so the harness is production-shaped”:** CONTEXT forbids the monolith this phase.
- **`go_router` catalog shell:** Out of scope; slows the gate.
- **Client field `pocketedCount` written into Replay JSON:** Forged score. Write only from the harness.
- **Stale Flame Forge2D tutorial (`FixtureDef`):** Will not compile on 0.20.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Rigid-body collisions | Custom SAT/impulse solver | Forge2D 0.15 (feel) + dyn4j 6 (authority) | Sleep, friction, restitution, stacking |
| 60 FPS game clock | `Ticker` + raw Canvas | Flame `Forge2DGame` | Camera, overlays, component tree |
| Live netcode / lockstep | Custom determinism layer | Closed keyframe Replay | Cross-engine floats will desync |
| JSON schema codegen | Freezed / proto for 8 fields | Hand-written DTO + `dart:convert` | STACK.md: no codegen soup on frames |
| Spring physics host | Modulith module | `HarnessMain` + JUnit | CONTEXT: no monolith yet |
| FPS counter | Custom frame averaging only | `FpsTextComponent` + Flutter performance overlay | Flame docs: Flame FPS is the game-loop source of truth |

**Key insight:** The hard problem is **two solvers, one contract** — not writing a physics engine. Spend the phase on units, fixed `dt`, shared constants, and proving Replay ignores client rest poses.

## Common Pitfalls

### Pitfall 1: Variable `dt` into Box2D / Forge2D
**What goes wrong:** Impulse and damping change with FPS; emulator ≠ device; first throw feels weak. [CITED: github.com/flame-engine/flame/issues/2750]
**Why it happens:** `Forge2DWorld.update(dt)` calls `physicsWorld.step(dt, subStepCount: 4)` with frame time. [CITED: forge2d_world.dart on flame main]
**How to avoid:** Accumulator: `acc += frameDt; while (acc >= 1/60 && steps < 4) { step(1/60); acc -= 1/60; }`. Same `1/60` in dyn4j (`Settings.setStepFrequency(1.0/60.0)` — value is the period, not 60). [CITED: dyn4j RELEASE-NOTES setStepFrequency is 1/frequency since 3.1.1]
**Warning signs:** Throw distance changes when you toggle 30/60 FPS or run a slow emulator.

### Pitfall 2: Pixel vs meter scale (and `lengthUnitsPerMeter`)
**What goes wrong:** Bones “stick,” never sleep, or tunnel. Box2D speculative distance is **0.02 m** absolute. A 2 cm disk is always in contact. [CITED: pub.dev/packages/forge2d Units]
**How to avoid:** Circle ≈ **1.2–1.6 m** radius. Saka ≈ **0.06–0.08 m**. Bones ≈ **0.05–0.06 m**. Render with `metersToPixels` (~80–140 px/m). Do **not** call `initializeForge2D(lengthUnitsPerMeter: 100)` unless you also scale every tolerance and impulse. Prefer real meters.
**Warning signs:** `beginContact` while pieces still show a gap; jitter on the cluster.

### Pitfall 3: Y-up vs Flame Y-down
**What goes wrong:** Replay is mirrored; aim angle disagrees with the harness.
**How to avoid:** Canonical space is **Y-up meters, +X right, angle CCW from +X** (dyn4j native, Box2D native). Convert only in the Flutter renderer (`drawY = -y`). Document `yUp: true` on every JSON file.
**Warning signs:** Golden Replay flies the opposite way of the local throw.

### Pitfall 4: Sleep / at-rest thresholds on a zero-g table
**What goes wrong:** Bodies creep forever; settle never fires; or they sleep mid-slide.
**Why it happens:** No gravity + low damping. dyn4j sleeps when linear/angular velocity stay below `Settings.getMaximumAtRest*` for `getMinimumAtRestTime()`. Box2D uses `BodyDef.sleepThreshold` (default 0.05 m/s). [CITED: dyn4j.org/pages/advanced.html Body State] [CITED: pub.dev/packages/forge2d BodyDef.sleepThreshold]
**How to avoid:** Linear damping **0.9–1.4**, angular **0.7–1.0**, restitution **0.30–0.45**, friction **0.25–0.40**. Hard cap **1.2 s** sim time (D-09 / FEATURES). After timeout, freeze and score from current poses.
**Warning signs:** HUD `settled=false` past 1.2 s; cluster vibrates.

### Pitfall 5: Applying impulse to a sleeping / invalid body
**What goes wrong:** First Android throw is a no-op (historical Forge2D report). [CITED: github.com/flame-engine/flame/issues/2750]
**How to avoid:** `wake: true` / dyn4j `applyImpulse` (wakes by spec). Do not start bodies `isAwake = false`. After Reset, `setAtRest(false)` / wake before the next throw. [CITED: javadoc.io dyn4j 6.0.0 — applyImpulse resets at-rest]
**Warning signs:** First throw after load is dead; second works.

### Pitfall 6: NDK / native assets on Windows
**What goes wrong:** `forge2d` 0.15 will not compile. pub.dev: Dart 3.12+, C toolchain — VS Build Tools on Windows, **NDK on Android**. [CITED: pub.dev/packages/forge2d Requirements]
**How to avoid:** Wave 0 installs Flutter 3.47, Android SDK, NDK **28.2.13676358** (Flutter engine default in current tree). [CITED: flutter engine android config.gni android_ndk_version] Flutter 3.47 Android matrix: Java 17 min, AGP 9.1.0, Gradle 9.3.1, minSdk 24. [CITED: flutter.dev/blog/whats-new-in-flutter-3-47]
**Fallback:** `flame_forge2d` 0.19.3+7 + `forge2d` 0.14.x. Same app. Do not switch engines.
**Warning signs:** Hook compile errors, missing `libc++`, “C toolchain required”.

### Pitfall 7: Measuring FPS in debug / emulator only
**What goes wrong:** Gate “passes” in debug JIT and fails on a mid phone.
**How to avoid:** PROTO-01 evidence is **`flutter run --profile` on a physical mid-range device** (or the slowest reasonable device). Flutter: debug/emulator numbers lie. [CITED: docs.flutter.dev/perf/ui-performance]
**HUD:** Flame `FpsTextComponent` is the game-loop source of truth (may read lower than DevTools). [CITED: docs.flame-engine.org/latest/flame/other/debug.html]
**Warning signs:** Overlay red bars; Flame FPS < 55 during the throw.

### Pitfall 8: Client-authored score sneaks into the HUD
**What goes wrong:** PROTO-02 fails even if Replay looks pretty.
**How to avoid:** Two labels: `preview` (local settle, debug only) and `scored` (from `ThrowResolved.pocketedCount`). Replay refuses to start without a JVM file whose `input` matches the last `ThrowInput` (or the golden fixture).
**Warning signs:** Score updates before Replay; JSON written from Dart poses.

## Code Examples

### Fixed-dt accumulator (client — required)

```dart
// Pattern required because flame_forge2d 0.20 steps with frame dt.
// Source: Box2D/Gaffer fixed timestep; 0.20 calls physicsWorld.step(dt, subStepCount: 4)
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

### Hold duration → impulse (shared formula)

```dart
// Same constants in Dart and Java (TableConstants).
double impulseFromHoldMs(int holdMs) {
  final t = ((holdMs.clamp(150, 1100) - 150) / (1100 - 150));
  return impulseMinNs + t * (impulseMaxNs - impulseMinNs);
}
```

Recommend starting values (discretion, tune on device): `impulseMinNs = 0.06`, `impulseMaxNs = 0.38` for a ~1.4 m circle and 0.07 m saka. [ASSUMED]

### dyn4j burst + score (authority)

```java
// Source: dyn4j getting-started + advanced (World.step, isAtRest, applyImpulse)
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
int pocketed = countFullyOutside(world, CIRCLE_R); // center dist > R + radius
boolean sakaOut = isFullyOutside(saka, CIRCLE_R);
int score = sakaOut ? 0 : pocketed;
```

[CITED: dyn4j.org/pages/advanced.html] [CITED: javadoc.io 6.0.0 PhysicsBody.applyImpulse / isAtRest]

### Replay lerp

```dart
// Source: Gaffer snapshot interpolation applied to a closed buffer (PITFALLS / ARCHITECTURE)
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

### FPS HUD

```dart
// Source: docs.flame-engine.org/latest/flame/other/debug.html
camera.viewfinder.add(FpsTextComponent());
debugMode = true; // optional body outlines
```

Profile run: `flutter run --profile` then `P` or DevTools Performance Overlay. [CITED: docs.flutter.dev/perf/ui-performance]

### 2.5D tilt (presentation only)

Physics circle stays circular. Fake tilt with a **render-only** `scale.y ≈ 0.86` on a presentation layer (or slight `viewfinder.angle`). Do not squash colliders. [ASSUMED — Flame has no 3D camera; `CameraComponent` viewfinder is 2D zoom/angle. CITED: docs.flame-engine.org/latest/flame/camera.html]

## Shared ThrowInput schema (Dart ↔ Java)

Canonical file: UTF-8 JSON. Units: meters, radians, milliseconds. `yUp: true`.

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

`TableConstants` (same object embedded in every `ThrowResolved`, also a Dart/Java const class):

| Field | Phase-1 value | Notes |
|-------|----------------|-------|
| `circleRadiusM` | 1.40 | [ASSUMED] tune so 6 bones + saka read on a phone |
| `sakaRadiusM` | 0.07 | Distinct, brighter |
| `boneRadiusM` | 0.055 | Disk; capsule allowed if spin still reads |
| `sakaMassKg` | 0.12 | Heavier shooter |
| `boneMassKg` | 0.055 | |
| `friction` | 0.30 | |
| `restitution` | 0.38 | |
| `linearDamping` | 1.15 | Table friction stand-in |
| `angularDamping` | 0.85 | Spin remains visible then dies |
| `impulseMinNs` / `impulseMaxNs` | 0.06 / 0.38 | Maps 150–1100 ms |
| `physicsHz` | 60 | Both engines |
| `keyframeHz` | 20 | 3 physics steps / frame |
| `settleTimeoutS` | 1.2 | D-09 |
| `boneCount` | 6 | D-01 |

`ThrowResolved` (harness output only):

```json
{
  "schemaVersion": 1,
  "yUp": true,
  "input": { "...ThrowInput" },
  "table": { "...TableConstants" },
  "settled": true,
  "settleReason": "sleep",
  "simMs": 780,
  "pocketedCount": 2,
  "sakaOut": false,
  "pocketedIds": ["b2", "b5"],
  "keyframes": [
    { "tMs": 0, "bodies": [{ "id": "saka", "x": 0.0, "y": -1.15, "angle": 0.0 }] }
  ]
}
```

**Clamp on both sides:** `holdMs` → `[150, 1100]`; `aimAngleRad` must be finite; reject NaN/Inf. `seed` reserved (cluster layout); Phase 1 may use a fixed hex-cluster.

**Replay matching:** Replay runs only if `ThrowResolved.input` equals the last committed `ThrowInput` (or the baked golden). Mismatch → disable Replay and keep `scored` blank.

**Device handoff (no REST):**

1. After a throw, write `throw_input.json` to app documents (and log it).
2. Developer: `adb pull` → `mvnw -q exec:java -Dexec.args="throw_input.json throw_resolved.json"` → `adb push` into documents **or** drop onto `assets/replays/`.
3. Ship `assets/replays/golden_throw.json` so Replay works on first install.
4. JUnit asserts a fixture `ThrowInput` → stable `pocketedCount` + keyframe count > 2.

## Discretion recommendations (planner should lock these)

| Topic | Use | Why |
|-------|-----|-----|
| Physics Hz | **1/60**, subStepCount 4 on Forge2D | Matches Flame default substeps; dyn4j one `step(1)` per 1/60 |
| Keyframe rate | **20 Hz** JSON | Enough for lerp; few KB |
| Schema | **JSON**, not binary | Debuggable adb dumps |
| Harness | **CLI + JUnit** | CLI for device Replay; JUnit for PROTO-02 automation |
| Forge2D pin | **0.15.1 / 0.20.0 first** | Production family. Fallback 0.14 only after a real NDK failure |
| HUD | Flame `FpsTextComponent` + Flutter text for settle/bodies/score | D-02 |
| Reset | Snap cluster to spawn, wake bodies, clear Replay pointer | No animation required |
| Pocket test | Entire disk outside: `distance(center, origin) > circleR + bodyR` | Matches “fully outside” |

## NDK / Windows native assets

| Target | Toolchain | Status on this machine |
|--------|-----------|------------------------|
| Android APK + Forge2D 0.15 | Android SDK + **NDK 28.2.13676358** | **Missing** (no ANDROID_HOME / SDK) |
| `flutter run -d windows` + 0.15 | Visual Studio Build Tools (MSVC) | **Missing** |
| JVM harness | Corretto **21.0.11** at `~/.jdks/corretto-21.0.11` | **Present**, not on PATH |
| Maven | `mvn` | **Missing** — add Maven Wrapper in `harness/` |

[CITED: pub.dev/packages/forge2d Requirements] [CITED: flutter 3.47 Android matrix] [VERIFIED: local probe 2026-09-05]

**Wave 0 (blocking):** install Flutter 3.47 stable, Android Studio (SDK platform 36, cmdline-tools, emulator), NDK 28.2.13676358, put Corretto 21 on PATH for Gradle, generate `harness/mvnw`. Then `flutter doctor -v` must be green for Android.

**0.14 fallback trigger:** native-assets / NDK compile fails after a documented install attempt. Same `ThrowInput` and Replay path. Do not reopen Unity.

## How to prove ~60 FPS (PROTO-01)

1. **In-game:** `FpsTextComponent` on the viewfinder. Gate: **≥ 55** average during aim + throw + settle + Replay, 7 bodies. Flame FPS is the loop truth. [CITED: docs.flame-engine.org/latest/flame/other/debug.html]
2. **Flutter overlay:** `flutter run --profile` on a **physical** mid-range device; enable Performance Overlay (`P` or DevTools). No sustained red bars over the 16 ms line. [CITED: docs.flutter.dev/perf/ui-performance]
3. **HUD extras (D-02):** body count, `settled` flag, physics step Hz, last `holdMs`.
4. **Emulator:** allowed for functional QA; **not** sufficient alone for the FPS gate.
5. **If fill-rate bound:** drop shadows / `saveLayer` clips; keep 20 Hz keyframes; do not raise keyframe rate. [CITED: STACK.md / Flutter saveLayer notes on perf page]

Mid-range definition (discretion): Snapdragon 6/7 class 2022–2024 or equivalent; do not require a flagship.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| forge2d 0.14 pure Dart Box2D 2.x | forge2d 0.15 Box2D v3 FFI + native assets | 0.15 / flame_forge2d 0.20 (2026-08) | Must `initializeForge2D()`; `createShape`; NDK; ~18× bench2d speedup [CITED: pub.dev/packages/forge2d] |
| `World()` gravity 0 in old Forge2D | `World()` gravity `(0,-10)` | 0.15 | Top-down **must** pass `Vector2.zero()` |
| flame_forge2d zoom=10 as scale | `metersToPixels` decoupled from camera zoom | 0.20 | Set meters, then pixels/meter |
| jbox2d on JVM | dyn4j 6.0.0 | 2026 stack research | Do not use jbox2d |
| Lockstep two phones | Input → burst sim → Replay | Product lock | Phase 1 proves the path |

**Deprecated/outdated:**
- Flame Forge2D docs that show `FixtureDef` / `createFixture` (0.19).
- dyn4j getting-started Maven snippet still showing **5.0.2** — pin **6.0.0**. [CITED: dyn4j.org/pages/getting-started.html vs Maven Central 6.0.0]
- Spring Boot / Postgres as “Phase 1 backend”.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Starting masses / radii / impulse range (table above) | Shared schema | Throw too weak/strong; one tuning pass on device |
| A2 | 2.5D via render `scale.y ≈ 0.86` (no 3D camera) | Patterns | Owner wants a stronger tilt — still presentation-only |
| A3 | File + golden Replay is enough (no localhost HTTP) | Authority | If owner wants one-tap Replay after every throw without adb, add a later debug pull script — still not Spring |
| A4 | Physical mid-range Android is available for the FPS gate | Env / Validation | Gate uses emulator + “device when available”; record the gap |
| A5 | JUnit Jupiter **6.1.3** is acceptable on Java 21 | Stack | If wrapper/plugin issues, fall back to 5.13.x BOM — same tests |
| A6 | Cluster layout can be a fixed hex (seed unused) | Schema | Replay still works; seed needed when bots exist (Phase 2) |

## Open Questions (RESOLVED)

1. **Is a physical mid-range Android available this week?**
   - What we know: D-03 allows emulator + device if available. Flutter docs say profile-on-device is the real FPS proof.
   - Recommendation: Planner includes a device checkpoint; emulator is a fallback with the gap recorded.
   - RESOLVED: Device proof is the 01-05 human-check (`flutter run --profile` on a physical mid-range Android). Emulator is functional QA only and does not pass PROTO-01 alone.

2. **Who installs Flutter / Android SDK / NDK?**
   - What we know: none of these are on PATH now. Corretto 21 exists.
   - Recommendation: Wave 0 human install; do not start `flutter create` until `flutter doctor` Android is green.
   - RESOLVED: 01-01 Task 1 installs Flutter 3.47, Android SDK platform 36, NDK 28.2.13676358, and writes `scripts/dev-env.ps1`. `flutter create` runs only after `flutter doctor` Android is usable.

3. **Replay UX without adb every throw**
   - What we know: D-10 requires Replay of JVM frames after a throw.
   - Recommendation: golden asset always; plus documents-dir import. Optional tiny `scripts/replay.ps1` that pull/run/push. No REST.
   - RESOLVED: 01-05 ships `scripts/replay.ps1` (adb pull → `mvnw exec:java` → adb push) plus baked `assets/replays/golden_throw.json` so first-install Replay works without adb. No REST.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Flutter SDK 3.47 | PROTO-01 client | ✗ | — | Install stable 3.47 (blocking) |
| Dart 3.13 | client | ✗ (comes with Flutter) | — | With Flutter |
| Android SDK + platform 36 | Android APK | ✗ | — | Install Android Studio (blocking for device gate) |
| Android NDK 28.2.13676358 | Forge2D 0.15 native | ✗ | — | Install NDK **or** Forge2D 0.14 fallback |
| VS Build Tools (MSVC) | Windows desktop target | ✗ | — | Skip Windows desktop; use Android / emulator |
| JDK 21 | harness | ✓ (not on PATH) | Corretto 21.0.11 | Add `~/.jdks/corretto-21.0.11/bin` to PATH |
| Maven | harness build | ✗ | — | Maven Wrapper in `harness/` |
| Node | unused for product | ✓ | PATH | — |
| Physical mid-range Android | PROTO-01 FPS | unknown | — | Emulator + record gap |
| iOS / Xcode | not required | n/a (Windows) | — | Skip (D-03) |

**Missing dependencies with no fallback:** Flutter 3.47, Android SDK (for the Android gate).
**Missing dependencies with fallback:** NDK → Forge2D 0.14; physical device → emulator + explicit incomplete-FPS note; global Maven → wrapper; MSVC → do not target Windows desktop.

**Step 2.6:** NOT skipped — external toolchains are required.

## Validation Architecture

Nyquist is enabled (`workflow.nyquist_validation` is true).

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Flutter `flutter_test` (client) + JUnit Jupiter 6.1.3 (harness) |
| Config file | none yet — Wave 0 creates `client/` and `harness/` |
| Quick run command | `cd harness && mvnw -q test` and `cd client && flutter test` |
| Full suite command | both of the above + manual Android profile checklist |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| PROTO-01 | Aim + hold-to-throw + readable collisions ~60 FPS | unit (clamp/impulse) + **manual device** | `flutter test test/throw_input_test.dart` | ❌ Wave 0 |
| PROTO-01 | Fixed dt: 30 vs 60 FPS local stepper uses same step count | unit | `flutter test test/physics_stepper_test.dart` | ❌ Wave 0 |
| PROTO-01 | FPS readable on HUD | manual-only | `flutter run --profile` + Flame FPS ≥ 55 | n/a (device) |
| PROTO-02 | Same `ThrowInput` → closed keyframes + score | unit | `mvnw -q test -Dtest=BurstSimTest` | ❌ Wave 0 |
| PROTO-02 | Timeout 1.2s still emits frames + score | unit | `BurstSimTest.timeoutStillScores` | ❌ Wave 0 |
| PROTO-02 | Harness JSON rejects / ignores client poses | unit | `BurstSimTest.outputHasNoClientPosesField` | ❌ Wave 0 |
| PROTO-02 | Replay uses JVM `pocketedCount` only | integration + manual | golden asset Replay; HUD `scored` == file | ❌ Wave 0 |
| PROTO-02 | Forged `pocketedCount` written by a fake client file is not mixed into harness output | unit | harness never reads a score field from input | ❌ Wave 0 |

### Sampling Rate

- **Per task commit:** `mvnw -q test` and/or `flutter test` for the touched tree
- **Per wave merge:** both suites green
- **Phase gate:** suites green **and** the manual Android/profile checklist below

### Wave 0 Gaps

- [ ] Install Flutter 3.47 + Android SDK + NDK 28.2.13676358; `flutter doctor` Android green
- [ ] `flutter create --org com.nomadgames --platforms=android,ios client` (no extra pubs except Flame/Forge2D)
- [ ] `harness/` Maven Wrapper + `pom.xml` (dyn4j 6.0.0, JUnit 6.1.3, Java 21)
- [ ] `client/test/throw_input_test.dart` — clamp 150–1100, impulse monotonic
- [ ] `client/test/physics_stepper_test.dart` — accumulator never steps with raw frame dt
- [ ] `client/test/replay_score_test.dart` — HUD score helper reads only `ThrowResolved.pocketedCount`
- [ ] `harness/src/test/java/.../BurstSimTest.java` — fixture throw → frames + score; timeout path
- [ ] `assets/replays/golden_throw.json` produced by the harness, not by hand-edited poses

### Observe to know PROTO-01 passed

1. Mid-range Android (or recorded emulator fallback): aim arrow rotates around the saka; **separate** Hold button charges a visible meter (0.15–1.1 s, hold-at-max).
2. Release knocks bones: mass contrast (saka vs bone), collisions, **visible spin**, sliding friction, bounce (restitution) are obvious on a felt circle with a flashing rim.
3. Six bones, Reset restores the cluster.
4. Flame FPS HUD ≥ 55 during the throw; profile overlay without sustained red 16 ms bars.
5. Bodies sleep or hit 1.2 s; +1 / pocketed preview only **after** settle.

### Observe to know PROTO-02 passed

1. A `ThrowInput` JSON from the client (or fixture) run through the harness produces `ThrowResolved` with `keyframes.length >= 3` and `pocketedCount` / `sakaOut` set by **dyn4j rest poses**.
2. Device Replay interpolates those frames (golden or imported). Motion is the JVM track; if local preview diverges, keyframes win.
3. The number labeled **scored** equals `ThrowResolved.pocketedCount` and is **not** computed from Forge2D rest poses.
4. There is no API/field that lets the client submit a score. JUnit fixture is deterministic enough to assert score + frame count (not bit-identical vs Forge2D).

## Security Domain

`security_enforcement` is enabled (ASVS L1). This phase has no auth, sessions, or network. Still apply input validation on the schema boundary.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | No login (D-02) |
| V3 Session Management | no | No sessions |
| V4 Access Control | no | Single-player sandbox |
| V5 Input Validation | yes | Clamp `holdMs`, reject non-finite `aimAngleRad`; schemaVersion must be 1; ignore unknown fields; never `eval` JSON |
| V6 Cryptography | no | No tokens. Do not add JWT “for later” |

### Known Threat Patterns for this slice

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Client-authored score / rest poses | Tampering / Spoofing | Harness is the only writer of `pocketedCount`; Replay reads JVM file only |
| Pathological JSON (huge arrays, NaN) | Denial of service | Cap keyframe count (e.g. 40), body count (8), reject NaN |
| File drop as code | Tampering | Parse as data; no isolate/spawn from Replay files |
| Lockstep cheat later | Elevation of privilege | Do not build a client scorer “to finish later” |

## Sources

### Primary (HIGH authority pages; seam transport often LOW)

- https://docs.flutter.dev/release/release-notes — Flutter 3.47.0 current stable
- https://flutter.dev/blog/whats-new-in-flutter-3-47 — Dart 3.13, Android matrix (Java 17, AGP 9.1.0, Gradle 9.3.1, minSdk 24)
- https://pub.dev/packages/flame — 1.38.2
- https://pub.dev/packages/forge2d — 0.15.1, units, gravity default, `initializeForge2D`, NDK/MSVC
- https://pub.dev/packages/flame_forge2d — 0.20.0, migration from 0.19
- https://github.com/flame-engine/flame/releases/tag/flame_forge2d-v0.20.0 — 2026-08-17
- https://github.com/flame-engine/flame/issues/3952 — Box2D v3 migrate, `metersToPixels`, `step(dt, subStepCount:)`
- https://raw.githubusercontent.com/flame-engine/flame/main/packages/flame_forge2d/lib/forge2d_world.dart — variable-dt `update`
- https://docs.flame-engine.org/latest/flame/game.html — `GameWidget`, do not construct game in `build`
- https://docs.flame-engine.org/latest/flame/other/debug.html — `FpsTextComponent`
- https://docs.flame-engine.org/latest/flame/camera.html — viewfinder / HUD on viewport
- https://docs.flutter.dev/perf/ui-performance — profile mode, physical device, overlay
- https://central.sonatype.com/artifact/org.dyn4j/dyn4j — 6.0.0
- https://dyn4j.org/pages/getting-started.html — MKS, `World.update` vs `step`, stale 5.0.2 snippet
- https://dyn4j.org/pages/advanced.html — zero-g via `setGravity`, at-rest, impulses immediate, headless `step` loop
- https://javadoc.io/static/org.dyn4j/dyn4j/6.0.0/org.dyn4j/org/dyn4j/dynamics/PhysicsBody.html — `applyImpulse`, `isAtRest`
- https://central.sonatype.com/artifact/org.junit.jupiter/junit-jupiter — 6.1.3
- `.planning/research/STACK.md`, `ARCHITECTURE.md`, `PITFALLS.md`, `FEATURES.md`, `SUMMARY.md`
- `.planning/phases/01-alchiki-physics-prototype/01-CONTEXT.md`

### Secondary (MEDIUM)

- https://github.com/flame-engine/flame/issues/2750 — FPS-coupled impulse/damping (0.14-era; still the variable-`dt` lesson)
- Flutter engine `android_ndk_version = "28.2.13676358"`
- Gaffer snapshot interpolation (via project PITFALLS) — playback, not live UDP

### Tertiary (LOW)

- Context7 unavailable; `gsd-tools query research-plan` failed to parse a Windows temp JSON this session
- npm legitimacy seam (wrong ecosystem) — ignored for disposition of Dart/Java packages
- Exact parlor masses / 2.5D scale factor — [ASSUMED]

## Metadata

**Confidence breakdown:**
- Standard stack: MEDIUM — first-party pub.dev / docs.flutter.dev / Maven Central fetched; seam `webfetch` = LOW, `websearch --verified` = MEDIUM
- Architecture: HIGH for the locked path (CONTEXT D-01–D-11 + ARCHITECTURE input→sim→replay); MEDIUM for Replay file handoff UX
- Pitfalls: MEDIUM — official units/sleep/gravity + flame#2750 + 0.20 source showing variable `dt`

**Research date:** 2026-09-05
**Valid until:** 30 days for Flutter/Flame/dyn4j pins (fast-moving around 0.20)

**Commit:** skipped (orchestrator / user: do not commit)
