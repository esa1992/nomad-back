---
phase: 07-bind-ranked-ship
plan: 04
subsystem: matchmaking
tags: [ranked, fifo, searching, MODE-04, D-97, D-98, D-99, flutter, spring]

requires:
  - phase: 07-bind-ranked-ship
    provides: Bind + guest claim JWT (07-02/03)
  - phase: 07-bind-ranked-ship
    provides: Soft-lock Ranked CTA for guests (07-10)
  - phase: 07-bind-ranked-ship
    provides: Wave 0 RankedQueueIT + ranked_search_test stubs (07-01)
provides:
  - "Sibling RankedQueueService FIFO + POST/GET/DELETE /v1/matchmaking/ranked"
  - "MatchService.createRankedMatch mode=RANKED; allowsRematch PRIVATE|CASUAL only"
  - "Bound catalog Ranked CTAs + SearchingPage mode=ranked without bot fallback"
affects:
  - 07-08 Glicko settle / Find Ranked match result CTA / Stick Pull rankedFalseStart
  - 07-05 Boards (bound entry already soft-locked)

tech-stack:
  added: []
  patterns:
    - "Sibling RankedQueueService — never share CasualQueue maps; never bot-fill"
    - "JWT guest claim gate 403 on Ranked controller (T-07-12)"
    - "isHumanPvP includes RANKED; allowsRematch stays PRIVATE|CASUAL (D-99)"
    - "SearchingPage mode=ranked skips _fallbackClock; poll RankedApi"

key-files:
  created:
    - backend/src/main/java/com/nomadgames/matchmaking/RankedQueueService.java
    - backend/src/main/java/com/nomadgames/matchmaking/RankedMatchmakingController.java
    - client/lib/matchmaking/ranked_api.dart
  modified:
    - backend/src/main/java/com/nomadgames/session/MatchService.java
    - backend/src/main/java/com/nomadgames/session/MatchSnapshot.java
    - backend/src/test/java/com/nomadgames/matchmaking/RankedQueueIT.java
    - client/lib/matchmaking/searching_page.dart
    - client/lib/catalog/catalog_page.dart
    - client/lib/platform/router.dart
    - client/lib/platform/api/nomad_api.dart
    - client/lib/l10n/app_en.arb
    - client/lib/l10n/app_ru.arb
    - client/test/ranked_search_test.dart

key-decisions:
  - "Sibling RankedQueueService clone of Casual FIFO — not mode flag on CasualQueue (T-07-15)"
  - "RANKED in isHumanPvP for seats/WS/reconnect; allowsRematch PRIVATE|CASUAL only"
  - "Ranked MatchSnapshot omits difficulty; Find Ranked match result CTA deferred to 07-08"

patterns-established:
  - "RankedMatchmakingController.requireBound via JWT guest claim"
  - "rankedApiProvider thin wrapper over NomadApi enqueue/poll/dequeue Ranked"
  - "Catalog bound Ranked → enqueueRanked then /matchmaking?mode=ranked"

requirements-completed: [MODE-04]

coverage:
  - id: D1
    description: "Guest JWT Ranked enqueue → 403"
    requirement: MODE-04
    verification:
      - kind: integration
        ref: "backend/src/test/java/com/nomadgames/matchmaking/RankedQueueIT.java#guestRejected"
        status: pass
    human_judgment: false
  - id: D2
    description: "Two bound players pair into mode=RANKED match; no bot difficulty"
    requirement: MODE-04
    verification:
      - kind: integration
        ref: "backend/src/test/java/com/nomadgames/matchmaking/RankedQueueIT.java#pairCreatesRanked"
        status: pass
    human_judgment: false
  - id: D3
    description: "Ranked searching shows rankedSearchingBody + Cancel; no bot/invite after 8s"
    requirement: MODE-04
    verification:
      - kind: automated_ui
        ref: "client/test/ranked_search_test.dart#rankedSearchingBody"
        status: pass
      - kind: automated_ui
        ref: "client/test/ranked_search_test.dart#rankedSearchHasNoBotOrInviteFallback"
        status: pass
    human_judgment: false

duration: 12min
completed: 2026-09-14
status: complete
---

# Phase 07 Plan 04: RankedQueue + Searching UI Summary

**Sibling Ranked FIFO queue with bind gate, createRankedMatch mode=RANKED, and catalog/search chrome without bot fallback**

## Performance

- **Duration:** 12 min
- **Started:** 2026-09-14T14:18:14Z
- **Completed:** 2026-09-14T14:30:24Z
- **Tasks:** 2/2
- **Files modified:** 14

## Accomplishments

- Bound players enqueue Ranked for Alchiki and Stick Pull via per-game FIFO; guests get 403
- createRankedMatch produces mode=RANKED human PvP tables; rematch window stays PRIVATE|CASUAL
- Ranked searching waits indefinitely with Cancel only — no Play vs bot / Invite friend chrome

## Task Commits

1. **Task 1: RankedQueue + createRankedMatch (no settle)** - `2315896` (feat)
2. **Task 2: Catalog Ranked CTAs + searching without bot fallback** - `bb708ec` (feat)

**Plan metadata:** `839a613` + `8a35d09` (docs: complete plan + STATE sync)

## Files Created/Modified

- `backend/.../RankedQueueService.java` — sibling FIFO; calls createRankedMatch
- `backend/.../RankedMatchmakingController.java` — `/v1/matchmaking/ranked` + guest 403
- `backend/.../MatchService.java` — createRankedMatch; isHumanPvP+allowsRematch split
- `backend/.../MatchSnapshot.java` — omit null difficulty for Ranked
- `backend/.../RankedQueueIT.java` — green guestRejected + pairCreatesRanked
- `client/lib/matchmaking/ranked_api.dart` — enqueue/poll/dequeue wrapper
- `client/lib/matchmaking/searching_page.dart` — mode=ranked; no fallback timer
- `client/lib/catalog/catalog_page.dart` — bound Ranked CTAs for both tiles
- `client/lib/platform/router.dart` — pass mode query to SearchingPage
- `client/lib/platform/api/nomad_api.dart` — ranked HTTP methods
- `client/lib/l10n/app_en.arb` / `app_ru.arb` — rankedSearchingBody, findRankedMatch
- `client/test/ranked_search_test.dart` — green searching assertions

## Decisions Made

- Sibling service over CasualQueue mode flag (T-07-15 / D-98 leakage risk)
- Split rematch eligibility from isHumanPvP so Ranked gets seats/WS without RematchWindow
- Result Find Ranked match CTA stays out of searching chrome (07-08)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] RankedQueueIT difficulty assertion**
- **Found during:** Task 1
- **Issue:** Wave 0 stub expected `$.difficulty` nullValue on queue response, but CasualQueueResponse omits the field — MockMvc fails PathNotFound
- **Fix:** Assert `doesNotExist()` for enqueue response (aligned with match GET)
- **Files modified:** RankedQueueIT.java
- **Verification:** RankedQueueIT green
- **Committed in:** `2315896`

**2. [Rule 2 - Missing Critical] allowsRematch split**
- **Found during:** Task 1
- **Issue:** Expanding isHumanPvP to RANKED would open RematchWindow for Ranked (D-99)
- **Fix:** Added allowsRematch(PRIVATE|CASUAL); requirePrivateTerminal uses it
- **Files modified:** MatchService.java
- **Verification:** Rematch path unchanged for CASUAL/PRIVATE; Ranked still human PvP
- **Committed in:** `2315896`

**3. [Rule 1 - Bug] findRankedMatchResultCta Wave 0 stub**
- **Found during:** Task 2
- **Issue:** Stub expected Find Ranked match on searching page; plan defers that CTA to 07-08
- **Fix:** Assert absence on searching + Cancel present; keys still in arb for 07-08
- **Files modified:** ranked_search_test.dart, app_en.arb, app_ru.arb
- **Verification:** flutter test ranked_search_test green
- **Committed in:** `bb708ec`

---

**Total deviations:** 3 auto-fixed (2 Rule 1, 1 Rule 2)
**Impact on plan:** Correctness only — no scope creep; settle/Glicko still 07-08

## Issues Encountered

None beyond the deviations above.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Ranked enqueue + search UI ready for human pair play
- 07-08 owns Glicko settle, Find Ranked match result CTA, Stick Pull rankedFalseStart
- Casual QM / rematch paths untouched

## Self-Check: PASSED

- FOUND: RankedQueueService.java, RankedMatchmakingController.java, ranked_api.dart, searching_page.dart
- FOUND commits: 2315896, bb708ec

---
*Phase: 07-bind-ranked-ship*
*Completed: 2026-09-14*
