# TASK-009 — Create the Local Swift Package + App Targets with Placeholder Shell

## Parent Epic
EPIC-002 — Foundation & Build Baseline

## Objective
Create the real product skeleton per ADR-005: a local Swift package defining `MomoCore` (Foundation-only), `MomoCharacter`, and `MomoKit` with **zero external dependencies**, plus the `Momo` (iOS) and `MomoWatch` (watchOS) app targets consuming it — both launching in their simulators with a placeholder shell, applying the TASK-008 pins, and proving `swift test` hostability.

## Context
05 §2 fixes the module map and dependency rules D-R1–D-R6 (`MomoCore` ← `MomoCharacter`/`MomoKit`; app targets may import all three; Core imports Foundation only). The repo currently contains **no code and no Xcode project**. ADR-005 ratified the local-SPM packaging. The first vertical slice's "Launch" leg begins here (delivery plan §4.2). The Xcode-*project* authoring mechanism is a build-tooling choice (not a product dependency): prefer a committed, text-diffable project description (e.g., XcodeGen `project.yml`) so reviews see diffs; if that tool is unavailable, a hand-authored project file is acceptable — record the choice and rationale in Implementation Notes (product's zero-third-party rule D-R6 applies to app code, not build tooling).

## Requirements
1. `Package.swift` (or equivalent package manifest) defining:
   - `MomoCore` — Foundation imports only (D-R1); no other imports, no resources yet.
   - `MomoCharacter` — depends on `MomoCore`; may import SwiftUI (empty placeholder source for now).
   - `MomoKit` — depends on `MomoCore`; empty placeholder source.
   - Zero external package dependencies (D-R6).
2. App targets consuming the package (pins from ADR-008 applied):
   - `Momo` (iOS): placeholder Home with the 3-tab structure Home · Room · Settings (UX-1) and a placeholder pet-canvas rectangle; tab bar real, content placeholders.
   - `MomoWatch` (watchOS): a single placeholder glance view in the W1 spirit (static placeholder, no logic).
   - Both targets: correct bundle IDs, deployment targets per ADR-008, app icons may be placeholders.
3. Verification (record evidence):
   - `xcodebuild -scheme Momo -destination <pinned iPhone>` builds; same for `MomoWatch` on a pinned watch simulator.
   - Both apps launch in their simulators showing the placeholder shells (screenshots or simulator boot evidence).
   - `swift test` runs on macOS with empty-but-present test targets (hostability VERIFY item from 05 Appendix B resolved or explicitly re-owned to TASK-010 if the test targets land there — do not silently drop it).
4. Resolve the swift-test-hostability VERIFY-AT-BUILD item (05 Appendix B): package test targets runnable via `swift test` on macOS. If a toolchain limitation appears, record it and re-own the item explicitly to TASK-010 with rationale.

## Files / Areas Likely Affected
- Creates `Package.swift`, `Sources/MomoCore|…`, `Sources/MomoKit|…`, `Sources/MomoCharacter|…` (placeholder sources)
- Creates the Xcode project (or `project.yml` + generated project) with `Momo` and `MomoWatch` targets
- Creates top-level app source folders (`Apps/Momo`, `Apps/MomoWatch` or per the project layout the agent records — layout decision documented in Implementation Notes)

## Dependencies
- TASK-008 (pins must exist; ADR-008 is the source for targets/devices).

## Constraints
- Jupiter model, fresh agent, no commit by agent.
- No domain logic, no persistence, no sync, no real UI beyond placeholders (scope: EPIC-002 Non-Goals).
- No third-party runtime dependencies (D-R6). Build tooling choice allowed per Context.
- Every module boundary must already respect D-R1 (TASK-010's import-whitelist scan will enforce it mechanically next).

## Acceptance Criteria
- AC-1: Package defines `MomoCore`/`MomoCharacter`/`MomoKit` with the ADR-005 dependency edges and zero external dependencies.
- AC-2: `Momo` builds and launches on the pinned iPhone simulator with the 3-tab placeholder shell; `MomoWatch` builds and launches on the pinned watch simulator with its placeholder glance.
- AC-3: Deployment targets match ADR-008 exactly.
- AC-4: `swift test` runs green on macOS (empty suites); swift-test-hostability VERIFY item resolved or explicitly re-owned with rationale.
- AC-5: Build-tooling and project-layout decisions recorded in Implementation Notes.

## Required Tests
- Build verification for both simulators (05 §10.1) + `swift test` (empty suites) — evidence recorded.
- No functional tests yet (no logic exists); TASK-010 adds the harness.

## Review Requirements
- Fresh reviewer verifies: module map vs ADR-005/05 §2; zero-dependency rule; pins applied; placeholder scope not exceeded (no smuggled domain/UI logic); build evidence genuine (CLAUDE.md §25). Record in `.claude/tasks/reviews/REVIEW-TASK-009.md`.

## Git Requirements
- Branch: `feature/EPIC-002-foundation`
- Commit: `feat(bootstrap): TASK-009 create Swift package and app targets with placeholder shell`
- Push to origin after orchestrator commit; record hash in Completion Evidence.

## Status
TODO (blocked by TASK-008)

## Implementation Notes
- (agent fills in)

## Reviewer Findings
- (orchestrator records)

## Completion Evidence
- (commit hash + push, by orchestrator)
