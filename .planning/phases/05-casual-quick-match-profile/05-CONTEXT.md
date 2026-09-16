# Phase 5: Casual Quick Match + Profile - Context

**Gathered:** 2026-09-11
**Status:** Ready for planning

<domain>
## Phase Boundary

This phase delivers **Casual Quick Match** for Alchiki (queue → human opponent, or short search then bot/invite fallback — never a 60s fail spinner) plus a **player profile** (Guest/username later, avatar presets, level/XP, W/L, soft casual rating, selected cosmetics, per-game stats).

Success is MODE-03, PROF-01, PROF-02, PROF-03 — and rematch after casual still works (MODE-05 / Phase 3 D-43 extended). Not Ranked/bind (Phase 7), Stick Pull playable (Phase 6), real IAP, friends graph, or Redis-as-SoT queues (Postgres owns outcomes; queue impl is planner/researcher within product locks).

Do **not** reopen: guest-first (D-16), private rooms (D-26–D-44), economy/shop/equip (D-45–D-61), physics stack, or SESS-01 (server authors scores/currency/rating updates).

</domain>

<decisions>
## Implementation Decisions

### Empty-queue fallback (discussed)
- **D-62:** After joining Casual Quick Match, run a **short search (~5–10 s)**. If no human pair: show a **choice screen** — never a long fail spinner. Exact seconds in that band is Claude’s discretion.
- **D-63:** Fallback actions are **two equal buttons** side by side: **Play vs bot** and **Invite friend** — no primary/secondary hierarchy.
- **D-64:** **Invite friend** = **Create private room** (same as catalog Create Room: code + system share). Player **leaves the casual queue** when creating the room. Do not invent a “share into the same MM pool” deep link in this phase.
- **D-65:** During search, **Cancel** is always available → catalog and **dequeue immediately**. Fallback screen also has **Back to catalog** (leave without bot/invite).

### Quick Match entry & pairing (discussed)
- **D-66:** **Quick Match** is the **primary CTA on the Alchiki tile**. Bot play and private create/join stay **secondary** (existing Private band + bot path). Do not replace the whole catalog with a single global QM bar.
- **D-67:** Search UI is **full-screen “Searching…”** (spinner/pulse) + **Cancel** — minimal copy, **no countdown timer** to fallback.
- **D-68:** Pairing is **first-available** in the casual queue for MVP. No latency/region or win-rate band matching yet (FEATURES can inform a later upgrade).
- **D-69:** Casual Quick Match PvP tables are always **NORMAL** (same as private D-31). Catalog difficulty chips remain **bot-only**.

### Casual rematch (discussed)
- **D-70:** After casual Quick Match **PvP**, rematch CTA is **one-tap “Play again”** (bot-style label/feel), not the private “Again?” dual-prompt chrome.
- **D-71:** Semantics stay **same-opponent dual-accept**: Play again means “I want another with this player”; the new match starts only when **both** have accepted.
- **D-72:** Accept window is **10 s** (aligned with private rematch / FEATURES casual online). If the other player does not accept → both return to **catalog**.
- **D-73:** After tapping Play again, leave the ResultOverlay for a **short dedicated waiting screen** (not status text on the result overlay). Waiting screen must allow cancel → catalog.

### Profile + avatar (discussed)
- **D-74:** Catalog top bar gains an **avatar chip** (tap → profile). Shop + wallet chip stay; do not open profile from the wallet chip.
- **D-75:** Profile shows the full PROF-01 set for guests now: **Guest** display name, avatar, level, XP, matches, wins, losses, win rate, **soft casual rating** + best rating, and **selected cosmetics** (read-only; equip remains in Shop per D-55). XP/level grow from **any finished match**; rating is **casual soft MMR**, not Ranked/Glicko (Phase 7 may replace or fork the formula later).
- **D-76:** Avatars: **~6–8 original presets**, change **only in profile** (grid → equip). No photo upload. Do not sell avatar presets as Shop SKUs in this phase.
- **D-77:** Per-game stats (PROF-02): show **both Alchiki and Stick Pull** sections. Alchiki uses live numbers; Stick Pull shows **zeros / “No matches yet”** until Phase 6 makes it playable — do not hide the section.

### Claude's Discretion
- Exact search timeout in the 5–10 s band; queue storage (in-memory vs Postgres) and REST/WS shape for enqueue/match — as long as D-62–D-69 hold.
- Soft casual MMR / XP curve numbers and level thresholds (must be server-authored; client display-only).
- Avatar art style within PRES-02 / nomadic catalog look; default preset for new guests.
- Waiting-screen and Searching chrome (UI-SPEC); how bot difficulty is chosen when falling back from QM (reuse last catalog chip vs force NORMAL) — prefer reuse of existing bot start path.
- Whether casual rematch reuses private rematch seat plumbing or a dedicated casual rematch ticket — product behavior is D-70–D-73.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase and requirements
- `.planning/ROADMAP.md` — Phase 5 goal, success criteria, MODE-03, PROF-01…03
- `.planning/REQUIREMENTS.md` — MODE-03, MODE-05, PROF-01…03, SESS-02 (30s casual reconnect already shipped); do not implement MODE-04 Ranked, AUTH-02 bind, CAT-02 Stick Pull playable, PAY-*
- `.planning/PROJECT.md` — guest-first; profile/stats; server authority; no real IAP
- `.planning/STATE.md` — milestone position after Phase 4 complete

### Research
- `.planning/research/FEATURES.md` — Quick Match empty-queue bot/invite; rematch 10s for private/casual online; profile/avatar/XP; Redis queues later

### Prior phase locks
- `.planning/phases/02-guest-catalog-first-alchiki-match/02-CONTEXT.md` — D-16–D-25 guest catalog, bot Alchiki
- `.planning/phases/03-private-rooms-casual-reconnect/03-CONTEXT.md` — D-26–D-44 private rooms, NORMAL PvP, rematch, 30s reconnect, no bot-fill of friend’s seat (D-42)
- `.planning/phases/03-private-rooms-casual-reconnect/03-UI-SPEC.md` — catalog/match chrome to extend
- `.planning/phases/04-economy-cosmetic-shop/04-CONTEXT.md` — D-45–D-61 wallets, shop, equip; inventory in Shop not profile
- `.planning/phases/04-economy-cosmetic-shop/04-UI-SPEC.md` — wallet chip / shop patterns to keep beside profile chip

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `client/lib/catalog/catalog_page.dart` — Alchiki tile + Private band + Shop/wallet top bar; add QM primary + avatar chip
- `client/lib/games/alchiki/match_page.dart` + `pause_overlay.dart` — ResultOverlay rematch/bot paths; extend for casual PvP Play again + waiting screen
- `backend/.../matchmaking/` — `RoomService` / create-join private rooms for Invite fallback (D-64)
- Economy settle + wallet chip — profile reads cosmetics/loadout; do not move equip out of Shop

### Established Patterns
- Private PvP: REST lobby + raw WS in-play (D-38); NORMAL only (D-31); rematch 10s dual-accept (D-43)
- Bot: REST settle; one-tap Play again
- Guest labels Guest-XXXX (D-33); bind still Phase 7

### Integration Points
- New casual queue enqueue/dequeue + match create when two players paired → same Alchiki authority/WS path as private (or thin wrapper)
- Fallback bot → existing bot match start; fallback invite → existing `createRoom`
- Profile REST aggregate: stats, soft rating, avatar id, equipped cosmetics from economy loadout
- Reconnect: SESS-02 30s already applies to Casual Alchiki — ensure QM matches are tagged casual so rejoin works

</code_context>

<specifics>
## Specific Ideas

- User selected **all four** gray areas and answered every question explicitly (no “You decide” picks).
- Rematch nuance: **bot-like Play again button** + **private-like both-must-accept + 10s**, then **dedicated waiting screen** (not overlay status).
- Empty-queue Invite deliberately reuses **private room**, not a second queue protocol.

</specifics>

<deferred>
## Deferred Ideas

- Latency/region and win-rate band matchmaking (FEATURES) — post-MVP when queue is populated
- Ranked / Glicko-2 / soft season reset — Phase 7
- Stick Pull playable + real Stick Pull stats — Phase 6
- Avatar SKUs in Shop; photo upload — out of v1
- Redis-backed queues as scale path — REQUIREMENTS out-of-scope note

None from discussion left the phase boundary without being deferred above.

</deferred>

---

*Phase: 5-Casual Quick Match + Profile*
*Context gathered: 2026-09-11*
