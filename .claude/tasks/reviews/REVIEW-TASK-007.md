# REVIEW-TASK-007 — Independent Adversarial Review of TASK-007 (Step 6: Delivery Plan)

- **Task:** TASK-007 — Step 6: Delivery Plan (EPIC-001)
- **Date:** 2026-09-08
- **Reviewer:** Independent fresh adversarial review agent (Jupiter). Not the implementation agent; did not modify any artifact under review; made no commits.
- **Artifacts reviewed:** `docs/product/06-delivery-plan.md`; `.claude/tasks/epics/EPIC-002…009` (8 files); first-batch `.claude/tasks/active/TASK-008…011`; side-effects on `EPIC-001-product-definition.md`; ground truth = `CLAUDE.md`, `project.md`, `docs/product/01…02`, `docs/design/03…04`, `docs/architecture/05`, `.claude/tasks/decisions/ADR-001…007`, `.claude/tasks/reviews/REVIEW-TASK-006.md`, git history.

## Review Method

I attempted to disprove every completion claim independently:

1. **Rebuilt FR/NFR traceability from scratch** from `02-mvp-prd.md` (FR-1…20, NFR-1…9, with all TASK-006 owner amendments) and cross-checked against plan Appendix A/B and the §3 task tables — not trusting the plan's own appendices.
2. **Recounted arithmetic**: 43 tasks = TASK-008…050 inclusive; epic subtotals 4+2+7+4+6+9+5+6 = 43; cross-checked §3 tables against each epic file's task table (titles, sizes, dependencies).
3. **Re-derived the dependency graph** from the table dependencies and checked it for cycles; walked the claimed slice spine 008→009→012→014→016→017→019→021→031→033→034→040→041(+042) against project.md §40 Step 7's legs and against each referenced task's dependency row.
4. **Normative-number sweep**: grepped the deliverables for every amended/loaded number — nibble 30–90 min ×0.25 (I-2), cascade rule 1 "(local time ≥ 20:00 or local time < 07:00)" (OPEN-1 fix), satiety 90-min three-phase window, bands 20/45/75, stages 149/399/749, attractor 60/floor 25/ceiling 92, decline −1.5/h, bond +8/+4/+6/+20 — and checked no stale pre-amendment value survived.
5. **Epic-file completeness**: read all 8 files against the CLAUDE.md §7 template section by section.
6. **First-batch self-sufficiency**: read TASK-008…011 as a fresh agent would (could I execute with no chat history?); checked the TASK-007 Intake Obligations item by item; verified ADR numbering continuity against `.claude/tasks/decisions/` (holds ADR-001…007 only).
7. **Process forensics**: `git status`, `git log` (HEAD unchanged at 95e7649), `git diff` on EPIC-001; verified `status.md` untouched; verified the plan's OPEN-2 disposition claim against `REVIEW-TASK-006.md` lines 130/157 and the OPEN-2 definition in `05` Appendix B (line 709); verified ADR-006's deferral language against TASK-008's requirements.
8. **Philosophy/scope audit**: searched for punishment/streak/game/engagement drift across all deliverables; checked §8 Phase-2 reservations carry no tasks and epic Non-Goals match project.md §27–28.

## Findings

### MAJOR

None found. I specifically hunted for: an unmapped FR/NFR, a cycle or a spine that violates a table dependency, a stale pre-amendment normative number, a Phase 2 task leaking into Phase 1, a bootstrap task missing a binding Intake Obligation, and process violations (commit/status.md). None materialized — evidence per dimension under "Clean Dimensions".

### MINOR

**MINOR-1 — §4.1 dependency graph over-constrains EPIC-007 and EPIC-009 relative to the backlog-of-record tables.**
- Evidence: `docs/product/06-delivery-plan.md:169` draws EPIC-007 as a strict chain `031 → 032 → 033 → 034 → 035 → 036 → 037 → 038 → 039`, and line 178 draws EPIC-009 as `045 → 046 → 047 → 048 → 049 → 050`. The legend (line 152) says "arrows = must finish before". But the §3 tables and epic files state: TASK-036 depends on TASK-033 + TASK-018 (not 035); TASK-037 on TASK-025 + TASK-031 (not 036); TASK-038 on TASK-031 + TASK-022 (not 037); TASK-046 on TASK-020 + TASK-024 (not 045); TASK-047/TASK-048 on TASK-039 + TASK-044 (siblings, not chained).
- Why wrong: the graph asserts hard dependencies the backlog does not have. 036/037/038 are mutually parallel per the tables, and 047/048 don't depend on 045 at all. A fresh orchestrator reading only §4.1 would serialize three pairs of parallelizable tasks. (Conservative over-constraint — no unsoundness — but the plan contradicts itself, and §3 is declared "the backlog of record".)
- Fix: redraw those segments as fan-ins matching the tables (036 hanging from 033+018; 037 from 025+031; 038 from 031+022; 046 from the 020/024 lane; 047/048 as siblings converging on 049). One-pass ASCII edit; no task content changes.

**MINOR-2 — Miscitation "05 §25" (05-technical-architecture has no §25).**
- Evidence: `docs/product/06-delivery-plan.md:132` (TASK-044 row: "device obligations: WC frame delivery under suspension verified on paired hardware (05 §10, §25 — never claimed from simulators alone)") and `.claude/tasks/epics/EPIC-008-watch-app-sync.md:31` and `:38` ("05 §10/§25", "05 §25 — never claimed from simulators alone").
- Why wrong: 05's numbered sections end at §12, followed by Appendices A/B/C (verified against its heading list) — there is no §25. The intended referents are (a) the paired-device delivery obligations in 05 §10.4 and (b) the no-fake-completion rule, which is CLAUDE.md §25 / project.md §25 ("a feature works on device when only static inspection occurred"). As written, the citation resolves to nothing.
- Fix: cite "05 §10.4" for the device obligations and CLAUDE.md §25 (or project.md §25) for the no-fake-device-claims rule, in all three locations.

### NITPICK

**NITPICK-1 — FR-2 AC-2 (3-tap delight rule) is not named in any owning task row.**
- Evidence: PRD `02-mvp-prd.md:243` (AC-2: delightful interaction reachable within 3 taps from app open); TASK-033's row (`06-delivery-plan.md:114`) names AC-1a/1b/AC-3/AC-4 explicitly but not AC-2; the 3-tap path also involves TASK-032 (onboarding steps). Coverage is not missing — plan Appendix A line 296 maps FR-2 → TASK-033 (+031 scaffolding), and EPIC-007 AC-1 blanket-sweeps every FR AC — but the task row is where a fresh implementer looks first.
- Fix: add "3-tap rule (AC-2, joint with TASK-032)" to TASK-033's row, or leave for the TASK-033/TASK-032 task files to carry explicitly (orchestrator creates them just-in-time).

**NITPICK-2 — M1's flourish + optional light haptic (03 §5.4) absent from TASK-036's row.**
- Evidence: `03-ux-architecture.md:296,305` ("inline mark fill + tiny flourish + optional light haptic"); TASK-036's row (`06-delivery-plan.md:117`) and EPIC-007.md's scope line describe M1 as "inline completion (auto, no claim, no modal)" without the flourish/haptic detail. Covered implicitly by the FR-16 blanket (EPIC-007 AC-1) and the row's UX citations, but the row cites UX §5.5–5.6 while the haptic detail lives in §5.4.
- Fix: add "flourish + optional light haptic (03 §5.4)" to TASK-036's row or ensure the just-in-time TASK-036 task file quotes §5.4.

**NITPICK-3 — TASK-007 Intake Obligation's import-whitelist wiring is distributed to TASK-010, and TASK-008 doesn't say so.**
- Evidence: Intake Obligations (`TASK-007-delivery-plan.md:43`) bind the "EPIC-002 bootstrap task" to include "import-whitelist scan wiring (05 §10.2)". TASK-008 (the READY bootstrap task) contains no import-whitelist reference; the wiring lives in TASK-010 Requirements 4/6 with fixture self-tests, and TASK-009's Constraints cross-reference it ("TASK-010's import-whitelist scan will enforce it mechanically next").
- Why flagged: the substance is satisfied — the scan exists inside the same epic's first batch, before any domain code — but a fresh agent executing TASK-008 alone cannot see that the whole Intake Obligation is accounted for.
- Fix (optional): one cross-reference line in TASK-008's Context ("import-whitelist scan wiring: owned by TASK-010"), or the orchestrator notes it when green-lighting TASK-010.

## Clean Dimensions (explicitly verified, with what was checked)

1. **FR/NFR coverage — PASS.** Independent traceability rebuild: FR-1→032, FR-2→033(+031), FR-3→037, FR-4→026/027, FR-5→034, FR-6→016/035, FR-7→017/035, FR-8→017/035, FR-9→021, FR-10→014, FR-11→020/024, FR-12→011/010-scan, FR-13→021/023, FR-14→019, FR-15→016/018, FR-16→018/036, FR-17→041/042, FR-18→040/044, FR-19→038, FR-20→039/047/048/050; NFR-1→045, NFR-2→026/045, NFR-3→045, NFR-4→045, NFR-5→048, NFR-6→039/047 (launch-blocking stated in EPIC-007 AC-5, EPIC-009 AC-3), NFR-7→046, NFR-8→038/048, NFR-9→041/044/045. Every FR/NFR has ≥1 owning task; no orphan found.
2. **§32 granularity — PASS.** Model/engine/tests are separate tasks (012/013/014; 016–020 with TASK-020 as matrix+property+coverage-floor hardening), matching CLAUDE.md §32's own example; no "build the entire app" task; all 43 tasks have size, ACs, tests, deps.
3. **Acyclicity and spine — PASS.** Cross-epic edges consistent everywhere I walked them (031 needs 004+005+006; 040 needs 031+023; 041 needs 026/019; 045…049 gated by 039/044); no cycle found. Spine is a valid topological path and maps to project.md §40 Step 7's legs, with idle-animation legs supplied by LANE B (025–030) converging at 033 — consistent with §4.2/§4.3. (The within-epic serialization of MINOR-1 does not affect spine validity.)
4. **Phase discipline — PASS.** §8 reservations (widgets, notifications, HealthKit, monetization, social) carry zero tasks; epic Non-Goals fence Watch/UI cross-talk correctly (TASK-038 ships only the reset marker; EPIC-008 completes it — cross-epic AC handoff explicit); E1/E3 recorded closed; E4 gated at TASK-050; N-1 widening deferred to TASK-050 exactly per ADR-006.
5. **Epic files — PASS.** All 8 contain every §7 section (Objective, User/Product Value, Scope, Non-Goals, Dependencies, Tasks with branch, Acceptance Criteria, Test Requirements, Definition of Done, Status TODO); branches encoded per epic (`feature/EPIC-002-foundation` … `feature/EPIC-009-release-readiness`).
6. **First-batch self-sufficiency — PASS (with NITPICK-3).** Exactly one READY (TASK-008; 009/010/011 TODO with correct blocking rationale). TASK-008 alone covers TR10 verification with a STOP/BLOCKED path, OPEN-3's three sub-items, ADR-006 pins ("current shipping generation, verify at execution — do not assume the documents' examples"), device names with smallest-screen obligations (AC-1a no-scroll, glyph legibility ~32 pt), framework pin, N-1 deferral note, §21-template ADR-008, and VERIFY-AT-BUILD resolution listing. TASK-009 resolves/re-owns swift-test hostability explicitly; TASK-010 fixture-self-tests both scanners; TASK-011 consumes 04 §8.4 slot names verbatim, project.md §18, and the three `momo.line.*` namespaces with marked placeholders. ADR numbering continues at ADR-008; `decisions/` holds only ADR-001…007 (no premature ADR-008). All template sections non-placeholder.
7. **Normative-number fidelity — PASS.** Amended nibble 30–90 min ×0.25 in TASK-016/035 and EPIC-004; amended cascade rule 1 in TASK-018 (named test "02:00 tuck-in with Q1 done selects Q6") and EPIC-004 AC-5; bands/stages/window/attractor/decline/bond/ceiling all consumed as amended; no stale value found anywhere in the deliverables.
8. **Philosophy/scope — PASS.** No punishment, streak, engagement, or game drift in any deliverable; §44's "avoids guilt and manipulative engagement" question is an explicit EPIC-009 AC; FR-12 guardrails stated in the plan's method section; MVP non-goals (§24 list) all fenced in epic Non-Goals or §8.
9. **Test mapping — PASS.** §5 maps each epic to the project.md §32 matrices via 05 §10.1–10.6; coverage floors Core ≥ 90 % / Kit ≥ 80 % recorded with enforcement owner (TASK-010 wires measurement, TASK-020 enforces floors); 05 §12 budgets are release gates with "a miss is a task-level blocker" (EPIC-009 AC-1); NFR-6 audit launch-blocking in both EPIC-007 and EPIC-009.
10. **Risk register — PASS.** R1–R13 each carry likelihood×impact and a named owning task (R1/TR10→008, R3→026/045, R9 device availability→044 paired-hardware evidence, tone drift→010 banned-vocabulary scan, scope creep→§8/Non-Goals); TR1 battery and TR10 toolchain both owned.
11. **Internal consistency — PASS.** 43 = Σ subtotals = TASK-008…050; §3 rows identical to epic-file rows for every epic spot-checked (006/007/008/009 titles, sizes, deps); §4.2 spine table consistent with §4.1 for all shared nodes; Appendix A/B rows agree with the tables.
12. **Process compliance — PASS.** `git log`: no commit by the implementer (HEAD = 95e7649, the pre-task state); `git status`: only the intended new/modified files; `git diff EPIC-001-product-definition.md`: single Status-line change, which TASK-007's spec explicitly permits; `status.md` untouched; Reviewer Findings / Completion Evidence correctly left empty; the plan's OPEN-2 disposition ("confirmed by REVIEW-TASK-006's APPROVED verdict") is factually supported by `REVIEW-TASK-006.md:130` ("Reviewer rulings: OPEN-2/I-1 confirmed correct") and `:157` (final **APPROVED**); OPEN-3→TASK-008/ADR-008 and every VERIFY-AT-BUILD item has an owner (008, 009/010, 014, 025, 040/044, 045, 048) matching 05 Appendix B.

## VERDICT

**APPROVED_WITH_MINOR_NOTES** — 0 MAJOR, 2 MINOR, 3 NITPICK.

Rationale: The delivery plan is substantively complete and internally sound: all 20 FRs and 9 NFRs trace to owning tasks (independently rebuilt, not taken on faith), the 43-task breakdown honors §32 granularity, the dependency graph is acyclic and the slice spine faithfully realizes project.md §40 Step 7, every binding Intake Obligation has an owner in the first batch, amended normative numbers are consumed everywhere with no stale residue, phase discipline holds with zero Phase-2 leakage, and the process was followed exactly (no commits, no status.md edits, permitted EPIC-001 status-line edit only, OPEN-2 claim verified true against REVIEW-TASK-006). Both MINOR findings are documentation-precision defects, not plan defects: MINOR-1's graph over-constrains conservatively (never unsoundly) and MINOR-2 is a wrong section pointer — each is a one-pass fix that requires no re-planning and can be applied before the orchestrator's commit. The task's own acceptance bar ("review verdict ≥ APPROVED_WITH_MINOR_NOTES") is met.

---

## Disposition (orchestrator, 2026-09-08)

Verdict received: **APPROVED_WITH_MINOR_NOTES** (0 MAJOR / 2 MINOR / 3 NITPICK). Meets the task's acceptance bar ("≥ APPROVED_WITH_MINOR_NOTES"). All five findings closed mechanically pre-commit by the orchestrator (no re-review required — none changed plan substance):

| ID | Disposition | Fix |
|---|---|---|
| MINOR-1 | FIXED | §4.1 graph redrawn as fan-ins matching the §3 tables: 036 ← 033+018; 037 ← 031+025; 038 ← 031+022; all converge on 039. EPIC-009 drawn as siblings 045/047/048 (← 039+044) + 046 (← 020+024) converging on 049 → 050. Additionally applied the same defect-class fix to EPIC-008's segment (not separately flagged): 042/043 drawn as siblings under 041, converging on 044 (whose table deps are TASK-040…043). Marker alignment verified programmatically (all fan-in ┤/▼ at col 41). |
| MINOR-2 | FIXED | "05 §25" → "05 §10.4; CLAUDE.md §25" in all three locations (plan TASK-044 row; EPIC-008 task table row; EPIC-008 AC-5). |
| NITPICK-1 | FIXED | TASK-033 row now names "3-tap delight path (AC-2, joint with TASK-032)". |
| NITPICK-2 | FIXED | TASK-036 row now carries "tiny flourish + optional light haptic per UX §5.4". |
| NITPICK-3 | FIXED | TASK-008 Context now cross-references: "import-whitelist scan wiring (05 §10.2) is owned by TASK-010 (same epic, later in the batch)". |

Plan header status updated DRAFT → REVIEWED. No other content changed; no task dependency, AC, test, or normative number was altered by these fixes.

**Final: APPROVED — cleared for commit** `docs(product): TASK-007 delivery plan with Phase 1 epics and task breakdown`.
