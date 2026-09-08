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
- TASK-006 ✅ DONE (`8fb9653` + owner amendments `95e7649`). E2 RESOLVED: **Direction C — Round Rabbit** (ADR-001). Both owner decisions from the TASK-006 review RESOLVED — **consume the AMENDED PRD**: §5.5 rule 1 is "(local time ≥ 20:00 or local time < 07:00)"; FR-6/§4 carry the 30–90-min nibble (×0.25) as normative.

## Intake Obligations (binding, accumulated from TASK-004…006)
- First vertical slice (project.md §40 Step 7) is the ordering spine: Launch → Momo visible → idle animation → touch → react → state change → persist → Watch receives state.
- Architecture-derived task structure: local SPM package `MomoCore`/`MomoCharacter`/`MomoKit` + `Momo`/`MomoWatch` app targets (ADR-005); test targets + coverage floors from 05 §10 (headless-first, `swift test` on macOS for Core); persistence = Codable atomic store (ADR-002); sync = WatchConnectivity dual epoch-scoped guards (ADR-003); engine = pure event-driven `reduce` (ADR-004).
- **EPIC-002 bootstrap task must include:** Xcode availability verification (TR10/OPEN-3), deployment-target pins per ADR-006, device names, import-whitelist scan wiring (05 §10.2). All VERIFY-AT-BUILD items from 05 Appendix B resolve at build time — plan tasks so each has an owner.
- Character tasks derive from 04 as amended: ~11-part Direction-C rig, SwiftUI-native parametric vector rig via build-time script, ear-thickness rule, copy classes (`momo.line.*`), tone guide §10 governs all user-visible strings.
- Performance budgets from 05 §12 are release gates (launch ≤ 2.0 s, 60 fps, memory caps, restore ≤ ~2 s); accessibility audit is launch-blocking (NFR-6).
- Every task traces to PRD FRs/NFRs and architecture sections; Phase 1 only; ADR numbering continues at ADR-008+.

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
DONE (implemented, reviewed APPROVED_WITH_MINOR_NOTES, findings fixed, committed, pushed — 2026-09-08)

## Reviewer Findings
- **REVIEW-TASK-007** (fresh adversarial reviewer, 2026-09-08): **APPROVED_WITH_MINOR_NOTES** — 0 MAJOR / 2 MINOR / 3 NITPICK. Full record + orchestrator disposition in `.claude/tasks/reviews/REVIEW-TASK-007.md`.
- Reviewer independently rebuilt FR/NFR traceability (all 20 FRs + 9 NFRs owned), verified 43-task arithmetic, graph acyclicity, spine validity vs project.md §40 Step 7, phase discipline (zero Phase-2 leakage), epic-file §7 completeness, first-batch self-sufficiency, amended-normative-number fidelity (no stale values), philosophy guardrails, test mapping/coverage floors, risk register ownership, and process compliance (no commits, no status.md edits).
- Findings: MINOR-1 (§4.1 graph over-constrained EPIC-007/009 vs the backlog tables), MINOR-2 (miscitation "05 §25" ×3), NITPICK-1 (FR-2 AC-2 3-tap rule unnamed in TASK-033 row), NITPICK-2 (M1 flourish/haptic detail absent from TASK-036 row), NITPICK-3 (TASK-008 lacks cross-ref that TASK-010 owns import-whitelist wiring).
- All five fixed mechanically pre-commit by the orchestrator (see disposition table in the review file); no plan substance changed. **Final: APPROVED.**

## Implementation Notes
- **Agent:** fresh Jupiter implementation agent, 2026-09-08. All Phase 0 documents re-read (incl. amended PRD) before writing; no code exists in the repo yet, so EPIC-002 starts from a bare repo.
- **Deliverable A — `docs/product/06-delivery-plan.md`:** method (vertical slices, granularity per CLAUDE.md §32, domain-before-UI, branch model, size legend, no-punishment/FR-12 guardrails, VERIFY-AT-BUILD ownership rule); §2 epic overview; §3 full task tables per epic (the backlog of record — later task files are created just-in-time by the orchestrator); §4 dependency graph + first-vertical-slice spine + parallel lanes (EPIC-005 LANE A from TASK-012/014; EPIC-006 LANE B from TASK-009+011) + sequencing rationale; §5 per-epic test mappings to project.md §32 matrices / 05 §10 with coverage floors (Core 90 %, Kit 80 %); §6 release gates (per-epic DoD + final gates incl. 05 §12 budgets, NFR-6 launch-blocking audit, FR-20 privacy audits, §44 checklist, E4, N-1); §7 risk register R1–R13 (incl. TR10, TR1, battery, tone drift, device availability, scope creep) each with an owning task; §8 Phase 2+ reservations (no tasks); §9 open items; Appendix A FR→task traceability (FR-1…20 all covered); Appendix B NFR→task traceability (NFR-1…9 all covered).
- **Epic list (8 epics, 43 tasks, TASK-008…050):** EPIC-002 Foundation & Build Baseline (4) → EPIC-003 Pet Domain Model (2) → EPIC-004 Pet State Engine (7) → EPIC-005 Persistence & Sync Logic (4) → EPIC-006 Character Rendering (6) → EPIC-007 iPhone Home Experience (9) → EPIC-008 Watch App & Sync (5) → EPIC-009 Polish/QA/Release Readiness (6). Engine split follows CLAUDE.md §32's own example (model / engine / tests separate tasks); each engine task additionally carries focused in-task unit tests, with TASK-020 as the §10.3-matrix + property-test + coverage-floor hardening task.
- **Slice order (spine):** 008 → 009 → 012 → 014 → 016 → 017 → 019 → 021 → 031 → 033 → 034 → 040 → 041 (+042) maps 1:1 to Launch → Momo visible → idle → touch → react → state change → persist → Watch receives state (project.md §40 Step 7). Slice completes at end of EPIC-008; each epic ends on a demonstrable increment (table in plan §2).
- **Deliverable B:** 8 epic files materialized under `.claude/tasks/epics/` (EPIC-002-foundation … EPIC-009-polish-qa-release), each per the CLAUDE.md §7 template, Status TODO.
- **Deliverable C:** first executable batch only — TASK-008 (toolchain verify + deployment pins/device matrix/framework pin → ADR-008; **READY**), TASK-009 (SPM package + app targets + placeholder shells; TODO), TASK-010 (test targets + import-whitelist + banned-vocabulary harness with fixture self-tests; TODO), TASK-011 (single design-token pass + `momo.line.*` String Catalog scaffolding; TODO). Branch `feature/EPIC-002-foundation` encoded in each Git Requirements.
- **OPEN items fenced (plan §9):** OPEN-3 → TASK-008/ADR-008; OPEN-2 (interpretation I-1) treated as confirmed by REVIEW-TASK-006's APPROVED, asserted by TASK-016 tests; VERIFY-AT-BUILD register distributed with exactly one owner each (008, 009/010, 014, 025, 040/044, 045, 048); E4 → TASK-050 release gate; E1/E3 closed for Phase 1 (D8/D19). Xcode-project authoring tooling (XcodeGen-preferred, hand-authored fallback) deliberately delegated to TASK-009 as a reversible build-tooling choice, recorded in its notes.
- **Decisions made within delegated authority:** tokens homed in `MomoCharacter` (both apps import it; R4 enforced at the token file); project-generation tooling guidance (not a product dependency); 04 §9.2 interface types defined in TASK-012 so the character lane can parallel the engine lane. Nothing in the PRD/ADRs was re-decided.
- **Not done (by design):** no commits (orchestrator owns commit/push); no `status.md` edits; Reviewer Findings / Completion Evidence left for the orchestrator and reviewer.

## Reviewer Findings
- (orchestrator records)

## Completion Evidence
- Commit: `(this commit)` — the atomic task commit `docs(product): TASK-007 delivery plan with Phase 1 epics and task breakdown` (hash recorded explicitly in `.claude/tasks/status.md` Recent Commits at the next rewrite).
- Push: main → origin (orchestrator verifies and records success/failure in status.md immediately after push).
- Contains: `docs/product/06-delivery-plan.md` (new); `.claude/tasks/epics/EPIC-002…009-*.md` (8 new); `.claude/tasks/active/TASK-008…011-*.md` (4 new); REVIEW-TASK-007.md + disposition (new); this task file (record complete); EPIC-001 status → COMPLETE; status.md rewrite.
- Acceptance criteria: met — plan covers all Phase 1 epics at §32 granularity with dependency-ordered tasks; first vertical slice is the earliest build path; every epic has ACs + test requirements + release gates; EPIC-002+ materialized; first batch self-sufficient (reviewer-verified); review verdict ≥ APPROVED_WITH_MINOR_NOTES.

## Handoff

### Completed
- Step 6 Delivery Plan: 8 epics (TASK-008…050, 43 tasks), dependency graph + slice spine, §32 test mappings (floors Core 90 % / Kit 80 %), release gates, risks R1–R13, Phase 2+ reservations, FR/NFR traceability appendices; 8 epic files; first-batch task files TASK-008 (READY) + 009/010/011 (TODO); independent review passed with all findings resolved.

### Files Changed
- New: `docs/product/06-delivery-plan.md`; `.claude/tasks/epics/EPIC-002…009-*.md` (8); `.claude/tasks/active/TASK-008…011-*.md` (4); `.claude/tasks/reviews/REVIEW-TASK-007.md`.
- Updated: this task file (Status/Reviewer Findings/Completion Evidence/Handoff); `.claude/tasks/epics/EPIC-001-product-definition.md` (→ COMPLETE); `.claude/tasks/status.md` (Phase 0 close-out).

### Tests Run
- Not applicable (documentation task) — independent adversarial review per CLAUDE.md §10 is the gate; 12 review dimensions verified clean (see REVIEW-TASK-007 Clean Dimensions).

### Test Results
- REVIEW-TASK-007: APPROVED_WITH_MINOR_NOTES → fixes applied → APPROVED.

### Known Issues
- None blocking. E1/E3/E4 remain owner-gated as planned (E4 → TASK-050 gate); TR10 resolves at TASK-008.

### Decisions Made
- Xcode-project authoring tooling (XcodeGen-preferred) delegated to TASK-009 as reversible build tooling; tokens homed in `MomoCharacter`; 04 §9.2 interface types defined in TASK-012 so the character lane parallels the engine lane — all within delegated authority, nothing PRD/ADR-level re-decided.

### Reviewer Status
- APPROVED (after APPROVED_WITH_MINOR_NOTES + mechanical fixes; disposition recorded).

### Commit
- `docs(product): TASK-007 delivery plan with Phase 1 epics and task breakdown` (this commit).

### Push
- Orchestrator pushes immediately post-commit; result recorded in status.md.

### Recommended Next Step
- Phase 0 (project.md §40 Steps 1–6) is COMPLETE → begin Step 7 engineering with EPIC-002: spawn the fresh TASK-008 agent on branch `feature/EPIC-002-foundation` (verify toolchain, pin deployment targets/device names/framework → ADR-008).
