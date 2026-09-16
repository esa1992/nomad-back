---
phase: 05-casual-quick-match-profile
fixed_at: 2026-09-14T03:35:00Z
review_path: .planning/phases/05-casual-quick-match-profile/05-REVIEW.md
iteration: 1
findings_in_scope: 4
fixed: 4
skipped: 0
status: all_fixed
---

# Phase 5: Code Review Fix Report

**Fixed at:** 2026-09-14T03:35:00Z
**Source review:** `.planning/phases/05-casual-quick-match-profile/05-REVIEW.md`
**Iteration:** 1

**Summary:**
- Findings in scope: 4
- Fixed: 4
- Skipped: 0

## Fixed Issues

### CR-01: MATCHED queue tickets never clear after pairing

**Files modified:** `backend/src/main/java/com/nomadgames/matchmaking/CasualQueueService.java`, `backend/src/test/java/com/nomadgames/matchmaking/CasualQueueIT.java`
**Commit:** `327423d`
**Applied fix:** On enqueue, keep `SEARCHING` tickets; keep `MATCHED` only while `hasInPlayHumanSeat`; otherwise remove the stale ticket and allow re-queue. Added IT `reEnqueueAfterMatchEndsClearsStaleMatched` (pair → leave → enqueue → `SEARCHING`, then peer enqueue → new `matchId`).

### WR-01: Client-controlled `X-Forwarded-For` bypasses join rate limit

**Files modified:** `backend/src/main/java/com/nomadgames/matchmaking/CasualMatchmakingController.java`
**Commit:** `aad6c50`
**Applied fix:** `clientIp` now returns only `request.getRemoteAddr()`; no longer reads `X-Forwarded-For`.

### WR-02: Settlement claim can orphan XP/Elo if player row vanishes mid-loop

**Files modified:** `backend/src/main/java/com/nomadgames/profile/ProfileService.java`
**Commit:** `e827f95`
**Status:** fixed: requires human verification
**Applied fix:** `lockPlayer` before `claimSettlement`; if lock fails, set `allClaimed = false` and skip without inserting an idempotency claim.

### WR-03: How-to → casual match drops URI encoding for `matchId`

**Files modified:** `client/lib/howto/alchiki_howto_page.dart`
**Commit:** `9eb068b`
**Applied fix:** Encode both `mode` and `matchId` with `Uri.encodeQueryComponent` on how-to → `/match` navigation.

---

_Fixed: 2026-09-14T03:35:00Z_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
