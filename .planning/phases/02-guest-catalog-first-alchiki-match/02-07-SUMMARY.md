---
phase: 02-guest-catalog-first-alchiki-match
plan: 07
subsystem: catalog
tags: [catalog, jwt, dio, flutter-secure-storage, guest-mint, spring-modulith]

requires:
  - phase: 02-guest-catalog-first-alchiki-match
    provides: Guest mint/refresh backend (02-02); localized catalog shell (02-01)
provides:
  - GET /v1/catalog Bearer-gated tiles with alchiki PLAYABLE and Coming Soon stick_pull/more_games
  - SessionStore playerId + refresh in FlutterSecureStorage; access JWT memory-only
  - NomadApi mintGuest / refresh / fetchCatalog with QueuedInterceptorsWrapper
  - SplashPage silent guest mint and CatalogPage server tiles
affects:
  - 02-08 match start/throw client (NomadApi extension)
  - 02-03 how-to pager after Play Alchiki

tech-stack:
  added: []
  patterns:
    - CatalogService owns PLAYABLE flags; unauthenticated GET is 401
    - Refresh and mint use a second Dio with no auth interceptor
    - QueuedInterceptorsWrapper shares one refresh; retry uses a naked Dio
    - android:allowBackup false; debug-only usesCleartextTraffic

key-files:
  created:
    - backend/src/main/java/com/nomadgames/catalog/CatalogService.java
    - backend/src/main/java/com/nomadgames/catalog/CatalogController.java
    - backend/src/test/java/com/nomadgames/catalog/CatalogIT.java
    - client/lib/platform/auth/session_store.dart
    - client/lib/platform/api/nomad_api.dart
    - client/test/guest_mint_test.dart
  modified:
    - client/lib/platform/splash_page.dart
    - client/lib/catalog/catalog_page.dart
    - client/android/app/src/main/AndroidManifest.xml
    - client/android/app/src/debug/AndroidManifest.xml
    - client/test/catalog_test.dart
    - client/test/widget_test.dart

key-decisions:
  - "Access JWT stays in NomadApi memory; playerId and refresh use FlutterSecureStorage default ciphers"
  - "Debug overlay allows cleartext to 10.0.2.2; release manifest does not enable cleartext"
  - "Catalog tests override NomadApi instead of shipping CatalogSnapshot.local as the product default"
  - "Main Android manifest declares INTERNET so a release APK can mint and fetch catalog"

patterns-established:
  - "Pattern: CatalogController GET /v1/catalog is resource-server authenticated and does not import identity internals"
  - "Pattern: Splash mint on first frame; 2500ms in-flight timeout shows errorGuestMint + Retry"
  - "Pattern: CatalogPage 401 after failed refresh clears SessionStore and returns to /splash"

requirements-completed: [AUTH-01, CAT-01, CAT-03]

coverage:
  - id: D1
    description: GET /v1/catalog without Bearer is 401
    requirement: AUTH-01
    verification:
      - kind: integration
        ref: "backend/src/test/java/com/nomadgames/catalog/CatalogIT.java#catalogWithoutBearerIsUnauthorized"
        status: pass
    human_judgment: false
  - id: D2
    description: Authenticated GET /v1/catalog returns alchiki PLAYABLE plus stick_pull and more_games COMING_SOON
    requirement: CAT-01
    verification:
      - kind: integration
        ref: "backend/src/test/java/com/nomadgames/catalog/CatalogIT.java#catalogWithGuestAccessReturnsAlchikiPlayable"
        status: pass
      - kind: integration
        ref: "backend/src/test/java/com/nomadgames/catalog/CatalogIT.java#catalogComingSoonTilesAreStickPullAndMoreGames"
        status: pass
    human_judgment: false
  - id: D3
    description: Splash mint failure shows errorGuestMint and Retry with no username field
    requirement: AUTH-01
    verification:
      - kind: automated_ui
        ref: "client/test/guest_mint_test.dart#splash mint failure shows errorGuestMint and retry"
        status: pass
    human_judgment: false
  - id: D4
    description: Successful splash mint has no account-name field
    requirement: AUTH-01
    verification:
      - kind: automated_ui
        ref: "client/test/guest_mint_test.dart#splash mint success has no account-name field"
        status: pass
    human_judgment: false
  - id: D5
    description: Catalog home still shows Play Alchiki and non-navigating Coming Soon tiles from server-shaped tiles
    requirement: CAT-03
    verification:
      - kind: automated_ui
        ref: "client/test/catalog_test.dart#catalog home shows Alchiki playable and Coming Soon tiles"
        status: pass
      - kind: automated_ui
        ref: "client/test/widget_test.dart#NomadApp catalog is home"
        status: pass
    human_judgment: false

duration: 7min
completed: 2026-09-06
status: complete
---

# Phase 2 Plan 07: Guest Catalog Mint Summary

**Silent splash guest mint with FlutterSecureStorage refresh plus Bearer GET /v1/catalog returning server-owned PLAYABLE flags**

## Performance

- **Duration:** 7 min
- **Started:** 2026-09-06T15:36:46Z
- **Completed:** 2026-09-06T15:43:32Z
- **Tasks:** 2
- **Files modified:** 12

## Accomplishments

- `CatalogService` returns a static tile list; `GET /v1/catalog` requires a Bearer access token from 02-02
- Cold start mints a guest on splash with no username field; `playerId` and refresh persist in `FlutterSecureStorage`
- `NomadApi` attaches Authorization, refreshes on 401 via a second Dio, and `CatalogPage` renders server tiles
- Debug emulator can reach `10.0.2.2` over cleartext; release backup is disabled

## Task Commits

Each task was committed atomically:

1. **Task 1: Write failing catalog and splash-mint tests** - `052f086` (test)
2. **Task 2: Splash mint and server catalog fetch** - `7dd0663` (feat)

**Plan metadata:** docs(02-07) complete splash mint and server catalog plan

## Files Created/Modified

- `backend/src/main/java/com/nomadgames/catalog/CatalogService.java` - Static alchiki PLAYABLE plus Coming Soon tiles
- `backend/src/main/java/com/nomadgames/catalog/CatalogController.java` - GET /v1/catalog
- `backend/src/test/java/com/nomadgames/catalog/CatalogIT.java` - 401 without Bearer; tile statuses with guest JWT
- `client/lib/platform/auth/session_store.dart` - Secure playerId + refresh; memory store for tests
- `client/lib/platform/api/nomad_api.dart` - mintGuest, refresh, fetchCatalog, queued 401 refresh
- `client/lib/platform/splash_page.dart` - Silent mint, 2500ms timeout, errorGuestMint + Retry
- `client/lib/catalog/catalog_page.dart` - fetchCatalog; empty/error banners; 401 returns to splash
- `client/android/app/src/main/AndroidManifest.xml` - allowBackup false + INTERNET
- `client/android/app/src/debug/AndroidManifest.xml` - usesCleartextTraffic true
- `client/test/guest_mint_test.dart` - Mint failure and no-username success
- `client/test/catalog_test.dart` / `client/test/widget_test.dart` - NomadApi overrides so existing catalog tests stay green

## Decisions Made

- Access JWT is memory-only on `NomadApi`; only playerId and refresh go to Keystore/Keychain defaults
- Cleartext is debug-overlay only so the emulator can reach `10.0.2.2` without enabling it on release
- Existing catalog widget tests override `nomadApiProvider` rather than keeping a local snapshot as the product default
- Main manifest declares INTERNET so a release APK can call guest mint and catalog

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] INTERNET on the main Android manifest**
- **Found during:** Task 2
- **Issue:** Release/main manifest had no INTERNET permission; debug-only INTERNET would block guest mint and catalog on a release APK
- **Fix:** Added `android.permission.INTERNET` on the main application manifest
- **Files modified:** `client/android/app/src/main/AndroidManifest.xml`
- **Verification:** Manifest contains INTERNET and allowBackup; Flutter catalog/mint tests pass
- **Committed in:** `7dd0663`

**2. [Rule 3 - Blocking] Catalog widget tests needed NomadApi overrides**
- **Found during:** Task 2
- **Issue:** `CatalogPage` now fetches tiles; `catalog_test` and `widget_test` would hang or error against a real HTTP client
- **Fix:** Override `nomadApiProvider` with an in-memory `fetchCatalog` that returns `CatalogSnapshot.local`
- **Files modified:** `client/test/catalog_test.dart`, `client/test/widget_test.dart`
- **Verification:** `flutter test test/catalog_test.dart test/widget_test.dart` exits 0
- **Committed in:** `7dd0663`

**3. [Rule 1 - Bug] Success mint test would hit real catalog HTTP**
- **Found during:** Task 2
- **Issue:** After a successful stub mint, splash navigates to catalog and the same stub called real `fetchCatalog`
- **Fix:** `_SucceedingMintApi.fetchCatalog` returns `CatalogSnapshot.local`
- **Files modified:** `client/test/guest_mint_test.dart`
- **Verification:** `flutter test test/guest_mint_test.dart` exits 0
- **Committed in:** `7dd0663`

---

**Total deviations:** 3 auto-fixed (1 missing critical, 1 blocking, 1 bug)
**Impact on plan:** Required for release networking and green existing tests. No match UI, how-to pager, shop, or bind added.

## Issues Encountered

None beyond the auto-fixes above. Docker Desktop / Testcontainers PostgreSQL 18 was already available from 02-02.

## Authentication Gates

None

## Known Stubs

- `client/lib/platform/api/nomad_api.dart` has no `startMatch` / `submitThrow` — those are 02-08
- `client/lib/catalog/catalog_models.dart` `CatalogSnapshot.local` remains as a test fixture, not the product catalog path
- `client/lib/platform/router.dart` `/howto/alchiki` and `/match` wood placeholders remain 02-03 / 02-08

These stubs do not block AUTH-01 / CAT-01 / CAT-03 for this plan: a guest reaches server catalog tiles with no username wall.

## User Setup Required

None - no external service configuration required. Local DEV still uses Compose `postgres:18.6` and `--dart-define=NOMAD_API_URL` when the host is not the Android emulator default.

## Next Phase Readiness

Ready for 02-08 match client (`startMatch` / `submitThrow`) and remaining Wave 3/4 plans. Do not add shop, wallets UI, Glicko-2, Redis, or bind here.

## TDD Gate Compliance

- RED commit `052f086` `test(02-07): add failing test for catalog and splash mint` — CatalogIT 404 on missing `/v1/catalog`; guest_mint_test failed to compile without SessionStore / NomadApi
- GREEN commit `7dd0663` `feat(02-07): implement splash mint and server catalog` — CatalogIT + GuestIdentityIT + ModularityTest and Flutter mint/catalog/widget tests passed

## Self-Check: PASSED

- FOUND: CatalogService.java, CatalogController.java, CatalogIT.java, session_store.dart, nomad_api.dart, splash_page.dart, catalog_page.dart, guest_mint_test.dart, 02-07-SUMMARY.md
- FOUND: 052f086 test(02-07), 7dd0663 feat(02-07)

---
*Phase: 02-guest-catalog-first-alchiki-match*
*Completed: 2026-09-06*
