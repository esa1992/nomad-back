# Phase 3: Private Rooms + Casual Reconnect - Research

**Researched:** 2026-09-07
**Domain:** Authoritative 1v1 Alchiki private rooms, rematch, casual reconnect, consented forfeit
**Confidence:** HIGH (locked decisions + existing code + official Spring/Colyseus/pub.dev docs). Transport seam tags `webfetch` LOW / `websearch --verified` MEDIUM; official URLs are treated as primary anyway.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-26:** Catalog grows **two new CTAs**: **Create room** and **Join by code**. Do not fold both into a single «With a friend» screen. Existing **Play Alchiki** + EASY/NORMAL/HARD chips stay for the **bot** path only.
- **D-27:** After the second guest joins, the match does **not** start immediately. Both players tap **Ready**; then the server starts. Nobody should eat a throw unprepared.
- **D-28:** Host lobby shows a large 4–6 character code plus **system share sheet** (WhatsApp/Telegram/etc.) **and** **Copy**. Deep links are not required this phase (`go_router` can take them later).
- **D-29:** **Host-alive lobby:** if the host leaves the lobby before kickoff, the **code dies immediately**. If **10 minutes** pass with nobody reaching both-Ready, the room closes. Joiner must not sit in a zombie lobby.
- **D-30:** When both Ready, the **joiner throws first**. Host waited; guest starts. Server assigns seats — the client does not pick turn order.
- **D-31:** Private-room Alchiki is always **NORMAL (6 target bones)**. Difficulty chips are **bot-only**. Do not put EASY/HARD on Create room.
- **D-32:** Join errors are short copy (**no such room** / **already started** / **host left**) and the **code field stays** so the player can type another code without bouncing to the catalog.
- **D-33:** Lobby labels are **Guest-XXXX** (last four characters of `playerId`). No username yet (bind is Phase 7).
- **D-34:** Opponent aim is **not live**. Same theatrical as the bot: after the server accepts a throw it sends `ThrowResolved`; the waiting client plays **aim + hold + keyframe settle**. No 60 Hz live physics, no telegraph of aim angle over WebSocket.
- **D-35:** While the opponent has not released yet: table frozen at last settle, HUD **their 20s clock**, plus a **static “aiming” pose with no angle**. Not a live arrow.
- **D-36:** **Your** throw still gets local Forge2D **preview then morph onto JVM keyframes** (Phase 1 D-10). The opponent sees **only** the keyframe buffer for that throw.
- **D-37:** **Two sakas**, different colors, parked on the rim; only the current owner’s saka throws. Do not keep the single shared saka from the bot table.
- **D-38:** **REST** for create/join room, lobby Ready, rematch accept, leave. **Raw WebSocket** (JSON, **not STOMP/SockJS**) for the in-play match channel: `ThrowInput`, `ThrowResolved`, `RejoinSnapshot`, `Ping`. One socket owned by session. Steal Colyseus **patterns** (seat hold, rotating rejoin token, full snapshot) — do **not** adopt Colyseus/Nakama as the backend.
- **D-39:** Guests may create and join private rooms (FEATURES: casual + private stay open for guests). Bind is not a gate.
- **D-40:** Room code is **4–6 alphanumeric** (MODE-01). Planner may exclude ambiguous glyphs (0/O, 1/I) as long as the code stays short and shareable.
- **D-41:** Casual Alchiki reconnect grace is **30 seconds** (SESS-02 / ROADMAP). **Not** the research 60s proposal. Seat held on the server; token bound to `playerId` + `matchId`, rotate on use; **full snapshot** on rejoin, never a delta from a dead client. Client auto-retries then offers **Rejoin**. Opponent HUD: **reconnecting + server timer**. Pause **turn/match clocks** for the dropped seat during grace so a Wi-Fi blip is not a free 20s forfeit. Consented leave is **0 s grace** (not a reconnect).
- **D-42:** If the 30s grace expires in a **private** match, the remaining player **wins**. **No bot-fill** of a friend’s seat (bot-fill is a later casual-queue idea, not this phase).
- **D-43:** **Rematch (MODE-05):** after a **private** result, both see **Again?** with a **10s** accept window; both must accept or both return to catalog. After a **bot** result, **one-tap Play again** (no dual accept). Rematch is a **new match** with the same two seats (private) or a new bot match (bot). Joiner-first (D-30) applies to a private rematch kickoff.
- **D-44:** **Leave/forfeit:** keep the existing Pause **confirm** dialog. Consented leave ends the match **immediately as a loss** for the leaver (SESS-05). Vs bot: still `BOT_WIN`. Vs human: **opponent wins** — do **not** write `BOT_WIN` onto a two-player row. Crash/drop ≠ Leave.

### Claude's Discretion
- Exact code alphabet, lobby layout, Ready button chrome, share-sheet copy — UI-SPEC / planner, within PRES-02 palette.
- WS frame schema, ticket vs query JWT, 1 Hz housekeeping, Flyway room tables — researcher/planner, as long as D-38–D-42 hold.
- Whether Create room is a catalog button that pushes `/lobby` or a sheet; Join is a catalog button that pushes `/join` with a code field — both CTAs must exist (D-26).
- How-to: if `howto.alchiki.seen` is already true, skip the pager on the way to a private table (D-14). First-ever Alchiki (bot or room) still gets the five cards.
- Break the Modulith cycle `games ↔ session` **before** two-player types are shared (STATE concern). Do not paper over it with `*.*.internal` forever.
- `web_socket_channel` 3.x per STACK.md; reconnect token in secure storage beside refresh.
- Ranked reconnect, Quick Match empty-queue, Stick Pull reconnect, chat/emotes — out of this phase.

### Deferred Ideas (OUT OF SCOPE)
- Casual Quick Match + empty-queue bot/invite (Phase 5)
- Ranked reconnect, aggregate pause budget, rated forfeit (Phase 7 / SESS-03)
- Stick Pull reconnect (Phase 6 / SESS-04)
- Chat, emotes, friends list, QR codes, deep-link join (v2 / later unless planner finds deep links free)
- Bot-fill of a disconnected **casual queue** seat (not private rooms)
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| MODE-01 | Player can create a private room and get a short 4–6 character join code | REST `POST /v1/rooms`; Postgres unique code; 5-char Crockford-like alphabet; host lobby shows code |
| MODE-02 | Another player can join that room by entering the code | REST `POST /v1/rooms/join`; errors keep the field (D-32); host-alive + 10 min TTL (D-29) |
| MODE-05 | After bot or private match the player can accept Rematch within a short window | Bot: one-tap `POST /v1/matches` again. Private: 10s dual accept → new match, joiner-first |
| SESS-02 | After a brief disconnect in Casual Alchiki the player can rejoin within 30s from a full server snapshot | Colyseus seat-hold + rotating token + `RejoinSnapshot`; clocks paused in grace; no 60s / no bot-fill |
| SESS-05 | Consented leave/forfeit ends the match immediately as a loss | Existing Leave confirm; 0s grace; `BOT_WIN` vs bot; `HOST_WIN`/`JOINER_WIN` vs human (never `BOT_WIN` on a two-player row) |
</phase_requirements>

## Summary

Phase 3 is the first **human** Alchiki match. Phase 2 already ships guest JWT, catalog, and an authoritative **bot** loop over REST (`POST /v1/matches` + `/throws` + `/leave`). This phase **adds** Create room / Join by code, a both-Ready lobby, a raw WebSocket in-play channel, rematch, 30s casual reconnect, and honest forfeit — without reopening Flutter/Flame/Forge2D/dyn4j and without adopting Colyseus/Nakama as a product.

The live codebase is not ready to grow two-player types on top of the current cut. `MatchService` imports `AlchikiRules`, `MatchStatus`, and `internal.ScriptedBot`; `AlchikiEngine` implements `session.GameEngine`. That is a Modulith **cycle** plus an **internal-package** violation — `ModularityTest` fails today. `matches` has a single `player_id` and `leaveMatch` always writes `BOT_WIN`. The client table has one `SakaBody`. `pom.xml` has no WebSocket starter; `pubspec.yaml` has no `web_socket_channel`.

**Primary recommendation:** Wave 0 breaks `games ↔ session` by expanding `GameEngine` so session never imports games types, then add a `matchmaking` module (rooms/lobby) + in-heap `MatchSession` with raw `TextWebSocketHandler`, rotating reconnect token, full snapshot, and seat-based settlement (`HOST_WIN`/`JOINER_WIN`). Prefer SESS-02 **30s** over SUMMARY.md’s 60s casual proposal. Steal Colyseus/Nakama **room patterns only**.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Create / join room + Ready lobby | API / Backend | Browser / Client (code field, share, Ready) | Server owns code, TTL, host-alive; client only displays |
| Room code persistence + uniqueness | Database / Storage | API / Backend | Postgres unique + `expires_at`; no Redis |
| Seat assignment + joiner-first | API / Backend | — | Client must not pick turn order (D-30) |
| In-play throws + keyframes | API / Backend | Browser / Client (preview + replay) | Same authority as Phase 2; WS is transport, not a second scorer |
| Opponent theatrical turn | Browser / Client | — | `ThrowResolved` → aim + hold + keyframes (D-34); no live aim |
| Two sakas / colors | Browser / Client + API burst spawn | — | PRIVATE world has two saka bodies; bot path stays one `saka` |
| Reconnect seat + 30s grace | API / Backend (heap session) | Browser / Client (auto-retry + Rejoin) | Server timer is truth; clocks freeze during grace |
| Consented leave / rematch accept | API / Backend | Browser / Client (confirm / Again?) | REST; 0s grace; dual 10s window |
| Guest identity | API / Backend | Browser / Client (secure store) | Existing mint; guests may create/join (D-39) |
| i18n + PRES-02 chrome | Browser / Client | — | New keys EN/RU; palette already locked |

## Project Constraints (from .cursor/rules/)

Actionable directives from `.claude/.cursor/rules` (PROJECT.md + STACK.md):

- **Authority:** Backend is source of truth; client never authors score, outcome, rating, balance, grants.
- **Platform:** One Flutter client for Android + iOS; Android remains the proof device.
- **Physics lock:** Flutter 3.47 + Flame 1.38 + **forge2d 0.14.2 / flame_forge2d 0.19.3+7**. Do not upgrade Forge2D. Do not reopen Unity/Godot.
- **Backend lock:** Java 21 + Spring Boot 4.1.1 + Modulith 2.1.1; PostgreSQL 18; **no Redis**; REST + **raw** WebSocket (not STOMP/SockJS).
- **Auth:** First-party HS256 access JWT (~15 min) + opaque rotating refresh. No Keycloak / Firebase / OAuth.
- **Localization:** i18n keys; MVP EN+RU only.
- **Art:** Original colorful nomadic/Asian; no licensed ornaments.
- **Git:** Do not create a nested `.git` under `nomad-game`.
- **MVP first:** No shop, Ranked, Quick Match, Stick Pull playable, chat, Redis, microservices, K8s.
- **GSD workflow:** This file is planner input; do not implement outside the phase plans.

No project skills (`SKILL.md`) exist under `.cursor/skills/` or `.agents/skills/`.

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Flutter SDK | **3.47.x** / Dart **3.13.x** | Client | Phase 1–2 lock; load via `scripts/dev-env.ps1` [VERIFIED: scripts/dev-env.ps1 + pubspec] |
| Flame | **1.38.2** | Table + keyframe interpolation | Already pinned [VERIFIED: client/pubspec.yaml] |
| forge2d / flame_forge2d | **0.14.2** / **0.19.3+7** | Local preview only | Phase 1 NDK fallback; do not bump [VERIFIED: pubspec + STATE.md] |
| JDK | **21.0.11** (Corretto) | Backend | Available after `dev-env.ps1` (`JAVA_HOME` `~/.jdks/corretto-21.0.11`) [VERIFIED: toolchain] |
| Spring Boot | **4.1.1** | Modular monolith | Project lock [VERIFIED: backend/pom.xml] |
| Spring Modulith | **2.1.1** | `ApplicationModules.verify()` | Must go green this phase [CITED: docs.spring.io/spring-modulith/reference/verification.html] |
| dyn4j | **6.0.0** | Authority burst | Harness module; do not replace [VERIFIED: harness] |
| PostgreSQL | **18.6** | Rooms + match rows | No Redis [CITED: STACK.md] |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `spring-boot-starter-websocket` | BOM **4.1.1** | Raw `WebSocketHandler` | Add now. Official Boot 4.1 module for MVC WS. **Do not** add `@EnableWebSocketMessageBroker` / SockJS [CITED: docs.spring.io/spring-boot/4.1/reference/messaging/websockets.html] |
| `web_socket_channel` | **3.0.3** | Client match socket | Official Dart team (`tools.dart.dev`). STACK pin. `WebSocketChannel.connect` + `await ready` [CITED: pub.dev/packages/web_socket_channel] |
| `share_plus` | **13.3.0** | System share sheet (D-28) | Official Flutter Community. `SharePlus.instance.share(ShareParams(text:))`. Requires Flutter ≥3.38.1 [CITED: pub.dev/packages/share_plus] |
| Flutter `Clipboard` | SDK | Copy code (D-28) | `services.Clipboard.setData` — no extra pub |
| `flutter_secure_storage` | **11.0.0** (already) | Reconnect token beside refresh | Extend `SessionStore`; do not put token in SharedPreferences [VERIFIED: session_store.dart] |
| `go_router` | **18.0.1** (already) | `/lobby`, `/join`, private match | Deep links later [VERIFIED: router.dart] |
| `dio` / `flutter_riverpod` | **5.11.1** / **3.4.3** | REST rooms + state | Already in use |
| JUnit + `ThrowAuthorityIT` pattern | Boot BOM | Room / leave / rematch / reconnect ITs | Follow existing `@SpringBootTest` + MockMvc |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Raw `TextWebSocketHandler` | STOMP + SockJS | **Rejected (D-38).** Official Spring docs treat STOMP as an optional sub-protocol for pub/sub. Fights JSON game frames + reconnect tokens. |
| Spring `MatchSession` | Colyseus / Nakama product | **Rejected (D-38 / STACK).** Steal seat-hold + token + snapshot only. |
| `share_plus` | `share` (deprecated) or intent-only Android | Old `Share.share()` is deprecated. Use `SharePlus.instance`. |
| Query-string access JWT | One-time WS ticket | Ticket wins: access JWT in query leaks via logs/proxies. Ticket TTL 60s (STACK). |
| SUMMARY 60s + bot-fill | D-41/D-42 30s + remaining-player win | **Rejected.** ROADMAP/SESS-02 override research proposal. |
| One shared saka | Two rim sakas (D-37) | Bot path stays one `saka` id so golden/harness stay green. |

**Installation:**

```bash
# client (from client/)
flutter pub add web_socket_channel:3.0.3
flutter pub add share_plus:13.3.0

# backend: add to pom.xml (BOM-managed, no version)
# org.springframework.boot:spring-boot-starter-websocket
```

**Version verification (this session):**
- `web_socket_channel` **3.0.3** on pub.dev, publisher `tools.dart.dev` [CITED: pub.dev/packages/web_socket_channel]
- `share_plus` **13.3.0** on pub.dev, publisher `fluttercommunity.dev` [CITED: pub.dev/packages/share_plus]
- `spring-boot-starter-websocket` exists for Boot **4.1.x** [CITED: docs.spring.io/spring-boot/4.1/reference/messaging/websockets.html + Maven Central]
- npm `package-legitimacy` on these Dart names returns `SLOP` / does-not-exist — **ignore that verdict**; they are not npm packages. Verified on **pub.dev official pages**, not the npm seam.

## Package Legitimacy Audit

| Package | Registry | Age | Downloads | Source Repo | Verdict | Disposition |
|---------|----------|-----|-----------|-------------|---------|-------------|
| `web_socket_channel` | pub.dev (`tools.dart.dev`) | years (3.0.3 listed) | high (Dart team) | dart-lang | OK (pub.dev official) | Approved |
| `share_plus` | pub.dev (`fluttercommunity.dev`) | years (13.3.0, 45 days ago) | high | fluttercommunity | OK (pub.dev official) | Approved |
| `spring-boot-starter-websocket` | Maven Central (Spring BOM) | years | n/a (BOM) | spring-projects/spring-boot | OK | Approved |

**Packages removed due to [SLOP] verdict:** none (npm seam false-negative on Dart names).
**Packages flagged as suspicious [SUS]:** none.

*Do not add Colyseus, Nakama, SockJS, stompjs, or Redis clients.*

## Architecture Patterns

### System Architecture Diagram

```
Catalog (Create room | Join by code | Play Alchiki+chips)
    | REST
    v
matchmaking (rooms)
    create/join/ready/leave-lobby / 10min TTL / host-alive
    both Ready ──► session.createPrivateMatch(host, joiner, NORMAL)
                         |
                         | heap MatchSession (seats, tokens, clocks, WS)
                         v
                    GameEngine (SPI in session)
                         |
                         v
                    games.alchiki (implements SPI only)
                         Dyn4jBurstSim + AlchikiRules + ScriptedBot
                         |
    REST: rematch accept, consented leave, ws-ticket, rejoin
    WS:  ThrowInput / ThrowResolved / RejoinSnapshot / Ping
                         |
                         v
                    Postgres: rooms, matches (seats + winner), outcomes
```

### Recommended Project Structure

```
backend/src/main/java/com/nomadgames/
├── identity/                 # unchanged guest JWT
├── catalog/                  # unchanged
├── matchmaking/              # NEW: RoomService, RoomController, code gen
│   └── internal/             # RoomEntity, RoomRepository
├── session/                  # GameEngine SPI, MatchSession, raw WS, reconnect
│   ├── GameEngine.java       # expand: bot turn, resolve, private spawn
│   ├── MatchStatus.java      # MOVE HERE from games.alchiki
│   └── internal/             # MatchEntity seats, WsHandler, ReconnectPolicy
└── games/alchiki/            # implements GameEngine only
    ├── AlchikiEngine.java
    ├── AlchikiRules.java     # stay; session must not import
    └── internal/ScriptedBot.java

client/lib/
├── catalog/catalog_page.dart # + Create room / Join by code
├── platform/
│   ├── router.dart           # /lobby /join /match
│   ├── api/nomad_api.dart    # rooms + rematch + leave + ticket
│   ├── session/match_socket.dart  # NEW: one WebSocketChannel
│   └── auth/session_store.dart    # + reconnectToken
└── games/alchiki/
    ├── match_page.dart       # bot REST vs human WS
    ├── match_game.dart       # two SakaBody when private
    └── pause_overlay.dart    # rematch CTAs + reconnect banner
```

### Pattern 1: Break the Modulith cycle (Wave 0, mandatory)

**What:** Official Modulith `verify()` forbids cycles and `internal/` access [CITED: docs.spring.io/spring-modulith/reference/verification.html]. Named interfaces do **not** fix a cycle — invert the dependency.

**When to use:** Before any two-player type is added.

**Do this:**
1. Move `MatchStatus` into `session` (settlement is a session concern). Add `HOST_WIN`, `JOINER_WIN`. Keep `PLAYER_WIN` / `BOT_WIN` / `DRAW` for the bot path.
2. Expand `GameEngine` so `MatchService` never imports `AlchikiRules`, `MatchStatus` (games copy), or `ScriptedBot`:
   - `start(difficulty)` — bot bones (unchanged)
   - `startPrivate()` — NORMAL 6 bones + saka ids `saka-host`, `saka-joiner`
   - `applyThrow(...)` — existing bot/single-saka
   - `applyThrow(..., throwingSakaId, parkedSakaIds)` — private
   - `nextBotThrow(difficulty, seed, remaining)` — returns `ThrowInput` + scored view (moves `ScriptedBot` call into `AlchikiEngine`)
   - `resolve(ScoreClock, Instant)` — returns session `MatchStatus`
3. `games` → `session` (implements SPI) is the **only** allowed direction. `session` → `games` types: **zero**.
4. Do **not** mark `games` `OPEN`. Do **not** whitelist `games.alchiki.internal`.

`ModularityTest` must pass on the same `ApplicationModules.of(NomadGamesApplication.class).verify()` already in tree.

### Pattern 2: Rooms in `matchmaking`, live play in `session`

**What:** ARCHITECTURE.md already assigned room codes to `matchmaking` and seats/WS to `session`. Phase 5 queues will land in `matchmaking` — create the module now so lobby TTL does not bloat `MatchService`.

**REST (D-38):**

| Method | Path | Result |
|--------|------|--------|
| POST | `/v1/rooms` | `{ roomId, code, hostLabel, idleExpiresAt }` — guests allowed |
| POST | `/v1/rooms/join` `{ code }` | lobby snapshot **or** 404 no-such / 409 started / 410 host-left |
| GET | `/v1/rooms/{id}` | lobby (labels, ready flags, code for host) |
| POST | `/v1/rooms/{id}/ready` | `{ bothReady, matchId?, wsTicket? }` — start only when both ready |
| POST | `/v1/rooms/{id}/leave` | host leave **closes** code immediately; joiner leave clears seat, code lives |

**Code:** 5 characters from `ABCDEFGHJKLMNPQRSTUVWXYZ23456789` (32 glyphs, no 0/O/1/I). `32^5 ≈ 33.5M`. Unique index + retry on collision. Accept 4–6 on join (trim/uppercase). [ASSUMED: 5-char length is the planner default inside D-40.]

**Labels:** `Guest-` + last 4 hex chars of `playerId` with hyphens stripped (D-33).

**Idle TTL:** `idle_expires_at = created_at + 10 minutes` (D-29). 1 Hz housekeeping closes `LOBBY` rows past TTL.

### Pattern 3: Colyseus/Nakama seat hold — implemented in Spring

Steal only these official behaviors [CITED: docs.colyseus.io/room/reconnection; heroiclabs.com/docs/nakama/concepts/multiplayer/authoritative/]:

| Pattern | Nomad mapping |
|---------|----------------|
| `onDrop` + `allowReconnection(30)` | Unexpected WS close → hold seat 30s (D-41) |
| Do not remove player in `onDrop` | Seat stays; opponent sees reconnecting + **server** timer |
| Consented leave ≠ drop | REST `/leave` or WS close code `4000` → 0s grace, immediate loss |
| Rotating `reconnectionToken` | Opaque 32 bytes; SHA-256 stored; bound `playerId+matchId`; rotate on use |
| Full snapshot on rejoin | `RejoinSnapshot` — never a delta from a dead client |
| Auto vs manual | Auto-retry while isolate lives; after process death show **Rejoin** |
| Nakama `MatchJoinAttempt` | Rejoin REST checks token + grace; reject if expired or wrong player |

**On private grace expiry (D-42):** remaining player wins (`HOST_WIN` or `JOINER_WIN`). No bot-fill.

**Clock pause (D-41):** on drop, store remaining `turn` / `match` / `hardCap` durations. Housekeeping must **not** expire those Instants while the seat is in grace. On rejoin, rewrite deadlines as `now + remaining`. Consented leave does not pause.

MiniTon official guide (~20s reconnect, server timer, forfeit ≠ abort, pause clocks on turn-based drop) agrees with D-41’s 30s product choice [CITED: docs.miniton.games aborted-matches-and-forfeits]. Do **not** implement MiniTon’s aggregate pause budget this phase (SESS-03).

### Pattern 4: Raw WebSocket (official Spring)

```java
@Configuration
@EnableWebSocket
public class MatchWebSocketConfig implements WebSocketConfigurer {
    @Override
    public void registerWebSocketHandlers(WebSocketHandlerRegistry registry) {
        registry.addHandler(matchHandler, "/v1/matches/{matchId}/ws")
                .addInterceptors(ticketInterceptor)
                .setAllowedOriginPatterns("*"); // Flutter has no browser same-origin
        // Do NOT call .withSockJS()
    }
}
```

Handler extends `TextWebSocketHandler`. Wrap sessions with `ConcurrentWebSocketSessionDecorator` — official Spring: JSR-356 forbids concurrent sends [CITED: docs.spring.io/spring-framework/reference/web/websocket/server.html].

**Auth:** REST `POST /v1/matches/{id}/ws-ticket` (Bearer JWT) returns a **one-time 60s** ticket. Handshake reads `?ticket=`. Reject missing/expired/wrong-match tickets. Do not put the 15-min access JWT in the query string.

**SecurityConfig:** permit the WS handshake path (ticket is the credential) **or** authenticate the handshake after ticket lookup. Keep all room/match REST on Bearer JWT.

**Frames (JSON, one `type` field):**

Client → server: `ThrowInput` (existing schema), `Ping`.
Server → client: `ThrowResolved`, `RejoinSnapshot`, `Ping`/`Pong`, plus `OpponentDropped` / `OpponentRejoined` / `MatchSettled` / `Error` (needed for HUD; still D-38 family).

Bot matches **stay on REST**. Do not force the bot path onto WS.

### Pattern 5: Two sakas without breaking the bot harness

`Dyn4jBurstSim` and `AlchikiMatchGame` spawn one body id `saka` at `(0, -1.15)`. T-02-15 caps bodies at **8**. PRIVATE is always NORMAL (6 bones) + 2 sakas = **8** — fits.

- **BOT:** unchanged `saka` id; golden / `BurstSimTest` stay green.
- **PRIVATE:** spawn `saka-host` and `saka-joiner` on the south rim, e.g. `(-0.25,-1.12)` and `(0.25,-1.12)`. Impulse only `throwingSakaId`. Score still ignores sakas (only target bones).
- Client: two `SakaBody` with different fills (keep `#FFF6D6` for you; opponent a second PRES-02 color, e.g. ice `#7EB6D9` or fire `#C43C2C` — UI-SPEC). Only the current owner’s saka accepts aim/hold.

### Pattern 6: Rematch and leave

**Bot (D-43):** Result overlay gains **Play again** → existing `NomadApi.startMatch`. No dual accept. No new room.

**Private (D-43):** After `HOST_WIN`/`JOINER_WIN`/`DRAW`, both see **Again?** with a **server 10s** window. `POST /v1/matches/{id}/rematch`. Both accept → `session` creates a **new** matchId, same seats, joiner throws first. One reject or timeout → both catalog.

**Leave (D-44):** Keep `LeaveConfirm`. `POST /v1/matches/{id}/leave`:
- mode `BOT` + `IN_PLAY` → `BOT_WIN` (Phase 2 behavior; keep `ThrowAuthorityIT` green)
- mode `PRIVATE` + `IN_PLAY` → opponent seat wins (`HOST_WIN` or `JOINER_WIN`)
- already terminal → return existing snapshot (02-09)

Drop/crash is **not** leave.

### Anti-Patterns to Avoid

- **STOMP tutorial default:** `@EnableWebSocketMessageBroker` + SockJS.
- **Ignore Modulith with `OPEN` / `internal`:** CONTEXT forbids papering the cycle.
- **`BOT_WIN` on a private row:** D-44.
- **Delete seat in `afterConnectionClosed`:** Colyseus `onDrop` must hold.
- **Token = `WebSocketSession.getId()`:** dies with the connection.
- **Delta rejoin / client rest poses.**
- **Clocks keep ticking in grace.**
- **SUMMARY 60s or bot-fill.**
- **Difficulty chips on Create room.**
- **Live opponent aim over WS.**
- **Deep links / QR / chat.**

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| System share sheet | Custom WhatsApp/Telegram URLs | `share_plus` `SharePlus.instance.share` | OS share UI; D-28 |
| Copy to clipboard | Extra pub | Flutter `Clipboard` | SDK |
| WS client | `dart:io` WebSocket only | `web_socket_channel` 3.0.3 | Cross-platform; STACK |
| Secure reconnect token | SharedPreferences | Existing `FlutterSecureStorage` | Same as refresh |
| Room uniqueness | In-memory set only | Postgres `UNIQUE(code)` + retry | Restart-safe |
| Cycle “fix” | `@ApplicationModule(OPEN)` on games | Expand `GameEngine` SPI | Official verify() |
| Concurrent WS send | Bare `session.sendMessage` | `ConcurrentWebSocketSessionDecorator` | Official Spring |

**Key insight:** The hard parts (reconnect, seats, authority) are already specified by Colyseus/Nakama **patterns** and Phase 2 scoring. The work is wiring those patterns onto Spring + the existing table — not inventing a netcode.

## Common Pitfalls

### Pitfall 1: Growing two-player types on a failing Modulith graph
**What goes wrong:** `ModularityTest` stays red; agents copy `ScriptedBot` into session.
**Why:** Cycle already exists (`MatchService` → games + `AlchikiEngine` → session).
**How to avoid:** Wave 0 SPI expansion first.
**Warning signs:** New imports of `com.nomadgames.games.alchiki` from `session`.

### Pitfall 2: One reconnect policy / delete-on-drop / token = transport
**What goes wrong:** Wi-Fi flip = instant loss or frozen board. Process death cannot rejoin.
**Why:** PITFALLS.md Pitfall 4; Colyseus tutorials copied without `onDrop` vs `onLeave`.
**How to avoid:** D-41/D-42 exactly. Persist token in secure storage; rotate; full snapshot.
**Warning signs:** `afterConnectionClosed` deletes the seat; single `reconnectSeconds` used for Stick Pull later.

### Pitfall 3: `BOT_WIN` on a human match
**What goes wrong:** Result overlay says “Bot wins” after a friend forfeits.
**Why:** `leaveMatch` is bot-oriented today.
**How to avoid:** Branch on `mode`. Add `HOST_WIN`/`JOINER_WIN`. Update `ResultOverlay` + i18n (`opponentWins`).
**Warning signs:** Private `matches.status = BOT_WIN`.

### Pitfall 4: Clocks eat the 20s during grace
**What goes wrong:** Blip → turn forfeit → feels like a cheat.
**Why:** `tickClocks` compares `Instant.now()` to stored deadlines.
**How to avoid:** Freeze remaining durations while seat is `DISCONNECTED`.
**Warning signs:** `turnDeadline` still in the past after a 5s drop.

### Pitfall 5: Same-origin WS block + JWT in query
**What goes wrong:** Flutter handshake 403; tokens appear in access logs.
**Why:** Spring default allowed origin is same-origin [CITED: Spring WebSocket Allowed Origins].
**How to avoid:** `setAllowedOriginPatterns("*")` for the match handler; ticket query param only.
**Warning signs:** Handshake works in curl-with-Origin localhost, fails on device.

### Pitfall 6: Two-saka spawn breaks bot goldens
**What goes wrong:** `BurstSimTest` / seed-1 drift.
**How to avoid:** Private spawn is a **new** method. `simulate(input, remaining)` stays one `saka`.
**Warning signs:** Changing `IDS = {"saka", ...}` globally.

### Pitfall 7: Client-trusted rooms (PITFALLS 9)
**What goes wrong:** Joiner starts the match; client picks winner.
**How to avoid:** Ready + start + scores only on server. Inputs-only WS.

### Pitfall 8: Host leave leaves a zombie code
**What goes wrong:** Joiner sits in a dead lobby (D-29).
**How to avoid:** Host lobby leave → status `CLOSED`, unique code released or marked dead. Join returns **host left**.

## Code Examples

### Raw Spring handler registration
```java
// Source: https://docs.spring.io/spring-framework/reference/web/websocket/server.html
@Configuration
@EnableWebSocket
public class WebSocketConfiguration implements WebSocketConfigurer {
    @Override
    public void registerWebSocketHandlers(WebSocketHandlerRegistry registry) {
        registry.addHandler(myHandler(), "/myHandler")
                .addInterceptors(new HttpSessionHandshakeInterceptor());
    }
}
```
Use a **ticket** interceptor, not `HttpSessionHandshakeInterceptor` (we are stateless JWT).

### Flutter socket
```dart
// Source: https://pub.dev/packages/web_socket_channel
final channel = WebSocketChannel.connect(wsUrl);
await channel.ready;
channel.stream.listen((message) { /* parse type */ });
channel.sink.add(jsonEncode({'type': 'Ping', 't': DateTime.now().millisecondsSinceEpoch}));
```

### Share + copy
```dart
// Source: https://pub.dev/packages/share_plus
await SharePlus.instance.share(ShareParams(text: 'Nomad Alchiki code: $code'));
await Clipboard.setData(ClipboardData(text: code));
```

### Colyseus mapping (do not add the SDK)
```
onDrop     → MatchSession.markDropped(playerId) + start 30s grace
onReconnect→ apply RejoinSnapshot + rotate token
onLeave    → consented or grace-expired settlement
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| SUMMARY Phase 3 = empty GameEngine only; rooms in later “Phase 5” | ROADMAP collapsed rooms + rematch + 30s reconnect into Phase 3 | ROADMAP 2026-09-05 | Plan rooms **and** WS **and** rematch here |
| Casual reconnect 60s + bot-fill | **30s** + remaining player wins | D-41 / D-42 / SESS-02 | Do not implement SUMMARY table |
| REST-only bot loop | Keep REST for bot; WS for private in-play | D-24 then D-38 | Do not migrate bot throws to WS |
| Single `player_id` match + `BOT_WIN` leave | Seats + `HOST_WIN`/`JOINER_WIN` | This phase | Flyway `V3__rooms_and_seats.sql` |
| Colyseus 0.17 auto-reconnect SDK | Steal pattern; implement with `web_socket_channel` | D-38 | No Colyseus dependency |

**Deprecated/outdated:**
- `Share.share()` — use `SharePlus.instance.share` [CITED: pub.dev/packages/share_plus]
- STOMP-as-“Spring WebSocket” — optional sub-protocol, not this game [CITED: docs.spring.io/spring-framework/reference/web/websocket.html]
- Architecture research 60s casual / 120s empty lobby — overridden by D-29 (10 min lobby) and D-41 (30s play)

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Default room code length is **5** (inside 4–6) | Pattern 2 | Planner may pick 4 or 6; alphabet still holds |
| A2 | Opponent saka color `#7EB6D9` (ice) is acceptable until UI-SPEC | Pattern 5 | UI-SPEC may pick Fire/Gold pair instead |
| A3 | Server restart mid-match drops the heap session (no physics resume from Postgres) | Pattern 3 | Acceptable for one-JVM MVP; document in UAT |
| A4 | WS path `/v1/matches/{matchId}/ws` | Pattern 4 | Planner may flatten to `/v1/ws` + matchId in ticket |
| A5 | Extra HUD frames `OpponentDropped` / `MatchSettled` are in-scope as D-38 family | Pattern 4 | If planner is strict, piggyback on `RejoinSnapshot` + REST poll |

**If this table is empty:** — not empty; A1–A5 are discretion, not product reopens.

## Open Questions (RESOLVED)

1. **Exact lobby chrome (sheet vs `/lobby` route)**
   - What we know: both CTAs must exist (D-26). Discretion allows either.
   - Recommendation: dedicated `/lobby` and `/join` routes — easier tests and how-to skip.
   - RESOLVED: 03-02 implements `/lobby` after Create room and a `/join` placeholder; 03-03 fills `/join`. No sheet.

2. **Whether inactive saka is a physics body or decoration**
   - What we know: D-37 says parked on the rim.
   - Recommendation: real dyn4j/Forge2D body so a throw can hit it; scoring still bones-only. Bot harness untouched.
   - RESOLVED: 03-05 `simulatePrivate` spawns real `saka-host` and `saka-joiner` bodies; impulse applies only to throwingSakaId; pocketing ignores saka ids.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| JDK 21 | Backend tests / run | ✓ after `scripts/dev-env.ps1` | 21.0.11 Corretto | Script sets `JAVA_HOME` |
| Flutter 3.47 | Client tests | ✓ after `dev-env.ps1` (`~/develop/flutter`) | 3.47.x | Not on raw PATH |
| Maven Wrapper | `.\mvnw.cmd -pl backend -am` | ✓ **repo root** (not `backend/`) | 3.9.11 | Do not require global `mvn` |
| Docker | Testcontainers / Compose Postgres | ✓ | 29.7.2 | ITs already use Testcontainers |
| Redis | — | n/a | — | **Do not add** |
| `spring-boot-starter-websocket` | Match WS | ✗ not in pom | add BOM | Wave 0 install |
| `web_socket_channel` / `share_plus` | Client WS + share | ✗ not in pubspec | 3.0.3 / 13.3.0 | Wave 0 `flutter pub add` |
| Context7 MCP | Docs seam | ✗ this runtime | — | Official WebFetch used |

**Missing dependencies with no fallback:** none if Wave 0 adds the three artifacts above.

**Missing dependencies with fallback:** Context7 → official URLs already fetched.

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Flutter `flutter_test` + JUnit Jupiter (Spring Boot 4.1 BOM) + existing Testcontainers ITs |
| Config file | `client/analysis_options.yaml`; repo-root `pom.xml` aggregator (`-pl backend -am`) |
| Quick run command | `. ./scripts/dev-env.ps1; .\mvnw.cmd -pl backend -am test -Dtest=ModularityTest,AlchikiRulesTest; Set-Location client; flutter test test/catalog_test.dart` |
| Full suite command | `. ./scripts/dev-env.ps1; .\mvnw.cmd -pl harness,backend -am verify` + `Set-Location client; flutter test` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| MODE-01 | Create room returns 4–6 code | integration | `.\mvnw.cmd -pl backend -am test -Dtest=RoomIT#createReturnsCode` | ❌ Wave 0 |
| MODE-02 | Join by code; errors keep field | integration + widget | `RoomIT#join*` + `flutter test test/join_code_test.dart` | ❌ Wave 0 |
| MODE-02 | Host leave kills code; 10 min TTL | integration | `RoomIT#hostLeaveCloses` / `#idleTtlCloses` | ❌ Wave 0 |
| D-27 | Both Ready then start; joiner first | integration | `RoomIT#bothReadyStartsJoinerTurn` | ❌ Wave 0 |
| MODE-05 | Bot Play again one-tap | widget | `flutter test test/rematch_overlay_test.dart` | ❌ Wave 0 |
| MODE-05 | Private 10s dual accept / timeout | integration | `.\mvnw.cmd -pl backend -am test -Dtest=RematchIT` | ❌ Wave 0 |
| SESS-02 | 30s hold + full snapshot; clocks paused | integration | `.\mvnw.cmd -pl backend -am test -Dtest=ReconnectIT` | ❌ Wave 0 |
| SESS-02 | Token rotate; reject reuse / expiry | integration | `ReconnectIT#tokenRotateAndExpire` | ❌ Wave 0 |
| SESS-05 | Leave vs bot → `BOT_WIN` | integration | existing `ThrowAuthorityIT` leave cases | ✅ |
| SESS-05 | Leave vs human → opponent win, not `BOT_WIN` | integration | `ThrowAuthorityIT` or `LeaveIT#privateLeaveOpponentWins` | ❌ Wave 0 |
| SESS-01 carry | Forged score on WS/REST ignored | integration | extend `ThrowAuthorityIT#forgedClientScoreIsIgnoredOnThrow` | ✅ extend |
| Modulith | `games ↔ session` acyclic | unit | `.\mvnw.cmd -pl backend -am test -Dtest=ModularityTest` | ✅ (currently red) |
| PRES-01 | New EN/RU keys | widget | `catalog_test` + arb compile | ⚠️ extend ARB |
| D-26 | Catalog still has Play Alchiki + chips + two new CTAs | widget | extend `test/catalog_test.dart` | ✅ extend |

### Sampling Rate

- **Per task commit:** touched tree (`flutter test test/<file>.dart` and/or `-Dtest=Class#method`)
- **Per wave merge:** `ModularityTest` + Room/Reconnect/Leave ITs + `catalog_test` / rematch overlay
- **Phase gate:** Full suite green + owner UAT: create → join → both Ready → throw → drop/rejoin 30s → rematch → leave

### Wave 0 Gaps

- [ ] `ModularityTest` green — `GameEngine` SPI expansion; `MatchStatus` in `session`; no `session` → `games` imports
- [ ] `backend/.../RoomIT.java` — MODE-01/02, host-alive, TTL, both-Ready, joiner-first
- [ ] `backend/.../ReconnectIT.java` — 30s snapshot, clock pause, token rotate, grace expiry win
- [ ] `backend/.../RematchIT.java` — 10s dual accept / timeout
- [ ] `backend/.../LeaveIT.java` or extend `ThrowAuthorityIT` — private leave ≠ `BOT_WIN`
- [ ] `client/test/join_code_test.dart` — error copy, field remains
- [ ] `client/test/rematch_overlay_test.dart` — bot Play again vs private Again?
- [ ] Flyway `V3__rooms_and_seats.sql`
- [ ] `spring-boot-starter-websocket` in `backend/pom.xml`
- [ ] `web_socket_channel` 3.0.3 + `share_plus` 13.3.0 in `client/pubspec.yaml`
- [ ] ARB keys: createRoom, joinByCode, noSuchRoom, alreadyStarted, hostLeft, ready, rematchAgain, playAgain, reconnecting, opponentWins, copy, share

Existing tests that must stay green: `ThrowAuthorityIT`, `CatalogIT`, `GuestIdentityIT`, `AlchikiRulesTest`, `ScriptedBotTest`, `catalog_test.dart`, `bot_turn_test.dart`, `howto_test.dart`, harness `BurstSimTest`.

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | yes | Existing guest JWT; WS **ticket** (60s, one-time), not query access JWT |
| V3 Session Management | yes | Rotating reconnect token hashed SHA-256; bound `playerId+matchId`; secure storage |
| V4 Access Control | yes | Seat membership, not Phase 2 `requireOwner` alone; non-seat → 403; turn check on every `ThrowInput` |
| V5 Input Validation | yes | Room code charset + length; `ThrowInput.parse` ignores score-like keys (Phase 2) |
| V6 Cryptography | yes | Existing HS256 + SHA-256; **never** hand-roll a new hash |

### Known Threat Patterns for REST + raw WS parlor

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Forged score / rest poses | Tampering | Inputs only; dyn4j scores (SESS-01) |
| Join another player’s match WS | Elevation | Ticket + seat bind; reject wrong `matchId` |
| Reconnect token reuse / theft | Spoofing | Rotate on use; hash at rest; grace expiry |
| Room-code spray | Information / DoS | 5-char 32-glyph space; in-process join rate limit per IP/`playerId` (same style as guest 20/min) |
| Consented leave as “crash” | Repudiation | Distinct REST leave vs WS drop; 0s vs 30s |
| `BOT_WIN` on human row | Tampering / UX lie | D-44 statuses |
| Host-alive bypass | Tampering | Server closes code; client cannot keep lobby |
| Concurrent WS write crash | Denial | `ConcurrentWebSocketSessionDecorator` |
| Live aim leak | Information | D-34: no angle on the wire until `ThrowResolved` |

Phase 2 T-02-16 (“no socket package”) is **superseded** for private in-play only; bot throws stay REST.

## Sources

### Primary (HIGH confidence — official pages; seam transport may be LOW)

- https://docs.spring.io/spring-framework/reference/web/websocket.html — raw WS vs STOMP/SockJS
- https://docs.spring.io/spring-framework/reference/web/websocket/server.html — `TextWebSocketHandler`, `HandshakeInterceptor`, `ConcurrentWebSocketSessionDecorator`, allowed origins
- https://docs.spring.io/spring-boot/4.1/reference/messaging/websockets.html — `spring-boot-starter-websocket`
- https://docs.spring.io/spring-modulith/reference/verification.html — no cycles, no internal access
- https://docs.colyseus.io/room/reconnection — seat hold, rotating token, full snapshot, consented ≠ drop
- https://heroiclabs.com/docs/nakama/concepts/multiplayer/authoritative/ — seat reserve on disconnect, explicit rejoin
- https://docs.miniton.games/developer-success/miniton-developer-documentation/aborted-matches-and-forfeits — forfeit ≠ abort; server timer; pause turn-based clocks
- https://pub.dev/packages/web_socket_channel — **3.0.3**, `tools.dart.dev`
- https://pub.dev/packages/share_plus — **13.3.0**, `SharePlus.instance.share`
- Existing code: `MatchService`, `MatchController`, `AlchikiEngine`, `catalog_page.dart`, `pause_overlay.dart`, Flyway V1/V2

### Secondary (MEDIUM confidence)

- JetBrains Modulith migration guide (2026-02) — extract shared types / invert deps to break cycles
- FEATURES.md parlor room-code + rematch 10s (product defaults locked by D-*)
- ARCHITECTURE.md `MatchSession` + `GameEngine` plugin (still the target; reconnect seconds overridden)

### Tertiary (LOW confidence)

- Context7 MCP unavailable; `gsd-tools classify-confidence --provider webfetch --verified` = LOW
- npm legitimacy on Dart package names = false `SLOP` — discarded
- Clash-Royale-class timers — unused

## Metadata

**Confidence breakdown:**
- Standard stack: **HIGH** — pins already in repo; new artifacts from official Spring/pub.dev
- Architecture: **HIGH** — CONTEXT locks D-26–D-44; cycle fix is forced by Modulith docs + current imports
- Pitfalls: **HIGH** — mapped to existing PITFALLS.md + live `leaveMatch` / single-saka / failing `ModularityTest`

**Research date:** 2026-09-07
**Valid until:** 30 days (stable Spring/Flutter pins; reconnect seconds are product-locked)

---
*Phase: 3-Private Rooms + Casual Reconnect*
*Researched: 2026-09-07*
