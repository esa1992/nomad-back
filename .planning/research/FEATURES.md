# Feature Research

**Domain:** Mobile multiplayer traditional-games platform (casual 1v1 parlor PvP)
**Researched:** 2026-09-05
**Confidence:** HIGH for table-stakes parlor features and cultural-rule sources; MEDIUM for tap-stamina / anti-autoclicker thresholds (biomechanics + community detectors, not Nomad playtests)

## Feature Landscape

Nomad Games is not competing with a single asyk app. Existing Asyk Atu (KEO Limits, last notable update ~2020) is a physics arcade with global/LAN/hotseat and almost none of the account-platform layer. The real category is **hypercasual-plus-account parlor PvP**: 8 Ball Pool (Miniclip), Ludo King / Carrom King (Gametion), Mini Football / Mini Tennis (Miniclip). Those products share one funnel: guest → first short match → bind account → coins/cosmetics → friends code → ranked/leaderboard.

Owner-locked product facts are classified below into **v1 / v1.x / v2+**. Do not reopen: guest-first, EN+RU, catalog (Alchiki + Stick Pull + Coming Soon), bot/private/quick/ranked modes, profile/stats/leaderboard, COINS+GEMS cosmetics without real money, static tutorial, nomadic visual, reconnect, Ranked not P2W.

### Table Stakes (Users Expect These)

Features users assume exist. Missing these = product feels incomplete or "unfinished indie," not a platform.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Instant guest play | Miniclip and party-room apps ship play-before-login; registration-first kills first-session conversion | LOW | Device-bound guest token. Prompt bind after first Alchiki bot win, not on splash. Guest progress can be lost on reinstall — tell the player once, after they have something to lose. |
| Bind username/password later | Players expect progress to survive a new phone; owner locked this over OAuth | MEDIUM | Soft-lock Ranked, shop spend, and leaderboard identity behind bind. Casual bot + private room stay open for guests. Password hashing + refresh rotation are backend table stakes, not a "security phase extra." |
| Playable catalog home | Ludo King / Carrom King / Miniclip titles always open on "what can I play now" | LOW | Alchiki live, Stick Pull live, 1–2 Coming Soon tiles. Catalog is the platform promise. Empty home after one game feels like a single title. |
| Offline / vs-bot first match | Ludo King "no internet, play computer"; 8 Ball Pool practice; tug apps ship vs AI | MEDIUM | Success metric is a completed Alchiki bot match. Ship EASY/NORMAL/HARD as deterministic bots with visible mistakes, not ML. EASY must be beatable in <3 minutes by a new player. |
| Hold-to-throw physics that reads as skill | 8 Ball Pool / Carrom retain players because aim+power feel earned | HIGH | Table stakes for *this* product, not for generic hypercasual. Aim gesture + hold-to-throw + settle-then-score. If the throw feels like a random dice roll, the platform has no core value. |
| Private room + short shareable code | Ludo King, Party Room, Bukharo, Carrom King: friends join in <30s via 4-letter/digit code | LOW | 4–6 char alphanumeric, host-alive lobby, system share sheet (WhatsApp/Telegram). Code dies when host leaves. No Facebook friends graph required. |
| One-tap Quick Match | 8 Ball Pool 1v1 and Ludo King online are the default "play now" | HIGH | Casual 1v1 only in v1. Match by latency/region first, then recent win-rate band. Empty-queue fallback: offer bot or "invite a friend" — never a 60s spinner then fail. |
| Reconnect after a brief drop | Mobile Wi-Fi/LTE flips are normal; Colyseus/MiniTon treat 20–30s seat hold as standard | HIGH | Server holds seat, opponent sees "reconnecting + timer," client auto-retries then offers Rejoin. Distinct rules for Casual vs Ranked (see spec). Without this, online modes feel broken on phones. |
| Post-match result that cannot be argued | Parlor players rage when the client "decides" the pot | HIGH | Server is source of truth for score, win, coins, rating. Client predicts feel only. |
| Profile + per-game stats | Carrom King "watch opponent statistics"; Miniclip titles show name/avatar/XP | LOW | Display name, avatar, games played, W/L, favorite game. Enough to make the opponent feel real. |
| Cosmetic identity | Every successful parlor title sells *looks*: cues, strikers, boards, dice, frames | MEDIUM | Small shop of saka colors / stick skins / frames / ornaments. Earn COINS from matches, GEMS from milestones. No IAP in MVP. Cosmetics must not change physics, tap power, or aim assist. |
| Dual currency visible in HUD | Mini Football / Mini Tennis / 8 Ball Pool always show Coins + premium currency | LOW | COINS = match rewards. GEMS = scarce / later IAP. Even with no real money, keep two wallets so economy is not rewritten. |
| Static how-to before first throw | 8 Ball Pool table "i" rules; owner forbids animated tutorial | LOW | 3–5 illustrated cards per game, skippable after first view, reopen from pause. If the player cannot score in the first bot match, the cards failed — rewrite copy, do not add a tutorial engine. |
| EN + RU with i18n keys | No-country audience; owner locked | LOW | All UI strings keyed from day one. Turkic locales are later, not a v1 feature. |
| Rematch / Play again | Ludo King and Carrom King treat rematch as social glue | LOW | After private and casual online: "Again?" 10s accept window. After bot: immediate restart. Ranked rematch optional later. |
| Leave / forfeit with known outcome | MiniTon: intentional leave submits a loss, not a silent abort | LOW | Confirm dialog. Casual: loss, no rating. Ranked (when live): rated loss. Distinguish crash/disconnect from quit. |
| Fair disconnect / forfeit rules | Players punish "rage quit = you lose nothing" and "Wi-Fi blip = you lose ranked" equally | MEDIUM | See Reconnect spec. Casual generous; Ranked stricter + aggregate reconnect budget to stop pause-griefing. |
| Coming Soon slots | Platform products advertise the next table; single-title apps do not | LOW | Non-clickable or "notify" tile. Do not fake a third game. |

### Differentiators (Competitive Advantage)

Features that set Nomad apart. Do not try to beat 8 Ball Pool on cue collections or Ludo King on chat.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Honest mobile Alchiki (asyk atu) | UNESCO-listed game with almost no modern parlor treatment; existing apps are stale and thin | HIGH | Differentiate on *feel + readable rules*, not on simulating a 4 m outdoor field. See **Alchiki Mobile Rules Spec**. This is the only reason to exist. |
| Catalog of nomadic games, not one title | Ludo King added Snakes & Ladders; Nomad starts as a shelf | MEDIUM | Architecture must allow `games/alchiki` + `games/stick_pull` without rewriting accounts, matchmaking, shop. Coming Soon is a differentiator only if a second game actually ships in v1. |
| Stick Pull as opposite-sit mas-wrestling, not autoclicker | Tug It! / Button Mash are local mash toys; World Nomad Games Tayak Tartysh is a real sport | MEDIUM | Stamina + server-side intensity validation makes a 15–40s party game *watchable and fair*. See **Stick Pull Spec**. |
| Ranked that is not Pay-to-Win | 8 Ball Pool and Carrom King sell aim/force/time on equipment — players know this is P2W | MEDIUM | Owner-locked. Cosmetics only. Rating (Glicko-2 hypothesized) ignores cosmetics. Soft season reset so new players are not crushed by year-one accounts. |
| Per-game + season + all-time leaderboards | Miniclip splits Friends / Country / Global and weekly coin-won boards | MEDIUM | Ours: **per game**, **season**, **all-time**, plus a soft rating reset. Do not rank by coin balance (8 Ball Pool's weekly coin board rewards bankroll, not skill). |
| Short honest sessions | 8 Ball Pool 3–7 min; official outdoor asyk can run 15–45 min | LOW (design) / HIGH (tuning) | Alchiki 2–5 min, Stick Pull 15–40 s. Session length is the retention mechanic. Cap turns/time in rules, do not hope players "play fast." |
| Bright original nomadic art (Gold / Neon / Ice / Fire / Space / ornaments) | Cultural games often look either museum-beige or generic cartoon | MEDIUM | Arcade-readable, not ethnographic reconstruction. Original ornaments only — licensed brands and others' patterns are anti-features. |
| Guest → identity without social graph | Miniclip pushes Facebook for recovery and friends | LOW | Username/password is enough. Differentiator vs "must link Facebook or lose everything" *if* bind UX is timely and a bind reward (small GEMS) is paid once. |
| Server-authoritative physics parlor on a platform | Legacy Asyk Atu uses mixed global/P2P/hotseat | HIGH | Authority is table stakes for Ranked/economy and a differentiator vs abandoned cultural ports. |

### Anti-Features (Commonly Requested, Often Problematic)

Features that seem good but create problems. Explicitly do not build.

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| Real-money IAP / Play Billing / Apple IAP in MVP | "Need monetization from day one" | Owner locked out. Unlocks App Store review, receipt verification, refunds, and P2W pressure before the throw feels good | Earn-only COINS/GEMS shop. Model wallets + idempotent purchases so IAP can drop in later |
| Pay-to-Win cues / weighted saka / aim line upgrades | 8 Ball Pool and Carrom King make this the meta | Destroys Ranked trust and the "honest throw" core value | Cosmetic-only shop. Same mass/restitution/aim for every saka in ranked |
| Coin-wager tables (entry fee / double or nothing) | 8 Ball Pool's retention loop | Bankroll anxiety, empty-wallet churn, matchmaking-by-wealth, scam-site magnets | Flat match reward (win > draw > loss). Never gate a mode behind a coin buy-in in v1 |
| Facebook / Google / Apple as required login | Miniclip "save guest" default | Owner locked guest + username/password. Social login adds store review, revoked tokens, and "why Facebook?" friction | Optional OAuth later as *additional* bind method, never the only one |
| Dynamic animated tutorial / coach overlays | "New players won't understand asyk" | Owner locked static cards. Tutorial engines delay the success metric | 3–5 static cards + EASY bot that misses on purpose. Iterate card copy from first-match funnel |
| ML / neural bots | "Smarter opponents" | Unexplainable difficulty, training cost, one-dev burden | Scripted EASY/NORMAL/HARD with aim noise and stamina mistakes |
| Full friend list, clubs, voice/text chat | Ludo King Adda, 8 Ball Pool friends, Salam rooms | Moderation, voice abuse, store age ratings, support load | Room code + rematch. Add mute/report only when public chat exists (v2) |
| In-match emoji / trash talk pack | Carrom King / 8 Ball Pool spice | Nice, not validating. Chat-like surface invites toxicity | Defer. If added later: 6 canned stickers, rate-limited, no free text |
| Season pass / loot boxes / gacha chests | 8 Ball Pool Pool Pass, Carrom chests | Predatory, review risk, economy rewrite, P2W perception even if "cosmetic" | Direct catalog prices. No random boxes in v1/v1.x |
| Tournaments / 8-player brackets | Ludo King tournaments | Scheduling, no-shows, prize economy, far beyond 1v1 authority | 1v1 only until matchmaking + reconnect are boringly reliable |
| Third full game in MVP | "Catalog must look full" | Owner locked Coming Soon. Splits physics/tap polish | Two playable + Coming Soon tiles |
| Kazakh / Kyrgyz / other Turkic UI in MVP | Cultural authenticity | Owner locked as expansion. Shipping unreviewed locales is worse than EN+RU done well | i18n keys now; first Turkic locale after EN+RU QA is clean |
| Exact outdoor asyk reconstruction (15 bones, 4 m, 8-to-win, running field) | Cultural purists | 15-bone first-to-8 is a 15-minute outdoor sport, not a 2–5 min mobile session | Mobile-adapted rules below. Credit the tradition in the how-to; do not claim federation sport rules |
| Alshy-face scoring as a v1 win condition | UNESCO notes bone *position* matters | Hard to read on a phone; fights "visual clarity > bone simulation" | Cosmetic landing pose + optional v2 "Alshy bonus" mode |
| Stick Pull as raw unlimited mash | Tug toys are instantly understandable | Autoclicker wins Ranked; thumbs hurt; matches are unreadable | Stamina + clamp + pattern detect (spec below) |
| Local same-phone two-thumb tug | Tug It! party trick | Not the online platform; conflicts with server authority story | Online/bot only in v1. Couch mode is v2 if requested |
| Client-authoritative or P2P ranked | Cheaper sync | Forged scores, coin dupes, rating collapse | Server authority. Hybrid prediction only for animation |
| Live ops / analytics SaaS (Amplitude, Firebase suite, Grafana) as MVP | "Need events" | Owner: instrument events, do not stand up a platform | Log APP_STARTED, REGISTERED, LOGIN, MATCHMAKING_*, MATCH_*, ITEM_PURCHASED to backend. Query later |
| Microservices / Kubernetes / PlayFab-scale backfill | "Real games do this" | One developer, modular monolith | Single API + WS. No backfill bots into Ranked |
| Licensed characters, brands, others' ornaments | "Familiar IP" | Legal; owner forbidden | Original themes only |
| Spectate / share-live | 8 Ball Pool social | Extra sync + privacy | After-match replay clip later, not live spectate |
| Daily login spinner / ad-gated rewards | Miniclip daily rewards | Ads + IAP adjacency; trains the wrong loop | Match-play is the reward loop. Tiny daily COINS chest is v1.x at most |
| Email / phone verification | Account recovery | Friction vs guest-first; support burden | Username + password; recovery is a v1.x "forgot password" if bind exists |

## Feature Dependencies

```
Alchiki Physics Prototype
    └──requires──> Readable hold-to-throw + settle-then-score
                       └──requires──> Static Alchiki how-to
                       └──requires──> Bot EASY/NORMAL/HARD
                              └──requires──> Guest session
                              └──enhances──> Catalog home (Alchiki tile live)

Guest session
    └──requires──> Bind username/password (for persistence)
                       └──requires──> Profile + per-game stats
                       └──requires──> COINS + GEMS wallets
                              └──requires──> Cosmetic shop (no IAP)
                              └──requires──> Analytics events (ITEM_PURCHASED)

Private room code
    └──requires──> Match session + reconnect (casual rules)
    └──requires──> Alchiki (or Stick Pull) playable vs human
    └──enhances──> Rematch

Quick Match
    └──requires──> Matchmaking queue + empty-queue fallback
    └──requires──> Reconnect (casual)
    └──requires──> Server-authoritative result
    └──enhances──> Rematch

Stick Pull module
    └──requires──> Shared catalog / accounts / rooms / matchmaking
    └──requires──> Stamina + server tap validation
    └──requires──> Static Stick Pull how-to
    └──enhances──> Catalog-as-platform claim

Ranked
    └──requires──> Bind account
    └──requires──> Glicko-2 (or chosen) rating + soft reset policy
    └──requires──> Reconnect (ranked rules, shorter + aggregate budget)
    └──requires──> Anti-cheat (Alchiki authority + Stick Pull tap clamp)
    └──requires──> Quick Match (or dedicated ranked queue)
    └──conflicts──> Any cosmetic that changes gameplay
    └──conflicts──> Coin-wager entry

Leaderboards (game / season / all-time)
    └──requires──> Ranked or at least rated casual
    └──requires──> Bind account (no guest on global boards)
    └──conflicts──> Ranking by coin balance

IAP (v2)
    └──requires──> Existing COINS/GEMS + idempotent grant
    └──conflicts──> Ranked P2W
```

### Dependency Notes

- **Physics prototype requires playable throw before accounts:** If FPS, collisions, spin, and a path to authority fail, do not build shop or ranked. The success metric never fires.
- **Bots require guest, not bind:** First session must complete without a keyboard.
- **Bind requires something worth saving:** Prompt after first bot win or first cosmetic grant, not at install.
- **Quick Match requires reconnect + authority:** Otherwise the most-used online button is the most-complained bug.
- **Ranked requires bind + anti-cheat + distinct reconnect:** Shipping ranked on guest + client scores is how parlor titles lose trust permanently.
- **Stick Pull enhances the platform only if it is not a second Alchiki:** Shared shell, different input model. Do not reuse hold-to-throw.
- **Leaderboards conflict with coin-rank:** 8 Ball Pool weekly "coins won" boards privilege bankroll. Ours rank skill/rating and seasonal points from rated matches only.
- **Shop conflicts with P2W:** Any stat on a saka/stick forces a ranked rewrite.

## Alchiki Mobile Rules Spec (v1)

Design goal: keep **circle, saka, knock-out** recognizable (UNESCO + Kazakhstan Assyk Federation) while forcing a **2–5 minute** sensor session. Outdoor sport rules are the inspiration, not the implementation.

**What we keep from tradition (HIGH — Astana Times 2024-05 interview with Assyk Federation; UNESCO ICH 01086):**

- Playing field is a **circle**. Target bones start clustered in the center.
- Each player has a personal **saka** (shooter), visually distinct / bright.
- Turn-based: shoot the saka to knock target bones **fully outside the circle**.
- First to a target count wins (outdoor: 15 bones, first to 8).

**What we cut for mobile (opinionated):**

- 15 bones / first-to-8 / 4–6 m field / "opportunity" closer reshoot from the rim — too long, too much walking analog, hard to read on a phone.
- Mandatory **alshy** landing to score — unreadably 3D on a 2.5D board; save as a later mode.
- Running / changing shooting distance mid-match.

### Setup

| Parameter | v1 value | Why |
|-----------|----------|-----|
| Field | Circle, camera top-down or slight 2.5D tilt | Reads like a parlor table, not a sports pitch |
| Target bones | **5** on EASY bot, **6** NORMAL, **7** HARD / human | 15 is outdoor. 5–7 finishes in a handful of turns |
| Saka | 1 per player, returned after each turn | Personal shooter is the identity object (cosmetics attach here) |
| Colliders | Disk / capsule approximation | Visual spin matters more than bone-faithful mesh |
| Physics settle | Score only after all bodies sleep or timeout ~1.2s | Prevents "still rolling" arguments |

### Turn

1. Player aims (drag / rotate aiming arrow). No aim-assist line that lengthens with shop items.
2. Hold to charge power (visible meter, 0.15–1.1s). Release throws. Charge past max pulses at max — no overcharge penalty (keeps first session kind).
3. Turn clock: **20s** to release. Timeout = forfeit the throw (saka stays, no score).
4. After settle: every **target** whose entire body is outside the circle is scored to the **throwing** player and removed.
5. Saka that leaves the circle: **0 points**, saka returns to the owner's next throw. Do not burn the turn a second time.
6. Friendly fire: knocking a bone out still scores for the thrower (outdoor "you knocked it, you keep it"). No team bones.
7. If the saka is still in-circle after settle, leave it until the next turn starts, then reset to the rim shoot point. Do not play from wherever it stopped (that is the outdoor "opportunity" — v1.x experiment only).

### Win / draw

| Mode | Win | Draw |
|------|-----|------|
| Bot / Private / Quick | First to **5** points, **or** highest score after **8 turns each** or **4:00** match clock | Allowed. Split COINS. |
| Ranked (when live) | Same score target / turn cap | No raw draw: **last successful knock-out** wins; if none, both get a draw rating update (Glicko-2 handles draws). |

Hard cap **5:00**. If the clock hits the cap mid-throw, finish the settle, then apply the table above.

### Presentation (table stakes for "understandable")

- Circle rim flashes when a bone crosses out.
- Floating +1 after settle, not mid-roll.
- How-to cards: (1) circle + saka, (2) aim, (3) hold-to-throw, (4) out = point, (5) first to 5.
- Do not mention federation diameters or alshy names in the mandatory cards. A "Tradition" info sheet can.

### Explicitly later (not v1 rules)

- Rim "opportunity" extra shot after a score.
- Alshy-face bonus / turn-order toss.
- 15-bone "sport" mode.
- Multiplayer >2.

## Stick Pull Stamina / Anti-Autoclicker Spec (v1)

Design goal: feel like **Tayak Tartysh / mas-wrestling** (World Nomad Games: opposite sit, shared stick, pull across the board after a ready/go command) while being a **15–40s** thumb sport that **cannot be won by an autoclicker**.

Local mash toys (Tug It!, Button Mash) prove the fantasy and also prove the failure mode: unlimited CPS, no server, no stamina.

### Match flow

1. Both players ready (or bot instant-ready).
2. Server countdown **3-2-1-GO** (analog of Belem → Che). Inputs before GO are **false starts**:
   - Casual: ignore pre-GO taps, small on-screen slap on the wrist.
   - Ranked: first false start = stamina penalty (start at 70%). Second = forfeit.
3. Live phase: each accepted tap adds force to your side; a **center marker** (knot / stick midpoint) moves along a 1D lane.
4. Win: marker crosses your **win threshold**, **or** you are ahead when **match clock** hits 0.
5. Duration: target **20–30s** typical, hard clamp **15s min / 40s max** (clock shown). Do not let a stamina stalemate run forever — timeout always ends it.

### Stamina model (client displays, server simulates)

Human single-finger sustainable tap is about **5–6.5 taps/s** (biomechanics-reported ceiling; treat as MEDIUM). Mobile multi-finger bursts can look like 10–15 TPS; phone screens debounce around 10–20. Design for **one-thumb** play.

| Knob | v1 value | Role |
|------|----------|------|
| Soft-efficiency band | 0–6 accepted taps/s | Full force per tap, stamina drains slowly |
| Hard clamp | **10 taps/s** accepted | Extra taps dropped. Never apply 20+ CPS even if the client sends them |
| Burst window | 8–10 taps/s for ≤1.5s | Reduced force (×0.4) and **fast** stamina drain |
| Exhaustion | stamina ≤ 0 | Force ×0.15 until stamina ≥ 25% |
| Recovery | no accepted tap for 280–350ms | Stamina regen; rewards rhythm, not mash |
| Bot EASY | 3–4 taps/s, long pauses, over-drains | New player wins often |
| Bot NORMAL | ~5 taps/s with human-like jitter | Fair |
| Bot HARD | ~7 taps/s, smarter recovery | Rarely mash-suicides |

Stamina is a bar under your avatar. When it flashes, the marker visibly slips — the player must understand *why* they lost a mash duel.

### Server validation (required for Ranked, cheap enough for all online)

Client may send tap events; server **re-timestamps** on arrival and simulates stamina itself.

1. **Rate clamp:** accept at most 10 taps/s per player (sliding 200ms buckets). Drop the rest silently (do not ACK extra force).
2. **Burst budget:** if accepted rate > 8 taps/s for > 2s continuous, treat as exhaust (force collapse). Humans fatigue; scripts do not.
3. **Regularity flag (soft):** if ≥ 20 consecutive inter-tap intervals have variance below a tight epsilon (scripted 50.0ms, 50.0ms, …), mark the match `suspect`. Casual: no ban, just log. Ranked v1.x: hidden MMR penalty / review. Do **not** auto-ban in v1 — false positives destroy trust.
4. **Impossible device rate:** > 16 claimed taps/s sustained 3s → hard reject remaining taps + `suspect`.
5. **Clock:** all win checks on server tick. Client animation is interpolated.

Do not ship client-side "anti-cheat SDKs" (Tencent ACE, Appdome) in MVP. Clamp + stamina + authority is the product feature; kernel-level detectors are a v2 ops topic.

### Presentation

- How-to cards: (1) opposite sit + stick, (2) wait for GO, (3) tap in rhythm, (4) stamina = don't mash, (5) pull the marker over.
- Haptics on GO and on threshold crossing only — not on every tap (battery + spam).
- No freeze / snap / power-up pickups (Tug It! has these; they are chaotic and P2W-adjacent).

## MVP Definition

### Launch With (v1)

Minimum to validate the PROJECT.md success metric: *first Alchiki bot match understood from static cards, plus desire for one more short session* — and to prove this is a **platform**, not a prototype APK.

- [ ] **Alchiki physics + mobile rules** — core value; prototype gate before the rest
- [ ] **Static Alchiki how-to (EN+RU)** — required for the success metric
- [ ] **Guest play** — zero-friction first session
- [ ] **Bot EASY/NORMAL/HARD** — validates rules without matchmaking
- [ ] **Catalog home** — Alchiki live, Stick Pull live, Coming Soon
- [ ] **Stick Pull with stamina + server clamp** — second module proves the shelf; without it Nomad is "an asyk demo"
- [ ] **Bind username/password** — after first win; unlocks identity surfaces
- [ ] **Private room code** — friends path; highest-trust human match
- [ ] **Quick Match (casual 1v1)** — table-stakes "Play" button
- [ ] **Reconnect (casual rules)** — 30s seat, opponent countdown, Rejoin
- [ ] **Server-authoritative results** — scores, coins, outcomes
- [ ] **Profile + basic per-game W/L** — parlor identity
- [ ] **COINS + GEMS + small cosmetic shop (no IAP)** — loop after match 2
- [ ] **Nomadic visual theme pack (subset)** — at least default + 2–3 cosmetics
- [ ] **Rematch** — private + casual + bot
- [ ] **Analytics events in existing backend logs** — APP_STARTED, REGISTERED, LOGIN, MATCHMAKING_*, MATCH_*, ITEM_PURCHASED; no extra SaaS
- [ ] **i18n keys** — EN+RU shipped; other locales empty but wired

### Add After Validation (v1.x)

Triggers assume v1 already produces repeat Alchiki sessions.

- [ ] **Ranked queue** — trigger: casual online + reconnect are stable (low abort rate) and bind rate is healthy
- [ ] **Glicko-2 rating + soft season reset** — trigger: ranked ships; reset when seasons start or when rating inflation appears
- [ ] **Leaderboards: per game / season / all-time** — trigger: ranked or rated casual exists; guests excluded
- [ ] **Reconnect ranked rules** — shorter window (~15–20s), aggregate pause budget, disconnect cap, rated forfeit
- [ ] **Suspect-tap review on Ranked Stick Pull** — trigger: first autoclicker complaints
- [ ] **Forgot-password / account recovery** — trigger: first "I lost my bind" tickets
- [ ] **Daily COINS grant (no spinner, no ad)** — trigger: D1 retention needs a second hook
- [ ] **Bind reward (small GEMS)** — trigger: if guests bounce before bind
- [ ] **Rim-opportunity extra shot** (Alchiki) — trigger: playtests say turns feel samey
- [ ] **Canned emotes (6)** — trigger: private rooms feel mute; still no free chat
- [ ] **First Turkic locale (KK or KY)** — trigger: EN+RU complete and a locale owner exists

### Future Consideration (v2+)

- [ ] **IAP for GEMS** — after cosmetic loop is wanted without being required to win
- [ ] **OAuth as extra bind** — never replace username/password
- [ ] **Tournaments / clubs / voice / friends graph**
- [ ] **Season pass, boxes, ads**
- [ ] **Third traditional game**
- [ ] **Alshy-face mode / 15-bone sport mode**
- [ ] **Couch same-device Stick Pull**
- [ ] **Spectate / share replay**
- [ ] **Play Integrity / App Attest / commercial anti-cheat**
- [ ] **Remaining Turkic locales**

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Alchiki physics + mobile rules | HIGH | HIGH | P1 |
| Guest play | HIGH | LOW | P1 |
| Static how-to EN+RU | HIGH | LOW | P1 |
| Bot EASY/NORMAL/HARD | HIGH | MEDIUM | P1 |
| Catalog + Coming Soon | HIGH | LOW | P1 |
| Bind username/password | HIGH | MEDIUM | P1 |
| Private room code | HIGH | LOW | P1 |
| Server-authoritative result | HIGH | HIGH | P1 |
| Reconnect casual | HIGH | HIGH | P1 |
| Quick Match casual | HIGH | HIGH | P1 |
| Stick Pull + stamina/clamp | HIGH | MEDIUM | P1 |
| Profile + per-game W/L | MEDIUM | LOW | P1 |
| COINS+GEMS + cosmetic shop (no IAP) | MEDIUM | MEDIUM | P1 |
| Rematch | MEDIUM | LOW | P1 |
| Analytics events (logs only) | LOW | LOW | P1 |
| Ranked + Glicko-2 + soft reset | HIGH | HIGH | P2 |
| Leaderboards game/season/all-time | MEDIUM | MEDIUM | P2 |
| Reconnect ranked rules | HIGH | MEDIUM | P2 |
| Daily COINS / bind GEMS reward | MEDIUM | LOW | P2 |
| Canned emotes | LOW | LOW | P2 |
| Turkic locale #1 | MEDIUM | MEDIUM | P2 |
| IAP | HIGH (revenue) | HIGH | P3 |
| Chat / clubs / friends | MEDIUM | HIGH | P3 |
| Tournaments / season pass | MEDIUM | HIGH | P3 |
| Third game / alshy sport mode | MEDIUM | HIGH | P3 |
| OAuth / ads / gacha | LOW–MEDIUM | HIGH | P3 |

**Priority key:**

- P1: Must have for launch
- P2: Should have, add when v1 loop is proven
- P3: Nice to have, future consideration

## Competitor Feature Analysis

| Feature | 8 Ball Pool (Miniclip) | Ludo King / Carrom King | Tug mash apps | Legacy Asyk Atu | Nomad Games |
|---------|------------------------|-------------------------|---------------|-----------------|-------------|
| Guest → bind | Guest + Facebook/Google/Apple strongly pushed | Facebook/login to save progress | Often no account | Thin / none | **Guest first, username/password later** |
| First session | Practice / low tables | Offline vs computer | Instant mash | Local / P2P | **Alchiki vs EASY bot + static cards** |
| Session length | ~3–7 min | Long board games; Quick Mode added | ~10–30s | Unclear / outdoor-paced | **Alchiki 2–5 min; Stick Pull 15–40s** |
| Friends play | Facebook friends / challenge | Private room + share code | Same-phone | LAN / hotseat | **Short room code + share sheet** |
| Random PvP | Tables + skill/coin MM | Online matchmaking | Rarely online | "Global network" (dated) | **Quick Match casual, then Ranked** |
| Bots | Practice | First-class offline | vs AI common | Unknown | **EASY/NORMAL/HARD, no ML** |
| Reconnect | Expected at this scale | "Game resume" advertised | N/A local | Weak | **Casual 30s; Ranked stricter (v1.x)** |
| Economy | Coins wager + Cash IAP | Coins / diamonds + IAP | Optional IAP skins | Workshop upgrades | **COINS+GEMS, no IAP, no wager** |
| Cosmetics | Cues with **Force/Aim/Spin/Time** (P2W) | Dice/boards/strikers; some with power | Skins | Weight/color/size workshop | **Cosmetic only; same physics for all** |
| Ranked / leagues | Weekly leagues, tables | Seasons, tournaments | High-score local | None modern | **Glicko-2 ranked, soft reset; no coin ladder** |
| Leaderboards | Weekly coins won, friends/country/global | Seasons / clubs | Local stats | None | **Per game / season / all-time, not coins** |
| Tutorial | Table "i" + long-tail complexity | Traditional rules assumed | "No tutorial" | Rules dump | **Static 3–5 cards only** |
| Chat / social | Friends, challenges, VIP | Voice/text, Adda clubs | None | None | **None in v1** (anti-feature) |
| Catalog | Mini-games + 9-ball inside one sport | Ludo + Snakes | Single toy | Single game | **Alchiki + Stick Pull + Coming Soon** |
| Cultural game | Generic pub pool | Indian parlor (strong) | Generic rope | Authentic but abandoned | **Nomadic catalog, arcade-readable** |
| Authority | Mature server stack | Online + resume | Client/local | Mixed P2P | **Server authority from v1 online** |

**Opinion:** Copy Ludo King's **room code + bot-first** and Miniclip's **guest → currency HUD → bind**. Refuse 8 Ball Pool's **wager tables and stat cues** — that is the trap that would make Nomad feel like a clone and break the honesty promise.

## Sources

Confidence via source class (research-plan / classify-confidence seam unavailable in this runtime; Brave/Firecrawl/Exa unavailable; WebSearch + WebFetch used). Official / standards = HIGH. Store listings + vendor docs = HIGH–MEDIUM. Guides / community = MEDIUM. Biomechanics-via-secondary = MEDIUM. Do not treat MEDIUM tap-rate numbers as lab truth — tune on device.

- UNESCO ICH 01086, *Kazakh traditional Assyk games* (inscribed 2017) — saka, knock-out, bone position. [HIGH]
  https://ich.unesco.org/en/RL/kazakh-traditional-assyk-games-01086
- The Astana Times (2024-05), interview with Assyk Federation (Zhomart Sabyrzhanuly) — 15 assyks, 4–6 m circle, first to 8, "opportunity" closer shot. [HIGH]
  https://astanatimes.com/2024/05/assyk-great-kazakh-outdoor-game-video/
- World Nomad Games, *Tayak Tartysh (Mas-Wrestling)* — opposite sit, shared stick, best of bouts. [HIGH]
  https://worldnomadgames.org/en/sport/stick-deadlift/
- World Nomad Games Astana 2024 sports note on mas-wrestling (pull stick or opponent across the board). [HIGH]
  https://worldnomadgames.kz/en/news/vidy-sporta/34
- Colyseus docs, *Reconnection* — 30s seat hold, auto + token rejoin, mark disconnected, snapshot resync. [HIGH]
  https://docs.colyseus.io/room/reconnection
- MiniTon docs, *Aborted Matches and Forfeits* — ~20s reconnect, aggregate pause budget, forfeit ≠ crash abort. [HIGH]
  https://docs.miniton.games/developer-success/miniton-developer-documentation/aborted-matches-and-forfeits
- Miniclip Help, *How to start playing 8 Ball Pool* / *Why and how to save a guest account* / *Leaderboards* — guest, bind, 1v1, friends, weekly coin boards. [HIGH]
  https://support.miniclip.com/hc/en-us/articles/360020665798--How-to-start-playing-8-Ball-Pool
  https://support.miniclip.com/hc/en-us/articles/4404723030033-Why-and-how-to-save-a-guest-account
  https://support.miniclip.com/hc/en-us/articles/204975658-Leaderboards-8-Ball-Pool
- Miniclip Help, Mini Football / Mini Tennis start guides — guest save, coins+gems HUD, shop, play, leaderboards. [HIGH]
  https://support.miniclip.com/hc/en-us/articles/360013709757-How-to-start-playing-Mini-Football
- Google Play, *Ludo King* (updated 2026-09-04) — offline computer, online 2–6, private rooms, seasons, coins/diamonds, themes, rematch/chat. [HIGH]
  https://play.google.com/store/apps/details?id=com.ludo.king
- Google Play / App Store listings, *Carrom King* — online 1v1, room code, resume, opponent stats, strikers with power (P2W-adjacent). [HIGH]
- Play listing / mirrors, *Asyk atu* (KEO Limits, ~2020) — global/LAN/hotseat, workshop weight/color/size; no modern parlor platform. [MEDIUM]
- Tug It! / Button Mash / Tug Of War store copy — local mash, vs AI, skins, no-account party. [MEDIUM]
- Secondary 8 Ball Pool economy writeups (VGTopup and similar, 2026) — coins wager, Cash, cue Force/Aim/Spin/Time. [MEDIUM — used only to confirm P2W cue stats as an anti-pattern]
- Click-speed / CPS explainers citing finger-tapping ceilings ~5–6.5/s; mobile screen debounce ~10–20 TPS. [MEDIUM]
- Hypixel community writeup on statistical autoclicker detection (variance / regularity). [MEDIUM — informs logging, not v1 bans]

---
*Feature research for: Nomad Games — mobile multiplayer traditional parlor PvP*
*Researched: 2026-09-05*
