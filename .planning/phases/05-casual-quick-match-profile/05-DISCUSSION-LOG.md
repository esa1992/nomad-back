# Phase 5: Casual Quick Match + Profile - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-09-11
**Phase:** 5-Casual Quick Match + Profile
**Areas discussed:** Empty-queue fallback, Quick Match entry & pairing, Casual rematch, Profile + avatar

---

## Empty-queue fallback

| Option | Description | Selected |
|--------|-------------|----------|
| Short search → choice | ~5–10s then bot / invite screen | ✓ |
| Immediate choice if empty | No search spinner when queue empty on entry | |
| Auto-bot after timeout | Auto-start bot; invite secondary | |
| You decide | | |

**User's choice:** Short search → choice
**Notes:** Never 60s fail spinner (MODE-03 / FEATURES)

| Option | Description | Selected |
|--------|-------------|----------|
| Two equal buttons | Bot and Invite side by side | ✓ |
| Bot primary | | |
| Invite primary | | |
| You decide | | |

**User's choice:** Two equal buttons

| Option | Description | Selected |
|--------|-------------|----------|
| Create private room | Code + share; leave queue | ✓ |
| System share into Quick Match | | |
| Deep link same queue | | |
| You decide | | |

**User's choice:** Create private room

| Option | Description | Selected |
|--------|-------------|----------|
| Cancel always | Cancel → catalog, dequeue | ✓ |
| System Back only | | |
| Cancel + Back on fallback | | |
| You decide | | |

**User's choice:** Cancel always; Back to catalog also locked on fallback screen

---

## Quick Match entry & pairing

| Option | Description | Selected |
|--------|-------------|----------|
| Primary on Alchiki tile | QM primary; bot/private secondary | ✓ |
| Separate band above tiles | | |
| Replace current Play | | |
| You decide | | |

**User's choice:** Primary on Alchiki tile

| Option | Description | Selected |
|--------|-------------|----------|
| Full-screen Searching… | Spinner + Cancel, minimal | ✓ |
| Searching with hint copy | | |
| Searching with countdown | | |
| You decide | | |

**User's choice:** Full-screen Searching…

| Option | Description | Selected |
|--------|-------------|----------|
| First-available | MVP queue | ✓ |
| Latency/region first | | |
| Win-rate band | | |
| You decide | | |

**User's choice:** First-available

| Option | Description | Selected |
|--------|-------------|----------|
| Always NORMAL | Like private D-31 | ✓ |
| Chips affect QM | | |
| Queue host chooses difficulty | | |
| You decide | | |

**User's choice:** Always NORMAL

---

## Casual rematch

| Option | Description | Selected |
|--------|-------------|----------|
| Like private dual-accept UI | Again? 10s | |
| Like bot one-tap | Play again | ✓ |
| Re-queue | | |
| You decide | | |

**User's choice:** Like bot one-tap (clarified next)

| Option | Description | Selected |
|--------|-------------|----------|
| Wait for same opponent (both must tap) | Dual-accept semantics | ✓ |
| Immediate re-queue | | |
| Same seats without 10s | | |
| You decide | | |

**User's choice:** Both must tap; same opponent

| Option | Description | Selected |
|--------|-------------|----------|
| 10s like private | Then catalog | ✓ |
| ~20–30s | | |
| No timer | | |
| You decide | | |

**User's choice:** 10s

| Option | Description | Selected |
|--------|-------------|----------|
| Status on ResultOverlay | | |
| Separate short waiting screen | | ✓ |
| No status / button pressed | | |
| You decide | | |

**User's choice:** Separate short waiting screen

---

## Profile + avatar

| Option | Description | Selected |
|--------|-------------|----------|
| Avatar chip | Top bar → profile | ✓ |
| Profile button next to Shop | | |
| Tap wallet chip | | |
| You decide | | |

**User's choice:** Avatar chip

| Option | Description | Selected |
|--------|-------------|----------|
| Full casual metrics | XP/level + soft casual rating | ✓ |
| Stats without rating | | |
| Only W/L + cosmetics + avatar | | |
| You decide | | |

**User's choice:** Full casual metrics

| Option | Description | Selected |
|--------|-------------|----------|
| ~6–8 in profile only | | ✓ |
| ~12 in profile | | |
| Presets + shop SKUs | | |
| You decide | | |

**User's choice:** ~6–8 presets, profile only

| Option | Description | Selected |
|--------|-------------|----------|
| Both sections with zeros | Stick Pull empty until Phase 6 | ✓ |
| Alchiki only now | | |
| Stick Pull collapsed Coming soon | | |
| You decide | | |

**User's choice:** Both sections; Stick Pull zeros / No matches yet

---

## Claude's Discretion

No “You decide” options selected. Discretion limited to implementation details listed in CONTEXT.md (timeout within 5–10s, MMR/XP numbers, art, chrome, queue storage).

## Deferred Ideas

- Region/WR matchmaking; Ranked/Glicko; Stick Pull playable; avatar shop SKUs; Redis queues — see CONTEXT.md Deferred
