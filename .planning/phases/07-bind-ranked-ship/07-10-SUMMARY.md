---
phase: 07-bind-ranked-ship
plan: 10
subsystem: auth
tags: [sign-in, logout, soft-lock, adopt, D-93, D-95, D-96, AUTH-03, AUTH-04, flutter]

requires:
  - phase: 07-bind-ranked-ship
    provides: POST /v1/identity/login adopt + logout mint guest (07-03)
  - phase: 07-bind-ranked-ship
    provides: Bind sheet chrome + Sign in instead entry (07-09)
provides:
  - "Profile Sign in sheet with D-93 adoptHint (import / replaceGuest drop)"
  - "Destructive Log out confirm → logout API → catalog (D-95)"
  - "Guest soft-lock sheets for Ranked CTA and Boards chip (D-96)"
affects:
  - 07-04 Ranked enqueue CTAs when bound
  - 07-05 Boards route when bound

tech-stack:
  added: []
  patterns:
    - "login probe with persist=false then adopt=import|drop before writing tokens"
    - "showSoftLockSheet → Bind now opens bind sheet; Casual/bot/private/shop stay open"
    - "logout persists server-minted guest session then context.go('/')"

key-files:
  created:
    - client/lib/profile/sign_in_sheet.dart
    - client/lib/catalog/soft_lock_sheet.dart
  modified:
    - client/lib/platform/api/nomad_api.dart
    - client/lib/platform/auth/bind_api.dart
    - client/lib/profile/profile_page.dart
    - client/lib/profile/bind_sheet.dart
    - client/lib/catalog/catalog_page.dart
    - client/lib/l10n/app_en.arb
    - client/lib/l10n/app_ru.arb
    - client/test/bind_sheet_test.dart

key-decisions:
  - "adopt=none probe never persists; DROP_REQUIRED → replaceGuest confirm then adopt=drop; IMPORT_ELIGIBLE offers Bind this guest vs Sign in anyway (drop)"
  - "Guest Ranked is wood outline CTA opening soft-lock; bound Ranked enqueue deferred to 07-04"
  - "Boards chip always visible; guest → soft-lock, bound route deferred to 07-05"

patterns-established:
  - "NomadApi.login(..., persist:) + GuestSession.importEligible/dropRequired from adoptHint"
  - "showSignInSheet / showLogOutConfirm / showSoftLockSheet modal helpers"
  - "catalog _onRankedTap / _onBoardsTap gate on SessionStore.isGuest()"

requirements-completed: [AUTH-03, AUTH-04]

coverage:
  - id: D1
    description: "Sign-in sheet shows signInTitle and Sign in CTA"
    requirement: AUTH-03
    verification:
      - kind: unit
        ref: "client/test/bind_sheet_test.dart#sign-in sheet shows signInTitle and Sign in CTA"
        status: pass
    human_judgment: false
  - id: D2
    description: "replaceGuest confirm uses replaceGuestTitle when DROP_REQUIRED"
    requirement: AUTH-03
    verification:
      - kind: unit
        ref: "client/test/bind_sheet_test.dart#replaceGuest confirm uses replaceGuestTitle"
        status: pass
    human_judgment: false
  - id: D3
    description: "Profile guest shows Sign in + guestBindHelper; bound shows Log out"
    requirement: AUTH-04
    verification:
      - kind: unit
        ref: "client/test/bind_sheet_test.dart#Profile always exposes Bind account for guests"
        status: pass
    human_judgment: false
  - id: D4
    description: "Soft-lock Ranked/Boards sheets use rankedLock* / boardsLock* and bindNow"
    requirement: AUTH-03
    verification:
      - kind: unit
        ref: "client/test/bind_sheet_test.dart#soft-lock Ranked uses rankedLockTitle and bindNow"
        status: pass
    human_judgment: false

duration: 5min
completed: 2026-09-14
status: complete
---

# Phase 07 Plan 10: Sign-in/out UI + Soft-lock Ranked/Boards Summary

**Flutter AUTH-03/04 Sign in / Log out with D-93 adopt probes and D-96 guest soft-lock on Ranked/Boards.**

## Performance

- **Duration:** 5 min (verify + SUMMARY; task commits from prior aborted run)
- **Started:** 2026-09-14T14:11:00Z
- **Completed:** 2026-09-14T14:13:00Z
- **Tasks:** 2
- **Files modified:** 12

## Accomplishments

- Profile wires Sign in sheet + destructive Log out confirm; logout persists minted guest and returns to catalog (D-95)
- Login follows server `adoptHint` — IMPORT_ELIGIBLE / DROP_REQUIRED confirm paths; never silent wallet sum (D-93)
- Catalog guest Ranked CTA and Boards chip open soft-lock Bind now sheets; Casual/bot/private/shop stay open (D-96)

## Task Commits

Each task was committed atomically:

1. **Task 1: Sign in / Log out UI wired to adopt contract** - `21a86d2` (feat)
2. **Task 2: Guest soft-lock Ranked/Boards** - `be95280` (feat)

**Plan metadata:** `1ae8f44` (docs: complete plan)

## Files Created/Modified

- `client/lib/profile/sign_in_sheet.dart` - Sign in sheet + Log out confirm + adopt panels
- `client/lib/catalog/soft_lock_sheet.dart` - D-96 Ranked/Boards soft-lock sheet
- `client/lib/platform/api/nomad_api.dart` - login/logout + adoptHint on GuestSession
- `client/lib/platform/auth/bind_api.dart` - login/logout wrappers
- `client/lib/profile/profile_page.dart` - guest Sign in / bound Log out chrome
- `client/lib/profile/bind_sheet.dart` - Sign in instead → showSignInSheet
- `client/lib/catalog/catalog_page.dart` - guest Ranked/Boards soft-lock gates
- `client/lib/l10n/app_en.arb` / `app_ru.arb` (+ generated) - sign-in/logout/soft-lock copy
- `client/test/bind_sheet_test.dart` - sign-in, replaceGuest, soft-lock, Profile Log out

## Decisions Made

- Probe login with `persist: false` before writing tokens so DROP_REQUIRED can confirm without binding the session
- Soft-lock sheet chrome shipped with Task 1; Task 2 only wired catalog CTAs (same outcome as plan)
- Bound Ranked enqueue and `/boards` navigation remain stubs for 07-04 / 07-05

## Deviations from Plan

### Auto-fixed Issues

None - plan executed as written (task commits recovered from aborted run; verification re-run green).

**Note:** `soft_lock_sheet.dart` landed in Task 1 commit `21a86d2` ahead of Task 2 file list; Task 2 `be95280` wired catalog only. No behavior gap.

## TDD Gate Compliance

- Plan `tdd="true"`; tests and implementation landed together in feat commits (config-style match to 07-09)
- No separate `test(...)` RED commit — green coverage verified via `flutter test test/bind_sheet_test.dart` (10/10 pass)

## Threat Mitigations

| Threat | Disposition | Evidence |
|--------|-------------|----------|
| T-07-11 Elevation (guest Ranked via UI) | mitigate | Soft-lock UX; server 403 still 07-04 |
| T-07-31 Elevation (client-forced adopt=import) | mitigate | UI follows adoptHint; import only after IMPORT_ELIGIBLE; server rejects import_not_eligible |

## Known Stubs

- Bound Ranked tap is no-op until 07-04 ranked_api enqueue
- Bound Boards tap is no-op until 07-05 `/boards` route

## Self-Check: PASSED

- FOUND: `client/lib/profile/sign_in_sheet.dart`
- FOUND: `client/lib/catalog/soft_lock_sheet.dart`
- FOUND: `client/lib/catalog/catalog_page.dart` (soft-lock gates)
- FOUND: commit `21a86d2`
- FOUND: commit `be95280`
