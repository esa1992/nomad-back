---
phase: 05-casual-quick-match-profile
plan: 06
subsystem: api
tags: [profile, soft-elo, xp, flyway, modulith, jwt]

requires:
  - phase: 05-casual-quick-match-profile
    provides: createCasualMatch + afterTerminal economy grants + Wave 0 ProfileIT stubs
  - phase: 04-economy-cosmetic-shop
    provides: economy.getLoadout + settle TX grants pattern
provides:
  - "GET /v1/profile Guest + Guest-XXXX + XP/W/L/soft rating + Stick Pull zeros"
  - "PUT /v1/profile/avatar allow-list avatar_01…08"
  - "ProfileService.recordSettlement from MatchService.afterTerminal (XP any mode; Elo CASUAL only)"
  - "Green ProfileIT + ModularityTest with profile package"
affects:
  - 05-07 Flutter profile UI
  - phase UAT PROF-01…03

tech-stack:
  added: []
  patterns:
    - "Classic SoftElo K=24 start 1000 floor 100; CASUAL PvP only"
    - "XP +12/+6/+4 any terminal; level via triangular 100*n*(n+1)/2"
    - "Sync profile settle after economy grants in afterTerminal (same TX)"
    - "Profile JSON field rating (soft MMR) + subtitle Guest-XXXX per ProfileIT / Q2 LOCKED"

key-files:
  created:
    - backend/src/main/resources/db/migration/V9__profile_casual.sql
    - backend/src/main/java/com/nomadgames/profile/SoftElo.java
    - backend/src/main/java/com/nomadgames/profile/internal/ProfileJdbc.java
    - backend/src/main/java/com/nomadgames/profile/ProfileService.java
    - backend/src/main/java/com/nomadgames/profile/ProfileController.java
  modified:
    - backend/src/main/java/com/nomadgames/identity/GuestService.java
    - backend/src/main/java/com/nomadgames/session/MatchService.java
    - backend/src/main/java/com/nomadgames/session/internal/MatchEntity.java
    - backend/src/test/java/com/nomadgames/profile/ProfileIT.java

key-decisions:
  - "API projection uses subtitle + rating to match Wave 0 ProfileIT (not guestSubtitle/softRating)"
  - "games map uses camelCase stickPull/alchiki with noMatchesYet; Stick Pull always present"
  - "Elo applied only when both seats newly claim profile_settlements in one call"

patterns-established:
  - "profile Modulith package: JdbcClient stats + EconomyService getLoadout read-only"
  - "Guest mint calls profile.ensureDefaults after economy.ensureDefaults"

requirements-completed: [PROF-01, PROF-02, PROF-03]

coverage:
  - id: D1
    description: "GET /v1/profile returns Guest + Guest-XXXX, avatar_01, level/XP, rating 1000, Stick Pull zeros"
    requirement: PROF-01
    verification:
      - kind: integration
        ref: "backend/.../ProfileIT.java#profileReturnsGuestDefaults"
        status: pass
    human_judgment: false
  - id: D2
    description: "Stick Pull stats always present with zeros / noMatchesYet"
    requirement: PROF-02
    verification:
      - kind: integration
        ref: "backend/.../ProfileIT.java#profileReturnsGuestDefaults"
        status: pass
    human_judgment: false
  - id: D3
    description: "PUT avatar allow-list avatar_01…08; unknown → 400"
    requirement: PROF-03
    verification:
      - kind: integration
        ref: "backend/.../ProfileIT.java#putAvatarAllowList"
        status: pass
    human_judgment: false
  - id: D4
    description: "XP increments on bot settle; soft rating unchanged"
    requirement: PROF-01
    verification:
      - kind: integration
        ref: "backend/.../ProfileIT.java#xpIncrementsOnBotSettleRatingUnchanged"
        status: pass
    human_judgment: false
  - id: D5
    description: "Soft Elo updates on CASUAL PvP settle only; private does not move rating"
    requirement: PROF-01
    verification:
      - kind: integration
        ref: "backend/.../ProfileIT.java#eloUpdatesOnCasualSettleOnly"
        status: pass
    human_judgment: false
  - id: D6
    description: "GET /v1/profile is self-only; no public by-id route (T-05-06)"
    requirement: PROF-01
    verification:
      - kind: integration
        ref: "backend/.../ProfileIT.java#profileSelfOnly"
        status: pass
    human_judgment: false

duration: 6min
completed: 2026-09-11
status: complete
---

# Phase 5 Plan 06: Backend Profile + XP/Elo Summary

**Server-authored guest profile with SoftElo (K=24), XP on any settle, Stick Pull zeros, and avatar allow-list — ProfileIT green**

## Performance

- **Duration:** 6 min
- **Started:** 2026-09-11T11:14:04Z
- **Completed:** 2026-09-11T11:20:00Z
- **Tasks:** 2
- **Files modified:** 9

## Accomplishments

- Flyway V9 adds avatar/XP/level/soft+best rating, `player_game_stats`, and idempotent `profile_settlements`
- `GET /v1/profile` projects Guest + Guest-XXXX, loadout cosmetics, Alchiki + Stick Pull stats; `PUT /v1/profile/avatar` allow-lists `avatar_01`…`08`
- `MatchService.afterTerminal` calls `ProfileService.recordSettlement` after economy grants (XP any mode; Elo CASUAL only)
- ProfileIT (5) + ModularityTest green; no Flutter profile UI (05-07)

## Task Commits

Each task was committed atomically:

1. **Task 1: V9 + SoftElo + ProfileJdbc + ProfileService core** - `9c1826b` (feat)
2. **Task 2: ProfileController + afterTerminal settle hook + ProfileIT green** - `560bf35` (feat)

**Plan metadata:** `f3a51ed` (docs: complete plan)

## Files Created/Modified

- `backend/src/main/resources/db/migration/V9__profile_casual.sql` - Profile columns + stats + settlements
- `backend/src/main/java/com/nomadgames/profile/SoftElo.java` - Classic Elo K=24 floor 100
- `backend/src/main/java/com/nomadgames/profile/internal/ProfileJdbc.java` - JdbcClient persistence
- `backend/src/main/java/com/nomadgames/profile/ProfileService.java` - get/setAvatar/recordSettlement/ensureDefaults
- `backend/src/main/java/com/nomadgames/profile/ProfileController.java` - REST self-JWT surface
- `backend/src/main/java/com/nomadgames/identity/GuestService.java` - mint ensures profile stats defaults
- `backend/src/main/java/com/nomadgames/session/MatchService.java` - settle hook after grants
- `backend/src/main/java/com/nomadgames/session/internal/MatchEntity.java` - public getGame()
- `backend/src/test/java/com/nomadgames/profile/ProfileIT.java` - stub comment → green contract

## Decisions Made

- Match Wave 0 ProfileIT JSON (`subtitle`, `rating`, `games.stickPull`) rather than plan sketch field names (`guestSubtitle`, `softRating`, games array)
- Elo only when both seats newly claim `profile_settlements` so retries cannot double-apply MMR

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] MatchEntity lacked getGame()**
- **Found during:** Task 2
- **Issue:** `recordProfileSettlements` needed game for stats row key; accessor missing
- **Fix:** Added public `getGame()`
- **Files modified:** `MatchEntity.java`
- **Verification:** ProfileIT + ModularityTest green
- **Committed in:** `560bf35`

## Threat Flags

None — settle writers and self-only GET/PUT match T-05-02/03/06; no new public by-id or client MMR body.

## Known Stubs

None — Flutter profile deferred to 05-07 by plan.

## Self-Check: PASSED

- FOUND: V9__profile_casual.sql, SoftElo.java, ProfileJdbc.java, ProfileService.java, ProfileController.java
- FOUND: commits 9c1826b, 560bf35
- FOUND: MatchService calls recordSettlement; ProfileIT methods pass
