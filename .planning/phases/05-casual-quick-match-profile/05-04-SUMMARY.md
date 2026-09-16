---
phase: 05-casual-quick-match-profile
plan: 04
subsystem: ui
tags: [flutter, matchmaking, casual, fallback, empty-queue, MODE-03]

requires:
  - phase: 05-casual-quick-match-profile
    provides: SearchingPage + NomadApi enqueue/poll/dequeue Casual
provides:
  - "FallbackPage /matchmaking/fallback with equal Play vs bot / Invite friend"
  - "8s Searching client clock → fallback without dequeue (D-62, D-67)"
  - "Exit paths dequeue then bot / createRoom lobby / catalog (D-64, D-65)"
  - "Green matchmaking_test including fallbackAfterEightSeconds"
affects:
  - 05-05 casual rematch
  - 05-07 avatar chip

tech-stack:
  added: []
  patterns:
    - "Searching Timer 8s replaces route; ticket stays SEARCHING until explicit exit"
    - "Fallback polls GET /casual every 500ms for late MATCH"
    - "lastBotDifficultyProvider (Notifier) mirrors catalog chip for bot fallback"

key-files:
  created:
    - client/lib/matchmaking/fallback_page.dart
  modified:
    - client/lib/matchmaking/searching_page.dart
    - client/lib/platform/router.dart
    - client/lib/catalog/catalog_models.dart
    - client/lib/catalog/catalog_page.dart
    - client/lib/l10n/app_en.arb
    - client/lib/l10n/app_ru.arb
    - client/test/matchmaking_test.dart

key-decisions:
  - "Bot fallback difficulty via lastBotDifficultyProvider Notifier (Riverpod 3; no StateProvider)"
  - "Invite friend = dequeue then createRoom → /lobby same as catalog Create room"
  - "Play vs bot navigates howto/match path (not direct startMatch) after dequeue"

patterns-established:
  - "Empty-queue UX: 8s clock on Searching, choice on Fallback, dequeue only on exit"
  - "Equal wood-outline CTAs — neither bot nor invite uses accent (D-63)"

requirements-completed: [MODE-03]

coverage:
  - id: D1
    description: "After 8s alone, equal Play vs bot and Invite friend replace Searching (no countdown)"
    requirement: MODE-03
    verification:
      - kind: automated_ui
        ref: "client/test/matchmaking_test.dart#fallbackAfterEightSeconds"
        status: pass
    human_judgment: false
  - id: D2
    description: "Back to catalog from fallback dequeues and returns home"
    requirement: MODE-03
    verification:
      - kind: automated_ui
        ref: "client/test/matchmaking_test.dart#backToCatalogDequeues"
        status: pass
    human_judgment: false
  - id: D3
    description: "Invite friend dequeues then createRoom and opens lobby"
    requirement: MODE-03
    verification:
      - kind: automated_ui
        ref: "client/test/matchmaking_test.dart#inviteFriendDequeuesThenLobby"
        status: pass
    human_judgment: false
  - id: D4
    description: "Fallback keeps polling so a late human pair can still MATCH"
    requirement: MODE-03
    verification:
      - kind: other
        ref: "client/lib/matchmaking/fallback_page.dart#_refresh"
        status: pass
    human_judgment: false

duration: 5min
completed: 2026-09-11
status: complete
---

# Phase 5 Plan 04: Empty-Queue Fallback Summary

**8s Searching clock opens wood FallbackPage with equal Play vs bot / Invite friend; exits always dequeue before bot, createRoom lobby, or catalog**

## Performance

- **Duration:** 5 min
- **Started:** 2026-09-11T10:58:12Z
- **Completed:** 2026-09-11T11:03:33Z
- **Tasks:** 2
- **Files modified:** 8

## Accomplishments
- Solo search never sits on a long fail spinner — after 8s the player chooses bot or invite (MODE-03, D-62)
- Queue ticket stays SEARCHING on fallback with continued poll for late human MATCH
- Bot / invite / back exits always call `dequeueCasual` before starting bot, creating a room, or returning home (D-64, D-65)

## Task Commits

Each task was committed atomically:

1. **Task 1: FallbackPage + 8s Searching clock** - `024d2cd` (feat)
2. **Task 2: Bot / Invite / Back exits dequeue** - `d9d7373` (feat)

**Plan metadata:** `175ecfc` (docs: complete plan)

_Note: Wave 0 RED stubs already shipped in 05-01; this plan greened them without a new RED commit._

## Files Created/Modified
- `client/lib/matchmaking/fallback_page.dart` - Empty-queue choice screen + poll + exits
- `client/lib/matchmaking/searching_page.dart` - 8s Timer → `/matchmaking/fallback` without dequeue
- `client/lib/platform/router.dart` - `/matchmaking/fallback` route
- `client/lib/catalog/catalog_models.dart` - `lastBotDifficultyProvider` Notifier
- `client/lib/catalog/catalog_page.dart` - Persists chip difficulty into provider on Quick Match / chip change
- `client/lib/l10n/app_en.arb` / `app_ru.arb` - fallbackTitle, fallbackBody, playVsBot, inviteFriend, errorQueueLeft
- `client/test/matchmaking_test.dart` - Green fallback / back / invite cases

## Decisions Made
- Riverpod 3 has no `StateProvider` — used `NotifierProvider<LastBotDifficulty, String>` for last catalog chip
- Play vs bot reuses catalog howto/match navigation at last chip difficulty rather than calling `startMatch` from the fallback page
- Invite friend mirrors catalog `_createRoom` after dequeue (threat T-05-05)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] lastBotDifficultyProvider for bot chip reuse**
- **Found during:** Task 2 (Bot / Invite / Back exits)
- **Issue:** Catalog difficulty lived only in page state; after route replace to fallback the chip was lost
- **Fix:** Notifier provider updated on chip change and Quick Match; fallback reads it for bot path
- **Files modified:** `catalog_models.dart`, `catalog_page.dart`, `fallback_page.dart`
- **Verification:** matchmaking_test green; bot path uses provider value
- **Committed in:** `d9d7373` (Task 2)

**2. [Rule 3 - Blocking] StateProvider unavailable on flutter_riverpod 3.4.3**
- **Found during:** Task 2
- **Issue:** Compile error `Method not found: 'StateProvider'`
- **Fix:** Switched to `NotifierProvider` pattern matching `LocaleController`
- **Files modified:** `catalog_models.dart`, `catalog_page.dart`
- **Verification:** `flutter test test/matchmaking_test.dart` green
- **Committed in:** `d9d7373` (Task 2)

---

**Total deviations:** 2 auto-fixed (1 missing critical, 1 blocking)
**Impact on plan:** Required for correct bot difficulty and Riverpod 3 compile; no scope creep.

## Issues Encountered
None beyond the Riverpod 3 StateProvider compile fix above.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- MODE-03 empty-queue UX complete for solo search
- Ready for 05-05 casual rematch waiting
- Profile / avatar chip still 05-06 / 05-07

## TDD Gate Compliance
- RED stubs for `fallbackAfterEightSeconds` / `backToCatalogDequeues` landed in 05-01 Wave 0
- GREEN: `024d2cd` (UI + 8s), `d9d7373` (exits) — no separate RED commit in this plan (pre-existing failing stubs)

---
## Self-Check: PASSED

- FOUND: `client/lib/matchmaking/fallback_page.dart`
- FOUND: `client/lib/matchmaking/searching_page.dart`
- FOUND: `client/lib/platform/router.dart`
- FOUND: `05-04-SUMMARY.md`
- FOUND: commits `024d2cd`, `d9d7373`

---
*Phase: 05-casual-quick-match-profile*
*Completed: 2026-09-11*
