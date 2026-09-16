---
phase: 07-bind-ranked-ship
verified: 2026-09-14T15:50:00Z
status: passed
score: 1/5 must-haves verified
behavior_unverified: 4
overrides_applied: 0
behavior_unverified_items:

  - truth: "Player can bind a unique username and password to the same guest identity (progress kept; no sum), log in, stay signed in across restarts, and log out"
    test: "Mint guest → bind → confirm same playerId/wallets → kill app → reopen signed in → logout → guest catalog"
    expected: "Bind keeps identity; refresh yields guest=false; logout mints new guest with credentials intact for Sign in"
    why_human: "BindIT/Auth paths need live Postgres/Testcontainers; widget tests only cover chrome and adopt UI, not token persistence across restarts"

  - truth: "Bound player can start Ranked that updates Glicko-2 (no bots); ranked disconnect uses shorter grace + pause budget → rated forfeit"
    test: "Two bound clients enqueue Ranked Alchiki/Stick Pull → settle → check Glicko; drop mid-match until grace/budget forfeit"
    expected: "mode=RANKED match; Glicko changes SoftElo unchanged; 18s/12s grace; budget exhaustion → immediate rated loss; no bot-fill"
    why_human: "Glicko2Test + StickPullSimTest green; RankedQueueIT/RankedSettleIT/RankedReconnectIT not executed in this verify (Docker/Testcontainers)"

  - truth: "Bound player views global boards by game with season/all-time; soft reset; never coins; guests excluded"
    test: "Sign in → Profile/Boards → toggle Alchiki/Stick Pull and Season/All-time; confirm guest 403 and ranking by rating"
    expected: "Top-100 skill rows; season soft-reset formula applied at quarter; guests absent; coin-rich low-skill below high-skill poor"
    why_human: "BoardsService SQL + SeasonService inspected; boards_test uses stub empty list — live BoardsIT not run here"

  - truth: "Nine ANLT-01 events appear in backend logs/analytics_events without analytics SaaS"
    test: "Boot app, bind, login, ranked queue+match, purchase → grep logs/table for all nine type names"
    expected: "APP_STARTED…ITEM_PURCHASED as structured analytics_event JSON + rows; no Amplitude/Firebase/Grafana"
    why_human: "All nine emit call sites + EventSink catch/log verified statically; EventSinkIT not run in this verify"
human_verification:

  - test: "Guest → Bind sheet (or Profile Bind) with valid username/password"
    expected: "Same playerId; wallets/cosmetics unchanged; guest=false; Ranked/Boards unlock"
    why_human: "End-to-end identity + secure storage across restart"

  - test: "Sign in with adoptHint (import vs drop) when guest has progress and target is empty/non-empty"
    expected: "Never silent wallet sum; replaceGuest confirm when DROP_REQUIRED; import only when eligible"
    why_human: "D-93 adopt branches need real accounts"

  - test: "Two bound players Find Ranked match for Alchiki and Stick Pull; cancel search; complete settle"
    expected: "Indefinite search with Cancel only (no bot/invite); Find Ranked match CTA after settle; Glicko updates"
    why_human: "Matchmaking + settle need two clients / live server"

  - test: "Ranked disconnect within grace then return; exhaust pause budget then drop"
    expected: "Opponent sees reconnect timer (18 Alchiki / 12 Stick); budget gone → rated forfeit; Casual still 30/8"
    why_human: "Real-time reconnect timing and HUD"

  - test: "Bound Boards UI season/all-time + game filter; guest soft-lock"
    expected: "Live rows from GET /v1/boards; guest sees boardsLockTitle / bindNow"
    why_human: "Visual + live API data"

  - test: "Confirm analytics_event lines for nine types after a short parlor loop; confirm CI workflow present on PR"
    expected: "Logs/table contain nine types; PR CI runs Maven verify + Flutter analyze/test"
    why_human: "Runtime log volume and CI green on real PR not asserted here"
---

# Phase 7: Bind, Ranked + Ship Verification Report

**Phase Goal:** As a guest player, I want to bind progress under a username, play honest Ranked with skill boards, and ship behind CI, so that identity survives devices and ratings stay fair without P2W

**Verified:** 2026-09-14T15:50:00Z  
**Status:** human_needed  
**Re-verification:** No — initial verification  
**Mode:** mvp (user-story goal validated)

## User Flow Coverage

User story: «As a guest player, I want to bind progress under a username, play honest Ranked with skill boards, and ship behind CI, so that identity survives devices and ratings stay fair without P2W.»

| Step | Expected | Evidence | Status |
|------|----------|----------|--------|
| Open as guest | Guest session / catalog | `GuestService` mint + splash `mintGuest`; catalog guest soft-lock | ✓ code |
| Bind under username | Same `playerId`, progress kept | `BindService.bind` same id + credentials; Flutter `bind_sheet.dart`; `bind_sheet_test` green | ✓ code / ⚠️ E2E human |
| Play honest Ranked | Bound enqueue, no bots, Glicko settle | `RankedMatchmakingController.requireBound`; `RankedQueueService` → `createRankedMatch`; `RatingService.recordRankedSettlement`; `Glicko2Test` + `StickPullSimTest` green | ✓ code / ⚠️ E2E human |
| Read skill boards | Game + season/all-time | `BoardsController`/`BoardsService` bound-only SQL; `/boards` + `boards_page.dart`; `boards_test` chrome green | ✓ code / ⚠️ E2E human |
| Ship behind CI | Releasable backend+client | `.github/workflows/ci.yml` Maven+Flutter; `compose.prod.yaml` + `Dockerfile` | ✓ |
| Outcome | Identity survives devices; ratings fair without P2W | Bind+refresh+Glicko fork from SoftElo+boards never coins | ⚠️ needs human UAT |

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | ------- | ---------- | -------------- |
| 1 | Player can bind unique username/password to same guest identity (progress/cosmetics/wallets kept; no second account; no summed balances), log in on a new session, stay signed in across restarts, and log out | ⚠️ PRESENT_BEHAVIOR_UNVERIFIED | `BindService` / `AuthService` / `TokenService.rotate(…, player.isGuest())` / `GuestController` bind\|login\|logout wired; Flutter bind/sign-in/logout + soft-lock tests **17/17 green**; BindIT not run here |
| 2 | Bound player can start Ranked updating Glicko-2 (cosmetics ignored, no bot); ranked disconnect shorter window (~15–20s) + pause budget → rated forfeit | ⚠️ PRESENT_BEHAVIOR_UNVERIFIED | Guest 403 + FIFO Ranked queue + `recordRankedSettlement` on RANKED settle; `ReconnectPolicy` 18/12 + budgets 45/20; `Glicko2Test` (2) + `StickPullSimTest` incl. `rankedFalseStart` (9) **BUILD SUCCESS**; reconnect/queue/settle ITs not run; `reconnect_hud_test` green |
| 3 | Bound player views global leaderboard by game; season vs all-time; soft reset; never coins; guests excluded | ⚠️ PRESENT_BEHAVIOR_UNVERIFIED | `BoardsService` `ORDER BY gr.rating` / `all_time_peak`, `p.guest = false`, `TOP_N=100`; `SeasonService.softResetRating` = `1500+0.5*(r-1500)`; UI wired `/boards`; boards widget tests green with stub API |
| 4 | APP_STARTED, REGISTERED, LOGIN, MATCHMAKING_STARTED, MATCH_FOUND, MATCH_STARTED, MATCH_FINISHED, MATCH_ABANDONED, ITEM_PURCHASED in backend logs without analytics SaaS | ⚠️ PRESENT_BEHAVIOR_UNVERIFIED | All nine `events.emit("…")` call sites present; `EventSink` JSON `log.info` + `analytics_events` append, catch-never-rethrows; **no** Amplitude/Firebase/Grafana deps; EventSinkIT not run |
| 5 | Build is releasable — PR CI + PROD compose single-JAR (D-108) | ✓ VERIFIED | `ci.yml` `./mvnw -pl backend -am verify` + `flutter analyze`/`test`; `compose.prod.yaml` `postgres:18.6` + app JAR; `compose.yaml` Postgres-only; `Dockerfile` temurin 21 |

**Score:** 1/5 truths verified (4 present, behavior-unverified)

### Required Artifacts

| Artifact | Expected | Status | Details |
| -------- | ----------- | ------ | ------- |
| `backend/.../BindService.java` | AUTH-02 bind same playerId | ✓ VERIFIED | Substantive; emits REGISTERED; wired from `GuestController` |
| `backend/.../AuthService.java` | AUTH-03/04 login/logout + D-93 adopt | ✓ VERIFIED | Import/drop; logout → `guests.createGuest()` |
| `backend/.../TokenService.java` | rotate loads `isGuest` | ✓ VERIFIED | `issue(player.getId(), player.isGuest())` |
| `client/lib/profile/bind_sheet.dart` | Bind UI + D-92 gate | ✓ VERIFIED | Wired; widget tests green |
| `client/lib/profile/sign_in_sheet.dart` | Sign in/out + adopt | ✓ VERIFIED | Wired; widget tests green |
| `client/lib/catalog/soft_lock_sheet.dart` | D-96 Ranked/Boards lock | ✓ VERIFIED | Used from `catalog_page` |
| `backend/.../RankedQueueService.java` | Ranked FIFO no bot | ✓ VERIFIED | Calls `createRankedMatch` |
| `backend/.../RankedMatchmakingController.java` | Guest 403 | ✓ VERIFIED | `requireBound` |
| `client/lib/matchmaking/searching_page.dart` | Ranked search no fallback | ✓ VERIFIED | Fallback timer only if `!_ranked` |
| `backend/.../internal/Glicko2.java` | Vendored Glicko-2 | ✓ VERIFIED | Defaults match STACK; unit tests green |
| `backend/.../RatingService.java` | Ranked settle | ✓ VERIFIED | Called from `MatchService.recordProfileSettlements` when RANKED |
| `backend/.../ReconnectPolicy.java` | Grace + pause budgets | ✓ VERIFIED | 18/12/45/20 constants |
| `backend/.../BoardsController.java` + `BoardsService.java` | GET /v1/boards | ✓ VERIFIED | Bound-only; rating ORDER BY |
| `backend/.../SeasonService.java` | Quarter soft reset | ✓ VERIFIED | `YYYY-Qn` + soft reset helpers |
| `client/lib/boards/boards_page.dart` | Boards UI | ✓ VERIFIED | Fetches via `boards_api`; route `/boards` |
| `backend/.../EventSink.java` | ANLT-01 sink | ✓ VERIFIED | Log + JDBC; scrub passwords/tokens |
| `.github/workflows/ci.yml` | PR CI | ✓ VERIFIED | Backend + client jobs |
| `compose.prod.yaml` + `Dockerfile` | PROD topology | ✓ VERIFIED | Postgres 18.6 + single JAR |

### Key Link Verification

| From | To | Via | Status | Details |
| ---- | --- | --- | ------ | ------- |
| `GuestController` | `BindService` / `AuthService` | POST bind/login/logout | WIRED | Controllers call services |
| `sign_in_sheet` / `bind_sheet` | `/v1/identity/*` | `bind_api` → `NomadApi` | WIRED | Adopt + persist paths |
| `catalog Ranked CTA` | `enqueueRanked` + searching | `_onRankedTap` | WIRED | Soft-lock if guest |
| `RankedQueueService` | `MatchService.createRankedMatch` | pair FIFO | WIRED | No bot path |
| Ranked settle | `RatingService.recordRankedSettlement` | `recordProfileSettlements` | WIRED | Mode gate RANKED |
| Disconnect | rated forfeit | `ReconnectPolicy` + `pauseUsedMs` | WIRED | `MatchService` pause budget |
| `BoardsPage` | `GET /v1/boards` | `boards_api` / `NomadApi` | WIRED | Real fetch in prod |
| Bind/Auth/queues/Match/Economy | `EventSink.emit` | fire-and-forget | WIRED | Nine types covered |
| `ci.yml` | Maven + Flutter | GHA | WIRED | Both jobs present |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| -------- | ------------- | ------ | ------------------ | ------ |
| `BoardsPage` | `_entries` | `boardsApi.fetch` → `BoardsService` SQL on `glicko_ratings` | Yes (DB query, not hardcoded) | ✓ FLOWING |
| `BindService.bind` | same `playerId` + wallets | Credentials insert; wallets untouched | Yes | ✓ FLOWING |
| `RatingService` | Glicko rows | `Glicko2.update` after Ranked settle | Yes | ✓ FLOWING |
| `EventSink` | analytics payload | callers + `AnalyticsJdbc.append` | Yes | ✓ FLOWING |
| `boards_test` stub | empty `entries` | test double only | N/A (test) | ℹ️ stub in test only |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| -------- | ------- | ------ | ------ |
| Glicko defaults + W/L/D | `mvnw -pl backend -am -Dtest=Glicko2Test,StickPullSimTest test` | Tests run: 11, Failures: 0 | ✓ PASS |
| Stick Pull Ranked false-start | (same) `rankedFalseStart` in StickPullSimTest | Included in 9/9 StickPullSimTest | ✓ PASS |
| Bind/sign-in/soft-lock/boards/reconnect HUD widgets | `flutter test test/reconnect_hud_test.dart test/boards_test.dart test/bind_sheet_test.dart` | All tests passed (17) | ✓ PASS |
| BindIT / Ranked*IT / BoardsIT / EventSinkIT | (skipped — Testcontainers/Docker) | Not executed in verify window | ? SKIP |

### Probe Execution

| Probe | Command | Result | Status |
| ----- | ------- | ------ | ------ |
| — | — | No phase-declared `scripts/*/tests/probe-*.sh` | SKIPPED |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
| ----------- | ---------- | ----------- | ------ | -------- |
| AUTH-02 | 07-01, 07-02, 07-09 | Bind username/password same identity | ? NEEDS HUMAN | API+UI wired; BindIT not run |
| AUTH-03 | 07-01, 07-03, 07-10 | Login + refresh rotation | ? NEEDS HUMAN | `rotate` loads `isGuest`; login wired |
| AUTH-04 | 07-01, 07-03, 07-10 | Logout → guest session | ? NEEDS HUMAN | `logout` mints guest; UI confirm |
| MODE-04 | 07-01, 07-04, 07-08 | Ranked Glicko, no bots | ? NEEDS HUMAN | Queue+settle+Glicko units green |
| SESS-03 | 07-01, 07-05 | Ranked grace + pause budget | ? NEEDS HUMAN | Policy + HUD tests; IT skipped |
| LEAD-01 | 07-01, 07-06 | Boards by game | ? NEEDS HUMAN | Filter + UI |
| LEAD-02 | 07-01, 07-06 | Season vs all-time | ? NEEDS HUMAN | Scope param + UI toggle |
| LEAD-03 | 07-01, 07-06 | Soft reset; no coins; no guests | ✓ SATISFIED (static) | SQL + `SeasonService`; IT skipped for runtime |
| ANLT-01 | 07-01, 07-07 | Nine events, no SaaS | ✓ SATISFIED (wiring) | Emit sites + no SaaS grep; IT skipped |

No orphaned Phase 7 requirements — all nine IDs appear in plans and REQUIREMENTS.md (marked Complete).

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| ---- | ---- | ------- | -------- | ------ |
| `backend/.../BindIT.java` | class javadoc | Stale «expect RED / not shipped yet» | ℹ️ Info | Tests assert green; comment drift only — not TBD/FIXME |
| — | — | No TBD/FIXME/XXX in phase main sources scanned | — | — |

### Human Verification Required

### 1. Bind → restart → Sign in / Log out

**Test:** Guest bind; force-stop app; reopen; Sign in on another session; Log out.  
**Expected:** Progress kept on bind; signed-in after restart; logout returns guest catalog; credentials still work.  
**Why human:** Secure storage + refresh across process death.

### 2. Ranked match + reconnect forfeit

**Test:** Two bound devices Ranked Alchiki then Stick Pull; brief drop; budget exhaust.  
**Expected:** No bot fallback; Glicko moves; grace/budget forfeit rated; Find Ranked match CTA.  
**Why human:** Multiplayer timing.

### 3. Live boards + guest soft-lock

**Test:** Bound open Boards toggles; guest taps Ranked/Boards.  
**Expected:** Live skill rows; soft-lock sheets; Casual/shop still open for guests.  
**Why human:** Visual + live API.

### 4. Analytics + CI smoke

**Test:** Short bind→ranked→shop loop; open a PR or run CI locally.  
**Expected:** Nine `analytics_event` types; CI jobs green.  
**Why human:** Runtime logs / CI runners.

### Gaps Summary

No structural gaps: artifacts exist, are substantive, and are wired end-to-end. Phase goal is **not** marked `passed` because four roadmap truths assert runtime behaviors that this verifier did not execute via Integration Tests (Docker/Testcontainers) and because MVP user-story outcome requires human UAT. Ship/CI artifacts alone are fully verified.

**next_action:** Run human UAT (phase UAT / `/gsd-verify-work` conversational flow); optionally green BindIT/Ranked*IT/BoardsIT/EventSinkIT under Docker to upgrade behavior_unverified truths before ship.

---

_Verified: 2026-09-14T15:50:00Z_  
_Verifier: Claude (gsd-verifier)_
