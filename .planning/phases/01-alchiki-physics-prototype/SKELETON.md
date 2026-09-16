# Walking Skeleton — Nomad Games (Alchiki Physics Gate)

**Phase:** 1
**Generated:** 2026-09-06

## Capability Proven End-to-End

A player on a mid-range Android device can aim with a fixed-length arrow, charge Hold Throw (150–1100 ms), knock six bones on a zero-g felt table, Reset Table, persist `ThrowInput` JSON, and Replay a closed dyn4j keyframe buffer whose `pocketedCount` is the only scored result.

## Architectural Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Client framework | Flutter 3.47.0 (Dart 3.13) + Flame 1.38.2 + `GameWidget` (no `go_router`) | One Android proof binary; catalog shell later; widgets are not the 60 FPS clock |
| Feel solver | Forge2D 0.15.1 + flame_forge2d 0.20.0 (`initializeForge2D()`, `createShape`, `metersToPixels`) | Production family (D-11). Fallback only after documented NDK failure: forge2d 0.14.x + flame_forge2d 0.19.3+7 |
| Authority solver | Headless Maven Java 21 module + dyn4j 6.0.0 (no Spring Boot / Modulith / Postgres) | JVM is the scorer (D-09). Monolith is Phase 2+ |
| Shared contract | UTF-8 JSON `ThrowInput` / `ThrowResolved` / `TableConstants`; meters, Y-up, `yUp: true`, `schemaVersion: 1` | Boring reusable types for future `games/alchiki`; no Freezed / Jackson |
| Physics clock | Fixed `dt = 1/60`, Forge2D accumulator `maxCatchUp = 4`, dyn4j `Settings.setStepFrequency(1.0/60.0)` | Never step with frame time (D-11). Gravity `(0,0)` on both engines |
| One real write | Client writes `throw_input.json` (documents dir). Harness writes `ThrowResolved` (`pocketedCount` harness-only). Ship `assets/replays/golden_throw.json` from CLI | No REST/WebSocket. Device handoff: adb pull → `mvnw exec:java` → adb push |
| One real UI interaction | Aim-arrow drag around saka + Flutter Hold Throw + settle + Reset Table + Replay Throw | D-04 / D-01 / D-10. Hold is a widget, not a Flame component |
| Auth | None | D-02: no login, guest, shop, bots, rooms, i18n |
| Deployment target | `flutter run --profile` on physical mid-range Android (Snapdragon 6/7 2022–2024 class) + `harness/mvnw.cmd -q test` | Emulator is functional QA only; not sufficient for PROTO-01 FPS |
| Directory layout | `client/` Flutter app; `harness/` Maven module `com.nomadgames.alchiki.proto`; no nested `.git` | Keep future `games/alchiki` seam in type names only |
| Phase 1 waves | Wave 1: 01-01 toolchain + Flutter stub + failing client tests. Wave 2 (parallel): 01-02 feel + 01-06 Maven stubs + failing BurstSimTest. Wave 3 (parallel): 01-03 six bones + 01-04 dyn4j CLI/golden. Wave 4: 01-05 Replay + device checklist | Walking skeleton stays Flutter GameWidget + ThrowInput/ThrowResolved files + `mvnw test`. No Spring/Postgres |

## Stack Touched in Phase 1

- [ ] Project scaffold (Flutter 3.47 + Flame/Forge2D pubs; Maven Wrapper + dyn4j 6.0.0 + JUnit 6.1.3; no Spring)
- [ ] Routing — single `MaterialApp(home: SandboxPage)` (no catalog router)
- [ ] Persistence — client export of `ThrowInput`; harness write of `ThrowResolved` (authority `pocketedCount`)
- [ ] UI — aim arrow + Hold Throw + Reset Table + Replay Throw wired to feel world and JVM replay
- [ ] Deployment — `flutter run --profile` on physical mid-range Android + `mvnw.cmd -q test` for `BurstSimTest`

## Out of Scope (Deferred to Later Slices)

- First-to-5 match, turn order, how-to cards, EASY/NORMAL/HARD bots (Phase 2)
- Spring Boot, Modulith, PostgreSQL, Redis, REST, WebSocket
- `go_router` catalog, Riverpod session, Dio, secure storage, i18n screens
- Guest bind, shop, rooms, Stick Pull, Ranked / Glicko-2
- iOS device proof / Xcode shipping (keep `--platforms=android,ios` only)
- Full nomadic art pack, cosmetics, trails, victory animations
- Lockstep Forge2D ↔ dyn4j; client-authored scores / rest poses

## Subsequent Slice Plan

Each later phase adds one vertical slice on top of this skeleton without altering its architectural decisions:

- Phase 2: Guest catalog + first authoritative Alchiki match vs bot
- Phase 3: Private rooms + casual reconnect
- Phase 4: Economy + cosmetic shop (no physics change)
- Phase 5: Casual Quick Match + profile
- Phase 6: Stick Pull as second live title
- Phase 7: Bind, Ranked (Glicko-2), leaderboards, CI harden
