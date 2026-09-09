# REVIEW-TASK-017 — Bond ledger (05 §4.6; FR-10)

**Reviewer:** fresh independent adversarial review agent (CLAUDE.md §10/§33); not the implementer, no shared context with TASK-017-impl.
**Reviewed:** working tree of `feature/EPIC-004-engine` @ `38ece671b5bdf001e4518b075185f1d75973cfc5` carrying the TASK-017 change set UNCOMMITTED (9 modified + 5 untracked files), on 2026-09-09.
**Verdict: APPROVED_WITH_MINOR_NOTES** (one MINOR finding — a new build warning from a task file plus the handoff line that denies it; dispose before commit; no engine-behavior defect found).

---

## 1. Independence statement

This review was written by an agent spawned solely to review TASK-017. I did not write, modify, or run the implementation, and I received no summary of its correctness — only the task file, the normative documents, and the diff. Every expectation below was re-derived from the normative sources BEFORE comparing against the code, and every behavioral claim below is backed by a check I executed myself (suite reproductions, a HEAD baseline run, 16 adversarial probe tests, two scanner bite-probes, and targeted greps). The probes lived only in a scratch copy of the repo; see §8 for the tree-integrity evidence.

## 2. State reconciliation (dimension 1)

- HEAD = `38ece67` on `feature/EPIC-004-engine`; `git stash list` empty; recent commits show only the two TASK-017 orchestration docs commits (`b045af4`, `38ece67`) after TASK-016's `f61093a`.
- Porcelain inventory matches the declared set EXACTLY — modified: `TASK-017-bond-ledger.md`, `HandshakeMachine.swift`, `InteractionEffects.swift`, `InteractionSemantics.swift`, `Reduce.swift`, `EngineReduceTests.swift`, `InteractionResponseTests.swift`, `RepetitionCurveTests.swift`, `Support/InteractionFixture.swift`; untracked: `BondLedger.swift`, `BondRules.swift`, `BondRulesPinnedTests.swift`, `BondLedgerTests.swift`, `BondLedgerPropertyTests.swift`.
- The implementer committed nothing (verified: HEAD predates the change set; no stash; the task file's Git Requirements section demands exactly this).
- Real tree re-verified byte-identical after all probing (§8).

## 3. Correctness against the normative sources (dimension 2) — independently re-derived

### 3.1 Clamp-at-award (Req 2; INV-5/INV-3; plateau)
`BondLedger.award` (BondLedger.swift:51–83) applies `applied = min(delta, dailyBondCap − entry.bondAwarded, Thresholds.Bond.maximum − state.state.bond)`, then writes back `pet.bond += applied` and `bondAwarded += applied` — the ledger records the ACTUAL applied amount (Req 2's "exact, not nominal"). Both subtractions are ≥ 0 at any model-valid state (`bondAwarded ∈ 0…20` is enforced by `DayRecord`'s init guard at DayRecord.swift:73; `bond ∈ 0…1000` by `PetState`), so `applied ≥ 0` by construction; `applied ≤ cap − awarded` keeps INV-5, `applied ≤ 1000 − bond` keeps INV-3 and the plateau. The single-formula structure is exactly Req 2's mandate. Verified behaviorally: cap sequence pins (§3.3), plateau truncation (shipped + probe P5: headroom 2, +4 requested → bond 1000, ledger +2), P4 (award at exactly cap → zero applied, whole state unchanged).

### 3.2 Hello (Req 3; INV-7, UX-6, AC-6)
`awardHello` gates ONLY on `!entry.helloAwarded` on the intent's own `dayKey`; `BondLedger` never reads `intent.source` (grep-verified over the whole file), and there is no time/window operand anywhere in the hello path. It rides `applyPat`'s counting return (InteractionSemantics.swift:126–128 — the same event that increments `patCount`), after the pat's mood/repetition arithmetic is already fixed, so TASK-016 pat semantics are untouched (pinned by `helloDoesNotDisturbPatSemantics`: exact ResponsePlan, exact mood delta × instance-1 multiplier, patCount, AND +8). Re-derived from PRD §3.3 ("Daily hello — first touch of the local day, +8, one per day") and 05 §4.6's hello row ("either device, idempotent, never window-gated; a first touch at 14:00 (Q1 expired) still earns +8 exactly once").

### 3.3 The two PRD cap arithmetics (AC-7)
- **3-quest day:** 8 + 4+4+4 = 20; the later trio completion's +6 applies `min(6, 20−20) = 0` — "variety adds 0" (PRD: "on 3-quest days the cap is already reached via hello + quests"). Pinned exactly in `threeQuestDayReachesCapExactly` (incl. the post-cap feed recording its family at applied-0, and the capped trio completion truncating to +0 with the family recorded).
- **2-quest varied day:** 8 + 4+4 = 16; variety +6 applies `min(6, 20−16) = 4` → 20 — §4.6's "8+8+4 (the +6 truncated)". Pinned exactly in `twoQuestDayTruncatesVarietyToFour` (bond 16 → 20, `bondAwarded == 20` — ledger exact).
Both arithmetics re-derived by me from PRD §3.3 / 05 §4.6 BEFORE reading the pins; the pins match.

### 3.4 Quest mechanism-only (Req 4; scope)
`awardQuestCompletion(to:dayKey:)` is the only quest-side surface; it calls `award` and nothing else. Grep over the entire change set: NO quest ticking, NO window checks, NO completion detection, NO `questCompleted` moment anywhere. Tests drive the award directly. Scope clause satisfied.

### 3.5 Variety trio (Req 5)
`recordFamilyUse` records `.feed`/`.play`/`.care` on exactly the I-1 counting events — verified at each site: feed wraps the shared count closure used by EVERY feed path including refusals and asleep declines (InteractionSemantics applyFeed); play records inside `applyPlayRoundEffects` (InteractionEffects.swift:130–134), the single function both cease kinds route through (`playRoundFinished` and `handshakeCancelled(.play)` — HandshakeMachine.swift:71, 89); care records at settle-authorization, blanket-adjust, and nap-acceptance, and NOT at the settling reaffirm (which TASK-016 never counted), NOT on out-of-window tuck-in, NOT on declined nap. The +6 fires at the trio-completing event via `completesTrio = ¬(trio ⊆ before) ∧ (trio ⊆ after)` — once per day by set membership (a recorded family short-circuits). Shipped tests cover every trigger site; my probes P7–P10 additionally prove the AWARD fires at each completing-event flavor (blanket-adjust, play cease finished AND cancelled, nap acceptance, refusal feed).

### 3.6 Expired-dayKey (Req 6)
All ledger reads/writes route through `InteractionEffects.dayEntry`/`updatingDay`, which no-op on a missing entry. Shipped test proves: stale-dayKey pat earns no bond, sets no flag, writes no counter, creates no retroactive `DayRecord`; stale feed records no family while keeping current-state effects. Consistent with the recorded interpretation (an un-ledgered award would be un-idempotent and un-clampable).

### 3.7 Stage reconciliation (Req 7; FR-10 AC-4, UX-10)
`reconcileStage` is state-based (`makeBondStage(bond)` vs `highestCelebratedStage`, private ledger-local `rank`) and runs AFTER every mutation on all three event paths (Reduce.swift:117–118, 156–159, 184–187), with `moments` flow-through and `changed` recomputed against the reconciled state. The guard advances only WITH an emission (`state.with(highestCelebratedStage: stage)` returned together with the moment), so each crossing emits exactly once ever. The duplicate-intent no-op path correctly returns before reconciliation (nothing mutated). Probe P13: a constructed guard-above-derived state stays silent and unchanged (no regression path). Probe P14: boundary values 149/150/749/750 reconcile exactly relative to the guard. Multi-stage jumps emit ONE moment carrying the CURRENT stage on both the evaluate path (shipped) and the interaction path (probe P6: 700 + hello → 708 → one `.bestFriends` moment; P6b: organic 746 + quest → 750 → `.soulCompanions`).

### 3.8 Bond read-only everywhere else (Req 8)
Grep for `bond:` across Sources/MomoCore: every writer outside `PetState`'s own init is a pass-through (`pet.bond` / `state.state.bond` / `petState.bond`) — HandshakeMachine:135, InteractionEffects:124, InteractionSemantics ×6, TimeFold:242. The ONLY raiser is `BondLedger.award`. No engine path lowers bond.

### 3.9 `momentFinished` no-op + determinism (Req 9/10)
HandshakeMachine:93–97 unchanged (tolerated no-op). Determinism: the ledger takes no rng and reads no clock anywhere; twin-equality holds in the shipped unit and property suites, and probe P12 proves bond fields are IDENTICAL across different seeds over an award-bearing stream (tokens differ; bond may not).

## 4. Adversarial probes (dimension 3) — 16 probes, all passing

Written as a scratch suite in a /tmp copy (deleted afterwards; real tree untouched). Three initial failures were MY probe-construction errors, not engine defects — corrected and documented because they sharpen the record:
- P3 initially expected a *stale* report on a state with a PENDING crossing to stay silent; UX-10 mandates the opposite (the next evaluation of ANY kind surfaces the crossing exactly once) — the engine is right, my expectation was wrong. Corrected probe proves: duplicate report on a post-emission state re-emits nothing (whole-state equal); a stale report on a pending-crossing state emits exactly once; a further stale report is silent; `momentFinished` re-emits nothing.
- P14 initially asserted 749-with-guard-`.newFriends` is silent — wrong on my side: crossing is relative to the GUARD (749 > 149), and the engine correctly emits `.bestFriends`. Corrected probe pins 149/150/749/750 guard-relative, incl. 750 with guard `.soulCompanions` silent.
- P5 initially asserted `bond == Σ bondAwarded` on a state whose `bond` I had preset to an arbitrary 998 — the identity is defined for organically-grown states (exactly the domain the property suite proves it over). Corrected probe asserts the delta identity (bond grew by exactly what `bondAwarded` grew by = 2).

Passing probes (all green): P1 mixed-device same-day hello both orders (shipped device test compares two INDEPENDENT runs; the shared-day sequence was unpinned — the flag gates, not the device); P2 replayed pat intent is a total no-op (INV-10: no double hello, `changed == false`, whole-state equal); P3 duplicate/stale reports after a stage moment; P4 quest award at exactly cap applies zero and changes nothing; P5 plateau headroom-2 truncation with exact ledger delta, then a further award is a no-op; P6 multi-stage jump on the interaction path emits one current-stage moment; P6b organic soulCompanions jump (746 + quest 4 = 750) emits on the next evaluation; P7 variety fires at a blanket-adjust completing the trio; P8 variety fires at BOTH play-cease kinds completing the trio; P9 variety fires at nap acceptance completing the trio; P10 a REFUSAL feed completes the trio and fires the +6 (the I-1 asymmetry taken to its bond consequence — spec-conformant: every feed intent counts, the award rides the completing event); P11 organic midnight rollover: 23:59 pat awards day D, 00:01 pat after a real fold awards day D+1 (each ledger day +8, bond 16); P12 bond-field seed invariance (the ledger draws no rng — sharp form of the determinism requirement); P13 guard-above-derived state silent and unchanged; P14 boundary reconciliation guard-relative; P15 an award on one dayKey leaves other days' records byte-identical.

## 5. The two TASK-016 first-pat pins (dimension 4) — judgment call 1 adjudicated: APPROVED

The diff on `InteractionResponseTests.touchGestureZoneMap` and `RepetitionCurveTests.patCurveExact` is exactly: fixture gains `helloAwarded: true` at the two first-pat call sites, two trailing COMMENTS reworded, zero assertion expressions touched. Adjudication:

- **The tension is real and created by the contract itself.** Req 3 mandates the +8 hello ON the first pat; the old pins asserted `bond == start.bond` on a day's first pat. No implementation can satisfy both verbatim. Req 8's "existing pins must keep passing unmodified EXCEPT where this contract names the touch point" — Req 3 names the touch point (`applyPat` → the pat-counting event). The "it names none" reading cannot be literal, or Req 3 is unimplementable.
- **The chosen resolution is the least-invasive one and does not weaken what the pins prove.** G2's normative content (PRD §4: "petting banks no bond at any volume"; G2: "raw petting … never moves Bond") has always been about petting volume, not the first touch — the PRD's own earning table awards the hello to the first touch. The preset re-scopes both pins to exactly that: past the hello, pats bank nothing, for every gesture×zone cell and every curve instance.
- **The preset actually adds coverage:** with the flag pre-set, every gesture×zone cell and every curve instance now proves the hello's idempotency gate — a broken flag gate (re-awarding despite `helloAwarded`) would surface as `bond == start + 8` in ANY of those assertions.
- **No coverage gap results:** the hello award itself (+8 once, flag, ledger, patCount, non-disturbance) is pinned in `BondLedgerTests.firstPatAwardsHelloExactlyOnce` and `helloDoesNotDisturbPatSemantics`; `#expect(bondAwarded == 0)` in the gesture×zone pin now doubles as a re-award guard.
- **Audit for other weakening:** the complete diffs of both files plus `InteractionFixture.swift` were read line by line — no other change exists. Fixture changes are strictly additive defaulted parameters plus the `evaluate` wrapper; no existing call site altered except the two disclosed presets. The comment rewordings replace a now-false "ever" claim with an accurate statement; that is honesty, not weakening.

## 6. Judgment calls 2–10 adjudicated

2. **Multi-stage jump = ONE current-stage moment — APPROVED.** §4.6's form is singular (`momentRequest(.bondStageReached(newStage))`); UX-10: "shown once"; per-threshold backfill has no spec support anywhere in 03/05. Probes P6/P6b confirm single emission with the current stage.
3. **Hello flag sets even when the award clamps to 0 — APPROVED.** Effect-equivalent to the alternative (on a capped day, a later touch awards 0 through the cap either way — the cap is the second guard), and the chosen form makes the flag mean "the day's touch happened", which is the honest ledger reading and what 03 §Appendix's shared-trigger analysis treats the flag as. Shipped pin `helloFlagSetsWhenClamped` proves both truths at the plateau.
4. **Ledger-local `rank(_:)` — APPROVED.** `BondStage` is deliberately unordered presentation vocabulary (Bands.swift:21–27); a private ledger-owned rank avoids editing the unlisted `Bands.swift` and keeps precedence a ledger concern. No `Comparable` conformance was retrofitted.
5. **`dailyBondCap` in both homes, pinned equal — APPROVED, not an anti-echo violation.** Both homes named: `BondRules.dailyBondCap` (the award formula's operand, BondLedger.swift:59) and `Thresholds.Bond.dailyCap` (the `DayRecord` init's INV-5 stored-range bound, DayRecord.swift:73 — PRE-EXISTING TASK-012 code; the init's range guard reads it). Collapsing would have edited an unlisted TASK-012 file or coupled the formula to a model-validation constant. The equality pin (`capHomesAgree`) reproduces the exact house discipline of `InteractionRulesPinnedTests.swift:76–77` (`tuckInWindowStartHour == Thresholds.Quest.q6WindowStartHour`) — verified precedent. A PRD change now fails loudly at the pin instead of diverging silently.
6. **Family writes at the counting sites — APPROVED.** Placement mirrors I-1 exactly: `.play` inside `applyPlayRoundEffects` (the one function both cease kinds route through), `.feed`/`.care` at the counting return sites; `HandshakeMachine` needed only the additive `with(highestCelebratedStage:)` helper (read in full — no semantic change).
7. **Stale `moments` doc in `EngineEvent.swift` left standing — ACCEPTED (NITPICK 4).** Unlisted file; disclosed, not hidden. See findings.
8. **Fixture `evaluate` wrapper + additive params — APPROVED.** Strictly additive, all defaulted; the wrapper mirrors the existing zero-elapsed discipline.
9. **Subset-arithmetic trio trigger — APPROVED.** `¬(trio ⊆ before) ∧ (trio ⊆ after)` is correct for any set content; an `after == trio` equality would be wrong the moment non-trio families could be recorded.
10. **`awardQuestCompletion` mechanism-only — APPROVED.** Verified zero ticking/detection/moments in the change set; the name is self-describing for TASK-018's caller.

## 7. Findings

### MINOR-1 — New build warning from a task file; handoff claims zero (dispose before commit)
Clean `swift build --build-tests` (in the scratch copy) emits:
```
Tests/MomoCoreTests/BondLedgerPropertyTests.swift:47:17: warning: initialization of immutable value 'id' was never used; consider replacing with assignment to '_' or removing it
```
`run(...)` computes `let id = UUID(...)` that is never used (`step(...)` recomputes its own `intentID`). The task file's Handoff claims "`swift build --build-tests`: zero errors, zero warnings from this task's files" and the Status line says "zero build warnings" — the claim is FALSE for this task's own new file (the other two warnings — `EngineClockTests.swift:46` var-let and the `ld: warning: search path '/opt/extra/lib' not found` — are pre-existing and were correctly disclosed). A §25-adjacent reporting inaccuracy, though a trivial one: the fix is deleting one dead line, plus correcting the two handoff/status lines. No executable behavior affected; the suite is green either way.

### NITPICK-2 — Handoff prose undercount
The Handoff says "BondLedgerTests (17 tests: …)"; the file holds **23** `@Test` functions (counted: 23). The suite-level numbers the claim feeds into (273/32, +37 over 236/29) are exactly right — see §9 — so this is prose only. Correct the line when disposing MINOR-1.

### NITPICK-3 — Stale TITLE on `InteractionRulesPinnedTests.touchDelta`
Title: "touch +2 mood in every state; bond never moves (G2 is a rule — no bond constant exists)". The parenthetical is now false (`BondRules.helloBondDelta` exists; a first touch moves bond); the assertion body (`touchMoodDelta == 2`) is true and unmodified. Implementer disclosed it accurately. Under the unmodified-pins rule, leaving it was defensible (a display name is not an assertion); recommend the orchestrator permit a title-only wording fix riding the task commit or a near-term touch, since a title asserting a falsehood is mild documentation debt.

### NITPICK-4 — Stale `moments` doc-comment in `EngineEvent.swift` (implementer judgment call 7)
The comment still frames `moments` as populated by "TASK-015/018"; TASK-017 now flows `bondStageReached` through it. Unlisted file, disclosed, left standing per the letter of the contract — accepted, with the same recommendation as NITPICK-3 (comment-only touch).

No MAJOR findings. No correctness, scope, security/privacy, concurrency, or architectural finding of any grade beyond the above.

## 8. Hygiene + scanner verification (dimension 6)

- Zero TODO/FIXME/HACK/TEMP/`print(` in all five new files and the four modified sources (grep-clean).
- Both new sources import Foundation only; zero stored `var` in `BondRules`/`BondLedger` (all `static let` / pure functions); immutability via `with(...)` copies throughout.
- No `Date(`/`UUID(` anywhere in Sources/MomoCore outside the documented `EngineClock.swift` exemption (grep + standing scan).
- **Scanners UNCHANGED:** the three scan test files are absent from the change set; both are directory-level scans over `Sources/MomoCore` via `TestRepo.momoCoreSources()`, so the new files are covered by construction — and I proved it with bite-probes in the scratch copy: a seeded `let probeViolation = Date()` appended to `BondLedger.swift` turns `EnginePurityScanTests.momoCoreIsPure` RED with exact attribution (`Violation(file: "Sources/MomoCore/BondLedger.swift", literal: "Date(")`); a seeded `import Combine` in `BondRules.swift` turns `momoCorePassesWhitelist` RED with exact attribution. Both bites reverted; scratch copy re-verified green at 273/32 afterwards.
- Anti-echo: award constants appear in executable code ONLY via `BondRules.*` (grep-verified call sites: BondLedger.swift:59, 101, 125, 133); no bare award numerals in executable lines of the new sources (doc-comment spec labels are documentation, not echo); `BondRulesPinnedTests` is the sanctioned literal echo (8 pins). `Thresholds` keeps the stage thresholds (150/400/750) and the 0…1000 range; `BondRules` restates neither (it READS `Thresholds.Bond.maximum` in the clamp).

## 9. Full-suite reproduction + count reconciliation (dimension 7)

Ran twice on a bit-faithful copy of the working tree, plus an independent HEAD baseline:
- Reproduction 1: `✔ Test run with 273 tests in 32 suites passed after 0.401 seconds.`
- Reproduction 2: `✔ Test run with 273 tests in 32 suites passed after 0.466 seconds.`
- HEAD baseline (my own run of `38ece67`): `✔ Test run with 236 tests in 29 suites passed after 0.416 seconds.`
- Delta: exactly **+37 tests / +3 suites** — matches the implementer's claim. Reconciliation by `@Test` count: 8 (`BondRulesPinnedTests`) + 23 (`BondLedgerTests`) + 3 (`BondLedgerPropertyTests`) + 3 (`EngineReduceTests` additions) = **37 new test functions**; the runner's summary line counts parameterized tests once per function (the two `arguments:` tests expand to 4 + 3 cases at runtime), which is what reconciles 37 against 42 case-executions. New suites: exactly the 3 new files.
- Clean-build warning inventory: MINOR-1's new warning + the two disclosed pre-existing diagnostics. Nothing else.

## 10. Scope control (dimension 8)

- No quest ticking / detection / window checks / `questCompleted` moments anywhere in the change set (grep + read).
- No greeting moments, no copy keys (`momo.line.*` absent), no read-models, no Watch-specific code paths (device-agnostic by construction — the ledger never reads `intent.source`).
- `TimeFold.swift` and `CharacterInterface.swift` untouched (absent from git status). Scanners untouched. Package layout untouched.
- `momentFinished` remains the tolerated no-op (HandshakeMachine:93–97 unmodified).
- Determinism: the ledger draws no rng and reads no clock (probe P12 seed invariance + shipped twin-equality unit and property tests, bond fields included).

## 11. Acceptance criteria sweep (AC-1…7)

- **AC-1** ✅ `capByConstruction` over 4 seeds × 30 mixed steps, plus per-step INV-5 (`bondAwarded ≤ cap` on EVERY day at EVERY step) and per-step ledger exactness (`bond == Σ bondAwarded`) in `check(_:_:)`.
- **AC-2** ✅ `monotonicAcrossRollover` over 3 seeds spanning local midnight; plus per-step `next.bond ≥ prev.bond` and the 0…1000 range check on every step of every property run. (Sync-application monotonicity is structural: §6's applier routes through the same `reduce` — out of this task's executable scope.)
- **AC-3** ✅ 1000-loop: bond moves exactly +8 once, patCount 1000, ledger +8. Post-hello zero: flag-gate pins (gesture×zone matrix, curve instances, probe P1/P2). The AC's second half ("with the hello already awarded, 1000 pats move nothing") is proven compositionally (flag gate + cap + G2 pins) rather than as a second 1000-loop — adequate; the mechanism is identity-independent of loop length.
- **AC-4** ✅ once-guard on all three event paths (evaluate/interaction/report shipped tests), closed-surfacing at next evaluation, multi-stage single moment, guard advances only WITH emission (property `check` enforces "no moments ⇒ guard unchanged" and "moments ⇒ guard == moment stage" on every step); label derivation stays `makeBondStage` (no new threshold knowledge anywhere in the ledger).
- **AC-5** ✅ twin equality whole-trajectory (property suite) and unit-level, bond fields included; plus probe P12's stronger seed-invariance of bond fields.
- **AC-6** ✅ idempotent per dayKey (first/second pat), device-agnostic (`.watch` pinned + P1 shared-day sequences), never window-gated (14:00 and 23:50 pinned), second same-day touch banks nothing.
- **AC-7** ✅ both PRD cap arithmetics pinned exactly (§3.3); variety fires once at the trio-completing event and never again that day (shipped + probes P7–P10 across ALL completing-event flavors).

Required-tests sweep vs delivery plan §3 TASK-017 row: cap-by-construction property over randomized sequences ✅; 1000-pats-zero-bond ✅; hello idempotency incl. post-12:00 first touch ✅ (14:00 and 23:50); all ten additional named tests present and passing.

## 12. Clean dimensions

State reconciliation (§2), clamp-at-award structure (§3.1), hello semantics (§3.2), both PRD arithmetics (§3.3), quest mechanism-only (§3.4), variety counting-exactness (§3.5), expired-dayKey disposition (§3.6), stage once-guard incl. multi-stage and boundaries (§3.7), bond-writer exclusivity (§3.8), momentFinished no-op + determinism (§3.9), pin-preset adjudication (§5), all ten judgment calls (§6), hygiene + scanner coverage with bite-proofs (§8), suite reproduction and count reconciliation (§9), scope control (§10), AC sweep (§11).

## 13. Verdict

**APPROVED_WITH_MINOR_NOTES.** The implementation is correct against every normative clause I re-derived, survives 16 adversarial probes including edges the shipped suite did not directly cover, keeps both scanners provably live over the new files, reproduces its claimed suite numbers exactly, and stays in scope. The single MINOR finding is a dead-code build warning in a new test file together with the handoff lines that deny it — a one-line removal plus two prose corrections, required before the orchestrator's commit. NITPICKs 2–4 are prose/doc debts the orchestrator may dispose in the task commit or defer.

## 14. Recommendation to the orchestrator

1. Have the MINOR-1 fix applied (delete the dead `let id` at BondLedgerPropertyTests.swift:47; correct the Handoff's "BondLedgerTests (17 tests)" → 23 and the "zero warnings from this task's files" line; optionally soften the Status line's "zero build warnings") — a fresh-agent fix cycle is not required for a one-line dead-code deletion, but the corrected task file must carry the disposition.
2. Optionally ride the two comment/title touch-ups (NITPICK-3/4) in the same commit or record them as follow-ups.
3. Re-run `swift build --build-tests` + `swift test` after the fix; expect `✔ Test run with 273 tests in 32 suites passed` and only the two pre-existing warnings.
4. Then commit per the task's Git Requirements — `feat(engine): TASK-017 bond ledger, variety bonus, stage moments` — record the hash, push, update status.md, move the task to completed.

## Disposition (orchestrator, 2026-09-09 — findings addressed pre-commit)

- **MINOR-1 — FIXED.** The dead `let id = UUID(...)` at `BondLedgerPropertyTests.swift:47` deleted (the loop passes `id: i` directly). Both false prose lines corrected in the task file: the Handoff's build line now states the original inaccuracy and its correction verbatim; the Status line no longer claims zero build warnings. Post-fix `swift build --build-tests` emits only the pre-existing `ld` search-path diagnostic (the `EngineClockTests` var-let appears only in the test-build phase, also pre-existing).
- **NITPICK-2 — FIXED.** Handoff "BondLedgerTests (17 tests)" → 23.
- **NITPICK-3 — FIXED (rode the task commit).** `touchDelta`'s title now reads "past the day's hello, bond never moves (G2 — petting VOLUME banks nothing)", citing this review; the assertion body was already true and untouched.
- **NITPICK-4 — FIXED (rode the task commit).** `EngineEvent.swift`'s `moments` doc-comment now attributes `bondStageReached` to `BondLedger.reconcileStage` (TASK-017), greeting to TASK-019+, questCompleted to TASK-018. The sibling stale `response` comment in the same block ("until the response matrix lands, TASK-016/017") was corrected in the same comment-only pass — same staleness class, disclosed here.
- **Post-fix verification:** `swift test` → `✔ Test run with 273 tests in 32 suites passed after 0.398 seconds.` — suite unchanged (dead code + comments only).

**Disposition status: APPROVED — commit-ready.**
