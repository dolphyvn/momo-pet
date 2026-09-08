# TASK-005 — Step 4: Character System

## Parent Epic
EPIC-001 — Product Definition & Delivery Plan

## Objective
Define Momo the character: visual direction, anatomy constraints, expressions, animation/state inventory, interaction→reaction map, motion timings, and asset requirements (project.md §40 Step 4, §30 items 12, 14–16).

## Context
Momo must feel alive even untouched (§4): idle, blinking, breathing, looking around, plus state animations (happy, excited, sleepy, sleeping, eating, playing, walking, surprised, affection, celebrating, low energy). Motion is a core capability, not decoration (§19); subtle over excessive; battery-conscious. Visual language: warm off-white, soft pastels, rounded, minimal (§18). Reduce Motion must degrade gracefully (§20). Phase 1 = ONE production-quality pet.

## Requirements
Read `CLAUDE.md`, `project.md`, `docs/product/01-product-review.md`, `docs/product/02-mvp-prd.md`, then produce `docs/design/04-character-system.md` containing:
1. Visual direction (silhouette-first description; proportions; what makes it read "cute × calm × premium" — spec does not fix a species; recommend one and justify, decision flag if truly product-defining)
2. Character anatomy constraints (rig/parts model that SwiftUI/vector animation can actually implement; what may never change)
3. Expression inventory mapped to Mood/Energy/Bond (the only three user-facing dimensions, §5) — color-independent state communication (§20)
4. Animation state inventory: every state from §4 with trigger, duration, loop behavior, interruption rules (can a blink be interrupted by a tap?)
5. Idle behaviour choreography (how idle feels alive without distraction; variation rules; §8's "controlled variation" with injectable randomness)
6. Interaction→reaction map (head/belly/touch gestures → reactions, per §4)
7. Motion timings & curves (breath cycle, blink rate, transition durations; Reduce Motion fallbacks per §20)
8. Asset requirements & production plan (vector/SVG/Lottie-vs-SwiftUI-native tradeoff; size budgets; naming convention; what Phase 1 actually ships)
9. Character behaviour variance spec (how the Pet State Engine (§23) requests animations; the contract between this document and TASK-006)
Rules:
- Every animation must state its battery/performance consideration (§33).
- No audio design required in Phase 0 unless trivially scoped; note as OPEN-DECISION if it matters.
- Phase 1 only: one pet, no outfits/seasonal content (those are Phase 3, §27).

## Files / Areas Likely Affected
- Creates `docs/design/04-character-system.md`

## Dependencies
- TASK-003 (DONE required). Runs in parallel with TASK-004 (different file, no overlap).

## Constraints
- Jupiter model, fresh agent, no commit by agent.

## Acceptance Criteria
- All 9 sections present; every §4 state covered with trigger/duration/interruption; interaction map consistent with TASK-004 flows; Reduce Motion handled; asset plan is implementable with a SwiftUI-first approach and names a concrete recommendation.
- Review verdict ≥ APPROVED_WITH_MINOR_NOTES.

## Required Tests
- Not applicable (document). Independent review agent required.

## Review Requirements
- Fresh reviewer verifies: §4 state coverage, feasibility of every animation in SwiftUI/vector terms, interruption rules coherence, battery statements, philosophy compliance (subtle, not noisy). Record in `.claude/tasks/reviews/REVIEW-TASK-005.md`.

## Git Requirements
- Commit (orchestrator, post-approval): `docs(design): TASK-005 character system specification`

## Status
TODO

## Implementation Notes
- (agent fills in)

## Reviewer Findings
- (orchestrator records)

## Completion Evidence
- (commit hash + push, by orchestrator)
