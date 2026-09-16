---
phase: 05-casual-quick-match-profile
plan: 01
subsystem: testing
tags: [nyquist, wave0, matchmaking, profile, rematch, reconnect, flutter_test, testcontainers]

requires:
  - phase: 03-private-rooms-casual-reconnect
    provides: RoomIT / RematchIT / ReconnectIT harness patterns; PRIVATE rematch + 30s rejoin
  - phase: 04-economy-cosmetic-shop
    provides: EconomyIT mint + bot settle + MatchRewardTable human/private grant path
provides:
  - "Wave 0 RED CasualQueueIT locking MODE-03 pair/dequeue/rate-limit/IN_PLAY/settle grants"
  - "Wave 0 RED ProfileIT locking PROF-01…03 + XP vs Elo + self-only"
  - "Wave 0 RED CasualRematchIT locking MODE-05 CASUAL dual-accept + seat check"
  - "Wave 0 RED ReconnectIT.casualRejoinWithinGrace locking SESS-02 for CASUAL"
  - "Wave 0 RED Flutter stubs for Searching/fallback/profile/rematch-wait/catalog Quick Match"
affects:
  - 05-02 casual queue + createCasualMatch
  - 05-03 Searching UI
  - 05-04 fallback CTAs
  - 05-05 casual rematch
  - 05-06 profile backend
  - 05-07 profile UI

tech-stack:
  added: []
  patterns:
    - "Wave 0 Nyquist stubs call future endpoints with andExpect success → RED 404 until later plans"
    - "Client Wave 0 pumps NomadApp at future routes and asserts 05-UI-SPEC EN copy"

key-files:
  created:
    - backend/src/test/java/com/nomadgames/matchmaking/CasualQueueIT.java
    - backend/src/test/java/com/nomadgames/profile/ProfileIT.java
    - backend/src/test/java/com/nomadgames/session/CasualRematchIT.java
    - client/test/matchmaking_test.dart
    - client/test/profile_page_test.dart
    - client/test/casual_rematch_test.dart
  modified:
    - backend/src/test/java/com/nomadgames/session/ReconnectIT.java
    - client/test/catalog_test.dart

key-decisions:
  - "Wave 0 only — no CasualQueueService, ProfileService, createCasualMatch, or Flutter QM/profile UI"
  - "Casual rematch/rejoin stubs pair via POST /v1/matchmaking/casual so they stay RED until 05-02"
  - "ProfileIT bot settle uses full CreateMatchRequest body (game/mode/difficulty) matching EconomyIT"

patterns-established:
  - "CasualQueueIT / ProfileIT / CasualRematchIT copy RoomIT/EconomyIT/RematchIT SpringBootTest + postgres:18"
  - "ReconnectIT.bothReadyCasual mirrors bothReady but expects mode CASUAL"

requirements-completed: [MODE-03, MODE-05, SESS-02, PROF-01, PROF-02, PROF-03]

coverage:
  - id: D1
    description: "CasualQueueIT method names lock MODE-03 queue contracts (RED until 05-02)"
    requirement: MODE-03
    verification:
      - kind: integration
        ref: "backend/.../CasualQueueIT.java#twoPlayersPair"
        status: fail
    human_judgment: false
  - id: D2
    description: "ProfileIT locks PROF-01…03 guest defaults + avatar allow-list + self-only (RED until 05-06)"
    requirement: PROF-01
    verification:
      - kind: integration
        ref: "backend/.../ProfileIT.java#profileReturnsGuestDefaults"
        status: fail
    human_judgment: false
  - id: D3
    description: "CasualRematchIT locks MODE-05 CASUAL dual-accept (RED until 05-05)"
    requirement: MODE-05
    verification:
      - kind: integration
        ref: "backend/.../CasualRematchIT.java#casualRematchCreatesCasualMatch"
        status: fail
    human_judgment: false
  - id: D4
    description: "ReconnectIT.casualRejoinWithinGrace locks SESS-02 for CASUAL (RED until 05-02)"
    requirement: SESS-02
    verification:
      - kind: integration
        ref: "backend/.../ReconnectIT.java#casualRejoinWithinGrace"
        status: fail
    human_judgment: false
  - id: D5
    description: "Flutter Wave 0 stubs lock Searching/fallback/profile/rematch-wait/catalog CTAs (RED)"
    requirement: MODE-03
    verification:
      - kind: automated_ui
        ref: "client/test/matchmaking_test.dart#fallbackAfterEightSeconds"
        status: fail
    human_judgment: false

duration: 16min
completed: 2026-09-11
status: complete
---

# Phase 5 Plan 01: Wave 0 Nyquist RED Stubs Summary

**Failing IT/widget stubs lock MODE-03 queue, MODE-05 casual rematch, SESS-02 CASUAL rejoin, and PROF-01…03 before any production QM/profile code.**

## Performance

- **Duration:** 16 min
- **Started:** 2026-09-11T10:12:33Z
- **Completed:** 2026-09-11T10:28:55Z
- **Tasks:** 2/2
- **Files modified:** 8

## Accomplishments

- Backend Wave 0: `CasualQueueIT`, `ProfileIT`, `CasualRematchIT`, plus `ReconnectIT.casualRejoinWithinGrace`
- Client Wave 0: `matchmaking_test`, `profile_page_test`, `casual_rematch_test`, and catalog Quick Match / Open profile assertions
- Targeted Surefire (20 tests, 14 failures) and Flutter (+5/-9) stays RED as required — no production controllers/services/routes shipped

## Task Commits

| Task | Commit | Description |
|------|--------|-------------|
| 1 | `c02b822` | test(05-01): add backend Wave 0 RED IT stubs |
| 2 | `2b7ccdd` | test(05-01): add client Wave 0 RED widget stubs |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] ProfileIT bot create body**
- **Found during:** Task 1 verify (`xpIncrementsOnBotSettleRatingUnchanged`)
- **Issue:** `POST /v1/matches` with only `difficulty` returned 400; EconomyIT uses `game`/`mode`/`difficulty`
- **Fix:** Matched EconomyIT `CreateMatchRequest` JSON so the stub fails at GET `/v1/profile` (404) instead of create
- **Files modified:** `ProfileIT.java`
- **Commit:** `c02b822`

## Auth Gates

None.

## Known Stubs

Intentional Wave 0 RED only — no production stubs. Later plans must green:

| Stub | File | Reason |
|------|------|--------|
| `/v1/matchmaking/casual` missing | CasualQueueIT / CasualRematchIT / ReconnectIT | Greens in 05-02 |
| `/v1/profile` missing | ProfileIT | Greens in 05-06 |
| Searching / fallback / profile / rematch-wait UI | client Wave 0 tests | Greens in 05-03…05-07 |

## Threat Flags

None — stubs only; no new runtime surfaces. Threat register mitigations remain as RED method names (T-05-01…T-05-06).

## Self-Check: PASSED

- FOUND: `backend/src/test/java/com/nomadgames/matchmaking/CasualQueueIT.java` (twoPlayersPair, enqueueRateLimited, casualSettleGrantsMatchPrivatePath)
- FOUND: `backend/src/test/java/com/nomadgames/profile/ProfileIT.java` (profileReturnsGuestDefaults, eloUpdatesOnCasualSettleOnly)
- FOUND: `backend/src/test/java/com/nomadgames/session/CasualRematchIT.java` (casualRematchCreatesCasualMatch)
- FOUND: `backend/src/test/java/com/nomadgames/session/ReconnectIT.java` (casualRejoinWithinGrace)
- FOUND: `client/test/matchmaking_test.dart` (fallbackAfterEightSeconds / playVsBot)
- FOUND: `client/test/profile_page_test.dart` (noMatchesYet / Stick Pull)
- FOUND: `client/test/casual_rematch_test.dart` (rematch-wait / rematchWaitingTitle EN)
- FOUND: `client/test/catalog_test.dart` (Quick Match)
- FOUND commits: `c02b822`, `2b7ccdd`
