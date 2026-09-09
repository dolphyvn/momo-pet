# REVIEW-TASK-018 — Quest generator + completion windows + Watch cascade

Reviewer: independent adversarial review agent (CLAUDE.md §10/§33), fresh context, Jupiter.
Date: 2026-09-09. Branch under review: `feature/EPIC-004-engine`, working tree (uncommitted) over HEAD `60e4fe5`.

## Verdict

**APPROVED_WITH_MINOR_NOTES** — MAJOR 0 · MINOR 1 · NITPICK 2.

The implementation is normatively correct, mutation-validated, and supersedes nothing beyond the license. The single MINOR finding is a **test-file-only** amendment (the property-suite moment re-pin asserts an invariant the implementation — correctly — violates); it should be applied at disposition (5-line edit inside license (a)'s named surface; not material to the implementation, no fresh re-review needed per §11's proportionality). No MAJOR findings; nothing blocks commit once the pin amendment lands.

## Independence statement

Nobody primed this review with "the implementation is correct". Verified with my own hands: repository state (HEAD, branch, stash list, dirty inventory, file-by-file diffs of all 7 modified sources and 8 modified test files; full reads of both new sources and all 4 new suites); both open questions re-derived from §4.8/§5.3/§5.5/contract text **before** reading the implementer's judgment notes; `swift build --build-tests` and `swift test` reproduced (314 tests / 36 suites, 0 failures); five seeded mutations run against a scratch copy in `/tmp` (all five bit, with exact attribution — details below); a scratch production-path probe proved the double-completion reachability; purity and anti-echo scans run by grep over all new/modified sources; supersession audit performed per-diff. Taken on faith (stated): the pre-TASK-018 baseline count "273 tests / 32 suites" (consistent with what I could verify — suite count delta 32→36 exact, `@Test` attribute delta HEAD 256 → tree 297 = +41, matching the claimed +41; re-running HEAD would have required a worktree build I judged not worth the time); the two build warnings' pre-existence (verified indirectly: `/opt/extra/lib` linker warning is recorded in REVIEW-TASK-009 and REVIEW-TASK-017; the `var original` subject exists at `EngineClockTests.swift:46` and that file is untouched by this task).

## State reconciliation

- HEAD = `60e4fe5433905a12af02c216cbf8577a6b543f59` (the dispatch commit) — **untouched** before, during, and after review (re-verified at the end). Branch `feature/EPIC-004-engine`. Stash list empty.
- Dirty tree = exactly the implementation inventory: 7 modified sources (`TimeFold`, `Reduce`, `InteractionSemantics`, `InteractionEffects`, `HandshakeMachine`, `BondLedger`, `EngineEvent`), 2 new sources (`QuestGeneration.swift`, `QuestTick.swift`), 8 modified test files, 4 new test suites, plus the task file itself (implementation notes). 22 dirty paths total; nothing extra, nothing missing.
- The implementer committed nothing (dispatch honored). Scratch probes ran in a `/tmp` copy; deleted afterwards; the real tree was never written by this review except the review record and the task file's Reviewer Findings section.

## Normative re-derivations

### Open question 1 — the Q6-credit rule (adjudicated: the implementation's strong reading is correct)

The candidates are: (weak) credit iff **at least one** prior set contains Q6 — the literal reading of contract Req 1b's "the two prior sets TOGETHER lack Q6" and of §4.8's "if the rolling 3-day window lacks Q6 (checking the two prior sets)"; (strong, implemented) credit iff **both** priors carry Q6 (`QuestGeneration.swift:114-116`, `allSatisfy { … contains .q6 } && count == 2`).

Derivation from the normative text:

1. **PRD §5.3's invariant does not discriminate.** Under the weak reading, three consecutive Q6-less days are impossible (the third day sees both priors lacking → forced Q6), so "Q6 in every rolling 3-day window" holds under *both* readings. My seeded mutation M1 (below) confirms this empirically: the 30-day × 5-seed simulation stays **green** under the weak reading. The window invariant therefore cannot be the tiebreaker.
2. **§4.8's own non-emptiness arithmetic does discriminate.** §4.8 (and contract Req 1c) asserts the post-filter space is "never empty (≥ 4 pairs in the tightest case)", i.e. 5 − 1: the Q6-restriction active **while yesterday's pair contains Q6**. Under the weak reading that configuration is *unreachable* — restriction active means both priors lack Q6, hence yesterday's pair lacks Q6 and the ban can never remove a Q6 pair; the true weak-reading minimum is 5, and the normative parenthetical would describe an impossible case. Only the strong reading makes the doc's 5 − 1 = 4 coherent and reachable (yesterday's pair carries Q6, the older prior lacks it). A normative doc's own proof sketch is disambiguating evidence about its intent.
3. **PRD §5.3's purpose leans the same way.** "(keeps the evening anchor present)": the strong reading forbids two consecutive Q6-less days; the weak reading permits them (e.g. Q6 on d−3, absent d−2 and d−1). The anchor is kept more present under the strong reading.
4. **Unknown priors.** "Unknown priors count as no Q6 credit" (Req 1b; §4.8's parenthetical). The `count == 2` conjunct is *required* for this: `allSatisfy` over an empty array is vacuously true, so without it day 1 of a fresh install would have credit and could omit Q6. With it, the 0-prior and 1-prior cases both force Q6 — exactly Req 1b's "an empty (or 1-element) `priorTwoSets` forces Q6". Correct as written.
5. **Mutation M1 seals it.** Mutating the scratch copy to the weak reading turns `exhaustiveNonEmptiness` red with verbatim `(tightest → 5) == 4`, and turns `unknownPriorsForceQ6` and `rolloverPriorGap` red — while the 30-day sim stays green. The suite discriminates the readings precisely where the normative arithmetic sits.

Conclusion: strong reading conforms; reachable minimum is 4 pairs; the pin `tightest == 4` is correct and reachable; the `count == 2` conjunct is correct. **Note for the record:** contract Req 1b's "TOGETHER lack" wording, read in isolation, suggests the weak reading; the contract is only self-consistent through Req 1c's parenthetical. Recommend the orchestrator treat Req 1b as clarified (not amended) by this adjudication — no code or contract change required beyond this record.

### Open question 2 — moment multiplicity vs the named re-pin (adjudicated: the implementation is right; the re-pin as written is wrong and must be amended)

The contract's Req 5 asserted "at most one quest completes per event *structurally* (targets and per-family progression make double completion unreachable)". That premise is **false**, and the implementation (which loops and never assumes) is correct:

- Feed (Q2 t1 / Q3 t2) and play (Q4 t2 / Q5 t3) *are* target-interleaved — singles only there.
- But the pat serves `.greet` (Q1, target 1, **window-gated** < 12:00) and `.pet` (Q7, target 3, all-day). The window gate breaks the interleaving: pats at 13:00 and 14:00 progress Q7 to 2/3 while Q1 sits at 0 (its window silently expired); a pat **timestamped 11:30 applied at 14:30** — exactly §4.8's own verbatim offline-pat shape, forward-only folds notwithstanding — is in-window *at its own timestamp* and completes **both** quests on one event, emitting `[.questCompleted, .questCompleted]` and banking +8.
- I proved this through the **full production path** (scratch probe: `fixture.send → reduce → InteractionSemantics.applyPat → QuestTick.tick`, no preset progress, ordinary events only): probe passed. `QuestTickTests.doubleCompletionLoops` (QuestTickTests.swift:228-242) proves the same shape synthetically. If such an event also crosses a stage threshold, the moment list is three long: `[.questCompleted, .questCompleted, .bondStageReached]`.

Consequences for the named re-pin (license (a), `BondLedgerPropertyTests.check()`): `moments.count <= 2` with "at most one of each kind" is a **false invariant of the implemented (and normatively correct) engine**. It is doubly-latent today — the suite's fixture set is `[q1, q2, q6]` (no Q7: `InteractionFixture`), the intent clock is monotone (no offline-replay ordering), and the direct `.quest` award steps carry `moments: []` — so no seeded sequence can reach a double and the suite is green. But the moment coverage grows (e.g. any future offline-replay step, or a Q7-carrying fixture), the pin fails spuriously, and an engineer reading "at most one of each kind" could "fix" the *engine* — a behavioral regression. **The pin must say:** count ≤ 3; at most 2 `.questCompleted` (one per completing quest; Q1+Q7 is the only reachable pair); at most 1 `.bondStageReached`, always last; every `.questCompleted` before it. That is the MINOR-1 fix. The contract's own text (Req 5's structural premise, and the re-pin it named in license (a)) encoded the disproven premise; the orchestrator should record this as a contract correction alongside this review.

### Rules 3–4 in-set scoping (probed independently — correct)

The literal PRD text ("first incomplete feed-family quest") without an in-set qualifier is indefensible: quest progress exists only for in-set quests, so a catalog-scan reading surfaces quests that can never progress — e.g. Q3 in set, Q2 not: the Watch would promise Q2 all day, and after Q3 completes it would keep promising Q2 forever (rule 3 re-scans to the permanently-incomplete out-of-set Q2 before any later rule). That contradicts §5.5's opening ("one quest, chosen deterministically … by relevance") and §5.1 rule 3's non-manipulative intent (completion pressure toward an impossible wish). Rule 5's explicit in-set gate shows the authors gate where they remember. The contract directs the scoping; the cascade table pins it (rows "rule 3 scans in-set only…", "rule 5's in-set gating…"). Approved.

## Suite reproduction

- `swift build --build-tests`: complete, no errors.
- `swift test`: **`Test run with 314 tests in 36 suites passed`** — matches the implementer's claim verbatim. Warnings: the warm build did not re-emit them; both are pre-existing (see independence statement) and this task touches neither `EngineClockTests` nor link settings.
- Baseline delta: suite count 32 → 36 exact (+4 new suites); `@Test` attributes 256 → 297 (+41, matching the claimed +41 tests).

## Adversarial probes (all run in a /tmp scratch copy; deleted after)

| # | Probe | Result |
|---|---|---|
| P1 | Named cascade test exists with §4.8's name and passes ("a 02:00 tuck-in with Q1 done selects Q6", QuestGenerationPinnedTests.swift:229) | PASS |
| P2 | Six-rule precedence table: rule 1 over rule 2 in the early-morning tail with Q1 open (row 1); 11:59/12:00 boundaries (rows 7–8); rules 3–4 in-set scoping + catalog order; rule 5 gating; rule 6 all-done ×2 | PASS (17-row table) |
| P3 | Window checks use the event's own timestamp: offline-pat verbatim pin (11:30 applied at 12:30 ticks Q1, PinnedTests:195-210); hour derived from the passed `instant`, never the application instant (QuestTick.swift:59; all sites pass `intent.timestamp` / cease instant) | PASS |
| P4 | D20 attribution: 00:30 tuck-in completes the NEW day's Q6, counted on the new day (PinnedTests:212-225) | PASS |
| P5 | Qualifying-only progress: daytime nap counts care but leaves Q6 at 0; 20:30 tuck-in completes it; post-noon pats count but never start Q1 | PASS |
| P6 | Expired-dayKey no-tick (no progress, no completion, no moment, no retroactive record); out-of-set quests never tick (in-set Q3 advances; Q2 never joins) | PASS |
| P7 | +4 clamps at the +20 cap (headroom-respecting, moment still emits, ledger exact) and at bond 1000 (zero applied, zero recorded) | PASS |
| P8 | Completion idempotence (no re-emit/re-award/un-complete) and all-done day quiet across pat/feed/tuck-in | PASS |
| P9 | Rollover exactly-once under re-derived landing dayKey; never regenerates a past (ticked) day; prior-gap semantics; fresh-install day 1 contains Q6; epoch stamped, placeholder era gone (grep: no placeholder code remains in Sources) | PASS |
| P10 | 30-day × 5-seed sim asserts **every** FR-15 AC-2 clause per day (exactly 3, Q1 anchor, no duplicates, no consecutive pair repeat) plus the rolling-3-day Q6 window over all 28 windows | PASS |
| P11 | Two-draw pin bites: **M3** (burn a third RNG draw in `generate`) → `twoDrawPin` red (generated `[q1,q4,q7]` vs replayed `[q1,q2,q3]`) while all constraint tests stay green — the pin alone guards the recipe | BIT (red as intended) |
| P12 | **M1** weak Q6-credit reading → `exhaustiveNonEmptiness` red (`tightest → 5 == 4`), `unknownPriorsForceQ6` red, `rolloverPriorGap` red; 30-day sim stays green (see open question 1) | BIT (red as intended) |
| P13 | **M2** cascade rule-2 `<=` off-by-one → six-rule table red exactly at the hour-12 row (got `.wish(.q1)`, expected `.wish(.q2)`) | BIT (red as intended) |
| P14 | **M4** pat families `[.greet]` only → `doubleCompletionLoops` red (Q7 not completed) | BIT (red as intended) |
| P15 | **M5** Thresholds divergence (`q1WindowClosesAtHour` 12 → 13) → three pins red with exact attribution (window table, two-draw pin, 11:59/12:00 tick boundary) — the anti-echo discipline bites on divergence | BIT (red as intended) |
| P16 | Production-path double completion (scratch test, real events only): pats 13:00, 14:00, then an 11:30 pat applied at 14:30 → Q1 and Q7 both complete, moments `[.questCompleted, .questCompleted]` | PASS (double confirmed reachable) |
| P17 | Purity scan over all new/modified sources: no `UUID()`, `Date()`, `Calendar.current`, system randomness, `randomElement`/`shuffle`; the only `.now` is the pre-existing injected-clock read in `Reduce.characterReport`; generation uses its own per-call `SeededGenerator(seed:)` (QuestGeneration.swift:159), never the choreography rng threaded through `reduce` | PASS |
| P18 | Fold draw lineage: `rollover` takes no rng; token/twin tests (`WakefulnessHandshakeTests`, `BondLedgerPropertyTests.twinRunsAreWholeStateEqual`, mint determinism) unchanged by this task and green | PASS |
| P19 | Supersession-license audit, per-diff: (a) property-suite re-pin — named text implemented; (b) TimeFold placeholder + seam — replaced; (c) Reduce header — exactly the one sentence, quest domain; (d) `apply`/`HandshakeMachine` return shapes extended; (e) the six superseded test files each annotate the supersession in place with its reason. `EngineEvent.swift` is doc-comment provenance only (named in the task's Files/Areas). Nothing outside (a)–(e) changed | PASS |
| P20 | Scope check: no UI, no Watch app code, no persistence/sync/retention, no celebration rendering, `.questCompleted` stays BARE (no associated value anywhere), `QuestCatalog` targets/windows untouched, MomoCore Foundation-only, zero mutable module state | PASS |

## Judgment-call adjudications (implementer's ranked calls 1–9)

1. **Draw = two seeded quests from the filtered pair space** — APPROVED. Contract Req 1 mandates exactly two draws; constraints hold by construction (the drawn pair is always a pool member; no retry loop exists); P11 shows the recipe is pinned. The side-claim of universal uniformity is overstated (NITPICK-1), with no behavioral effect.
2. **Rules 3–4 in-set only** — APPROVED (see re-derivation above; the literal alternative is indefensible).
3. **`QuestLine` enum, not nullable ID** — APPROVED. A nil conflates "no wish" with "all done", which §4.11's `questLine` needs distinguished; rendering stays presentation's.
4. **Epoch (and dayKey) interface-only inside `generate`** — APPROVED. Req 3 explicitly directs this; the epoch already flows through the caller's `DaySeed.make(…, epoch:, salt: .quest)`; re-mixing would hash it twice; documented in the doc comment as required; the lineage is pinned end-to-end (`rolloverGeneratesTheLandingDay`, `questSeedDeterminism`).
5. **Corrected pool-minimum (tightest = 4, reachable)** — APPROVED. My independent derivation and M1 both confirm: 4 requires restriction ∧ yesterday's pair carries Q6 ∧ older prior lacks it; the 225-configuration sweep pins it exactly.
6. **Tick site order pinned; doubles are real and looped** — APPROVED on the code; the property-pin consequence is escalated as MINOR-1 (the re-pin's premise, inherited from the contract, is false — see open question 2).
7. **Rule 2's defensive in-set check** — APPROVED. Makes the cascade total over malformed input; totality sweep green; harmless.
8. **Fold wiring (petID param, NEWEST-FIRST priors, exactly-once, no retro-creation)** — APPROVED. All three `TimeFold.apply` call sites updated; the lineage test re-derives `DaySeed` exactly, so salt/epoch/prior-order drift fails.
9. **Test mechanics (local `state(questSet:)` helper + `rebased`)** — APPROVED. Test-side only; preserves the fixture's no-fold-dynamics discipline; `doubleCompletionLoops` and the boundary pins depend on it.

## AC sweep

- **AC-1** ✓ twins over 3 seeds; `questSeedDeterminism` (same (pet, day, epoch) ⇒ same seed ⇒ same set); caller lineage re-derived in the rollover test.
- **AC-2** ✓ pool-level unit proofs for both constraints (ban alone, ban as set-equality, ban ∧ restriction = 4, restriction, unknown/short priors); exhaustive 225-config sweep pinning `tightest == 4`; 200-case randomized property with shape noise; 30-day × 5 seeds asserting all FR-15 AC-2 clauses per day. By-construction verified in code: filters run before the draw and the draw always lands in the pool (M1/M3 show no check-and-retry exists to mask).
- **AC-3** ✓ 11:59/12:00 and 19:59/20:00/06:59/07:00 boundary tables; the verbatim offline-pat pin; event's-own-hour in `QuestTick`; attribution to the event's dayKey including the 00:30 D20 pin.
- **AC-4** ✓ automatic completion at the qualifying event; +4 through the clamp (cap headroom + 1000 plateau, ledger exact in both); never un-completes/re-emits/re-awards; all-done day quiet.
- **AC-5** ✓ the named test exists and passes; the six rules in order with amended rule 1; precedence edges incl. rule 1 over rule 2 at 06:00 with Q1 open; rules 3–4 scoping and order; rule 5 gating; rule 6 all-done; twins; 24-hour totality.
- **AC-6** ✓ rollover generates real sets, stamps `currentEpoch`, placeholder gone; exactly-once under backward/re-derived dayKeys; never regenerates a past day; fresh-install day 1 contains Q6; all pre-existing suites green with only the licensed supersessions.
- **AC-7** ✓ purity scan green (P17); anti-echo holds in the sources and bites on divergence (P15); build + `swift test` reproduced green (314/36).

## Findings

### MAJOR — none.

### MINOR-1 — the property-suite moment re-pin asserts a false invariant (amend at disposition, test-only)

`Tests/MomoCoreTests/BondLedgerPropertyTests.swift:117-135` (`check()`): `moments.count <= 2` with "at most one of each kind" is contradicted by the engine the same submission proves: `QuestTickTests.doubleCompletionLoops` (QuestTickTests.swift:228-242) and this review's production-path probe (P16) both emit `[.questCompleted, .questCompleted]` from one event, and a simultaneous stage crossing yields three moments. The pin is latent today (fixture set `[q1,q2,q6]` has no Q7; the intent clock is monotone; direct `.quest` award steps carry no moments) but false — and a future red would invite "fixing" correct engine behavior. **Fix (5 lines, inside license (a)'s named surface):** re-pin to count ≤ 3; ≤ 2 `.questCompleted` (one per completing quest — the Q1+Q7 pair is the only reachable one); ≤ 1 `.bondStageReached`, always last, with the existing guard semantics unchanged; keep the header doc in step. Note explicitly in the pin comment that the property generator itself cannot reach a double (why the bound is wider than what the suite observes) and that `QuestTickTests.doubleCompletionLoops` is the live coverage. **Contract correction to record:** Req 5's "at most one completion per event structurally" and license (a)'s named re-pin inherited a disproven premise; the implementation is right. Applying this amendment does not require a fresh review (mechanical test-bound edit; §11 proportionality).

### NITPICK-1 — uniformity overclaim in the generator doc comment

`Sources/MomoCore/QuestGeneration.swift:48` and `:141-145` claim the induced pair distribution is "uniform over the surviving pool in every scenario". False for ban-active non-star pools (e.g. pool = K6 minus {q2,q3}: P({q2,q4}) = 1/24 + 1/30 = 0.075 ≠ 1/14). Uniformity does hold for the two star-shaped scenarios the comment describes (unrestricted K6; the Q6-restricted 5-star — I verified both arithmetically), and no normative text requires uniformity (§5.3/§4.8 require determinism + by-construction constraints, both held). No behavioral impact. Fix: one line — claim uniformity only for the unrestricted and Q6-restricted scenarios, or drop the claim.

### NITPICK-2 — implementation-notes bookkeeping omission

The task's supersession notes attribute the `TimeFold.apply(petID:)` mechanical signature fixes to `EngineReduceTests`/`TimeFoldTests` (+`SatietyWindowTests` in Files Changed), but the `HandshakeMachine.apply` tuple return also mechanically touched `RepetitionCurveTests.ceaseDayAttribution` (`ceased.state.…`, RepetitionCurveTests.swift:234-239) — a licensed (d) consequence, correctly made, just not listed. No action needed beyond this record (or one line in the task notes at disposition).

## Reviewer Findings summary (for the task file)

> Independent adversarial review complete (§10/§33). **APPROVED_WITH_MINOR_NOTES** — MAJOR 0 / MINOR 1 / NITPICK 2. Reproduced `swift test`: 314 tests / 36 suites, 0 failures; HEAD `60e4fe5` untouched; inventory exact; purity, anti-echo (seeded divergence bites with exact attribution), supersession audit (nothing beyond license items (a)–(e)), and draw-lineage checks all clean. Both open questions adjudicated independently: (1) the Q6-credit rule — the strong reading (credit iff BOTH priors carry Q6, `count == 2` for unknown-priors) is the only reading under which §4.8's "≥ 4 pairs in the tightest case (5 − 1)" arithmetic is coherent and reachable; PRD §5.3's window invariant holds under both readings (verified: the 30-day sim stays green under a seeded weak-reading mutation), so the non-emptiness parenthetical is the discriminator; pin `tightest == 4` correct; (2) moment multiplicity — the implementation is right and the contract's premise was wrong: a pat serves Q1 (window-gated) and Q7 (all-day), so pats 13:00/14:00 + an 11:30 pat applied 14:30 (§4.8's own offline-pat shape) complete BOTH on one event via the full production path (probe passed), and a stage crossing makes 3 moments. All nine judgment calls APPROVED. All required tests 1–10 present and mutation-validated (5 seeded mutations bit with exact attribution). **MINOR-1 (apply at disposition, test-only, inside license (a)):** `BondLedgerPropertyTests.check()`'s re-pin (`≤ 2` moments, ≤ 1 of each kind) is a false-but-latent invariant — amend to ≤ 3 moments, ≤ 2 `.questCompleted`, ≤ 1 `.bondStageReached` last, quest moments first, and record the contract correction (Req 5's "structurally unreachable" premise is disproven; the tick loop is correct). NITPICK-1: uniformity overclaim in `QuestGeneration.swift`'s draw doc comment (uniform only in the unrestricted/Q6-restricted scenarios; ban-active pools skew — no behavioral impact). NITPICK-2: `RepetitionCurveTests.ceaseDayAttribution`'s mechanical `ceased.state` signature fix is unlisted in the notes. No MAJOR findings; nothing blocks commit once MINOR-1 lands.
