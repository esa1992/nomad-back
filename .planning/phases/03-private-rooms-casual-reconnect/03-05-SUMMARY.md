---
phase: 03-private-rooms-casual-reconnect
plan: 05
subsystem: session
tags: [websocket, ws-ticket, two-saka, private-throw, d-34, d-37, d-38, mode-01, mode-02]
status: complete

requires:
  - phase: 03-private-rooms-casual-reconnect
    provides: both-Ready PRIVATE NORMAL match with turn JOINER, requireSeat, GameEngine.startPrivate
provides:
  - Dyn4jBurstSim.simulatePrivate with saka-host and saka-joiner; bot simulate still uses id saka
  - POST /v1/matches/{id}/ws-ticket one-time 60s SHA-256 tickets bound to playerId+matchId
  - Raw WebSocket /v1/matches/{matchId}/ws with ThrowInput/Ping in and ThrowResolved/Pong/Error/MatchSettled out
  - MatchService.applyPrivateThrow; REST POST /throws on PRIVATE is 409
affects:
  - Phase 3 Flutter private table wiring (03-06)
  - Consented leave close code 4000 (03-07)
  - Reconnect seat hold (03-09)

tech-stack:
  added:
    - spring-boot-starter-websocket (Boot BOM 4.1.1)
  patterns:
    - Raw WebSocketConfigurer only — no STOMP broker, no SockJS
    - Handshake credential is a one-time ticket query param, not the 15-minute access JWT
    - ConcurrentWebSocketSessionDecorator for send; afterConnectionClosed removes the socket not the seat

key-files:
  created:
    - backend/src/main/java/com/nomadgames/session/MatchWebSocketConfig.java
    - backend/src/main/java/com/nomadgames/session/internal/MatchWebSocketHandler.java
    - backend/src/main/java/com/nomadgames/session/internal/WsTicketInterceptor.java
    - backend/src/main/java/com/nomadgames/session/internal/WsTicketService.java
    - backend/src/main/java/com/nomadgames/session/internal/MatchSessionRegistry.java
    - backend/src/main/java/com/nomadgames/session/WsTicketResponse.java
    - backend/src/main/java/com/nomadgames/session/PrivateThrowResult.java
    - backend/src/test/java/com/nomadgames/session/PrivateThrowIT.java
  modified:
    - harness/src/main/java/com/nomadgames/alchiki/proto/Dyn4jBurstSim.java
    - harness/src/test/java/com/nomadgames/alchiki/proto/BurstSimTest.java
    - backend/src/main/java/com/nomadgames/session/GameEngine.java
    - backend/src/main/java/com/nomadgames/games/alchiki/AlchikiEngine.java
    - backend/src/main/java/com/nomadgames/session/MatchService.java
    - backend/src/main/java/com/nomadgames/session/MatchController.java
    - backend/src/main/java/com/nomadgames/identity/SecurityConfig.java
    - backend/pom.xml

key-decisions:
  - "Private in-play throws travel on raw JSON WebSocket; bot matches stay on REST POST /throws (D-38)"
  - "Handshake uses a one-time 60s ticket from POST /v1/matches/{id}/ws-ticket; access JWT is not a query parameter (D-38)"
  - "PRIVATE burst spawn uses saka-host and saka-joiner; impulse applies only to throwingSakaId (D-37)"
  - "ThrowResolved may include the throw input so the waiting seat can replay aim+hold; no live aim stream (D-34)"
  - "Jackson 3 tools.jackson ObjectMapper is the Boot 4.1 JSON engine for WS frames"

patterns-established:
  - "Pattern: ticket interceptor consumes SHA-256 hashed one-time tickets and stashes playerId+matchId on the handshake"
  - "Pattern: MatchSessionRegistry maps matchId to ConcurrentWebSocketSessionDecorator list; close does not delete the seat"
  - "Pattern: playerScore=host and botScore=joiner on PRIVATE applyPrivateThrow; ScoreClock.privateMatch true"

requirements-completed: [MODE-01, MODE-02]

coverage:
  - id: D1
    description: Private two-saka burst spawn never pockets a saka id; bot simulate still spawns id saka only
    requirement: MODE-02
    verification:
      - kind: unit
        ref: "harness/src/test/java/com/nomadgames/alchiki/proto/BurstSimTest.java#simulatePrivateJoinerDoesNotNpeOrPocketSaka"
        status: pass
      - kind: unit
        ref: "harness/src/test/java/com/nomadgames/alchiki/proto/BurstSimTest.java#simulateRemainingStillSpawnsOnlyBotSakaId"
        status: pass
    human_judgment: false
  - id: D2
    description: Ticket-authenticated joiner ThrowInput yields ThrowResolved to both seats; forged score keys ignored; host on joiner turn errors; REST /throws on PRIVATE is 409
    requirement: MODE-02
    verification:
      - kind: integration
        ref: "backend/src/test/java/com/nomadgames/session/PrivateThrowIT.java"
        status: pass
    human_judgment: false
  - id: D3
    description: Bot REST throw authority stays on POST /throws without a socket
    requirement: MODE-01
    verification:
      - kind: integration
        ref: "backend/src/test/java/com/nomadgames/session/ThrowAuthorityIT.java"
        status: pass
    human_judgment: false
  - id: D4
    description: Raw WebSocketConfigurer at /v1/matches/{matchId}/ws with allowed origin patterns star; no SockJS or STOMP broker
    requirement: MODE-02
    verification:
      - kind: other
        ref: "backend/src/main/java/com/nomadgames/session/MatchWebSocketConfig.java"
        status: pass
      - kind: unit
        ref: "backend/src/test/java/com/nomadgames/ModularityTest.java"
        status: pass
    human_judgment: false

duration: 11min
completed: 2026-09-07
---

# Phase 3 Plan 5: Private Throw WebSocket Summary

**Private Alchiki throws score on a ticket-authenticated raw JSON WebSocket using two saka bodies; bot matches stay on REST.**

## Performance

- **Duration:** 11 min
- **Started:** 2026-09-07T08:23:24Z
- **Completed:** 2026-09-07T08:34:37Z
- **Tasks:** 2/2
- **Files modified:** 16

## Accomplishments

- `Dyn4jBurstSim.simulatePrivate` spawns `saka-host` at (-0.25,-1.12) and `saka-joiner` at (0.25,-1.12); impulse applies only to `throwingSakaId`; pocketing ignores ids starting with `saka`. Bot `simulate(input, remaining)` still uses id `saka`.
- `POST /v1/matches/{id}/ws-ticket` (Bearer JWT, seat required) issues a one-time 60s opaque ticket hashed SHA-256 in-heap. Handshake `GET /v1/matches/{matchId}/ws?ticket=` is `permitAll` because the ticket is the credential.
- `MatchWebSocketHandler` accepts `ThrowInput` and `Ping`; broadcasts `ThrowResolved` (playerThrow + snapshot, plus input for theatrical replay) and `Pong` / `Error` / `MatchSettled`. No live aim stream (D-34).
- `applyPrivateThrow` maps host→`saka-host` / joiner→`saka-joiner`, updates playerScore (host) / botScore (joiner), resolves with `privateMatch true`. REST `POST /throws` on PRIVATE returns 409.

## Task Commits

Each task was committed atomically:

1. **Task 1 RED: Two-saka private burst plus failing PrivateThrowIT** - `cf8f8f5` (test)
2. **Task 1 GREEN: Two-saka private burst and applyThrow overload** - `04ff94d` (feat)
3. **Task 2: Raw WebSocket ticket handler and private apply** - `02b94eb` (feat)

**Plan metadata:** pending docs commit

_Note: TDD tasks may have multiple commits (test → feat → refactor)_

## Files Created/Modified

- `harness/.../Dyn4jBurstSim.java` - `simulatePrivate` + two-saka spawn; bot path unchanged
- `backend/.../GameEngine.java` / `AlchikiEngine.java` - 4-arg `applyThrow`
- `backend/pom.xml` - BOM-managed `spring-boot-starter-websocket`
- `backend/.../MatchWebSocketConfig.java` - raw `/v1/matches/{matchId}/ws`, `setAllowedOriginPatterns("*")`
- `backend/.../internal/WsTicketService.java` - 60s one-time hashed tickets
- `backend/.../internal/WsTicketInterceptor.java` - `?ticket=` handshake
- `backend/.../internal/MatchWebSocketHandler.java` - JSON frames + ConcurrentWebSocketSessionDecorator
- `backend/.../internal/MatchSessionRegistry.java` - matchId → open sessions
- `backend/.../MatchService.java` - `applyPrivateThrow`, `issueWsTicket`, PRIVATE REST 409
- `backend/.../SecurityConfig.java` - permit `/v1/matches/*/ws` only
- `backend/.../PrivateThrowIT.java` - ticket, broadcast, forged scores, turn, REST 409

## Decisions Made

- Tickets live hashed in an in-heap map (not Postgres). Bound to `playerId`+`matchId`, consumed once, TTL 60s.
- `ThrowResolved` includes an `input` object copied from the client frame so the waiting seat can play aim+hold without a live angle stream (D-34).
- WS JSON uses Boot 4.1 Jackson 3 (`tools.jackson.databind.ObjectMapper`); `com.fasterxml.jackson.databind` is not on the compile classpath.
- `afterConnectionClosed` removes the socket from the registry and does not delete the seat (close code 4000 reserved for 03-07).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Jackson 3 package for WS frames**
- **Found during:** Task 2
- **Issue:** `com.fasterxml.jackson.databind.ObjectMapper` does not compile on Spring Boot 4.1.1 (Jackson 3 / `tools.jackson`)
- **Fix:** Import `tools.jackson.databind.ObjectMapper` and `JsonNode`
- **Files modified:** `MatchWebSocketHandler.java`
- **Verification:** PrivateThrowIT, ThrowAuthorityIT, ModularityTest pass
- **Committed in:** `02b94eb` (Task 2)

**2. [Rule 2 - Missing Critical] ThrowResolved carries throw input**
- **Found during:** Task 2
- **Issue:** `PlayerThrowView` has no aim/hold; opponent theatrical replay (D-34) needs the angle only inside ThrowResolved
- **Fix:** Handler copies `aimAngleRad`/`holdMs` from the ThrowInput frame into `ThrowResolved.input`; never streams live aim
- **Files modified:** `MatchWebSocketHandler.java`
- **Verification:** PrivateThrowIT joiner throw still receives ThrowResolved with playerThrow.displayedScore
- **Committed in:** `02b94eb` (Task 2)

---

**Total deviations:** 2 auto-fixed (1 blocking, 1 missing critical)
**Impact on plan:** Both required for Boot 4.1 compile and D-34. No scope creep.

## Issues Encountered

None beyond the Jackson 3 package rename, which compiled cleanly after the import change.

## Authentication Gates

None.

## Known Stubs

None — PrivateThrowIT exercises real tickets, handshake, and ThrowResolved. Flutter private table UI is 03-06 by design, not a stub in this plan.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Ready for **03-06** (Flutter private table + WS client). Server accepts joiner-first throws after both Ready. Rematch, consented leave, and reconnect are later plans. Do not migrate bot throws off REST.

---
*Phase: 03-private-rooms-casual-reconnect*
*Completed: 2026-09-07*

## Self-Check: PASSED

- Key files exist on disk (Dyn4jBurstSim, MatchWebSocketConfig, WsTicketService, handler, interceptor, registry, PrivateThrowIT, pom.xml, SUMMARY.md)
- Commits present: cf8f8f5, 04ff94d, 02b94eb
