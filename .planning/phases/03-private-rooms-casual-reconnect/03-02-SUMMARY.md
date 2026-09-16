---
phase: 03-private-rooms-casual-reconnect
plan: 02
subsystem: matchmaking
tags: [rooms, create-room, lobby, share-plus, mode-01, d-26, d-28, d-39, d-40]

requires:
  - phase: 03-private-rooms-casual-reconnect
    provides: Session MatchStatus + GameEngine SPI (03-01); guest JWT mint
provides:
  - Flyway rooms table with UNIQUE code and idle_expires_at
  - POST /v1/rooms for authenticated guests returning roomId, 5-char code, Guest-XXXX, idleExpiresAt
  - Catalog Create room and Join by code CTAs (Play Alchiki + chips unchanged)
  - Host /lobby with Display-28 code, Share code, Copy code
affects:
  - Phase 3 join-by-code / Ready / host-alive (03-03, 03-04)
  - Catalog ARB keys for rematch, reconnect, and join errors

tech-stack:
  added:
    - share_plus 13.3.0
  patterns:
    - matchmaking Modulith package owns rooms; create does not call session.createPrivateMatch
    - 5-char codes from ABCDEFGHJKLMNPQRSTUVWXYZ23456789 with unique retry
    - Catalog private band is wood + cream outline, not accent

key-files:
  created:
    - backend/src/main/resources/db/migration/V3__rooms.sql
    - backend/src/main/java/com/nomadgames/matchmaking/RoomController.java
    - backend/src/main/java/com/nomadgames/matchmaking/RoomService.java
    - backend/src/main/java/com/nomadgames/matchmaking/RoomCreatedResponse.java
    - backend/src/main/java/com/nomadgames/matchmaking/internal/RoomEntity.java
    - backend/src/main/java/com/nomadgames/matchmaking/internal/RoomRepository.java
    - backend/src/test/java/com/nomadgames/matchmaking/RoomIT.java
    - client/lib/rooms/lobby_page.dart
  modified:
    - client/lib/catalog/catalog_page.dart
    - client/lib/platform/router.dart
    - client/lib/platform/api/nomad_api.dart
    - client/lib/l10n/app_en.arb
    - client/lib/l10n/app_ru.arb
    - client/pubspec.yaml
    - client/test/catalog_test.dart

key-decisions:
  - "Lobby shows the server code via /lobby?roomId=&code=&hostLabel= this plan; GET /v1/rooms/{id} waits for 03-03"
  - "Unique code collisions retry in a fresh TransactionTemplate so a doomed flush cannot poison the outer create"
  - "Leave lobby is hidden until 03-04; Ready is visible at 40% disabled until a joiner sits"

patterns-established:
  - "Pattern: RoomController copies MatchController JWT principal; guests allowed, host_id from jwt subject"
  - "Pattern: private catalog CTAs are outlined wood; Play Alchiki stays accent and still owns difficulty chips"

requirements-completed: [MODE-01]

coverage:
  - id: D1
    description: Guest POST /v1/rooms returns 201 with a 4–6 character Crockford-like code, Guest-XXXX hostLabel, and roomId
    requirement: MODE-01
    verification:
      - kind: integration
        ref: "backend/src/test/java/com/nomadgames/matchmaking/RoomIT.java#createReturnsCode"
        status: pass
    human_judgment: false
  - id: D2
    description: POST /v1/rooms without Bearer is 401
    requirement: MODE-01
    verification:
      - kind: integration
        ref: "backend/src/test/java/com/nomadgames/matchmaking/RoomIT.java#createWithoutBearerIsUnauthorized"
        status: pass
    human_judgment: false
  - id: D3
    description: Catalog shows Play Alchiki, Easy selected, Coming Soon x2, Create room, and Join by code
    requirement: MODE-01
    verification:
      - kind: unit
        ref: "client/test/catalog_test.dart#catalog home shows Alchiki playable and Coming Soon tiles"
        status: pass
      - kind: unit
        ref: "client/test/catalog_test.dart#catalog shows Create room and Join by code CTAs"
        status: pass
    human_judgment: false
  - id: D4
    description: Host lobby shows the server code with Share code and Copy code; no deep-link URL in share text
    requirement: MODE-01
    verification: []
    human_judgment: true
    rationale: "Widget tests cover catalog labels only; SharePlus sheet and Copied flash need a device/host path"
  - id: D5
    description: Room create does not start a match and does not apply difficulty chips; ModularityTest stays green
    requirement: MODE-01
    verification:
      - kind: integration
        ref: "backend/src/test/java/com/nomadgames/matchmaking/RoomIT.java#createReturnsCode"
        status: pass
      - kind: unit
        ref: "backend/src/test/java/com/nomadgames/ModularityTest.java#modulesShouldVerify"
        status: pass
    human_judgment: false
  - id: D6
    description: New 03-UI-SPEC player-facing strings exist as EN+RU ARB keys including rematchAgain, rejoinMatch, opponentWins, errorNoSuchRoom
    requirement: MODE-01
    verification:
      - kind: other
        ref: "client/lib/l10n/app_en.arb rematchAgain rejoinMatch opponentWins errorNoSuchRoom"
        status: pass
    human_judgment: false

duration: 8min
completed: 2026-09-07
status: complete
---

# Phase 3 Plan 02: Create Room + Shareable Code Summary

**Guest Create room persists a unique 5-char Crockford-like code and opens a host lobby with system Share and Copy (MODE-01)**

## Performance

- **Duration:** 8 min
- **Started:** 2026-09-07T07:47:33Z
- **Completed:** 2026-09-07T07:55:04Z
- **Tasks:** 2
- **Files modified:** 18

## Accomplishments

- `POST /v1/rooms` mints an authenticated guest room (`LOBBY`, 10-minute idle TTL) without starting a match
- Catalog adds Create room and Join by code as a wood band under the Alchiki tile; Play Alchiki + EASY/NORMAL/HARD chips stay bot-only
- Host `/lobby` shows the server code at Display 28, Share code (`share_plus` 13.3.0, no deep link), and Copy code with a 2s Copied flash

## Task Commits

Each task was committed atomically:

1. **Task 1: Failing create-room tests** - `fee61a8` (test)
2. **Task 2: POST /v1/rooms plus catalog Create room lobby** - `c0b942b` (feat)

**Plan metadata:** pending (this commit)

_Note: TDD tasks may have multiple commits (test → feat → refactor)_

## Files Created/Modified

- `backend/src/main/resources/db/migration/V3__rooms.sql` - rooms table with UNIQUE code and idle_expires_at
- `backend/src/main/java/com/nomadgames/matchmaking/RoomController.java` - POST /v1/rooms, Bearer JWT, 201
- `backend/src/main/java/com/nomadgames/matchmaking/RoomService.java` - 5-char alphabet, unique retry, Guest-XXXX
- `backend/src/main/java/com/nomadgames/matchmaking/RoomCreatedResponse.java` - roomId, code, hostLabel, idleExpiresAt
- `backend/src/main/java/com/nomadgames/matchmaking/internal/RoomEntity.java` - JPA rooms row
- `backend/src/main/java/com/nomadgames/matchmaking/internal/RoomRepository.java` - findByCode
- `backend/src/test/java/com/nomadgames/matchmaking/RoomIT.java` - createReturnsCode + unauthorized
- `client/lib/catalog/catalog_page.dart` - private CTA band, createRoom POST, errorRoomCreate
- `client/lib/rooms/lobby_page.dart` - host code, Share, Copy
- `client/lib/platform/router.dart` - /lobby and /join placeholder
- `client/lib/platform/api/nomad_api.dart` - createRoom
- `client/lib/l10n/app_en.arb` / `app_ru.arb` - 03-UI-SPEC keys
- `client/pubspec.yaml` - share_plus 13.3.0
- `client/test/catalog_test.dart` - Create room / Join by code assertions

## Decisions Made

- Lobby receives `code` and `hostLabel` as query params this plan so the host sees the server code without adding GET /v1/rooms/{id} (join/poll is 03-03)
- Unique-code retry uses `TransactionTemplate` so a unique-violation flush cannot mark the outer create rollback-only
- Leave lobby is hidden; Ready stays visible at 40% disabled (plan allowed until joiner/03-04)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] Pass code on the lobby query string**
- **Found during:** Task 2 (host lobby must show the server code)
- **Issue:** Plan navigates to `/lobby?roomId=` only and does not add GET /v1/rooms/{id}, so the lobby would have no code to display
- **Fix:** Create room goes to `/lobby?roomId=&code=&hostLabel=`; GET stays out of this plan
- **Files modified:** `client/lib/catalog/catalog_page.dart`, `client/lib/platform/router.dart`, `client/lib/rooms/lobby_page.dart`
- **Verification:** RoomIT + catalog_test green; lobby widget reads `code` from the route
- **Committed in:** `c0b942b`

---

**Total deviations:** 1 auto-fixed (1 missing critical)
**Impact on plan:** Needed so MODE-01 host path shows a real server code. No join/Ready/match start scope creep.

## Known Stubs

- `/join` is a wood Scaffold with `joinByCode` heading only — real field is 03-03 (plan-required placeholder)
- Lobby Ready is visible and disabled at 40% — joiner/Ready wiring is 03-03/03-04
- Leave lobby is hidden this plan (PLAN.md allowed hide or no-op)

## Issues Encountered

None

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Ready for 03-03 (join by code). Host create + shareable code is live; do not reopen Modulith cycle or Forge2D pins.

## Self-Check: PASSED

- V3__rooms.sql, RoomController, RoomService, RoomEntity, RoomRepository, catalog_page, lobby_page, RoomIT, catalog_test exist on disk
- Commits `fee61a8` (test) and `c0b942b` (feat) present on master
- RoomIT + ModularityTest BUILD SUCCESS; `flutter test test/catalog_test.dart` 5 passed

---
*Phase: 03-private-rooms-casual-reconnect*
*Completed: 2026-09-07*
