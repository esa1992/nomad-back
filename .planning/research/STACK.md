# Stack Research

**Domain:** Mobile multiplayer traditional-games platform (Nomad Games)
**Researched:** 2026-09-05
**Confidence:** HIGH for the prescription (physics+multiplayer criteria force one stack); MEDIUM for exact patch pins that will move

Seam-classified transport: `webfetch` = LOW, `websearch --verified` = MEDIUM, Context7 MCP unavailable this runtime. Version pins below rest on **first-party pages** (docs.flutter.dev, pub.dev, spring.io, docs.spring.io, postgresql.org, Maven Central, godotengine.org, Unity Manual). Treat those URLs as primary even when the transport tag is LOW. Do not treat community blogs as version authority.

## Prescription (do not reopen)

| Decision | Choice | Why this, not the runner-up |
|----------|--------|------------------------------|
| **Client engine** | **Flutter 3.47 + Flame 1.38 + Forge2D 0.15** | Server is the physics authority (see ARCHITECTURE.md). Unity/Godot do **not** reduce the #1 risk — their solvers do not run on the JVM. Flutter+Flame is the only short list that ships a catalog/account shell **and** a 60 FPS keyframe replay in one binary a single developer + AI agents can maintain. |
| **Dimensionality** | **2.5D presentation, 2D physics** | Circle + 5–7 bones. Visual spin must read; bone-faithful 3D mesh and alshy-face scoring are out of v1. 2D rigid bodies (disk/capsule) + slight camera tilt + sprite rotation. |
| **Client physics** | **Forge2D 0.15.1** (`flame_forge2d` 0.20.0) | Box2D v3: mass, velocity, impulse, friction, restitution, rotation, sleep. Used for the **prototype feel** and optional later local preview. **Not** the multiplayer authority. |
| **Server physics** | **dyn4j 6.0.0** | Maintained pure-Java 2D solver. jbox2d is unmaintained. No Unity/Godot dedicated server. |
| **Networking** | **REST + raw WebSocket** (JSON frames, not STOMP/SockJS, not UDP) | Owner-locked. Alchiki is a short reliable keyframe buffer; Stick Pull is 10–20 Hz. TCP/WS is enough. |
| **Backend** | **Java 21 + Spring Boot 4.1.1 + Spring Modulith 2.1.1** | No strong reason against the owner preference. Burst physics and a 20 Hz tug do not justify Go/Nest. |
| **Database** | **PostgreSQL 18.6**. **No Redis on day one** | Confirms ARCHITECTURE.md. One JVM, in-process queues/sessions. |
| **Auth tokens** | **Access JWT (HS256, ~15 min) + opaque rotating refresh** in Postgres | First-party issuer. No Keycloak / Auth Server / OAuth in MVP. |
| **Passwords** | **Argon2id** via Spring Security 7 `Argon2PasswordEncoder` inside `DelegatingPasswordEncoder` | Spring Security 7 docs: Argon2 is recommended for new apps. |
| **Rating** | **Glicko-2**, vendored in-repo | Sparse play + RD. Elo under-rates uncertainty. No Maven Glicko-2 worth depending on. |
| **Prototype family** | **Same as production** | Phase 1 is Flutter+Flame+Forge2D **plus** a JVM dyn4j harness that emits keyframes Flame interpolates. Do **not** prototype in Unity/Godot and then rewrite. |

## Recommended Stack

### Core Technologies

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| Flutter SDK | **3.47.0** (Dart **3.13.0**) | One Android + iOS client | Current stable (docs.flutter.dev, 2026-08-12). Widgets own catalog, auth, shop, i18n. Impeller path is production. iOS minimum **15** (3.47 announcement). |
| Flame | **1.38.2** | Game loop, sprites, camera, gestures, keyframe interpolation | Current pub.dev. Widgets are not a 60 FPS loop. Flame is the official Flutter game engine; overlay it inside the Flutter shell. |
| forge2d | **0.15.1** | Client rigid-body solver (prototype + optional preview) | Native Box2D v3 via FFI. Proves hold-to-throw feel. Top-down: `World(gravity: Vector2.zero())`. |
| flame_forge2d | **0.20.0** | Flame ↔ Forge2D bridge | Current; adapted to Flutter 3.47. Breaking vs 0.19 — start on 0.20, do not straddle. |
| Eclipse Temurin JDK | **21** (LTS) | Backend + dyn4j harness | Boot 4.1 allows 17–26; 21 is the LTS AI agents and Docker images know. Do not jump to 25 for a one-dev MVP. |
| Spring Boot | **4.1.1** | Modular monolith HTTP + WS | Current stable (spring.io, 2026-08-20). Owner preference stands: Alchiki is a burst, Stick Pull is 10–20 Hz — not a reason to leave the JVM. |
| Spring Framework / Security | BOM via Boot 4.1.1 (**Framework 7.0.9**, **Security 7.1.x**) | Filters, JWT decoder, Argon2 | Let the Boot BOM pin. Do not override Security by hand. |
| Spring Modulith | **2.1.1** | Package modules + `ApplicationModules.verify()` | Released against Boot 4.1.1 (2026-08-26). Matches ARCHITECTURE.md `identity` / `session` / `games.*`. |
| dyn4j | **6.0.0** | Server Alchiki physics (simulate-to-rest → keyframes) | Maven Central current. 100% Java, no JNI. 5–15 bodies, 60–120 Hz burst, then sleep. |
| PostgreSQL | **18.6** (`postgres:18.6` official image) | Source of truth | Current stable (postgresql.org, 2026-08-13). Pin the minor tag in Compose. |
| Flyway | **12.4.0** (`flyway-core` + `flyway-database-postgresql`) | Schema migrations | Version from Spring Boot 4.1 managed coordinates. One history for DEV/TEST/PROD. |
| Docker Compose | Compose v2 (no K8s) | DEV/TEST/PROD topology | App + Postgres only. Redis later. |

### Supporting Libraries

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| go_router | **18.0.0** | Catalog / auth / shop / match routes | Always. Deep links for room codes later. |
| flutter_riverpod | **3.4.3** | Client session, tokens, catalog cache | Always. One pattern AI agents generate well. No Bloc. |
| dio | **5.11.0** | REST client + 401→refresh interceptor | Always. Separate Dio instance for `/refresh` (no interceptor loop). |
| web_socket_channel | **3.0.3** | Match WebSocket | Match session only. One socket owned by `platform/session`. |
| flutter_secure_storage | **10.3.1** | Device guest UUID, refresh token, reconnect token | Always. Not SharedPreferences. |
| flutter_localizations + intl | SDK / BOM | EN+RU, keyed i18n | Day one. Turkic locales later. |
| nimbus-jose-jwt | BOM (**10.9** via Security 7.1) | Sign/verify access JWT | Transitive via `spring-security-oauth2-jose`. Do not declare a floating version. |
| spring-boot-starter-websocket | 4.1.1 | Raw `WebSocketHandler` | Match channel. **Disable STOMP/SockJS.** |
| spring-boot-starter-data-jpa | 4.1.1 | Identity, catalog, profile, rooms | Default persistence. |
| JdbcClient (spring-jdbc) | BOM | Economy ledger writes | `economy` module only — idempotent INSERT, never “load entity, mutate balance”. |
| HikariCP | BOM | Pool | Default. Size for one JVM. |
| PostgreSQL JDBC | **42.7.13** | Driver | BOM-managed. |
| Testcontainers | **2.0.5** | TEST Postgres | `spring-boot-testcontainers`. |
| spring-boot-starter-actuator | 4.1.1 | `/actuator/health` | Always. No Prometheus in MVP. |
| Bucket4j | *later* | Rate limits | In-process when abuse appears; Redis-backed only with a second instance. |

### Development Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| Android Studio / VS Code + Flutter + Java plugins | Daily IDE | Cursor/AI agents work on Dart + Java text, not Unity YAML. |
| Flutter stable channel | Client SDK | `flutter channel stable && flutter upgrade`. Pin CI to 3.47.x. |
| Maven (not Gradle) | Backend build | One `pom.xml`, Boot parent 4.1.1. AI + Spring samples are Maven-first. |
| Docker Desktop | Postgres + later PROD compose | DEV: app on host, DB in Docker (`spring-boot-docker-compose`). |
| GitHub Actions | CI | `flutter test` + `mvn verify` + Modulith verify. No K8s deploy. |
| Android NDK (r28+ as Flutter requires) | Forge2D 0.15 native assets | Needed because 0.15 compiles bundled Box2D C. Install once; do not skip. |
| Xcode (macOS) | iOS archive | Required for any client stack. iOS 15+ / Xcode current. |

## Explicit decisions

### Client engine — Flutter + Flame + Forge2D

**Deciding criteria were physics quality + multiplayer path, not “Flutter is easy” and not “games use Unity.”**

ARCHITECTURE.md already froze authority: client sends aim+power; **server** steps physics to sleep; clients **replay keyframes**. Therefore a client engine “wins” only if it can (1) prove a readable throw at 60 FPS, (2) interpolate a server keyframe buffer, (3) host a catalog/account platform, (4) stay one codebase for one developer + AI.

Unity’s Physics Core 2D and Godot Physics **do not run inside Spring**. Picking them does **not** close the sync risk unless we also throw away Java (forbidden) or run a second dedicated-server process (forbidden complexity).

### Dimensionality — 2.5D, not 3D

| Option | Verdict |
|--------|---------|
| **2D** | Physics yes. Presentation too flat — rotation of a bone/saka will not “read” as skill. |
| **2.5D (chosen)** | 2D dyn4j/Forge2D world (XY, gravity 0). Camera slight tilt or 3/4 sprites. Disk/capsule colliders. Spin is a sprite/normal, not a 3D inertia tensor. |
| **3D** | Rejected. FEATURES.md cut alshy-face scoring as unreadably 3D. 5–7 parlor pieces do not justify PhysX/Godot 3D or a 3D art pipeline. |

### Client physics — Forge2D (Box2D v3)

Flame’s built-in collision is AABB overlap. That cannot prove mass, impulse, friction, restitution, or sleep. Forge2D 0.15.1 is the current Flame-official solver and is **the real Box2D v3**, not the old Dart port.

Use it in:

1. **Alchiki Physics Prototype** — local throw feel on a mid Android device.
2. **Optional later** — throwing-client preview that morphs to server keyframes. Server still wins.

Do **not** lockstep Forge2D against dyn4j. Float + two engines = desync that looks like cheating.

**Fallback (same family, not a new engine):** if native assets / NDK block the first prototype week, pin `flame_forge2d` 0.19.x + `forge2d` 0.14.x (pure Dart). Same Flame app. Switch back to 0.20 once NDK is green.

### Server physics — dyn4j, not jbox2d

| Library | Status (2026-09) | Verdict |
|---------|------------------|---------|
| **dyn4j 6.0.0** | Maven Central current; 6.0.0 (2026-07) adds `Copyable` | **Use.** Headless, no GPU, burst 1–3 s of sim. |
| jbox2d | deps.dev Maintained **0/10** (2026-07); BountySource-era | **Do not use.** Same “Box2D family” story as old Forge2D 0.14 — still not bit-identical, and abandoned. |
| Box2D JNI on the server | Native per OS in Docker | Rejected. One more toolchain for 8 bodies. |
| Unity / Godot dedicated server | Second runtime | Rejected. Breaks Java monolith. |

dyn4j getting-started HTML still shows 5.0.2 — **ignore the stale snippet; pin 6.0.0 from Maven Central.**

### Networking — REST + raw WebSocket

- **REST:** identity, catalog, matchmaking tickets, room codes, shop, profile. JWT `Authorization: Bearer`.
- **WebSocket:** one match URL. First frame or query ticket authenticates. Message types: `ThrowInput`, `TapWindow`, `ThrowResolved` (keyframes), `StickSnapshot`, `RejoinSnapshot`, `Ping`.
- **Not STOMP / SockJS.** Spring’s WebSocket chapter treats STOMP as an optional sub-protocol for pub/sub apps. It fights binary/JSON game frames and reconnect tokens.
- **Not UDP / KCP / Steam.** Alchiki is a closed reliable buffer (~few KB/throw). Stick Pull is 10–20 Hz on a 15–40 s match. Mobile NAT + WS through 443 is the operable path.
- **Not Colyseus / Nakama as the backend.** Steal room/rejoin patterns only (ARCHITECTURE.md).

### Backend — Java + Spring Boot stands

Compared because the owner asked. **No strong reason against Java:**

| Backend | Verdict |
|---------|---------|
| **Spring Boot 4.1.1 + Modulith 2.1.1** | **Use.** One JAR, plugin `GameEngine`, Flyway, Testcontainers, raw WS. |
| NestJS / Node | Faster CRUD demos; **worse** server physics (JS solvers + two languages). AI-easy is not a reason. |
| Go | Fine for tick servers at huge CCU. We are one JVM, burst physics, 1v1. Extra language for the AI agent. |
| PlayFab / Nakama-as-product | Out of “modular monolith we own.” |

### Database — Postgres yes, Redis no (confirmed)

ARCHITECTURE.md is **correct**. Refute Redis-on-day-one:

| Data | Day one | Redis later |
|------|---------|-------------|
| Identity, ledger, ratings, rooms, analytics_events | Postgres | Never as truth |
| Matchmaking queues | In-process | Redis ZSET when a **second app instance** exists |
| Live physics / seats | JVM heap | Never Redis |
| Rate limits | In-process | Redis-backed Bucket4j at 2+ nodes |
| Leaderboard | `ORDER BY` | Optional ZSET cache of top N |

Do not add Redis “because games use Redis.”

**Compose note:** Postgres 18 official image moved `PGDATA` to `/var/lib/postgresql/18/docker`. Mount `/var/lib/postgresql`, not the old `/var/lib/postgresql/data` path, or restores will surprise you.

### Auth tokens

| Token | Form | Lifetime | Storage |
|-------|------|----------|---------|
| Access | JWT, **HS256**, claims `sub`=playerId, `guest` bool, `jti` | **15 minutes** | Memory only |
| Refresh | **Opaque** 32-byte random, **SHA-256** stored in Postgres | **30 days**, **rotate** on every use (old hash revoked) | `flutter_secure_storage` |
| WS ticket | Short-lived JWT or one-time nonce from REST | **60 seconds** to connect | Memory |
| Reconnect | Opaque, bound to `playerId` + `matchId` | Mode grace (ARCHITECTURE.md) | Secure storage |

HS256 is correct for **one** monolith. Switch to RS256 only if a second verifier appears.

Do **not** stand up Spring Authorization Server, Keycloak, Firebase Auth, or Cognito for guest + username/password.

Passwords: `DelegatingPasswordEncoder` with encode id `argon2@SpringSecurity_v5_8` (`Argon2PasswordEncoder.defaultsForSpringSecurity_v5_8()`). Spring Security 7 also documents `Argon2Password4jPasswordEncoder` as the newer Argon2id path — acceptable if the 7.1.x javadoc on your BOM includes it; otherwise the v5_8 factory is enough. Never bcrypt-only “because the factory default is bcrypt” on a greenfield.

Guest: client-generated UUID in secure storage (not advertising ID) → `Player` + `device` credential.

### Rating — Glicko-2, not Elo

Glickman’s Glicko-2 exists because **Elo assumes regular play**. Nomad Ranked will be sparse (a few 2–5 min matches). RD (rating deviation) + volatility keep a new or returning player from being treated as a settled 1500.

**Implementation:** vendor ~200 lines in `rating/internal` from Glickman’s 2013 procedure (same algorithm Lichess keeps as a Java `RatingCalculator`). Defaults: r=1500, RD=350, σ=0.06, τ=0.5–0.75. Period = calendar day or “N ranked games”, not “after every match with RD stuck at 350 forever” and not “one giant period of a year.”

| Avoid | Why |
|-------|-----|
| Elo | No RD; smurfs and idle accounts distort fast. |
| Maven `goochjs/glicko2` | Not on Central; repo idle. Copy the algorithm, do not add a zombie JAR. |
| Scala `sglicko2` | Second language on a Java monolith. |
| TrueSkill | Heavier, Microsoft-flavored, 1v1 does not need it. |

Soft season reset stays a product policy on top of Glicko-2, not a reason to pick Elo.

## Engine comparison (physics + multiplayer decide)

Scores are for **this** product: server-authoritative 1v1 parlor + catalog/account, one developer + AI, Java backend locked.

| Criterion | Flutter widgets only | Flutter + Flame | **Flutter + Flame + Forge2D (chosen)** | Unity 6.3 LTS (6000.3.x) / 6.6 Supported | Godot **4.7.2** |
|-----------|----------------------|-----------------|----------------------------------------|------------------------------------------|-----------------|
| Rigid-body feel (mass, impulse, friction, restitution, rotation, sleep) | None | AABB only — **fails the prototype gate** | **Box2D v3 native** — passes the gate | Physics Core 2D = Box2D v3; or PhysX 3D | Godot Physics 2D — good enough locally |
| **Server-authoritative path with Java** | Replay only, no feel proto | Replay only | Local feel **+** dyn4j keyframes (two solvers, one protocol) | PhysX/Core2D **≠** dyn4j. Helps only with a Unity dedicated server | Godot Physics **≠** dyn4j. Same split |
| Lockstep two phones | N/A | N/A | **Do not.** FFI Box2D ≠ JVM dyn4j | Do not across mobile SOCs + JVM | Do not |
| Catalog / account / shop / i18n | Excellent | Excellent (widgets around `GameWidget`) | **Excellent** | UI Toolkit possible; CRUD platform is the tax | Control nodes; weakest of the three for a shop+profile shell |
| Stick Pull (tap + stamina bar) | Widgets are enough | Widgets or Flame | Widgets; **no physics world** | Overkill | Fine |
| AI agent fluency | High | High | High (Dart + pubspecs) | Low (scenes, YAML, `.meta`) | Medium (GDScript less in training) |
| Store pipeline | First-class Android/iOS | Same | Same (+ NDK for 0.15) | Hub, licenses, long CI | Android OK; iOS still Xcode |
| Prototype = production? | No (cannot prove physics) | No (cannot prove impulse) | **Yes** | Only if the whole product becomes Unity — then Java backend is a second universe | Only if the whole product becomes Godot |
| **Physics+MP verdict** | Fail | Fail gate | **Win** — feel on device, truth on JVM, replay on Flame | Lose on *this* architecture: extra engine, no JVM solver, platform UI cost | Lose: same split as Flutter, worse shell, weaker agents |

**Unity is rejected** because it does not own the match result (Java does) and it makes the majority of Nomad screens (catalog, guest bind, shop, leaderboard, i18n) more expensive. That is a physics+multiplayer + platform argument, not “apps should be Flutter.”

**Godot is rejected** for the same split plus a weaker account-platform story and weaker AI-codegen.

**Flutter without Flame** is rejected: no game loop, no camera, no interpolation clock.

**Flutter + Flame without Forge2D** is rejected: the prototype cannot prove the throw.

## Installation

Client (`client/`):

```bash
# SDK
flutter channel stable
flutter upgrade
# expect: Flutter 3.47.x · Dart 3.13.x

flutter create --org com.nomadgames --platforms=android,ios nomad_games
cd nomad_games

flutter pub add flame:1.38.2
flutter pub add flame_forge2d:0.20.0
flutter pub add forge2d:0.15.1
flutter pub add go_router:18.0.0
flutter pub add flutter_riverpod:3.4.3
flutter pub add dio:5.11.0
flutter pub add web_socket_channel:3.0.3
flutter pub add flutter_secure_storage:10.3.1
flutter pub add intl
```

`pubspec.yaml` also needs `flutter_localizations` from the SDK. Android: install NDK so Forge2D 0.15 native assets compile.

Backend (`backend/` — Maven, Boot parent **4.1.1**):

```xml
<parent>
  <groupId>org.springframework.boot</groupId>
  <artifactId>spring-boot-starter-parent</artifactId>
  <version>4.1.1</version>
</parent>
<properties>
  <java.version>21</java.version>
</properties>
<!-- starters: web, websocket, security, data-jpa, flyway, actuator, validation -->
<!-- extra: spring-modulith-starter-core 2.1.1, dyn4j 6.0.0 -->
<!-- flyway-database-postgresql (required in Flyway 10+) -->
<!-- test: spring-boot-starter-test, spring-boot-testcontainers, modulith-starter-test -->
```

```xml
<dependency>
  <groupId>org.dyn4j</groupId>
  <artifactId>dyn4j</artifactId>
  <version>6.0.0</version>
</dependency>
<dependency>
  <groupId>org.springframework.modulith</groupId>
  <artifactId>spring-modulith-starter-core</artifactId>
  <version>2.1.1</version>
</dependency>
```

Compose (DEV/PROD):

```yaml
services:
  postgres:
    image: postgres:18.6
    environment:
      POSTGRES_DB: nomad
      POSTGRES_USER: nomad
      POSTGRES_PASSWORD: nomad
    volumes:
      - pgdata:/var/lib/postgresql
volumes:
  pgdata:
```

No Redis service.

## Prototype stack = production family

Phase 1 **Alchiki Physics Prototype** must ship in this family or the gate is meaningless.

| Layer | Prototype | Production |
|-------|-----------|------------|
| Client render / input | Flutter 3.47 + Flame 1.38 + hold-to-throw | Same |
| Client solver | Forge2D 0.15 world, 5–7 disks, sleep | Optional preview only |
| Authority solver | **dyn4j 6.0.0** CLI/JUnit harness: `ThrowInput` → keyframes | `games.alchiki` inside Spring |
| Playback | Flame interpolates harness keyframes (even from a file) | Flame interpolates WS `ThrowResolved` |
| FPS target | Stable 60 on a mid Android | Same |

**Pass:** collisions, rotation, friction, restitution, hold-to-throw, bodies sleep, mid-Android FPS, **and** a non-client scorer (dyn4j) that consumes the same `ThrowInput`.

**Fail → change stack before accounts.** Do not “finish the shop in Flutter and add physics later.” Do not prototype in Unity “just to feel bones” — that produces a throwaway and a second art pipeline.

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| Flutter+Flame+Forge2D | Unity 6.3 LTS | Only if the owner drops Java and runs a Unity dedicated server as authority — not this project. |
| Flutter+Flame+Forge2D | Godot 4.7.2 | Only if the product becomes a single game with almost no account shell and the team is Godot-native. |
| Flutter+Flame+Forge2D | Flutter+Flame (no Forge2D) | Never for Alchiki. Stick Pull alone could skip Forge2D. |
| Flutter+Flame+Forge2D | Flutter widgets only | Never. Fails the prototype gate. |
| dyn4j 6.0.0 | jbox2d | Never on a 2026 greenfield. |
| dyn4j 6.0.0 | libGDX Box2D JNI | If we already had a libGDX server. We do not. |
| Spring Boot 4.1.1 | NestJS / Go | If the backend were a thin BaaS with **no** JVM physics. We have dyn4j in-process. |
| Spring Boot 4.1.1 | Spring Boot 3.5.x | Only if a blocker appears on 4.1 (Jackson 3 / split starters). 3.5 OSS ended 2026-06-30 — do not start there. |
| PostgreSQL 18.6 | Postgres 17.11 | If an extension we need is not on 18. None identified. |
| No Redis | Redis 8.x | Second app instance, or measured queue latency. Not before. |
| Glicko-2 in-repo | Elo | Never for Ranked with sparse matches. |
| HS256 access + opaque refresh | Spring Authorization Server | If we grow a second public API. Not MVP. |
| Maven | Gradle | If the owner already standardizes on Gradle. Otherwise Maven. |
| Riverpod | flutter_bloc | If the owner already writes Bloc. Do not run both. |

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| Unity “because it is a game” | Does not run on the Java authority; catalog/account becomes the expensive part | Flutter+Flame+Forge2D + dyn4j |
| Flutter “because apps are easy” as the *reason* | Wrong criterion; would have picked widgets-only and failed physics | Flame+Forge2D for the throw, widgets for the shell |
| Flutter without Flame | No 60 FPS interpolation clock | Flame `GameWidget` |
| Flame without Forge2D | Cannot prove impulse/friction/restitution | `flame_forge2d` 0.20 |
| Lockstep Forge2D ↔ dyn4j / jbox2d | Cross-engine floats desync; looks like cheating | Server sim + keyframe replay |
| 3D / PhysX / alshy-face as v1 | Unreadable on a phone; art and sync cost | 2.5D sprites, 2D colliders |
| jbox2d | Unmaintained | dyn4j 6.0.0 |
| Colyseus / Nakama as the app | Second backend, not Java | Spring `MatchSession` + their *patterns* |
| STOMP / SockJS | Chat/app protocol; broker destinations | Raw `WebSocketHandler` |
| Redis on day one | One JVM; economy must not live in a cache | Postgres + heap |
| Microservices / K8s | Owner-forbidden; one developer | One JAR, Compose |
| Firebase Auth / PlayFab login | Owner locked guest + username/password | Our `identity` module |
| Keycloak / Spring Auth Server | Ops surface for two token types we can issue ourselves | HS256 JWT + opaque refresh |
| Elo | Sparse Ranked | Glicko-2 |
| Coin-ladder / TrueSkill | Wrong product / overkill | Glicko-2 per game |
| Amplitude / Grafana / OTel in MVP | Owner: instrument, do not platform | `EventSink` + JSON logs |
| IAP SDKs in MVP | Owner-locked | Ledger columns reserved, unused |
| Bloc + Riverpod together | Two patterns for one agent | Riverpod only |
| Freezed / code-gen soup on WS frames | Slows the prototype | Hand-written DTOs + `dart:convert` |

## Stack Patterns by Variant

**If the Forge2D 0.15 NDK/native-assets build fails in week 1:**

- Stay on Flame 1.38. Drop to `flame_forge2d` 0.19.x + `forge2d` 0.14.x (Dart port).
- Because the production path is still Flame replay + dyn4j. Do not switch to Unity.

**If dyn4j sleep/stacking feels worse than Forge2D in the harness:**

- Tune masses, friction, restitution, and collider shapes first (FEATURES.md: visual clarity > bone mesh).
- Because swapping to JNI Box2D on the server is a Docker/ABI tax for eight bodies.
- Revisit only if the prototype gate fails after tuning.

**If mid-Android FPS < 50 with 7 bodies + interpolation:**

- Drop shadows/overdraw; keep 10–20 Hz keyframes; do not raise to 60 Hz net.
- Because the bottleneck will be fill rate, not dyn4j (server burst is milliseconds).

**If a second Spring instance is actually deployed:**

- Add Redis for queues + rate limits + reconnect routing hint.
- Because sticky WS + in-process queues will not span processes. Still no K8s.

**If Ranked ships:**

- Glicko-2 + bind-required + no cosmetics in the update.
- Because guest smurfs and P2W cues destroy the honesty promise.

## Version Compatibility

| Package A | Compatible With | Notes |
|-----------|-----------------|-------|
| Flutter 3.47.0 | Dart 3.13.0, Flame 1.38.2, flame_forge2d 0.20.0 | 0.20 changelog: “Adapt to Flutter 3.47”. |
| forge2d 0.15.1 | Dart ≥ 3.12, Flutter ≥ 3.38, C toolchain/NDK | Breaking vs 0.14. Call `initializeForge2D()`. Web uses bundled WASM (~220 KB) if we ever ship web — we do not in MVP. |
| flame_forge2d 0.20.0 | forge2d 0.15.x, Flame 1.38.x | Do not mix 0.20 with forge2d 0.14. |
| Spring Boot 4.1.1 | Java 21, Modulith 2.1.1, Security 7.1.x, Framework 7.0.9 | Jackson **3** (Boot 4 generation). Watch Modulith Rabbit/Jackson2 notes — we do not use Rabbit. |
| Flyway 12.4.0 | `flyway-database-postgresql` **required** | Community DB support split out. Starter without the PG module fails at runtime. |
| Testcontainers 2.0.5 | Boot 4.1 `spring-boot-testcontainers` | Compose support skipped in tests unless opted in (Boot 3.4+ docs; still the model). |
| postgres:18.6 | Volume `/var/lib/postgresql` | PGDATA is versioned under 18/docker. |
| Spring Security 7.1 + nimbus-jose-jwt 10.9 | HS256 `NimbusJwtDecoder` / `NimbusJwtEncoder` | Resource-server JWT support lives in `oauth2-jose`. We are the issuer, not a third-party IdP. |
| go_router 18 | Flutter 3.47 | 18.0.0 published days before this research — read the 18.0 migration notes on first use. |

## Sources

Official / first-party (treat as HIGH despite `webfetch` = LOW transport):

- https://docs.flutter.dev/release/release-notes — Flutter **3.47.0** current stable
- https://docs.flutter.dev/release/whats-new — 3.47 + Dart 3.13, 2026-08-12
- https://pub.dev/packages/flame — **1.38.2**
- https://pub.dev/packages/forge2d — **0.15.1**, Box2D v3 FFI, gravity/sleep/units
- https://pub.dev/packages/flame_forge2d — **0.20.0**, Flutter 3.47 adapt, Box2D v3 migration
- https://pub.dev/packages/go_router — **18.0.0**
- https://pub.dev/packages/flutter_riverpod — **3.4.3**
- https://pub.dev/packages/dio — **5.11.0**
- https://pub.dev/packages/web_socket_channel — **3.0.3**
- https://pub.dev/packages/flutter_secure_storage — **10.3.1**
- https://spring.io/blog/2026/08/20/spring-boot-4-1-1-available-now — Boot **4.1.1**
- https://docs.spring.io/spring-boot/4.1/appendix/dependency-versions/coordinates.html — Flyway 12.4.0, Testcontainers 2.0.5, PostgreSQL JDBC 42.7.13
- https://github.com/spring-projects/spring-modulith/releases — Modulith **2.1.1** (Boot 4.1.1)
- https://docs.spring.io/spring-framework/reference/web/websocket.html — raw WS vs STOMP/SockJS
- https://docs.spring.io/spring-security/reference/servlet/oauth2/resource-server/jwt.html — Nimbus JWT resource server
- https://docs.spring.io/spring-security/reference/7.0-SNAPSHOT/features/authentication/password-storage.html — Argon2 recommended for new apps
- https://central.sonatype.com/artifact/org.dyn4j/dyn4j — dyn4j **6.0.0**
- https://www.postgresql.org/about/news/postgresql-186-1711-1615-1519-1424-and-19-beta-3-released-3365/ — Postgres **18.6** (2026-08-13)
- https://hub.docker.com/_/postgres — `postgres:18.6`, PGDATA change
- https://godotengine.org/download/archive/4.7.2-stable/ — Godot **4.7.2** (2026-08-18)
- https://unity.com/releases/unity-6/support — Unity **6.3 LTS**; 6.6 is current Supported
- https://docs.unity3d.com/6000.5/Documentation/Manual/WhatsNewUnity65.html — Physics Core 2D = Box2D v3
- https://www.glicko.net/glicko/glicko2.pdf — Glicko-2 procedure (Glickman)

Community / scorecards (MEDIUM — `websearch --verified`):

- https://deps.dev/project/github/jbox2d/jbox2d — jbox2d Maintained 0/10 (2026-07)
- https://github.com/goochjs/glicko2 — common Java Glicko-2; vendor the algorithm, do not depend
- https://github.com/lichess-org/lila (rating module) — production use of the same algorithm family

---
*Stack research for: Nomad Games — mobile multiplayer traditional parlor platform*
*Researched: 2026-09-05*
