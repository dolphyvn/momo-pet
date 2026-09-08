# TASK-013 — Domain-Model Property Tests

## Parent Epic
EPIC-003 — Pet Domain Model

## Objective
Prove the TASK-012 domain model against the PRD §3.1–3.2 tables exhaustively — full-range sweeps (not samples) over bands and bond stages (FR-9 AC-1's property) — and demonstrate that no numeric-leakage types exist (FR-9's core rule "UI presents bands, never raw numbers" + FR-9 AC-4's domain half; the UI-rendering half is EPIC-007), making "the domain matches the PRD" a mechanically checked fact before any engine dynamics exist. (Citation corrected per REVIEW-TASK-013 NITPICK-1.)

## Context
TASK-012 ships the types and derivations with focused unit tests only; this task adds the exhaustive property layer the delivery plan calls out for EPIC-003's acceptance ("band/invariant property tests green headlessly") and FR-9 AC-1. Swift Testing parameterized tests make full-range sweeps cheap: 0…100 for mood/energy band inputs, 0…1000 for BondStage inputs. Attractor/floor/ceiling dynamics are engine territory (EPIC-004) and OUT of scope — here only the static band/stage mappings.

## Requirements
1. Exhaustive band property tests: for every input 0…100, `makeMoodBand` and `makeEnergyBand` return exactly the PRD §3.1–3.2 band for the 20/45/75 cut-offs (both boundaries: 20/45/75 themselves included, per the PRD table's boundary semantics).
2. Exhaustive stage property tests: for every input 0…1000, `makeBondStage` matches the 149/399/749 thresholds (boundaries included per PRD).
3. Single-source verification: the tests read thresholds from the same single-source constants TASK-012 defined (no re-hardcoded 20/45/75/149/399/749 in test code) — the property being tested is mapping-correctness, while the threshold VALUES are pinned by dedicated constant-vs-PRD assertions so a silent constant change still fails.
4. No-numeric-leakage check (FR-9's core rule "UI presents bands, never raw numbers" — §3.1 presentation mandate; FR-9 AC-4's domain half; citation corrected per REVIEW-TASK-013 NITPICK-1): assert the public API exposes bands/stages as their enum/derivation types only — no public raw numeric band fields a consumer could branch on, and the band/stage case SETS are pinned so a new payload-bearing case cannot silently evade the check (REVIEW-TASK-013 MAJOR-1). (Compile-time/API-shape assertions where possible; document the method.)
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
APPROVED_WITH_MINOR_NOTES (REVIEW-TASK-013 as revised after fix round 1: MAJOR-1 fixed+verified via Probe D build-failure, MINOR-1 documented, NITPICK-1 corrected at contract source — committing per §12)

## Implementation Notes
- **Agent / repo state at start:** fresh implementation agent; HEAD verified `6d08f0850a4d101ff08057202ffc8eae4b46fdbd` on `feature/EPIC-003-domain-model`, clean tree. Model: session default (Jupiter inherited, no override).
- **Baseline (before any change):** `swift test` → `✔ Test run with 64 tests in 11 suites passed after 0.012 seconds.` (TASK-012's count reproduced verbatim).
- **Test-file layout (3 new files, 15 new `@Test` declarations, zero source changes):**
  - `Tests/MomoCoreTests/DomainPropertySweepTests.swift` (4 tests) — the AC-1 sweeps: 3 Swift Testing parameterized tests over the full PRD domains — mood `0...100` (101 cases), energy `0...100` (101 cases), bond `0...1000` (1001 cases) — every boundary value included as an argument (19/20/44/45/74/75/100 and 0/149/150/399/400/749/750/1000), plus a full-sweep idempotence test (Requirement 5).
  - `Tests/MomoCoreTests/ThresholdsPinnedToPRDTests.swift` (8 tests) — the AC-2 anti-regression layer: constant-values-vs-PRD-literal pins, partition-tiling properties, PRD-literal edge mappings (details below).
  - `Tests/MomoCoreTests/NoNumericLeakageTests.swift` (3 tests) — FR-9 AC-1's domain half; method documented in the file header.
- **Threshold-pinning approach (how the pins avoid constant-echoing):** two independent layers, per Requirement 3. (1) The sweeps' expected partitions are computed from the same `Thresholds` constants the derivations read — written in a deliberately DIFFERENT formulation (ascending integer partial-range `switch` with `..<Int(cut-off)`) than the implementation's descending `Double` `>=` cascade, so an off-by-one or case mix-up cannot be mirrored on both sides (a constant drift, however, leaves both sides self-consistent — that is layer 2's job). (2) `ThresholdsPinnedToPRDTests` compares the constants to PRD §3.1–3.3 numbers AS LITERALS; the edge-mapping tests use PRD literals on BOTH sides (input value and expected band name), so nothing can echo. Sweep bounds are the PRD domain literals `0...100` / `0...1000` (domain bounds, not cut-offs — outside Requirement 3's forbidden list of 20/45/75/149/399/749). Tiling properties derive the four ranges from the constants, assert contiguity + exact coverage from the constants alone (gap/overlap/total-size), then compare the derived ranges to the PRD literal ranges verbatim; the band constants' integrality is asserted explicitly so the `Int()` derivation is provably lossless.
- **Leakage-check method (Requirement 4; documented in the file header):** three reflection/existential layers over the compiled types — (1) `value as? any RawRepresentable == nil` for every case of MoodBand/EnergyBand/BondStage (catches a raw-value enum); (2) `Mirror(...).children.isEmpty` per case (catches associated-value payloads and struct-ification, i.e. the "public let value: Int" reshape); (3) exact field inventories of `PetState` and `CharacterDisplayState` (exact label lists, exact metatypes for band/stage fields, numeric-typed label inventory == exactly the D10 internal scalars / empty on the read-model, and `.bondStageReached`'s payload `is BondStage`). **Non-vacuity proven by mutation probes** in a throwaway `/tmp` copy of the repo (destroyed after use; the real repo untouched): P1 MoodBand → `Int` raw values ⇒ layer 1 fails (4 issues, one per case); P2 MoodBand struct-ified with `public let value: Int` ⇒ layer 2 fails (4 issues); P3 `moodBandValue: Int` added to CharacterDisplayState ⇒ layer 3 fails (2 issues); P4 `contentLowerBound` silently 45→46 ⇒ **pin suite fails on 4 tests while the constant-fed sweeps stay green** (the exact AC-2 scenario: sweeps alone cannot catch constant drift; pins do); P5 derivation `>=`→`>` off-by-one ⇒ mood sweep fails exactly at boundary 75.
- **Verbatim test evidence (final):**
  - `✔ Test "mood band: every integer 0…100 matches the PRD §3.1 partition" with 101 test cases passed after 0.034 seconds.`
  - `✔ Test "energy band: every integer 0…100 matches the PRD §3.2 partition" with 101 test cases passed after 0.019 seconds.`
  - `✔ Test "bond stage: every integer 0…1000 matches the PRD §3.3 partition" with 1001 test cases passed after 0.055 seconds.`
  - Suites `Domain property sweeps (TASK-013)`, `Thresholds pinned to PRD §3.1–3.3 (TASK-013, AC-2)`, `No numeric leakage out of bands/stages (TASK-013, FR-9 AC-1 domain half)` — all passed.
  - `✔ Test run with 79 tests in 14 suites passed after 0.058 seconds.` (baseline 64/11 + 15 new tests + 3 new suites; Swift Testing counts each parameterized function as one test carrying its case count).
- **Coverage (informational only; floors unenforced until TASK-020/024):** `swift test --enable-code-coverage` + the TASK-010 llvm-cov command → `Sources/MomoCore/Bands.swift` **100.00 %** lines/regions/functions; all three new test files 100 %; TOTAL **92.06 %** lines / 95.44 % functions. (`DayKey.swift` 50 % and `SettingsState.swift` 0 % are pre-existing TASK-012-era numbers — informational, not this task's scope.)
- **Standing scans + hygiene:** D-R1 import-whitelist scan and banned-vocabulary scan green in-suite (among the 79). `grep -rnE "print\(|TODO|FIXME|HACK|TEMP"` over the three new files → no matches. Imports are `Testing` + `@testable MomoCore` only; no clock, no RNG, no Foundation needed. `git status` = the 3 new test files + this task file's status/notes edit; `Sources/`, `Package.swift`, docs untouched.
- **Judgment calls flagged for reviewer scrutiny:**
  1. *Sweep granularity:* parameterized over INTEGER values only (101/1001). The task text specifies "0…100"/"0…1000" sweeps; the `Double` domain's sub-integer points are covered by TASK-012's focused 19.5/44.5/74.5 boundary tests, and the derivations are monotone step functions fixed at every integer by these sweeps. Recorded as the honest reading of AC-1.
  2. *Counting:* 79/14 is the Swift Testing headline (parameterized = 1 test + N cases); the exhaustive case counts are the 101/101/1001 lines above.
  3. *Deliberate overlap with TASK-012 tests:* `ThresholdsPinnedToPRDTests` re-pins values TASK-012's `thresholdsMatchPRD`/boundary tests already cover. Intentional: the AC-2 PRD-literal layer must be self-contained in TASK-013's files, and the constraint allowed only new test files — TASK-012's tests are byte-untouched.
  4. *Leakage scope:* reflection covers the two types that carry band/stage state (`PetState`, `CharacterDisplayState`) + the derivation outputs + the moment payload; the UI-rendering half of FR-9 AC-4 ("no surface renders numbers") is EPIC-007's. Stated in the file header.
  5. *Quest constants* (`questsPerDay` 3, windows 12/20/7) deliberately NOT re-pinned here — already pinned by TASK-012's suite and outside this task's band/stage scope (§22).
  6. *Fixtures:* fixed scalar values, `lastFedAt: nil` — no ambient `.now` anywhere in the new tests (cf. REVIEW-TASK-012 NITPICK-2).
- **Fix round 1 (REVIEW-TASK-013 MAJOR-1/MINOR-1):** fresh fix agent; `feature/EPIC-003-domain-model` @ `6d08f0850a4d101ff08057202ffc8eae4b46fdbd`; model session default (Jupiter inherited). Touched ONLY `Tests/MomoCoreTests/NoNumericLeakageTests.swift` + this task file; no existing test, assertion, or import weakened/reordered/renamed.
  - *MAJOR-1 (case-set pin):* added one default-free exhaustive-switch name helper per type — `prdCaseName(of:)` overloads for `MoodBand`/`EnergyBand`/`BondStage` (INV-8's pattern, no `default:` clause; each case returns its Swift case name, PRD display names in trailing comments). Adding or removing any case of the three types now breaks compilation of the leakage test file itself, so layers 1–2's "for every case" loops are compile-time total and Probe D's `case historic(Int)` shape fails to BUILD. A new focused `@Test` (`bandStageCaseSetsPinned`) asserts each helper's outputs equal the PRD §3.1–3.3 case-name sets in order, so the helpers cannot silently rot into no-ops. Header METHOD gains layer 4; NON-VACUITY gains the case add/remove mutation class.
  - *MINOR-1 (blind-spot note):* header gains a "KNOWN BLIND SPOT" paragraph — the reflection layers inspect STORED fields only (`Mirror` reflects stored properties); computed members, subscripts, and extension members are invisible to this method and are covered by review instead (standing note tracked in status.md by the orchestrator).
  - *Verbatim test evidence:* `✔ Test "band and stage case sets are exactly the PRD §3.1–3.3 sets — a new case fails to build" passed after 0.006 seconds.` · `✔ Test run with 80 tests in 14 suites passed after 0.058 seconds.` (79/14 + the one new non-parameterized @Test; the 101/101/1001 sweep case lines unchanged, still 1203 parameterized cases).
  - *Fix verification (throwaway /tmp copy, destroyed after; repo untouched):* re-created Probe D — added `case historic(Int)` to `MoodBand` → test target fails to build with `error: switch must be exhaustive` at `NoNumericLeakageTests.swift:78:9` (the `prdCaseName(of: MoodBand)` switch). The MAJOR-1 hole is closed at compile time.
  - *Hygiene re-verified:* `grep -rnE "print\(|TODO|FIXME|HACK|TEMP|\.now|Date\(\)|RandomNumberGenerator|UUID\(\)|random"` over `NoNumericLeakageTests.swift` → no matches. Imports unchanged (`Testing` + `@testable MomoCore`). The word `default` appears only in doc comments describing the switches as default-free — no `default:` clause exists.

## Handoff

### Completed
- Requirements 1–5 implemented: exhaustive 0…100 mood/energy sweeps (101 cases each), exhaustive 0…1000 stage sweep (1001 cases), thresholds-vs-PRD literal pinning + tiling properties + PRD-literal edge mappings, three-layer no-numeric-leakage check, determinism idempotence test.
- AC-1 MET (full-range sweeps pass headlessly). AC-2 MET (constants pinned to PRD literals; anti-echo proven by probe P4). AC-3 MET (leakage check exists, passes, method documented, non-vacuity proven by probes P1–P3). AC-4 MET (baseline 64/11 preserved; final counts recorded below; standing scans green).
- Constraint compliance: new test files only; zero source changes; no print; no TODO/FIXME/HACK/TEMP; no new dependencies; no clock/RNG; no scope creep into engine dynamics, satiety derivation, or DisplayState construction.

### Files Changed
- `Tests/MomoCoreTests/DomainPropertySweepTests.swift` (new)
- `Tests/MomoCoreTests/ThresholdsPinnedToPRDTests.swift` (new)
- `Tests/MomoCoreTests/NoNumericLeakageTests.swift` (new)
- `.claude/tasks/active/TASK-013-domain-property-tests.md` (status + this section)

### Tests Run
- `swift test` (baseline, pre-change) — 64 tests / 11 suites.
- `swift test` (final) — 79 tests / 14 suites.
- `swift test --enable-code-coverage` + `xcrun llvm-cov report .build/arm64-apple-macosx/debug/MomoPackageTests.xctest/Contents/MacOS/MomoPackageTests -instr-profile .build/debug/codecov/default.profdata` (informational).
- Mutation probes P1–P5 in a `/tmp` throwaway copy (leakage layers, pin anti-echo, sweep sensitivity).

### Test Results
- Final: `✔ Test run with 79 tests in 14 suites passed after 0.058 seconds.` — sweeps carry 101 + 101 + 1001 = 1203 cases; all TASK-010/011/012 suites still green; D-R1 + banned-vocabulary scans green in-suite.
- Coverage: Bands.swift 100.00 % lines; TOTAL 92.06 % lines (informational; floors unenforced until TASK-020/024).

### Known Issues
- None blocking. Note: sub-integer `Double` inputs between integers are not swept (see Implementation Notes judgment call 1; TASK-012's focused .5-boundary tests cover the representative points). Pre-existing informational coverage gaps (`SettingsState` 0 %, `DayKey` 50 %) are TASK-012-era, not this task's scope.

### Decisions Made
- Two-layer pin design (constant-fed sweeps + PRD-literal pins) exactly per Requirement 3; integer partial-range formulation chosen for the expected partitions so off-by-one bugs cannot be mirrored.
- Leakage check via runtime reflection + existential casts over compiled types (see Implementation Notes); non-vacuity demonstrated by five mutation probes, then the probe tree destroyed.
- Sweep bounds as PRD domain literals (0…100 / 0…1000) rather than constant-derived, so the sweep domain cannot silently shrink with a constant drift.
- Deliberate self-contained duplication of threshold pins (TASK-012 tests untouched).

### Reviewer Status
- Not yet reviewed — fresh adversarial reviewer to be dispatched by the orchestrator (per §10/§33; review record target: `.claude/tasks/reviews/REVIEW-TASK-013.md`). Suggested scrutiny: exhaustiveness/boundary semantics vs the verified partition (PRD inclusive ranges; first-value cut-offs), pin non-echoing (probe P4 evidence), leakage-method soundness (probes P1–P3), the six flagged judgment calls in Implementation Notes.

### Commit
- None (agent does not commit — §9). Suggested: `test(domain): TASK-013 exhaustive domain-model property tests`.

### Push
- None (follows the orchestrator's commit).

### Recommended Next Step
- Fresh reviewer over the three new test files + this task file; after APPROVED disposition, orchestrator commits and pushes, records the hash, updates status.md, then EPIC-003 merges to `main` per the §14 rule.

## Reviewer Findings
- **REVIEW-TASK-013 — CHANGES_REQUIRED → fix round 1 → REVISED VERDICT: APPROVED_WITH_MINOR_NOTES** (full record + verification + orchestrator disposition in `.claude/tasks/reviews/REVIEW-TASK-013.md`). Original review: all counts/coverage reproduced (79/14; 101+101+1001=1203 cases; Bands 100 %, TOTAL 92.06 % lines); two-layer pin separation proven empirically (constant 45→46 → pins fail 4/4, sweeps stay green; `>=`→`>` → mood sweep fails exactly at 75); **MAJOR-1**: `case historic(Int)` on MoodBand passed the full suite (case sets unpinned); **MINOR-1**: computed members invisible to Mirror (documented-scope blind spot); **NITPICK-1**: FR-9 AC-1 citation wobble from the task contract. Fix round 1 (fresh fix agent): default-free exhaustive-switch case-set helpers + PRD-literal name-set test + KNOWN BLIND SPOT header paragraph. Verification (same reviewer, §11): Probe D re-run → `swift build --build-tests` fails with `error: switch must be exhaustive` — MAJOR-1 materially closed; 80/14 green; nothing weakened; NITPICK-1 verified fixed. All six implementer judgment calls adjudicated sound (notably: integer sweeps + asserted-integral constants determine the whole Double domain).

## Completion Evidence
- (this commit) — `test(domain): TASK-013 exhaustive domain-model property tests`, pushed to origin `feature/EPIC-003-domain-model`. Final suite: 80 tests / 14 suites (sweeps 101+101+1001 cases). Post-disposition `swift test` (orchestrator, after disposition edits): `✔ Test run with 80 tests in 14 suites passed` — D-R1 + banned-vocabulary standing scans green in the same run.
