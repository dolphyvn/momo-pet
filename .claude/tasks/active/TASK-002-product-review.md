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
IN_PROGRESS

## Implementation Notes
- (agent fills in)

## Reviewer Findings
- (reviewer records via orchestrator)

## Completion Evidence
- (commit hash, push status — recorded by orchestrator)
