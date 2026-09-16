# Phase 1: User Setup Required

**Generated:** 2026-09-06
**Phase:** 01-alchiki-physics-prototype
**Status:** Incomplete

Claude installed Flutter 3.47.2, Android SDK platform 36, build-tools 36.0.0, NDK 28.2.13676358, and accepted SDK licenses. `scripts/dev-env.ps1` sets `JAVA_HOME` and `ANDROID_HOME`. What remains needs a human and a phone.

## Environment Variables

| Status | Variable | Source | Add to |
|--------|----------|--------|--------|
| [x] | `JAVA_HOME` | Corretto 21.0.11 at `%USERPROFILE%\.jdks\corretto-21.0.11` (set by `scripts/dev-env.ps1`) | session via script |
| [x] | `ANDROID_HOME` | `%USERPROFILE%\Android\Sdk` (set by `scripts/dev-env.ps1`) | session via script |

## Account Setup

None.

## Dashboard Configuration

- [x] **Android SDK licenses + platform 36 + NDK 28.2.13676358**
  - Location: commandline-tools `sdkmanager` (automated in 01-01)
  - Notes: `flutter doctor` Android toolchain is usable. iOS/Xcode and MSVC Windows desktop are not required (D-03).

- [ ] **Physical mid-range Android for PROTO-01 FPS**
  - Location: USB device + developer options
  - Set to: a 2022–2024 Snapdragon 6/7 class phone (or equivalent)
  - Notes: Emulator is functional QA only. Plan 01-05 runs `flutter run --profile`. This plan does not hang waiting for a device.

## Local Development

```powershell
cd nomad-game
. ./scripts/dev-env.ps1
flutter --version
flutter doctor -v
cd client
flutter test   # expected RED: matcher Expected: on clamp / stepper / score
```

## Verification

```powershell
. ./scripts/dev-env.ps1
flutter doctor
```

Expected results:
- Flutter 3.47.x
- Android toolchain checkmark (SDK 36 / build-tools 36 / licenses accepted)
- Physical device appears under `flutter devices` only after you plug one in

---

**Once all items complete:** Mark status as "Complete" at top of file.
