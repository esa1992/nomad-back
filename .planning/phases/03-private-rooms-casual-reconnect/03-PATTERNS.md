# Phase 3: Private Rooms + Casual Reconnect - Pattern Map

**Mapped:** 2026-09-07
**Files analyzed:** 48
**Analogs found:** 42 / 48

Planner: copy the cited line ranges, not “the vibe.” Wave 0 **must** invert `games ↔ session` before any two-player type is added. Do **not** copy `@ApplicationModule(Type.OPEN)` from `com.nomadgames.alchiki` onto `games`.

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `backend/.../session/GameEngine.java` | service (SPI) | transform | same file + `AlchikiEngine.java` | exact |
| `backend/.../session/MatchStatus.java` | model | transform | `games/alchiki/MatchStatus.java` | exact (move) |
| `backend/.../games/alchiki/MatchStatus.java` | model | — | delete after move; `AlchikiRules` must import session enum | exact |
| `backend/.../games/alchiki/AlchikiEngine.java` | service | transform | same file | exact |
| `backend/.../games/alchiki/AlchikiRules.java` | utility | transform | same file (`resolve` return type → session `MatchStatus`) | exact |
| `backend/.../session/MatchService.java` | service | CRUD + request-response | same file | exact |
| `backend/.../session/internal/MatchEntity.java` | model | CRUD | same file + `RefreshTokenEntity` for hashed token columns | role-match |
| `backend/.../session/MatchController.java` | controller | request-response | same file | exact |
| `backend/.../session/MatchSnapshot.java` | model | request-response | same file (add seats / opponent scores) | exact |
| `backend/.../identity/SecurityConfig.java` | config | request-response | same file | exact |
| `backend/pom.xml` | config | — | same file (`spring-boot-starter-*` BOM, no version) | exact |
| `backend/.../db/migration/V3__rooms_and_seats.sql` | migration | file-I/O | `V2__matches.sql` | exact |
| `backend/.../matchmaking/RoomController.java` | controller | request-response | `session/MatchController.java` | exact |
| `backend/.../matchmaking/RoomService.java` | service | CRUD | `session/MatchService.java` | role-match |
| `backend/.../matchmaking/internal/RoomEntity.java` | model | CRUD | `session/internal/MatchEntity.java` | role-match |
| `backend/.../matchmaking/internal/RoomRepository.java` | model | CRUD | `session/internal/MatchRepository.java` | exact |
| `backend/.../session/MatchWebSocketConfig.java` | config | streaming | **none** — RESEARCH Pattern 4 | none |
| `backend/.../session/internal/MatchWebSocketHandler.java` | controller | streaming | **none** — Spring `TextWebSocketHandler` | none |
| `backend/.../session/internal/WsTicketInterceptor.java` | middleware | request-response | **none** (auth analog: `SecurityConfig` + `TokenService`) | none |
| `backend/.../session/internal/MatchSession.java` | service | event-driven | `MatchService` (authority) + heap, not JPA | role-match |
| `backend/.../session/internal/ReconnectPolicy.java` | utility | event-driven | `TokenService.rotate` + `GuestMintRateLimiter` clock | role-match |
| `backend/.../identity/internal/JoinRateLimiter.java` (optional) | middleware | request-response | `GuestMintRateLimiter.java` | exact |
| `harness/.../Dyn4jBurstSim.java` | utility | transform | same file `simulate` — **new method only** | role-match |
| `backend/.../session/ThrowAuthorityIT.java` | test | request-response | same file | exact |
| `backend/.../matchmaking/RoomIT.java` | test | request-response | `ThrowAuthorityIT` + `CatalogIT` | role-match |
| `backend/.../session/ReconnectIT.java` | test | request-response | `GuestIdentityIT#refreshRotatesAndRejectsReplay` | role-match |
| `backend/.../session/RematchIT.java` | test | request-response | `ThrowAuthorityIT` MockMvc | role-match |
| `backend/.../session/LeaveIT.java` | test | request-response | `ThrowAuthorityIT#leaveMatchReturnsBotWin` | exact |
| `backend/.../ModularityTest.java` | test | — | same file (must go green; do not change assertion) | exact |
| `client/lib/catalog/catalog_page.dart` | component | request-response | same file | exact |
| `client/lib/platform/router.dart` | route | request-response | same file | exact |
| `client/lib/platform/api/nomad_api.dart` | service | request-response | same file | exact |
| `client/lib/platform/session/match_socket.dart` | service | streaming | **none** — `NomadApi` error wrap + RESEARCH Dart snippet | none |
| `client/lib/platform/auth/session_store.dart` | store | file-I/O | same file | exact |
| `client/lib/games/alchiki/match_page.dart` | component | request-response + streaming | same file | exact |
| `client/lib/games/alchiki/match_game.dart` | component | event-driven | same file + `saka_body.dart` | exact |
| `client/lib/games/alchiki/pause_overlay.dart` | component | request-response | same file | exact |
| `client/lib/games/alchiki/match_hud.dart` | component | request-response | same file | exact |
| `client/lib/game/saka_body.dart` | component | event-driven | same file | exact |
| `client/lib/rooms/lobby_page.dart` | component | request-response | `catalog_page.dart` (wood page + `_TableButton`) | role-match |
| `client/lib/rooms/join_page.dart` | component | request-response | `catalog_page.dart` error banner + `_TableButton` | role-match |
| `client/lib/howto/alchiki_howto_page.dart` | component | request-response | same file (`context.go('/match?...')`) | exact |
| `client/lib/l10n/app_en.arb` | config | — | same file | exact |
| `client/lib/l10n/app_ru.arb` | config | — | same file | exact |
| `client/pubspec.yaml` | config | — | same file (pin exact versions like `go_router: 18.0.1`) | exact |
| `client/test/catalog_test.dart` | test | request-response | same file | exact |
| `client/test/join_code_test.dart` | test | request-response | `catalog_test.dart` ProviderScope override | role-match |
| `client/test/rematch_overlay_test.dart` | test | request-response | `bot_turn_test.dart` + `pause_overlay.dart` widgets | role-match |

---

## Pattern Assignments

### `backend/.../session/GameEngine.java` (service, transform)

**Analog:** `backend/src/main/java/com/nomadgames/session/GameEngine.java` + `AlchikiEngine.java`

**Current SPI** (lines 6–11 of `GameEngine.java`) — expand, do not replace bot methods:

```java
public interface GameEngine {
    List<String> start(String difficulty);
    ScoredThrow applyThrow(String rawJson, Set<String> remainingBoneIds);
}
```

**Implementor** (`AlchikiEngine.java` lines 18–36): `@Component` implementing `GameEngine`; `start` maps EASY/NORMAL/HARD → 5/6/7 bone ids via `Dyn4jBurstSim.targetIdsForBoneCount`; `applyThrow` parses then `Dyn4jBurstSim.simulate`.

**Copy this shape for new methods (planner names from RESEARCH Pattern 1):**

- `startPrivate()` → same as `start("NORMAL")` plus document saka ids `saka-host` / `saka-joiner` (do **not** change `start` bone lists).
- `applyThrow(..., throwingSakaId, parkedSakaIds)` → new overload; bot path keeps existing two-arg method.
- `nextBotThrow(difficulty, seed, remaining)` → move the `ScriptedBot.nextThrow` call **out of** `MatchService.afterPlayerHalfIfInPlay` (MatchService.java lines 137–163) into `AlchikiEngine`. Return `ThrowInput` + `ScoredThrow` / `BotThrowView`.
- `resolve(...)` → wrap `AlchikiRules.resolve` and return **session** `MatchStatus`.

**Auth/Guard:** none (SPI). Session is the only caller.

**Error handling:** `AlchikiEngine.start` throws `IllegalArgumentException("difficulty")` (lines 23–28) — keep that; MatchController already maps `IllegalArgumentException` → 400.

---

### `backend/.../session/MatchStatus.java` (model, transform)

**Analog:** `backend/src/main/java/com/nomadgames/games/alchiki/MatchStatus.java` lines 3–8:

```java
public enum MatchStatus {
    IN_PLAY,
    PLAYER_WIN,
    BOT_WIN,
    DRAW
}
```

**Add** `HOST_WIN`, `JOINER_WIN`. Keep `PLAYER_WIN` / `BOT_WIN` / `DRAW` for the bot path (D-44). Settlement is a session concern — `AlchikiRules` in `games` must import `com.nomadgames.session.MatchStatus` (games → session is the allowed direction). Delete the games copy after the move so `MatchService` never imports `com.nomadgames.games.alchiki.MatchStatus`.

---

### `backend/.../session/MatchService.java` (service, CRUD)

**Analog:** same file.

**Imports to stop using** (lines 16–19) — this is the cycle:

```java
import com.nomadgames.alchiki.proto.ThrowInput;
import com.nomadgames.games.alchiki.AlchikiRules;
import com.nomadgames.games.alchiki.MatchStatus;
import com.nomadgames.games.alchiki.internal.ScriptedBot;
```

Replace clocks/resolve/bot with `GameEngine` methods. Keep `ThrowInput` **out** of session if it forces a games/proto leak — prefer engine DTOs already in `session` (`ThrowInputView`, `ScoredThrow`).

**Auth pattern** (lines 181–187) — bot path stays owner-check; private path must become **seat membership**:

```java
private MatchEntity requireOwner(UUID playerId, UUID matchId) {
    MatchEntity match = matches.findById(matchId)
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "match"));
    if (!match.getPlayerId().equals(playerId)) {
        throw new ResponseStatusException(HttpStatus.FORBIDDEN, "not owner");
    }
    return match;
}
```

Private: `403` if `playerId` is neither host nor joiner. Do not reuse `player_id` as the only seat.

**Create bot match** (lines 36–58) — keep `game=ALCHIKI` + `mode=BOT` validation; private create is **not** this method. RoomService calls a new `createPrivateMatch(host, joiner)` that sets `mode=PRIVATE`, `difficulty=NORMAL`, turn = joiner first (D-30).

**Leave** (lines 69–77) — today always `BOT_WIN`. Branch on `mode`:

```java
if (!MatchStatus.IN_PLAY.name().equals(match.getStatus())) {
    return new LeaveResponse(snapshot(match));
}
match.setStatus(MatchStatus.BOT_WIN.name());
```

Keep that for `BOT`. For `PRIVATE` set `HOST_WIN` or `JOINER_WIN` (remaining seat), never `BOT_WIN` (D-44). Already-terminal returns existing snapshot (ThrowAuthorityIT lines 307–328).

**Clock tick** (lines 109–117) — `tickClocks` compares `Instant.now()` to `turnDeadline`. During reconnect grace **do not** call this path; freeze remaining durations on the heap `MatchSession` (D-41). Consented leave does not pause.

**Error handling:** `IllegalArgumentException` for bad create body; `ResponseStatusException` NOT_FOUND / FORBIDDEN / CONFLICT `"not your turn"` (line 87). Copy CONFLICT for WS `ThrowInput` from a non-active seat.

---

### `backend/.../session/MatchController.java` (controller, request-response)

**Analog:** same file, lines 17–55.

**Imports / auth:**

```java
@RestController
@RequestMapping("/v1/matches")
public class MatchController {
    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public MatchCreatedResponse create(@AuthenticationPrincipal Jwt jwt, @RequestBody CreateMatchRequest request) {
        return matches.createMatch(playerId(jwt), request);
    }
    // ...
    private static UUID playerId(Jwt jwt) {
        return UUID.fromString(jwt.getSubject());
    }
}
```

**Copy for new REST (D-38):** same JWT principal, same `@ExceptionHandler(IllegalArgumentException) → 400`. Add:

- `POST /{id}/ws-ticket` — Bearer JWT, returns one-time 60s ticket (do **not** put access JWT in query).
- `POST /{id}/rematch` — dual accept window.
- `POST /{id}/rejoin` (if REST rejoin is separate from WS) — token + seat check.

Bot `POST /`, `/throws`, `/leave` stay. Do not migrate bot throws to WS.

---

### `backend/.../matchmaking/RoomController.java` (controller, request-response)

**Analog:** `MatchController.java` (JWT + status codes) + `GuestController.java` for extra status mapping.

Copy `@AuthenticationPrincipal Jwt jwt` + `playerId(jwt)` from MatchController. Guests are allowed (D-39) — **no extra bind check**. Map:

| Condition | HTTP | Analog |
|-----------|------|--------|
| no such code | 404 | `requireOwner` NOT_FOUND |
| already started | 409 | `CONFLICT, "not your turn"` (MatchService:87) |
| host left / idle closed | 410 | new; no existing 410 — use `ResponseStatusException(HttpStatus.GONE, "host left")` |
| bad code charset | 400 | `IllegalArgumentException` handler |

REST table from RESEARCH Pattern 2: `POST /v1/rooms`, `POST /v1/rooms/join`, `GET /v1/rooms/{id}`, `POST /v1/rooms/{id}/ready`, `POST /v1/rooms/{id}/leave`.

---

### `backend/.../matchmaking/RoomService.java` (service, CRUD)

**Analog:** `MatchService.createMatch` (validate + persist + return DTO) + `GuestMintRateLimiter` for join spray.

**Core create pattern** (MatchService 36–58): validate, call engine/start, `Instant.now()`, `matches.save`, return DTO. Room create: generate 5-char code from `ABCDEFGHJKLMNPQRSTUVWXYZ23456789`, unique retry on collision, `idle_expires_at = now + 10 minutes` (D-29), labels `Guest-` + last 4 hex chars of `playerId` with hyphens stripped (D-33).

**Host-alive:** host `leave` while `LOBBY` → status `CLOSED` immediately (D-29). Joiner leave clears seat, code lives.

**Both Ready:** only then `session.createPrivateMatch(host, joiner, NORMAL)` (D-27, D-31). Do not start on join.

**Housekeeping:** 1 Hz close of `LOBBY` past TTL — closest analog is `tickClocks` (MatchService 109–117) as a scheduled method, not a request.

---

### `backend/.../matchmaking/internal/RoomEntity.java` (model, CRUD)

**Analog:** `MatchEntity.java` lines 16–67 (JPA entity, UUID id, `protected` no-arg ctor, explicit ctor, string status).

Copy column style (`@Column(name = "...")`, `nullable = false`). Unique `code`. Do **not** store ready flags only on the client.

**Hashed secret analog** if reconnect tokens live on match rows: `RefreshTokenEntity.java` lines 20–22 `byte[] tokenHash` + unique.

---

### `backend/.../matchmaking/internal/RoomRepository.java` (model, CRUD)

**Analog:** `MatchRepository.java` lines 7–8:

```java
public interface MatchRepository extends JpaRepository<MatchEntity, UUID> {}
```

Add `Optional<RoomEntity> findByCode(String code)` (Spring Data derived name). Unique index is in Flyway, not only in-memory.

---

### `backend/.../db/migration/V3__rooms_and_seats.sql` (migration, file-I/O)

**Analog:** `V2__matches.sql` lines 1–18:

```sql
CREATE TABLE matches (
    id UUID PRIMARY KEY,
    player_id UUID NOT NULL REFERENCES players (id),
    ...
    created_at TIMESTAMPTZ NOT NULL
);
```

**Copy:** UUID PKs, `REFERENCES players (id)`, `VARCHAR` status/mode, `TIMESTAMPTZ`, `JSONB` for lists. **Alter** `matches` to add host/joiner seats (do not keep a single `player_id` as the only occupant for PRIVATE). New `rooms` table: `code` unique, `host_id`, `joiner_id` nullable, `status`, `idle_expires_at`. Next Flyway version is **V3** (V1 identity, V2 matches).

---

### `backend/pom.xml` (config)

**Analog:** existing starter deps without versions (lines 43–78). Add:

```xml
<dependency>
  <groupId>org.springframework.boot</groupId>
  <artifactId>spring-boot-starter-websocket</artifactId>
</dependency>
```

BOM-managed like `spring-boot-starter-webmvc`. **Do not** add STOMP/SockJS extras.

---

### `backend/.../identity/SecurityConfig.java` (config)

**Analog:** lines 22–33. Today everything except guest/refresh/health is `authenticated()`.

```java
.authorizeHttpRequests(auth -> auth.requestMatchers(POST, "/v1/identity/guest", "/v1/identity/refresh")
        .permitAll()
        .requestMatchers("/actuator/health")
        .permitAll()
        .anyRequest()
        .authenticated())
```

**Extend:** permit WS handshake path (`/v1/matches/*/ws` or exact pattern) because the **ticket** is the credential. Keep all room/match REST on Bearer JWT. CSRF already disabled; session STATELESS — keep both.

---

### `backend/.../session/MatchWebSocketConfig.java` + handler (config/controller, streaming)

**Analog:** **none in repo.** Copy RESEARCH Pattern 4 / Spring docs, **not** `@EnableWebSocketMessageBroker`.

```java
@Configuration
@EnableWebSocket
public class MatchWebSocketConfig implements WebSocketConfigurer {
    @Override
    public void registerWebSocketHandlers(WebSocketHandlerRegistry registry) {
        registry.addHandler(matchHandler, "/v1/matches/{matchId}/ws")
                .addInterceptors(ticketInterceptor)
                .setAllowedOriginPatterns("*");
        // Do NOT call .withSockJS()
    }
}
```

Handler: `TextWebSocketHandler`. Wrap with `ConcurrentWebSocketSessionDecorator`. Frames: client `ThrowInput` / `Ping`; server `ThrowResolved` / `RejoinSnapshot` / `Pong` / `OpponentDropped` / `OpponentRejoined` / `MatchSettled` / `Error`.

**Drop vs leave:** `afterConnectionClosed` → hold seat 30s (D-41). Close code `4000` or REST leave → 0s grace. **Do not** delete the seat in `afterConnectionClosed`.

---

### `backend/.../session/internal/ReconnectPolicy.java` (utility, event-driven)

**Analog:** `TokenService.java` rotate + hash (lines 66–118).

**Rotate on use** (`GuestIdentityIT` 53–76 is the test analog — reject replay of old token):

```java
public TokenPair rotate(String refreshToken) {
    byte[] hash = hashRefresh(refreshToken);
    RefreshTokenEntity existing = refreshTokens.findByTokenHash(hash)
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.UNAUTHORIZED, "invalid refresh"));
    // expiry check, delete, flush, issue new
}
```

Reconnect token: opaque 32 bytes, SHA-256 at rest (`sha256` lines 113–118), bound `playerId+matchId`, rotate on rejoin. TTL/grace = **30s** (D-41), not refresh TTL.

**Grace expiry:** remaining player wins `HOST_WIN`/`JOINER_WIN` (D-42). No bot-fill.

---

### `backend/.../identity/internal/JoinRateLimiter.java` (middleware, optional)

**Analog:** `GuestMintRateLimiter.java` lines 15–42. Copy `ConcurrentHashMap` + sliding 1-minute window + `ResponseStatusException(HttpStatus.TOO_MANY_REQUESTS)`. Key by IP **and/or** `playerId`. Limit style: same 20/min unless planner picks another number — do not invent Redis.

---

### `harness/.../Dyn4jBurstSim.java` (utility, transform)

**Analog:** same file `simulate` spawn at lines 113–114 (`addDisk(..., "saka", 0.0, -1.15, true)`). **Do not** change `IDS` globally (Pitfall 6). Add a **new** private-spawn method: `saka-host` / `saka-joiner` at e.g. `(-0.25,-1.12)` and `(0.25,-1.12)`; impulse only `throwingSakaId`; score still ignores sakas. Bot `simulate(input, remaining)` stays one `saka`. T-02-15 body cap 8: NORMAL 6 bones + 2 sakas = 8.

---

### Integration tests (test, request-response)

**Analog harness** — copy `ThrowAuthorityIT.java` lines 30–57:

```java
@SpringBootTest(classes = NomadGamesApplication.class,
        properties = "nomad.jwt.secret=test-jwt-secret-that-is-32-bytes!!")
@AutoConfigureMockMvc
@Testcontainers
class ThrowAuthorityIT {
    @Container
    @ServiceConnection
    static PostgreSQLContainer postgres = new PostgreSQLContainer("postgres:18");
```

Mint: `POST /v1/identity/guest` → `$.accessToken` (lines 346–350). Create bot: `POST /v1/matches` with `{"game":"ALCHIKI","mode":"BOT","difficulty":"..."}` expect 201 (357–368).

**Leave bot must stay green** (297–304): `POST .../leave` → `$.match.status` = `BOT_WIN`.

**Private leave:** new test, same MockMvc, expect `HOST_WIN` or `JOINER_WIN`, **not** `BOT_WIN`.

**Token rotate analog:** `GuestIdentityIT#refreshRotatesAndRejectsReplay` (53–76) — copy “second use of old token is 401” for reconnect tokens.

**Catalog unauthorized analog:** `CatalogIT#catalogWithoutBearerIsUnauthorized` (38–40) — rooms REST without Bearer → 401.

**ModularityTest.java** lines 8–10 — do not weaken:

```java
ApplicationModules.of(NomadGamesApplication.class).verify();
```

---

### `client/lib/platform/router.dart` (route)

**Analog:** same file lines 9–48. Copy `GoRoute` + `state.uri.queryParameters`.

Add `/lobby` and `/join` (UI-SPEC locked: **routes, not sheets**). Extend `/match` to read `mode` + `matchId`:

```dart
GoRoute(
  path: '/match',
  builder: (context, state) {
    final String difficulty =
        state.uri.queryParameters['difficulty'] ?? 'EASY';
    return AlchikiMatchPage(difficulty: difficulty);
  },
),
```

How-to already passes `difficulty` and `fromPause` (lines 23–32). Private kickoff: after both Ready, if `howto.alchiki.seen` is false, go through `/howto/alchiki` then `/match?mode=private&matchId=` (CONTEXT discretion + UI-SPEC). If seen, skip pager (D-14).

---

### `client/lib/catalog/catalog_page.dart` (component)

**Analog:** same file.

**Tokens / buttons:** `_surround` `#241810`, `_felt` `#1B6B3A`, `_accent` `#F0B429`, `_TableButton` 48px min (lines 413–454). Play Alchiki stays accent (lines 314–322).

**Private CTAs:** wood + cream **outline**, **not** accent (UI-SPEC). Insert a band **after** `_AlchikiTile`, **before** Coming Soon, with `SizedBox(height: 16)` then `64` (`3xl`) before Coming Soon. Do **not** put chips on that band (D-31). Do **not** fold into one «With a friend» button (D-26).

**Create room:** `POST /v1/rooms` then `context.go('/lobby?roomId=')`. On error stay on catalog with Retry — copy `_load` / `_CatalogBanner` (lines 63–104, 157–162). **Do not** open how-to before the host sees the code (UI-SPEC).

**Join by code:** `context.go('/join')` — no network yet.

**Play Alchiki** `_playAlchiki` (106–118) unchanged: how-to gate then `/match?difficulty=`.

---

### `client/lib/rooms/lobby_page.dart` (component)

**Analog:** `catalog_page.dart` Scaffold + SafeArea + 16 padding + `_TableButton` / outlined wood; `pause_overlay.dart` `_PanelButton` outlined + destructive confirm.

Host: Display 28 code, letter-spacing 4px, Share (`share_plus` — **no analog**; RESEARCH snippet) + Copy (`Clipboard.setData` — SDK). Copied flash 2s Label 14 — **not** SnackBar.

Ready: accent only when joiner present and local seat not ready; else 40% / outlined disabled after tap (UI-SPEC). Poll `GET /v1/rooms/{id}` (same rhythm as catalog `_load`).

Host Leave lobby → confirm chrome from `LeaveConfirm` (pause_overlay 87–135) with new copy keys. Joiner Leave lobby: immediate POST, no confirm.

Closed / host-left: heading + body + Back to catalog — copy `_ErrorBanner` on match_page (552–558).

---

### `client/lib/rooms/join_page.dart` (component)

**Analog:** catalog error banner + `_TableButton`; **no existing TextField screen** — use Material `TextField` with Display 28, cream outline, min height 48.

Join errors **keep route and characters** (D-32). Map API 404/409/410 to `errorNoSuchRoom` / `errorAlreadyStarted` / `errorHostLeft`. Destructive field border `#C43C2C` on error (catalog banner already uses that color, lines 213–216). Join room accent when length 4–6.

Success → `/lobby?roomId=`.

---

### `client/lib/platform/api/nomad_api.dart` (service, request-response)

**Analog:** same file.

**Provider + Dio + Bearer interceptor** (lines 11–177). Add room/rematch/ticket/rejoin methods with the same `try / on DioException → NomadApiException(message, statusCode:)`.

**Create analog** (232–248):

```dart
final Response<dynamic> response = await _dio.post<dynamic>(
  '/v1/matches',
  data: <String, String>{'game': 'ALCHIKI', 'mode': 'BOT', 'difficulty': difficulty},
);
```

Rooms: `POST /v1/rooms` (empty or `{game: ALCHIKI}`), `POST /v1/rooms/join` `{code}`, etc. Surface `statusCode` so join page can branch 404/409/410.

**Leave analog** (269–298): `POST /v1/matches/$matchId/leave` then parse `match.status`. Private leave still this path (REST, D-38).

Keep bot `startMatch` / `submitThrow` on REST. Do not send private in-play throws through `submitThrow`.

---

### `client/lib/platform/session/match_socket.dart` (service, streaming)

**Analog:** **none.** Wrap errors like `NomadApiException`. Connect after `POST .../ws-ticket`. RESEARCH:

```dart
final channel = WebSocketChannel.connect(wsUrl);
await channel.ready;
channel.stream.listen((message) { /* parse type */ });
channel.sink.add(jsonEncode({'type': 'Ping', 't': DateTime.now().millisecondsSinceEpoch}));
```

One socket owned by session. Parse `type` field. Reconnect token from `SessionStore`, not SharedPreferences.

---

### `client/lib/platform/auth/session_store.dart` (store, file-I/O)

**Analog:** same file lines 6–65. Add `reconnectTokenKey` beside `playerIdKey` / `refreshTokenKey`. Extend `persist` / `clear` / `_read` / `_write`. Keep `SessionStore.memory()` for tests. **Do not** put the token in `HowToSeenStore` / SharedPreferences (`howto_seen_store.dart` is the wrong store).

---

### `client/lib/games/alchiki/match_page.dart` (component)

**Analog:** same file.

**Start only after REST create succeeds** then attach `GameWidget` (`_tableAttached`, line 506–507) — keep for bot; private attaches after lobby Ready + optional how-to.

**Bot theatrical turn** (lines 259+) `playBotTurn` — **reuse for opponent `ThrowResolved`** (D-34). Do not add live aim over WS.

**While waiting for opponent release:** freeze table, hide Hold Throw (`_isPlayerTurn` already hides it, lines 621+), HUD their clock + static aiming marker (D-35). Closest flag: `_botsTurn` (lines 105–106, 245–266).

**Leave** (452–476): keep confirm then `leaveMatch`. Pass private copy into `LeaveConfirm`.

**Result** (576–583): extend `ResultOverlay` with Play again (bot) vs Again? (private). Terminal set must include `HOST_WIN` / `JOINER_WIN` (today only PLAYER_WIN/BOT_WIN/DRAW, lines 108–111). Private result must never show `botWins`.

**Clocks** (113–127): display `deadline - now`. During grace, **stop ticking** — show frozen remaining (D-41). Server Instants remain truth.

**How-to from pause** (487–492): keep `fromPause=1`. Private how-to-from-kickoff needs extra query (`mode`, `matchId`) on `AlchikiHowToPage` (howto line 93 currently `context.go('/match?difficulty=')`).

---

### `client/lib/games/alchiki/match_game.dart` + `saka_body.dart` (component)

**Analog:** `match_game.dart` onLoad lines 85–107 (one `SakaBody()`); `saka_body.dart` fill `#FFF6D6` / stripe `#8B4513`, spawn `(0, -1.15)`.

Private: two `SakaBody` with constructor colors (you always cream, opponent ice `#7EB6D9` / stripe `#2F5F7A` — UI-SPEC). Spawns `(-0.25,-1.12)` / `(0.25,-1.12)`. Only current owner accepts drag (`MatchTableDragLayer` uses `game.saka` — generalize). Replay targets today hardcode `id: 'saka'` (match_game ~225) — private keyframes use `saka-host` / `saka-joiner`. Bot path **unchanged** one cream `saka`.

Aiming marker: new Flame component, 8×8 dp, 40% cream, 16px above parked opponent saka; no angle.

---

### `client/lib/games/alchiki/pause_overlay.dart` (component)

**Analog:** same file.

**Scrim panel** (188–213): wood 60% scrim, 88% panel, 16 padding — copy for rematch, rejoin, host-leave-lobby, private result.

**LeaveConfirm** (87–135): add optional `body` (or `leaveBodyPrivate`) — vs human: opponent wins. Stay outlined, Leave match destructive.

**ResultOverlay** (138–185): add accent **Play again** (bot, D-43) and private **Again?** + `rematchClock` Label 14. Heading switch today:

```dart
final String heading = switch (status) {
  'PLAYER_WIN' => l10n.youWin,
  'BOT_WIN' => l10n.botWins,
  _ => l10n.draw,
};
```

Extend: local win vs `HOST_WIN`/`JOINER_WIN` → `youWin` / `opponentWins`. Never `botWins` on private.

Rejoin overlay: same `_ScrimPanel`, single accent **Rejoin match**, **no** Back to catalog (UI-SPEC).

---

### `client/lib/games/alchiki/match_hud.dart` (component)

**Analog:** same file lines 54–80. Score line `'${l10n.you} $youScore — ${l10n.bot} $botScore'`. Private: `You n — Guest-XXXX n`. Turn line `isPlayerTurn ? l10n.yourTurn : l10n.botsTurn` → `opponentsTurn` when private. Add reconnect banner Label 14 under turn (`reconnecting` + `{ss}`), no accent. Difficulty line stays `First to 5 · NORMAL` on private (no chips).

---

### `client/lib/l10n/app_en.arb` + `app_ru.arb` (config)

**Analog:** existing keys (`playAlchiki`, `leaveTitle`, `leaveBody`, `errorMatchStart`, parameterized `turnClock`). Add UI-SPEC keys (`createRoom`, `joinByCode`, `joinRoom`, `ready`, `shareCode`, `copyCode`, `copied`, `leaveLobby`, `playAgain`, `rematchAgain`, `rejoinMatch`, `opponentWins`, `reconnecting`, join/lobby errors). Keep EN template + complete RU. Placeholders follow `@turnClock` / `@previewHud` JSON blocks.

Do **not** hand-edit generated `app_localizations*.dart` — `flutter gen-l10n`.

---

### `client/pubspec.yaml` (config)

**Analog:** pinned deps (lines 37–49). Add **exact** `web_socket_channel: 3.0.3` and `share_plus: 13.3.0`. Do not use deprecated `Share.share()`.

---

### Widget tests

**Analog:** `catalog_test.dart` lines 9–28 — `SessionStore.memory()`, `ProviderScope` overrides `sessionStoreProvider` + `nomadApiProvider`, `NomadApp(initialLocation: '/')`.

Extend catalog tests: Play Alchiki + chips **and** Create room / Join by code present.

`join_code_test.dart`: pump `/join`, type code, stub API 404, expect error copy **and** field text remains (D-32).

`rematch_overlay_test.dart`: pump `ResultOverlay` / match page with terminal status — bot shows Play again; private shows Again? / opponentWins, not Bot wins.

`bot_turn_test.dart` fake `NomadApi.startMatch` — copy for private match page fakes (no live WS in unit tests unless a fake `MatchSocket`).

---

## Shared Patterns

### Authentication (REST)

**Source:** `MatchController.java` 29–54, `SecurityConfig.java` 22–33
**Apply to:** RoomController, MatchController rematch/ticket/leave, all room REST

`@AuthenticationPrincipal Jwt jwt` → `UUID.fromString(jwt.getSubject())`. Guests may create/join (D-39). WS handshake uses one-time ticket, not query access JWT.

### Authorization (seats vs owner)

**Source:** `MatchService.requireOwner` 181–187
**Apply to:** private match REST + every `ThrowInput`

Bot: keep owner = `player_id`. Private: host **or** joiner; non-seat → 403. Turn check: CONFLICT `"not your turn"` (line 87).

### Error handling (HTTP)

**Source:** `MatchController` 49–51; `MatchService` `ResponseStatusException`
**Apply to:** rooms + matches

- `IllegalArgumentException` → 400
- missing entity → 404
- wrong player → 403
- not your turn / already started → 409
- host left / gone code → 410
- join spray → 429 (`GuestMintRateLimiter` 37–38)

Client: `NomadApiException` + `statusCode` (`nomad_api.dart` 15–22, 242–247). Catalog/match Retry banners (`catalog_page` 157–162, `match_page` 552–558). Join: **do not** `context.go('/')` on 404/409/410.

### Error handling (Flutter overlays)

**Source:** `pause_overlay.dart` `_ScrimPanel` + `_ErrorBanner` on match_page
**Apply to:** lobby closed, rematch error, rejoin error, create-room error

Wood 60% scrim, 88% panel, Label 14 / Body 16, Retry accent, Back to catalog outlined.

### Validation

**Source:** `MatchService.createMatch` 38–40 (`game`/`mode`); `AlchikiEngine.start` difficulty switch; `ThrowInput.parse` ignores score keys (Phase 2, keep on WS)
**Apply to:** room codes 4–6 from Crockford-like alphabet (accept 4–6, trim/uppercase); ThrowInput inputs-only on WS (SESS-01)

### Token hashing / rotate

**Source:** `TokenService` 66–118; test `GuestIdentityIT` 53–76
**Apply to:** reconnect tokens and WS tickets (hash at rest, rotate on use, reject replay)

### Rate limit

**Source:** `GuestMintRateLimiter.java` 15–42
**Apply to:** `POST /v1/rooms/join` (PITFALLS 9 / RESEARCH security)

### i18n + chrome

**Source:** `catalog_page.dart` / `pause_overlay.dart` / `match_hud.dart` — four type roles, 48dp targets, PRES-02 hexes, `AppLocalizations.of(context)`
**Apply to:** lobby, join, rematch, reconnect, private HUD

### Authority

**Source:** `AlchikiEngine` + `ThrowAuthorityIT#forgedClientScoreIsIgnoredOnThrow`
**Apply to:** WS `ThrowInput` as well as REST throws. Client never authors score/outcome (SESS-01).

### How-to gate

**Source:** `catalog_page._playAlchiki` 106–118; `HowToSeenStore.seenKey = 'howto.alchiki.seen'`
**Apply to:** private table **after** both Ready, not before host lobby. Pause path unchanged.

### Modulith

**Source:** `ModularityTest.java`; **anti-analog** `com.nomadgames.alchiki/package-info.java` (`Type.OPEN`)
**Apply to:** new `matchmaking` package as its own module; `games` implements `session.GameEngine` only; **zero** `session` → `games.alchiki` imports including `internal.ScriptedBot`.

---

## No Analog Found

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `session/MatchWebSocketConfig.java` | config | streaming | No Spring WS in tree. Use RESEARCH Pattern 4; never STOMP/SockJS. |
| `session/internal/MatchWebSocketHandler.java` | controller | streaming | No `TextWebSocketHandler`. Steal Colyseus **onDrop hold / onLeave settle** as comments + MatchSession methods, not the SDK. |
| `session/internal/WsTicketInterceptor.java` | middleware | request-response | No handshake interceptor. Ticket lookup is new; JWT resource-server analog is `SecurityConfig` only. |
| `client/lib/platform/session/match_socket.dart` | service | streaming | No `web_socket_channel` yet. Copy NomadApi exception style + RESEARCH Dart snippet. |
| OS share sheet | component | request-response | No `share_plus`. Use `SharePlus.instance.share(ShareParams(text: l10n.shareSheetText(code)))`. |
| Clock freeze during grace | service | event-driven | `tickClocks` is the **opposite** (expires turns). New heap fields for remaining durations; housekeeping must skip DISCONNECTED seats. |
| Join `TextField` screen | component | request-response | No form pages. Invent from catalog wood + 48dp + Display 28; keep D-32 field persistence. |

Planner should pull WS/share snippets from `03-RESEARCH.md` Code Examples, not invent STOMP or `Share.share()`.

---

## Metadata

**Analog search scope:** `backend/src/main/java/com/nomadgames/{session,games,identity,catalog,alchiki}`, `backend/src/main/resources/db/migration`, `backend/src/test/java`, `harness/src/main/java/com/nomadgames/alchiki/proto`, `client/lib/{catalog,platform,games,howto,game,l10n}`, `client/test`, `client/pubspec.yaml`, `backend/pom.xml`
**Files scanned:** ~70 source/test files; 8 primary analogs read in full; large `match_page.dart` (~800 lines) via targeted sections (start, bot turn, leave, overlays)
**Pattern extraction date:** 2026-09-07

**Stop criterion:** 5 strong analog families used throughout — Match REST (`MatchController`/`MatchService`/`ThrowAuthorityIT`), Catalog Flutter (`catalog_page`/`router`/`catalog_test`), Table/HUD (`match_page`/`pause_overlay`/`match_hud`/`saka_body`), Identity tokens (`TokenService`/`GuestMintRateLimiter`/`GuestIdentityIT`), Flyway/JPA (`V2`/`MatchEntity`). WS + share have no in-repo analog.
