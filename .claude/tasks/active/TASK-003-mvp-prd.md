# TASK-003 — Step 2: MVP Product Specification (PRD)

## Parent Epic
EPIC-001 — Product Definition & Delivery Plan

## Objective
Produce a concise, implementation-ready MVP PRD that consolidates the spec + the resolved decisions from TASK-002 into the single product source of truth for Phases 1 (project.md §40 Step 2, §30 items 1–8).

## Context
Momo: iPhone + Apple Watch companion pet. Mood ❤️ / Energy ⚡ / Bond ✨ are the only three user-facing dimensions (§5). Phase 1 MVP = iPhone (one pet, home, idle animation, interactions, feed, simple play, basic room, persistence) + Watch (pet, mood/state, today's quest, one interaction, haptics, sync) (§27). No punishment (§4). Notifications must feel like a companion (§15).

## Requirements
Read `CLAUDE.md`, `project.md`, `docs/product/01-product-review.md`, then produce `docs/product/02-mvp-prd.md` containing:
1. Target users & personas (2–3, with jobs-to-be-done)
2. Core loop (daily loop per §6, explicitly excluding feed-grind loops)
3. Functional requirements (numbered FR-x, each testable, MVP-scoped)
4. Non-functional requirements (performance, battery, privacy, accessibility, reliability)
5. MVP scope (Phase 1, per §27) and explicit non-goals (§28)
6. Acceptance criteria per FR
7. Success metrics (aligned with §34 analytics events; no surveillance framing)
8. Three-dimension model definition (Mood/Energy/Bond semantics, ranges, what moves them — relational, not XP grinding)
9. Quest design rules for Phase 1 (small, achievable, non-manipulative)
Rules:
- Must incorporate every decision logged in `01-product-review.md`; if the PRD needs a decision that was escalated (not resolved), mark it OPEN-DECISION and do not invent it.
- Phase discipline: nothing from Phases 2–4 may appear as a requirement (§24, §27).
- Concise and decision-oriented; every requirement must be verifiable.

## Files / Areas Likely Affected
- Creates `docs/product/02-mvp-prd.md`

## Dependencies
- TASK-002 (DONE required).

## Constraints
- Jupiter model, fresh agent, no commit by agent.

## Acceptance Criteria
- All 9 sections present; FRs are numbered, testable, and MVP-only; acceptance criteria concrete; non-goals restated verbatim-equivalent to §28; every TASK-002 default decision either adopted (with trace) or challenged with rationale.
- Review verdict ≥ APPROVED_WITH_MINOR_NOTES.

## Required Tests
- Not applicable (document). Independent review agent required.

## Review Requirements
- Fresh reviewer independently verifies: MVP-only scope, no manipulative mechanics, FR testability, consistency with 01-product-review decisions, philosophy compliance. Record in `.claude/tasks/reviews/REVIEW-TASK-003.md`.

## Git Requirements
- Commit (orchestrator, post-approval): `docs(product): TASK-003 MVP product requirements document`

## Status
TODO

## Implementation Notes
- (agent fills in)

## Reviewer Findings
- (orchestrator records)

## Completion Evidence
- (commit hash + push, by orchestrator)
