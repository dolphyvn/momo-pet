# TASK-024 — MomoKit suite audit: §32 persistence + §10.4 sync-matrix Kit rows + ≥ 80 % coverage floor (05 §10.2, §10.4; delivery plan TASK-024)

## Parent Epic
EPIC-005 — Persistence & Sync Logic (MomoKit), task 4 of 4 (size M) — the EPIC CLOSER. Epic acceptance criteria served: AC-6 (MomoKit ≥ 80 % line coverage recorded) plus the audit that AC-1–AC-5's claims each resolve to a named, actually-green test. Follows the TASK-020 precedent (Core's matrix audit + coverage floor) applied to Kit.

## Objective
Close EPIC-005's test obligations (05 §10.2; delivery-plan TASK-024 row):
1. **§32 Persistence matrix audit (project.md §32 rows: save/load, migration, corruption/recovery):** every row resolves to named, green tests in `MomoKitTests` — with the audit's adversarial standard: a named test COUNTS only if reading it shows it actually pins that row's clause (a test that touches the area without pinning the clause does not count — find or write the one that does).
2. **§10.4 sync-matrix Kit-share audit (05 §10.4):** each row's KIT portion maps to named green tests; each row's non-Kit portion (Watch UI test, UI tests, device obligations) is explicitly routed to its owning epic (EPIC-008 / UI-test epics / EPIC-002 VERIFY-AT-BUILD) in the audit table — routed, never silently dropped.
3. **MomoKit ≥ 80 % line coverage floor, measured and recorded (05 §10.2):** llvm-cov recipe, per-file table over the 10 production files, TOTAL recorded; if below floor, close with named tests and re-measure.

**This is an AUDIT-and-floor task, not a rewrite.** TASK-020's finding stands: existing coverage is extensive — the implementer's first job is a VERIFIED GAP ANALYSIS. Expect to write few or zero new tests; every new test must close a named gap from the audit tables, never pad the percentage.

## Context
- **Codebase state:** TASK-023 complete (`9109457`). MomoKit production surface = EXACTLY 10 files: `SnapshotStore`, `StoreRules`, `LedgerRetention`, `MigrationChain`, `SyncDTOs` (`WatchSnapshot`/`IntentEvent`), `IntentJournal`, `SyncState`, `SyncStateStore`, `WatchSnapshotBuilder`, `WatchSyncGate`. Baseline `swift test` = **515 tests / 54 suites green** @ `9109457`.
- **Coverage recipe (TASK-010/TASK-020 precedent, works on this toolchain):**
  `swift test --enable-code-coverage`
  `xcrun llvm-cov report .build/arm64-apple-macosx/debug/MomoPackageTests.xctest/Contents/MacOS/MomoPackageTests -instr-profile .build/debug/codecov/default.profdata`
  (xccov CANNOT read SwiftPM's raw profdata — use llvm-cov directly. Filter to the `Sources/MomoKit` rows.)
- **Precedent for the record:** TASK-020's Completion Evidence carries the per-file table verbatim + TOTAL + exact command + the exact closing-test names for any gap. Mirror that format for Kit. TASK-020's Core TOTAL was 97.68 % — Kit need not match Core's number; it must clear **80 %**.
- **Where the matrix rows already live (audit STARTING points, verify each — do not take this list on faith):**
  - save/load roundtrip, corruption/generation recovery, torn-write windows, concurrency pins → `SnapshotStoreTests`, `SnapshotStoreConcurrencyTests`, `SnapshotStoreGoldenBytesTests`
  - migration (chain walk, missing hop, above-head, corrupt-below-current-never-migrates, fresh-vs-upgrade parity shape) → `MigrationChainTests` + SnapshotStore's version-gate tests; **check whether an explicit NFR-7 fresh-vs-upgrade parity test exists** — if not, that is a REAL gap (epic AC-3: "upgrade path produces identical engine-visible state to a fresh install seeded with the same history")
  - retention/prune determinism, caps → `LedgerRetentionTests` (+ `StoreRulesPinnedTests` pins)
  - codec versioning (DTO round-trips, unknown-version gates), journal (torn line, epoch-matched prune), watermark arithmetic (INV-10 exactly-once property, epoch reset, stale epoch), sync-state durability → the TASK-023 suites
- **Known likely gaps to evaluate (candidates, not conclusions — verify before acting):** an NFR-7 fresh-vs-upgrade parity pin (above); the golden-bytes test being excluded from a coverage run is EXPECTED (it runs out-of-process recording only at authoring time) — do not chase its lines; `assertionFailure`/`print` DEBUG-loud paths are legitimately unexercisable and get a noted reason per TASK-020's format.
- **Kit discipline:** any new test file follows the house conventions (`@Test`/`#expect`, injected directories, no ambient reads, fixtures in `Support/`); the standing scans (`MomoKitDisciplineScanTests`) must stay green with NO new exemptions; no `Sources/MomoCore/` changes; production diff expected EMPTY — any production touch is a DISCLOSURE with justification.

## Requirements
1. **Audit table 1 — §32 Persistence rows:** for each of save/load, migration, corruption/recovery: the clause restated from the docs, the named green test(s) that pin it, and the pin verification (one line: what would break if the clause regressed). Gaps close with named tests.
2. **Audit table 2 — §10.4 sync matrix, all seven rows:** per row, the KIT-share mapping (named green tests) AND the explicit routing of the non-Kit share (owning epic). The seven rows: iPhone→Watch; Watch→iPhone interaction; temporary disconnection; stale data; conflict handling; guard reset; termination/relaunch. Note: several rows' Kit-share is exactly the TASK-023 gate/journal/codec suites — the audit must confirm the named tests pin the row's CLAUSE (e.g. "offline pat applies exactly once after reconnect" is the INV-10 exactly-once property + journal-drain, not merely a gate unit test).
3. **Coverage floor:** run the llvm-cov recipe; produce the per-file table for the 10 MomoKit files + Kit TOTAL; if TOTAL < 80 %, write the named closing tests, re-run, and report the closing set; record command + table + TOTAL in Completion Evidence. Note every file's deliberately-unexercisable lines with reasons.
4. **No scope creep:** no transport, no UI, no engine changes, no MomoCore changes, no new production code unless a gap genuinely requires it (then DISCLOSURE + justification). No schemaVersion bumps. Do not weaken or delete existing tests to move the number — that is a BLOCKED-level finding.
5. **Suite hygiene:** final `swift test` green ×2 with zero warnings; record exact counts; suite runtime stays bounded (no new unbounded loops; any property test is seeded and bounded per house discipline).

## Files / Areas Likely Affected
- Mostly NOTHING in production; possibly NEW `Tests/MomoKitTests/` files for named gap closures (e.g. an NFR-7 parity test) and small additions to existing suites.
- This task file (audit tables in Implementation Notes, coverage table in Completion Evidence).
- NOT affected: `Sources/MomoKit/` (expected diff EMPTY), `Sources/MomoCore/` (must stay EMPTY), docs.

## Dependencies
- TASK-021…023 (all landed on `feature/EPIC-005-persistence`).

## Constraints
- Fresh agent, Jupiter, no commit rights; house 200–400-line file discipline for any new test file; scans green, no new exemptions; baseline count pinned at dispatch by the orchestrator.
- The coverage run is EVIDENCE, not a test — the reviewer reproduces the command and compares tables.

## Acceptance Criteria
1. Audit table 1 complete: all three §32 persistence rows → named green tests, gaps (if any) closed and named.
2. Audit table 2 complete: all seven §10.4 rows → Kit-share mapping + non-Kit routing, nothing silently dropped.
3. MomoKit line coverage ≥ 80 % measured via the llvm-cov recipe; per-file table + TOTAL + exact command recorded; any gap closed with named tests.
4. Final `swift test` green ×2, zero warnings, standing scans green with no new exemptions.
5. Production diff EMPTY (or disclosed + justified); `Sources/MomoCore/` diff EMPTY.

## Required Tests
- The audit's closing tests (only those the gap analysis justifies — expected: an NFR-7 fresh-vs-upgrade parity pin if genuinely absent).
- The coverage measurement run (llvm-cov) with the recorded table.

## Review Requirements
- Independent fresh reviewer (CLAUDE.md §10/§33), adversarial, unprimed:
  - Re-derive BOTH audit tables from 05 §10.4 / project.md §32 and the doc clauses BEFORE comparing to the implementer's tables; name any clause the tables miss or map to a test that does not actually pin it.
  - Re-run the llvm-cov coverage command; compare the per-file table and TOTAL; reject any table that cannot be reproduced.
  - Mutation-bite the audit's central claim: pick ONE audit-mapped clause, apply a small mutation to the production code it pins, and verify the named test ACTUALLY fails (the audit counts only if the mapping is executable truth). Restore byte-identical (record the sha256 before/after).
  - Verify the suite is green ×2 and the scans carry no new exemptions.
  - Verify `git diff` scope: production EMPTY-or-disclosed, MomoCore EMPTY.
  - Review file: `.claude/tasks/reviews/REVIEW-TASK-024.md`.

## Git Requirements
- No commit by the implementation agent. Orchestrator commits after review disposition: `test(kit): TASK-024 MomoKit suite audit, §10.4 mapping, coverage floor` — atomic, TASK-ID included.
- This is the EPIC-005 closer: after this task's housekeeping, the epic merges to `main` per CLAUDE.md §14 (owner-authorized, no PR; `git fetch` + check `origin/main` FIRST; merge only the remainder; never force-push).

## Status
READY — contract materialized by the orchestration agent from 05 §10.2/§10.4, project.md §32, the delivery-plan TASK-024 row (docs/product/06-delivery-plan.md:91), the TASK-010 coverage recipe, and the TASK-020 audit precedent. Baseline count pinned at dispatch.

## Implementation Notes
(implementation agent fills)

## Reviewer Findings
(reviewer fills)

## Completion Evidence
(orchestrator fills at housekeeping)
