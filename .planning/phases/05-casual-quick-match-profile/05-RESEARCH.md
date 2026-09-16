# Phase 5: Casual Quick Match + Profile - Research

**Researched:** 2026-09-11
**Domain:** In-process casual 1v1 matchmaking + empty-queue fallback; soft casual MMR / XP / avatar profile; extend human PvP (CASUAL) rematch + reconnect
**Confidence:** HIGH for seams (Mode CASUAL reuse of PRIVATE table/WS/rematch/reconnect; REST queue; profile tables). MEDIUM for Elo K/XP curve numbers (Claude discretion → tagged).

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-62:** After joining Casual Quick Match, run a **short search (~5–10 s)**. If no human pair: show a **choice screen** — never a long fail spinner. Exact seconds in that band is Claude’s discretion.
- **D-63:** Fallback actions are **two equal buttons** side by side: **Play vs bot** and **Invite friend** — no primary/secondary hierarchy.
- **D-64:** **Invite friend** = **Create private room** (same as catalog Create Room: code + system share). Player **leaves the casual queue** when creating the room. Do not invent a “share into the same MM pool” deep link in this phase.
- **D-65:** During search, **Cancel** is always available → catalog and **dequeue immediately**. Fallback screen also has **Back to catalog** (leave without bot/invite).
- **D-66:** **Quick Match** is the **primary CTA on the Alchiki tile**. Bot play and private create/join stay **secondary** (existing Private band + bot path). Do not replace the whole catalog with a single global QM bar.
- **D-67:** Search UI is **full-screen “Searching…”** (spinner/pulse) + **Cancel** — minimal copy, **no countdown timer** to fallback.
- **D-68:** Pairing is **first-available** in the casual queue for MVP. No latency/region or win-rate band matching yet (FEATURES can inform a later upgrade).
- **D-69:** Casual Quick Match PvP tables are always **NORMAL** (same as private D-31). Catalog difficulty chips remain **bot-only**.
- **D-70:** After casual Quick Match **PvP**, rematch CTA is **one-tap “Play again”** (bot-style label/feel), not the private “Again?” dual-prompt chrome.
- **D-71:** Semantics stay **same-opponent dual-accept**: Play again means “I want another with this player”; the new match starts only when **both** have accepted.
- **D-72:** Accept window is **10 s** (aligned with private rematch / FEATURES casual online). If the other player does not accept → both return to **catalog**.
- **D-73:** After tapping Play again, leave the ResultOverlay for a **short dedicated waiting screen** (not status text on the result overlay). Waiting screen must allow cancel → catalog.
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

### Deferred Ideas (OUT OF SCOPE)
- Latency/region and win-rate band matchmaking (FEATURES) — post-MVP when queue is populated
- Ranked / Glicko-2 / soft season reset — Phase 7
- Stick Pull playable + real Stick Pull stats — Phase 6
- Avatar SKUs in Shop; photo upload — out of v1
- Redis-backed queues as scale path — REQUIREMENTS out-of-scope note

None from discussion left the phase boundary without being deferred above.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| MODE-03 | Casual Quick Match → human pair or bot/invite fallback; never 60s fail spinner | In-process FIFO queue + REST enqueue/poll/dequeue; client 8s → fallback UI (05-UI-SPEC); Invite = existing `RoomService.create` (D-64); bot = existing `POST /v1/matches` BOT |
| PROF-01 | Profile: Guest, avatar, level/XP, W/L, win rate, soft rating + best, selected cosmetics | Flyway profile columns + `GET /v1/profile`; cosmetics from `economy.getLoadout`; XP any settle; soft Elo only on CASUAL PvP |
| PROF-02 | Per-game stats Alchiki + Stick Pull | `player_game_stats` rows; Stick Pull always present with zeros / `noMatchesYet` (D-77) |
| PROF-03 | Avatar from small preset set (no photo) | 8 presets `avatar_01`…`avatar_08`; `PUT /v1/profile/avatar`; change only on `/profile` (D-76) |
| MODE-05 (preserve) | Rematch after casual | Extend rematch window to `CASUAL`; UI Play again + dedicated wait route (D-70…D-73); reuse `RematchWindow` dual-accept 10s |
| SESS-02 (preserve) | 30s casual reconnect for QM | `createCasualMatch` mints reconnect tokens + `registerPrivate`; generalize `PRIVATE`-only guards to human two-seat (`PRIVATE` \|\| `CASUAL`) |
</phase_requirements>

## Summary

Phase 5 adds the **table-stakes Play button** and **parlor identity** on top of an already-working private PvP + economy stack. Backend today has `matchmaking` (rooms only), `session` (BOT + PRIVATE + rematch + 30s reconnect), and `economy` (wallets/loadout) — **no casual queue, no `CASUAL` mode, no profile/XP/avatar tables**. Client catalog has Shop + wallet but **no Quick Match CTA, no `/matchmaking` / `/profile` routes**; `match_page` treats only `mode == 'private'` as human PvP and wires rematch as private Again? chrome.

The planner should treat this as: (1) **thin CASUAL mode** that reuses PRIVATE seat/WS/reconnect/rematch plumbing with mode-tagged rows; (2) **in-process FIFO queue** in `matchmaking` with REST poll; (3) **sync profile settle** beside economy grants; (4) **Flutter routes + ResultOverlay fork** per approved 05-UI-SPEC. Do **not** add Redis, Ranked, bind, Stick Pull playable, or band MM.

**Primary recommendation:** Implement `mode=CASUAL` via `MatchService.createCasualMatch` (clone of `createPrivateMatch` with `"CASUAL"`), `CasualQueueService` FIFO in-process pairing, REST `/v1/matchmaking/casual`, generalize human-seat guards, extend rematch to CASUAL with client Play-again → `/match/rematch-wait`, and Modulith `profile` package with Flyway stats/XP/avatar + Elo soft MMR.

### Claude discretion locks (yolo — planner MUST use these)

| Topic | Decision |
|-------|----------|
| Search timeout | **8 s** (mid D-62; locked in 05-UI-SPEC) |
| Queue storage | **In-process** `ConcurrentLinkedQueue` + `ConcurrentHashMap` — **not** Postgres queue SoT, **not** Redis |
| Pairing | First-available on enqueue; **no** found-match accept dialog (D-68) |
| Fallback while still queued | Keep ticket **SEARCHING** and **continue poll** on fallback screen; dequeue only on Cancel / Back / Invite / Play vs bot |
| Bot fallback difficulty | **Last catalog chip** (existing bot path) |
| Avatar count / default | **8** presets; default **`avatar_01`** |
| Soft MMR | Classic Elo, **start 1000**, **K=24**, update **CASUAL PvP only**; floor **100** |
| XP | **+12 win / +6 draw / +4 loss** any finished match; level = floor of cumulative XP thresholds `100 * n*(n+1)/2` (level 1 at 0 XP) |
| Rematch plumbing | **Reuse** private `RematchWindow` + `/rematch` REST; `createCasualMatch` when finished mode is CASUAL |
| Routes | `/matchmaking`, `/matchmaking/fallback`, `/match/rematch-wait`, `/profile` as **full-screen wood go_router routes** (not sheets) |

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Casual enqueue / dequeue / pair | API / Backend (`matchmaking`) | Browser (poll + 8s UI) | Server owns queue membership; client owns empty-queue UX clock (D-62) |
| Create CASUAL match + seats | API / Backend (`session`) | matchmaking calls create | Same authority as PRIVATE |
| In-play throws / settle | API / Backend (`session` + WS) | Browser / Flame | Raw WS; SESS-01 |
| Reconnect 30s | API / Backend (`session`) | Browser (token storage) | SESS-02; mode must be casual-tagged |
| Casual rematch dual-accept | API / Backend (`RematchWindow`) | Browser (Play again + wait page) | D-70…D-73 product chrome ≠ private Again? |
| Empty-queue Invite | API / Backend (`RoomService.create`) | Browser | D-64 reuse private room |
| Empty-queue bot | API / Backend (`createMatch` BOT) | Browser | Existing bot REST |
| Soft MMR / XP / W/L write | API / Backend (`profile`) | Session settle hook | Server-authored (D-75); sync in settle TX |
| Profile / avatar read-write | API / Backend | Browser `/profile` | PROF-01…03 |
| Cosmetics on profile | API / Backend (`economy` loadout) | Browser read-only | D-55 / D-75 — no equip on profile |
| Avatar art assets | CDN / Static (Flutter assets) | Browser | Original parlor presets only |

## Project Constraints (from .cursor/rules/ / PROJECT)

No `.cursor/rules/` in repo root; actionable locks from PROJECT / STACK / prior RESEARCH:

- **Authority:** Server authors scores, outcomes, currency, **rating, XP, avatar persistence**; client never POSTs MMR/XP/score.
- **No Redis day one:** In-process queues only until second app instance.
- **Physics lock:** Flutter 3.47 + Flame 1.38 + forge2d **0.14.2** / flame_forge2d **0.19.3+7** — do not bump.
- **Backend lock:** Java 21 + Spring Boot **4.1.1** + Modulith **2.1.1** + PostgreSQL; REST for lobby/queue/profile; raw WS in-play only.
- **Guest-first:** QM + profile open to guests (no bind).
- **i18n:** Every new string is ARB EN+RU (05-UI-SPEC copy table).
- **PRES-02:** Felt/wood/gold palette; no licensed IP; avatar presets original.
- **Inventory/equip stays in Shop** (D-55).
- **No nested `.git` under nomad-game.**

No project skills under `.cursor/skills/` or `.agents/skills/`. Knowledge graph: **absent**.

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Flutter SDK | **3.47.x** / Dart **3.13.x** | Catalog QM + Searching/Fallback/Profile/Rematch-wait | Phase 1–4 lock [VERIFIED: prior 04-RESEARCH + pubspec] |
| Flame / forge2d / flame_forge2d | **1.38.2** / **0.14.2** / **0.19.3+7** | Casual table presentation | Do not reopen [VERIFIED: client/pubspec.yaml] |
| go_router | **18.0.1** | `/matchmaking`, `/profile`, rematch-wait | Already pinned; Flutter recommends go_router over named routes [CITED: docs.flutter.dev/ui/navigation] |
| Spring Boot | **4.1.1** | REST + scheduling | Project lock [VERIFIED: backend/pom.xml] |
| Spring Modulith | **2.1.1** | `matchmaking` / `session` / new `profile` modules | Sync settle call pattern like economy [CITED: docs.spring.io/spring-modulith/reference/events.html] |
| PostgreSQL | **18.x** (Testcontainers) | Profile/stats durability; match rows | No Redis queues [VERIFIED: prior ITs] |
| Flyway | BOM | `V9__profile_casual.sql` (next after V8) | Existing V1–V8 [VERIFIED: migration dir] |
| JdbcClient / JPA | Boot BOM | Profile stats writes; MatchEntity mode CASUAL | Follow economy JdbcClient for stats; JPA MatchEntity for seats |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `dio` / `flutter_riverpod` | existing | REST queue + profile | Extend `NomadApi` |
| `flutter_secure_storage` | existing | Reconnect token for casual | Same as private |
| `share_plus` | existing | Invite friend → private share | Unchanged |
| JUnit + Testcontainers | Boot BOM | `CasualQueueIT`, `ProfileIT`, rematch CASUAL | Follow `RematchIT` / `RoomIT` |
| `flutter_test` | SDK | catalog QM, matchmaking, profile, rematch-wait widget tests | Follow `catalog_test` / `rematch_*` |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| In-process FIFO queue | Postgres `FOR UPDATE SKIP LOCKED` tickets | Overkill for 1 JVM; loses zero-latency pair-on-enqueue. **Reject for MVP** — keep Postgres for outcomes only [CITED: ARCHITECTURE.md Redis-later table] |
| In-process FIFO | Redis ZSET | Forbidden day one (REQUIREMENTS). Scale path only |
| New `CASUAL` mode row | Reuse `PRIVATE` mode bit | **Reject.** SESS-02 + analytics + rematch UX need distinct mode; reconnect grace already “casual Alchiki” |
| Async `@ApplicationModuleListener` for XP | Sync `ProfileService.recordSettlement` | Prefer **sync** so profile is consistent before response (same as economy D-45) [CITED: Modulith events — sync default] |
| Found-match accept 15–20s (ARCHITECTURE) | Immediate start | **Reject for QM.** D-68 first-available; accept window is rematch-only (D-72) |
| Soft MMR from private + bot | CASUAL PvP only | Private friend farming / bot farming would inflate parlor rating [ASSUMED product risk] |
| New Flutter packages | — | **None required** |

**Installation:**

```bash
# No new Maven or Flutter packages for Phase 5 MVP.
# Verify pins after scripts/dev-env.ps1:
# flutter --version ; .\mvnw.cmd -pl backend -am -q -DskipTests dependency:tree
```

**Version verification (this session):**
- flame **1.38.2**, forge2d **0.14.2**, flame_forge2d **0.19.3+7**, go_router **18.0.1** [VERIFIED: client/pubspec.yaml]
- Spring Boot parent + Modulith **2.1.1** [VERIFIED: backend/pom.xml]
- Modules present: `alchiki`, `catalog`, `economy`, `games`, `identity`, `matchmaking`, `session` — **no `profile` yet** [VERIFIED: package listing]

## Package Legitimacy Audit

> Phase installs **no new external packages**. Existing deps already approved in prior phases.

| Package | Registry | Age | Downloads | Source Repo | Verdict | Disposition |
|---------|----------|-----|-----------|-------------|---------|-------------|
| *(none new)* | — | — | — | — | N/A | No install |

**Packages removed due to [SLOP] verdict:** none  
**Packages flagged as suspicious [SUS]:** none

## Architecture Patterns

### System Architecture Diagram

```
Catalog [/]
  │ tap Quick Match
  ▼
POST /v1/matchmaking/casual ──► CasualQueueService (heap FIFO)
  │                                    │
  │                         if peer waiting ──► MatchService.createCasualMatch
  │                                    │              mode=CASUAL, NORMAL, host/joiner,
  │                                    │              reconnect tokens, registerPrivate
  ▼                                    ▼
GET poll (500ms) ◄──────────── SEARCHING | MATCHED{matchId}
  │
  ├─ matched early ──► howto? ──► /match?mode=casual&matchId= ──► WS throws (reuse private)
  │                                      │
  │                                      └─ settle ──► economy grants + profile XP/W/L
  │                                                   (+ Elo if CASUAL)
  │                                      └─ ResultOverlay Play again ──► POST rematch
  │                                           └── /match/rematch-wait (10s dual accept)
  │                                                └── createCasualMatch again
  │
  ├─ 8s no pair ──► /matchmaking/fallback (still SEARCHING; poll continues)
  │     ├─ Play vs bot ──► dequeue ──► POST /v1/matches BOT (last chip)
  │     ├─ Invite friend ──► dequeue ──► POST /v1/rooms ──► /lobby
  │     └─ Back to catalog ──► dequeue
  │
  └─ Cancel search ──► dequeue ──► /

Avatar chip ──► GET /v1/profile ──► /profile (PUT avatar; cosmetics read-only from loadout)
```

### Recommended Project Structure

```
backend/src/main/java/com/nomadgames/
├── matchmaking/
│   ├── CasualQueueService.java      # enqueue/dequeue/pair
│   ├── CasualMatchmakingController.java
│   └── internal/JoinRateLimiter.java  # reuse/extend for enqueue
├── session/
│   ├── MatchService.java            # createCasualMatch; humanMode helpers; rematch CASUAL
│   └── internal/MatchSessionRegistry.java  # RematchWindow reuse
└── profile/                         # NEW Modulith package
    ├── ProfileService.java
    ├── ProfileController.java
    ├── SoftElo.java
    └── internal/ProfileJdbc.java

backend/src/main/resources/db/migration/
└── V9__profile_casual.sql

client/lib/
├── catalog/catalog_page.dart        # QM CTA + avatar chip
├── matchmaking/
│   ├── searching_page.dart
│   └── fallback_page.dart
├── profile/profile_page.dart
├── games/alchiki/
│   ├── match_page.dart              # _isHuman / casual rematch path
│   ├── rematch_waiting_page.dart
│   └── pause_overlay.dart           # casual Play again (not Again?)
└── platform/
    ├── router.dart
    └── api/nomad_api.dart
```

### Pattern 1: Human two-seat mode helper
**What:** Replace scattered `"PRIVATE".equals(match.getMode())` with `isHumanPvP(mode)` = PRIVATE \|\| CASUAL for WS ticket, throws, leave, reconnect, seats, rematch eligibility. Keep bot path on REST. Rematch **create** branches: PRIVATE → `createPrivateMatch`; CASUAL → `createCasualMatch`.
**When to use:** Every former PRIVATE-only guard in `MatchService` / client `_isPrivate`.
**Example:**
```java
// Source: codebase pattern extension [VERIFIED: MatchService.java createPrivateMatch]
static boolean isHumanPvP(String mode) {
    return "PRIVATE".equals(mode) || "CASUAL".equals(mode);
}

@Transactional
public UUID createCasualMatch(UUID hostId, UUID joinerId) {
    // identical to createPrivateMatch but mode "CASUAL"
    // difficulty NORMAL; turn JOINER; reconnect tokens; sessions.registerPrivate
}
```

### Pattern 2: Pair-on-enqueue FIFO
**What:** On `enqueue(playerId)`: if map already has ticket → idempotent return; else if queue non-empty → poll peer, createCasualMatch, return MATCHED for both; else offer into queue SEARCHING.
**When to use:** CasualQueueService only.
**Anti-race:** synchronize on queue monitor; never leave one player MATCHED without matchId.

### Pattern 3: Sync profile settle (economy twin)
**What:** Inside `afterTerminal`, after grants, call `profile.recordSettlement(...)` with matchId, seats, outcomes, mode, game. Idempotent on `(matchId, playerId)`.
**When to use:** Every terminal path (throw resolve, leave, reconnect expiry).

### Anti-Patterns to Avoid
- **60s fail spinner:** Forbidden by MODE-03 / D-62.
- **Client-side MMR/XP:** Display only; server writes.
- **Treating CASUAL as PRIVATE in UI rematch:** Use Play again + waiting route, not Again? (D-70).
- **Dequeuing at 8s automatically:** Loses late pairs; dequeue on explicit exits only (discretion lock).
- **Band / region MM:** Deferred.
- **Equip cosmetics on profile:** Shop only (D-55).
- **Bot-fill of empty QM seat mid-search without choice UI:** Product requires choice screen (D-62/63), not silent bot.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Human PvP table | Second Flame/WS stack for casual | Reuse private match_page + MatchSocket with `mode=casual` | Already proven SESS-02/WS |
| Rematch dual-accept | New ticket protocol | `RematchWindow` + `/v1/matches/{id}/rematch` | RematchIT covers races |
| Invite friend MM deep link | Custom share→queue | `RoomService.create` + lobby | D-64 |
| Soft skill rating | Ad-hoc ±points | Classic Elo formula | Documented, Phase 7 can fork to Glicko [CITED: en.wikipedia.org/wiki/Elo_rating_system] |
| Profile cosmetics source | Duplicate inventory | `economy.getLoadout` | Single loadout SoT |
| Queue across JVMs | Redis now | In-process; Redis later | REQUIREMENTS / STACK |
| Found-match ready gate | 15–20s accept lobby | Immediate match start | D-68 |

**Key insight:** CASUAL is a **mode tag + queue entrypoint**, not a new game engine. Most risk is generalizing PRIVATE guards without breaking bot or private rematch chrome.

## Common Pitfalls

### Pitfall 1: PRIVATE-only guards leave CASUAL without WS/reconnect
**What goes wrong:** `issueWsTicket` / `applyPrivateThrow` / `rejoin` / rematch throw `not private`; QM match unplayable or no SESS-02.
**Why it happens:** Codebase uses `"PRIVATE".equals` in many branches [VERIFIED: MatchService.java].
**How to avoid:** Introduce `isHumanPvP`; IT covering CASUAL ws-ticket + rejoin + rematch.
**Warning signs:** Client stuck on Starting scaffold; HTTP 409 on rematch.

### Pitfall 2: Client `_isPrivate` only
**What goes wrong:** Casual uses bot rematch (one-tap new bot) or skips reconnect chrome.
**How to avoid:** `_isHuman = mode == private \|\| mode == casual`; rematch UX flag `_isCasual` for Play again → wait route vs Again?.
**Warning signs:** `rematch_overlay_test` still assumes private-only dual CTA on casual.

### Pitfall 3: Double-pair / stuck queue ticket
**What goes wrong:** Two matchIds for one player; or dequeue leaves peer orphaned.
**How to avoid:** Synchronized pair; on create failure re-queue both; cancel clears map+queue; IT concurrent enqueue.
**Warning signs:** 409 on second match create; ghost SEARCHING forever.

### Pitfall 4: Soft MMR from bot/private
**What goes wrong:** Farm bots / friends inflate parlor rating; Phase 7 Glicko polluted.
**How to avoid:** Elo only when `mode == CASUAL`; XP/W/L still all modes (D-75).
**Warning signs:** Rating changes after bot win.

### Pitfall 5: Empty-queue Invite without dequeue
**What goes wrong:** Player sits in FIFO while in private lobby → surprise match.
**How to avoid:** `createRoom` path always `dequeue(playerId)` first (D-64).

### Pitfall 6: Profile Stick Pull section hidden
**What goes wrong:** PROF-02 / D-77 fail.
**How to avoid:** Always render section; zeros + `noMatchesYet`.

## Code Examples

### Soft Elo update (server)
```java
// Source: Elo rating system [CITED: en.wikipedia.org/wiki/Elo_rating_system]
// E_a = 1 / (1 + 10^((R_b - R_a) / 400))
// R'_a = R_a + K * (S_a - E_a)  ; S in {1, 0.5, 0}
public static int expectedScore(int ratingA, int ratingB) { /* use double internally */ }

public static int nextRating(int rating, int opponent, double score, int k) {
    double expected = 1.0 / (1.0 + Math.pow(10.0, (opponent - rating) / 400.0));
    int next = (int) Math.round(rating + k * (score - expected));
    return Math.max(100, next);
}
```

### Client human vs casual rematch fork
```dart
// Source: extend match_page.dart [VERIFIED: client _isPrivate getter]
bool get _isHuman => widget.mode == 'private' || widget.mode == 'casual';
bool get _isCasual => widget.mode == 'casual';

// ResultOverlay: if (_isCasual) onPlayAgain → push /match/rematch-wait + POST rematch
// if (private) keep Again? + rematchSeconds on overlay
```

### Enqueue REST shape (recommended)
```http
POST /v1/matchmaking/casual
Authorization: Bearer <access>
→ 200 { "status": "SEARCHING"|"MATCHED", "matchId": null|"uuid", "ticketId": "uuid" }

GET /v1/matchmaking/casual
→ 200 { "status": "IDLE"|"SEARCHING"|"MATCHED", "matchId": ..., "ticketId": ... }

DELETE /v1/matchmaking/casual
→ 204
```

### Flyway sketch
```sql
-- V9__profile_casual.sql
ALTER TABLE players ADD COLUMN avatar_preset VARCHAR(32) NOT NULL DEFAULT 'avatar_01';
ALTER TABLE players ADD COLUMN xp INT NOT NULL DEFAULT 0;
ALTER TABLE players ADD COLUMN level INT NOT NULL DEFAULT 1;
ALTER TABLE players ADD COLUMN soft_rating INT NOT NULL DEFAULT 1000;
ALTER TABLE players ADD COLUMN best_rating INT NOT NULL DEFAULT 1000;

CREATE TABLE player_game_stats (
  player_id UUID NOT NULL REFERENCES players(id),
  game VARCHAR(32) NOT NULL,
  matches INT NOT NULL DEFAULT 0,
  wins INT NOT NULL DEFAULT 0,
  losses INT NOT NULL DEFAULT 0,
  draws INT NOT NULL DEFAULT 0,
  PRIMARY KEY (player_id, game)
);

CREATE TABLE profile_settlements (
  match_id UUID NOT NULL,
  player_id UUID NOT NULL REFERENCES players(id),
  PRIMARY KEY (match_id, player_id)
);
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Research SUMMARY “Phase 7 = QM + profile” | ROADMAP **Phase 5** | Roadmap creation | Ignore obsolete SUMMARY phase numbers |
| FEATURES latency/win-rate MM | D-68 first-available | 05-CONTEXT | Ship bands later |
| ARCHITECTURE 15–20s match accept | Immediate QM start | D-68 | Accept only on rematch |
| Redis ZSET day one | In-process queue | STACK / REQUIREMENTS | No Redis dependency |
| Private rematch Again? for all human | Casual Play again + wait page | D-70…D-73 | Separate client chrome |

**Deprecated/outdated:**
- Treating private reconnect research “60s” — SESS-02 / D-41 lock **30s** (already shipped).
- Soft-locking profile behind bind — guests see full PROF-01 now (D-75).

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Soft Elo K=24, start 1000, floor 100 is acceptable parlor feel | Discretion / Soft Elo | Owner may want different scale before Phase 7 |
| A2 | Soft MMR updates **CASUAL PvP only** (not private/bot) | Pitfalls / XP-MMR split | If owner wanted private rated too, formula scope wrong |
| A3 | XP +12/+6/+4 and triangular level thresholds | Discretion | Curve too fast/slow — tune only numbers |
| A4 | Stay queued during fallback UI (poll continues) | Discretion | If owner prefers dequeue-at-8s, change fallback lifecycle |
| A5 | `MatchRewardTable.privateMatch=true` path applies to CASUAL grants | Economy hook | Need to rename flag to `humanMatch` or pass true for CASUAL |
| A6 | classify-confidence seam returned LOW for websearch/webfetch this session | Sources | Planner should prefer codebase-verified claims over web digests |

**If this table is empty:** — not empty; confirm A1–A5 only if product questions reopen (yolo = proceed).

## Open Questions (RESOLVED)

1. **Economy grant flag naming for CASUAL** — **RESOLVED / LOCKED**
   - What we know: `grantSeat(..., boolean privateMatch)` feeds `MatchRewardTable` [VERIFIED: MatchService / MatchRewardTable].
   - **Locked decision:** CASUAL uses `humanMatch=true` (same grant path as private). Rename `privateMatch` → `humanMatch` at the call site when touched. No third reward column.

2. **Guest display on profile: `Guest` vs `Guest-XXXX`** — **RESOLVED / LOCKED**
   - UI-SPEC allows Guest heading + Guest-XXXX subtitle.
   - **Locked decision:** Heading `Guest`; subtitle Guest-XXXX (last-4 of playerId, D-33 pattern) per 05-UI-SPEC.

No remaining open questions — yolo discretion covers queue/MMR/XP/routes.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| JDK 21 | Backend build/ITs | ✓ (prior phases) | 21.x Corretto | — |
| Flutter 3.47 | Client | ✓ (dev-env.ps1) | 3.47.x | — |
| PostgreSQL 18 (Testcontainers) | ITs | ✓ | 18 | — |
| Maven Wrapper | `./mvnw` | ✓ | repo | — |
| Redis | — | N/A | — | **Do not use** |
| Context7 MCP | Docs lookup | ✗ this session | — | Official WebFetch + codebase |

**Missing dependencies with no fallback:** none for Phase 5 scope.  
**Missing dependencies with fallback:** Context7 → WebFetch / CITED project research.

Step 2.6: External tools limited to existing toolchain — **no new CLIs**.

## Validation Architecture

> `workflow.nyquist_validation: true` in `.planning/config.json` — include for VALIDATION.md.

### Test Framework

| Property | Value |
|----------|-------|
| Framework | JUnit 5 + Spring Boot Test + Testcontainers (backend); `flutter_test` (client) |
| Config file | backend Surefire via Maven; client `flutter test` |
| Quick run command | `.\mvnw.cmd -pl backend -am -Dtest=CasualQueueIT,ProfileIT,RematchIT -Dsurefire.failIfNoSpecifiedTests=false test` and `flutter test test/catalog_test.dart test/matchmaking_test.dart` |
| Full suite command | `.\mvnw.cmd -pl backend -am test` ; `flutter test` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| MODE-03 | Two enqueues → one CASUAL matchId; single enqueue stays SEARCHING | IT | `CasualQueueIT` | ❌ Wave 0 |
| MODE-03 | After timeout UX path: fallback CTAs dequeue + bot/room | widget | `flutter test test/matchmaking_test.dart` | ❌ Wave 0 |
| MODE-03 | Invite friend calls createRoom after dequeue | widget/IT | matchmaking + RoomIT reuse | ❌ / ✅ RoomIT |
| MODE-05 | CASUAL rematch dual-accept mints new CASUAL match | IT | extend `RematchIT` or `CasualRematchIT` | ❌ Wave 0 |
| MODE-05 | Play again navigates to rematch-wait; Cancel → catalog | widget | `flutter test test/casual_rematch_test.dart` | ❌ Wave 0 |
| SESS-02 | CASUAL rejoin within 30s | IT | extend `ReconnectIT` for mode CASUAL | ❌ Wave 0 (ReconnectIT exists for PRIVATE) |
| PROF-01 | GET profile returns Guest fields + rating + cosmetics | IT | `ProfileIT` | ❌ Wave 0 |
| PROF-02 | Stick Pull zeros always present | IT + widget | ProfileIT + `profile_page_test.dart` | ❌ Wave 0 |
| PROF-03 | PUT avatar only allows preset enum; default avatar_01 | IT | ProfileIT | ❌ Wave 0 |
| D-75 | XP increments on bot settle; rating unchanged on bot | IT | ProfileIT | ❌ Wave 0 |
| D-75 | Elo changes on CASUAL settle only | IT | ProfileIT | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** targeted IT or widget test for touched seam
- **Per wave merge:** quick run command above
- **Phase gate:** full backend + `flutter test` green before `/gsd-verify-work`

### Wave 0 Gaps
- [ ] `backend/.../CasualQueueIT.java` — MODE-03 pair + dequeue + concurrent enqueue
- [ ] `backend/.../ProfileIT.java` — PROF-01…03 + XP vs Elo split
- [ ] Extend `RematchIT` / new `CasualRematchIT` — MODE-05 CASUAL
- [ ] Extend `ReconnectIT` — SESS-02 for `mode=CASUAL`
- [ ] `client/test/matchmaking_test.dart` — Searching Cancel + 8s fallback (fake async)
- [ ] `client/test/profile_page_test.dart` — Stick Pull empty + avatar save
- [ ] `client/test/casual_rematch_test.dart` — Play again → wait route
- [ ] `client/test/catalog_test.dart` — assert Quick Match + avatar chip (extend existing)

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | yes (existing guest JWT) | Reuse access JWT on queue/profile; no new auth |
| V3 Session Management | yes | WS ticket + rotating reconnect token (existing) |
| V4 Access Control | yes | Queue ticket bound to `playerId`; rematch `requireSeat`; profile self-only |
| V5 Input Validation | yes | Avatar preset allow-list enum; reject unknown ids; mode enum server-side |
| V6 Cryptography | no new | No client-trusted rating; existing SHA-256 refresh/reconnect hashes |

### Known Threat Patterns for casual queue + profile

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Enqueue flood / queue DoS | Denial of Service | Extend `JoinRateLimiter`-style per playerId+IP on POST casual |
| Client-submitted MMR/XP | Tampering | Profile writes only from settle; GET is projection |
| Avatar path traversal / XSS via upload | Tampering | Preset ids only; no upload (D-76) |
| Steal rematch into opponent match | Elevation | Seat check on rematch; createCasualMatch uses window host/joiner only |
| Stay queued while in another match | Tampering | Reject enqueue if player already IN_PLAY human seat; dequeue on match start |
| Enumerate other profiles | Information Disclosure | MVP: only `GET /v1/profile` self; no public by-id (opponent stats later) |

## Sources

### Primary (HIGH confidence)
- Codebase: `MatchService.java` (PRIVATE create/rematch/WS/reconnect), `RoomService.java`, `ReconnectPolicy.java`, `match_page.dart` `_isPrivate`, Flyway V1–V8, `EconomyService.grantMatchRewards`
- `.planning/phases/05-*-CONTEXT.md` / `05-UI-SPEC.md` — D-62…D-77 + UI locks
- `.planning/research/ARCHITECTURE.md` / `STACK.md` — in-process queues; Redis later
- Spring Modulith events reference — sync publication default [CITED: docs.spring.io/spring-modulith/reference/events.html]
- Flutter navigation — prefer go_router [CITED: docs.flutter.dev/ui/navigation]

### Secondary (MEDIUM confidence)
- Elo expected-score / K-factor update [CITED: en.wikipedia.org/wiki/Elo_rating_system]
- FEATURES.md empty-queue bot/invite; rematch 10s

### Tertiary (LOW confidence)
- WebSearch Redis MM tutorials (explicitly **out of scope** for day one) — classify-confidence LOW this session
- Soft XP/level curve numbers [ASSUMED]

## Metadata

**Confidence breakdown:**
- Standard stack: **HIGH** — pinned versions verified in pubspec/pom; no new packages
- Architecture: **HIGH** — clear reuse of PRIVATE seams + CONTEXT/UI-SPEC locks; queue choice aligned with ARCHITECTURE
- Pitfalls: **HIGH** — PRIVATE-only guard sprawl verified in MatchService/match_page
- Soft MMR / XP numbers: **MEDIUM** — formula cited; constants Claude discretion [ASSUMED A1/A3]

**Research date:** 2026-09-11  
**Valid until:** 2026-10-11 (stable stack; revisit if Spring/Flutter pins move)
