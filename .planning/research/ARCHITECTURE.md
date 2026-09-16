# Architecture Research

**Domain:** Mobile multiplayer traditional-games platform (Nomad Games)
**Researched:** 2026-09-05
**Confidence:** MEDIUM

Seam-classified confidence: official docs + community sources via `websearch --verified` = MEDIUM; raw `webfetch` = LOW. Claims below that rest on Colyseus, Nakama, Spring Modulith, Spring Boot, or Gaffer On Games official pages are treated as primary sources even when the seam tags the transport MEDIUM. Proposed reconnect numbers are derived from those official ranges, not from published Clash Royale / Brawl Stars forfeit timers (those titles do not publish a useful public number).

## Standard Architecture

A modular mobile multiplayer platform is **one client binary + one backend process**, not a fleet of game microservices. Shared platform services (identity, matchmaking, economy, profile) sit in the monolith. Each game is a **plugin behind a shared match session**. Authority lives on the server. Clients render and send inputs.

Do **not** adopt Colyseus or Nakama as the Nomad backend (Java/Spring is the intended stack). Adopt their room/match patterns: seat reservation, explicit rejoin, full snapshot on reconnect, server-mutated state, game-type-specific match loops.

### System Overview

```
CLIENT (Android + iOS, one codebase)
  platform/          auth, catalog, REST, WS, i18n, shop, profile
  games/alchiki/     aim, hold-to-throw, trajectory replay
  games/stick_pull/  countdown, tap stream, stamina bar
  games/<future>/    Coming Soon tile only
       |                              |
       | REST                         | WebSocket (match only)
       | identity, catalog, shop,     | inputs, snapshots,
       | profile, queue, room codes   | reconnect, settle
       v                              v
MODULAR MONOLITH (Spring Boot, one JAR, one container)
  identity     catalog     matchmaking     session
  guest/bind   game list   casual/ranked   MatchSession
  tokens       coming soon private codes   seats, WS, reconnect
                                              |
                                              v
                                       GameEngine plugin
                                         games.alchiki
                                         games.stickpull
                                              |
         +------------+------------+----------+----------+
         v            v            v                     v
      economy      profile      rating              analytics
      ledger       stats/LB     Glicko-2            EventSink
         |            |            |                     |
         v            v            v                     v
  PostgreSQL (truth)     in-process maps          analytics_events
  players, ledger,       queues, live sessions    + stdout JSON
  matches, rooms
```

Redis is **absent on day one**. See [When Redis is justified](#when-redis-is-justified).

### Component Responsibilities

| Component | Responsibility | Typical Implementation |
|-----------|----------------|------------------------|
| Client platform shell | Auth, catalog, navigation, REST, WS lifecycle, i18n, shop/profile screens | Shared app module; no game rules |
| `games/alchiki` (client) | Aim, hold-to-throw, replay server keyframes, local bot preview in prototype only | Isolated package; talks to session via `GameClient` |
| `games/stick_pull` (client) | Countdown UI, tap capture, render server marker/stamina | Isolated package; same `GameClient` |
| `identity` | Guest player, username/password bind, access/refresh, merge audit | Spring module; `Player` + `Credential[]` |
| `catalog` | Enabled games, Coming Soon slots, per-game metadata | Static config + DB flags |
| `matchmaking` | Casual queue, ranked queue, private room codes | In-process queues now; Redis ZSET later |
| `session` | Seats, WS auth, reconnect tokens, clock, mode policy, engine dispatch | One `MatchSession` per live match |
| `games.alchiki` (server) | Turn machine + burst physics + scoring | `GameEngine` plugin; dyn4j or jbox2d |
| `games.stickpull` (server) | 10–20 Hz tap/stamina tick + marker | `GameEngine` plugin; no physics world |
| `economy` | COINS/GEMS ledger, cosmetics grant, idempotent purchases | Postgres ledger; never client balances |
| `profile` | Per-game stats, season + all-time leaderboards | Postgres; cache later |
| `rating` | Ranked updates (Glicko-2 hypothesis) | Called only from session settle |
| `analytics` | Thin event sink | Insert + log; no product analytics platform |
| PostgreSQL | Durable truth: identity, economy, match outcomes, rooms | Flyway migrations |
| Docker Compose | DEV/TEST/PROD process topology | App + Postgres; Redis later; no K8s |

### Authority Decision (the key choice)

| Model | Use for Nomad? | Why |
|-------|----------------|-----|
| Deterministic lockstep | **No** | Gaffer On Games: lockstep needs hard float determinism and waits on the slowest peer. Android / iOS / a JVM physics port will not stay bit-identical. Cross-engine lockstep (Forge2D ↔ jbox2d) is a rewrite risk. |
| 60 Hz snapshot interpolation as authority | **No** | Snapshot interpolation (Gaffer) is a **client reconstruction** technique. Alchiki is turn-based throws, not twitch. A continuous 60 Hz server tick is wasted work and couples both games to the wrong loop. |
| Client-authoritative / hybrid “client sends rest poses” | **No** | Project constraint: result, scores, rating, currency are server-owned. Rest positions from the client are a cheat surface. |
| **Input → server simulates → clients replay** | **Yes — Alchiki** | Matches billiards-class turn games (GameDev SE). Client sends aim + power (hold duration), never “I scored 3”. Server steps physics to sleep, then sends a keyframe buffer. Clients interpolate between keyframes (snapshot interpolation as **playback**, not as authority). |
| **Input-rate tick** | **Yes — Stick Pull** | 15–40 s tap stream. Server ticks 10–20 Hz, clamps taps, owns stamina and marker. Clients render the last authoritative marker. |

**Hybrid-authoritative physics (optional later, not MVP):** the throwing client may start a local preview of the same impulse for zero release lag. The server result still wins. If the local preview diverges, morph or snap to the server keyframe track. Do **not** build this until the prototype proves the simpler replay path feels dead. Prediction also leaks a local solver that can be used as an aimbot — acceptable for Casual, avoid exposing a perfect clone in Ranked if it is easy to query.

**Alchiki is not 60 Hz netcode.** The match is a turn state machine. Physics runs in a **burst** (internal 60–120 Hz steps for 1–3 s of sim, typically <50 ms wall time on server), then sleeps.

```
WAITING_AIM  --input-->  SIMULATING (burst)  -->  SETTLE_SCORE  -->  NEXT_TURN | MATCH_OVER
```

**Stick Pull is a short real-time loop** hosted by the same `MatchSession`, different engine:

```
COUNTDOWN 3-2-1-GO  -->  TICKING (10–20 Hz)  -->  TIMEOUT or THRESHOLD  -->  SETTLE
```

## Recommended Project Structure

### Backend (Spring Modulith)

Spring Modulith treats each **direct sub-package** of the `@SpringBootApplication` class as a module. Public types live in the module root; everything under `internal/` is invisible to other modules. Verify with `ApplicationModules.verify()`. Nested modules (since Modulith 1.3) fit `games.*`.

```
backend/
├── pom.xml
├── src/main/java/com/nomadgames/
│   ├── NomadGamesApplication.java
│   ├── identity/                 # public API: PlayerId, AuthService, MergeService
│   │   └── internal/
│   ├── catalog/
│   │   └── internal/
│   ├── matchmaking/              # enqueue, tickets, room codes
│   │   └── internal/
│   ├── session/                  # MatchSession, WsHandler, ReconnectPolicy
│   │   ├── GameEngine.java       # plugin SPI
│   │   ├── MatchMode.java        # BOT, PRIVATE, CASUAL, RANKED
│   │   └── internal/
│   ├── economy/
│   │   └── internal/
│   ├── profile/
│   │   └── internal/
│   ├── rating/
│   │   └── internal/
│   ├── analytics/                # EventSink only
│   │   └── internal/
│   └── games/
│       ├── alchiki/              # nested module; implements GameEngine
│       │   └── internal/         # physics world, scoring
│       └── stickpull/
│           └── internal/         # tap window, stamina
├── src/main/resources/
│   ├── application.yml
│   ├── application-dev.yml
│   ├── application-test.yml
│   └── application-prod.yml
└── src/test/java/.../ModularityTest.java
```

### Client

Keep the same seam regardless of Flutter / Unity / Godot (stack is not frozen). Games must be addable without touching platform screens.

```
client/
├── platform/                 # auth, catalog, rest, ws, i18n, shop, profile
│   ├── session/              # reconnect token store, snapshot apply
│   └── net/
├── games/
│   ├── alchiki/              # only Alchiki UI + replay
│   ├── stick_pull/
│   └── coming_soon/
└── app/                      # bootstrap, routing
```

### Structure Rationale

- **`session` owns the wire and the seat.** Games never open their own sockets or invent room codes.
- **`games.*` depend on `session` + `identity` APIs only.** Alchiki must not import Stick Pull. A third game is a new nested module + catalog row.
- **`economy` / `rating` / `profile` subscribe to session events** (`MatchSettled`, `RewardGranted`). They do not call into game internals.
- **Package-by-feature, not package-by-layer.** Spring Modulith and the JetBrains Modulith guide both treat layer-first packages as the thing to leave behind.
- **Client mirrors the same cut.** Platform shell can ship a Coming Soon tile without a server engine.

## Architectural Patterns

### Pattern 1: Shared Match Session + GameEngine plugin

**What:** One `MatchSession` holds matchId, mode, seats, reconnect policy, and a `GameEngine`. Alchiki and Stick Pull are different engines, not different servers.

**When to use:** Always. This is the platform invariant.

**Trade-offs:** One session protocol to maintain. Engines must not assume a global tick. Slightly more abstract than “just write AlchikiRoom”. Worth it — Stick Pull is 15–40 s of a different loop, and a third game will come.

**Example:**

```java
public interface GameEngine {
    GameType type();
    void onStart(MatchContext ctx);
    void onInput(PlayerId from, ClientInput in, Instant serverNow);
    void onTick(Instant serverNow);          // no-op for Alchiki; 20 Hz for Stick Pull
    void onDisconnect(PlayerId id);
    void onReconnect(PlayerId id);
    Snapshot snapshotFor(PlayerId viewer);   // full state for join/rejoin
    Optional<Settlement> pollSettlement();
}

public final class MatchSession {
    private final MatchMode mode;
    private final ReconnectPolicy reconnect;
    private final GameEngine engine;
    private final Map<PlayerId, Seat> seats;
    // WS send: engine.snapshot or delta; REST never writes live state
}
```

Alchiki `onTick` is empty. Session still has a coarse 1 Hz housekeeping tick for reconnect expiry and empty-match dispose (Nakama-style `emptyTicks`).

### Pattern 2: Alchiki — input, simulate-to-rest, keyframe replay

**What:** On release, client sends `{ aimAngle, power01 | holdMs, optionalSpin }`. Server validates turn owner, clamps power, applies impulse, steps until all bodies sleep or a 3 s cap, scores pieces fully outside the circle, then broadcasts `{ seed, keyframes[], scores, nextTurn }`.

**When to use:** Turn-based physics with 5–15 bodies. Same family as pool / Jenga table games.

**Trade-offs:** One RTT before motion starts (~50–150 ms mobile). Playback is smooth and identical for both clients. No cross-platform determinism required. Bandwidth is a few KB per throw (10–20 Hz keyframes × ~2 s × ~8 bodies × pos+rot), not a 60 Hz stream.

Keyframe interpolation on the client **is** Gaffer’s snapshot interpolation, applied to a closed buffer, not to a live unreliable UDP stream. TCP/WebSocket is acceptable: the buffer is reliable and short.

```java
// AlchikiEngine.onInput
if (!turn.belongsTo(from)) throw new IllegalMove();
ThrowInput t = ThrowInput.clamp(in);
List<Keyframe> frames = physics.simulateToRest(t); // internal 1/120 s steps
Scores scores = scorer.apply(world, circle);
state.advanceTurn(scores);
session.broadcast(new ThrowResolved(frames, scores, state.publicView()));
```

### Pattern 3: Stick Pull — clamped input-rate tick

**What:** Client sends tap counts per 50 ms window (or raw taps if easier), not “marker = 0.9”. Server: clamp taps/window to a human max, drain/recover stamina, integrate marker, broadcast `{ marker, stamina[], remainingMs }` at 10–20 Hz.

**When to use:** Short real-time contests where the cheat is autoclicker, not physics forgery.

**Trade-offs:** Needs a real tick. Do not reuse Alchiki’s burst simulator. Disconnect of 10 s is most of the match — grace must be short.

### Pattern 4: Seat reservation + snapshot on rejoin

**What:** On unexpected drop, do **not** remove the seat. Hold it for a mode-specific grace. Client stores a `reconnectionToken` (Colyseus) and calls rejoin (Nakama `MatchJoinAttempt`). Success → **full snapshot**, not a delta. Consented leave forfeits immediately.

**When to use:** Every live match.

**Trade-offs:** Ranked seats stay occupied, so no backfill. Casual Alchiki may bot-fill after grace. Token must be bound to `playerId`, not to a transport `sessionId`.

### Pattern 5: Guest is a real Player, bind is a link

**What:** First launch creates `Player` + `device` credential (client-generated UUID stored in secure storage, not a raw advertising ID). “Register” **links** username/password to the same `playerId` (Nakama device-first + link; Firebase `linkWithCredential`). Linking a username that already exists returns **409**. No silent wallet merge.

**When to use:** From the identity schema of phase 2, even if the bind UI ships later.

**Trade-offs:** Device IDs rotate (Nakama docs). Persist our own UUID. Ranked and gem sinks require a bound account so a wiped guest cannot launder rating/currency.

### Pattern 6: Thin EventSink

**What:** `EventSink.emit(type, playerId, matchId, attrs)` writes one Postgres row and a JSON line. Types: `APP_STARTED`, `REGISTERED`, `LOGIN`, `MATCHMAKING_*`, `MATCH_*`, `ITEM_PURCHASED`. No Segment, Amplitude, Kafka, or warehouse in MVP.

**When to use:** At every module boundary from the moment identity exists.

**Trade-offs:** You cannot do funnels well until you export. You also cannot stall the roadmap on an analytics platform.

## Data Flow

### Request Flow (REST — out of match)

```
Client action (login, enqueue, buy, profile)
    ↓
API controller (auth filter, rate limit, validate)
    ↓
Module service (identity | matchmaking | economy | profile)
    ↓
PostgreSQL  +  EventSink
    ↓
DTO response
```

Live match state is **not** in REST after the session is created. REST may create a room or ticket and return `matchId` + WS ticket.

### Match Flow (WebSocket)

```
Client input
    ↓
WS (JWT / ticket, playerId)
    ↓
MatchSession (seat alive? grace? turn/tick legal?)
    ↓
GameEngine.onInput / onTick
    ↓
Alchiki: physics burst → scores
Stick Pull: clamp taps → stamina → marker
    ↓
Broadcast snapshot/delta to seats
    ↓
pollSettlement() → rating + economy + profile  (once, idempotent)
    ↓
EventSink MATCH_COMPLETED
```

### Key Data Flows

1. **Guest play:** device UUID → `identity` creates `Player` → access/refresh → catalog → `matchmaking` (BOT or PRIVATE or CASUAL) → `session` + engine. Ranked rejected until bound.
2. **Alchiki throw:** aim/hold on client (local only) → `ThrowInput` → server physics → keyframes + scores → both clients replay → if last throw, `Settlement`.
3. **Stick Pull stream:** tap windows → server clamp + stamina → marker snapshots 10–20 Hz → settle on threshold or timeout.
4. **Reconnect:** drop → seat reserved, opponent sees `disconnected` → client presents token within grace → `onReconnect` + full snapshot → play continues. Grace miss → Casual Alchiki bot-fill **or** forfeit; Ranked always forfeit; Stick Pull always forfeit (match too short to bot-fill fairly).
5. **Guest → account:** bound credential inserted on same `playerId`. Conflict (username taken) → 409, stay on guest or sign in to the existing account. Existing-account path does **not** add guest coins to the rich account.
6. **Economy:** only `economy` writes balances. Session publishes `RewardDue`. Ledger row + idempotency key (`matchId:reason`). Client display is a projection.
7. **Private room:** creator gets a 4–6 char code stored in Postgres with TTL (e.g. 15 min unused). Joiner REST `join(code)` → same `MatchSession` as matchmaking. No Redis required for codes.

### Reconnect Timeouts (proposed)

Colyseus official guidance: ~30 s for fast-paced rooms, ~5 min for turn-based, or reject after N missed turns. Stick Pull is closer to fast-paced and the whole match is 15–40 s, so a 30–300 s seat would outlive the match. Alchiki sessions are 2–5 min and turn-based, so wall-clock can be longer, but a 5 min wait is hostile on mobile.

| Mode | Game | Grace | On expiry | Notes |
|------|------|-------|-----------|-------|
| Casual | Alchiki | **60 s** | Bot-fill remaining turns | Also reject if **2 of the disconnected player’s turns** are missed (Colyseus “missed rounds” pattern). Whichever comes first. |
| Ranked | Alchiki | **90 s** | Ranked forfeit (no bot) | Rating applied as loss for the disconnected player. Tie-break rules do not apply. |
| Casual | Stick Pull | **8 s** | Opponent wins | Includes countdown. Do not bot-fill a tug. |
| Ranked | Stick Pull | **12 s** | Ranked forfeit | Slightly more than casual; still ≪ match length. |
| Any | Consented leave | **0 s** | Immediate forfeit / abort | `leave()` is not a reconnect. |
| BOT / Private lobby (not started) | Any | **120 s** empty lobby | Dispose room | Unused codes expire in Postgres. |

Client: persist reconnect token across app backgrounding. Automatic WS retry with backoff while the process lives; manual rejoin after process death (Colyseus 0.17+ pattern).

**Confidence:** MEDIUM — official ranges exist; exact seconds are a product choice to tune in UAT.

### Anti-cheat: what the server must own

| Asset | Server owns | Client may send | Reject |
|-------|-------------|-----------------|--------|
| Alchiki score / winner | Yes | Throw **inputs** | Rest poses, “pocketed N”, client timestamps as truth |
| Stick Pull marker / winner | Yes | Tap counts per window | Marker position, “I won”, uncapped tap floods |
| Tap rate / stamina | Yes | Taps | Inter-tap times as authoritative; use server clock. Clamp e.g. ≤ 12 taps / 100 ms (tune on device). Flag near-zero variance over ≥ 40 taps as **signal**, not instant ban (Roblox action-cadence heuristic). |
| Rating | Yes | Nothing | Client-sent MMR |
| COINS / GEMS / inventory | Yes | Purchase SKU + idempotency key | Client balances, “grant 500” |
| Turn / GO clock | Yes | Intent | Starting a throw off-turn, taps before GO |
| Reconnect eligibility | Yes | Token | Rejoin after grace, token reuse after consume+rotate |

Rate-limit REST and WS per `playerId` and IP. Hash passwords. Rotate refresh tokens. Validate every WS frame against the seat.

### When Redis is justified

| Use | Day-one MVP (1 JVM) | After second replica |
|-----|---------------------|----------------------|
| Matchmaking queue | In-process `ConcurrentSkipListMap` / lists | Redis ZSET + Lua/WATCH claim ([Redis matchmaking tutorial](https://redis.io/tutorials/matchmaking-and-game-session-state-with-redis/)) |
| Private room codes | Postgres unique + `expires_at` | Still Postgres (durable, low QPS) |
| Live match state | JVM heap on the session owner | Still heap; do not put physics in Redis |
| Reconnect token | Memory + optional Postgres row | Redis TTL **or** Postgres; need a routing hint if 2 nodes |
| Rate limits | In-process Bucket4j | Redis-backed Bucket4j |
| Economy / inventory | **Never Redis as truth** | Never |
| Leaderboard | Postgres `ORDER BY` | Redis ZSET cache of top N |

**Do not add Redis “because games use Redis.”** One developer, Docker, no K8s: Postgres + one app container is the whole topology until a second app instance is real.

Matchmaking product rules (same component, two queues):

- **Casual:** 2-player, ignore rating or very wide band; expand after ~8–10 s; allow guest.
- **Ranked:** bound account only; Glicko-2 rating window expands over ~15–30 s; no bot opponent.
- **Private:** short code, creator picks game + casual rules (ranked-by-code is a later choice; default **off** so friends cannot farm rating).
- **Accept timeout:** 15–20 s to confirm a found match; decliner returns to queue with wait-time preserved.

### Guest → account merge

Follow Nakama/Firebase **link**, not “create second user and merge rows ad hoc.”

1. Happy path: `POST /identity/bind { username, password }` on a guest session → unique username → add password credential → same `playerId`. Guest matches, cosmetics, coins stay.
2. Conflict: username exists → **409**. Client offers Sign in. After sign-in, guest `playerId` remains orphaned. **Do not** add guest coins/gems/rating onto the existing account (double-spend / smurf merge). Optional: if the target account has **zero matches and zero spend**, allow a one-time import (still a single transaction + audit). Otherwise discard guest progress.
3. Never implement `max(guest.coins, account.coins)` or sum. That is an economy exploit.
4. Merge/bind is idempotent and audited (`identity_audit`).
5. Ranked and gem sinks require `credentials` other than `device`.

### Environments (DEV / TEST / PROD, Docker, no K8s)

Spring profiles + Compose. Spring Boot 3.4 documents Docker Compose at development time (`spring-boot-docker-compose`) and Testcontainers; Compose support is disabled in tests unless you opt in. Use that for DEV. TEST uses Testcontainers Postgres or a `docker-compose.test.yml` with a disposable volume. PROD is `docker compose -f docker-compose.prod.yml up` on one VM: `app` + `postgres`. No Kubernetes, no service mesh, no ingress controller.

```
# DEV:  Postgres in Docker, app on host (hot reload)
# TEST: ephemeral Postgres, Flyway migrate, JUnit + a few WS fixtures
# PROD: app image + Postgres volume, SPRING_PROFILES_ACTIVE=prod
```

One Flyway history for all envs. Structured logs (JSON in prod). Prometheus/Grafana/OTel stay out of MVP (project constraint). Health: `/actuator/health`.

WebSocket: raw Spring WebSocket (or a small Netty handler), **not STOMP/SockJS**. STOMP is a chat/app protocol; it fights a game tick and binary snapshots.

## Suggested Build Order

Dependencies run **down** this list. Do not invert.

| # | Slice | Why this position | Unlocks |
|---|-------|-------------------|---------|
| **1** | **Alchiki Physics Prototype** (client feel + a JVM or headless sim that can emit keyframes) | Project gate. If FPS, sleep, rotation, hold-to-throw, or “server can step this” fail, **stop and change stack** before accounts. | Engine pick, 2D vs 2.5D, “replay vs live stream” |
| **2** | Modular monolith skeleton + `identity` (guest) + `catalog` + `EventSink` | Matches need a `playerId`. Bind UI can wait; schema cannot. | Everything authenticated |
| **3** | `session` + WS + reconnect + empty `GameEngine` | Shared match must exist before either real game is multiplayer. | Rooms, bots, later Stick Pull |
| **4** | `games.alchiki` on session + BOT (EASY/NORMAL/HARD deterministic) | Core value: first honest short match vs bot. | Private, casual, ranked content |
| **5** | Private rooms (short codes) | Lowest-risk PvP; no matchmaking. | Friend QA of physics sync |
| **6** | `economy` + cosmetics shop (soft currency only) | Ledger + idempotency before ranked rewards. IAP columns reserved, unused. | Rewards, shop |
| **7** | `profile` + per-game stats + leaderboards | Reads settlements; do not build before settle exists. | Meta progression |
| **8** | Casual matchmaking + Ranked + `rating` | Needs bind, settle, anti-cheat path proven in private. Guests blocked from Ranked. | Competitive loop |
| **9** | `games.stickpull` engine + client module | Second loop on the **same** session. Proves the plugin boundary. | Catalog completeness |
| **10** | Guest bind UI + 409 conflict handling | Data model from #2; UX now that there is something to keep. | Cross-device, ranked eligibility |
| **11** | CI + PROD compose harden, rate limits, reconnect UAT | Not a platform rewrite. | Ship |

**Phase-1 prototype must prove:** stable FPS on mid Android, collisions + rotation + friction readable, hold-to-throw, bodies sleep, **and** a non-client scorer path (even a desktop/JVM harness) that consumes the same `ThrowInput` and emits keyframes. If the client stack cannot feed a server sim, change stack **here**.

## Scaling Considerations

| Scale | Architecture Adjustments |
|-------|--------------------------|
| 0–1k users (MVP, 1 developer) | One Spring JAR, one Postgres, in-memory sessions and queues. This is the target. |
| 1k–100k users | Add Redis for queues + rate limits. Sticky WS or a session-routing table. Postgres connection pool. Still one deployable. |
| 100k+ users | Split only if a module’s load profile demands it (usually session/tick). Extract `session` + engines first. Still not a default. |

### Scaling Priorities

1. **First bottleneck:** live `MatchSession` heap + WS fan-out on one JVM. Fix: cap concurrent matches, then a second session-bearing instance + routing. Not K8s.
2. **Second bottleneck:** ranked matchmaking scans if wrongly done in SQL `FOR UPDATE`. Fix: Redis ZSET when (and only when) there is a second instance or measured queue latency.

Alchiki burst physics is cheap (handful of bodies, rare). Stick Pull ticks are cheap. Do not pre-emptively shard games.

## Anti-Patterns

### Anti-Pattern 1: Lockstep because “two players is lockstep”

**What people do:** Exchange inputs and run Forge2D/Box2D on both phones.
**Why it's wrong:** Float determinism across mobile SOCs and a JVM port fails. Desync looks like cheating. Gaffer limits lockstep to small deterministic sims.
**Do this instead:** Server simulates; clients replay keyframes.

### Anti-Pattern 2: One 20 Hz tick for every game

**What people do:** Force Alchiki through the Stick Pull loop (or vice versa).
**Why it's wrong:** Alchiki spends minutes waiting on a turn; Stick Pull is 20 seconds of taps. A shared tick either wastes CPU or starves the tug.
**Do this instead:** Shared **session**, different **engine** clocks.

### Anti-Pattern 3: Client sends scores or rest state

**What people do:** “Hybrid” where the thrower uploads final transforms.
**Why it's wrong:** Ranked and economy become a JSON forge.
**Do this instead:** Inputs only. Hybrid preview is local and disposable.

### Anti-Pattern 4: Microservices or K8s for two game modules

**What people do:** `alchiki-svc`, `stick-svc`, `mm-svc`.
**Why it's wrong:** One developer, two loops, shared settlement. Distributed transactions for coins/rating will dominate the work.
**Do this instead:** Spring Modulith. Split only after a measured bottleneck.

### Anti-Pattern 5: Redis as source of truth

**What people do:** Match + wallet in Redis because it is fast.
**Why it's wrong:** Restart or flush deletes economy and ranked integrity. Community production stacks keep Redis for hot/ephemeral data only.
**Do this instead:** Postgres for truth; Redis later for queues/limits.

### Anti-Pattern 6: New `playerId` on register

**What people do:** Guest row + new registered row, then a weekend “merge script.”
**Why it's wrong:** Nakama/Firebase already document that two existing accounts do not link; 409 / `linkWithCredential` failure is the real world. Ad-hoc merges corrupt ledgers.
**Do this instead:** Link credentials to the guest `playerId`. Conflict = sign in to the other account, no wallet sum.

### Anti-Pattern 7: Analytics platform in MVP

**What people do:** Segment + warehouse + replay.
**Why it's wrong:** Slows identity and match work; project already listed a thin sink.
**Do this instead:** `EventSink` table + logs.

### Anti-Pattern 8: STOMP/SockJS as the game protocol

**What people do:** Spring “WebSocket” tutorial default.
**Why it's wrong:** Broker destinations and text frames fight binary snapshots and reconnect tokens.
**Do this instead:** One match WS, explicit message types, JWT on connect.

### Anti-Pattern 9: Building shop/ranked before the physics gate

**What people do:** Full platform, then “drop in Alchiki.”
**Why it's wrong:** The product’s core value and the technical risk are the throw. A beautiful ledger on a dead feel is a rewrite.
**Do this instead:** Prototype → session → Alchiki bot → then meta.

## Integration Points

### External Services

| Service | Integration Pattern | Notes |
|---------|---------------------|-------|
| PostgreSQL | JDBC / Flyway | Only required data store for MVP |
| Redis | Optional later | Queues, rate limits — not economy |
| Google Play Billing / Apple IAP | Out of MVP | Reserve `purchase` table + idempotency now |
| Push / email / OAuth | Out of MVP | Identity is guest + username/password |
| Analytics SaaS | Out of MVP | EventSink only |
| Play Integrity / App Attest | Optional later | Extra signal, not a substitute for server authority |

### Internal Boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| Client platform ↔ game module | In-process API (`GameClient`) | Game must not call REST for settle |
| Client ↔ identity/catalog/economy/profile | REST + JWT | Stateless |
| Client ↔ session | WebSocket + reconnect token | Stateful for match lifetime |
| `matchmaking` → `session` | In-process call | Creates session + engine by `GameType` |
| `session` → `games.*` | `GameEngine` SPI | No reverse dependency |
| `session` → `economy` / `rating` / `profile` | Application event `MatchSettled` | Once; idempotent consumers |
| `*` → `analytics` | `EventSink` | Fire-and-forget, must not fail the match |
| `identity` → others | `PlayerId` only | No leaking password hashes |

Allowed Modulith dependencies (acyclic):

```
games.alchiki, games.stickpull → session, identity
matchmaking → session, identity, catalog
session → identity, catalog, games.* (SPI), analytics
economy, profile, rating → identity, analytics
economy/profile/rating ← session events
catalog → (none)
```

## Sources

- [Colyseus State Synchronization](https://docs.colyseus.io/state) — server-mutated schema, clients send messages, delta patches. (official)
- [Colyseus Reconnection](https://docs.colyseus.io/room/reconnection) — `allowReconnection`, token, full snapshot on rejoin; ~30 s fast-paced / ~5 min turn-based; missed-round reject. (official)
- [Nakama Authoritative Multiplayer](https://heroiclabs.com/docs/nakama/concepts/multiplayer/authoritative/) — isolated match state, tick from `MatchInit`, seat reserve on disconnect, explicit rejoin. (official)
- [Nakama Authentication](https://heroiclabs.com/docs/nakama/concepts/authentication/) — one account, many linked ids; link conflict 409; device-first then link. (official)
- [Firebase Auth account linking (Android)](https://firebase.google.com/docs/auth/android/account-linking) — `linkWithCredential`; existing credential requires a manual merge policy. (official)
- [PlayFab LoginWithCustomID](https://learn.microsoft.com/en-us/rest/api/playfab/client/authentication/login-with-custom-id?view=playfab-rest) — anonymous/custom id creates or resumes a player. (official)
- [Gaffer On Games — Snapshot Interpolation](https://gafferongames.com/post/snapshot_interpolation/) — lockstep vs snapshots; floats; interpolation buffer as playback. (canonical)
- [GameDev SE — server-authoritative turn-based physics](https://gamedev.stackexchange.com/questions/217115/how-to-design-with-low-latency-in-focus-a-turn-based-multiplayer-game-without-cl) — aim local, strike to server, simulate-to-rest + keyframes. (2026)
- [nape-js multiplayer guide](https://github.com/NewKrok/nape-js/blob/master/docs/guides/multiplayer-guide.md) — always run physics on the server; lockstep not recommended. (community)
- [Spring Modulith Fundamentals](https://docs.spring.io/spring-modulith/reference/fundamentals.html) — package = module, `internal/` hidden, nested modules. (official)
- [JetBrains — Modular monolith with Spring Modulith](https://blog.jetbrains.com/idea/2026/02/migrating-to-modular-monolith-using-spring-modulith-and-intellij-idea/) — package-by-feature, verify boundaries. (2026-02)
- [Redis — Matchmaking and game session state](https://redis.io/tutorials/matchmaking-and-game-session-state-with-redis/) — ZSET queues, atomic claim. (official)
- [Spring Boot 3.4 Development-time Services](https://docs.spring.io/spring-boot/3.4/reference/features/dev-services.html) — Docker Compose + Testcontainers; Compose skipped in tests by default. (official)
- [jbox2d](https://jbox2d.org/) / [dyn4j 5.0.2](https://github.com/dyn4j/dyn4j/) — JVM 2D physics options for the Alchiki server burst. (official)
- [Roblox server-side detection](https://github.com/Roblox/creator-docs/blob/main/content/en-us/scripting/security/server-side-detection.md) — action-cadence as a suspicion signal. (vendor docs)

---
*Architecture research for: Nomad Games — modular mobile multiplayer traditional-games platform*
*Researched: 2026-09-05*
