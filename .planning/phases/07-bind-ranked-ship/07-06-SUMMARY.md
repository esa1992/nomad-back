---
phase: 07-bind-ranked-ship
plan: 06
subsystem: rating
tags: [leaderboards, boards, glicko, season, soft-reset, flutter, LEAD-01, LEAD-02, LEAD-03, D-105, D-106]

requires:
  - phase: 07-bind-ranked-ship
    provides: Glicko ratings storage + Ranked settle (07-08)
  - phase: 07-bind-ranked-ship
    provides: Guest soft-lock Ranked/Boards entry (07-10)
provides:
  - "GET /v1/boards bound-only Top-100 season/all_time skill lists"
  - "SeasonService YYYY-Qn soft-reset ensure-on-read (D-105)"
  - "Flutter /boards wood UI + Profile/catalog bound entry"
affects:
  - 07-07 CI/compose ship polish
  - verify-work LEAD UAT

tech-stack:
  added: []
  patterns:
    - "BoardsService JdbcClient ORDER BY rating/peak only; guest=false + credentials.username"
    - "SeasonService soft-reset ensure-on-read + RatingService loadOrCreate via season row"
    - "Flutter boards_api + boards_page wood chrome mirroring profile"

key-files:
  created:
    - backend/src/main/java/com/nomadgames/rating/BoardsController.java
    - backend/src/main/java/com/nomadgames/rating/BoardsService.java
    - backend/src/main/java/com/nomadgames/rating/SeasonService.java
    - client/lib/boards/boards_page.dart
    - client/lib/boards/boards_api.dart
  modified:
    - backend/src/main/java/com/nomadgames/rating/RatingService.java
    - backend/src/test/java/com/nomadgames/rating/BoardsIT.java
    - client/lib/platform/router.dart
    - client/lib/catalog/catalog_page.dart
    - client/lib/profile/profile_page.dart
    - client/lib/platform/api/nomad_api.dart
    - client/lib/l10n/app_en.arb
    - client/lib/l10n/app_ru.arb
    - client/test/boards_test.dart

key-decisions:
  - "Soft reset ensure-on-read via SeasonService (not a separate job)"
  - "all_time board uses DISTINCT ON player_id + all_time_peak; season uses current YYYY-Qn rating"
  - "BoardsIT seeds ratings/wallets to prove guest exclusion and skill-over-coins order"

patterns-established:
  - "requireBound JWT guest claim on GET /v1/boards (same as Ranked queue)"
  - "Bound catalog Boards chip → /boards; guest soft-lock unchanged"

requirements-completed: [LEAD-01, LEAD-02, LEAD-03]

coverage:
  - id: D1
    description: "Bound-only boards exclude guests; guest JWT → 403"
    requirement: LEAD-01
    verification:
      - kind: integration
        ref: "backend/src/test/java/com/nomadgames/rating/BoardsIT.java#guestsExcluded"
        status: pass
      - kind: integration
        ref: "backend/src/test/java/com/nomadgames/rating/BoardsIT.java#guestRejected"
        status: pass
    human_judgment: false
  - id: D2
    description: "Per-game filter + season vs all-time scopes"
    requirement: LEAD-02
    verification:
      - kind: integration
        ref: "backend/src/test/java/com/nomadgames/rating/BoardsIT.java#filterByGame"
        status: pass
      - kind: integration
        ref: "backend/src/test/java/com/nomadgames/rating/BoardsIT.java#seasonVsAllTime"
        status: pass
    human_judgment: false
  - id: D3
    description: "Never order/rank by coins or gems"
    requirement: LEAD-03
    verification:
      - kind: integration
        ref: "backend/src/test/java/com/nomadgames/rating/BoardsIT.java#neverOrderByCoins"
        status: pass
    human_judgment: false
  - id: D4
    description: "Flutter /boards title, Season|All-time, game filters"
    requirement: LEAD-01
    verification:
      - kind: automated_ui
        ref: "client/test/boards_test.dart#boardsTitle"
        status: pass
      - kind: automated_ui
        ref: "client/test/boards_test.dart#seasonAndAllTimeSegments"
        status: pass
      - kind: automated_ui
        ref: "client/test/boards_test.dart#gameFilters"
        status: pass
    human_judgment: false

duration: 25min
completed: 2026-09-14
status: complete
---

# Phase 07 Plan 06: Boards Season/All-time + Soft Reset Summary

**Bound-only GET /v1/boards Top-100 (season YYYY-Qn + all_time_peak) with quarterly soft-reset ensure and Flutter `/boards` wood UI.**

## Performance

- **Duration:** 25 min
- **Started:** 2026-09-14T15:17:00Z
- **Completed:** 2026-09-14T15:42:00Z
- **Tasks:** 2
- **Files modified:** 17

## Accomplishments

- Shipped `BoardsController`/`BoardsService` with bound-only SQL (guest=false + credentials username) ordered by Glicko season rating or all-time peak — never wallets
- `SeasonService` applies D-105 soft reset on ensure-on-read / new season row creation; `RatingService` updates `all_time_peak` on Ranked settle
- Flutter `/boards` with Alchiki|Stick Pull chips, Season|All-time segment, local-row highlight `#3A2A1C`; Profile Boards CTA + catalog bound navigation; guests remain soft-locked

## Task Commits

1. **Task 1: Boards API + soft season reset ensure** - `33116d1` (feat)
2. **Task 2: Flutter /boards page + Profile/catalog entry** - `1fc743a` (feat)

**Plan metadata:** `70d8232` (docs: complete plan)

## Files Created/Modified

- `backend/.../BoardsController.java` - GET /v1/boards requireBound
- `backend/.../BoardsService.java` - Top-100 season/all_time JdbcClient queries
- `backend/.../SeasonService.java` - YYYY-Qn soft-reset ensure
- `backend/.../RatingService.java` - season row via SeasonService; peak updates
- `backend/.../BoardsIT.java` - LEAD proofs + guest 403 + skill-over-coins seed
- `client/lib/boards/boards_page.dart` - wood boards UI
- `client/lib/boards/boards_api.dart` - Riverpod boards client
- `client/lib/platform/router.dart` - `/boards` route
- `client/lib/catalog/catalog_page.dart` - bound → /boards
- `client/lib/profile/profile_page.dart` - Boards entry for bound
- `client/lib/platform/api/nomad_api.dart` - fetchBoards
- `client/lib/l10n/app_en.arb` / `app_ru.arb` - boards copy keys
- `client/test/boards_test.dart` - title/segments/filters green

## Decisions Made

- Soft reset is ensure-on-read (Boards list + Ranked settle loadOrCreate), not a cron job
- all_time uses `DISTINCT ON (player_id) … all_time_peak`; season uses current `YYYY-Qn` `rating`
- BoardsIT seeds guest/high-coin rows so LEAD-03/D-106 cannot pass vacuously on empty lists

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing critical functionality] Strengthened BoardsIT seeds + guestRejected**
- **Found during:** Task 1 (Boards API)
- **Issue:** Wave 0 stubs expected `entries[0].rating` without seeding and lacked guest 403 coverage; shared IT DB could also make season assertions flaky on `entries[0]`
- **Fix:** Seed glicko + wallets; add `guestRejected`; assert season/all_time by username filter
- **Files modified:** `BoardsIT.java`
- **Verification:** `./mvnw -pl backend -am -Dtest=BoardsIT test` — 5/5 green
- **Committed in:** `33116d1`

**Total deviations:** 1 auto-fixed (Rule 2)
**Impact on plan:** Necessary for LEAD correctness proofs; no scope creep.

## Issues Encountered

None beyond shared-DB assertion flake fixed above.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

LEAD-01…03 closed. Remaining incomplete plan in phase: **07-07** (CI/compose ship). SoftElo untouched; SoftElo boards never added.

## Self-Check: PASSED

- FOUND: `backend/src/main/java/com/nomadgames/rating/BoardsController.java`
- FOUND: `backend/src/main/java/com/nomadgames/rating/BoardsService.java`
- FOUND: `backend/src/main/java/com/nomadgames/rating/SeasonService.java`
- FOUND: `client/lib/boards/boards_page.dart`
- FOUND: `client/lib/boards/boards_api.dart`
- FOUND: commit `33116d1`
- FOUND: commit `1fc743a`

---
*Phase: 07-bind-ranked-ship*
*Completed: 2026-09-14*
