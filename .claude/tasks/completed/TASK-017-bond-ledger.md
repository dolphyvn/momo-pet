# TASK-017 — Bond ledger (05 §4.6; FR-10)

## Parent Epic
EPIC-004 — Pet State Engine (task 4 of 7).

## Objective
Make the bond model executable: the enumerated daily award events (hello +8, quest +4, variety +6) applied through clamp-at-award under the +20 daily cap, by construction (INV-5); bond monotonic everywhere (INV-3) with the 1000 plateau; the family ledger (`familiesUsed`) maintained by the same events that count; and the one-time stage-crossing moment under the `highestCelebratedStage` once-guard (`momentRequest(.bondStageReached)`, UX-10).

## Context
- Normative: **05 §4.6** (Bond ledger — FR-10; cap by construction) — read it whole; it is short and every clause binds. **PRD §3.3** (stage thresholds + earning table + legibility rules + pacing intent), **FR-10 AC-1…5**, **INV-3/INV-5/INV-7** (05 §5 invariants table), **UX-6** (hello device-agnostic, never window-gated; 03 §Appendix "hello idempotency" row: shared trigger with Q1, different windows), **G1/G2** (PRD §4 guarantees), delivery plan §3 TASK-017 row (scope + named tests).
- Domain already in place (TASK-012): `PetState.bond` (0…1000, validated), `DayRecord.helloAwarded` / `DayRecord.bondAwarded` / `DayRecord.familiesUsed: Set<QuestFamily>`, `EngineState.highestCelebratedStage`, `BondStage` + `makeBondStage(_)` (stages 150/400/750 first-value form), `QuestFamily{greet,feed,play,care,pet}` with the doc comment fixing the variety trio as **feed/play/care**, `CharacterMoment.bondStageReached(BondStage)` in the moment vocabulary (05 §4.1: `moments` = greeting / questCompleted / bondStageReached).
- TASK-016 state of the world: `familiesUsed`, `helloAwarded`, `bondAwarded`, and `pet.bond` are **never written** anywhere in the engine (reviewer-verified pass-throughs); `moments` is `[]` on every path. This task starts writing them. The interaction counters and their events are already landed: feed counts on every intent (I-1), play counts ONLY at the unified cease (`InteractionEffects.applyPlayRoundEffects` via `HandshakeMachine.completePlayRound`), care counts at settle-authorization / blanket-adjust / nap-acceptance, pats always.
- The determinism tuple is (state, event, clock, calendar, seed); everything here is pure derivation off it.

## Requirements
1. **Constants home.** New `BondRules` (the §4.6 constants home, `FoldRules`/`InteractionRules` discipline): `helloBondDelta = 8`, `questBondDelta = 4`, `varietyBondDelta = 6`, `dailyBondCap = 20` — each labeled PRD-normative (PRD §3.3 earning table). No raw award literals anywhere else (anti-echo: pinned tests may use literals; the pin files are the sanctioned echo).
2. **Clamp-at-award is the only award mechanism.** One function applies every award: `applied = min(event, dailyBondCap − day.bondAwarded, 1000 − pet.bond)`; then `pet.bond += applied`, `day.bondAwarded += applied`. `applied ≥ 0` by construction (both bounds are monotone). This single formula makes INV-5 (per-dayKey sum ≤ +20), INV-3 (monotonic), and the 1000 plateau (PRD §3.3 "a plateau, not an end") all structural. The day ledger records what was ACTUALLY applied (so the invariant is exact, not nominal).
3. **Hello (INV-7, UX-6).** The first touch (pat) intent attributed to a local dayKey awards +8 once: gated on `!day.helloAwarded`, which the award sets. Device-agnostic (the ledger never reads `intent.source` — pin a `.watch`-sourced first pat awarding identically), never window-gated (a 14:00 first touch after Q1's expiry still awards +8; a 23:50 first touch likewise). The hello rides the existing pat path (`InteractionSemantics.applyPat` → the same event that increments `patCount`); it must not disturb the pat's mood/repetition semantics from TASK-016.
4. **Quest +4 award path (mechanism only — detection is TASK-018's).** The ledger exposes the quest-completed award (callable per completion) but this task implements NO quest ticking, NO window checks, NO completion detection, NO `questCompleted` moments (all §4.8 / TASK-018). Tests drive the award path directly. Cap interplay pins from PRD §3.3/05 §4.6's own arithmetic: a 3-quest day reaches 20 as 8+4+4+4 (variety adds 0); a 2-quest varied day reaches 20 as 8+4+4+4-remaining → 8+8+4 with the +6 truncated to 4 — both sequences pinned exactly.
5. **Variety bonus (+6, feed/play/care trio).** `familiesUsed` records the trio on exactly the events that count (mirrors I-1): feed → every feed intent; play → the unified cease only; care → settle-authorization, blanket-adjust, nap-acceptance. The moment the set becomes all three, the SAME event applies the +6 award ("fired at the moment all three families are used") — set membership makes it once-per-day by construction (a later interaction cannot re-fire). Out-of-window tuck-in and declined nap start no family use (no care count ⇒ no family use).
6. **Expired-dayKey disposition.** An intent whose dayKey has no ledger entry keeps its current-state effects (TASK-016 convention) but earns NO bond: the hello's idempotency flag and the cap context both live on the ledger, and an un-ledgered award would be un-idempotent and un-clampable (INV-5 must stay verifiable). Recorded interpretation — no retroactive `DayRecord` is created (engine stays append-only).
7. **Stage-crossing moment, exactly once (FR-10 AC-4, UX-10).** After any event's state mutation, `reduce` reconciles: if `makeBondStage(pet.bond)` is above `highestCelebratedStage`, the outcome carries `momentRequest(.bondStageReached(newStage))` — appended to `moments` — and `highestCelebratedStage` advances to it. The reconciliation is state-based and runs on every event path (a hello-carrying pat can cross; crossings while the app is closed surface at the next evaluation of any kind — UX-10's deferral). The guard only advances WITH the emission, so each crossing emits exactly once ever. Fresh states (bond 0, guard `.newFriends`) emit nothing.
8. **Bond is read-only everywhere else.** No engine path lowers bond; pats beyond the day's first move nothing (G2/FR-10 AC-3); play/feed/pat mood or energy arithmetic never touches bond; TASK-015/016 pins keep passing unchanged except where this contract names the touch point.
9. **`momentFinished` stays a tolerated no-op** (presentation bookkeeping — already true in `HandshakeMachine`; don't change it).
10. **Determinism.** The ledger draws NO randomness and reads NO clock — the hello/variety detection is a pure function of (state, intent/instant already folded). Whole-state twin equality must continue to hold for identical tuples, now including bond/family fields.

## Files / Areas Likely Affected
- New: `Sources/MomoCore/BondRules.swift`, `Sources/MomoCore/BondLedger.swift`.
- Modified: `Sources/MomoCore/InteractionSemantics.swift` (pat path hello; family-use writes), `Sources/MomoCore/InteractionEffects.swift` (day-updating helper reuse; cease-side family write), `Sources/MomoCore/HandshakeMachine.swift` (cease-side variety composition, if kept there), `Sources/MomoCore/Reduce.swift` (stage reconciliation on every path; moments flow-through).
- Tests: new `BondLedgerTests` (+ property suite), extensions to `EngineReduceTests`; `InteractionFixture` gains whatever state-bending it needs (e.g. a bond preset — it already takes `bond:`).
- Not touched: `TimeFold.swift` (folds never move bond), `CharacterInterface.swift`, scanners, package layout.

## Dependencies
- TASK-016 (interactions/cease/counters) — DONE (`f61093a`). Depends on nothing else in flight.

## Constraints
- MomoCore stays Foundation-only (D-R1); purity scans + import whitelist green with NO new exemptions; zero stored `var`; immutability via `EngineState.with(...)` copies.
- TASK-015/016 pins may be superseded ONLY where this contract names the supersession (it names none — existing pins must keep passing unmodified).
- Scope control (§22/§24): no quest ticking/detection (TASK-018), no greeting moments (TASK-019+), no Watch-specific code (the engine is source-agnostic), no copy keys, no read-models.
- Anti-echo: award constants ONLY in `BondRules`; `Thresholds` keeps the stage thresholds and the 0…1000 range — do not duplicate them.

## Acceptance Criteria
- AC-1 (FR-10 AC-1 / INV-5): no randomized sequence of events on one local dayKey moves bond more than +20; `bondAwarded` equals the sum of applied awards; property test over randomized sequences (seeded, replayable).
- AC-2 (FR-10 AC-2 / INV-3): no engine action, absence duration, or replay decreases bond — property over randomized sequences spanning day rollovers.
- AC-3 (FR-10 AC-3 / G2): 1000 same-day pats move bond by exactly the day's hello (+8 once, then zero); with the hello already awarded, 1000 pats move nothing.
- AC-4 (FR-10 AC-4 / UX-10): each stage crossing emits `.bondStageReached` exactly once, including crossings detected at the next evaluation after the fact; label/descriptor derivation stays `makeBondStage` (no new threshold knowledge).
- AC-5 (FR-10 AC-5 / FR-13): stage transitions deterministic under injected clock + seeded RNG (whole-state twin equality incl. bond fields).
- AC-6 (UX-6 / INV-7): hello idempotent per dayKey, device-agnostic, never window-gated (14:00 / 23:50 first touches award; second touch same day does not).
- AC-7: PRD §4.6's two cap arithmetics (3-quest day; 2-quest varied day with +6 truncated to 4) land exactly; variety fires once at the trio-completing event and never again that day.

## Required Tests
Named per delivery plan: cap-by-construction property over randomized sequences; 1000-pats-zero-bond; hello idempotency incl. post-12:00 first touch. Plus: hello device-agnostic (`.watch` source), variety trio per-family triggers (feed intent / play cease / care authorize·blanket·nap), variety once-only + not re-fired, PRD arithmetic pins (both cap sequences), plateau at 1000 (award truncates; ledger exact), stage-crossing once-guard (incl. crossing-while-closed surfacing at next evaluation, and a pat-hello crossing), expired-dayKey no-award, monotonicity property, out-of-window tuck-in / declined nap start no family use, fresh-state no spurious moment.

## Review Requirements
Fresh independent adversarial review agent (§10/§33) after implementation, per the standing cycle; review record to `.claude/tasks/reviews/REVIEW-TASK-017.md`; the reviewer independently re-derives the cap arithmetic and probes the once-guards.

## Git Requirements
- Branch: `feature/EPIC-004-engine` (current). Implementation agent commits NOTHING.
- Final commit (orchestrator, after review + disposition): `feat(engine): TASK-017 bond ledger, variety bonus, stage moments` — atomic (sources + tests + task file + review file), TASK-ID in the message, then push (§12/§13).

## Status
APPROVED (REVIEW-TASK-017 APPROVED_WITH_MINOR_NOTES 0 MAJOR / 1 MINOR / 3 NITPICK; disposition applied pre-commit 2026-09-09 — see Reviewer Findings; suite green at **273 tests / 32 suites**; committed and pushed — see Completion Evidence).

## Implementation Notes
Ranked judgment calls (1 = most consequential), for reviewer adjudication:

1. **TASK-016 pin resolution — `helloAwarded: true` preset (contract named the pat touch point, not the pins).** `InteractionResponseTests.touchGestureZoneMap` and `RepetitionCurveTests.patCurveExact` pinned `bond == start.bond` on a day's FIRST pat — directly contradicted by the mandated hello. Rather than editing any assertion expression (the contract says pins keep passing unmodified), the fixtures now preset `helloAwarded: true`, so every assertion line stays byte-identical while correctly pinning the post-hello G2 form ("past the hello, pats bank nothing"); the hello award itself is fully pinned in `BondLedgerTests`. Two trailing comments on those assertion lines were reworded to stop misstating the old "ever" semantics. Alternative rejected: editing the assertions to expect +8 (that would supersede un-named pin text).
2. **Multi-stage jumps emit ONE moment carrying the CURRENT stage.** A jump clearing several thresholds (e.g. guard `.newFriends`, bond 700) emits `momentRequest(.bondStageReached(.bestFriends))` once — the singular form of §4.6's `momentRequest(.bondStageReached(newStage))` — not one moment per threshold. Letter-of-spec reading; per-threshold backfill would need spec support.
3. **Hello flag sets even when the award clamps to 0.** On a capped/plateaued day the first touch still consumes the day's hello (`helloAwarded: true`, `bondAwarded` unchanged): the touch happened once, and the ledger records the truth of both facts. A "flag sets only when applied > 0" variant would let a capped day's later touch re-award nothing but also re-flag — indistinguishable in effect but less honest.
4. **Rank comparison kept local to `BondLedger`.** `BondStage` is presentation vocabulary, deliberately unordered; instead of a retroactive `Comparable` conformance (which would edit unlisted `Bands.swift`), the ledger owns a private `rank(_:)`. Precedence is ledger concern, not vocabulary concern.
5. **`dailyBondCap` lives in both homes, pinned equal.** `BondRules.dailyBondCap = 20` (the award formula's operand) and `Thresholds.Bond.dailyCap` (the `DayRecord` init's INV-5 range bound) coexist; `BondRulesPinnedTests` pins them EQUAL (the `InteractionRules.tuckInWindowStartHour` == `Q6WindowStartHour` house discipline). Collapsing to one home would have edited TASK-012's `Thresholds` or made the award formula read through `Thresholds` — both unnecessary.
6. **Family writes composed at the counting sites, not in `HandshakeMachine`.** The cease-side `.play` record lives inside `InteractionEffects.applyPlayRoundEffects` (the single function both cease kinds route through), and intent-side `.feed`/`.care` records at `InteractionSemantics`'s counting return sites. `HandshakeMachine` needed only the `with(highestCelebratedStage:)` helper — no semantic change. Contract listed the composition "if kept there"; kept in the effects layer instead.
7. **Pre-existing stale doc left standing (unlisted file).** `EngineEvent.swift` still says `moments` is where "TASK-015/018 populate" (bond is 017's and now flows); the file was not in the contract's touch list, so the stale comment stands and is disclosed here rather than silently edited.
8. **InteractionFixture gained an `evaluate(...)` wrapper** (additive, mirrors `send`/`report` zero-elapsed discipline) — the stage tests needed an evaluate entry point the fixture lacked; also additive `helloAwarded:`/`familiesUsed:`/`bondAwarded:`/`highestCelebratedStage:`/`source:` parameters, all defaulted (no existing call site changes).
9. **Variety trigger uses subset arithmetic, not equality.** `completesTrio = trio ⊄ before ∧ trio ⊆ after` — correct even if a future spec ever recorded non-trio families into `familiesUsed`; an `after == trio` equality test would be wrong the moment the set could hold anything else.
10. **Quest award exposed as `awardQuestCompletion(to:dayKey:)`** (mechanism only, per contract Req 4): no detection, no windows, no moments; tests drive it directly. Name keeps `BondLedger`'s surface self-describing for TASK-018's caller.

Non-call notes: pre-existing diagnostics outside this task's files (EngineClockTests var-`let` warning, `/opt/extra/lib` linker search path in some invocations) were observed and left alone — not this task's debt. InteractionRulesPinnedTests' touch test TITLE ("bond never moves … no bond constant exists") is now historically inaccurate but its assertion (touchMoodDelta == 2) remains true and unmodified — left standing per the unmodified-pins rule, flagged for the reviewer.

## Reviewer Findings
- **REVIEW-TASK-017 (fresh adversarial reviewer, Jupiter, 2026-09-09): APPROVED_WITH_MINOR_NOTES — 0 MAJOR / 1 MINOR / 3 NITPICK.** Full record: `.claude/tasks/reviews/REVIEW-TASK-017.md`.
- Method: every normative clause independently re-derived before comparing (clamp-at-award, hello, both PRD cap arithmetics, variety counting sites, stage once-guard); 273/32 reproduced twice + an independent HEAD baseline run (delta exactly +37/+3, reconciled by @Test count); **16 adversarial probes** (mixed-device hello, replayed-intent no-op, duplicate/stale reports after a stage moment, cap-exact/plateau truncations, multi-stage jumps on both paths, variety at all four completing-event flavors incl. a refusal feed, organic midnight hello, bond-field seed-invariance, guard-relative boundaries 149/150/749/750); both scanner bites proven with exact attribution (seeded `Date()` and `import Combine` in the new files); three initial probe failures were the reviewer's own construction errors, documented.
- **MINOR-1:** one new build warning from a task file (dead `let id`, BondLedgerPropertyTests.swift:47) + handoff/status lines claiming zero warnings. **Disposition (applied):** dead line deleted, both prose lines corrected. **NITPICK-2** (17→23 count) fixed. **NITPICK-3/4** (stale `touchDelta` title; stale `moments`/`response` doc-comments in EngineEvent.swift) fixed comment-only, riding the task commit.
- All ten judgment calls adjudicated APPROVED/ACCEPTED — incl. #1: the `helloAwarded: true` fixture preset in the two TASK-016 first-pat pins is the contract's own Req-3-vs-pins tension resolved least-invasively (assertion expressions byte-identical, G2 re-scoped to its true volume-reading, the preset ADDS idempotency-gate coverage per cell, hello fully pinned in BondLedgerTests) — and #5: `dailyBondCap` in both homes is the house cross-home equality-pin discipline (`BondRules` award operand vs pre-existing `Thresholds.Bond.dailyCap` model bound), following the `tuckInWindowStartHour == q6WindowStartHour` precedent.
- Post-fix: `swift test` **273/32 green** (dead code + comments only); build clean except the two pre-existing diagnostics.

## Completion Evidence
- Commit: (this commit) — `feat(engine): TASK-017 bond ledger, variety bonus, stage moments` on `feature/EPIC-004-engine`; sources (2 new + 5 modified), tests (3 new suites + 4 modified incl. the disposition touches), this task file, REVIEW-TASK-017.md.
- Push: to `origin feature/EPIC-004-engine` — success (hash recorded in `.claude/tasks/status.md` at housekeeping).
- Tests at commit: `swift test` → `✔ Test run with 273 tests in 32 suites passed after 0.398 seconds.`; `swift build --build-tests` clean of new warnings (MINOR-1's dead-code warning removed at disposition; two pre-existing diagnostics disclosed).

## Handoff

### Completed
- `BondRules` (constants home): hello 8 / quest 4 / variety 6 / cap 20, each PRD-normative-labeled; `varietyTrio = [.feed, .play, .care]`; cross-home cap equality pinned.
- `BondLedger` (the only bond writer): `award(_:)` clamp-at-award (`min(event, cap − awarded, 1000 − bond)`, ≥ 0 by construction, ledger exact); `awardHello` (once/dayKey, device-agnostic, never window-gated, flag-truthful under clamping); `recordFamilyUse` (trio subset trigger, fires at the completing event, once/day by set membership); `awardQuestCompletion` (mechanism only); `reconcileStage` (state-based, once-guard advances only WITH emission, single current-stage moment on multi-stage jumps).
- Touch points: hello rides `applyPat`'s counting return; `.feed` records on every feed intent (refusal/decline included) via the shared count closure; `.care` records at settle-authorization, blanket-adjust, nap-acceptance; `.play` records inside `applyPlayRoundEffects` (both cease kinds); `reduce` reconciles on all three paths with `moments` flow-through and honest `changed`; `EngineState.with(highestCelebratedStage:)` added.
- Expired-dayKey: no bond, no flag, no family, no retroactive DayRecord (current-state effects kept).
- Tests: `BondRulesPinnedTests` (8 pins incl. both PRD cap arithmetics + trio membership); `BondLedgerTests` (23 tests: hello idempotency/device/window/clamp-flag, variety per-family triggers + once-only, PRD sequences, 1000-pat AC-3 both halves, plateau truncation, stage once-guard incl. evaluate-surfacing + multi-stage + report path, expired-dayKey, pat-semantics non-disturbance, twin equality); `BondLedgerPropertyTests` (seeded randomized sequences ×4/×3 seeds: cap-by-construction, monotonicity across midnight rollover, whole-trajectory twin equality, per-step ledger exactness `bond == Σ bondAwarded`, guard discipline); `EngineReduceTests` +3 every-path reconciliation tests; fixture gained additive defaulted params (`helloAwarded`/`familiesUsed`/`bondAwarded`/`highestCelebratedStage`/`source`/`evaluate` wrapper).

### Files Changed
- New: `Sources/MomoCore/BondRules.swift`, `Sources/MomoCore/BondLedger.swift`, `Tests/MomoCoreTests/BondRulesPinnedTests.swift`, `Tests/MomoCoreTests/BondLedgerTests.swift`, `Tests/MomoCoreTests/BondLedgerPropertyTests.swift`.
- Modified (contract-named): `Sources/MomoCore/InteractionSemantics.swift`, `Sources/MomoCore/InteractionEffects.swift`, `Sources/MomoCore/Reduce.swift`, `Sources/MomoCore/HandshakeMachine.swift` (helper only).
- Modified (disclosed): `Tests/MomoCoreTests/Support/InteractionFixture.swift` (additive params), `Tests/MomoCoreTests/InteractionResponseTests.swift` + `Tests/MomoCoreTests/RepetitionCurveTests.swift` (the two first-pat pins: `helloAwarded: true` fixture preset — assertion expressions byte-identical), `Tests/MomoCoreTests/EngineReduceTests.swift` (fixture bond params + 3 new tests), `.claude/tasks/active/TASK-017-bond-ledger.md` (this file).

### Tests Run
- `swift test` (full suite) — verbatim result line:
  `✔ Test run with 273 tests in 32 suites passed after 0.378 seconds.`
- Baseline at dispatch: 236 tests / 29 suites, exit 0 → +37 cases, zero regressions.
- Standing scanners all green inside the suite: engine purity scan, import whitelist, banned vocabulary, numeric-leakage.
- `swift build --build-tests`: zero errors; **corrected at disposition (REVIEW-TASK-017 MINOR-1):** the handoff's original "zero warnings from this task's files" was inaccurate — one dead-code warning existed (`let id` never used, BondLedgerPropertyTests.swift:47, the loop passes `id: i` directly); the dead line was deleted at disposition. Two pre-existing diagnostics remain and are unrelated to this task (`EngineClockTests.swift` var-let; `ld` search-path `/opt/extra/lib`).

### Test Results
All acceptance criteria exercised: AC-1 (cap-by-construction property, 4 seeds), AC-2 (monotonicity property incl. rollover, 3 seeds), AC-3 (1000-pat loop, both halves), AC-4 (once-guard incl. closed-surfacing, multi-stage, all three event paths), AC-5 (whole-trajectory twin equality), AC-6 (idempotent/device-agnostic/14:00/23:50), AC-7 (both PRD arithmetic sequences pinned exactly; variety once at the completing event).

### Known Issues
- None blocking. Disclosed for review: stale `moments` doc in `EngineEvent.swift` (unlisted file, left standing — judgment call 7); historically inaccurate TITLE on `InteractionRulesPinnedTests.touchDelta` (assertion still true and unmodified — see non-call notes); pre-existing non-task diagnostics (EngineClockTests var-`let` warning, `/opt/extra/lib` linker search path on some invocations).

### Decisions Made
- See Implementation Notes (10 ranked judgment calls; #1 — the `helloAwarded: true` pin preset — is the one needing explicit reviewer adjudication).

### Reviewer Status
NOT STARTED — fresh independent review agent required (§10/§33) before commit; review record to `.claude/tasks/reviews/REVIEW-TASK-017.md`. Reviewer should independently re-derive both PRD cap arithmetics, probe the once-guards (hello, variety, stage), and adjudicate judgment call #1.

### Commit
NONE — implementation agent committed nothing (per contract). Working tree carries the change set on `feature/EPIC-004-engine`, clean at dispatch commit `f61093a` before these edits.

### Push
NOT APPLICABLE — nothing to push yet.

### Recommended Next Step
Orchestrator: spawn the fresh review agent (contract §Review Requirements) against the uncommitted diff; after APPROVAL and finding disposition, run the task commit `feat(engine): TASK-017 bond ledger, variety bonus, stage moments` and push per §12/§13.
