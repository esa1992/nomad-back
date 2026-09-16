---
phase: 06-stick-pull
reviewed: 2026-09-14T10:18:00Z
depth: standard
files_reviewed: 31
files_reviewed_list:
  - backend/src/main/java/com/nomadgames/games/stickpull/StickPullBot.java
  - backend/src/main/java/com/nomadgames/games/stickpull/StickPullConstants.java
  - backend/src/main/java/com/nomadgames/games/stickpull/StickPullPhase.java
  - backend/src/main/java/com/nomadgames/games/stickpull/StickPullRuntime.java
  - backend/src/main/java/com/nomadgames/games/stickpull/StickPullSim.java
  - backend/src/main/java/com/nomadgames/catalog/CatalogService.java
  - backend/src/main/java/com/nomadgames/matchmaking/CasualQueueService.java
  - backend/src/main/java/com/nomadgames/matchmaking/CreateRoomRequest.java
  - backend/src/main/java/com/nomadgames/matchmaking/EnqueueCasualRequest.java
  - backend/src/main/java/com/nomadgames/matchmaking/GameDiscriminator.java
  - backend/src/main/java/com/nomadgames/matchmaking/RoomService.java
  - backend/src/main/resources/db/migration/V10__rooms_game.sql
  - backend/src/main/java/com/nomadgames/session/MatchCreatedResponse.java
  - backend/src/main/java/com/nomadgames/session/MatchService.java
  - backend/src/main/java/com/nomadgames/session/internal/MatchWebSocketHandler.java
  - backend/src/main/java/com/nomadgames/session/internal/ReconnectPolicy.java
  - client/lib/catalog/catalog_models.dart
  - client/lib/catalog/catalog_page.dart
  - client/lib/games/alchiki/match_page.dart
  - client/lib/games/stick_pull/stick_pull_game.dart
  - client/lib/games/stick_pull/stick_pull_match_page.dart
  - client/lib/games/stick_pull/stick_pull_ws.dart
  - client/lib/howto/howto_seen_store.dart
  - client/lib/howto/stick_pull_howto_page.dart
  - client/lib/matchmaking/fallback_page.dart
  - client/lib/matchmaking/searching_page.dart
  - client/lib/platform/api/nomad_api.dart
  - client/lib/platform/auth/session_store.dart
  - client/lib/platform/router.dart
  - client/lib/platform/splash_page.dart
  - client/lib/rooms/lobby_page.dart
findings:
  critical: 0
  warning: 0
  info: 1
  total: 1
status: clean
---

# Phase 6: Code Review Report

**Reviewed:** 2026-09-14T10:18:00Z
**Depth:** standard
**Files Reviewed:** 31
**Status:** clean

## Narrative Findings (AI reviewer)

## Summary

Confirmation re-review after iter-3 CR-01 fix. Cold-start Stick Pull rejoin now persists and routes `game=stickPull`. All prior CR/WR from earlier iterations remain fixed. Status is **clean** (info-only).

### Focus: CR-01 cold-start rejoin (verified fixed)

| Check | Evidence |
|-------|----------|
| Persist game/mode | `SessionStore.persistReconnect` writes `reconnectGame` / `reconnectMode`; `clearReconnect`/`clear` delete both |
| Stick Pull write path | `stick_pull_match_page.dart` `_persistTicketReconnect` + post-rejoin persist: `game: 'STICK_PULL'`, `mode: widget.mode` |
| Alchiki write path | `match_page.dart` persists `game: 'ALCHIKI'` |
| Splash cold boot | `splash_page.dart` 80–86: `game == 'STICK_PULL' → '&game=stickPull'`, mode default `private` |
| Catalog cold boot | `catalog_page.dart` `_openStoredRejoin` 99–105: same query construction |
| Router | `router.dart` 86–91: `game == 'stickPull'` → `StickPullMatchPage` |

### Prior findings (verified still fixed)

| ID | Status |
|----|--------|
| CR-01 (iter3) cold-start omit `game=stickPull` | **Fixed** (SessionStore + splash + catalog + persist callers) |
| CR-01 (iter2) `liveDeadline` freeze | Fixed (`StickPullSim.pauseClock`/`resumeClock`; `MatchService` markDropped/rejoin/clearSeatDrop; runtime holds on `anyDropped` / clientPaused) |
| WR-01 (iter2) Bot Pause freeze | Fixed (`setStickPullClientPaused` → `StickPullRuntime.setClientPaused`) |
| WR-02 (iter2) `OpponentRejoined` stale seed | Fixed (`_opponentSecondsAtDrop = 0` at lines 421–425) |
| CR-01 HOST/JOINER settle | Fixed (`settleStickPullMatch` 227–232) |
| CR-02 `applyTap` + anyDropped | Fixed (`anyDropped` gate + LIVE tick freeze) |
| WR-01 forfeit tear-down | Fixed (`settleExpiredDrop` forceSettle + remove) |
| WR-02 synchronized(sim) | Fixed (`applyTap` / runtime `advance`) |
| WR-03 difficulty allowlist | Fixed (`requireStickPullDifficulty`) |
| WR-04 WS rate limit | Fixed (`TapRateLimiter`) |

## Critical Issues

None.

## Warnings

None.

## Info

### IN-01: `createMatch` game string not normalized

**File:** `backend/src/main/java/com/nomadgames/session/MatchService.java:90-96`

**Issue:** Rooms/casual use `GameDiscriminator.normalize`; bot `createMatch` still requires exact `STICK_PULL`/`ALCHIKI`. Fail-closed, inconsistent API. Client already sends exact `STICK_PULL`.

**Fix:** `String game = GameDiscriminator.normalize(request.game());` then branch (or a bot-specific allowlist).

---

_Reviewed: 2026-09-14T10:18:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
