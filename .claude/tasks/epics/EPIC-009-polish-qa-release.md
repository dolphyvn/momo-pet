# EPIC-009 — Polish, QA & Release Readiness

## Objective
Take the feature-complete product to releasable quality: verify every 05 §12 performance budget on the pinned device matrix, execute the complete §32 edge-case matrix, run the launch-blocking full accessibility audit across both devices, perform the privacy/security review (FR-20/NFR-5), execute the §44 final product test (philosophy & tone), and clear the release gates — §35 DoD, E4 name clearance, N-1 reconsideration, "Data Not Collected" App Store posture, TestFlight.

## User / Product Value
The promises become verified facts: fast launch, all-day battery, no memory creep, accessible to everyone, provably private, and — the deepest gate — it still feels like quiet companionship, not an engagement machine. This epic is where "no guilt mechanics" is proven, not asserted.

## Scope
- Performance verification (05 §12; NFR-1/2/3/4/9): launch ≤ 2.0 s; 60 fps sustained; iPhone ≤ 150 MB / Watch ≤ 80 MB idle soak; download ≤ 60 MB; energy gauge Low over 10-min idle on both devices; Watch restore ≤ ~2 s; sync cadence on-change only — measured, never assumed; **a miss is a task-level blocker**.
- §32 edge-case matrix execution (05 §10.5): timezone, DST, rollover, Watch unavailable, offline, fresh install, upgrade, 7-day inactivity fold — each row executed with evidence.
- Full accessibility audit (FR-20 AC-2, NFR-6): both devices, every 03 §10 row — launch-blocking.
- Privacy/security review (05 §11; CLAUDE.md §27): network audit = paired link only; no StoreKit/analytics/location/HealthKit; strings-only copy; privacy manifest + required-reason APIs; zero entitlements; secrets scan.
- Philosophy & tone QA (project.md §44; FR-12; 04 §10): every §44 question answered with evidence; banned-vocabulary scan green; §15 bad-copy sweep; simplification question answered.
- Release readiness (§35; E4; ADR-006 N-1): DoD signed item-by-item; E4 trademark search executed; N-1 widening re-evaluated; App Store metadata + privacy label "Data Not Collected"; TestFlight build.

## Non-Goals
New features of any kind (scope freeze — findings become follow-up tasks, not fixes-in-passing), Phase 2 seams, analytics instrumentation (D7), monetization (E1 closed), location (E3 closed).

## Dependencies
- EPIC-007 + EPIC-008 complete (feature-complete product).

## Tasks
Branch: `feature/EPIC-009-release-readiness` (from `main`).

| TASK | Title | Size | Depends on |
|---|---|---|---|
| TASK-045 | Performance budget verification (05 §12, NFR-1/2/3/4/9) | L | TASK-039, TASK-044 |
| TASK-046 | §32 edge-case matrix execution (05 §10.5, FR-11 AC-3, NFR-7) | M | TASK-020, TASK-024 |
| TASK-047 | Full accessibility audit — launch-blocking (FR-20 AC-2, NFR-6, 03 §10) | M | TASK-039, TASK-044 |
| TASK-048 | Privacy & security review (FR-20, NFR-5, 05 §11, CLAUDE.md §27) | M | TASK-039, TASK-044 |
| TASK-049 | Philosophy & tone QA — the §44 final product test (project.md §44, FR-12, 04 §10) | S | TASK-045…048 |
| TASK-050 | Release readiness: gates, E4 clearance, N-1 decision, App Store posture (§35, ADR-006) | M | TASK-049 |

## Acceptance Criteria
1. All 05 §12 budgets measured within limits on the pinned device matrix, evidence recorded; any miss blocks the task (not a note).
2. Every §10.5 edge-case row executed with recorded evidence; upgrade parity holds (NFR-7).
3. Accessibility audit fully green on both devices — zero open blockers (launch-blocking NFR-6).
4. Network audit shows only the paired link; repo/build free of forbidden frameworks; privacy label "Data Not Collected" justified by implementation; secrets scan clean.
5. §44 checklist executed with evidence on the release build, including "Momo feels alive while idle" and "the product avoids guilt and manipulative engagement".
6. §35 DoD checklist signed; E4 clearance executed (risk escalates to owner with search results); N-1 decision recorded; TestFlight build exists.

## Test Requirements
- project.md §32 **Edge cases matrix (complete)** + release audits per 05 §10.5–10.6 and §12: XCTest launch metrics, Instruments traces, energy-gauge sessions, accessibility audits (manual + automated), static privacy scans.
- Standing static scans (import-whitelist, banned vocabulary) green on the release build.

## Definition of Done
All six tasks DONE per CLAUDE.md §18; every §35 DoD condition satisfied with evidence; reviews APPROVED; atomic TASK-ID commits on `feature/EPIC-009-release-readiness`, pushed; epic merged to `main`; orchestrator status update declares Phase 1 release-ready pending owner sign-off.

## Status
TODO
