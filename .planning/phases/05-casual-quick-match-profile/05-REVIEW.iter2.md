---
phase: 05-casual-quick-match-profile
reviewed: 2026-09-11T11:50:00Z
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
  critical: 1
  warning: 3
  info: 3
  total: 7
status: issues_found
---

# Phase 5: Code Review Report

**Reviewed:** 2026-09-11T11:50:00Z
**Depth:** standard
**Files Reviewed:** 38
**Status:** issues_found

## Summary

Phase 5 casual queue, rematch, and profile surfaces were reviewed adversarially at standard depth. Profile allow-listing, self-JWT controllers, SoftElo/XP settlement idempotency, and client rematch-wait wiring look sound. The highest-impact defect is sticky `MATCHED` queue tickets that never clear after a finished casual match, which breaks subsequent Quick Match for both players until an explicit DELETE (which the happy path never issues).

## Critical Issues

### CR-01: MATCHED queue tickets never clear after pairing

**File:** `backend/src/main/java/com/nomadgames/matchmaking/CasualQueueService.java:36-39`
**Issue:** On enqueue, any existing ticket is returned as-is. After a successful pair, both players keep `MATCHED` entries in `tickets` indefinitely. Client happy paths (`SearchingPage` / `FallbackPage` `_goCasualMatch`, catalog Quick Match) navigate into the match **without** `dequeueCasual`. After the match leaves `IN_PLAY`, `hasInPlayHumanSeat` no longer blocks, so a second Quick Match returns the stale `MATCHED` + old `matchId`. Searching immediately re-enters the finished match; players cannot start a new casual game without a manual DELETE they never see.
**Fix:** Treat terminal/stale matches as clearable on enqueue (and optionally clear both tickets when the match is created or settles):

```java
Ticket existing = tickets.get(playerId);
if (existing != null) {
    if ("SEARCHING".equals(existing.status())) {
        return toResponse(existing);
    }
    if ("MATCHED".equals(existing.status())
            && existing.matchId() != null
            && matches.hasInPlayHumanSeat(playerId)) {
        return toResponse(existing);
    }
    tickets.remove(playerId); // stale MATCHED — allow re-queue
}
```

Also clear both players’ tickets once `createCasualMatch` succeeds (or when both have observed MATCHED / match becomes terminal), and add an IT: pair → finish/leave → enqueue again → expect `SEARCHING` or a **new** `matchId`.

## Warnings

### WR-01: Client-controlled `X-Forwarded-For` bypasses join rate limit

**File:** `backend/src/main/java/com/nomadgames/matchmaking/CasualMatchmakingController.java:51-56`
**Issue:** `clientIp` prefers the first `X-Forwarded-For` hop unconditionally. Any client can rotate spoofed values and dilute the IP half of `JoinRateLimiter` (player-id half still applies, but shared NAT / multi-device abuse is easier). Same pattern is high-risk if this limiter is the only DoS control for casual enqueue (T-05-01).
**Fix:** Trust forwarded headers only behind a known proxy (`server.forward-headers-strategy` / Spring `ForwardedHeaderFilter` with trusted proxies), otherwise use `request.getRemoteAddr()` only:

```java
private static String clientIp(HttpServletRequest request) {
    return request.getRemoteAddr();
}
```

### WR-02: Settlement claim can orphan XP/Elo if player row vanishes mid-loop

**File:** `backend/src/main/java/com/nomadgames/profile/ProfileService.java:108-116`
**Issue:** `claimSettlement` inserts the idempotency row **before** `lockPlayer`. If the player row is missing (`lockPlayer` empty), the claim still sticks (`allClaimed` becomes false for Elo), so a later retry will not grant XP and will permanently skip casual Elo for that match.
**Fix:** Lock (or verify) the player first; only `claimSettlement` after a successful lock, or delete/compensate the claim when lock fails inside the same TX:

```java
PlayerProfileRow locked = jdbc.lockPlayer(seat.playerId()).orElse(null);
if (locked == null) {
    allClaimed = false;
    continue;
}
if (!jdbc.claimSettlement(matchId, seat.playerId())) {
    allClaimed = false;
    continue;
}
// then apply XP / stats using locked
```

### WR-03: How-to → casual match drops URI encoding for `matchId`

**File:** `client/lib/howto/alchiki_howto_page.dart:100-102`
**Issue:** Searching/fallback encode `matchId` with `Uri.encodeQueryComponent`; how-to forwards the raw value. UUIDs work today, but any future id format with reserved query characters will break the casual resume path (regression class already hit once in 05-03 when casual `matchId` was dropped).
**Fix:**

```dart
context.go(
  '/match?mode=${Uri.encodeQueryComponent(widget.mode!)}'
  '&matchId=${Uri.encodeQueryComponent(widget.matchId!)}',
);
```

## Info

### IN-01: Empty `IllegalArgumentException` handler body

**File:** `backend/src/main/java/com/nomadgames/matchmaking/CasualMatchmakingController.java:43-45`
**Issue:** Bad JWT subjects (`UUID.fromString`) map to HTTP 400 with an empty body, which is harder for clients/ops to diagnose than a small problem detail.
**Fix:** Return a tiny JSON/`ProblemDetail` message (e.g. `"invalid player id"`).

### IN-02: In-process FIFO is single-instance only

**File:** `backend/src/main/java/com/nomadgames/matchmaking/CasualQueueService.java:18-20`
**Issue:** Queue state lives in JVM heap (explicit plan choice: no Redis). Multi-instance deploy will split queues / fail to pair across nodes. Acceptable for current milestone; document as an ops constraint before horizontal scale.
**Fix:** Keep as-is for MVP; track sticky-session or shared queue before multi-replica prod.

### IN-03: Guest subtitle uses last 4 hex of player UUID

**File:** `backend/src/main/java/com/nomadgames/profile/ProfileService.java:142-145`
**Issue:** `Guest-XXXX` collides whenever two UUIDs share a suffix; cosmetic only (PROF display), not authz.
**Fix:** Use a denser unique fragment or server-assigned display code if collisions become visible in UX.

---

_Reviewed: 2026-09-11T11:50:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
