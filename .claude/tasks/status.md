# Momo Project Status

Last Updated: 2026-09-08 12:05 UTC
Updated By: main orchestration agent

## Current Phase
Phase 0 — Product Definition (project.md §40, Steps 1–6).
**No production code is permitted yet.** Engineering begins only after Steps 1–6 are internally consistent (Step 7).

## Current Epic
EPIC-001 — Product Definition & Delivery Plan

## Overall Progress
5/7 tasks complete (TASK-001…005). Next: TASK-006 → TASK-007.

## Completed Work
- TASK-001 — Repository & orchestration bootstrap (commit `557c936`, pushed)
- TASK-002 — Step 1 Product Review (APPROVED_WITH_MINOR_NOTES; `f72b78b`, pushed; D1–D20 + E1–E4)
- TASK-003 — Step 2 MVP PRD (CHANGES_REQUIRED → fix → ALL_FIXES_VERIFIED → APPROVED; `c766ffe`, pushed; `docs/product/02-mvp-prd.md`)
- TASK-004 — Step 3 UX Architecture (APPROVED_WITH_MINOR_NOTES → 11 fixes → APPROVED; `40c4b77`, pushed; `docs/design/03-ux-architecture.md`)
- TASK-005 — Step 4 Character System (CHANGES_REQUIRED → fix → ALL_FIXES_VERIFIED → APPROVED; `docs/design/04-character-system.md`; E2 gate intact — owner pick A/B/C still pending)

## Work In Progress
- None (between tasks). E2 owner pick being surfaced before TASK-006 spawns.

## Next Tasks
1. TASK-006 — Step 5 Technical Architecture + ADRs (blocked by TASK-004 ✅ + TASK-005 ✅ → READY)
2. TASK-007 — Step 6 Delivery Plan (blocked by TASK-006)

## Blocked Tasks
- None. Owner escalations E1–E4 pending; none blocks Phase 0 execution. E2 pick (character direction A/B/C) is the one open product-defining decision — §2–9 of the character doc are direction-agnostic, so TASK-006 can start regardless; the pick should land before EPIC-002 asset work.

## Recent Commits
- `557c936` — TASK-001 — chore(orchestration): bootstrap Momo agent team contracts and task structure
- `f72b78b` — TASK-002 — docs(product): step 1 product review of project spec
- `c766ffe` — TASK-003 — docs(product): TASK-003 MVP product requirements document
- `40c4b77` — TASK-004 — docs(design): TASK-004 UX architecture for Phase 1
- (this commit) TASK-005 — docs(design): TASK-005 character system specification

## Recent Pushes
- main → origin — success (557c936, f72b78b, c766ffe, 40c4b77)

## Architecture / Product Decisions
- Binding decision log: `docs/product/01-product-review.md` §6 (D1–D20).
- PRD-normative numbers (`docs/product/02-mvp-prd.md`): Bond 0–1000 monotonic, stages 149/399/749, +8 hello / +4 quest / +6 variety / +20 day cap, touches bank zero; Mood bands 20/45/75 (attractor 60, floor 25, ceiling 92); Energy bands 20/45/75 (start 85, play −10, feed +6, nap +20); quests Q1–Q7, daily set = Q1 + 2 seeded, Q1 ≤ 12:00, Q6 20:00–07:00.
- **TASK-004 UX decisions (UX-1–UX-14, `docs/design/03-ux-architecture.md` §11.1):** 3 native tabs Home·Room·Settings (erase alert = only modal); bond = stage word + descriptor, NO within-stage meter (resolves PR8); play = fingertip-follow ≤ 30 s, 3-phase shell; quest card = per-wish soft marks, no aggregate bar; wish lines render inside windows (UX-5, reviewer-legitimated); Watch pat = daily hello, device-agnostic idempotent (UX-6); no sync-freshness indicator (UX-9); zero permissions Phase 1, Phase 2 contextual-ask strategy only; DisplayState read-model reserved for TASK-006.
- **TASK-004 review clarifications (binding on TASK-006):** hello and Q1 share a trigger but not a window — hello (+8) awarded once per local day whenever the first touch occurs (iPhone or Watch), Q1 ticks only before 12:00; the hello must never be window-gated. AC-1a budget assumes single-line wish rows at default Dynamic Type (wish copy is length-constrained; TASK-005 tone guide owns it).
- **TASK-005 character decisions (binding on TASK-006, `docs/design/04-character-system.md`):** tuck-in gate is CLOCK-based (20:00+) per FR-8 AC-1, not energy-band; VoiceOver spoken reaction lines = accessibility-only copy class `momo.line.react.<family>.<nn>` (+ `momo.line.moment.<nn>`); play effects apply at the single instant the round ceases (completion or preemption) via `handshakeCancelled(HandshakeKind)` / idempotent completion reports; play round = TASK-004's UX-3 fingertip-follow shell governs ("Drifting Pom" withdrawn to static room decor `momo.room.pom`); props = 4 (food, blanket, 2 sparkles); engine owns what/when (ResponsePlan per PRD §4 matrix), character owns how (durations per §7), presentation owns pause (single CharacterClock); day-stable idle seed = hash(petID, localDay, choreographyEpoch); rig = SwiftUI-native parametric vector rig (Lottie rejected), ~17-part transform-only rig, y=550 touch partition, 8 invariants INV-1..8; **NO Phase 1 audio** — FR-19 sound toggle omitted, Settings = rename, haptics, erase, About (within delegated authority per FR-19; reviewer concurred; revisit criteria in §11); tone guide §10 governs all copy (8 rules + banned list + 40 seeded lines, String Catalog `momo.line.<slot>.<nn>`).
- Orchestration: docs under `docs/{product,design,architecture}/`; ADRs under `.claude/tasks/decisions/`; direct-to-main during Phase 0; feature branches from EPIC-002; all agents Jupiter.

## Known Issues
- **PRD §5.5 cascade rule 1 gap (TASK-006 intake, found by TASK-004 reviewer):** rule 1's "local time ≥ 20:00" misses Q6's 00:00–07:00 tail when Q1 is already complete (e.g., 02:00 tuck-in with Q1 done). The UX doc inherits the cascade's output without error; TASK-006 implementing the cascade must flag it to the PRD owner (one-line PRD fix candidate).
- **OBS-1 (TASK-005 verifier, non-blocking):** 03-ux-architecture.md:428's VoiceOver template hard-codes "…and has {energy phrase}." while 04 §3.5's binding formula uses a verb-phrase slot — FR-20 audit string agrees verbatim in all three docs (the actual AC); one clause in 04 §3.5 closes it if TASK-006 wants belt-and-braces.
- **OBS-2 (TASK-005 verifier, non-blocking):** tone rule 2's 12-word max vs. M2 banner template (~13 words) — TASK-006 copy pass should exempt the banner explicitly or scope rule 2 to visual lines.
- Xcode availability not yet verified (TR10) — must verify before EPIC-002 build work.
- 2026 fall OS churn: all API availability claims VERIFY-AT-BUILD (TASK-006 ADRs).

## Test Status
- Phase 0: review gates only. REVIEW-TASK-002 = APPROVED_WITH_MINOR_NOTES. REVIEW-TASK-003 = APPROVED (after fix+verify). REVIEW-TASK-004 = APPROVED_WITH_MINOR_NOTES → fixes → APPROVED. REVIEW-TASK-005 = CHANGES_REQUIRED → fix → ALL_FIXES_VERIFIED → APPROVED.

## Build Status
- Not applicable yet.

## Repository Status
- Branch: main
- Clean/Dirty: clean after this commit
- Remote sync: in sync with origin/main after push

## Important Context for Next Agent
- Read first: `CLAUDE.md`, `project.md`, `docs/product/01-product-review.md` (D1–D20 binding), `docs/product/02-mvp-prd.md` (normative), `docs/design/03-ux-architecture.md` (UX contract), `docs/design/04-character-system.md` (character contract).
- Dependency chain: 001–005 ✅ → 006 → 007.
- Per-task cycle: fresh agent → implement (no commit) → fresh review agent → fix loop → commit → push → status update. Review records: `.claude/tasks/reviews/REVIEW-TASK-0XX.md`. Reviewer agents should WRITE their full review record directly to the review file and reply with only a confirmation (message truncation workaround, established pattern).
- **TASK-006 intake obligations accumulated:** DisplayState read-model (UX §7); FR-2 AC-1a device matrix (UX §5.1 budget); hello idempotency + hello/Q1 window split (UX §11.3); haptics sync to Watch (UX-13 reduced to haptics per TASK-005); Watch snapshot restore ≤ ~2 s (protects FR-17 ≤ 5 s); invisible corruption-recovery cadence (FR-13 AC-2); from TASK-005 §9 — ResponsePlan per PRD §4 matrix, satiety window value, settle/wake/play handshakes (idempotent completion + `handshakeCancelled` cancellation reports), backgrounding-mid-play rule (§9.6 item 4 = effects at the instant the round ceases), single CharacterClock pause authority, day-stable idle seed hash(petID, localDay, choreographyEpoch), copy-class namespace + M2/M3 surfaces, VoiceOver formula binding (04 §3.5 governs wording — OBS-1), banner length exemption (OBS-2); PRD §5.5 cascade rule-1 Q6-tail fix (flag to owner).
- E2 pick pending (A Loaf Cat / B Mochi Spirit / C Round Rabbit — C recommended in 04 §1.4). §2–9 direction-agnostic; TASK-006 may start before the pick, but the pick must be recorded in the decision log before EPIC-002.
- Philosophy guardrail: Cute × Calm × Minimal × Alive × Premium. No punishment. MVP scope protection (§27–28).

## Exact Next Action
Surface E2 character pick to the owner (A/B/C, C recommended) → record decision → create TASK-006 task file → spawn fresh Jupiter agent (Step 5 Technical Architecture + ADRs).
