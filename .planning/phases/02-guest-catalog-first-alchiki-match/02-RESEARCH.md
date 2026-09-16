# Phase 2: Guest Catalog + First Alchiki Match - Research

**Researched:** 2026-09-06
**Domain:** Flutter catalog shell + Spring Modulith guest identity + REST-scored Alchiki bot match
**Confidence:** MEDIUM

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
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
- **D-16:** Cold start **mints a guest** with no username/password UI. Persist `playerId` + session tokens on device across restarts. Bind (AUTH-02) is Phase 7. Do not show a registration wall.
- **D-17:** **Catalog is home** after launch (short branded splash OK). Alchiki is the only playable tile. Stick Pull and other titles are **Coming Soon** (non-playable; CAT-02 is Phase 6). Do not fake a third game.
- **D-18:** All player-facing strings are i18n keys; **EN and RU complete**. In-app language switch is in scope if cheap; device locale with EN fallback is the minimum. Kazakh/Kyrgyz stay out.
- **D-19:** Replace the Phase 1 sandbox loop (Reset after one throw) with a **match**: 5–7 target bones, **first to 5**, else highest after **8 turns each** or **4:00**, **hard cap 5:00**. Bone count: **5 EASY / 6 NORMAL / 7 HARD**. Turn clock **20s** to release; timeout = forfeit that throw (saka stays, 0). Scoring only after sleep or ~1.2s settle. Saka-out = 0 and saka returns (ALCH-05, Phase 1 D-08). Pocketed targets leave the table.
- **D-20:** Controls stay Phase 1 **D-04/D-05**: aim arrow + separate Hold Throw, charge 0.15–1.1s. No slingshot. No cosmetic aim assist.
- **D-21:** First catalog path starts **EASY** (new player can win in under 3 minutes). EASY / NORMAL / HARD are all selectable this phase. Bots are **scripted** (aim/hold noise, visible mistakes). No ML. The bot takes a **visible turn** on the table (aim + throw + settle), not an instant score popup.
- **D-22:** Bot `ThrowInput` is produced **on the server** (same schema as the player) and scored by the same dyn4j burst path. The client must not invent bot results.
- **D-23:** This phase **introduces the first Spring Boot 4.1 / Java 21 / Modulith / PostgreSQL 18 slice**. Guest mint, start bot match, submit `ThrowInput`, return closed keyframes + `ThrowResolved`. **No client-authored score.** Promote `harness/` dyn4j burst into `games.alchiki` (keep CLI/JUnit golden as a regression harness).
- **D-24:** **REST is enough for the bot loop.** Do not build private-room WebSocket, reconnect, rematch windows, or forfeit-as-rated-loss here (Phases 3 / 5 / 7). Local Forge2D preview is still allowed; when preview and keyframes diverge, **keyframes win** (Phase 1 D-10).
- **D-25:** Do **not** add shop, wallets as a product surface, Glicko-2, leaderboards, analytics SaaS, Redis, or iOS shipping as a gate. Android remains the proof device; keep the Flutter iOS target compilable.

Phase 1 carry-forward (do not reopen): Flutter 3.47 + Flame 1.38 + forge2d 0.14.2 / flame_forge2d 0.19.3+7 + dyn4j 6, 2.5D / 2D, no lockstep. If throw feel regresses, fix wiring — do not swap engines.

### Claude's Discretion
- Card **illustration** style (simple diagrams vs painted stills) as long as cards are static, 5-count, colorful nomadic/Asian, original art only.
- Flutter i18n mechanism (`gen-l10n` vs a small ARB wrapper) and catalog router (`go_router` vs Navigator) — pick one boring pattern and use it for catalog → how-to → match → pause.
- Where to store guest tokens + how-to “seen” (SharedPreferences is enough).
- Exact Spring/Modulith package layout and whether the existing `harness` Maven module is moved or depended on.
- Bot noise magnitudes, HUD chrome (clock, scores, whose turn), pause layout, Coming Soon tile count/copy — planner/UI-SPEC, within PRES-02 and Phase 1 palette (`#1B6B3A` felt, `#241810` wood, `#F0B429` accents).
- Whether the old `SandboxPage` remains behind a debug flag or is deleted once the match table exists. Do **not** keep sandbox as the app home.
- Fix Phase 1 review defects **CR-01** (Hold Throw before `onLoad`) and **CR-02** (HUD `scored` ignores `sakaOut`) when extracting the match table — do not copy them.

### Deferred Ideas (OUT OF SCOPE)
- Private rooms, join codes, rematch, casual reconnect (Phase 3)
- Cosmetic shop, COINS/GEMS as a player-facing economy (Phase 4)
- Casual Quick Match + profile (Phase 5)
- Stick Pull playable + its how-to (Phase 6; catalog tile stays Coming Soon)
- Bind username/password, Ranked, Glicko-2, leaderboards, CI/compose harden (Phase 7)
- Tradition/info sheet beyond the five mandatory cards
- iOS App Store shipping as a Phase 2 gate
- WebSocket live session (needed for rooms, not for bot REST)
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| AUTH-01 | Player can start as a guest and reach a first match without creating a username | Cold-start `POST /v1/identity/guest` mints `Player` + access JWT + rotating refresh; no bind UI |
| CAT-01 | Player can open a game catalog showing Alchiki as playable | Catalog is `GoRouter` home; Alchiki tile starts EASY path |
| CAT-03 | Player can see future games as Coming Soon tiles (not fake playable entries) | Static catalog payload: Stick Pull + one extra Coming Soon; tiles non-navigating |
| ALCH-01 | Player completes a turn by aiming, holding power, releasing | Lift Phase 1 aim arrow + Hold Throw (D-04/D-05); fix CR-01 `isLoaded` guard |
| ALCH-02 | After settle, +1 per target fully outside the circle; those bones leave | Server `Dyn4jBurstSim` rest-pose score; client HUD uses `displayedScore()` (CR-02) |
| ALCH-03 | 5–7 bones, first to 5 or highest after 8 turns each / 4:00, hard cap 5:00 | Server match clock + turn machine; bone count by difficulty |
| ALCH-04 | Skippable static how-to before first match; reopen from pause | Full-screen 5-card `PageView`; skip on card 1; `howto.alchiki.seen` local flag |
| ALCH-05 | Saka-out = 0 and returns; score only after sleep or ~1.2s settle | Existing `ThrowResolved.displayedScore()` + settle timeout; do not copy CR-02 |
| BOT-01 | EASY / NORMAL / HARD scripted bots with visible mistakes | Server `ScriptedBot` emits `ThrowInput`; client animates that input then replays keyframes |
| BOT-03 | New player can beat EASY in under 3 minutes using static how-to | EASY default; large aim/hold noise; skippable cards; first-to-5 on 5 bones |
| SESS-01 | Match result / pocketed bones decided only on the server; client cannot submit a score | REST throw returns closed `ThrowResolved`; reject score-like fields |
| PRES-01 | All player-facing strings are i18n keys; EN and RU complete | Official `gen-l10n` ARB (`app_en.arb` / `app_ru.arb`) |
| PRES-02 | Catalog and matches use colorful original nomadic/Asian style | Extend Phase 1 UI-SPEC palette; static original how-to art |
</phase_requirements>

## Summary

Phase 2 is the first honest product loop: guest mint → localized catalog → five static how-to cards → REST-scored Alchiki match vs a scripted bot. Phase 1 already proved hold-to-throw feel and a headless dyn4j keyframe scorer. This phase must **not** rewrite physics or reopen Forge2D 0.15. It must **introduce** the Spring Boot 4.1 / Modulith / PostgreSQL 18 slice and **lift** the sandbox table into a match.

ARCHITECTURE.md originally split “identity+catalog” and “Alchiki+bots+WS” across later build-order numbers. ROADMAP Phase 2 **collapses** those into one MVP vertical, and D-24 **overrides** the “live match is WebSocket-only” rule for the bot loop. Planner tasks must be vertical slices (guest can finish an EASY match), not a horizontal “all backend then all UI” stack.

**Primary recommendation:** Scaffold `backend/` as a Spring Boot 4.1.1 Modulith that **depends on** the existing Spring-free `harness/` module; expose REST guest + catalog + bot-match; replace `SandboxPage` as home with `go_router` catalog → how-to → match; score only from server `ThrowResolved.displayedScore()`.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Guest mint + access/refresh | API / Backend | Browser / Client (secure store) | Server creates `Player`; client only persists tokens |
| Catalog tiles / Coming Soon | API / Backend | Browser / Client | Server owns enabled/playable flags so a patched APK cannot unlock Stick Pull |
| How-to pager + “seen” flag | Browser / Client | — | Local, skippable, no server tutorial engine |
| Aim + Hold Throw feel | Browser / Client | — | Phase 1 Forge2D preview; not authority |
| Throw scoring / pocketed IDs / saka-out | API / Backend | Database / Storage (match row) | SESS-01; dyn4j burst in `games.alchiki` |
| Match clocks (20s / 4:00 / 5:00) and first-to-5 | API / Backend | Browser / Client (HUD) | Client may display; server Instant is truth |
| Bot `ThrowInput` + visible turn | API / Backend | Browser / Client (animate + replay) | D-22: client must not invent bot results |
| i18n EN/RU | Browser / Client | — | `gen-l10n`; no server copy this phase |
| Palette / parlor table | Browser / Client | CDN / Static (card PNGs) | PRES-02; extend 01-UI-SPEC |

## Project Constraints (from .cursor/rules/)

Actionable directives extracted from `.claude/.cursor/rules` (sourced from PROJECT.md + STACK.md):

- **Authority:** Backend is source of truth; client never authors score, outcome, rating, balance, grants.
- **Platform:** One Flutter client for Android + iOS; Android is the Phase 2 proof device; keep iOS target compilable.
- **Physics lock:** Flutter 3.47 + Flame 1.38 + **forge2d 0.14.2 / flame_forge2d 0.19.3+7** (Phase 1 NDK fallback). Do **not** upgrade to Forge2D 0.15 / flame_forge2d 0.20. Do **not** reopen Unity/Godot.
- **Backend lock:** Java 21 + Spring Boot 4.1.1 + Modulith; PostgreSQL 18; **no Redis**; REST + later raw WS (WS out of this phase).
- **Auth model:** First-party HS256 access JWT (~15 min) + opaque rotating refresh in Postgres. No Keycloak / Firebase Auth / OAuth this phase.
- **Localization:** i18n keys from day one; MVP EN+RU only.
- **Art:** Original colorful nomadic/Asian; no licensed ornaments.
- **Git:** Do not create a nested `.git` under `nomad-game`.
- **MVP first:** No shop, wallets UI, Glicko-2, analytics SaaS, IAP, microservices, K8s.
- **GSD workflow:** Planning artifacts stay in sync; this research file is the planner input.

No project skills (`SKILL.md`) exist under `.cursor/skills/` or `.agents/skills/`.

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Flutter SDK | **3.47.2** / Dart **3.13.2** | Client | Host SDK via `scripts/dev-env.ps1` [VERIFIED: toolchain] |
| Flame | **1.38.2** | Game loop + keyframe interpolation | Already pinned; do not bump [VERIFIED: client/pubspec.yaml] |
| forge2d | **0.14.2** | Local preview solver | Phase 1 lock; 0.15 needs MSVC for host tests [VERIFIED: pubspec + STATE.md] |
| flame_forge2d | **0.19.3+7** | Flame ↔ Forge2D 0.14 | 0.20 `createShape` does not compile on this pin [VERIFIED: STATE.md] |
| Eclipse Temurin / Corretto JDK | **21.0.11** | Backend + harness | `JAVA_HOME` Corretto 21 [VERIFIED: toolchain] |
| Spring Boot | **4.1.1** | Modular monolith HTTP | Project lock; official current [CITED: spring.io Boot 4.1] |
| Spring Modulith | **2.1.1** | Package modules + `ApplicationModules.verify()` | Released against Boot 4.1.1 [CITED: STACK.md + modulith docs] |
| dyn4j | **6.0.0** | Server burst-sim | Already in `harness/` [VERIFIED: harness/pom.xml] |
| PostgreSQL | **18.6** (`postgres:18.6`) | Identity + match outcomes | Project lock; no Redis [CITED: STACK.md] |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `flutter_localizations` | SDK | Material/Cupertino locale delegates | Always [CITED: docs.flutter.dev/ui/internationalization] |
| `intl` | `any` (SDK-aligned) | ARB / gen-l10n | Always; official `flutter pub add intl:any` [CITED: docs.flutter.dev/ui/internationalization] |
| `go_router` | **18.0.1** | Catalog → how-to → match → pause | Official flutter.dev package; current pub.dev [CITED: pub.dev/packages/go_router] |
| `flutter_riverpod` | **3.4.3** | Session, locale, match client state | STACK lock; no Bloc [CITED: pub.dev/packages/flutter_riverpod] |
| `dio` | **5.11.1** | REST + 401 refresh | Official; separate Dio for `/refresh` [CITED: pub.dev/packages/dio] |
| `flutter_secure_storage` | **11.0.0** | `playerId` + refresh token | Official Keychain/Keystore; default `AndroidOptions()` [CITED: pub.dev/packages/flutter_secure_storage] |
| `shared_preferences` | **2.5.5** | How-to “seen” only (non-secret) | Official flutter.dev; use `SharedPreferencesAsync` [CITED: pub.dev/packages/shared_preferences] |
| `spring-boot-starter-webmvc` | BOM 4.1.1 | REST | Boot 4 official servlet starter [CITED: docs.spring.io/spring-boot/4.1/reference/web/index.html] |
| `spring-boot-starter-security` + `oauth2-resource-server` | BOM | Bearer JWT filter | First-party issuer + resource server in one JAR [CITED: docs.spring.io/spring-security JWT] |
| `spring-boot-starter-data-jpa` | BOM | `Player`, refresh, match rows | Default persistence |
| `spring-boot-starter-flyway` | BOM | Migrations | Boot 4 auto-config lives in the starter, not `flyway-core` alone [CITED: docs.spring.io/spring-boot/4.1/how-to/data-initialization.html] |
| `flyway-database-postgresql` | BOM (12.4.x) | PG 18 dialect | Required or Flyway throws Unsupported Database [CITED: Boot issue #49012 + official Flyway note] |
| `spring-boot-starter-validation` | BOM | DTO `@Valid` | ThrowInput / match create |
| `spring-boot-starter-actuator` | BOM | `/actuator/health` | Always; no Prometheus |
| `spring-modulith-starter-core` + `starter-test` | 2.1.1 | Module verify | Official [CITED: docs.spring.io/spring-modulith] |
| `spring-boot-testcontainers` + Testcontainers PostgreSQL | BOM / **2.0.5** | TEST DB | `@ServiceConnection` [CITED: docs.spring.io/spring-boot/4.1 Testcontainers] |
| `spring-boot-starter-docker-compose` | BOM | DEV: Postgres in Docker | Optional; app on host [CITED: Boot 4.1 Dev Services] |
| JUnit Jupiter | harness **6.1.3** / Boot BOM | Unit + slice tests | Keep harness version; backend uses BOM |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `go_router` 18 | Imperative `Navigator` | Works for 4 screens; STACK and deep-link-later rooms favor `go_router` now |
| `flutter_secure_storage` | SharedPreferences for tokens | CONTEXT said prefs “are enough”; ASVS/STACK say Keychain/Keystore for refresh. **Use secure storage for tokens, prefs for how-to seen** |
| `gen-l10n` | Hand-rolled map / easy_localization | Official typed getters; no extra i18n framework |
| REST bot loop | WebSocket `MatchSession` | Correct for Phase 3 rooms; D-24 forbids it here |
| Depend on `harness/` | Move Java into `backend/` and delete CLI | Loses golden CLI/`BurstSimTest`. **Keep harness; backend depends on it** |
| Riverpod codegen (`@riverpod`) | Hand-written `Notifier` | STACK: no code-gen soup. Use `NotifierProvider` / `AsyncNotifier` without `riverpod_generator` |
| `spring-boot-starter-web` | `starter-webmvc` | Boot 4 docs: most apps use `starter-webmvc`; `starter-web` is deprecated-in-favor on Central |

**Installation (client, from `client/` after `dev-env.ps1`):**

```bash
flutter pub add flutter_localizations --sdk=flutter
flutter pub add intl:any
flutter pub add go_router:18.0.1 flutter_riverpod:3.4.3 dio:5.11.1 flutter_secure_storage:11.0.0 shared_preferences:2.5.5
```

Do **not** add `web_socket_channel`, `flame_forge2d` 0.20, or `forge2d` 0.15.

**Installation (backend):** new Maven module `backend/` with `spring-boot-starter-parent` **4.1.1**. Do not pin Flyway/Security/Jackson versions by hand — use the Boot BOM. Add a repo-root aggregator POM:

```xml
<modules>
  <module>harness</module>
  <module>backend</module>
</modules>
```

`backend` depends on `com.nomadgames:alchiki-proto-harness:0.1.0-SNAPSHOT`. Keep `harness` Spring-free (CLI + `BurstSimTest` + golden JSON).

**Version verification (this session):**

| Package | Registry check | Published |
|---------|----------------|-----------|
| go_router 18.0.1 | pub.dev / flutter.dev | current [CITED: pub.dev/packages/go_router] |
| flutter_riverpod 3.4.3 | pub.dev | current [CITED: pub.dev/packages/flutter_riverpod] |
| dio 5.11.1 | pub.dev / flutter.cn | current [CITED: pub.dev/packages/dio] |
| flutter_secure_storage 11.0.0 | pub.dev | current (STACK 10.3.1 is stale) [CITED: pub.dev/packages/flutter_secure_storage] |
| shared_preferences 2.5.5 | pub.dev / flutter.dev | current [CITED: pub.dev/packages/shared_preferences] |
| Spring Boot 4.1.1 | spring.io | project lock |
| dyn4j 6.0.0 | Maven Central via harness POM | [VERIFIED: harness/pom.xml] |

## Package Legitimacy Audit

Flutter packages live on **pub.dev**, not npm. The GSD `package-legitimacy` seam is npm/pypi/crates — running `npm view go_router` would hit the **wrong ecosystem** (documented hallucination vector). This audit uses official publisher pages fetched this session.

| Package | Registry | Age / publisher | Downloads signal | Source Repo | Verdict | Disposition |
|---------|----------|-----------------|------------------|-------------|---------|-------------|
| go_router | pub.dev | flutter.dev | 5.7k likes | flutter/packages | OK | Approved — official Flutter team |
| flutter_riverpod | pub.dev | dash-overflow.net | 2.9k likes | rrousselGit/riverpod | OK | Approved — STACK lock |
| dio | pub.dev | flutter.cn | 8.3k likes | cfug/dio | OK | Approved — STACK lock |
| flutter_secure_storage | pub.dev | steenbakker.dev | 4.4k likes | juliansteenbakker/flutter_secure_storage | OK | Approved — use **11.0.0**, default ciphers |
| shared_preferences | pub.dev | flutter.dev | 10.5k likes | flutter/packages | OK | Approved — how-to flag only |
| flutter_localizations / intl | Flutter SDK | flutter.dev | SDK | flutter/flutter | OK | Approved |
| Spring Boot starters / Modulith / Flyway PG module / Testcontainers | Maven Central | spring-projects / flyway / testcontainers | BOM | official orgs | OK | Approved — BOM-managed |
| dyn4j | Maven Central | already in repo | — | dyn4j/dyn4j | OK | Already installed |

**Packages removed due to [SLOP] verdict:** none
**Packages flagged as suspicious [SUS]:** none

No npm `postinstall` scripts apply. Do not add unverified pub packages from training data.

*STACK.md listed flutter_secure_storage **10.3.1**. Official current is **11.0.0** (custom RSA-OAEP + AES-GCM; `encryptedSharedPreferences` deprecated). Pin 11.0.0. [CITED: pub.dev/packages/flutter_secure_storage]*

## Architecture Patterns

### System Architecture Diagram

```
Cold start
    │
    ▼
Client splash (optional, short)
    │  no username UI
    ▼
POST /v1/identity/guest  ──► identity ──► Postgres players + refresh_tokens
    │                         HS256 access (15m) + opaque refresh (30d, rotate)
    ▼
Persist playerId + refresh in flutter_secure_storage; access in memory
    │
    ▼
GET /v1/catalog  ──► catalog ──► { alchiki: PLAYABLE, stick_pull: COMING_SOON, … }
    │
    ▼
Catalog home (GoRouter /)
    │ tap Alchiki (default EASY; NORMAL/HARD selectable)
    ▼
howto.alchiki.seen? ──no──► full-screen 5-card PageView (Skip on card 1)
    │ yes / skip / finish                 persist seen in SharedPreferencesAsync
    ▼
POST /v1/matches { game:ALCHIKI, mode:BOT, difficulty }
    │
    ▼
session + games.alchiki ── spawn N bones (5/6/7), clocks, seats (player + BOT)
    │
    ▼
Match table (Flame GameWidget + Flutter Hold Throw)
    │ player aims + holds + releases
    ▼
POST /v1/matches/{id}/throws  { ThrowInput }   ✗ no score fields
    │
    ▼
games.alchiki: clamp input → Dyn4jBurstSim → ThrowResolved
    │ if next turn is BOT: ScriptedBot.ThrowInput → same burst
    ▼
JSON { playerThrow, botThrow?, match }   keyframes win over local preview
    │
    ▼
Client: replay player → (optional) animate bot aim/hold from botThrow.input
        → replay bot keyframes → HUD from match.scores / displayedScore()
    │
    ▼
first-to-5 / 8 turns each / 4:00 / hard 5:00 ──► persist match outcome
```

### Recommended Project Structure

```
backend/
├── pom.xml                          # parent 4.1.1; depends on harness
├── src/main/java/com/nomadgames/
│   ├── NomadGamesApplication.java
│   ├── identity/                    # public: GuestService, TokenService
│   │   └── internal/
│   ├── catalog/                     # public: CatalogService
│   │   └── internal/
│   ├── session/                     # public: MatchService (REST bot loop)
│   │   ├── GameEngine.java
│   │   └── internal/
│   └── games/
│       └── alchiki/                 # nested module; implements GameEngine
│           └── internal/            # wraps Dyn4jBurstSim + ScriptedBot
├── src/main/resources/
│   ├── application.yaml
│   ├── application-dev.yaml
│   └── db/migration/V1__identity_catalog_match.sql
└── src/test/java/.../ModularityTest.java

harness/                             # UNCHANGED role: CLI + BurstSimTest + golden
└── (existing proto types; extend spawn for 5/7 bones)

client/lib/
├── main.dart                        # ProviderScope + MaterialApp.router
├── l10n/app_en.arb
├── l10n/app_ru.arb
├── platform/
│   ├── router.dart
│   ├── api/nomad_api.dart           # Dio + refresh Dio
│   ├── auth/session_store.dart      # secure storage
│   └── i18n/
├── catalog/
├── howto/
└── games/alchiki/                   # lift sandbox table here
    ├── match_page.dart
    ├── match_game.dart              # from alchiki_sandbox_game.dart
    └── ...
```

Do **not** create `games/stick_pull` playable code. Catalog tile only.

### Pattern 1: First-party JWT issuer (not issuer-uri)

**What:** The monolith issues HS256 access JWTs and verifies them with the same secret. Refresh tokens are opaque 32-byte values; store only SHA-256 in Postgres; rotate on every `/refresh`.
**When to use:** Always for AUTH-01. Do **not** set `spring.security.oauth2.resourceserver.jwt.issuer-uri` — that discovers a third-party JWKS. [CITED: docs.spring.io/spring-security/reference/servlet/oauth2/resource-server/jwt.html]

```java
// Source: Spring Security 7 NimbusJwtEncoder/Decoder API
// https://docs.spring.io/spring-security/reference/api/java/org/springframework/security/oauth2/jwt/NimbusJwtEncoder.SecretKeyJwtEncoderBuilder.html
SecretKey key = new SecretKeySpec(secretBytes, "HmacSHA256"); // >= 256 bits
JwtEncoder encoder = NimbusJwtEncoder.withSecretKey(key).algorithm(MacAlgorithm.HS256).build();
JwtDecoder decoder = NimbusJwtDecoder.withSecretKey(key).macAlgorithm(MacAlgorithm.HS256).build();

JwtClaimsSet claims = JwtClaimsSet.builder()
    .subject(playerId.toString())
    .id(UUID.randomUUID().toString())
    .claim("guest", true)
    .issuedAt(now)
    .expiresAt(now.plus(Duration.ofMinutes(15)))
    .build();
String access = encoder.encode(JwtEncoderParameters.from(claims)).getTokenValue();
```

Permit only `POST /v1/identity/guest`, `POST /v1/identity/refresh`, and `/actuator/health`. Everything else requires `Authorization: Bearer`.

### Pattern 2: REST bot match (D-24 override of WS)

**What:** One request-response throw. Server may attach the already-scored bot throw so the client can play a visible bot turn without inventing input.
**When to use:** BOT mode only. Phase 3 will add WS; keep `GameEngine` SPI so the same dyn4j path is reused.

```http
POST /v1/matches/{matchId}/throws
Authorization: Bearer <access>
Content-Type: application/json

{ "schemaVersion": 1, "yUp": true, "aimAngleRad": 1.2, "holdMs": 640, "seed": 1, "tableId": "alchiki-match-v1" }
```

Response (authoritative):

```json
{
  "playerThrow": { "pocketedCount": 2, "sakaOut": false, "displayedScore": 2, "keyframes": [] },
  "botThrow": { "input": { "aimAngleRad": 0.4, "holdMs": 280 }, "pocketedCount": 0, "sakaOut": true, "displayedScore": 0, "keyframes": [] },
  "match": { "status": "IN_PLAY", "playerScore": 2, "botScore": 0, "turn": "PLAYER", "bonesLeft": ["b3","b4","b5"] }
}
```

Reject any client field named `pocketedCount`, `score`, `sakaOut`, `winner`. Reuse Phase 1 ignore-unknown-keys discipline [VERIFIED: 01-SECURITY.md T-01-01].

If the 20s turn clock expired before the POST, treat as forfeit throw (saka stays, 0) and still run the bot half if the match continues.

### Pattern 3: Guest is the Player

**What:** `POST /v1/identity/guest` inserts `players(id, guest=true)` and a refresh row. No `device` advertising ID. Bind later **links** a credential to the same `playerId` (Phase 7). Schema may include empty `credentials` table now so Phase 7 does not rewrite PKs. [CITED: ARCHITECTURE.md Pattern 5 + PITFALLS.md Pitfall 5]

### Pattern 4: Modulith simple modules

**What:** Direct sub-packages of `com.nomadgames` are modules. Public API in the module root; `internal/` is invisible. `games.alchiki` is a nested module. [CITED: docs.spring.io/spring-modulith/reference/fundamentals.html]

```java
// Source: https://docs.spring.io/spring-modulith/reference/verification.html
ApplicationModules.of(NomadGamesApplication.class).verify();
```

Allowed deps: `games.alchiki` → `session` + harness types; `session` → `identity` API; `catalog` standalone. No `identity` → `games.alchiki`.

### Pattern 5: How-to pager

**What:** Flutter `PageView` (Material, no extra package) with five static illustrated cards, a persistent **Skip** on card 1 (and later cards), Next on 1–4, Play on 5. On skip or Play: write `howto.alchiki.seen=true` via `SharedPreferencesAsync`, `context.go('/match?difficulty=EASY')`. Pause reopens the same route without clearing seen.

### Pattern 6: Secure tokens vs prefs

**What:** Refresh + `playerId` in `FlutterSecureStorage()` default options (RSA-OAEP + AES-GCM). How-to seen in `SharedPreferencesAsync`. Set `android:allowBackup="false"` on the application to avoid Keystore unwrap crashes after Drive backup. [CITED: pub.dev/packages/flutter_secure_storage]

Access JWT stays in memory (Riverpod). On 401, a **second** Dio instance (no interceptor) calls `/refresh`; rotate stored refresh. [CITED: pub.dev/packages/dio Interceptors + STACK.md]

### Anti-Patterns to Avoid

- **Client `scored` from Forge2D rest poses** — SESS-01 / D-10 / CR-02.
- **`issuer-uri` resource-server config** — we are the issuer; JWKS discovery will fail.
- **`flyway-core` without `spring-boot-starter-flyway` + `flyway-database-postgresql`** — Boot 4 silent no-migrate or “Unsupported Database: PostgreSQL 18”.
- **Jackson 2 `com.fasterxml.jackson.databind.ObjectMapper`** — Boot 4 default is Jackson 3 `tools.jackson.databind.json.JsonMapper`. Annotations stay `com.fasterxml.jackson.annotation`. [CITED: spring.io/blog/2025/10/07/introducing-jackson-3-support-in-spring]
- **WebSocket / STOMP this phase** — D-24.
- **Sandbox as `MaterialApp.home`** — CAT-01.
- **`encryptedSharedPreferences: true`** — deprecated in secure_storage 10/11.
- **Upgrade Forge2D** — Wave 1 lock.
- **Bot score popup without table motion** — D-21.
- **Registration / username field** — AUTH-01.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| EN/RU strings | Custom map / `.json` loader | `gen-l10n` + ARB | Official typed `AppLocalizations`; missing keys fail codegen [CITED: docs.flutter.dev/ui/internationalization] |
| Catalog/match navigation | Ad-hoc `Navigator.push` soup | `go_router` 18 | Named routes + later room deep links [CITED: pub.dev/documentation/go_router] |
| HTTP + 401 refresh | Raw `HttpClient` | `dio` + second refresh client | Interceptor loop is a known footgun; official Interceptors API |
| Access JWT sign/verify | JJWT hand HMAC / custom Base64 | `NimbusJwtEncoder` / `NimbusJwtDecoder` | Spring Security 7 first-party path |
| Refresh persistence | Plain SharedPreferences | `flutter_secure_storage` 11 | ASVS session token storage; STACK |
| Schema evolution | `ddl-auto=update` + `schema.sql` | Flyway starter + PG module | Official: one migration tool; do not mix [CITED: Boot 4.1 data-initialization] |
| How-to swipe deck | Custom PageController framework | Material `PageView` | Five static pages |
| Physics / scoring | New solver or client pocket math | Existing `Dyn4jBurstSim` | Phase 1 golden path |
| TEST Postgres | H2 | Testcontainers PG 18 | Dialect parity with Flyway PG module |
| In-process guest UUID | Advertising ID / ANDROID_ID | Server-minted UUID | PITFALLS.md Pitfall 5 |

**Key insight:** The cheat surface is the throw result. Reuse the Phase 1 wire (`ThrowInput` → closed keyframes → `displayedScore()`). New work is identity, routing, match clocks, and a scripted bot **on that same path**.

## Common Pitfalls

### Pitfall 1: Copying CR-01 / CR-02 into the match table
**What goes wrong:** Hold Throw before `onLoad` throws `LateInitializationError`. HUD shows raw `pocketedCount` when `sakaOut` is true.
**Why it happens:** `sandbox_page.dart` `_holdEnabled` ignores `game.isLoaded`; `AuthorityScore.readPocketedCount` drops `displayedScore()`.
**How to avoid:** Extract with the 01-REVIEW fixes applied. Add a widget test that Hold is disabled until loaded, and a replay test `sakaOut: true, pocketedCount: 2` → scored `0`.
**Warning signs:** `scored` equals `pocketedCount` in match HUD.

### Pitfall 2: Client-authored or preview-as-scored
**What goes wrong:** Ranked/economy later inherit a forged score. [CITED: PITFALLS.md Pitfall 2 / 9]
**How to avoid:** Match HUD calls `ThrowResolved.displayedScore()` from the REST body only. Local settle may show `preview`, never `scored`.

### Pitfall 3: Dyn4jBurstSim always spawnSeed1 (6 bones)
**What goes wrong:** EASY/HARD ignore D-19 bone counts. [VERIFIED: Dyn4jBurstSim.java SEED1]
**How to avoid:** Add spawn variants (5 / 6 / 7) that **reuse the same collider family and seed-1 hex radius**. Recommend: NORMAL = current hex; EASY = drop `b5`+`b6`; HARD = add center `b7` at `(0,0)`. Keep `tableId` distinct (`alchiki-match-v1`) but physics constants from `TableConstants`.

### Pitfall 4: Boot 4 Flyway / Jackson / web starter traps
**What goes wrong:** Migrations never run; PG 18 unsupported; `ObjectMapper` import fails compile; wrong starter.
**How to avoid:** `spring-boot-starter-webmvc` + `spring-boot-starter-flyway` + `flyway-database-postgresql`; Jackson 3 `JsonMapper`; `spring.jpa.hibernate.ddl-auto=validate` (Flyway owns DDL).

### Pitfall 5: Guest wall or second user on “play”
**What goes wrong:** First-session death; later bind sums wallets. [CITED: PITFALLS.md Pitfall 5]
**How to avoid:** Silent mint on splash. No username. Schema: one `players` PK. Do not implement bind endpoints.

### Pitfall 6: Dio interceptor refresh loop
**What goes wrong:** `/refresh` 401 retried forever.
**How to avoid:** Refresh client has **no** auth interceptor. Use `QueuedInterceptorsWrapper` on the main client so concurrent 401s share one refresh. [CITED: pub.dev/packages/dio]

### Pitfall 7: How-to as overlay / 3 cards / federation copy
**What goes wrong:** Misses D-12–D-15 and BOT-03 (skippers still need a winnable EASY).
**How to avoid:** Full-screen route; exactly five FEATURES.md topics; Skip on card 1.

### Pitfall 8: Instant bot score
**What goes wrong:** D-21 fails; player cannot see mistakes.
**How to avoid:** Client must animate `botThrow.input` (aim + hold) then interpolate keyframes. Server still produced the input.

### Pitfall 9: WR-01 / WR-02 regress in the match
**What goes wrong:** Preview freezes on frame-dt; sleep path omits rest keyframe.
**How to avoid:** Advance `simTimeS` per physics step (WR-01). On `allAtRest`, capture a final keyframe (WR-02) when promoting `Dyn4jBurstSim`.

### Pitfall 10: Tokens in SharedPreferences / Android backup
**What goes wrong:** Refresh readable on device; Keystore unwrap after Drive backup.
**How to avoid:** Secure storage + `allowBackup=false`. Prefs only for how-to seen.

## Code Examples

Verified patterns from official sources:

### Flutter gen-l10n (EN + RU)

```yaml
# Source: https://docs.flutter.dev/ui/internationalization
# pubspec.yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_localizations:
    sdk: flutter
  intl: any
flutter:
  generate: true
```

```yaml
# l10n.yaml (client/)
arb-dir: lib/l10n
template-arb-file: app_en.arb
output-localization-file: app_localizations.dart
nullable-getter: false
```

```dart
// Source: https://docs.flutter.dev/ui/internationalization
return MaterialApp.router(
  locale: localeOverride, // null = device
  localeListResolutionCallback: (locales, supported) {
    for (final locale in locales ?? const <Locale>[]) {
      if (supported.contains(Locale(locale.languageCode))) {
        return Locale(locale.languageCode);
      }
    }
    return const Locale('en');
  },
  supportedLocales: const [Locale('en'), Locale('ru')],
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  routerConfig: router,
);
```

### go_router catalog → how-to → match

```dart
// Source: https://pub.dev/documentation/go_router/latest/topics/Configuration-topic.html
final router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (_, __) => const CatalogPage()),
    GoRoute(path: '/howto/alchiki', builder: (_, __) => const AlchikiHowToPage()),
    GoRoute(
      path: '/match',
      builder: (_, state) => AlchikiMatchPage(
        difficulty: state.uri.queryParameters['difficulty'] ?? 'EASY',
      ),
    ),
  ],
);
```

### Dio interceptors (refresh on a second client)

```dart
// Source: https://pub.dev/packages/dio (Interceptors)
dio.interceptors.add(
  InterceptorsWrapper(
    onRequest: (options, handler) {
      final token = accessToken;
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
      return handler.next(options);
    },
    onError: (error, handler) async {
      // refreshDio has NO this interceptor
      return handler.next(error);
    },
  ),
);
```

### Authority HUD (CR-02)

```dart
// Fix from 01-REVIEW.md — do not ship readPocketedCount as scored
int displayedScore(ThrowResolved resolved) =>
    resolved.sakaOut ? 0 : resolved.pocketedCount;
```

### Flyway on Boot 4 + PG 18

```xml
<!-- Source: https://docs.spring.io/spring-boot/4.1/how-to/data-initialization.html -->
<dependency>
  <groupId>org.springframework.boot</groupId>
  <artifactId>spring-boot-starter-flyway</artifactId>
</dependency>
<dependency>
  <groupId>org.flywaydb</groupId>
  <artifactId>flyway-database-postgresql</artifactId>
</dependency>
```

### Hold Throw guard (CR-01)

```dart
// Source: 01-REVIEW.md CR-01
bool get holdEnabled =>
    game.isLoaded && !throwing && !settled && !replaying && isPlayerTurn;
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `spring-boot-starter-web` | `spring-boot-starter-webmvc` | Boot 4.0 | New backend must use webmvc [CITED: Boot 4.1 Web reference] |
| Jackson 2 `ObjectMapper` | Jackson 3 `JsonMapper` (`tools.jackson`) | Boot 4.0 | Do not copy Boot 3 snippets [CITED: spring.io Jackson 3 blog] |
| `flyway-core` auto-config | `spring-boot-starter-flyway` + DB module | Boot 4.0 | Silent migrate failure otherwise |
| flutter_secure_storage EncryptedSharedPreferences | Default RSA-OAEP + AES-GCM (`AndroidOptions()`) | v10/v11 | Do not set deprecated flag [CITED: pub.dev 11.0.0] |
| Legacy `SharedPreferences.getInstance()` | `SharedPreferencesAsync` | plugin 2.3+ | Official for new code [CITED: pub.dev/packages/shared_preferences] |
| ARCHITECTURE “match = WS only” | REST bot loop (D-24) | Phase 2 lock | WS waits for Phase 3 |
| STACK Forge2D 0.15 | forge2d 0.14.2 / flame_forge2d 0.19.3+7 | Phase 1 | Do not upgrade |

**Deprecated/outdated:**

- `encryptedSharedPreferences` on flutter_secure_storage
- `spring-boot-starter-web` as the Boot 4 default name
- Client `AuthorityScore.readPocketedCount` as the match HUD (CR-02)
- Sandbox Reset-as-product loop
- `issuer-uri` for a first-party HS256 issuer

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | EASY spawn drops `b5`+`b6`; HARD adds `b7` at `(0,0)` | Pitfall 3 / ALCH-03 | Cluster feel/tuning; planner may pick another pair to drop |
| A2 | REST paths `/v1/identity/guest`, `/v1/identity/refresh`, `/v1/catalog`, `/v1/matches`, `/v1/matches/{id}/throws` | Pattern 2 | Naming only; contract fields matter more |
| A3 | Bot noise: EASY aim ±0.60 rad and hold 200–450 ms; NORMAL ±0.25 rad / 400–800 ms; HARD ±0.10 rad / 700–1050 ms with 15% intentional miss | BOT-01 / BOT-03 | EASY may be too hard/easy; tune in UAT, keep “visible mistakes” |
| A4 | One extra Coming Soon tile besides Stick Pull (two non-playable tiles) | CAT-03 | D-17 forbids a fake third **playable** game; tile count is discretion |
| A5 | In-app EN/RU switch via Riverpod locale override is “cheap enough” to include | D-18 | If UI-SPEC cuts it, device locale + EN fallback still satisfies PRES-01 |
| A6 | Refresh reuse detection (revoke family) is in-scope at ASVS L1 | Security | Minimum is rotate-on-use; family revoke can wait if time-boxed |
| A7 | `tableId` becomes `alchiki-match-v1` while physics constants stay proto | Integration | Replay equality vs golden `alchiki-proto-v1` — keep proto tableId for harness CLI only |

**If this table is empty:** All claims in this research were verified or cited — no user confirmation needed.

## Open Questions (RESOLVED)

1. **5- and 7-bone cluster geometry** — RESOLVED: A1 spawn. EASY drops `b5`+`b6` from the seed-1 hex; NORMAL keeps the six-bone hex; HARD adds center `b7` at `(0,0)`. Same collider family and radii. Locked in 02-04 `Dyn4jBurstSim.spawnForBoneCount`.

2. **Keep `SandboxPage` behind a debug flag?** — RESOLVED: optional `/debug/sandbox` wrapping the existing `SandboxPage`; never linked from catalog (D-17). Locked in 02-01 `buildRouter`.

3. **DEV HTTPS** — RESOLVED: debug-only cleartext so the emulator can reach `10.0.2.2`. Release manifest does not enable cleartext. Tokens stay in `FlutterSecureStorage`. Locked in 02-07 debug overlay manifest.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Flutter SDK | Client | ✓ (via `scripts/dev-env.ps1`) | 3.47.2 / Dart 3.13.2 | — |
| JDK 21 | Backend + harness | ✓ | Corretto 21.0.11 | Script sets `JAVA_HOME` |
| Maven Wrapper | Harness / backend | ✓ | `harness/mvnw.cmd` | No global `mvn` on PATH — use wrapper |
| Docker Desktop | Postgres TEST/DEV | ✓ | 29.7.2 | — |
| PostgreSQL on :5432 | Runtime | ✗ | — | Compose `postgres:18.6` or Testcontainers |
| Context7 / ctx7 CLI | Doc lookup | ✗ | — | Official URLs via WebSearch/WebFetch (used) |
| Redis | — | n/a | — | Forbidden this phase |
| iOS / Xcode | Ship | not a gate | — | Keep target compilable only |

**Missing dependencies with no fallback:**
- None for planning. Postgres must be **started by the plan** (Compose or Testcontainers), not assumed on the host.

**Missing dependencies with fallback:**
- Host `java`/`flutter`/`mvn` not on default PATH → always dot-source `scripts/dev-env.ps1` and use `harness/mvnw.cmd` (or a new `backend/mvnw`).

Step 2.6 note: Docker is up; `pg_isready` had no listener on :5432.

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework (client) | `flutter_test` (SDK, Flutter 3.47.2) |
| Framework (backend) | JUnit Jupiter via Spring Boot 4.1 BOM + existing harness JUnit **6.1.3** |
| Config file | `client/analysis_options.yaml`; backend `pom.xml` (Wave 0) |
| Quick run command | `. ./scripts/dev-env.ps1; Set-Location client; flutter test` |
| Full suite command | Client `flutter test` + `harness/mvnw.cmd -q test` + `backend/mvnw.cmd -q verify` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| AUTH-01 | Guest mint returns playerId + tokens; no username UI | integration | `backend` `@SpringBootTest` guest POST + `flutter test` catalog smoke | ❌ Wave 0 |
| CAT-01 | Catalog shows Alchiki playable | widget | `flutter test test/catalog_test.dart` | ❌ Wave 0 |
| CAT-03 | Coming Soon tiles not navigable | widget | same file | ❌ Wave 0 |
| ALCH-01 | Aim + Hold Throw + `isLoaded` guard | widget/unit | `flutter test test/match_hold_test.dart` | ❌ Wave 0 (fix CR-01) |
| ALCH-02 | Score = bones fully out after settle | unit | existing `pocket_settle_test.dart` + server score test | ✅ client settle / ❌ server match |
| ALCH-03 | First to 5 / 8 turns / 4:00 / 5:00 | unit | `AlchikiRulesTest` on server | ❌ Wave 0 |
| ALCH-04 | Skip on card 1; seen persisted; pause reopens | widget | `flutter test test/howto_test.dart` | ❌ Wave 0 |
| ALCH-05 | sakaOut → displayedScore 0 | unit | extend `replay_score_test.dart` + `BurstSimTest` | ⚠️ missing sakaOut case (CR-02) |
| BOT-01 | Server emits ThrowInput per difficulty; visible mistakes | unit | `ScriptedBotTest` | ❌ Wave 0 |
| BOT-03 | EASY bone count 5 + noisy aim | unit | same | ❌ Wave 0 |
| SESS-01 | Client score fields ignored; only server ThrowResolved | integration | POST throw with forged `pocketedCount` ignored | ❌ Wave 0 |
| PRES-01 | EN+RU keys present for player-facing copy | unit | `flutter gen-l10n` + test both locales | ❌ Wave 0 |
| PRES-02 | Palette hex still used on catalog/match | widget/manual | grep + UI-SPEC | ⚠️ table exists; catalog does not |

### Sampling Rate

- **Per task commit:** `flutter test` (changed files) and/or `harness/mvnw.cmd -q test`
- **Per wave merge:** client `flutter test` + harness test + `backend/mvnw.cmd -q verify` (includes `ApplicationModules.verify()`)
- **Phase gate:** Full suite green before `/gsd-verify-work`; owner UAT: guest → EASY win &lt; 3 min

### Wave 0 Gaps

- [ ] `backend/` Maven module + `ModularityTest` + Testcontainers guest/match slice
- [ ] `client/test/catalog_test.dart` — CAT-01 / CAT-03
- [ ] `client/test/howto_test.dart` — ALCH-04 skip-from-card-1
- [ ] `client/test/match_hold_test.dart` — CR-01
- [ ] `client/test/replay_score_test.dart` — add `sakaOut: true` (CR-02)
- [ ] `client/l10n/app_en.arb` + `app_ru.arb` + `l10n.yaml`
- [ ] `harness` spawn-5/7 tests + WR-02 sleep keyframe
- [ ] `client/test/widget_test.dart` currently expects `SandboxApp` / “Table reset” — **must be rewritten** when home becomes catalog [VERIFIED: client/test/widget_test.dart]

Existing client tests to keep green: `throw_input_test.dart`, `physics_stepper_test.dart`, `pocket_settle_test.dart`, `replay_score_test.dart` (extended).

## Security Domain

`security_enforcement` is enabled (ASVS level 1).

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | yes | Guest mint (no password this phase); first-party HS256 access JWT |
| V3 Session Management | yes | Opaque rotating refresh in Postgres; 15 min access; store refresh in Keychain/Keystore |
| V4 Access Control | yes | Match row owned by `playerId`; reject throw if not current player turn |
| V5 Input Validation | yes | `ThrowInput` schemaVersion/yUp/finite aim/hold clamp; Bean Validation on REST DTOs; ignore unknown/score keys |
| V6 Cryptography | yes | HS256 via Nimbus (secret ≥ 256 bits from env); SHA-256 of refresh; **never** hand-roll HMAC |

### Known Threat Patterns for Flutter + Spring REST parlor

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Client submits `pocketedCount` / winner | Tampering | Ignore; score only from dyn4j rest poses (SESS-01, T-01-01 carry-forward) |
| Oversized keyframe / body arrays | Denial of service | Existing caps 40 frames / 8 bodies; keep on REST parser |
| Guest-mint flood | Denial of service | In-process rate limit per IP on `POST /v1/identity/guest` (no Redis/Bucket4j product yet) |
| Refresh theft / replay | Elevation of privilege | Rotate on use; hash at rest; optional family revoke (A6) |
| Off-turn throw / clock expire | Tampering | Server Instant turn deadline; 20s forfeit |
| Bot result invented on client | Spoofing | Bot `ThrowInput` + keyframes only from server |
| JWT `alg` confusion | Tampering | Pin `macAlgorithm(HS256)` on decoder [CITED: Spring Security NimbusJwtDecoder] |
| Android backup unwrap | Information disclosure | `allowBackup=false` |
| SQL injection | Tampering | JPA / parameterized queries only |
| XSS in catalog copy | Tampering | Flutter widgets, not HTML; i18n strings are data |

Carry-forward closed Phase 1 threats (T-01-01..T-01-05, T-01-SC) still apply to the throw JSON. New identity/match endpoints need a PLAN `<threat_model>` on first backend plan.

## Sources

### Primary (HIGH / codebase)
- `.planning/phases/02-guest-catalog-first-alchiki-match/02-CONTEXT.md` — D-12–D-25
- `.planning/REQUIREMENTS.md`, `ROADMAP.md`, `PROJECT.md`, `STATE.md`
- `client/lib/**`, `harness/**`, `01-REVIEW.md` CR-01/CR-02, `01-SECURITY.md`
- Host toolchain: Flutter 3.47.2, Corretto 21.0.11, Docker 29.7.2

### Secondary (MEDIUM — official docs via WebSearch)
- https://docs.flutter.dev/ui/internationalization — gen-l10n
- https://docs.spring.io/spring-boot/4.1/reference/web/index.html — `starter-webmvc`
- https://docs.spring.io/spring-boot/4.1/how-to/data-initialization.html — Flyway starter + PG module
- https://docs.spring.io/spring-security/reference/servlet/oauth2/resource-server/jwt.html — resource server JWT
- https://docs.spring.io/spring-security/reference/api/java/org/springframework/security/oauth2/jwt/NimbusJwtEncoder.SecretKeyJwtEncoderBuilder.html
- https://docs.spring.io/spring-modulith/reference/fundamentals.html
- https://docs.spring.io/spring-modulith/reference/verification.html
- https://pub.dev/packages/go_router — 18.0.1
- https://pub.dev/packages/flutter_riverpod — 3.4.3
- https://pub.dev/packages/dio — 5.11.1
- https://pub.dev/packages/flutter_secure_storage — 11.0.0
- https://pub.dev/packages/shared_preferences — 2.5.5
- https://spring.io/blog/2025/10/07/introducing-jackson-3-support-in-spring
- https://owasp.org/www-project-application-security-verification-standard/

### Tertiary (LOW)
- Community Boot 4 Flyway silent-failure write-ups (cross-checked against official data-initialization page)
- ASVS 5.0 chapter renumbering (session → V7); this file keeps the RESEARCH template V2–V6 labels

Context7 MCP and `ctx7` CLI were **unavailable**. Official URLs were used instead (`research-documentation-lookup.md` fallback). No knowledge graph (`.planning/graphs/graph.json` absent).

## Metadata

**Confidence breakdown:**
- Standard stack: MEDIUM — versions confirmed on official registries; GSD classify-confidence rates WebSearch+verified as MEDIUM (WebFetch-only as LOW)
- Architecture: MEDIUM — D-24 REST bot loop is locked; module cut follows official Modulith + existing harness
- Pitfalls: HIGH for CR-01/CR-02/Flyway/Jackson (code + official Boot 4); MEDIUM for bot noise (A3)

**Research date:** 2026-09-06
**Valid until:** 2026-10-06 (30 days; Boot 4 / pub pins move faster — re-check pub.dev if planning slips)

## Planner notes (vertical slices)

MVP_MODE is on. Prefer waves like:

1. **Wave 0** — failing tests + `backend/` skeleton + l10n.yaml + router stub (catalog is home).
2. **Guest → catalog** — AUTH-01, CAT-01, CAT-03, PRES-01 skeleton.
3. **How-to** — ALCH-04 (skip from card 1).
4. **REST throw authority** — promote harness, SESS-01, ALCH-02/05; fix WR-02.
5. **Match table lift** — ALCH-01, CR-01/CR-02, clocks ALCH-03.
6. **Bots + EASY default** — BOT-01, BOT-03, PRES-02 polish.

Do not ship a horizontal “all Flyway entities” wave without a guest that can open the catalog.
