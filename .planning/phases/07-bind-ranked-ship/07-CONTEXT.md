# Phase 7: Bind, Ranked + Ship - Context

**Gathered:** 2026-09-14
**Status:** Ready for planning

<domain>
## Phase Boundary

This phase ships the **guest → bound identity** loop, **honest Ranked** (Glicko-2, bind-required, no bots, cosmetics ignored), **skill leaderboards** (per game / season / all-time; soft season reset; guests and coin ladders excluded), **backend analytics events in logs** (no SaaS), and **releasable hardening** (CI + PROD compose folded in — not a standalone DevOps phase).

Success is AUTH-02, AUTH-03, AUTH-04, MODE-04, SESS-03, LEAD-01, LEAD-02, LEAD-03, ANLT-01.

Do **not** reopen: guest-first (D-16), SoftElo casual (D-75), private/QM/Stick Pull casual reconnect (Phases 3–6), shop/equip presentation-only (D-45…D-61), Forge2D pin, real IAP, OAuth-as-required, Redis-as-truth, K8s, analytics SaaS.

</domain>

<decisions>
## Implementation Decisions

> User: «обработай всё самостоятельно, выбери оптимальные вариант» — all gray areas locked to REQUIREMENTS + FEATURES / STACK / PITFALLS parlor defaults. No interactive Q&A.

### Bind UX (AUTH-02…04)
- **D-92:** Soft **bind prompt after first Alchiki bot win** (FEATURES funnel) — sheet/dialog, dismissible; not a splash wall. Always reachable later from **Profile** (Bind / Sign in / Log out).
- **D-93:** Bind **links username + password to the same `playerId`**. Username taken → **409** with a clear **Sign in** path. After sign-in to an existing bound account: **never sum/max wallets, cosmetics, XP, SoftElo, or Glicko** onto a non-empty target. Optional one-time import only if the signed-in target has **zero matches and zero spend** (PITFALLS) — otherwise keep the signed-in account as-is and drop the guest device row only after explicit confirm when progress would be lost.
- **D-94:** Password: **min 8 characters**; store with a modern password hash (Argon2id or bcrypt — planner picks one stack-standard). Refresh tokens already rotate (AUTH-03); reuse that path for bound sessions. No email/phone verification in this phase (forgot-password is deferred).
- **D-95:** **Log out** clears access/refresh on device and returns the UI to a guest-capable catalog; **device guest identity remains** until bind succeeds or reinstall (AUTH-04). Bound players stay signed in across restarts via rotating refresh (AUTH-03).
- **D-96:** Soft-lock **Ranked enqueue + global leaderboards** behind bind. **Do not** re-lock Casual bot / private / QM or the existing guest shop — those stay open for guests (FEATURES soft-lock Ranked/boards; shop already shipped for guests in Phase 4).

### Ranked queue & match (MODE-04)
- **D-97:** Ranked ships for **both live titles** — Alchiki and Stick Pull — with **per-game FIFO** queues (same discriminator pattern as Casual D-79). Bind required; enqueue rejects guests.
- **D-98:** **No bot opponent** and **no empty-queue bot/invite fallback** in Ranked. Searching UI can wait indefinitely with Cancel; never a 60s fail-then-bot. Cosmetics ignored for rating (already presentation-only).
- **D-99:** Ranked rematch is **out of MVP** (FEATURES optional later). After settle → boards/catalog/Play again = new Ranked search, not dual-accept rematch.
- **D-100:** Stick Pull Ranked adopts FEATURES false-start rule: **first false start → stamina starts at 70%**; **second → rated forfeit**. Casual Stick Pull keeps D-90 ignore.

### Ranked reconnect (SESS-03)
- **D-101:** Ranked grace: **Alchiki 18s**, **Stick Pull 12s** per drop (ROADMAP ~15–20s band + Stick Pull shorter tug; FEATURES checklist). Casual stays **30s / 8s**. Consented leave = **0s** rated loss.
- **D-102:** **Aggregate pause budget** per Ranked match: **Alchiki 45s**, **Stick Pull 20s** (sum of grace pauses). When budget is exhausted, the **next** disconnect is **immediate rated forfeit** (stops pause-griefing). Clocks/tug deadline **pause** during grace (D-41 / Phase 6 CR clock freeze).
- **D-103:** On grace expiry or budget forfeit: **rated loss** for the dropped seat; remaining player **rated win**. **No bot-fill**. Opponent HUD shows reconnect + server timer (existing chrome).

### Glicko-2, seasons, boards (LEAD-01…03)
- **D-104:** Vendored **Glicko-2** in-repo (STACK): defaults **r=1500, RD=350, σ=0.06, τ=0.5**. Rating is **per game** (Alchiki vs Stick Pull separate). Update **only on Ranked settle** (including rated forfeit/draw rules). SoftElo casual **unchanged** (D-75 fork).
- **D-105:** **Seasons:** calendar **quarter** (~90 days). Soft reset at season boundary: move rating toward 1500 (e.g. `1500 + 0.5*(r-1500)`) and **inflate RD** toward 350 — exact formula Claude’s discretion within “soft, not wipe”. All-time board keeps lifetime peak / all-time rated score separately from season rating.
- **D-106:** Leaderboards: **bound players only**; filter by **game**; toggle **current season vs all-time**. **Never** rank by coins/gems. Entry: **Profile → Boards** plus a catalog/profile chip for bound users (PRES-02). Top-N list (~50–100) is enough for MVP.

### Analytics + Ship (ANLT-01 + releasable)
- **D-107:** Backend **EventSink**: emit **APP_STARTED, REGISTERED, LOGIN, MATCHMAKING_STARTED, MATCH_FOUND, MATCH_STARTED, MATCH_FINISHED, MATCH_ABANDONED, ITEM_PURCHASED** as structured JSON logs (+ optional Postgres append-only table if cheap). **No** Amplitude/Firebase/Grafana SaaS in this phase.
- **D-108:** **Ship harden:** GitHub Actions on PR — Maven backend tests + Flutter analyze/test; **docker-compose PROD** = Postgres + single app JAR; Android is the proof release target; keep iOS target compilable. **No** K8s, Redis-as-truth, or multi-service split.

### Claude's Discretion
- Exact bind sheet copy/timing animation; password hasher choice (Argon2id vs bcrypt); Glicko period (calendar day vs N games) within D-104.
- Soft-reset coefficient and all-time storage schema within D-105.
- Whether Ranked queue shares `CasualQueueService` with a `mode=RANKED` flag or a sibling service — product locks are D-97…D-99.
- CI matrix runners / cache; EventSink table vs log-only for ANLT-01.
- Ranked Alchiki draw policy when neither side scores (FEATURES last-knock-out / Glicko draw) — pick one consistent with Glicko-2 and document in plan.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase and requirements
- `.planning/ROADMAP.md` — Phase 7 goal and success criteria
- `.planning/REQUIREMENTS.md` — AUTH-02…04, MODE-04, SESS-03, LEAD-01…03, ANLT-01
- `.planning/PROJECT.md` — guest→bind, Ranked not P2W, server authority, modular monolith
- `.planning/STATE.md` — position after Phase 6 complete

### Research
- `.planning/research/FEATURES.md` — bind funnel, Ranked/reconnect checklist (~15–20s + pause budget), boards, Stick Pull Ranked false-start
- `.planning/research/STACK.md` — Glicko-2 vendored defaults (r/RD/σ/τ)
- `.planning/research/PITFALLS.md` — Pitfall 5 bind/wallet-sum; Pitfall 4 reconnect policies; no Ranked on guests
- `.planning/research/ARCHITECTURE.md` — identity / rating / analytics Modulith seams
- `.planning/research/SUMMARY.md` — guest→bind→Ranked order (ROADMAP collapsed into Phase 7)

### Prior phase locks
- `.planning/phases/02-guest-catalog-first-alchiki-match/02-CONTEXT.md` — D-16 guest mint; bind deferred
- `.planning/phases/03-private-rooms-casual-reconnect/03-CONTEXT.md` — D-41…D-42 reconnect patterns
- `.planning/phases/04-economy-cosmetic-shop/04-CONTEXT.md` — wallets/shop; no-sum discipline
- `.planning/phases/05-casual-quick-match-profile/05-CONTEXT.md` — D-75 SoftElo ≠ Glicko; profile chip
- `.planning/phases/06-stick-pull/06-CONTEXT.md` — D-86…D-91 Stick Pull; Ranked false-start reserved here

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `identity` — `GuestService` mint + `TokenService` refresh rotation; extend with bind/login/logout credentials on same `PlayerEntity`
- `profile` — SoftElo + XP/W/L; add Glicko fields or sibling rating table without replacing SoftElo
- `CasualQueueService` + `GameDiscriminator` — clone/extend for Ranked FIFO + bind gate
- `ReconnectPolicy` — already game-aware (30s / 8s); add Ranked mode + aggregate pause budget
- `client/lib/platform/auth/session_store.dart` + profile/catalog chrome — bind sheet, logout, boards entry
- Economy settle hooks — Ranked settle triggers Glicko update (cosmetics ignored)

### Established Patterns
- Guest JWT + rotating refresh; server-authored match outcomes
- Per-game queues and reconnect policies
- EN+RU ARB; PRES-02 catalog/profile chips

### Integration Points
- New credential store + bind/login APIs; Ranked matchmaking mode; rating module; leaderboard REST; EventSink; CI workflows + PROD compose beside existing DEV compose

</code_context>

<specifics>
## Specific Ideas

Analyzed defaults from FEATURES/STACK/REQUIREMENTS (user delegated). No additional “make it like X” references beyond Miniclip guest→bind and MiniTon-style ranked reconnect budget.

</specifics>

<deferred>
## Deferred Ideas

- Forgot-password / email recovery (FEATURES v1.x)
- OAuth as *additional* bind method
- Bind GEMS reward / daily COINS if bind rate is low
- Ranked rematch dual-accept
- Suspect-tap MMR penalty on Ranked Stick Pull (log-only stays)
- Redis queues, K8s, analytics SaaS, Prometheus/Grafana
- Friends / country boards, tournaments, season pass

None — discussion stayed within phase scope for product locks; list above is backlog only.

</deferred>

---

*Phase: 7-Bind, Ranked + Ship*
*Context gathered: 2026-09-14*
