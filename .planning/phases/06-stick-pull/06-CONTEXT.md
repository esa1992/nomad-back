# Phase 6: Stick Pull - Context

**Gathered:** 2026-09-14
**Status:** Ready for planning

<domain>
## Phase Boundary

This phase makes **Stick Pull** a second playable catalog title: server **3-2-1-GO**, shared-stick tug with **live marker**, **stamina + tap clamp**, skippable static how-to (EN+RU), **EASY/NORMAL/HARD** bots with human-like jitter, and **online** play with a **short reconnect (~8s casual) then forfeit** and **no bot-fill mid-tug**.

Success is CAT-02, STICK-01…STICK-05, BOT-02, SESS-04. Not Ranked/bind (Phase 7), couch same-device tug (STICK-06), Alchiki physics reuse, real IAP, or auto-ban anti-cheat SDKs.

Do **not** reopen: guest-first, EN+RU, PRES-02 palette, SESS-01 server authority, shop Stick Pull skins already buyable (D-52 — **apply** visuals here), private/QM shells from Phases 3–5, Alchiki hold-to-throw / Forge2D table.

</domain>

<decisions>
## Implementation Decisions

> User: «проанализируй сам и выбери первое общепринятое решение» — all gray areas locked to REQUIREMENTS + FEATURES Stick Pull Spec (first-principles parlor defaults). No interactive Q&A.

### Online modes for Stick Pull MVP (analyzed — platform parity)
- **D-78:** Stick Pull ships **bot + private room + Casual Quick Match** in this phase — same entry surface as Alchiki (catalog tile primary paths). Ranked Stick Pull is **Phase 7** (MODE-04). Do not invent a Stick-Pull-only mode set.
- **D-79:** Bot path: EASY / NORMAL / HARD chips on the Stick Pull tile (BOT-02). Private: reuse create/join room + Ready + rematch patterns; Stick Pull match instead of Alchiki table. Quick Match: reuse casual queue/fallback (bot/invite) with game=`STICK_PULL` (or equivalent discriminator) — empty-queue still never a 60s fail spinner.
- **D-80:** Rematch after Stick Pull follows existing mode rules: bot → one-tap Play again; private/casual PvP → dual-accept window (Phase 3/5). New match is Stick Pull, same seats where applicable.

### Feel & chrome (analyzed — FEATURES presentation + PRES-02)
- **D-81:** Shared **1D lane** with a **center marker** (knot / stick midpoint). Players sit opposite (presentation). **Stamina bar under the avatar**; when stamina flashes / exhausts, the marker **visibly slips** so the player reads *why* they lost.
- **D-82:** Server drives **3-2-1-GO**; client shows countdown then GO. **Haptics only on GO and threshold win** — not every tap. No freeze/snap/power-up pickups.
- **D-83:** Equipped **Stick Pull skins** from economy loadout apply at match start (presentation-only; D-54). Default free skin if unequipped.

### How-to Stick Pull (analyzed — mirror Alchiki + FEATURES five cards)
- **D-84:** Full-screen static card pager **before first Stick Pull match** (same product pattern as Alchiki D-12…D-14): skip available on card 1; auto-show once per device; later matches skip to tug; reopen same deck from Pause → How to play.
- **D-85:** **Five cards** (FEATURES): (1) opposite sit + stick, (2) wait for GO, (3) tap in rhythm, (4) stamina = don't mash, (5) pull the marker over. EN+RU via l10n. No animated coach overlays.

### Reconnect / forfeit mid-tug (analyzed — SESS-04 + FEATURES)
- **D-86:** Online Stick Pull reconnect grace **~8s casual** (SESS-04). Ranked ~12s is **out of this phase**. On expiry: **forfeit** for the dropped player; remaining player **wins**. **No bot-fill mid-tug** (explicit SESS-04 / D-42 spirit).
- **D-87:** During grace the opponent sees a clear **reconnect / waiting** state (countdown or short copy); on forfeit show result and rematch/catalog CTAs. Do not silently continue as if the seat were AI-filled.

### Stamina & tap rules (analyzed — lock FEATURES Stick Pull Spec)
- **D-88:** Adopt FEATURES v1 stamina table as product lock: soft band **0–6** taps/s full force; hard clamp **10** accepted taps/s (extras drop, no force); burst **8–10** for ≤1.5s reduced force + fast drain; exhaustion force ×0.15 until stamina ≥25%; recovery after **~280–350ms** no-tap. Exact numeric micro-tuning within these bands is Claude’s discretion if playtests demand it — do not remove bands.
- **D-89:** Match length: target **~20–30s** typical; hard clamp **15–40s**; clock always ends a stalemate. Win = marker crosses threshold **or** ahead at clock 0.
- **D-90:** Pre-GO taps in **casual/bot/private/QM** (this phase): **ignore** + light false-start feedback (FEATURES casual). Ranked false-start penalties wait for Phase 7.
- **D-91:** Server **re-timestamps** taps and simulates stamina; client interpolates marker. Soft **suspect** log on robotic regularity; **no auto-ban** in v1 (STICK-04).

### Claude's Discretion
- Exact force-per-tap constants, marker friction, win-threshold distance, bot jitter curves within EASY/NORMAL/HARD envelopes.
- Whether Stick Pull uses a dedicated Modulith package vs `games.stickpull` beside Alchiki; REST vs WS frame names — as long as D-78…D-91 and SESS-01 hold.
- Catalog tile chrome (promote from Coming Soon) and tug HUD layout within PRES-02 — UI-SPEC.
- Whether QM Stick Pull shares one queue service with a `game` field or a parallel FIFO — planner chooses; product is D-79.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase and requirements
- `.planning/ROADMAP.md` — Phase 6 goal and success criteria
- `.planning/REQUIREMENTS.md` — CAT-02, STICK-01…05, BOT-02, SESS-04; defer STICK-06, MODE-04 Ranked
- `.planning/PROJECT.md` — catalog promise; server authority; parlor feel
- `.planning/STATE.md` — position after Phase 5 complete

### Research (authoritative Stick Pull feel)
- `.planning/research/FEATURES.md` — **Stick Pull Stamina / Anti-Autoclicker Spec (v1)** — countdown, bands, bots, how-to cards, presentation

### Prior phase locks
- `.planning/phases/02-guest-catalog-first-alchiki-match/02-CONTEXT.md` — D-12…D-17 how-to + catalog Coming Soon → promote Stick Pull
- `.planning/phases/03-private-rooms-casual-reconnect/03-CONTEXT.md` — D-26–D-44 rooms, rematch, reconnect patterns; no bot-fill friend’s seat
- `.planning/phases/04-economy-cosmetic-shop/04-CONTEXT.md` — D-52 Stick Pull skins buyable; D-54 presentation-only
- `.planning/phases/05-casual-quick-match-profile/05-CONTEXT.md` — D-62…D-77 QM/fallback/rematch; Stick Pull stats were zeros
- Prior UI-SPECs `02`–`05` — catalog/match/shop chrome to extend; do not reinvent palette

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `client/lib/catalog/` — promote `stick_pull` tile from Coming Soon to playable + bot chips + entry CTAs
- Alchiki how-to pager — clone pattern for Stick Pull five cards (new copy/assets)
- `matchmaking` private rooms + `CasualQueueService` — extend with game discriminator for Stick Pull
- Economy loadout Stick Pull skin slots — consume at Stick Pull match create
- Profile `STICK_PULL` stats rows — start incrementing on settle (were zeros)

### Established Patterns
- Server authority + raw WS for human in-play; REST for lobby/queue/bot start
- Bot settle grants + rematch dual-accept / one-tap
- Guest JWT; EN+RU ARB

### Integration Points
- New Stick Pull match engine (not Forge2D Alchiki) — 1D marker + stamina sim on server
- Catalog CAT-02 flip; how-to route; match page / Flame or Flutter overlay for tug chrome
- Reconnect policy shorter than Alchiki’s 30s (8s) for Stick Pull online only

</code_context>

<specifics>
## Specific Ideas

- User declined interactive discuss and asked for the **first generally accepted** lock per area → FEATURES Stick Pull Spec + existing platform mode parity.
- False-start Ranked penalties explicitly deferred; casual ignore is the v1 online behavior.
- Couch two-thumb (STICK-06) stays deferred / v2.

</specifics>

<deferred>
## Deferred Ideas

- Ranked Stick Pull false-start penalties and ~12s reconnect (Phase 7 / SESS-03 overlap)
- STICK-06 same-device couch tug
- Auto-ban / hidden MMR penalty for suspect taps (v1.x)
- Redis shared queue / multi-instance Stick Pull MM
- Power-ups, freeze, snap (explicitly rejected in FEATURES)

</deferred>

---

*Phase: 6-Stick Pull*
*Context gathered: 2026-09-14*
