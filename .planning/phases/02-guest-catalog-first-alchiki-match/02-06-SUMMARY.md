---
phase: 02-guest-catalog-first-alchiki-match
plan: 06
subsystem: bots
tags: [scripted-bot, botThrow, easy-default, pres-02, forge2d]

requires:
  - phase: 02-guest-catalog-first-alchiki-match
    provides: REST throw authority (02-04); match clocks + afterPlayerHalfIfInPlay hook (02-05); lifted table resetSakaToRim (02-08)
provides:
  - Server ScriptedBot EASY/NORMAL/HARD ThrowInput on leftover bone ids
  - REST botThrow { input, keyframes, displayedScore, sakaOut, pocketedIds }
  - Visible client playBotTurn (aim + hold then keyframes, then resetSakaToRim)
affects:
  - Phase 3 rematch / live opponent turns
  - Owner UAT BOT-03 (EASY under 3 minutes)

tech-stack:
  added: []
  patterns:
    - ScriptedBot.nextThrow(difficulty, seed, tableId, remainingBoneIds) then GameEngine.applyThrow JSON
    - afterPlayerHalfIfInPlay attaches botThrow; duplicate empty POST is a no-op
    - playBotTurn hides Hold Throw, shows botsTurn, then KeyframePlayer

key-files:
  created:
    - backend/src/main/java/com/nomadgames/games/alchiki/internal/ScriptedBot.java
    - backend/src/main/java/com/nomadgames/session/BotThrowView.java
    - backend/src/main/java/com/nomadgames/session/ThrowInputView.java
    - backend/src/test/java/com/nomadgames/games/alchiki/ScriptedBotTest.java
    - client/test/bot_turn_test.dart
  modified:
    - backend/src/main/java/com/nomadgames/session/MatchService.java
    - backend/src/main/java/com/nomadgames/session/ThrowResponse.java
    - backend/src/main/java/com/nomadgames/games/alchiki/AlchikiEngine.java
    - backend/src/test/java/com/nomadgames/session/ThrowAuthorityIT.java
    - client/lib/games/alchiki/match_page.dart
    - client/lib/platform/api/nomad_api.dart

key-decisions:
  - "ScriptedBot mixes remainingBoneIds into the RNG seed; EASY always misses center by more than 0.2 rad"
  - "BotThrowView + ThrowInputView stay in session so the REST body does not expose harness proto types"
  - "playBotTurn schedules hold via Timer so flutter_test can pump fake time"
  - "Catalog Easy chip stays the default selected FilterChip (D-21)"

patterns-established:
  - "Pattern: ScriptedBot runs only on the server; client animates botThrow.input then keyframes (D-22)"
  - "Pattern: after bot replay, startTurn/resetSakaToRim at (0,-1.15); pocketed ids stay gone (ALCH-05)"

requirements-completed: [BOT-01, BOT-03, PRES-02, ALCH-05]

coverage:
  - id: D1
    description: ScriptedBot emits ThrowInput (not a score DTO) with EASY/NORMAL/HARD noise
    requirement: BOT-01
    verification:
      - kind: unit
        ref: "backend/src/test/java/com/nomadgames/games/alchiki/ScriptedBotTest.java#easyHoldIsNoisyAndMissesCenterOnFixedSeed"
        status: pass
    human_judgment: false
  - id: D2
    description: Non-terminal player throw returns botThrow.input + keyframes; forged botScore is ignored
    requirement: BOT-01
    verification:
      - kind: integration
        ref: "backend/src/test/java/com/nomadgames/session/ThrowAuthorityIT.java#nonTerminalPlayerThrowIncludesBotThrowAndIgnoresForgedBotScore"
        status: pass
    human_judgment: false
  - id: D3
    description: Player-pocketed ids are omitted from botThrow keyframes, botThrow.pocketedIds, and bonesLeft
    requirement: ALCH-05
    verification:
      - kind: integration
        ref: "backend/src/test/java/com/nomadgames/session/ThrowAuthorityIT.java#botThrowOmitsIdsPocketedByPlayer"
        status: pass
    human_judgment: false
  - id: D4
    description: Forfeit while IN_PLAY attaches botThrow; duplicate empty POST does not increment playerTurns or attach a second botThrow
    requirement: BOT-01
    verification:
      - kind: integration
        ref: "backend/src/test/java/com/nomadgames/session/ThrowAuthorityIT.java#forfeitThenBotThenDuplicatePostDoesNotAttachSecondBotThrow"
        status: pass
    human_judgment: false
  - id: D5
    description: During playBotTurn, Hold Throw is hidden and the banner is botsTurn
    requirement: BOT-01
    verification:
      - kind: automated_ui
        ref: "client/test/bot_turn_test.dart#when snapshot turn is BOT, Hold Throw is hidden and banner is botsTurn"
        status: pass
    human_judgment: false
  - id: D6
    description: After botThrow keyframe replay, saka is at (0,-1.15) and pocketed bones stay gone
    requirement: ALCH-05
    verification:
      - kind: automated_ui
        ref: "client/test/bot_turn_test.dart#after botThrow keyframe replay, saka is at -1.15 and pocketed bones stay gone"
        status: pass
    human_judgment: false
  - id: D7
    description: New guest beats EASY in under 3 minutes after skippable how-to (BOT-03)
    requirement: BOT-03
    verification: []
    human_judgment: true
    rationale: Session length and skippable-card win need owner play; pending human verification — not a blocking checkpoint
  - id: D8
    description: Visible bot aim+hold+settle and PRES-02 palette; Coming Soon tiles stay non-playable
    requirement: PRES-02
    verification:
      - kind: automated_ui
        ref: "client/test/catalog_test.dart#catalog home shows Alchiki playable and Coming Soon tiles"
        status: pass
    human_judgment: true
    rationale: Widget tests lock Easy chip and Coming Soon; felt/wood/gold reserved CTAs and bot-turn readability still need owner visual UAT

duration: 14min
completed: 2026-09-06
status: complete
---

# Phase 2 Plan 06: Scripted Bot Turns + EASY Default Summary

**Server-authored EASY/NORMAL/HARD ScriptedBot ThrowInput scored by dyn4j, returned as botThrow, and played as a visible aim+hold+keyframe turn with rim reset at (0,-1.15)**

## Performance

- **Duration:** 14 min
- **Started:** 2026-09-06T17:11:00Z
- **Completed:** 2026-09-06T17:25:00Z
- **Tasks:** 2
- **Files modified:** 11

## Accomplishments

- ScriptedBot emits a real `ThrowInput` (schemaVersion 1, yUp, leftover-aware seed) with RESEARCH A3 noise; EASY hold 200–450 ms and a visible center miss
- After a non-terminal player throw or a 20s forfeit, `afterPlayerHalfIfInPlay` runs the same applyThrow path, attaches `botThrow`, and a duplicate empty POST is a no-op
- Client `playBotTurn` hides Hold Throw, shows `botsTurn`, aims from `botThrow.input`, fills the power meter, then interpolates keyframes — not an instant score popup
- After bot replay, `resetSakaToRim` puts the next player throw at `(0,-1.15)` and pocketed ids stay gone
- Catalog Easy chip remains the default; forge2d stays 0.14.2

## Task Commits

Each task was committed atomically:

1. **Task 1: Write failing scripted-bot tests** - `0b8e47d` (test)
2. **Task 2: Visible bot turns and EASY default polish** - `a3d62a5` (feat)

**Plan metadata:** docs(02-06) complete scripted bot plan (this commit)

## Files Created/Modified

- `backend/src/main/java/com/nomadgames/games/alchiki/internal/ScriptedBot.java` - Deterministic noisy ThrowInput per difficulty
- `backend/src/main/java/com/nomadgames/session/MatchService.java` - ScriptedBot after player half / forfeit; botThrow on response
- `backend/src/main/java/com/nomadgames/session/ThrowResponse.java` - `{ playerThrow, botThrow, match }`
- `backend/src/main/java/com/nomadgames/session/BotThrowView.java` - input + keyframes + displayedScore
- `backend/src/main/java/com/nomadgames/session/ThrowInputView.java` - REST input DTO
- `backend/src/main/java/com/nomadgames/games/alchiki/AlchikiEngine.java` - applyThrow(ThrowInput, remainingBoneIds)
- `backend/src/test/java/com/nomadgames/games/alchiki/ScriptedBotTest.java` - EASY/NORMAL/HARD noise
- `backend/src/test/java/com/nomadgames/session/ThrowAuthorityIT.java` - botThrow leftover + forfeit no-op
- `client/lib/games/alchiki/match_page.dart` - playBotTurn, botsTurn, reset after bot
- `client/lib/platform/api/nomad_api.dart` - parse optional botThrow
- `client/test/bot_turn_test.dart` - Hold hidden; saka at -1.15

## Decisions Made

- Leftover bone ids are mixed into the ScriptedBot RNG seed so the bot cannot aim as if pocketed bones were still on the table
- EASY always offsets aim by more than 0.2 rad from the perfect-center angle so the "visible mistake" test is stable
- REST `botThrow.input` is a session `ThrowInputView`, not the harness proto class
- `playBotTurn` uses `Timer` (not `Future.delayed`) so widget tests can advance fake time with `pump`

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Future.delayed deadlocked flutter_test**
- **Found during:** Task 2 GREEN — bot_turn_test hung on await playBotTurn
- **Issue:** Widget tests use a fake clock; `await Future.delayed(holdMs)` never completed without a pump inside the awaited future
- **Fix:** Schedule the bot hold→replay transition with `Timer` so `tester.pump(duration)` fires it
- **Files modified:** `client/lib/games/alchiki/match_page.dart`
- **Verification:** `flutter test test/bot_turn_test.dart` passed
- **Committed in:** `a3d62a5`

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** Required for GREEN widget tests. No shop, rematch, or ML bot.

## Issues Encountered

- `ModularityTest` reports a `games ↔ session` cycle and `games.alchiki` types as non-exposed. Session already imported `AlchikiRules` / `MatchStatus` in 02-05; ScriptedBot is the same pattern. Out of scope for this plan — see Deferred Issues.

## Authentication Gates

None

## Known Stubs

None — `afterPlayerHalfIfInPlay` is filled. No shop / rematch / Guest chip stubs on the catalog path.

## Pending Human Verification

Owner UAT (not a blocking checkpoint):

1. Cold start as guest → catalog EN/RU → Play Alchiki → skip or finish five cards → EASY match. Win in under 3 minutes (BOT-03).
2. Bot turn is visible aim + hold + settle, not an instant score popup (D-21).
3. Catalog / how-to / table use felt `#1B6B3A`, wood `#241810`, gold accent only on reserved CTAs (PRES-02).
4. Coming Soon tiles do not start a game. No shop, room code, or rematch button.

## Deferred Issues

- Pre-existing `ModularityTest` cycle (`games` ↔ `session`) and nested `games.alchiki` types treated as non-exposed. Do not reopen the GameEngine / AlchikiRules cut in this plan.

## Threat Flags

None — `botThrow` is the plan `<threat_model>` mitigation (T-02-20, T-02-21). Client cannot author botScore. No shop/Ranked/Redis surface (T-02-22).

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Phase 2 plans are complete. Ready for `/gsd-verify-work` (includes pending BOT-03 / PRES-02 human checks) then Phase 3 rooms. forge2d stays 0.14.2. Do not add rematch or rated forfeit.

## TDD Gate Compliance

- RED commit `0b8e47d` `test(02-06): add failing test for scripted bot and visible bot turn` — ScriptedBot package missing; `playBotTurn` undefined
- GREEN commit `a3d62a5` `feat(02-06): implement scripted bot turns and EASY default polish` — ScriptedBotTest 3/3, ThrowAuthorityIT 10/10, AlchikiRulesTest 12/12, bot_turn + catalog + howto + match_hold passed

## Self-Check: PASSED

- FOUND: ScriptedBot.java, MatchService.java, match_page.dart, bot_turn_test.dart, ScriptedBotTest.java, 02-06-SUMMARY.md
- FOUND: 0b8e47d test(02-06), a3d62a5 feat(02-06)
