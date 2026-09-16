# Phase 2: Guest Catalog + First Alchiki Match - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-09-06
**Phase:** 2-Guest Catalog + First Alchiki Match
**Areas discussed:** How-to cards

---

## Gray-area picker

| Option | Description | Selected |
|--------|-------------|----------|
| Guest and catalog | First screen, Coming Soon treatment, EN/RU switch | |
| How-to cards | When to show, skip, card count | ✓ |
| Match win condition | First-to-5 vs 8 turns / 4:00 / 5:00 cap, bone count | |
| Bot and scoring | Visible bot throw, default difficulty, harness vs first HTTP server | |

**User's choice:** How-to cards only
**Notes:** Other areas locked from REQUIREMENTS.md + FEATURES.md Alchiki Mobile Rules Spec without a second discuss pass.

---

## How-to cards

### When to show the first time

| Option | Description | Selected |
|--------|-------------|----------|
| Full-screen pager after Alchiki tap, before the table | Matches ALCH-04 “before first match”; table does not fight copy | ✓ |
| Translucent overlay on felt | Table visible; harder to read and layout | |
| Match starts immediately; How to play is only a button | Risk: first throw with no rules | |

**User's choice:** Full-screen pager after tapping Alchiki, before the table
**Notes:** None

### How skippable is the first showing

| Option | Description | Selected |
|--------|-------------|----------|
| Skip from card 1 | Can reach the table immediately; ALCH-04 skippable | ✓ |
| Must finish the deck once; Skip only on later launches | Forces a full read | |
| You decide (Skip from card 1 + don’t show again after first view) | Discretion | |

**User's choice:** Skip available from the first card
**Notes:** None

### When auto-show repeats

| Option | Description | Selected |
|--------|-------------|----------|
| First match on this device only; later only from pause | ALCH-04 + FEATURES “skippable after first view” | ✓ |
| Keep showing until the guest scores at least 1 | Extra nag | |
| Before every match, with Skip | Noisy; fights “before the first” | |

**User's choice:** Auto-show only before the first Alchiki match on the device
**Notes:** Reopen from Pause → How to play is still required (ALCH-04)

### Card count and topics

| Option | Description | Selected |
|--------|-------------|----------|
| 5 cards: circle; aim; hold power; bone out = 1; first to 5 | PITFALLS / FEATURES mandatory deck | ✓ |
| 3 cards: aim+hold; score after settle; first to 5 | Shorter, less tradition framing | |
| You decide in 3–5, same topics, no animated overlay | Discretion | |

**User's choice:** Five cards with those five topics
**Notes:** No federation jargon on the mandatory deck

---

## Claude's Discretion

User did not pick “you decide” on how-to. Discretion covers undiscussed product/engineering choices documented in CONTEXT.md D-16–D-25 and the Discretion bullet list (i18n/router/storage, Spring layout, bot noise, sandbox retirement, CR-01/CR-02).

## Deferred Ideas

None raised in this discussion. Roadmap later phases (rooms, shop, quick match, Stick Pull, bind/Ranked) were not expanded.
