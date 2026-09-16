# Phase 2: Guest Catalog + First Alchiki Match - Context

**Gathered:** 2026-09-06
**Status:** Ready for planning

<domain>
## Phase Boundary

This phase delivers the **first honest product loop**: a guest (no username) opens a localized catalog, taps Alchiki, reads skippable static how-to cards, and finishes a short **server-scored** match against a scripted bot.

Success is AUTH-01, CAT-01, CAT-03, ALCH-01–ALCH-05, BOT-01, BOT-03, SESS-01, PRES-01, PRES-02 — not rooms, reconnect, shop, Stick Pull playable, bind, Ranked, or Glicko-2.

Do **not** reopen the Phase 1 physics stack (Flutter 3.47 + Flame 1.38 + forge2d 0.14.2 / flame_forge2d 0.19.3+7 + dyn4j 6, 2.5D / 2D, no lockstep). If the throw feel regresses, fix wiring — do not swap engines.

</domain>

<decisions>
## Implementation Decisions

### How-to cards (discussed)
- **D-12:** After the guest taps Alchiki in the catalog, show a **full-screen static card pager before the table**. Not an overlay on felt. Not “match starts immediately with an optional How to play”.
- **D-13:** **Skip is available on card 1** of the first showing. The player may leave for the table without finishing the deck. Do not force a full swipe on first launch.
- **D-14:** **Auto-show once per device** — before the first Alchiki match only. After skip or finish, persist “seen” locally. Later matches go straight to the table. Reopen the **same** five cards from **Pause → How to play** (ALCH-04).
- **D-15:** **Five cards**, no animated tutorial, no coach overlays, no federation jargon / alshy names in the mandatory deck:
  1. Circle + saka
  2. Aim (rotate arrow)
  3. Hold-to-throw (power by hold duration)
  4. Target bone fully outside the circle = 1 after settle
  5. First to 5
  EN+RU via i18n keys. A separate “Tradition” sheet is out of this phase.

### Guest, catalog, i18n (not discussed — locked from REQUIREMENTS)
- **D-16:** Cold start **mints a guest** with no username/password UI. Persist `playerId` + session tokens on device across restarts. Bind (AUTH-02) is Phase 7. Do not show a registration wall.
- **D-17:** **Catalog is home** after launch (short branded splash OK). Alchiki is the only playable tile. Stick Pull and other titles are **Coming Soon** (non-playable; CAT-02 is Phase 6). Do not fake a third game.
- **D-18:** All player-facing strings are i18n keys; **EN and RU complete**. In-app language switch is in scope if cheap; device locale with EN fallback is the minimum. Kazakh/Kyrgyz stay out.

### Match rules (not discussed — lock FEATURES.md Mobile Rules)
- **D-19:** Replace the Phase 1 sandbox loop (Reset after one throw) with a **match**: 5–7 target bones, **first to 5**, else highest after **8 turns each** or **4:00**, **hard cap 5:00**. Bone count: **5 EASY / 6 NORMAL / 7 HARD**. Turn clock **20s** to release; timeout = forfeit that throw (saka stays, 0). Scoring only after sleep or ~1.2s settle. Saka-out = 0 and saka returns (ALCH-05, Phase 1 D-08). Pocketed targets leave the table.
- **D-20:** Controls stay Phase 1 **D-04/D-05**: aim arrow + separate Hold Throw, charge 0.15–1.1s. No slingshot. No cosmetic aim assist.

### Bots (not discussed — lock BOT-01 / BOT-03)
- **D-21:** First catalog path starts **EASY** (new player can win in under 3 minutes). EASY / NORMAL / HARD are all selectable this phase. Bots are **scripted** (aim/hold noise, visible mistakes). No ML. The bot takes a **visible turn** on the table (aim + throw + settle), not an instant score popup.
- **D-22:** Bot `ThrowInput` is produced **on the server** (same schema as the player) and scored by the same dyn4j burst path. The client must not invent bot results.

### Authority and backend (not discussed — lock SESS-01 + PROJECT)
- **D-23:** This phase **introduces the first Spring Boot 4.1 / Java 21 / Modulith / PostgreSQL 18 slice**. Guest mint, start bot match, submit `ThrowInput`, return closed keyframes + `ThrowResolved`. **No client-authored score.** Promote `harness/` dyn4j burst into `games.alchiki` (keep CLI/JUnit golden as a regression harness).
- **D-24:** **REST is enough for the bot loop.** Do not build private-room WebSocket, reconnect, rematch windows, or forfeit-as-rated-loss here (Phases 3 / 5 / 7). Local Forge2D preview is still allowed; when preview and keyframes diverge, **keyframes win** (Phase 1 D-10).
- **D-25:** Do **not** add shop, wallets as a product surface, Glicko-2, leaderboards, analytics SaaS, Redis, or iOS shipping as a gate. Android remains the proof device; keep the Flutter iOS target compilable.

### Claude's Discretion
- Card **illustration** style (simple diagrams vs painted stills) as long as cards are static, 5-count, colorful nomadic/Asian, original art only.
- Flutter i18n mechanism (`gen-l10n` vs a small ARB wrapper) and catalog router (`go_router` vs Navigator) — pick one boring pattern and use it for catalog → how-to → match → pause.
- Where to store guest tokens + how-to “seen” (SharedPreferences is enough).
- Exact Spring/Modulith package layout and whether the existing `harness` Maven module is moved or depended on.
- Bot noise magnitudes, HUD chrome (clock, scores, whose turn), pause layout, Coming Soon tile count/copy — planner/UI-SPEC, within PRES-02 and Phase 1 palette (`#1B6B3A` felt, `#241810` wood, `#F0B429` accents).
- Whether the old `SandboxPage` remains behind a debug flag or is deleted once the match table exists. Do **not** keep sandbox as the app home.
- Fix Phase 1 review defects **CR-01** (Hold Throw before `onLoad`) and **CR-02** (HUD `scored` ignores `sakaOut`) when extracting the match table — do not copy them.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase and requirements
- `.planning/ROADMAP.md` — Phase 2 goal, success criteria, requirement IDs
- `.planning/REQUIREMENTS.md` — AUTH-01, CAT-01, CAT-03, ALCH-01–ALCH-05, BOT-01, BOT-03, SESS-01, PRES-01, PRES-02 (do not implement AUTH-02, CAT-02, MODE-*, ECON-*, LEAD-*, STICK-* playable)
- `.planning/PROJECT.md` — guest-first, EN+RU, catalog platform, server authority, modular monolith, no IAP, static how-to
- `.planning/phases/01-alchiki-physics-prototype/01-CONTEXT.md` — D-01–D-11 carried forward (aim/hold, 2.5D, JVM keyframes, no lockstep)
- `.planning/phases/01-alchiki-physics-prototype/01-UI-SPEC.md` — table palette and throw chrome to extend, not replace
- `.planning/phases/01-alchiki-physics-prototype/01-REVIEW.md` — CR-01, CR-02 must not ship into the match table

### Rules, bots, how-to copy
- `.planning/research/FEATURES.md` — **Alchiki Mobile Rules Spec (v1)** (bones by difficulty, first to 5, 8 turns / 4:00, cap 5:00, 20s turn clock, five how-to topics)
- `.planning/research/PITFALLS.md` — guest wall, federation jargon on cards, client-authored scores

### Stack and authority
- `.planning/research/STACK.md` — Flutter + Flame + Forge2D 0.14 fallback; Java 21 + Spring Boot 4.1 + Modulith; PostgreSQL 18; dyn4j 6.0.0
- `.planning/research/ARCHITECTURE.md` — input → server burst-sim → closed keyframe buffer; REST + later WS; no Forge2D↔dyn4j lockstep
- `.planning/research/SUMMARY.md` — catalog + first bot match after the physics gate
- `client/lib/input/throw_input.dart` — shared `ThrowInput` JSON (`schemaVersion`, `yUp`, `aimAngleRad`, `holdMs`, `seed`, `tableId`)
- `harness/src/main/java/com/nomadgames/alchiki/proto/Dyn4jBurstSim.java` — burst-to-rest authority to reuse

No SPEC.md for this phase. No external ADRs.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `client/lib/game/alchiki_sandbox_game.dart` + `felt_circle.dart` / `saka_body.dart` / `bone_body.dart` / `aim_controller.dart` / `physics_stepper.dart` — table, 2.5D squash, zero-g Forge2D. Lift into a match game; drop Reset-as-product.
- `client/lib/replay/keyframe_player.dart`, `throw_resolved.dart`, `authority_score.dart` — JVM replay + displayed score. Match HUD must use `displayedScore()` (CR-02).
- `client/lib/input/throw_input.dart` + `client/lib/schema/table_constants.dart` — keep as the wire contract with the new server.
- `harness/` Maven module (`Dyn4jBurstSim`, `HarnessMain`, `BurstSimTest`, `client/assets/replays/golden_*.json`) — extract/call from Modulith; do not rewrite physics constants ad hoc.
- `client/lib/sandbox_page.dart` — Hold Throw / Replay / palette. Extract chrome; it is **not** the Phase 2 home (`main.dart` currently `home: SandboxPage()`).
- `scripts/dev-env.ps1`, `scripts/replay.ps1` — keep as the local toolchain.

### Established Patterns
- Flame `GameWidget` inside a Flutter scaffold; Flutter owns Hold Throw; Flame owns aim drag.
- Fixed `dt` 1/60 with accumulator, max 4 catch-up (`physics_stepper.dart`).
- Authority JSON: client writes `ThrowInput`, JVM returns closed keyframes; Replay interpolates; preview never becomes `scored`.
- No `go_router`, no i18n, no auth, no HTTP client, no Spring Boot app yet — those are new in this phase.
- `.planning/codebase/` maps do not exist; scout was grep on `client/lib` + `harness/`.

### Integration Points
- New Flutter routes: splash/catalog → how-to pager → Alchiki match → pause/how-to → catalog.
- New server module owns guest identity + `MatchSession` for bot Alchiki; client submits `ThrowInput` over REST and plays returned keyframes.
- Seed-1 sandbox layout (saka `(0.0, -1.15)`, hex bones r=0.22) is a starting cluster; match setup may vary bone **count** by difficulty, not collider family.

</code_context>

<specifics>
## Specific Ideas

- How-to deck topics were locked to the FEATURES.md five-card list (circle, aim, hold, out = point, first to 5). Planner/UI must not collapse to 3 cards or add an animated overlay.
- Skip-from-card-1 is a product requirement, not a “nice to have”: BOT-03 still has to work for players who skip.

</specifics>

<deferred>
## Deferred Ideas

- Private rooms, join codes, rematch, casual reconnect (Phase 3)
- Cosmetic shop, COINS/GEMS as a player-facing economy (Phase 4)
- Casual Quick Match + profile (Phase 5)
- Stick Pull playable + its how-to (Phase 6; catalog tile stays Coming Soon)
- Bind username/password, Ranked, Glicko-2, leaderboards, CI/compose harden (Phase 7)
- Tradition/info sheet beyond the five mandatory cards
- iOS App Store shipping as a Phase 2 gate
- WebSocket live session (needed for rooms, not for bot REST)

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 2-Guest Catalog + First Alchiki Match*
*Context gathered: 2026-09-06*
