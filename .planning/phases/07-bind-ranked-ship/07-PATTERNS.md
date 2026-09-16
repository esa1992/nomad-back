# Phase 7: Bind, Ranked + Ship - Pattern Map

**Mapped:** 2026-09-14
**Files analyzed:** 28
**Analogs found:** 24 / 28

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `identity/BindService.java` | service | request-response | `identity/GuestService.java` | exact |
| `identity/GuestController.java` (+ bind/login/logout) | controller | request-response | `identity/GuestController.java` | exact |
| `identity/PasswordConfig.java` | config | request-response | `identity/SecurityConfig.java` | role-match |
| `identity/TokenService.java` (fix rotate) | service | request-response | `identity/TokenService.java` | exact |
| `identity/internal/CredentialEntity.java` + Flyway | model / migration | CRUD | `V1__identity.sql` + `RefreshTokenEntity` | role-match |
| `matchmaking/RankedQueueService.java` | service | request-response | `matchmaking/CasualQueueService.java` | exact |
| `matchmaking/RankedMatchmakingController.java` | controller | request-response | `matchmaking/CasualMatchmakingController.java` | exact |
| `session/MatchService.java` (`createRankedMatch`, settle split) | service | event-driven | `session/MatchService.java` | exact |
| `session/internal/ReconnectPolicy.java` | utility | transform | `session/internal/ReconnectPolicy.java` | exact |
| `session/internal/MatchSessionRegistry.LiveMatch` (`pauseUsedMs`) | model | event-driven | `MatchSessionRegistry.LiveMatch` | exact |
| `profile/SoftElo.java` → sibling `rating/internal/Glicko2.java` | utility | transform | `profile/SoftElo.java` | exact |
| `rating/RatingService.java` | service | CRUD | `profile/ProfileService.java` | exact |
| `profile` boards read API | controller / service | CRUD | `profile/ProfileService.getProfile` | role-match |
| `analytics/EventSink.java` | service | event-driven | `MatchService` SLF4J logger | partial |
| `games/stickpull/StickPullSim.java` (Ranked false-start) | service | event-driven | `StickPullSim.applyAcceptedTap` | role-match |
| `identity/SecurityConfig.java` (permit login) | config | request-response | `identity/SecurityConfig.java` | exact |
| `client/.../session_store.dart` | store | file-I/O | `client/lib/platform/auth/session_store.dart` | exact |
| `client/.../bind_prompt_store.dart` (prefs) | store | file-I/O | `client/lib/howto/howto_seen_store.dart` | exact |
| `client/.../bind_sheet.dart` / soft-lock | component | request-response | `games/alchiki/pause_overlay.dart` `LeaveConfirm` | role-match |
| `client/profile/profile_page.dart` | component | request-response | `client/lib/profile/profile_page.dart` | exact |
| `client/catalog/catalog_page.dart` (Ranked + Boards) | component | request-response | `client/lib/catalog/catalog_page.dart` | exact |
| `client/matchmaking/searching_page.dart` (Ranked) | component | request-response | `client/lib/matchmaking/searching_page.dart` | exact |
| `client/boards/boards_page.dart` | component | CRUD | `client/lib/profile/profile_page.dart` | role-match |
| `client/platform/router.dart` + `nomad_api.dart` | route / utility | request-response | `router.dart` + `nomad_api.enqueueCasual` | exact |
| `client/.../ResultOverlay` Ranked CTAs | component | event-driven | `pause_overlay.dart` `ResultOverlay` | exact |
| `.github/workflows/ci.yml` | config | batch | — | none |
| `Dockerfile` | config | file-I/O | — | none |
| `compose.prod.yaml` | config | file-I/O | `compose.yaml` | partial |

## Pattern Assignments

### `identity/BindService.java` (service, request-response)

**Analog:** `backend/src/main/java/com/nomadgames/identity/GuestService.java`

**Imports / DI pattern** (lines 1–28):
```java
package com.nomadgames.identity;

import java.time.Instant;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import com.nomadgames.economy.EconomyService;
import com.nomadgames.identity.internal.PlayerEntity;
import com.nomadgames.identity.internal.PlayerRepository;
import com.nomadgames.profile.ProfileService;
```

**Core mint / same-playerId TX pattern** (lines 30–39):
```java
@Transactional
public GuestSessionResponse createGuest() {
    UUID playerId = UUID.randomUUID();
    players.save(new PlayerEntity(playerId, true, Instant.now()));
    players.flush(); // FK-visible wallet/profile defaults in same TX
    economy.ensureDefaults(playerId);
    profile.ensureDefaults(playerId);
    TokenPair pair = tokens.issue(playerId, true);
    return new GuestSessionResponse(playerId, pair.accessToken(), pair.refreshToken(), true);
}
```

**Copy for bind:** Same `@Transactional` + `players.flush()` discipline; set `guest=false` on **existing** `PlayerEntity` (do not mint a new id). Call `tokens.issue(playerId, false)`. Emit `REGISTERED` via EventSink after credential save. Never call economy merge/sum.

---

### `identity/GuestController.java` (+ bind / login / logout) (controller, request-response)

**Analog:** `backend/src/main/java/com/nomadgames/identity/GuestController.java`

**Controller pattern** (lines 13–36):
```java
@RestController
public class GuestController {
    @PostMapping("/v1/identity/guest")
    @ResponseStatus(HttpStatus.CREATED)
    public GuestSessionResponse createGuest(HttpServletRequest request) {
        rateLimiter.check(clientIp(request));
        return guests.createGuest();
    }

    @PostMapping("/v1/identity/refresh")
    public TokenPair refresh(@RequestBody RefreshRequest body) {
        return tokens.rotate(body == null ? null : body.refreshToken());
    }
}
```

**Security permit list** — `SecurityConfig.java` lines 26–33:
```java
.authorizeHttpRequests(auth -> auth.requestMatchers(POST, "/v1/identity/guest", "/v1/identity/refresh")
        .permitAll()
        .requestMatchers("/actuator/health")
        .permitAll()
        // …
        .anyRequest()
        .authenticated())
```

**Copy for Phase 7:** Add `POST /v1/identity/login` to `permitAll`. `POST /v1/identity/bind` and logout require authenticated JWT. Reuse `GuestMintRateLimiter` / `JoinRateLimiter` style for login rate limit. Return `ResponseStatusException` 409 for username taken (same style as `CasualQueueService` CONFLICT).

**IT analog:** `GuestIdentityIT.java` — mint + rotate + replay reject (lines 39–76). Extend as `BindIT` with same Testcontainers + MockMvc skeleton.

---

### `identity/TokenService.java` (MODIFY rotate) (service, request-response)

**Analog:** same file — **must fix** for AUTH-03.

**Bug + issue pattern** (lines 59–78):
```java
@Transactional
public TokenPair issue(UUID playerId, boolean guest) {
    String accessToken = encodeAccess(playerId, guest);
    String refreshToken = mintRefresh(playerId);
    return new TokenPair(accessToken, refreshToken);
}

@Transactional
public TokenPair rotate(String refreshToken) {
    // … validate hash, delete old row …
    return issue(existing.getPlayerId(), true); // BUG: always guest=true
}
```

**Copy for Phase 7:** On rotate (and login/bind), look up `PlayerEntity.isGuest()` and pass that boolean into `issue`. Logout: delete all refresh rows for `playerId` (extend `RefreshTokenRepository`), then client clears secure storage and mints new guest via existing `createGuest`.

**JWT claim pattern** (lines 81–90): keep `claim("guest", guest)` — server sets claim from DB only.

---

### Credentials migration + entity (model / migration, CRUD)

**Analog:** `backend/src/main/resources/db/migration/V1__identity.sql` lines 15–17 + `V9__profile_casual.sql` alter/create style.

```sql
CREATE TABLE credentials (
    player_id UUID PRIMARY KEY REFERENCES players (id)
);
```

**Copy:** New Flyway `V11__…sql` — `ALTER TABLE credentials ADD username … UNIQUE`, `password_hash`, timestamps. Follow V9 pattern of additive alters + new tables (`glicko_ratings`, `analytics_events`) without rewriting SoftElo columns (`soft_rating` / `best_rating` stay).

---

### `matchmaking/RankedQueueService.java` (service, request-response)

**Analog:** `backend/src/main/java/com/nomadgames/matchmaking/CasualQueueService.java`

**FIFO core** (lines 35–55, 59–149 condensed):
```java
private final ConcurrentHashMap<String, ConcurrentLinkedQueue<UUID>> fifos = new ConcurrentHashMap<>();
private final ConcurrentHashMap<UUID, Ticket> tickets = new ConcurrentHashMap<>();
private final Object monitor = new Object();

public CasualQueueResponse enqueue(UUID playerId, String ip, String game) {
    String normalizedGame = GameDiscriminator.normalize(game);
    joinRateLimiter.check(ip, playerId);
    if (matches.hasInPlayHumanSeat(playerId)) {
        throw new ResponseStatusException(HttpStatus.CONFLICT, "already in play");
    }
    synchronized (monitor) {
        UUID peerId = pollWaitingPeer(playerId, normalizedGame);
        if (peerId != null) {
            UUID matchId = matches.createCasualMatch(peerId, playerId, normalizedGame);
            // mark both MATCHED …
            return toResponse(matchedSelf);
        }
        // else SEARCHING + fifo.offer
    }
}
```

**Game discriminator** — `GameDiscriminator.java` lines 13–21:
```java
public static String normalize(String game) {
    if (game == null || game.isBlank()) return ALCHIKI;
    String upper = game.trim().toUpperCase(Locale.ROOT);
    if (!ALCHIKI.equals(upper) && !STICK_PULL.equals(upper)) {
        throw new IllegalArgumentException("game");
    }
    return upper;
}
```

**Copy for Ranked sibling:** Clone FIFO maps/monitor/ticket lifecycle; call `createRankedMatch` instead of `createCasualMatch`; response `mode=RANKED`. **Do not** share CasualQueue maps. **Add bind gate:** reject if JWT/`PlayerEntity.guest==true` → 403. **No** bot/invite/empty-queue fallback path.

**Controller analog:** `CasualMatchmakingController.java` lines 19–46 — mirror as `/v1/matchmaking/ranked` with `@AuthenticationPrincipal Jwt`, `@ExceptionHandler(IllegalArgumentException)` → 400.

---

### `session/MatchService.java` — createRanked + settle + rematch split (service, event-driven)

**Analog:** same file.

**Human match factory** (lines 255–302):
```java
public static boolean isHumanPvP(String mode) {
    return "PRIVATE".equals(mode) || "CASUAL".equals(mode);
}

public UUID createCasualMatch(UUID hostId, UUID joinerId, String game) {
    return createHumanMatch(hostId, joinerId, "CASUAL", game);
}
```

**Settle → profile** (lines 948–962):
```java
private void recordProfileSettlements(MatchEntity match) {
    // build SeatSettlement list…
    profile.recordSettlement(match.getId(), match.getMode(), match.getGame(), seats);
}
```

**Copy for Phase 7:**
1. Add `createRankedMatch(..., game)` → `createHumanMatch(..., "RANKED", game)`.
2. Split helpers: wire/settle/reconnect treat Ranked as human PvP; **`allowsRematch` stays PRIVATE|CASUAL only** (D-99 — do not broaden rematch via `isHumanPvP`).
3. After settle: always XP/W/L via profile; if `RANKED` also `ratingService.recordRankedSettlement(...)`; SoftElo only when `CASUAL` (already gated in ProfileService).

---

### `profile/ProfileService.recordSettlement` + SoftElo → Glicko sibling (service / utility)

**Analog:** `ProfileService.java` lines 88–141 + `SoftElo.java` lines 6–20.

```java
@Transactional
public void recordSettlement(UUID matchId, String mode, String game, List<SeatSettlement> seats) {
    boolean casual = "CASUAL".equals(mode);
    // claimSettlement idempotency + XP/stats for every seat…
    if (casual && seats.size() == 2 && allClaimed && claimedCount == 2) {
        applyCasualElo(seats.get(0), seats.get(1));
    }
}

public static int nextRating(int rating, int opponent, double score) { /* SoftElo */ }
```

**Copy for Glicko:** New `rating/internal/Glicko2` as final utility (same “pure math, no Spring” style as SoftElo). New `RatingService` with settle-claim table (mirror `profile_settlements` / `claimSettlement`). SoftElo columns **untouched**. Defaults r=1500, RD=350, σ=0.06, τ=0.5; score ∈ {0, 0.5, 1}.

---

### `session/internal/ReconnectPolicy.java` + LiveMatch pause budget (utility / model)

**Analog:** `ReconnectPolicy.java` lines 16–67 + `MatchService.markDropped` lines 597–633 + `LiveMatch` fields 132–151.

```java
public static int graceSeconds(String game) {
    return "STICK_PULL".equals(game) ? STICK_PULL_GRACE_SECONDS : GRACE_SECONDS;
}

// MatchService.markDropped:
int grace = ReconnectPolicy.graceSeconds(match.getGame());
Instant deadline = ReconnectPolicy.graceDeadline(now, match.getGame());
```

```java
public static final class LiveMatch {
    public Instant hostGraceDeadline;
    public Instant joinerGraceDeadline;
    public FrozenClocks frozen;
    // …
}
```

**Copy for SESS-03:** Extend to `graceSeconds(mode, game)` → Ranked Alchiki 18 / Stick Pull 12; casual unchanged 30/8. Add `pauseBudgetSeconds(mode, game)` → 45/20 Ranked only. Add heap `pauseUsedMs` on `LiveMatch`; accrue during grace; if budget exhausted → next drop 0s grace → rated forfeit. Keep clock freeze (`ReconnectPolicy.freeze` / Stick Pull `pauseClock`) during grace.

---

### `games/stickpull/StickPullSim.java` Ranked false-start (service, event-driven)

**Analog:** `StickPullSim.java` lines 166–177 (D-90 ignore):

```java
/** Attempt to accept a tap at server {@code now}. Pre-GO returns accepted=false (D-90). */
public TapResult applyAcceptedTap(Side side, Instant now) {
    if (phase != StickPullPhase.LIVE) {
        return snapshot(false, now); // COUNTDOWN / pre-GO ignored
    }
    // …
}
```

**Copy for D-100:** Pass match `mode` into sim or runtime; Ranked only: 1st pre-GO → set stamina baseline `0.70`; 2nd → force rated forfeit settle. Casual keeps ignore. Unit tests extend `StickPullSimTest` (same Instant/tap style).

---

### `analytics/EventSink.java` (service, event-driven)

**Analog (partial):** `MatchService` logger — lines 24–25, 50:
```java
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
private static final Logger log = LoggerFactory.getLogger(MatchService.class);
```

**No EventSink / analytics package exists.** Copy: Modulith package like `alchiki/package-info.java` (`@ApplicationModule`). Sink API `emit(type, playerId, matchId, attrs)` → structured JSON log + insert `analytics_events`. **Never throw into settle TX** (catch+log). Hook points: guest mint / bind / login, ranked enqueue, match found/start/finish/abandon, shop purchase (`EconomyService` grant/buy).

---

### Client: session + bind prefs (store, file-I/O)

**Analog:** `session_store.dart` persist/clear (lines 38–92) + `howto_seen_store.dart` SharedPreferencesAsync (lines 8–31):

```dart
Future<void> persist({required String playerId, required String refreshToken}) async { … }
Future<void> clear() async { /* delete playerId + refresh + reconnect keys */ }

static const String seenKey = 'howto.alchiki.seen';
Future<void> markSeen() async {
  try { await _store.setBool(seenKey, true); } catch (_) {}
}
```

**Copy:** Logout = `sessionStore.clear()` then mint guest via API + `persist`. Bind prompt once: `bind.prompt.seen` mirroring howto keys.

---

### Client: bind / soft-lock / logout confirm (component, request-response)

**Analog:** `LeaveConfirm` in `pause_overlay.dart` lines 86–138 — scrim + heading/body + wood outline + destructive confirm:

```dart
class LeaveConfirm extends StatelessWidget {
  // Stay = outlined wood; Leave match = destructive fill
}
```

**Copy:** Soft-lock / progress-loss / logout confirms reuse this scrim+dual-CTA chrome. Bind sheet is **new** modal bottom sheet (no existing `showModalBottomSheet` in repo) — still use PRES-02 wood/cream/48dp from catalog `_TableButton` (catalog_page.dart ~960–999).

---

### Client: catalog Ranked CTA + Boards chip (component, request-response)

**Analog:** `catalog_page.dart` header Shop chip + `_quickMatch` (lines 271–328, 418–433):

```dart
await ref.read(nomadApiProvider).enqueueCasual();
context.go('/matchmaking');
// Stick Pull: enqueueCasual(game: 'STICK_PULL'); context.go('/matchmaking?game=stickPull');

_ShopEntry(label: l10n.shop, onTap: () => context.push('/shop'));
```

**CTA chrome:** `_TableButton` accent fill vs `outlined: true` wood+cream (lines 960–999).

**Copy:** Bound → accent Ranked above Quick Match → enqueue ranked + `/matchmaking?mode=ranked&game=`. Guest → outlined Ranked → soft-lock (no enqueue). Boards chip after Shop; guest → soft-lock.

---

### Client: Ranked searching (component, request-response)

**Analog:** `searching_page.dart` — wood scaffold, poll 500ms, Cancel dequeue (lines 89–309).

**Critical difference — remove for Ranked:**
```dart
static const Duration _fallbackAfter = Duration(seconds: 8);
_fallbackClock = Timer(_fallbackAfter, _openFallback); // → /matchmaking/fallback
```

**Copy:** Same Searching chrome + Cancel; poll ranked endpoints; navigate `mode=ranked`; **never** start `_fallbackClock` / bot fallback (D-98). Router today: `/matchmaking` → `SearchingPage(game:)` only (`router.dart` 127–132) — extend query `mode=ranked`.

---

### Client: boards page + profile auth chrome (component, CRUD)

**Analog:** `profile_page.dart` wood metrics + SoftElo Display (lines 211–278) — keep SoftElo hero; add Ranked Glicko lines + Bind/Sign in/Log out/Boards under display name.

**Router analog:** add `GoRoute(path: '/boards', …)` beside `/profile` (`router.dart` 119–126).

**API analog:** `nomad_api.dart` `enqueueCasual` / `pollCasual` / `dequeueCasual` (853–887) — mirror for ranked + `GET /v1/boards?game=&scope=`.

---

### Client: Ranked result CTAs (component, event-driven)

**Analog:** `ResultOverlay` in `pause_overlay.dart` (from line 143) — bot Play again / casual rematch-wait / private Again?.

**Copy:** Ranked branch: **no** `onRematchAccept` / Play again dual-accept. Primary accent = Find Ranked match → new ranked search; secondary Back to catalog; optional Boards TextButton. Leave Ranked uses `LeaveConfirm` with `leaveRankedBody`.

---

### Ops: `compose.prod.yaml` (config, file-I/O)

**Analog (partial):** root `compose.yaml`:
```yaml
services:
  postgres:
    image: postgres:18.6
    environment:
      POSTGRES_DB: nomad
      POSTGRES_USER: nomad
      POSTGRES_PASSWORD: nomad
```

**Copy:** Keep DEV compose Postgres-only. PROD adds `app` service (JAR from new Dockerfile), `SPRING_DATASOURCE_*`, `NOMAD_JWT_SECRET`, healthcheck `/actuator/health` (already permitAll).

### Ops: CI + Dockerfile

**No in-repo analog** (no `.github/`, no Dockerfile). Planner uses RESEARCH locks: `./mvnw -pl backend -am verify`; Flutter analyze/test; Temurin 21 + flutter-action 3.47.2.

---

## Shared Patterns

### Authentication / JWT
**Source:** `TokenService` + `SecurityConfig` + `GuestController`
**Apply to:** bind, login, logout, ranked enqueue, boards
- Access JWT 15m HS256; refresh opaque SHA-256 rotate-on-use
- `guest` claim from DB after bind fix
- Controllers: `@AuthenticationPrincipal Jwt` → `UUID.fromString(jwt.getSubject())` (see CasualMatchmakingController 52–54)

### Error handling
**Source:** `ResponseStatusException` usage in TokenService / CasualQueueService / ProfileService
**Apply to:** all new REST
- 400 IllegalArgument / password &lt; 8
- 401 invalid refresh / bad login
- 403 guest on Ranked/boards
- 409 username_taken / already in play
- Client: `NomadApiException` + Retry banners (catalog `_CatalogBanner` pattern)

### Idempotent settle claims
**Source:** `ProfileJdbc.claimSettlement` via `ProfileService.recordSettlement`
**Apply to:** Glicko / analytics side-effects — claim once per (matchId, playerId); EventSink must not fail TX

### Game discriminator + per-game FIFO
**Source:** `GameDiscriminator` + `CasualQueueService.fifos`
**Apply to:** RankedQueueService only (sibling)

### PRES-02 UI chrome
**Source:** catalog `_TableButton`, searching wood page, `LeaveConfirm`, profile Display SoftElo
**Apply to:** bind sheet, soft-lock, boards, Ranked CTAs — felt `#1B6B3A` / wood `#241810` / gold `#F0B429` / cream `#F4E8C8` / destructive `#C43C2C`; 48dp; EN+RU ARB keys from 07-UI-SPEC

### Modulith packages
**Source:** `com.nomadgames.alchiki/package-info.java` `@ApplicationModule(type = OPEN)`
**Apply to:** new `rating` + `analytics` modules with public API + `internal/`

### IT skeleton
**Source:** `GuestIdentityIT` / `CasualQueueIT` / `ReconnectIT` / `StickPullSimTest`
**Apply to:** BindIT, RankedQueueIT, RankedReconnectIT, BoardsIT, EventSinkIT, Glicko2Test

## No Analog Found

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `.github/workflows/ci.yml` | config | batch | No `.github/` in repo — use RESEARCH GHA pins |
| `Dockerfile` | config | file-I/O | No container image for app JAR yet |
| `analytics/EventSink` table schema | service | event-driven | Only ad-hoc SLF4J; design from RESEARCH (JSON + append-only) |
| Modal bottom sheet bind UI | component | request-response | No `showModalBottomSheet` usage; compose from LeaveConfirm + `_TableButton` tokens |

## Metadata

**Analog search scope:** `backend/src/main/java/com/nomadgames/{identity,matchmaking,session,profile,games,economy}`, `backend/src/main/resources/db/migration`, `backend/src/test/java`, `client/lib/{platform,catalog,profile,matchmaking,howto,games}`, root `compose.yaml`
**Files scanned:** ~45 primary + greps across session/matchmaking/client
**Pattern extraction date:** 2026-09-14
)
