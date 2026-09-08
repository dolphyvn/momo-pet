# TASK-002 — Step 1: Product Review

## Parent Epic
EPIC-001 — Product Definition & Delivery Plan

## Objective
Critically review the `project.md` product specification and produce a findings document that resolves or explicitly defers every contradiction, unknown, and risk — without changing the core vision (project.md §40 Step 1).

## Context
Momo is a premium virtual companion for iPhone + Apple Watch: "a tiny pet that lives alongside your real life." The spec mandates Phase 0 documents before any code. This review is the first step; its outputs feed the PRD (TASK-003) and all later documents.

## Requirements
Read `CLAUDE.md` and `project.md` in full, then produce `docs/product/01-product-review.md` containing:
1. **Contradictions** — internal inconsistencies in the spec (e.g., between MVP scope §27, daily loop §6, quest design §7, engine determinism §23).
2. **Unknowns / open questions** — decisions the spec leaves open, each classified: (a) resolve now with a documented low-risk default (project.md §42 autonomy), or (b) escalate to the human owner (product-defining, privacy-sensitive, etc., per CLAUDE.md §36).
3. **Unnecessary complexity** — spec areas that risk over-engineering an MVP; recommend KEEP / SIMPLIFY / DEFER.
4. **Technical risks** — Apple-platform risks (API availability/deprecation, watchOS sync pitfalls, HealthKit constraints, widget refresh budgets, battery).
5. **Product risks** — emotional-tone drift, engagement-manipulation risk, scope creep vectors.
6. **Decisions log** — every default decision made autonomously, with rationale (these become binding inputs to TASK-003…007 and must be mirrored into `.claude/tasks/status.md` "Architecture / Product Decisions" by the orchestrator).

Rules:
- Do NOT change the core vision or the product philosophy (Cute × Calm × Minimal × Alive × Premium; no punishment mechanics; MVP scope §27–28 are fixed).
- Do NOT write code. Do NOT modify `project.md` or `CLAUDE.md`.
- Findings must cite section numbers of `project.md`.
- The document must be concise and decision-oriented — no padding.

## Files / Areas Likely Affected
- Creates `docs/product/01-product-review.md`
- Nothing else (orchestrator mirrors decisions into status.md)

## Dependencies
- TASK-001 (bootstrap) — DONE.

## Constraints
- Model: Jupiter (session model; no override).
- Fresh agent; no prior conversational context assumed.
- Agent must NOT commit; orchestrator handles commit after review.

## Acceptance Criteria
- Document exists at `docs/product/01-product-review.md`.
- All six categories present, each finding cites `project.md` sections.
- Every open question is either resolved-with-default or explicitly escalated with why.
- No contradiction of the North Star (§45) or MVP scope protection (§27–28).
- Review agent verdict ≥ APPROVED_WITH_MINOR_NOTES.

## Required Tests
- Not applicable (document task). Verification = independent review agent (CLAUDE.md §10).

## Review Requirements
- Fresh review agent receives: this task file, `project.md`, `CLAUDE.md`, and the produced document. Reviewer must independently try to disprove: finding correctness, citation accuracy, scope protection, and whether any "default decision" quietly crosses into product-defining territory. Reviewer must NOT be primed with "the review is good".
- Record verdict in `.claude/tasks/reviews/REVIEW-TASK-002.md`.

## Git Requirements
- Commit (by orchestrator, after review approval): `docs(product): TASK-002 step 1 product review of project spec`

## Status
DONE

## Implementation Notes
- (agent fills in)
- 2026-09-08 — Produced `docs/product/01-product-review.md` (all six required categories + executive summary + TASK-003 handoff section).
  - Contradictions: 7 findings (C1 quest content precedes its HealthKit data source; C2 onboarding species choice vs. single-pet MVP; C3 Watch independence vs. iPhone-authoritative state; C4 device-sync vs. cloud-sync conflation; C5 example model ahead of MVP; C6 retention analytics vs. minimal-data local-first; C7 ambiguous "sleep period" input) + 3 recorded clarifications of apparent (non-)contradictions (§8 vs. §23 determinism; §12 vs. §13; §26 vs. §28).
  - Unknowns: 21 catalogued (U1–U21) — 17 resolved with documented low-risk defaults per project.md §42, 4 escalated per CLAUDE.md §36.
  - Complexity: 10 KEEP/SIMPLIFY/DEFER calls (K1–K10); none touch the North Star (§45) or Phase 1 scope (§27).
  - Technical risks: TR1–TR10 (Watch sync, WidgetKit refresh budget, idle-animation battery, SwiftData-no-device-sync misconception, HealthKit retroactive/opaque-permission realities, 2026 OS-churn/VERIFY-AT-BUILD policy, timezone/DST, asset pipeline weight, Watch lifecycle, toolchain availability).
  - Product risks: PR1–PR9 (tone drift, metrics-vs-philosophy, quest engagement creep, health-quest inclusivity, childish drift, Watch value ambiguity, scope creep vectors, bond-legibility design problem, single-pet depth).
  - Decisions log: D1–D20 (binding inputs to TASK-003…007; orchestrator to mirror into status.md "Architecture / Product Decisions").
  - Escalations: E1 monetization model (§26); E2 character/species direction (owner sign-off gate at TASK-005); E3 location/weather (hard privacy gate, §9/§25); E4 "Momo" trademark clearance (release gate, TASK-007).
- No blocking finding for TASK-003; PRD must honor D1, D3, D4, D6, D10 at minimum (full list in review doc Section 8).
- Scope compliance: no code written; `project.md`, `CLAUDE.md`, and all `.claude/tasks/` files other than this Implementation Notes section untouched; nothing committed (orchestrator handles commit after independent review per CLAUDE.md §10).

## Reviewer Findings
- Independent review agent (`task-002-reviewer`, Jupiter, no shared context): **APPROVED_WITH_MINOR_NOTES** — see `.claude/tasks/reviews/REVIEW-TASK-002.md`.
- 7 findings (F1–F7), all MINOR/NITPICK: one citation error (care/§7), one handoff ambiguity (interaction rules TASK-003 vs TASK-006), one overstatement, one analytics-reconciliation gap, four wording/precision nits.
- All 7 addressed by the orchestrator before commit; 25+ citation spot-checks otherwise all correct; all decisions confirmed within §42 autonomy; no scope expansion; acceptance criteria fully satisfied.

## Completion Evidence
- Deliverable: `docs/product/01-product-review.md` (6 categories + decisions log D1–D20 + escalations E1–E4 + TASK-003 handoff).
- Review record: `.claude/tasks/reviews/REVIEW-TASK-002.md` (APPROVED_WITH_MINOR_NOTES; all findings dispositioned FIXED).
- Commit: hash recorded in `.claude/tasks/status.md` Recent Commits (task file cannot contain its own commit's hash).
- Push: to `origin main` — status recorded in status.md.
