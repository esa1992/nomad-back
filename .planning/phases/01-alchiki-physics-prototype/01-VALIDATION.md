---
phase: 1
slug: alchiki-physics-prototype
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-09-05
---

# Phase 1 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Flutter `flutter_test` (client) + JUnit Jupiter 6.1.3 (harness) |
| **Config file** | none — Wave 0 installs `client/` and `harness/` |
| **Quick run command** | `cd harness && mvnw -q test` / `cd client && flutter test` |
| **Full suite command** | both suites + Android profile checklist |
| **Estimated runtime** | ~30 seconds automated; device checklist extra |

---

## Sampling Rate

- **After every task commit:** Run the suite for the touched tree (`mvnw -q test` and/or `flutter test`)
- **After every plan wave:** Run both suites
- **Before `/gsd-verify-work`:** Both suites green **and** manual Android checklist
- **Max feedback latency:** 30 seconds (automated)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| W0 toolchain | 01 | 0 | PROTO-01 | — | N/A | setup | `flutter doctor` Android green | ❌ W0 | ⬜ pending |
| throw_input | 01 | 0 | PROTO-01 | T-1-01 | clamp holdMs 150–1100; reject NaN aim | unit | `flutter test test/throw_input_test.dart` | ❌ W0 | ⬜ pending |
| physics_stepper | 01 | 0 | PROTO-01 | — | never `World.step(frameDt)` | unit | `flutter test test/physics_stepper_test.dart` | ❌ W0 | ⬜ pending |
| BurstSimTest | 01 | 0 | PROTO-02 | T-1-01 | pocketedCount from dyn4j only | unit | `mvnw -q test -Dtest=BurstSimTest` | ❌ W0 | ⬜ pending |
| replay_score | 01 | 0 | PROTO-02 | T-1-01 | HUD scored = ThrowResolved.pocketedCount | unit | `flutter test test/replay_score_test.dart` | ❌ W0 | ⬜ pending |
| device FPS | 01 | last | PROTO-01 | — | N/A | manual | `flutter run --profile` FPS ≥ 55 | n/a | ⬜ pending |
| device Replay | 01 | last | PROTO-02 | T-1-01 | Replay refuses client poses | manual | golden JSON Replay on device | n/a | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] Flutter 3.47 + Android SDK + NDK 28.2.13676358; `flutter doctor` Android green
- [ ] `client/` Flutter app (`--platforms=android,ios`)
- [ ] `harness/` Maven Wrapper + dyn4j 6.0.0 + JUnit 6.1.3
- [ ] `client/test/throw_input_test.dart`
- [ ] `client/test/physics_stepper_test.dart`
- [ ] `client/test/replay_score_test.dart`
- [ ] `harness/src/test/java/.../BurstSimTest.java`
- [ ] `assets/replays/golden_throw.json` produced by the harness

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Aim arrow + Hold meter + knock feel ~60 FPS | PROTO-01 | Needs a real GPU/device frame time | Mid-range Android (or emulator + gap note): rotate arrow, Hold 0.15–1.1s, release, FPS HUD ≥ 55, spin/collisions/friction obvious, Reset restores 6 bones |
| Replay interpolates JVM keyframes; scored from file | PROTO-02 | Visual interpolation + HUD | Import golden `ThrowResolved`; Replay motion is JVM track; HUD **scored** equals `pocketedCount`; no client score field |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
