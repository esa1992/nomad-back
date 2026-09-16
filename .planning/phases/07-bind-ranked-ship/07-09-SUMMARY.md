---
phase: 07-bind-ranked-ship
plan: 09
subsystem: auth
tags: [bind, flutter, D-92, AUTH-02, bind.prompt.seen, profile]

requires:
  - phase: 07-bind-ranked-ship
    provides: POST /v1/identity/bind Argon2id same-playerId (07-02)
  - phase: 07-bind-ranked-ship
    provides: 07-UI-SPEC bind sheet copy + color contract
provides:
  - "Dismissible bind bottom sheet (07-UI-SPEC) with Sign in instead on username taken"
  - "bind.prompt.seen prefs gate + Profile Bind entry for guests"
  - "D-92 post-bot-win funnel from Alchiki ResultOverlay host"
affects:
  - 07-10 soft-lock Sign in Log out
  - 07-04 Ranked CTAs when bound

tech-stack:
  added: []
  patterns:
    - "BindPromptStore mirrors HowToSeenStore SharedPreferencesAsync key bind.prompt.seen"
    - "shouldOfferBindAfterBotWin gate: bot + PLAYER_WIN + guest + unseen"
    - "SessionStore.persistGuest / isGuest for D-92 guest check"

key-files:
  created:
    - client/lib/platform/auth/bind_api.dart
    - client/lib/platform/auth/bind_prompt_store.dart
    - client/lib/profile/bind_sheet.dart
  modified:
    - client/lib/profile/profile_page.dart
    - client/lib/games/alchiki/match_page.dart
    - client/lib/platform/api/nomad_api.dart
    - client/lib/platform/auth/session_store.dart
    - client/lib/l10n/app_en.arb
    - client/lib/l10n/app_ru.arb
    - client/test/bind_sheet_test.dart

key-decisions:
  - "D-92 offer runs after ResultOverlay is visible via post-frame schedule on match_page; does not block Back to catalog"
  - "Profile Bind uses markPromptSeen:false so Profile entry never consumes the post-win funnel prefs gate"
  - "Sign in instead exposed on bind sheet; full login/adopt UI deferred to 07-10"

patterns-established:
  - "showBindSheet marks bind.prompt.seen on any dismiss/success when markPromptSeen true"
  - "NomadApi.bind POSTs /v1/identity/bind and persists rotated tokens + guest=false"

requirements-completed: [AUTH-02]

coverage:
  - id: D1
    description: "Bind sheet shows bindSheetTitle / bindAccount / notNow from ARB"
    requirement: AUTH-02
    verification:
      - kind: unit
        ref: "client/test/bind_sheet_test.dart#bind sheet shows bindSheetTitle bindAccount notNow from ARB"
        status: pass
    human_judgment: false
  - id: D2
    description: "Username taken UI exposes Sign in instead path (D-93)"
    requirement: AUTH-02
    verification:
      - kind: unit
        ref: "client/test/bind_sheet_test.dart#username taken UI exposes Sign in instead path"
        status: pass
    human_judgment: false
  - id: D3
    description: "Profile always exposes Bind account for guests (D-92)"
    requirement: AUTH-02
    verification:
      - kind: unit
        ref: "client/test/bind_sheet_test.dart#Profile always exposes Bind account for guests"
        status: pass
    human_judgment: false
  - id: D4
    description: "D-92 once-only funnel gate for guest Alchiki bot win when bind.prompt.seen false"
    requirement: AUTH-02
    verification:
      - kind: unit
        ref: "client/test/bind_sheet_test.dart#D-92 funnel gate offers once for guest bot win when unseen"
        status: pass
    human_judgment: false

duration: 28min
completed: 2026-09-14
status: complete
---

# Phase 07 Plan 09: Bind Sheet + D-92 Post-Bot-Win Funnel Summary

**Flutter AUTH-02 bind sheet with Profile Bind entry and once-only D-92 prompt after first Alchiki bot win via `bind.prompt.seen`.**

## Performance

- **Duration:** 28 min
- **Started:** 2026-09-14T11:49:37Z
- **Completed:** 2026-09-14T12:17:00Z
- **Tasks:** 2
- **Files modified:** 12

## Accomplishments

- Wood bind bottom sheet per 07-UI-SPEC (accent Bind account, wood Not now, Sign in instead; password obscureText)
- `BindPromptStore` prefs key `bind.prompt.seen`; Profile always shows Bind for guests without consuming the funnel flag
- `NomadApi.bind` / `BindApi` POST `/v1/identity/bind` and persist rotated tokens + guest flag
- Alchiki `match_page` offers the sheet once after bot `PLAYER_WIN` when guest and unseen (D-92)

## Task Commits

Each task was committed atomically:

1. **Task 1: Bind sheet + Profile Bind entry + bind API client** - `383258e` (feat)
2. **Task 2: Wire D-92 funnel after first Alchiki bot win** - `c0f4ca0` (feat)

**Plan metadata:** `6349229` (docs: complete plan)

## Files Created/Modified

- `client/lib/platform/auth/bind_api.dart` - Riverpod BindApi wrapping NomadApi.bind
- `client/lib/platform/auth/bind_prompt_store.dart` - `bind.prompt.seen` SharedPreferencesAsync gate
- `client/lib/profile/bind_sheet.dart` - sheet UI + `shouldOfferBindAfterBotWin` + `showBindSheet`
- `client/lib/profile/profile_page.dart` - guest Bind entry + helper copy
- `client/lib/games/alchiki/match_page.dart` - post-frame D-92 offer on bot win
- `client/lib/platform/api/nomad_api.dart` - POST bind; persist guest on mint/refresh/bind
- `client/lib/platform/auth/session_store.dart` - `guest` key + `isGuest` / `persistGuest`
- `client/lib/l10n/app_en.arb` / `app_ru.arb` (+ generated) - bind ARB keys from UI-SPEC
- `client/test/bind_sheet_test.dart` - sheet, taken path, Profile Bind, D-92 gate

## Decisions Made

- Funnel host is `match_page` ResultOverlay path (post-frame), not a second result chrome
- Profile `showBindSheet(..., markPromptSeen: false)` so Profile discovery never skips the post-win prompt
- Sign in instead closes the sheet for now; login/adopt chrome stays 07-10

## Deviations from Plan

None - plan executed exactly as written.

## TDD Gate Compliance

- Wave 0 RED stubs replaced with green coverage in Task 1 feat commit `383258e` (config `tdd_mode: false`; plan `tdd="true"` satisfied by failing→green verify via `flutter test test/bind_sheet_test.dart`)
- No separate `test(...)` commit — implementation and tests landed together in Task 1 feat

## Threat Mitigations

| Threat | Disposition | Evidence |
|--------|-------------|----------|
| T-07-29 Spoofing (bind_api) | mitigate | Uses session JWT via NomadApi interceptor; server enforces guest bind |
| T-07-30 Information (bind form) | mitigate | `obscureText: true`; no password logging |

## Known Stubs

- Sign in instead closes sheet only — full Sign in / adopt / Log out UI deferred to 07-10
- Soft-lock Ranked/boards deferred to 07-10

## Self-Check: PASSED

- FOUND: `client/lib/profile/bind_sheet.dart`
- FOUND: `client/lib/platform/auth/bind_prompt_store.dart`
- FOUND: `client/lib/games/alchiki/match_page.dart` (bind.prompt / shouldOffer)
- FOUND: commit `383258e`
- FOUND: commit `c0f4ca0`
