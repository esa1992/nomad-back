# Phase 6: Stick Pull - Pattern Map

**Mapped:** 2026-09-14
**Files analyzed:** 22
**Analogs found:** 20 / 22

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `backend/.../catalog/CatalogService.java` | service | request-response | same file (flip `COMING_SOON`→`PLAYABLE`) | exact |
| `backend/.../catalog/CatalogIT.java` | test | request-response | same IT (assert PLAYABLE) | exact |
| `client/lib/catalog/catalog_page.dart` (`_StickPullTile`) | component | request-response | `_AlchikiTile` in same file | exact |
| `client/lib/catalog/catalog_models.dart` | model | transform | `lastBotDifficultyProvider` + local snapshot | exact |
| `client/lib/howto/stick_pull_howto_page.dart` | component | request-response | `alchiki_howto_page.dart` | exact |
| `client/lib/howto/howto_seen_store.dart` | utility | file-I/O | same store (add Stick Pull key) | exact |
| `client/lib/platform/router.dart` | route | request-response | `/howto/alchiki` + `/match` routes | exact |
| `backend/.../games/stickpull/StickPullSim.java` | service | event-driven | `AlchikiRules` / FEATURES bands (no Forge2D) | role-match |
| `backend/.../games/stickpull/StickPullBot.java` | service | event-driven | `ScriptedBot.java` | exact |
| `backend/.../games/stickpull/StickPullConstants.java` | config | — | `ScriptedBot` constants / `AlchikiEngine` clocks | role-match |
| `backend/.../session/MatchService.java` | service | request-response + event-driven | same file (`createMatch` / rematch / drop) | exact |
| `backend/.../session/internal/MatchWebSocketHandler.java` | middleware | streaming | same handler (`ThrowInput` branch) | exact |
| `backend/.../session/internal/ReconnectPolicy.java` | utility | request-response | same policy (`GRACE_SECONDS=30`) | exact |
| `backend/.../matchmaking/CasualQueueService.java` | service | request-response | same FIFO service | exact |
| `backend/.../matchmaking/RoomService.java` | service | CRUD | same create/join/ready/kickoff | exact |
| `backend/.../matchmaking/internal/RoomEntity.java` + Flyway `V10` | model / migration | CRUD | `RoomEntity` + `V3__rooms.sql` | exact |
| `client/lib/games/stick_pull/stick_pull_match_page.dart` | component | streaming | `alchiki/match_page.dart` | exact |
| `client/lib/games/stick_pull/stick_pull_game.dart` | component | transform | `alchiki/match_game.dart` (Flame only, no forge2d) | role-match |
| `client/lib/games/stick_pull/stick_pull_ws.dart` | utility | streaming | WS frame handling in `match_page.dart` | exact |
| `backend/.../profile/ProfileService.java` | service | CRUD | same `recordSettlement(..., game, ...)` | exact |
| `backend/.../economy` loadout `stick_pull` | service | CRUD | V7 SKUs + `getLoadout` already present | exact |
| `client/test/howto_stick_pull_test.dart` / `catalog_test.dart` | test | request-response | `howto_test.dart` / `catalog_test.dart` | exact |

## Pattern Assignments

### `CatalogService.java` — promote Coming Soon → PLAYABLE (CAT-02)

**Analog:** `backend/src/main/java/com/nomadgames/catalog/CatalogService.java`

**Core pattern** (lines 10–15):
```java
public CatalogResponse list() {
    return new CatalogResponse(List.of(
            new CatalogTileView("alchiki", CatalogTileStatus.PLAYABLE),
            new CatalogTileView("stick_pull", CatalogTileStatus.COMING_SOON), // → PLAYABLE
            new CatalogTileView("more_games", CatalogTileStatus.COMING_SOON)));
}
```

**Test analog:** `CatalogIT.catalogComingSoonTilesAreStickPullAndMoreGames` currently expects `COMING_SOON` for `stick_pull` — flip assertion to `PLAYABLE`; keep `more_games` Coming Soon.

---

### `catalog_page.dart` — `_StickPullTile` from `_AlchikiTile` + Coming Soon branch

**Analog:** `client/lib/catalog/catalog_page.dart`

**Catalog render branch** (lines 401–429) — today `stick_pull` falls into `_ComingSoonTile`; promote to playable twin of `_AlchikiTile`:
```dart
if (tile.id == 'alchiki' &&
    tile.availability == CatalogAvailability.playable) ...[
  _AlchikiTile(...),
  // private Alchiki band stays here
] else
  _ComingSoonTile(
    title: tile.id == 'stick_pull'
        ? l10n.stickPullTitle
        : l10n.moreGamesTitle,
    badge: l10n.comingSoon,
  );
```

**Playable tile chrome** (lines 531–607) — copy felt band, chips, accent Quick Match, wood+cream Play CTA; add third outline CTA `Create Stick Pull room`:
```dart
class _AlchikiTile extends StatelessWidget {
  // minHeight: 192, felt DecoratedBox, Difficulty chips, quickMatch accent, playAlchiki outlined
}
```

**How-to gate before bot** (lines 235–246):
```dart
Future<void> _playAlchiki() async {
  final bool seen = await store.isSeen();
  if (!seen) {
    context.go('/howto/alchiki?difficulty=$query');
  } else {
    context.go('/match?difficulty=$query');
  }
}
```
Stick Pull mirror: `/howto/stick-pull?...` and `/match?game=stickPull&difficulty=...` using **separate** seen store / difficulty provider.

**QM enqueue** (lines 249–261):
```dart
await ref.read(nomadApiProvider).enqueueCasual();
context.go('/matchmaking');
```
Extend API + route with `game=STICK_PULL` / `game=stickPull` (D-79).

---

### `catalog_models.dart` — separate Stick Pull bot chip memory

**Analog:** `client/lib/catalog/catalog_models.dart` lines 11–22

```dart
final lastBotDifficultyProvider =
    NotifierProvider<LastBotDifficulty, String>(LastBotDifficulty.new);

class LastBotDifficulty extends Notifier<String> {
  @override
  String build() => 'EASY';
  void setDifficulty(String query) { state = query; }
}
```

**Copy as:** `lastStickPullBotDifficultyProvider` — do **not** clobber Alchiki chip (RESEARCH yolo). Update local snapshot `stick_pull` → `CatalogAvailability.playable`.

---

### `stick_pull_howto_page.dart` — 5-card pager (STICK-05)

**Analog:** `client/lib/howto/alchiki_howto_page.dart`

**Imports / structure** (lines 1–26):
```dart
import 'package:client/howto/howto_diagrams.dart';
import 'package:client/howto/howto_seen_store.dart';
// ConsumerStatefulWidget with difficulty, fromPause, mode, matchId
```

**Cards + diagrams** (lines 53–83) — Alchiki uses 5 cards; Stick Pull also 5 with new ARB keys (`howtoStickSit*` … `howtoStickWin*` per 06-UI-SPEC):
```dart
static const List<Widget> _diagrams = <Widget>[ /* 5 static diagrams */ ];
List<({String title, String body})> _cards(AppLocalizations l10n) { ... }
```

**Seen + navigation** (lines 86–107):
```dart
Future<void> _goMatch({required bool persistSeen}) async {
  if (persistSeen && !widget.fromPause) {
    await ref.read(howToSeenStoreProvider).markSeen();
  }
  if (widget.fromPause && context.canPop()) { context.pop(); return; }
  // private/casual → /match?mode=&matchId= ; bot → /match?difficulty=
}
```
Stick Pull: persist `howto.stickpull.seen`; navigate with `game=stickPull`.

**Router analog:** `client/lib/platform/router.dart` lines 28–44 (`/howto/alchiki`) → add `/howto/stick-pull` with same query params.

---

### `howto_seen_store.dart` — dedicated prefs key

**Analog:** `client/lib/howto/howto_seen_store.dart` lines 8–31

```dart
class HowToSeenStore {
  static const String seenKey = 'howto.alchiki.seen';
  Future<bool> isSeen() async { ... }
  Future<void> markSeen() async { ... }
}
```

**Extend:** add `stickPullSeenKey = 'howto.stickpull.seen'` + `isStickPullSeen` / `markStickPullSeen` (or sibling store). Never reuse Alchiki key (CONTEXT pitfall).

---

### `StickPullSim.java` + package layout

**Analog package:** `backend/src/main/java/com/nomadgames/games/alchiki/` (`AlchikiEngine` `@Component` beside SPI — **not** new Modulith module).

**Do not implement `GameEngine`:** that SPI is throw/bones (`start`, `applyThrow`, `nextBotThrow`). Stick Pull is a dedicated sim; `MatchService` branches on `match.getGame()`.

**Numeric locks** live in `StickPullConstants` (RESEARCH yolo): soft force `0.012`, threshold `±0.85`, recovery `320ms`, burst `1.5s`, clock default `30s` / clamp `15–40`.

---

### `StickPullBot.java` — EASY/NORMAL/HARD jitter (BOT-02)

**Analog:** `backend/src/main/java/com/nomadgames/games/alchiki/internal/ScriptedBot.java`

**Difficulty switch + RNG noise** (lines 21–59):
```java
public static ThrowInput nextThrow(String difficulty, int seed, ...) {
    String diff = difficulty == null ? "EASY" : difficulty.toUpperCase();
    Random rng = new Random(mixed);
    switch (diff) {
        case "HARD" -> { /* tighter noise */ }
        case "NORMAL" -> { ... }
        default -> { /* EASY wider noise */ }
    }
    // return scripted input
}
```

Stick Pull bot returns **tap schedule** (mean TPS + pause windows per RESEARCH), not `ThrowInput`. Keep `final` utility + pure functions + unit tests like `ScriptedBotTest`.

---

### `MatchService.java` — game branching (create / rematch / settle)

**Analog:** same file

**Bot create currently Alchiki-only** (lines 70–91):
```java
public MatchCreatedResponse createMatch(UUID playerId, CreateMatchRequest request) {
    if (request == null || !"ALCHIKI".equals(request.game()) || !"BOT".equals(request.mode())) {
        throw new IllegalArgumentException("game/mode");
    }
    // engine.start(difficulty) → MatchEntity(..., "ALCHIKI", "BOT", ...)
}
```
**Extend:** accept `STICK_PULL` + `BOT`; start `StickPullSim` lifecycle instead of `GameEngine.start`.

**Human create hardcodes ALCHIKI** (lines 109–146):
```java
public UUID createPrivateMatch(UUID hostId, UUID joinerId) {
    return createHumanMatch(hostId, joinerId, "PRIVATE");
}
public UUID createCasualMatch(UUID hostId, UUID joinerId) {
    return createHumanMatch(hostId, joinerId, "CASUAL");
}
private UUID createHumanMatch(...) {
    MatchEntity match = new MatchEntity(..., "ALCHIKI", mode, "NORMAL", ...);
    // mint reconnect tokens via ReconnectPolicy
}
```
**Extend:** `createPrivateMatch(host, joiner, game)` / `createCasualMatch(..., game)` threading `STICK_PULL`.

**Rematch reuses create\*** (lines 260–264) — must pass original `match.getGame()`:
```java
UUID newId = "CASUAL".equals(match.getMode())
        ? createCasualMatch(window.hostId, window.joinerId)
        : createPrivateMatch(window.hostId, window.joinerId);
```

**Settlement hooks already game-aware** (lines 656–700) — SoftElo/XP via `profile.recordSettlement(..., match.getGame(), ...)` + `economy.grantMatchRewards`. Stick Pull settle should call the same `afterTerminal` path so profile `STICK_PULL` W/L increments.

---

### `MatchWebSocketHandler.java` — TapInput beside ThrowInput

**Analog:** `backend/.../session/internal/MatchWebSocketHandler.java` lines 57–100

```java
String type = root.path("type").asText("");
if ("Ping".equals(type)) { sendJson(session, Map.of("type", "Pong")); return; }
if (!"ThrowInput".equals(type)) {
    sendError(session, "unknown_type", "unknown type");
    return;
}
PrivateThrowResult result = matches.applyPrivateThrow(...);
// broadcast ThrowResolved / MatchSettled
```

**Pattern to copy:** type allowlist → service call → broadcast resolved + terminal `MatchSettled`. Add `TapInput` → `matches.applyTap(...)` → broadcast `TapResolved` / `StickState` / `Countdown`. Keep Alchiki `ThrowInput` path untouched. Drop/close still calls `markDropped` / `leaveMatch` (lines 104–124).

---

### `ReconnectPolicy.java` — 30s Alchiki → 8s Stick Pull (SESS-04)

**Analog:** `backend/.../session/internal/ReconnectPolicy.java` lines 15–55

```java
public static final int GRACE_SECONDS = 30;
public static Instant graceDeadline(Instant now) {
    return now.plus(GRACE);
}
```

**Refactor pattern:**
```java
public static int graceSeconds(String game) {
    return "STICK_PULL".equals(game) ? 8 : 30;
}
public static Instant graceDeadline(Instant now, String game) {
    return now.plusSeconds(graceSeconds(game));
}
```

**Broadcast site** (`MatchService.markDropped` lines 374–382):
```java
Instant deadline = ReconnectPolicy.graceDeadline(now);
broadcastJson(matchId, Map.of(
    "type", "OpponentDropped",
    "secondsLeft", ReconnectPolicy.GRACE_SECONDS));
```
Must pass `match.getGame()` so Stick Pull clients see `secondsLeft ≤ 8`.

**Forfeit / no bot-fill** (`settleExpiredDrop` lines 480–487):
```java
private void settleExpiredDrop(MatchEntity match, boolean droppedHost) {
    // Remaining human wins. Never fill a private seat with a bot (D-42).
    match.setStatus(ReconnectPolicy.remainingWinStatus(droppedHost));
    ...
    afterTerminal(match);
}
```
Reuse unchanged for Stick Pull mid-tug (SESS-04 / D-86).

**Client clamp** (`match_page.dart` lines 785–792) defaults/clamps to 30 — Stick Pull match page must clamp to **8**.

---

### `CasualQueueService.java` — per-game FIFO

**Analog:** `backend/.../matchmaking/CasualQueueService.java`

**Current single FIFO** (lines 18–72):
```java
private final ConcurrentLinkedQueue<UUID> fifo = new ConcurrentLinkedQueue<>();
public CasualQueueResponse enqueue(UUID playerId, String ip) {
    ...
    UUID matchId = matches.createCasualMatch(peerId, playerId);
}
```

**Target pattern (RESEARCH):**
```java
ConcurrentHashMap<String, ConcurrentLinkedQueue<UUID>> fifos;
// enqueue(playerId, ip, game) → poll peer from fifos.get(game) only
// createCasualMatch(peer, self, game)
```

**Client API analog:** `nomad_api.dart` `enqueueCasual()` posts `{}` to `/v1/matchmaking/casual` — add `game` body/query. Searching/fallback pages (`searching_page.dart`, `fallback_page.dart`) hardcode Alchiki howto — thread Stick Pull discriminator.

---

### `RoomService.java` + Flyway — `rooms.game`

**Analog create** (lines 51–75):
```java
public RoomCreatedResponse create(UUID playerId) {
    RoomEntity room = new RoomEntity(UUID.randomUUID(), code, playerId, STATUS_LOBBY, ...);
}
```

**Kickoff** (lines 187–192):
```java
UUID matchId = matches.createPrivateMatch(room.getHostId(), room.getJoinerId());
```

**Schema analog:** `V3__rooms.sql` — next migration **V10** adds `game VARCHAR ... DEFAULT 'ALCHIKI'` (`ALCHIKI` \| `STICK_PULL`). Extend `RoomEntity` + `create(playerId, game)` + kickoff `createPrivateMatch(..., room.getGame())`. Shared catalog “Create room” stays Alchiki; Stick Pull tile uses `Create Stick Pull room`.

**Client:** `createRoom()` posts empty body — add `game` for Stick Pull path; lobby already navigates to howto with `mode=private` (`lobby_page.dart`).

---

### SoftElo / XP settlement hooks

**Analog:** `ProfileService.recordSettlement` lines 92–128 + `SoftElo.java`

```java
public void recordSettlement(UUID matchId, String mode, String game, List<SeatSettlement> seats) {
    String statsGame = game == null || game.isBlank() ? GAME_ALCHIKI : game;
    ...
    jdbc.incrementGameStats(seat.playerId(), statsGame, normalizeOutcome(...));
    if (casual && seats.size() == 2 && allClaimed) {
        applyCasualElo(...); // SoftElo.nextRating K=24
    }
}
```

**Already wired:** `MatchService.recordProfileSettlements` passes `match.getGame()`. Stick Pull only needs matches persisted with `game=STICK_PULL` — no new profile API. Economy grants via `grantSeat` / `MatchRewardTable` reuse difficulty + humanMatch flags.

---

### Economy Stick Pull skins (D-83)

**Already in catalog:** `V7__economy_ledger_shop.sql` SKUs `stick_pull_default`, `stick_pull_ice` slot `stick_pull`.

**Apply pattern from Alchiki presentation:** `match_game.dart` loadout helpers at match start only (D-56) — Stick Pull Flame paints shaft from `loadout['stick_pull']` (`stick_pull_default` → `#8B5A2B`, `stick_pull_ice` → ice accents). Never affect force math (D-54).

`MatchService.createMatch` already returns `economy.getLoadout(playerId)` in `toCreated` — include Stick Pull loadout on Stick Pull create/snapshot.

---

### Flutter Stick Pull match — GameWidget + HUD

**Analog:** `client/lib/games/alchiki/match_page.dart`

**Stack + GameWidget** (lines 1458–1468):
```dart
body: Stack(
  children: [
    if (_tableAttached)
      IgnorePointer(
        ignoring: _isTerminal || _paused,
        child: GameWidget.controlled(
          gameFactory: () => game,
        ),
      ),
    // Flutter HUD overlays: pause, scores, reconnect, result
  ],
)
```

Stick Pull: same Stack — Flame 1D lane (`StickPullGame` **without** forge2d) + Flutter stamina bars, clock, full-width tap zone (≥96dp), countdown overlay, reconnect banner. Pause → `/howto/stick-pull?fromPause=1`.

**WS frame switch** (lines 783–812): copy `OpponentDropped` / `OpponentRejoined` / terminal settle handling; replace `ThrowResolved` with `TapResolved` / `StickState` / `Countdown`.

**Rematch waiting:** reuse `rematch_waiting_page.dart` + `/match/rematch-wait` (router lines 47–56); new match must be Stick Pull via server rematch game threading.

---

## Shared Patterns

### Authentication / seat binding
**Source:** `MatchService.requireSeat` + WS ticket attrs in `MatchWebSocketHandler`
**Apply to:** All Stick Pull REST create/get/leave and `TapInput` handlers — cannot tap for other seat.

### Error handling (WS)
**Source:** `MatchWebSocketHandler` lines 96–100, 137–142
```java
} catch (ResponseStatusException ex) {
    sendError(session, codeFor(ex), ...);
} catch (IllegalArgumentException ex) {
    sendError(session, "invalid_throw", "invalid throw");
}
// Error frame: { type, code, message }
```
Stick Pull: use `invalid_tap` (or keep generic) — never trust client timestamps/force.

### Settlement pipeline
**Source:** `MatchService.afterTerminal` → economy grants + `profile.recordSettlement`
**Apply to:** Threshold win, clock-0, leave forfeit, reconnect forfeit — same as Alchiki terminal paths.

### Rematch mode rules (D-80)
**Source:** `MatchService.acceptRematch` dual-accept; bot one-tap `createMatch` from client
**Apply to:** Stick Pull private/casual rematch windows; bot Play again → `POST /v1/matches` with `game=STICK_PULL`.

### PRES-02 / UI chrome
**Source:** 01–05 UI-SPEC + Alchiki catalog/howto/match overlays
**Apply to:** All new Flutter Stick Pull surfaces — felt `#1B6B3A`, wood `#241810`, gold `#F0B429`; text-labeled 48dp targets; EN+RU ARB.

### No bot-fill mid-match
**Source:** `settleExpiredDrop` comment D-42
**Apply to:** Stick Pull 8s grace expiry — remaining wins; never spawn `StickPullBot` into dropped seat.

## No Analog Found

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `StickPullSim` stamina/clamp internals | service | event-driven | No 1D tug sim exists; copy **package/`@Component` layout** from Alchiki + FEATURES/D-88 math (RESEARCH) |
| Countdown `3-2-1-GO` server phase | service | event-driven | Alchiki has turn clocks, not GO countdown; new `StickPullPhase` + WS `Countdown` (RESEARCH frames) |

## Metadata

**Analog search scope:** `backend/src/main/java/com/nomadgames/{catalog,session,matchmaking,games,profile,economy}`, `backend/src/main/resources/db/migration`, `client/lib/{catalog,howto,games/alchiki,matchmaking,rooms,platform}`, related ITs/widget tests
**Files scanned:** ~45 (targeted greps + reads of 18 primary analogs)
**Pattern extraction date:** 2026-09-14
**Key planner takeaway:** Thread `game=STICK_PULL` through catalog → howto → rooms/queue → MatchService create/rematch → WS taps → 8s reconnect → settle; presentation clones Alchiki shells without Forge2D/`GameEngine`.
