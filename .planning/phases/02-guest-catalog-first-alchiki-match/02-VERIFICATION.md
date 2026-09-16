---
phase: 02-guest-catalog-first-alchiki-match
verified: 2026-09-07T03:40:00Z
status: passed
score: 4/5 must-haves verified
behavior_unverified: 1
overrides_applied: 0
re_verification:
  previous_status: gaps_found
  previous_score: 3/5
  gaps_closed:

    - "Match result is decided only on the server; the client cannot submit or rewrite a score (SESS-01)"
  gaps_remaining: []
  regressions: []
behavior_unverified_items:

  - truth: "Player can finish a 5–7 bone match (first to 5, or highest after 8 turns each / 4:00, hard cap 5:00) against EASY, NORMAL, and HARD bots that make visible mistakes; a new player can beat EASY in under 3 minutes using skippable static how-to cards"
    test: "Cold start as guest → catalog EN/RU → Play Alchiki → skip or finish five cards → complete an EASY match under 3 minutes; also spot NORMAL and HARD bot turns"
    expected: "Bot turn is visible aim + hold + keyframe settle (not an instant score popup). EASY is winnable in under 3 minutes. First-to-5 / clocks end the match. Coming Soon tiles do not start a game."
    why_human: "Presence of ScriptedBot + AlchikiRules + how-to pager cannot prove a new player wins in under 3 minutes or that bot mistakes are visible on device."
human_verification:

  - test: "Холодный старт без поля имени → каталог EN/RU → «Играть в Альчики» → пропуск или пять карточек → матч EASY. Довести партию до конца."
    expected: "Победа (или хотя бы завершённый матч) менее чем за 3 минуты; бот ходит видимо (прицел + заряд + settle), не мгновенным popup счёта."
    why_human: "Нет e2e-теста на длительность партии и видимость хода бота."

  - test: "С каталога выбрать Норма и Сложно, начать матч. Нажать плитки «Перетягивание палки» и «Ещё игры»."
    expected: "Стол с 6 / 7 костями; бот ошибается по-разному. Coming Soon не открывает игру. Нет магазина, кода комнаты, Rematch."
    why_human: "Визуальное поведение плиток и сложность бота на устройстве."

  - test: "Просмотреть каталог, how-to, стол, паузу и результат."
    expected: "Войлок #1B6B3A, дерево #241810, золото только на зарезервированных CTA (Play Alchiki, Hold Throw, выбранная сложность, Resume)."
    why_human: "Соответствие «живому» nomadic стилю grep не доказывает."
---

# Phase 2: Guest Catalog + First Alchiki Match Verification Report

**Phase Goal:** A guest can open a localized nomadic catalog and complete a short, server-scored Alchiki match against a bot using skippable static how-to cards
**Verified:** 2026-09-07T03:40:00Z
**Status:** human_needed
**Re-verification:** Yes — after gap closure 02-09
**Mode:** mvp (ROADMAP goal is outcome-form — same as initial verify. PLAN restated the slots as a valid user story. Verification proceeds against the PLAN user story. ROADMAP Phase 2 checkbox `[x]` / REQUIREMENTS checkmarks are **not** evidence.)

## User Flow Coverage

User story: «As a guest, I want to open a localized nomadic catalog and complete a short, server-scored Alchiki match against a bot using skippable static how-to cards, so that I finish an honest first party without creating a username.»

| Step | Expected | Evidence | Status |
|------|----------|----------|--------|
| Open app | Silent guest mint, no username / account field | `SplashPage` has no `TextField`; `GuestSessionResponse` is `playerId` + tokens + `guest` only | ✓ |
| See catalog | Localized parlor home; Alchiki playable; Stick Pull / More games Coming Soon | `CatalogService` returns `alchiki PLAYABLE`, `stick_pull` / `more_games` `COMING_SOON`; `_ComingSoonTile` has no `onTap` | ✓ |
| How-to | First Play Alchiki opens five static cards; Skip on card 1 | `AlchikiHowToPage` `PageView` + header Skip when `!fromPause` | ✓ |
| Play a turn | Aim + Hold Throw; release sends ThrowInput only | `submitThrow` still posts `ThrowInput`; `ThrowInput.parse` ignores unknown score keys | ✓ |
| Server scores | 1 per bone fully outside after settle; saka-out = 0 and saka returns | `displayedScore()` is `sakaOut ? 0 : pocketedCount`; `applyThrow` no-ops when status is not `IN_PLAY` | ✓ |
| Bot turn | Server-authored ThrowInput + keyframes, visible playback | `ScriptedBot.nextThrow` + client `playBotTurn` present and wired | ✓ present |
| Finish match | First to 5 / 8 turns / 4:00 / 5:00 vs EASY–HARD; EASY < 3 min | `AlchikiRules` + HUD + result overlay exist; **no device proof** of a finished EASY win under 3 minutes | ⚠️ |
| Outcome | Honest first party; client cannot author or rewrite the result | `/throws` ignores forged score keys. `leaveMatch` writes `BOT_WIN` only while `IN_PLAY`; named ITs passed | ✓ |

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | ------- | ---------- | -------------- |
| 1 | Player can start as a guest (no username) and reach a first Alchiki match from a catalog that shows Alchiki as playable and future games as Coming Soon | ✓ VERIFIED | Regression: `SplashPage` still has no `TextField` / username. `GuestSessionResponse(playerId, accessToken, refreshToken, boolean guest)`. Catalog tiles: Alchiki `PLAYABLE`, others `COMING_SOON`. `_ComingSoonTile` has no navigation. |
| 2 | Player can complete a turn by aiming, holding to set power, and releasing; after bodies sleep (or the settle timeout) they score 1 per target bone fully outside the circle, those bones leave, and a saka that leaves scores 0 and returns | ✓ VERIFIED | Regression: `ThrowResolved.displayedScore()` still `sakaOut ? 0 : pocketedCount`. `applyThrow` still returns unchanged snapshot when status is not `IN_PLAY`. |
| 3 | Player can finish a 5–7 bone match (first to 5, or highest after 8 turns each / 4:00, hard cap 5:00) against EASY, NORMAL, and HARD bots that make visible mistakes; a new player can beat EASY in under 3 minutes using skippable static how-to cards | ⚠️ PRESENT_BEHAVIOR_UNVERIFIED | Rules + ScriptedBot EASY/NORMAL/HARD + how-to Skip still present and wired (`AlchikiRules.FIRST_TO = 5`, `TURN_CLOCK` 20s, `MATCH_LIMIT` 4:00, `HARD_CAP` 5:00). Under-3-minute win and visible mistakes are not exercised by a passing end-to-end test. |
| 4 | All player-facing strings are complete in EN and RU; catalog and matches use the colorful original nomadic/Asian visual style | ✓ VERIFIED | Regression: ARB keys and palette tokens unchanged. Device “feel” still listed under harvested human-check. |
| 5 | Match result is decided only on the server; the client cannot submit or rewrite a score (SESS-01) | ✓ VERIFIED | Full 3-level check after 02-09. `leaveMatch` returns `LeaveResponse(snapshot)` without `setStatus`/`save` when status is not `IN_PLAY`; IN_PLAY leave still writes `BOT_WIN`. `MatchController.leave` is still a one-line delegate. Named ITs `leaveAfterPlayerWinPreservesPlayerWin`, `leaveAfterDrawPreservesDraw`, `leaveMatchReturnsBotWin` **passed** (Tests run: 3, Failures: 0). `/throws` path still ignores unknown score keys. Result overlay does not POST `/leave` (`_leaveConfirm && !_isTerminal`). |

**Score:** 4/5 truths verified (1 present, behavior-unverified)

ROADMAP `[x]` and REQUIREMENTS.md Phase-2 checkmarks were treated as claims, not evidence.

### Deferred Items

None. The idle-GET hard-cap warning is not a failed must-have and is not scheduled as a later-phase success criterion.

### Required Artifacts

Hand-checked (existence, substance, wiring). Previously PASSED artifacts: existence + sanity regression only. Previously FAILED `MatchService.leaveMatch`: full 3-level.

| Artifact | Expected | Status | Details |
| -------- | ----------- | ------ | ------- |
| `client/l10n.yaml` | gen-l10n config | ✓ VERIFIED | Unchanged |
| `client/lib/l10n/app_en.arb` | EN copy | ✓ VERIFIED | `leaveMatch` / play / how-to keys present |
| `client/lib/l10n/app_ru.arb` | RU copy | ✓ VERIFIED | «Покинуть матч» / matching keys |
| `client/lib/catalog/catalog_page.dart` | Catalog home | ✓ VERIFIED | Play Alchiki + Coming Soon without `onTap` |
| `client/lib/platform/router.dart` | GoRouter routes | ✓ VERIFIED | `/splash`, `/`, `/howto/alchiki`, `/match` |
| `client/lib/main.dart` | ProviderScope owner | ✓ VERIFIED | Present |
| `client/lib/platform/app.dart` | Router/locale shell | ✓ VERIFIED | Present |
| `client/lib/platform/splash_page.dart` | Silent mint | ✓ VERIFIED | No username field |
| `client/lib/platform/auth/session_store.dart` | Secure persist | ✓ VERIFIED | Present |
| `client/lib/platform/api/nomad_api.dart` | Dio client | ✓ VERIFIED | `leaveMatch` still POSTs `/v1/matches/$id/leave` |
| `client/lib/howto/alchiki_howto_page.dart` | Five-card pager | ✓ VERIFIED | Skip when `!fromPause` |
| `client/lib/howto/howto_seen_store.dart` | seen flag | ✓ VERIFIED | Present |
| `client/lib/games/alchiki/match_page.dart` | Hold Throw + bot playback | ✓ VERIFIED | Leave confirm hidden when `_isTerminal` |
| `client/lib/games/alchiki/match_game.dart` | Rim reset | ✓ VERIFIED | Present |
| `client/lib/games/alchiki/match_hud.dart` | Clocks + scores | ✓ VERIFIED | Present |
| `client/lib/games/alchiki/pause_overlay.dart` | Pause / leave / result | ✓ VERIFIED | `ResultOverlay` has `onBackToCatalog` only — no rematch |
| `client/lib/replay/throw_resolved.dart` | displayedScore | ✓ VERIFIED | `sakaOut ? 0 : pocketedCount` |
| `backend/.../GuestController.java` | POST guest | ✓ VERIFIED | `/v1/identity/guest` |
| `backend/.../CatalogService.java` | Tile flags | ✓ VERIFIED | Alchiki PLAYABLE; others COMING_SOON |
| `backend/.../MatchController.java` | start / throws / leave | ✓ VERIFIED | `POST /{id}/leave` → `matches.leaveMatch` |
| `backend/.../MatchService.java` | Authority + bot hook + leave gate | ✓ VERIFIED | `leaveMatch` IN_PLAY-only `BOT_WIN` (lines 70–78); `applyThrow` still no-ops off IN_PLAY |
| `backend/.../AlchikiEngine.java` | dyn4j wrapper | ✓ VERIFIED | Present |
| `backend/.../AlchikiRules.java` | first-to-5 / clocks | ✓ VERIFIED | Constants unchanged |
| `backend/.../ScriptedBot.java` | Noisy ThrowInput | ✓ VERIFIED | EASY / NORMAL / HARD branches present |
| `backend/.../ThrowAuthorityIT.java` | Leave-after-terminal + IN_PLAY forfeit | ✓ VERIFIED | `setMatchStatus` + three named leave tests; this pass ran them and they passed |
| `client/pubspec.yaml` | Forge2D lock | ✓ VERIFIED | `forge2d: 0.14.2`, `flame_forge2d: 0.19.3+7` — **not reopened** |

### Key Link Verification

| From | To | Via | Status | Details |
| ---- | --- | ---- | ------ | ------- |
| `MatchController` | `MatchService.leaveMatch` | `POST /{id}/leave` | WIRED | One-line delegate; IN_PLAY guard lives in the service (same pattern as `applyThrow`) |
| `ThrowAuthorityIT` | `POST /v1/matches/{id}/leave` | seed terminal status then POST | WIRED | `leaveAfterPlayerWinPreservesPlayerWin` / `leaveAfterDrawPreservesDraw` / `leaveMatchReturnsBotWin` all green this pass |
| `pause_overlay.dart` | POST `/leave` | confirm Leave | WIRED | Only while `!_isTerminal`; consented IN_PLAY forfeit |
| `ResultOverlay` | catalog | `onBackToCatalog` | WIRED | Does not POST `/leave` after PLAYER_WIN / DRAW / BOT_WIN |
| `MatchService.applyThrow` | `AlchikiRules` / `ScriptedBot` | throw path | WIRED | Regression: still gated on IN_PLAY |
| `catalog_page.dart` | `GET /v1/catalog` | `fetchCatalog` | WIRED | Unchanged |
| `splash_page.dart` | `nomad_api.dart` | `mintGuest` | WIRED | Unchanged |
| `match_page.dart` | POST `/throws` | `submitThrow` | WIRED | Unchanged |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| -------- | ------------- | ------ | ------------------ | ------ |
| `CatalogPage` | `tiles` | `GET /v1/catalog` | Server-owned tile list | ✓ FLOWING |
| `AlchikiMatchPage` | scores / status | REST throw + match snapshot | dyn4j + persisted scores | ✓ FLOWING |
| `LeaveResponse.match.status` | `match.getStatus()` | Loaded row; mutated only if IN_PLAY | Terminal seed survives POST leave (IT) | ✓ FLOWING |
| `SplashPage` | session | `POST /v1/identity/guest` | New playerId + tokens | ✓ FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| -------- | ------- | ------ | ------ |
| Leave after PLAYER_WIN preserves status | `mvnw -pl backend -am test -Dtest=ThrowAuthorityIT#leaveAfterPlayerWinPreservesPlayerWin,ThrowAuthorityIT#leaveAfterDrawPreservesDraw,ThrowAuthorityIT#leaveMatchReturnsBotWin` | Tests run: 3, Failures: 0 | ✓ PASS |
| Leave after DRAW preserves status | (same command) | `$.match.status` DRAW | ✓ PASS |
| IN_PLAY leave still BOT_WIN | (same command) | `leaveMatchReturnsBotWin` green | ✓ PASS |
| Forged throw score ignored | `ThrowInput.parse` unknown-key comment + applyThrow IN_PLAY gate | Code regression only; IT method not re-run this pass | ? SKIP (code present) |
| EASY win under 3 minutes | device UAT | No runnable e2e without app + server | ? SKIP → human |

### Probe Execution

| Probe | Command | Result | Status |
| ----- | ------- | ------ | ------ |
| — | — | No `scripts/*/tests/probe-*.sh`; PLAN/SUMMARY do not declare probes | SKIPPED |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
| ----------- | ---------- | ----------- | ------ | -------- |
| AUTH-01 | 02-02, 02-07 | Guest reaches first match without a username | ✓ SATISFIED | Silent mint, no username on `GuestSessionResponse` / splash |
| CAT-01 | 02-01, 02-07 | Catalog shows Alchiki playable | ✓ SATISFIED | Server `PLAYABLE` + Play Alchiki CTA |
| CAT-03 | 02-01, 02-07 | Future games Coming Soon, not fake playable | ✓ SATISFIED | `stick_pull` / `more_games` `COMING_SOON`; tile has no `onTap` |
| ALCH-01 | 02-08 | Aim, hold, release | ✓ SATISFIED | Match table Hold Throw + aim |
| ALCH-02 | 02-04, 02-08 | 1 per bone fully outside; bones leave | ✓ SATISFIED | dyn4j pocket + leftover set |
| ALCH-03 | 02-05 | 5–7 bones, first to 5 / 8 turns / 4:00 / 5:00 | ✓ SATISFIED (warning) | `AlchikiRules` implements all five constants. Idle GET still does not resolve match/hard cap unless the turn clock also expired |
| ALCH-04 | 02-03, 02-05 | Skippable how-to before first match; reopen from pause | ✓ SATISFIED | Skip on first-run header; Pause → `fromPause` |
| ALCH-05 | 02-04, 02-06, 02-08 | Saka-out 0 and returns; score after sleep / 1.2s | ✓ SATISFIED | `displayedScore()` + rim reset |
| BOT-01 | 02-06 | EASY / NORMAL / HARD scripted bots with visible mistakes | ✓ SATISFIED (code) | `ScriptedBot` branches present; visibility is human |
| BOT-03 | 02-06 | New player beats EASY in under 3 minutes with how-to | ? NEEDS HUMAN | How-to skippable; no timed match proof |
| SESS-01 | 02-04, 02-09 | Server-only result; client cannot submit or rewrite a score | ✓ SATISFIED | `/throws` ignores forged keys; `/leave` no-ops unless `IN_PLAY`; three named ITs passed this pass |
| PRES-01 | 02-01 | All player-facing strings EN+RU | ✓ SATISFIED | ARB pairs present |
| PRES-02 | 02-06 | Nomadic/Asian original visual style | ? NEEDS HUMAN | Palette tokens present; device feel not proven |

No orphaned Phase 2 IDs.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| ---- | ---- | ------- | -------- | ------ |
| `MatchService.java` | 109–116 | `tickClocks` only forfeits the 20s turn; does not call `AlchikiRules.resolve` for 4:00 / 5:00 | ⚠️ Warning | Hard cap is not a hard cap on idle GET |
| `AlchikiRules.java` | — | No empty-`bonesLeft` terminal | ⚠️ Warning | 3–2 on EASY (5 bones gone, neither at 5) continues throws at an empty table until turns/clocks |
| `session_store.dart` | — | Persist failures swallowed | ⚠️ Warning | Guest identity may not survive restart |
| `GuestController.java` | — | `X-Forwarded-For` trusted for mint rate-limit | ℹ️ Info | Not a phase must-have |
| Phase-modified `*.dart` / `*.java` (02-09) | — | `TBD` / `FIXME` / `XXX` | — | None found |

Previous blocker (`leaveMatch` unconditional `BOT_WIN`) is **closed**. Forge2D 0.15 was **not** reopened (`pubspec.yaml` still `0.14.2`).

No shop, wallet, Ranked, Glicko-2, Redis, WebSocket, rematch CTA, or username `TextField` in `client/lib` or `backend/src/main`.

### Human Verification Required

Harvested from `02-06-PLAN.md` `<human-check>` plus the behavior-unverified SC3. Эти шаги — для владельца на устройстве (не автоматика):

### 1. Первая партия EASY до 3 минут (BOT-03)

**Test:** Холодный старт без поля имени → каталог EN/RU → «Играть в Альчики» → пропуск или пять карточек → матч EASY. Довести партию до конца.
**Expected:** Победа (или хотя бы завершённый матч) менее чем за 3 минуты; бот ходит видимо (прицел + заряд + settle), не мгновенным popup счёта.
**Why human:** Нет e2e-теста на длительность партии и видимость хода бота.

### 2. NORMAL / HARD и Coming Soon

**Test:** С каталога выбрать Норма и Сложно, начать матч. Нажать плитки «Перетягивание палки» и «Ещё игры».
**Expected:** Стол с 6 / 7 костями; бот ошибается по-разному. Coming Soon не открывает игру. Нет магазина, кода комнаты, Rematch.
**Why human:** Визуальное поведение плиток и сложность бота на устройстве.

### 3. Палитра PRES-02

**Test:** Просмотреть каталог, how-to, стол, паузу и результат.
**Expected:** Войлок `#1B6B3A`, дерево `#241810`, золото только на зарезервированных CTA (Play Alchiki, Hold Throw, выбранная сложность, Resume).
**Why human:** Соответствие «живому» nomadic стилю grep не доказывает.

### Inversion / Confirmation Bias (disconfirmation pass)

1. **Partial requirement:** ALCH-03 clocks exist in `AlchikiRules.resolve`, but idle `GET` still only forfeits the 20s turn clock — 4:00 / 5:00 are not applied unless that turn also expired. Warning, not a SESS-01 miss.
2. **Misleading test:** Leave-after-terminal ITs seed `PLAYER_WIN` / `DRAW` with `JdbcTemplate UPDATE`, not a played first-to-5. They correctly prove a client cannot rewrite a **stored** terminal status (the SESS-01 hole). They do not re-prove `AlchikiRules` produces those statuses.
3. **Untested error path:** No dedicated IT for already-`BOT_WIN` leave idempotency. The same `!IN_PLAY` early return covers it; not a blocker.

### Gaps Summary

Previous SESS-01 blocker is closed in code and in named ITs run this pass. `POST /leave` no longer rewrites `PLAYER_WIN` or `DRAW`. IN_PLAY consented leave is still `BOT_WIN`.

The remaining open item is device UAT: BOT-03 (EASY under 3 minutes, visible bot turn) and PRES-02 palette feel. That is `human_needed`, not `gaps_found`.

Do **not** treat ROADMAP Phase 2 as complete until human verification. Do **not** reopen Forge2D 0.15.

---

_Verified: 2026-09-07T03:40:00Z_
_Verifier: Claude (gsd-verifier)_
