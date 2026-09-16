---
phase: 3
slug: private-rooms-casual-reconnect
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-09-07
---

# Phase 3 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Flutter `flutter_test` + JUnit Jupiter (Spring Boot 4.1 BOM) + existing Testcontainers ITs |
| **Config file** | `client/analysis_options.yaml`; repo-root `pom.xml` aggregator (`-pl backend -am`) |
| **Quick run command** | `. ./scripts/dev-env.ps1; .\mvnw.cmd -pl backend -am test -Dtest=ModularityTest,AlchikiRulesTest; Set-Location client; flutter test test/catalog_test.dart` |
| **Full suite command** | `. ./scripts/dev-env.ps1; .\mvnw.cmd -pl harness,backend -am verify` + `Set-Location client; flutter test` |
| **Estimated runtime** | ~90 seconds automated; owner UAT extra |

---

## Sampling Rate

- **After every task commit:** Run the touched tree (`flutter test test/<file>.dart` and/or `-Dtest=Class#method`)
- **After every plan wave:** `ModularityTest` + Room/Reconnect/Leave ITs + `catalog_test` / rematch overlay
- **Before `/gsd-verify-work`:** Full suite must be green **and** owner UAT: create → join → both Ready → throw → drop/rejoin 30s → rematch → leave
- **Max feedback latency:** 90 seconds (automated)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| create room code | TBD | 0 | MODE-01 | T-03-code | Create returns 4–6 alphanumeric code | integration | `.\mvnw.cmd -pl backend -am test -Dtest=RoomIT#createReturnsCode` | ❌ W0 | ⬜ pending |
| join by code | TBD | 0 | MODE-02 | T-03-join | Join succeeds; errors keep field | integration + widget | `RoomIT#join*` + `flutter test test/join_code_test.dart` | ❌ W0 | ⬜ pending |
| host-alive TTL | TBD | 0 | MODE-02 | T-03-host | Host leave kills code; 10 min idle closes | integration | `RoomIT#hostLeaveCloses` / `#idleTtlCloses` | ❌ W0 | ⬜ pending |
| both Ready | TBD | 0 | D-27 | — | Both Ready starts; joiner first | integration | `RoomIT#bothReadyStartsJoinerTurn` | ❌ W0 | ⬜ pending |
| bot rematch | TBD | 0 | MODE-05 | — | Bot Play again one-tap | widget | `flutter test test/rematch_overlay_test.dart` | ❌ W0 | ⬜ pending |
| private rematch | TBD | 0 | MODE-05 | T-03-rematch | 10s dual accept / timeout | integration | `.\mvnw.cmd -pl backend -am test -Dtest=RematchIT` | ❌ W0 | ⬜ pending |
| rejoin 30s | TBD | 0 | SESS-02 | T-03-rejoin | 30s hold + full snapshot; clocks paused | integration | `.\mvnw.cmd -pl backend -am test -Dtest=ReconnectIT` | ❌ W0 | ⬜ pending |
| token rotate | TBD | 0 | SESS-02 | T-03-token | Rotate; reject reuse / expiry | integration | `ReconnectIT#tokenRotateAndExpire` | ❌ W0 | ⬜ pending |
| leave bot | TBD | 0 | SESS-05 | T-02-18 | Leave vs bot → `BOT_WIN` | integration | existing `ThrowAuthorityIT` leave cases | ✅ | ⬜ pending |
| leave human | TBD | 0 | SESS-05 | T-03-leave | Leave vs human → opponent win, not `BOT_WIN` | integration | `LeaveIT#privateLeaveOpponentWins` | ❌ W0 | ⬜ pending |
| forged score | TBD | 0 | SESS-01 | T-02-score | Forged score on WS/REST ignored | integration | extend `ThrowAuthorityIT#forgedClientScoreIsIgnoredOnThrow` | ✅ extend | ⬜ pending |
| modulith | TBD | 0 | — | — | `games ↔ session` acyclic | unit | `.\mvnw.cmd -pl backend -am test -Dtest=ModularityTest` | ✅ (currently red) | ⬜ pending |
| catalog CTAs | TBD | 0 | D-26 | — | Play Alchiki + chips + Create/Join | widget | extend `test/catalog_test.dart` | ✅ extend | ⬜ pending |
| i18n | TBD | last | PRES-01 | — | New EN/RU keys | widget | `catalog_test` + arb compile | ⚠️ extend ARB | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `ModularityTest` green — `GameEngine` SPI expansion; `MatchStatus` in `session`; no `session` → `games` imports
- [ ] `backend/.../RoomIT.java` — MODE-01/02, host-alive, TTL, both-Ready, joiner-first
- [ ] `backend/.../ReconnectIT.java` — 30s snapshot, clock pause, token rotate, grace expiry win
- [ ] `backend/.../RematchIT.java` — 10s dual accept / timeout
- [ ] `backend/.../LeaveIT.java` or extend `ThrowAuthorityIT` — private leave ≠ `BOT_WIN`
- [ ] `client/test/join_code_test.dart` — error copy, field remains
- [ ] `client/test/rematch_overlay_test.dart` — bot Play again vs private Again?
- [ ] Flyway `V3__rooms_and_seats.sql`
- [ ] `spring-boot-starter-websocket` in `backend/pom.xml`
- [ ] `web_socket_channel` 3.0.3 + `share_plus` 13.3.0 in `client/pubspec.yaml`
- [ ] ARB keys: createRoom, joinByCode, noSuchRoom, alreadyStarted, hostLeft, ready, rematchAgain, playAgain, reconnecting, opponentWins, copy, share

Existing tests that must stay green: `ThrowAuthorityIT`, `CatalogIT`, `GuestIdentityIT`, `AlchikiRulesTest`, `ScriptedBotTest`, `catalog_test.dart`, `bot_turn_test.dart`, `howto_test.dart`, harness `BurstSimTest`.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Create → join → both Ready → throw | MODE-01/02 | Two devices / two guests | Host Create room, share code; joiner Join; both Ready; joiner throws first |
| Drop / rejoin within 30s | SESS-02 | Airplane / swipe-away | During private match, drop network; opponent sees reconnecting + timer; rejoin with full snapshot |
| Private rematch 10s | MODE-05 | Dual-accept UX | After result, both tap Again? within 10s; timeout returns to catalog |
| Leave is immediate loss | SESS-05 | Confirm dialog + opponent banner | Pause → Leave confirm; leaver loses; remaining player sees opponent win (not BOT_WIN) |
| Opponent turn readability | D-34/D-35 | Animation | Waiting player sees aiming pose + 20s, then aim+hold+keyframes — not instant score |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 90s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
