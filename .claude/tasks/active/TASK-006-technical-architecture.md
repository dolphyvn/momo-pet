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
Also create ADRs under `.claude/tasks/decisions/` (format per CLAUDE.md §21). **ADR-001 is already taken** (character direction, E2 owner decision) — continue the sequence, minimum:
- ADR-002-local-first-persistence.md
- ADR-003-watch-sync-strategy.md
- ADR-004-pet-state-engine.md
Plus any additional ADRs for decisions with real alternatives (e.g., module packaging, animation runtime).
Rules:
- Verify API/deployment claims against current official Apple documentation knowledge; where uncertain, mark VERIFY-AT-BUILD rather than asserting (project.md §21, §25 "no fake completion").
- Deployment target choice must be explicit and justified.
- No enterprise abstractions without demonstrated value (§22).

## Files / Areas Likely Affected
- Creates `docs/architecture/05-technical-architecture.md`
- Creates `.claude/tasks/decisions/ADR-001…00n.md`

## Dependencies
- TASK-004 ✅ DONE (`40c4b77`) and TASK-005 ✅ DONE (`ce84811`) — both satisfied. E2 owner gate RESOLVED: **Direction C — Round Rabbit** (ADR-001).

## Intake Obligations (accumulated from TASK-004/005 reviews — binding)
- DisplayState read-model (UX §7); FR-2 AC-1a device matrix (UX §5.1 budget).
- Hello idempotency + the hello/Q1 window split: hello (+8) once per local day on first touch from either device, never window-gated; Q1 ticks only before 12:00 (UX §11.3).
- Haptics sync to Watch (UX-13 reduces to haptics — no sound in Phase 1 per 04 §11).
- Watch snapshot restore ≤ ~2 s (protects FR-17 ≤ 5 s); invisible corruption-recovery cadence (FR-13 AC-2).
- From 04 §9: ResponsePlan per PRD §4 matrix (engine decides what/when, never warm/cold); satiety window value (open — TASK-006 decides); settle/wake/play handshakes with idempotent completion reports AND `handshakeCancelled(HandshakeKind)` cancellation reports; play effects applied at the single instant the round ceases (completion or preemption, §9.6 item 4); single CharacterClock pause authority; day-stable idle seed = hash(petID, localDay, choreographyEpoch); copy-class namespace (`momo.line.<slot>.<nn>`, `momo.line.react.<family>.<nn>`, `momo.line.moment.<nn>`) with M2 banner + M3 all-done surfaces.
- OBS-1: 04 §3.5's VoiceOver formula governs wording (03:428's literal template hard-codes "has {energy phrase}"); OBS-2: exempt the M2 banner from tone rule 2's 12-word max or scope rule 2 to visual lines — resolve in the copy/engine sections as appropriate.
- **PRD §5.5 cascade rule 1 gap — flag to owner:** rule 1's "local time ≥ 20:00" misses Q6's 00:00–07:00 tail when Q1 is already complete (e.g., 02:00 tuck-in). TASK-006 must surface this as a one-line PRD fix candidate, not silently re-interpret it.

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
READY (dependencies satisfied 2026-09-08; E2 = Direction C recorded in ADR-001)

## Implementation Notes
- (agent fills in)

## Reviewer Findings
- (orchestrator records)

## Completion Evidence
- (commit hash + push, by orchestrator)
