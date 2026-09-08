# Momo Project Status

Last Updated: 2026-09-08 15:20 UTC
Updated By: main orchestration agent

## Current Phase
Phase 0 — Product Definition (project.md §40, Steps 1–6).
**No production code is permitted yet.** Engineering begins only after Steps 1–6 are internally consistent (Step 7).

## Current Epic
EPIC-001 — Product Definition & Delivery Plan

## Overall Progress
6/7 tasks complete (TASK-001…006). Both TASK-006 owner decisions RESOLVED and applied (PRD amended). TASK-007 (final Phase 0 task) next.

## Completed Work
- TASK-001 — Repository & orchestration bootstrap (commit `557c936`, pushed)
- TASK-002 — Step 1 Product Review (APPROVED_WITH_MINOR_NOTES; `f72b78b`, pushed; D1–D20 + E1–E4)
- TASK-003 — Step 2 MVP PRD (CHANGES_REQUIRED → fix → ALL_FIXES_VERIFIED → APPROVED; `c766ffe`, pushed; `docs/product/02-mvp-prd.md`)
- TASK-004 — Step 3 UX Architecture (APPROVED_WITH_MINOR_NOTES → 11 fixes → APPROVED; `40c4b77`, pushed; `docs/design/03-ux-architecture.md`)
- TASK-005 — Step 4 Character System (CHANGES_REQUIRED → fix → ALL_FIXES_VERIFIED → APPROVED; `ce84811`, pushed; `docs/design/04-character-system.md`)
- E2 — Character direction: owner picked **C "Round Rabbit"**; ADR-001 + 04 §1.4 gate box (`39d6bab` record fix, `2cfba30` E2 record, both pushed)
- TASK-006 — Step 5 Technical Architecture (CHANGES_REQUIRED → fix → ALL_FIXES_VERIFIED → APPROVED; `docs/architecture/05-technical-architecture.md` + ADR-002…007)

## Work In Progress
- None (between tasks). Owner decisions being surfaced, then TASK-007 spawns.

## Next Tasks
1. TASK-007 — Step 6 Delivery Plan (blocked by TASK-006 ✅ → READY once owner decisions are recorded or deferred)

## Blocked Tasks
- None. Owner escalations E1 (monetization), E3 (location), E4 (name) remain pending; none blocks Phase 0. **New batched owner decisions (non-blocking for the TASK-006 commit, resolved before/during TASK-007):** I-2/OPEN-5 nibble class; OPEN-1 §5.5 cascade fix.

## Recent Commits
- `557c936` — TASK-001 — chore(orchestration): bootstrap Momo agent team contracts and task structure
- `f72b78b` — TASK-002 — docs(product): step 1 product review of project spec
- `c766ffe` — TASK-003 — docs(product): TASK-003 MVP product requirements document
- `40c4b77` — TASK-004 — docs(design): TASK-004 UX architecture for Phase 1
- `ce84811` — TASK-005 — docs(design): TASK-005 character system specification
- `39d6bab` — housekeeping — TASK-005 record completion (rename in `ce84811` captured stale index-blob content)
- `2cfba30` — E2 record — Direction C gate resolution + ADR-001 + TASK-006 task file READY
- `8fb9653` — TASK-006 — docs(architecture): TASK-006 technical architecture and ADRs
- (this commit) — owner decisions OPEN-1 + I-2/OPEN-5 applied: PRD §5.5 rule 1 + FR-6/§4 amended; 05/ADR-004 flipped to owner-confirmed

## Recent Pushes
- main → origin — success (…, ce84811, 39d6bab, 2cfba30, 8fb9653)

## Architecture / Product Decisions
- Binding decision log: `docs/product/01-product-review.md` §6 (D1–D20).
- **ADR-001 (owner, E2): Character direction = C "Round Rabbit"** — `.claude/tasks/decisions/ADR-001-character-direction-round-rabbit.md`; 04 §1.3 deltas + ~11-part rig + ear-thickness rule now normative.
- **ADR-002–007 (TASK-006, all under `.claude/tasks/decisions/`):** plain Codable atomic file store over SwiftData (envelope+checksum, 3-generation recovery, additive-first migrations); WatchConnectivity-only sync (context latest-wins iPhone→Watch, FIFO journal Watch→iPhone, `sendMessage` = optimization only; dual idempotency guards scoped per `watchSessionEpoch` — re-pair/reinstall self-heals); pure event-driven engine `reduce(state, event, clock, rng)` with catch-up folding, no timers; satiety window 90 min (0–30 full / 30–90 recently-fed nibble ×0.25 — **nibble OWNER-CONFIRMED 2026-09-08, PRD FR-6/§4 amended**); module packaging = local SPM package `MomoCore`/`MomoCharacter`/`MomoKit` + app targets; deployment targets pinned at EPIC-002 bootstrap to current shipping OS generation, N-1 non-committed; SwiftUI-native rig ratified (ADR-007).
- **Owner decision 2026-09-08 (OPEN-1):** PRD §5.5 cascade rule 1 widened to Q6's full window ("≥ 20:00 ∨ < 07:00") — closes the 02:00-tuck-in gap; PRD amended, cascade + test aligned.
- PRD-normative numbers (`docs/product/02-mvp-prd.md`): Bond 0–1000 monotonic, stages 149/399/749, +8 hello / +4 quest / +6 variety / +20 day cap, touches bank zero; Mood bands 20/45/75 (attractor 60, floor 25, ceiling 92); Energy bands 20/45/75 (start 85, play −10, feed +6, nap +20); quests Q1–Q7, daily set = Q1 + 2 seeded, Q1 ≤ 12:00, Q6 20:00–07:00.
- **TASK-004 UX decisions (UX-1–UX-14, `docs/design/03-ux-architecture.md` §11.1):** 3 native tabs Home·Room·Settings (erase alert = only modal); bond = stage word + descriptor, NO within-stage meter (resolves PR8); play = fingertip-follow ≤ 30 s, 3-phase shell; quest card = per-wish soft marks, no aggregate bar; wish lines render inside windows (UX-5, reviewer-legitimated); Watch pat = daily hello, device-agnostic idempotent (UX-6); no sync-freshness indicator (UX-9); zero permissions Phase 1, Phase 2 contextual-ask strategy only; DisplayState read-model reserved for TASK-006.
- **TASK-004 review clarifications (binding on TASK-006):** hello and Q1 share a trigger but not a window — hello (+8) awarded once per local day whenever the first touch occurs (iPhone or Watch), Q1 ticks only before 12:00; the hello must never be window-gated. AC-1a budget assumes single-line wish rows at default Dynamic Type (wish copy is length-constrained; TASK-005 tone guide owns it).
- **TASK-005 character decisions (binding on TASK-006, `docs/design/04-character-system.md`):** tuck-in gate is CLOCK-based (20:00+) per FR-8 AC-1, not energy-band; VoiceOver spoken reaction lines = accessibility-only copy class `momo.line.react.<family>.<nn>` (+ `momo.line.moment.<nn>`); play effects apply at the single instant the round ceases (completion or preemption) via `handshakeCancelled(HandshakeKind)` / idempotent completion reports; play round = TASK-004's UX-3 fingertip-follow shell governs ("Drifting Pom" withdrawn to static room decor `momo.room.pom`); props = 4 (food, blanket, 2 sparkles); engine owns what/when (ResponsePlan per PRD §4 matrix), character owns how (durations per §7), presentation owns pause (single CharacterClock); day-stable idle seed = hash(petID, localDay, choreographyEpoch); rig = SwiftUI-native parametric vector rig (Lottie rejected), ~17-part transform-only rig, y=550 touch partition, 8 invariants INV-1..8; **NO Phase 1 audio** — FR-19 sound toggle omitted, Settings = rename, haptics, erase, About (within delegated authority per FR-19; reviewer concurred; revisit criteria in §11); tone guide §10 governs all copy (8 rules + banned list + 40 seeded lines, String Catalog `momo.line.<slot>.<nn>`).
- Orchestration: docs under `docs/{product,design,architecture}/`; ADRs under `.claude/tasks/decisions/`; direct-to-main during Phase 0; feature branches from EPIC-002; all agents Jupiter.

## Known Issues
- ~~Owner decision 1 (OPEN-1)~~ **RESOLVED:** owner approved the PRD §5.5 rule-1 fix ("≥ 20:00 ∨ < 07:00") — PRD amended 2026-09-08; cascade implements the amended rule.
- ~~Owner decision 2 (I-2/OPEN-5)~~ **RESOLVED:** owner accepted the nibble — PRD FR-6/§4 amended (0–30 min refusal / 30–90 min nibble ×0.25); 05 + ADR-004 updated to owner-confirmed.
- Xcode availability not yet verified (TR10) — must verify before EPIC-002 build work; bootstrap pins (OPEN-3) resolve there.
- 2026 fall OS churn: all API availability claims VERIFY-AT-BUILD, consolidated in 05 Appendix B.

## Test Status
- Phase 0: review gates only. REVIEW-TASK-002 = APPROVED_WITH_MINOR_NOTES. REVIEW-TASK-003 = APPROVED (after fix+verify). REVIEW-TASK-004 = APPROVED_WITH_MINOR_NOTES → fixes → APPROVED. REVIEW-TASK-005 = CHANGES_REQUIRED → fix → ALL_FIXES_VERIFIED → APPROVED. REVIEW-TASK-006 = CHANGES_REQUIRED → fix → ALL_FIXES_VERIFIED → APPROVED.

## Build Status
- Not applicable yet.

## Repository Status
- Branch: main
- Clean/Dirty: clean after this commit
- Remote sync: in sync with origin/main after push

## Important Context for Next Agent
- Read first: `CLAUDE.md`, `project.md`, `docs/product/01-product-review.md` (D1–D20 binding), `docs/product/02-mvp-prd.md` (normative), `docs/design/03-ux-architecture.md`, `docs/design/04-character-system.md`, `docs/architecture/05-technical-architecture.md` (+ ADR-001…007).
- Dependency chain: 001–006 ✅ → 007 (last Phase 0 task).
- Per-task cycle: fresh agent → implement (no commit) → fresh review agent → fix loop → commit → push → status update. Review records: `.claude/tasks/reviews/REVIEW-TASK-0XX.md`. Reviewer agents WRITE the full record to the review file and reply with only a confirmation (truncation workaround).
- **git mv gotcha:** `git mv` moves the index blob, NOT working-tree edits — always `git add` the moved file explicitly after any post-edit rename (cost a housekeeping commit for TASK-005).
- **TASK-007 intake:** produce the delivery plan converting the approved MVP into EPIC-002+ epics/stories with ACs, dependencies, implementation order, test requirements, release gates. Carry in: both owner decisions RESOLVED (PRD already amended — consume the amended PRD); EPIC-002 bootstrap obligations from ADR-006/OPEN-3 (deployment pins, device names, Xcode verify, import-whitelist scan); test-target structure from 05 §10; performance budgets from 05 §12 as release gates; ADR numbering continues at ADR-008+.
- Philosophy guardrail: Cute × Calm × Minimal × Alive × Premium. No punishment. MVP scope protection (§27–28).

## Exact Next Action
Commit + push the owner-decision amendments → update TASK-007 task file with intake (owner decisions resolved) → spawn fresh Jupiter agent (Step 6 Delivery Plan).
