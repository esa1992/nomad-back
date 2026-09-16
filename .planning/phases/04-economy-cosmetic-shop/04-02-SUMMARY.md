---
phase: 04-economy-cosmetic-shop
plan: 02
subsystem: economy
tags: [match-rewards, jdbcclient, result-overlay, idempotency, spring-modulith]

requires:
  - phase: 04-economy-cosmetic-shop
    provides: EconomyService wallet + WalletLedgerJdbc (04-01)
  - phase: 04-economy-cosmetic-shop
    provides: rewardCoins/rewardGems ARB + /shop route (04-06)
provides:
  - "Sync grantMatchRewards inside MatchService settle TX (D-45)"
  - "MatchSnapshot coinsGranted/gemsGranted + MatchSettled grants map"
  - "ResultOverlay reward lines + secondary Shop link (D-46)"
  - "EconomyIT matchGrantIdempotent + leaveAndDropGrant green"
affects:
  - 04-03 shop catalog spend loop
  - 04-04 soft purchases
  - 04-05 equip/loadout on match create

tech-stack:
  added: []
  patterns:
    - "afterTerminal grants all paid seats then snapshot; ON CONFLICT DO NOTHING for Postgres-safe idempotency"
    - "session → economy one-way MatchRewardCommand; no async-only listener for overlay grants"

key-files:
  created:
    - backend/src/main/java/com/nomadgames/economy/MatchRewardTable.java
    - backend/src/main/java/com/nomadgames/economy/MatchRewardCommand.java
    - backend/src/main/java/com/nomadgames/economy/RewardGrant.java
    - client/test/result_reward_test.dart
  modified:
    - backend/src/main/java/com/nomadgames/economy/EconomyService.java
    - backend/src/main/java/com/nomadgames/economy/internal/WalletLedgerJdbc.java
    - backend/src/main/java/com/nomadgames/session/MatchService.java
    - backend/src/main/java/com/nomadgames/session/MatchSnapshot.java
    - backend/src/test/java/com/nomadgames/economy/EconomyIT.java
    - client/lib/games/alchiki/pause_overlay.dart
    - client/lib/games/alchiki/match_page.dart
    - client/lib/platform/api/nomad_api.dart

key-decisions:
  - "Ledger insert uses ON CONFLICT DO NOTHING (not catch DuplicateKeyException) so Postgres does not abort the settle TX"
  - "MatchSettled carries grants map; REST MatchSnapshot keeps viewer coinsGranted/gemsGranted"
  - "Result Shop pops to catalog then pushes /shop so remount refreshes WalletChip (D-48)"

patterns-established:
  - "MatchService.afterTerminal / terminalGrants for every terminal settle path"
  - "MatchRewardTable hash(matchId,playerId)%100 for scarce win-only GEMS"

requirements-completed: [ECON-01, ECON-04]

coverage:
  - id: D1
    description: "Bot win settle returns coinsGranted > 0; replay leave does not double-credit wallet"
    requirement: ECON-01
    verification:
      - kind: integration
        ref: "backend/.../EconomyIT.java#matchGrantIdempotent"
        status: pass
    human_judgment: false
  - id: D2
    description: "Leave while IN_PLAY and reconnect-expiry settle each grant eligible seats"
    requirement: ECON-01
    verification:
      - kind: integration
        ref: "backend/.../EconomyIT.java#leaveAndDropGrant"
        status: pass
    human_judgment: false
  - id: D3
    description: "ResultOverlay shows +N COINS / optional GEMS and secondary Shop; rematch CTAs stay primary"
    requirement: ECON-01
    verification:
      - kind: automated_ui
        ref: "client/test/result_reward_test.dart"
        status: pass
    human_judgment: false
  - id: D4
    description: "ThrowAuthorityIT + ModularityTest still green after session→economy grant wiring"
    requirement: ECON-04
    verification:
      - kind: integration
        ref: "ThrowAuthorityIT,ModularityTest"
        status: pass
    human_judgment: false

duration: 15min
completed: 2026-09-10
status: complete
---

# Phase 4 Plan 02: Sync Match Grants + ResultOverlay Rewards Summary

**Server grants COINS/GEMS synchronously on every terminal settle path and surfaces them on ResultOverlay without a blocking wallet screen.**

## Performance

- **Duration:** 15 min
- **Started:** 2026-09-10T13:51:00+06:00
- **Completed:** 2026-09-10T14:06:00+06:00
- **Tasks:** 2
- **Files modified:** 12

## Accomplishments

- Wired `EconomyService.grantMatchRewards` + `MatchRewardTable` (win > loss COINS; scarce win-only GEMS) with idempotent ledger keys
- `MatchService.afterTerminal` on leave / throw / private throw / reconnect-expiry; `MatchSnapshot` viewer grant fields; `MatchSettled.grants` map
- `ResultOverlay` reward lines + secondary Shop; rematch CTAs unchanged; catalog remount path for D-48

## Task Commits

1. **Task 1: Failing grant ITs + result_reward_test** - `6831928` (test)
2. **Task 2: Sync grant in settle TX + ResultOverlay lines** - `319dc31` (feat)

**Plan metadata:** `be2a1c8` (docs: complete plan)

## Files Created/Modified

- `MatchRewardTable.java` / `MatchRewardCommand.java` / `RewardGrant.java` — reward constants + economy command types
- `EconomyService.java` / `WalletLedgerJdbc.java` — sync grant + ON CONFLICT credit
- `MatchService.java` / `MatchSnapshot.java` — afterTerminal + grant fields + WS grants map
- `pause_overlay.dart` / `match_page.dart` / `nomad_api.dart` — overlay rewards + Shop + parse grants
- `EconomyIT.java` / `result_reward_test.dart` — ECON-01 coverage

## Decisions Made

- ON CONFLICT DO NOTHING instead of catch-DuplicateKeyException (Postgres TX abort)
- Grants map on MatchSettled; viewer fields on REST snapshot
- Shop from result: `go('/')` then `push('/shop')` for wallet chip refresh

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Postgres aborts TX on DuplicateKeyException catch path**
- **Found during:** Task 2 verify (`leaveAndDropGrant` / idempotent replay)
- **Issue:** Catching unique-violation after failed INSERT left the settle TX aborted; subsequent SELECT failed
- **Fix:** Pre-check + `INSERT ... ON CONFLICT (idempotency_key) DO NOTHING` via `creditIfAbsent`
- **Files modified:** `WalletLedgerJdbc.java`, `EconomyService.java`
- **Commit:** `319dc31`

## TDD Gate Compliance

- RED: `6831928` — failing EconomyIT grant methods + result_reward_test compile fail
- GREEN: `319dc31` — grant wiring + overlay; EconomyIT/ThrowAuthorityIT/ModularityTest + flutter tests green

## Known Stubs

None that block ECON-01 overlay rewards. Shop shelf/purchase remain later plans (04-03/04-04).

## Threat Flags

None beyond plan register (T-04-05/T-04-06 mitigated by server-only grants + UNIQUE idempotency_key).

## Self-Check: PASSED

- FOUND: MatchRewardTable.java, MatchService grantMatchRewards/afterTerminal, MatchSnapshot coinsGranted, pause_overlay rewardCoins, result_reward_test.dart
- FOUND: commits 6831928, 319dc31
