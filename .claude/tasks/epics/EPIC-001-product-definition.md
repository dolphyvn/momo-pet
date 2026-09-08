# EPIC-001 — Product Definition & Delivery Plan

## Objective
Complete project.md §40 Steps 1–6 (Product Review → MVP PRD → UX Architecture → Character System → Technical Architecture → Delivery Plan) as a set of internally consistent, implementation-ready documents, so that engineering (Step 7) can start on a solid, non-contradictory foundation.

## User / Product Value
No end-user value yet. This epic de-risks the entire product: it prevents building the wrong thing, resolves spec contradictions early, and produces the executable task breakdown for all later engineering epics.

## Scope
- Critical review of `project.md` (contradictions, unknowns, unnecessary complexity, technical/product risks) — without changing the core vision.
- Concise, implementation-ready MVP PRD (target users, JTBD, core loop, functional/non-functional requirements, MVP scope, non-goals, acceptance criteria, success metrics).
- UX architecture (sitemap, screen inventory, navigation, onboarding, daily flow, iPhone/Watch/widget flows, permission flow).
- Character system specification (visual direction, anatomy constraints, expressions, animation/state inventory, interaction map, motion timings, asset requirements).
- Technical architecture (system context, module architecture, domain model, Pet State Engine design, persistence, iPhone↔Watch sync strategy, HealthKit strategy, widget architecture, notification architecture, testing architecture, privacy architecture) + ADRs.
- Delivery plan converting the approved MVP into epics, stories, acceptance criteria, dependencies, implementation order, test requirements, release gates.

## Non-Goals
- Any production code, Xcode project, or asset production (Step 7+ / EPIC-002+).
- Phase 2–4 features (HealthKit integration design beyond strategy level, widgets implementation, monetization implementation).
- Documentation for volume's sake — every artifact must resolve a real product/engineering decision (project.md §30).

## Dependencies
- None external. Requires only the two contracts: `CLAUDE.md` and `project.md`.

## Tasks
- TASK-001 — Repository & orchestration bootstrap
- TASK-002 — Step 1: Product Review
- TASK-003 — Step 2: MVP Product Specification (PRD)
- TASK-004 — Step 3: UX Architecture
- TASK-005 — Step 4: Character System
- TASK-006 — Step 5: Technical Architecture (+ ADRs)
- TASK-007 — Step 6: Delivery Plan

Dependency chain: 002 → 003 → {004 ∥ 005} → 006 → 007.

## Acceptance Criteria
- All six documents exist under `docs/` and are consistent with each other and with the core vision (§45 North Star).
- Every contradiction/risk found in Step 1 is either resolved with a documented decision or explicitly deferred with rationale.
- ADRs for meaningful architecture decisions exist under `.claude/tasks/decisions/`.
- Delivery plan yields EPIC-002+ with independently executable tasks (CLAUDE.md §32 granularity).
- Every task passed independent review before its commit.

## Test Requirements
- Not code — verification is via independent review agents (CLAUDE.md §10) checking consistency, scope protection, and contract compliance.

## Definition of Done
- All tasks DONE (implemented, reviewed, committed, pushed), `status.md` accurate, and a new orchestration agent could resume from the repository alone.

## Status
IN_PROGRESS (TASK-001 ✅, TASK-002 ✅; TASK-003 READY — see .claude/tasks/status.md)
