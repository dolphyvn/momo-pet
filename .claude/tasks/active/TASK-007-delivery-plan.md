# TASK-007 — Step 6: Delivery Plan

## Parent Epic
EPIC-001 — Product Definition & Delivery Plan

## Objective
Convert the approved MVP into an executable, dependency-ordered plan: epics, stories/tasks, acceptance criteria, implementation order, test requirements, release gates (project.md §40 Step 6, §30 item 23) — and materialize it as `.claude/tasks/` files ready for fresh-agent execution.

## Context
All Phase 0 documents are DONE and reviewed. The first vertical slice is fixed (project.md §40 Step 7): Launch → Momo visible → idle animation → touch → react → state change → persist → Watch receives state. Build vertical slices, not disconnected layers. CLAUDE.md §32: tasks must be independently understandable/implementable/testable/reviewable/committable — never "build the entire app".

## Requirements
Read `CLAUDE.md`, `project.md`, and ALL documents under `docs/`, then produce:
1. `docs/product/06-delivery-plan.md`:
   - Epic breakdown for Phase 1 (EPIC-002+; recommended seed from the spec: foundation/project bootstrap, pet model, pet state engine, persistence, iPhone home experience + character rendering, watch app + sync, then polish/QA/release-readiness)
   - Story-level task list per epic with: TASK-IDs (continuing numbering from TASK-008), parent epic, objective, acceptance criteria, required tests, dependencies, estimated size (S/M/L)
   - Implementation order with dependency graph (respecting the recommended first vertical slice)
   - Test requirements per epic mapped to the §32 matrices
   - Release gates (Definition of Done per §35; final product test checklist §44)
   - Risk register with mitigations
2. Materialize into `.claude/tasks/`:
   - `epics/EPIC-002…00N-*.md` files (§7 template)
   - `active/TASK-008…` files ONLY for the first executable batch (do not pre-create every future task file as full documents — batch creation is the orchestrator's job per just-in-time principle; a task list table inside the delivery plan is the backlog of record)
3. Update targets: mark EPIC-001 status; orchestrator will update status.md after review.
Rules:
- Task granularity per CLAUDE.md §32 examples (e.g., "Define PetState domain model", "Implement deterministic PetStateEngine", "Add PetStateEngine tests" are separate tasks).
- Every task must trace to PRD FRs and architecture documents.
- Phase discipline: Phase 1 only.
- Horizontal ordering: domain before UI; each epic should end with a demonstrable vertical slice wherever possible.

## Files / Areas Likely Affected
- Creates `docs/product/06-delivery-plan.md`
- Creates `.claude/tasks/epics/EPIC-002…00N-*.md`
- Creates first-batch `.claude/tasks/active/TASK-008…` files
- May update `.claude/tasks/epics/EPIC-001-product-definition.md` status line

## Dependencies
- TASK-006 (DONE required).

## Constraints
- Jupiter model, fresh agent, no commit by agent.

## Acceptance Criteria
- Delivery plan covers all Phase 1 epics with dependency-ordered tasks at §32 granularity; first vertical slice is the earliest build path; every epic has acceptance criteria + test requirements + release-relevant gates; EPIC-002+ files materialized; first task batch ready with no conversational-context dependency.
- Review verdict ≥ APPROVED_WITH_MINOR_NOTES.

## Required Tests
- Not applicable (document). Independent review agent required.

## Review Requirements
- Fresh reviewer verifies: completeness vs PRD FRs (every FR mapped to ≥1 task), granularity, dependency-graph acyclicity + slice ordering, phase discipline, task-file self-sufficiency for a fresh agent. Record in `.claude/tasks/reviews/REVIEW-TASK-007.md`.

## Git Requirements
- Commit (orchestrator, post-approval): `docs(product): TASK-007 delivery plan with Phase 1 epics and task breakdown`

## Status
TODO

## Implementation Notes
- (agent fills in)

## Reviewer Findings
- (orchestrator records)

## Completion Evidence
- (commit hash + push, by orchestrator)
