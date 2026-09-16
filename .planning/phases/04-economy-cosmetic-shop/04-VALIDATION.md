---
phase: 4
slug: economy-cosmetic-shop
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-09-10
---

# Phase 4 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Flutter `flutter_test` + JUnit Jupiter (Spring Boot 4.1 BOM) + Testcontainers |
| **Config file** | `client/analysis_options.yaml`; repo-root `pom.xml` aggregator (`-pl backend -am`) |
| **Quick run command** | `. ./scripts/dev-env.ps1; .\mvnw.cmd -pl backend -am test -Dtest=ModularityTest,EconomyIT; Set-Location client; flutter test test/shop_wallet_test.dart` |
| **Full suite command** | `. ./scripts/dev-env.ps1; .\mvnw.cmd -pl harness,backend -am verify` + `Set-Location client; flutter test` |
| **Estimated runtime** | ~90 seconds automated; owner UAT extra |

---

## Sampling Rate

- **After every task commit:** Run touched tree (`-Dtest=EconomyIT#…` and/or `flutter test test/<file>.dart`)
- **After every plan wave:** `ModularityTest` + `EconomyIT` + shop/catalog/result widget tests
- **Before `/gsd-verify-work`:** Full suite green **and** owner UAT: finish match → see grant → Shop → buy → equip → next match shows loadout
- **Max feedback latency:** 90 seconds (automated)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| match grant | TBD | 0 | ECON-01 | T-04-grant | Terminal settle grants; replay matchId no double | integration | `.\mvnw.cmd -pl backend -am test -Dtest=EconomyIT#matchGrantIdempotent` | ❌ W0 | ⬜ pending |
| leave/drop grant | TBD | 0 | ECON-01 | T-04-grant | Leave / reconnect expiry also grants | integration | `EconomyIT#leaveAndDropGrant` | ❌ W0 | ⬜ pending |
| shop catalog | TBD | 0 | ECON-02 | — | GET catalog: 7 categories + thin SKUs | integration | `EconomyIT#catalogHasSevenCategories` | ❌ W0 | ⬜ pending |
| guest purchase | TBD | 0 | ECON-02 | T-04-buy | Guest buys with COINS | integration | `EconomyIT#guestPurchase` | ❌ W0 | ⬜ pending |
| equip loadout | TBD | 0 | ECON-03 | T-04-p2w | Equip persists; match create has loadout; physics unchanged | integration | `EconomyIT#equipOnCreate` | ❌ W0 | ⬜ pending |
| forged balance | TBD | 0 | ECON-04 | T-04-forge | Client coinsDelta / forged balance ignored | integration | `EconomyIT#forgedBalanceRejected` | ❌ W0 | ⬜ pending |
| purchase idempotent | TBD | 0 | ECON-05 | T-04-idem | Same idempotencyKey → one debit | integration | `EconomyIT#purchaseIdempotent` | ❌ W0 | ⬜ pending |
| purchases table | TBD | 0 | ECON-05 | T-04-iap | Empty UNIQUE `purchases.token` | integration | `EconomyIT#purchasesTableUnique` | ❌ W0 | ⬜ pending |
| wallet + shop UI | TBD | 0 | ECON-02 | — | Catalog chip + `/shop` + empty/error | widget | `flutter test test/shop_wallet_test.dart` | ❌ W0 | ⬜ pending |
| result rewards | TBD | 0 | ECON-01 | — | ResultOverlay `+N COINS` / GEMS; Shop secondary | widget | `flutter test test/result_reward_test.dart` | ❌ W0 | ⬜ pending |
| modulith | TBD | 0 | — | — | `economy` module; no illegal cycles | unit | `.\mvnw.cmd -pl backend -am test -Dtest=ModularityTest` | ✅ extend | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `backend/.../EconomyIT.java` — ECON-01…05 server behaviors
- [ ] `client/test/shop_wallet_test.dart` — catalog chip + Shop route + empty/error
- [ ] `client/test/result_reward_test.dart` — ResultOverlay rewards + Shop secondary link
- [ ] Flyway `V7__economy_ledger_shop.sql` — wallets, ledger, soft_purchases, purchases, cosmetic_skus, inventory, loadout + seed defaults
- [ ] ARB keys from 04-UI-SPEC (EN+RU)
- [ ] Framework install: none — existing Testcontainers + flutter_test

Existing tests that must stay green: `ThrowAuthorityIT`, `RoomIT` / reconnect / rematch ITs, `CatalogIT`, `GuestIdentityIT`, `AlchikiRulesTest`, `ModularityTest`, `catalog_test.dart`, rematch/join overlay tests, harness `BurstSimTest`. Do **not** reopen forge2d 0.14.2.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Felt preview + theme SKUs | ECON-02 / PRES-02 | Visual | Open Shop; browse Gold/Neon/Ice/Fire/Space; detail shows felt disk preview |
| Equip visible next match | ECON-03 | Live table | Equip paid saka color; start bot match; confirm presentation only (same throw feel) |
| Rematch CTAs stay primary | D-46 | Overlay UX | After bot/private result, rematch buttons remain primary; rewards visible; Shop is secondary |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 90s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
