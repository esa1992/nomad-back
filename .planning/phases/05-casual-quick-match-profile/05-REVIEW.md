---
phase: 05-casual-quick-match-profile
reviewed: 2026-09-14T04:35:00Z
depth: standard
files_reviewed: 38
files_reviewed_list:
  - backend/src/main/java/com/nomadgames/economy/EconomyService.java
  - backend/src/main/java/com/nomadgames/economy/MatchRewardCommand.java
  - backend/src/main/java/com/nomadgames/economy/MatchRewardTable.java
  - backend/src/main/java/com/nomadgames/identity/GuestService.java
  - backend/src/main/java/com/nomadgames/matchmaking/CasualMatchmakingController.java
  - backend/src/main/java/com/nomadgames/matchmaking/CasualQueueResponse.java
  - backend/src/main/java/com/nomadgames/matchmaking/CasualQueueService.java
  - backend/src/main/java/com/nomadgames/matchmaking/internal/JoinRateLimiter.java
  - backend/src/main/java/com/nomadgames/profile/internal/ProfileJdbc.java
  - backend/src/main/java/com/nomadgames/profile/ProfileController.java
  - backend/src/main/java/com/nomadgames/profile/ProfileService.java
  - backend/src/main/java/com/nomadgames/profile/SoftElo.java
  - backend/src/main/java/com/nomadgames/session/internal/MatchEntity.java
  - backend/src/main/java/com/nomadgames/session/internal/MatchRepository.java
  - backend/src/main/java/com/nomadgames/session/MatchService.java
  - backend/src/main/resources/db/migration/V9__profile_casual.sql
  - client/lib/catalog/avatar_chip.dart
  - client/lib/catalog/catalog_models.dart
  - client/lib/catalog/catalog_page.dart
  - client/lib/games/alchiki/match_game.dart
  - client/lib/games/alchiki/match_page.dart
  - client/lib/games/alchiki/pause_overlay.dart
  - client/lib/games/alchiki/rematch_waiting_page.dart
  - client/lib/howto/alchiki_howto_page.dart
  - client/lib/l10n/app_en.arb
  - client/lib/l10n/app_ru.arb
  - client/lib/matchmaking/fallback_page.dart
  - client/lib/matchmaking/searching_page.dart
  - client/lib/platform/api/nomad_api.dart
  - client/lib/platform/router.dart
  - client/lib/profile/avatar_assets.dart
  - client/lib/profile/profile_page.dart
  - client/pubspec.yaml
  - backend/src/test/java/com/nomadgames/matchmaking/CasualQueueIT.java
  - backend/src/test/java/com/nomadgames/profile/ProfileIT.java
  - client/test/matchmaking_test.dart
  - client/test/profile_page_test.dart
  - client/test/catalog_test.dart
findings:
  critical: 0
  warning: 0
  info: 3
  total: 3
status: clean
---

# Phase 5: Code Review Report

**Reviewed:** 2026-09-14T04:35:00Z
**Depth:** standard
**Files Reviewed:** 38
**Status:** clean

## Summary

Iteration-2 re-review after code-review fixes (`327423d`, `aad6c50`, `e827f95`, `9eb068b`). All prior Critical/Warning findings are **closed** and verified in source; no regressions found in the fix commits. Remaining items are Info-only (intentionally unfixed from iter1) — status is **clean** for the auto-loop.

### Prior findings — closure verification

| ID | Status | Evidence |
|----|--------|----------|
| CR-01 | **closed** | `CasualQueueService.enqueue` keeps SEARCHING; keeps MATCHED only while `hasInPlayHumanSeat`; otherwise removes stale ticket. IT `reEnqueueAfterMatchEndsClearsStaleMatched` asserts SEARCHING then a new `matchId`. |
| WR-01 | **closed** | `CasualMatchmakingController.clientIp` returns only `request.getRemoteAddr()`; no `X-Forwarded-For`. |
| WR-02 | **closed** | `ProfileService.recordSettlement` calls `lockPlayer` before `claimSettlement`; missing player skips without inserting a claim. |
| WR-03 | **closed** | `alchiki_howto_page.dart` encodes `mode` and `matchId` with `Uri.encodeQueryComponent`. |

## Narrative Findings (AI reviewer)

No Critical or Warning findings remain.

## Info

### IN-01: Empty `IllegalArgumentException` handler body

**File:** `backend/src/main/java/com/nomadgames/matchmaking/CasualMatchmakingController.java:43-45`
**Issue:** Bad JWT subjects (`UUID.fromString`) map to HTTP 400 with an empty body (intentionally unfixed).
**Fix:** Return a tiny JSON/`ProblemDetail` message (e.g. `"invalid player id"`).

### IN-02: In-process FIFO is single-instance only

**File:** `backend/src/main/java/com/nomadgames/matchmaking/CasualQueueService.java:18-20`
**Issue:** Queue state lives in JVM heap (explicit plan choice: no Redis). Multi-instance deploy will split queues / fail to pair across nodes (intentionally unfixed).
**Fix:** Keep as-is for MVP; track sticky-session or shared queue before multi-replica prod.

### IN-03: Guest subtitle uses last 4 hex of player UUID

**File:** `backend/src/main/java/com/nomadgames/profile/ProfileService.java:144-147`
**Issue:** `Guest-XXXX` collides whenever two UUIDs share a suffix; cosmetic only (PROF display), not authz (intentionally unfixed).
**Fix:** Use a denser unique fragment or server-assigned display code if collisions become visible in UX.

---

_Reviewed: 2026-09-14T04:35:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
_Iteration: 2 (post-fix re-review)_
