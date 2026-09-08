# TASK-006 — Step 5: Technical Architecture

## Parent Epic
EPIC-001 — Product Definition & Delivery Plan

## Objective
Produce the technical architecture for Phase 1 and record all meaningful decisions as ADRs (project.md §40 Step 5, §30 items 17–21; CLAUDE.md §21).

## Context
Native Apple stack, local-first MVP (§21). iPhone is the authoritative pet state holder; Watch syncs carefully around offline/eventual consistency (§21). Pet behaviour is a real domain engine with deterministic core + injectable randomness (§23). Domains per §22; no business logic in views; Presentation/Domain/Data separation proportional to product. Phases 2+ concerns (HealthKit reads, widgets, notifications) are architecture-*reservations*, not implementations.

## Requirements
Read `CLAUDE.md`, `project.md`, `docs/product/01-product-review.md`, `docs/product/02-mvp-prd.md`, `docs/design/03-ux-architecture.md`, `docs/design/04-character-system.md`, then produce `docs/architecture/05-technical-architecture.md` containing:
1. System context diagram (textual) — app, Watch app, future widget/HealthKit extension points
2. Module architecture (targets: iOS app, Watch app, shared domain package; module boundaries + dependency rules)
3. Domain model (Pet, PetState, Mood/Energy/Bond, DailyProgress, Quest, Interaction, Room — normalized from §24 example, with types and invariants)
4. Pet State Engine design (inputs, outputs, pure core, injectable clock/randomness, tick model, transition rules; how the character system consumes it per 04-character-system §9)
5. Persistence architecture (SwiftData vs alternatives — decide with rationale; corruption/recovery stance; migration policy)
6. iPhone↔Watch synchronization strategy (transport, freshness/staleness rules, conflict handling, what happens with no iPhone/paired-but-away; per §32 sync test matrix)
7. HealthKit strategy (Phase 2 reservation: permission UX contract, data minimization, read-only step counts, denied-permission degradation)
8. Widget architecture (Phase 2 reservation: timeline budget, shared state read path)
9. Notification architecture (Phase 2 reservation: categories, frequency governor, quiet rules per §15)
10. Testing architecture (per-target test plan mapping §32's domain/persistence/sync/UI/edge matrices to concrete test targets)
11. Privacy architecture (data inventory, on-device stance, privacy manifest implications, deletion story; §25)
12. Performance budget (launch, animation frame target, Watch battery stance, §33)
Also create ADRs under `.claude/tasks/decisions/` (format per CLAUDE.md §21), minimum:
- ADR-001-local-first-persistence.md
- ADR-002-watch-sync-strategy.md
- ADR-003-pet-state-engine.md
Plus any additional ADRs for decisions with real alternatives (e.g., module packaging, animation runtime).
Rules:
- Verify API/deployment claims against current official Apple documentation knowledge; where uncertain, mark VERIFY-AT-BUILD rather than asserting (project.md §21, §25 "no fake completion").
- Deployment target choice must be explicit and justified.
- No enterprise abstractions without demonstrated value (§22).

## Files / Areas Likely Affected
- Creates `docs/architecture/05-technical-architecture.md`
- Creates `.claude/tasks/decisions/ADR-001…00n.md`

## Dependencies
- TASK-004 AND TASK-005 (both DONE required).

## Constraints
- Jupiter model, fresh agent, no commit by agent.

## Acceptance Criteria
- All 12 sections present; domain model has types + invariants; engine design is testable-by-construction (pure core, injected clock/random); sync strategy covers the §32 sync edge matrix; ADRs exist with Status/Context/Decision/Alternatives/Consequences/Date; every open Apple-API question is marked VERIFY-AT-BUILD, none asserted blindly.
- Review verdict ≥ APPROVED_WITH_MINOR_NOTES.

## Required Tests
- Not applicable (document). Independent review agent required.

## Review Requirements
- Fresh reviewer (architecture mindset) verifies: dependency rules actually enforceable, engine determinism/injectability, sync conflict coverage, persistence choice rationale, no speculative Phase 2+ implementation, ADR completeness. Record in `.claude/tasks/reviews/REVIEW-TASK-006.md`.

## Git Requirements
- Commit (orchestrator, post-approval): `docs(architecture): TASK-006 technical architecture and ADRs`

## Status
TODO

## Implementation Notes
- (agent fills in)

## Reviewer Findings
- (orchestrator records)

## Completion Evidence
- (commit hash + push, by orchestrator)
