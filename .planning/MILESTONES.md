# Milestones

## v1.0 Parlor MVP (Shipped: 2026-09-15)

**Closeout type:** verified_closeout (all phases `phase_complete` + `verification_status=passed`; audit-open clear)

**Audit:** `tech_debt` accepted — [v1.0-MILESTONE-AUDIT.md](./milestones/v1.0-MILESTONE-AUDIT.md) (46/46 requirements; integration 15/15; Nyquist partial on phases 1–4, 6)

**Phases completed:** 7 phases, 59 plans, 118 tasks

**Delivered:** Guest-first parlor catalog (Alchiki + Stick Pull) with private rooms, casual QM, soft economy/cosmetics, bind identity, Glicko Ranked, skill boards, EventSink analytics, and PR CI + PROD compose.

**Key accomplishments:**

1. Alchiki physics gate: Forge2D client + dyn4j JVM keyframe authority (PROTO-01/02)
2. Guest mint → catalog → server-scored Alchiki bot match with EN/RU how-to (AUTH-01, ALCH-*, PRES-*)
3. Private rooms + casual reconnect + consented leave; Casual Quick Match + SoftElo profile
4. Server ledger COINS/GEMS + presentation-only cosmetics (ECON-*)
5. Stick Pull live title with stamina tug, tap clamp, 8s reconnect no bot-fill
6. Bind (same playerId, never-sum adopt) + Ranked Glicko + boards + ANLT-01 + GHA/compose.prod

**Git range:** 2026-09-05 → 2026-09-15 (~381 commits in parent repo; ~7.2k Java + ~16.8k Dart LOC main)

**Known tech debt (accepted at close):** see audit YAML `tech_debt` — primarily `/gsd-validate-phase` for phases 1–4 and 6; Phase 3 leave/clock warnings; Phase 7 VERIFICATION stale `behavior_unverified` fields.
