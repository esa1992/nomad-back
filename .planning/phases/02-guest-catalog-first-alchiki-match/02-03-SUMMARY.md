---
phase: 02-guest-catalog-first-alchiki-match
plan: 03
subsystem: howto
tags: [flutter, go_router, riverpod, shared_preferences, howto, pageview]

requires:
  - phase: 02-guest-catalog-first-alchiki-match
    provides: Localized catalog home and Play Alchiki route (02-01); splash mint + server catalog (02-07)
provides:
  - Full-screen five-card AlchikiHowToPage PageView before first match
  - HowToSeenStore howto.alchiki.seen via SharedPreferencesAsync
  - Catalog Play Alchiki gate: unseen → /howto/alchiki, seen → /match
affects:
  - 02-05 pause reopen of the same five cards
  - 02-08 match table behind /match

tech-stack:
  added: []
  patterns:
    - How-to seen lives in SharedPreferencesAsync, not FlutterSecureStorage
    - PageView swipes diagrams; heading/body bind to the current index
    - First-run Skip and card-5 Play Alchiki mark seen then go /match

key-files:
  created:
    - client/lib/howto/alchiki_howto_page.dart
    - client/lib/howto/howto_seen_store.dart
    - client/lib/howto/howto_diagrams.dart
    - client/test/howto_test.dart
  modified:
    - client/lib/catalog/catalog_page.dart
    - client/lib/platform/router.dart

key-decisions:
  - "HowToSeenStore is a Riverpod Provider over SharedPreferencesAsync key howto.alchiki.seen; tests inject a memory subclass"
  - "Heading and body sit outside PageView so only the current card copy is in the tree"
  - "fromPause Back to match is implemented on the page/route but not linked from Pause (02-05)"

patterns-established:
  - "Pattern: Play Alchiki reads HowToSeenStore.isSeen then go /howto/alchiki or /match"
  - "Pattern: First-run Skip/Play call markSeen; fromPause does not clear or rewrite seen"

requirements-completed: [ALCH-04]

coverage:
  - id: D1
    description: After Play Alchiki, first-run shows a full-screen five-card static pager before the table
    requirement: ALCH-04
    verification:
      - kind: automated_ui
        ref: "client/test/howto_test.dart#Play Alchiki opens pager with The circle and Skip on card 1"
        status: pass
    human_judgment: false
  - id: D2
    description: Skip is visible and usable on card 1 of the first showing
    requirement: ALCH-04
    verification:
      - kind: automated_ui
        ref: "client/test/howto_test.dart#Skip writes howto.alchiki.seen and routes to /match"
        status: pass
    human_judgment: false
  - id: D3
    description: Skip or Play persists howto.alchiki.seen; later Play Alchiki goes straight to /match
    requirement: ALCH-04
    verification:
      - kind: automated_ui
        ref: "client/test/howto_test.dart#after markSeen, Play Alchiki skips the pager"
        status: pass
    human_judgment: false
  - id: D4
    description: Exactly five cards (circle, aim, hold, out=1, first to 5) with no federation or alshy jargon
    requirement: ALCH-04
    verification:
      - kind: automated_ui
        ref: "client/test/howto_test.dart#page 1 of 5; swipe to card 5 shows First to 5 and Play Alchiki"
        status: pass
      - kind: automated_ui
        ref: "client/test/howto_test.dart#card copy does not include federation or alshy words"
        status: pass
    human_judgment: false
  - id: D5
    description: EN card copy comes from ARB keys howtoCircleTitle through howtoWinBody
    requirement: ALCH-04
    verification:
      - kind: automated_ui
        ref: "client/test/howto_test.dart#card copy does not include federation or alshy words"
        status: pass
    human_judgment: false
  - id: D6
    description: Wood full-screen pager with 50% CustomPaint diagrams and cream page dots matches the UI-SPEC overlay
    verification: []
    human_judgment: true
    rationale: Widget tests assert copy, Skip, seen, and five headings, not exact dp split or Phase 1 hex fills

duration: 6min
completed: 2026-09-06
status: complete
---

# Phase 2 Plan 03: How-to Pager Summary

**Skippable five-card full-screen how-to before the first Alchiki match, with Skip on card 1 and local howto.alchiki.seen**

## Performance

- **Duration:** 6 min
- **Started:** 2026-09-06T16:39:13Z
- **Completed:** 2026-09-06T16:43:22Z
- **Tasks:** 2
- **Files modified:** 6

## Accomplishments

- First Play Alchiki opens a wood full-screen `PageView` (not a felt overlay) with Skip on card 1
- Five static CustomPaint cards: circle, aim, hold, out=1, first to 5; EN/RU from existing ARB keys
- Skip and card-5 Play Alchiki write `howto.alchiki.seen` then go `/match?difficulty=`; later Play skips the pager
- `fromPause` uses Back to match and does not clear seen; Pause wiring stays in 02-05

## Task Commits

Each task was committed atomically:

1. **Task 1: Write failing how-to pager tests** - `2fc488b` (test)
2. **Task 2: Full-screen five-card how-to with skip on card 1** - `94df87f` (feat)

**Plan metadata:** docs(02-03) complete how-to pager plan

## Files Created/Modified

- `client/test/howto_test.dart` - Skip-on-card-1, five headings, seen persistence
- `client/lib/howto/alchiki_howto_page.dart` - Full-screen PageView pager
- `client/lib/howto/howto_seen_store.dart` - SharedPreferencesAsync `howto.alchiki.seen`
- `client/lib/howto/howto_diagrams.dart` - Five static CustomPaint diagrams (Phase 1 hexes)
- `client/lib/catalog/catalog_page.dart` - Play Alchiki reads HowToSeenStore
- `client/lib/platform/router.dart` - `/howto/alchiki` builds AlchikiHowToPage

## Decisions Made

- HowToSeenStore is injected via `howToSeenStoreProvider`; widget tests use a memory subclass instead of the plugin
- Heading/body bind to `_index` outside `PageView` so off-screen card copy is not in the tree
- `fromPause` is on the page and query (`fromPause=true`) but Pause → How to play is 02-05

## Deviations from Plan

None - plan executed exactly as written.

---

**Total deviations:** 0 auto-fixed
**Impact on plan:** None.

## Issues Encountered

None

## Authentication Gates

None

## Known Stubs

- `client/lib/platform/router.dart` `/match` remains the 02-01 wood placeholder — 02-08 lifts the table
- Pause → How to play is not linked yet — 02-05 owns reopen of the same five cards
- `HowtoHoldDiagram` paints English "Hold Throw" as illustration text; card heading/body stay on ARB keys

These stubs do not block ALCH-04 first-run: Skip on card 1, five topics, and once-per-device seen all work.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Ready for 02-08 (match table). Do not lift Flame here. Pause how-to reopen stays 02-05.

## TDD Gate Compliance

- RED commit `2fc488b` `test(02-03): add failing test for how-to pager` — compile failed on missing `AlchikiHowToPage` / `HowToSeenStore`
- GREEN commit `94df87f` `feat(02-03): implement five-card how-to pager` — howto + catalog + widget tests passed

## Self-Check: PASSED

- FOUND: client/lib/howto/alchiki_howto_page.dart, howto_seen_store.dart, howto_diagrams.dart, client/test/howto_test.dart, catalog_page.dart, router.dart
- FOUND: 2fc488b test(02-03), 94df87f feat(02-03)

---
*Phase: 02-guest-catalog-first-alchiki-match*
*Completed: 2026-09-06*
