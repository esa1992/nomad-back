---
phase: 01-alchiki-physics-prototype
plan: 05
subsystem: replay
tags: [flutter, flame, forge2d, replay, keyframes, authority-score, proto-01, proto-02]

requires:
  - phase: 01-alchiki-physics-prototype
    provides: Golden ThrowResolved JSON and settle/preview HUD from 01-03/01-04
provides:
  - Closed-buffer KeyframePlayer.applyFrame lerp/nlerp of JVM poses
  - HUD scored from ThrowResolved.pocketedCount only
  - Replay Throw button, golden load, documents import, scripts/replay.ps1
  - PROTO-01 physical Android FPS human-verify APPROVED
affects:
  - Phase 1 UAT / PROTO-01 physical Android FPS check
  - Later match Replay of server keyframes

tech-stack:
  added: []
  patterns:
    - AuthorityScore.readPocketedCount reads file pocketedCount only
    - Replay allowed only on last ThrowInput match or baked golden
    - applyFrame overwrites Forge2D poses so keyframes win (D-10, D-11)

key-files:
  created:
    - client/lib/replay/throw_resolved.dart
    - client/lib/replay/keyframe_player.dart
    - scripts/replay.ps1
  modified:
    - client/lib/replay/authority_score.dart
    - client/test/replay_score_test.dart
    - client/lib/input/throw_input.dart
    - client/lib/sandbox_page.dart
    - client/lib/game/alchiki_sandbox_game.dart
    - client/pubspec.yaml

key-decisions:
  - "scored updates only from AuthorityScore.readPocketedCount; no Forge2D rest-pose argument"
  - "Replay starts if resolved.input equals last ThrowInput or baked golden (1.0471975512 / 640 ms)"
  - "scripts/replay.ps1 is adb pull → mvnw exec:java → adb push; documents path /data/data/com.nomadgames.client/app_flutter"
  - "PROTO-01 device FPS human-verify APPROVED 2026-09-06 — owner ran aim+Hold Throw+settle+Replay Throw; Flame FPS >= 55; scored = ThrowResolved.pocketedCount; UI-SPEC colors"

patterns-established:
  - "Pattern: parse Reject schemaVersion!=1, yUp!=true, NaN/Inf, >40 keyframes, >8 bodies"
  - "Pattern: Replay playback applies JVM transforms after the world step; velocities zeroed"
  - "Pattern: preview stays local; scored is file-only and words distinguish them"

requirements-completed: [PROTO-01, PROTO-02]

coverage:
  - id: D1
    description: AuthorityScore reads only ThrowResolved.pocketedCount; forged client counts and input mismatch leave scored blank
    requirement: PROTO-02
    verification:
      - kind: unit
        ref: "client/test/replay_score_test.dart#scored value equals ThrowResolved.pocketedCount"
        status: pass
      - kind: unit
        ref: "client/test/replay_score_test.dart#forged client pocketedCount is ignored"
        status: pass
      - kind: unit
        ref: "client/test/replay_score_test.dart#input mismatch disables replay and scored"
        status: pass
    human_judgment: false
  - id: D2
    description: ThrowResolved.parse rejects schemaVersion != 1, yUp != true, non-finite numbers, >40 keyframes, >8 bodies
    requirement: PROTO-02
    verification:
      - kind: unit
        ref: "client/test/replay_score_test.dart#parse rejects schemaVersion other than 1"
        status: pass
      - kind: unit
        ref: "client/test/replay_score_test.dart#parse rejects non-finite numbers"
        status: pass
      - kind: unit
        ref: "client/test/replay_score_test.dart#parse rejects more than 40 keyframes"
        status: pass
    human_judgment: false
  - id: D3
    description: KeyframePlayer.applyFrame lerps x,y and nlerps angle between surrounding JVM keyframes
    requirement: PROTO-02
    verification:
      - kind: unit
        ref: "client/test/replay_score_test.dart#applyFrame lerps position and nlerps angle between JVM keyframes"
        status: pass
    human_judgment: false
  - id: D4
    description: Replay Throw button, scored HUD, golden asset, documents import, and scripts/replay.ps1 exec:java handoff
    requirement: PROTO-02
    verification:
      - kind: other
        ref: "flutter test (25 passed); dart analyze lib (no issues); grep Replay Throw / scored / exec:java / assets/replays"
        status: pass
      - kind: unit
        ref: "harness/mvnw.cmd -q test -Dtest=BurstSimTest"
        status: pass
      - kind: manual_procedural
        ref: "owner approved 2026-09-06: Replay Throw + scored = ThrowResolved.pocketedCount + UI-SPEC colors"
        status: pass
    human_judgment: true
    rationale: "Unit tests prove the score helper and parse. On-device Replay motion and HUD scored vs preview were confirmed by owner approval on 2026-09-06."
  - id: D5
    description: Profile run on a physical mid-range Android shows Flame FpsTextComponent average >= 55 during aim+throw+settle+Replay
    requirement: PROTO-01
    verification:
      - kind: manual_procedural
        ref: "owner approved 2026-09-06: flutter run --profile on physical mid-range Android; Flame FPS >= 55 during aim + Hold Throw + settle + Replay Throw"
        status: pass
    human_judgment: true
    rationale: "PROTO-01 requires a physical mid-range Android (D-03). Owner ran the checklist and typed approved on 2026-09-06. Device FPS check passed by owner approval."

duration: 6min
completed: 2026-09-06
status: complete
---

# Phase 1 Plan 05: Replay Throw + Authority Score Summary

**Replay interpolates a closed JVM keyframe buffer; HUD scored equals ThrowResolved.pocketedCount only, never a Forge2D rest-pose count**

## Performance

- **Duration:** 6 min
- **Started:** 2026-09-06T02:29:18Z
- **Completed:** 2026-09-06T02:35:06Z
- **Human-verify:** APPROVED 2026-09-06 (owner physical Android checklist)
- **Tasks:** 2/2 complete (automated + PROTO-01 device FPS human-check)
- **Files modified:** 8

## Accomplishments

- `ThrowResolved.parse` accepts harness JSON (`schemaVersion` 1, `yUp` true) and rejects NaN/Inf, more than 40 keyframes, and more than 8 bodies
- `AuthorityScore.readPocketedCount` returns file `pocketedCount` or null; there is no Dart rest-pose argument
- Replay is allowed only when `resolved.input` equals the last `ThrowInput` or the baked golden (`aimAngleRad` 1.0471975512, `holdMs` 640)
- `KeyframePlayer.applyFrame` lerps x,y and nlerps angle; the game applies those transforms so keyframes win
- Replay Throw (gold, 48dp, English) sits next to Reset Table; Hold/Reset lock during playback; `scored {n}` updates only then
- Golden loads from `assets/replays/`; `throw_resolved.json` in app documents is imported; `scripts/replay.ps1` does adb pull → `exec:java` → adb push
- PROTO-01 device FPS check passed by owner approval on 2026-09-06: Flame FPS >= 55 during aim + Hold Throw + settle + Replay Throw; `scored` equals `ThrowResolved.pocketedCount`; UI-SPEC colors confirmed

## Task Commits

Each task was committed atomically:

1. **Task 1 RED: authority score and replay tests** - `1a5ea4a` (test)
2. **Task 1 GREEN: parse, scored helper, applyFrame** - `0a9019a` (feat)
3. **Task 2: Replay Throw UI and adb handoff** - `3926d12` (feat)
4. **Human-verify: record approved device FPS** - this docs commit

**Plan metadata:** `ab71fa8` (docs, SUMMARY pending device) superseded by this approval commit

_Note: Task 1 is TDD (RED then GREEN). Task 2 is UI/script glue. Replay was not re-implemented after the checkpoint._

## Files Created/Modified

- `client/lib/replay/throw_resolved.dart` - Parse + `allowsReplay` (last input or golden)
- `client/lib/replay/keyframe_player.dart` - Closed-buffer `applyFrame`
- `client/lib/replay/authority_score.dart` - File-only `pocketedCount` reader
- `client/test/replay_score_test.dart` - D-10 scored / mismatch / parse / lerp tests
- `client/lib/input/throw_input.dart` - `==` / `hashCode` for Replay matching
- `client/lib/sandbox_page.dart` - Replay Throw, scored HUD, English errors, golden + import
- `client/lib/game/alchiki_sandbox_game.dart` - JVM pose playback; keyframes overwrite preview
- `client/pubspec.yaml` - `assets/replays/` directory
- `scripts/replay.ps1` - adb ↔ harness file handoff (no REST)

## Decisions Made

- Matching uses already-clamped `ThrowInput` equality; file `holdMs` is never re-applied as a new throw (T-01-03)
- Golden Replay stays available without adb; imported `throw_resolved.json` replaces the current buffer when valid
- Replay disabled style is a secondary `#241810` outline; enabled fill is `#F0B429` with on-accent `#241810`
- PROTO-01 device FPS is a human-check: owner approved 2026-09-06 after running the physical Android checklist

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] ThrowInput equality for Replay matching**
- **Found during:** Task 1
- **Issue:** `allowsReplay` needs structural equality; `ThrowInput` had none
- **Fix:** Added `==` / `hashCode` on schemaVersion, yUp, aimAngleRad, holdMs, seed, tableId
- **Files modified:** `client/lib/input/throw_input.dart`
- **Verification:** mismatch / golden / matching tests green
- **Committed in:** `0a9019a`

**2. [Rule 3 - Blocking] flutter analyze LSP avoided**
- **Found during:** Task 2 verify
- **Issue:** Prior plans saw `flutter analyze` abort with truncated LSP JSON
- **Fix:** Ran `dart analyze lib` (no issues) plus `flutter test`
- **Files modified:** none
- **Verification:** `dart analyze lib` — No issues found
- **Committed in:** n/a (tooling only)

---

**Total deviations:** 2 auto-fixed (1 missing critical, 1 blocking)
**Impact on plan:** Equality is required for D-10 matching. No Spring, shop, catalog, or extra pubs.

## TDD Gate Compliance

Task 1 is `tdd="true"` on a `type: execute` plan.

- RED: `1a5ea4a` `test(01-05): add failing test for authority score and replay`
- GREEN: `0a9019a` `feat(01-05): implement authority score and keyframe interpolator`

No missing RED/GREEN gates. Task 2 is not TDD.

## Issues Encountered

None for automated work.

## Human Verification (PROTO-01)

**Status:** APPROVED 2026-09-06 by owner.

Owner ran the physical Android checklist (aim + Hold Throw + settle + Replay Throw). Flame FPS >= 55. `scored` equals `ThrowResolved.pocketedCount`. UI-SPEC colors confirmed. PROTO-01 device FPS check passed by owner approval. Replay was not re-implemented after the checkpoint.

Checklist that passed:

1. Source `scripts/dev-env.ps1`. Physical mid-range Android (Snapdragon 6/7 2022–2024 class).
2. `flutter run --profile`. Flutter performance overlay (P). Flame `FpsTextComponent` average >= 55 during aim + Hold Throw + settle + Replay Throw.
3. Drag around the saka to rotate the cream aim arrow. Press Hold Throw 150–1100 ms; meter fills; hold-at-max pulses. Release knocks bones with visible mass contrast, spin, friction, bounce. Rim may flash on target exit. +1 only after settle. Reset Table restores six bones.
4. Tap Replay Throw on the golden (or after `scripts/replay.ps1`). Motion is the JVM track. HUD `scored` equals `ThrowResolved.pocketedCount`. `preview` may differ; `scored` must not copy `preview`.
5. Palette: felt `#1B6B3A`, wood `#241810`, gold `#F0B429` only on Hold Throw, Replay Throw, rim flash, power-meter fill. Buttons labeled Hold Throw, Reset Table, Replay Throw. Touch targets >= 48dp.

## Authentication Gates

None.

## Known Stubs

None that block the plan goal. `scored` stays `—` until Replay starts, by design (D-10).

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Walking skeleton is closed (throw → harness JSON → Replay → file score). PROTO-01 device FPS and PROTO-02 file-only score are both checkable and approved. Phase 1 plan 01-05 is complete (plan 6 of 6). Ready for phase verification / next GSD step. Do not add Spring/shop/catalog. Do not reopen Wave 1–3 work.

## Threat Flags

None — parse is data-only (`dart:convert`); script only pulls/runs/pushes JSON; no new packages (T-01-SC). Surface matches the plan threat model (T-01-01..05).

## Self-Check: PASSED

- FOUND: `client/lib/replay/throw_resolved.dart`
- FOUND: `client/lib/replay/keyframe_player.dart`
- FOUND: `client/lib/replay/authority_score.dart`
- FOUND: `client/lib/sandbox_page.dart`
- FOUND: `scripts/replay.ps1`
- FOUND: `client/pubspec.yaml`
- FOUND: commit `1a5ea4a`
- FOUND: commit `0a9019a`
- FOUND: commit `3926d12`
- FOUND: commit `ab71fa8`
- VERIFY: `flutter test` exit 0 (25 tests)
- VERIFY: `dart analyze lib` no issues
- VERIFY: `harness/mvnw.cmd -q test -Dtest=BurstSimTest` exit 0
- VERIFY: greps for `pocketedCount`, `applyFrame`, `schemaVersion`, `Replay Throw`, `scored`, `exec:java`, `assets/replays`
- VERIFY: human-verify APPROVED 2026-09-06 — PROTO-01 physical Android FPS >= 55 during aim + Hold Throw + settle + Replay Throw; scored = ThrowResolved.pocketedCount; UI-SPEC colors (owner approval; device not re-run by executor)

---
*Phase: 01-alchiki-physics-prototype*
*Completed: 2026-09-06*
