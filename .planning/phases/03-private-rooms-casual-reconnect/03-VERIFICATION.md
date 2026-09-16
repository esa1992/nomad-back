---
phase: 03-private-rooms-casual-reconnect
verified: 2026-09-08T11:30:00Z
status: passed
score: 8/8 must-haves verified
behavior_unverified: 0
overrides_applied: 0
re_verification:
  previous_status: gaps_found
  previous_score: 7/8
  gaps_closed:
    - "After a brief disconnect in Casual Alchiki the player can rejoin within 30 seconds and resume from a full server snapshot"
  gaps_remaining: []
  regressions: []
deferred:
  - truth: "After casual (Quick Match) matches the player can accept Rematch within a short window (MODE-05 casual half)"
    addressed_in: "Phase 5"
    evidence: "Phase 5 success criterion 2: 'After casual matches the rematch window from Phase 3 still works'. Casual Quick Match is MODE-03 / Phase 5; not in this phase's shipped surface."
---

# Phase 3: Private Rooms + Casual Reconnect Verification Report

**Phase Goal:** Two players can start an authoritative Alchiki match from a short room code, rematch, rejoin after a brief drop, or leave and forfeit
**Verified:** 2026-09-08T11:30:00Z
**Status:** passed
**Re-verification:** Yes — after gap-closure plan 03-14 (prior 03-11..03-13). Previous remaining gap was SESS-02 isolate-alive 409 seat-not-dropped treated as grace expiry.
**Mode:** mvp (ROADMAP goal is outcome-form, not `As a …, I want to …, so that ….`. PLAN files restate a valid user story. Verification proceeds against that user story plus ROADMAP success criteria. ROADMAP Phase 3 checkbox `[x]` and REQUIREMENTS.md Complete/Gaps-found checkmarks are **not** evidence.)

Code review `03-REVIEW.md` (after 03-14) was treated as hypotheses. CR-01 is closed in source. CR-02, CR-05, and WR-05 remain warnings: they do not falsify a living IN_PLAY SESS-02 resume.

End-of-phase two-device UAT is a later orchestrator step (`human_verify_mode = end-of-phase`). It is not a remaining must-have gap.

## User Flow Coverage

User story: «As a guest, I want to start an authoritative Alchiki match from a short room code, rematch, rejoin after a brief drop, or leave and forfeit, so that I can play a friend without Quick Match, Ranked, or a bot sitting in their seat.»

| Step | Expected | Evidence | Status |
|------|----------|----------|--------|
| Create room | Catalog Create room yields a 4–6 character code | `RoomService.create` 5-char alphabet; `CatalogPage._createRoom` POSTs `/v1/rooms` then `/lobby?roomId=` | ✓ |
| Share / join | Friend enters the code; errors keep the field | `JoinPage` keeps `TextEditingController`; 404/409/410 stay on `/join`; share text is code-only | ✓ |
| Both Ready | Match starts; joiner throws first; no bot in a seat | `findByIdForUpdate` / `findByCodeForUpdate` + `@Version`; `kickoffIfBothReady` only while `matchId == null`; `RoomIT#concurrentBothReadyCreatesOneMatch` exists | ✓ |
| Play | Authoritative throws on raw WS; two sakas | Ticket handshake + `applyPrivateThrow` wired. Private clocks never forfeit on the server (CR-02 warning) | ⚠️ |
| Leave | Pause confirm ends the match immediately as opponent win | REST `leaveMatch` writes HOST_WIN/JOINER_WIN. Client never closes WS with 4000; failed POST still `_goCatalog()` (CR-05 warning) | ✓ happy path |
| Rematch | Bot Play again; private both accept in 10s, same two seats, new matchId | Bot `_playAgain` wired. `acceptRematch` `synchronized(window)` create-once; `RematchIT#concurrentBothAcceptCreatesOneMatch` exists | ✓ |
| Rejoin | Brief drop: resume within 30s from full snapshot | Overlay POSTs `/rejoin`. Isolate-alive: only 410 is expiry; 409 + GET `IN_PLAY` keeps token and tickets a new socket; handshake `clearSeatDrop` after `registry.add` | ✓ |
| Outcome | Play a friend without Quick Match, Ranked, or a bot in a seat | No QM/Ranked in this phase. Kickoff and rematch are create-once. Living-client blip rejoin no longer maps 409 to expiry | ✓ |

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | ------- | ---------- | -------------- |
| 1 | Player can create a private room and receive a short 4–6 character join code; another player can join by entering that code | ✓ VERIFIED | Regression: `V3__rooms.sql` UNIQUE code. `RoomService` alphabet length 5, 4–6 accepted on join. Catalog Create room / Join by code CTAs unchanged. Join errors keep `_code`. Share is code-only. Concurrent join `findByCodeForUpdate`; second guest 409. |
| 2 | When both Ready, the server creates a PRIVATE NORMAL match and the joiner is to throw first | ✓ VERIFIED | Regression: `findByIdForUpdate` / `findByCodeForUpdate` `PESSIMISTIC_WRITE`. `RoomEntity` `@Version` + `V6__room_version.sql`. `kickoffIfBothReady` only when both flags, `joinerId` set, and `matchId == null`. Turn JOINER, difficulty NORMAL. `RoomIT#concurrentBothReadyCreatesOneMatch` exists. |
| 3 | After a bot or private match the player can accept Rematch within a short window | ✓ VERIFIED | Regression: Bot `_playAgain` → `startMatch`. Private: `acceptRematch` `synchronized(window)`; if `newMatchId != null` return it; create only when both accepted and id still null. `RematchIT#concurrentBothAcceptCreatesOneMatch` exists. Casual rematch deferred to Phase 5. |
| 4 | After a brief disconnect in Casual Alchiki the player can rejoin within 30 seconds and resume from a full server snapshot | ✓ VERIFIED | **03-14 closed the remaining gap in source.** `_rejoinMatch` maps only HTTP 410 to `_onGraceExpiredDropped`; 409 calls `_resumeAfterRejoinConflict` which GETs the stored match. Terminal statuses apply the snapshot; `IN_PLAY` does not `clearReconnect` and `_attachPrivateSocket` mints `wsTicket` then `MatchSocket.connect`. `_reconnectPrivateSocket` captures `lost` before `_rejoinMatch` and returns success only when `_socket != null && !identical(_socket, lost) && !_rejoinError`. `MatchService.rejoin` still 409 when `graceDeadline == null` (correct); client no longer treats that as expiry. `clearSeatDrop` after `registry.add` unfreezes that `playerId` without rotating the token. Named widget test `isolate-alive first rejoin 409 keeps token then tickets and hides Rejoin match` **PASS** (this verifier). Overlay remaining-12 and always-200 isolate-alive also PASS. `ReconnectIT#handshakeClearsSeatGrace` exists (ticket connect without POST rejoin; `reconnectSecondsLeft` JSON null; status stays `IN_PLAY`). WR-05 overlay 409 `match settled` keeps Rejoin up — already-settled match, not a living IN_PLAY seat. |
| 5 | Consented leave/forfeit ends the match immediately as a loss | ✓ VERIFIED | Regression: `leaveMatch` on PRIVATE IN_PLAY writes `JOINER_WIN`/`HOST_WIN` immediately, `clearDrops`, broadcasts `MatchSettled`. Already-terminal returns existing snapshot. Pause uses `leaveBodyPrivate`. WS close 4000 still unused by `MatchSocket.close()` (WARNING CR-05). |
| 6 | Leave vs human never writes BOT_WIN on a PRIVATE row; leave vs bot still records BOT_WIN | ✓ VERIFIED | Regression: `leaveMatch` branches on `PRIVATE`. `LeaveIT#privateLeaveOpponentWins` exists. Bot path still `BOT_WIN`. Client parser still defaults missing leave status to `BOT_WIN` (WR-02). |
| 7 | Private in-play throws travel on a raw JSON WebSocket with a one-time 60s ticket; bot matches stay on REST | ✓ VERIFIED | Regression: `/v1/matches/{matchId}/ws` + `WsTicketInterceptor`; tickets hashed, TTL 60s. Handler `ThrowInput`/`Ping` → `applyPrivateThrow`. Bot path still `submitThrow`. `issueWsTicket` is `requireSeat` + PRIVATE only — works while not dropped, which is what the 409 ticket-then-connect path needs. |
| 8 | Process-death Rejoin overlay + token/matchId/localSeat in FlutterSecureStorage; cold start routes to `/match?mode=private&matchId=` | ✓ VERIFIED | `SessionStore.persistReconnect` unchanged. Splash routes when token+matchId exist. `RejoinOverlay` has Rejoin match only. Overlay boot GETs match and seeds `_rejoinSecondsAtShow` from `reconnectSecondsLeft` clamped 0..30 (WR-01: GET failure / null still falls back to 30). Isolate-alive hides overlay and now completes rejoin on 409 IN_PLAY. |

**Score:** 8/8 truths verified (0 present, behavior-unverified)

ROADMAP `[x]` and REQUIREMENTS.md Phase-3 Complete/Gaps-found checkmarks were treated as claims, not evidence. REQUIREMENTS.md still lists SESS-02 as `Gaps found` in the mapping table; that row is stale relative to this source check.

### Gap closure (03-14) — previous FAILED truth, full 3-level check

| Check | Status | Evidence |
| ----- | ------ | -------- |
| Only HTTP 410 is grace-gone | ✓ VERIFIED | `match_page.dart` `_rejoinMatch` `on NomadApiException`: `statusCode == 410` → `_onGraceExpiredDropped`; `409` → `_resumeAfterRejoinConflict`. 409 is not in the expiry branch. |
| Isolate-alive 409 + GET match IN_PLAY keeps token, retries or tickets | ✓ VERIFIED | `_resumeAfterRejoinConflict` GETs `api.getMatch(matchId)`. Terminal statuses apply snapshot and return (no `clearReconnect`). `IN_PLAY` calls `_attachPrivateSocket` (wsTicket + connect). GET throw sets `_rejoinError`, does not invent HOST_WIN/JOINER_WIN. Widget test `_FirstRejoinConflictApi` first rejoin 409, then `reconnectToken` still non-null, `wsTicket` after `rejoin`, `Rejoin match` absent — **PASS**. |
| Retry loop does not succeed on the dead MatchSocket | ✓ VERIFIED | `_reconnectPrivateSocket` `final MatchSocket? lost = _socket` then `if (_socket != null && !identical(_socket, lost) && !_rejoinError) return`. Dead socket + false `_rejoinError` continues the 8×400ms loop unless unmounted / leave / rematch / terminal / overlay. |
| Handshake `registry.add` then `clearSeatDrop(playerId)` | ✓ VERIFIED | `MatchWebSocketHandler.afterConnectionEstablished`: `registry.add(matchId, safe)` then `matches.clearSeatDrop(playerId, matchId)` inside `ResponseStatusException` catch. `clearSeatDrop` nulls only that seat's grace, unfreezes if last drop, does not rotate token. `MatchController` has no REST mapping for it. `ReconnectIT#handshakeClearsSeatGrace` exists. |

### Deferred Items

| # | Item | Addressed In | Evidence |
|---|------|-------------|----------|
| 1 | MODE-05 rematch after Casual Quick Match | Phase 5 | Phase 5 SC: "After casual matches the rematch window from Phase 3 still works" |

### Required Artifacts

| Artifact | Expected | Status | Details |
| -------- | ----------- | ------ | ------- |
| `backend/src/main/java/com/nomadgames/session/MatchStatus.java` | HOST_WIN / JOINER_WIN | ✓ VERIFIED | Enum includes IN_PLAY, PLAYER_WIN, BOT_WIN, DRAW, HOST_WIN, JOINER_WIN |
| `backend/src/main/java/com/nomadgames/session/GameEngine.java` | SPI; `startPrivate` / `nextBotThrow` | ✓ VERIFIED | Session does not import `games.alchiki`; `AlchikiEngine implements GameEngine` |
| `backend/src/main/java/com/nomadgames/session/MatchService.java` | Private match, leave, rematch, rejoin, WS throw, clearSeatDrop | ✓ VERIFIED (clocks still warning) | `rejoin` 409 seat-not-dropped is correct. `clearSeatDrop` present, no REST. `applyPrivateThrow` still never `forfeitThrowIfExpired`; `tickClocks` only handles `PLAYER` (CR-02) |
| `backend/src/main/resources/db/migration/V3__rooms.sql` | Unique code | ✓ VERIFIED | `code VARCHAR(6) NOT NULL UNIQUE` |
| `backend/src/main/resources/db/migration/V6__room_version.sql` | rooms.version | ✓ VERIFIED | `ALTER TABLE rooms ADD COLUMN version BIGINT NOT NULL DEFAULT 0` |
| `backend/src/main/java/com/nomadgames/matchmaking/RoomController.java` | POST `/v1/rooms`, `/join` | ✓ VERIFIED | Create, join, get, ready, leave |
| `backend/src/main/java/com/nomadgames/matchmaking/RoomService.java` | Locked Ready + idle close | ✓ VERIFIED | ForUpdate join/ready/leave; create-once kickoff; per-row idle closer |
| `backend/src/main/java/com/nomadgames/matchmaking/internal/RoomRepository.java` | PESSIMISTIC_WRITE finders | ✓ VERIFIED | `findByIdForUpdate` / `findByCodeForUpdate` |
| `backend/src/main/java/com/nomadgames/matchmaking/internal/RoomEntity.java` | @Version | ✓ VERIFIED | `long version` |
| `backend/src/main/resources/db/migration/V4__match_seats.sql` | host_id / joiner_id | ✓ VERIFIED | Columns added |
| `backend/src/main/java/com/nomadgames/session/MatchWebSocketConfig.java` | Raw WS + origins | ✓ VERIFIED | `setAllowedOriginPatterns("*")` + interceptor |
| `backend/src/main/java/com/nomadgames/session/internal/WsTicketService.java` | 60s one-time tickets | ✓ VERIFIED | `TTL = 60s`; consume removes |
| `backend/src/main/java/com/nomadgames/session/internal/ReconnectPolicy.java` | 30s grace | ✓ VERIFIED | `GRACE_SECONDS = 30` |
| `backend/src/main/resources/db/migration/V5__reconnect_tokens.sql` | Token hashes | ✓ VERIFIED | host/joiner `reconnect_token_hash` |
| `backend/src/main/java/com/nomadgames/session/internal/MatchSessionRegistry.java` | One socket per seat | ✓ VERIFIED | `add` replaces by `ATTR_PLAYER_ID`; `hasOpenSeat` |
| `backend/src/main/java/com/nomadgames/session/internal/MatchWebSocketHandler.java` | Handshake add then clearSeatDrop | ✓ VERIFIED | `afterConnectionEstablished` add then `clearSeatDrop`; close 4000 → leave; else `markDropped` unless `hasOpenSeat` |
| `backend/src/main/java/com/nomadgames/session/MatchSnapshot.java` | reconnectSecondsLeft | ✓ VERIFIED | Trailing `Integer reconnectSecondsLeft` |
| `backend/src/test/java/com/nomadgames/session/ReconnectIT.java` | Snapshot, rotate, handshake clear | ✓ VERIFIED (exists) | Includes `handshakeClearsSeatGrace`. ITs not re-run (Testcontainers) |
| `backend/src/test/java/com/nomadgames/session/RematchIT.java` | Dual accept concurrent | ✓ VERIFIED (exists) | `concurrentBothAcceptCreatesOneMatch` |
| `backend/src/test/java/com/nomadgames/matchmaking/RoomIT.java` | Concurrent Ready/join | ✓ VERIFIED (exists) | `concurrentBothReadyCreatesOneMatch`, `concurrentJoinSeatsOneJoiner` |
| `backend/src/test/java/com/nomadgames/session/LeaveIT.java` | Private opponent wins | ✓ VERIFIED (exists) | `privateLeaveOpponentWins` |
| `client/lib/catalog/catalog_page.dart` | Create room / Join by code | ✓ VERIFIED | Separate CTAs; join is `context.go('/join')` |
| `client/lib/rooms/lobby_page.dart` | Code Display 28, Share, Copy, Ready | ✓ VERIFIED | Unchanged |
| `client/lib/rooms/join_page.dart` | Errors keep field | ✓ VERIFIED | Controller retained |
| `client/lib/platform/session/match_socket.dart` | Single WS channel | ⚠️ PARTIAL | Connect/send wired. `close()` uses default code — never 4000 |
| `client/lib/games/alchiki/match_page.dart` | Seat HUD, WS, rematch, rejoin 409 | ✓ VERIFIED | 410-only expiry; 409 IN_PLAY tickets; socket identity retry |
| `client/test/reconnect_overlay_test.dart` | Isolate-alive 409 keeps token | ✓ VERIFIED | `_FirstRejoinConflictApi`; named test PASS this run |
| `client/lib/platform/auth/session_store.dart` | Secure reconnect bundle | ✓ VERIFIED | FlutterSecureStorage keys beside refresh |
| `client/lib/platform/splash_page.dart` | Cold-start Rejoin route | ✓ VERIFIED | token+matchId → `/match?mode=private&matchId=` |
| `client/lib/games/alchiki/pause_overlay.dart` | Play again / Again? / Rejoin / leaveBodyPrivate | ✓ VERIFIED | Rejoin overlay has no Back to catalog |
| `client/pubspec.yaml` | web_socket_channel 3.0.3 | ✓ VERIFIED | Pinned |
| `harness/.../Dyn4jBurstSim.java` | saka-host / saka-joiner | ✓ VERIFIED | `simulatePrivate` present |

`gsd-tools query verify.artifacts` / `verify.key-links` on 03-14-PLAN.md failed to parse YAML lists (0 items). Artifacts and links above were checked in source.

### Key Link Verification

| From | To | Via | Status | Details |
| ---- | --- | ---- | ------ | ------- |
| `catalog_page.dart` | `nomad_api.dart` | `createRoom` | WIRED | POST `/v1/rooms` then `/lobby?roomId=` |
| `join_page.dart` | `nomad_api.dart` | `joinRoom` | WIRED | POST `/v1/rooms/join` then lobby |
| `RoomService` | `MatchService` | `createPrivateMatch` | WIRED | Called only while both ready and `matchId` null, under row lock |
| `MatchWebSocketHandler` | `MatchService` | `applyPrivateThrow` | WIRED | ThrowInput JSON → session apply |
| `MatchWebSocketConfig` | `WsTicketInterceptor` | `addInterceptors` | WIRED | Ticket query param, not JWT |
| `match_page.dart` | `match_socket.dart` | `wsTicket` + `MatchSocket.connect` | WIRED | Start, rematch, overlay rejoin, isolate-alive 200 and 409 IN_PLAY |
| `match_page.dart` | `MatchService.rejoin` | `NomadApi.rejoin` | WIRED | Isolate-alive and overlay both POST `/rejoin`. 409 IN_PLAY no longer expiry |
| `match_page.dart` | `nomad_api.dart` | `_resumeAfterRejoinConflict` → `getMatch` | WIRED | 409 path GETs stored matchId before ticket-connect |
| `MatchWebSocketHandler` | `MatchService.clearSeatDrop` | `afterConnectionEstablished` after `registry.add` | WIRED | `ATTR_PLAYER_ID`; catch `ResponseStatusException`; no REST |
| `MatchWebSocketHandler` | `ReconnectPolicy` | `markDropped` on non-4000 close | WIRED | Close 4000 → `leaveMatch`; other → `markDropped` unless `hasOpenSeat` |
| `match_page.dart` | `leaveMatch` | Pause confirm POST `/leave` | WIRED | REST leave. Socket not closed with 4000 |
| `pause_overlay.dart` | `nomad_api.dart` | `rematch` / `startMatch` | WIRED | Bot Play again vs private Again? |
| `MatchService.acceptRematch` | `MatchSessionRegistry` | `synchronized(window)` | WIRED | Create-once `newMatchId` |
| `splash_page.dart` | `match_page.dart` | `mode=private` + matchId | WIRED | Cold start overlay |
| `GET /v1/matches/{id}` | overlay countdown | `reconnectSecondsLeft` | WIRED | `remainingGraceSeconds` cap 30; overlay `?? 30` fallback |
| `AlchikiEngine` | `GameEngine` | `implements GameEngine` | WIRED | Only GameEngine `@Component` |
| `MatchService` | `GameEngine` | `engine.nextBotThrow` / `start` / `resolve` | WIRED | No `AlchikiRules` / `ScriptedBot` imports in session |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| -------- | ------------- | ------ | ------------------ | ------ |
| Host lobby code | `room.code` | `RoomService.randomCode` persisted | Yes, unique 5-char | ✓ FLOWING |
| Join lobby | `RoomLobbyResponse` | `findByCodeForUpdate` + joiner_id | Yes; concurrent join one seat | ✓ FLOWING |
| Kickoff matchId | `room.matchId` | `createPrivateMatch` after both Ready under lock | One PRIVATE NORMAL row | ✓ FLOWING |
| Private throw result | `ThrowResolved.match` | `applyPrivateThrow` + Dyn4jBurstSim | Yes | ✓ FLOWING |
| Rematch newMatchId | `window.newMatchId` | `createPrivateMatch` inside `synchronized(window)` | At most one row | ✓ FLOWING |
| Overlay rejoin snapshot | `RejoinSnapshot` | `MatchService.rejoin` lastThrow + sakaPoses | Yes when overlay POSTs after drop | ✓ FLOWING |
| Isolate-alive resume | grace + token + new socket | `_reconnectPrivateSocket` → `_rejoinMatch`; 409 → GET IN_PLAY → `_attachPrivateSocket`; handshake `clearSeatDrop` | Token kept; new ticket socket; seat unfrozen | ✓ FLOWING |
| Rejoin overlay timer | `_rejoinSecondsAtShow` | GET `reconnectSecondsLeft` clamped 0..30 | Server remaining on success; invents 30 on GET fail/null | ⚠️ STATIC fallback |
| Opponent reconnecting HUD | `_opponentSecondsAtDrop` | WS `OpponentDropped.secondsLeft` | Server 30 on drop frame | ✓ FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| -------- | ------- | ------ | ------ |
| Isolate-alive first rejoin 409 keeps token then tickets | `flutter test test/reconnect_overlay_test.dart` | 8 tests, all passed, including named 409 case (11s) | ✓ PASS |
| Isolate-alive always-200 rejoin then wsTicket | same file | PASS this run | ✓ PASS |
| Overlay remaining-12 from `reconnectSecondsLeft` | same file | PASS this run | ✓ PASS |
| Concurrent both-Ready one match | `RoomIT#concurrentBothReadyCreatesOneMatch` | Method exists. Not re-run (Testcontainers) | ? SKIP (existence) |
| Concurrent rematch one matchId | `RematchIT#concurrentBothAcceptCreatesOneMatch` | Method exists. Not re-run | ? SKIP (existence) |
| Handshake clears seat grace | `ReconnectIT#handshakeClearsSeatGrace` | Method exists (ticket without POST rejoin, `reconnectSecondsLeft` null, stays IN_PLAY). Not re-run | ? SKIP (existence) |
| Orchestrator-reported regression | Flutter phase 1–2; ThrowAuthorityIT, CatalogIT, GuestIdentityIT, AlchikiRulesTest, ScriptedBotTest, ModularityTest | Prior run, not this verifier | n/a |

Step 7b: Ran the full `reconnect_overlay_test.dart` file once (8 tests). Did not start Testcontainers. Named 409 isolate-alive test is the behavioral evidence for truth 4.

### Probe Execution

| Probe | Command | Result | Status |
| ----- | ------- | ------ | ------ |
| — | No `scripts/*/tests/probe-*.sh`; PLAN/SUMMARY do not declare probes | — | SKIPPED |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
| ----------- | ---------- | ----------- | ------ | -------- |
| MODE-01 | 03-02, 03-05, 03-06 | Create private room, 4–6 character join code | ✓ SATISFIED | Create + unique code + lobby share/copy + private table |
| MODE-02 | 03-03, 03-04, 03-05, 03-06, 03-11 | Another player joins by code | ✓ SATISFIED | Join-by-code + locked both-Ready kickoff + concurrent join one seat |
| MODE-05 | 03-08, 03-12 | Rematch after bot, private, and casual | ✓ SATISFIED (bot + private); casual deferred | Bot Play again. Private 10s window create-once. Casual half → Phase 5 |
| SESS-02 | 03-09, 03-10, 03-13, 03-14 | Rejoin within 30s from full snapshot | ✓ SATISFIED | Server snapshot/rotate/expiry, overlay POST, isolate-alive POST, 410-only expiry, 409 IN_PLAY ticket-connect, handshake `clearSeatDrop`. Widget 409 test PASS |
| SESS-05 | 03-01, 03-07 | Consented leave ends immediately (loss) | ✓ SATISFIED | PRIVATE → remaining-seat win; 0s grace on REST leave. WS 4000 unused (warning) |

Orphaned REQUIREMENTS.md IDs mapped to Phase 3 but missing from plans: **none**. All five IDs appear in PLAN `requirements:` blocks.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| ---- | ---- | ------- | -------- | ------ |
| `backend/.../MatchService.java` | 243–301 | Private clocks never forfeit | ⚠️ Warning | `applyPrivateThrow` skips `forfeitThrowIfExpired`; `tickClocks` ignores HOST/JOINER. Table can deadlock until Leave (CR-02). Not a listed SC. Out of 03-14 by design |
| `client/lib/platform/session/match_socket.dart` | 107 | `sink.close()` default code | ⚠️ Warning | Consented leave is REST-only; failed POST + dispose = 30s drop (CR-05). Out of 03-14 by design |
| `client/lib/games/alchiki/match_page.dart` | 1198–1203 | `_goCatalog()` after leave catch | ⚠️ Warning | Failed REST leave still leaves the table; server may `markDropped` |
| `client/lib/games/alchiki/match_page.dart` | 652–658 | Overlay 409 match-settled keeps `_showRejoin` | ⚠️ Warning | WR-05: `ResultOverlay` gated on `_isTerminal && !_showRejoin`. Already-settled match, not living IN_PLAY resume. Isolate-alive `_showRejoin` is already false |
| `client/lib/games/alchiki/match_page.dart` | 398–406 | Overlay 30s fallback | ⚠️ Warning | GET fail / null `reconnectSecondsLeft` invents 30s (WR-01) |
| `client/lib/platform/api/nomad_api.dart` | leave parser | Default leave status `BOT_WIN` | ⚠️ Warning | D-44 footgun if a caller renders the snapshot |
| `backend/.../MatchWebSocketHandler.java` | 160–165 | All 409 → `not_your_turn` | ⚠️ Warning | Includes opponent reconnecting (WR-03) |
| Phase-modified sources | — | TBD / FIXME / XXX | none | No unreferenced debt markers in 03-14 files |

### CR-01 hypothesis (source check after 03-14)

**Does CR-01 still falsify SESS-02?** No.

1. `match_page.dart` `_rejoinMatch`: only `statusCode == 410` calls `_onGraceExpiredDropped`; `409` calls `_resumeAfterRejoinConflict`.
2. `_resumeAfterRejoinConflict`: GET match; terminal apply snapshot; `IN_PLAY` does not `clearReconnect`; GET failure sets `_rejoinError` and does not invent HOST_WIN/JOINER_WIN.
3. `_reconnectPrivateSocket`: captures `lost` before `_rejoinMatch`; success requires a different non-null `_socket` and `!_rejoinError`.
4. `MatchService.clearSeatDrop`: nulls that seat's grace, unfreezes if last drop, does not rotate token, no REST mapping.
5. `afterConnectionEstablished`: `registry.add` then `clearSeatDrop(ATTR_PLAYER_ID)` in `ResponseStatusException` catch.
6. This verifier ran `flutter test test/reconnect_overlay_test.dart`: named 409 isolate-alive test PASS.

CR-02 (private clocks) and CR-05 (no WS 4000) remain warnings. They do not fail a roadmap sentence.

WR-05 (overlay 409 match-settled keeps Rejoin) is overlay UX after the match is already not `IN_PLAY`. It does not falsify SESS-02 resume-from-snapshot for a living IN_PLAY seat. Isolate-alive is unaffected (`_showRejoin` already false).

### Confirmation-bias notes (not gaps)

- Widget 409 stub always returns GET `IN_PLAY`, so it does not lock WR-05. That is overlay-after-settled, not the failed truth.
- `MatchService.rejoin` still returns 409 when `graceDeadline == null`. That is the race the client now handles; it is not a remaining client expiry mapping.
- MODE-05 casual rematch remains deferred to Phase 5 (same as prior pass).

### Human Verification Required

None for this gate. Two-device table feel, process-death on a real device, and a live network blip remain end-of-phase UAT (later workflow step). No `<verify><human-check>` XML blocks in PLAN files.

### Gaps Summary

No remaining must-have gaps. Plans 03-11 and 03-12 previously closed concurrent Ready and dual rematch. 03-13 wired isolate-alive POST `/rejoin`. 03-14 closed the last FAILED truth in source: isolate-alive 409 while GET match is `IN_PLAY` keeps the rotating token and resumes via a new ws-ticket; only 410 is grace-gone; the retry loop cannot treat the dead `MatchSocket` as success; handshake after `registry.add` clears that seat's grace.

Do not treat CR-02 / CR-05 / WR-05 or Phase 5 casual rematch as covering a remaining SESS-02 hole. Do not mark the ROADMAP phase complete from this report (already checked in ROADMAP.md; that checkbox is not evidence).

---

_Verified: 2026-09-08T11:30:00Z_
_Verifier: Claude (gsd-verifier)_
