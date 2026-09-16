# Phase 4: Economy + Cosmetic Shop - Pattern Map

**Mapped:** 2026-09-10
**Files analyzed:** 24
**Analogs found:** 21 / 24

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `backend/.../economy/EconomyController.java` | controller | request-response | `backend/.../matchmaking/RoomController.java` | exact |
| `backend/.../economy/EconomyService.java` | service | CRUD | `backend/.../matchmaking/RoomService.java` | role-match |
| `backend/.../economy/MatchRewardTable.java` | config | transform | `backend/.../catalog/CatalogService.java` | partial |
| `backend/.../economy/ShopCatalog.java` | model | CRUD | `backend/.../catalog/CatalogService.java` (records) | role-match |
| `backend/.../economy/internal/WalletLedgerJdbc.java` | utility | CRUD | *(none — JdbcClient greenfield)* | none |
| `backend/.../economy/internal/SoftPurchaseJdbc.java` | utility | CRUD | *(none — JdbcClient greenfield)* | none |
| `backend/.../economy/internal/InventoryJdbc.java` | utility | CRUD | `backend/.../matchmaking/internal/RoomRepository.java` | partial |
| `backend/.../economy/internal/LoadoutJdbc.java` | utility | CRUD | `backend/.../matchmaking/internal/RoomRepository.java` | partial |
| `backend/.../resources/db/migration/V7__economy_ledger_shop.sql` | migration | file-I/O | `backend/.../db/migration/V1__identity.sql` + `V3__rooms.sql` | exact |
| `backend/.../session/MatchService.java` | service | request-response | *(self — extend terminal paths)* | exact |
| `backend/.../session/MatchSnapshot.java` | model | request-response | *(self — extend record)* | exact |
| `backend/.../identity/GuestService.java` | service | CRUD | *(self — hook ensureDefaults)* | exact |
| `backend/.../session/MatchCreatedResponse.java` | model | request-response | *(self — optional loadout fields)* | exact |
| `backend/.../test/.../EconomyIT.java` | test | request-response | `backend/.../catalog/CatalogIT.java` + `RoomIT.java` | exact |
| `client/lib/shop/shop_page.dart` | component | request-response | `client/lib/rooms/join_page.dart` + `catalog_page.dart` | role-match |
| `client/lib/shop/shop_detail_page.dart` | component | request-response | `client/lib/rooms/join_page.dart` | role-match |
| `client/lib/shop/wallet_chip.dart` | component | request-response | `client/lib/catalog/catalog_page.dart` (`_LangTarget` / header) | partial |
| `client/lib/catalog/catalog_page.dart` | component | request-response | *(self — header + Shop)* | exact |
| `client/lib/platform/router.dart` | config | request-response | *(self — add `/shop`)* | exact |
| `client/lib/platform/api/nomad_api.dart` | service | request-response | *(self — extend Dio methods)* | exact |
| `client/lib/games/alchiki/pause_overlay.dart` | component | request-response | *(self — `ResultOverlay`)* | exact |
| `client/lib/games/alchiki/match_game.dart` | component | transform | *(self — seat fill paint)* | exact |
| `client/lib/game/saka_body.dart` | component | transform | *(self — fill/stripe ctor)* | exact |
| `client/lib/l10n/app_en.arb` + `app_ru.arb` | config | transform | *(self — ARB keys)* | exact |
| `client/test/shop_wallet_test.dart` | test | request-response | `client/test/catalog_test.dart` | exact |
| `client/test/result_reward_test.dart` | test | request-response | `client/test/rematch_overlay_test.dart` | exact |

## Pattern Assignments

### `backend/.../economy/EconomyController.java` (controller, request-response)

**Analog:** `backend/src/main/java/com/nomadgames/matchmaking/RoomController.java`

**Imports + JWT principal pattern** (lines 1–33):
```java
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.*;

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

**Auth / playerId extraction** (lines 64–66):
```java
private static UUID playerId(Jwt jwt) {
    return UUID.fromString(jwt.getSubject());
}
```

**Error handling** (lines 60–62):
```java
@ExceptionHandler(IllegalArgumentException.class)
@ResponseStatus(HttpStatus.BAD_REQUEST)
public void badRequest() {}
```

**Apply to EconomyController:** Mirror for `/v1/wallet`, `/v1/shop/catalog`, `/v1/shop/purchases`, `/v1/shop/equip`, `/v1/loadout`. Always take `playerId` from JWT — never from body. Use `@ResponseStatus` / `ResponseStatusException` for 404 SKU / insufficient funds (prefer explicit status codes like `RoomService`’s `HttpStatus.CONFLICT` / `GONE` pattern).

**Secondary analog:** `MatchController.java` lines 17–79 — same `@RequestMapping("/v1/matches")` + JWT + `IllegalArgumentException` handler.

---

### `backend/.../economy/EconomyService.java` (service, CRUD)

**Analog:** `backend/src/main/java/com/nomadgames/matchmaking/RoomService.java`

**Constructor injection + TransactionTemplate** (lines 34–48):
```java
@Service
public class RoomService {
    private final RoomRepository rooms;
    private final TransactionTemplate transactions;
    // ...
    public RoomService(RoomRepository rooms, PlatformTransactionManager transactionManager, ...) {
        this.rooms = rooms;
        this.transactions = new TransactionTemplate(transactionManager);
    }
```

**Idempotent collision handling** (lines 54–69):
```java
try {
    RoomEntity saved = transactions.execute(status -> {
        RoomEntity room = new RoomEntity(...);
        return rooms.saveAndFlush(room);
    });
    return toCreated(saved);
} catch (DataIntegrityViolationException collision) {
    lastCollision = collision;
}
```

**Cross-module one-way call** (lines 37, 48): `RoomService` depends on `MatchService` — same direction as `session` → `economy` (never reverse).

**Apply:** `EconomyService.grantMatchRewards` / `purchase` / `equip` / `ensureDefaults` as `@Service` with Jdbc writers; catch unique-violation / `DuplicateKeyException` for ledger & soft_purchase idempotency (same spirit as code-collision retry). Keep grant **sync** and callable from `MatchService` inside existing `@Transactional`.

**Secondary analog:** `GuestService.java` lines 12–29 — thin `@Transactional` create-then-return.

---

### `backend/.../economy/MatchRewardTable.java` + `ShopCatalog.java` (config/model, transform/CRUD)

**Analog:** `backend/src/main/java/com/nomadgames/catalog/CatalogService.java`

**In-module records + static list** (lines 8–27):
```java
@Service
public class CatalogService {
    public CatalogResponse list() {
        return new CatalogResponse(List.of(
                new CatalogTileView("alchiki", CatalogTileStatus.PLAYABLE),
                new CatalogTileView("stick_pull", CatalogTileStatus.COMING_SOON),
                new CatalogTileView("more_games", CatalogTileStatus.COMING_SOON)));
    }
}
enum CatalogTileStatus { PLAYABLE, COMING_SOON }
record CatalogTileView(String id, CatalogTileStatus status) {}
record CatalogResponse(List<CatalogTileView> tiles) {}
```

**Apply:** Put reward constants and SKU DTOs as package-local records/enums next to the service (or seed-backed queries). Prefer DB seed for SKUs (ECON-02); keep reward table as Java constants (Claude discretion from RESEARCH).

---

### `backend/.../economy/internal/*Jdbc.java` (utility, CRUD)

**No JdbcClient writers exist in the repo** (grep: zero `JdbcClient` usages). Closest related patterns:

**Row lock intent** — `RoomRepository.java` lines 19–25:
```java
@Lock(LockModeType.PESSIMISTIC_WRITE)
@Query("SELECT r FROM RoomEntity r WHERE r.id = :id")
Optional<RoomEntity> findByIdForUpdate(@Param("id") UUID id);
```

**Test-side SQL verification** — `RoomIT.java` lines 230–233 / 258–262:
```java
new JdbcTemplate(dataSource)
    .update("UPDATE rooms SET idle_expires_at = now() - interval '1 second' WHERE id = ?", ...);
JdbcTemplate jdbc = new JdbcTemplate(dataSource);
UUID hostId = jdbc.queryForObject("SELECT host_id FROM rooms WHERE id = ?", UUID.class, ...);
```

**Apply:** Implement writers with Spring `JdbcClient` per RESEARCH Pattern 2 (named params INSERT ledger + UPDATE wallets). Use `SELECT … FOR UPDATE` on wallet rows for purchases. Treat unique violation on `idempotency_key` as success + re-read (RESEARCH sketch). Do **not** introduce JPA entities that mutate `balance`.

---

### `V7__economy_ledger_shop.sql` (migration, file-I/O)

**Analog:** `V1__identity.sql` + `V3__rooms.sql`

**FK + UNIQUE style** (`V1__identity.sql` lines 1–17):
```sql
CREATE TABLE players (
    id UUID PRIMARY KEY,
    guest BOOLEAN NOT NULL,
    created_at TIMESTAMPTZ NOT NULL
);
CREATE TABLE refresh_tokens (
    id UUID PRIMARY KEY,
    player_id UUID NOT NULL REFERENCES players (id),
    token_hash BYTEA NOT NULL UNIQUE,
    ...
);
```

**Status VARCHAR + defaults** (`V3__rooms.sql` lines 1–12):
```sql
CREATE TABLE rooms (
    id UUID PRIMARY KEY,
    code VARCHAR(6) NOT NULL UNIQUE,
    host_id UUID NOT NULL REFERENCES players (id),
    ...
    status VARCHAR(32) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL
);
```

**Apply:** Next migration after `V6__room_version.sql`. Tables: `wallets`, `wallet_ledger` (UNIQUE `idempotency_key`), `soft_purchases` (UNIQUE idempotency), empty `purchases(provider, token)` PK, `cosmetic_skus`, `inventory`, `loadout` + seed defaults. TIMESTAMPTZ + UUID PK conventions match V1/V3.

---

### `MatchService.java` + `MatchSnapshot.java` (service/model — modify)

**Analog:** self — terminal settle + snapshot builder

**Terminal leave path** (`MatchService.java` lines 125–141):
```java
@Transactional
public LeaveResponse leaveMatch(UUID playerId, UUID matchId) {
    MatchEntity match = requireSeat(playerId, matchId);
    if (!MatchStatus.IN_PLAY.name().equals(match.getStatus())) {
        return new LeaveResponse(snapshot(match));
    }
    // ... setStatus ...
    matches.save(match);
    MatchSnapshot settled = snapshot(match);
    broadcastSettled(match.getId(), settled);
    return new LeaveResponse(settled);
}
```

**Snapshot construction** (lines 635–653):
```java
private MatchSnapshot snapshot(MatchEntity match, UUID viewerId) {
    return new MatchSnapshot(
            match.getStatus(),
            match.getPlayerScore(),
            // ... existing fields ...
            remainingGraceSeconds(match, viewerId));
}
```

**WS settle frame** (lines 563–570):
```java
private void broadcastSettled(UUID matchId, MatchSnapshot snapshot) {
    // Map.of("type", "MatchSettled", "match", snapshot)
}
```

**Current record** (`MatchSnapshot.java` lines 6–23): no grant fields yet.

**Apply:**
1. Inject `EconomyService`; after every terminal `setStatus` (`applyThrow` / `applyPrivateThrow` / `leaveMatch` / `settleExpiredDrop` / clock forfeits), call `grantMatchRewards` **before** building snapshot.
2. Extend `MatchSnapshot` with `coinsGranted` / `gemsGranted` (viewer-specific) **or** add `grants` map on WS frame (RESEARCH open Q — prefer map on `MatchSettled`).
3. Single private `afterTerminal(match)` helper to avoid missing exits (Pitfall 1).
4. On create/rematch/rejoin, attach seat loadout maps from economy for presentation.

---

### `GuestService.java` (service — modify)

**Analog:** self — mint hook

**Core mint** (lines 23–28):
```java
@Transactional
public GuestSessionResponse createGuest() {
    UUID playerId = UUID.randomUUID();
    players.save(new PlayerEntity(playerId, true, Instant.now()));
    TokenPair pair = tokens.issue(playerId, true);
    return new GuestSessionResponse(playerId, pair.accessToken(), pair.refreshToken(), true);
}
```

**Apply:** After `players.save`, call `economy.ensureDefaults(playerId)` (wallets 0/0 + free inventory/loadout). One-way `identity` → `economy`. Do not put balance fields on `PlayerEntity`.

---

### `EconomyIT.java` (test, request-response)

**Analog:** `CatalogIT.java` (JWT + MockMvc) + `RoomIT.java` (JdbcTemplate asserts / races) + `ThrowAuthorityIT.java` (forged client fields ignored)

**IT scaffold** (`CatalogIT.java` lines 24–50):
```java
@SpringBootTest(classes = NomadGamesApplication.class,
        properties = "nomad.jwt.secret=test-jwt-secret-that-is-32-bytes!!")
@AutoConfigureMockMvc
@Testcontainers
class CatalogIT {
    @Container @ServiceConnection
    static PostgreSQLContainer postgres = new PostgreSQLContainer("postgres:18");

    @Test
    void catalogWithoutBearerIsUnauthorized() throws Exception {
        mockMvc.perform(get("/v1/catalog")).andExpect(status().isUnauthorized());
    }
```

**Mint helper** (`CatalogIT.java` lines 63–68 / `RoomIT.java` 403–407):
```java
private String mintAccessToken() throws Exception {
    MvcResult minted = mockMvc.perform(post("/v1/identity/guest")
            .contentType(APPLICATION_JSON).content("{}"))
            .andExpect(status().isCreated()).andReturn();
    return JsonPath.read(minted.getResponse().getContentAsString(), "$.accessToken");
}
```

**Authority pattern** (`ThrowAuthorityIT.java` lines 61–84): POST with forged client fields → assert server ignores them (mirror for forged `coinsDelta` / balance).

**Apply:** Cover ECON-01…05: grant on settle + leave + drop; purchase idempotency; catalog 7 categories; equip on create; `purchases` table empty UNIQUE; `ModularityTest` must stay green with new `economy` package.

---

### `client/lib/shop/shop_page.dart` + `shop_detail_page.dart` (component, request-response)

**Analog:** `client/lib/rooms/join_page.dart` (wood page shell) + `catalog_page.dart` (chips / load-error / FilterChip)

**Wood page + styles** (`join_page.dart` lines 15–39, 116–120):
```dart
static const Color _wood = Color(0xFF241810);
static const Color _onDark = Color(0xFFF4E8C8);
static const Color _accent = Color(0xFFF0B429);
// Label 14 / Body 16 / Heading 20
return Scaffold(
  backgroundColor: _wood,
  body: SafeArea(
    child: Padding(
      padding: const EdgeInsets.all(16),
```

**API + error status mapping** (`join_page.dart` lines 75–106):
```dart
try {
  final RoomLobby lobby = await ref.read(nomadApiProvider).joinRoom(code: _normalized);
  // navigate
} on NomadApiException catch (error) {
  setState(() { _joining = false; _errorStatus = error.statusCode; });
}
```

**Selected chip accent** (`catalog_page.dart` lines 471–494):
```dart
return FilterChip(
  selected: selected,
  selectedColor: _CatalogPageState._accent,
  backgroundColor: Colors.transparent,
  side: selected ? BorderSide.none : const BorderSide(color: _CatalogPageState._onDark, width: 1),
  ...
);
```

**Apply:** Shop shelf = wood Scaffold + Back + wallet + Shop|Owned segment + 7 category chips + 2-col GridView. Detail = pushed wood page with felt disk `#1B6B3A` 96dp. Buy/Equip use accent when enabled; errors use destructive banner like `_CatalogBanner`.

---

### `client/lib/shop/wallet_chip.dart` (component, request-response)

**Analog:** catalog header cluster (`catalog_page.dart` lines 201–218) + `_LangTarget` (48dp text control)

**Header row** (lines 201–218):
```dart
Row(
  children: [
    Expanded(child: Text(l10n.appTitle, style: _heading)),
    _LangTarget(...), // EN
    _LangTarget(...), // RU
  ],
)
```

**Apply:** Insert read-only wallet chip **leading of trailing cluster**: title | `[COINS n · GEMS m]` | Shop | EN RU. Chip: wood fill, 1dp cream outline, Label 14, height 48, **not** navigable. Refresh via `GET /v1/wallet` after catalog load / settle / purchase.

---

### `client/lib/catalog/catalog_page.dart` (component — modify)

**Analog:** self

**Load + retry banner** (lines 93–134, 221–226):
```dart
Future<void> _load() async {
  setState(() { _loading = true; _error = false; });
  try {
    final CatalogSnapshot next = await ref.read(nomadApiProvider).fetchCatalog();
    // ...
  } on NomadApiException catch (error) {
    if (error.statusCode == 401) { /* clear → splash */ }
    setState(() { _loading = false; _error = true; });
  }
}
```

**Apply:** Parallel-fetch wallet with catalog; add Shop `TextButton`/`Outlined` wood control → `context.push('/shop')`; wallet error banner uses `errorWallet` without blocking Shop.

---

### `client/lib/platform/router.dart` (config — modify)

**Analog:** self — GoRoute list

**Route pattern** (lines 11–70):
```dart
GoRouter buildRouter({String initialLocation = '/splash'}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(path: '/', builder: (context, state) => const CatalogPage()),
      GoRoute(path: '/join', builder: (context, state) => const JoinPage()),
      // query-param pages: /lobby?roomId=, /match?difficulty=
```

**Apply:** Add `/shop` (and optional `?sku=` for detail or child route). Prefer pushed page on same stack (04-UI-SPEC). Import new shop pages.

---

### `client/lib/platform/api/nomad_api.dart` (service — modify)

**Analog:** self — Dio GET/POST + `NomadApiException`

**GET pattern** (lines 622–631):
```dart
Future<CatalogSnapshot> fetchCatalog() async {
  try {
    final Response<dynamic> response = await _dio.get<dynamic>('/v1/catalog');
    return _parseCatalog(response.data);
  } on DioException catch (error) {
    throw NomadApiException('Catalog failed', statusCode: error.response?.statusCode);
  }
}
```

**POST pattern** (lines 550–562):
```dart
Future<RoomCreated> createRoom() async {
  try {
    final Response<dynamic> response = await _dio.post<dynamic>(
      '/v1/rooms', data: <String, Object>{},
    );
    return _parseRoomCreated(response.data);
  } on DioException catch (error) {
    throw NomadApiException('Room create failed', statusCode: error.response?.statusCode);
  }
}
```

**Apply:** Add `fetchWallet`, `fetchShopCatalog`, `purchaseSku({skuId, idempotencyKey})`, `equipSku({slot, skuId})`, `fetchLoadout`. Parse `coinsGranted`/`gemsGranted` (and optional `grants` map) in `_matchFromMap` / throw/leave parsers. Generate idempotency key with `Random.secure()` hex — **no new uuid package**.

---

### `client/lib/games/alchiki/pause_overlay.dart` (`ResultOverlay` — modify)

**Analog:** self + `rematch_overlay_test.dart` pump helper

**Result column** (`pause_overlay.dart` lines 189–252):
```dart
children: [
  Text(heading, style: _heading, textAlign: TextAlign.center),
  const SizedBox(height: 16),
  Text(pair, style: _display, textAlign: TextAlign.center),
  // INSERT reward lines under score pair (D-46)
  const SizedBox(height: 24),
  // Play again / Again? ...
  _PanelButton(label: l10n.backToCatalog, outlined: true, onTap: onBackToCatalog),
  // ADD secondary Shop TextButton — pops to catalog then /shop
],
```

**Apply:** Add optional `coinsGranted` / `gemsGranted` ctor params; show `l10n.rewardCoins(n)` / `rewardGems(m)` only when > 0. Keep rematch CTAs primary. Shop link secondary cream TextButton.

---

### `match_game.dart` + `saka_body.dart` (presentation — modify)

**Analog:** self — paint-only ctor overrides

**Seat fills at start** (`match_game.dart` lines 52–55, 143–156):
```dart
static const Color _youFill = Color(0xFFFFF6D6);
static const Color _youStripe = Color(0xFF8B4513);
hostSaka = SakaBody(
  fill: localIsHost ? _youFill : _oppFill,
  stripe: localIsHost ? _youStripe : _oppStripe,
  ...
);
```

**Physics untouched** (`saka_body.dart` lines 16–40):
```dart
SakaBody({ Color fill = SakaBody.fill, Color stripe = SakaBody.stripe, ... })
  : ...
    fixtureDefs: [
      FixtureDef(
        CircleShape()..radius = TableConstants.sakaRadiusM,
        density: _density,
        friction: TableConstants.friction,
        restitution: TableConstants.restitution,
      ),
    ],
```

**Apply:** Map server loadout SKU → fill/stripe/trail **colors only** at match start / rematch kickoff. Never change density/friction/restitution/impulse. No mid-throw swap (D-56).

---

### `client/lib/l10n/app_en.arb` + `app_ru.arb` (config — modify)

**Analog:** self — keyed strings + placeholders

**Placeholder pattern** (`app_en.arb` lines 40–46):
```json
"previewHud": "preview {n}",
"@previewHud": {
  "placeholders": { "n": { "type": "int" } }
},
```

**Apply:** Add all 04-UI-SPEC keys (`shop`, `owned`, `buyItem`, `equipItem`, `coins`, `gems`, `rewardCoins`, `rewardGems`, category keys, error/empty strings). Complete RU in `app_ru.arb`. Regenerate l10n via Flutter gen-l10n.

---

### `client/test/shop_wallet_test.dart` (test)

**Analog:** `client/test/catalog_test.dart`

**Override pattern** (lines 9–27):
```dart
class _LocalCatalogApi extends NomadApi {
  _LocalCatalogApi(SessionStore session) : super(sessionStore: session);
  @override
  Future<CatalogSnapshot> fetchCatalog() async => CatalogSnapshot.local;
}

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

**Apply:** Fake wallet + shop catalog on `NomadApi`; assert Shop entry, wallet chip text, `/shop` grid, empty/error Retry.

---

### `client/test/result_reward_test.dart` (test)

**Analog:** `client/test/rematch_overlay_test.dart`

**Direct overlay pump** (lines 6–21, 64–80):
```dart
Future<void> _pump(WidgetTester tester, Widget Function(AppLocalizations l10n) builder) async {
  await tester.pumpWidget(MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Builder(builder: (context) => Scaffold(body: builder(AppLocalizations.of(context)))),
  ));
}
// ResultOverlay(... onPlayAgain: () {}) → expect Play again
```

**Apply:** Pass `coinsGranted` / `gemsGranted`; assert `+N COINS` / optional GEMS; assert Shop secondary link present and rematch CTA still primary.

---

## Shared Patterns

### Authentication (JWT on all economy REST)
**Source:** `RoomController.java` lines 31–32, 64–66; `SecurityConfig.java` lines 26–34  
**Apply to:** All `/v1/wallet`, `/v1/shop/*`, `/v1/loadout`
```java
public RoomCreatedResponse create(@AuthenticationPrincipal Jwt jwt) {
    return rooms.create(playerId(jwt));
}
private static UUID playerId(Jwt jwt) {
    return UUID.fromString(jwt.getSubject());
}
// SecurityFilterChain: anyRequest().authenticated() except guest/refresh/health/ws
```
Guests shop freely (D-51) — no bind gate; guest JWT already authenticates.

### Error handling (HTTP status + client NomadApiException)
**Source:** `RoomController` `@ExceptionHandler`; `RoomService` `ResponseStatusException`; client `NomadApiException(statusCode)`  
**Apply to:** Controllers + Flutter shop/purchase/equip
```java
throw new ResponseStatusException(HttpStatus.CONFLICT, "not your turn");
```
```dart
} on NomadApiException catch (error) {
  setState(() { _errorStatus = error.statusCode; });
}
```
Map insufficient funds to clear body / client `errorInsufficientFunds` (402/409 — planner pick; keep consistent).

### Server authority (no client deltas)
**Source:** `ThrowAuthorityIT.java` forged score ignored; CONTEXT D-45/ECON-04  
**Apply to:** Grant + purchase paths — reject/ignore any client `coinsDelta` / balance fields; HUD never authorizes buy.

### Sync grant inside settle TX
**Source:** RESEARCH Pattern 1 + `MatchService` `@Transactional` terminal methods  
**Apply to:** All terminal branches before snapshot/WS broadcast — **not** async `@ApplicationModuleListener` for overlay-critical grants.

### Presentation-only cosmetics
**Source:** `SakaBody` fixture constants + `match_game` fill/stripe ctor  
**Apply to:** Loadout → Color/paint only; `TableConstants` untouched.

### Localization
**Source:** Existing ARB + `AppLocalizations.of(context)` in catalog/join/result  
**Apply to:** Every new shop/wallet/reward string from 04-UI-SPEC EN+RU.

### Modulith direction
**Source:** `RoomService` → `MatchService`; `ModularityTest`  
**Apply to:** `session` → `economy`, `identity` → `economy`; economy must not import session types (plain command records in economy package).

## No Analog Found

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `economy/internal/WalletLedgerJdbc.java` | utility | CRUD | No `JdbcClient` writers in codebase yet — use RESEARCH Pattern 2 + Spring docs; lock pattern only from `RoomRepository` FOR UPDATE |
| `economy/internal/SoftPurchaseJdbc.java` | utility | CRUD | Same — greenfield append-only purchase TX |
| *(partial)* empty `purchases` IAP shell | migration | file-I/O | No prior IAP table; schema from RESEARCH Pattern 3 / Play token UNIQUE |

Planner should copy RESEARCH code sketches for JdbcClient ledger INSERT + unique-violation replay when implementing these three.

## Metadata

**Analog search scope:** `backend/src/main/java/com/nomadgames/**`, `backend/src/test/**`, `backend/src/main/resources/db/migration/**`, `client/lib/**`, `client/test/**`  
**Files scanned:** ~90 Java/Dart/SQL sources (59 Java main, 8 IT, 6 Flyway, 37 Dart lib, 17 Dart tests)  
**Pattern extraction date:** 2026-09-10  
**JdbcClient status:** not used in production code yet — Phase 4 introduces it  
**Strong analogs retained:** RoomController/RoomService/RoomIT, CatalogController/CatalogService/CatalogIT, MatchService/MatchSnapshot/MatchController, GuestService, join_page/catalog_page/ResultOverlay/nomad_api/router, rematch_overlay_test/catalog_test, SakaBody/match_game paints
)
