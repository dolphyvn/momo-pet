# REVIEW-TASK-020 — Engine test matrix, meta-determinism property, coverage floor

**Reviewer:** independent fresh Jupiter agent (CLAUDE.md §10/§33), adversarial, unprimed.
**Date:** 2026-09-09
**Branch:** `feature/EPIC-004-engine`
**HEAD at review start and end:** `13d27344dc0da79a333487ad6e3dbbc3ccb7d38e` (untouched; verified before and after all probes)
**Verdict: APPROVED_WITH_MINOR_NOTES** (findings: 0 MAJOR, 2 MINOR, 3 OBSERVATION, 1 NITPICK — all dispositionable without re-implementation; see §8)

## 1. Independence statement

This review was conducted by a fresh agent with no prior conversational context from the implementation agent. The implementer's Implementation Notes and Handoff were treated as CLAIMS, not evidence. Every load-bearing number was re-derived or re-executed: the §10.3 matrix was enumerated from `docs/architecture/05-technical-architecture.md` §10.2–§10.3 (lines 589–605) BEFORE reading the implementation's gap table; the four FR clause texts were read from `docs/product/02-mvp-prd.md` (lines 288–313); the test-count, runtime, and coverage claims were re-executed; both contractually mandated mutation bites were performed by this reviewer with probes authored, run, and reverted by this reviewer. No implementation number is adopted without independent reproduction.

## 2. State reconciliation

- HEAD verified `13d27344…` at dispatch, mid-review (after each probe), and at close.
- Inventory at dispatch, exactly as disclosed: `M` task file, `M` BondLedgerTests.swift, `M` TimeFoldTests.swift, `??` MetaDeterminismTests.swift. No other paths.
- Requirement 7/5 scope audit: `git diff --stat` = task file +199, BondLedgerTests +29, TimeFoldTests +136 (165 insertions across the two modified test files, matching the Handoff's "2 files, 165 insertions" claim), plus the new 217-line suite. **Zero production-source, doc, `MomoCopy.xcstrings`, or dependency changes.** The task-file diff touches only Status / Implementation Notes / Handoff subsections — no contract-section headers removed or modified (verified by diffing section headers).
- Requirement 5's defect protocol: not triggered. No production change exists to audit.

## 3. Matrix re-derivation (before comparing to the gap table)

Enumerated independently from 05 §10.3 (lines 596–605):

1. **Mood/energy transitions** — band-mapping property over 0…100 (FR-9 AC-1); attractor/floor/coupling folds (FR-9 AC-2/3).
2. **Bond progression** — cap-by-construction over random sequences (FR-10 AC-1); monotonicity incl. replay (AC-2); 1000-pats-zero-bond (AC-3); stage crossing once (AC-4/5).
3. **Daily reset** — midnight rollover exactly once across folded spans; absent-day ledger emptiness (FR-11 AC-2, FR-12 AC-1).
4. **Quest progression** — generator 30-day simulation + by-construction candidates; window checks (Q1/Q6); completion auto-tick; cascade rules incl. the letter-of-PRD gap test (§4.8).
5. **State-engine rules** — response-matrix table (PRD §4 rows × bands × wakefulness); satiety rows asserting the nibble normative (I-2/OPEN-5); satiety phases; settling + waking decline-warm cells; repetition curve; handshakes incl. late/duplicate/cancelled reports; play single-instant application.
6. **Deterministic randomness** — seed stability (same day ⇒ same seed); sequencer schedule purity (FR-4 AC-1) — Core/Character.

Clause-text verification against the PRD: FR-9 AC-3 verbatim includes "which self-reverses on energy recovery" (02-mvp-prd.md:292) — the new test's clause is real, not invented. FR-10 AC-2 ("No gameplay action, absence duration, or sync conflict ever decreases bond", :298) grounds the replay clause. FR-11 AC-2 ("rolls … exactly once", :306) and FR-12 AC-1 ("bond unchanged, quests for those days silently empty", :312) ground row 3. Row 6's Character half is out of scope (module does not exist until EPIC-006; the task's own Context anticipates this) — recorded N/A honestly.

**Result: I could not find a clause the gap table misses.** My decomposition matches the table's row/clause split; every cell's mapping is defensible.

## 4. Gap-table audit (existence + body-level verification)

All ~130 named tests in the table were grep-verified to exist (zero MISSING). The `couplingAndFloor` cell cites TimeFoldTests.swift — correct (TimeFoldTests.swift:295; a same-named test also exists in FoldRulesPinnedTests.swift:38, which is legal and does not invalidate the citation).

Bodies read, not just names (each verified to genuinely pin its clause):

| Test | Verification |
|---|---|
| `capByConstruction` (BondLedgerPropertyTests:157) | 4 seeds × ≤ 30 single-day steps, bond ≤ `BondRules.dailyBondCap` at EVERY intermediate state + `days.count == 1` sanity — pins FR-10 AC-1 |
| `monotonicAcrossRollover` (:171) | 3 seeds crossing midnight, pairwise non-decreasing + exactness — and its runner mints a FRESH intent id per step (`id: i`), confirming the implementer's motivation for the new same-id test |
| `thousandPatsMoveExactlyTheHello` (BondLedgerTests:298) | 1000 pats → exactly hello+Q1 once, `patCount == 1000` — pins AC-3's volume-yields-zero |
| `couplingAndFloor` (TimeFoldTests:295) | raw-literal pins: coupled convergence (60−25·(1−e^(−1/3))) + exact 25 floor — the downward pull and floor arms of FR-9 AC-2/3 |
| `attractorConvergenceMatchesTau` (:287) | exact 60−30/e with 1e-9 |
| `midnightRolloverExactlyOnce` (:387) | CONFIRMED evaluate-path-only — the new all-paths test is genuinely additive |
| `recentlyFedNibble` (InteractionResponseTests:132) | exact ×0.25 effect via `InteractionRules` constants, clock re-anchor, count — pins the nibble-as-normative rows |
| `cancellationMatchesKindOnly` / `staleReportDiscardedAndUnstrands` / `lateReportAfterFoldClearance` (WakefulnessHandshakeTests:195/215/231) | kind-matched cancellation, stale rejection + unstrand, late-report tolerance — the handshake clauses |
| `thirtyDaySimulation` (QuestGenerationTests:175) | 5 seeds × 30 days: 3/day, Q1 anchor, consecutive-pair ban, rolling 3-day Q6 window |
| `sixRuleTable` + `cascadeTwins` + `cascadeIsTotalOverEveryHour` (QuestCascadeTests:83–112) | parameterized rule table + twin determinism + totality |
| `tuckInAtTwoAMWithQ1DoneSelectsQ6` (QuestGenerationPinnedTests:230) | the letter-of-PRD gap: hour 2, Q1 done → `.wish(.q6)` |
| `dayStability` / `dayVariation` / `saltSeparation` (DaySeedTests:20+) | same-day ⇒ same seed plus variation/salt/epoch/pet sensitivity |
| `momoCoreIsPure` + `exemptionIsLive` (EnginePurityScanTests:113/123) | non-vacuous purity scan + the exactly-one-`Date` occurrence pin on the sanctioned exemption |

**Four added tests — adversarial findings:**

1. `couplingSelfReversesOnEnergyRecovery` (TimeFoldTests:321) — GENUINE. Coupled segment (energy 30, Drowsy) converges DOWN to `FoldRules.moodCoupledTarget` at τ (exact formula, 1e-9); recovered segment (energy 60) converges UP to `FoldRules.moodAttractorTarget` by the same τ formula. If coupling were a ratchet, the second assertion's exact formula would fail. The brief's question "does it prove the pull releases at the attractor τ rate?" — yes, both direction and rate are pinned. Caveat: it is a formula-SHAPE pin, not a constant-VALUE pin (see bite (b) in §6 — by design, per the anti-echo division of labor).
2. `midnightRolloverExactlyOnceAcrossFoldedSpans` (TimeFoldTests:406) — GENUINE on the clause's substance: each of the three fold entry points (evaluate to-instant, interaction fold-to-intent-timestamp, report fold-to-now via the injected clock) lands the crossing 1 → 2 records with the new dayKey. OBSERVATION-B below on the replay legs.
3. `absentDayLedgerIsEmpty` (TimeFoldTests:472) — GENUINE and more than shape: exact two-element day list, six absent dayKeys explicitly asserted absent, landing day full-reset semantics (all four counters 0, `helloAwarded == false`, `bondAwarded == 0`, `questGenEpoch == QuestGeneration.currentEpoch`, Q1 present), bond parked at 130. Distinct from `sevenDayAbsenceAddsOnlyLandingDay`'s shape pin.
4. `monotonicUnderReplay` (BondLedgerTests:416) — GENUINE and exactly the clause: ONE intent id re-delivered at 11:00, 23:30, and 00:30 next-day; whole-state `==` no-op each time; `days.count == 1` after the past-midnight replay additionally pins belt-answers-before-fold (a fold would have rolled the day). NITPICK below on a redundant assertion.

## 5. Meta-determinism audit (deliverable 2)

- **Seeds:** 6 distinct (`[11, 2_026, 70_001, 424_242, 987_654_321, 0xDEAD_BEEF_1234]`, MetaDeterminismTests.swift:60) — ≥ 5 ✓.
- **Multi-day by arithmetic:** 80 steps × [57, 114] min ≥ 76 h > 72 h → ≥ 3 local midnights for EVERY seed regardless of draw; every 9 h night window between them is necessarily intersected (the widest night-free gap is 15 h). The in-runner sanity assertions (:113–117 — `days.count >= 3`, an `.asleep` outcome, a `.waking`/pending-wake outcome) verify the CONSEQUENCE per seed at runtime, which is the honest check since only non-`questAward` steps fold. Verified green for all six seeds.
- **Step surface:** all five interaction kinds, `.evaluate`, the direct `BondLedger.awardQuestCompletion` mechanism call, kind-matched reports answering the actually-pending handshake (settle→settleFinished, wake→wakeFinished, play→playRoundFinished, nil→tolerated stale), and `handshakeCancelled` with the pending kind — completions AND cancellations ✓; composite play/tuckIn steps carry real +60 s/+120 s completions so nothing strands.
- **Whole-trajectory twin equality:** each sequence runs twice from identical tuples; EVERY intermediate outcome is compared step-for-step with real `EngineOutcome ==` (:64–67), which subsumes the intermediate `newState`, response, moments, and `changed`. `differentSeedsDiverge` proves non-vacuity — and bite (a) below proves the equality assertion itself bites.
- **Determinism:** repo `SeededGenerator` per engine call, `ManualEngineClock` at the step instant, fixed-UUID intent ids (index-derived), injected fixture calendar. Grep over all touched files: no `Date.now`, no `Date()`, no `randomElement`, no debug print/NSLog ✓. The single `UUID()` hit in TimeFoldTests.swift:253 is pre-existing code, not this task's diff.
- **Runtime bounded:** full suite 0.429–0.485 s across four runs this review ✓.

## 6. Mutation bites (both mandatory probes; all residue reverted)

| # | Probe | Exact failing evidence | Outcome | Restore |
|---|---|---|---|---|
| (a) | One twin's schedule perturbed +1 minute at step index 40 (`run(seed:perturbed:)` probe variant; failure comment carried the step index) | All six seeded cases FAIL `#expect(a == b)`; recorded failures attribute first divergence at steps 41–46 per seed ("twin trajectories diverge at step 41/42/43/44/45/46"), i.e. within ≤ 6 steps downstream of the bite (the bitten step's own outcome absorbed the 1-minute shift in each seed; the shift then perturbs subsequent folds) | The twin-equality assertion HAS TEETH and attributes the failing step | Both probe edits reverted; file byte-identical to its pre-probe task content (verified by suite-green re-run and inventory re-check) |
| (b) | `FoldRules.moodAttractorTauHours` 3 → 3.5 (production constant, probe only) | Four raw-literal pins bit: `FoldRulesPinnedTests` "mood attractor: target 60, τ = 3 h" (`FoldRules.moodAttractorTauHours → 3.5 == 3 → 3.0` FAILED at FoldRulesPinnedTests.swift:34); `couplingBandReadsSegmentStart` (TimeFoldTests.swift:121, |Δ|=0.51 ≫ 1e-9); `attractorConvergenceMatchesTau` (:288, |Δ|=1.69); `couplingAndFloor` (:304, |Δ|=0.87). **`couplingSelfReversesOnEnergyRecovery` stayed green** — its expected values are computed FROM `FoldRules` constants, so it demonstrably FOLLOWS the constant (formula-shape pin); constant-VALUE coverage lives in the standing raw-literal pins, exactly the house division of labor. MetaDeterminismTests stayed green too (twin equality is formula-independent) | Constant bite lands on the standing pins; the new test's anti-echo stance confirmed | Reverted; `cmp` against `git show HEAD:` proved BYTE-IDENTICAL restore (an intermediate sed mistake that left a literal `$` on line 74 was caught by diff and corrected) |

Post-probe state: `git status` clean of probe residue, HEAD `13d27344…` unchanged, full `swift test` re-run **369 tests / 43 suites green (0.443 s)**.

## 7. Coverage floor reproduction (deliverable 3)

Exact recorded command re-executed after a fresh `swift test --enable-code-coverage` (the profdata-regeneration caveat was honored — llvm-cov exits 1 on a mismatched profdata, which I confirmed as a real failure mode by running the report after a plain `swift test`).

- **Reproduction run (fresh instrumented): TOTAL 1679 lines, 39 missed → 97.68 % lines; 550 regions, 28 missed → 94.91 %; 196 functions, 10 missed → 94.90 %. Per-file table matches the recorded table EXACTLY, row for row, including QuestTick 8 missed / 89.19 %.** The ≥ 90 % floor is met; the recorded numbers are genuine.
- **However, the report is BIMODAL in exactly one place across identical fresh instrumented runs.** My first fresh run produced TOTAL 97.92 % (35 missed) with QuestTick at 4 missed / 94.59 %; every other file identical. The variance sits on QuestTick.swift lines 82–85 — the `else` branch the implementation honestly labels "Unreachable: 0 < advanced ≤ target satisfies INV-6". In the 97.92 % run, llvm-cov `show` renders those lines with a garbage-scale counter (`18.4E`, ≈10^19 — a profiling-counter artifact, not real execution: the suite passed and `assertionFailure` on that line never trapped, and the loop-total counter contradicts such a count); in the 97.68 % run the same lines read 0 and are counted missed. I inspected the source: for `advanced = min(target, progress+1) ∈ [1, target]` the failable `QuestProgress` init cannot fail, so the LOGIC reading (unreachable) is correct in both runs — only the instrumentation disagrees with itself run-to-run.
- **Deliberately-unexercised reasons audit:** honest. `DayKey.swift` 46.15 % = the DEBUG `assertionFailure`+`return ""` guard (unreachable by construction; exercising it would trap the process); `CharacterInterface.swift` = the `HapticID.init(rawValue:)` presentation seam (EPIC-007); the `assertionFailure` rebuild guards in QuestTick/BondLedger/TimeFold/InteractionEffects (their reachable branches pinned by the named clamp/idempotency tests); `InteractionSemantics` line 419's un-exercised decline arm (neighboring arms pinned). MINOR-1 below records the one caveat on how the discarded 97.92 % figure was explained.

## 8. Verdict and findings

**APPROVED_WITH_MINOR_NOTES** — all three deliverables verified genuine; the suite is materially stronger (4 named gap tests + the §10.2 property through the full `reduce` surface); both bites behaved exactly as the contract requires; no production change; no pin weakened; no exemption added.

- **MINOR-1 (recording fidelity, disposition = one sentence of bookkeeping, no code):** The recorded coverage table reproduces exactly (verified row-for-row), but Decision 3's explanation of the discarded 97.92 % figure ("arose from a stale profdata comparison") is incomplete: this reviewer reproduced 97.92 % from a FRESH instrumented run. The real cause is the bimodal llvm-cov reading of QuestTick.swift lines 82–85 (garbage counter vs 0 — §7). The floor is met under either mode (97.68 % and 97.92 % both ≥ 90 %); the recorded 97.68 % TOTAL is the conservative and reproducible choice and needs no change. Recommended disposition: record one sentence in status.md's TASK-020 completion note that the QuestTick guard-line coverage reading is nondeterministic across runs (llvm-cov counter artifact) and the floor holds under both readings.
- **MINOR-2 (documentation precision in the gap table, disposition = optional wording touch):** `midnightRolloverExactlyOnceAcrossFoldedSpans`' task-file description says re-delivery is pinned "no matter which event shape crosses midnight … each re-delivery is a no-op" — true as written, but the replay legs are structurally-guaranteed no-ops (the fold target already moved / the INV-10 belt answers before fold). The clause's real risk — a doubled record on the FIRST crossing — is genuinely pinned per path (1 → 2 legs). No test change required.
- **OBSERVATION-A:** QuestTick.swift 82–85's `assertionFailure` "unreachable" guard is logically unreachable (verified from the failable-init contract) but intermittently reports a garbage execution count to llvm-cov. If the guard were EVER genuinely reached in DEBUG it would trap; its coverage signal is noise. Standing-note material for future coverage measurements, nothing more.
- **OBSERVATION-B:** `run(seed:)`'s in-runner multi-day assertions check consequences (`days.count >= 3`, `.asleep` present, `.waking`/wake-token present) rather than the schedule arithmetic itself. Sound as implemented: the 76 h arithmetic guarantees the crossings and the assertions verify each seed's trajectory actually registered them (the engine-side registration depends on fold placement, so runtime checking is the honest form).
- **OBSERVATION-C:** The meta-suite's `.questAward` step calls `BondLedger.awardQuestCompletion` directly (bypassing `reduce`). This matches the contract's "quest-award mechanism calls" wording and TASK-018's mechanism-only design; noted so future readers do not mistake it for a reduce-surface gap.
- **NITPICK:** `monotonicUnderReplay`'s `#expect(replay.newState.state.bond >= current.state.bond)` is implied by the preceding whole-state `==` assertion. Harmless belt-and-suspenders; no change required.

## 9. Recommendation to orchestrator

Disposition MINOR-1 (one bookkeeping sentence in status.md) and optionally MINOR-2 (wording), then commit `test(engine): TASK-020 §10.3 matrix, meta-determinism property, coverage floor` with the four test/task files, push, move the task to completed, and proceed to the EPIC-004 `--no-ff` merge per CLAUDE.md §14. The reviewer re-ran the full suite green after all probes: **369 tests / 43 suites, 0 failures, 0 skips**; HEAD `13d27344dc0da79a333487ad6e3dbbc3ccb7d38e` verified unchanged with zero probe residue (FoldRules.swift `cmp`-verified byte-identical).
