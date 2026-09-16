# Phase 7: Bind, Ranked + Ship - Research

**Researched:** 2026-09-14
**Domain:** Guest→bound identity (Argon2id + refresh), Ranked Glicko-2 matchmaking (both titles, no bots), ranked reconnect budgets, skill leaderboards + soft seasons, EventSink analytics logs, GHA + PROD compose
**Confidence:** HIGH for codebase seams and product locks (D-92…D-108, prior phases). MEDIUM for Glicko period/idle-RD and CI action pins (verified against Glickman + setup-java docs; Flutter/Java not on researcher PATH this session).

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-92:** Soft **bind prompt after first Alchiki bot win** (FEATURES funnel) — sheet/dialog, dismissible; not a splash wall. Always reachable later from **Profile** (Bind / Sign in / Log out).
- **D-93:** Bind **links username + password to the same `playerId`**. Username taken → **409** with a clear **Sign in** path. After sign-in to an existing bound account: **never sum/max wallets, cosmetics, XP, SoftElo, or Glicko** onto a non-empty target. Optional one-time import only if the signed-in target has **zero matches and zero spend** (PITFALLS) — otherwise keep the signed-in account as-is and drop the guest device row only after explicit confirm when progress would be lost.
- **D-94:** Password: **min 8 characters**; store with a modern password hash (Argon2id or bcrypt — planner picks one stack-standard). Refresh tokens already rotate (AUTH-03); reuse that path for bound sessions. No email/phone verification in this phase (forgot-password is deferred).
- **D-95:** **Log out** clears access/refresh on device and returns the UI to a guest-capable catalog; **device guest identity remains** until bind succeeds or reinstall (AUTH-04). Bound players stay signed in across restarts via rotating refresh (AUTH-03).
- **D-96:** Soft-lock **Ranked enqueue + global leaderboards** behind bind. **Do not** re-lock Casual bot / private / QM or the existing guest shop — those stay open for guests (FEATURES soft-lock Ranked/boards; shop already shipped for guests in Phase 4).
- **D-97:** Ranked ships for **both live titles** — Alchiki and Stick Pull — with **per-game FIFO** queues (same discriminator pattern as Casual D-79). Bind required; enqueue rejects guests.
- **D-98:** **No bot opponent** and **no empty-queue bot/invite fallback** in Ranked. Searching UI can wait indefinitely with Cancel; never a 60s fail-then-bot. Cosmetics ignored for rating (already presentation-only).
- **D-99:** Ranked rematch is **out of MVP** (FEATURES optional later). After settle → boards/catalog/Play again = new Ranked search, not dual-accept rematch.
- **D-100:** Stick Pull Ranked adopts FEATURES false-start rule: **first false start → stamina starts at 70%**; **second → rated forfeit**. Casual Stick Pull keeps D-90 ignore.
- **D-101:** Ranked grace: **Alchiki 18s**, **Stick Pull 12s** per drop (ROADMAP ~15–20s band + Stick Pull shorter tug; FEATURES checklist). Casual stays **30s / 8s**. Consented leave = **0s** rated loss.
- **D-102:** **Aggregate pause budget** per Ranked match: **Alchiki 45s**, **Stick Pull 20s** (sum of grace pauses). When budget is exhausted, the **next** disconnect is **immediate rated forfeit** (stops pause-griefing). Clocks/tug deadline **pause** during grace (D-41 / Phase 6 CR clock freeze).
- **D-103:** On grace expiry or budget forfeit: **rated loss** for the dropped seat; remaining player **rated win**. **No bot-fill**. Opponent HUD shows reconnect + server timer (existing chrome).
- **D-104:** Vendored **Glicko-2** in-repo (STACK): defaults **r=1500, RD=350, σ=0.06, τ=0.5**. Rating is **per game** (Alchiki vs Stick Pull separate). Update **only on Ranked settle** (including rated forfeit/draw rules). SoftElo casual **unchanged** (D-75 fork).
- **D-105:** **Seasons:** calendar **quarter** (~90 days). Soft reset at season boundary: move rating toward 1500 (e.g. `1500 + 0.5*(r-1500)`) and **inflate RD** toward 350 — exact formula Claude’s discretion within “soft, not wipe”. All-time board keeps lifetime peak / all-time rated score separately from season rating.
- **D-106:** Leaderboards: **bound players only**; filter by **game**; toggle **current season vs all-time**. **Never** rank by coins/gems. Entry: **Profile → Boards** plus a catalog/profile chip for bound users (PRES-02). Top-N list (~50–100) is enough for MVP.
- **D-107:** Backend **EventSink**: emit **APP_STARTED, REGISTERED, LOGIN, MATCHMAKING_STARTED, MATCH_FOUND, MATCH_STARTED, MATCH_FINISHED, MATCH_ABANDONED, ITEM_PURCHASED** as structured JSON logs (+ optional Postgres append-only table if cheap). **No** Amplitude/Firebase/Grafana SaaS in this phase.
- **D-108:** **Ship harden:** GitHub Actions on PR — Maven backend tests + Flutter analyze/test; **docker-compose PROD** = Postgres + single app JAR; Android is the proof release target; keep iOS target compilable. **No** K8s, Redis-as-truth, or multi-service split.

### Claude's Discretion
- Exact bind sheet copy/timing animation; password hasher choice (Argon2id vs bcrypt); Glicko period (calendar day vs N games) within D-104.
- Soft-reset coefficient and all-time storage schema within D-105.
- Whether Ranked queue shares `CasualQueueService` with a `mode=RANKED` flag or a sibling service — product locks are D-97…D-99.
- CI matrix runners / cache; EventSink table vs log-only for ANLT-01.
- Ranked Alchiki draw policy when neither side scores (FEATURES last-knock-out / Glicko draw) — pick one consistent with Glicko-2 and document in plan.

### Deferred Ideas (OUT OF SCOPE)
- Forgot-password / email recovery (FEATURES v1.x)
- OAuth as *additional* bind method
- Bind GEMS reward / daily COINS if bind rate is low
- Ranked rematch dual-accept
- Suspect-tap MMR penalty on Ranked Stick Pull (log-only stays)
- Redis queues, K8s, analytics SaaS, Prometheus/Grafana
- Friends / country boards, tournaments, season pass
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| AUTH-02 | Bind username/password to same guest `playerId`; keep progress; no sum | Extend stub `credentials` + `BindService`; 409 taken; Argon2id; same `PlayerEntity` |
| AUTH-03 | Login + stay signed in via rotating refresh | `POST /login`; fix `TokenService.rotate` to honor `guest` flag; reuse refresh table |
| AUTH-04 | Log out; guest-capable device remains | Revoke refresh; clear client tokens; mint **new** guest; bound row stays server-side |
| MODE-04 | Ranked both games; Glicko; no bots; cosmetics ignored | `RankedQueueService` + `createRankedMatch`; `rating` Glicko on settle only |
| SESS-03 | Ranked reconnect shorter + pause budget → rated forfeit | Extend `ReconnectPolicy` 18/12 + budgets 45/20; heap pause accumulator |
| LEAD-01 | Global boards filtered by game | `GET /v1/boards?game=&scope=`; bound-only SQL |
| LEAD-02 | Season vs all-time toggle | Season key `YYYY-Qn` vs all-time peak columns |
| LEAD-03 | Soft season reset; no coin ladder; guests excluded | Quarterly job/on-read ensure; never `ORDER BY` wallets |
| ANLT-01 | Nine event types in backend logs (no SaaS) | `analytics.EventSink` → JSON log + `analytics_events` |
</phase_requirements>

## Summary

Phase 7 closes the v1 loop: **bind the guest**, open **honest Ranked** on Alchiki + Stick Pull, expose **skill boards**, emit **thin analytics**, and make the repo **releasable** (CI + PROD compose). The platform already has guest mint + rotating refresh, SoftElo (casual-only), per-game casual FIFO, game-aware reconnect (30s / 8s), profile XP/W/L, and Stick Pull false-start **ignore** (D-90). Missing: password credentials on the stub `credentials` table, Ranked mode/queues/Glicko, ranked reconnect budgets, boards REST/UI, EventSink, `.github/workflows`, Dockerfile + PROD compose (DEV `compose.yaml` is Postgres-only today).

Critical scout findings the planner must not miss: (1) `TokenService.rotate` always re-issues `guest=true` — breaks AUTH-03 after bind until fixed; (2) `credentials` exists as `player_id` PK only — needs username/hash migration; (3) `ProfileService.recordSettlement` applies SoftElo only for `CASUAL` — Ranked must call a **separate** `rating` path; (4) `isHumanPvP` is `PRIVATE|CASUAL` only — Ranked must be added carefully without enabling Ranked rematch (D-99); (5) no `.github/`, no Dockerfile, no `rating`/`analytics` packages yet.

**Primary recommendation:** Ship identity bind/login/logout first (fix token guest claim), then Ranked queue + settle→Glicko + reconnect budgets, then boards + EventSink, then GHA + PROD compose — all against approved `07-UI-SPEC.md`.

### Claude discretion locks (yolo — planner MUST use these)

| Topic | Decision |
|-------|----------|
| Password hasher | **Argon2id** via `Argon2PasswordEncoder.defaultsForSpringSecurity_v5_8()` as `DelegatingPasswordEncoder` **idForEncode** `argon2@SpringSecurity_v5_8` — **not** `PasswordEncoderFactories` default bcrypt [CITED: docs.spring.io/spring-security/reference/features/authentication/password-storage.html] |
| BouncyCastle | Declare `org.bouncycastle:bcprov-jdk18on` (Boot BOM-managed if present) — Spring docs: Argon2 encoder **requires** BouncyCastle [CITED: same] |
| Glicko period | **One Ranked settle = one rating period** (m=1 opponent). Defaults **r=1500, RD=350, σ=0.06, τ=0.5**. Vendor algorithm under `rating/internal` — **no** Maven Glicko JAR [CITED: glicko.net/glicko/glicko2.pdf via WebSearch] |
| Soft reset | At quarter boundary: `r' = round(1500 + 0.5 * (r - 1500))`; `RD' = min(350, RD + 0.5 * (350 - RD))`; σ unchanged. Season key **`YYYY-Qn`** (UTC) |
| All-time storage | Table `glicko_ratings(player_id, game, season_key, rating, rd, sigma, …)` + columns / sibling `all_time_rating`, `all_time_peak`, `all_time_matches`. Season board = current season row; all-time board = `all_time_peak` (update peak on every Ranked settle if higher) |
| Ranked queue | **Sibling** `RankedQueueService` (clone FIFO pattern from `CasualQueueService`) — **do not** add `mode=RANKED` into CasualQueue (prevents bot/invite leakage) |
| Ranked match create | `MatchService.createRankedMatch(host, joiner, game)` → `mode=RANKED`; no rematch window for Ranked |
| Alchiki Ranked draw | Keep FEATURES: **last successful knock-out wins**; if neither scored a knock-out → **DRAW** with Glicko scores **0.5/0.5** |
| Stick Pull Ranked false-start | Server counter on Ranked only: 1st pre-GO → set stamina baseline **0.70**; 2nd → settle rated forfeit for offender. Casual keeps D-90 ignore |
| Pause budget | Heap field on live match: `pauseUsedMs`; each grace start accrues until rejoin/expiry; if `pauseUsedMs >= budget` then next drop → immediate forfeit (0s grace) |
| EventSink | **Both** structured JSON log (`type`, `playerId`, `matchId`, `attrs`, `ts`) **and** append-only `analytics_events` — sink must **never** throw into settle TX (catch+log) |
| CI | Single workflow `.github/workflows/ci.yml`: job `backend` (`./mvnw -pl backend -am verify`) + job `client` (`flutter analyze` + `flutter test`); `actions/setup-java` Temurin **21** `cache: maven`; `subosito/flutter-action@v2` channel stable **flutter-version: 3.47.2** (or repo pin) `cache: true`; trigger `pull_request` |
| PROD compose | `compose.prod.yaml`: `postgres:18.6` + `app` service from local `Dockerfile` (eclipse-temurin:21-jre + Boot JAR); env `SPRING_DATASOURCE_*`, `NOMAD_JWT_SECRET`; healthcheck `/actuator/health`. Keep root `compose.yaml` as DEV Postgres-only |
| Boards Top-N | **100** |
| Bind prompt prefs | `bind.prompt.seen` in SharedPreferencesAsync (mirror howto keys) |
| Logout after bind | Revoke all refresh rows for player → clear secure storage → **mint new guest** → catalog. Bound account remains for Sign in |
| Empty-target import | Allow one-time guest→bound import **only if** target has `matches==0` **and** ledger spend==0; else confirm drop guest (UI-SPEC) — **never sum** |
| SoftElo | **Untouched**; Ranked never calls `SoftElo` |
| Modulith packages | Add `com.nomadgames.rating` + `com.nomadgames.analytics` (public API + `internal/`) |

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Bind / login / logout / password hash | API / Backend (`identity`) | Browser forms | Credentials + JWT SoT; client stores refresh only |
| Soft-lock Ranked/boards | Browser / Client | API 403 backup | UX gate (D-96); server still rejects guests |
| Ranked enqueue / pair | API (`matchmaking`) | Browser searching | FIFO in-process; no Redis |
| Ranked match + settle | API (`session` + games) | Browser / Flame | SESS-01; cosmetics ignored for rating |
| Glicko update | API (`rating`) | — | Only on Ranked settle event |
| SoftElo / XP | API (`profile`) | Browser display | Casual fork stays (D-75 / D-104) |
| Reconnect grace + pause budget | API (`session`) | Browser banners | Server timer SoT (D-101…D-103) |
| Leaderboards | API (`profile` or `rating`) | Browser `/boards` | Postgres ORDER BY; bound filter |
| Season soft reset | API / Backend job or ensure-on-read | — | Quarterly policy (D-105) |
| EventSink | API (`analytics`) | — | Logs (+ table); no SaaS |
| CI / PROD compose | CDN / Static + ops files | — | GHA + Docker; not in-app UI |
| Bind sheet / boards chrome | Browser / Flutter | — | 07-UI-SPEC |

## Project Constraints (from .cursor/rules/ / PROJECT)

No `.cursor/rules/` in repo root. Actionable locks from PROJECT / STACK / prior RESEARCH / 07-UI-SPEC:

- **Authority:** Server authors scores, ratings, wallets, settle; client never POSTs Glicko/score.
- **Guest-first:** Casual/bot/private/shop stay open (D-96); Ranked/boards soft-locked.
- **No Redis day one; no K8s; modular monolith.**
- **Passwords:** Argon2id (STACK); refresh rotate opaque SHA-256 (already).
- **Glicko-2 vendored** — no Maven Glicko dependency.
- **SoftElo ≠ Glicko** (D-75 / D-104).
- **i18n EN+RU** for every new string (07-UI-SPEC keys).
- **PRES-02** palette; no purple/AI chrome; text-labeled controls ≥48dp.
- **UI contract:** Approved `07-UI-SPEC.md` extends 01–06 — planner must not invent alternate Ranked/bind chrome.
- **No nested `.git` under nomad-game.**

No project skills under `.cursor/skills/`. Knowledge graph: **absent**.

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Flutter SDK | **3.47.x** / Dart **3.13.x** | Bind sheet, Ranked search, boards, soft-lock | Phase lock [VERIFIED: client/pubspec.yaml + STACK] |
| Flame | **1.38.2** | Existing match GameWidgets only | No new engine for boards [VERIFIED: prior RESEARCH] |
| go_router / riverpod / dio / secure_storage | existing pins | Routes `/boards`, auth APIs, tokens | Extend — do not replace |
| Spring Boot | **4.1.1** | REST + WS + security | [VERIFIED: backend/pom.xml] |
| Spring Security | BOM via Boot 4.1.1 | JWT + Argon2id | [CITED: Spring Password Storage] |
| Spring Modulith | **2.1.1** | New `rating` / `analytics` modules | STACK / ARCHITECTURE |
| PostgreSQL + Flyway | **18.6** / existing | credentials, glicko, analytics_events, seasons | DEV compose already `postgres:18.6` [VERIFIED: compose.yaml] |
| Glicko-2 | vendored ~200 LOC | Ranked rating | STACK; no Central JAR [CITED: glicko.net PDF] |
| JUnit + Testcontainers | Boot BOM | BindIT, RankedQueueIT, GlickoTest, ReconnectRankedIT, BoardsIT | Follow GuestIdentityIT / CasualQueueIT / ReconnectIT |
| GitHub Actions | `setup-java` + `flutter-action` | PR CI | D-108 [CITED: actions/setup-java README] |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `org.bouncycastle:bcprov-jdk18on` | Boot BOM / Central | Argon2 runtime | If not already transitive — required by `Argon2PasswordEncoder` [CITED: Spring docs] |
| Docker Compose v2 | host | PROD postgres+app | `compose.prod.yaml` |
| Maven Wrapper | root `./mvnw` | CI + local | [VERIFIED: mvnw present at repo root] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Argon2id | bcrypt (factory default) | STACK forbids greenfield bcrypt-only — **reject** |
| Vendored Glicko-2 | Maven `goochjs/glicko2` | Not Central / idle — **reject** (STACK) |
| Sibling RankedQueueService | `CasualQueueService` + mode flag | Risk of bot fallback + guest path — **reject** |
| SoftElo for Ranked | Dual-use SoftElo | D-75/D-104 fork — **reject** |
| Analytics SaaS | EventSink | D-107 / ANLT-01 — **reject** |
| Redis Ranked queue | In-process FIFO | Out of scope — **reject** |
| K8s / multi-JAR | Single JAR compose | D-108 — **reject** |

**Installation:**

```bash
# Prefer zero new pub packages.
# Backend — only if BouncyCastle not already on classpath after Argon2 smoke test:
#   add org.bouncycastle:bcprov-jdk18on (version from Spring Boot 4.1.1 BOM)
# Vendor Glicko-2 sources under backend/.../rating/internal/ — no Maven artifact.
```

**Version verification:** Flutter/Java not on researcher PATH this session; pins from `client/pubspec.yaml`, `backend/pom.xml`, `compose.yaml` [VERIFIED: files on disk]. Argon2 API from official Spring Security password-storage page [CITED]. Glicko defaults from Glickman PDF [CITED via WebSearch MEDIUM].

## Package Legitimacy Audit

> Phase 7 installs **no new npm/PyPI/crates/pub packages**. Optional Maven dep is BouncyCastle (Spring-documented companion for Argon2). `gsd-tools package-legitimacy` supports only npm|pypi|crates — Maven audited via official Spring docs + Boot BOM.

| Package | Registry | Age | Downloads | Source Repo | Verdict | Disposition |
|---------|----------|-----|-----------|-------------|---------|-------------|
| *(none npm/pub)* | — | — | — | — | N/A | No install |
| `org.bouncycastle:bcprov-jdk18on` | Maven Central | long-lived | high | bouncycastle.org | OK (Spring-cited) | Add **only if** missing transitively; planner smoke-tests Argon2 encode first |

**Packages removed due to [SLOP] verdict:** none  
**Packages flagged as suspicious [SUS]:** none  

*Do not add third-party Glicko JARs discovered via search — vendor algorithm only.*

## Architecture Patterns

### System Architecture Diagram

```
Guest device
  │ POST /v1/identity/guest (existing)
  ▼
Player(guest=true) + refresh
  │ first Alchiki bot win → bind sheet (client)
  │ POST /v1/identity/bind {username,password}
  ├─ 200 → guest=false, credential row, REGISTERED event, same playerId
  └─ 409 → Sign in path
        POST /v1/identity/login → tokens for bound player (no wallet sum)
  │
  ├─ Ranked CTA (bound) → POST /v1/matchmaking/ranked {game}
  │     RankedQueueService FIFO → MATCH_FOUND → createRankedMatch
  │     WS play → settle → rating.Glicko2.update + EventSink MATCH_*
  │     drop → grace 18|12 + pause budget → rated forfeit (no bot-fill)
  │
  ├─ GET /v1/boards?game=&scope=season|all_time → top 100 bound
  │
  └─ Logout → revoke refresh → mint new guest → catalog
```

### Recommended Project Structure

```
backend/src/main/java/com/nomadgames/
├── identity/
│   ├── BindService.java / AuthController.java
│   ├── PasswordConfig.java          # DelegatingPasswordEncoder Argon2id
│   ├── TokenService.java            # FIX rotate(guest from DB)
│   └── internal/CredentialEntity.java
├── matchmaking/
│   ├── RankedQueueService.java      # NEW sibling FIFO
│   └── CasualQueueService.java      # unchanged product behavior
├── rating/
│   ├── RatingService.java           # public settle hook
│   └── internal/Glicko2.java        # vendored algorithm
├── analytics/
│   ├── EventSink.java
│   └── internal/AnalyticsJdbc.java
├── profile/                         # boards read API OR rating owns boards
├── session/
│   ├── MatchService.java            # createRankedMatch; isHumanPvP+Ranked settle
│   └── internal/ReconnectPolicy.java # mode+game grace + budgets
└── games/stickpull/StickPullSim.java # Ranked false-start branch

client/lib/
├── platform/auth/                   # bind/login/logout API + session_store
├── profile/                         # Bind/Sign in/Log out chrome
├── boards/boards_page.dart          # NEW /boards
└── catalog/                         # Ranked CTAs + soft-lock + Boards chip

.github/workflows/ci.yml             # NEW
Dockerfile                           # NEW
compose.prod.yaml                    # NEW
```

### Pattern 1: Bind links same playerId (no merge)
**What:** Guest `Player` gains a unique username credential; `guest=false`.  
**When to use:** AUTH-02 happy path.  
**Example:**

```java
// Pattern from ARCHITECTURE.md + PITFALLS Pitfall 5 — implement in BindService
@Transactional
public TokenPair bind(UUID playerId, String username, String rawPassword) {
  if (rawPassword == null || rawPassword.length() < 8) throw badRequest("password");
  if (credentials.existsByUsernameIgnoreCase(username)) throw conflict("username_taken");
  PlayerEntity p = players.findById(playerId).orElseThrow();
  credentials.save(new CredentialEntity(playerId, username, encoder.encode(rawPassword)));
  p.setGuest(false);
  eventSink.emit("REGISTERED", playerId, null, Map.of("username", username));
  return tokens.issue(playerId, false);
}
```

### Pattern 2: Ranked settle → Glicko only
**What:** After terminal Ranked match, idempotent rating claim then Glicko update; SoftElo skipped.  
**When to use:** MODE-04 / LEAD-*.  

```java
// Source: D-104 + ProfileService.recordSettlement casual gate (extend, don't replace SoftElo)
if ("RANKED".equals(mode)) {
  ratingService.recordRankedSettlement(matchId, game, seats); // Glicko win/loss/draw/forfeit
} else {
  profile.recordSettlement(matchId, mode, game, seats); // existing XP + SoftElo for CASUAL
}
// Ensure Ranked still gets XP/W/L — either profile always increments stats, Elo only if CASUAL
```

### Pattern 3: Mode-aware reconnect + pause budget
**What:** Grace and budget keyed by `(mode, game)`.  
**When to use:** SESS-03.  

```java
// Extend ReconnectPolicy — D-101 / D-102
public static int graceSeconds(String mode, String game) {
  boolean ranked = "RANKED".equals(mode);
  if ("STICK_PULL".equals(game)) return ranked ? 12 : 8;
  return ranked ? 18 : 30;
}
public static int pauseBudgetSeconds(String mode, String game) {
  if (!"RANKED".equals(mode)) return Integer.MAX_VALUE; // no budget casual
  return "STICK_PULL".equals(game) ? 20 : 45;
}
```

### Anti-Patterns to Avoid
- **Wallet/max/sum on sign-in:** PITFALLS #5 — always 409 Sign in / confirm drop guest.
- **Ranked bot fallback:** D-98 — searching waits forever.
- **Single reconnect constant:** PITFALLS #4 — mode+game policy required.
- **Updating SoftElo on Ranked:** D-104 fork.
- **TokenService.rotate forcing guest=true:** breaks bound sessions — **must fix**.
- **Enabling Ranked rematch via `isHumanPvP`:** D-99 — Ranked settle must skip RematchWindow.
- **Coin-ordered boards:** LEAD-03 forbidden.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Password hashing | Custom PBKDF/SHA | Spring `Argon2PasswordEncoder` + Delegating | Salt/params/encoding id format |
| Glicko math | Elo / TrueSkill | Vendored Glicko-2 | Sparse play needs RD (STACK) |
| Analytics platform | Amplitude/Firebase | `EventSink` | ANLT-01 / D-107 |
| Ranked matchmaking | Redis ZSET | In-process FIFO sibling | One JVM; Redis later |
| Auth server | Keycloak / OAuth | Existing JWT + refresh | STACK |
| CI from scratch scripts | Ad-hoc bash only | GHA setup-java + flutter-action | D-108 |

**Key insight:** Bind and Ranked are **policy + seams** on existing identity/session/profile — not a new platform. The dangerous complexity is **no-sum identity** and **pause-budget reconnect**, not inventing new engines.

## Common Pitfalls

### Pitfall 1: Guest→bound merge / sum
**What goes wrong:** Smurf coin laundering or lost cosmetics.  
**Why:** Treating bind as “create user B + merge”.  
**How to avoid:** Same `playerId`; 409; no-sum tests with two seeded wallets.  
**Warning signs:** Dual PK `guest_id`/`user_id`; `balance = max(a,b)`.

### Pitfall 2: `TokenService.rotate` always guest
**What goes wrong:** Bound JWT claims `guest=true`; Ranked enqueue accepts wrongly or profile wrong.  
**Why:** Current code hardcodes `issue(..., true)` on rotate [VERIFIED: TokenService.java].  
**How to avoid:** Look up `PlayerEntity.isGuest()` on rotate/login/bind.  
**Warning signs:** IT login→refresh still has `guest: true`.

### Pitfall 3: Pause-griefing without aggregate budget
**What goes wrong:** Infinite 18s pauses stall opponent.  
**Why:** Per-drop grace resets without budget (MiniTon pattern).  
**How to avoid:** D-102 budgets; next drop immediate forfeit.  
**Warning signs:** Only `graceSeconds` constant for Ranked.

### Pitfall 4: Casual SoftElo overwritten by Glicko
**What goes wrong:** Profile hero rating jumps; casual MMR polluted.  
**Why:** Single rating column.  
**How to avoid:** Separate `glicko_*` storage; SoftElo columns untouched.  
**Warning signs:** `soft_rating` changes after Ranked-only settle.

### Pitfall 5: Ranked rematch accidentally enabled
**What goes wrong:** Dual-accept After Ranked (D-99 forbidden).  
**Why:** Broadening `isHumanPvP` to include RANKED for settle/WS also opens rematch.  
**How to avoid:** Split helpers: `isHumanPvPWire` vs `allowsRematch` (PRIVATE|CASUAL only).  
**Warning signs:** RematchIT greens for RANKED.

### Pitfall 6: CI without wrapper / wrong Java
**What goes wrong:** PR red on agents without global `mvn`/`flutter`.  
**Why:** Root has `./mvnw` but no `.github` yet; researcher PATH lacked java/flutter.  
**How to avoid:** Workflow uses `./mvnw` + pinned flutter-action; document `scripts/dev-env.ps1` for local.

## Code Examples

### Argon2id encoder bean

```java
// Source: https://docs.spring.io/spring-security/reference/features/authentication/password-storage.html
@Bean
PasswordEncoder passwordEncoder() {
  String id = "argon2@SpringSecurity_v5_8";
  Map<String, PasswordEncoder> encoders = new HashMap<>();
  encoders.put(id, Argon2PasswordEncoder.defaultsForSpringSecurity_v5_8());
  return new DelegatingPasswordEncoder(id, encoders);
}
```

### Glicko-2 defaults (vendored)

```java
// Source: Glickman Glicko-2 PDF — r=1500, RD=350, σ=0.06, τ=0.5
public final class Glicko2 {
  public static final double DEFAULT_R = 1500;
  public static final double DEFAULT_RD = 350;
  public static final double DEFAULT_VOLATILITY = 0.06;
  public static final double TAU = 0.5;
  public static final double SCALE = 173.7178;
  // update(player, opponent, score) with score in {0, 0.5, 1}
}
```

### Security permit list extension

```java
// Extend SecurityConfig — login/bind may be authenticated (bind) or permit login
.requestMatchers(POST, "/v1/identity/guest", "/v1/identity/refresh", "/v1/identity/login")
.permitAll()
// POST /v1/identity/bind requires authenticated guest JWT
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Elo-only | SoftElo casual + Glicko Ranked | Phase 5 / 7 | Honest sparse Ranked |
| Guest-only JWT | Bind + login | Phase 7 | Progress survives devices |
| One reconnect policy | Mode+game + pause budget | Phase 3/6/7 | Fair mobile Ranked |
| No CI | GHA on PR | Phase 7 | Releasable (D-108) |
| Analytics SaaS | EventSink logs+table | ARCHITECTURE | Ship without platform tax |

**Deprecated/outdated:**
- Maven Glicko JARs for this monolith — vendor instead (STACK).
- `PasswordEncoderFactories` bcrypt default for **new** encodes — use Argon2 idForEncode.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | BouncyCastle must be explicitly declared (may already be transitive) | Standard Stack | Duplicate dep or missing at runtime — smoke-test Argon2 in Wave 0 |
| A2 | Flutter CI pin `3.47.2` matches local SDK used in Phase 1 | CI | Analyzer skew — adjust to exact repo-documented pin |
| A3 | XP/W/L should still increment on Ranked (rating separate) | Architecture | If product wanted Ranked-only Glicko without XP — confirm; yolo = XP yes, SoftElo no |
| A4 | New guest mint on logout is correct reading of D-95/AUTH-04 after bind | Auth | Alternative “anonymous replay of bound id” would leak Ranked — reject |

**If empty verified-only:** Not empty — A1–A4 need planner awareness; A3/A4 are yolo-locked above.

## Open Questions (RESOLVED)

> Mode: **yolo** — gray areas locked below; planner must not reopen.

1. **Password hasher Argon2id vs bcrypt?** → **RESOLVED: Argon2id** (`argon2@SpringSecurity_v5_8`).
2. **Glicko period calendar day vs N games?** → **RESOLVED: one Ranked settle = one period** (m=1).
3. **Soft-reset coefficient / all-time schema?** → **RESOLVED: 0.5 pull to 1500 + RD halfway to 350; season rows + `all_time_peak`.**
4. **Ranked queue sibling vs mode flag?** → **RESOLVED: sibling `RankedQueueService`.**
5. **EventSink table vs log-only?** → **RESOLVED: both JSON logs + `analytics_events`.**
6. **Alchiki Ranked draw when neither scores?** → **RESOLVED: last knock-out wins; else Glicko draw 0.5/0.5.**
7. **CI runners/cache?** → **RESOLVED: ubuntu-latest; setup-java Temurin 21 maven cache; flutter-action 3.47.2 cache.**
8. **Logout guest identity?** → **RESOLVED: mint new guest after revoke; bound account stays for Sign in.**

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Node | gsd-tools | ✓ | v24.18.0 | — |
| Docker | PROD compose / Testcontainers | ✓ | 29.7.2 | — |
| Maven Wrapper | Backend CI/build | ✓ | root `./mvnw` | — |
| Java 21 on PATH | Local researcher shell | ✗ | — | Use `scripts/dev-env.ps1` / CI Temurin 21 [ASSUMED script exists from Phase 1 STATE] |
| Flutter on PATH | Local researcher shell | ✗ | — | CI flutter-action; local via Phase 1 stable clone |
| Global `mvn` | — | ✗ | — | Always `./mvnw` |
| `.github/workflows` | D-108 | ✗ | — | **Create** in this phase |
| Dockerfile / compose.prod | D-108 | ✗ | — | **Create**; DEV `compose.yaml` Postgres-only exists |
| EventSink / rating pkgs | ANLT-01 / MODE-04 | ✗ | — | **Create** modules |
| Postgres image | DEV/PROD | ✓ via compose | 18.6 | — |

**Missing dependencies with no fallback:**
- None blocking planning — CI/Docker create is in-phase work; local Java/Flutter absence is agent PATH only.

**Missing dependencies with fallback:**
- Global mvn/java/flutter → wrapper + GHA + `scripts/dev-env.ps1`.

## Validation Architecture

> `workflow.nyquist_validation` is **true** in `.planning/config.json`.

### Test Framework

| Property | Value |
|----------|-------|
| Framework | JUnit 5 + Spring Boot Test / Testcontainers (backend); `flutter_test` (client) |
| Config file | `backend/pom.xml` Surefire defaults; client `flutter_test` |
| Quick run command | `./mvnw -pl backend -am -Dtest=BindIT,Glicko2Test,RankedQueueIT test` + `cd client && flutter test test/boards_test.dart` |
| Full suite command | `./mvnw -pl backend -am verify` + `cd client && flutter analyze && flutter test` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| AUTH-02 | Bind same playerId; wallets unchanged | IT | `./mvnw -pl backend -am -Dtest=BindIT#bindKeepsPlayerIdNoSum test` | ❌ Wave 0 |
| AUTH-02 | Username taken → 409 | IT | `BindIT#usernameTaken409` | ❌ Wave 0 |
| AUTH-03 | Login + refresh guest=false | IT | `BindIT#loginThenRefreshBound` | ❌ Wave 0 |
| AUTH-04 | Logout mints guest; bound row intact | IT | `BindIT#logoutMintsGuest` | ❌ Wave 0 |
| MODE-04 | Guest Ranked enqueue rejected | IT | `RankedQueueIT#guestRejected` | ❌ Wave 0 |
| MODE-04 | Pair → RANKED match; no bot | IT | `RankedQueueIT#pairCreatesRanked` | ❌ Wave 0 |
| MODE-04 | Glicko updates on settle only | unit+IT | `Glicko2Test` + `RankedSettleIT` | ❌ Wave 0 |
| SESS-03 | Grace 18/12; budget forfeit | IT | `RankedReconnectIT` | ❌ Wave 0 |
| LEAD-01..03 | Boards filter; guests excluded; no coins | IT | `BoardsIT` | ❌ Wave 0 |
| ANLT-01 | Events logged / rows inserted | IT | `EventSinkIT` | ❌ Wave 0 |
| AUTH UI | Bind sheet / soft-lock / boards | widget | `flutter test test/bind_* boards_*` | ❌ Wave 0 |
| D-100 | Ranked false-start 70% then forfeit | unit | `StickPullSimTest#rankedFalseStart` | ❌ Wave 0 (extend) |

### Sampling Rate
- **Per task commit:** targeted `*IT` / widget test for touched req
- **Per wave merge:** backend module tests + affected Flutter tests
- **Phase gate:** Full `./mvnw -pl backend -am verify` + `flutter analyze` + `flutter test` green before `/gsd-verify-work`

### Wave 0 Gaps
- [ ] `BindIT.java` — AUTH-02…04 (no-sum, 409, refresh guest flag, logout)
- [ ] `Glicko2Test.java` — known PDF worked example vectors where practical
- [ ] `RankedQueueIT.java` — guest reject, pair, no bot
- [ ] `RankedReconnectIT.java` — 18/12 grace + pause budget forfeit
- [ ] `BoardsIT.java` — season/all-time, bound-only
- [ ] `EventSinkIT.java` — nine event types
- [ ] Flutter widget tests: bind sheet, soft-lock, boards, Ranked searching (no fallback)
- [ ] Fix/guard test: `TokenService.rotate` bound claim
- [ ] CI workflow file itself verified by existing on PR (meta)

## Security Domain

> `security_enforcement: true` (ASVS level 1).

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | yes | Argon2id + rotating refresh; JWT HS256 15m |
| V3 Session Management | yes | Stateless JWT; refresh revoke on logout/rotate |
| V4 Access Control | yes | Ranked/boards require `guest=false`; seat checks unchanged |
| V5 Input Validation | yes | Username charset/length; password ≥8; game enum |
| V6 Cryptography | yes | Argon2id; SHA-256 refresh hashes — never plaintext passwords |

### Known Threat Patterns for Nomad Ranked + Bind

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Wallet sum / smurf merge | Elevation / Tampering | Same playerId bind; 409; no-sum; audit optional |
| Guest Ranked smurfs | Elevation | Bind gate server-side |
| Password stuffing | Spoofing | Argon2id cost; existing mint rate limit; add login rate limit (reuse JoinRateLimiter pattern) |
| JWT guest claim forged | Spoofing | Server sets claim from DB only |
| Pause-grief Ranked | Denial | Aggregate pause budget |
| Client-authored rating | Tampering | Glicko only on server settle |
| Analytics PII leak | Information | Log playerId UUID only; no raw passwords |

## Sources

### Primary (HIGH confidence)
- Codebase scout: `GuestService`, `TokenService`, `ReconnectPolicy`, `CasualQueueService`, `SoftElo`, `ProfileService`, `V1__identity.sql` credentials stub, `compose.yaml`, absence of `.github` / Dockerfile / EventSink
- `.planning/phases/07-bind-ranked-ship/07-CONTEXT.md` D-92…D-108
- `.planning/phases/07-bind-ranked-ship/07-UI-SPEC.md` (approved)
- `.planning/research/STACK.md` Argon2 + Glicko vendored
- `.planning/research/ARCHITECTURE.md` identity / rating / EventSink seams
- `.planning/research/PITFALLS.md` Pitfalls 4–5
- `.planning/research/FEATURES.md` Ranked reconnect + false-start + boards

### Secondary (MEDIUM confidence)
- https://www.glicko.net/glicko/glicko2.pdf — defaults r/RD/σ/τ [WebSearch verified]
- https://docs.spring.io/spring-security/reference/features/authentication/password-storage.html — Argon2 + DelegatingPasswordEncoder [WebFetch]
- https://github.com/actions/setup-java — maven cache [WebSearch]

### Tertiary (LOW confidence)
- Community Flutter GHA tutorials (pattern only; pin versions from STACK/pubspec)
- PROD compose layout conventions (standard Boot+Postgres; no project Dockerfile yet)

## Metadata

**Confidence breakdown:**
- Standard stack: **HIGH** — locked by STACK + pom/pubspec; Argon2/Glicko cited
- Architecture: **HIGH** — seams verified in code; gaps explicit
- Pitfalls: **HIGH** — PITFALLS + live TokenService bug + rematch trap

**Research date:** 2026-09-14  
**Valid until:** 2026-10-14 (30 days; CI action majors may drift)
