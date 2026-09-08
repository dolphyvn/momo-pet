# TASK-010 — Test-Target Scaffolding + Import-Whitelist + Banned-Vocabulary Harness

## Parent Epic
EPIC-002 — Foundation & Build Baseline

## Objective
Stand up the five-target test architecture per 05 §10.1 and wire the two standing static scans from 05 §10.2: the import-whitelist scan enforcing D-R1 (MomoCore imports Foundation only) and the banned-vocabulary scan enforcing the 04 §10.2 tone guide over String Catalogs — both as mechanically failing tests, self-tested against fixtures, so the guardrails exist before any logic or copy is written.

## Context
05 §10.1 defines: `MomoCoreTests` (package, `swift test` on macOS), `MomoKitTests`, `MomoCharacterTests` (same), plus `MomoUITests` and `MomoWatchUITests` (app-project test targets on simulators). 05 §10.2 mandates the two static scans and the coverage floors (Core ≥ 90 %, Kit ≥ 80 % — enforced later per task, not here). TASK-009 delivered the package + app targets; this task adds the test targets and the scans. The scans are structural guarantees for FR-12 (tone) and D-R1 (purity) — they must fail loudly, and their failure modes must themselves be tested.

## Requirements
1. Package test targets `MomoCoreTests`, `MomoKitTests`, `MomoCharacterTests`, runnable via `swift test` on macOS; each contains one smoke test so the suites are non-empty.
2. App-project UI test targets `MomoUITests` (hosting `Momo`) and `MomoWatchUITests` (hosting `MomoWatch`), each with one trivial smoke test, runnable on the pinned simulators via `xcodebuild test`.
3. Test framework pinned per ADR-008 (expected Swift Testing; fall back per its note). Resolve any remaining framework VERIFY-AT-BUILD item and record it resolved in Implementation Notes.
4. **Import-whitelist scan** (D-R1, 05 §10.2): a test in `MomoCoreTests` that scans the `MomoCore` sources and fails if any `import` other than Foundation (and standard-library modules on the whitelist — whitelist itself committed and documented) appears. Implement the scan logic as a pure, fixture-testable function.
5. **Banned-vocabulary scan** (FR-12, 04 §10.2): a test that loads the String Catalogs (TASK-011 creates them; until then the scan reads whatever catalogs exist, vacuously green) and fails if any banned term from the 04 §10.2 list appears in any value. Same fixture-testable design. If TASK-011 has not landed, the scan still ships and passes vacuously — coordinate ordering with the orchestrator if simpler to invert.
6. Self-tests for both scanners: unit tests against fixture strings/modules — a violating fixture fails, a clean fixture passes. No scratch-commit tricks: the scanners are tested as functions.
7. Coverage measurement wired (report generated locally; floors are *recorded* in later tasks, not enforced here).

## Files / Areas Likely Affected
- `Tests/MomoCoreTests/…`, `Tests/MomoKitTests/…`, `Tests/MomoCharacterTests/…` (package)
- `MomoUITests/…`, `MomoWatchUITests/…` (app project)
- Scan sources + fixtures (suggest `Tests/MomoCoreTests/Support/`)

## Dependencies
- TASK-009 (package + app targets exist).

## Constraints
- Jupiter model, fresh agent, no commit by agent.
- No product logic in this task — harness only.
- Scans must be fast and deterministic (no network, no subprocess flakiness).

## Acceptance Criteria
- AC-1: `swift test` runs all three package test targets green on macOS.
- AC-2: `xcodebuild test` runs both UI-test targets green on the pinned simulators.
- AC-3: Import-whitelist scan fails on a violating fixture (non-Foundation import) and passes `MomoCore` as it stands; whitelist documented.
- AC-4: Banned-vocabulary scan fails on a fixture containing a banned term and passes clean fixtures; the banned list is sourced from 04 §10.2 verbatim.
- AC-5: Framework pin resolved; any 05 Appendix B item owned here (swift-test hostability if re-owned from TASK-009, framework) marked resolved with evidence.

## Required Tests
- The scanner self-tests (AC-3/AC-4) + the five smoke tests. Evidence: `swift test` and `xcodebuild test` outputs in Implementation Notes.

## Review Requirements
- Fresh reviewer verifies: target set matches 05 §10.1; scanners enforce exactly the documented rules (no extra vocabulary, no missing whitelist entries); self-tests genuinely exercise failure paths; no product logic smuggled in. Record in `.claude/tasks/reviews/REVIEW-TASK-010.md`.

## Git Requirements
- Branch: `feature/EPIC-002-foundation`
- Commit: `test(bootstrap): TASK-010 scaffold test targets with import-whitelist and banned-vocabulary scans`
- Push to origin after orchestrator commit; record hash in Completion Evidence.

## Status
TODO (blocked by TASK-009)

## Implementation Notes
- (agent fills in)

## Reviewer Findings
- (orchestrator records)

## Completion Evidence
- (commit hash + push, by orchestrator)
