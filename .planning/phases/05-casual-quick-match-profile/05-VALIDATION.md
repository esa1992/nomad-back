---
phase: 5
slug: casual-quick-match-profile
status: draft
nyquist_compliant: true
wave_0_complete: false
created: 2026-09-11
updated: 2026-09-11
---

# Phase 5 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Derived from `05-RESEARCH.md` § Validation Architecture.
> Task IDs remapped by planner revision 2026-09-11 (scope split 05-02 / 05-05).

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | JUnit 5 + Spring Boot Test + Testcontainers (backend); `flutter_test` (client) |
| **Config file** | backend Surefire via Maven; client `pubspec.yaml` / Flutter test |
| **Quick run command** | `.\mvnw.cmd -pl backend -am "-Dtest=CasualQueueIT,ProfileIT,CasualRematchIT,RematchIT,ReconnectIT,ModularityTest,EconomyIT" "-Dsurefire.failIfNoSpecifiedTests=false" test` and `. ./scripts/dev-env.ps1; flutter test test/catalog_test.dart test/matchmaking_test.dart test/profile_page_test.dart test/casual_rematch_test.dart` |
| **Full suite command** | `.\mvnw.cmd -pl backend -am test` ; `. ./scripts/dev-env.ps1; flutter test` |
| **Estimated runtime** | ~90–180 seconds (targeted); full suite longer |
| **Latency tip** | Mid-task: prefer narrower `-Dtest=ClassName` or `flutter test --name <case>` before full quick-run |

---

## Sampling Rate

- **After every task commit:** Run targeted IT or widget test for the touched seam
- **After every plan wave:** Run quick run command above
- **Before `/gsd-verify-work`:** Full backend + `flutter test` must be green
- **Max feedback latency:** ~180 seconds for quick run

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 05-01-01 | 01 | 0 | MODE-03…PROF-03 | T-05-01…06 | N/A stubs | IT stubs | create CasualQueueIT, ProfileIT, CasualRematchIT, ReconnectIT casual | ❌ W0 | ⬜ pending |
| 05-01-02 | 01 | 0 | MODE-03…PROF-03 | — | N/A stubs | widget stubs | matchmaking/profile/casual_rematch/catalog stubs | ❌ W0 | ⬜ pending |
| 05-02-01 | 02 | 1 | MODE-03, SESS-02 | T-05-01, T-05-05 | rate-limit enqueue; reject IN_PLAY; CASUAL rejoin | IT | `CasualQueueIT,ReconnectIT,ModularityTest` | ❌ W0 | ⬜ pending |
| 05-02-02 | 02 | 1 | MODE-03 | T-05-02 | CASUAL settle humanMatch=true parity with private | IT | `CasualQueueIT,EconomyIT` (casualSettleGrantsMatchPrivatePath) | ❌ W0 | ⬜ pending |
| 05-03-01 | 03 | 2 | MODE-03 | — | Cancel dequeues | widget | `matchmaking_test` cancelSearchReturnsCatalog | ❌ W0 | ⬜ pending |
| 05-03-02 | 03 | 2 | MODE-03 | — | Quick Match CTA + casual human match_page | widget | `catalog_test` + `matchmaking_test` cancelSearchReturnsCatalog (not full; fallback → 05-04) | ❌ W0 | ⬜ pending |
| 05-04-01 | 04 | 3 | MODE-03 | — | 8s → fallback; no countdown | widget | `matchmaking_test` fallbackAfterEightSeconds | ❌ W0 | ⬜ pending |
| 05-04-02 | 04 | 3 | MODE-03 | T-05-05 | dequeue before bot/invite/back | widget | `matchmaking_test` full | ❌ W0 | ⬜ pending |
| 05-05-01 | 05 | 4 | MODE-05 | T-05-04 | rematch requireSeat; CASUAL create | IT | `CasualRematchIT,RematchIT` | ❌ W0 | ⬜ pending |
| 05-05-02 | 05 | 4 | MODE-05 | — | Play again → rematch-wait; Cancel → catalog | widget | `casual_rematch_test` + `rematch_overlay_test` | ❌ W0 | ⬜ pending |
| 05-06-01 | 06 | 5 | PROF-01…03 | — | V9 + SoftElo + ProfileService compile | compile | `mvnw … test-compile` | ❌ W0 | ⬜ pending |
| 05-06-02 | 06 | 5 | PROF-01…03 | T-05-02, T-05-03, T-05-06 | settle-only XP/Elo; avatar allow-list; self-only GET | IT | `ProfileIT,ModularityTest` | ❌ W0 | ⬜ pending |
| 05-07-01 | 07 | 6 | PROF-01…03 | — | avatar chip → profile | widget | `catalog_test` | ❌ W0 | ⬜ pending |
| 05-07-02 | 07 | 6 | PROF-01…03 | — | Stick Pull zeros; Guest + Guest-XXXX; avatar save | widget | `profile_page_test` + `catalog_test` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky. Wave 0 files exist after 05-01.*

---

## Wave 0 Requirements

- [ ] `backend/src/test/java/com/nomadgames/matchmaking/CasualQueueIT.java` — MODE-03 pair + dequeue + concurrent/rate-limit + IN_PLAY reject + casualSettleGrantsMatchPrivatePath
- [ ] `backend/src/test/java/com/nomadgames/profile/ProfileIT.java` — PROF-01…03 + XP vs Elo split + self-only + Guest/Guest-XXXX
- [ ] `backend/src/test/java/com/nomadgames/session/CasualRematchIT.java` — MODE-05 CASUAL dual-accept + seat check
- [ ] Extend `backend/src/test/java/com/nomadgames/session/ReconnectIT.java` — SESS-02 for `mode=CASUAL`
- [ ] `client/test/matchmaking_test.dart` — Searching Cancel + 8s fallback
- [ ] `client/test/profile_page_test.dart` — Stick Pull empty + avatar save
- [ ] `client/test/casual_rematch_test.dart` — Play again → rematch-wait route
- [ ] Extend `client/test/catalog_test.dart` — Quick Match primary + avatar chip

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Felt Searching / fallback chrome on device | MODE-03 / UI-SPEC | Visual pulse + equal CTAs hard to assert in CI | After implementation: enqueue alone → 8s → equal bot/invite; Cancel returns catalog |
| Avatar chip TalkBack label | PROF-03 / a11y | Screen-reader on device | TalkBack announces Open profile on chip |

*Automated coverage remains primary; device UAT deferred post-MVP per project practice unless verify-work requires otherwise.*

---

## Threat → Test Cross-Reference

| Threat | Mitigation | Covered by |
|--------|------------|------------|
| T-05-01 Enqueue flood | Rate limit like JoinRateLimiter | 05-02-01 CasualQueueIT.enqueueRateLimited |
| T-05-02 Client MMR/XP + grant tampering | Server settle only; humanMatch from mode | 05-02-02 CasualQueueIT.casualSettleGrantsMatchPrivatePath + 05-06-02 ProfileIT |
| T-05-03 Avatar upload/XSS | Preset enum only | 05-06-02 ProfileIT putAvatarAllowList |
| T-05-04 Rematch seat steal | requireSeat | 05-05-01 CasualRematchIT.casualRematchRequiresSeat |
| T-05-05 Double-queue while IN_PLAY | Reject enqueue; dequeue on invite | 05-02-01 + 05-04-02 |
| T-05-06 Enumerate profiles | Self-only GET | 05-06-02 ProfileIT.profileSelfOnly |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 180s for quick run
- [x] `nyquist_compliant: true` set after planner mapped task IDs

**Approval:** planner revision mapped 2026-09-11 — execute phase next
