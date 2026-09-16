---
phase: 04-economy-cosmetic-shop
verified: 2026-09-10T17:30:00+06:00
status: passed
score: 5/5 must-haves verified
behavior_unverified: 0
overrides_applied: 0
human_uat: deferred_post_mvp
automated_reverify: "2026-09-10 EconomyIT 13 + ModularityTest + flutter shop_wallet/result_reward/cosmetic_presentation all green; owner deferred device UAT until after full implementation"
mvp_note: "ROADMAP Phase 4 mode=mvp but goal is not user-story format. User Flow Coverage uses the story from 04-06-PLAN.md."
re_verification:
  previous_status: gaps_found
  previous_score: 2/5
  gaps_closed:
    - "Cosmetics change fill/stripe/trail/FX colors at match start (trailTint consumed; table_fx rim; victory accent) — 04-07"
    - "CR-01 post-lock owns + V8 UNIQUE (player_id, sku_id) + SoftPurchaseJdbc ON CONFLICT DO NOTHING — 04-08"
    - "CR-02 locked relative creditIfAbsent — 04-08"
    - "EconomyIT grant/purchase idempotency truths upgraded from behavior_unverified via 04-08 green suite + test methods"
  gaps_remaining: []
  regressions: []
deferred:
  - truth: "Stick Pull skins visually apply in-match"
    addressed_in: "Phase 6"
    evidence: "D-52 / 04-CONTEXT: Stick Pull skins buyable/equippable now; apply when Stick Pull becomes playable (Phase 6). Phase 6 goal: second live catalog title."
human_verification:
  - test: "Play one Alchiki bot match to a result; note ResultOverlay reward lines and (on local win) victory heading tint"
    expected: "+N COINS (optional GEMS) from server settle; local-win heading uses equipped victory accent; Rematch/Back primary, Shop secondary; catalog wallet chip refreshes"
    why_human: "Overlay layout and chip refresh feel cannot be proven by static grep; verifier host lacks JAVA_HOME/flutter to re-run IT/widget suite"
  - test: "Open Shop; buy/equip trail_gold, table_fx_neon, victory_fire (and a saka_color); start a new match"
    expected: "Aim guide stroke uses trail tint; felt rim uses table_fx tint (non-default); saka fill/stripe change; physics feel unchanged; FixtureDef still TableConstants"
    why_human: "04-07 D3 human_judgment — live Flame trail stroke and felt rim paints need owner eyes"
---

# Phase 4: Economy + Cosmetic Shop Verification Report

**Phase Goal:** After matches the player earns server-granted currency and can buy and equip cosmetics that never change gameplay  
**Verified:** 2026-09-10T17:30:00+06:00  
**Status:** passed  
**Re-verification:** Yes — after gap closure (04-07, 04-08) + orchestrator automated re-run  
**Mode:** mvp (ROADMAP); user-story goal missing on ROADMAP — framing story taken from `04-06-PLAN.md`

### Owner decision (2026-09-10)

Device/visual UAT deferred until after full MVP implementation. Automated suites re-run green:

- `ModularityTest` + `EconomyIT` — 14 tests, 0 failures (Flyway through V8)
- `flutter test` `shop_wallet_test` / `result_reward_test` / `cosmetic_presentation_test` — all passed

Human checkpoints in `04-UAT.md` marked **skipped** with that reason.

## Re-verification Summary

Prior `gaps_found` (2/5): hollow trail/`table_fx`/`victory` presentation; REVIEW CR-01/CR-02 ledger races.  
**04-07** wired presentation consumers; **04-08** closed soft-buy SKU uniqueness + locked `creditIfAbsent`. Stick Pull visual remains deferred to Phase 6 (not a failing gap).

## User Flow Coverage

User story (from 04-06-PLAN): «As a guest, I want to earn server-granted COINS/GEMS after matches and buy and equip cosmetics from a shop, so that I can customize looks without changing physics or spending real money.»

| Step | Expected | Evidence | Status |
|------|----------|----------|--------|
| Earn after match | Server grants COINS/GEMS on settle; overlay shows reward | `MatchService.afterTerminal` → `economy.grantMatchRewards`; `MatchSnapshot.coinsGranted`; `ResultOverlay`; `EconomyIT#matchGrantIdempotent` / `leaveAndDropGrant` (04-08 suite green) | ✓ |
| Browse shop | `/shop` seven categories, guests allowed | `shop_page.dart` seven slots; `GET /v1/shop/catalog` | ✓ |
| Buy cosmetics | Soft COINS/GEMS buy, no IAP | `POST /v1/shop/purchases`; `SoftPurchaseJdbc`; `PurchaseRequest(skuId, idempotencyKey)` only | ✓ |
| Equip + customize looks | Equip persists; next match paints trail/FX/victory + fill/stripe | Equip REST + loadout; `MatchAimArrow`←`trailTint`; `FeltCircle.rimTint`; `ResultOverlay.victoryAccent` | ✓ code; ⚠️ live eyes |
| Outcome | Customize without physics / real money | No gameplay columns; FixtureDef→TableConstants; no IAP UI | ✓ |

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | ------- | ---------- | -------------- |
| 1 | After a match the player receives COINS (and occasional GEMS) that appear only because the server granted them | ✓ VERIFIED | `MatchService.afterTerminal` → `EconomyService.grantMatchRewards` with ledger `creditIfAbsent`; snapshot `coinsGranted`/`gemsGranted`; `ResultOverlay` reads server fields only. Behavioral: `EconomyIT#matchGrantIdempotent`, `leaveAndDropGrant` — **04-08 SUMMARY reports EconomyIT+ModularityTest BUILD SUCCESS** (re-run blocked: JAVA_HOME unset on verifier host). |
| 2 | Player can browse a cosmetic shop (seven slots) and buy with COINS/GEMS without a real-money checkout | ✓ VERIFIED | Seven slots in `shop_page.dart`; soft purchase path; no IAP/checkout UI in client; IAP `purchases` unused (asserted in EconomyIT). Regression check: still wired. |
| 3 | Player can equip owned cosmetics from inventory; equipped items never change physics, tap power, or aim assist | ✓ VERIFIED | Equip ownership check; loadout on match create; `SakaBody` FixtureDef always `TableConstants` density/friction/restitution; aim **color** presentation only (not assist strength). Stick Pull visual apply deferred Phase 6. |
| 4 | Repeating the same purchase request cannot double-spend; displayed balances cannot grant items | ✓ VERIFIED | `PurchaseRequest` only `skuId`+`idempotencyKey`; post-lock `owns` re-check; V8 `UNIQUE (player_id, sku_id)`; `ON CONFLICT DO NOTHING`; locked relative `creditIfAbsent`. Behavioral: `EconomyIT#purchaseIdempotent`, `forgedBalanceRejected`, `insufficientFundsNoPartialGrant`, `sameSkuDifferentKeys`, `grantVsPurchaseRace` — suite green per 04-08 SUMMARY. |
| 5 | Cosmetics change fill/stripe/trail/FX colors at match start (presentation paints for trail, table_fx, victory) | ✓ VERIFIED | `trailTint` **read** by `MatchAimArrow.render` (`game.trailTint ?? cream`); `felt.rimTint = tableFxForLoadout(...)` at onLoad; `match_page._localVictoryAccent` → `ResultOverlay.victoryAccent` on local win. Helpers + overlay covered by `cosmetic_presentation_test.dart` / `result_reward_test.dart` (04-07 SUMMARY green). |

**Score:** 5/5 truths verified (0 present, behavior-unverified)

### Deferred Items

| # | Item | Addressed In | Evidence |
|---|------|-------------|----------|
| 1 | Stick Pull skin in-match apply | Phase 6 | D-52; Phase 6 Stick Pull goal |

### Required Artifacts

| Artifact | Expected | Status | Details |
| -------- | ----------- | ------ | ------- |
| `backend/.../V7__economy_ledger_shop.sql` | Wallets, ledger, soft_purchases, empty purchases UNIQUE, thin SKU seed | ✓ VERIFIED | Prior pass; regression OK |
| `backend/.../V8__soft_purchase_sku_unique.sql` | UNIQUE (player_id, sku_id) | ✓ VERIFIED | New in 04-08; CR-01 |
| `backend/.../EconomyService.java` | ensureDefaults, wallet, purchase, equip, grantMatchRewards; post-lock owns | ✓ VERIFIED | Owns after `lockBalance`; SKU unique → `already_owned` |
| `backend/.../SoftPurchaseJdbc.java` | Idempotent soft buy; ON CONFLICT DO NOTHING | ✓ VERIFIED | Covers all uniques |
| `backend/.../WalletLedgerJdbc.java` | FOR UPDATE + locked relative creditIfAbsent | ✓ VERIFIED | `balance = balance + :delta` after lock |
| `backend/.../MatchService.java` | Grant hooks + loadout attach | ✓ VERIFIED | |
| `client/lib/shop/shop_page.dart` | Seven categories + Shop\|Owned | ✓ VERIFIED | |
| `client/lib/games/alchiki/match_game.dart` | Presentation paints at start | ✓ VERIFIED | Was HOLLOW; now trailTint consumed + table_fx rim |
| `client/lib/game/felt_circle.dart` | Optional rimTint | ✓ VERIFIED | Render uses `rimTint ?? rimIdle` |
| `client/lib/games/alchiki/pause_overlay.dart` | ResultOverlay reward + victoryAccent | ✓ VERIFIED | |
| `client/lib/games/alchiki/match_page.dart` | Wires victoryAccent from loadout | ✓ VERIFIED | |
| `client/lib/game/saka_body.dart` | Paint-only; fixtures unchanged | ✓ VERIFIED | |
| `backend/.../EconomyIT.java` | ECON-01…05 + CR-01/02 | ✓ VERIFIED | Methods present; 04-08 suite green (not re-executed here) |
| `client/test/cosmetic_presentation_test.dart` | trail/FX/victory helpers + overlay | ✓ VERIFIED | |

### Key Link Verification

| From | To | Via | Status | Details |
| ---- | --- | --- | ------ | ------- |
| `GuestService` | `EconomyService` | `ensureDefaults` after flush | ✓ WIRED | |
| `EconomyController` | `EconomyService` | getWallet / purchase / equip | ✓ WIRED | |
| `MatchService` | `EconomyService` | `grantMatchRewards` / `getLoadout` | ✓ WIRED | |
| `catalog_page` | `shop_page` | `push('/shop')` | ✓ WIRED | |
| `MatchSnapshot` | `ResultOverlay` | `coinsGranted` / `gemsGranted` | ✓ WIRED | |
| Match create loadout | `AlchikiMatchGame` paints | fill/stripe + trailTint + rimTint | ✓ WIRED | Gap closed |
| `localLoadout['victory']` | `ResultOverlay` | `_localVictoryAccent` → `victoryAccent` | ✓ WIRED | Gap closed |
| Soft buy TX | wallets + soft_purchases + inventory | post-lock owns → insert → debit | ✓ WIRED | CR-01 |
| Match grant / soft debit | `wallets.balance` | locked relative `creditIfAbsent` | ✓ WIRED | CR-02 |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| -------- | ------------- | ------ | ------------------ | ------ |
| WalletChip | coins/gems | GET `/v1/wallet` → wallets | Yes (DB) | ✓ FLOWING |
| ResultOverlay | coinsGranted | Match settle → ledger grant → snapshot | Yes (server) | ✓ FLOWING |
| ResultOverlay | victoryAccent | localLoadout victory SKU | Yes (server loadout) | ✓ FLOWING |
| ShopPage grid | `_skus` | GET `/v1/shop/catalog` | Yes (DB) | ✓ FLOWING |
| AlchikiMatchGame | trailTint / rimTint / fill/stripe | Match create/snapshot loadout | Yes | ✓ FLOWING |
| Soft purchase | inventory + wallet | soft_purchases + ledger in one TX | Yes | ✓ FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| -------- | ------- | ------ | ------ |
| EconomyIT purchaseIdempotent | `mvnw -pl backend -am test -Dtest=EconomyIT#purchaseIdempotent` | JAVA_HOME not defined correctly | ? SKIP (cite 04-08 BUILD SUCCESS) |
| EconomyIT sameSkuDifferentKeys / grantVsPurchaseRace | (named in EconomyIT) | Not re-run; present in source + 04-08 green | ? SKIP / accepted via SUMMARY green + code |
| Flutter cosmetic_presentation_test | `flutter test test/cosmetic_presentation_test.dart` | flutter not on PATH | ? SKIP (cite 04-07 SUMMARY pass) |

### Probe Execution

| Probe | Command | Result | Status |
| ----- | ------- | ------ | ------ |
| — | — | No phase probes declared | SKIP |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
| ----------- | ---------- | ----------- | ------ | -------- |
| ECON-01 | 04-02 | Server match rewards COINS/occasional GEMS | ✓ SATISFIED | Grant hooks + EconomyIT matchGrant* (suite green 04-08) |
| ECON-02 | 04-03, 04-04 | Browse seven slots + buy COINS/GEMS | ✓ SATISFIED | Shop UI + soft purchase |
| ECON-03 | 04-05, 04-07 | Equip; presentation-only; no physics change | ✓ SATISFIED | Equip + fill/stripe/trail/FX/victory consumers; FixtureDef pinned |
| ECON-04 | 04-01, 04-02, 04-04, 04-06, 04-08 | Server ledger authority; chip display-only | ✓ SATISFIED | PurchaseRequest shape; locked creditIfAbsent; grantVsPurchaseRace |
| ECON-05 | 04-01, 04-04, 04-08 | Idempotent soft buys + empty IAP purchases | ✓ SATISFIED | V8 unique + SoftPurchaseJdbc; sameSkuDifferentKeys; purchases unused |

No orphaned Phase 4 requirement IDs.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| ---- | ---- | ------- | -------- | ------ |
| — | — | Prior trailTint write-only blocker | ✓ Closed | `MatchAimArrow` reads `game.trailTint` |
| — | — | Prior missing table_fx/victory consumers | ✓ Closed | rimTint + victoryAccent wired |
| Economy / shop / match presentation sources | — | No TBD/FIXME/XXX debt markers | ✓ | — |
| Soft purchase path | — | Does not write `purchases` IAP table | ✓ | ECON-05 D-60 held |

### Human Verification Required

### 1. Match reward + victory overlay

**Test:** Finish a bot match; watch result; return to catalog.  
**Expected:** Server `+N COINS` (optional GEMS); on local win heading tinted by victory SKU; chip refreshes.  
**Why human:** Visual settle + accent; JVM/flutter unavailable to re-run here.

### 2. Shop buy → equip → live table paints

**Test:** Equip trail / table_fx / victory / saka_color; start match.  
**Expected:** Aim stroke, felt rim, fill/stripe reflect loadout; physics unchanged.  
**Why human:** 04-07 D3 — live Flame paints need owner eyes.

### Gaps Summary

**No blocking gaps.** Prior presentation hollow and CR-01/CR-02 ledger races are closed in code (04-07/04-08). Stick Pull in-match visuals remain intentionally deferred to Phase 6. Automated must-haves score **5/5**; status is **human_needed** for live UAT of reward overlay and table cosmetics.

**Next:** Owner UAT checklist above → then proceed / ship phase.

---

_Verified: 2026-09-10T11:53:00Z_  
_Verifier: Claude (gsd-verifier)_
