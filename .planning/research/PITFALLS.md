# Pitfalls Research

**Domain:** Mobile 1v1 parlor PvP platform (physics Alchiki + tap-stamina Stick Pull, guest-first, server-authoritative, cosmetics economy)
**Researched:** 2026-09-05
**Confidence:** MEDIUM overall (seam: `websearch --verified` = MEDIUM, raw `webfetch` = LOW). Claims that rest on official Gaffer / Colyseus / Nakama / Firebase / Play Billing / Roblox / MiniTon pages are treated as primary even when the transport is tagged MEDIUM. No fabricated incident URLs.

Phase names below follow the architecture research build order. **Phase 1 is Alchiki Physics Prototype.** Do not invert it.

## Critical Pitfalls

### Pitfall 1: Building accounts, shop, and ranked before the throw feels good

**What goes wrong:**
The team (or one developer + agents) spends weeks on guest auth, COINS/GEMS ledgers, shop SKUs, Glicko-2, and a catalog shell. Alchiki is “dropped in” last. The hold-to-throw feels random, bodies never sleep, FPS dies on mid Android, or there is no path from client input to a server sim. The success metric — a first bot match that makes the player want another — never fires. The platform is a beautiful empty box.

**Why it happens:**
Accounts and shops are familiar CRUD. Physics feel is not. AI agents are faster at Spring modules than at tuning restitution. “Platform first” sounds responsible for a catalog product.

**How to avoid:**
Phase 1 is **only** the throw: aim, hold-to-throw, mass/impulse/rotation/friction/restitution, sleep, settle-then-score, mid-Android FPS, and a **non-client scorer** that consumes the same `ThrowInput` and emits keyframes. No shop UI. No bind screen. No ranked. If the prototype fails, **change the client/physics stack here**, not after identity exists.

**Warning signs:**
- Sprint 1 tickets are `Player`, JWT, Flyway, shop mockups.
- Physics is “we’ll use Forge2D later.”
- Success demos show a login screen, not a bone leaving the circle.
- “We’ll prove multiplayer after the platform is solid.”

**Phase to address:**
**Phase 1 — Alchiki Physics Prototype.** This is a hard gate. Later phases are forbidden until the gate passes.

---

### Pitfall 2: Lockstep (or client-authoritative rest poses) for Alchiki physics

**What goes wrong:**
Both phones run Forge2D / Unity Physics / Box2D on the same inputs. After a few throws the boards disagree. Ranked looks like cheating. Or the throwing client uploads final transforms (“hybrid”) and anyone with a patched APK pockets three bones.

Gaffer On Games is explicit: lockstep needs **bit-identical** results; most physics engines are not deterministic across compilers, OS, instruction sets, or even debug vs release. Lockstep also **cannot simulate frame n without input n** — lost packets hitch the whole match (TCP wait ≈ RTT×2). Snapshot interpolation exists precisely because “floating point determinism across platforms is hard,” and lockstep waits on the slowest peer.

Unity’s built-in physics is non-deterministic by design; a 2019 Unity Discussions thread from a **carrom/billiards** team reports same-device replay works and **cross-device final board state does not**. Flame/Forge2D users hit frame-dependent impulse/damping (flame-engine/flame#2750: first impulse ≠ later impulse when FPS drops). Cross-engine lockstep (Forge2D on phone ↔ jbox2d/dyn4j on JVM) is a guaranteed rewrite.

**Why it happens:**
“1v1 = lockstep” is a meme from RTS/fighters. Bandwidth looks cheaper than snapshots. Hybrid “client simulates, server trusts rest” feels low-latency.

**How to avoid:**
**Do not lockstep Alchiki.** Client sends `{ aim, power/holdMs }`. Server burst-simulates to sleep, scores, broadcasts a **closed keyframe buffer**. Clients interpolate (Gaffer snapshot interpolation as **playback**, not as live 60 Hz authority). Optional local preview may start on release; server keyframes win; morph/snap on diverge. Never accept rest poses, scores, or “I pocketed N” from the client.

TCP/WebSocket is acceptable **for the keyframe buffer** (short, reliable, turn-based). Do not copy Gaffer’s live 60 Hz UDP snapshot stream into a 2–5 min parlor turn.

**Warning signs:**
- Protocol has `finalTransforms[]` or `clientScore`.
- Checksums of world state differ after the same throw on two devices.
- “We’ll sync once when everything sleeps” (the carrom workaround — looks like a teleport).
- Physics steps with `dt = frameTime` instead of a fixed 1/60 or 1/120.

**Phase to address:**
**Phase 1** must prove a server-side (or headless JVM) sim path. **Phase 4** wires it to `GameEngine`. Do not “fix lockstep later” in Ranked.

---

### Pitfall 3: Flutter-vs-Unity lock-in before the prototype gate

**What goes wrong:**
Stack is frozen by habit: Flutter because the rest of the app is forms; Unity because “it’s a game.” Three months later the throw is unshippable on Flutter+Flame (variable-dt, no shared solver with the Java server) **or** Unity is a 200 MB client with a C# physics world that cannot be replayed on Spring. Rewriting the client after identity, shop, and i18n exist is the expensive rewrite.

**Why it happens:**
Comfort. Store listings. Agent training data. Nobody wants to throw away a week of screens.

**How to avoid:**
Treat Phase 1 as a **stack experiment**, not a product. The acceptance test is: mid-Android FPS + readable collisions + hold-to-throw + **the same `ThrowInput` produces keyframes from a server-owned solver**. Flutter+Flame+Forge2D is allowed only if a JVM (dyn4j/jbox2d) can consume the same impulse model — not if the Dart world is the authority. Unity is allowed only if you will run **the same** physics on the server (dedicated Unity headless **or** a ported solver) — not Unity client + “send transforms.” Godot same rule.

Do not start platform screens until that sentence is true.

**Warning signs:**
- `pubspec.yaml` / Unity project created in week 0 “so we can move fast.”
- Shop and catalog widgets exist; no throw scene.
- Argument is “Flutter is better for CRUD” or “real games use Unity,” not a prototype recording.

**Phase to address:**
**Phase 1.** Stack decision is an **output** of the prototype, not an input.

---

### Pitfall 4: One reconnect policy; token = transport session; seat deleted on drop

**What goes wrong:**
Casual Alchiki, Ranked Alchiki, and Stick Pull share a 30 s (or 5 min) seat. A 20 s tug outlives its own match. A Wi-Fi flip in Ranked is either a free escape or an instant rated loss. Consented `leave()` is treated like a crash. Client stores `sessionId` / room id; after process death the seat is gone. Opponent sees a frozen board.

Colyseus official reconnection: hold the seat with `allowReconnection`; persist a **`reconnectionToken` that refreshes on every successful connection**; automatic retry only while the in-memory room object lives; after app kill use **manual reconnect**; server sends a **full snapshot**; **do not remove the player in `onDrop`** — wait for permanent `onLeave`; consented leave is a different close code and must **not** get a grace. Suggested windows: ~30 s fast-paced, ~5 min turn-based, **or reject after N missed turns**.

MiniTon official forfeit guide: typical reconnect ~20 s; **aggregate** the timer so pause-griefing cannot reset it; **forfeit ≠ crash abort**; intentional leave submits a losing score, not a silent abort; timer lives on the **server**.

**Why it happens:**
One `allowReconnection(client, 30)` copied from a tutorial. Mobile backgrounding is underestimated. Stick Pull is treated as “just another room.”

**How to avoid:**
Mode-specific grace (architecture research): Casual Alchiki 60 s **or** 2 missed own turns; Ranked Alchiki 90 s then rated forfeit; Stick Pull 8–12 s then opponent wins; consented leave **0 s**. Bind the token to `playerId` + `matchId`, rotate after use. Full snapshot on rejoin, never a delta from a dead client. Opponent UI: “reconnecting + server timer.” Ranked: no bot-fill.

**Warning signs:**
- Single `reconnectSeconds` constant.
- `onDisconnect` deletes the seat.
- Client only retries the open WebSocket (dies with the process).
- Stick Pull grace ≥ match length.
- Ranked “draw” after a rage-quit.

**Phase to address:**
**Phase 3 — Match session + reconnect** (empty `GameEngine`). Tune numbers in **Phase 8** (Ranked) and **Phase 9** (Stick Pull). Verify in **Phase 11** UAT (background app, airplane mode, process kill).

---

### Pitfall 5: Guest → account as “create user + merge wallets”

**What goes wrong:**
First launch creates Guest A. “Register” creates User B. A weekend script does `coins = max(A,B)` or `A+B`. Smurfs farm guest coins and dump them onto a ranked account. Or the opposite: the player binds an existing username and **loses** the guest cosmetics with no 409. Or the guest key was an advertising ID / `Settings.Secure.ANDROID_ID` and silently rotates — new `playerId`, empty wallet, support tickets.

Nakama official: one account, many linked identifiers; **link of an ID already owned by another account returns 409**; Nakama **does not auto-merge** two existing accounts; device IDs **rotate** — generate a UUID, store in **private** app storage, do **not** use hardware IDs other apps can read.

Firebase official `linkWithCredential`: same user id on success; **fails if the credential already belongs to another account**; docs say you must handle merge **as appropriate for your app** — there is no platform default that is safe for a ledger.

**Why it happens:**
REST mental model: POST `/users` then POST `/merge`. Tutorials show “anonymous then create email user.” Economy is an afterthought.

**How to avoid:**
Guest **is** the `Player`. Bind **links** username/password to the same `playerId` (Phase 2 schema, even if UI is Phase 10). Username taken → **409**, offer Sign in. After sign-in: **do not add guest coins/gems/rating** onto a non-empty account. Optional one-time import only if the target has **zero matches and zero spend**, one transaction, audit row. Never `max` or `sum`. Ranked and gem sinks require a bound credential. Persist our UUID in secure storage.

**Warning signs:**
- `players` table has `guest_id` and `user_id` as different PKs.
- Merge function adds balances.
- Guest key is advertising ID / vendor ID only.
- Bind UI exists before the unique-credential constraint.

**Phase to address:**
**Phase 2** (schema: `Player` + `Credential[]` + audit). **Phase 10** (bind UI + 409). Tests in Phase 2: link happy path, 409, no-sum.

---

### Pitfall 6: Economy as client balances (and IAP bolted on later)

**What goes wrong:**
Client displays `coins` from local prefs or a GET that the client can replay. Match-end POSTs `{ coinsDelta: 50 }`. Shop buy is `UPDATE players SET coins = coins - 100` without an idempotency key — double-tap or retry grants twice. When IAP finally ships, Play `purchaseToken` is not stored, PENDING purchases grant GEMS, Apple `finish()` runs before the ledger write — or the inverse, unfinished transactions re-grant forever.

Play Billing official security: send `purchaseToken` to a **secure backend**; **`purchaseToken` is globally unique — use it as a primary key**; verify with the Developer API; grant only if unused **and** state is `PURCHASED` (not PENDING); then consume/acknowledge on the server.

Apple StoreKit: `finish()` means the app **already delivered** the content. Finish before a durable grant and a crash **loses the purchase**. Finish never, and the transaction **re-delivers**. Same `transactionId` can arrive from `purchase()` and `Transaction.updates` — grant must be idempotent.

**Why it happens:**
MVP has no real money, so “we’ll add a unique constraint later.” Soft currency feels fake. IAP is out of scope, so the table is `players.coins INTEGER`.

**How to avoid:**
Phase 6: **ledger only**. `economy` writes balances. Settlement uses key `matchId:reason`. Shop uses client-generated idempotency key + unique constraint. Dual wallets COINS/GEMS from day one. Reserve `purchases(provider, token UNIQUE, player_id, sku, state)` **empty** — do not implement Play/App Store in MVP, but do not invent a second wallet when they arrive. Never grant on PENDING. Never trust client balances.

**Warning signs:**
- `Player.coins` updated in the match handler.
- Shop endpoint has no idempotency column.
- “IAP is post-MVP so skip the purchase table.”
- Cosmetic SKU changes mass, restitution, or tap force.

**Phase to address:**
**Phase 6 — Economy + cosmetics.** Settlement consumers in **Phase 4/8** must call economy, not write coins. IAP columns idle until a later milestone.

---

### Pitfall 7: Stick Pull as unlimited mash (client timestamps, auto-ban)

**What goes wrong:**
The tug is “who sends more tap events.” An autoclicker or a multi-touch flood wins Ranked. Or the client sends `{ t: 12.01, tap: true }` and a speed hacker lies about time. Or a regularity detector **auto-bans** a rhythmic human and support explodes.

Roblox official server-side detection: **the server decides**; never ban from client detections; **design > detection** (clamp/validate first); **Action Cadence** is a **signal**, not proof — robotic inter-tap variance; use a **suspicion score**; escalate (log → clamp → restrict → ban); prefer reversible actions.

Human single-finger sustainable tap is roughly 5–6.5/s (MEDIUM — tune on device). Unlimited CPS is the failure mode of Tug It! / Button Mash toys.

**Why it happens:**
Tap games are “easy.” Anti-cheat is imagined as an SDK. Stamina is “feel,” not authority.

**How to avoid:**
Client sends tap **counts per window**, not marker position. Server re-timestamps on arrival, clamps (e.g. ≤10 accepted taps/s), owns stamina and marker, ticks 10–20 Hz. Regularity flag → `suspect` log in v1, **no auto-ban**. Exhaustion is the product: mash loses. False-start taps before GO are ignored (Casual) or penalized (Ranked). Do not ship kernel anti-cheat SDKs in MVP.

**Warning signs:**
- Win condition reads `client.marker`.
- No stamina bar, or stamina is cosmetic-only.
- “If variance < ε, ban.”
- Same Alchiki burst loop used for the tug.

**Phase to address:**
**Phase 9 — Stick Pull.** Clamp/stamina live on **all** online modes, not “Ranked only later.” Soft `suspect` review is v1.x (**Phase 8+**).

---

### Pitfall 8: One-dev over-architecture (microservices, K8s, Redis-as-truth)

**What goes wrong:**
`alchiki-svc`, `stick-svc`, `mm-svc`, Redis wallets, Prometheus, Segment, a Compose file that needs a cluster. Weeks of YAML. Zero throws. Distributed transactions for coins + rating become the job. Or Redis is the match **and** the wallet — a flush deletes Ranked integrity.

PROJECT.md already forbids microservices/K8s and analytics platforms. Indie consensus matches it: microservices solve **org** scale, not 1v1 parlor. A modular monolith is the platform move.

**Why it happens:**
“Real games do this.” Agents happily generate Helm charts. Redis is in every game-backend blog.

**How to avoid:**
One Spring JAR, one Postgres, Docker Compose, in-process queues and sessions. Spring Modulith boundaries instead of network. Redis **only** when a second app instance or measured queue latency exists — never as economy truth. Thin `EventSink` table, not Amplitude. Split `session` out only after a measured heap/WS bottleneck.

**Warning signs:**
- More deployables than playable games.
- `docker-compose` has Redis, Kafka, Grafana in week 2.
- Economy rows live in Redis hashes.
- Phase 2 is “platform infra” with no `playerId` used by a match.

**Phase to address:**
**Phase 2** (skeleton stays a monolith). Re-check at **Phase 11**. Never a standalone “infra phase” before Phase 1.

---

### Pitfall 9: Client-sent scores, rest state, or rating as “anti-cheat later”

**What goes wrong:**
Private rooms ship client-authoritative “to move fast.” Ranked and coins inherit the same message. Cheating is not a future DLC — it is the JSON.

**Why it happens:**
Server physics feels expensive. Friends “won’t cheat.” Anti-cheat is scheduled after launch.

**How to avoid:**
From the first human match (**Phase 5**), the wire is inputs-only. Ranked (**Phase 8**) adds nothing new except bind + Glicko-2 + stricter reconnect. If private rooms trust the client, Ranked cannot be “turned on.”

**Warning signs:**
- Different authority for Casual vs Ranked.
- Client can set `winnerPlayerId`.
- “We’ll add Play Integrity later” as a substitute for server sim.

**Phase to address:**
**Phase 4** (bot already uses server scorer). **Phase 5** (first human). **Phase 8** must not introduce a second protocol.

---

## Technical Debt Patterns

Shortcuts that seem reasonable but create long-term problems.

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Client-only Alchiki prototype (no JVM harness) | Faster feel iteration | No proof the server can step the same throw; stack lock-in | Only the first days of Phase 1; gate still requires a non-client scorer |
| Local bot using the client physics world | Easy EASY/NORMAL/HARD | Bot scores diverge from online; “bot is fair, PvP is not” | Phase 1 only; Phase 4 bots must use server engine |
| In-memory guest map, no Postgres | Faster Phase 2 | Lost players on restart; merge/audit impossible | Never past the first identity spike |
| Single `reconnectSeconds` | Less code | Stick Pull / Ranked grief | Never — use a `ReconnectPolicy` per mode |
| Soft-currency `UPDATE coins` without ledger | Fewer tables | Cannot audit, cannot idempotent-settle, IAP rewrite | Never |
| Skip purchase-token table because IAP is out of MVP | Less schema | Double-grant on first IAP week | Never — empty unique table is cheap |
| Auto-ban on tap regularity | Feels “secure” | False positives destroy Ranked trust | Never in v1; log `suspect` only |
| Redis for wallets / live physics | Fast reads | Restart = economy/rank hole | Never as truth |
| Perfect local prediction clone in Ranked | Zero release lag | Aimbot queries the local solver | Casual preview only; Ranked can wait 1 RTT |
| STOMP/SockJS “Spring WebSocket” | Tutorial default | Fights binary snapshots + reconnect tokens | Never for match WS |
| Analytics SaaS in MVP | Pretty funnels | Slows identity/match work | Never; `EventSink` only |
| Microservices / K8s | Feels “production” | One-dev rewrite | Never in this milestone |
| Advertising ID as guest key | One line of code | Rotates; other apps can impersonate | Never — app-generated UUID |
| Coin-wager tables / stat cosmetics | Retention like 8 Ball Pool | P2W + honesty promise broken | Never |
| One 20 Hz tick for Alchiki and Stick Pull | One loop | Wasted CPU or starved tug | Never — shared session, different clocks |

## Integration Gotchas

Common mistakes when connecting to external services.

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| Colyseus-style reconnect (patterns only — we are not adopting Colyseus) | Hold seat 30 s for every room; persist `sessionId`; delete player on drop; skip snapshot | Mode-specific grace; persist **rotating** reconnect token; full snapshot; consented leave ≠ drop |
| Nakama / Firebase link (patterns only) | Create second user; sum wallets; ignore 409; use hardware device id | Link onto guest `playerId`; 409 → sign in; no-sum; app UUID in secure storage |
| Google Play Billing (post-MVP) | Grant from client callback; reuse token; grant on PENDING; no unique constraint | Backend verify; `purchaseToken` PK; grant only `PURCHASED`; then consume/ack |
| Apple StoreKit (post-MVP) | `finish()` before ledger write, or never finish; treat `purchase()` and `updates` as two grants | Verify → durable idempotent grant on `transactionId` → `finish()` |
| Play Integrity / App Attest | Treat attestation as authority | Extra signal later; never a substitute for server sim + tap clamp |
| Redis | Wallet / match / physics in Redis | Queues and rate limits after replica #2; Postgres remains truth |
| Spring WebSocket | STOMP broker destinations | Raw match WS, JWT/ticket on connect |
| Device identity | `ANDROID_ID` / IDFA / `identifierForVendor` as login | Client-generated UUID; vendor id is a **hint**, not the credential |

## Performance Traps

Patterns that work at small scale but fail as usage grows.

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| 60 Hz server tick for Alchiki | Idle CPU, battery on host, coupling to Stick Pull | Burst sim per throw, 1 Hz housekeeping | Immediately (wrong model), not at user count |
| Variable `dt` physics (Flame/Forge2D default) | Impulse/damping change with FPS; emulator ≠ device (flame#2750) | Fixed timestep 1/60 or 1/120, catch-up cap | First mid-tier Android drop |
| Live 60 Hz snapshot stream over WS | Jank + bandwidth on cellular | 10–20 Hz keyframes for a **closed** 1–3 s throw | First LTE match |
| Physics in Redis / across nodes | Desync, serialization cost | Sim on the session owner’s heap | First two-node deploy |
| Matchmaking `SELECT … FOR UPDATE` on all rated players | Queue latency | In-process lists now; Redis ZSET when 2 instances | ~second replica or slow SQL, not 100 users |
| One JVM, unbounded concurrent matches | GC pauses, WS fan-out | Cap matches; then route sessions | First load spike (measure; don’t pre-shard) |
| Leaderboard `ORDER BY` every profile open | Slow reads | Postgres now; Redis ZSET cache of top N later | Tens of thousands of rated rows |
| Stick Pull raw tap flood (no clamp) | Server spin, unfair wins | Window + clamp before integrate | First autoclicker, even at 10 users |

## Security Mistakes

Domain-specific security issues beyond general web security.

| Mistake | Risk | Prevention |
|---------|------|------------|
| Client rest poses / scores / rating / balances | Forged Ranked and coin dupes | Inputs only; server owns settle |
| Guest wallet merge (`sum` / `max`) | Economy exploit, smurf laundering | Link same `playerId`; 409; no-sum |
| Hardware / advertising ID as auth | Impersonation, silent account loss | App UUID in secure storage |
| WS without seat-bound auth | Hijack live match | JWT/ticket + `playerId` on every frame |
| Replay match-reward or shop POST | Double coins / double SKU | Idempotency keys + unique constraints |
| IAP grant on PENDING / unverified token | Stolen GEMS | Verify; `PURCHASED` only; token PK |
| Client tap timestamps as clock | Speed hacks | Server clock; clamp rate |
| Auto-ban on one cadence heuristic | Ban innocent rhythmic players | Suspicion score; v1 log only (Roblox) |
| Ranked open to guests | Disposable smurfs, rating noise | Bind required |
| Consented leave counted as crash | Rage-quit farming | Immediate forfeit; abort ≠ forfeit (MiniTon) |
| Cosmetics that change physics / tap force | Pay-to-win | Same mass/restitution/aim for all ranked saka |
| Play Integrity as the anti-cheat | Bypassed; still need authority | Optional later signal only |

## UX Pitfalls

Common user experience mistakes in this domain.

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| Registration wall before first throw | First-session death | Guest → EASY bot → bind after first win |
| Bind prompt on splash | Rage-quit install | Prompt when there is something to lose |
| 5 min Ranked wait on a Wi-Fi flip | “Game stole my rank” | 90 s + visible timer + rated forfeit on expiry |
| Same reconnect as Stick Pull | Tug frozen half the match | 8–12 s then opponent wins |
| Silent seat deletion on background | “I didn’t leave” | Persist token; Rejoin button after process death |
| Autoclicker wins the tug | Party game feels broken | Stamina + clamp; mash visibly fails |
| Auto-ban for “too regular” taps | Support war | Log `suspect`; no v1 ban |
| Shop / ranked before fun throw | Pretty app, no retention | Phase 1 gate |
| Outdoor 15-bone / first-to-8 rules | 15 min sessions, unread board | Mobile 5–7 bones, first to 5, 2–5 min cap |
| Static cards that dump federation jargon | Player never scores | 3–5 cards: circle, aim, hold, out = point, first to 5 |
| Empty-queue spinner 60 s | “Online is dead” | Offer bot or room code |
| Coin-wager / P2W cue stats | Distrust | Flat rewards; cosmetic-only |
| Guest progress lost with no warning | 1-star reviews | One notice after they have coins/cosmetics |
| 409 bind with no Sign-in path | “Username taken” dead end | Sign in to existing; do not merge wallets |

## "Looks Done But Isn't" Checklist

Things that appear complete but are missing critical pieces.

- [ ] **Phase 1 prototype:** FPS on a **mid Android device**, not only the emulator — verify sleep, rotation, hold-to-throw, and a **headless/JVM** keyframe dump from the same `ThrowInput`.
- [ ] **Physics timestep:** Fixed `dt`, not frame time — verify two runs at 30 FPS vs 60 FPS produce the same settle (server) / readable feel (client).
- [ ] **Authority:** No client field can change score, winner, coins, or rating — verify by sending a forged settle and seeing reject.
- [ ] **Reconnect token:** Survives **process death**, not only WS drop — verify airplane mode + swipe-away.
- [ ] **Consented leave:** Immediate forfeit, no grace — verify Leave button ≠ crash path.
- [ ] **Guest bind:** Same `playerId` on happy path; **409** on taken username; **balances do not sum** — verify with two seeded accounts.
- [ ] **Guest key:** App UUID in secure storage — verify uninstall creates a new guest; advertising ID unused.
- [ ] **Economy:** Replay shop POST and match reward — verify second call is a no-op.
- [ ] **IAP-ready schema:** `purchases.token` unique exists even with zero IAP rows.
- [ ] **Stick Pull:** 20+ CPS client flood does not move the marker faster than clamp — verify on device.
- [ ] **Stick Pull GO:** Pre-GO taps do not move the marker.
- [ ] **Ranked:** Guest enqueue rejected; cosmetics do not change impulse.
- [ ] **Session plugin:** Alchiki and Stick Pull share `MatchSession`, not a copy-pasted room with a different tick assumption.
- [ ] **Empty queue:** Quick Match offers bot or invite, not a silent fail.
- [ ] **i18n:** No hardcoded RU/EN strings in game modules — verify a missing key, not a missing language.

## Recovery Strategies

When pitfalls occur despite prevention, how to recover.

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Throw feels bad / stack cannot feed server sim | HIGH | **Stop product work.** New Phase 1. Do not migrate shop/auth onto a dead feel. Change Flutter/Unity/Godot here. |
| Lockstep / client rest poses already shipped | HIGH | Freeze Ranked and coin rewards. Switch wire to input→sim→keyframes. Treat old matches as exhibition. |
| Engine lock-in (wrong client, shop already built) | HIGH | Keep platform REST; rewrite only `games/alchiki` + server solver. Do not rewrite identity. This is why Phase 1 is first. |
| Wallet-sum merge in production | HIGH | Halt bind. Reverse merged ledgers from audit if possible; otherwise freeze balances and manual restore. Ship no-sum + 409. |
| Guest key rotation (advertising ID) | MEDIUM | Issue new UUID; cannot recover lost guests — show “progress was on this device only.” |
| Double coin grant (no idempotency) | MEDIUM | Unique constraint + backfill keys from `matchId`; claw back obvious dupes via ledger. |
| IAP double-grant / PENDING grant | HIGH | Token PK; revoke extra entitlements; grant only `PURCHASED`. |
| Stick Pull autoclicker meta | MEDIUM | Ship clamp + stamina immediately (even as hotfix). Do not start with bans. |
| False-positive tap bans | MEDIUM | Revert bans; switch to `suspect` logs; apologize in-app. |
| One reconnect timer griefing Ranked | MEDIUM | Deploy mode policies + aggregate budget; do not need a protocol rewrite if seats already exist. |
| Microservices already generated | HIGH | Collapse to one JAR. Do not “finish K8s then play.” |
| Redis wallets flushed | HIGH | Restore from Postgres if it was truth; if Redis **was** truth, economy is gone — this is why it must never be. |
| P2W cosmetic already sold | HIGH | Stat-reset all saka; refund or convert to look-only; Ranked trust may not recover. |

## Pitfall-to-Phase Mapping

How roadmap phases should address these pitfalls.

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| Shop/accounts/ranked before feel | **Phase 1 — Alchiki Physics Prototype** | Gate checklist: FPS, sleep, rotation, hold-to-throw, **server/headless keyframes**. No identity tickets in this phase. |
| Lockstep / client rest poses | Phase 1 (path), Phase 4 (wire) | Two devices + JVM harness: same throw → same scores from **server** only. Forged transforms rejected. |
| Flutter/Unity lock-in | **Phase 1** | Stack chosen only after server-sim path proven. |
| Variable-dt / Forge2D FPS coupling | Phase 1 | 30 vs 60 FPS: server settle identical; client feel still readable. |
| Over-architecture (K8s, Redis-truth, SaaS analytics) | Phase 2 | One JAR + Postgres in Compose. No Redis/K8s/Amplitude. |
| Guest key / schema split users | Phase 2 | UUID in secure storage; `Player` + `Credential[]`; no second PK on register. |
| Reconnect one-size / delete-on-drop / token = session | Phase 3 | Process-kill rejoin; consented leave instant; full snapshot. |
| Client scores in first human match | Phase 4–5 | Private room: patched client cannot pocket bones. |
| Economy without ledger / IAP hole | Phase 6 | Replay buy + reward; `purchases.token` unique exists. |
| P2W cosmetics / wager tables | Phase 6 + 8 | All saka same physics; no entry fee. |
| Ranked on guests / rage-quit = draw | Phase 8 | Bind required; disconnect after grace = rated loss. |
| Autoclicker tug / client clock / auto-ban | Phase 9 | Flood clamped; stamina exhausts mash; no ban on regularity. |
| Bind 409 / wallet sum | Phase 10 | Conflict → Sign in; balances unchanged on existing account. |
| Reconnect/background UAT gaps | Phase 11 | Airplane mode, swipe-away, LTE flip on both games. |

**Phase ordering rationale (pitfall-driven):**

1. Feel + server-sim path first — or every later phase is a rewrite.
2. Identity schema before matches — but **not** shop/ranked UI.
3. Shared session + reconnect before either game is “online.”
4. Alchiki bot → private PvP → economy → ranked. Stick Pull after the session plugin is real.
5. Bind UI late (something to keep) but bind **schema** early.

**Research flags for later phases:**

- Phase 1: **Needs deeper research** if Flutter+Forge2D cannot match a JVM solver (stack reopen).
- Phase 3: Tune grace seconds in UAT — Colyseus/MiniTon give ranges, not Nomad numbers.
- Phase 8: Glicko-2 draw/forfeit mapping — standard, but confirm with rating research.
- Phase 9: Tap clamp numbers are MEDIUM until device playtests.
- Phase 6 IAP: **Needs research** only when real money is in scope (Play PENDING, RTDN `messageId`, StoreKit `updates`).

## Sources

Official / canonical (treat as HIGH authority; seam transport MEDIUM/LOW):

- [Gaffer On Games — Deterministic Lockstep](https://gafferongames.com/post/deterministic_lockstep/) — lockstep needs bit-identical sim; most physics engines are not deterministic across compilers/OS/ISA/debug-vs-release; TCP lockstep hitches on loss (wait for input n). (2014-11-29)
- [Gaffer On Games — Floating Point Determinism](https://gafferongames.com/post/floating_point_determinism/) — same-machine replay ≠ cross-machine; physics APIs may spend more time on faster CPUs.
- [Gaffer On Games — Snapshot Interpolation](https://gafferongames.com/post/snapshot_interpolation/) — use snapshots when determinism is impossible; interpolation buffer trades delay for smoothness; live snapshots want UDP (lost snapshot is skipped). For Nomad: apply interpolation to a **closed throw buffer**, do not run a 60 Hz authority stream.
- [Colyseus — Reconnection](https://docs.colyseus.io/room/reconnection) — `allowReconnection`, rotating `reconnectionToken`, auto vs manual after app kill, full snapshot, do not remove player on drop, ~30 s fast-paced / ~5 min turn-based / missed-round reject, consented leave is not a reconnect.
- [Nakama — Authentication](https://heroiclabs.com/docs/nakama/concepts/authentication/) — one account, many links; link conflict **409**; device IDs rotate; generate UUID, private storage, do not use hardware IDs other apps can read.
- [Nakama — Silent social sign-in](https://heroiclabs.com/docs/nakama/guides/concepts/social-sign-in/) — 409 means two saves; Nakama never auto-unlinks / auto-merges.
- [Firebase Auth — Account linking (Android)](https://firebase.google.com/docs/auth/android/account-linking) — `linkWithCredential` fails if credential already on another user; merge policy is **app-specific**.
- [Play Billing — Fight fraud and abuse](https://developer.android.com/google/play/billing/security) — `purchaseToken` globally unique, use as PK; verify on backend; grant only unused + `PURCHASED`; then consume/acknowledge.
- [Apple — Finishing a transaction](https://developer.apple.com/documentation/storekit/finishing-a-transaction) — finish **after** delivering content. (JS-rendered fetch was empty; wording corroborated by Apple `Transaction.finish()` documentation: finish after the app delivered the content.)
- [Roblox — Server-side detection](https://create.roblox.com/docs/scripting/security/server-side-detection) — server decides; design > detection; Action Cadence as **signal**; suspicion score; no single-heuristic bans.
- [MiniTon — Aborted matches and forfeits](https://docs.miniton.games/developer-success/miniton-developer-documentation/aborted-matches-and-forfeits) — ~20 s reconnect; aggregate pause budget; forfeit ≠ abort; server-side timer.

Community / vendor discussions (MEDIUM — do not treat as incidents we invented):

- [Unity Discussions — Unable to get deterministic physics](https://discussions.unity.com/t/unable-to-get-deterministic-physics/728409) — carrom/billiards: same device OK, cross-device final state diverges; Unity physics non-deterministic.
- [flame-engine/flame#2750](https://github.com/flame-engine/flame/issues/2750) — Forge2D impulse/damping sensitive to FPS / `dt`.
- [Unity Discussions — Deterministic physics for lockstep](https://discussions.unity.com/t/deterministic-physics-for-lockstep-networking-any-progress/585635) — send absolute positions + interpolate rather than chase engine determinism.

Project context (not external incidents):

- `.planning/PROJECT.md` — prototype gate, server authority, one-dev, no IAP in MVP, modular monolith.
- `.planning/research/ARCHITECTURE.md` — input→sim→keyframes; guest is a Player; Redis not truth.
- `.planning/research/FEATURES.md` — table stakes vs anti-features (P2W, wager, mash tug).

---
*Pitfalls research for: Nomad Games — mobile multiplayer traditional parlor PvP*
*Researched: 2026-09-05*
