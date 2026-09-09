# TASK-020 — Engine test matrix, meta-determinism property, coverage floor

## Parent Epic
EPIC-004 — Pet State Engine (the epic's closer; after this task the epic merges to `main` per CLAUDE.md §14).

## Objective
Close EPIC-004's test obligations (05 §10.2–§10.3; delivery plan TASK-020 row): every 05 §10.3 domain-matrix row resolves to named, green tests in `MomoCoreTests`; the §10.2 meta-determinism property runs as a property over bounded seeded random interaction sequences through the FULL `reduce` surface; and the MomoCore ≥ 90 % line-coverage floor is measured and recorded.

## Context
- The engine is fully executable through TASK-014–019: `reduce` + folds/wakefulness/handshakes (015), interaction semantics/satiety/repetition (016), bond ledger (017), quests + cascade (018), read-models + copy selection (019). Current suite: **363 tests / 42 suites green** (`swift test`, macOS host).
- The delivery-plan TASK-020 row (06-delivery-plan.md line 80) is normative: "Every §10.3 row exists as a named test …; meta-determinism property …; MomoCore ≥ 90 % line coverage recorded (05 §10.2)". Verification: "Full MomoCoreTests suite green via `swift test` on macOS". Size L; depends on TASK-014…019.
- 05 §10.3 matrix (verbatim rows): **(1) Mood/energy transitions** — band-mapping property over 0...100 (FR-9 AC-1); attractor/floor/coupling folds (FR-9 AC-2/3). **(2) Bond progression** — cap-by-construction property over random sequences (FR-10 AC-1); monotonicity incl. replay (AC-2); 1000-pats-zero-bond (AC-3); stage crossing once (AC-4/5). **(3) Daily reset** — midnight rollover exactly once across folded spans; absent-day ledger emptiness (FR-11 AC-2, FR-12 AC-1). **(4) Quest progression** — generator 30-day simulation + by-construction candidates; window checks (Q1/Q6); completion auto-tick; cascade rules incl. the letter-of-PRD gap test (§4.8). **(5) State-engine rules** — response-matrix table test (PRD §4 rows × bands × wakefulness), satiety rows asserting the nibble as normative (I-2/OPEN-5); satiety phases; settling + waking decline-warm cells; repetition curve; handshakes incl. late/duplicate/cancelled reports; play single-instant application. **(6) Deterministic randomness** — seed stability (same day ⇒ same seed); sequencer schedule purity (FR-4 AC-1) — Core/Character.
- Existing coverage is extensive — the implementer's first job is a VERIFIED GAP ANALYSIS, not a rewrite. Likely homes: row 1 → `BandDerivationTests` + `TimeFoldTests` + `DomainPropertySweepTests`; row 2 → `BondLedgerTests` + `BondLedgerPropertyTests`; row 3 → `TimeFoldTests` (+ `BondLedgerPropertyTests` for cross-midnight ledger exactness); row 4 → `QuestGenerationTests`/`QuestGenerationPinnedTests`/`QuestTickTests`/`QuestCascadeTests`; row 5 → `InteractionResponseTests` + `SatietyWindowTests` + `RepetitionCurveTests` + `CareInteractionTests`/`PlayRoundTests`/`WakefulnessHandshakeTests` + `EngineReduceTests`; row 6 → `DaySeedTests` + `SeededGeneratorTests` (the sequencer half is EPIC-006's — out of scope here).
- Coverage recipe (TASK-010 precedent): `swift test --enable-code-coverage` → `xcrun llvm-cov report .build/arm64-apple-macosx/debug/MomoPackageTests.xctest/Contents/MacOS/MomoPackageTests -instr-profile .build/debug/codecov/default.profdata` (xccov CANNOT read SwiftPM's raw profdata). Last measured TOTAL: 97.77 % lines (TASK-015 final) — informational then, the FLOOR is enforced now.
- Out of scope: 05 §10.4 sync matrix (EPIC-008-era; its Core-half bits — replay no-op INV-10, hello device-agnostic idempotency — already live in `DomainInvariantsTests`/`BondLedgerTests`); §10.5 edge matrix (TASK-046 executes it); §10.6 UI/accessibility (EPIC-007+).

## Requirements
1. **Gap analysis (the matrix audit).** Produce, in the task file's Implementation Notes, a §10.3 row → named test(s) → suite-file table covering EVERY row and every named clause of the six rows. For each clause, VERIFY the named test exists and is green; where a clause has no home, ADD the named test (house naming: test names echo the matrix cell, e.g. `midnightRolloverExactlyOnceAcrossFoldedSpans`, `absentDayLedgerIsEmpty`, `thousandPatsBondZero`, `monotonicUnderReplay`). Report any clause you judged already-covered with the exact test name — the reviewer re-audits the table.
2. **Meta-determinism property (§10.2).** New suite (suggested `MetaDeterminismTests`): generate bounded seeded random interaction sequences spanning ≥ 3 local days (rollovers INCLUDED), mixed steps — interactions of all kinds, character reports (incl. handshake completions/cancellations), evaluates, quest-award mechanism calls — through the production `reduce`; run each sequence TWICE from identical initial states (same clock, calendar, seed) and assert whole-trajectory equality (every intermediate `EngineState` AND every `EngineOutcome` response/moments equal step-for-step), not just endpoints. ≥ 5 distinct seeds; steps advance across the 22:00/07:00 night window and midnight so folds/handshakes/quests all engage. Deterministic generation (repo-owned `SeededGenerator`), no wall clock.
3. **Coverage floor (§10.2; FR coverage per delivery plan).** Measure MomoCore line coverage with the llvm-cov recipe above; record the per-file table + TOTAL in Completion Evidence. If TOTAL < 90 %, add targeted tests for the uncovered lines and re-measure until ≥ 90 % (report the closing tests). Record the exact command + numbers; note any file with deliberately-untestable lines (e.g. `SystemEngineClock`'s ambient `Date.now`, `assertionFailure` paths) with reasons.
4. **Suite health.** `swift build --build-tests` green; full `swift test` green with zero failures/skips; no new compiler warnings; standing in-suite scanners (D-R1 import whitelist, banned vocabulary, token purity, engine purity) green with no new exemptions. Runtime stays bounded — the meta-determinism sims must keep the whole suite snappy (current wall ≈ 0.5 s; target: the suite stays under a few seconds).
5. **Defect protocol.** This is a TEST-first task, but if a new test exposes a real engine defect: fix minimally, disclose prominently in Implementation Notes (defect → root cause → fix → regression pin), and let the reviewer adversarially audit the fix. Never weaken a normative pin to make a test pass; never edit a spec doc.
6. **Anti-echo discipline.** New behavior tests read `Thresholds`/`FoldRules`/`BondRules`/`InteractionRules`/`CopyRules`/`QuestCatalog` constants; raw literals only in pinned tests (the standing division of labor — the reviewer mutation-bites at least one new constant to prove the pins bite).
7. **No doc changes, no `MomoCopy.xcstrings` changes, no dependency additions.** MomoCore stays Foundation-only.

## Files / Areas Likely Affected
- New: `Tests/MomoCoreTests/MetaDeterminismTests.swift` (+ any gap-closing suite files, if a clause truly has no home).
- Modified: existing suites ONLY where the gap analysis finds a missing clause (surgical — name the exact tests touched).
- Production sources: expected UNTOUCHED; any change falls under Requirement 5's defect protocol.
- Task file (this one) — Implementation Notes, Completion Evidence; no other docs.

## Dependencies
- TASK-014–019 (all DONE on this branch). No new external dependencies (D-R6).

## Constraints
- Test-target changes only by default (Requirement 5 exception).
- Determinism: `ManualEngineClock` + injected fixed calendars; no `Date.now`, no ambient randomness anywhere in tests.
- Match house style: Swift Testing (`@Suite`/`@Test`/`#expect`), seeded generators, raw-literal pins with attribution comments, headers citing the normative doc section.

## Acceptance Criteria
1. The §10.3 gap-analysis table exists in Implementation Notes, maps EVERY row/clause to a named green test, and any added tests are named after their matrix clauses.
2. The meta-determinism suite is green: ≥ 5 seeds × bounded multi-day mixed sequences, whole-trajectory (states + outcomes) byte-equality between twin runs.
3. MomoCore line coverage ≥ 90 % measured via llvm-cov; per-file table + TOTAL + exact command recorded in Completion Evidence; any < 90 % gap closed with named tests.
4. `swift build --build-tests` + full `swift test` green; standing scanners green; no new warnings; bounded runtime.
5. Any production change is defect-driven, minimal, disclosed, and reviewer-audited; zero undisclosed diffs outside Tests/.

## Required Tests
1. The §10.3 clause audit (the table) — every clause resolved to a named test; missing clauses get named tests in this task.
2. `MetaDeterminismTests` — the §10.2 property over ≥ 5 seeds, multi-day mixed streams, whole-trajectory twin equality.
3. The coverage measurement run (llvm-cov) with the recorded table — this is evidence, not a test; the command is reproduced by the reviewer.

## Review Requirements
Independent fresh reviewer (CLAUDE.md §10/§33), adversarial, unprimed: re-derive the §10.3 matrix from 05 §10.3 and try to find a clause the gap table misses or maps to a test that doesn't actually pin that clause; re-run the llvm-cov coverage command and compare the table; mutation-bite (a) one meta-determinism seed or step-kind (the twin equality must fail with attribution) and (b) one new/audited constant (the raw pin must bite); audit `git diff` scope (Requirement 7/5 — no undisclosed production changes); verify suite runtime stays bounded. Review file: `.claude/tasks/reviews/REVIEW-TASK-020.md`.

## Git Requirements
No commit by the implementation agent. Orchestrator commits after review disposition: `test(engine): TASK-020 §10.3 matrix, meta-determinism property, coverage floor` — atomic, TASK-ID included.

## Status
READY (2026-09-09 — contract materialized by the orchestration agent from 05 §10.2–§10.3, the delivery-plan TASK-020 row, the TASK-010 coverage recipe, and the live suite inventory of 37 test files / 42 suites).

## Implementation Notes
(To be filled by the implementation agent.)

## Reviewer Findings
(To be appended by the review agent only.)

## Completion Evidence
(To be filled at disposition: test command + counts, coverage table, review file, commit hash.)
