# EPIC-002 — Foundation & Build Baseline

## Objective
Convert the docs-only repository into a verified, buildable, testable product skeleton: toolchain verified and deployment pins recorded (ADR-008), the local SPM package (`MomoCore` / `MomoCharacter` / `MomoKit`, ADR-005) plus `Momo` (iOS) and `MomoWatch` (watchOS) app targets launching placeholder shells, five test targets running under `swift test` with the import-whitelist and banned-vocabulary static harnesses wired, and the design-system token pass complete.

## User / Product Value
No end-user value yet by design. This epic retires TR10 (Xcode availability) and OPEN-3 (bootstrap pins) and guarantees every later epic lands on a green, provably-tested build — the precondition for "domain before UI" and for the first vertical slice.

## Scope
- Xcode verification, deployment-target pins, device-matrix names, iOS↔watchOS pairing rule (ADR-006, OPEN-3) → recorded as **ADR-008**.
- `Package.swift`: `MomoCore` (Foundation-only), `MomoCharacter` (Core + SwiftUI), `MomoKit` (Core); zero external dependencies (D-R6).
- `Momo` + `MomoWatch` app targets consuming the package; placeholder Home / W1 shells; simulator launch.
- Test-target scaffolding per 05 §10.1; Swift Testing framework pinned (VERIFY-AT-BUILD resolved).
- Import-whitelist scan in `MomoCoreTests` (D-R1, 05 §10.2) and banned-vocabulary static scan over String Catalogs (04 §10.2).
- Design tokens: project.md §18 UI tokens + all 8 character slots (04 §8.4), light/dark, as Swift constants; String Catalogs with `momo.line.*` namespaces.

## Non-Goals
Any domain logic (EPIC-003+), real UI beyond placeholder shells, persistence, sync, real character art, onboarding. Phase 2 seams (widgets/HealthKit/notifications) stay untouched.

## Dependencies
- TASK-001…007 complete (Phase 0 documents DONE and amended PRD normative).
- Nothing else — this is the root of the build DAG.

## Tasks
Branch: `feature/EPIC-002-foundation` (from `main`).

| TASK | Title | Size | Depends on |
|---|---|---|---|
| TASK-008 | Verify toolchain & pin deployment targets (TR10, OPEN-3, ADR-006) → ADR-008 | S | — |
| TASK-009 | Create the local Swift Package + app targets with placeholder shell (ADR-005) | M | TASK-008 |
| TASK-010 | Test-target scaffolding + import-whitelist + banned-vocabulary harness (05 §10.1–10.2) | M | TASK-009 |
| TASK-011 | Design-system token pass + String Catalog scaffolding (project.md §18; 04 §8.4) | M | TASK-009 |

Full acceptance criteria per task live in the task files (first batch materialized under `.claude/tasks/active/`); the delivery plan §3 is the backlog of record.

## Acceptance Criteria
1. `Momo` and `MomoWatch` build for their pinned simulators and launch to placeholder shells (launch evidence recorded).
2. `swift test` runs green on macOS across all package test targets.
3. Import-whitelist scan and banned-vocabulary scan exist and demonstrably fail on a deliberate violation (harness self-test).
4. ADR-008 exists, recording deployment pins, device-matrix device names, pairing rule, and test framework — all VERIFY-AT-BUILD bootstrap items resolved (05 Appendix B).
5. Tokens compile into both app targets; no hex color literals downstream (R4); catalogs expose `momo.line.<slot>`, `momo.line.react.<family>`, `momo.line.moment` namespaces.

## Test Requirements
- Harness self-tests (TASK-010): a seeded violation fails each scan.
- Build verification per 05 §10.1: both simulators build and launch; `swift test` green.
- No coverage floors apply yet (no logic exists).

## Definition of Done
All four tasks DONE per CLAUDE.md §18 (implemented → independently reviewed → findings addressed → atomic TASK-ID commits on `feature/EPIC-002-foundation` → pushed). Epic slice increment demonstrable: both placeholder shells launch. Tests green with evidence. Epic branch merged to `main`. `.claude/tasks/status.md` updated by the orchestrator.

## Status
TODO (TASK-008 materialized as READY in `.claude/tasks/active/`; TASK-009–011 TODO pending their in-epic dependencies)
