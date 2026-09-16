---
phase: 05-casual-quick-match-profile
verified: 2026-09-11T11:50:00Z
status: passed
score: 5/5 must-haves verified
behavior_unverified: 0
overrides_applied: 0
re_verification: false
mvp_mode: true
requirements_checked:
  - MODE-03
  - MODE-05
  - SESS-02
  - PROF-01
  - PROF-02
  - PROF-03
automated_reverify: "2026-09-11 Maven CasualQueueIT+ProfileIT+CasualRematchIT+ReconnectIT+RematchIT+EconomyIT+ModularityTest — Tests run: 39, Failures: 0; flutter catalog/matchmaking/profile_page/casual_rematch — 16/16 passed"
---

# Phase 5: Casual Quick Match + Profile Verification Report

**Phase Goal:** As a guest player, I want to tap Casual Quick Match and land in a human match or bot/invite fallback and open my profile with stats and avatar presets, so that I never wait on a 60-second fail spinner and can see parlor progress.  
**Verified:** 2026-09-11T11:50:00Z  
**Status:** passed  
**Re-verification:** No — initial verification  
**Mode:** mvp (user-story goal validated via `user-story.validate` → `valid=true`)

End-of-phase device UAT (two guests pairing + visual parlor chrome) is an orchestrator step (`human_verify_mode = end-of-phase`). It is **not** treated as a remaining must-have gap — same stance as Phase 3. SUMMARY.md claims were not trusted; evidence is source + Surefire/Flutter runs from this verifier.

## User Flow Coverage

User story: «As a guest player, I want to tap Casual Quick Match and land in a human match or bot/invite fallback and open my profile with stats and avatar presets, so that I never wait on a 60-second fail spinner and can see parlor progress.»

| Step | Expected | Evidence | Status |
|------|----------|----------|--------|
| Tap Quick Match | Alchiki tile primary CTA enqueues and opens Searching | `catalog_page.dart` `_quickMatch` → `NomadApi` enqueue → `context.go('/matchmaking')`; `SearchingPage` wood + Cancel; `catalog_test` Quick Match assert | ✓ |
| Pair or wait | Two guests → one CASUAL match; alone stays SEARCHING | `CasualQueueService.enqueue` FIFO pair → `MatchService.createCasualMatch`; `CasualQueueIT#twoPlayersPair` / `singlePlayerStaysSearching` **PASS** | ✓ |
| Empty-queue fallback | After 8s alone: Play vs bot + Invite friend (no 60s fail spinner) | `SearchingPage` `_fallbackAfter = 8s` → `/matchmaking/fallback`; equal outline CTAs; ticket stays SEARCHING with continued poll; `matchmaking_test#fallbackAfterEightSeconds` **PASS** | ✓ |
| Play again (casual) | Play again → rematch-wait; both accept → new CASUAL | `match_page` → `/match/rematch-wait`; `acceptRematch` → `createCasualMatch`; `CasualRematchIT` + `casual_rematch_test` **PASS** | ✓ |
| Open profile | Avatar chip → Guest + Guest-XXXX, XP/rating, cosmetics, Stick Pull zeros | `AvatarChip` → `/profile`; `ProfilePage` + `GET /v1/profile`; `ProfileIT#profileReturnsGuestDefaults` + `profile_page_test` **PASS** | ✓ |
| Choose avatar | 8 presets only; Save PUT allow-list | `avatar_01…08`; `PUT /v1/profile/avatar`; `ProfileIT#putAvatarAllowList` + widget Save assert **PASS** | ✓ |
| Outcome | No 60s fail spinner; parlor progress visible | No long fail-spinner UI; 8s fallback; profile XP/W/L/rating from server settle | ✓ |

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | ------- | ---------- | -------------- |
| 1 | Player can start Casual Quick Match and be paired with a random opponent, or be offered a bot / invite if the queue is empty — never a 60-second fail spinner | ✓ VERIFIED | Backend: `CasualQueueService` in-process FIFO pair-on-enqueue → `createCasualMatch`; rate-limit + IN_PLAY reject. Client: catalog Quick Match → Searching (Cancel + poll) → 8s clock to Fallback with equal Play vs bot / Invite friend; no auto-dequeue at 8s; poll continues on fallback. Behavioral: `CasualQueueIT` 6/6 PASS; `matchmaking_test` Cancel + `fallbackAfterEightSeconds` PASS. |
| 2 | After casual matches the rematch window from Phase 3 still works (MODE-05) | ✓ VERIFIED | `MatchService.acceptRematch` branches `createCasualMatch` when mode is CASUAL; dual-accept 10s window; seat-bound. Client: casual Play again → `RematchWaitingPage` (not private Again? chrome); Cancel/timeout → catalog. Behavioral: `CasualRematchIT#casualRematchCreatesCasualMatch` + `#casualRematchRequiresSeat` PASS; `casual_rematch_test` Play again / Cancel PASS; `RematchIT` still in green suite. |
| 3 | Player can open a profile showing Guest, avatar, level, XP, matches, wins, losses, win rate, rating, best rating, selected cosmetics, plus per-game stats (Alchiki live / Stick Pull zeros) | ✓ VERIFIED | Flyway `V9__profile_casual.sql`; `ProfileService.getProfile` projects Guest + `Guest-XXXX`, loadout cosmetics, always includes `stickPull` zeros/`noMatchesYet`; `MatchService.afterTerminal` → `recordSettlement`. Client: `AvatarChip` → `ProfilePage` renders fields + Stick Pull section. Behavioral: `ProfileIT#profileReturnsGuestDefaults` / Elo vs XP tests PASS; `profile_page_test#stickPullSectionShowsNoMatchesYet` PASS; catalog avatar chip + wallet-does-not-open-profile PASS. |
| 4 | Player can choose an avatar from a small original preset set (no photo upload) | ✓ VERIFIED | Allow-list `avatar_01…08` in `ProfileService` + client `kAvatarPresets`; PUT rejects others; eight asset PNGs; no ImagePicker/file_picker. Behavioral: `ProfileIT#putAvatarAllowList` PASS; widget Save → `putAvatar('avatar_03')` PASS. |
| 5 | After a brief disconnect in Casual Alchiki the player can rejoin within 30 seconds (SESS-02 for CASUAL) | ✓ VERIFIED | `MatchService.isHumanPvP` includes CASUAL; createCasualMatch uses same seats/WS/reconnect as PRIVATE; client `_isHumanPvP` treats `casual` like private. Behavioral: `ReconnectIT#casualRejoinWithinGrace` PASS (mode CASUAL snapshot + rejoin). |

**Score:** 5/5 truths verified (0 present, behavior-unverified)

### Required Artifacts

| Artifact | Expected | Status | Details |
| -------- | -------- | ------ | ------- |
| `backend/.../CasualQueueService.java` | FIFO enqueue/pair | ✓ VERIFIED | Exists, substantive, wired via `CasualMatchmakingController` |
| `backend/.../MatchService.java` | `createCasualMatch` + `isHumanPvP` + rematch + settle | ✓ VERIFIED | Wired to queue, rematch, economy `humanMatch`, profile `recordSettlement` |
| `backend/.../ProfileService.java` + `ProfileController.java` | GET/PUT profile | ✓ VERIFIED | JWT self-only; allow-list avatar; Stick Pull defaults |
| `backend/.../V9__profile_casual.sql` | Schema | ✓ VERIFIED | Applied in IT Flyway (v9); columns + `player_game_stats` + `profile_settlements` |
| `backend/.../SoftElo.java` | K=24 Elo | ✓ VERIFIED | Used from `recordSettlement` casual path |
| `client/lib/matchmaking/searching_page.dart` | Searching + 8s fallback | ✓ VERIFIED | Routed `/matchmaking`; Cancel dequeues |
| `client/lib/matchmaking/fallback_page.dart` | Bot / invite CTAs | ✓ VERIFIED | Routed `/matchmaking/fallback`; dequeue on exit |
| `client/lib/games/alchiki/rematch_waiting_page.dart` | Casual rematch wait | ✓ VERIFIED | Routed `/match/rematch-wait` |
| `client/lib/profile/profile_page.dart` | Full PROF UI | ✓ VERIFIED | Wired fetch/put; Stick Pull section |
| `client/lib/catalog/avatar_chip.dart` | Catalog → profile | ✓ VERIFIED | `openProfileA11y`; wallet chip has no profile nav |
| IT/widget suites | Behavioral locks | ✓ VERIFIED | See spot-checks |

### Key Link Verification

| From | To | Via | Status | Details |
| ---- | -- | --- | ------ | ------- |
| `CasualQueueService` | `MatchService.createCasualMatch` | Pair-on-enqueue | ✓ WIRED | `matches.createCasualMatch(peerId, playerId)` |
| `MatchService.afterTerminal` | `EconomyService.grantMatchRewards` | `humanMatch=true` for CASUAL/PRIVATE | ✓ WIRED | `isHumanPvP` → `grantSeat(..., true)` |
| `MatchService.afterTerminal` | `ProfileService.recordSettlement` | Sync in settle TX | ✓ WIRED | `recordProfileSettlements` |
| `ProfileService.getProfile` | `economy.getLoadout` | Cosmetics projection | ✓ WIRED | `cosmetics` map on view |
| `catalog_page` | `/matchmaking` | Quick Match CTA | ✓ WIRED | `_quickMatch` enqueue then go |
| `searching_page` | `/match?mode=casual` or fallback | Poll MATCHED / 8s timer | ✓ WIRED | `_goCasualMatch` / `_openFallback` |
| `fallback_page` | `dequeueCasual` + bot/room | Explicit exits only | ✓ WIRED | `_playVsBot` / `_inviteFriend` |
| Result casual Play again | `/match/rematch-wait` + rematch API | Leaves result (D-73) | ✓ WIRED | `rematch-wait` route + POST accept |
| `acceptRematch` | `createCasualMatch` | Mode CASUAL | ✓ WIRED | Branch in `MatchService` |
| `avatar_chip` | `/profile` | Catalog header | ✓ WIRED | `context.push('/profile')` |
| `profile_page` | `GET/PUT /v1/profile` | `fetchProfile` / `putAvatar` | ✓ WIRED | NomadApi Dio calls |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| -------- | ------------- | ------ | ------------------ | ------ |
| `ProfilePage` | `_profile` | `NomadApi.fetchProfile` → GET `/v1/profile` → JDBC + loadout | Yes (IT + guest defaults) | ✓ FLOWING |
| `SearchingPage` | queue status | `pollCasual` → queue tickets | Yes (IT pair/status) | ✓ FLOWING |
| `FallbackPage` | late MATCHED | Continued `pollCasual` while SEARCHING | Yes (code path + widget poll) | ✓ FLOWING |
| `CatalogPage` avatar | `_avatarPreset` | `fetchProfile` on catalog load | Yes (API; default avatar_01 on error) | ✓ FLOWING |
| Result rematch | new `matchId` | Dual-accept rematch window | Yes (`CasualRematchIT`) | ✓ FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| -------- | ------- | ------ | ------ |
| Backend phase suite | `mvnw -pl backend -am -Dtest=CasualQueueIT,ProfileIT,CasualRematchIT,ReconnectIT,RematchIT,EconomyIT,ModularityTest test` | Tests run: **39**, Failures: **0**, Errors: **0** — BUILD SUCCESS | ✓ PASS |
| Flutter phase widgets | `flutter test test/catalog_test.dart test/matchmaking_test.dart test/profile_page_test.dart test/casual_rematch_test.dart` | **16/16** passed | ✓ PASS |
| Named: queue pair | CasualQueueIT#twoPlayersPair | failures=0 in Surefire XML | ✓ PASS |
| Named: CASUAL rematch | CasualRematchIT#casualRematchCreatesCasualMatch | failures=0 | ✓ PASS |
| Named: CASUAL rejoin | ReconnectIT#casualRejoinWithinGrace | failures=0 | ✓ PASS |
| Named: profile defaults | ProfileIT#profileReturnsGuestDefaults | failures=0 | ✓ PASS |
| Named: 8s fallback UI | matchmaking_test#fallbackAfterEightSeconds | included in flutter run | ✓ PASS |

### Probe Execution

| Probe | Command | Result | Status |
| ----- | ------- | ------ | ------ |
| — | — | No `scripts/*/tests/probe-*.sh` declared for this phase | SKIPPED |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
| ----------- | ---------- | ----------- | ------ | -------- |
| MODE-03 | 05-01…05-04 | Casual Quick Match + empty-queue fallback | ✓ SATISFIED | Queue + Searching + Fallback + ITs/widgets |
| MODE-05 | 05-01, 05-05 | Rematch after casual | ✓ SATISFIED | createCasualMatch rematch branch + CasualRematchIT |
| SESS-02 | 05-01, 05-02 | Rejoin within 30s for Casual | ✓ SATISFIED | isHumanPvP(CASUAL) + ReconnectIT#casualRejoinWithinGrace |
| PROF-01 | 05-06, 05-07 | Profile heading + metrics + cosmetics | ✓ SATISFIED | ProfileService + ProfilePage + ProfileIT |
| PROF-02 | 05-06, 05-07 | Per-game stats incl. Stick Pull zeros | ✓ SATISFIED | ensureGameStatsRow STICK_PULL; UI section always shown |
| PROF-03 | 05-06, 05-07 | Avatar presets only | ✓ SATISFIED | Allow-list 8; no upload |

No ORPHANED requirements: MODE-05 and SESS-02 were claimed by Wave 0 / 05-02 / 05-05 plans and verified.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| ---- | ---- | ------- | -------- | ------ |
| — | — | No TBD/FIXME/XXX in phase production matchmaking/profile paths | — | — |
| Searching spinner | — | Short search spinner (not 60s fail) | ℹ️ Info | Expected chrome; Cancel + 8s fallback prevent stuck fail |

### Human Verification Required

None blocking this report. Orchestrator may still run end-of-phase two-device UAT (pair two guests, empty-queue fallback, casual rematch, profile avatar) after `passed` — same pattern as Phase 3.

### Gaps Summary

No actionable gaps. All five must-have truths are present, wired, data-flowing, and exercised by named automated tests. Phase 6 Stick Pull playability is out of scope (PROF-02 only requires zero row / “No matches yet”).

---

_Verified: 2026-09-11T11:50:00Z_  
_Verifier: Claude (gsd-verifier)_
