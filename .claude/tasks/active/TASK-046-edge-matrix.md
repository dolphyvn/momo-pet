# TASK-046 — §32 edge-case matrix execution (05 §10.5)

## Parent Epic

EPIC-009 — Polish, QA & Release Readiness (epic file `.claude/tasks/epics/EPIC-009-release-readiness.md`, TASK-046 row). Normative source: `docs/architecture/05-technical-architecture.md` §10.5 (matrix at :622-635); FR-11 AC-3; NFR-7.

## Objective

Every row of the normative 05 §10.5 edge-case matrix EXECUTED — not merely mapped. An R0 body-level audit table maps each of the ten rows to its existing name-precise, body-verified tests; rows already covered are RECORDED with fresh green execution pointers from this session; real execution gaps are CLOSED with new tests in the correct suite; the two n/a-Phase-1 permission rows are recorded as such with citations. Builds on the TASK-020 (Core fold matrix) and TASK-024 (Kit store/migration suites) work; fills real execution gaps rather than duplicating green tests — which explicitly permits a zero-new-tests outcome IF the audit table proves it.

## Context

- Standing baselines at task start: `swift test` 1161/113 green; MomoKit coverage 90.84 % lines (floor 80); both builds BUILD SUCCEEDED on pinned sims; `MomoWatchUITests` 9/9; app UI suite 35/35. TASK-045 (05 §12 budgets) just closed DONE (`c43c92b`, review APPROVED_WITH_MINOR_NOTES).
- **Pinned simulators:** iPhone SE 3rd gen `1F25E487-A78E-464C-95AF-0BD1A9B3E1BE` (primary); Watch SE 3 44mm `8A854895-225C-411B-89C1-B03337BFE957` (watchOS 26.5, build/UI baseline); EPIC-009 matrix legs when needed: Watch SE 3 40mm `F0A75761-CB62-4812-A1C4-8E682A3F02FB`, Series 11 42mm `EB5715E3-E528-4139-B768-2898AF583EC5`, iPhone 17 Pro `8E57D4E0-FAA2-499F-8FC6-E0B50AE855BA`. Verify with `xcrun simctl list devices available` and use what the host reports. The pinned iPhone sims are UNPAIRED — that is exactly the posture R1a's "Watch unavailable" leg wants; use it as-is and record it.
- TASK-020's Core fold coverage (name-precise pointers observed at contract time in `Tests/MomoCoreTests/TimeFoldTests.swift` — VERIFY AT BODY LEVEL, never trust this contract's line numbers blindly): :552 "a timezone change mid-day causes AT MOST one rollover" · :176/:209 the named 2026 DST fall-back/spring-forward nights · :386/:410 midnight rollover exactly-once in-session across evaluate/interaction/report paths · :469/:504 absent-day ledger + seven absent days (FR-12) · :530 backward-clock folds nothing. `GreetingSelectionTests` :39/:54 the missedYou warm-return legs.
- TASK-024's Kit coverage: `MigrationChainTests` carries the upgrade row — version-order walks, missing-hop unreadability, checksum fall-through, re-persist-at-current, and :290 "a state loaded through migration equals the equivalent freshly-built state (NFR-7 parity)".
- **Candidate REAL GAPS (R0 must verify each; this is a starting hypothesis, NOT a verdict):**
  - (a) **Watch unavailable** — "iPhone full functionality with zero Watch-dependent code paths (sync is fire-and-forget) — Core + UI": the contract-time census found NO named unavailable/fire-and-forget test. TASK-045's R9 census (WC 7006 "not installed" tolerated while the app stayed fully functional) is adjacent evidence, not a §10.5 execution.
  - (b) **Offline device** — "everything (both devices) — UI smoke offline": no named offline UI smoke found. Both apps have zero network code, so the honest execution is a UI smoke on sims with no network reach, recording that the loop completes and no error surface appears.
  - (c) **Fresh installation** — "onboarding → Enter atomic write; day-1 Q6-forced generation — UI + Core": plan tests (`AppModelOnboardingPlanTests`), the onboarding UI suite, and day-1 Q6 generation tests exist by name; whether the Enter-path write's ATOMICITY is asserted anywhere (the Watch store's temp+rename atomicity is pinned in SnapshotStoreTests — the iPhone Enter path may not be) needs a body check.
  - (d) **Date rollover catch-up** — §10.5 says "in-session + catch-up paths": :410 covers the in-session legs; whether a launch-after-midnight catch-up leg exists needs a body check (fold-at-launch logic may live in the wakefulness/fold path).
- EPIC-009 standing discipline: physical-hardware legs attempt-then-BLOCKED per §25; nothing sim-claimed as device; budget values (none in this task) and product scope untouched.

## Requirements

- **R0 — the §10.5 audit table (mandatory first; TASK-044 R0 precedent).** One row per §10.5 matrix row (all ten), each carrying: the §10.5 normative text VERBATIM; every existing test that covers it by NAME-PRECISE `file:line` citation; a BODY-READ verification (open the test body — confirm it exercises the row's semantics, not a name-match); and a verdict: **ALREADY-COVERED** (with a fresh green execution pointer from this session's run), **GAP** (what exactly is missing), or **N/A-PHASE-1** (rows 4-5, with the §10.5 + 05 §11.4 citations). The table lands in this file's Implementation Notes. Suite misattribution is a review finding (REVIEW-TASK-044 F-1 precedent).
- **R1 — close the gaps R0 actually finds** (the candidate list above is hypotheses, not obligations). For each real GAP: new tests in the CORRECT suite (Core fold → `Tests/MomoCoreTests/`; Kit store/sync → `Tests/MomoKitTests/`; UI smoke → the app UI test target), minimum diff, each new test carrying a one-line provenance comment citing its §10.5 row. Expected shapes, to verify then implement only what is real:
  - **R1a Watch unavailable:** a UI smoke completing the core loop on an unpaired iPhone sim (full functionality; no Watch-dependent stall), plus a Core/Kit-level pin that snapshot pushes are failure-tolerant (a failed push never propagates into the interaction path — fire-and-forget). Do NOT weaken any sync guard; do NOT add production code paths.
  - **R1b Offline device:** the honest UI smoke offline — pinned sims, connectivity absent, both apps' loops complete, no error surface. Record exactly what was executed and what "offline" means on a simulator (no reachability); do not fake a network cut that wasn't performed.
  - **R1c Fresh install:** the Enter-atomic-write leg if R0 confirms it missing — assert the onboarding completion write reaches disk only atomically, reusing the store's existing atomic-write seam. Do not invent a new write path.
  - **R1d Date-rollover catch-up:** only if R0 shows a real hole after the body read.
- **R2 — n/a rows:** record "No Health permission" and "Notification permission denied" as n/a-Phase-1 exactly per §10.5 (no HealthKit; no notification flows; zero Info.plist permission strings per 05 §11.4 — no permission dialog can exist).
- **R3 — execution evidence:** every ALREADY-COVERED row re-executed green in this session's `swift test` run (or the relevant UI suite) with the pointer recorded; every new test proven non-vacuous per house style (mutation bite or fixture-negative control; a simple assertion test needs a truthful one-line rationale if a bite is impractical).
- **R4 — stop-on-failure discipline:** no production-source changes are expected. If any row FAILS against production behavior, STOP, record a BLOCKED finding in Implementation Notes, and end the handoff — the orchestrator adjudicates (a frozen-surface bug is escalated to a new adjudicated task, never fixed opportunistically — epic constraint).
- **R5 — §19 gates at session end:** `swift test` green (record exact counts); both scheme builds BUILD SUCCEEDED on the pinned sims; the app UI suite green if the app UI target was touched (new baseline = 35 + additions); the Watch UI suite only if touched. Repo hygiene: porcelain shows exactly the expected task-doc entries; stash 0.
- **R6 — honest recording:** every executed leg carries a surface label (sim name/OS version); nothing device-claimed; n/a rows and any attempt-then-BLOCKED legs recorded per §25; evidence files under `.claude/tasks/evidence/TASK-046/` (small text files; no traces/bundles). DISK: the host volume is at ~critical free space — check `df -h /` before heavy legs; keep evidence small; clean probe artifacts; if ENOSPC threatens, record it and stop rather than truncate evidence.

## Files / Areas Likely Affected

- `Tests/MomoCoreTests/` (fold gaps), `Tests/MomoKitTests/` (unavailable-push tolerance / store legs), the app UI test target (offline/unavailable smokes), this task file, `.claude/tasks/evidence/TASK-046/`.
- **Production surfaces expected UNTOUCHED:** `Sources/MomoCore/`, `Sources/MomoKit/`, `Sources/MomoCharacter/`, `Apps/**`, `Momo.xcodeproj/`.

## Dependencies

- TASK-020 (Core fold matrix) DONE, TASK-024 (Kit suites) DONE — both merged. Depends on nothing else in EPIC-009 (TASK-045 DONE).

## Constraints

- Frozen surfaces stay frozen (epic constraint): `Sources/MomoCore/`, `Sources/MomoCharacter/`, `Apps/Momo/**`, `Apps/Shared/MomoCopy.xcstrings`, `Momo.xcodeproj/`. (`Tests/` are NOT frozen.)
- Scope control (§22/§24): execute the matrix; no new features; no new production code paths; no schema changes — the upgrade row EXECUTES the existing migration chain, it does not add a version.
- All agents Jupiter. The implementer does NOT commit (§9).
- Verify every claim at source; report actual state (§25).

## Acceptance Criteria

- AC-1: the R0 audit table exists, complete over all ten §10.5 rows, every pointer name-precise and body-verified.
- AC-2: every row lands ALREADY-COVERED (fresh green execution pointer), GAP→closed (the new test, non-vacuous), or N/A-PHASE-1 (citation). No row unmapped.
- AC-3: all §19 gates green at the final tree; exact counts recorded in Completion Evidence.
- AC-4: zero production-source diff; frozen surfaces diff-empty.
- AC-5: the §28 handoff is complete and truthful — no sim claimed as device, no n/a row claimed as executed, no gap claimed closed that wasn't.

## Required Tests

- New: whatever R0's real gaps demand (expected 2-8 tests across Core/Kit/UI). If R0 closes with zero gaps, record that honestly with the full table.
- Standing: `swift test` (1161/113 + additions); both builds; app UI suite if touched; Watch UI suite if touched.

## Review Requirements

- Independent fresh §10/§33 reviewer (Jupiter, not primed): re-derives the §10.5 row list from `05-technical-architecture.md` §10.5 BEFORE reading this file's Implementation Notes or the R0 table; body-reads every pointer; runs own probes (at minimum: one misattribution hunt per audit row class + one non-vacuity check per new test); re-runs `swift test` + both builds. Findings recorded in `.claude/tasks/reviews/REVIEW-TASK-046.md`; CHANGES_REQUIRED/BLOCKED gates the commit (§10/§11).

## Git Requirements

- Implementer: NO commit. Orchestrator: one atomic commit after review approval — `<type>(<scope>): TASK-046 <summary>` — carrying the task record, REVIEW-TASK-046, and the evidence set; push; status.md updated (§12/§13).

## Status

READY (contract authored 2026-09-12; fresh Jupiter implementer dispatch is the next action).

## Implementation Notes

(filled by the implementer)

## Reviewer Findings

(filled at review)

## Completion Evidence

(filled at closeout)

## Handoff protocol

End the final report with a freshly-typed marker line: the word HANDOFF-COMPLETE, one space, then TASK-046. Type it fresh in your own final message — exactly once, on its own line, at column 0, as the last line of the handoff.
