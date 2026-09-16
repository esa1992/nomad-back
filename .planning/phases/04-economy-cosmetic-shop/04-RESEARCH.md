# Phase 4: Economy + Cosmetic Shop - Research

**Researched:** 2026-09-10
**Domain:** Server-authoritative dual-currency ledger, soft-currency cosmetic shop, presentation-only loadout
**Confidence:** HIGH (locked D-45…D-61 + UI-SPEC + live settle/shop seams + official Spring Modulith / JdbcClient / Play Billing docs). Reward table numbers and thin SKU counts are Claude discretion → tagged where assumed.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-45:** Match settlement stays **server-only**. On terminal result the server grants currency once per `(matchId, playerId, reason)` and includes the grant in the result payload the client already uses for `ResultOverlay` (bot REST settle and private WS/HTTP result path). The client never POSTs a `coinsDelta`.
- **D-46:** Rewards appear **on the existing result screen**, not a separate blocking wallet screen: short `+N COINS` / `+M GEMS` lines under the outcome. Rematch / Back to catalog remain the primary actions (D-43). No “coins fly into a distant chip” as a required gate before rematch.
- **D-47:** Flat casual rewards: **win > loss** (and draw if the rules emit one). Difficulty may scale COINS slightly for bot matches. **GEMS are scarce** (occasional; not every match). Exact amounts and gem drop rate are Claude’s discretion — must feel like a reward without flooding GEMS.
- **D-48:** Catalog (and shop header) show a **read-only dual wallet chip** (COINS | GEMS) refreshed from server balance after settle and after purchase. Displayed numbers never authorize a buy.
- **D-49:** Primary entry is a **Shop** control on the **catalog** (tile or top-bar button — UI-SPEC picks chrome). Secondary: optional text link **Shop** on the result overlay that does **not** replace Rematch / Play again. No real-money checkout, no IAP banners.
- **D-50:** Shop is its own `go_router` route (e.g. `/shop`). First screen is a **category shelf + SKU grid** (not a long unstructured list): categories match ECON-02. EN+RU via existing l10n. Empty / error: short copy + retry; never invent local stock.
- **D-51:** Guests may **browse, buy, and equip** with earned soft currency. Do **not** soft-lock the shop behind bind in this phase (bind is Phase 7; guest identity already owns progress).
- **D-52:** Ship **all ECON-02 slots** this phase with a **thin SKU set** (default free starter + a few paid themes), not a full live-ops catalog: saka **color / material / ornament**, **trail**, **table/FX effects**, **victory animation**, and **Stick Pull skins**. Stick Pull skins are buyable and equippable now; they apply when Stick Pull becomes playable (Phase 6). Do not invent P2W stats, frames-as-power, or weighted sakas.
- **D-53:** Visual themes stay inside PRES-02: **Gold / Neon / Ice / Fire / Space** plus **original ornaments** — no third-party brand IP. Default free loadout so a new guest is never “naked” on the table.
- **D-54:** Cosmetics are **presentation-only**. Same mass, restitution, aim chrome, tap force, and stamina rules for every SKU (ECON-03 / Ranked trust later).
- **D-55:** **Inventory lives inside the shop shell** (tab or segment: Shop | Owned) — not a separate Phase 5 profile dependency. Owned items show **Equip**; equipped shows **Equipped**. Unequip / switch returns the slot to the **default free** SKU (or the newly equipped one) — no empty slot that breaks render.
- **D-56:** Equip is **server-authoritative loadout**. Client sends equip intent; server stores selected SKU per slot; next match (and rematch) loads that loadout into spawn/presentation. **No mid-throw swap** — changes apply at match start / rematch kickoff so private opponents share a stable look for the bout.
- **D-57:** Shop detail shows a **static felt preview** of the saka/trail/effect (catalog palette). Live table uses the equipped set from the server loadout at match create — do not trust client-only prefs for what the opponent sees.
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

### Deferred Ideas (OUT OF SCOPE)
- Real-money IAP / Play Billing / Apple IAP (PAY-01/02, post-MVP)
- Soft-lock shop spend behind bind (FEATURES hypothesis — revisit Phase 7 if needed)
- Profile screen showing selected cosmetics + W/L (Phase 5 PROF-*)
- Stick Pull playable table that consumes equipped stick skins (Phase 6)
- Daily COINS chest, bind GEMS reward, season pass, gacha (v1.x / v2+)
- Coin-wager tables, P2W cue stats (never for Ranked trust)

None extra from this discussion — user stayed inside Phase 4 and accepted defaults.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| ECON-01 | Player receives COINS (and occasional GEMS) from match rewards decided on the server | Sync grant on every terminal settle path in `MatchService`; idempotent ledger key `{matchId}:{playerId}:{reason}`; extend `MatchSnapshot` / throw / leave / `MatchSettled` WS frames with `coinsGranted` / `gemsGranted` for `ResultOverlay` |
| ECON-02 | Browse cosmetic shop (all seven slots) and buy with COINS/GEMS | Flyway SKU seed + REST catalog; Flutter `/shop` category shelf + grid per 04-UI-SPEC; guests allowed (D-51) |
| ECON-03 | Equip owned cosmetics; never change physics / tap / aim | `loadout` table + equip REST; `MatchGame`/`SakaBody` apply fill/stripe/trail **paint only**; density/friction/restitution untouched |
| ECON-04 | Wallet balances from server ledger only; displayed numbers cannot grant | No client `coinsDelta`; buys check DB balance inside economy TX; wallet chip is GET projection |
| ECON-05 | Idempotent soft purchases + empty unique-token `purchases` table for future IAP | `soft_purchases(idempotency_key UNIQUE)` + empty `purchases(provider, token UNIQUE)` per Play `purchaseToken` guidance |
</phase_requirements>

## Summary

Phase 4 adds the **cosmetic economy loop** beside an already-authoritative match stack. The backend today has `identity`, `catalog`, `matchmaking`, `session`, and `games.alchiki` — **no `economy` package, no ledger tables, no JdbcClient usage, no shop REST**. Settlement already terminates matches via `engine.resolve` / leave / reconnect expiry and returns `MatchSnapshot` over REST and WS `MatchSettled`, but the snapshot has **no reward fields**. The Flutter client has catalog + `ResultOverlay` + `go_router` without `/shop`, wallet chip, or loadout presentation beyond hardcoded seat colors in `AlchikiMatchGame`.

The planner should treat this as a **greenfield economy module + thin client shop**, not a rooms/WS rewrite. Rooms, rematch, reconnect, and forge2d **0.14.2** stay untouched. Grants must complete **inside the settle transaction before the response is built** (D-45/D-46) — do not rely on async `@ApplicationModuleListener` for the reward lines the overlay needs.

**Primary recommendation:** Add Modulith package `com.nomadgames.economy` with Flyway wallets + append-only ledger + inventory/loadout/SKU seed + empty `purchases`; grant synchronously from every terminal `MatchService` path; expose REST `/v1/wallet`, `/v1/shop/*`, `/v1/loadout`; extend catalog/`ResultOverlay`/`/shop` per 04-UI-SPEC; pass seat loadouts on match create/rejoin for presentation-only paints.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Match reward grant (COINS/GEMS) | API / Backend (`economy`) | Session (detect terminal → call grant) | Server-only; idempotent ledger; D-45 |
| Result reward lines UI | Browser / Client | — | Display grant from payload; never invent (D-46) |
| Dual wallet chip | Browser / Client | API GET `/v1/wallet` | Read-only projection (D-48 / ECON-04) |
| Soft-currency purchase | API / Backend | Browser (idempotency key + Buy CTA) | Unique key + balance check (D-59) |
| Shop catalog / Owned / detail | Browser / Client | API shop catalog | `/shop` route; empty/error from server (D-50) |
| Equip / loadout persistence | API / Backend | Browser (Equip CTA) | Server loadout is truth (D-56) |
| Match presentation (fills/trails/FX) | Browser / Client (Flame paint) | API (loadout snapshot at create) | Presentation-only; freeze for bout (D-54/D-57) |
| Ledger / balances / inventory durability | Database / Storage | API / Backend | Postgres only; no Redis |
| Future IAP token uniqueness | Database / Storage | — | Empty `purchases.token` UNIQUE now (D-60) |
| Guest browse/buy/equip | API / Backend | Browser | Existing guest JWT; no bind gate (D-51) |

## Project Constraints (from .cursor/rules/)

Actionable directives from `.claude/.cursor/rules` (PROJECT.md + STACK.md):

- **Authority:** Backend is source of truth; client never authors score, outcome, rating, balance, grants, or purchases.
- **Fairness:** Cosmetics must not change physics, tap power, or aim assist (ECON-03).
- **Payments:** No IAP in MVP; reserve idempotent purchase model / unique token table so wallets are not rewritten later.
- **Physics lock:** Flutter 3.47 + Flame 1.38 + **forge2d 0.14.2 / flame_forge2d 0.19.3+7** (pinned in `client/pubspec.yaml` — do not bump to STACK’s 0.15 research aspirational).
- **Backend lock:** Java 21 + Spring Boot 4.1.1 + Modulith 2.1.1; PostgreSQL; **no Redis**; REST for shop; raw WS stays match-only.
- **Auth:** First-party HS256 JWT + rotating refresh; guests shop (D-51).
- **Localization:** Every new string is an ARB key; EN+RU complete (04-UI-SPEC copy table).
- **Art:** PRES-02 themes only; no licensed IP.
- **Git:** Do not create a nested `.git` under `nomad-game`.
- **GSD workflow:** Research/planning artifacts only here; implement via phase plans.

No project skills (`SKILL.md`) under `.cursor/skills/` or `.agents/skills/`. Knowledge graph: **absent** (`.planning/graphs/graph.json` missing).

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Flutter SDK | **3.47.x** / Dart **3.13.x** | Client shell + shop widgets | Phase 1–3 lock; `scripts/dev-env.ps1` → `~/develop/flutter` [VERIFIED: scripts/dev-env.ps1 + pubspec] |
| Flame / forge2d / flame_forge2d | **1.38.2** / **0.14.2** / **0.19.3+7** | Match presentation only | Do not reopen; cosmetics = paint [VERIFIED: client/pubspec.yaml] |
| JDK | **21.0.11** (Corretto) | Backend | Available after `dev-env.ps1` [VERIFIED: toolchain probe this session] |
| Spring Boot | **4.1.1** | Modular monolith | Project lock [VERIFIED: backend/pom.xml] |
| Spring Modulith | **2.1.1** | Package modules + `ModularityTest` | Must stay green [VERIFIED: pom + ModularityTest] |
| PostgreSQL | **18.x** (Testcontainers `postgres:18`) | Wallets / ledger / shop | No Redis [VERIFIED: ThrowAuthorityIT container] |
| Flyway | BOM (**12.4.0** per STACK) | `V7__economy_*.sql` | Next migration after `V6__room_version.sql` [VERIFIED: migrations V1–V6 exist] |
| JdbcClient (`spring-jdbc`) | Boot BOM | Ledger + purchase writes | STACK prescription; never JPA mutate-balance [CITED: docs.spring.io/spring-framework/reference/data-access/jdbc/core.html#jdbc-JdbcClient] |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `go_router` | **18.0.1** (already) | `/shop`, detail query | Already pinned [VERIFIED: pubspec] |
| `dio` / `flutter_riverpod` | **5.11.1** / **3.4.3** | REST wallet/shop/equip | Extend `NomadApi` |
| `flutter_secure_storage` | **11.0.0** | Unchanged tokens | Do not store balances here |
| JUnit + Testcontainers ITs | Boot BOM | `EconomyIT`, grant/purchase races | Follow `ThrowAuthorityIT` / `RoomIT` |
| Flutter `flutter_test` | SDK | Shop / wallet / reward widget tests | Follow `catalog_test.dart` override pattern |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Sync `EconomyService.grant*` from `MatchService` | Async `@ApplicationModuleListener` + Event Publication Registry | **Reject for grant path.** Async loses D-45 (reward must be in same response). Registry adds Flyway event tables not needed this phase. Prefer sync call; optional `ApplicationEventPublisher.publishEvent(MatchSettled)` for future rating **without** blocking on async consumers [CITED: docs.spring.io/spring-modulith/reference/events.html] |
| JPA `@Version` wallet entity | JdbcClient INSERT ledger + UPDATE wallets | **Reject entity mutate.** STACK + Pitfall 6: ledger-only writes [CITED: STACK.md + PITFALLS.md] |
| Client SharedPreferences coins | Server GET wallet | **Reject.** ECON-04 / Pitfall 6 |
| New `uuid` pub package | `Random.secure()` hex / UUID string in `NomadApi` | Prefer **no new Flutter dep**; hand-roll v4-ish key or use `Uuid` from a tiny helper. Do not add IAP SDKs |
| Redis balances | Postgres | **Reject.** No Redis day one |
| Soft-lock shop behind bind | Guest shop (D-51) | **Reject** FEATURES soft-lock hypothesis for this phase |

**Installation:**

```bash
# No new Maven artifacts required — JdbcClient is on the classpath via spring-boot-starter-data-jpa / spring-jdbc (Boot BOM).
# No new Flutter packages required for MVP shop.

# Verify existing pins (from repo root after . ./scripts/dev-env.ps1):
.\mvnw.cmd -pl backend -am -q dependency:tree -Dincludes=org.springframework:spring-jdbc
# client: forge2d 0.14.2 already in pubspec.yaml — do not flutter pub add forge2d
```

**Version verification (this session):**
- forge2d **0.14.2**, flame_forge2d **0.19.3+7**, go_router **18.0.1** [VERIFIED: client/pubspec.yaml]
- Spring Boot **4.1.1**, Modulith **2.1.1**, websocket starter present [VERIFIED: backend/pom.xml]
- JdbcClient API documented in Spring Framework reference [CITED: docs.spring.io/spring-framework/.../jdbc-JdbcClient]
- Play Billing: `purchaseToken` globally unique → use as PK / UNIQUE [CITED: developer.android.com/google/play/billing/security]

## Package Legitimacy Audit

> No new external packages are required for Phase 4. JdbcClient is BOM-transitive; Flutter shop uses existing Material + go_router + dio + riverpod.

| Package | Registry | Age | Downloads | Source Repo | Verdict | Disposition |
|---------|----------|-----|-----------|-------------|---------|-------------|
| `spring-jdbc` / `JdbcClient` | Maven Central (Boot BOM) | years | n/a (BOM) | spring-projects/spring-framework | OK | Approved — already on classpath via `spring-boot-starter-data-jpa` |
| (none new on pub.dev) | — | — | — | — | — | Do not add Play Billing / in_app_purchase / uuid unless planner explicitly needs uuid |

**Packages removed due to [SLOP] verdict:** `spring-jdbc` looked up on **npm** seam → `SLOP` (wrong ecosystem). Ignore; Maven BOM is authoritative (same pattern as Phase 3 Dart↔npm false negatives).
**Packages flagged as suspicious [SUS]:** none.

*Do not add Colyseus, Nakama, Redis clients, Play Billing, StoreKit, gacha SDKs, or `google_fonts`.*

## Architecture Patterns

### System Architecture Diagram

```
Match terminal transition (bot REST throw | private WS throw | leave | reconnect expiry)
    │  @Transactional MatchService
    ▼
economy.grantMatchRewards(matchId, seats, outcome, difficulty, mode)
    │  INSERT wallet_ledger (UNIQUE idempotency_key)
    │  UPDATE wallets SET balance = balance + delta WHERE balance + delta >= 0
    ▼
MatchSnapshot (+ coinsGranted, gemsGranted for viewer)
    │
    ├─► REST ThrowResponse / LeaveResponse  ──► ResultOverlay reward lines
    └─► WS type=MatchSettled                ──► ResultOverlay reward lines

Catalog / Shop (REST + JWT, no WS)
    GET  /v1/wallet
    GET  /v1/shop/catalog
    POST /v1/shop/purchases   { skuId, idempotencyKey }
    POST /v1/shop/equip       { slot, skuId }
    GET  /v1/loadout          (self)
        │
        ▼
Match create / rematch / rejoin
    │  attach hostLoadout + joinerLoadout (or bot: local only)
    ▼
AlchikiMatchGame applies presentation paints at start only (no mid-throw swap)
```

### Recommended Project Structure

```
backend/src/main/java/com/nomadgames/
├── identity/                 # unchanged; guest mint may call economy.ensureDefaults(playerId)
├── catalog/
├── matchmaking/
├── session/                  # hook grants on terminal; extend MatchSnapshot + create payloads
│   └── internal/
├── economy/                  # NEW Modulith module
│   ├── EconomyController.java      # /v1/wallet, /v1/shop/*, /v1/loadout
│   ├── EconomyService.java         # grant, purchase, equip, queries
│   ├── MatchRewardTable.java       # COINS/GEMS amounts (discretion)
│   ├── ShopCatalog.java            # SKU DTOs
│   └── internal/
│       ├── WalletLedgerJdbc.java   # JdbcClient only writers
│       ├── SoftPurchaseJdbc.java
│       ├── InventoryJdbc.java
│       └── LoadoutJdbc.java
└── games/alchiki/            # unchanged physics; no economy imports

backend/src/main/resources/db/migration/
└── V7__economy_ledger_shop.sql

client/lib/
├── catalog/catalog_page.dart       # wallet chip + Shop top-bar (04-UI-SPEC)
├── shop/                           # NEW
│   ├── shop_page.dart              # segments + categories + grid
│   ├── shop_detail_page.dart       # felt preview + Buy/Equip
│   └── wallet_chip.dart
├── platform/
│   ├── router.dart                 # /shop
│   └── api/nomad_api.dart          # wallet/shop/equip + parse grant fields
└── games/alchiki/
    ├── pause_overlay.dart          # reward lines + secondary Shop link
    └── match_game.dart             # apply server loadout paints at start
```

### Pattern 1: Sync grant inside settle TX (D-45)

**What:** When `MatchService` transitions a match out of `IN_PLAY`, call `EconomyService.grantMatchRewards(...)` in the **same** `@Transactional` method, then build `MatchSnapshot` including the returned grant for the viewing seat.
**When to use:** Every terminal path — bot `applyThrow` / clock forfeit, private `applyPrivateThrow`, `leaveMatch`, `settleExpiredDrop`.
**Modulith:** `session` → `economy` is a **one-way** bean dependency (allowed). Do **not** have `economy` import `session` types; pass a plain command record defined in `economy` (or a shared API record owned by economy). Avoid `session` ↔ `economy` cycle. Optional `ApplicationEventPublisher.publishEvent` after grant for future rating — **not** required to build the overlay payload.
**Example:**

```java
// Source: Spring Modulith events guidance adapted for sync grant (D-45)
// https://docs.spring.io/spring-modulith/reference/events.html
@Transactional
public ThrowResponse applyThrow(UUID playerId, UUID matchId, String rawJson) {
    // ... existing throw + resolve ...
    matches.save(match);
    RewardGrant grant = RewardGrant.NONE;
    if (isTerminal(match.getStatus())) {
        grant = economy.grantMatchRewards(MatchRewardCommand.fromBot(match, playerId));
    }
    return new ThrowResponse(scored.playerThrow(), bot, snapshot(match, playerId, grant));
}
```

### Pattern 2: JdbcClient ledger + wallet row (ECON-04/05)

**What:** Append-only `wallet_ledger` with `UNIQUE (idempotency_key)`; maintain `wallets(player_id, currency, balance)` updated only in the same TX as the ledger insert. On unique violation → treat as success and return existing effect (idempotent replay).
**When to use:** Match grants (`{matchId}:{playerId}:MATCH_REWARD`) and soft purchases (`client idempotency UUID`).
**Example:**

```java
// Source: Spring Framework JdbcClient
// https://docs.spring.io/spring-framework/reference/data-access/jdbc/core.html#jdbc-JdbcClient
jdbcClient.sql("""
    INSERT INTO wallet_ledger (id, player_id, currency, delta, balance_after, reason, idempotency_key, created_at)
    VALUES (:id, :playerId, :currency, :delta, :balanceAfter, :reason, :key, :createdAt)
    """)
    .param("id", id)
    .param("playerId", playerId)
    // ...
    .update();
```

Catch PostgreSQL unique_violation on `idempotency_key` → `SELECT` prior grant and return it (no double credit).

### Pattern 3: Soft purchase + empty IAP shell (ECON-05 / D-60)

**What:** `POST /v1/shop/purchases` with body `{ "skuId", "idempotencyKey" }`. Server: lock wallet row (`SELECT … FOR UPDATE`), check funds, insert `soft_purchases`, debit ledger, insert inventory. Separate empty table:

```sql
CREATE TABLE purchases (
    provider VARCHAR(16) NOT NULL,      -- PLAY | APPLE (future)
    token    VARCHAR(512) NOT NULL,     -- Play purchaseToken / Apple transactionId
    player_id UUID NULL,
    sku_id   VARCHAR(64) NULL,
    state    VARCHAR(32) NULL,         -- future: PENDING|PURCHASED|…
    created_at TIMESTAMPTZ NOT NULL,
    PRIMARY KEY (provider, token)
);
```

**When to use:** Soft buys now; IAP rows stay zero until PAY-*. Play docs: token is globally unique — use as key; grant only `PURCHASED` later [CITED: developer.android.com/google/play/billing/security].

### Pattern 4: Server loadout → presentation paints (ECON-03)

**What:** Seven slots mirror ECON-02 categories. Defaults granted on guest mint / first wallet ensure. Equip writes `loadout(player_id, slot, sku_id)`. `createMatch` / `createPrivateMatch` / rematch / `RejoinSnapshot` include each seat’s SKU map. Client maps SKU → fill/stripe/trail/FX **colors only** in `SakaBody` / overlay — never density, friction, restitution, impulse, or aim length.
**When to use:** Always for Alchiki; Stick Pull skins stored now, ignored by playable table until Phase 6.

### Anti-Patterns to Avoid

- **Client `coinsDelta` / local prefs balance:** Pitfall 6 — forgeable economy.
- **`UPDATE wallets SET balance = ?` without ledger + idempotency:** Cannot audit or dedupe retries.
- **Async grant after HTTP/WS response:** Overlay shows 0 / races rematch.
- **Mid-throw equip apply:** Opponent sees desync; violates D-56.
- **P2W SKU fields** (`mass`, `aimAssist`, `tapPower`): Forbidden forever for Ranked trust.
- **Shop over WebSocket:** D-38 — WS is match-only.
- **Soft-lock “Sign in to buy”:** Conflicts with D-51.
- **Skipping empty `purchases` table:** ECON-05 / Pitfall 6 rewrite tax.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Ledger / idempotent wallet writes | Ad-hoc string SQL in session | `JdbcClient` in `economy.internal` | STACK + Framework facade; named params [CITED: Spring JdbcClient docs] |
| Cross-module settle fan-out later | `session` calling `rating`+`profile` beans ad hoc | Sync economy now; Modulith events later for rating | D-45 needs sync return; events docs for async secondary work [CITED: Modulith events] |
| IAP token dedupe later | Second wallet table | Empty `purchases(provider,token)` UNIQUE | Play: token as PK [CITED: Play Billing security] |
| UUID idempotency on client | New analytics SDK | Tiny helper / `Random.secure` hex | No new dep required |
| Shop UI kit | Custom design system package | Existing Material + 04-UI-SPEC tokens | Flutter parlor already locked |
| Cosmetics physics variants | Per-SKU FixtureDef | One `TableConstants` + paint overrides | ECON-03 |

**Key insight:** Soft currency fails the same way IAP fails — missing uniqueness and trusting the client. Building the ledger + empty token table now is cheaper than a Phase-PAY rewrite.

## Common Pitfalls

### Pitfall 1: Grant missing on some settle exits
**What goes wrong:** Bot throw grants, but leave / reconnect forfeit / private WS settle does not → players learn to quit for free coins or get nothing.
**Why it happens:** Multiple `setStatus` sites in `MatchService` (`applyThrow`, `applyPrivateThrow`, `leaveMatch`, `settleExpiredDrop`, clock forfeits).
**How to avoid:** Single private helper `afterTerminal(match)` that grants for all paid seats then snapshots; call from every terminal branch. IT that covers leave + reconnect expiry + normal resolve.
**Warning signs:** `ResultOverlay` sometimes lacks `+N COINS` for the same outcome status.

### Pitfall 2: Double grant on retry / rematch confusion
**What goes wrong:** Client retries throw response; rematch creates new `matchId` (correct) but reuse of old key or missing key duplicates coins.
**Why it happens:** No UNIQUE on `{matchId}:{playerId}:MATCH_REWARD}`; or rematch incorrectly re-grants old match.
**How to avoid:** Idempotency key includes **finished** `matchId`; rematch is a new match with its own future grant. Unique violation → return prior grant amounts in payload.
**Warning signs:** Wallet jumps by 2× after flaky network.

### Pitfall 3: Displayed balance authorizes Buy
**What goes wrong:** Client disables Buy from chip math; attacker POSTs purchase anyway or chip is stale.
**Why it happens:** Treating HUD as source of truth.
**How to avoid:** Server re-reads `wallets` under row lock; 409/402-style body with `errorInsufficientFunds`; chip is refresh-only (D-48).
**Warning signs:** Buy succeeds when chip shows 0 after two devices.

### Pitfall 4: Empty owned / naked saka
**What goes wrong:** New guest has no default SKUs → render crash or invisible saka.
**Why it happens:** Inventory only filled on purchase.
**How to avoid:** On guest mint (or first `ensureDefaults`), insert free default SKU per slot + loadout rows (D-53/D-55).
**Warning signs:** NPE / missing paint on first bot match before shop visit.

### Pitfall 5: Skipping `purchases` table “until IAP”
**What goes wrong:** First IAP week double-grants; schema fight with soft_purchases.
**Why it happens:** Pitfall 6 rationalization.
**How to avoid:** Ship empty UNIQUE token table in V7 (D-60 / ECON-05).
**Warning signs:** Migration PR says “IAP later, skip”.

### Pitfall 6: Presentation bleed into physics
**What goes wrong:** Theme SKU tweaks restitution “for feel”.
**Why it happens:** Tempting polish.
**How to avoid:** Code review gate — cosmetics may touch `Color` / sprite / trail drawable only; `TableConstants` and `SakaBody` fixture math unchanged. Unit test: two SKUs → identical impulse response in harness if applicable; at minimum assert fixture density constants unused by SKU map.
**Warning signs:** SKU JSON contains `mass` / `friction`.

## Code Examples

### MatchSnapshot grant fields (extend record)

```java
// Integration point: backend/.../session/MatchSnapshot.java [VERIFIED: codebase]
public record MatchSnapshot(
        String status,
        int playerScore,
        int botScore,
        // ... existing fields ...
        Integer reconnectSecondsLeft,
        int coinsGranted,   // NEW — viewer-specific; 0 if none
        int gemsGranted     // NEW — 0 omits GEMS line on client
) {}
```

Private WS: either per-seat fields in the frame or client uses `coinsGranted` from a seat-scoped snapshot (prefer **viewer-specific** values when broadcasting — send two personalized frames or include `grants: { hostId: {...}, joinerId: {...} }`). Planner pick: **map of playerId → grant** on `MatchSettled` is clearest for two seats.

### Soft purchase API (client)

```dart
// Extend client/lib/platform/api/nomad_api.dart [VERIFIED: codebase pattern]
Future<PurchaseResult> purchaseSku({
  required String skuId,
  required String idempotencyKey,
}) async {
  final Response res = await _dio.post(
    '/v1/shop/purchases',
    data: {'skuId': skuId, 'idempotencyKey': idempotencyKey},
  );
  // on 409 insufficient → map to errorInsufficientFunds
  return PurchaseResult.fromJson(res.data);
}
```

### ResultOverlay reward lines

```dart
// Extend ResultOverlay in pause_overlay.dart — insert under score pair [VERIFIED: codebase]
if (coinsGranted > 0)
  Text(l10n.rewardCoins(coinsGranted), style: _label, textAlign: TextAlign.center),
if (gemsGranted > 0)
  Text(l10n.rewardGems(gemsGranted), style: _label, textAlign: TextAlign.center),
// Shop TextButton secondary; onTap: context.go('/'); context.push('/shop');
```

### Idempotent ledger grant (sketch)

```java
public RewardGrant grantMatchRewards(MatchRewardCommand cmd) {
    String key = cmd.matchId() + ":" + cmd.playerId() + ":MATCH_REWARD";
    try {
        return insertGrant(cmd, key);
    } catch (DuplicateKeyException ex) {
        return readGrantByKey(key); // same amounts for overlay replay
    }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `players.coins INTEGER` mutate | Append-only ledger + wallet projection | Architecture research / Pitfall 6 | Audit + idempotency |
| Client settle POSTs delta | Server grants on terminal | SESS-01 / D-45 | Anti-cheat |
| Soft-lock shop on bind | Guest shop | D-51 (overrides FEATURES hypothesis) | Funnel keeps playing |
| Async module listeners for everything | Sync grant for UX-critical rewards | Modulith events docs vs D-45 | Overlay correctness |
| Skip IAP schema until PAY | Empty `purchases.token` UNIQUE | ECON-05 / Play security | No wallet rewrite |

**Deprecated/outdated:**
- FEATURES “soft-lock shop spend behind bind” for MVP — **not** adopted (CONTEXT specifics).
- SUMMARY / PITFALLS old “Phase 6 = economy” numbering — **ROADMAP Phase 4** is authoritative.
- Async-only Modulith listener as the **sole** grant mechanism — incompatible with D-45.

## Recommended reward table (Claude discretion)

Ship as constants in `economy` (tunable without UI change). Must satisfy win > loss > 0 and scarce GEMS [ASSUMED amounts — confirm in plan if owner wants different feel]:

| Outcome | Bot EASY COINS | Bot NORMAL | Bot HARD | Private COINS |
|---------|----------------|------------|----------|---------------|
| Win | 24 | 32 | 40 | 36 |
| Draw | 14 | 18 | 22 | 20 |
| Loss | 8 | 10 | 12 | 10 |

**GEMS:** on **win only**, grant **1 GEMS** with probability **3% / 5% / 8%** (EASY/NORMAL/HARD) and **6%** private; else 0. Never show `+0 GEMS`. Deterministic option for tests: `hash(matchId, playerId) % 100 < p`.

**Thin SKU set (discretion):** per category — 1 free `default` + 2 paid themes (prefer Gold + Neon for color; Ice + Fire for material; Space + ornament for ornament; one paid each for trail / table FX / victory / stick). Target **~15–20 SKUs**, not dozens. Prices: mostly COINS (80–400); 1–2 showcase GEMS SKUs (5–15 GEMS) so dual wallet is exercised.

## Open Questions (RESOLVED)

1. **Personalized vs shared `MatchSettled` grant payload**
   - What we know: two seats need different grants; one broadcast frame is used today.
   - **RESOLVED:** Embed `grants: { "<uuid>": { "coins": n, "gems": m } }` on `MatchSettled`; client picks own `playerId`. REST `MatchSnapshot` keeps viewer-specific `coinsGranted` / `gemsGranted`. Locked in **04-02-PLAN.md**.

2. **Guest mint vs lazy `ensureDefaults`**
   - What we know: defaults required before first match paint.
   - **RESOLVED:** Mint-time `economy.ensureDefaults(playerId)` from `GuestService` after `players.save` (one-way identity→economy). Locked in **04-01-PLAN.md**.

3. **Maven on PATH / reward table verify**
   - What we know: `mvn` not on raw PATH; repo has `mvnw.cmd`; Java works after `dev-env.ps1`.
   - **RESOLVED:** All plan verify commands use `.\mvnw.cmd` + `scripts/dev-env.ps1` (same as Phase 3). Exact COINS/GEMS amounts and gem probabilities stay Claude discretion per RESEARCH “Recommended reward table”; constants ship in `MatchRewardTable` under **04-02-PLAN.md**; verify toolchain locked from **04-01-PLAN.md**.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| JDK 21 (Corretto) | Backend build/tests | ✓ after `scripts/dev-env.ps1` | 21.0.11 | — |
| Flutter SDK | Client tests | ✓ at `~/develop/flutter` via dev-env | 3.47.x expected | — |
| Docker | Testcontainers Postgres 18 | ✓ 29.7.2 | — | — |
| `mvnw.cmd` | Backend verify | ✓ repo root | wrapper | Do not require global `mvn` |
| Global `mvn` | — | ✗ on PATH | — | Use wrapper |
| PostgreSQL client | Manual SQL | ✓ 17.7 | — | Optional; ITs use Testcontainers |
| Redis | — | n/a | — | **Do not use** |
| Play/App Store IAP tooling | — | n/a | — | Out of scope |

**Missing dependencies with no fallback:** none for Phase 4 implementation (wrapper + Docker + dev-env cover CI-like runs).

**Missing dependencies with fallback:** global `mvn` → `mvnw.cmd`.

Step 2.6 complete: external toolchain probed; no Redis/IAP required.

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Flutter `flutter_test` + JUnit Jupiter (Spring Boot 4.1 BOM) + Testcontainers |
| Config file | `client/analysis_options.yaml`; repo-root `mvnw.cmd -pl backend -am` |
| Quick run command | `. ./scripts/dev-env.ps1; .\mvnw.cmd -pl backend -am test -Dtest=ModularityTest,EconomyIT; Set-Location client; flutter test test/shop_wallet_test.dart` |
| Full suite command | `. ./scripts/dev-env.ps1; .\mvnw.cmd -pl harness,backend -am verify` + `Set-Location client; flutter test` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| ECON-01 | Terminal bot settle returns coinsGranted; replay same matchId does not double | integration | `.\mvnw.cmd -pl backend -am test -Dtest=EconomyIT#matchGrantIdempotent` | ❌ Wave 0 |
| ECON-01 | Leave / reconnect expiry also grants | integration | `EconomyIT#leaveAndDropGrant` | ❌ Wave 0 |
| ECON-02 | GET shop catalog returns all 7 categories + thin SKUs | integration | `EconomyIT#catalogHasSevenCategories` | ❌ Wave 0 |
| ECON-02 | Guest can purchase with COINS | integration | `EconomyIT#guestPurchase` | ❌ Wave 0 |
| ECON-03 | Equip persists; match create payload includes loadout; physics constants unchanged | integration + unit | `EconomyIT#equipOnCreate` + optional rules assert | ❌ Wave 0 |
| ECON-04 | Forged client balance / coinsDelta ignored; buy uses DB | integration | `EconomyIT#forgedBalanceRejected` | ❌ Wave 0 |
| ECON-05 | Double POST same idempotencyKey → one debit | integration | `EconomyIT#purchaseIdempotent` | ❌ Wave 0 |
| ECON-05 | `purchases` table exists with unique token (0 rows) | integration | `EconomyIT#purchasesTableUnique` | ❌ Wave 0 |
| UI | Catalog wallet + Shop; `/shop` grid; reward lines | widget | `flutter test test/shop_wallet_test.dart` `test/result_reward_test.dart` | ❌ Wave 0 |
| Modulith | `economy` module verify; no illegal cycles | unit | `ModularityTest` | ✅ extend |

### Sampling Rate

- **Per task commit:** quick command above (or narrower `-Dtest=…` for the touched IT)
- **Per wave merge:** full backend `verify` + `flutter test` for shop/catalog/result tests
- **Phase gate:** Full suite green before `/gsd-verify-work`

### Wave 0 Gaps

- [ ] `backend/.../EconomyIT.java` — covers ECON-01…05 server behaviors
- [ ] `client/test/shop_wallet_test.dart` — catalog chip + Shop route + empty/error
- [ ] `client/test/result_reward_test.dart` — `ResultOverlay` shows `+N COINS` / optional GEMS; Shop secondary link
- [ ] Flyway `V7__economy_ledger_shop.sql` — wallets, ledger, soft_purchases, purchases, cosmetic_skus, inventory, loadout + seed defaults
- [ ] ARB keys from 04-UI-SPEC (EN+RU)
- [ ] Framework install: none — use existing Testcontainers + flutter_test

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | yes (existing) | Guest JWT on all `/v1/wallet` and `/v1/shop/*`; no new public shop endpoints |
| V3 Session Management | no new | Refresh rotation unchanged; do not put balances in secure storage as authority |
| V4 Access Control | yes | `playerId` from JWT only; cannot equip/buy for another player; seat loadout read on match create is server-side |
| V5 Input Validation | yes | `skuId` allow-list / FK; currency enum; idempotencyKey length/format; reject client `coinsDelta` / balance fields |
| V6 Cryptography | no new soft-currency crypto | Existing HS256; never hand-roll; IAP verify later with platform APIs |

### Known Threat Patterns for economy + shop

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Client-granted coins / forged settle | Tampering | No `coinsDelta`; grants only on server terminal (D-45, Pitfall 6) |
| Double-spend purchase / retry | Tampering | Unique `idempotency_key` (ECON-05) |
| Insufficient funds race | Tampering | `SELECT … FOR UPDATE` wallet row + single TX debit |
| Buy then refund via crash mid-TX | Tampering | One TX: soft_purchases + ledger + inventory |
| Enumerate / buy unknown SKU | Elevation | FK to `cosmetic_skus`; unknown → 404 |
| IAP token replay (future) | Tampering | Empty UNIQUE `purchases.token`; grant only PURCHASED later [CITED: Play security] |
| P2W cosmetic stats | Elevation / spoofing fairness | Schema + API forbid gameplay fields (ECON-03) |
| Shop over stolen WS ticket | Elevation | Shop is REST+JWT only; WS remains match-only |

`security_enforcement` is enabled in `.planning/config.json` — this section is required.

## Sources

### Primary (HIGH confidence)

- Live codebase: `MatchService`, `MatchSnapshot`, `ResultOverlay`, `router.dart`, `nomad_api.dart`, `catalog_page.dart`, `AlchikiMatchGame` / `SakaBody`, Flyway V1–V6, `SecurityConfig`, `ThrowAuthorityIT` [VERIFIED: filesystem]
- `.planning/phases/04-economy-cosmetic-shop/04-CONTEXT.md` D-45…D-61 [VERIFIED]
- `.planning/phases/04-economy-cosmetic-shop/04-UI-SPEC.md` (approved contract) [VERIFIED]
- `.planning/REQUIREMENTS.md` ECON-01…05 [VERIFIED]
- `.planning/research/{ARCHITECTURE,STACK,PITFALLS,FEATURES}.md` [VERIFIED]
- Spring Modulith application events [CITED: https://docs.spring.io/spring-modulith/reference/events.html]
- Spring Framework JdbcClient [CITED: https://docs.spring.io/spring-framework/reference/data-access/jdbc/core.html#jdbc-JdbcClient]
- Play Billing security — `purchaseToken` unique / PK [CITED: https://developer.android.com/google/play/billing/security]

### Secondary (MEDIUM confidence)

- WebSearch cross-check of Modulith `@ApplicationModuleListener` async semantics vs D-45 sync need [CITED: Modulith docs + classify-confidence websearch --verified → MEDIUM]
- FEATURES.md dual-currency HUD / no wager / no gacha (product research) [CITED: FEATURES.md]

### Tertiary (LOW confidence)

- Exact COINS/GEMS numbers and gem probabilities in “Recommended reward table” [ASSUMED]
- Exact thin SKU count (~15–20) and price bands [ASSUMED]
- classify-confidence for raw `webfetch` provider → LOW; official Spring/Play URLs still treated as CITED primary content

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Reward COINS table (24/32/40 win ladder, etc.) | Recommended reward table | Owner may want higher/lower economy pacing — tune constants only |
| A2 | GEMS win-only with 3–8% chance for +1 | Recommended reward table | Too rare → GEMS SKUs unsellable; too common → floods premium |
| A3 | ~15–20 SKUs, mostly COINS-priced | Recommended reward table / ECON-02 | Scope creep if planner seeds dozens |
| A4 | `grants` map on WS `MatchSettled` is preferred over dual personalized frames | Open Questions | Either works; pick one in PLAN and test |
| A5 | No new Flutter/`uuid` package | Standard Stack | If team standardizes on `uuid`, add via pub.dev (not npm seam) |

**If this table is empty:** N/A — five discretion items need plan-time confirmation only if owner overrides defaults.

## Metadata

**Confidence breakdown:**
- Standard stack: **HIGH** — locked pins verified in pubspec/pom; JdbcClient/Modulith cited from official docs
- Architecture: **HIGH** — settle hooks and client seams verified in code; sync-grant pattern forced by D-45
- Pitfalls: **HIGH** — Pitfall 6 + multi-exit settle paths confirmed in `MatchService`

**Research date:** 2026-09-10
**Valid until:** 2026-10-10 (30 days; stack stable; reward constants may tune in UAT)
