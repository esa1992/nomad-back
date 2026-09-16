# Phase 1: Alchiki Physics Prototype - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-09-05
**Phase:** 1-Alchiki Physics Prototype
**Areas discussed:** Prototype design (aim/throw, play loop, board look, authority proof) as a single locked spec

---

## Gray-area picker

| Option | Description | Selected |
|--------|-------------|----------|
| Aim & throw gesture | Arrow + hold button vs 8 Ball drag | |
| Play loop | Sandbox vs first-to-5 | |
| Board look | Placeholders vs nomadic table | |
| Authority proof | On-device replay vs JVM tests only | |
| Other: «спроектируй именно Alchiki Physics Prototype» | User asked Claude to design the prototype instead of picking areas | ✓ |

**User's choice:** Design the prototype as a whole, then lock it.
**Notes:** Matches the owner's earlier rule: only ask product forks; technical design can be prescribed.

---

## Prototype design lock

| Option | Description | Selected |
|--------|-------------|----------|
| Lock this design | Sandbox, arrow+hold, readable felt table, on-device JVM Replay | ✓ |
| Different aim | User would explain another gesture | |
| Different look | More placeholder or more final art | |
| Different loop | Mini first-to-5 instead of sandbox | |

**User's choice:** Lock this design and write CONTEXT.md.
**Notes:** No further gray-area questions; user did not request more discussion.

---

## Claude's Discretion

Masses, friction, restitution, keyframe schema, harness layout (JUnit vs CLI), NDK vs Dart Forge2D fallback, HUD details, exact Android mid-range profile.

## Deferred Ideas

Phase 2+: match rules loop, bots, how-to, catalog, iOS shipping, cosmetics, multiplayer, Stick Pull, ranked.
