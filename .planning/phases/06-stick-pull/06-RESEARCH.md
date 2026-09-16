# Phase 6: Stick Pull - Research

**Researched:** 2026-09-14
**Domain:** Second catalog title — server-authoritative 1D stamina tug (countdown, tap clamp, bots, 8s reconnect); Flutter/Flame presentation without Forge2D Alchiki reuse
**Confidence:** HIGH for seams (catalog/queue/rooms/session/profile/economy already exist; Alchiki-only hardcodes are the work). MEDIUM for exact force/friction constants (yolo-locked below within FEATURES bands).

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-78:** Stick Pull ships **bot + private room + Casual Quick Match** in this phase — same entry surface as Alchiki (catalog tile primary paths). Ranked Stick Pull is **Phase 7** (MODE-04). Do not invent a Stick-Pull-only mode set.
- **D-79:** Bot path: EASY / NORMAL / HARD chips on the Stick Pull tile (BOT-02). Private: reuse create/join room + Ready + rematch patterns; Stick Pull match instead of Alchiki table. Quick Match: reuse casual queue/fallback (bot/invite) with game=`STICK_PULL` (or equivalent discriminator) — empty-queue still never a 60s fail spinner.
- **D-80:** Rematch after Stick Pull follows existing mode rules: bot → one-tap Play again; private/casual PvP → dual-accept window (Phase 3/5). New match is Stick Pull, same seats where applicable.
- **D-81:** Shared **1D lane** with a **center marker** (knot / stick midpoint). Players sit opposite (presentation). **Stamina bar under the avatar**; when stamina flashes / exhausts, the marker **visibly slips** so the player reads *why* they lost.
- **D-82:** Server drives **3-2-1-GO**; client shows countdown then GO. **Haptics only on GO and threshold win** — not every tap. No freeze/snap/power-up pickups.
- **D-83:** Equipped **Stick Pull skins** from economy loadout apply at match start (presentation-only; D-54). Default free skin if unequipped.
- **D-84:** Full-screen static card pager **before first Stick Pull match** (same product pattern as Alchiki D-12…D-14): skip available on card 1; auto-show once per device; later matches skip to tug; reopen same deck from Pause → How to play.
- **D-85:** **Five cards** (FEATURES): (1) opposite sit + stick, (2) wait for GO, (3) tap in rhythm, (4) stamina = don't mash, (5) pull the marker over. EN+RU via l10n. No animated coach overlays.
- **D-86:** Online Stick Pull reconnect grace **~8s casual** (SESS-04). Ranked ~12s is **out of this phase**. On expiry: **forfeit** for the dropped player; remaining player **wins**. **No bot-fill mid-tug** (explicit SESS-04 / D-42 spirit).
- **D-87:** During grace the opponent sees a clear **reconnect / waiting** state (countdown or short copy); on forfeit show result and rematch/catalog CTAs. Do not silently continue as if the seat were AI-filled.
- **D-88:** Adopt FEATURES v1 stamina table as product lock: soft band **0–6** taps/s full force; hard clamp **10** accepted taps/s (extras drop, no force); burst **8–10** for ≤1.5s reduced force + fast drain; exhaustion force ×0.15 until stamina ≥25%; recovery after **~280–350ms** no-tap. Exact numeric micro-tuning within these bands is Claude’s discretion if playtests demand it — do not remove bands.
- **D-89:** Match length: target **~20–30s** typical; hard clamp **15–40s**; clock always ends a stalemate. Win = marker crosses threshold **or** ahead at clock 0.
- **D-90:** Pre-GO taps in **casual/bot/private/QM** (this phase): **ignore** + light false-start feedback (FEATURES casual). Ranked false-start penalties wait for Phase 7.
- **D-91:** Server **re-timestamps** taps and simulates stamina; client interpolates marker. Soft **suspect** log on robotic regularity; **no auto-ban** in v1 (STICK-04).

### Claude's Discretion
- Exact force-per-tap constants, marker friction, win-threshold distance, bot jitter curves within EASY/NORMAL/HARD envelopes.
- Whether Stick Pull uses a dedicated Modulith package vs `games.stickpull` beside Alchiki; REST vs WS frame names — as long as D-78…D-91 and SESS-01 hold.
- Catalog tile chrome (promote from Coming Soon) and tug HUD layout within PRES-02 — UI-SPEC.
- Whether QM Stick Pull shares one queue service with a `game` field or a parallel FIFO — planner chooses; product is D-79.

### Deferred Ideas (OUT OF SCOPE)
- Ranked Stick Pull false-start penalties and ~12s reconnect (Phase 7 / SESS-03 overlap)
- STICK-06 same-device couch tug
- Auto-ban / hidden MMR penalty for suspect taps (v1.x)
- Redis shared queue / multi-instance Stick Pull MM
- Power-ups, freeze, snap (explicitly rejected in FEATURES)
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| CAT-02 | Open Stick Pull as playable from catalog | Flip `CatalogService` `stick_pull` → PLAYABLE; promote `_ComingSoonTile` → `_StickPullTile` with QM / Play / Create room / chips (06-UI-SPEC) |
| STICK-01 | 3-2-1-GO then live shared-stick marker | Server countdown phase + WS `Countdown` / `TapResolved` / `StickState`; Flame 1D lane interpolates marker |
| STICK-02 | Stamina reduces mash force; rhythm required | `StickPullSim` stamina bands D-88; client bars + exhaust slip (D-81) |
| STICK-03 | ~15–40s; threshold or clock-0 win | Match clock 30s default; hard clamp 15–40; settle on threshold or ahead-at-0 |
| STICK-04 | ≤10 taps/s accepted; suspect log; no auto-ban | Server re-timestamp + 200ms buckets; drop extras; regularity → log only |
| STICK-05 | Skippable static how-to EN+RU | `/howto/stick-pull` + `howto.stickpull.seen`; five ARB cards from UI-SPEC |
| BOT-02 | EASY/NORMAL/HARD bots with human-like jitter | `StickPullBot` scripted TPS + pauses; chips on Stick Pull tile only |
| SESS-04 | ~8s casual reconnect then forfeit; no bot-fill | Game-aware `ReconnectPolicy` (8s for `STICK_PULL`); reuse drop/rejoin/forfeit; never spawn bot mid-tug |
</phase_requirements>

## Summary

Phase 6 turns the existing **Coming Soon** `stick_pull` shelf tile into a second live parlor title. The platform shell already has guest JWT, private rooms, casual FIFO queue, 30s Alchiki reconnect, rematch dual-accept, economy Stick Pull skins (`stick_pull` loadout slot), and profile `STICK_PULL` stats rows that stay zero until settle writes `match.game=STICK_PULL`. What is missing is a **non-Alchiki match engine**: today’s `GameEngine` / WS `ThrowInput` / Forge2D table are throw-and-bones only and must **not** be reused for tug.

Planner should treat this as: (1) **promote catalog + how-to**; (2) **game discriminator** through rooms / queue / createMatch / rematch; (3) **new StickPull sim + lifecycle** beside Alchiki; (4) **WS tap frames + 8s reconnect**; (5) **Flame 1D presentation + Flutter HUD** per approved 06-UI-SPEC. No new pub/npm packages; no Redis; no Ranked; no Forge2D on the tug.

**Primary recommendation:** Implement `com.nomadgames.games.stickpull.StickPullSim` + session lifecycle branching on `match.game`, extend rooms/queue with `game=STICK_PULL`, flip catalog PLAYABLE, and ship a dedicated Flutter/Flame stick-pull match route — keep Alchiki `GameEngine` untouched.

### Claude discretion locks (yolo — planner MUST use these)

| Topic | Decision |
|-------|----------|
| Backend package | **`com.nomadgames.games.stickpull`** beside Alchiki — **not** a new Modulith `@ApplicationModule` |
| Match orchestration | **Branch in `MatchService`** (and WS handler) on `match.getGame()`; do **not** force Stick Pull into `GameEngine` throw SPI |
| Casual queue | **One** `CasualQueueService` with **per-game FIFO** (`ConcurrentHashMap<String, ConcurrentLinkedQueue<UUID>>`) + enqueue body/query `game` |
| Private rooms | Flyway add **`rooms.game`** (`ALCHIKI` \| `STICK_PULL`, default `ALCHIKI`); `create(playerId, game)` |
| Reconnect grace | **`ReconnectPolicy.graceFor(game)`** → `STICK_PULL` = **8s**, else **30s**; broadcast `secondsLeft` from that value |
| Match clock | Default **30s** live phase after GO; reject create if outside **15–40**; hard_cap = matchDeadline |
| Marker space | Position **[-1, +1]**; host/local near side = **−1**; joiner/far = **+1**; win threshold **±0.85** |
| Soft force | **+0.012** marker units per accepted soft-band tap (toward puller’s side) |
| Burst | Rate **8–10**/s for **≤1.5s** continuous → force **×0.4**, drain **fast**; then treat as approaching exhaust (FEATURES table wins over the older “>2s” prose line) |
| Exhaust | Force **×0.15** while stamina **&lt; 25%** after hitting 0 |
| Recovery | Regen starts after **320ms** no accepted tap (mid 280–350); regen **~35%/s** while idle |
| Clamp | Sliding **200ms** buckets; accept **≤2** taps per bucket (**10/s**); extras **silent drop** |
| Suspect | ≥20 consecutive inter-tap intervals with variance **&lt; 0.5ms²** → log `suspect=true` on match; **no ban** |
| Bot EASY | Mean **3.5** tps, σ≈0.45, pause **500–1100ms** every 6–10 taps; over-drains intentionally |
| Bot NORMAL | Mean **5.0** tps, σ≈0.35, short pauses; rare burst |
| Bot HARD | Mean **7.0** tps, σ≈0.25, recovers before exhaust; rarely mash-suicides |
| WS frames | `TapInput`, `TapResolved`, `StickState`, `Countdown`, keep `Ping`/`Pong`/`OpponentDropped`/`OpponentRejoined`/`MatchSettled`; Alchiki keeps `ThrowInput` |
| REST bot start | `POST /v1/matches` with `game=STICK_PULL`, `mode=BOT`, `difficulty` |
| How-to prefs | Key **`howto.stickpull.seen`** (mirror Alchiki store API) |
| Bot chip memory | Separate **`lastStickPullBotDifficultyProvider`** (do not clobber Alchiki chip) |
| Tap zone height | **96dp** (UI-SPEC discretion band 48–96) |
| Local seat | Marker pulls toward **near/bottom** edge for local player |
| Skin paint | Map `stick_pull_default` → wood shaft `#8B5A2B`; `stick_pull_ice` → ice rim `#7EB6D9` accents — presentation only |
| Tick rate | Server sim tick **20 Hz** while LIVE; broadcast `StickState` **10 Hz** (or on accepted tap) |
| FEATURES 2s burst prose | **Ignore** — D-88 / table **1.5s** is authoritative |

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Catalog PLAYABLE flip | API / Backend (`catalog`) | Browser (tile chrome) | Server status is SoT; client renders CTAs |
| How-to gate + cards | Browser / Client | — | Device prefs + ARB; no server tutorial state |
| Bot / private / QM entry | API (`session` / `matchmaking`) | Browser routes | REST lobby/queue; D-78/D-79 |
| Countdown 3-2-1-GO | API / Backend | Browser display | Server clock (D-82); client never authors GO |
| Tap accept + stamina + marker | API / Backend (`stickpull` sim) | Browser interpolate | SESS-01 / D-91 |
| Tap clamp + suspect log | API / Backend | — | STICK-04; no client ban UI |
| Bot jitter taps | API / Backend | — | Scripted server bot; client only presents |
| 1D lane + stick skin | Browser / Flame | CDN assets | Presentation; skins from loadout at start |
| Stamina / clock HUD | Browser / Flutter overlay | — | 06-UI-SPEC bars + clock |
| Reconnect 8s / forfeit | API / Backend | Browser banners | SESS-04; no bot-fill |
| Rematch Stick Pull | API (`RematchWindow`) | Browser CTAs | D-80 mode rules |
| Profile STICK_PULL W/L | API (`profile`) | Browser | Already wired via `match.game` |
| Economy stick skin apply | API loadout read | Flame paint | D-83 / D-54 |

## Project Constraints (from .cursor/rules/ / PROJECT)

No `.cursor/rules/` in repo root. Actionable locks from PROJECT / STACK / prior RESEARCH / 06-UI-SPEC:

- **Authority:** Server authors scores, outcomes, currency, XP/stats, stamina, marker, countdown; client never POSTs force/marker/win.
- **No Redis day one:** In-process queues only.
- **Physics lock for Alchiki unchanged:** Flutter 3.47 + Flame **1.38.2** + forge2d **0.14.2** / flame_forge2d **0.19.3+7** — Stick Pull **must not** attach Forge2D.
- **Backend lock:** Java 21 + Spring Boot **4.1.1** + Modulith **2.1.1** + PostgreSQL; REST lobby/queue; raw WS in-play.
- **Guest-first:** Stick Pull bot/private/QM open to guests.
- **i18n:** Every new string ARB EN+RU (06-UI-SPEC tables).
- **PRES-02:** Felt `#1B6B3A` / wood `#241810` / gold `#F0B429`; no licensed IP.
- **Cosmetics presentation-only** (D-54 / D-83).
- **No nested `.git` under nomad-game.**
- **UI contract:** Approved `06-UI-SPEC.md` extends 01–05 — planner must not invent alternate chrome.

No project skills under `.cursor/skills/`. Knowledge graph: **absent**.

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Flutter SDK | **3.47.x** / Dart **3.13.x** (`sdk: ^3.13.2`) | Catalog / how-to / tug HUD / routes | Phase lock [VERIFIED: client/pubspec.yaml] |
| Flame | **1.38.2** | 1D lane GameWidget **without** forge2d | Already pinned; GameWidget + PositionComponent [CITED: docs.flame-engine.org/latest/flame/game_widget.html] |
| go_router | **18.0.1** | `/howto/stick-pull`, `/match?game=stickPull…` | Existing [VERIFIED: pubspec] |
| Spring Boot | **4.1.1** | REST + WS + scheduling | [VERIFIED: backend/pom.xml] |
| Spring Modulith | **2.1.1** | Keep stickpull under `games` package | Existing pattern [VERIFIED: pom] |
| PostgreSQL + Flyway | existing | `rooms.game`; optional match JSON state | V1–V9 present; next **V10** |
| JUnit + Testcontainers | Boot BOM | StickPullSimTest, StickPullIT, queue/room game filter, 8s reconnect IT | Follow ReconnectIT / CasualQueueIT |
| `flutter_test` | SDK | catalog promote, howto stick, tug HUD widget tests | Follow catalog_test / howto_test |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `dio` / `flutter_riverpod` / `web_socket_channel` / `flutter_secure_storage` / `shared_preferences` | existing | REST, WS taps, reconnect token, howto seen | Extend — **do not add packages** |
| Flutter `HapticFeedback` (`services`) | SDK | GO + threshold only | No haptic plugin [ASSUMED API stable — verify at implement] |
| forge2d / flame_forge2d | pinned | **Alchiki only** | **Forbidden** on Stick Pull routes |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Branch `MatchService` on game | New Modulith `stickpull` module | Extra wiring; Alchiki already lives as `@Component` under `games.alchiki` — **reject new module** |
| Parallel `CasualQueueServiceStickPull` | Shared service + game key | Duplicate rate-limiter/IT surface — **reject** |
| Implement `GameEngine` for tug | Dedicated `StickPullSim` | `GameEngine` is throw/bones SPI — **reject** shoehorning |
| Client-side stamina | Server-only sim | Violates D-91 / STICK-04 — **reject** |
| New Flame/Forge packages | Existing Flame only | No install needed — **reject new deps** |
| Reuse Alchiki 30s reconnect | Game-aware 8s | SESS-04 — **reject** sharing 30s for Stick Pull |

**Installation:**

```bash
# No new packages. Verify pins only:
# client/pubspec.yaml — flame: 1.38.2 (no forge2d on stick-pull imports)
# backend/pom.xml — spring-boot 4.1.1
```

**Version verification:** Flutter/Dart not on researcher PATH this session; versions taken from `client/pubspec.yaml` and `backend/pom.xml` [VERIFIED: files on disk].

## Package Legitimacy Audit

> Phase 6 installs **no new** npm/PyPI/crates/pub packages. Existing Flutter deps stay pinned.

| Package | Registry | Age | Downloads | Source Repo | Verdict | Disposition |
|---------|----------|-----|-----------|-------------|---------|-------------|
| *(none new)* | — | — | — | — | N/A | No install |

**Note:** `gsd-tools query package-legitimacy check --ecosystem npm flame` returns misleading npm hits — **do not** treat Flame as an npm package. Flame is Pub (`pub.dev/packages/flame`) already vendored via pubspec.

**Packages removed due to [SLOP] verdict:** none (no candidates)
**Packages flagged as suspicious [SUS]:** none for this phase

## Architecture Patterns

### System Architecture Diagram

```
Catalog tile Stick Pull
  ├─ Play Stick Pull (bot chip) ──► howto? ──► POST /v1/matches {STICK_PULL,BOT}
  ├─ Quick Match ──► enqueue(game=STICK_PULL) ──► MATCHED | 8s fallback
  │                      └─ createCasualMatch(..., STICK_PULL)
  └─ Create Stick Pull room ──► Room(game=STICK_PULL) ──► Ready ──► createPrivateMatch STICK_PULL

Match IN_PLAY (game=STICK_PULL)
  │
  ▼
Server StickPullLifecycle
  COUNTDOWN (3,2,1,GO) ──broadcast──► client overlay
  LIVE ◄── TapInput (WS) ── re-timestamp / clamp / stamina / marker
       ◄── BotScheduler (bot mode)
       ── StickState @10Hz ──► Flame interpolate
  SETTLE (threshold | clock0 | forfeit | leave)
       ── afterTerminal (economy + profile game=STICK_PULL)

Drop mid-tug
  markDropped → grace 8s → OpponentDropped{secondsLeft:8}
  expire → remaining wins; NO bot-fill
  rejoin → full StickPull snapshot (not Alchiki poses)
```

### Recommended Project Structure

```
backend/src/main/java/com/nomadgames/
├── games/stickpull/
│   ├── StickPullSim.java          # stamina + marker + clamp + suspect
│   ├── StickPullBot.java          # EASY/NORMAL/HARD jitter
│   ├── StickPullPhase.java        # COUNTDOWN|LIVE|SETTLED
│   └── StickPullConstants.java    # yolo numeric locks
├── session/
│   ├── MatchService.java          # branch create/applyTap/tick by game
│   ├── internal/MatchWebSocketHandler.java  # TapInput dispatch
│   └── internal/ReconnectPolicy.java        # graceFor(game)
├── matchmaking/
│   ├── CasualQueueService.java    # per-game FIFO
│   └── RoomService.java           # create(game)
└── catalog/CatalogService.java    # stick_pull PLAYABLE

client/lib/
├── catalog/catalog_page.dart      # _StickPullTile
├── howto/stick_pull_howto_page.dart
├── howto/howto_seen_store.dart    # add stickpull key (or sibling store)
└── games/stick_pull/
    ├── stick_pull_match_page.dart # Stack: Flame + Flutter HUD + tap zone
    ├── stick_pull_game.dart       # FlameGame 1D lane (no forge2d)
    └── stick_pull_ws.dart         # TapInput / StickState client
```

### Pattern 1: Server re-timestamp + sliding clamp
**What:** Ignore client tap timestamps; on each `TapInput`, `acceptedAt = Instant.now()`; bucket by `floor(epochMs/200)`; accept ≤2/bucket.
**When to use:** All human Stick Pull taps (bot/private/QM).
**Example:**
```java
// Source: FEATURES.md Stick Pull Spec + D-91 (project)
boolean acceptTap(Deque<Instant> window, Instant now) {
  while (!window.isEmpty() && Duration.between(window.peekFirst(), now).toMillis() >= 1000) {
    window.removeFirst();
  }
  if (window.size() >= 10) return false; // hard clamp 10/s
  window.addLast(now);
  return true;
}
```

### Pattern 2: Flame 1D lane + Flutter tap zone
**What:** `GameWidget` renders stick/marker; Flutter `GestureDetector` full-width tap zone (≥96dp) sends WS taps; `HitTestBehavior` so HUD buttons work.
**When to use:** All Stick Pull match pages.
**Example:**
```dart
// Source: docs.flame-engine.org/latest/flame/game_widget.html
GameWidget(
  game: stickPullGame,
  // Prefer Flutter Stack HUD (match Alchiki overlay style) over Flame overlays for Pause/stamina
)
```

### Pattern 3: Game-aware reconnect
**What:** `markDropped` uses `ReconnectPolicy.graceFor(match.getGame())` so Alchiki ITs stay at 30 and Stick Pull uses 8.
**When to use:** Any human PvP drop.
**Example:**
```java
int seconds = ReconnectPolicy.graceSeconds(match.getGame()); // STICK_PULL -> 8
Instant deadline = now.plusSeconds(seconds);
broadcastJson(matchId, Map.of("type", "OpponentDropped", "secondsLeft", seconds));
```

### Anti-Patterns to Avoid
- **Attaching forge2d / AlchikiMatchGame to Stick Pull:** Wrong input model; violates UI-SPEC.
- **Trusting client force or client timestamps:** Autoclicker wins (STICK-04).
- **Bot-fill on grace expiry:** Explicitly forbidden (D-86 / SESS-04).
- **One shared 30s grace for all games:** Breaks SESS-04.
- **Enqueue Stick Pull into Alchiki-only FIFO:** Cross-game pairing.
- **Showing Coming Soon after promote:** CAT-02 fail.
- **Per-tap haptics or Ranked false-start UI:** Out of scope / D-82 / D-90.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Rate limiting | Custom token bucket from scratch without tests | Sliding 200ms / 10/s from FEATURES | Spec already defines buckets |
| Reconnect tokens | New token scheme | Existing `ReconnectPolicy` mint/hash/rotate | Proven in ReconnectIT |
| Rematch | New rematch protocol | `RematchWindow` + mode create*Match(STICK_PULL) | D-80 |
| How-to persistence | Server flag | `SharedPreferences` key like Alchiki | D-84 device-local |
| Queue pairing | Redis / Postgres queue | In-process FIFO + game key | Phase 5 lock |
| Haptics plugin | `vibration` package | `HapticFeedback` SDK | No new deps |
| Physics tug | Forge2D joints | 1D float marker sim | D-81 |

**Key insight:** Stick Pull is a **small authoritative sim** + **presentation shell reuse**. Complexity is wiring `game` through existing platform paths, not inventing a second platform.

## Common Pitfalls

### Pitfall 1: Alchiki hardcodes assume game=ALCHIKI forever
**What goes wrong:** `createMatch` rejects non-ALCHIKI; `createHumanMatch` always writes ALCHIKI; rooms have no game column; queue pairs across titles; rematch creates Alchiki after Stick Pull.
**Why it happens:** Phase 2–5 never needed a second game discriminator end-to-end.
**How to avoid:** Audit every ` "ALCHIKI"` literal in matchmaking/session; thread `game` from catalog CTA → create → rematch → profile.
**Warning signs:** Profile Stick Pull stays zero after bot wins; private Stick Pull lobby starts Alchiki table.

### Pitfall 2: Reusing 30s reconnect / OpponentDropped secondsLeft
**What goes wrong:** Stick Pull feels unfairly long; ITs assert `≤30` still pass while product wants 8.
**Why it happens:** `ReconnectPolicy.GRACE_SECONDS = 30` is a constant used in broadcast.
**How to avoid:** Game-aware grace; add `StickPullReconnectIT` asserting `secondsLeft ∈ [1,8]` and forfeit by ~8s.
**Warning signs:** UI shows Reconnecting… 30 on Stick Pull.

### Pitfall 3: Client-side stamina or accepting dropped taps visually as force
**What goes wrong:** Desync; mash looks strong locally then snaps back.
**Why it happens:** Tempting to animate every tap locally.
**How to avoid:** Optimistic pulse optional; marker **only** from server `StickState` / `TapResolved`; silent drops = no force pulse.
**Warning signs:** Marker jumps on lag; clamp feels “broken”.

### Pitfall 4: FEATURES 1.5s vs 2s burst conflict
**What goes wrong:** Two implementers pick different burst windows.
**Why it happens:** Spec table says ≤1.5s; validation prose says >2s.
**How to avoid:** **D-88 / yolo lock = 1.5s**; document in StickPullConstants.
**Warning signs:** Unit tests disagree with FEATURES checklist.

### Pitfall 5: Bot-fill or AI takeover chrome
**What goes wrong:** Violates SESS-04 / D-87.
**Why it happens:** Casual empty-queue bot fallback mental model leaks into mid-match drop.
**How to avoid:** Expiry path = forfeit only; remaining seat keeps human result CTAs.
**Warning signs:** Result shows `Bot wins` after opponent disconnect in private/casual.

### Pitfall 6: How-to key collision / clearing Alchiki seen
**What goes wrong:** Stick Pull howto skipped incorrectly or Alchiki howto reappears.
**Why it happens:** Sharing `howto.alchiki.seen`.
**How to avoid:** Dedicated `howto.stickpull.seen`.
**Warning signs:** First Stick Pull jumps straight to tug without cards.

## Code Examples

### StickPullSim soft vs clamp (illustrative)

```java
// Source: .planning/research/FEATURES.md Stick Pull Spec (v1) + D-88
public final class StickPullSim {
  public static final double SOFT_FORCE = 0.012;
  public static final double BURST_FORCE_MULT = 0.4;
  public static final double EXHAUST_FORCE_MULT = 0.15;
  public static final double WIN_THRESHOLD = 0.85;
  public static final long RECOVERY_MS = 320;
  // applyAcceptedTap(side, now): update stamina, marker; return StickSnapshot
}
```

### WS TapInput (client → server)

```json
{ "type": "TapInput", "schemaVersion": 1, "clientSeq": 42 }
```

Server responds/broadcasts (no client force field):

```json
{
  "type": "TapResolved",
  "accepted": true,
  "marker": -0.12,
  "staminaHost": 0.81,
  "staminaJoiner": 0.77,
  "phase": "LIVE",
  "clockSecondsLeft": 24
}
```

### Catalog status flip

```java
// Source: backend CatalogService (current Coming Soon → Phase 6)
new CatalogTileView("stick_pull", CatalogTileStatus.PLAYABLE)
```

### How-to seen key

```dart
// Mirror client/lib/howto/howto_seen_store.dart
static const String stickPullSeenKey = 'howto.stickpull.seen';
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Stick Pull Coming Soon tile | PLAYABLE second title | Phase 6 | CAT-02 |
| Alchiki-only matches | `game` discriminator ALCHIKI \| STICK_PULL | Phase 6 | Platform shelf proven |
| Unlimited mash toys | Stamina + 10/s clamp + authority | FEATURES v1 | Fair 15–40s bouts |
| 30s reconnect for all casual | 8s for Stick Pull online | SESS-04 | Faster forfeit mid-tug |
| Profile Stick Pull zeros forever | Increment on settle | Phase 6 | PROF-02 live |

**Deprecated/outdated:**
- FEATURES validation bullet “burst &gt;2s continuous” — superseded by D-88 **1.5s** band for this phase.
- Treating Stick Pull skins as “unused until later” — D-83 applies them now at match start.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Flutter `HapticFeedback.mediumImpact` sufficient for GO/threshold without a plugin | Standard Stack | Need alternate haptic call on some devices |
| A2 | Soft force 0.012 / threshold 0.85 / 30s clock feel “~20–30s typical” without retune | Yolo locks | Playtest may require constant retune within D-88 bands (allowed) |
| A3 | 20 Hz sim / 10 Hz broadcast enough on mid-range Android | Architecture | May raise broadcast rate if marker stutters |
| A4 | Storing live Stick Pull state in `MatchSessionRegistry` LiveMatch fields (not new DB columns) is enough for reconnect snapshot | Architecture | May need JSON column if process restart mid-match matters (out of MVP — in-memory like Alchiki private) |

**If empty table were required for zero assumptions:** not applicable — A1–A4 remain confirmation items; product locks D-78…D-91 are not assumptions.

## Open Questions

### Open Questions (RESOLVED — yolo)

1. **Modulith package vs `games.stickpull`?**
   - **RESOLVED:** `com.nomadgames.games.stickpull` beside Alchiki; no new `@ApplicationModule`.
2. **Shared queue vs parallel FIFO service?**
   - **RESOLVED:** Shared `CasualQueueService` + per-game FIFO map + `game` on enqueue/status.
3. **Exact force / threshold / clock / bot curves?**
   - **RESOLVED:** Yolo table in Summary (0.012 force, ±0.85 threshold, 30s clock, bot TPS means).
4. **FEATURES 1.5s vs 2s burst?**
   - **RESOLVED:** Use **1.5s** (D-88).
5. **WS frame names?**
   - **RESOLVED:** `TapInput` / `TapResolved` / `StickState` / `Countdown`.
6. **Tap zone height / local seat?**
   - **RESOLVED:** 96dp; local pulls toward near/bottom (06-UI-SPEC discretion).

Remaining non-blocking: playtest micro-tuning of force/friction **within** D-88 bands only.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Node.js | gsd-tools | ✓ | v24.18.0 | — |
| Java 21 | Backend compile/IT | ✗ on researcher PATH | — | Use project CI / developer JDK 21; plans assume `./mvnw` or IDE JDK as in prior phases |
| Maven / mvnw | Backend tests | ✗ `mvnw` not in repo tree this scout | — | Prior phases used IDE/CI; planner tasks should use whatever the repo already documents for backend tests |
| Flutter / Dart | Client tests | ✗ on researcher PATH | pubspec sdk ^3.13.2 | Developer machine / CI Flutter 3.47 as Phase 1–5 |
| PostgreSQL (Testcontainers) | ITs | via Docker in prior ITs | — | Same as CasualQueueIT / ReconnectIT |
| Redis | — | N/A | — | Forbidden |
| Knowledge graph | Research enrichment | ✗ | — | Codebase grep only |

**Missing dependencies with no fallback:** none for planning — execution hosts that already ran Phases 1–5 remain the build environment.

**Missing dependencies with fallback:** local researcher PATH missing Java/Flutter — do not block plans; verification runs where prior phase ITs ran.

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | JUnit 5 + Spring Boot Test / Testcontainers (backend); `flutter_test` (client) |
| Config file | `backend/pom.xml` surefire; `client/pubspec.yaml` |
| Quick run command | `./mvnw -pl backend -Dtest=StickPullSimTest,CatalogIT test` (or IDE equiv) + `flutter test test/catalog_test.dart test/howto_stick_pull_test.dart` |
| Full suite command | Backend session/matchmaking/catalog/profile ITs touching Stick Pull + `flutter test` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| CAT-02 | `stick_pull` status PLAYABLE; tile CTAs | IT + widget | `CatalogIT` expect PLAYABLE; `catalog_test` Stick Pull Quick Match | ❌ Wave 0 (today COMING_SOON) |
| STICK-01 | Countdown then marker moves on taps | unit + IT | `StickPullSimTest`; `StickPullIT` WS | ❌ Wave 0 |
| STICK-02 | Mash reduces force / exhaust slip | unit | `StickPullSimTest` burst/exhaust | ❌ Wave 0 |
| STICK-03 | Ends at threshold or clock 0 in 15–40s | unit + IT | sim clock settle; IT | ❌ Wave 0 |
| STICK-04 | &gt;10/s extras no force; suspect log | unit | clamp + regularity tests | ❌ Wave 0 |
| STICK-05 | How-to 5 cards skip/seen | widget | `howto_stick_pull_test.dart` | ❌ Wave 0 |
| BOT-02 | EASY/NORMAL/HARD jitter envelopes | unit | `StickPullBotTest` | ❌ Wave 0 |
| SESS-04 | 8s grace then forfeit; no bot-fill | IT | `StickPullReconnectIT` | ❌ Wave 0 (Alchiki ReconnectIT is 30s) |

### Sampling Rate
- **Per task commit:** targeted unit/widget for touched seam
- **Per wave merge:** Stick Pull sim + CatalogIT + one reconnect IT
- **Phase gate:** Full Stick Pull IT set green before `/gsd-verify-work`

### Wave 0 Gaps
- [ ] `backend/.../games/stickpull/StickPullSimTest.java` — STICK-01…04 bands
- [ ] `backend/.../games/stickpull/StickPullBotTest.java` — BOT-02
- [ ] `backend/.../session/StickPullIT.java` — countdown/tap/settle WS
- [ ] `backend/.../session/StickPullReconnectIT.java` — 8s forfeit, no bot-fill
- [ ] `backend/.../matchmaking/CasualQueueIT` cases for `game=STICK_PULL` isolation
- [ ] `backend/.../catalog/CatalogIT` PLAYABLE assertion update
- [ ] `client/test/howto_stick_pull_test.dart` — STICK-05
- [ ] `client/test/catalog_test.dart` — promote Stick Pull CTAs
- [ ] Update `ReconnectIT` so Alchiki 30s still holds after `graceFor(game)` refactor

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | yes | Existing guest JWT on REST/WS ticket |
| V3 Session Management | yes | WS ticket + reconnect token rotate; seat binding |
| V4 Access Control | yes | `requireSeat`; cannot tap for other seat |
| V5 Input Validation | yes | JSON type allowlist; ignore client timestamps/force; clamp |
| V6 Cryptography | yes (existing) | SHA-256 reconnect token hash — do not reinvent |

### Known Threat Patterns for Stick Pull / parlor WS

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Autoclicker / scripted taps | Elevation / Spoofing | Server re-timestamp + 10/s clamp + stamina; suspect log only (STICK-04) |
| Client claims win / marker | Tampering | Server settle only |
| Tap for opponent seat | Spoofing | Seat check on TapInput |
| Steal reconnect token | Information | Hash at rest; rotate on rejoin; secure storage client |
| Cross-game queue grief | Denial | Per-game FIFO isolation |
| Bot-fill social attack | Tampering | Forbidden mid-tug (SESS-04) |

## Sources

### Primary (HIGH confidence)
- Codebase: `CatalogService`, `CasualQueueService`, `MatchService`, `ReconnectPolicy`, `MatchWebSocketHandler`, `ProfileService.recordSettlement`, economy `stick_pull` SKUs, `howto_seen_store.dart`, `catalog_page.dart`
- `.planning/research/FEATURES.md` — Stick Pull Stamina Spec v1
- `.planning/phases/06-stick-pull/06-CONTEXT.md` — D-78…D-91
- `.planning/phases/06-stick-pull/06-UI-SPEC.md` — approved UI contract
- [CITED: docs.flame-engine.org/latest/flame/game_widget.html] — GameWidget / overlays / hit testing
- [CITED: docs.spring.io/spring-framework/reference/web/websocket/server.html] — TextWebSocketHandler

### Secondary (MEDIUM confidence)
- [CITED: FEATURES biomechanics TPS ranges] — soft band 5–6.5 human sustainable
- WebSearch rate-limit sliding window practices — aligned with FEATURES buckets

### Tertiary (LOW confidence)
- Exact force 0.012 / threshold 0.85 feel — yolo until playtest (allowed under D-88)

## Metadata

**Confidence breakdown:**
- Standard stack: **HIGH** — reuse pinned Flutter/Flame/Spring; no new packages
- Architecture: **HIGH** — seams verified in code; game discriminator gaps clear
- Pitfalls: **HIGH** — hardcoded ALCHIKI + 30s grace are concrete failure modes
- Numeric feel constants: **MEDIUM** — yolo within locked bands

**Research date:** 2026-09-14
**Valid until:** 2026-10-14 (stable parlor stack; retune constants anytime within D-88)
