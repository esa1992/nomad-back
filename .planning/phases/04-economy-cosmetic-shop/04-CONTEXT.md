# Phase 4: Economy + Cosmetic Shop - Context

**Gathered:** 2026-09-10
**Status:** Ready for planning

<domain>
## Phase Boundary

This phase delivers the **cosmetic economy loop**: after matches the server grants **COINS** (and occasional **GEMS**); the player browses a **cosmetic shop**, buys with soft currency only, and **equips** owned items that never change physics, tap power, or aim assist.

Success is ECON-01…ECON-05 — not real IAP (PAY-*), Quick Match (Phase 5), Stick Pull playable (Phase 6), bind/Ranked (Phase 7), profile W/L surface as a product goal (PROF-* is Phase 5), wager tables, loot boxes, or daily-login spinners.

Do **not** reopen the physics stack (Flutter 3.47 + Flame 1.38 + forge2d 0.14.2 / flame_forge2d 0.19.3+7 + dyn4j 6). Do **not** reopen SESS-01: the client still cannot author scores or grant currency. Phase 3 rooms/reconnect/rematch stay; this phase **adds** ledger + shop beside them.

</domain>

<decisions>
## Implementation Decisions

### Reward moment after a match (discussed — user: all defaults)
- **D-45:** Match settlement stays **server-only**. On terminal result the server grants currency once per `(matchId, playerId, reason)` and includes the grant in the result payload the client already uses for `ResultOverlay` (bot REST settle and private WS/HTTP result path). The client never POSTs a `coinsDelta`.
- **D-46:** Rewards appear **on the existing result screen**, not a separate blocking wallet screen: short `+N COINS` / `+M GEMS` lines under the outcome. Rematch / Back to catalog remain the primary actions (D-43). No “coins fly into a distant chip” as a required gate before rematch.
- **D-47:** Flat casual rewards: **win > loss** (and draw if the rules emit one). Difficulty may scale COINS slightly for bot matches. **GEMS are scarce** (occasional; not every match). Exact amounts and gem drop rate are Claude’s discretion — must feel like a reward without flooding GEMS.
- **D-48:** Catalog (and shop header) show a **read-only dual wallet chip** (COINS | GEMS) refreshed from server balance after settle and after purchase. Displayed numbers never authorize a buy.

### Shop entry and first screen (discussed — user: all defaults)
- **D-49:** Primary entry is a **Shop** control on the **catalog** (tile or top-bar button — UI-SPEC picks chrome). Secondary: optional text link **Shop** on the result overlay that does **not** replace Rematch / Play again. No real-money checkout, no IAP banners.
- **D-50:** Shop is its own `go_router` route (e.g. `/shop`). First screen is a **category shelf + SKU grid** (not a long unstructured list): categories match ECON-02. EN+RU via existing l10n. Empty / error: short copy + retry; never invent local stock.
- **D-51:** Guests may **browse, buy, and equip** with earned soft currency. Do **not** soft-lock the shop behind bind in this phase (bind is Phase 7; guest identity already owns progress).

### MVP assortment (discussed — user: all defaults)
- **D-52:** Ship **all ECON-02 slots** this phase with a **thin SKU set** (default free starter + a few paid themes), not a full live-ops catalog: saka **color / material / ornament**, **trail**, **table/FX effects**, **victory animation**, and **Stick Pull skins**. Stick Pull skins are buyable and equippable now; they apply when Stick Pull becomes playable (Phase 6). Do not invent P2W stats, frames-as-power, or weighted sakas.
- **D-53:** Visual themes stay inside PRES-02: **Gold / Neon / Ice / Fire / Space** plus **original ornaments** — no third-party brand IP. Default free loadout so a new guest is never “naked” on the table.
- **D-54:** Cosmetics are **presentation-only**. Same mass, restitution, aim chrome, tap force, and stamina rules for every SKU (ECON-03 / Ranked trust later).

### Equip, inventory, preview (discussed — user: all defaults)
- **D-55:** **Inventory lives inside the shop shell** (tab or segment: Shop | Owned) — not a separate Phase 5 profile dependency. Owned items show **Equip**; equipped shows **Equipped**. Unequip / switch returns the slot to the **default free** SKU (or the newly equipped one) — no empty slot that breaks render.
- **D-56:** Equip is **server-authoritative loadout**. Client sends equip intent; server stores selected SKU per slot; next match (and rematch) loads that loadout into spawn/presentation. **No mid-throw swap** — changes apply at match start / rematch kickoff so private opponents share a stable look for the bout.
- **D-57:** Shop detail shows a **static felt preview** of the saka/trail/effect (catalog palette). Live table uses the equipped set from the server loadout at match create — do not trust client-only prefs for what the opponent sees.

### Ledger, purchase, IAP shell (not discussed — lock REQUIREMENTS + research)
- **D-58:** Dual wallets **COINS + GEMS** from day one. Only the **`economy`** module writes balances via **ledger inserts** (JdbcClient-style; never “load entity, mutate balance”). Session/match settlement publishes a settle/reward event; economy consumes **idempotently** (`matchId:reason`).
- **D-59:** Soft-currency purchase uses a **client-generated idempotency key** + unique constraint so retry/double-tap cannot double-spend (ECON-05). Insufficient funds → clear error, no partial grant.
- **D-60:** Create an empty **`purchases`** (or equivalent) table with **unique provider token** column so later Play/App Store IAP can attach without rewriting wallets (ECON-05). **No** Play Billing / Apple IAP / checkout UI in this phase.
- **D-61:** No coin-wager tables, entry fees, gacha/loot boxes, or daily-login ad spinners. Match-play remains the reward loop.

### Claude's Discretion
- Exact COINS/GEMS grant tables, gem rarity curve, and SKU prices.
- Shop layout chrome (grid vs shelves, category chips), wallet chip placement on catalog, result-overlay reward typography — UI-SPEC / planner within PRES-02 (`#1B6B3A` felt, `#241810` wood, `#F0B429` gold).
- Flyway table names, Modulith package wiring (`economy` events from `session`), REST paths under `/v1/...`, and whether Stick Pull skin preview uses a stick illustration vs text-only card.
- How many paid SKUs ship in the thin set (aim for “default + a few themes,” not dozens).
- Whether bot and private matches share one reward table or differ slightly — win > loss and scarce GEMS must hold either way.

</decisions>

<specifics>
## Specific Ideas

- User answered **«все»** — treat as accept defaults for every gray area (reward moment, shop entry, assortment, equip/preview) without further Q&A.
- Research FEATURES soft-lock of “shop spend behind bind” is **not** adopted here; guest-first MVP and AUTH-02 (bind keeps wallets) win. Soft-lock can be reconsidered in Phase 7 if funnel data needs it.
- SUMMARY’s old “Phase 6 = economy” numbering is obsolete — **ROADMAP Phase 4** is authoritative.

</specifics>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase and requirements
- `.planning/ROADMAP.md` — Phase 4 goal, success criteria, ECON-01…05
- `.planning/REQUIREMENTS.md` — ECON-01…05, PRES-02; do not implement PAY-01/02, MODE-03/04, AUTH-02, CAT-02, PROF-*, STICK-* playable
- `.planning/PROJECT.md` — no real IAP in MVP; cosmetics; server authority; modular monolith
- `.planning/STATE.md` — current milestone position after Phase 3 complete

### Prior phase locks
- `.planning/phases/01-alchiki-physics-prototype/01-CONTEXT.md` — physics / forge2d pins; cosmetics must not touch throw feel
- `.planning/phases/02-guest-catalog-first-alchiki-match/02-CONTEXT.md` — D-12–D-25 guest catalog; D-25 deferred shop until this phase
- `.planning/phases/03-private-rooms-casual-reconnect/03-CONTEXT.md` — D-26–D-44 rooms, rematch, reconnect; ResultOverlay primary CTAs stay rematch/catalog
- `.planning/phases/03-private-rooms-casual-reconnect/03-UI-SPEC.md` — catalog/match chrome to extend; shop/wallets were out of Phase 3

### Economy research
- `.planning/research/FEATURES.md` — dual currency HUD, cosmetic-only shop, no IAP/wager/gacha in v1; flat match reward win > loss
- `.planning/research/ARCHITECTURE.md` — `economy` module, ledger, `MatchSettled` / reward consumers, REST for shop
- `.planning/research/STACK.md` — JdbcClient ledger writes; go_router shop routes; Postgres truth
- `.planning/research/PITFALLS.md` — Pitfall 6 (client balances / missing purchase-token table)
- `.planning/research/SUMMARY.md` — ledger + empty purchases table; ignore obsolete phase numbering that put economy at “Phase 6”

### Code to extend
- `client/lib/catalog/catalog_page.dart` — Shop entry + wallet chip
- `client/lib/games/alchiki/pause_overlay.dart` — ResultOverlay reward lines; keep rematch CTAs primary
- `client/lib/platform/router.dart` — `/shop` (and inventory segment) routes
- `client/lib/platform/api/nomad_api.dart` — wallet/shop/equip REST beside existing match/room APIs
- `backend` Modulith — new `economy` package; session settle already decides winners (hook grants there); no client-trusted balance writes

No SPEC.md for this phase. No external ADRs.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- Catalog + `go_router` + i18n EN/RU + guest JWT — add Shop CTA and wallet chip; do not rebuild identity.
- `ResultOverlay` — add grant lines under outcome; do not replace D-43 rematch behavior.
- Palette constants already in catalog/pause overlays (`#1B6B3A`, `#241810`, `#F0B429`) — shop preview reuses felt/wood language.
- Match settlement paths (bot REST + private session) — publish one settle event for economy to consume.

### Established Patterns
- Server Instants / server outcomes are truth; client HUD is display-only (same rule for wallets).
- REST + JWT for platform surfaces; raw WS stays match-only (D-38) — shop does **not** need a socket.
- Modulith packages by domain; avoid new cycles (`economy` listens to session events, does not call game physics).

### Integration Points
- Catalog `/` → Shop `/shop` → buy/equip → back to catalog → next match loads loadout.
- After match: settle → ledger grant → result payload includes grant → overlay shows `+COINS`/`+GEMS` → rematch or catalog (chip refresh).
- Opponent presentation: match create/rejoin snapshot should carry each seat’s equipped cosmetic ids so both clients render the same looks.

</code_context>

<deferred>
## Deferred Ideas

- Real-money IAP / Play Billing / Apple IAP (PAY-01/02, post-MVP)
- Soft-lock shop spend behind bind (FEATURES hypothesis — revisit Phase 7 if needed)
- Profile screen showing selected cosmetics + W/L (Phase 5 PROF-*)
- Stick Pull playable table that consumes equipped stick skins (Phase 6)
- Daily COINS chest, bind GEMS reward, season pass, gacha (v1.x / v2+)
- Coin-wager tables, P2W cue stats (never for Ranked trust)

None extra from this discussion — user stayed inside Phase 4 and accepted defaults.

</deferred>

---

*Phase: 4-Economy + Cosmetic Shop*
*Context gathered: 2026-09-10*
