---
phase: 07
slug: bind-ranked-ship
status: verified
nyquist_compliant: true
wave_0_complete: true
created: 2026-09-15
updated: 2026-09-15
---

# Phase 7 — Validation Strategy

> Nyquist validation for bind / Ranked / boards / analytics / ship. ASVS L1. Mode: mvp.
> State A audit 2026-09-15: mapped ITs/widgets green; WR-06 max-password IT added; Wave 0 closed.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | JUnit 5 + Spring Boot Test / Testcontainers (backend); `flutter_test` (client) |
| **Config file** | `backend/pom.xml` Surefire defaults; client `flutter_test` |
| **Quick run command** | `. ./scripts/dev-env.ps1; .\mvnw.cmd -pl backend -am "-Dtest=BindIT,Glicko2Test,RankedQueueIT,RankedSettleIT,RankedReconnectIT,BoardsIT,EventSinkIT,StickPullSimTest" test` |
| **Flutter quick** | `. ./scripts/dev-env.ps1; cd client; flutter test test/bind_sheet_test.dart test/boards_test.dart test/ranked_search_test.dart test/reconnect_hud_test.dart` |
| **Full suite command** | `./mvnw -pl backend -am verify` + `cd client && flutter analyze && flutter test` |
| **Estimated runtime** | ~4–5 min backend quick · ~30 s Flutter quick |

---

## Sampling Rate

- **After every task commit:** targeted `*IT` / widget test for touched req
- **After every plan wave:** backend module tests + affected Flutter tests
- **Before `/gsd-verify-work`:** Full `./mvnw -pl backend -am verify` + `flutter analyze` + `flutter test` green
- **Max feedback latency:** ~300 s (Testcontainers)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 07-02-01 | 02 | 1 | AUTH-02 | T-07-04 | Bind same playerId; wallets unchanged | IT | `.\mvnw.cmd -pl backend -am "-Dtest=BindIT#bindKeepsPlayerIdNoSum" test` | ✅ | ✅ green |
| 07-02-02 | 02 | 1 | AUTH-02 | T-07-04 | Username taken → 409 | IT | `.\mvnw.cmd -pl backend -am "-Dtest=BindIT#usernameTaken409" test` | ✅ | ✅ green |
| 07-02-03 | 02 | 1 | AUTH-02 | T-07-04 | Username charset/length → 400; password &lt; 8 → 400 | IT | `.\mvnw.cmd -pl backend -am "-Dtest=BindIT#usernameInvalid400" test` | ✅ | ✅ green |
| 07-02-04 | 02 | 1 | WR-06 | T-07-04 | Password &gt; 128 → 400 on bind + login | IT | `.\mvnw.cmd -pl backend -am "-Dtest=BindIT#passwordLongerThan128Rejected400" test` | ✅ | ✅ green |
| 07-03-01 | 03 | 1 | AUTH-03 | T-07-08 | Login + refresh guest=false (TokenService.rotate from DB) | IT | `.\mvnw.cmd -pl backend -am "-Dtest=BindIT#loginThenRefreshBound" test` | ✅ | ✅ green |
| 07-03-02 | 03 | 1 | AUTH-04 | T-07-08 | Logout mints guest; bound row intact | IT | `.\mvnw.cmd -pl backend -am "-Dtest=BindIT#logoutMintsGuest" test` | ✅ | ✅ green |
| 07-03-03 | 03 | 1 | AUTH-02/D-93 | — | Sign-in never sums onto non-empty | IT | `.\mvnw.cmd -pl backend -am "-Dtest=BindIT#loginNeverSumsOntoNonEmptyTarget" test` | ✅ | ✅ green |
| 07-03-04 | 03 | 1 | AUTH-02/D-93 | — | Empty-target import | IT | `.\mvnw.cmd -pl backend -am "-Dtest=BindIT#loginEmptyTargetImportsGuest" test` | ✅ | ✅ green |
| 07-03-05 | 03 | 1 | AUTH-02/D-93 | — | Drop guest leaves bound intact | IT | `.\mvnw.cmd -pl backend -am "-Dtest=BindIT#loginDropGuestLeavesBoundIntact" test` | ✅ | ✅ green |
| 07-03-06 | 03 | 1 | CR-01 | T-07-08 | Adopt without guest possession → 401 | IT | `.\mvnw.cmd -pl backend -am "-Dtest=BindIT#loginAdoptWithoutGuestPossessionIsUnauthorized" test` | ✅ | ✅ green |
| 07-03-07 | 03 | 1 | CR-01 | T-07-08 | Adopt accepts guestRefreshToken possession | IT | `.\mvnw.cmd -pl backend -am "-Dtest=BindIT#loginAdoptAcceptsGuestRefreshPossession" test` | ✅ | ✅ green |
| 07-04-01 | 04 | 2 | MODE-04 | — | Guest Ranked enqueue rejected | IT | `.\mvnw.cmd -pl backend -am "-Dtest=RankedQueueIT#guestRejected" test` | ✅ | ✅ green |
| 07-04-02 | 04 | 2 | MODE-04 | — | Pair → RANKED match; no bot | IT | `.\mvnw.cmd -pl backend -am "-Dtest=RankedQueueIT#pairCreatesRanked" test` | ✅ | ✅ green |
| 07-08-01 | 08 | 2 | MODE-04 | T-07-03 | Glicko defaults + win/loss/draw | unit | `.\mvnw.cmd -pl backend -am "-Dtest=Glicko2Test" test` | ✅ | ✅ green |
| 07-08-02 | 08 | 2 | MODE-04 | T-07-03 | Glicko settle SoftElo untouched | IT | `.\mvnw.cmd -pl backend -am "-Dtest=RankedSettleIT" test` | ✅ | ✅ green |
| 07-08-03 | 08 | 2 | D-100 | — | Ranked false-start 70% then forfeit | unit | `.\mvnw.cmd -pl backend -am "-Dtest=StickPullSimTest#rankedFalseStart" test` | ✅ | ✅ green |
| 07-05-01 | 05 | 2 | SESS-03 | — | Grace 18/12; pause budget forfeit | IT | `.\mvnw.cmd -pl backend -am "-Dtest=RankedReconnectIT" test` | ✅ | ✅ green |
| 07-05-02 | 05 | 2 | SESS-03 | — | Ranked reconnect HUD copy | widget | `flutter test test/reconnect_hud_test.dart` | ✅ | ✅ green |
| 07-06-01 | 06 | 2 | LEAD-01..03 | T-07-23 | Boards filter; guests excluded; no coins | IT | `.\mvnw.cmd -pl backend -am "-Dtest=BoardsIT" test` | ✅ | ✅ green |
| 07-06-02 | 06 | 2 | LEAD-01..03 | — | Boards UI game filter / season toggle | widget | `flutter test test/boards_test.dart` | ✅ | ✅ green |
| 07-07-01 | 07 | 3 | ANLT-01 | T-07-25 | Nine event types logged / rows | IT | `.\mvnw.cmd -pl backend -am "-Dtest=EventSinkIT" test` | ✅ | ✅ green |
| 07-07-02 | 07 | 3 | CI meta | — | Maven verify + flutter analyze/test | meta | inspect `.github/workflows/ci.yml` | ✅ | ✅ green |
| 07-09-01 | 09 | 3 | AUTH UI | — | Bind sheet / soft-lock / D-92 funnel | widget | `flutter test test/bind_sheet_test.dart` | ✅ | ✅ green |
| 07-10-01 | 10 | 3 | AUTH-03/04 UI | — | Sign-in / logout / Ranked soft-lock | widget | `flutter test test/bind_sheet_test.dart test/ranked_search_test.dart` | ✅ | ✅ green |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] `BindIT.java` — AUTH-02…04, D-93 adopt trio, CR-01 possession, WR-06 password max 128 — **COVERED green**
- [x] `Glicko2Test.java` — defaults + win/loss/draw — **COVERED green**
- [x] `RankedQueueIT.java` — guest reject, pair, no bot — **COVERED green**
- [x] `RankedSettleIT.java` — Glicko settle SoftElo isolation + Alchiki draw 0.5/0.5 — **COVERED green**
- [x] `RankedReconnectIT.java` — 18/12 grace + pause budget forfeit — **COVERED green**
- [x] `BoardsIT.java` — season/all-time, bound-only, no coins order — **COVERED green**
- [x] `EventSinkIT.java` — nine event types — **COVERED green**
- [x] Flutter: `bind_sheet_test.dart`, `boards_test.dart`, `ranked_search_test.dart`, `reconnect_hud_test.dart` — **COVERED green**
- [x] `StickPullSimTest#rankedFalseStart` — D-100 — **COVERED green**
- [x] `TokenService.rotate` bound claim — covered by `BindIT#loginThenRefreshBound` (refresh `guest=false`) — **COVERED green**
- [x] CI workflow `.github/workflows/ci.yml` — `./mvnw -pl backend -am verify` + `flutter analyze` + `flutter test` — **COVERED (meta)**

---

## Manual-Only Verifications

All phase behaviors have automated verification. Live UAT of Ranked matchmaking UX remains optional human smoke outside Nyquist gate.

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency acceptable for Testcontainers ITs
- [x] `nyquist_compliant: true` set in frontmatter

**Last green runs (2026-09-15):**
- Backend quick suite: 38 tests → BUILD SUCCESS (pre WR-06); `BindIT#passwordLongerThan128Rejected400` → green
- Flutter: 20 tests → All tests passed
- CI meta: `.github/workflows/ci.yml` verified present

**Approval:** approved 2026-09-15 (State A Nyquist audit)
