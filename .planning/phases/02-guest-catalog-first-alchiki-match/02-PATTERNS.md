# Phase 2: Guest Catalog + First Alchiki Match - Pattern Map

**Mapped:** 2026-09-06
**Files analyzed:** 34
**Analogs found:** 22 / 34

Phase 1 already owns the throw/replay/score wire. Phase 2 **lifts** that stack into a match and **introduces** Spring + catalog/i18n/router — those last three have no in-repo analog. Planner must copy Phase 1 excerpts below and use RESEARCH.md snippets only for greenfield files.

Do **not** copy CR-01 (`_holdEnabled` without `game.isLoaded`) or CR-02 (`AuthorityScore.readPocketedCount` as HUD `scored`).

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `client/lib/main.dart` | config | request-response | `client/lib/main.dart` | exact (modify) |
| `client/pubspec.yaml` | config | — | `client/pubspec.yaml` | exact (modify) |
| `client/l10n.yaml` | config | transform | — | greenfield |
| `client/lib/l10n/app_en.arb` | config | transform | — | greenfield |
| `client/lib/l10n/app_ru.arb` | config | transform | — | greenfield |
| `client/lib/platform/router.dart` | route | request-response | `client/lib/main.dart` | partial |
| `client/lib/platform/splash_page.dart` | component | request-response | `client/lib/sandbox_page.dart` (palette / empty / error) | role-match |
| `client/lib/platform/api/nomad_api.dart` | service | request-response | `client/lib/sandbox_page.dart` file persist (wrong transport) | partial |
| `client/lib/platform/auth/session_store.dart` | store | file-I/O | `client/lib/sandbox_page.dart` `_persistThrowInput` | partial |
| `client/lib/catalog/catalog_page.dart` | component | request-response | `client/lib/sandbox_page.dart` chrome / `_TableButton` | role-match |
| `client/lib/howto/alchiki_howto_page.dart` | component | request-response | `client/lib/sandbox_page.dart` empty-state overlay | role-match |
| `client/lib/games/alchiki/match_page.dart` | component | request-response | `client/lib/sandbox_page.dart` | exact |
| `client/lib/games/alchiki/match_game.dart` | component | event-driven | `client/lib/game/alchiki_sandbox_game.dart` | exact |
| `client/lib/sandbox_page.dart` | component | event-driven | itself (demote off home) | exact (modify) |
| `client/lib/replay/authority_score.dart` | utility | transform | itself + Java `ThrowResolved.displayedScore()` | exact (fix) |
| `client/lib/replay/throw_resolved.dart` | model | transform | itself + `harness/.../ThrowResolved.java` | exact (fix) |
| `client/lib/schema/table_constants.dart` | config | — | itself + `harness/.../TableConstants.java` | exact |
| `client/lib/input/throw_input.dart` | model | transform | itself + `harness/.../ThrowInput.java` | exact (keep) |
| `client/android/app/src/main/AndroidManifest.xml` | config | — | itself | exact (modify) |
| `client/test/widget_test.dart` | test | request-response | itself | exact (rewrite) |
| `client/test/catalog_test.dart` | test | request-response | `client/test/widget_test.dart` | role-match |
| `client/test/howto_test.dart` | test | request-response | `client/test/widget_test.dart` | role-match |
| `client/test/match_hold_test.dart` | test | event-driven | `client/test/widget_test.dart` + sandbox `_holdEnabled` | role-match |
| `client/test/replay_score_test.dart` | test | transform | itself | exact (extend) |
| `pom.xml` (repo root aggregator) | config | — | `harness/pom.xml` | role-match |
| `backend/pom.xml` | config | — | `harness/pom.xml` | role-match |
| `backend/.../NomadGamesApplication.java` | config | request-response | `harness/.../HarnessMain.java` | partial |
| `backend/.../identity/**` | controller + service | CRUD | — | greenfield |
| `backend/.../catalog/**` | controller + service | request-response | — | greenfield |
| `backend/.../session/**` | controller + service | request-response | `HarnessMain` + `Dyn4jBurstSim.simulate` | partial |
| `backend/.../games/alchiki/**` | service | batch | `harness/.../Dyn4jBurstSim.java` | exact |
| `backend/.../db/migration/V1__*.sql` | migration | CRUD | — | greenfield |
| `backend/src/main/resources/application.yaml` | config | — | — | greenfield |
| `harness/.../Dyn4jBurstSim.java` | service | batch | itself | exact (extend spawn + WR-02) |
| `harness/.../BurstSimTest.java` | test | batch | itself | exact (extend) |

Files that stay as-is and are **imported, not rewritten:** `client/lib/replay/keyframe_player.dart`, `client/lib/game/felt_circle.dart`, `client/lib/game/saka_body.dart`, `client/lib/game/bone_body.dart`, `client/lib/input/aim_controller.dart`, `client/lib/game/physics_stepper.dart`, `harness/.../ThrowInput.java`, `harness/.../JsonSupport.java`, `scripts/dev-env.ps1`.

## Pattern Assignments

### `client/lib/main.dart` (config, request-response)

**Analog:** `client/lib/main.dart` (current home is the thing to replace)

**Imports / bootstrap** (lines 1–15):
```dart
import 'package:flutter/material.dart';

import 'sandbox_page.dart';

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

**Copy:** keep `WidgetsFlutterBinding.ensureInitialized()` as the first line of `main()`.
**Do not copy:** `MaterialApp(home: SandboxPage())` — CAT-01 / D-17. New shell is `ProviderScope` + `MaterialApp.router` from RESEARCH Pattern 5 / gen-l10n example. Optional `/debug/sandbox` may wrap `SandboxPage`; it must not be `initialLocation`.

---

### `client/lib/games/alchiki/match_page.dart` (component, request-response)

**Analog:** `client/lib/sandbox_page.dart`

**Imports pattern** (lines 1–11):
```dart
import 'dart:async';
import 'package:client/game/alchiki_sandbox_game.dart';
import 'package:client/input/throw_input.dart';
import 'package:client/replay/authority_score.dart';
import 'package:client/replay/throw_resolved.dart';
import 'package:client/schema/table_constants.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
```

**Palette / type tokens** (lines 23–46) — copy hexes and the four styles verbatim (01-UI-SPEC / PRES-02):
```dart
static const Color _surround = Color(0xFF241810);
static const Color _onDark = Color(0xFFF4E8C8);
static const Color _accent = Color(0xFFF0B429);
static const Color _onAccent = Color(0xFF241810);
static const Color _destructive = Color(0xFFC43C2C);

static const TextStyle _label = TextStyle(
  color: _onDark, fontSize: 14, fontWeight: FontWeight.w600, height: 1.2,
);
static const TextStyle _body = TextStyle(
  color: _onDark, fontSize: 16, fontWeight: FontWeight.w400, height: 1.5,
);
static const TextStyle _heading = TextStyle(
  color: _onDark, fontSize: 20, fontWeight: FontWeight.w600, height: 1.2,
);
```

**Hold Throw chrome** (lines 173–223, 478–519) — Flutter owns charge; Flame owns aim:
```dart
void _startCharge() {
  if (!_holdEnabled) { return; }
  // ...
  game.aimLocked = true;
}

Future<void> _releaseCharge() async {
  final holdMs = _rawHoldMs.clamp(TableConstants.holdMsMin, TableConstants.holdMsMax);
  final input = ThrowInput(
    schemaVersion: 1,
    yUp: true,
    aimAngleRad: game.aim.aimAngleRad,
    holdMs: holdMs,
    seed: 1,
    tableId: TableConstants.tableId,
  );
  await _persistThrowInput(input); // REPLACE with REST POST /v1/matches/{id}/throws
  game.throwSaka(input);           // local preview only
}
```

**CR-01 — do not copy line 131.** Current (buggy):
```dart
bool get _holdEnabled => !_throwing && !_settled && !_replaying;
```
Use the 01-REVIEW fix + match extras:
```dart
bool get holdEnabled =>
    game.isLoaded && !throwing && !settled && !replaying && isPlayerTurn;
```

**Scaffold / GameWidget** (lines 378–382):
```dart
return Scaffold(
  backgroundColor: _surround,
  body: Stack(
    children: [
      GameWidget.controlled(gameFactory: () => game),
```

**Power meter** (lines 678–701) — copy `_PowerMeter` as-is (8px track, accent fill, 16px inset).

**Error banner** (lines 634–675) — copy `_ReplayErrorBanner` structure (destructive border, heading + body) for guest/catalog/throw errors. Replace hardcoded English with ARB getters.

**Do not copy as product chrome:** Reset Table / Replay Throw buttons (lines 450–476), file-watch `_pollImportedResolved` (lines 260–284), `_documentsDir` persist (lines 342–367). Product match submits REST and replays the response buffer. Debug HUD (lines 531–571) stays debug-only.

**CR-02 — do not copy lines 321–327:**
```dart
final scored = AuthorityScore.readPocketedCount(resolved, lastInput: _lastInput);
```
Match HUD `scored` must call `ThrowResolved.displayedScore()` (or a fixed `AuthorityScore` that returns `sakaOut ? 0 : pocketedCount`) from the REST body only.

---

### `client/lib/games/alchiki/match_game.dart` (component, event-driven)

**Analog:** `client/lib/game/alchiki_sandbox_game.dart`

**Forge2D world + zero-g** (lines 27–45):
```dart
class FixedDtWorld extends Forge2DWorld {
  final PhysicsStepper stepper = PhysicsStepper();
  @override
  void update(double dt) {
    stepper.tick(dt, physicsWorld.stepDt);
  }
}

class AlchikiSandboxGame extends Forge2DGame {
  AlchikiSandboxGame()
    : super(
        gravity: Vector2.zero(),
        world: FixedDtWorld(gravity: Vector2.zero()),
        zoom: 100,
      );
```

**Seed-1 hex — keep collider family** (lines 47–56). Vary **count** by difficulty, not radii:
```dart
static final Map<String, Vector2> seed1Bones = {
  'b1': Vector2(0.22, 0.0),
  'b2': Vector2(0.11, 0.19053),
  'b3': Vector2(-0.11, 0.19053),
  'b4': Vector2(-0.22, 0.0),
  'b5': Vector2(-0.11, -0.19053),
  'b6': Vector2(0.11, -0.19053),
};
```
RESEARCH A1: EASY drop `b5`+`b6` (5 bones); NORMAL = this hex; HARD add `b7` at `(0,0)`. Saka spawn stays `SakaBody.spawn` `(0, -1.15)`.

**onLoad table assembly** (lines 92–126):
```dart
await initializeForge2D();
await super.onLoad();
camera.viewfinder.anchor = Anchor.center;
// parlor + felt + saka + bones + AimArrow + TableDragLayer
```

**Preview settle (not scored)** (lines 232–258):
```dart
sakaOut = isFullyOutside(sakaPos.x, sakaPos.y, TableConstants.circleRadiusM, TableConstants.sakaRadiusM);
// increment previewCount + PlusOnePopup — HUD prefix must stay "preview"
```

**Replay overwrite (D-10)** (lines 148–184):
```dart
KeyframePlayer.applyFrame(replayTimeMs, resolved.keyframes, _replayTargets);
```

**throwSaka** (lines 293–300) — add CR-01 `isLoaded` guard from 01-REVIEW:
```dart
void throwSaka(ThrowInput input) {
  if (!isLoaded) { return; }
  cancelReplay();
  throwing = true;
  tableSettled = false;
  simTimeS = 0;
  aimLocked = true;
  saka.applyThrowImpulse(input);
}
```

**WR-01:** do not copy `simTimeS += dt` (line 136). Advance `simTimeS` by `PhysicsStepper.step` per actual physics step (see `client/lib/game/physics_stepper.dart` lines 1–19).

**Aim / drag** (lines 364–416) — copy `AimArrow` (fixed length 0.42 m, cream `#F4E8C8`) and `TableDragLayer` (`aimLocked` early-return). Hide arrow until bot aim animates on bot turn.

**Bodies to import, not rewrite:** `SakaBody.applyThrowImpulse` (`saka_body.dart` 43–50), `BoneBody` + `isFullyOutside` (`bone_body.dart` 8–15), `AimController` (`aim_controller.dart` 6–18).

---

### `client/lib/catalog/catalog_page.dart` (component, request-response)

**Analog:** `client/lib/sandbox_page.dart` chrome only — there is no catalog widget today.

**Copy:** `_surround` / `_onDark` / `_accent` / `_TableButton` (lines 574–628) for Play Alchiki (accent fill) and Coming Soon tiles (wood fill, no `onTap` navigation). Empty/error: `_ReplayErrorBanner` layout (destructive border + heading/body + later Retry).

**Do not copy:** `GameWidget`, Hold Throw, Reset/Replay.
**Greenfield from RESEARCH / UI-SPEC:** three stacked tiles, EN/RU toggle, EASY default chips, Coming Soon tap is a no-op.

---

### `client/lib/howto/alchiki_howto_page.dart` (component, request-response)

**Analog:** `client/lib/sandbox_page.dart` empty-state overlay (lines 417–440) for wood page + heading/body stack.

```dart
Text('Table reset', style: _heading),
SizedBox(height: 8),
Text('Drag around the saka…', style: _body, textAlign: TextAlign.center),
```

Replace copy with ARB keys `howtoCircleTitle` / `howtoCircleBody` … (UI-SPEC five cards). Skip/Next/Play use `_TableButton`. Persist `howto.alchiki.seen` via `SharedPreferencesAsync` (no analog — RESEARCH Pattern 5). Skip must exist on card 1 (D-13).

---

### `client/lib/platform/splash_page.dart` (component, request-response)

**Analog:** same palette + `_ReplayErrorBanner` for mint failure. No existing splash.

Copy `_surround` fill and `_heading` cream wordmark. Felt disk `#1B6B3A` has no widget analog — new, 96dp, no accent. Silent `POST /v1/identity/guest` after `ensureInitialized`; no username field (D-16).

---

### `client/lib/platform/router.dart` (route, request-response)

**Analog:** `client/lib/main.dart` line 14 (`MaterialApp(home:)`) — only the “app owns one root route” idea.

No `go_router` in repo. Use RESEARCH snippet (do not invent a second router):
```dart
final router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (_, __) => const CatalogPage()),
    GoRoute(path: '/howto/alchiki', builder: (_, __) => const AlchikiHowToPage()),
    GoRoute(
      path: '/match',
      builder: (_, state) => AlchikiMatchPage(
        difficulty: state.uri.queryParameters['difficulty'] ?? 'EASY',
      ),
    ),
  ],
);
```
Optional: `GoRoute(path: '/debug/sandbox', …)` wrapping existing `SandboxPage`. Never link it from catalog.

---

### `client/lib/platform/api/nomad_api.dart` (service, request-response)

**Analog (transport to replace):** `sandbox_page.dart` `_persistThrowInput` + `_pollImportedResolved` (lines 260–353) — client writes `ThrowInput.toJsonString()`, later parses `ThrowResolved.parse`. Phase 2 does the same DTO over REST.

**Wire contract to keep:** `client/lib/input/throw_input.dart` `toJson()` (lines 64–73) and `ThrowInput.parse` ignore-unknown / clamp-hold (lines 25–54). Java twin: `harness/.../ThrowInput.parse` (lines 46–70) — unknown keys including `pocketedCount` / `score` are ignored.

**Do not copy:** `File` / `Directory` / adb documents path. `scripts/replay.ps1` is the old offline loop; match path is `POST /v1/matches/{id}/throws` (RESEARCH Pattern 2). Body = `ThrowInput` fields only. Parse `playerThrow` / `botThrow` with existing `ThrowResolved.parseMap`.

Dio + second refresh client: **greenfield** (RESEARCH Dio excerpt). No HTTP client exists in `client/`.

---

### `client/lib/platform/auth/session_store.dart` (store, file-I/O)

**Analog:** `sandbox_page.dart` `_persistThrowInput` try/catch + `debugPrint` (lines 342–353) — swallow IO, do not crash the throw.

**Do not store tokens in SharedPreferences.** RESEARCH Pattern 6: `FlutterSecureStorage()` default options for `playerId` + refresh; access JWT in Riverpod memory; how-to seen + locale in `SharedPreferencesAsync`.

---

### `client/lib/replay/throw_resolved.dart` + `authority_score.dart` (model / utility, transform)

**Analog (correct score rule):** `harness/src/main/java/com/nomadgames/alchiki/proto/ThrowResolved.java` lines 59–62:
```java
public int displayedScore() {
    return sakaOut ? 0 : pocketedCount;
}
```

**Dart parser today** (`throw_resolved.dart` 42–91) never reads `sakaOut`. Add the 01-REVIEW CR-02 parse:
```dart
final sakaOut = json['sakaOut'];
if (sakaOut is! bool) {
  throw const FormatException('sakaOut must be a boolean');
}
```

**Do not ship** `AuthorityScore.readPocketedCount` as HUD scored (`authority_score.dart` 8–19). Either rename to `displayedScore` or change the return to `resolved.sakaOut ? 0 : resolved.pocketedCount`. Caps stay: `maxKeyframes = 40`, `maxBodies = 8` (lines 8–9).

**Ignore-unknown:** `parseMap` only reads known keys — keep that for SESS-01 / T-01-01. Client must never send `pocketedCount` / `score` / `winner`.

---

### `client/lib/input/throw_input.dart` + `client/lib/schema/table_constants.dart`

**Keep as the REST body.** Parse/clamp (`throw_input.dart` 25–54, 96–106) already matches Java `ThrowInput`.

`TableConstants.tableId` is `'alchiki-proto-v1'` (line 23). RESEARCH A7: match REST uses `alchiki-match-v1`; harness CLI/golden keep proto id. Add a second constant — do not retarget golden fixtures.

Physics numbers (lines 5–22) must stay bit-identical to `harness/.../TableConstants.java` 8–22.

---

### `client/pubspec.yaml` + `client/l10n.yaml` (config)

**Analog:** `client/pubspec.yaml` pins (lines 30–41):
```yaml
  flame: 1.38.2
  flame_forge2d: 0.19.3+7
  forge2d: 0.14.2
```
Do **not** bump Forge2D. Add RESEARCH packages beside these; set `flutter: generate: true`. `l10n.yaml` is greenfield (RESEARCH gen-l10n block).

---

### `client/android/app/src/main/AndroidManifest.xml` (config)

**Analog:** itself (lines 1–6). Application tag currently has no `allowBackup` / cleartext:
```xml
<application
    android:label="client"
    android:name="${applicationName}"
    android:icon="@mipmap/ic_launcher">
```

Add `android:allowBackup="false"` (RESEARCH Pattern 6). Debug cleartext for emulator `10.0.2.2` belongs on `android/app/src/debug/AndroidManifest.xml` (existing debug overlay), not release.

---

### Tests (client)

**Analog for new widget tests:** `client/test/widget_test.dart` (lines 1–13):
```dart
import 'package:client/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('SandboxApp shows empty-state copy', (WidgetTester tester) async {
    await tester.pumpWidget(const SandboxApp());
    expect(find.text('Table reset'), findsOneWidget);
  });
}
```
Rewrite this file when home becomes catalog — it **will fail** if left as-is.

**Analog for score tests:** `client/test/replay_score_test.dart`. Fixture already embeds `"sakaOut": false` (line 53) but never asserts the true path. Copy `_resolvedJson` helper (lines 9–58); add `sakaOut: true, pocketedCount: 2` → displayed `0`. Keep ignore-forged test (lines 114–123).

**Analog for throw validation:** `client/test/throw_input_test.dart` (clamp 150/1100, reject NaN, schemaVersion 1) — REST client tests should reuse these cases, not re-implement clamp.

**Analog for settle:** `client/test/pocket_settle_test.dart` — keep green; match bone-count tests should still use `isFullyOutside` / `computeSettled`.

`catalog_test.dart` / `howto_test.dart` / `match_hold_test.dart` have **no file yet**. Structure = `widget_test.dart` (`pumpWidget` + `find.text`). Hold test must assert Hold disabled until `game.isLoaded` (CR-01).

---

### `harness/.../Dyn4jBurstSim.java` (service, batch) — promote, do not rewrite

**Analog:** itself. Backend `games.alchiki` **calls** `Dyn4jBurstSim.simulate(input)`.

**Entry** (lines 63–84):
```java
public static Result simulate(ThrowInput input) {
    return simulate(input, TableConstants.settleTimeoutS);
}
// World gravity (0,0), step 1/60, spawnSeed1, impulse from holdMs
```

**Score from rest poses only** (lines 165–180):
```java
PocketScore score = scoreFromRestPoses(bodies);
// isFullyOutside: distance > circleRadiusM + bodyRadiusM
```

**Ignore client score fields:** proven by `BurstSimTest.outputHasNoClientPosesField` (lines 48–71). REST layer must keep that: parse with `ThrowInput.parse`, never a score DTO.

**Extend (do not fork):** `spawnSeed1` (lines 123–141) + `SEED1` / `IDS` (lines 24–35) need 5- and 7-bone variants that reuse the same fixture family. RESEARCH A1.

**WR-02 — do not copy the sleep break as-is** (lines 98–105). 01-REVIEW fix:
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

**CLI stays Spring-free:** `HarnessMain.java` 15–37 (`ThrowInput.parse` → `simulate` → `resolved.toJson()`). Backend depends on `com.nomadgames:alchiki-proto-harness:0.1.0-SNAPSHOT`; do not move these classes into `backend/` and delete the CLI.

---

### `harness/.../BurstSimTest.java` (test, batch)

**Analog for all new Java physics/rules tests.** Pattern (lines 22–37, 48–71):
```java
ThrowInput input = ThrowInput.parse(FIXTURE);
Dyn4jBurstSim.Result result = Dyn4jBurstSim.simulate(input);
assertTrue(result.keyframes().size() >= 3);
assertNotEquals(99, result.pocketedCount()); // tainted input ignored
```

**Do not copy** the tautology at lines 35–37 (WR-03). New assertion:
```java
assertEquals(0, result.resolved().displayedScore()); // when sakaOut
```
Add spawn-5 / spawn-7 tests and a constructed `sakaOut=true, pocketedCount>0` case.

---

### `backend/**` Spring slice (mostly greenfield)

**Closest Maven analog:** `harness/pom.xml` (Java 21, JUnit 6.1.3, artifact `com.nomadgames:alchiki-proto-harness:0.1.0-SNAPSHOT`). Copy `groupId` / `version` / `maven.compiler.release=21`. New root aggregator:
```xml
<modules>
  <module>harness</module>
  <module>backend</module>
</modules>
```
`backend` uses `spring-boot-starter-parent` **4.1.1** (RESEARCH). Do not copy harness’s hand-pinned dyn4j into backend — depend on the harness module. Do **not** add Spring to `harness/pom.xml`.

**Closest “input in → authority JSON out” analog:** `HarnessMain.main` (lines 22–30). Session `POST /throws` is that pipeline plus match clocks + optional bot half:
```java
ThrowInput input = ThrowInput.parse(json);
ThrowResolved resolved = Dyn4jBurstSim.simulate(input).resolved();
```

**ScriptedBot:** no analog. Emit the same `ThrowInput` constructor (`ThrowInput.java` 20–40): `schemaVersion=1`, `yUp=true`, finite `aimAngleRad`, clamped `holdMs`, `tableId=alchiki-match-v1`. Then the same `simulate`. Client animates `botThrow.input` then `KeyframePlayer`.

**Identity / catalog / Flyway / JWT / Modulith verify:** **greenfield.** Use RESEARCH Patterns 1, 3, 4 (Nimbus HS256, guest-is-player, `ApplicationModules.of(...).verify()`). Do not invent `issuer-uri`. Jackson 3 `JsonMapper` — do not copy Jackson 2 `ObjectMapper` snippets.

**Modulith package cut (RESEARCH):**
- public API in module root; internals in `internal/`
- allowed: `games.alchiki` → `session` + harness types; `session` → `identity`; `catalog` standalone
- forbidden: `identity` → `games.alchiki`

---

### `scripts/dev-env.ps1` (utility)

**Analog:** itself. Every plan command that runs Flutter/Java must dot-source it first (lines 1–33). Harness tests: `harness/mvnw.cmd` (no global `mvn`). `scripts/replay.ps1` is **not** the Phase 2 product path (file+adb); keep for harness golden only.

## Shared Patterns

### Authority score (SESS-01 / ALCH-05 / CR-02)
**Source:** `harness/.../ThrowResolved.java` lines 59–62
**Apply to:** match HUD, REST response, `AuthorityScore`, `replay_score_test.dart`, `BurstSimTest`
```java
return sakaOut ? 0 : pocketedCount;
```
Local Forge2D `previewCount` may update `preview {n}` only (`sandbox_page.dart` 399). Never assign preview into `scored`.

### ThrowInput wire (ALCH-01 / SESS-01)
**Source:** `client/lib/input/throw_input.dart` 25–73 + `harness/.../ThrowInput.java` 46–70
**Apply to:** REST body, ScriptedBot, match `_releaseCharge`
- `schemaVersion == 1`, `yUp == true`, finite `aimAngleRad`, `holdMs` clamp 150–1100
- Unknown / score-like keys ignored
- Impulse: `impulseFromHoldMs` (Dart 96–106 / Java 76–81)

### Flame-in-Flutter overlay
**Source:** `sandbox_page.dart` 378–519 + `alchiki_sandbox_game.dart` 364–416
**Apply to:** `match_page.dart` / `match_game.dart`
- `Scaffold` + `GameWidget.controlled`
- Flutter: Hold Throw `Listener` (pointer down/up/cancel), power meter, HUD, Pause
- Flame: aim drag, bodies, rim flash, `+1`, keyframe overwrite
- Hold disabled/hidden when `!game.isLoaded`, throwing, replaying, bot turn, paused (CR-01)

### Keyframe replay wins (D-10 / D-24)
**Source:** `keyframe_player.dart` 12–44 + `alchiki_sandbox_game.dart` 171–184
**Apply to:** player throw after REST, then bot throw
```dart
KeyframePlayer.applyFrame(tMs, resolved.keyframes, targets);
```

### Palette / type / 48dp targets
**Source:** `sandbox_page.dart` 23–46, 488–492, 609
**Apply to:** catalog, how-to, splash, pause, result, match chrome
- Felt `#1B6B3A`, wood `#241810`, accent `#F0B429` only on reserved CTAs
- Weights 400 and 600 only
- `BoxConstraints(minWidth: 48, minHeight: 48)`; Hold / Play Alchiki width ≥ 192

### Error surfaces
**Source:** `sandbox_page.dart` `_ReplayErrorBanner` 634–675
**Apply to:** splash mint, catalog GET, match POST, throw POST
- Destructive `#C43C2C` border, heading + body, i18n Retry
- Persist/IO failures: `on Object catch` + log, do not crash (`_persistThrowInput` 351–353)

### Validation / ignore-unknown
**Source:** Dart `ThrowInput.parse` / `ThrowResolved.parseMap`; Java `ThrowInput.parse`; `BurstSimTest` tainted fixture
**Apply to:** every REST DTO
- Reject non-finite / bad schemaVersion
- Ignore `pocketedCount`, `score`, `sakaOut`, `winner` on **input**
- Server writes those fields on **output** only

### Test shape
**Source:** `widget_test.dart`, `replay_score_test.dart`, `throw_input_test.dart`, `BurstSimTest.java`
**Apply to:** new catalog/howto/hold/rules/bot tests
- Flutter: `testWidgets` + `find.text` / `flutter_test`
- Java: JUnit 5 `@Test`, `ThrowInput.parse` fixtures, assert keyframe count ≥ 3 and score independence from input

### Toolchain
**Source:** `scripts/dev-env.ps1`, `harness/mvnw.cmd`
**Apply to:** every verify command in PLAN.md

## No Analog Found

Planner should use RESEARCH.md Patterns 1–6 and official snippets — do not invent a second style.

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `client/l10n.yaml` + `lib/l10n/app_*.arb` | config | transform | No i18n in repo (CONTEXT: “No go_router, no i18n”) |
| `client/lib/platform/router.dart` | route | request-response | No `go_router`; only `MaterialApp.home` |
| `client/lib/platform/api/nomad_api.dart` | service | request-response | No Dio / HTTP client |
| `client/lib/platform/auth/session_store.dart` | store | file-I/O | No secure storage; only proto file persist |
| `backend/src/main/java/com/nomadgames/identity/**` | controller + service | CRUD | No Spring, JWT, or Player table |
| `backend/src/main/java/com/nomadgames/catalog/**` | controller + service | request-response | No catalog API |
| `backend/.../db/migration/V1__*.sql` | migration | CRUD | No Flyway / Postgres schema |
| `backend/src/main/resources/application*.yaml` | config | — | No Spring app |
| `backend/.../ModularityTest.java` | test | — | No Modulith module |
| `backend/.../games/alchiki/ScriptedBot.java` | service | transform | No bot; only fixture `ThrowInput` |
| `backend/.../session` match clocks / first-to-5 | service | request-response | Sandbox is one throw + Reset; no turn machine |
| Compose `postgres:18.6` | config | — | No compose file; Docker is available but PG not on :5432 |

## Anti-patterns (do not copy)

| Source | Defect | Replacement |
|--------|--------|-------------|
| `sandbox_page.dart:131` | CR-01 Hold before `onLoad` | `game.isLoaded && … && isPlayerTurn` |
| `authority_score.dart:18` | CR-02 raw `pocketedCount` | `displayedScore()` / `sakaOut ? 0 : pocketedCount` |
| `alchiki_sandbox_game.dart:136` | WR-01 `simTimeS += dt` | step-counted `PhysicsStepper.step` |
| `Dyn4jBurstSim.java:98-105` | WR-02 sleep omits rest keyframe | capture on `allAtRest` then break |
| `BurstSimTest.java:35-37` | WR-03 tautology | `assertEquals(0, resolved.displayedScore())` |
| `main.dart:14` | Sandbox as home | `GoRouter` `/` = catalog |
| `scripts/replay.ps1` | File+adb authority loop | REST `POST /throws` |
| `sandbox_page.dart` Reset / Replay buttons | Product chrome | Pause / clocks / scores only |
| STACK.md Forge2D 0.15 / secure_storage 10.3.1 | Stale vs Phase 1 lock / RESEARCH | forge2d **0.14.2**, secure_storage **11.0.0** |

## Metadata

**Analog search scope:** `client/lib/**`, `client/test/**`, `client/android/app/src/main/AndroidManifest.xml`, `client/pubspec.yaml`, `harness/src/**`, `harness/pom.xml`, `scripts/**`, `.planning/phases/01-alchiki-physics-prototype/01-REVIEW.md`
**Files scanned:** 48 project source files (Glob `*.{dart,java,xml,yaml,ps1,json}` under nomad-game, excluding generated/plugin noise)
**Strong analogs used (5):** `sandbox_page.dart`, `alchiki_sandbox_game.dart`, `Dyn4jBurstSim.java` + `ThrowResolved.java` / `ThrowInput.java`, `replay_score_test.dart` + `BurstSimTest.java`, `main.dart` + `widget_test.dart`
**Pattern extraction date:** 2026-09-06
