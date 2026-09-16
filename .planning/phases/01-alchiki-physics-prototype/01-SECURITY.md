---
phase: 1
slug: alchiki-physics-prototype
status: verified
threats_open: 0
asvs_level: 1
created: 2026-09-06
---

# Phase 1 — Security

> Per-phase security contract: threat register, accepted risks, and audit trail.
>
> Source: PLAN.md `<threat_model>` blocks (01-01..01-06). L1 grep-depth verification 2026-09-06. No SECURITY.md existed before this run (State B).

---

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|---------------|
| Touch overlay → ThrowInput | Untrusted hold duration and aim angle | `aimAngleRad`, `holdMs` |
| Client documents → `throw_input.json` | Exported input only; must not include a score | schemaVersion, yUp, aimAngleRad, holdMs, seed, tableId |
| ThrowInput file → Dyn4jBurstSim | Untrusted JSON; clamp/reject before the world exists | same input keys |
| Dyn4jBurstSim → ThrowResolved file | Only trusted writer of `pocketedCount` | keyframes, pocketedCount, sakaOut |
| Documents / assets JSON → Replay | Untrusted file; parse as data, never spawn/eval | ThrowResolved JSON |
| Replay → HUD `scored` | Only file `pocketedCount` may cross | integer score or em-dash |
| Local Forge2D rest poses → preview HUD | Feel-only; must never become `scored` | preview count |
| Developer workstation → pub.dev / Maven Central | Toolchain and package downloads | Flutter/Flame pins, dyn4j, JUnit |
| HarnessMain CLI | Local files only | input path → output path |

---

## Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation | Status |
|-----------|----------|-----------|----------|-------------|------------|--------|
| T-01-01 | Tampering | scored HUD / ThrowResolved / throw_input.json | high | mitigate | `ThrowInput.toJson()` has no `pocketedCount`. `AuthorityScore.readPocketedCount` reads `ThrowResolved.pocketedCount` only. `Dyn4jBurstSim` is the JVM writer. Tests: `forged client pocketedCount is ignored`. | closed |
| T-01-02 | Tampering | ThrowInput.parse / ThrowResolved.parse | high | mitigate | Reject non-finite `aimAngleRad`; `schemaVersion` must be 1; ignore unknown keys; `dart:convert` / hand JSON, no eval. | closed |
| T-01-03 | Tampering | holdMs | high | mitigate | Clamp 150–1100 in Dart `ThrowInput.parse`, Hold Throw release, `impulseFromHoldMs`, and Java `ThrowInput.clampHoldMs`. Replay matching does not re-throw file hold. | closed |
| T-01-04 | Denial of service | keyframe / body arrays | medium | mitigate | Cap 40 keyframes and 8 bodies on Dart `ThrowResolved` and Java `ThrowResolved`/`Keyframe`. Invalid JSON disables Replay. | closed |
| T-01-05 | Elevation of privilege / Tampering | HarnessMain / `scripts/replay.ps1` | medium | mitigate | CLI reads/writes two local paths; no bind port, no Spring. Script only `adb pull` → `mvnw exec:java` → `adb push` JSON. | closed |
| T-01-SC | Tampering | pub.dev / Maven pins | high | mitigate | Client: `flame` 1.38.2, `forge2d` 0.14.2, `flame_forge2d` 0.19.3+7 (NDK fallback from planned 0.15). Harness: dyn4j 6.0.0, junit-jupiter 6.1.3, no Spring parent. | closed |
| T-01-HUD | Information disclosure | debug HUD | low | accept | FPS / bodies / settled overlay is a prototype aid (D-02). No accounts. | closed |

*Status: open · closed · open — below high threshold (non-blocking)*
*Severity: critical > high > medium > low — only open threats at or above `workflow.security_block_on` (`high`) count toward `threats_open`*
*Disposition: mitigate (implementation required) · accept (documented risk) · transfer (third-party)*

---

## Accepted Risks Log

| Risk ID | Threat Ref | Rationale | Accepted By | Date |
|---------|------------|-----------|-------------|------|
| AR-01 | T-01-HUD | Debug HUD (fps, bodies, settled) is allowed by D-02 for the physics sandbox. No identity, network, or wallet exists in this phase. | Phase 1 CONTEXT D-02 / planner disposition accept | 2026-09-06 |

*Accepted risks do not resurface in future audit runs.*

---

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-09-06 | 7 | 7 | 0 | gsd-secure-phase (L1 grep; auditor skipped — `threats_open: 0`, plan-time register, ASVS L1) |

Evidence (L1):

- `client/lib/input/throw_input.dart` — `toJson` keys, `isFinite`, `schemaVersionRequired`, holdMs clamp
- `client/lib/replay/authority_score.dart` — `readPocketedCount`
- `client/lib/replay/throw_resolved.dart` — `maxKeyframes` 40, `maxBodies` 8
- `client/test/throw_input_test.dart`, `client/test/replay_score_test.dart`
- `harness/src/main/java/com/nomadgames/alchiki/proto/{ThrowInput,ThrowResolved,Dyn4jBurstSim,HarnessMain,Keyframe}.java`
- `harness/pom.xml` — no Spring parent
- `scripts/replay.ps1` — JSON pull/run/push only
- SUMMARY Threat Flags (01-02, 01-03, 01-05): none raised

---

## Sign-Off

- [x] All threats have a disposition (mitigate / accept / transfer)
- [x] Accepted risks documented in Accepted Risks Log
- [x] `threats_open: 0` confirmed
- [x] `status: verified` set in frontmatter

**Approval:** verified 2026-09-06
