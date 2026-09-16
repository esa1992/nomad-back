# Phase 1: Alchiki Physics Prototype - Context

**Gathered:** 2026-09-05
**Status:** Ready for planning

<domain>
## Phase Boundary

This phase delivers **only** the Alchiki physics gate: a playable throw on a mid-range Android device, plus a headless JVM dyn4j harness that scores the same `ThrowInput` via a closed keyframe buffer. If the throw does not feel like skill, or the client can author the score, **stop and reopen the stack before any identity, catalog, shop, bots, or matchmaking exist**.

PROTO-01 and PROTO-02 are the only v1 requirements in this phase. Success is a device demo + harness, not an app shell.

</domain>

<decisions>
## Implementation Decisions

### Prototype product shape
- **D-01:** Prototype is a **sandbox table**, not a first-to-5 match, not a catalog, not vs-bot. Six target bones start in the circle. After physics settle, show pocketed count and a **Reset** that restores the cluster. Repeat throws until the feel is proven.
- **D-02:** No login, guest bind, shop, bots, rooms, how-to cards, Stick Pull, or i18n screens. A debug HUD (FPS, body count, settle flag) is allowed.
- **D-03:** iOS compile is **not** required to pass the gate. Android (emulator + mid-range device if available) is the proof target. Keep the Flutter project capable of iOS later; do not spend Phase 1 on Xcode shipping.

### Aim and throw
- **D-04:** Controls match the original product spec, not 8 Ball Pool. Player **rotates an aiming arrow** (drag around the saka). A **separate hold button** charges power by hold duration. Release throws. No drag-back slingshot, no aim-assist line that lengthens with cosmetics (there are no cosmetics yet).
- **D-05:** Charge window ~0.15–1.1s; holding past max stays at max (no overcharge penalty). Visible power meter required so the throw reads as skill.
- **D-06:** Camera is **2.5D**: top-down circle with a slight tilt. Physics stay 2D (disk/capsule colliders). Gravity of the physics world is zero (table-top).

### Board look (prototype fidelity)
- **D-07:** Not gray cubes, not the full art pipeline. **Readable parlor table:** felt-colored circle, contrasting rim that can flash when a bone exits, disk/capsule bones with visible spin, a brighter distinct saka. Placeholder materials are fine if mass, collisions, rotation, friction, and restitution are obvious.
- **D-08:** Scoring presentation: floating +1 only **after settle**, not mid-roll. Saka leaving the circle scores 0 and returns on Reset / next throw setup.

### Authority proof
- **D-09:** Client Forge2D may simulate locally for **feel and optional preview**. Authority is **dyn4j on the JVM**. Same `ThrowInput` `{ aimAngle, holdMs }` (plus seed/table constants) goes to a **headless harness** that burst-simulates to sleep (~1.2s timeout) and emits a **closed keyframe buffer**.
- **D-10:** After a throw, the device must offer **Replay** that interpolates those JVM keyframes. The demo **must not** accept a client-authored score or rest poses. Overlay or morph from local preview onto the keyframe replay is allowed; when they diverge, **keyframes win**.
- **D-11:** Do **not** lockstep Forge2D against dyn4j. Fixed physics `dt` (1/60 or 1/120), never `dt = frameTime`. Prototype family = production family: Flutter 3.47 + Flame + Forge2D + dyn4j 6. If the gate fails, change stack **in this phase**, not after accounts exist.

### Claude's Discretion
- Exact masses, friction, restitution, saka vs bone size, keyframe rate, JSON vs binary frame schema, JUnit vs CLI harness layout, NDK/Forge2D 0.15 vs 0.14 Dart fallback, HUD layout, Reset animation — planner/researcher decide, as long as D-01–D-11 hold.
- Mid-range Android: treat as a typical 2022–2024 Snapdragon 6/7 class or equivalent emulator profile; do not require a flagship.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase and requirements
- `.planning/ROADMAP.md` — Phase 1 goal, success criteria, PROTO-01/PROTO-02 only
- `.planning/REQUIREMENTS.md` — PROTO-01, PROTO-02; Alchiki rules ALCH-* are Phase 2 (do not implement bots/how-to here)
- `.planning/PROJECT.md` — core value, hold-to-throw spec, prototype gate constraint

### Stack and physics architecture (locked unless gate fails)
- `.planning/research/STACK.md` — Flutter 3.47 + Flame 1.38 + Forge2D 0.15; dyn4j 6.0.0; 2.5D/2D; no Unity/Godot unless Phase 1 fails
- `.planning/research/ARCHITECTURE.md` — input → server burst-sim → keyframe replay; no lockstep; no 60 Hz live authority tick
- `.planning/research/FEATURES.md` — Alchiki Mobile Rules Spec (5–7 bones, settle-then-score, saka-out = 0). Use as **feel/scoring hypotheses** in the sandbox, not a full match loop
- `.planning/research/PITFALLS.md` — Pitfalls 1–3: no accounts first, no lockstep, no engine lock-in before the gate
- `.planning/research/SUMMARY.md` — Phase 1 gate wording and fail → reopen stack

No external ADRs yet. No SPEC.md for this phase.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- None. Greenfield: the nomad-game folder has planning docs only. Phase 1 **creates** the Flutter app and the JVM harness.

### Established Patterns
- None in-repo. Follow STACK.md: Flame game loop inside Flutter, Forge2D world with `gravity: Vector2.zero()`, Maven Spring/Java harness (a minimal Java module is enough — do not scaffold the full modular monolith or Postgres in this phase).

### Integration Points
- Future `games/alchiki` client module and `games.alchiki` server engine should be able to reuse `ThrowInput` + keyframe schema from this prototype. Keep those types boring and serializable. Do not wire REST, WebSocket, or Spring Modulith yet unless a tiny CLI/JUnit entrypoint needs it.

</code_context>

<specifics>
## Specific Ideas

- User: «спроектируй именно Alchiki Physics Prototype» — they declined picking isolated gray-area checkboxes; they want this phase to be a designed prototype, then they locked the design as presented.
- Original product throw: choose direction, then hold button, hold duration = power, release throws — preserved in D-04.
- Visual: colorful traditional nomadic/Asian is the product direction; Phase 1 uses a **readable subset** (felt circle + bright saka), not Gold/Neon shop skins.

</specifics>

<deferred>
## Deferred Ideas

- First-to-5 match clock, turn order, static how-to cards, EASY/NORMAL/HARD bots — Phase 2
- iOS device proof / App Store packaging — later phases
- Full nomadic art pack, cosmetics, trails, victory animations — Phase 4+
- WebSocket match session, reconnect, private rooms — Phase 3
- Stick Pull — Phase 6
- Bind / Ranked / Glicko-2 — Phase 7

None extra from this discussion — stayed inside the prototype gate.

</deferred>

---

*Phase: 1-Alchiki Physics Prototype*
*Context gathered: 2026-09-05*
