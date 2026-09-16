---
phase: 2
slug: guest-catalog-first-alchiki-match
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-09-06
---

# Phase 2 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Flutter `flutter_test` (client) + JUnit Jupiter via Spring Boot 4.1 BOM + harness JUnit 6.1.3 |
| **Config file** | `client/analysis_options.yaml`; backend `pom.xml` (Wave 0) |
| **Quick run command** | `. ./scripts/dev-env.ps1; Set-Location client; flutter test` |
| **Full suite command** | Client `flutter test` + `harness/mvnw.cmd -q test` + `backend/mvnw.cmd -q verify` |
| **Estimated runtime** | ~60 seconds automated; owner UAT extra |

---

## Sampling Rate

- **After every task commit:** Run `{quick run command}` for the touched tree (`flutter test` and/or `harness/mvnw.cmd -q test`)
- **After every plan wave:** Client `flutter test` + harness test + `backend/mvnw.cmd -q verify` (includes `ApplicationModules.verify()`)
- **Before `/gsd-verify-work`:** Full suite must be green **and** owner UAT: guest → EASY win under 3 minutes
- **Max feedback latency:** 60 seconds (automated)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| guest mint | TBD | 0 | AUTH-01 | T-02-guest | POST guest returns playerId + tokens; no username UI | integration | `backend` `@SpringBootTest` guest POST + catalog smoke | ❌ W0 | ⬜ pending |
| catalog Alchiki | TBD | 0 | CAT-01 | — | Catalog shows Alchiki playable | widget | `flutter test test/catalog_test.dart` | ❌ W0 | ⬜ pending |
| Coming Soon | TBD | 0 | CAT-03 | — | Coming Soon tiles not navigable | widget | same file | ❌ W0 | ⬜ pending |
| hold guard | TBD | 0 | ALCH-01 | — | Aim + Hold Throw + `isLoaded` guard (CR-01) | widget/unit | `flutter test test/match_hold_test.dart` | ❌ W0 | ⬜ pending |
| settle score | TBD | 1 | ALCH-02 | T-01-01 | Score = bones fully out after settle | unit | `pocket_settle_test.dart` + server score test | ✅ client / ❌ server | ⬜ pending |
| match rules | TBD | 0 | ALCH-03 | — | First to 5 / 8 turns / 4:00 / 5:00 | unit | `AlchikiRulesTest` on server | ❌ W0 | ⬜ pending |
| how-to skip | TBD | 0 | ALCH-04 | — | Skip on card 1; seen persisted; pause reopens | widget | `flutter test test/howto_test.dart` | ❌ W0 | ⬜ pending |
| sakaOut | TBD | 0 | ALCH-05 | T-01-01 | sakaOut → displayedScore 0 (CR-02) | unit | extend `replay_score_test.dart` + `BurstSimTest` | ⚠️ missing sakaOut case | ⬜ pending |
| scripted bot | TBD | 0 | BOT-01 | T-02-bot | Server emits ThrowInput per difficulty | unit | `ScriptedBotTest` | ❌ W0 | ⬜ pending |
| EASY path | TBD | 0 | BOT-03 | — | EASY bone count 5 + noisy aim | unit | same | ❌ W0 | ⬜ pending |
| forged score | TBD | 0 | SESS-01 | T-02-score | Client score fields ignored; only server ThrowResolved | integration | POST throw with forged `pocketedCount` ignored | ❌ W0 | ⬜ pending |
| i18n | TBD | 0 | PRES-01 | — | EN+RU keys present | unit | `flutter gen-l10n` + locale tests | ❌ W0 | ⬜ pending |
| palette | TBD | last | PRES-02 | — | Palette hex on catalog/match | widget/manual | grep + UI-SPEC | ⚠️ table exists; catalog does not | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `backend/` Maven module + `ModularityTest` + Testcontainers guest/match slice
- [ ] `client/test/catalog_test.dart` — CAT-01 / CAT-03
- [ ] `client/test/howto_test.dart` — ALCH-04 skip-from-card-1
- [ ] `client/test/match_hold_test.dart` — CR-01
- [ ] `client/test/replay_score_test.dart` — add `sakaOut: true` (CR-02)
- [ ] `client/l10n/app_en.arb` + `app_ru.arb` + `l10n.yaml`
- [ ] `harness` spawn-5/7 tests + WR-02 sleep keyframe
- [ ] Rewrite `client/test/widget_test.dart` when home becomes catalog (currently expects `SandboxApp` / “Table reset”)

Existing client tests to keep green: `throw_input_test.dart`, `physics_stepper_test.dart`, `pocket_settle_test.dart`, `replay_score_test.dart` (extended).

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| New player beats EASY in under 3 minutes | BOT-03 | Session length + skippable cards need a human | Guest → catalog → skip/read how-to → EASY match; win under 3 min |
| Catalog/match colorful nomadic style | PRES-02 | Visual style | Catalog + how-to + table use Phase 1 palette; Coming Soon not playable |
| Visible bot turn (aim + throw + settle) | BOT-01 | Animation readability | Bot turn is not an instant score popup |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 60s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
