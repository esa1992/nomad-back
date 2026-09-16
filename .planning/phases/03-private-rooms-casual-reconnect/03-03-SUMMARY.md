---
phase: 03-private-rooms-casual-reconnect
plan: 03
subsystem: matchmaking
tags: [rooms, join-by-code, lobby, rate-limit, mode-02, d-32, d-33, d-40]

requires:
  - phase: 03-private-rooms-casual-reconnect
    provides: POST /v1/rooms create + host /lobby code chrome (03-02); guest JWT mint
provides:
  - POST /v1/rooms/join sitting a second guest in LOBBY without starting a match
  - GET /v1/rooms/{id} seat-gated snapshot that omits code for the joiner
  - /join page that keeps typed characters on 404/409/410
  - Lobby Guest-XXXX rows with 1s poll
affects:
  - Phase 3 both-Ready / host-alive close (03-04)
  - Private match start must not happen on join (D-27)

tech-stack:
  added: []
  patterns:
    - JoinRateLimiter copies GuestMintRateLimiter (ConcurrentHashMap + 1-minute window + 20/min)
    - Join errors stay on /join with destructive field outline (D-32)
    - Lobby snapshot omits code for the joiner (D-28)

key-files:
  created:
    - backend/src/main/java/com/nomadgames/matchmaking/internal/JoinRateLimiter.java
    - backend/src/main/java/com/nomadgames/matchmaking/JoinRoomRequest.java
    - backend/src/main/java/com/nomadgames/matchmaking/RoomLobbyResponse.java
    - client/lib/rooms/join_page.dart
    - client/test/join_code_test.dart
  modified:
    - backend/src/main/java/com/nomadgames/matchmaking/RoomController.java
    - backend/src/main/java/com/nomadgames/matchmaking/RoomService.java
    - backend/src/main/java/com/nomadgames/matchmaking/internal/RoomEntity.java
    - backend/src/main/resources/application.yaml
    - backend/src/test/java/com/nomadgames/matchmaking/RoomIT.java
    - client/lib/platform/api/nomad_api.dart
    - client/lib/platform/router.dart
    - client/lib/rooms/lobby_page.dart

key-decisions:
  - "Joiner POST/GET omits code via Jackson NON_NULL on the code field so host-only chrome is server-owned (D-28)"
  - "JoinRateLimiter checks both client IP and playerId at nomad.rooms.join-limit-per-minute default 20"
  - "Same joiner re-POST is idempotent 200; a different occupant is 409; host joining own code is 400"
  - "Host lobby chrome uses presence of code in the snapshot (plus create-room query fallback); Ready stays 40% disabled until 03-04"

patterns-established:
  - "Pattern: join spray is in-process like guest mint — no Redis/Bucket4j"
  - "Pattern: 404/409/410 map to errorNoSuchRoom / errorAlreadyStarted / errorHostLeft and never pop /join"

requirements-completed: [MODE-02]

coverage:
  - id: D1
    description: Second guest POST /v1/rooms/join sits in LOBBY with joinerLabel Guest-XXXX and no matchId
    requirement: MODE-02
    verification:
      - kind: integration
        ref: "backend/src/test/java/com/nomadgames/matchmaking/RoomIT.java#joinByCodeSitsInLobby"
        status: pass
    human_judgment: false
  - id: D2
    description: Unknown code ZZZZZ returns 404; STARTED is 409; CLOSED is 410
    requirement: MODE-02
    verification:
      - kind: integration
        ref: "backend/src/test/java/com/nomadgames/matchmaking/RoomIT.java#joinUnknownCodeIs404"
        status: pass
      - kind: integration
        ref: "backend/src/test/java/com/nomadgames/matchmaking/RoomIT.java#joinStartedRoomIs409"
        status: pass
      - kind: integration
        ref: "backend/src/test/java/com/nomadgames/matchmaking/RoomIT.java#joinClosedRoomIs410"
        status: pass
    human_judgment: false
  - id: D3
    description: GET /v1/rooms/{id} as joiner omits code; host GET still includes it
    requirement: MODE-02
    verification:
      - kind: integration
        ref: "backend/src/test/java/com/nomadgames/matchmaking/RoomIT.java#joinByCodeSitsInLobby"
        status: pass
    human_judgment: false
  - id: D4
    description: /join keeps typed K7M4Q after 404 No such room, 409 already started, and 410 Host left
    requirement: MODE-02
    verification:
      - kind: unit
        ref: "client/test/join_code_test.dart#404 keeps No such room and typed code"
        status: pass
      - kind: unit
        ref: "client/test/join_code_test.dart#409 keeps already started and typed code"
        status: pass
      - kind: unit
        ref: "client/test/join_code_test.dart#410 keeps Host left and typed code"
        status: pass
    human_judgment: false
  - id: D5
    description: Catalog Play Alchiki + chips and Create room / Join by code CTAs still present
    requirement: MODE-02
    verification:
      - kind: unit
        ref: "client/test/catalog_test.dart#catalog home shows Alchiki playable and Coming Soon tiles"
        status: pass
    human_judgment: false

duration: 10min
completed: 2026-09-07
status: complete
---

# Phase 3 Plan 03: Join by Code Summary

**Second guest joins a LOBBY room by 4–6 character code; 404/409/410 keep the field; seats are Guest-XXXX**

## Performance

- **Duration:** 10 min
- **Started:** 2026-09-07T07:57:33Z
- **Completed:** 2026-09-07T08:08:00Z
- **Tasks:** 2
- **Files modified:** 14

## Accomplishments

- `POST /v1/rooms/join` mints no match: status stays `LOBBY`, `matchId` stays null, `joinerLabel` is `Guest-` plus last four `playerId` hex chars (MODE-02, D-33, D-27)
- Join errors: missing code 404, STARTED or occupied seat 409, CLOSED 410 `host left`; code normalize is trim + uppercase + length 4–6 (D-40)
- `GET /v1/rooms/{id}` is 403 unless the JWT subject is host or joiner; joiner responses omit `code` (D-28, T-03-09)
- `/join` keeps the typed characters and route on 404/409/410 with destructive outline (D-32)
- Host lobby still shows Share/Copy/code; after poll it shows the joiner Guest-XXXX row. Ready stays 40% disabled (03-04)

## Task Commits

Each task was committed atomically:

1. **Task 1: Failing join-by-code tests** - `50490b5` (test)
2. **Task 2: Join REST, rate limit, /join page, lobby seats** - `5a74db2` (feat)

**Plan metadata:** pending (this commit)

_Note: TDD tasks used RED then GREEN (test → feat)._

## Files Created/Modified

- `backend/src/main/java/com/nomadgames/matchmaking/RoomController.java` - POST `/join` and GET `/{id}`
- `backend/src/main/java/com/nomadgames/matchmaking/RoomService.java` - join normalize, seats, lobby snapshot
- `backend/src/main/java/com/nomadgames/matchmaking/internal/JoinRateLimiter.java` - 20/min per IP and playerId
- `backend/src/main/java/com/nomadgames/matchmaking/JoinRoomRequest.java` - join body `{ code }`
- `backend/src/main/java/com/nomadgames/matchmaking/RoomLobbyResponse.java` - lobby snapshot; code omitted when null
- `backend/src/main/java/com/nomadgames/matchmaking/internal/RoomEntity.java` - joiner/status accessors
- `backend/src/main/resources/application.yaml` - `nomad.rooms.join-limit-per-minute: 20`
- `backend/src/test/java/com/nomadgames/matchmaking/RoomIT.java` - join 200/404/409/410 and joiner GET omits code
- `client/lib/rooms/join_page.dart` - code field, Join room, D-32 errors
- `client/lib/rooms/lobby_page.dart` - 1s GET poll, host-only code chrome, Guest rows
- `client/lib/platform/router.dart` - `/join` → JoinPage
- `client/lib/platform/api/nomad_api.dart` - `joinRoom` / `getRoom` with statusCode
- `client/test/join_code_test.dart` - 404/409/410 field persistence

## Decisions Made

- Joiner snapshot omits `code` with Jackson `@JsonInclude(NON_NULL)` on that field only so `matchId: null` still serializes for RoomIT
- Rate limit keys both IP (`X-Forwarded-For` or remote addr) and `playerId` (T-03-08 / PITFALLS 9)
- Same player joining again is 200 with the current snapshot; another guest hitting a filled seat is 409
- Host chrome is “code present in snapshot or create-room query”, not a new `hostId` field — matches D-28 host-only code
- Ready is still a disabled 40% button; no Ready POST and no match create on join

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] Acceptance string `rooms/join` on RoomController**
- **Found during:** Task 2 acceptance gate
- **Issue:** Mapping is `@PostMapping("/join")` under `@RequestMapping("/v1/rooms")`, so a literal `rooms/join` grep would fail
- **Fix:** Documented `POST /v1/rooms/join` on the handler
- **Files modified:** `backend/src/main/java/com/nomadgames/matchmaking/RoomController.java`
- **Verification:** grep `rooms/join` matches the controller
- **Committed in:** `5a74db2` (Task 2)

---

**Total deviations:** 1 auto-fixed (Rule 2)
**Impact on plan:** Comment-only; join path and behavior match the plan.

## Authentication Gates

None

## Issues Encountered

None — RED `joinByCodeSitsInLobby` failed 404 (no handler); GREEN RoomIT 6/6 + ModularityTest + `join_code_test` + `catalog_test` passed.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Ready for 03-04 (both Ready + host-alive close). Do not start the match on join. Leave lobby and Ready POST are still out of this slice.

## Self-Check: PASSED

- FOUND: RoomController, RoomService, JoinRateLimiter, join_page.dart, join_code_test.dart, RoomIT.java
- FOUND commits: `50490b5` test(03-03), `5a74db2` feat(03-03)

---
*Phase: 03-private-rooms-casual-reconnect*
*Completed: 2026-09-07*
