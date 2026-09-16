# Phase 5: Casual Quick Match + Profile - Pattern Map

**Mapped:** 2026-09-11
**Files analyzed:** 28
**Analogs found:** 28 / 28

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `backend/.../matchmaking/CasualQueueService.java` | service | request-response + in-memory FIFO | `backend/.../matchmaking/RoomService.java` + `JoinRateLimiter.java` | role-match |
| `backend/.../matchmaking/CasualMatchmakingController.java` | controller | request-response | `backend/.../matchmaking/RoomController.java` | exact |
| `backend/.../matchmaking/internal/JoinRateLimiter.java` | middleware | request-response | *(extend self)* | exact |
| `backend/.../session/MatchService.java` | service | request-response + event-driven settle | *(modify self)* `createPrivateMatch` / `afterTerminal` | exact |
| `backend/.../session/internal/MatchSessionRegistry.java` | store | event-driven | *(reuse)* `RematchWindow` / `registerPrivate` | exact |
| `backend/.../profile/ProfileService.java` | service | CRUD + settle transform | `backend/.../economy/EconomyService.java` | exact |
| `backend/.../profile/ProfileController.java` | controller | request-response | `backend/.../economy/EconomyController.java` | exact |
| `backend/.../profile/SoftElo.java` | utility | transform | `backend/.../session/internal/ReconnectPolicy.java` | role-match |
| `backend/.../profile/internal/ProfileJdbc.java` | utility | CRUD / file-I/O (SQL) | `backend/.../economy/internal/WalletLedgerJdbc.java` | exact |
| `backend/.../db/migration/V9__profile_casual.sql` | migration | batch | `backend/.../db/migration/V7__economy_ledger_shop.sql` | exact |
| `client/lib/matchmaking/searching_page.dart` | component | request-response (poll) | `client/lib/rooms/lobby_page.dart` | exact |
| `client/lib/matchmaking/fallback_page.dart` | component | request-response | `client/lib/rooms/join_page.dart` / lobby wood chrome | role-match |
| `client/lib/profile/profile_page.dart` | component | CRUD | `client/lib/shop/shop_page.dart` | exact |
| `client/lib/games/alchiki/rematch_waiting_page.dart` | component | request-response (poll) | `client/lib/rooms/lobby_page.dart` + rematch poll in `match_page.dart` | role-match |
| `client/lib/catalog/catalog_page.dart` | component | request-response | *(modify self)* header + `_AlchikiTile` | exact |
| `client/lib/shop/wallet_chip.dart` | component | display-only | *(clone chrome for AvatarChip)* | exact |
| `client/lib/games/alchiki/match_page.dart` | component | request-response + streaming WS | *(modify self)* `_isPrivate` | exact |
| `client/lib/games/alchiki/pause_overlay.dart` | component | event-driven UI | *(modify self)* `ResultOverlay` | exact |
| `client/lib/platform/router.dart` | config | request-response | *(modify self)* `GoRoute` list | exact |
| `client/lib/platform/api/nomad_api.dart` | service | request-response | *(modify self)* `createRoom` / `rematch` / `fetchWallet` | exact |
| `client/lib/l10n/app_en.arb` + `app_ru.arb` | config | transform | *(extend existing ARB)* | exact |
| `backend/.../CasualQueueIT.java` | test | request-response | `backend/.../matchmaking/RoomIT.java` | exact |
| `backend/.../ProfileIT.java` | test | CRUD | `backend/.../economy/EconomyIT.java` | exact |
| `backend/.../session/RematchIT.java` (extend) / `CasualRematchIT` | test | request-response | *(extend)* `RematchIT.java` | exact |
| `backend/.../session/ReconnectIT.java` (extend) | test | request-response | *(extend self)* | exact |
| `client/test/matchmaking_test.dart` | test | request-response | `client/test/catalog_test.dart` | role-match |
| `client/test/profile_page_test.dart` | test | CRUD | `client/test/catalog_test.dart` + shop widget tests | role-match |
| `client/test/casual_rematch_test.dart` | test | request-response | `client/test/rematch_overlay_test.dart` | exact |
| `client/test/catalog_test.dart` (extend) | test | request-response | *(extend self)* | exact |

## Pattern Assignments

### `CasualMatchmakingController.java` (controller, request-response)

**Analog:** `RoomController.java`

**Imports + JWT principal** (lines 1–33):
```java
@RestController
@RequestMapping("/v1/rooms")
public class RoomController {
    private final RoomService rooms;
    public RoomController(RoomService rooms) { this.rooms = rooms; }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public RoomCreatedResponse create(@AuthenticationPrincipal Jwt jwt) {
        return rooms.create(playerId(jwt));
    }
```

**Auth pattern** — every handler takes `@AuthenticationPrincipal Jwt jwt`; subject → `UUID.fromString(jwt.getSubject())` (lines 64–66).

**Error handling** — `@ExceptionHandler(IllegalArgumentException.class)` → 400 (lines 60–62); service throws `ResponseStatusException` for 404/409/429.

**Copy for casual:** `@RequestMapping("/v1/matchmaking/casual")` with `POST` enqueue, `GET` poll, `DELETE` dequeue; inject `CasualQueueService`; reuse `playerId(jwt)` + optional `clientIp` + rate limiter like join (lines 68–74).

---

### `CasualQueueService.java` (service, FIFO enqueue/pair)

**Analog:** `RoomService.java` (modulith matchmaking service) + `JoinRateLimiter` (in-process concurrent maps)

**Service skeleton** (RoomService lines 23–48):
```java
@Service
public class RoomService {
    private final JoinRateLimiter joinRateLimiter;
    private final MatchService matches;
    // constructor injection of repos + MatchService
}
```

**Pair create seam** — call `matches.createCasualMatch(hostId, joinerId)` the same way room kickoff calls `createPrivateMatch` (RoomService depends on `MatchService`).

**In-process concurrency** (JoinRateLimiter lines 16–47):
```java
private final ConcurrentHashMap<String, Deque<Long>> hits = new ConcurrentHashMap<>();
synchronized (window) { /* mutate deque */ }
```
**Copy for queue:** `ConcurrentLinkedQueue` + `ConcurrentHashMap<UUID, Ticket>`; synchronize on queue monitor for pair-on-enqueue; rate-limit `POST` via extended `JoinRateLimiter.check(ip, playerId)`.

**No analog for Postgres queue rows** — intentional; do not copy `RoomRepository` FOR UPDATE pattern into the queue SoT.

---

### `MatchService.java` — `createCasualMatch` + human PvP guards (service)

**Analog:** same file — `createPrivateMatch` (lines 93–118)

```java
@Transactional
public UUID createPrivateMatch(UUID hostId, UUID joinerId) {
    PrivateTable table = engine.startPrivate();
    MatchEntity match = new MatchEntity(
            UUID.randomUUID(), hostId, "ALCHIKI", "PRIVATE", "NORMAL",
            MatchStatus.IN_PLAY.name(), table.boneIds(), "JOINER",
            /* deadlines */, now, hostId, joinerId);
    String hostToken = ReconnectPolicy.mintToken();
    String joinerToken = ReconnectPolicy.mintToken();
    match.setHostReconnectTokenHash(ReconnectPolicy.hashToken(hostToken));
    match.setJoinerReconnectTokenHash(ReconnectPolicy.hashToken(joinerToken));
    matches.save(match);
    sessions.registerPrivate(match.getId(), hostToken, joinerToken);
    return match.getId();
}
```

**Copy:** clone with mode `"CASUAL"`; keep NORMAL / JOINER turn / reconnect mint / `registerPrivate`.

**PRIVATE-only guards to generalize** (examples):
- `issueWsTicket` lines 200–201: `!"PRIVATE".equals` → `!isHumanPvP(mode)`
- `leaveMatch` line 139: `"PRIVATE".equals` → human branch
- `requirePrivateTerminal` lines 542–546: allow `"CASUAL"` (rename conceptually to human terminal)
- `acceptRematch` line 234: branch `createPrivateMatch` vs `createCasualMatch` by finished mode
- `afterTerminal` lines 624–637: treat CASUAL like private for dual-seat grants (`privateMatch`/`humanMatch` true)
- `outcomeForSeat` line 658: `"PRIVATE".equals` → human PvP outcomes

**Helper to add:**
```java
static boolean isHumanPvP(String mode) {
    return "PRIVATE".equals(mode) || "CASUAL".equals(mode);
}
```

---

### `MatchSessionRegistry.RematchWindow` (store, dual-accept)

**Analog:** `MatchSessionRegistry.java` lines 66–79, 154–172

```java
public RematchWindow openRematch(UUID finishedMatchId, UUID hostId, UUID joinerId, Instant deadline) {
    return rematchWindows.computeIfAbsent(
            finishedMatchId, id -> new RematchWindow(hostId, joinerId, deadline));
}

public void registerPrivate(UUID matchId, String hostToken, String joinerToken) { /* ... */ }

public static final class RematchWindow {
    public final UUID hostId;
    public final UUID joinerId;
    public Instant deadline;
    public boolean acceptedHost;
    public boolean acceptedJoiner;
    public boolean rejected;
    public UUID newMatchId;
}
```

**Copy:** reuse as-is for CASUAL rematch; only `MatchService.acceptRematch` create branch changes. Do not invent a second window type.

---

### `ProfileController.java` / `ProfileService.java` (controller + service, CRUD)

**Analog controller:** `EconomyController.java` lines 15–57

```java
@RestController
public class EconomyController {
    @GetMapping("/v1/wallet")
    public WalletView wallet(@AuthenticationPrincipal Jwt jwt) {
        return economy.getWallet(playerId(jwt));
    }
    @GetMapping("/v1/loadout")
    public Map<String, String> loadout(@AuthenticationPrincipal Jwt jwt) {
        return economy.getLoadout(playerId(jwt));
    }
    private static UUID playerId(Jwt jwt) {
        return UUID.fromString(jwt.getSubject());
    }
}
```

**Copy:** `GET /v1/profile`, `PUT /v1/profile/avatar`; self-only JWT; validate avatar allow-list with `ResponseStatusException(BAD_REQUEST)` like purchase body checks (lines 36–38).

**Analog service:** `EconomyService` — sync settle twin (lines 186–200) + `getLoadout` for cosmetics:

```java
/** Sync match grant inside the caller's settle TX (D-45). */
@Transactional
public RewardGrant grantMatchRewards(MatchRewardCommand cmd) { /* idempotent */ }

@Transactional
public Map<String, String> getLoadout(UUID playerId) {
    ensureDefaults(playerId);
    return Map.copyOf(inventoryLoadout.loadoutMap(playerId));
}
```

**Copy for profile:** `recordSettlement(...)` called from `MatchService.afterTerminal` after grants; idempotent on `(matchId, playerId)` like ledger keys; profile GET aggregates stats + `economy.getLoadout` (do not duplicate inventory).

---

### `ProfileJdbc.java` (utility, SQL CRUD)

**Analog:** `WalletLedgerJdbc.java` lines 10–32

```java
@Component
public class WalletLedgerJdbc {
    private final JdbcClient jdbc;
    public WalletLedgerJdbc(JdbcClient jdbc) { this.jdbc = jdbc; }

    public void ensureWalletRows(UUID playerId) {
        jdbc.sql("""
                INSERT INTO wallets (player_id, currency, balance)
                VALUES (:playerId, :currency, 0)
                ON CONFLICT (player_id, currency) DO NOTHING
                """)
            .param("playerId", playerId)
            .param("currency", currency)
            .update();
    }
}
```

**Idempotent settle insert analog:** `SoftPurchaseJdbc.insertIfAbsent` — `ON CONFLICT DO NOTHING`.

**Copy:** named params via `JdbcClient`; ensure `player_game_stats` rows for `ALCHIKI` + `STICK_PULL`; insert `profile_settlements` before mutating XP/rating.

---

### `SoftElo.java` (utility, pure transform)

**Analog:** `ReconnectPolicy.java` — final utility, private ctor, static methods (lines 15–29)

```java
public final class ReconnectPolicy {
    public static final int GRACE_SECONDS = 30;
    private ReconnectPolicy() {}
    public static String mintToken() { /* ... */ }
}
```

**Copy:** `public final class SoftElo` with `K=24`, start 1000, floor 100; pure `nextRating` — no Spring bean required (or `@Component` only if tests prefer injection).

---

### `V9__profile_casual.sql` (migration)

**Analog:** `V7__economy_ledger_shop.sql` — ALTER/CREATE + CHECKs + PK composites (lines 1–76)

```sql
CREATE TABLE wallets (
    player_id UUID NOT NULL REFERENCES players (id),
    currency VARCHAR(16) NOT NULL,
    balance BIGINT NOT NULL,
    PRIMARY KEY (player_id, currency),
    CONSTRAINT wallets_currency_chk CHECK (currency IN ('COINS', 'GEMS'))
);
```

**Also extend:** `V1__identity.sql` `players` table — add columns via `ALTER TABLE players ADD COLUMN ...` (avatar_preset, xp, level, soft_rating, best_rating) as sketched in RESEARCH.

---

### `searching_page.dart` / `fallback_page.dart` / `rematch_waiting_page.dart` (component, poll)

**Analog:** `lobby_page.dart` — wood full-screen `ConsumerStatefulWidget`, Timer poll, error banner, go_router navigation (lines 13–117)

```dart
class LobbyPage extends ConsumerStatefulWidget { /* ... */ }

class _LobbyPageState extends ConsumerState<LobbyPage> {
  static const Color _wood = Color(0xFF241810);
  Timer? _poll;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_refresh());
      _poll = Timer.periodic(const Duration(seconds: 1), (_) {
        unawaited(_refresh());
      });
    });
  }
  Future<void> _refresh() async {
    final RoomLobby lobby = await ref.read(nomadApiProvider).getRoom(widget.roomId);
    // navigate on matchId
  }
}
```

**Copy for searching:** poll `GET /v1/matchmaking/casual` every **500ms**; client 8s → replace route with fallback (do **not** dequeue at 8s); Cancel → `DELETE` + `context.go('/')`.

**Copy for rematch-wait:** poll `getRematch` like `match_page.dart` rematch Timer (500ms); Cancel → rematch accept false + catalog.

**Wood chrome tokens:** same `_wood` / `_onDark` / `_accent` / typography as lobby/shop.

---

### `profile_page.dart` (component, CRUD)

**Analog:** `shop_page.dart` — wood page, `_load` via `Future.wait`, error + Retry, accent CTAs (lines 9–99)

```dart
class ShopPage extends ConsumerStatefulWidget { /* ... */ }

Future<void> _load() async {
  setState(() { _loading = true; _error = false; });
  try {
    final NomadApi api = ref.read(nomadApiProvider);
    final List<Object> results = await Future.wait<Object>([
      api.fetchShopCatalog(),
      api.fetchWallet(),
    ]);
    // setState success
  } catch (_) {
    setState(() { _loading = false; _error = true; });
  }
}
```

**Copy:** `fetchProfile` + optional loadout; Stick Pull section always rendered (`noMatchesYet`); avatar grid + Save dirty pattern like shop equip selection; Back → `context.go('/')`.

---

### `catalog_page.dart` + AvatarChip (component)

**Analog header** (catalog_page lines 282–307) — insert avatar **before** wallet:

```dart
Row(
  children: [
    Expanded(child: Text(l10n.appTitle, style: _heading)),
    if (_coins != null && _gems != null) ...[
      WalletChip(coins: _coins!, gems: _gems!),
      const SizedBox(width: 8),
    ],
    _ShopEntry(label: l10n.shop, onTap: () => context.push('/shop')),
    // EN/RU ...
  ],
)
```

**Avatar chip chrome analog:** `wallet_chip.dart` lines 5–50 — wood fill, cream border, 48 height, Semantics label, non-authoritative display.

**Alchiki tile CTA** (lines 512–520) — demote Play Alchiki to wood outline; add accent **Quick Match** above it (D-66 / UI-SPEC accent #16).

**Create room path** already in catalog — fallback Invite reuses `_createRoom()` / `api.createRoom()` then `/lobby`.

---

### `match_page.dart` + `pause_overlay.dart` (human vs casual rematch fork)

**Analog getters** (match_page ~193):
```dart
bool get _isPrivate => widget.mode == 'private';
```

**Copy:**
```dart
bool get _isHuman => widget.mode == 'private' || widget.mode == 'casual';
bool get _isCasual => widget.mode == 'casual';
```
Replace `_isPrivate` gates for WS/reconnect/leave/human HUD with `_isHuman`. Keep private-only for Again? overlay chrome; casual uses `onPlayAgain` → push `/match/rematch-wait` + POST rematch accept.

**ResultOverlay** (pause_overlay ~141–279):
```dart
/// Bot Play again is one-tap; private Again? is a 10s dual accept (D-43).
if (!isPrivate && onPlayAgain != null)
  _AccentButton(label: l10n.playAgain, onTap: onPlayAgain);
if (isPrivate)
  _AccentButton(label: l10n.rematchAgain, /* dual-accept */);
```

**Copy:** treat casual like bot for **button label** (`playAgain`) but wire `onPlayAgain` to dual-accept + waiting route (not new bot match). Do not show `rematchSeconds` on casual result overlay.

---

### `router.dart` (config)

**Analog:** existing routes (lines 12–76)

```dart
GoRoute(path: '/shop', builder: (context, state) => const ShopPage()),
GoRoute(
  path: '/match',
  builder: (context, state) {
    final String? mode = state.uri.queryParameters['mode'];
    final String? matchId = state.uri.queryParameters['matchId'];
    // ...
  },
),
```

**Copy add:**
- `/matchmaking` → SearchingPage
- `/matchmaking/fallback` → FallbackPage (or same stack replace)
- `/match/rematch-wait` → RematchWaitingPage (query: matchId, opponent label)
- `/profile` → ProfilePage
- Match route: default difficulty NORMAL when `mode == 'casual'` (same as private).

---

### `nomad_api.dart` (client API)

**Analog methods:**
- Queue: mirror `createRoom` / `getRoom` (lines 612–645) for POST/GET/DELETE casual
- Profile: mirror `fetchWallet` (line 696+) for GET profile; equip-style PUT for avatar
- Rematch: reuse `rematch` / `getRematch` (lines 484–524) unchanged

```dart
Future<RoomCreated> createRoom() async {
  final Response<dynamic> response = await _dio.post<dynamic>(
    '/v1/rooms', data: <String, Object>{},
  );
  return _parseRoomCreated(response.data);
}
```

**Error pattern:** `on DioException` → `NomadApiException(message, statusCode: ...)`.

---

### Tests

| New test | Analog | Copy |
|----------|--------|------|
| `CasualQueueIT` | `RoomIT` | `@SpringBootTest` + Testcontainers postgres:18 + MockMvc + mint guest JWT; concurrent enqueue latch like RoomIT |
| `ProfileIT` | `EconomyIT` | MockMvc GET/PUT + settle via MatchService; assert XP vs Elo split |
| CASUAL rematch | `RematchIT` | Same dual-accept race; expect mode CASUAL on new match |
| CASUAL reconnect | `ReconnectIT` | Same 30s grace with mode CASUAL |
| `matchmaking_test.dart` | `catalog_test.dart` | ProviderScope + NomadApi fake; fake_async 8s → fallback |
| `casual_rematch_test.dart` | `rematch_overlay_test.dart` | Pump ResultOverlay casual → Play again; assert waiting route |
| `catalog_test.dart` | self | Assert `Quick Match` + profile a11y / avatar chip |

**RoomIT scaffold** (lines 38–73):
```java
@SpringBootTest(classes = NomadGamesApplication.class,
        properties = { "nomad.jwt.secret=test-jwt-secret-that-is-32-bytes!!", ... })
@AutoConfigureMockMvc
@Testcontainers
class RoomIT {
    @Container @ServiceConnection
    static PostgreSQLContainer postgres = new PostgreSQLContainer("postgres:18");
}
```

**catalog_test pump** (lines 20–31):
```dart
await tester.pumpWidget(
  ProviderScope(
    overrides: [
      sessionStoreProvider.overrideWithValue(session),
      nomadApiProvider.overrideWithValue(_LocalCatalogApi(session)),
    ],
    child: const NomadApp(initialLocation: '/'),
  ),
);
```

## Shared Patterns

### Authentication (JWT guest)
**Source:** `RoomController.java` / `EconomyController.java`  
**Apply to:** CasualMatchmakingController, ProfileController, existing MatchController  
```java
@AuthenticationPrincipal Jwt jwt
private static UUID playerId(Jwt jwt) {
    return UUID.fromString(jwt.getSubject());
}
```
No new auth; guests allowed on QM + profile.

### Error handling
**Source:** services throw `ResponseStatusException`; controllers rarely map  
**Apply to:** queue (409 if already in human match), avatar (400 unknown preset), rematch (409/410 existing)  
```java
throw new ResponseStatusException(HttpStatus.CONFLICT, "already_owned"); // EconomyService style
```

### Sync settle inside TX
**Source:** `MatchService.afterTerminal` → `economy.grantMatchRewards`  
**Apply to:** after grants, `profile.recordSettlement(...)` in same TX  
```java
private Map<UUID, RewardGrant> afterTerminal(MatchEntity match) {
    // existing grants...
    // then profile.recordSettlement for each paid seat
}
```

### Rate limiting
**Source:** `JoinRateLimiter.java`  
**Apply to:** `POST /v1/matchmaking/casual` (playerId + IP)  
```java
joinRateLimiter.check(ip, playerId);
```

### Flutter wood page + Riverpod API
**Source:** `lobby_page.dart`, `shop_page.dart`  
**Apply to:** searching, fallback, profile, rematch-wait  
- `ConsumerStatefulWidget` + `ref.read(nomadApiProvider)`  
- PRES-02 hexes; Label 14 / Body 16 / Heading 20 / Display 28  
- 48dp touch targets; EN+RU via `AppLocalizations`

### Human PvP mode tag
**Source:** PRIVATE guards in `MatchService` + `_isPrivate` in `match_page.dart`  
**Apply to:** all former PRIVATE-only WS / reconnect / rematch eligibility paths — introduce `isHumanPvP` / `_isHuman`; keep rematch **chrome** split (`_isCasual` vs private Again?).

### Client display-only authority
**Source:** `WalletChip` / economy ECON-04  
**Apply to:** soft rating, XP, W/L, avatar persistence — never POST computed MMR/XP from client.

## No Analog Found

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| — | — | — | All Phase 5 files have a close analog. Soft Elo formula itself is new math but structural analog is `ReconnectPolicy` static utility. In-process casual FIFO has no prior queue class — compose from `JoinRateLimiter` concurrency + `RoomService`→`MatchService` create seam. |

## Metadata

**Analog search scope:** `backend/src/main/java/com/nomadgames/{matchmaking,session,economy,identity}`, `backend/src/main/resources/db/migration`, `backend/src/test/java`, `client/lib/{catalog,rooms,shop,games/alchiki,platform}`, `client/test`  
**Files scanned:** ~90 Java/Dart/SQL sources (controllers, services, key client pages, ITs)  
**Pattern extraction date:** 2026-09-11  
**Strong analogs used (3–5 core):** `RoomController`/`RoomService`, `EconomyController`/`EconomyService`/`WalletLedgerJdbc`, `MatchService.createPrivateMatch` + rematch, `lobby_page`/`shop_page`/`wallet_chip`, `catalog_page`/`ResultOverlay`
