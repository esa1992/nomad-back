---
phase: 05-casual-quick-match-profile
plan: 07
subsystem: ui
tags: [flutter, profile, avatar, go-router, arb, widget-test]

requires:
  - phase: 05-casual-quick-match-profile
    provides: GET/PUT /v1/profile + Guest-XXXX + Stick Pull zeros + avatar allow-list
provides:
  - "Catalog AvatarChip → /profile with openProfileA11y (D-74)"
  - "ProfilePage Guest + Guest-XXXX, XP/rating, cosmetics read-only, Stick Pull noMatchesYet"
  - "Eight avatar_01…08 presets + Save avatar PUT allow-list only (PROF-03)"
  - "Green profile_page_test + catalog avatar asserts"
affects:
  - phase UAT PROF-01…03
  - catalog header chrome

tech-stack:
  added: []
  patterns:
    - "AvatarChip clones WalletChip wood chrome; tap → push /profile; wallet stays non-nav"
    - "ProfilePage mirrors ShopPage wood scroll CRUD; Save avatar dirty when selection ≠ current"
    - "Client sends only allow-listed preset ids; display XP/MMR from API only (T-05-02/T-05-03)"

key-files:
  created:
    - client/lib/catalog/avatar_chip.dart
    - client/lib/profile/profile_page.dart
    - client/lib/profile/avatar_assets.dart
    - client/assets/avatars/avatar_01.png
    - client/assets/avatars/avatar_02.png
    - client/assets/avatars/avatar_03.png
    - client/assets/avatars/avatar_04.png
    - client/assets/avatars/avatar_05.png
    - client/assets/avatars/avatar_06.png
    - client/assets/avatars/avatar_07.png
    - client/assets/avatars/avatar_08.png
  modified:
    - client/lib/catalog/catalog_page.dart
    - client/lib/platform/api/nomad_api.dart
    - client/lib/platform/router.dart
    - client/lib/l10n/app_en.arb
    - client/lib/l10n/app_ru.arb
    - client/pubspec.yaml
    - client/test/catalog_test.dart
    - client/test/profile_page_test.dart

key-decisions:
  - "Avatar chip always visible before wallet; profile fetch failure keeps default avatar_01"
  - "Alchiki section shows zero metrics; Stick Pull uses noMatchesYet empty copy (D-77)"
  - "XP label uses current / (xp + remaining) because API xpToNext is remaining-to-next"

patterns-established:
  - "Catalog header order: avatar → wallet → Shop → EN/RU"
  - "avatar_preset_* keys for preset grid hit targets in widget tests"

requirements-completed: [PROF-01, PROF-02, PROF-03]

coverage:
  - id: D1
    description: "Catalog avatar chip opens /profile; wallet does not"
    requirement: PROF-01
    verification:
      - kind: automated_ui
        ref: "client/test/catalog_test.dart#catalog shows openProfileA11y avatar chip"
        status: pass
      - kind: automated_ui
        ref: "client/test/catalog_test.dart#wallet chip does not open profile"
        status: pass
    human_judgment: false
  - id: D2
    description: "Profile shows Guest + Guest-XXXX and Stick Pull No matches yet"
    requirement: PROF-02
    verification:
      - kind: automated_ui
        ref: "client/test/profile_page_test.dart#stickPullSectionShowsNoMatchesYet"
        status: pass
    human_judgment: false
  - id: D3
    description: "Save avatar PUTs allow-listed preset from profile grid"
    requirement: PROF-03
    verification:
      - kind: automated_ui
        ref: "client/test/profile_page_test.dart#saveAvatarCallsPut"
        status: pass
    human_judgment: false

duration: 8min
completed: 2026-09-11
status: complete
---

# Phase 5 Plan 07: Client Profile + Avatar Chip Summary

**Flutter parlor profile from catalog avatar chip — Guest + Guest-XXXX, Stick Pull zeros, and 8 allow-listed avatar presets with green widget tests**

## Performance

- **Duration:** 8 min
- **Started:** 2026-09-11T11:22:10Z
- **Completed:** 2026-09-11T11:30:33Z
- **Tasks:** 2
- **Files modified:** 21

## Accomplishments

- Catalog header AvatarChip (wood 48dp, `openProfileA11y`) opens `/profile`; wallet chip stays display-only (D-74)
- ProfilePage delivers PROF-01…03: Guest heading + subtitle, soft rating Display, XP bar, metrics, cosmetics read-only, Alchiki + Stick Pull sections, 8-preset Save avatar
- `flutter test test/profile_page_test.dart test/catalog_test.dart` green

## Task Commits

Each task was committed atomically:

1. **Task 1: Avatar chip + /profile route shell** — `ce223b9` (test) → `b96ac9b` (feat)
2. **Task 2: Full profile page + avatar save** — `9a8207a` (test) → `9e6edc5` (feat) → `261aafd` (fix XP mapping)

**Plan metadata:** `104e4e0` (docs: complete plan); `8e82a69` (docs: metrics/decisions)

## Files Created/Modified

- `client/lib/catalog/avatar_chip.dart` — catalog → profile entry
- `client/lib/profile/profile_page.dart` — full PROF UI
- `client/lib/profile/avatar_assets.dart` — preset allow-list + asset paths
- `client/lib/platform/api/nomad_api.dart` — `fetchProfile` / `putAvatar` + models
- `client/lib/platform/router.dart` — `/profile` route
- `client/lib/catalog/catalog_page.dart` — chip before wallet; optional profile fetch for art
- `client/lib/l10n/app_en.arb` / `app_ru.arb` — profile ARB keys from UI-SPEC
- `client/assets/avatars/avatar_01…08.png` — PRES-02 placeholder parlor faces
- `client/test/catalog_test.dart` / `profile_page_test.dart` — green asserts

## Decisions Made

- Keep avatar chip visible even when wallet/profile fetch fails (default `avatar_01`)
- Stick Pull empty uses `noMatchesYet`; Alchiki always shows numeric rows (including zeros)
- Map server remaining `xpToNext` to absolute next threshold for XP label/bar

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] XP bar treated remaining as absolute threshold**
- **Found during:** Task 2
- **Issue:** API `xpToNext` is remaining XP; dividing `xp / xpToNext` mis-scaled the bar and label
- **Fix:** Progress and label use `xp / (xp + xpToNext)`
- **Files modified:** `client/lib/profile/profile_page.dart`
- **Verification:** `flutter test test/profile_page_test.dart test/catalog_test.dart`
- **Committed in:** `261aafd`

**2. [Rule 1 - Bug] Widget tap missed off-screen avatar preset**
- **Found during:** Task 2
- **Issue:** `Save avatar` test tapped a grid cell below the viewport
- **Fix:** `ensureVisible` before preset and Save taps
- **Files modified:** `client/test/profile_page_test.dart`
- **Verification:** `saveAvatarCallsPut` green
- **Committed in:** `9e6edc5`

## TDD Gate Compliance

- RED: `ce223b9` (catalog), `9a8207a` (profile)
- GREEN: `b96ac9b` (catalog/shell), `9e6edc5` (full profile)

## Known Stubs

None — profile loads from `fetchProfile`; avatar assets are placeholder PNGs by design (PRES-02 OK).

## Threat Flags

None beyond plan threat model (display-only XP/MMR; allow-listed avatar PUT; self profile only).

## Self-Check: PASSED

- FOUND: `client/lib/profile/profile_page.dart`
- FOUND: `client/lib/catalog/avatar_chip.dart`
- FOUND: `client/test/profile_page_test.dart`
- FOUND: commits `ce223b9`, `b96ac9b`, `9a8207a`, `9e6edc5`, `261aafd`
