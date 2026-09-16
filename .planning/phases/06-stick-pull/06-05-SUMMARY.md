---
phase: 06-stick-pull
plan: 05
subsystem: session
tags: [stick-pull, reconnect, grace-seconds, skins, SESS-04, D-86, D-87]

requires:
  - phase: 06-stick-pull
    provides: Stick Pull private/casual matches + rooms.game (06-04); StickPullSim + match UI (06-03)
provides:
  - "ReconnectPolicy.graceSeconds(game): STICK_PULL=8s, Alchiki/default=30s"
  - "StickPullReconnectIT green — 8s forfeit without mid-tug bot-fill"
  - "Stick Pull client 8s reconnect banners + Rejoin; loadout shaft paint (D-83)"
affects:
  - Phase 7 ranked reconnect budgets
  - Stick Pull UAT / verify-work

tech-stack:
  added: []
  patterns:
    - "graceSeconds(String game) / graceDeadline(now, game) — broadcast OpponentDropped secondsLeft from grace"
    - "Client clamps Stick Pull reconnect display to 0..8; Alchiki stays 0..30"
    - "StickPullGame.shaftColorForLoadout at GameWidget create only (presentation, D-83/D-54)"

key-files:
  created: []
  modified:
    - backend/src/main/java/com/nomadgames/session/internal/ReconnectPolicy.java
    - backend/src/main/java/com/nomadgames/session/MatchService.java
    - backend/src/test/java/com/nomadgames/session/StickPullReconnectIT.java
    - backend/src/test/java/com/nomadgames/session/ReconnectIT.java
    - client/lib/games/stick_pull/stick_pull_match_page.dart
    - client/lib/games/stick_pull/stick_pull_game.dart
    - client/lib/l10n/app_en.arb
    - client/lib/l10n/app_ru.arb
    - client/lib/platform/router.dart

key-decisions:
  - "STICK_PULL grace is exactly 8s; ALCHIKI and null/unknown game keep GRACE_SECONDS=30"
  - "settleExpiredDrop unchanged — remaining human wins; never inject StickPullBot (T-06-02)"
  - "Stick Pull human result overlay omits dual-accept rematch chrome this plan — Back to catalog only on forfeit"

patterns-established:
  - "MatchService.markDropped and remainingGraceSeconds always pass match.getGame() into ReconnectPolicy"
  - "Stick Pull opponent grace: remaining seat disables tap zone + opponentReconnecting banner ≤8"

requirements-completed: [SESS-04, STICK-03, CAT-02]

coverage:
  - id: D1
    description: "Stick Pull OpponentDropped secondsLeft ∈ [1,8] and GET reconnectSecondsLeft ≤8"
    requirement: SESS-04
    verification:
      - kind: integration
        ref: "backend/.../StickPullReconnectIT.java#stickPullGraceIsEightSeconds"
        status: pass
    human_judgment: false
  - id: D2
    description: "Grace expiry forfeits remaining win without mid-tug bot-fill"
    requirement: SESS-04
    verification:
      - kind: integration
        ref: "backend/.../StickPullReconnectIT.java#graceExpiryForfeitsNoBotFill"
        status: pass
    human_judgment: false
  - id: D3
    description: "Alchiki / default reconnect grace still 30s after graceSeconds(game)"
    requirement: SESS-04
    verification:
      - kind: integration
        ref: "backend/.../StickPullReconnectIT.java#alchikiGraceStillThirty; ReconnectIT#getMatchExposesRemainingGrace"
        status: pass
    human_judgment: false
  - id: D4
    description: "Stick Pull client 8s reconnect chrome + loadout shaft paint; catalog/howto green"
    requirement: STICK-03
    verification:
      - kind: automated_ui
        ref: "client/test/catalog_test.dart; client/test/howto_stick_pull_test.dart"
        status: pass
    human_judgment: false
  - id: D5
    description: "Catalog Stick Pull tile still PLAYABLE (regression)"
    requirement: CAT-02
    verification:
      - kind: automated_ui
        ref: "client/test/catalog_test.dart#Stick Pull tile does not show Coming Soon"
        status: pass
    human_judgment: false

duration: 45min
completed: 2026-09-14
status: complete
---

# Phase 6 Plan 05: Stick Pull Reconnect + Skins Summary

**Game-aware reconnect: Stick Pull 8s forfeit without mid-tug bot-fill; Alchiki stays 30s; client waiting/Rejoin chrome clamps to 8s and paints loadout shaft at bout start.**

## Performance

- **Duration:** 45 min
- **Started:** 2026-09-14T07:36:00Z
- **Completed:** 2026-09-14T08:21:00Z
- **Tasks:** 2
- **Files modified:** 9

## Accomplishments

- `ReconnectPolicy.graceSeconds(game)` / `graceDeadline(now, game)` — STICK_PULL → 8, else 30; `MatchService.markDropped` broadcasts that value
- `StickPullReconnectIT` green (8s + no bot-fill); `ReconnectIT` Alchiki 30s still green
- Stick Pull match page: opponent reconnecting banner, tap disabled in grace, Rejoin ≤8s, shaft from `stick_pull` loadout SKU

## Task Commits

Each task was committed atomically:

1. **Task 1 RED: StickPullReconnectIT assertions** - `e60f76a` (test)
2. **Task 1 GREEN: game-aware 8s grace** - `3fc48b1` (feat)
3. **Task 2: Client 8s reconnect UI + skin paint** - `ede8196` (feat)

**Plan metadata:** `f237531` (docs: complete plan); `3c02d18` (docs: metrics/decisions)

## TDD Gate Compliance

- RED: `test(06-05): assert Stick Pull OpponentDropped secondsLeft in [1,8]` (`e60f76a`) — failed with secondsLeft=30 before implementation
- GREEN: `feat(06-05): game-aware 8s Stick Pull reconnect grace` (`3fc48b1`) — StickPullReconnectIT 3/3 + ReconnectIT 7/7 pass

## Files Created/Modified

- `backend/.../ReconnectPolicy.java` — `graceSeconds` / `graceDeadline(now, game)`
- `backend/.../MatchService.java` — markDropped + remainingGraceSeconds use game-aware grace
- `backend/.../StickPullReconnectIT.java` — SESS-04 proofs; joiner grace projection; no `botFilled` field
- `backend/.../ReconnectIT.java` — Alchiki 30s documentation lock
- `client/.../stick_pull_match_page.dart` — human reconnect path + banners + skins
- `client/.../stick_pull_game.dart` — `shaftColorForLoadout`, exhaust flash timer
- `client/lib/l10n/app_en.arb` / `app_ru.arb` (+ generated) — `opponentReconnecting`, `opponentDisconnected`, `staminaA11y`
- `client/lib/platform/router.dart` — pass `mode` into StickPullMatchPage

## Decisions Made

- Stick Pull human result uses Back-to-catalog only this plan (no dual-accept rematch chrome on Stick Pull overlay yet)
- Ice skin paints shaft `#7EB6D9`; default `#8B5A2B` — sim force untouched

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] StickPullReconnectIT stubs asserted non-existent API fields**
- **Found during:** Task 1 (RED)
- **Issue:** Room create has no `$.game`; MatchSnapshot has no `$.game` / `$.botFilled`; grace GET used host token (remaining seat) instead of dropped joiner
- **Fix:** Assert empty `bonesLeft` + PRIVATE IN_PLAY for Stick Pull setup; parse WS `secondsLeft`; GET with joiner token; assert `joinerId` + HOST_WIN for no bot-fill
- **Files modified:** `StickPullReconnectIT.java`, `ReconnectIT.java`
- **Verification:** RED failed on secondsLeft=30; GREEN StickPullReconnectIT 3/3
- **Committed in:** `e60f76a`

**2. [Rule 2 - Missing critical] Stick Pull match page had no human reconnect path**
- **Found during:** Task 2
- **Issue:** Page was bot-oriented; private/casual routes passed matchId but no OpponentDropped/Rejoin/8s clamp
- **Fix:** Wired mode, persist reconnect token, 8s banners, tap disable, Rejoin overlay, loadout shaft paint
- **Files modified:** `stick_pull_match_page.dart`, `stick_pull_game.dart`, `router.dart`, ARBs
- **Verification:** dart analyze clean on stick_pull; catalog/howto tests pass
- **Committed in:** `ede8196`

---

**Total deviations:** 2 auto-fixed (1× Rule 1, 1× Rule 2)
**Impact on plan:** Required for SESS-04 correctness and UI-SPEC reconnect matrix; no scope creep beyond plan must_haves.

## Issues Encountered

- PowerShell treats Mockito stderr as NativeCommandError (exit 1) even when surefire reports green — verified via surefire TXT
- `flutter analyze` LSP crash on Cyrillic workspace path; used `dart analyze` instead

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Phase 6 Stick Pull vertical slice complete (plans 01–05)
- Ready for phase verify / UAT; Phase 7 can add ranked ~12s grace without touching Stick Pull 8s path

## Self-Check: PASSED

- FOUND: `backend/src/main/java/com/nomadgames/session/internal/ReconnectPolicy.java` (graceSeconds)
- FOUND: `backend/src/test/java/com/nomadgames/session/StickPullReconnectIT.java`
- FOUND: `client/lib/games/stick_pull/stick_pull_match_page.dart` (opponentReconnecting)
- FOUND commits: `e60f76a`, `3fc48b1`, `ede8196`

---
*Phase: 06-stick-pull*
*Completed: 2026-09-14*
