# TASK-013 — Domain-Model Property Tests

## Parent Epic
EPIC-003 — Pet Domain Model

## Objective
Prove the TASK-012 domain model against the PRD §3.1–3.2 tables exhaustively — full-range sweeps (not samples) over bands and bond stages — and demonstrate that no numeric-leakage types exist (FR-9 AC-1), making "the domain matches the PRD" a mechanically checked fact before any engine dynamics exist.

## Context
TASK-012 ships the types and derivations with focused unit tests only; this task adds the exhaustive property layer the delivery plan calls out for EPIC-003's acceptance ("band/invariant property tests green headlessly") and FR-9 AC-1. Swift Testing parameterized tests make full-range sweeps cheap: 0…100 for mood/energy band inputs, 0…1000 for BondStage inputs. Attractor/floor/ceiling dynamics are engine territory (EPIC-004) and OUT of scope — here only the static band/stage mappings.

## Requirements
1. Exhaustive band property tests: for every input 0…100, `makeMoodBand` and `makeEnergyBand` return exactly the PRD §3.1–3.2 band for the 20/45/75 cut-offs (both boundaries: 20/45/75 themselves included, per the PRD table's boundary semantics).
2. Exhaustive stage property tests: for every input 0…1000, `makeBondStage` matches the 149/399/749 thresholds (boundaries included per PRD).
3. Single-source verification: the tests read thresholds from the same single-source constants TASK-012 defined (no re-hardcoded 20/45/75/149/399/749 in test code) — the property being tested is mapping-correctness, while the threshold VALUES are pinned by dedicated constant-vs-PRD assertions so a silent constant change still fails.
4. No-numeric-leakage check (FR-9 AC-1): assert the public API exposes bands/stages as their enum/derivation types only — no public raw numeric band fields a consumer could branch on. (Compile-time/API-shape assertions where possible; document the method.)
5. Determinism: pure-function sweeps — same input always yields same output; no clock, no RNG.

## Files / Areas Likely Affected
- `Tests/MomoCoreTests/` (new property-test files)
- Possibly trivial doc-comment additions in `Sources/MomoCore/` if the leakage check motivates an API note — no behavioral source changes expected

## Dependencies
- TASK-012 (types + derivations + single-source constants exist).

## Constraints
- Jupiter model, fresh agent, no commit by agent.
- D-R1 unchanged (`MomoCore` Foundation-only); tests may import the package + Swift Testing + Foundation.
- Scope control (§22): engine-dynamics tests discovered as tempting → record as EPIC-004 follow-up, do not implement.

## Acceptance Criteria
- AC-1: Full-range sweeps (0…100 ×2 bands, 0…1000 stages) pass headlessly via `swift test`.
- AC-2: Threshold constants are pinned against the PRD values in dedicated assertions (single source preserved, silent changes caught).
- AC-3: No-numeric-leakage assertion exists and passes; method documented.
- AC-4: Prior suites (35-test TASK-010/011 baseline + TASK-012's focused tests) still green; record the final suite/test counts.

## Required Tests
- This task IS tests. Evidence: verbatim `swift test` output with final counts; coverage recorded informationally via the TASK-010 llvm-cov command (floors still unenforced until TASK-020/024).

## Review Requirements
- Fresh reviewer verifies: sweep ranges truly exhaustive (boundary values included per PRD semantics); thresholds-vs-PRD assertions present (not just constant-echoing); leakage-check method sound; no scope creep into engine dynamics. Record in `.claude/tasks/reviews/REVIEW-TASK-013.md`.

## Git Requirements
- Branch: `feature/EPIC-003-domain-model`
- Commit: `test(domain): TASK-013 exhaustive domain-model property tests`
- Push to origin after orchestrator commit; record hash in Completion Evidence.

## Status
TODO (after TASK-012)

## Implementation Notes
- (agent fills in)

## Reviewer Findings
- (orchestrator records)

## Completion Evidence
- (commit hash + push, by orchestrator)
