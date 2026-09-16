# Phase 6 — Validation Strategy

> Nyquist validation extracted from 06-RESEARCH.md Validation Architecture.
> Dimension: backend + frontend. ASVS L1. Mode: mvp.

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | JUnit 5 + Spring Boot Test / Testcontainers (backend); `flutter_test` (client) |
| Config file | `backend/pom.xml` surefire; `client/pubspec.yaml` |
| Quick run command | `./mvnw -pl backend -Dtest=StickPullSimTest,CatalogIT test` (or IDE equiv) + `flutter test test/catalog_test.dart test/howto_stick_pull_test.dart` |
| Full suite command | Backend session/matchmaking/catalog/profile ITs touching Stick Pull + `flutter test` |

### Phase Requirements в†’ Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| CAT-02 | `stick_pull` status PLAYABLE; tile CTAs | IT + widget | `CatalogIT` expect PLAYABLE; `catalog_test` Stick Pull Quick Match | вќЊ Wave 0 (today COMING_SOON) |
| STICK-01 | Countdown then marker moves on taps | unit + IT | `StickPullSimTest`; `StickPullIT` WS | вќЊ Wave 0 |
| STICK-02 | Mash reduces force / exhaust slip | unit | `StickPullSimTest` burst/exhaust | вќЊ Wave 0 |
| STICK-03 | Ends at threshold or clock 0 in 15вЂ“40s | unit + IT | sim clock settle; IT | вќЊ Wave 0 |
| STICK-04 | &gt;10/s extras no force; suspect log | unit | clamp + regularity tests | вќЊ Wave 0 |
| STICK-05 | How-to 5 cards skip/seen | widget | `howto_stick_pull_test.dart` | вќЊ Wave 0 |
| BOT-02 | EASY/NORMAL/HARD jitter envelopes | unit | `StickPullBotTest` | вќЊ Wave 0 |
| SESS-04 | 8s grace then forfeit; no bot-fill | IT | `StickPullReconnectIT` | вќЊ Wave 0 (Alchiki ReconnectIT is 30s) |

### Sampling Rate
- **Per task commit:** targeted unit/widget for touched seam
- **Per wave merge:** Stick Pull sim + CatalogIT + one reconnect IT
- **Phase gate:** Full Stick Pull IT set green before `/gsd-verify-work`

### Wave 0 Gaps
- [ ] `backend/.../games/stickpull/StickPullSimTest.java` вЂ” STICK-01вЂ¦04 bands
- [ ] `backend/.../games/stickpull/StickPullBotTest.java` вЂ” BOT-02
- [ ] `backend/.../session/StickPullIT.java` вЂ” countdown/tap/settle WS
- [ ] `backend/.../session/StickPullReconnectIT.java` вЂ” 8s forfeit, no bot-fill
- [ ] `backend/.../matchmaking/CasualQueueIT` cases for `game=STICK_PULL` isolation
- [ ] `backend/.../catalog/CatalogIT` PLAYABLE assertion update
- [ ] `client/test/howto_stick_pull_test.dart` вЂ” STICK-05
- [ ] `client/test/catalog_test.dart` вЂ” promote Stick Pull CTAs
- [ ] Update `ReconnectIT` so Alchiki 30s still holds after `graceFor(game)` refactor

