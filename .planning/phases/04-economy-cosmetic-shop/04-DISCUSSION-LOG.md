# Phase 4: Economy + Cosmetic Shop - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-09-10
**Phase:** 4-Economy + Cosmetic Shop
**Areas discussed:** Reward moment, Shop entry, MVP assortment, Equip/preview (user: «все» → accept defaults)

---

## Reward moment

| Option | Description | Selected |
|--------|-------------|----------|
| On ResultOverlay | `+COINS`/`+GEMS` under outcome; rematch stays primary | ✓ |
| Separate reward screen | Full-screen grant before rematch | |
| Toast only | Transient snackbar; easy to miss | |

**User's choice:** «все» — accept Claude defaults
**Notes:** D-45–D-48. Server grant only; flat win>loss; scarce GEMS.

---

## Shop entry

| Option | Description | Selected |
|--------|-------------|----------|
| Catalog Shop CTA + wallet chip | Primary entry from catalog; `/shop` route | ✓ |
| Result-only CTA | Shop only after matches | |
| Bind-gated shop | Soft-lock spend until username (FEATURES hypothesis) | |

**User's choice:** «все» — accept Claude defaults
**Notes:** D-49–D-51. Guests may buy; optional result text link; no IAP UI.

---

## MVP assortment

| Option | Description | Selected |
|--------|-------------|----------|
| All ECON-02 slots, thin SKU set | Incl. Stick Pull skins (apply in Phase 6) | ✓ |
| Alchiki-only first | Defer Stick Pull skins | |
| Full live-ops catalog | Dozens of SKUs | |

**User's choice:** «все» — accept Claude defaults
**Notes:** D-52–D-54. PRES-02 themes; cosmetics presentation-only.

---

## Equip and preview

| Option | Description | Selected |
|--------|-------------|----------|
| Shop shell Shop\|Owned; server loadout | Equip at match start; felt preview in shop | ✓ |
| Profile-only inventory | Depends on Phase 5 profile | |
| Mid-throw live swap | Change look mid-bout | |

**User's choice:** «все» — accept Claude defaults
**Notes:** D-55–D-57. No mid-throw swap; default free starter.

---

## Claude's Discretion

- Grant tables, gem rarity, SKU prices
- Shop chrome / wallet chip placement (UI-SPEC)
- Flyway names, REST paths, event wiring
- Exact thin SKU count

## Deferred Ideas

- IAP, bind-gated shop, profile cosmetics, Stick Pull playable, daily chest, wager/gacha
