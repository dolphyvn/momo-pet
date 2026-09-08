# TASK-004 — Step 3: UX Architecture

## Parent Epic
EPIC-001 — Product Definition & Delivery Plan

## Objective
Define the complete experience architecture for Phase 1: information architecture, screens, navigation, flows, and the permission strategy (project.md §40 Step 3, §30 items 7–11).

## Context
iPhone is Momo's home/primary world (§2); Watch is glanceable, emotional, seconds-fast (§2, §12); widgets are living windows, not dashboards (§13–14). IA is deliberately small: Home / Collection / World(Room) / Settings (§10). Onboarding is extremely short (§11). Permissions are requested contextually, never as an onboarding wall (§6, §11, §25). 3-seconds-to-understand, 3-taps-to-happiness (§3).

## Requirements
Read `CLAUDE.md`, `project.md`, `docs/product/01-product-review.md`, `docs/product/02-mvp-prd.md`, then produce `docs/design/03-ux-architecture.md` containing:
1. Sitemap + screen inventory for Phase 1 only (every screen justified; screens without demonstrated product value are removed, per §10)
2. Navigation model (tab structure or equivalent; rationale)
3. Onboarding flow (meet → choose → name → meet friend → enter; ≤ 5 steps, zero permission walls)
4. Primary daily flow (wake/open → see Momo → react → quest → interact → bond moment → return)
5. iPhone interaction flows (tap/double-tap/long-press; feed; play; touch-specific reactions per §4)
6. Apple Watch flow (pet view, one quick interaction, today's quest, status; haptic rules per §12)
7. Widget/complication surfaces for Phase 1 (what is shown, what is NOT, refresh expectations)
8. Permission flow strategy (HealthKit, notifications: when asked, with what copy, what happens when denied — product must remain fully usable per §44)
9. Empty/failure/offline states for each surface
10. Accessibility intent per screen (Dynamic Type, VoiceOver labels, Reduce Motion, color-independent state per §20)
Use low-fidelity textual wireframes (structure/hierarchy lists) — no visual assets required in Phase 0.

## Files / Areas Likely Affected
- Creates `docs/design/03-ux-architecture.md`

## Dependencies
- TASK-003 (DONE required).

## Constraints
- Jupiter model, fresh agent, no commit by agent. Phase 1 only — no Phase 2+ surfaces (no HealthKit step quests in flows beyond quest *slots* the PRD defines, no complications beyond what PRD allows).

## Acceptance Criteria
- All 10 sections present; every Phase 1 screen from the PRD covered; permission-denied paths fully specified; flows respect 3-second/3-tap principles; accessibility intent present per screen.
- Review verdict ≥ APPROVED_WITH_MINOR_NOTES.

## Required Tests
- Not applicable (document). Independent review agent required.

## Review Requirements
- Fresh reviewer verifies: PRD coverage, phase discipline, permission-flow ethics (no guilt/no walls), watchflow glanceability, accessibility coverage. Record in `.claude/tasks/reviews/REVIEW-TASK-004.md`.

## Git Requirements
- Commit (orchestrator, post-approval): `docs(design): TASK-004 UX architecture for Phase 1`

## Status
TODO

## Implementation Notes
- (agent fills in)

## Reviewer Findings
- (orchestrator records)

## Completion Evidence
- (commit hash + push, by orchestrator)
