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
DONE

## Implementation Notes
- (agent fills in)
- 2026-09-08 — Executing agent produced `docs/design/03-ux-architecture.md` (all 10 required sections; character-agnostic "pet canvas" throughout; no code, no commits).
  - **Sitemap/inventory:** 10 surfaces total — S1–S3 onboarding (Meet/Name/Enter), S4 Home, S5 Room, S6 Settings (+S6.1 rename, S6.2 erase alert), W1 Watch pet glance; 3 transient in-scene moments (M1 quest tick, M2 bond stage, M3 all-done). Explicit rejected-surfaces list (Collection, quest detail, stats page, widget screens, Watch settings, pet picker, shop).
  - **Navigation (UX-1):** 3 native tabs — Home · Room · Settings; flat IA; the erase-all alert is the product's only modal; no badges/dots/counters anywhere.
  - **Key UX calls:** UX-2 bond = stage word + descriptor, NO within-stage meter anywhere (resolves PR8 in calmest direction; revisit gate = post-launch feedback). UX-3 play = character-agnostic fingertip-follow round (≤30 s, participation optional, no score). UX-4 quest card = per-wish soft marks, no aggregate fraction/bar. UX-9 Watch shows no sync-freshness indicator by design. UX-14 eye-follow off under Reduce Motion.
  - **Interpretation flags for reviewer (§11.2):** FR-2 "3 wishes + progress" vs Q6's 20:00 window → wish lines render inside their windows (UX-5; morning of a Q6-day shows 2 lines); Watch pat counts as the daily hello (device-agnostic, idempotent — TASK-006 engine obligation); D18 vs contextual care chips reconciled via §4 matrix offering gates; FR-8 "absent" chosen over "visibly not offered" (no disabled ghosts).
  - **Permission strategy (§8):** Phase 1 = zero permission requests on either device, enumerated never-asked list; Phase 2 HealthKit/notifications recorded as contextual-ask strategy only (value-first → system dialog → graceful decline → never re-nag), no designed screens.
  - **Widget reservation (§7):** no Phase 2 design; single DisplayState read-model recommended to TASK-006 as the one derivation behind Home/W1/future widgets.
  - **Handoff (§11.3):** TASK-005 — touch-zone geometry, play-round motion art, audio scope (decides Settings sound toggle), tone guide. TASK-006 — DisplayState read-model, AC-1a device matrix, hello idempotency across devices, haptics/sound toggle sync semantics, Watch snapshot restore ≤ ~2 s (protects FR-17 AC-1 ≤ 5 s pat), silent corruption-recovery contract.
  - All copy suggestions pass FR-12 tone guardrails; quests are wish-framed with auto-complete, silent expiry, no modals; corruption recovery is invisible; full per-screen accessibility intent in §10 (Dynamic Type AC-1a/1b split, pet-state-in-words VoiceOver template, Reduce Motion, color-independence, 44 pt / 4.5:1).
  - Independent review: APPROVED_WITH_MINOR_NOTES; 11 findings (5 MINOR + 6 NITPICK) fixed by orchestrator — see Reviewer Findings + REVIEW-TASK-004.md Disposition.

## Reviewer Findings
- Independent review (`task-004-reviewer`, fresh, unprimed, adversarial): **APPROVED_WITH_MINOR_NOTES** — 0 CRITICAL/MAJOR, 5 MINOR + 6 NITPICK. All D1–D20 compliance checks PASS; all five §11.2 interpretation flags judged LEGITIMATE (UX-5 "arguably the only PRD-consistent reading"); FR-12 tone audit PASS; all 10 required sections verified; FR-2 AC-1a arithmetic verified (~541/598 pt on SE-class). Full record: `.claude/tasks/reviews/REVIEW-TASK-004.md`.
- Disposition: all 11 findings applied by the orchestrator as mechanical one-line edits (no MAJOR ⇒ no separate fix agent per §11); disposition table in the review record. Final: APPROVED.

## Completion Evidence
- Deliverable: `docs/design/03-ux-architecture.md` (10 sections; S1–S3/S4–S6/W1 + M1–M3; UX-1–UX-14 decision log; zero-permission Phase 1 strategy; per-screen accessibility intent; DisplayState reservation to TASK-006)
- Review loop: APPROVED_WITH_MINOR_NOTES → 11 mechanical fixes applied → APPROVED (`.claude/tasks/reviews/REVIEW-TASK-004.md`)
- Commit/push: hash recorded in `.claude/tasks/status.md` Recent Commits
- Handoffs live: §11.3 → TASK-005 (zone registers, play shell, tone guide, audio scope) and TASK-006 (DisplayState, device matrix, hello/Q1 window split, haptics/sound sync, Watch snapshot ≤ 2 s, corruption cadence)
