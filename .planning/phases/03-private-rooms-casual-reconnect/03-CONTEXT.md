# Phase 3: Private Rooms + Casual Reconnect - Context

**Gathered:** 2026-09-07
**Status:** Ready for planning

<domain>
## Phase Boundary

This phase delivers the **first human Alchiki match**: two guests create or join a **private room by a short code**, both Ready, play an **authoritative** NORMAL table, **rematch**, **rejoin within 30s** after a brief drop, or **forfeit** with a known loss.

Success is MODE-01, MODE-02, MODE-05, SESS-02, SESS-05 — not Quick Match (Phase 5), Ranked/bind (Phase 7), Stick Pull playable (Phase 6), shop, chat, voice, or a friends graph.

Do **not** reopen the physics stack (Flutter 3.47 + Flame 1.38 + forge2d 0.14.2 / flame_forge2d 0.19.3+7 + dyn4j 6). Do **not** reopen SESS-01: the client still cannot author scores. Bot catalog path stays; this phase **adds** Create room / Join by code beside it.

</domain>

<decisions>
## Implementation Decisions

### Catalog entry, lobby, code (discussed)
- **D-26:** Catalog grows **two new CTAs**: **Create room** and **Join by code**. Do not fold both into a single «With a friend» screen. Existing **Play Alchiki** + EASY/NORMAL/HARD chips stay for the **bot** path only.
- **D-27:** After the second guest joins, the match does **not** start immediately. Both players tap **Ready**; then the server starts. Nobody should eat a throw unprepared.
- **D-28:** Host lobby shows a large 4–6 character code plus **system share sheet** (WhatsApp/Telegram/etc.) **and** **Copy**. Deep links are not required this phase (`go_router` can take them later).
- **D-29:** **Host-alive lobby:** if the host leaves the lobby before kickoff, the **code dies immediately**. If **10 minutes** pass with nobody reaching both-Ready, the room closes. Joiner must not sit in a zombie lobby.
- **D-30:** When both Ready, the **joiner throws first**. Host waited; guest starts. Server assigns seats — the client does not pick turn order.
- **D-31:** Private-room Alchiki is always **NORMAL (6 target bones)**. Difficulty chips are **bot-only**. Do not put EASY/HARD on Create room.
- **D-32:** Join errors are short copy (**no such room** / **already started** / **host left**) and the **code field stays** so the player can type another code without bouncing to the catalog.
- **D-33:** Lobby labels are **Guest-XXXX** (last four characters of `playerId`). No username yet (bind is Phase 7).

### Opponent turn on the table (discussed)
- **D-34:** Opponent aim is **not live**. Same theatrical as the bot: after the server accepts a throw it sends `ThrowResolved`; the waiting client plays **aim + hold + keyframe settle**. No 60 Hz live physics, no telegraph of aim angle over WebSocket.
- **D-35:** While the opponent has not released yet: table frozen at last settle, HUD **their 20s clock**, plus a **static “aiming” pose with no angle**. Not a live arrow.
- **D-36:** **Your** throw still gets local Forge2D **preview then morph onto JVM keyframes** (Phase 1 D-10). The opponent sees **only** the keyframe buffer for that throw.
- **D-37:** **Two sakas**, different colors, parked on the rim; only the current owner’s saka throws. Do not keep the single shared saka from the bot table.

### Transport, authority, guests (not discussed — lock research + REQUIREMENTS)
- **D-38:** **REST** for create/join room, lobby Ready, rematch accept, leave. **Raw WebSocket** (JSON, **not STOMP/SockJS**) for the in-play match channel: `ThrowInput`, `ThrowResolved`, `RejoinSnapshot`, `Ping`. One socket owned by session. Steal Colyseus **patterns** (seat hold, rotating rejoin token, full snapshot) — do **not** adopt Colyseus/Nakama as the backend.
- **D-39:** Guests may create and join private rooms (FEATURES: casual + private stay open for guests). Bind is not a gate.
- **D-40:** Room code is **4–6 alphanumeric** (MODE-01). Planner may exclude ambiguous glyphs (0/O, 1/I) as long as the code stays short and shareable.

### Reconnect, rematch, forfeit (not discussed — lock REQUIREMENTS + FEATURES defaults)
- **D-41:** Casual Alchiki reconnect grace is **30 seconds** (SESS-02 / ROADMAP). **Not** the research 60s proposal. Seat held on the server; token bound to `playerId` + `matchId`, rotate on use; **full snapshot** on rejoin, never a delta from a dead client. Client auto-retries then offers **Rejoin**. Opponent HUD: **reconnecting + server timer**. Pause **turn/match clocks** for the dropped seat during grace so a Wi-Fi blip is not a free 20s forfeit. Consented leave is **0 s grace** (not a reconnect).
- **D-42:** If the 30s grace expires in a **private** match, the remaining player **wins**. **No bot-fill** of a friend’s seat (bot-fill is a later casual-queue idea, not this phase).
- **D-43:** **Rematch (MODE-05):** after a **private** result, both see **Again?** with a **10s** accept window; both must accept or both return to catalog. After a **bot** result, **one-tap Play again** (no dual accept). Rematch is a **new match** with the same two seats (private) or a new bot match (bot). Joiner-first (D-30) applies to a private rematch kickoff.
- **D-44:** **Leave/forfeit:** keep the existing Pause **confirm** dialog. Consented leave ends the match **immediately as a loss** for the leaver (SESS-05). Vs bot: still `BOT_WIN`. Vs human: **opponent wins** — do **not** write `BOT_WIN` onto a two-player row. Crash/drop ≠ Leave.

### Claude's Discretion
- Exact code alphabet, lobby layout, Ready button chrome, share-sheet copy — UI-SPEC / planner, within PRES-02 palette.
- WS frame schema, ticket vs query JWT, 1 Hz housekeeping, Flyway room tables — researcher/planner, as long as D-38–D-42 hold.
- Whether Create room is a catalog button that pushes `/lobby` or a sheet; Join is a catalog button that pushes `/join` with a code field — both CTAs must exist (D-26).
- How-to: if `howto.alchiki.seen` is already true, skip the pager on the way to a private table (D-14). First-ever Alchiki (bot or room) still gets the five cards.
- Break the Modulith cycle `games ↔ session` **before** two-player types are shared (STATE concern). Do not paper over it with `*.*.internal` forever.
- `web_socket_channel` 3.x per STACK.md; reconnect token in secure storage beside refresh.
- Ranked reconnect, Quick Match empty-queue, Stick Pull reconnect, chat/emotes — out of this phase.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase and requirements
- `.planning/ROADMAP.md` — Phase 3 goal, success criteria, MODE-01/02/05, SESS-02/05
- `.planning/REQUIREMENTS.md` — MODE-01, MODE-02, MODE-05, SESS-02, SESS-05 (do not implement MODE-03/04, SESS-03/04, AUTH-02, CAT-02, ECON-*, STICK-* playable)
- `.planning/PROJECT.md` — guest-first, server authority, REST+WebSocket, modular monolith
- `.planning/STATE.md` — Modulith `games ↔ session` cycle; reconnect seconds were hypotheses, SESS-02 now 30s for this phase

### Prior phase locks
- `.planning/phases/01-alchiki-physics-prototype/01-CONTEXT.md` — D-04–D-11 aim/hold, 2.5D, JVM keyframes, no lockstep
- `.planning/phases/02-guest-catalog-first-alchiki-match/02-CONTEXT.md` — D-12–D-25 guest catalog, bot REST, no WS yet, result overlay without rematch
- `.planning/phases/02-guest-catalog-first-alchiki-match/02-UI-SPEC.md` — catalog/match/pause chrome to extend; rematch/reconnect banners were explicitly out of Phase 2

### Rooms, session, reconnect
- `.planning/research/FEATURES.md` — private 4–6 code, host-alive lobby, system share sheet, rematch 10s (private) / immediate (bot), leave confirm, guests in private rooms
- `.planning/research/ARCHITECTURE.md` — `MatchSession` + `GameEngine`, raw WS, rotating reconnect token, full snapshot, consented leave ≠ drop
- `.planning/research/STACK.md` — REST + raw WebSocket, `web_socket_channel` 3.0.3, `spring-boot-starter-websocket`, disable STOMP/SockJS
- `.planning/research/PITFALLS.md` — Pitfall 4 (one reconnect policy / token = transport / delete seat on drop); Pitfall 9 (client-trusted private rooms)
- `.planning/research/SUMMARY.md` — steal Colyseus/Nakama **room patterns only**; ignore its Phase 3 vs Phase 5 split (ROADMAP collapsed rooms+reconnect into Phase 3). Prefer SESS-02 **30s** over SUMMARY’s 60s casual proposal.

### Code to extend
- `client/lib/catalog/catalog_page.dart` — add Create room / Join by code; keep Play Alchiki + difficulty chips for bots
- `client/lib/platform/router.dart` — new lobby/join/match-human routes; `go_router` already chosen
- `client/lib/games/alchiki/pause_overlay.dart` — Leave confirm exists; ResultOverlay is catalog-only until rematch (D-43)
- `client/lib/platform/api/nomad_api.dart` — REST match create/throw/leave; add room + WS session
- `backend/src/main/java/com/nomadgames/session/MatchService.java` — `leaveMatch` is bot-oriented (`BOT_WIN` if `IN_PLAY`); two-player leave must follow D-44
- `client/lib/input/throw_input.dart` — unchanged wire contract for throws

No SPEC.md for this phase. No external ADRs.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- Catalog + `go_router` + i18n EN/RU + guest JWT mint — add two CTAs and lobby/join routes; do not rebuild identity.
- `AlchikiMatchPage` / `MatchGame` / HUD / pause — bot loop is REST `POST /v1/matches` + `/throws` + `/leave`. Human match should reuse the table, clocks, how-to-from-pause, and keyframe player; swap the second seat from `ScriptedBot` to a remote player.
- `MatchService.applyThrow` + `AlchikiRules` + dyn4j burst — keep as authority. Need a second saka in spawn (D-37) and a non-bot opponent path.
- Result overlay (`pause_overlay.dart`) — add rematch CTAs (D-43); keep palette PRES-02.

### Established Patterns
- Flame `GameWidget` only after match create succeeds (howto tests).
- Access JWT in memory; `playerId` + refresh in `FlutterSecureStorage`. Reconnect token belongs there too.
- Server Instants are HUD truth; client clocks display-only.
- Modulith: `session` currently uses non-exported `games` types (`AlchikiRules`, `MatchStatus`, `ScriptedBot`) — `ModularityTest` fails. Fix the cycle in this phase before two-player session types multiply.

### Integration Points
- Catalog home `/` → Create room → lobby with code; Join by code → code field; both Ready → `/match` (or stay in a match shell) with WS attached.
- `POST /v1/matches` today always creates a **bot** match. Rooms need a distinct create/join (REST) then a match id both seats share.
- Leave: bot path `BOT_WIN`; human path opponent win; terminal statuses must stay honest (02-09).

</code_context>

<specifics>
## Specific Ideas

- User picked **joiner throws first** on purpose (host waited). Rematch should not silently flip this unless seats swap — keep joiner-first for the new private match.
- User picked **always NORMAL** so catalog difficulty chips never apply to rooms. Do not “helpfully” copy the last bot difficulty into Create room.
- Opponent turn must **feel** like the bot’s visible turn (aim + hold + settle), not an instant score popup and not a live pool-style aim leak.

</specifics>

<deferred>
## Deferred Ideas

- Casual Quick Match + empty-queue bot/invite (Phase 5)
- Ranked reconnect, aggregate pause budget, rated forfeit (Phase 7 / SESS-03)
- Stick Pull reconnect (Phase 6 / SESS-04)
- Chat, emotes, friends list, QR codes, deep-link join (v2 / later unless planner finds deep links free)
- Bot-fill of a disconnected **casual queue** seat (not private rooms)

None extra from this discussion — user stayed inside Phase 3.

</deferred>

---

*Phase: 3-Private Rooms + Casual Reconnect*
*Context gathered: 2026-09-07*
