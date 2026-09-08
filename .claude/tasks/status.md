# Momo Project Status

Last Updated: 2026-09-08 17:30 UTC
Updated By: main orchestration agent

## Current Phase
**Phase 1 — Step 7 Engineering** (project.md §40). EPIC-002 (Foundation & Build Baseline) executing on branch `feature/EPIC-002-foundation`.

## Current Epic
EPIC-002 — Foundation & Build Baseline (`.claude/tasks/epics/EPIC-002-foundation.md`) — **IN_PROGRESS (1/4 tasks DONE)**.

## Overall Progress
Phase 0 complete (TASK-001…007, all pushed). EPIC-002: **TASK-008 DONE** (`172bc11`, pushed) — toolchain verified, ADR-008 pins recorded; TASK-009/010/011 staged TODO. Then EPIC-003+ per delivery plan §3/§4.1 (backlog of record).

## Completed Work
- TASK-001 — Repository & orchestration bootstrap (`557c936`)
- TASK-002 — Step 1 Product Review, D1–D20 + E1–E4 (`f72b78b`)
- TASK-003 — Step 2 MVP PRD (`c766ffe`)
- TASK-004 — Step 3 UX Architecture (`40c4b77`)
- TASK-005 — Step 4 Character System (`ce84811`, record fix `39d6bab`)
- E2 — Character direction C "Round Rabbit" (ADR-001; `2cfba30`)
- TASK-006 — Step 5 Technical Architecture + ADR-002…007 (`8fb9653`)
- Owner decisions OPEN-1 (§5.5 cascade rule) + I-2/OPEN-5 (nibble) — PRD amended (`95e7649`)
- TASK-007 — Step 6 Delivery Plan (8 epics / 43 tasks) (`71a510b`)
- **TASK-008 — Toolchain verified + ADR-008 bootstrap pins (`172bc11`, first commit on `feature/EPIC-002-foundation`, pushed).** Review chain: REVIEW-TASK-008 CHANGES_REQUIRED (MAJOR-1: smallest-iPhone mis-pin) → fresh fixer re-pinned iPhone-small to **iPhone SE (3rd generation)** → REVIEW-TASK-008-VERIFY: FIXED — CLEARED FOR COMMIT (three independent probe pairs agree).

## Work In Progress
- None (between tasks).

## Next Tasks
1. **TASK-009 — SPM package (MomoCore/MomoCharacter/MomoKit) + Momo/MomoWatch app targets + placeholder shells** — next to dispatch (task file staged in `.claude/tasks/active/`); consumes ADR-008 pins directly.
2. TASK-010 — Test-target scaffolding + import-whitelist + banned-vocabulary harness (after 009).
3. TASK-011 — Design-token pass + `momo.line.*` String Catalog scaffolding (after 009).

## Blocked Tasks
- None. Owner gates pending but non-blocking: E1 (monetization) and E3 (location) closed for Phase 1 (D8/D19); E4 (name/trademark clearance) scheduled as TASK-050 release gate.

## Recent Commits
- `172bc11` — TASK-008 — chore(bootstrap): verify toolchain and record deployment pins (ADR-008) — **first commit on `feature/EPIC-002-foundation`**
- `71a510b` — TASK-007 — docs(product): TASK-007 delivery plan with Phase 1 epics and task breakdown
- `95e7649` — owner decisions — OPEN-1 §5.5 rule-1 + I-2/OPEN-5 nibble applied (PRD amended)
- `8fb9653` — TASK-006 — docs(architecture): TASK-006 technical architecture and ADRs
- `2cfba30` — E2 record — Direction C gate resolution + ADR-001 + TASK-006 task file READY
- `39d6bab` — housekeeping — TASK-005 record completion
- `ce84811` — TASK-005 — docs(design): TASK-005 character system specification
- `40c4b77` — TASK-004 — docs(design): TASK-004 UX architecture for Phase 1
- `c766ffe` — TASK-003 — docs(product): TASK-003 MVP product requirements document
- `f72b78b` — TASK-002 — docs(product): step 1 product review of project spec
- `557c936` — TASK-001 — chore(orchestration): bootstrap Momo agent team contracts and task structure

## Recent Pushes
- `feature/EPIC-002-foundation` → origin — **success** (new branch, `172bc11`, tracking set; `* [new branch] feature/EPIC-002-foundation -> feature/EPIC-002-foundation`)
- main → origin — success (`95e7649..71a510b main -> main`)

## Architecture / Product Decisions
- Binding decision log: `docs/product/01-product-review.md` §6 (D1–D20).
- **ADR-001 (owner, E2):** Direction C "Round Rabbit" — ~11-part rig, ear-thickness rule, posture-led expression.
- **ADR-002–007 (TASK-006):** Codable atomic file store (envelope+checksum, 3-gen recovery, additive migrations); WatchConnectivity-only sync (context latest-wins ↓, FIFO journal ↑, dual idempotency guards scoped per `watchSessionEpoch`); pure event-driven engine `reduce(state, event, clock, rng)`, no timers; 90-min satiety window (0–30 refusal / 30–90 nibble ×0.25 owner-confirmed); SPM packaging MomoCore/MomoCharacter/MomoKit + app targets; SwiftUI-native rig (ADR-007); deployment-target policy (ADR-006, now **ACCEPTED** — status line reconciled during TASK-008's review loop).
- **ADR-008 (TASK-008, bootstrap pins — ACCEPTED):** min **iOS 26.0 / watchOS 26.0** (generation floor per ADR-006; build SDKs 26.5); pairing = both floors ≥ 26.0, current-generation floor; device matrix — iPhone small **iPhone SE (3rd generation)** 750×1334 px (375×667 pt, governs FR-2 AC-1a no-scroll), mid iPhone 17, large iPhone 17 Pro Max; Watch small Apple Watch SE 3 (40mm) 324×394 px (governs ADR-001 ~32 pt glyph; SE 2nd gen 40mm confirmed same geometry), flagship Series 11 (46mm), Ultra 3 optional upper bound; **Swift Testing** + XCUITest; N-1 widening deferred to TASK-050. Current-generation-hardware-only exclusion recorded as an owner lever (§36), **not taken**.
- **Owner decisions 2026-09-08:** OPEN-1 — §5.5 cascade rule 1 = "(local time ≥ 20:00 or local time < 07:00)"; I-2/OPEN-5 — nibble class normative (PRD FR-6/§4 amended).
- **TASK-007 delivery plan (`docs/product/06-delivery-plan.md`, normative for execution):** Phase 1 = EPIC-002 foundation → 003 domain model → 004 engine → 005 persistence/sync logic → 006 character rendering → 007 iPhone home → 008 watch & sync → 009 polish/QA/release. Slice spine 008→009→012→014→016→017→019→021→031→033→034→040→041(+042) = project.md §40 Step 7; slice completes at end of EPIC-008. Parallel lanes: LANE A (EPIC-005 from 012/014), LANE B (EPIC-006 from 009+011). Coverage floors Core ≥ 90 % / Kit ≥ 80 %; 05 §12 budgets are release blockers (measured on iPhone SE (3rd gen) / Watch SE 3 40mm at TASK-045); NFR-6 accessibility audit launch-blocking. Feature branches per epic from EPIC-002 (`feature/EPIC-00X-slug`); ADR numbering continues at ADR-009+. §3 task tables are the backlog of record — task files created just-in-time per batch.
- PRD-normative numbers: Bond 0–1000 monotonic, stages 149/399/749, +8/+4/+6/+20 cap; Mood bands 20/45/75 (attractor 60, floor 25, ceiling 92); Energy bands 20/45/75; quests Q1–Q7, daily set = Q1 + 2 seeded, Q1 < 12:00, Q6 20:00–07:00.
- Orchestration: docs under `docs/{product,design,architecture}/`; ADRs under `.claude/tasks/decisions/` (ADR-001…008 present); **feature branches from EPIC-002 onward**; all agents Jupiter.

## Known Issues
- ~~TR10 "Xcode availability never verified"~~ **RETIRED AS VERIFIED** (`172bc11`; ADR-008 Consequences; risk R1 mitigated).
- 2026 fall OS churn: all API availability claims VERIFY-AT-BUILD; register in 05 Appendix B, every item has exactly one owning task (009/010, 014, 025, 040/044, 045, 048).
- R9: paired Watch hardware needed for WC delivery obligations (TASK-044) — simulators carry development; device session is the explicit deliverable.
- `.gitignore` is minimal (`.DS_Store` only) — TASK-009 adds the Swift/Xcode entries as part of the build baseline.

## Test Status
- Phase 0: review gates — all six REVIEW records final (002–007 APPROVED).
- TASK-008: verification-as-evidence complete; **three independent probe pairs agree** (reviewer / fixer / verifier: iPhone SE 3rd gen 750×1334 px, Watch SE 2 40mm 324×394 px); Swift Testing probe reproduced exactly.

## Build Status
- Toolchain verified: Xcode 26.6 (17F113), iOS 26.5 + watchOS 26.5 runtimes, `xcodebuild -checkFirstLaunchStatus` clean. First build baseline (`swift test` green + shells launch) lands with TASK-009.

## Repository Status
- Branch: `feature/EPIC-002-foundation` @ `172bc11` (pushed); main @ `71a510b` (pushed).
- Clean/Dirty: dirty → clean after this housekeeping commit (status.md + EPIC-002 status line).
- Uncommitted files: none after this commit.
- Remote sync: epic branch tracking origin, in sync after this push.

## Important Context for Next Agent
- Read first: `CLAUDE.md`, `project.md`, `docs/product/06-delivery-plan.md` (§3 tables = backlog of record), then doc chain 01→02 (amended)→03→04→05 + ADR-001…008.
- Per-task cycle: fresh Jupiter agent → implement (no commit) → fresh adversarial reviewer (writes review file, replies confirmation-only) → fix loop (fresh fixer + fresh verifier when material) → atomic commit with TASK-ID → push → status update. Agents inherit Jupiter by omitting the model override (an explicit `fable` override fails in this environment — discovered 2026-09-08).
- **git mv gotcha:** `git mv` moves the index blob, NOT working-tree edits — always `git add` the moved file explicitly after any post-edit rename.
- "(this commit)" convention: task files record `(this commit)` in Completion Evidence; the real hash lands in status.md's Recent Commits via the housekeeping commit (see `39d6bab`/`1746a98` precedent).
- Branch model: each epic on `feature/EPIC-00X-slug` cut from `main`; one atomic commit per task, pushed after each task; epic merges to `main` at DoD (delivery plan §1.5, §6.1). EPIC-002's branch now exists with TASK-008 as its first commit.
- TASK-009 consumes ADR-008 verbatim: min iOS 26.0 / watchOS 26.0, SDKs 26.5, five matrix devices (SE 3rd gen / 17 / 17 Pro Max; Watch SE 3 40mm / Series 11 46mm; Ultra 3 optional) for simulator runs; import-whitelist wiring stays TASK-010's.
- Coverage floors (Core 90 %, Kit 80 %) recorded per task, enforced by TASK-020/024.
- Philosophy guardrail: Cute × Calm × Minimal × Alive × Premium. No punishment. MVP scope protection (§22/§24); scope-creep proposals route to KEEP/LATER/REJECT with the orchestrator (plan R10).

## Exact Next Action
Spawn a fresh Jupiter implementation agent for **TASK-009** (SPM package MomoCore/MomoCharacter/MomoKit + Momo/MomoWatch app targets + placeholder shells) on `feature/EPIC-002-foundation` → fresh adversarial reviewer → commit `feat(build): TASK-009 ...` → push → status update.
