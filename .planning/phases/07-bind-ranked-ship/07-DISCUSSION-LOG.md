# Phase 7: Bind, Ranked + Ship - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-09-14
**Phase:** 7-bind-ranked-ship
**Areas discussed:** Bind UX, Ranked queue, Ranked reconnect, Boards & seasons, Ship harden

**Mode:** User delegated — «обработай всё самостоятельно, выбери оптимальные вариант»

---

## Bind UX

| Option | Description | Selected |
|--------|-------------|----------|
| Soft prompt after first bot win + Profile entry | FEATURES Miniclip-style funnel | ✓ |
| Splash / wall before catalog | Registration-first | |
| Profile-only, never soft prompt | Lower conversion | |

**User's choice:** Delegate to optimal defaults  
**Notes:** D-92…D-96 — 409 Sign in, no wallet sum, logout keeps guest device, Ranked/boards soft-locked; guest shop stays open

---

## Ranked queue

| Option | Description | Selected |
|--------|-------------|----------|
| Both Alchiki + Stick Pull, per-game FIFO, no bots | Platform parity with Casual | ✓ |
| Alchiki only | Smaller MVP | |
| Empty-queue bot fallback | Violates MODE-04 | |

**User's choice:** Delegate  
**Notes:** D-97…D-100 — wait+Cancel only; no Ranked rematch; Stick Pull Ranked false-start 70% / forfeit

---

## Ranked reconnect

| Option | Description | Selected |
|--------|-------------|----------|
| Alchiki 18s / Stick 12s + aggregate pause budgets | ROADMAP 15–20 band + tug shorter | ✓ |
| Research SUMMARY 90s Alchiki / 12s Stick | Conflicts with REQUIREMENTS ~15–20 | |
| Single 20s for both games | Oversimplifies Stick tug | |

**User's choice:** Delegate  
**Notes:** D-101…D-103 — budgets 45s / 20s; rated forfeit; no bot-fill

---

## Boards & seasons

| Option | Description | Selected |
|--------|-------------|----------|
| Glicko-2 STACK defaults + quarterly soft reset + Profile/catalog boards | REQUIREMENTS LEAD-* | ✓ |
| Elo only | Rejected by STACK | |
| Coin leaderboards | Forbidden | |

**User's choice:** Delegate  
**Notes:** D-104…D-106

---

## Ship harden

| Option | Description | Selected |
|--------|-------------|----------|
| GHA Maven+Flutter + compose PROD Postgres+JAR; Android proof | ROADMAP folded CI | ✓ |
| Full K8s / Redis / SaaS analytics | Out of PROJECT | |
| Docs-only, no CI | Not releasable | |

**User's choice:** Delegate  
**Notes:** D-107…D-108

---

## Claude's Discretion

Password hasher; Glicko period; soft-reset coefficient; Ranked service shape; EventSink persistence; Alchiki Ranked draw edge-case.

## Deferred Ideas

Forgot-password, OAuth add-on, bind GEMS reward, Ranked rematch, suspect MMR penalty, Redis/K8s/SaaS.
