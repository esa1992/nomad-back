# Phase 6: Stick Pull - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-09-14
**Phase:** 6-Stick Pull
**Areas discussed:** All five gray areas (user-delegated analysis)

---

## Process note

User: «проанализируй сам и выбери первое общепринятое решение» — treated as accept **FEATURES + REQUIREMENTS first-principles defaults** for every gray area without interactive Q&A.

## Online modes MVP

| Option | Description | Selected |
|--------|-------------|----------|
| Bot only | | |
| Bot + private | | |
| Bot + private + Quick Match | Platform parity with Alchiki | ✓ |
| You decide | | |

**User's choice:** Delegated — locked bot + private + QM (D-78…D-80); Ranked out.

## Feel & chrome

| Option | Description | Selected |
|--------|-------------|----------|
| FEATURES presentation | 1D marker, stamina under avatar, GO haptics only | ✓ |
| Minimal abstract bars | | |
| Alchiki-like felt table | Wrong input model | |

**User's choice:** Delegated — FEATURES presentation (D-81…D-83).

## How-to Stick Pull

| Option | Description | Selected |
|--------|-------------|----------|
| Mirror Alchiki + FEATURES 5 cards | Skip once, Pause reopen | ✓ |
| Force full read every match | | |
| Overlay tip only | | |

**User's choice:** Delegated — D-84…D-85.

## Reconnect / forfeit

| Option | Description | Selected |
|--------|-------------|----------|
| SESS-04 8s → forfeit, no bot-fill | | ✓ |
| Alchiki 30s grace | Wrong req | |
| Bot-fill mid-tug | Forbidden | |

**User's choice:** Delegated — D-86…D-87.

## Stamina & tap rules

| Option | Description | Selected |
|--------|-------------|----------|
| Full FEATURES bands + 10/s clamp | | ✓ |
| Clamp only, no stamina bands | Loses anti-mash fantasy | |
| Client-side stamina | Violates SESS-01 | |

**User's choice:** Delegated — D-88…D-91.

## Claude's Discretion

Numeric micro-tuning within locked bands; module wiring; UI-SPEC chrome.

## Deferred Ideas

STICK-06 couch; Ranked false-start; auto-ban; Redis MM — see CONTEXT.md Deferred.
