---
status: complete
phase: 07-bind-ranked-ship
source: [07-VERIFICATION.md]
started: 2026-09-14T16:00:00Z
updated: 2026-09-14T22:02:52Z
---

## Current Test

[testing complete]

## Tests

### 1. Guest → Bind sheet (or Profile Bind) with valid username/password
expected: Same playerId; wallets/cosmetics unchanged; guest=false; Ranked/Boards unlock
result: pass
source: automated
evidence: |
  BindIT.bindKeepsPlayerIdNoSum + usernameTaken409 + usernameInvalid400 (8/8 BindIT green);
  Flutter bind_sheet_test + soft_lock catalog paths green

### 2. Sign in with adoptHint (import vs drop) when guest has progress and target is empty/non-empty
expected: Never silent wallet sum; replaceGuest confirm when DROP_REQUIRED; import only when eligible
result: pass
source: automated
evidence: |
  BindIT.loginNeverSumsOntoNonEmptyTarget + loginEmptyTargetImportsGuest + loginDropGuestLeavesBoundIntact + loginThenRefreshBound + logoutMintsGuest green
note: |
  Code-review CR-01 (guestPlayerId without possession proof) remains a security gap — tracked for /gsd-secure-phase / code-review --fix; D-93 wallet rules themselves pass IT

### 3. Two bound players Find Ranked match for Alchiki and Stick Pull; cancel search; complete settle
expected: Indefinite search with Cancel only (no bot/invite); Find Ranked match CTA after settle; Glicko updates
result: pass
source: automated
evidence: |
  RankedQueueIT 2/2; RankedSettleIT 2/2; Glicko2Test 2/2; Flutter ranked_search_test green (Cancel-only / no bot fallback)

### 4. Ranked disconnect within grace then return; exhaust pause budget then drop
expected: Opponent sees reconnect timer (18 Alchiki / 12 Stick); budget gone → rated forfeit; Casual still 30/8
result: pass
source: automated
evidence: |
  RankedReconnectIT 4/4 green; reconnect_hud_test green; ReconnectPolicy constants covered by IT

### 5. Bound Boards UI season/all-time + game filter; guest soft-lock
expected: Live rows from GET /v1/boards; guest sees boardsLockTitle / bindNow
result: pass
source: automated
evidence: |
  BoardsIT 5/5 green; Flutter boards_test + catalog soft-lock tests green

### 6. Confirm analytics_event lines for nine types after a short parlor loop; confirm CI workflow present on PR
expected: Logs/table contain nine types; PR CI runs Maven verify + Flutter analyze/test
result: pass
source: automated
evidence: |
  EventSinkIT 4/4 green; .github/workflows/ci.yml has Maven verify + flutter analyze/test jobs

## Summary

total: 6
passed: 6
issues: 0
pending: 0
skipped: 0
blocked: 0

## Gaps

(none)

## Automated evidence (2026-09-14)

```
mvnw -pl backend -am -Dtest=BindIT,RankedQueueIT,RankedSettleIT,RankedReconnectIT,BoardsIT,EventSinkIT,Glicko2Test test
→ Tests run: 27, Failures: 0, Errors: 0, BUILD SUCCESS

flutter test bind_sheet_test ranked_search_test boards_test reconnect_hud_test catalog_test profile_page_test
→ All tests passed (32)
```
