# Project Research Summary

**Project:** Nomad Games
**Domain:** Mobile multiplayer traditional-games platform (casual 1v1 parlor PvP)
**Researched:** 2026-09-05
**Confidence:** MEDIUM-HIGH (stack prescription HIGH; reconnect seconds, tap clamps, and exact patch pins MEDIUM)

## Executive Summary

Nomad Games is a catalog parlor platform, not a single asyk title. Experts in this category (8 Ball Pool, Ludo King, Carrom King, Mini Football) ship one binary with a guest→first short match→bind→cosmetics funnel, plus a server that owns scores, wallets, and ranked. Cultural sources (UNESCO assyk, Assyk Federation, World Nomad Games Tayak Tartysh) supply recognizable rules; mobile products cut outdoor length. Legacy Asyk Atu is a stale physics arcade with almost no account layer — that gap is the product.

The recommended approach is frozen: **Flutter 3.47 + Flame 1.38 + Forge2D 0.15** client (2.5D presentation, 2D physics), **Java 21 + Spring Boot 4.1.1 modular monolith** with **dyn4j 6.0.0** as the Alchiki authority, **REST + raw WebSocket**, **PostgreSQL 18.6 and no Redis on day one**, **Glicko-2** vendored in-repo, **guest-first** identity, **cosmetic-only COINS+GEMS and no IAP in MVP**. Alchiki is input → server burst-sim-to-rest → closed keyframe replay. Stick Pull is a 10–20 Hz clamped tap tick on the same `MatchSession`. Unity and Godot are rejected: their solvers do not run on the JVM, and the catalog/account shell is cheaper in Flutter.

The #1 risk is building accounts, shop, and ranked before the throw feels like skill. Mitigate with a hard **Phase 1 — Alchiki Physics Prototype** gate: mid-Android 60 FPS, readable collisions/rotation/friction, hold-to-throw, sleep, and a non-client dyn4j harness that consumes the same `ThrowInput`. Do not lockstep Forge2D against dyn4j. Do not treat guest bind as “create user + sum wallets.” Do not ship Stick Pull as unlimited mash. If Phase 1 fails, change stack before identity exists.

## Key Findings

### Recommended Stack

Full detail: [STACK.md](STACK.md). Physics quality + Java authority decide the stack, not “Flutter is easy” and not “games use Unity.” Prototype family **must equal** production family.

**Core technologies:**
- **Flutter 3.47.0 / Dart 3.13.0 + Flame 1.38.2 + forge2d 0.15.1 + flame_forge2d 0.20.0:** one Android/iOS binary; widgets own catalog/auth/shop/i18n; Flame owns the 60 FPS interpolation clock; Forge2D proves hold-to-throw feel. Not the multiplayer authority.
- **2.5D presentation / 2D physics:** disk/capsule colliders, slight camera tilt, sprite spin. 3D mesh and alshy-face scoring are out of v1.
- **Eclipse Temurin JDK 21 + Spring Boot 4.1.1 + Spring Modulith 2.1.1:** one JAR, package modules (`identity`, `session`, `games.*`), raw `WebSocketHandler` (disable STOMP/SockJS). Maven, not Gradle.
- **dyn4j 6.0.0:** maintained pure-Java 2D solver. jbox2d is unmaintained. No Unity/Godot dedicated server.
- **PostgreSQL 18.6 + Flyway 12.4.0:** only source of truth. No Redis until a second app instance or measured queue latency. Compose volume `/var/lib/postgresql` (PG 18 PGDATA change).
- **HS256 access JWT (~15 min) + opaque rotating refresh in Postgres + Argon2id:** first-party issuer. No Keycloak / Auth Server / OAuth / Firebase Auth in MVP.
- **Glicko-2 in-repo:** sparse Ranked needs RD. Do not depend on idle Maven Glicko JARs. Elo is rejected.
- **Client support:** go_router 18, Riverpod 3.4, dio 5.11, web_socket_channel 3.0, flutter_secure_storage 10.3, EN+RU i18n day one.

**Critical version notes:** `flame_forge2d` 0.20 is a breaking adapt to Flutter 3.47 — do not mix with forge2d 0.14. NDK required for Forge2D 0.15 native assets; fallback is 0.19/0.14 Dart port, same Flame app. Flyway needs `flyway-database-postgresql`. Boot 4 uses Jackson 3.

### Expected Features

Full detail: [FEATURES.md](FEATURES.md). Copy Ludo King’s room-code + bot-first and Miniclip’s guest → currency HUD → bind. Refuse 8 Ball Pool wager tables and stat cues.

**Must have (table stakes / v1 MVP):**
- Instant guest play, bind username/password later (prompt after first bot win)
- Playable catalog: Alchiki live, Stick Pull live, Coming Soon tiles
- Offline/vs-bot first match (EASY/NORMAL/HARD, no ML); EASY beatable in <3 min
- Hold-to-throw physics that reads as skill (mobile rules: 5–7 bones, first to 5, 2–5 min)
- Static 3–5 how-to cards EN+RU (no animated tutorial)
- Private room 4–6 char code + rematch
- One-tap Casual Quick Match with empty-queue fallback (bot or invite — never a 60s fail spinner)
- Casual reconnect (seat hold + opponent timer + Rejoin)
- Server-authoritative scores, coins, outcomes
- Profile + per-game W/L; COINS+GEMS HUD; cosmetic-only shop, **no IAP**
- Stick Pull: 15–40 s, stamina + server tap clamp (≤10 accepted taps/s)
- Analytics events in backend logs only (no Amplitude/Grafana)

**Should have (competitive / v1.x after the loop is proven):**
- Honest mobile Alchiki as the reason to exist (feel + readable rules, not a 4 m outdoor reconstruction)
- Ranked that is not P2W — **Glicko-2**, bind required, cosmetics ignored, soft season reset
- Per-game + season + all-time leaderboards (never rank by coin balance)
- Ranked reconnect (shorter + aggregate pause budget)
- Bind GEMS reward / daily COINS if funnel needs it; first Turkic locale after EN+RU QA

**Defer (v2+):**
- Real-money IAP, OAuth as extra bind, chat/clubs/friends/voice, tournaments, season pass/gacha/ads
- Third full game, alshy-face / 15-bone sport mode, couch same-device tug, spectate
- Play Integrity / commercial anti-cheat SDKs

**Anti-features (do not build):** P2W stats, coin-wager tables, required Facebook login, ML bots, client-authoritative ranked, microservices/K8s, licensed ornaments, unlimited mash tug.

### Architecture Approach

Full detail: [ARCHITECTURE.md](ARCHITECTURE.md). One client + one Spring process. Shared `MatchSession` + `GameEngine` plugin. Authority on the server. Clients render and send inputs. Steal Colyseus/Nakama **room patterns** (seat hold, rejoin token, full snapshot) — do not adopt those products as the backend.

**Major components:**
1. **Client `platform/` + `games/*`** — shell owns auth, catalog, REST, one WS, i18n, shop, profile. Alchiki owns aim/hold/replay. Stick Pull owns countdown/taps/stamina bar. Games never open their own sockets.
2. **`identity` / `catalog` / `matchmaking` / `session`** — guest is a real `Player`; bind links credentials to the same `playerId` (409, no wallet sum). Catalog flags Coming Soon. Queues in-process. Session owns seats, WS auth, reconnect policy, engine dispatch.
3. **`games.alchiki` / `games.stickpull`** — Alchiki: turn machine + dyn4j burst + circle scoring. Stick Pull: 10–20 Hz clamp/stamina/marker. Different clocks, same session.
4. **`economy` / `profile` / `rating` / `analytics`** — ledger-only balances; stats from settlements; Glicko-2 only on Ranked settle; `EventSink` insert + JSON log.
5. **PostgreSQL** — durable truth. Redis later for queues/limits only, never wallets or physics.

**Key patterns:** input→sim→keyframes (Alchiki); input-rate tick (Stick Pull); seat reservation + full snapshot on rejoin; guest-link not merge; thin EventSink. Do not lockstep. Do not run one 20 Hz tick for both games. Do not put live match state in REST after session create.

### Critical Pitfalls

Full detail: [PITFALLS.md](PITFALLS.md).

1. **Shop/accounts/ranked before the throw feels good** — Phase 1 is only the throw + JVM harness. If the gate fails, change stack here.
2. **Lockstep or client rest poses** — two engines will desync; uploaded transforms are a cheat. Inputs only; server scores; clients replay a closed keyframe buffer.
3. **Flutter-vs-Unity lock-in before the gate** — stack is an **output** of Phase 1. Research already picks Flutter+Flame+Forge2D + dyn4j; reopen only if the harness fails.
4. **One reconnect policy / delete seat on drop / token = transport session** — mode-specific grace; token bound to `playerId`+`matchId`; consented leave is 0 s; full snapshot on rejoin.
5. **Guest → “create user + sum wallets”** — guest **is** the Player; bind links; 409 + no-sum; app UUID in secure storage, never advertising ID.
6. **Economy as client balances / IAP bolted on later** — ledger + idempotency now; reserve empty `purchases.token UNIQUE`; no Play/App Store in MVP.
7. **Stick Pull as unlimited mash or auto-ban** — server clamp + stamina on all online modes; regularity → `suspect` log only in v1.

## Implications for Roadmap

Be opinionated: **Phase 1 is a hard gate.** Remaining phases follow ARCHITECTURE.md build order, but **FEATURES.md MVP vs v1.x wins on Ranked vs Stick Pull.** Stick Pull is launch-critical (without it Nomad is “an asyk demo”). Ranked, Glicko-2, and skill leaderboards are **v1.x** — after casual online + reconnect are boringly reliable. Profile W/L ships with Casual; global boards wait for rated play.

### Phase 1: Alchiki Physics Prototype
**Rationale:** PROJECT.md, FEATURES, ARCHITECTURE, and PITFALLS all agree — if FPS, sleep, rotation, hold-to-throw, or the server-sim path fail, every later phase is a rewrite. Forbidden: identity tickets, shop mockups, ranked.
**Delivers:** Flutter+Flame+Forge2D local throw on mid Android; dyn4j 6.0.0 CLI/JUnit harness that consumes the same `ThrowInput` and emits keyframes; Flame interpolates those frames (even from a file). Pass/fail recorded. Stack family locked or reopened here.
**Addresses:** Hold-to-throw physics that reads as skill; mobile collider/settle hypothesis (disk/capsule, sleep or ~1.2s timeout); 2.5D presentation spike.
**Avoids:** Pitfalls 1–3 (platform-first, lockstep, engine lock-in); variable-`dt` Forge2D (fixed 1/60 or 1/120).
**Gate:** Stable ~60 FPS, collisions + rotation + friction + restitution readable, hold-to-throw, bodies sleep, **non-client scorer**. Fail → change stack before accounts.

### Phase 2: Modular monolith + guest identity + catalog + EventSink
**Rationale:** Matches need a `playerId`. Bind **schema** cannot wait; bind **UI** can. Do not invent a second user row.
**Delivers:** Spring Boot 4.1.1 + Modulith 2.1.1 skeleton; Postgres 18.6 + Flyway; `Player` + `Credential[]` + audit; device UUID guest; HS256 + opaque refresh + Argon2id; catalog rows (Alchiki, Stick Pull, Coming Soon); `EventSink`; Compose app+Postgres only (no Redis, no K8s).
**Uses:** Java 21, Maven, Testcontainers, actuator `/health`, EN+RU i18n keys in the client shell.
**Implements:** `identity`, `catalog`, `analytics`. Guest play prerequisite. No shop UI, no ranked.
**Avoids:** Pitfall 5 (split PK / wallet merge); Pitfall 8 (microservices, Redis-as-truth, analytics SaaS).

### Phase 3: Match session + raw WebSocket + reconnect
**Rationale:** Shared match must exist before either game is multiplayer. Empty `GameEngine` is the platform invariant.
**Delivers:** `MatchSession`, `GameEngine` SPI, raw WS (JWT/ticket, message types: `ThrowInput`, `TapWindow`, `ThrowResolved`, `StickSnapshot`, `RejoinSnapshot`, `Ping`), rotating reconnect token, mode `ReconnectPolicy`, 1 Hz housekeeping. Full snapshot on rejoin. Consented leave = immediate forfeit.
**Addresses:** Reconnect table stakes (wire + seats). Tune seconds in UAT, not in a later protocol rewrite.
**Avoids:** Pitfall 4 (one timer, delete-on-drop, token = `sessionId`); STOMP/SockJS; one global 20 Hz tick.

### Phase 4: Alchiki on session + bots + static how-to
**Rationale:** Core value and success metric — first honest short bot match understood from static cards, desire for one more session.
**Delivers:** `games.alchiki` server engine (dyn4j burst → scores → keyframes); client replay on the real WS path; mobile rules (5–7 bones, first to 5, 8 turns or 4:00, hard cap 5:00); static 3–5 cards EN+RU; deterministic EASY/NORMAL/HARD bots on the **server** engine (Phase 1 client-world bots retired).
**Addresses:** Alchiki physics + rules; guest→bot first session; server-authoritative result; i18n in-game strings.
**Avoids:** Pitfall 2/9 (client scores); local-bot / online-scorer split.

### Phase 5: Private rooms + rematch
**Rationale:** Lowest-risk human PvP; no matchmaking. Friends QA of physics sync.
**Delivers:** 4–6 char codes in Postgres + TTL; host-alive lobby; system share sheet; rematch 10s window; casual Alchiki reconnect (60 s or 2 missed own turns; bot-fill on expiry).
**Addresses:** Private room code; rematch; first human authoritative match.
**Avoids:** Pitfall 9 — wire stays inputs-only from the first human match. Ranked cannot be “turned on” later if private rooms trust the client.

### Phase 6: Economy + cosmetic shop (no IAP)
**Rationale:** Ledger + idempotency before any online reward. FEATURES P1 loop after match 2. IAP columns reserved, unused.
**Delivers:** `economy` ledger (JdbcClient, never “load entity, mutate balance”); COINS + GEMS wallets; cosmetic SKUs (saka colors / stick skins / frames / ornaments — **same physics for all**); shop idempotency key; empty `purchases(provider, token UNIQUE, …)`; match rewards via `MatchSettled` (`matchId:reason`). Nomadic theme pack: default + 2–3 cosmetics.
**Addresses:** Dual currency HUD; cosmetic identity; no IAP; no wager tables.
**Avoids:** Pitfall 6 (client balances, missing purchase table); P2W stats.

### Phase 7: Casual Quick Match + profile
**Rationale:** Table-stakes “Play” button. Needs reconnect + authority already proven in private. FEATURES puts global leaderboards behind ranked — ship **per-game W/L profile** now, not coin boards.
**Delivers:** In-process casual queue (latency/region, then wide win-rate band); 15–20 s accept timeout; empty-queue fallback (bot or invite); rematch after casual; profile display name/avatar/games/W/L/favorite. Guests allowed.
**Addresses:** One-tap Quick Match; profile + basic stats; casual reconnect under load.
**Avoids:** 60s spinner-then-fail; ranking by coin balance; Ranked-on-guest (do not sneak a ranked queue in here).

### Phase 8: Stick Pull module
**Rationale:** FEATURES MVP — second live tile proves the shelf. ARCHITECTURE wanted this after Ranked; **override that.** Plugin boundary is already real after Phases 3–7. Ranked is not required to ship a 20 s party game.
**Delivers:** `games.stickpull` engine + client module; 3-2-1-GO; stamina model; server re-timestamp + clamp (≤10 taps/s); 10–20 Hz marker snapshots; 15–40 s clock; EASY/NORMAL/HARD tap bots; static how-to; Stick Pull reconnect 8 s casual (forfeit, no bot-fill). Regularity → `suspect` log, **no auto-ban**.
**Addresses:** Stick Pull + stamina/clamp; catalog-as-platform claim.
**Avoids:** Pitfall 7 (unlimited mash, client timestamps, auto-ban); reusing Alchiki’s burst loop.

### Phase 9: Guest bind UI + 409 conflict
**Rationale:** Schema existed since Phase 2; UX now that coins, cosmetics, and W/L are worth keeping. FEATURES: prompt after first win, not on splash. Unlocks Ranked eligibility.
**Delivers:** Bind username/password on the same `playerId`; 409 + Sign in path; no wallet sum; optional one-time import only if target has zero matches and zero spend; guest-progress warning once they have something to lose; Ranked/gem sinks require a bound credential.
**Addresses:** Bind later; guest → identity without social graph.
**Avoids:** Pitfall 5 (create-user merge, advertising ID, dead-end 409).

### Phase 10: Ranked + Glicko-2 + leaderboards (v1.x)
**Rationale:** FEATURES P2. Trigger: casual abort rate is low and bind rate is healthy. Do not ship in the first launch cut if Phase 1–9 already validate the success metric.
**Delivers:** Bind-only ranked queue; Glicko-2 (r=1500, RD=350, σ=0.06, τ=0.5–0.75, period = day or N games); soft season reset policy; ranked reconnect (Alchiki 90 s rated forfeit, Stick Pull 12 s; aggregate pause budget); per-game / season / all-time boards (guests excluded, never coins); no cosmetics in the rating update; no bot opponent.
**Addresses:** Honest Ranked; skill leaderboards; ranked reconnect.
**Avoids:** Guest smurfs; rage-quit = draw; P2W; Elo; coin ladder.

### Phase 11: Ship harden
**Rationale:** Not a platform rewrite. CI + PROD compose + UAT of the mobile failure modes that kill parlor titles.
**Delivers:** GitHub Actions (`flutter test` + `mvn verify` + Modulith verify); PROD compose (app + Postgres); in-process rate limits; reconnect UAT (airplane, swipe-away, LTE flip, process death) on both games; health checks; JSON logs. Still no Redis/K8s/OTel/IAP.
**Avoids:** Pitfall 8 creeping back in at ship time.

### Phase Ordering Rationale

- Feel + JVM keyframe path first — or identity/shop/ranked become a rewrite (PITFALLS 1–3).
- Guest **schema** before matches; bind **UI** after there is something to keep (FEATURES dependency graph).
- Shared session + mode-specific reconnect before either game is “online.”
- Alchiki bot → private PvP → ledger → casual queue → Stick Pull. That is the v1 launch cut.
- Ranked + Glicko-2 + skill boards after the casual loop is stable (FEATURES v1.x), not bundled with Quick Match.
- One JAR + Postgres the whole way. Redis is a scaling patch after replica #2, never a phase-0 service.

### Research Flags

Phases likely needing `/gsd-plan-phase --research-phase` during planning:

- **Phase 1:** If Forge2D feel or NDK/native assets fail, or dyn4j stacking/sleep is worse after mass/friction tuning — **reopen stack** (Dart-port Forge2D 0.14 fallback first; Unity/Godot only if the owner drops JVM authority). Also lock exact `ThrowInput` units (angle, holdMs vs power01, optionalSpin).
- **Phase 3:** Reconnect grace seconds are product choices derived from Colyseus/MiniTon **ranges**, not Nomad playtests. Research the wire message schema and snapshot shape.
- **Phase 8:** Tap clamp / stamina knobs are MEDIUM (biomechanics + screen debounce). Needs device playtests; do not treat 5–6.5 taps/s as lab truth.
- **Phase 10:** Glicko-2 draw/forfeit/RD-period mapping — algorithm is standard; product defaults need a short rating research pass.
- **IAP (post-MVP, not a v1 phase):** Play PENDING / RTDN `messageId` / StoreKit `updates` vs `finish()` — research only when real money is in scope.

Phases with standard patterns (skip research-phase):

- **Phase 2:** Spring Modulith + Flyway + JWT/Argon2 + guest UUID — well-documented; follow STACK pins.
- **Phase 4 (rules/UI after Phase 1 gate):** Mobile Alchiki rules and static cards are specified; implementation is engine wiring, not discovery.
- **Phase 5:** Short room codes + share sheet — parlor-standard.
- **Phase 6:** Ledger + idempotent shop without IAP — standard; keep purchase table empty.
- **Phase 7:** In-process 1v1 queue + profile W/L — standard; empty-queue fallback is the only product rule.
- **Phase 9:** Nakama/Firebase link pattern already specified (409, no-sum).
- **Phase 11:** Compose + Actions + actuator — standard one-dev ship.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH (prescription) / MEDIUM (patch pins) | First-party docs (Flutter 3.47, Boot 4.1.1, dyn4j 6.0.0, PG 18.6). Context7 unavailable; treat official URLs as primary. Pins will move. |
| Features | HIGH (table stakes + cultural rules) / MEDIUM (tap/stamina numbers) | UNESCO, Assyk Federation, WNG, Miniclip/Ludo King listings. Autoclicker thresholds need device UAT. |
| Architecture | MEDIUM | Colyseus/Nakama/Gaffer/Modulith patterns are primary; exact reconnect seconds and hybrid-preview timing are product choices. |
| Pitfalls | MEDIUM | Canonical Gaffer/Colyseus/Nakama/Play Billing/Roblox/MiniTon. No fabricated incident URLs. Flame#2750 and Unity carrom threads inform fixed-`dt` and no-lockstep. |

**Overall confidence:** MEDIUM-HIGH on the recommended path; LOW only if Phase 1 fails the server-sim gate.

### Gaps to Address

- **Phase 1 gate outcome:** Flutter+Forge2D + dyn4j is prescribed, not proven on a mid Android device. Planning must treat pass/fail as a stack decision, not a polish task.
- **Reconnect seconds:** Casual Alchiki 60 s / Ranked 90 s / Stick Pull 8–12 s are proposals. Validate in Phase 3 design and Phase 11 UAT.
- **ThrowInput contract:** aim units, holdMs vs power01, whether optionalSpin exists — lock in Phase 1 so client and harness cannot drift.
- **Alchiki saka-out rule:** FEATURES says 0 points + saka returns (do not burn the turn twice). Confirm in discuss/UAT if that feels too kind.
- **Tap clamp constants:** 10 taps/s, burst 8–10 for ≤1.5 s, recovery 280–350 ms — tune on device in Phase 8; do not auto-ban.
- **Glicko-2 period and soft-reset cadence:** defaults given; confirm when Phase 10 is planned.
- **go_router 18 / Boot 4 Jackson 3:** newly current — read migration notes on first use (STACK version table).
- **IAP verification:** schema only in MVP; full Play/App Store research is a later milestone gap, not a v1 blocker.

## Sources

### Primary (HIGH confidence)

- Flutter 3.47 / Dart 3.13 — https://docs.flutter.dev/release/whats-new
- Flame 1.38.2, forge2d 0.15.1, flame_forge2d 0.20.0 — pub.dev
- Spring Boot 4.1.1 — https://spring.io/blog/2026/08/20/spring-boot-4-1-1-available-now
- Spring Modulith 2.1.1, Framework WebSocket (raw vs STOMP), Security 7 Argon2 + JWT — docs.spring.io
- dyn4j 6.0.0 — Maven Central
- PostgreSQL 18.6 — postgresql.org (2026-08-13)
- Glicko-2 procedure — https://www.glicko.net/glicko/glicko2.pdf
- UNESCO ICH 01086 (Kazakh Assyk games)
- The Astana Times (2024-05), Assyk Federation interview
- World Nomad Games Tayak Tartysh / mas-wrestling
- Colyseus reconnection; Nakama authoritative MP + authentication; Firebase account linking
- Gaffer On Games — lockstep, floating-point determinism, snapshot interpolation
- Play Billing security; Apple StoreKit finish-after-deliver; Roblox server-side detection; MiniTon forfeits
- Miniclip Help (8 Ball Pool / Mini Football guest, bind, leaderboards); Ludo King / Carrom King store listings

### Secondary (MEDIUM confidence)

- jbox2d deps.dev Maintained 0/10 (2026-07) — do not use
- Flame#2750 — Forge2D impulse/damping vs FPS
- Unity Discussions carrom/billiards — cross-device physics divergence
- GameDev SE + nape-js — server-authoritative turn-based physics
- Redis matchmaking tutorial — ZSET **after** replica #2
- Click-speed / CPS explainers (~5–6.5 taps/s); Hypixel regularity detectors — inform logs, not v1 bans
- Secondary 8 Ball Pool economy writeups — P2W cue stats as anti-pattern only
- Legacy Asyk Atu (KEO Limits ~2020) listings; Tug It! / Button Mash store copy

### Tertiary (LOW confidence)

- Context7 MCP unavailable this runtime — version pins rest on first-party pages via webfetch (transport tagged LOW; treat official URLs as primary anyway)
- Exact Clash-Royale-class forfeit timers — not published; unused
- Hybrid local-preview morph timing — optional after Phase 1, not specified

---
*Research completed: 2026-09-05*
*Ready for roadmap: yes*
