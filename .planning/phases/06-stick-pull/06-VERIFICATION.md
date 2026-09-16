---
phase: 06-stick-pull
verified: 2026-09-14T08:05:00Z
status: passed
score: 4/4 must-haves verified
behavior_unverified: 0
overrides_applied: 0
re_verification: false
mvp_mode: true
requirements_checked:
  - CAT-02
  - STICK-01
  - STICK-02
  - STICK-03
  - STICK-04
  - STICK-05
  - BOT-02
  - SESS-04
automated_reverify: "2026-09-14 Maven StickPullSimTest+StickPullBotTest+StickPullIT+StickPullReconnectIT+CatalogIT+CasualQueueIT#stickPullEnqueueIsolatedFromAlchiki — Tests run: 22, Failures: 0; flutter catalog_test+howto_stick_pull_test — 13/13 passed"
---

# Phase 6: Stick Pull Verification Report

**Phase Goal:** As a guest player, I want to open Stick Pull from the catalog, learn from static how-to cards, and play a short stamina tug vs bot or online with fair short reconnect forfeit, so that the parlor has a second live title that cannot be won by mashing or mid-tug bot-fill.  
**Verified:** 2026-09-14T08:05:00Z  
**Status:** passed  
**Re-verification:** No — initial verification  
**Mode:** mvp (user-story goal validated via `user-story.validate` → `valid=true`)

End-of-phase device UAT (live tug feel, EN/RU how-to on device, private/QM two-guest pairing) is an orchestrator step (`human_verify_mode = end-of-phase`). It is **not** treated as a remaining must-have gap — same stance as Phase 5. SUMMARY.md claims were not trusted; evidence is source + Surefire/Flutter runs from this verifier.

## User Flow Coverage

User story: «As a guest player, I want to open Stick Pull from the catalog, learn from static how-to cards, and play a short stamina tug vs bot or online with fair short reconnect forfeit, so that the parlor has a second live title that cannot be won by mashing or mid-tug bot-fill.»

| Step | Expected | Evidence | Status |
|------|----------|----------|--------|
| Open catalog Stick Pull | Stick Pull tile PLAYABLE with Quick Match, Play Stick Pull, Create Stick Pull room, EASY/NORMAL/HARD chips — not Coming Soon | `CatalogService` stick_pull=PLAYABLE; `_StickPullTile` CTAs + chips; `CatalogIT` + `catalog_test` Stick Pull asserts **PASS** | ✓ |
| Learn how-to | First Play opens skippable five-card EN+RU pager; Skip on card 1; seen key `howto.stickpull.seen`; Pause→How to play reopens without clearing seen | `stick_pull_howto_page.dart` five cards; EN+RU ARB; `howto_stick_pull_test` **PASS**; match Pause → `/howto/stick-pull?fromPause=1` | ✓ |
| Play vs bot | Server 3-2-1-GO → tap zone → live marker + stamina; settle threshold or clock | `StickPullRuntime` countdown; `StickPullSim` + WS `TapInput`; `stick_pull_match_page` HUD; `StickPullIT` countdown/tap/settle **PASS** | ✓ |
| Anti-mash | Extra taps beyond 10/s grant no force; stamina bands weaken mash | `HARD_CLAMP_TPS=10`; `acceptClamp` / `forceFor`; `StickPullSimTest#hardClampDropsExtras` + band tests **PASS** | ✓ |
| Online private / QM | Create Stick Pull room → Ready → STICK_PULL match; QM per-game FIFO isolated from Alchiki | `V10__rooms_game.sql`; `GameDiscriminator`; `RoomIT#stickPullRoomKickoffCreatesStickPullMatch`; `CasualQueueIT#stickPullEnqueueIsolatedFromAlchiki` **PASS** | ✓ |
| Reconnect forfeit | Online drop → ~8s grace then forfeit; remaining wins; no mid-tug bot-fill | `ReconnectPolicy.graceSeconds(STICK_PULL)=8`; `settleExpiredDrop` forfeit-only; `StickPullReconnectIT` **PASS** | ✓ |
| Outcome | Second live title cannot be won by mashing or mid-tug bot-fill | Clamp + stamina + forfeit-without-bot-fill verified above | ✓ |

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | ------- | ---------- | -------------- |
| 1 | Player can open Stick Pull as playable from the same catalog (not a Coming Soon tile) | ✓ VERIFIED | Backend: `CatalogService` lists `stick_pull` as `PLAYABLE`, `more_games` stays `COMING_SOON`. Client: `_StickPullTile` with Quick Match / Play Stick Pull / Create Stick Pull room + EASY/NORMAL/HARD chips; Coming Soon only on More games. Behavioral: `CatalogIT` stick_pull PLAYABLE **PASS**; `catalog_test` Stick Pull CTAs + not Coming Soon **PASS** (13 Flutter tests green). |
| 2 | After a server 3-2-1-GO countdown two players tap a shared stick; the marker moves in real time, stamina reduces force when they mash, and the match ends at a win threshold or about 15–40 seconds | ✓ VERIFIED | `StickPullConstants` clock 15–40 (default 30), `WIN_THRESHOLD=0.85`, soft/burst/exhaust force bands. `StickPullSim.applyAcceptedTap` + `tick` settle; `StickPullRuntime` countdown then LIVE; WS `TapInput` → `MatchService.applyTap`; client interpolates `StickState`, stamina bars under avatars. Behavioral: `StickPullSimTest` 7/7 **PASS** (incl. `thresholdOrClockSettle`); `StickPullIT#countdownThenTapMovesMarker` / `#botMatchSettles` / `#preGoTapIgnored` **PASS**. |
| 3 | Extra taps beyond 10 per second grant no force; the player can open skippable static how-to cards in EN and RU | ✓ VERIFIED | Server: `HARD_CLAMP_TPS=10` + bucket clamp rejects extras (`accepted=false`, zero force); suspect flag logs only (`log.info`, no ban API). How-to: five static cards EN+RU ARB (`howtoStickSit*`…`howtoStickWin*`); Skip on card 1; `howto.stickpull.seen` separate from Alchiki. Behavioral: `StickPullSimTest#hardClampDropsExtras` + `#suspectRegularityLogsOnly` **PASS**; `howto_stick_pull_test` Skip/five cards **PASS**. |
| 4 | Player can play EASY, NORMAL, and HARD bots with human-like tap jitter; after a brief online disconnect they have a short window (~8s casual) and then forfeit with no bot-fill mid-tug | ✓ VERIFIED | `StickPullBot` envelopes mean TPS 3.5/5.0/7.0 + sigma + pauses; catalog chips → `lastStickPullBotDifficultyProvider` → bot create. Reconnect: `STICK_PULL_GRACE_SECONDS=8`; `markDropped` uses `graceSeconds(match.getGame())`; `settleExpiredDrop` sets remaining-win status only (comment + code: never bot-fill). Client caps banners at 8s (`_graceCap=8`). Behavioral: `StickPullBotTest` 4/4 **PASS**; `StickPullReconnectIT#stickPullGraceIsEightSeconds` / `#graceExpiryForfeitsNoBotFill` / `#alchikiGraceStillThirty` **PASS**. |

**Score:** 4/4 truths verified (0 present, behavior-unverified)

### Required Artifacts

| Artifact | Expected | Status | Details |
| -------- | -------- | ------ | ------- |
| `backend/.../catalog/CatalogService.java` | stick_pull PLAYABLE | ✓ VERIFIED | Exists, substantive, wired to catalog API |
| `client/lib/howto/stick_pull_howto_page.dart` | Five-card pager | ✓ VERIFIED | EN+RU via l10n; Skip / fromPause |
| `client/lib/howto/howto_seen_store.dart` | `howto.stickpull.seen` | ✓ VERIFIED | Dedicated key; does not clear Alchiki |
| `client/lib/catalog/catalog_page.dart` | `_StickPullTile` | ✓ VERIFIED | CTAs + chips + how-to gate |
| `backend/.../stickpull/StickPullSim.java` | Authoritative stamina/clamp/marker | ✓ VERIFIED | `applyAcceptedTap`, settle paths |
| `backend/.../stickpull/StickPullBot.java` | EASY/NORMAL/HARD jitter | ✓ VERIFIED | Used by `StickPullRuntime` |
| `backend/.../MatchWebSocketHandler.java` | TapInput dispatch | ✓ VERIFIED | Calls `MatchService.applyTap` |
| `client/lib/games/stick_pull/stick_pull_match_page.dart` | Countdown + tug HUD + reconnect | ✓ VERIFIED | Flame lane + Flutter HUD; 8s banners; skins |
| `backend/.../V10__rooms_game.sql` | rooms.game allowlist | ✓ VERIFIED | CHECK ALCHIKI\|STICK_PULL |
| `backend/.../CasualQueueService.java` | Per-game FIFO | ✓ VERIFIED | `fifoFor(game)` isolation |
| `backend/.../GameDiscriminator.java` | Allowlist normalize | ✓ VERIFIED | Rejects unknown game |
| `backend/.../ReconnectPolicy.java` | graceSeconds 8 vs 30 | ✓ VERIFIED | STICK_PULL → 8 |
| `backend/.../session/StickPullReconnectIT.java` | SESS-04 proofs | ✓ VERIFIED | Grace + forfeit IT green |
| IT/widget suites | Behavioral locks | ✓ VERIFIED | See spot-checks |

### Key Link Verification

| From | To | Via | Status | Details |
| ---- | -- | --- | ------ | ------- |
| `_StickPullTile` Play | `/howto/stick-pull` or `/match?game=stickPull` | `isStickPullSeen` gate | ✓ WIRED | `_playStickPull` in `catalog_page.dart` |
| `CatalogService` | `CatalogIT` | GET `/v1/catalog` PLAYABLE | ✓ WIRED | IT asserts stick_pull PLAYABLE |
| `MatchWebSocketHandler` TapInput | `MatchService.applyTap` → `StickPullSim` | Seat-bound re-timestamp | ✓ WIRED | Handler type branch + sim accept |
| `stick_pull_match_page` | POST `/v1/matches` STICK_PULL BOT | create then WS StickState | ✓ WIRED | `game: 'STICK_PULL'` create path |
| Room Ready kickoff | `MatchService.createPrivateMatch(..., game)` | rooms.game STICK_PULL | ✓ WIRED | `RoomIT` kickoff asserts game |
| `CasualQueueService.enqueue(game)` | Per-game FIFO → `createCasualMatch` | D-79 isolation | ✓ WIRED | `stickPullEnqueueIsolatedFromAlchiki` PASS |
| `MatchService.markDropped` | `ReconnectPolicy.graceSeconds(match.getGame())` | OpponentDropped secondsLeft | ✓ WIRED | Cap + deadline game-aware |
| `settleExpiredDrop` | `afterTerminal` | Remaining win; no StickPullBot inject | ✓ WIRED | Forfeit-only; reconnect IT asserts not BOT_WIN |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| -------- | ------------- | ------ | ------------------ | ------ |
| `stick_pull_match_page` | `_marker` / stamina / clock | WS `StickState` from `StickPullRuntime` broadcast | Server sim marker + staminaHost/Joiner | ✓ FLOWING |
| Catalog tile | PLAYABLE status | GET `/v1/catalog` | `CatalogService.list()` real tiles | ✓ FLOWING |
| How-to seen | `howto.stickpull.seen` | SharedPreferences via `HowToSeenStore` | Persisted bool after Skip/Play | ✓ FLOWING |
| Reconnect banner | `_opponentSecondsLeft` | WS `OpponentDropped.secondsLeft` capped 8 | `ReconnectPolicy` grace | ✓ FLOWING |
| Shaft color | `shaftColor` | Loadout map at GameWidget create | Economy loadout SKU → presentation colors only | ✓ FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| -------- | ------- | ------ | ------ |
| Sim bands + clamp + clock | `mvnw -pl backend -am test -Dtest=StickPullSimTest,StickPullBotTest` | 7+4 tests, Failures: 0 | ✓ PASS |
| Bot WS countdown/tap/settle | `-Dtest=StickPullIT` | 3 tests, Failures: 0 | ✓ PASS |
| 8s grace + no bot-fill | `-Dtest=StickPullReconnectIT` | 3 tests, Failures: 0 | ✓ PASS |
| Catalog PLAYABLE + QM isolation | `-Dtest=CatalogIT,CasualQueueIT#stickPullEnqueueIsolatedFromAlchiki` | 4+1 tests, Failures: 0 | ✓ PASS |
| Catalog + how-to widgets | `flutter test test/catalog_test.dart test/howto_stick_pull_test.dart` | 13/13 passed | ✓ PASS |

**Suite aggregate:** Tests run: 22 (Maven selected), Failures: 0, BUILD SUCCESS.

### Probe Execution

| Probe | Command | Result | Status |
| ----- | ------- | ------ | ------ |
| — | — | No `scripts/*/tests/probe-*.sh` declared for this phase | SKIPPED |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
| ----------- | ---------- | ----------- | ------ | -------- |
| CAT-02 | 06-01, 06-02, 06-04, 06-05 | Stick Pull playable from catalog | ✓ SATISFIED | CatalogService PLAYABLE + `_StickPullTile` + CatalogIT/catalog_test |
| STICK-01 | 06-01, 06-03, 06-04 | Countdown then shared-stick taps move marker | ✓ SATISFIED | StickPullRuntime countdown + StickPullIT countdownThenTapMovesMarker |
| STICK-02 | 06-01, 06-03 | Stamina reduces force when mashing | ✓ SATISFIED | StickPullSim force bands; StickPullSimTest exhaust/burst |
| STICK-03 | 06-01, 06-03, 06-05 | 15–40s / threshold or clock settle | ✓ SATISFIED | Constants + thresholdOrClockSettle + botMatchSettles |
| STICK-04 | 06-01, 06-03 | ≤10 taps/s accepted; extras no force; suspect log only | ✓ SATISFIED | hardClampDropsExtras; suspect log.info only |
| STICK-05 | 06-01, 06-02 | Skippable static how-to EN+RU | ✓ SATISFIED | Five-card pager + ARB + howto_stick_pull_test |
| BOT-02 | 06-01, 06-03, 06-04 | EASY/NORMAL/HARD bots with jitter | ✓ SATISFIED | StickPullBot + StickPullBotTest + catalog chips |
| SESS-04 | 06-01, 06-05 | ~8s reconnect then forfeit; no mid-tug bot-fill | ✓ SATISFIED | ReconnectPolicy 8s + StickPullReconnectIT |

**Orphaned requirements:** none — all Phase 6 REQUIREMENTS.md IDs appear in plan frontmatter.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| ---- | ---- | ------- | -------- | ------ |
| — | — | No TBD/FIXME/XXX in Stick Pull production sources | — | — |
| `stick_pull_match_page.dart` | import | Reuses Alchiki `pause_overlay.dart` chrome | ℹ️ Info | UI shell reuse only; Flame lane has no Forge2D / Alchiki GameEngine |

### Human Verification Required

None for verifier status gate. Device parlor UAT (live tug feel, dual-guest private/QM, reconnect banner copy) remains an orchestrator end-of-phase checklist item, not a `human_needed` status.

### Gaps Summary

No blocking gaps. Roadmap success criteria and requirement IDs CAT-02, STICK-01…05, BOT-02, SESS-04 are implemented and behaviorally locked. Ranked ~12s grace / MODE-04 Stick Pull remain Phase 7 by design (not deferred-as-gap for this phase).

---

_Verified: 2026-09-14T08:05:00Z_  
_Verifier: Claude (gsd-verifier)_
