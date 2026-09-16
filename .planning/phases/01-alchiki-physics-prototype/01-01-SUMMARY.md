---
phase: 01-alchiki-physics-prototype
plan: 01
subsystem: infra
tags: [flutter, android-sdk, flame, forge2d, walking-skeleton, tdd-red]

requires: []
provides:
  - scripts/dev-env.ps1 JAVA_HOME ANDROID_HOME Flutter PATH
  - client/ Flutter 3.47 sandbox (SandboxApp → SandboxPage)
  - Failing client tests for holdMs clamp, fixed-dt stepper, authority score
affects:
  - 01-02 parlor table
  - 01-06 Maven harness
  - 01-05 device FPS / Replay

tech-stack:
  added:
    - Flutter 3.47.2 / Dart 3.13.2
    - Flame 1.38.2
    - flame_forge2d 0.19.3+7
    - forge2d 0.14.2
    - Android SDK 36 + build-tools 36.0.0 + NDK 28.2.13676358
    - Corretto 21.0.11 on PATH via script
  patterns:
    - Pattern 1 single-screen MaterialApp home SandboxPage
    - Wave 0 compiling stubs that fail matcher assertions
    - Shared scripts/dev-env.ps1 toolchain

key-files:
  created:
    - scripts/dev-env.ps1
    - client/pubspec.yaml
    - client/lib/main.dart
    - client/lib/sandbox_page.dart
    - client/lib/input/throw_input.dart
    - client/lib/game/physics_stepper.dart
    - client/lib/replay/authority_score.dart
    - client/test/throw_input_test.dart
    - client/test/physics_stepper_test.dart
    - client/test/replay_score_test.dart
  modified: []

key-decisions:
  - "Flutter 3.47.2 from official github.com/flutter/flutter stable clone at %USERPROFILE%\\develop\\flutter"
  - "Android SDK at %USERPROFILE%\\Android\\Sdk; platform 36, build-tools 36.0.0, NDK 28.2.13676358"
  - "Host flutter test uses forge2d 0.14.2 + flame_forge2d 0.19.3+7 because 0.15 native hook requires MSVC; NDK remains for later APK"
  - "Physical mid-range Android is a documented gap until 01-05; this plan does not hang on a device"

patterns-established:
  - "Pattern 1: WidgetsFlutterBinding.ensureInitialized(); runApp(SandboxApp); MaterialApp(home: SandboxPage); no game in build"
  - "Wave 0 RED: stubs compile; flutter test fails with Expected: on clamp, 1/60 step, pocketedCount"

requirements-completed: []

coverage:
  - id: D1
    description: Flutter 3.47 and Android SDK/NDK toolchain usable via scripts/dev-env.ps1
    requirement: PROTO-01
    verification:
      - kind: other
        ref: "flutter doctor -v (Android toolchain SDK 36.0.0, licenses accepted)"
        status: pass
    human_judgment: false
  - id: D2
    description: SandboxApp launches MaterialApp home SandboxPage with UI-SPEC empty-state copy
    requirement: PROTO-01
    verification:
      - kind: unit
        ref: "client/test/widget_test.dart#SandboxApp shows empty-state copy"
        status: pass
    human_judgment: false
  - id: D3
    description: Compiling-but-failing client tests for clamp, fixed-dt stepper, and authority score
    requirement: PROTO-02
    verification:
      - kind: unit
        ref: "flutter test (RED; stdout contains Expected:)"
        status: pass
    human_judgment: false
  - id: D4
    description: PROTO-01 ~60 FPS on a physical mid-range Android
    requirement: PROTO-01
    verification: []
    human_judgment: true
    rationale: "Not in 01-01 scope; 01-05 device checklist. No physical device attached this session."

duration: 7h 2m
completed: 2026-09-06
status: complete
---

# Phase 1 Plan 01: Flutter toolchain + sandbox stub + failing client tests Summary

**Flutter 3.47.2 + Android SDK 36 walking skeleton: SandboxApp stub and RED flutter_test gates for holdMs clamp, fixed 1/60 dt, and JVM-only pocketedCount**

## Performance

- **Duration:** 7h 2m
- **Started:** 2026-09-05T18:39:36Z
- **Completed:** 2026-09-06T01:41:35Z
- **Tasks:** 2/2
- **Files modified:** 75 (1 toolchain script + 74 client tree)

## Accomplishments

- Installed official Flutter stable 3.47.2 (Dart 3.13.2) at `%USERPROFILE%\develop\flutter` and Android SDK (platform 36, build-tools 36.0.0, NDK 28.2.13676358) at `%USERPROFILE%\Android\Sdk`
- `scripts/dev-env.ps1` exports `JAVA_HOME` (Corretto 21.0.11) and `ANDROID_HOME` for later Maven + flutter
- `flutter doctor` Android toolchain is usable; Visual Studio C++ / iOS failures ignored (D-03)
- `client/` created with `--org com.nomadgames --platforms=android,ios`; no nested `.git`
- Single-screen `SandboxApp` → `MaterialApp(home: SandboxPage)` with empty-state **Table reset** / **Drag around the saka to aim, then press Hold Throw.**
- Compiling stubs + RED tests: `throw_input_test`, `physics_stepper_test`, `replay_score_test` fail on matcher `Expected:` (not compile errors)

## Task Commits

1. **Task 1: Install Flutter 3.47, Android SDK/NDK, and JDK PATH** - `a8dc802` (chore)
2. **Task 2: Create Flutter sandbox stub and failing client tests** - `c44a63c` (feat)

**Plan metadata:** pending docs commit after this file

## Files Created/Modified

- `scripts/dev-env.ps1` - JAVA_HOME / ANDROID_HOME / Flutter PATH
- `client/pubspec.yaml` - Flame 1.38.2; Forge2D 0.14 fallback (see deviations)
- `client/lib/main.dart` - SandboxApp entry
- `client/lib/sandbox_page.dart` - Scaffold/Stack empty-state stub (no GameWidget yet)
- `client/lib/input/throw_input.dart` - parse / impulseFromHoldMs without clamp or NaN reject
- `client/lib/game/physics_stepper.dart` - tick forwards raw frame dt
- `client/lib/replay/authority_score.dart` - readPocketedCount returns client integer
- `client/test/throw_input_test.dart` - 150/1100 clamp, monotonic impulse, finite angle, schemaVersion 1
- `client/test/physics_stepper_test.dart` - 1 / 60 steps, catch-up 4
- `client/test/replay_score_test.dart` - scored == pocketedCount; forged client ignored
- `client/test/widget_test.dart` - empty-state copy (green)
- `client/android/**`, `client/ios/**` - flutter create scaffold

## Decisions Made

- Official `git clone --branch stable` of Flutter (zip download was blocked by host policy); version is 3.47.2
- SDK root is the user Android folder, not a path inside nomad-game
- After 0.15.1 native-assets hook failed (`No compiler configured on host windows_x64`), dropped to `forge2d` 0.14.2 + `flame_forge2d` 0.19.3+7 so `flutter test` can run. Same Flame 1.38 app. Restore 0.15 when MSVC exists or 01-02 builds an Android APK with NDK
- No physical device this session; record gap, do not block Wave 0 client tests

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Forge2D 0.15 host native-assets hook**
- **Found during:** Task 2 (`flutter test`)
- **Issue:** `forge2d` 0.15.1 `hook/build.dart` requires MSVC `cl.exe` for `windows_x64`. Doctor already flagged missing VS C++. NDK is present but unused by host tests.
- **Fix:** RESEARCH Pitfall 6 / executor prompt NDK fallback — pin `flame_forge2d` 0.19.3+7 and `forge2d` 0.14.2. Plan AC strings `0.20.0` / `0.15.1` are not in pubspec.
- **Files modified:** `client/pubspec.yaml`, `client/pubspec.lock`
- **Verification:** `flutter test` compiles and fails with `Expected:`
- **Committed in:** `c44a63c`

**2. [Rule 2 - Missing Critical] Android build-tools 36.0.0**
- **Found during:** Task 1 (`flutter doctor` after platform 36 + NDK)
- **Issue:** Without `build-tools`, Flutter reports "No valid Android SDK platforms" even though `android.jar` exists.
- **Fix:** `sdkmanager --install "build-tools;36.0.0"`
- **Files modified:** none in-repo (SDK on disk)
- **Verification:** `flutter doctor` Android toolchain checkmark
- **Committed in:** n/a (host SDK)

---

**Total deviations:** 2 auto-fixed (1 blocking, 1 missing critical)
**Impact on plan:** Required for Wave 0 RED and a usable Android toolchain. 0.15 restore is explicit follow-up, not a stack reopen.

## Issues Encountered

- Flutter zip from `storage.googleapis.com` was blocked as an installer-like download; used official git clone instead
- Shallow clone first `flutter --version` spent ~10 minutes on `git fetch --tags`; completed with 3.47.2
- `cmdline-tools;latest` also landed in `latest-2` after a second sdkmanager install; original `latest` still works
- Physical Android not attached — documented in USER-SETUP and coverage D4

## Known Stubs

Intentional Wave 0 RED stubs (01-02 / 01-05 implement):

| File | Stub | Reason |
|------|------|--------|
| `client/lib/input/throw_input.dart` | no holdMs clamp; accepts non-finite aim and schemaVersion != 1 | tests must fail until 01-02 |
| `client/lib/game/physics_stepper.dart` | `tick` calls `stepWorld(frameDt)` | tests must fail until fixed-dt |
| `client/lib/replay/authority_score.dart` | returns `clientPocketedCount` | tests must fail until D-10 |
| `client/lib/sandbox_page.dart` | no GameWidget / Forge2DGame | parlor table is 01-02 |

## Authentication Gates

None.

## User Setup Required

**External services require manual configuration.** See [01-USER-SETUP.md](./01-USER-SETUP.md) for:
- Physical mid-range Android for the 01-05 profile FPS gate
- Environment variables already provided by `scripts/dev-env.ps1`

## Next Phase Readiness

- Ready for 01-02 (aim + Hold Throw + zero-g feel) and 01-06 (Maven BurstSimTest)
- Restore Forge2D 0.15 on Android APK once native-assets compile with NDK; keep 0.14 for host tests until MSVC exists
- Do not treat PROTO-01 / PROTO-02 as complete — only the client walking-skeleton half shipped
- No Spring, go_router, catalog, or identity

## Self-Check: PASSED

- FOUND: `scripts/dev-env.ps1`, `client/lib/main.dart`, `client/lib/sandbox_page.dart`, `client/lib/input/throw_input.dart`, `client/lib/game/physics_stepper.dart`, `client/lib/replay/authority_score.dart`, `client/test/throw_input_test.dart`, `client/test/physics_stepper_test.dart`, `client/test/replay_score_test.dart`
- FOUND: commit `a8dc802`, commit `c44a63c`
- `flutter --version` contains 3.47; `flutter doctor` Android toolchain usable; `flutter test` RED with `Expected:`

---
*Phase: 01-alchiki-physics-prototype*
*Completed: 2026-09-06*
