---
phase: 02-guest-catalog-first-alchiki-match
plan: 01
subsystem: catalog
tags: [flutter, go_router, riverpod, gen-l10n, catalog, i18n]

requires:
  - phase: 01-alchiki-physics-prototype
    provides: Flutter 3.47 client, Phase 1 palette tokens, SandboxPage for optional debug route
provides:
  - Localized GoRouter catalog home with Alchiki playable and Coming Soon tiles
  - Complete EN/RU ARB for the phase Copywriting Contract
  - LocaleController persist via SharedPreferencesAsync locale.override
affects:
  - 02-03 how-to pager (replaces inline /howto/alchiki scaffold)
  - 02-07 guest mint + GET /v1/catalog (replaces local CatalogSnapshot)
  - 02-08 match table (replaces inline /match scaffold)

tech-stack:
  added:
    - go_router 18.0.1
    - flutter_riverpod 3.4.3
    - flutter_localizations + intl
    - dio 5.11.1
    - flutter_secure_storage 11.0.0
    - shared_preferences 2.5.5
  patterns:
    - main() owns the sole ProviderScope; NomadApp is router/locale shell only
    - Official gen-l10n ARB; localeListResolutionCallback falls back to EN
    - Local CatalogSnapshot until server catalog exists

key-files:
  created:
    - client/l10n.yaml
    - client/lib/l10n/app_en.arb
    - client/lib/l10n/app_ru.arb
    - client/lib/platform/app.dart
    - client/lib/platform/router.dart
    - client/lib/platform/locale_controller.dart
    - client/lib/platform/splash_page.dart
    - client/lib/catalog/catalog_page.dart
    - client/lib/catalog/catalog_models.dart
    - client/test/catalog_test.dart
  modified:
    - client/lib/main.dart
    - client/pubspec.yaml
    - client/test/widget_test.dart

key-decisions:
  - "ProviderScope lives only in main() and widget tests; NomadApp does not nest a second scope"
  - "Catalog tiles use a local CatalogSnapshot (alchiki PLAYABLE, stick_pull/more_games COMING_SOON) until 02-07 GET /v1/catalog"
  - "Play Alchiki this plan routes to /match?difficulty=; how-to gate is 02-03"
  - "EN/RU override persists as locale.override in SharedPreferencesAsync"

patterns-established:
  - "Pattern: MaterialApp.router + AppLocalizations delegates + EN fallback"
  - "Pattern: Coming Soon tiles have no onTap and stay disabled in semantics"
  - "Pattern: Difficulty chips select locally and do not navigate"

requirements-completed: [CAT-01, CAT-03, PRES-01]

coverage:
  - id: D1
    description: Catalog home shows Alchiki as the only playable tile with Play Alchiki
    requirement: CAT-01
    verification:
      - kind: automated_ui
        ref: "client/test/catalog_test.dart#catalog home shows Alchiki playable and Coming Soon tiles"
        status: pass
      - kind: automated_ui
        ref: "client/test/widget_test.dart#NomadApp catalog is home"
        status: pass
    human_judgment: false
  - id: D2
    description: Stick Pull and More games are Coming Soon tiles that do not navigate
    requirement: CAT-03
    verification:
      - kind: automated_ui
        ref: "client/test/catalog_test.dart#tapping Stick Pull does not leave the catalog"
        status: pass
    human_judgment: false
  - id: D3
    description: Every Copywriting Contract key exists in EN and RU ARB including howtoWinTitle
    requirement: PRES-01
    verification:
      - kind: other
        ref: "flutter gen-l10n"
        status: pass
      - kind: other
        ref: "client/lib/l10n/app_en.arb#howtoWinTitle"
        status: pass
      - kind: other
        ref: "client/lib/l10n/app_ru.arb#howtoWinTitle"
        status: pass
    human_judgment: false
  - id: D4
    description: Easy is the selected difficulty on first catalog visit
    requirement: CAT-01
    verification:
      - kind: automated_ui
        ref: "client/test/catalog_test.dart#Easy is the selected difficulty on first visit"
        status: pass
    human_judgment: false
  - id: D5
    description: Catalog draws no shop, wallet, Ranked, bind, or account-name UI
    requirement: CAT-01
    verification:
      - kind: automated_ui
        ref: "client/test/catalog_test.dart#catalog has no account-name field or sign-in labels"
        status: pass
    human_judgment: false
  - id: D6
    description: Felt-band Alchiki tile, 192dp Play CTA, and wood Coming Soon tiles match the UI-SPEC overlay
    verification: []
    human_judgment: true
    rationale: Widget tests assert copy and selection, not exact dp sizes or Phase 1 hex fills

duration: 5min
completed: 2026-09-06
status: complete
---

# Phase 2 Plan 01: Catalog Home Summary

**GoRouter catalog is the launch home with complete EN/RU ARB, Alchiki playable at Easy, and non-navigating Coming Soon tiles**

## Performance

- **Duration:** 5 min
- **Started:** 2026-09-06T14:10:28Z
- **Completed:** 2026-09-06T14:15:34Z
- **Tasks:** 2
- **Files modified:** 16

## Accomplishments

- Cold launch uses `NomadApp` + `GoRouter` (`/splash` → `/`); tests pump `initialLocation: '/'` and see catalog copy, not the Phase 1 sandbox
- Catalog shows Alchiki with Easy selected and Play Alchiki; Stick Pull and More games are Coming Soon and do not navigate
- Complete EN/RU ARB from the 02-UI-SPEC Copywriting Contract; in-app EN/RU toggle persists `locale.override`
- Physics pins stay forge2d 0.14.2 / flame_forge2d 0.19.3+7; Phase 1 unit tests stay green

## Task Commits

Each task was committed atomically:

1. **Task 1: Write failing catalog home tests** - `45201f6` (test)
2. **Task 2: Catalog is home with complete EN/RU** - `0369bcf` (feat)

**Plan metadata:** docs(02-01) complete catalog home plan

## Files Created/Modified

- `client/test/catalog_test.dart` - CAT-01 / CAT-03 / D-16 / D-21 widget tests
- `client/test/widget_test.dart` - NomadApp catalog-as-home smoke
- `client/l10n.yaml` - Official gen-l10n config
- `client/lib/l10n/app_en.arb` / `app_ru.arb` - Full Copywriting Contract
- `client/lib/main.dart` - ensureInitialized + ProviderScope(NomadApp)
- `client/lib/platform/app.dart` - Router/locale shell
- `client/lib/platform/router.dart` - /splash, /, /howto/alchiki, /match, /debug/sandbox
- `client/lib/platform/locale_controller.dart` - locale.override persist
- `client/lib/platform/splash_page.dart` - Wood splash, 400ms then catalog, no HTTP
- `client/lib/catalog/catalog_page.dart` - Catalog home UI
- `client/lib/catalog/catalog_models.dart` - Difficulty + local CatalogSnapshot
- `client/pubspec.yaml` - RESEARCH-approved pins + generate: true

## Decisions Made

- Single ProviderScope owner is `main()` / tests (D-18 shell)
- Local CatalogSnapshot until 02-07 moves playable flags to GET /v1/catalog
- Play Alchiki routes to `/match?difficulty=` this plan; how-to gate is 02-03
- Locale override key is `locale.override` via SharedPreferencesAsync

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Locale hydrate String? promotion**
- **Found during:** Task 2
- **Issue:** `Locale(stored)` failed to compile because flow analysis did not promote the awaited `String?`
- **Fix:** Assign through `stored as String` after the `en`/`ru` guard
- **Files modified:** `client/lib/platform/locale_controller.dart`
- **Verification:** `flutter test test/catalog_test.dart test/widget_test.dart` exit 0
- **Committed in:** `0369bcf`

---

**Total deviations:** 1 auto-fixed (1 bug)
**Impact on plan:** Compile-only; no scope change.

## Issues Encountered

None

## Authentication Gates

None

## Known Stubs

- `client/lib/platform/router.dart` `/howto/alchiki` — inline wood Scaffold showing `howToPlay`; dedicated pager is 02-03
- `client/lib/platform/router.dart` `/match` — inline wood Scaffold showing `firstToFive` + difficulty query; match table is 02-08
- `client/lib/catalog/catalog_models.dart` `CatalogSnapshot.local` — local playable flags until 02-07 GET /v1/catalog
- `client/lib/platform/splash_page.dart` — no guest HTTP this plan (D-16 mint is 02-07)

These stubs do not block CAT-01 / CAT-03 / PRES-01: catalog is home and fully localized.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Ready for 02-02 (identity backend). Catalog shell and ARB are in place; do not reopen forge2d 0.14.2 / flame_forge2d 0.19.3+7.

## TDD Gate Compliance

- RED commit `45201f6` `test(02-01): add failing test for catalog home` — compile failed on missing `NomadApp` / `flutter_riverpod`
- GREEN commit `0369bcf` `feat(02-01): implement localized catalog home` — catalog + Phase 1 tests passed

## Self-Check: PASSED

- FOUND: client/l10n.yaml, app_en.arb, app_ru.arb, catalog_page.dart, router.dart, app.dart, main.dart, catalog_test.dart, 02-01-SUMMARY.md
- FOUND: 45201f6 test(02-01), 0369bcf feat(02-01)

---
*Phase: 02-guest-catalog-first-alchiki-match*
*Completed: 2026-09-06*
