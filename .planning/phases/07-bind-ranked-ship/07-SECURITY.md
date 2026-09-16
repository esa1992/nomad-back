---
phase: 07
slug: bind-ranked-ship
status: verified
# threats_open = count of OPEN threats at or above workflow.security_block_on severity (the blocking gate)
threats_open: 0
asvs_level: 1
block_on: high
created: 2026-09-14
verified: 2026-09-15
---

# Phase 07 — Security

> Per-phase security contract: threat register, accepted risks, and audit trail.
> ASVS L1 verification against plan `<threat_model>` registers. Implementation files were not modified.
> Re-audit after CR-01 / WR-01..WR-06 (`32764a7`..`d09968c`); `07-REVIEW.md` status: clean.

---

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|---------------|
| Client → Identity API | Guest mint / login permitAll; bind/logout authenticated; login adopt requires guest possession | username, password, guestPlayerId, adopt, guest Bearer / guestRefreshToken, JWT |
| Client → Ranked / Boards | Bound JWT + DB `guest=false` on Ranked enqueue/create | playerId, enqueue game, board scope |
| Client → Match WS / settle | Server SoT timers, Glicko, pause budget | match events, reconnect tokens |
| Host → compose.prod | Env-injected secrets vs committed defaults | `NOMAD_JWT_SECRET`, `NOMAD_POSTGRES_PASSWORD` |
| App → Analytics sink | Fire-and-forget emit inside settle/bind TX | event type, UUID playerId, scrubbed attrs |

---

## Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation | Status |
|-----------|----------|-----------|----------|-------------|------------|--------|
| T-07-01 | Spoofing | BindIT / login stubs | high | mitigate | Argon2id + LoginRateLimiter delivered in later plans | closed — `PasswordConfig.java:18-21`, `GuestController.java:68`, `LoginRateLimiter.java:29-40` |
| T-07-02 | Elevation | RankedQueueIT guestRejected | high | mitigate | Server guest gate on Ranked | closed — `RankedMatchmakingController.java:56-61`; `RankedQueueService.requireBoundPlayer`; `RankedQueueIT.guestRejected` |
| T-07-03 | Tampering | RankedSettleIT SoftElo isolation | high | mitigate | SoftElo only on CASUAL | closed — `ProfileService.java:98,126-128`; `MatchService.java:1082-1086`; `RankedSettleIT` |
| T-07-04 | Spoofing | BindService / PasswordConfig | high | mitigate | Argon2id; password min 8 / max 128; username charset 3–20 | closed — `PasswordConfig.java:18-21`, `BindService.java:24,50-51`, `AuthService.java:25,67-68` (WR-06 max length) |
| T-07-05 | Elevation | BindService wallet path | high | mitigate | Same playerId bind; never sum/merge wallets | closed — `BindService.java:45-48`; BindIT no-sum |
| T-07-06 | Information | Bind logs | medium | mitigate | No password / password_hash logging | closed — `BindService.java` has no Logger; emit attrs empty Map |
| T-07-08 | Spoofing | login + TokenService.rotate | high | mitigate | Argon2 verify + rotate `isGuest` from DB; guest adopt requires possession (Bearer sub==guestPlayerId + guest claim, or guestRefreshToken mapped to guest) | closed — `AuthService.java:81-82` gates any `guestPlayerId` via `TokenService.requireGuestPossession` (`TokenService.java:101-114`: access `sub`+`guest`+DB guest, or refresh hash→playerId+DB guest); wired from `GuestController.java:72-78` (`bearerToken` + `guestRefreshToken`); BindIT `loginAdoptWithoutGuestPossessionIsUnauthorized` / `loginAdoptAcceptsGuestRefreshPossession` |
| T-07-09 | Spoofing | credential stuffing | high | mitigate | Per-IP LoginRateLimiter on login; IP from socket remoteAddr only | closed — `GuestController.java:68,103-106`; `LoginRateLimiter.java:14-40` (WR-02: no XFF trust) |
| T-07-10 | Elevation | wallet sum on sign-in | high | mitigate | Adopt contract never-sum; import_not_eligible; abandon guest economy on import; BindIT | closed — `AuthService.java:51,88-96,225-237` (`abandonGuestEconomy` zeros wallets + deletes inventory/loadout before `revokeAll`); never-sum path present (WR-01) |
| T-07-11 | Elevation | guest Ranked via UI | medium | mitigate | Soft-lock UX; server 403 | closed — `catalog_page.dart:370-373`; server gate T-07-12 |
| T-07-12 | Elevation | RankedQueueService | high | mitigate | JWT `guest` claim gate + DB `isGuest=false` re-check | closed — `RankedMatchmakingController.java:56-61`; `RankedQueueService.java:45,65,166-174` `requireBoundPlayer`; `MatchService.java:293-306` `requireBoundSeat` (WR-04) |
| T-07-13 | Tampering | RatingService / settle | high | mitigate | Glicko only on server Ranked settle; no client rating POST | closed — `MatchService.java:1084-1086`, `RatingService.java`; no `/v1/rating` POST |
| T-07-14 | Tampering | SoftElo isolation | high | mitigate | Ranked settle does not touch SoftElo | closed — same as T-07-03; `RankedSettleIT.rankedSettleUpdatesGlickoNotSoftElo` |
| T-07-15 | Elevation | CasualQueue leakage | medium | mitigate | Sibling `RankedQueueService` | closed — `RankedQueueService.java:18+`; CasualQueue has no RANKED mode |
| T-07-16 | Repudiation | rematch on Ranked | medium | mitigate | `allowsRematch` excludes RANKED; UI Find Ranked only | closed — `MatchService.java:278-281`; `pause_overlay.dart:273-275,287` |
| T-07-17 | Denial | pause-grief reconnect | high | mitigate | Aggregate `pauseUsedMs` + budget → next drop forfeit | closed — `MatchService.java:677-694,861-876`; `ReconnectPolicy.java:50-56` |
| T-07-18 | Tampering | grace timer | high | mitigate | Server SoT grace/budget constants | closed — `ReconnectPolicy.java:37-56`; client display-only |
| T-07-19 | Elevation | bot-fill on Ranked drop | medium | mitigate | No bot-fill on Ranked forfeit | closed — `MatchService.java:677` path `settleExpiredDrop`; `RankedReconnectIT` asserts not BOT_WIN; `RankedQueueService` never bot-fills |
| T-07-20 | Tampering | Casual policy regression | medium | mitigate | Casual 30/8 unchanged | closed — `ReconnectPolicy.java:19-20,38-43`; `RankedReconnectIT` T-07-20 comment |
| T-07-21 | Elevation | BoardsController | high | mitigate | Bound-only + SQL `guest = false` | closed — `BoardsController.java:32-37`; `BoardsService.java:57,82`; `BoardsIT.guestRejected` |
| T-07-22 | Tampering | board ordering | high | mitigate | ORDER BY Glicko rating / all_time_peak only | closed — `BoardsService.java:60,85-87`; `BoardsIT.neverOrderByCoins` |
| T-07-23 | Information | boards response | low | accept | Username + rating public by design | closed — accepted risk |
| T-07-24 | Tampering | season reset | medium | mitigate | Server-side SeasonService formula only; separate all-time Glicko triple | closed — `SeasonService.java:90,110-111,117-137`; `GlickoRatingEntity` `all_time_rd`/`all_time_sigma`; no client rating write API (WR-05) |
| T-07-25 | Information | EventSink logs | high | mitigate | UUID playerId; scrub password/token/secret keys | closed — `EventSink.java:36-52,56-72` |
| T-07-26 | Denial | EventSink in settle TX | medium | mitigate | catch Throwable; never rethrow | closed — `EventSink.java:51-53`; `EventSinkIT.sinkFailureDoesNotRollBackSettle` |
| T-07-27 | Tampering | CI supply chain | medium | mitigate | Pin Temurin 21 + flutter 3.47.2; `./mvnw` | closed — `.github/workflows/ci.yml:11-17,26-28` |
| T-07-28 | Information | compose.prod secrets | high | mitigate | `NOMAD_JWT_SECRET` + `NOMAD_POSTGRES_PASSWORD` via required env; no secrets in git | closed — `compose.prod.yaml:5-6,14,33-38` (WR-03) |
| T-07-29 | Spoofing | bind_api | medium | mitigate | Session JWT via NomadApi; server guest bind | closed — `nomad_api.dart:437-442`; `GuestController.java:56-62` |
| T-07-30 | Information | bind form | low | accept | `obscureText: true`; no password logging | closed — accepted risk; `bind_sheet.dart:239`, `sign_in_sheet.dart:330` |
| T-07-31 | Elevation | client-forced adopt=import | high | mitigate | Server `import_not_eligible`; UI follows adoptHint | closed — `AuthService.java:90-92`; `sign_in_sheet.dart:198-216`; `GuestSession.importEligible` |
| T-07-SC | Tampering | Maven/pub installs | low | accept | No new npm/pub in phase; Wave 0 no installs | closed — accepted risk |

*Status: open · closed · open — below {block_on} threshold (non-blocking)*
*Severity: critical > high > medium > low — only open threats at or above `block_on: high` count toward `threats_open`*
*Disposition: mitigate (implementation required) · accept (documented risk) · transfer (third-party)*

### Open detail (blocking)

*None — all register threats closed; `threats_open: 0`.*

---

## Accepted Risks Log

| Risk ID | Threat Ref | Rationale | Accepted By | Date |
|---------|------------|-----------|-------------|------|
| AR-07-23 | T-07-23 | Boards intentionally expose username + Glicko rating; no passwords/wallets in response | plan threat_model (07-06) | 2026-09-14 |
| AR-07-30 | T-07-30 | Password field uses obscureText; residual shoulder-surf / client memory risk accepted at low | plan threat_model (07-09) | 2026-09-14 |
| AR-07-SC | T-07-SC | Phase dependency surface limited; no new npm/pub; Wave 0 had no package installs | plan threat_model (07-01 / 07-07) | 2026-09-14 |

---

## Unregistered Flags

From SUMMARY threat sections: plans used `## Threat Mitigations` (not `## Threat Flags`); all listed IDs map to the register above — **none unregistered from executor summaries**.

From `07-REVIEW.md` / `07-REVIEW-FIX.md` (prior CR/WR residuals — **all mitigated** on re-audit):

| Flag | Maps to | Notes |
|------|---------|-------|
| CR-01 login guestPlayerId IDOR | **T-07-08 CLOSED** | `requireGuestPossession` before adopt; BindIT IDOR 401 + refresh possession |
| WR-01 adopt leaves guest economy live | **T-07-10 mitigated** | `abandonGuestEconomy` in same TX before `revokeAll` |
| WR-02 X-Forwarded-For login IP | **T-07-09 mitigated** | `clientIp` = `getRemoteAddr()` only |
| WR-03 compose Postgres password | **T-07-28 mitigated** | `${NOMAD_POSTGRES_PASSWORD:?…}` required (same pattern as JWT) |
| WR-04 Ranked gate JWT-only | **T-07-12 mitigated** | DB `requireBoundPlayer` / `requireBoundSeat` |
| WR-05 all_time_rating overwritten | T-07-24 / integrity | Separate `all_time_rd`/`all_time_sigma`; soft-reset preserves all-time triple |
| WR-06 no password max length | **T-07-04 mitigated** | `MAX_PASSWORD_LENGTH=128` on bind + login before Argon2 |

**Unregistered (no plan threat ID):** none remaining — prior WR-03 DB default is closed under T-07-28.

Info-only from clean re-review (not register threats; do not affect `threats_open`): IN-01 EventSink key-name scrub narrowness; IN-02 client should omit `guestPlayerId` unless session is guest; IN-03 abandoned guest access JWT TTL until expiry (economy cleared).

---

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open (all) | Open ≥ block_on | Run By |
|------------|---------------|--------|------------|-----------------|--------|
| 2026-09-14 | 32 | 31 | 1 | 1 | gsd-security-auditor |
| 2026-09-15 | 32 | 32 | 0 | 0 | gsd-security-auditor (re-audit post CR-01/WR fixes) |

---

## Sign-Off

- [x] All threats have a disposition (mitigate / accept / transfer)
- [x] Accepted risks documented in Accepted Risks Log
- [x] `threats_open: 0` confirmed
- [x] `status: verified` set in frontmatter

**Approval:** verified — T-07-08 guest possession proof present; WR-01..WR-06 residuals mitigated in register notes
