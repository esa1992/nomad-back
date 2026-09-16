---
phase: 07-bind-ranked-ship
plan: 08
subsystem: rating
tags: [glicko2, ranked, settle, stick-pull, false-start, MODE-04, D-99, D-100, D-104, flutter]

requires:
  - phase: 07-bind-ranked-ship
    provides: RankedQueue + createRankedMatch + searching UI (07-04)
provides:
  - "Vendored Glicko-2 + RatingService.recordRankedSettlement (SoftElo untouched)"
  - "V12 glicko_ratings + glicko_settlements"
  - "Stick Pull Ranked false-start (70% then rated forfeit)"
  - "Alchiki Ranked last-knock-out / else DRAW 0.5/0.5"
  - "Ranked ResultOverlay Find Ranked match CTA (no rematch)"
affects:
  - 07-05 Boards season/all_time reads of glicko_ratings
  - 07-06 Boards UI Find Ranked match on empty boards

tech-stack:
  added: []
  patterns:
    - "Vendored Glicko-2 under rating/internal — no Maven Glicko JAR"
    - "Ranked settle → RatingService; SoftElo stays CASUAL-only in ProfileService"
    - "one settle = one Glicko period (m=1 opponent)"
    - "Ranked result Find Ranked match accent CTA; allowsRematch PRIVATE|CASUAL only"

key-files:
  created:
    - backend/src/main/resources/db/migration/V12__glicko_ratings.sql
    - backend/src/main/java/com/nomadgames/rating/internal/Glicko2.java
    - backend/src/main/java/com/nomadgames/rating/RatingService.java
    - backend/src/main/java/com/nomadgames/rating/internal/GlickoRatingEntity.java
    - backend/src/main/java/com/nomadgames/rating/internal/GlickoRatingRepository.java
  modified:
    - backend/src/main/java/com/nomadgames/session/MatchService.java
    - backend/src/main/java/com/nomadgames/games/stickpull/StickPullSim.java
    - client/lib/games/alchiki/pause_overlay.dart
    - client/lib/games/alchiki/match_page.dart
    - client/lib/games/stick_pull/stick_pull_match_page.dart
    - client/test/ranked_search_test.dart

key-decisions:
  - "Glicko claim both seats before update — avoids partial settle rows"
  - "Ranked client _isHuman includes ranked so WS table + Find Ranked match CTA work"
  - "findRankedMatch EN/RU keys reused from 07-04 arb (no new strings)"

patterns-established:
  - "MatchService.recordProfileSettlements branches RANKED → rating.recordRankedSettlement"
  - "StickPullSim(ranked=true) COUNTDOWN false-start counter"
  - "ResultOverlay.isRanked + onFindRankedMatch supersedes Play again / Again?"

requirements-completed: [MODE-04]

coverage:
  - id: D1
    description: "Glicko-2 defaults r=1500 RD=350 σ=0.06 τ=0.5; win/loss/draw scores update"
    requirement: MODE-04
    verification:
      - kind: unit
        ref: "backend/src/test/java/com/nomadgames/rating/Glicko2Test.java#defaultsMatchStack"
        status: pass
      - kind: unit
        ref: "backend/src/test/java/com/nomadgames/rating/Glicko2Test.java#winLossDrawScores"
        status: pass
    human_judgment: false
  - id: D2
    description: "Ranked settle updates Glicko only; SoftElo columns unchanged"
    requirement: MODE-04
    verification:
      - kind: integration
        ref: "backend/src/test/java/com/nomadgames/session/RankedSettleIT.java#rankedSettleUpdatesGlickoNotSoftElo"
        status: pass
    human_judgment: false
  - id: D3
    description: "Alchiki Ranked draw with no knock-outs → Glicko 0.5/0.5"
    requirement: MODE-04
    verification:
      - kind: integration
        ref: "backend/src/test/java/com/nomadgames/session/RankedSettleIT.java#alchikiDrawHalfScores"
        status: pass
    human_judgment: false
  - id: D4
    description: "Stick Pull Ranked false-start: 1st→70% stamina; 2nd→rated forfeit; Casual ignore"
    requirement: MODE-04
    verification:
      - kind: unit
        ref: "backend/src/test/java/com/nomadgames/games/stickpull/StickPullSimTest.java#rankedFalseStart"
        status: pass
    human_judgment: false
  - id: D5
    description: "Ranked result shows Find Ranked match; no Play again / Again? rematch"
    requirement: MODE-04
    verification:
      - kind: automated_ui
        ref: "client/test/ranked_search_test.dart#findRankedMatchResultCta"
        status: pass
    human_judgment: false

duration: 28min
completed: 2026-09-14
status: complete
---

# Phase 07 Plan 08: Glicko settle + Ranked false-start + result CTAs Summary

**Vendored Glicko-2 Ranked settle (SoftElo untouched), Stick Pull Ranked false-start, and Find Ranked match result CTA without rematch**

## Performance

- **Duration:** 28 min
- **Started:** 2026-09-14T14:33:00Z
- **Completed:** 2026-09-14T15:01:00Z
- **Tasks:** 2
- **Files modified:** 21

## Accomplishments

- Shipped Modulith `com.nomadgames.rating` with vendored Glicko-2 (r=1500, RD=350, σ=0.06, τ=0.5) and Flyway V12 `glicko_ratings` / `glicko_settlements`
- Ranked settle updates Glicko only; SoftElo stays CASUAL-only; XP/W/L still via ProfileService
- Stick Pull Ranked false-start (1→70% stamina, 2→rated forfeit); Alchiki Ranked last-knock-out else DRAW 0.5/0.5
- Ranked ResultOverlay primary **Find Ranked match** (accent); rematch chrome absent (D-99)

## Task Commits

Each task was committed atomically:

1. **Task 1: Glicko settle path + Stick Pull Ranked false-start** - `c9e2555` (feat)
2. **Task 2: Ranked result Find Ranked match CTA** - `ec97399` (feat)

**Plan metadata:** `96e6c99` (docs: complete plan)

_Note: TDD tasks may have multiple commits (test → feat → refactor)_

## Files Created/Modified

- `backend/src/main/resources/db/migration/V12__glicko_ratings.sql` - Glicko season + all-time columns + settlement claims
- `backend/src/main/java/com/nomadgames/rating/internal/Glicko2.java` - Vendored algorithm
- `backend/src/main/java/com/nomadgames/rating/RatingService.java` - `recordRankedSettlement`
- `backend/src/main/java/com/nomadgames/session/MatchService.java` - Ranked Glicko hook + Alchiki last-knock-out
- `backend/src/main/java/com/nomadgames/games/stickpull/StickPullSim.java` - D-100 Ranked false-start
- `client/lib/games/alchiki/pause_overlay.dart` - Ranked Find Ranked match CTA
- `client/lib/games/alchiki/match_page.dart` / `stick_pull_match_page.dart` - Ranked human path + enqueue search
- `client/test/ranked_search_test.dart` - Result CTA assertions

## Decisions Made

- Claim both Glicko settlement seats before applying updates (idempotent, no partial rows)
- Client `_isHuman` / `match_game.isPrivate` include `ranked` so dual-saka WS play and result CTAs work
- Reused existing `findRankedMatch` EN/RU arb keys from 07-04

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing critical functionality] Ranked client human PvP path**
- **Found during:** Task 2 (Ranked result Find Ranked match CTA)
- **Issue:** `_isHuman` / boot path only covered private|casual, so Ranked matches would not use WS human table or correct ResultOverlay wiring
- **Fix:** Include `ranked` in Alchiki/Stick Pull `_isHuman`, boot Ranked via `_bootPrivate`/`_bootHuman`, and treat `ranked` as private table in `match_game`
- **Files modified:** `match_page.dart`, `stick_pull_match_page.dart`, `match_game.dart`
- **Verification:** `flutter test test/ranked_search_test.dart` green; Find Ranked match CTA wired
- **Committed in:** `ec97399`

---

**Total deviations:** 1 auto-fixed (Rule 2)
**Impact on plan:** Required for MODE-04 result CTA and Ranked play correctness; no scope creep beyond plan goal

## Issues Encountered

None

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

MODE-04 settle half is green. Boards (07-05/06) can read `glicko_ratings` season/all_time columns. Incomplete phase plans remain 07-05, 07-06, 07-07.

## Self-Check: PASSED

- FOUND: `backend/src/main/java/com/nomadgames/rating/internal/Glicko2.java`
- FOUND: `backend/src/main/java/com/nomadgames/rating/RatingService.java`
- FOUND: `backend/src/main/resources/db/migration/V12__glicko_ratings.sql`
- FOUND: commit `c9e2555`
- FOUND: commit `ec97399`

---
*Phase: 07-bind-ranked-ship*
*Completed: 2026-09-14*
