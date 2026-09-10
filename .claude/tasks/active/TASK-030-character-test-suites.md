# TASK-030 — Character test suites: MomoCharacterTests audit + determinism-property coverage record + art-budget recording (05 §10.1–10.2; delivery plan TASK-030)

## Parent Epic
EPIC-006 — Character Rendering (MomoCharacter), task 6 of 6 (size S) — the EPIC CLOSER. Epic acceptance criteria served: AC-6 (`MomoCharacterTests` green via `swift test`; sequencer/pause/RM pure parts fully determinism-property covered per 05 §10.2; **art budgets recorded against §8.3**) plus the audit that AC-1–AC-5's test-visible claims each resolve to a named, actually-green test. Follows the TASK-024 precedent (Kit's matrix audit + coverage floor) and the TASK-020 precedent (Core's matrix audit), applied to Character — **without a coverage floor** (see Objective).

## Objective
Close EPIC-006's test obligations (delivery-plan TASK-030 row: "Sequencer determinism properties, pause discipline, RM pose mapping fully covered; pure files 100 % determinism-property covered per 05 §10.2"; 05 §10.1 MomoCharacterTests target row: "idle sequencer determinism, Reduce Motion pose mapping (pure files)"):

1. **Audit table A — sequencer determinism (04 §5.1–5.3, §9.4; 05 §10.2):** every determinism clause of the idle sequencer resolves to named, green tests — the property (identical `(idleSeed, timeline)` ⇒ identical event log), the meta-determinism property over bounded seeded randomized timelines (05 §10.2's definition), the §5.2 scheduler parameters (every authored interval/subrange inside its doc band, pinned), the §5.3 aliveness-floor fallback, and schedule purity (FR-4 AC-1).
2. **Audit table B — clock pause/resume (04 §7.4, §9.5; epic AC-2 / rig rule R3):** the single `CharacterClock` gating L0–L4, every channel independently pausable, zero-on-pause/resume-from-zero, the one-call scenePhase/AOD zeroing, and the glyph tier's never-binds-the-clock posture — each resolves to named green tests.
3. **Audit table C — Reduce Motion pose mapping (04 §7.3, §3.5):** "fully covered" means EVERY §7.3 binding-table row (idle loop, blink, look-around, state changes, touch reactions, celebrations, waking/settling, playing, plus the §7.3 closing never-removes-information law and the §3.5 grayscale-legibility clause) resolves to named green tests.
4. **Audit table D — reaction duration bounds + curves (04 §7.1, §7.2; §6.3):** every character-owned duration in the §7.1 master timing table resolves to a named test pinning it (and where a value is AUTHORED inside a doc band, the pin names the band + the authored digit); the §7.2 curve laws (incl. the executable no-bounce rule); §6.3 play-round character-side pacing inside UX-3's ≤ 30 s shell.
5. **Audit table E — geometry pins (04 §2.1; ADR-001; epic Test Requirements):** geometry pins over the §2.1 normalized grid — Direction-C landmarks measurable from the exported data (TASK-025's generated constants), the ADR-001 ear rule (≥ 12 % of body width **at base**), and the §2.1 LOD stage-size bands (220–280 / 60–80 / 24–32 pt) resolving to named green tests.
6. **Pure-file determinism-property coverage record (05 §10.2; the delivery-plan TASK-030 row's "100 %" clause):** enumerate the PURE logic files of `Sources/MomoCharacter` (the sequencer/random/events/variants layer, curves, expression system, rig motion model + channel/pose/layer-tree/LOD data, reaction clips/clip-motion/director/state/overlay motion, handshake choreography, moments, RM mapping, clock) and record for EACH the determinism property or twin-equality property that covers it (named tests). View files (`MomoRigView.swift`) are NOT pure — the record must say so explicitly rather than dodge; the §10.2 property (identical inputs ⇒ byte-identical outcome, bounded seeded) is the standard applied to the pure files, and the record is honest where a file's determinism rests on a twin corpus versus an analytic pin. **This record replaces a coverage floor: NO MomoCharacter line-coverage floor exists** — 05 §10.2's floors are MomoCore ≥ 90 % and MomoKit ≥ 80 %, both already recorded (TASK-020: 97.68 %; TASK-024: 88.86 %). Do NOT run or record a MomoCharacter llvm-cov number; do not invent a floor.
7. **Art budgets recorded against §8.3 (epic AC-6):** re-measure the rig bucket (`MomoRig+*.swift` generated constants), room+props bucket (`MomoRoom.swift` + `MomoProps.swift`), total art contribution (`Sources/MomoCharacter/` sources total), against §8.3's budgets (≤ 300 KB / ≤ 250 KB / ≤ 1.5 MB target). Byte counts via exact `getsize`-style measurement (never `du -k` — it inflates). Record basis notes: the hand-written `MomoRig.swift` anchor sits outside the rig bucket (O8 convention); the budgets compare SOURCE BYTES as TASK-025 recorded.

**This is an AUDIT-and-record task, not a rewrite.** TASK-025–029 landed extensive suites (34 suites in `Tests/MomoCharacterTests/`); the implementer's first job is a VERIFIED GAP ANALYSIS with the TASK-024 adversarial standard: **a named test COUNTS only if reading its body shows it actually pins that row's clause** — a test that touches the area without pinning the clause does not count; find or write the one that does. Expect to write few or zero new tests; every new test must close a named gap from the audit tables, never pad a count.

## Context
- **Codebase state:** TASK-029 complete (`9a46641`) + its closeout housekeeping (`a249913`). Branch `feature/EPIC-006-character`, HEAD `a249913`. **Baseline `swift test` = 824 tests / 82 suites green — pinned at dispatch.** All 40 `Sources/MomoCharacter/*.swift` files landed; the character pipeline (`Tools/character-pipeline/`) and its evidence PNGs are TASK-025 artifacts.
- **Normative mapping (re-derive from these; do not take this list on faith):** the delivery-plan TASK-030 row (`docs/product/06-delivery-plan.md`, EPIC-006 table); the delivery-plan §-coverage table's EPIC-006 row ("Domain: deterministic randomness (sequencer); UI-support: pause/RM behaviors (pure parts) → MomoCharacterTests → Sequencer logic fully covered by determinism properties"); 05 §10.1 (MomoCharacterTests target row) + §10.2 (coverage policy, determinism-property definition); the EPIC-006 epic file's Test Requirements + AC-6; project.md §32's Domain row "deterministic randomness" (the epic file's "§32 rendering row" phrasing is shorthand for the delivery-plan coverage-table mapping — project.md §32 itself has no rendering row; use the delivery-plan coverage table as the authoritative mapping and do NOT edit the epic or docs).
- **Where the clauses already live (audit STARTING points — verify each body, do not trust this list):**
  - Sequencer determinism + §5.2 parameter pins + resume discipline → `MomoIdleSequencerTests`, `MomoIdleRandomTests`, `MomoIdleResumeTests` (ADR-010), `MomoIdleRenderTests` (incl. the §5.3 aliveness-floor + ADR-012 occupancy budgets), `MomoCurvesTask027Tests`.
  - Clock/pause → `CharacterClockTests`, `RigDisciplineTests` (the ONE-clock + glyph-tier-never-binds scoping pins), `R1CompositionTests` (ADR-009), `MomoIdleResumeTests` (ADR-010 end-to-end).
  - RM mapping → `MomoReduceMotionMappingTests`, `MomoReduceMotionTwinTests` (fold/R15 law over the corpus), `MomoReduceMotionEndPoseTests` (R6 press law + end-pose partition).
  - Duration bounds/curves → `MomoCurveRulesTests`, `MomoCurvesTask027Tests` (§7.2 + no-bounce), `MomoReactionClipTests` (per-clip durations, tempo scope, pressReleaseSeconds), `MomoReactionDirectorTests` + `MomoHandshakeTests` (choreography durations 3.0/2.0, play pacer ≤ 30 s shell), `MomoMomentTests`.
  - Geometry → `MomoRigGeometryTests` (§2.1 grid + ADR-001 at-base ear rule), `MomoRigInventoryTests` (part/naming inventory), `MomoRigVariantsTests` (LOD-glance/glyph variants + winding/seam pins), `MomoGeneratedDisciplineTests`, `MomoPipelineReproducibilityTests` (AC-1 reproducibility), `MomoArtBudgetTests` (§8.3 budgets as an in-suite test).
  - Twin/meta-determinism properties → `MomoReactionTwinTests`, `MomoReduceMotionTwinTests` (whole-trajectory fold equality); the sequencer's determinism properties live in the Idle suites.
- **Known candidates to evaluate (candidates, not conclusions — verify before acting):** whether the §7.1 table has any character-owned duration row with NO named pin (the strongest expected gap shape — TASK-026–029 pinned their OWN constants, but the audit is against the DOC table); whether every pure file's determinism claim has a named test (e.g. `MomoExpressions`/`MomoIdleVariants`/`RigPose`/`RigChannel`/`RigLayerTree` data files — a pure data file covered by the same properties as its consumers counts, but the record must say WHICH property and WHERE); whether §3.5 grayscale has a named test anchor beyond the TASK-029 evidence harness (the committed PNGs + `MomoArtBudgetTests`-adjacent in-suite checks vs an actual named grayscale test — the epic clause says "grayscale legibility per §3.5 is verified per expression state").
- **House discipline:** any new test file follows the conventions (`@Test`/`#expect`, seeded bounded properties, fixtures in `Support/`, no ambient reads); the standing scans (`RigDisciplineTests` + token/copy/generated discipline) must stay green with NO new exemptions; no `Sources/MomoCore/` or `Sources/MomoKit/` changes; **production diff expected EMPTY** — any production touch is a DISCLOSURE with justification. No doc changes (doc-chain notes route to the orchestrator's backlog, never edited by this task). The TASK-029 Disclosures register in `MomoReduceMotion.swift` is the RM authority — do not restate or edit it.

## Requirements
1. **Audit tables A–E** (one per clause area above): for each row — the clause restated from the docs (with the doc section cited), the named green test(s) that pin it (suite file + test name), and the pin verification (one line: what would break if the clause regressed). Gaps close with named tests. Every named test's BODY read, not existence-grepped.
2. **Pure-file determinism-property coverage record:** the file-by-file table over the pure logic files of `Sources/MomoCharacter` — for each: the covering determinism/twin property (named tests + suite), and an honest one-line statement of the guarantee shape (analytic pin / twin corpus over seeded streams / structural scoping pin). View files explicitly excluded with the reason. This table is the deliverable that satisfies "pure files 100 % determinism-property covered per 05 §10.2" — it must cover EVERY pure file or honestly declare why a file needs no property (e.g. constants-only data with no behavior; say which suite pins its values).
3. **Art budgets table:** §8.3 budget rows × measured bytes (exact byte counts, the O8 basis note included), verdict per row, recorded in Completion Evidence in TASK-025's format.
4. **No scope creep:** no production changes unless a gap genuinely requires one (then DISCLOSURE + justification — expected: none); no coverage-floor invention; no doc edits; no test weakened, deleted, or skipped to make the audit clean — that is a BLOCKED-level finding; no new scan exemptions; no TODO/FIXME/HACK/TEMP debt (§26).
5. **Suite hygiene:** final `swift test` green ×2 with zero warnings; exact counts recorded; suite runtime stays bounded (no new unbounded loops; any new property test is seeded and bounded per house discipline).

## Files / Areas Likely Affected
- Possibly NEW `Tests/MomoCharacterTests/` files for named gap closures and small additions to existing suites (expected: few or none).
- This task file (audit tables + record + budgets in Implementation Notes / Completion Evidence).
- NOT affected: `Sources/MomoCharacter/` (expected diff EMPTY), `Sources/MomoCore/` (must stay EMPTY), `Sources/MomoKit/` (must stay EMPTY), `Apps/`, `Tools/` (evidence harnesses are TASK-025/029 artifacts — do not re-render PNGs; the committed evidence is byte-stable), docs, `.claude/` orchestration files other than this task file.

## Dependencies
- TASK-025…029 (all landed and pushed on `feature/EPIC-006-character`; baseline `a249913`).

## Constraints
- Fresh agent (Jupiter — omit any model override), no commit rights; house 200–400-line file discipline for any new test file; scans green, no new exemptions; baseline count pinned at dispatch (824/82 @ `a249913`); work uncommitted on the branch, tree left DIRTY for the orchestrator.
- The audit tables and the coverage record are EVIDENCE, not code — the reviewer re-derives them from the docs independently.

## Acceptance Criteria
1. Audit tables A–E complete: every clause of each area → named green tests with pin-verification lines; gaps (if any) closed and named.
2. Pure-file determinism-property coverage record complete: every pure `Sources/MomoCharacter` file covered or honestly dispositioned; view files explicitly excluded with reasons.
3. Art budgets table complete: measured bytes vs §8.3 budgets, verdicts recorded (epic AC-6).
4. Final `swift test` green ×2, zero warnings, standing scans green with no new exemptions.
5. Production diff EMPTY (or disclosed + justified); `Sources/MomoCore/` + `Sources/MomoKit/` diffs EMPTY; no doc changes.

## Required Tests
- The audit's closing tests (only those the gap analysis justifies — expected: possibly one §3.5-grayscale named-test anchor and/or any unpinned §7.1 duration row; the audit decides, the contract does not).
- The budget re-measurement (measurement, not a test).

## Review Requirements
- Independent fresh reviewer (CLAUDE.md §10/§33), adversarial, unprimed:
  - Re-derive ALL audit tables (A–E) and the pure-file coverage record from 04 §2.1/§3.5/§5–§7/§8.3/§9.4–9.5, 05 §10.1–10.2, the delivery-plan TASK-030 row + coverage table, and ADR-001 BEFORE comparing to the implementer's tables; name any clause the tables miss or map to a test that does not actually pin it (bodies read, not existence-grepped).
  - Verify the budget table by re-running the byte measurement; reject any number that cannot be reproduced.
  - Mutation-bite the audit's central claim: pick ONE audit-mapped clause, apply a small mutation to the production code it pins, and verify the named test ACTUALLY fails (the audit counts only if the mapping is executable truth). Restore byte-identical (record sha256 before/after).
  - Verify the suite is green ×2 and the scans carry no new exemptions.
  - Verify `git diff` scope: production EMPTY-or-disclosed; MomoCore/MomoKit EMPTY; no doc changes; no `.claude/` touches beyond this task file.
  - Review file: `.claude/tasks/reviews/REVIEW-TASK-030.md`.

## Git Requirements
- No commit by the implementation agent. Orchestrator commits after review disposition: `test(character): TASK-030 character suite audit + determinism-property coverage record` — atomic, TASK-ID included.
- This is the EPIC-006 closer: after this task's housekeeping, the epic merges to `main` per CLAUDE.md §14 (owner-authorized, no PR; `git fetch` + check `origin/main` FIRST — the owner may have PR-merged mid-epic, the EPIC-004 precedent; merge only the remainder; never force-push).

## Status
READY — contract materialized by the orchestration agent (2026-09-10) from 05 §10.1–10.2, project.md §32 (Domain: deterministic randomness), the delivery-plan TASK-030 row + §-coverage table EPIC-006 row, the EPIC-006 epic Test Requirements + AC-6, ADR-001, and the TASK-024/TASK-020 audit precedents. Baseline count pinned at dispatch: **824 tests / 82 suites green @ `a249913`**. Fresh implementation agent dispatching.

## Implementation Notes
(pending — the implementing agent records the audit tables, the coverage record, and the run history here)

## Reviewer Findings
(pending — REVIEW-TASK-030)

## Completion Evidence
(pending — commit hash, counts, budget table recorded post-disposition by the orchestrator)
