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
REVIEWED — disposition applied 2026-09-09 (APPROVED_WITH_MINOR_NOTES, 0 MAJOR; MINOR-1 bookkeeping sentence lands in status.md at housekeeping, MINOR-2 + NITPICK + OBS-A/B/C recorded with no test change required; suite re-verified green; atomic task commit follows this edit — the EPIC-004 closer). Was IN_REVIEW — implementation complete; was READY — contract materialized by the orchestration agent from 05 §10.2–§10.3, the delivery-plan TASK-020 row, the TASK-010 coverage recipe, and the live suite inventory of 37 test files / 42 suites.

## Implementation Notes
Implemented 2026-09-09 by the fresh TASK-020 agent (Jupiter), HEAD `13d27344dc0da79a333487ad6e3dbbc3ccb7d38e`, uncommitted. Method: audit first, close surgically. Suite 363 tests / 42 suites → **369 tests / 43 suites**, all green. **The Requirement 5 defect protocol was NOT triggered: no new test exposed any engine misbehavior — nothing was fixed, no pin weakened, no exemption added, production sources untouched.**

### §10.3 gap-analysis table

Legend: COVERED = clause already pinned by named green test(s), unchanged by this task. ADDED HERE = clause had no literal home; the named test was added by this task (house naming — test names echo the matrix cell).

**Row 1 — Mood/energy transitions**

| Clause | Named test(s) | File | Status |
|---|---|---|---|
| band-mapping property over 0…100 (FR-9 AC-1) | `moodBandSweep`, `energyBandSweep` | DomainPropertySweepTests.swift | COVERED |
| attractor / floor folds (FR-9 AC-2) | `attractorConvergenceMatchesTau`, `couplingAndFloor` (attractor + floor arms), `energyClampsHold`, `morningWakeClampsEnergy`, `wakingHoursDeclineEnergy` | TimeFoldTests.swift | COVERED |
| coupling folds — the downward pull (FR-9 AC-3) | `couplingBandReadsSegmentStart`, `couplingAndFloor` | TimeFoldTests.swift | COVERED |
| coupling self-reversal on energy recovery (FR-9 AC-3) | `couplingSelfReversesOnEnergyRecovery` | TimeFoldTests.swift | **ADDED HERE** |

**Row 2 — Bond progression**

| Clause | Named test(s) | File | Status |
|---|---|---|---|
| cap-by-construction property over random sequences (FR-10 AC-1) | `capByConstruction`; exact-cap pins `threeQuestDayReachesCapExactly`, `twoQuestDayTruncatesVarietyToFour`, `questAwardClamps`, `plateauTruncatesAndLedgerIsExact` | BondLedgerPropertyTests.swift / BondLedgerTests.swift | COVERED |
| monotonicity over random sequences (FR-10 AC-2) | `monotonicAcrossRollover` | BondLedgerPropertyTests.swift | COVERED |
| monotonicity incl. replay (FR-10 AC-2) | `monotonicUnderReplay` (same intent id re-delivered across afternoon, pre-midnight, post-midnight: whole-state no-op each time, bond never decreases) | BondLedgerTests.swift | **ADDED HERE** |
| 1000-pats-zero-bond (FR-10 AC-3) | `thousandPatsMoveExactlyTheHello` (volume banks nothing: +8 hello + 4 first-pat Q1 once, then zero) | BondLedgerTests.swift | COVERED |
| stage crossing once (FR-10 AC-4/5) | `patHelloCrossingEmitsExactlyOnce`, `crossingSurfacesAtNextEvaluation`, `multiStageJumpEmitsCurrentStageOnce`, `freshStateEmitsNothing`; path reconciliation `evaluatePathReconcilesStage`, `interactionPathReconcilesStage`, `reportPathReconcilesStage`; derivation sweep `bondStageSweep` | BondLedgerTests.swift, EngineReduceTests.swift, DomainPropertySweepTests.swift | COVERED |

**Row 3 — Daily reset**

| Clause | Named test(s) | File | Status |
|---|---|---|---|
| midnight rollover exactly once — evaluate path (FR-11 AC-2) | `midnightRolloverExactlyOnce` | TimeFoldTests.swift | COVERED |
| midnight rollover exactly once **across folded spans**, every event path | `midnightRolloverExactlyOnceAcrossFoldedSpans` (one crossing landed via `.evaluate`, one via an interaction intent, one via a character report; each re-delivery is a no-op — never doubles) | TimeFoldTests.swift | **ADDED HERE** |
| absent-day ledger emptiness (FR-12 AC-1) | `absentDayLedgerIsEmpty` (six absent dayKeys → zero records, bond parked, landing day all-zero counters + `helloAwarded == false` + fresh `QuestGeneration.currentEpoch` quest set containing Q1, exact day list) | TimeFoldTests.swift | **ADDED HERE** |
| absence adds only the landing day (FR-11 AC-2 shape) | `sevenDayAbsenceAddsOnlyLandingDay` | TimeFoldTests.swift | COVERED |

**Row 4 — Quest progression**

| Clause | Named test(s) | File | Status |
|---|---|---|---|
| generator 30-day simulation | `thirtyDaySimulation` | QuestGenerationTests.swift | COVERED |
| by-construction candidates | `exhaustiveNonEmptiness` (all 225 valid prior pairs), `randomizedNonEmptiness`, `generatedShape`, `consecutiveRepeatBan`, `banIsSetEquality`, `banCombinedWithRestriction`, `unknownPriorsForceQ6`, `freshInstallDayOneContainsQ6`, `generationTwins`, `seedsVaryTheDay`, `rolloverGeneratesTheLandingDay`, `rolloverNeverRegeneratesAPastDay`, `rolloverPriorGap`, `rolloverExactlyOnceUnderBackwardClock` | QuestGenerationTests.swift | COVERED |
| window checks (Q1/Q6) | pinned boundary tables `q1BoundaryTable`, `q6BoundaryTable`, `q1TickBoundaries`, `q6TickBoundaries`; generation-side `q6WindowRestriction`; tick-side `postNoonPatNeverTicksQ1`, `q6DefersToALaterInWindowCare` | QuestGenerationPinnedTests.swift, QuestGenerationTests.swift, QuestTickTests.swift | COVERED |
| completion auto-tick | `completionIsIdempotent`, `doubleCompletionLoops`, `completionCrossingOrdersTheMoments`, `playCeaseTicksAndEmitsOnTheReport`, `allDoneDayIsQuiet`, `outOfSetNeverTicks`, `expiredDayKeyTicksNothing` | QuestTickTests.swift | COVERED |
| cascade rules incl. the §4.8 letter-of-PRD gap test | `sixRuleTable`, `cascadeTwins`, `cascadeIsTotalOverEveryHour`; the letter-of-PRD gap itself: `tuckInAtTwoAMWithQ1DoneSelectsQ6` (02:00 tuck-in with Q1 done selects Q6), attribution sibling `tuckInAtHalfPastMidnightAttributesToTheNewDay` | QuestCascadeTests.swift, QuestGenerationPinnedTests.swift | COVERED |

**Row 5 — State-engine rules**

| Clause | Named test(s) | File | Status |
|---|---|---|---|
| response-matrix table test (PRD §4 rows × bands × wakefulness) | the per-cell table: `touchGestureZoneMap`, `softBandsKeepTheKeys`, `asleepTouchStirsAndCounts`, `nappingTouchStirs`, `hungryFeedFullMeal`, `sleepyBandFeedBeat`, `recentlyFedNibble`, `fullRefusalZeroEffectStillCounts`, `asleepFeedDeclinesAndCounts`, `nappingFeedDeclines`, `settlingFeedDeclines`, `exhaustedPlayStirsOnly`, `sleepingPlayStirsOnly`, `settlingPlayDeclines`, `midRoundPlayCheers`, `napNotOfferedOutsideDrowsyExhausted`, `napWhileSleepingIsANoOp`, `settlingNapDeclines`, `wakingTouchAndFeedApplyAndWakeSurvives`, `wakingChoreographyDeclines`, `planShapeAndSeams` | InteractionResponseTests.swift | COVERED |
| satiety rows asserting the nibble as normative (I-2/OPEN-5) | `recentlyFedNibble` + `satietyBoundariesExact` | InteractionResponseTests.swift, SatietyWindowTests.swift | COVERED |
| satiety phases | `neverFedIsHungry`, `feedAnchorsTheClock`, `phaseReDerivesEndToEnd`, `responseClassFollowsDerivedPhase` | SatietyWindowTests.swift | COVERED |
| settling + waking decline-warm cells | settling: `settlingFeedDeclines`, `settlingPlayDeclines`, `settlingNapDeclines` + the warm settle-touch cells `gateExactAtTwentyHundred`, `windowThroughTheNight` (care answers, stays `.settling`); waking: `wakingTouchAndFeedApplyAndWakeSurvives`, `wakingChoreographyDeclines` | InteractionResponseTests.swift, CareInteractionTests.swift | COVERED |
| repetition curve | `feedCurveExact`, `patCurveExact`, `playCurveExactAtCease`, `curveIndependentOfSatiety`, `familiesIndependent`, `careExempt`, `newDayResets`, `ceaseDayAttribution` | RepetitionCurveTests.swift | COVERED |
| handshakes incl. late/duplicate/cancelled reports | `settleFinishedAppliesAndIsIdempotent`, `wakeFinishedApplies`, `wakeFinishedAfterMidWakingNapPreservesNap`, `playRoundFinishedClearsTokenOnly`, `cancellationMatchesKindOnly`, `staleReportDiscardedAndUnstrands`, `lateReportAfterFoldClearance`, `interactionDuringSettleDoesNotQueue`, `wakeStretchMintDefersPastTheFold`, `cancelledWakeRecovers`, `wakeTokenSurvivesMorningLanding`, `foldWithoutTransitionKeepsHandshake`; duplicate-intent belt: `inv10IntentIdempotencyKey`, `processedIntentsCapacityPinned`, `duplicateIntentReplayCarriesSamePlanKey` | WakefulnessHandshakeTests.swift, DomainInvariantsTests.swift, EngineReduceTests.swift, LineSelectionTests.swift | COVERED |
| play single-instant application | `fullLifecycle` (authorize → one-instant apply at cease → re-cease no-op), `authorizationMintsAndSets`, `drowsyRoundAuthorized`, `cancellationIsTheUnifiedCease`, `staleReportsApplyNothing`, `ceasePreservesTheRest`, `authorizationDeterminism` | PlayRoundTests.swift | COVERED |

**Row 6 — Deterministic randomness**

| Clause | Named test(s) | File | Status |
|---|---|---|---|
| seed stability (same day ⇒ same seed) | `dayStability` (+ `dayVariation`, `saltSeparation`, `epochSensitivity`, `petIDSensitivity`, `saltRawValues`, `preimageGoldenBytes`, `preimageRoundTrips`, `truncationContract`) | DaySeedTests.swift | COVERED |
| sequencer schedule purity (FR-4 AC-1) — Core half | `momoCoreIsPure`, `ambientDateFails`, `randomnessFails`, `ambientCalendarFails`, `exemptionAppliesToDeclaredFilesOnly`; `rngUntouched`, `clockUnread`, `determinismAcrossEventKinds`; day-stable line picks `twinPicksAreIdentical`, `withinDayStabilityAcrossHours`, `crossDayVariationSweep`; generator contract `seed0Vector`, `seed1And2Vectors`, `determinismAndStatefulness`, `randomNumberGeneratorConformance`, `valueSemantics` | EnginePurityScanTests.swift, EngineReduceTests.swift, LineSelectionTests.swift, SeededGeneratorTests.swift | COVERED |
| sequencer schedule purity — Character half | Character module does not exist yet (EPIC-006). Out of scope per this task's Context; the Core-side purity gates above are the enforceable half today. | — | N/A (EPIC-006) |

### Tests added (4) and why

Each targets a clause whose wording no existing green test literally pinned:

1. `TimeFoldTests.couplingSelfReversesOnEnergyRecovery` (row 1, FR-9 AC-3). Existing pins proved the downward pull while energy is low (`couplingAndFloor`, `couplingBandReadsSegmentStart`) but not that the pull RELEASES. The new test walks a Drowsy pet through folded spans — mood descends toward `FoldRules.moodCoupledTarget` — then recovers energy and verifies mood inflects back UP toward `FoldRules.moodAttractorTarget` at the `FoldRules.moodAttractorTauHours` rate. Anti-echo: constants via `FoldRules`/`Thresholds` only.
2. `TimeFoldTests.midnightRolloverExactlyOnceAcrossFoldedSpans` (row 3, FR-11 AC-2 "across folded spans"). `midnightRolloverExactlyOnce` landed the crossing via the evaluate path only; the clause requires exactly-once no matter which event shape crosses midnight. The new test lands one crossing each via `.evaluate`, an interaction intent, and a character report (fresh dayKeys), asserts exactly one ledger record per crossing, and re-delivers each event to pin no-double replay.
3. `TimeFoldTests.absentDayLedgerIsEmpty` (row 3, FR-12 AC-1 names "absent-day ledger emptiness" directly). `sevenDayAbsenceAddsOnlyLandingDay` pinned the landing-day-only shape; the new test pins the emptiness semantics themselves — six absent days produce zero records, bond stays parked, landing day starts all-zero with no hello flag and a fresh-epoch quest set (Q1 present).
4. `BondLedgerTests.monotonicUnderReplay` (row 2, FR-10 AC-2 "monotonicity incl. replay"). `monotonicAcrossRollover` replays fresh ids; `inv10IntentIdempotencyKey` pins duplicate intents as no-ops at the reduce seam. The clause asks for the ledger under SAME-id re-delivery: first pat awards `BondRules.helloBondDelta + BondRules.questBondDelta`, then the identical intent id replays at 11:00, 23:30, and 00:30 next day — each a whole-state no-op (`changed == false`), so the monotone sequence is exact.

No other clause required a new test; every other cell above resolved to existing green tests.

### Meta-determinism suite (deliverable 2)

`Tests/MomoCoreTests/MetaDeterminismTests.swift` — 2 test functions, 7 runtime cases:

- Six distinct seeds; per seed a `SeededGenerator`-driven schedule of 80 mixed steps, each advancing 57–113 minutes ⇒ ≥ 76 h > 72 h, so EVERY sequence crosses ≥ 3 local midnights and every 9 h night window between them **by schedule arithmetic, not draw luck**. In-runner sanity assertions prove the premises per seed: `days.count >= 3`, the trajectory contains `.asleep` states, and contains `.waking` or a pending `.wake` token.
- Step surface through the production `reduce`: all five interaction kinds, `.evaluate`, the direct `BondLedger.awardQuestCompletion` mechanism call, character reports answering the actually-pending handshake (settle→`settleFinished`, wake→`wakeFinished`, play→`playRoundFinished`, nothing pending→the tolerated stale no-op), and kind-matched `handshakeCancelled` steps. Composite play/tuckIn steps carry their real choreography completions (+60 s / +120 s) so nothing strands pending (the `BondLedgerPropertyTests` convention).
- Twin equality: each sequence runs TWICE from identical (state, clock, calendar, seed) tuples; EVERY intermediate outcome is compared with `==` (EngineOutcome equality subsumes its `newState`'s EngineState, response, moments, changed) — not just endpoints. `differentSeedsDiverge` proves the property has teeth.
- Per-step light invariants (`check`): INV-2/INV-3 domains via `Thresholds`, `response != nil` iff the event is an interaction, `moments.count <= 3`, greeting evaluate-only.
- Determinism: repo `SeededGenerator` drives the schedule and per-call engine seeds, `ManualEngineClock` sits at the step instant (report-path fold target), the calendar is the fixture's injected Gregorian. No wall clock, no ambient randomness anywhere.

### Coverage floor (deliverable 3)

Command (verbatim; the trailing `Sources/MomoCore` argument filters rows to production sources so test files don't dominate):

```
swift test --enable-code-coverage
xcrun llvm-cov report .build/arm64-apple-macosx/debug/MomoPackageTests.xctest/Contents/MacOS/MomoPackageTests -instr-profile .build/debug/codecov/default.profdata Sources/MomoCore
```

Caveat recorded for the reviewer: the report must be REGENERATED after any plain `swift test` — an uninstrumented rebuild invalidates the profdata (llvm-cov exits 1 on the mismatch). Numbers below are from the final instrumented run.

**TOTAL: 1679 lines, 39 missed → 97.68 % lines (550 regions 94.91 %, 196 functions 94.90 %). The ≥ 90 % floor is met; no extra closing tests were needed beyond the four gap tests above.**

Per-file table (verbatim from the final instrumented run):

```
Filename                       Regions    Missed Regions     Cover   Functions  Missed Functions  Executed       Lines      Missed Lines     Cover
-------------------------------------------------------------------------------------------------------------------------------------------------------------
InteractionRules.swift               3                 0   100.00%           3                 0   100.00%           8                 0   100.00%
DayRecord.swift                     11                 0   100.00%           3                 0   100.00%          19                 0   100.00%
DaySeed.swift                        9                 0   100.00%           7                 0   100.00%          35                 0   100.00%
SettingsState.swift                  1                 0   100.00%           1                 0   100.00%           4                 0   100.00%
DisplayState.swift                  20                 0   100.00%           8                 0   100.00%          54                 0   100.00%
Quest.swift                         15                 0   100.00%           6                 0   100.00%          27                 0   100.00%
SHA256.swift                        20                 0   100.00%           5                 0   100.00%          72                 0   100.00%
CopyRules.swift                     20                 0   100.00%           5                 0   100.00%          21                 0   100.00%
PetState.swift                       8                 0   100.00%           6                 0   100.00%          23                 0   100.00%
QuestTick.swift                     21                 4    80.95%           5                 2    60.00%          74                 8    89.19%
InteractionSemantics.swift          96                 1    98.96%          16                 0   100.00%         311                 1    99.68%
InteractionIntent.swift              1                 0   100.00%           1                 0   100.00%           7                 0   100.00%
HandshakeMachine.swift              33                 0   100.00%          11                 0   100.00%         179                 0   100.00%
SeededGenerator.swift                2                 0   100.00%           2                 0   100.00%          10                 0   100.00%
InteractionEffects.swift            16                 2    87.50%          12                 1    91.67%          74                 3    95.95%
QuestGeneration.swift               51                 1    98.04%          31                 1    96.77%         127                 1    99.21%
TimeFold.swift                      87                13    85.06%          20                 2    90.00%         233                10    95.71%
Bands.swift                         30                 0   100.00%           3                 0   100.00%          18                 0   100.00%
BondLedger.swift                    37                 4    89.19%          16                 2    87.50%         106                 6    94.34%
LineSelection.swift                 23                 0   100.00%           8                 0   100.00%          42                 0   100.00%
EngineState.swift                    3                 0   100.00%           3                 0   100.00%          20                 0   100.00%
Reduce.swift                        24                 0   100.00%           9                 0   100.00%         150                 0   100.00%
CharacterInterface.swift             4                 1    75.00%           4                 1    75.00%          20                 3    85.00%
Pet.swift                            3                 0   100.00%           1                 0   100.00%           7                 0   100.00%
EngineClock.swift                    7                 0   100.00%           7                 0   100.00%          19                 0   100.00%
EngineEvent.swift                    1                 0   100.00%           1                 0   100.00%           6                 0   100.00%
DayKey.swift                         4                 2    50.00%           2                 1    50.00%          13                 7    46.15%
-------------------------------------------------------------------------------------------------------------------------------------------------------------
TOTAL                              550                28    94.91%         196                10    94.90%        1679                39    97.68%
```

Deliberately-unexercised lines, with reasons:

- `DayKey.swift` 46.15 % (lines 21–26) — the DEBUG-loud guard for a calendar returning missing components (`assertionFailure` + `return ""`). Unreachable by construction: callers derive components from the same calendar that formats them; exercising it means crashing the test process. House DEBUG-loud / release-safe pattern (mirrors `MomoCopy.resolve`).
- `CharacterInterface.swift` 85.00 % (lines 27–29) — `HapticID.init(rawValue:)`. The presentation seam: haptic identifiers arrive from the app layer (EPIC-007); nothing in MomoCore constructs one from a raw string yet, so the failable init sits uncovered until then.
- `QuestTick.swift` 89.19 % (82–85, 126–127), `BondLedger.swift` 94.34 % (79–80, 189–190), `TimeFold.swift` 95.71 % (368–375), `InteractionEffects.swift` 95.95 % (85–86) — the missed lines are the DEBUG-loud `assertionFailure` invariant-regression rebuild guards. Their reachable branches are pinned by the clamp/idempotency tests named in the table (`questAwardClampsAtDailyCap`, `questAwardClampsAtPlateau`, `questAwardClamps`, `energyClampsHold`, …); the guards fire only on a programmer-error invariant breach.
- `InteractionSemantics.swift` 99.68 % (line 419) — the "round in flight — cease first" decline `return` for the intent-kind combination not exercised by `midRoundPlayCheers` (play-during-round) or `tuckInDuringRoundDeclines` (tuck-in-during-round). Accepted residual: neighboring arms of the same gate are pinned and the floor is met with a wide margin.

### Suite health (Requirement 4)

- `swift build --build-tests`: green; only the pre-existing host linker warning (`ld: warning: search path '/opt/extra/lib' not found`) — no new warnings.
- `swift test`: **"Test run with 369 tests in 43 suites passed after 0.477 seconds."** Zero failures, zero skips; reproduced across runs (0.454–0.477 s), so the meta-suite keeps the whole suite snappy.
- Standing in-suite scanners green (import whitelist, banned vocabulary, numeric/token leakage, engine purity); **zero new exemptions** added.
- No debug residue (print/NSLog) in any touched file.

## Handoff

### Completed
- §10.3 gap-analysis table (above): all six rows and every named clause resolved to named green tests; the four clauses with no literal home got named tests.
- `MetaDeterminismTests` — the 05 §10.2 property: 6 seeds × 80-step ≥ 3-local-day mixed sequences through production `reduce`, whole-trajectory twin equality, teeth assertion.
- Coverage floor measured and recorded: TOTAL 97.68 % lines (floor ≥ 90 %), per-file table + command verbatim.

### Files Changed
- NEW `Tests/MomoCoreTests/MetaDeterminismTests.swift` (217 lines).
- MODIFIED `Tests/MomoCoreTests/TimeFoldTests.swift` (+136: `couplingSelfReversesOnEnergyRecovery`, `midnightRolloverExactlyOnceAcrossFoldedSpans`, `absentDayLedgerIsEmpty`).
- MODIFIED `Tests/MomoCoreTests/BondLedgerTests.swift` (+29: `monotonicUnderReplay`).
- MODIFIED this task file (Status / Implementation Notes / Handoff / Completion Evidence).
- NO production-source, doc, `MomoCopy.xcstrings`, or dependency changes (Requirement 7). Diff: 2 files, 165 insertions, 0 deletions, plus 1 new test file.

### Tests Run
`swift build --build-tests`; `swift test` (full suite); `swift test --enable-code-coverage` + the llvm-cov report command (above); filtered `swift test --filter` runs over the new/changed suites; debug-residue grep over the three touched test files.

### Test Results
Test run with 369 tests in 43 suites passed after 0.477 seconds (0 failures, 0 skips). Coverage TOTAL 97.68 % lines. All four gap tests and all seven meta-suite cases green; `differentSeedsDiverge` green.

### Known Issues
None. (Pre-existing host-only linker warning `/opt/extra/lib` not found is environmental, not new and not repo content.)

### Decisions Made
1. Audit-then-close: the vast majority of §10.3 clauses were already pinned; added only the 4 tests whose clauses no existing test literally pinned, each named after its matrix clause (Requirement 1 house naming). No rewrite, no duplicate coverage.
2. Row 6's Character half recorded N/A (EPIC-006) rather than inventing a Character module — exactly as this task's Context anticipates.
3. Coverage recorded from a fresh instrumented run (97.68 %). An earlier 97.92 % figure arose from a stale profdata comparison and was discarded; the regeneration caveat is recorded so the reviewer reproduces the recorded numbers.
4. Meta-suite composite steps carry real completions and report steps answer the actually-pending handshake — keeps every seed's trajectory stranded-free without weakening twin equality; the multi-day span is schedule arithmetic (80 × 57 min ≥ 76 h), asserted in-runner.
5. Defect protocol not triggered — no engine defect found; nothing fixed, no pin weakened, no exemption added.

### Reviewer Status
APPROVED_WITH_MINOR_NOTES (REVIEW-TASK-020, 0 MAJOR) — disposition applied: MINOR-1 bookkeeping sentence (status.md, housekeeping), MINOR-2/NITPICK/OBS recorded, no code change.

### Commit
`test(engine): TASK-020 §10.3 matrix, meta-determinism property, coverage floor` — the atomic task commit (hash recorded in status.md at housekeeping).

### Push
Pushed to `origin/feature/EPIC-004-engine` immediately after the commit (status recorded in status.md).

### Recommended Next Step
Orchestrator: spawn the independent review agent for TASK-020; on APPROVED disposition, commit `test(engine): TASK-020 §10.3 matrix, meta-determinism property, coverage floor`, push, move the task to completed, then merge `feature/EPIC-004-engine` → `main` per CLAUDE.md §14 (owner-authorized 2026-09-08).

## Reviewer Findings
REVIEW-TASK-020 (2026-09-09, independent fresh Jupiter reviewer, adversarial/unprimed) — **APPROVED_WITH_MINOR_NOTES** (0 MAJOR / 2 MINOR / 3 OBSERVATION / 1 NITPICK). Full record: `.claude/tasks/reviews/REVIEW-TASK-020.md`. Highlights:

- Matrix re-derived from 05 §10.3 before comparing; no clause found missing; all named tests existence-verified; 15+ load-bearing bodies read and confirmed to pin their clauses; PRD clause texts verified (FR-9 AC-3's "self-reverses" is verbatim PRD).
- All three deliverables reproduced independently: 369/43 green (0.429–0.485 s across four runs); coverage table reproduced row-for-row at TOTAL 97.68 % lines (regions 94.91 %, functions 94.90 %); meta-suite audit clean (6 seeds, 76 h arithmetic, full step surface, real per-step `EngineOutcome ==`, no wall clock/ambient randomness — grep-verified).
- Both contract bites landed: (a) one twin's schedule perturbed +1 min at step 40 → all six twin cases fail with step-attributed first divergence (steps 41–46); (b) `moodAttractorTauHours` 3→3.5 → four raw-literal pins bite (FoldRulesPinnedTests τ pin, `couplingBandReadsSegmentStart`, `attractorConvergenceMatchesTau`, `couplingAndFloor`), while `couplingSelfReversesOnEnergyRecovery` demonstrably FOLLOWS the constant (formula-shape pin — the anti-echo division of labor working as designed). All probes reverted; FoldRules.swift cmp-verified byte-identical; HEAD untouched; post-probe suite green.
- MINOR-1: the discarded 97.92 % coverage figure can arise from a FRESH instrumented run, not only a stale profdata — the llvm-cov reading of QuestTick.swift 82–85 (the logically-unreachable guard) is bimodal across runs (garbage counter vs 0); floor met under both readings; recorded 97.68 % TOTAL is the conservative, reproducible choice. Disposition: one bookkeeping sentence in status.md's TASK-020 completion note; no code change.
- MINOR-2 (optional wording): the folded-spans test's replay legs are structurally-guaranteed no-ops; the clause's substance (exactly-once on the FIRST crossing, all three paths) is genuinely pinned. No test change required.
- NITPICK: `monotonicUnderReplay`'s `>=` assertion is implied by the preceding whole-state `==`; harmless.

**Orchestrator disposition (2026-09-09):** MINOR-1 — APPLY as recommended: one bookkeeping sentence added to status.md's TASK-020 completion note + a standing Known-Issues note (the QuestTick.swift 82–85 coverage reading is bimodal across llvm-cov runs — a profiling-counter artifact on the logically-unreachable guard; the ≥ 90 % floor holds under both readings, 97.68 % and 97.92 %; 97.68 % recorded as the conservative choice). No code change. MINOR-2 — RECORD AS-IS (reviewer: no test change required; the clause's substance is genuinely pinned). NITPICK — record, no change (belt-and-suspenders assertion is harmless). OBSERVATION-A rides MINOR-1's standing note; OBSERVATION-B/C recorded here and in the review file, no action. Zero test/production edits in this disposition — the reviewer's approval stands unamended. Suite re-verified by the orchestrator before commit.

## Completion Evidence
Implementation-agent entries (2026-09-09; disposition entries pending):

- Test command + counts: `swift test` → **"Test run with 369 tests in 43 suites passed after 0.477 seconds."** (`swift build --build-tests` green; no new warnings.)
- Coverage: llvm-cov **TOTAL 97.68 % lines** (94.91 % regions, 94.90 % functions) — exact command + full per-file table in Implementation Notes above; the reviewer reproduces both lines.
- Review file: `.claude/tasks/reviews/REVIEW-TASK-020.md` — **APPROVED_WITH_MINOR_NOTES, 0 MAJOR** (matrix re-derived before comparing, no clause missed; coverage reproduced row-for-row incl. the bimodality finding; both bites landed with exact attribution and were restored byte-identical). Disposition applied as above; orchestrator re-verified the suite green post-disposition.
- Commit hash: `test(engine): TASK-020 §10.3 matrix, meta-determinism property, coverage floor` — this task's atomic commit (hash recorded in status.md at housekeeping). EPIC-004 is 7/7 after this task; the epic merges to `main` per §14.
