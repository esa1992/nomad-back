---
phase: 2
slug: guest-catalog-first-alchiki-match
status: verified
# threats_open = count of OPEN threats at or above workflow.security_block_on severity (the blocking gate)
threats_open: 0
asvs_level: 1
created: 2026-09-07
---

# Phase 2 — Security

> Per-phase security contract: threat register, accepted risks, and audit trail.
>
> Source: PLAN.md `<threat_model>` blocks (02-01..02-09). L1 grep-depth verification 2026-09-07. No SECURITY.md existed before this run (State B). `register_authored_at_plan_time: true`. `block_on: high`.

---

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|---------------|
| pub.dev → client lockfile | Flutter pins cross onto the device binary | go_router, riverpod, dio, secure storage, prefs |
| Maven Central → backend / harness | BOM-managed Spring + proto harness | Boot 4.1.1, Modulith 2.1.1, dyn4j, Flyway |
| Catalog UI → player | Coming Soon tiles must not unlock a third game | playable flag, onTap |
| Client → POST /v1/identity/guest | Unauthenticated mint; flood and fake device ids | IP, no advertising id, minted UUID + JWT |
| Client → POST /v1/identity/refresh | Refresh is a bearer secret; raw token must not persist as-is | refresh token → SHA-256 lookup |
| Device storage → refresh token | Refresh + playerId on device; access JWT must stay memory-only | FlutterSecureStorage, android:allowBackup |
| Client → GET /v1/catalog | Bearer required; APK must not invent PLAYABLE titles | CatalogService flags |
| Backend → PostgreSQL | Identity and match rows must be parameterized | JPA + Flyway |
| Client → POST /v1/matches/{id}/throws | Untrusted ThrowInput; score-like keys ignored | aimAngleRad, holdMs, seed |
| Match row → playerId | Only the owner on PLAYER turn may throw or leave | JWT subject, requireOwner |
| Server dyn4j → client keyframes | Authority poses overwrite local preview | ThrowResolved.displayedScore, keyframes |
| Client HUD → player | `scored` must not copy preview | preview vs scored |
| Client clocks → player | HUD is display-only; Instant on the server is truth | turn/match/hard-cap deadlines |
| Client POST /leave → MatchEntity.status | Leave must not rewrite a terminal result | IN_PLAY → BOT_WIN only |
| Client → bot result | Client must not author botThrow or botScore | ScriptedBot on server |

---

## Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation | Status |
|-----------|----------|-----------|----------|-------------|------------|--------|
| T-02-01 | Spoofing | CatalogPage Coming Soon tiles | medium | mitigate | `_ComingSoonTile` has no `onTap`; Semantics `enabled: false`. Only `alchiki` + PLAYABLE renders `_AlchikiTile`. | closed |
| T-02-02 | Information disclosure | Locale + how-to prefs | low | accept | Locale override is not a secret; tokens are not written in 02-01. | closed |
| T-02-03 | Spoofing | GuestController / GuestService | high | mitigate | `GuestService.createGuest` mints `UUID.randomUUID()`; controller ignores request body (no advertising id). Access JWT via Nimbus HS256. | closed |
| T-02-04 | Elevation of privilege | TokenService refresh | high | mitigate | Persist SHA-256 only; `rotate` deletes then re-issues; missing/replayed/expired refresh → 401. | closed |
| T-02-05 | Tampering | SecurityConfig / TokenService JWT | high | mitigate | Encoder/decoder pin `MacAlgorithm.HS256` on a local HMAC key. SecurityConfig uses that decoder; no JWKS discovery. | closed |
| T-02-06 | Denial of service | POST /v1/identity/guest | medium | mitigate | `GuestMintRateLimiter` in-process 20/min per IP on the guest route (primary auth boundary). | closed |
| T-02-07 | Information disclosure | SessionStore | high | mitigate | Persist `playerId` + `refreshToken` in `FlutterSecureStorage` only. Access JWT lives in `NomadApi.accessToken` memory. `allowBackup` false. | closed |
| T-02-08 | Tampering | JPA / Flyway | high | mitigate | Spring Data `JpaRepository` only (no native `@Query`). `spring-boot-starter-flyway` + `flyway-database-postgresql`. `ddl-auto: validate`. | closed |
| T-02-09 | Information disclosure | Android backup unwrap | medium | mitigate | `android:allowBackup="false"` on the application tag. | closed |
| T-02-10 | Tampering | HowToSeenStore | low | accept | Clearing seen only re-shows cards; it cannot mint tokens or submit a score. | closed |
| T-02-11 | Information disclosure | How-to copy | low | accept | Cards are public rules; no secrets. | closed |
| T-02-12 | Tampering | MatchController.applyThrow / ThrowInput.parse | high | mitigate | `AlchikiEngine.applyThrow` calls `ThrowInput.parse`; unknown/score-like keys ignored. Score from `Dyn4jBurstSim` rest poses. `ThrowAuthorityIT#forgedClientScoreIsIgnoredOnThrow`. | closed |
| T-02-13 | Tampering | MatchService turn check | high | mitigate | Non-owner → `requireOwner` 403. Turn not PLAYER → 409 `"not your turn"`. | closed |
| T-02-14 | Spoofing | AlchikiMatchPage HUD | high | mitigate | `_scored` set only via `AuthorityScore.displayedScore` from the REST `ThrowResolved`. `_preview` is a separate field and never copied into `_scored`. | closed |
| T-02-15 | Denial of service | ThrowResolved parser | medium | mitigate | Dart `maxKeyframes` 40 / `maxBodies` 8. Java `ThrowResolved.KEYFRAME_CAP` 40; `Keyframe` bodies cap 8. | closed |
| T-02-16 | Tampering | Client socket temptation | high | mitigate | Throws are REST `POST /v1/matches/{id}/throws` only. pubspec has no socket client package. | closed |
| T-02-17 | Tampering | Turn / match clocks | high | mitigate | `AlchikiRules` uses server `Instant`. `tickClocks` / expired POST share `forfeitExpiredPlayerTurn` (increment `playerTurns` once per deadline). | closed |
| T-02-18 | Tampering | Leave / result | high | mitigate | `POST /{id}/leave` is server-authored. IN_PLAY leave writes `BOT_WIN`. Result status from `AlchikiRules`. Pause overlay documents no rematch (D-24). Refined by T-02-26. | closed |
| T-02-19 | Information disclosure | Pause overlay | low | accept | Pause only freezes local input; no secrets shown. | closed |
| T-02-20 | Spoofing | botThrow on the client | high | mitigate | `ScriptedBot` lives only under `backend/.../internal/`. Client animates returned `botThrow` input+keyframes. | closed |
| T-02-21 | Tampering | Request botScore / winner | high | mitigate | `ThrowAuthorityIT` asserts forged `botScore` / `botThrow` do not change `match.botScore`. `ThrowInput.parse` ignores unknown keys. | closed |
| T-02-22 | Tampering | Shop / Ranked surface | medium | mitigate | Controllers are identity, catalog, and matches only. No shop, wallet, Glicko, or socket session endpoints. | closed |
| T-02-23 | Tampering | CatalogController | medium | mitigate | PLAYABLE flags come only from `CatalogService.list()`. Unauthenticated GET `/v1/catalog` is 401 (`CatalogIT`). | closed |
| T-02-24 | Tampering | resetSakaToRim | medium | mitigate | After replay, `resetSakaToRim` → `saka.snapToSpawn()` at `(0,-1.15)`. `_dropPocketedBones` so pocketed ids are not respawned. | closed |
| T-02-25 | Tampering | Dyn4jBurstSim throw 2+ spawn | high | mitigate | `applyThrow` passes `bonesLeft` into `simulate(input, remainingBoneIds)`. `spawnRemaining` skips ids not in the leftover set. | closed |
| T-02-26 | Tampering | MatchService.leaveMatch | high | mitigate | Write `BOT_WIN` only when status is `IN_PLAY`; otherwise return existing snapshot. `ThrowAuthorityIT#leaveAfterPlayerWinPreservesPlayerWin` / `#leaveAfterDrawPreservesDraw`. | closed |
| T-02-27 | Elevation of privilege | MatchService.requireOwner | high | mitigate | Missing match → 404. Other player's JWT → 403. `MatchController.leave` requires `@AuthenticationPrincipal Jwt`. No public leave-by-id. | closed |
| T-02-28 | Repudiation | Leave after terminal | low | accept | Phase 2 has no audit log; authority is the persisted status, not a leave event stream. | closed |
| T-02-SC | Tampering | pub.dev / Maven pins | high | mitigate | Client pins: go_router 18.0.1, flutter_riverpod 3.4.3, dio 5.11.1, flutter_secure_storage 11.0.0, shared_preferences 2.5.5, forge2d 0.14.2 (not 0.15). Backend: Boot 4.1.1 + Modulith 2.1.1 + Testcontainers; no Redis client; no socket / google_fonts. Later plans added no new pubs. | closed |

*Status: open · closed · open — below high threshold (non-blocking)*
*Severity: critical > high > medium > low — only open threats at or above `workflow.security_block_on` (`high`) count toward `threats_open`*
*Disposition: mitigate (implementation required) · accept (documented risk) · transfer (third-party)*

---

## Accepted Risks Log

| Risk ID | Threat Ref | Rationale | Accepted By | Date |
|---------|------------|-----------|-------------|------|
| AR-02-01 | T-02-02 | Locale override and how-to prefs are not secrets. 02-01 does not write tokens. | 02-01 PLAN disposition accept | 2026-09-07 |
| AR-02-02 | T-02-10 | Clearing how-to-seen only re-shows cards; it cannot mint tokens or submit a score. | 02-03 PLAN disposition accept | 2026-09-07 |
| AR-02-03 | T-02-11 | How-to cards are public rules text; no secrets. | 02-03 PLAN disposition accept | 2026-09-07 |
| AR-02-04 | T-02-19 | Pause freezes local input only; overlay shows no secrets. | 02-05 PLAN disposition accept | 2026-09-07 |
| AR-02-05 | T-02-28 | Phase 2 has no leave audit stream. Persisted `MatchEntity.status` is the authority for terminal results. | 02-09 PLAN disposition accept | 2026-09-07 |

*Accepted risks do not resurface in future audit runs.*

---

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-09-07 | 29 | 29 | 0 | gsd-security-auditor (L1 grep; plan-time register, ASVS L1, block_on high) |

Evidence (L1):

- `client/lib/catalog/catalog_page.dart:171-187` — Coming Soon path has no `onTap`; `_ComingSoonTile` `enabled: false` (`:372-383`)
- `backend/src/main/java/com/nomadgames/identity/GuestService.java:24-28` — server-minted UUID, no device/ad id
- `backend/src/main/java/com/nomadgames/identity/GuestController.java:26-30` — mint ignores body; rate-limit check
- `backend/src/main/java/com/nomadgames/identity/TokenService.java:51-52,67-78,113-115` — HS256 pin, rotate+delete, SHA-256
- `backend/src/main/java/com/nomadgames/identity/SecurityConfig.java:18-32` — resource-server decoder; no JWKS
- `backend/src/main/java/com/nomadgames/identity/internal/GuestMintRateLimiter.java:23-40` — 20/min per IP
- `client/lib/platform/auth/session_store.dart:13-28` — refresh + playerId only
- `client/lib/platform/api/nomad_api.dart:141-186` — access JWT memory field
- `client/android/app/src/main/AndroidManifest.xml:7` — `allowBackup` false
- `backend/src/main/resources/application.yaml:10-13` — `ddl-auto: validate`, Flyway on
- `backend/pom.xml:10,22,61-65` — Boot 4.1.1, Modulith 2.1.1, Flyway starter + postgresql; no Redis
- `backend/src/main/java/com/nomadgames/identity/internal/RefreshTokenRepository.java` — `JpaRepository` + `findByTokenHash`
- `harness/src/main/java/com/nomadgames/alchiki/proto/ThrowInput.java:42-69` — parse ignores unknown keys
- `backend/src/main/java/com/nomadgames/games/alchiki/AlchikiEngine.java:34-41` — parse + `Dyn4jBurstSim.simulate(input, remainingBoneIds)`
- `backend/src/main/java/com/nomadgames/session/MatchService.java:70-77,86-87,96-97,109-127,181-186` — leave IN_PLAY guard, 409 turn, leftover spawn, `forfeitExpiredPlayerTurn`, requireOwner 404/403
- `backend/src/main/java/com/nomadgames/session/MatchController.java:38-47` — REST throws + leave with JWT
- `backend/src/main/java/com/nomadgames/games/alchiki/AlchikiRules.java:16-55` — server Instant clocks
- `backend/src/main/java/com/nomadgames/games/alchiki/internal/ScriptedBot.java` — server-only bot
- `backend/src/test/java/com/nomadgames/session/ThrowAuthorityIT.java` — forged score/botScore ignored; leave preserves PLAYER_WIN/DRAW
- `client/lib/games/alchiki/match_page.dart:62-63,230,409` — preview vs scored
- `client/lib/replay/authority_score.dart:21-32` — `displayedScore` from REST body
- `client/lib/replay/throw_resolved.dart:8-9` — caps 40 / 8
- `harness/src/main/java/com/nomadgames/alchiki/proto/ThrowResolved.java:10,43-45` — KEYFRAME_CAP 40
- `harness/src/main/java/com/nomadgames/alchiki/proto/Keyframe.java:15-16` — bodies cap 8
- `harness/src/main/java/com/nomadgames/alchiki/proto/Dyn4jBurstSim.java:75-81,109-125` — `spawnRemaining` leftover ids only
- `client/lib/game/saka_body.dart:14` — spawn `(0, -1.15)`
- `client/lib/games/alchiki/match_game.dart:181-184` — `resetSakaToRim`
- `client/lib/games/alchiki/pause_overlay.dart:138` — no rematch
- `backend/src/main/java/com/nomadgames/catalog/CatalogService.java:10-14` — PLAYABLE only from server
- `backend/src/test/java/com/nomadgames/catalog/CatalogIT.java:40` — unauthenticated catalog 401
- `client/pubspec.yaml:37-49` — RESEARCH pins; no socket / google_fonts / forge2d 0.15
- SUMMARY `## Threat Flags` (02-04, 02-05, 02-06, 02-08): none raised; each maps to existing T-02-* IDs. 02-01, 02-02, 02-03, 02-07, 02-09 have no Threat Flags section.

L1 note (not a register opening): `GuestController.clientIp` prefers first `X-Forwarded-For` hop. Presence of the per-IP limiter closes T-02-06 at L1. A later L2 audit should re-check trusted-proxy binding.

---

## Unregistered Flags

None. SUMMARY Threat Flags that exist all map to plan-time IDs (T-02-12, T-02-13, T-02-14, T-02-15, T-02-17, T-02-18, T-02-20, T-02-21, T-02-22, T-02-24, T-02-25).

---

## Sign-Off

- [x] All threats have a disposition (mitigate / accept / transfer)
- [x] Accepted risks documented in Accepted Risks Log
- [x] `threats_open: 0` confirmed
- [x] `status: verified` set in frontmatter

**Approval:** verified 2026-09-07
