# Project Retrospective

*A living document updated after each milestone. Lessons feed forward into future planning.*

## Milestone: v1.0 — Parlor MVP

**Shipped:** 2026-09-15
**Phases:** 7 | **Plans:** 59 | **Tasks:** 118

### What Was Built
- Alchiki physics gate (Forge2D + dyn4j keyframe authority)
- Guest parlor: catalog, bot/private/casual Alchiki, SoftElo profile, soft cosmetics
- Stick Pull second live title with stamina + short reconnect
- Bind identity, Glicko Ranked, skill boards, EventSink, GHA + compose.prod

### What Worked
- Physics fail-fast Phase 1 before accounts/economy
- Wave 0 RED IT stubs before production paths (Nyquist)
- Sibling RankedQueue (not Casual flag) kept SoftElo/Glicko isolation clean
- code-review --fix --auto closed CR-01 guest possession IDOR before ship

### What Was Inefficient
- Phase 7 VERIFICATION left `behavior_unverified` after later UAT/IT greens (stale docs)
- Nyquist `nyquist_compliant` not closed on early phases until audit
- Parent-repo git nesting (`проекты` vs `nomad-game`) complicated pathspecs

### Patterns Established
- Guest-first + soft bind; never wallet sum on adopt
- Server SoT timers in ReconnectPolicy by mode×game
- PRES-02 palette + wood UI chrome across parlor surfaces
- Forge2D pin 0.14.2 — do not upgrade casually

### Key Lessons
1. Ship Ranked only after Casual reconnect is stable (roadmap order mattered)
2. permitAll login + guestPlayerId needs possession proof (CR-01) — catch in security review before close
3. Accept tech_debt Nyquist on early phases at milestone close if requirements and integration are green — track in Deferred Items

### Cost Observations
- Timeline: ~10 days (2026-09-05 → 2026-09-15)
- Notable: heavy Testcontainers IT coverage for bind/ranked/boards paid off at UAT

---

## Cross-Milestone Trends

### Process Evolution

| Milestone | Phases | Plans | Closeout | Notes |
|-----------|--------|-------|----------|-------|
| v1.0 | 7 | 59 | verified_closeout + tech_debt accepted | First ship |

### Recurring Debt Themes

- Nyquist frontmatter lag on early phases
- VERIFICATION frontmatter not always refreshed after late IT runs
