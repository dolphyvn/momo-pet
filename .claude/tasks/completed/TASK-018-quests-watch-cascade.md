# TASK-018 — Quest generator + completion windows + Watch cascade

## Parent Epic
EPIC-004 — Pet State Engine (task 5 of 7).

## Objective
Implement 05-technical-architecture §4.8 completely: (1) the by-construction daily quest generator, (2) window-checked quest-completion detection ticking at TASK-016's counting events — emitting `.questCompleted` moments and driving TASK-017's `awardQuestCompletion` (+4), and (3) the §5.5 Watch quest cascade as one shared pure function. Quests become fully executable headlessly: generation at dayKey rollover, automatic completion on target, the +4 bond award, and the Watch's one-quest selection.

## Context
- **Normative sources (read all before coding):**
  - `docs/architecture/05-technical-architecture.md` §4.8 ("Quests: generation by construction + Watch cascade") — the complete normative text, including the OPEN-1 resolution box (owner-approved 2026-09-08) and the offline-pat example.
  - `docs/product/02-mvp-prd.md` §5.1 (design rules 1–7), §5.2 (catalog), §5.3 (generation constraints), §5.4 (completion & celebration), §5.5 (Watch surfacing, **amended rule 1**), FR-14/15/16 with their ACs.
  - `docs/product/06-delivery-plan.md` TASK-018 row (scope + verification column).
  - `docs/design/04-character-system.md` §9.2 — `.questCompleted` is a BARE case (no associated value; "PRD §5.4 sparkle"). The vocabulary is frozen; do not change it.
- **What already exists (TASK-012/014/015/016/017, all committed):** `QuestID`/`QuestFamily`/`QuestWindow`/`QuestCatalogEntry`/`QuestCatalog`/`QuestProgress` (`Sources/MomoCore/Quest.swift` — catalog targets+windows are the INV-6/§5.2 source of truth); `DayRecord.questSet` (exactly-3, no-duplicates failable init); `DayRecord.questGenEpoch`; `DaySeed.make(petID:localDayKey:epoch:salt:)` with `.quest` salt; `SeededGenerator`; `Thresholds.Quest` (questsPerDay 3, q1WindowClosesAtHour 12, q6WindowStartHour 20, q6WindowEndHour 7); `BondLedger.awardQuestCompletion(to:dayKey:)` (the +4 clamp mechanism, currently mechanism-only); the four counting sites (below); `TimeFold.rollover` with the designated TASK-018 placeholder seam (`[Q1,Q2,Q6]`, `questGenEpoch: 0`).
- **The counting events (I-1 mirror, TASK-016 — these are where ticks ride):** feed → every feed intent incl. refusals/asleep-declines (`applyFeed`'s `count` closure); play → the unified cease ONLY (`InteractionEffects.applyPlayRoundEffects`, cease instant = attribution instant); care → settle-authorization, blanket-adjust, nap-acceptance (`applyTuckIn`, `applyNap`); pat → every pat intent (`applyPat`). Family records (variety) already ride exactly these events.
- **Dependencies:** TASK-014 (engine core), TASK-016 (counting sites), TASK-017 (`awardQuestCompletion`) — all DONE on this branch.

## Requirements

1. **The generator** — a pure function implementing §4.8's signature: `generate(dayKey, seed, priorTwoSets, questGenEpoch) -> [QuestProgress]`.
   - Candidates: the 15 unordered pairs of the six non-anchor quests {Q2…Q7}; Q1 is the mandatory anchor of every set (FR-14 AC-3).
   - Constraints applied BEFORE drawing (by construction, not by check-and-retry):
     a. **Consecutive-repeat ban:** the pair equal to yesterday's pair is removed from the pool. Pair equality is SET equality (unordered).
     b. **Q6 3-day window:** if the two prior sets together lack Q6 → restrict the pool to the 5 pairs containing Q6. **Unknown priors count as "no Q6 credit"**: an empty (or 1-element) `priorTwoSets` forces Q6, so day 1 of a fresh install always includes Q6.
     c. The post-filter pool is never empty — ≥ 4 pairs in the tightest case (Q6-restriction active ∧ yesterday's pair contains Q6: 5 − 1 = 4). Unit-test the enumeration; the by-construction argument (not a 30-day simulation) is the proof.
   - Draw exactly 2 quests with a `SeededGenerator(seed: seed)` — exactly two draws (first pick, then second pick from the remainder). **Pin the draw count** so the seed→set mapping is stable.
   - Return `[Q1, pairA, pairB]` with the pair in catalog order — zero progress, not completed, INV-6-satisfying.
2. **Seed lineage.** The generation CALLER (dayKey rollover in `TimeFold`) derives `seed = DaySeed.make(petID:, localDayKey: landingDayKey, epoch: <current questGenEpoch>, salt: .quest)`. The generator itself takes the seed as given (pure, testable without UUIDs). This is a **documented quest-domain exception** to `Reduce.swift`'s header line "the engine performs no `DaySeed` derivation of its own" — that statement was TASK-014/015's choreography-rng lineage statement; §4.8 requires the fold to stamp generated sets, and the derivation is pure/injected-value-only (purity scan holds). Update the header sentence accordingly (scope: that one sentence, not the doc's structure).
3. **`questGenEpoch` interface fidelity.** Per §4.8's signature the generator accepts `questGenEpoch`. Its determinism role flows through the seed (the caller derives the seed FROM the epoch — salt separation, §4.10), so inside `generate` the epoch may be interface-only; document that reading explicitly in the function's doc comment (the reviewer will probe it — pre-empt with the reasoning, do not invent an extra mixing step into the RNG seed). The CURRENT epoch lives in the new constants home (Req 8) with value 1; 0 remains the legacy placeholder marker (`TimeFold`'s comment). Rollover stamps the record with the current epoch.
4. **Rollover integration.** `TimeFold.rollover` replaces the placeholder seam: a newly created day record carries `QuestGeneration.generate(...)` output (seed per Req 2, `priorTwoSets` = the two most recent existing records' non-anchor quest pairs — NEWEST FIRST; fewer than two exist → the missing tail is unknown priors per Req 1b) and `questGenEpoch` = current epoch. The record's existence check stays exactly-once (backward clocks re-find, never regenerate). **Never regenerate for a past day** — generation happens only at record creation. Extend `TimeFold.apply`'s signature with the `petID: UUID` (read `state.pet.id` in `reduce`; check all three call sites).
5. **Window-checked completion detection (ticking).** A pure engine function (new file per Req 8) invoked at each counting event AFTER the counter increment and family/variety record, with the intent's (or cease's) `dayKey` and the EVENT'S OWN local hour (from the intent's/cease's timestamp via the injected calendar — never the application instant; §4.8's window-check rule). Semantics:
   - Scope: in-set, not-yet-completed quests of the event's served families only. A pat serves `.greet` (Q1) AND `.pet` (Q7); feed serves `.feed` (Q2/Q3); the cease serves `.play` (Q4/Q5); care serves `.care` (Q6). Out-of-set quests never tick (a day with Q2 but not Q3 in set: the 2nd feed ticks nothing for Q3).
   - **Qualifying-only progress:** the window check gates the TICK. For each candidate quest: if the event's local hour is inside the quest's catalog window (`QuestWindow.contains(hour:)`), progress advances by 1 (capped at target); `completed` becomes true exactly when progress reaches the target — at this event. Out-of-window counted events tick nothing: for Q1 a post-12:00 pat leaves progress 0 (the window never re-opens — silent expiry, §5.1 rule 6); for Q6 a daytime care event leaves progress 0 until an in-window care event (the window re-opens at 20:00).
   - Attribution: always to the event's `dayKey` (the intent's localDayKey; the cease's ledger day for play — the established TASK-016 conventions). D20 day-ownership: a 00:30 tuck-in belongs to the NEW day and can complete that day's Q6.
   - An expired-dayKey event (no ledger entry) ticks nothing: no progress, no completion, no moment (consistent with TASK-017's ledger-disposition).
   - On each completion: emit `.questCompleted` (bare — frozen vocabulary) AND call `BondLedger.awardQuestCompletion(to:dayKey:)` (+4 through the clamp). A completed quest never un-completes, never re-emits, never re-awards (progress-cap makes re-entry structurally dead).
   - Site order (pin one uniform rule): counter increment → family/variety record → quest tick. The cap arithmetic makes award order non-load-bearing, but pin the order for determinism-review.
   - At most one quest completes per event *structurally* (targets and per-family progression make double completion unreachable) — handle multiples correctly anyway (loop, don't assume); you may pin "≤ 1 questCompleted per event" as a test OBSERVATION, never as a simplification.
6. **Moment plumbing.** `InteractionSemantics.apply` returns the quest moments it raised (extend the internal return shape); the play-cease path threads its moments through `HandshakeMachine` so a report-path completion emits on the report event. `reduce` composes `moments` as `[questCompleted?, bondStageReached?]` — quest completion FIRST (it causes any stage crossing), stage reconciliation second (existing `BondLedger.reconcileStage` call unchanged). `changed` stays honest by construction (whole-state equality).
7. **The Watch cascade (§5.5, amended rule 1).** One shared pure function in MomoCore (Phase 2 widgets reuse it, §8): input = today's set + the local hour; output = the selected quest or the all-done state (shape your own — a nullable QuestID loses the all-done state; an enum or equivalent is expected). Rules IN ORDER, first match wins:
   1. Q6, if in today's set ∧ incomplete ∧ local hour ∈ Q6's window (≥ 20 ∨ < 07) — **the owner-amended rule 1** (PRD §5.5 amended 2026-09-08);
   2. else Q1, if local hour < 12 ∧ incomplete (Q1 is always in-set — the anchor);
   3. else the first incomplete feed-family quest in catalog order (Q2 → Q3) — **scoped to today's set**;
   4. else the first incomplete play-family quest in catalog order (Q4 → Q5) — **scoped to today's set**;
   5. else Q7, if in today's set ∧ incomplete;
   6. else the all-complete state ("All done — see you soon" — the copy key/rendering is TASK-036/EPIC-007/008's; the cascade returns the STATE).
   - Rules 3–4 MUST scan only in-set quests: an out-of-set quest can never progress, so surfacing it would promise an uncompletable wish. Record this reading (the PRD's rules 3–4 omit the in-set qualifier; §5.5's opening "one quest, chosen from relevance" + rule 5's explicit in-set gating + the never-progresses argument justify scoping).
8. **Constants home + file organization.** New file `Sources/MomoCore/QuestGeneration.swift` hosting: the generator (Req 1), the current-epoch constant (`QuestGeneration.currentEpoch = 1` — engine-owned authority: "05 §4.8's generator version; 0 is the pre-generation placeholder marker"), and the cascade (Req 7) — one cohesive §4.8 home, `BondRules`-style header documenting authorities (§4.8/§5.5/FR-14–16 + the two recorded readings: epoch-interface-fidelity, rules-3–4-in-set-scoping). Anti-echo discipline: every number flows from `Thresholds.Quest` / `QuestCatalog`; raw literals (window hours, counts, epoch value) appear ONLY in the pin-test file. The tick function may live in the same file or a sibling — your call, keep cohesion; the purity scan (Foundation-only, no `UUID()`/`Date()`/`Calendar.current`, no ambient state) holds over everything new.

## Files / Areas Likely Affected
- New: `Sources/MomoCore/QuestGeneration.swift`, focused test suites under `Tests/MomoCoreTests/`.
- Modified: `TimeFold.swift` (rollover seam + signature), `InteractionSemantics.swift` (tick calls + moment returns), `InteractionEffects.swift` (cease tick + header discharge), `HandshakeMachine.swift` (moment threading), `Reduce.swift` (moment composition + the one header sentence), `EngineEvent.swift`/doc comments whose "TASK-018's" seams discharge, `Tests/MomoCoreTests/BondLedgerPropertyTests.swift` (moment pins — Req 9 supersession), possibly `EngineOutcome`-adjacent doc comments.

## Dependencies
TASK-014, TASK-016, TASK-017 (all DONE, branch `feature/EPIC-004-engine` @ `928f9a3` or later).

## Constraints
- **Supersession license (narrow, named):** TASK-014/015/016/017 test pins and doc statements may be superseded ONLY where this contract names the supersession: (a) `BondLedgerPropertyTests`' "bond era" moment pins (`moments.count <= 1`, the all-`bondStageReached` guard) — re-pin as: ≤ 2 moments per event, ≤ 1 of each kind, order `[questCompleted?, bondStageReached?]`; (b) `TimeFold`'s placeholder set + its seam comment; (c) `Reduce.swift`'s "engine performs no `DaySeed` derivation" sentence (quest domain only); (d) internal `apply`/`HandshakeMachine` return shapes extended for moments; (e) any existing test asserting placeholder quest sets or exact rollover record contents. Everything else stands.
- No UI, no Watch app code, no persistence/sync, no retention/pruning (EPIC-005), no celebration rendering (TASK-036), no read-models (TASK-019). The cascade function's OUTPUT type is this task's; its rendering is not.
- `CharacterMoment` stays bare `.questCompleted` — do NOT add an associated QuestID (04 §9.2 frozen; TASK-036 can diff questSets if it needs the ID; changing the vocabulary would be a model-era change outside this task).
- MomoCore stays Foundation-only (D-R1); no new external dependencies (D-R6); zero mutable module state; immutability house style; no `console`-style debug residue.
- Do not touch `QuestCatalog` targets/windows (PRD §5.2 normative, already pinned).
- The engine still draws rng ONLY where token mints require it — quest generation uses its own locally-seeded generator (per-call `SeededGenerator(seed:)`), NOT the choreography rng passed through `reduce`; the fold's draw lineage must not perturb handshake token determinism (pin: existing token/twin tests keep passing unchanged).

## Acceptance Criteria
- AC-1 (FR-15 AC-1): identical (dayKey, seed, priorTwoSets, questGenEpoch) ⇒ identical set — twin-tested; the same (day, petID, epoch) also yields the same seed via `DaySeed` (caller lineage tested).
- AC-2 (FR-15 AC-2 + TASK-006 obligation): the three variation constraints hold BY CONSTRUCTION — consecutive-pair ban and Q6-window restriction unit-proven on the pool level (incl. the ≥ 4 tightest-case enumeration); the 30-day simulation passes as the sanity check (multiple seeds, parameterized: Q6 in every rolling 3-day window; no identical non-anchor pair on consecutive days; exactly 3 quests daily; Q1 anchor always).
- AC-3 (§4.8 window checks): Q1 ticks only for local hour < 12 (11:59 ticks, 12:00 does not); Q6 only ≥ 20 ∨ < 07 (19:59 no / 20:00 yes / 06:59 yes / 07:00 no); every check evaluates the event's OWN timestamp (the §4.8 offline-pat case: an 11:30 pat applied at 12:30 ticks Q1 — pinned verbatim); attribution to the event's dayKey incl. the 00:30 tuck-in → new day's Q6.
- AC-4 (FR-16): completion is automatic at the qualifying counted event; emits `.questCompleted` and awards +4 through the clamp (cap-clamp interplay tested); never un-completes/re-awards; all-done day shows no further completions.
- AC-5 (§5.5): the cascade implements the six rules in order with the amended rule 1; **the named test exists and passes: "a 02:00 tuck-in with Q1 done selects Q6"**; the table is exhaustively tested incl. precedence edges (rule 1 over rule 2 at 02:00 with Q1 open; 11:59/12:00 boundary; rules 3–4 in-set scoping + catalog order; rule 5 in-set gating; rule 6 all-done).
- AC-6 (integration): rollover generates real sets (current epoch stamped, placeholder gone), exactly-once under backward clocks, fresh-install day 1 contains Q6; existing engine suites stay green with only the contract-named supersessions.
- AC-7 (quality): purity scan green over all new/modified files; constants anti-echo holds (a seeded violation bites with exact attribution); `swift build --build-tests` and `swift test` fully green with every new test passing and no pre-existing failure introduced.

## Required Tests
Delivery-plan verification column ("Generator determinism; candidate-space non-emptiness; window checks; named cascade test: 02:00 tuck-in with Q1 done selects Q6") plus:
1. Generator twin/determinism (AC-1) + seed-count pin (exactly two draws — a third-draw mutation changes the set).
2. Constraint unit proofs: consecutive-pair ban (alone and combined with Q6-restriction); Q6-window restriction; unknown/short priors force Q6; fresh-install day 1 contains Q6.
3. Non-emptiness: exhaustive tight-case enumeration (≥ 4 pairs) + a property over randomized prior sets: pool never empty.
4. 30-day simulation, multiple seeds, all FR-15 AC-2 clauses asserted per day (AC-2).
5. Window-check boundary table for Q1 and Q6 (AC-3) + the verbatim offline-pat pin + the 00:30 tuck-in D20 attribution pin.
6. Tick semantics: out-of-set never ticks; out-of-window Q6 defers to a later in-window care event; Q1 post-noon pat never ticks; expired-dayKey no-tick; cap interplay (quest +4 clamps at the +20 cap and at bond 1000); completion idempotence; moment ordering `[questCompleted?, bondStageReached?]` incl. a completion that crosses a stage threshold.
7. Cascade: the NAMED test + exhaustive six-rule table + twin determinism (AC-5).
8. Rollover integration: generated set + epoch stamp + exactly-once + prior-two-sets gap semantics (AC-6).
9. Updated `BondLedgerPropertyTests` moment contract (the named supersession) + a seeded sequence exercising real completion ticks end-to-end.
10. Pin suite: `QuestGeneration.currentEpoch == 1`, quest-salt seed determinism + salt separation (extend the existing DaySeed vector suite only if the quest salt is not already vector-pinned).

## Review Requirements
Independent fresh reviewer (CLAUDE.md §10/§33), adversarial: re-derive every constraint proof, probe the two recorded readings (epoch-interface-fidelity; rules-3–4 scoping), try to construct a sequence completing two quests in one event, verify the offline-pat and D20 pins against §4.8's text, confirm no out-of-contract supersession, bite the anti-echo discipline, and check the fold's draw lineage (choreography tokens unaffected). Review file: `.claude/tasks/reviews/REVIEW-TASK-018.md`.

## Git Requirements
No commit by the implementation agent. Orchestrator commits after review disposition: `feat(engine): TASK-018 quest generator, completion windows, Watch cascade` — atomic, TASK-ID included.

## Status
DONE pending commit/push (2026-09-09) — implemented, independently reviewed APPROVED_WITH_MINOR_NOTES (REVIEW-TASK-018, 0 MAJOR / 1 MINOR / 2 NITPICK), all findings disposed (MINOR-1 applied, NITPICK-1 fixed, NITPICK-2 recorded; mechanical/test-only — §11 proportionality, no fresh re-review), suite re-run green post-disposition (314/36). Atomic commit + push follow this file (§12/§13); housekeeping then moves it to `completed/`.

## Implementation Notes
Implemented by the TASK-018 implementation agent (2026-09-09, branch `feature/EPIC-004-engine`). Scope held to Requirements 1–10: (a) the §4.8 by-construction generator + rollover wiring, (b) the window-checked ticks at the four counting sites, (c) the six-rule cascade as one shared pure function. Everything ships in one new source file, `Sources/MomoCore/QuestGeneration.swift`, plus the rollover seam edit in `Sources/MomoCore/TimeFold.swift`; the four new test suites carry Required Tests 1–10.

### Judgment calls, ranked (for the reviewer)

1. **The draw reads "two quests, by construction" (§4.8's filtering sentence + §5.3's pair constraints).** The candidate space is the filtered PAIRS; two seeded draws pick the pair's members — draw 1 from the pool's quest universe (distinct quests in surviving pairs, catalog order), draw 2 from the first pick's in-pool partners (catalog order). Every constraint then holds BY construction (the drawn pair is always a pool member; nothing is ever drawn-then-rejected, so no retry loop exists to break determinism), the pool is provably never empty (see 5), and the induced pair distribution is uniform over the surviving pool in every scenario. `QuestGenerationPinnedTests.twoDrawPin` replays the recipe independently and pins that exactly two draws are consumed (a third draw or a reorder changes the mapping and fails).
2. **Rules 3–4 scan in-set only (contract Req 7's framing).** The PRD's rules 3–4 omit an in-set qualifier; rule 5 has it explicitly. Surfacing an out-of-set quest would promise an uncompletable wish (ticks never progress out-of-set quests), so the scoping is applied uniformly. Pinned in the cascade table ("an out-of-set Q2 is never surfaced…", "an out-of-set Q7 never beats the all-done state").
3. **`QuestLine` is an enum (`wish(QuestID)` / `allDone`), not a nullable `QuestID`.** A nil would lose the all-done state from "wish pending" — §4.11's `DisplayState.questLine` needs the distinction; rendering stays presentation's business (EPIC-007/008).
4. **Epoch-interface fidelity (contract Req 3).** `generate` accepts `questGenEpoch` per §4.8's signature but does NOT mix it into the RNG seed: determinism flows through the caller's `DaySeed.make(…, epoch:, salt: .quest)` (§4.10's salt separation). Re-mixing would hash the epoch twice into the same derivation for no added guarantee. `dayKey` is likewise interface-only. Both parameters keep the function's mirror of the stored record auditable.
5. **Pool-minimum analysis — CORRECTED mid-task.** An earlier draft note here (and in the source doc) claimed the contract's "≥ 4" bound was vacuous with a true minimum of 5. That was WRONG: the tightest case IS reachable — yesterday's pair contains Q6 while the OLDER prior lacks it (Q6 credit needs BOTH priors), so the ban first removes that Q6-carrying pair and the restriction keeps the remaining 5 − 1 = 4. `exhaustiveNonEmptiness` sweeps all 225 ordered prior-pair configurations and pins `tightest == 4` exactly. The source doc comment states the corrected analysis.
6. **Tick site order is pinned: counter increment → family/variety record → quest tick.** The quest award therefore participates in the same clamp-at-award ledger write as the event's own bond (hello/variety), one `bondAwarded` per day, and `questCompleted` precedes `bondStageReached` in the moment list when one event crosses both (pinned twice: `completionCrossingOrdersTheMoments`, and the re-pinned property sweep). A single event CAN complete two quests (e.g. a fresh morning pat serving both Q1 and a Q7 at 2/3): the tick loop runs per in-set qualifying quest, emitting one moment per completion — the contract's "≤ 1 completion per event" reading is structurally false and the tests document the real shape (`doubleCompletionLoops`).
7. **Rule 2's in-set check is defensive but present**, mirroring rules 3–5, so the cascade is total and well-defined even over a malformed set (pinned by `cascadeIsTotalOverEveryHour` over full/all-done/partial sets × 24 hours).
8. **Fold wiring keeps TimeFold's shape**: `apply` gained `petID` (mechanical call-site updates in TimeFoldTests; the seed lineage `DaySeed.make(petID:localDayKey:epoch:salt: .quest)` is re-derived exactly in `rolloverGeneratesTheLandingDay`, so any drift in salt, epoch, or prior order fails). Priors pass NEWEST FIRST (`suffix(2).reversed()`); generation fires only when creating a record whose dayKey is absent (exactly-once; a re-landed day keeps its ticked set — `rolloverNeverRegeneratesAPastDay`, `rolloverExactlyOnceUnderBackwardClock`); absent days in a multi-day gap stay absent (no retro-creation) and the landing day's priors see the unknown tail as no-Q6-credit (`rolloverPriorGap`).
9. **Test mechanics**: the exact-value tick pins need quest sets the `InteractionFixture` placeholder (Q1/Q2/Q6 zero-progress) cannot express, so `QuestTickTests`/`QuestGenerationPinnedTests` build `DayRecord`s directly via a local `state(questSet:…)` helper (still through `fixture.state`, so the no-fold-dynamics discipline holds), plus a `rebased(_:at:)` helper that moves the evaluation high-water mark so multi-event tests fold zero elapsed (without it, the 09:00→20:30 fold completes the nap, lands the pet `.waking`, and declines the tuck-in — fold dynamics that belong to TimeFoldTests, not here).

### Supersession license (e) — existing tests updated, with reasons

All edits are the mechanical consequence of quest generation going live; the placeholders asserted. Per file:

- `BondLedgerPropertyTests` — license (a), the named re-pin: `check()` now pins `moments ≤ 2`, order exactly `[questCompleted?, bondStageReached?]` (each at most once, quest first), stage emission iff the guard advances, and guard never advances without emission.
- `BondLedgerTests` — every first-counting-event now completes a quest, so bond pins gained `+ BondRules.questBondDelta` (hello pins, variety-feed pin, thousandPats renamed to "…+12 once, then zero", helloDoesNotDisturb); patHelloCrossing's moments became `[.questCompleted, .bondStageReached(.gettingClose)]`; threeQuestDay exercises the cap through direct quest awards.
- `EngineReduceTests` — interactionPassThrough gained `expectedMoments` per intent (ticks land on feed/feed-refusal/pat, not on the quiet cells); interactionPathReconcilesStage's crossing now composes questCompleted first.
- `InteractionResponseTests` — per-cell bond pins gained the quest delta; `planShapeAndSeams` restructured to carry per-scenario moments (awake pat / asleep pat / feed / full-refusal feed tick; exhausted play / drowsy nap do not); renamed to "…moments are exactly the counting events' quest ticks".
- `RepetitionCurveTests` — patCurveExact's first-pat bond pin gained the quest delta (every cell's 09:00 first pat completes Q1); `ceaseDayAttribution`'s mechanical `ceased.state.…` signature fix from the `HandshakeMachine.apply` tuple return (license (d)) is also listed here per REVIEW-TASK-018 NITPICK-2.
- `CareInteractionTests` — careArithmeticHonesty's 20:30 tuck-in now completes Q6 (+ quest delta).
- `EngineReduceTests`/`TimeFoldTests` — mechanical signature fix for `TimeFold.apply(petID:)`.
- `DaySeedTests` — already vector-pins the `.quest` salt (untouched, no license needed).

### New files

- `Sources/MomoCore/QuestGeneration.swift` — epoch, candidate space, pool, `generate`, `QuestLine`, `cascade`.
- `Tests/MomoCoreTests/QuestGenerationPinnedTests.swift` — the anti-echo exception: raw spec literals (epoch 1, 15 pairs, window hour tables, the named "a 02:00 tuck-in with Q1 done selects Q6", D20 day-ownership, the offline-pat case).
- `Tests/MomoCoreTests/QuestGenerationTests.swift` — twins, seed variation, shape, pool-level constraint proofs, exhaustive + randomized non-emptiness, 30-day × 5-seed simulation, rollover integration.
- `Tests/MomoCoreTests/QuestTickTests.swift` — scope, qualifying-only progress, event's-own-time, dayKey attribution, expired-dayKey no-op, clamp interplay (cap + plateau), idempotence, all-done quiet, doubles, moment ordering, play-cease report emissions.
- `Tests/MomoCoreTests/QuestCascadeTests.swift` — the 17-row six-rule precedence table (named constants), cascade twins, 24-hour totality sweep.

## Handoff

### Completed
- Requirements 1–10 of the contract, nothing else: (a) `QuestGeneration.generate` per 05 §4.8 / PRD §5.3 wired into `TimeFold.rollover` (petID threaded into `TimeFold.apply`; priors NEWEST FIRST; epoch stamped; exactly-once; never regenerates a past day); (b) window-checked completion detection at all four counting sites (feed incl. refusals, unified play cease, care events, pat) with qualifying-only progress, event's-own-timestamp hour checks, event-dayKey attribution, expired-dayKey no-op, bare `.questCompleted` moments and `BondLedger.awardQuestCompletion` (+4 through the clamp); (c) the six-rule §5.5 cascade (amended rule 1: ≥ 20:00 ∨ < 07:00) as one shared pure function returning `QuestGeneration.QuestLine`.

### Files Changed
- Sources, new: `QuestGeneration.swift` (epoch, candidate space, pool, `generate`, `QuestLine`, `cascade`); `QuestTick.swift` (window-checked completion detection invoked at the counting sites).
- Sources, edited: `TimeFold.swift` (rollover generation + `petID` param); `BondLedger.swift` (`awardQuestCompletion`); `InteractionSemantics.swift` (feed/pat/care counting-site threading); `Reduce.swift` (the DaySeed sentence, license (c), + tick-site dispatch and moment threading); `HandshakeMachine.apply` returns `(state, moments)` so the unified play cease's completions emit on the report path (Req 6); `InteractionEffects.swift` (moment threading); `EngineEvent.swift` (doc-comment provenance only).
- Tests, new: `QuestGenerationPinnedTests.swift`, `QuestGenerationTests.swift`, `QuestTickTests.swift`, `QuestCascadeTests.swift`.
- Tests, edited: `BondLedgerTests`, `BondLedgerPropertyTests` (license (a)), `EngineReduceTests`, `InteractionResponseTests`, `RepetitionCurveTests`, `CareInteractionTests` (license (e) edits); `SatietyWindowTests`, `TimeFoldTests` (mechanical `TimeFold.apply(petID:)` signature).

### Tests Run
- `swift build --build-tests`
- `swift test`

### Test Results
- BOTH FULLY GREEN: **314 tests in 36 suites passed, 0 failures** (pre-TASK-018 baseline: 273 tests / 32 suites; +41 tests, +4 suites).
- Warnings, verbatim, both pre-existing and untouched by this task:
  - `/opt/works/personal/github/momo-pet/Tests/MomoCoreTests/EngineClockTests.swift:46:13: warning: variable 'original' was never mutated; consider changing to 'let' constant`
  - `ld: warning: search path '/opt/extra/lib' not found`

### Known Issues
- None in scope. (Purity scan holds: no `UUID()`, `Date()`, `Calendar.current`, `random(` in the new source; the generator seeds its own per-call `SeededGenerator`, never the choreography rng.)

### Decisions Made
- See "Judgment calls, ranked" above; the corrected pool-minimum analysis (call 5) supersedes the earlier "minimum 5" draft claim — the tightest case of 4 pairs is reachable and pinned.

### Reviewer Status
- APPROVED_WITH_MINOR_NOTES — fresh adversarial review agent (§10/§33), full record `.claude/tasks/reviews/REVIEW-TASK-018.md`; 0 MAJOR / 1 MINOR / 2 NITPICK. MINOR-1 + both NITPICKs disposed by the orchestrator (mechanical/test-only, §11 proportionality); see the Disposition under Reviewer Findings.

### Commit
- None — per dispatch, the orchestration agent commits after review.

### Push
- None — ditto.

### Recommended Next Step
- Independent review of this task (review agent, Jupiter), then TASK-019 per EPIC-004's remaining task list.

## Reviewer Findings
Independent adversarial review complete (§10/§33; full record: `.claude/tasks/reviews/REVIEW-TASK-018.md`). **APPROVED_WITH_MINOR_NOTES** — MAJOR 0 / MINOR 1 / NITPICK 2. Reproduced `swift test`: 314 tests / 36 suites, 0 failures; HEAD `60e4fe5` untouched; inventory exact; purity, anti-echo (seeded divergence bites with exact attribution), supersession audit (nothing beyond license items (a)–(e)), and the fold's draw-lineage checks all clean. Both open questions adjudicated independently: (1) **Q6-credit rule** — the strong reading (credit iff BOTH priors carry Q6; `count == 2` correctly implements "unknown priors = no credit") is the only reading under which §4.8's "≥ 4 pairs in the tightest case (5 − 1)" arithmetic is coherent and reachable; PRD §5.3's window invariant holds under BOTH readings (verified: the 30-day sim stays green under a seeded weak-reading mutation), so the non-emptiness parenthetical is the discriminator; the `tightest == 4` pin is correct; (2) **moment multiplicity** — the implementation is right and the contract's premise was wrong: a pat serves Q1 (window-gated) and Q7 (all-day), so pats at 13:00/14:00 plus an 11:30 pat applied at 14:30 (§4.8's own offline-pat shape) complete BOTH on one event via the full production path (reviewer probe passed), and a simultaneous stage crossing makes 3 moments. All nine judgment calls APPROVED; Required Tests 1–10 present and mutation-validated (5 seeded mutations bit with exact attribution, incl. the two-draw pin and the tightest-case sweep). **MINOR-1 (apply at disposition; test-only; inside license (a)):** `BondLedgerPropertyTests.check()`'s re-pin (`moments.count <= 2`, ≤ 1 of each kind) is a false-but-latent invariant — amend to ≤ 3 moments, ≤ 2 `.questCompleted` (one per completing quest; Q1+Q7 is the only reachable pair), ≤ 1 `.bondStageReached` always last, quest moments first, with a comment noting the generator itself cannot reach a double (why the bound exceeds what the suite observes) and that `QuestTickTests.doubleCompletionLoops` is the live coverage; record the contract correction (Req 5's "structurally unreachable" premise is disproven; the tick loop is correct). Mechanical test-bound edit — no fresh re-review required (§11 proportionality). NITPICK-1: uniformity overclaim in `QuestGeneration.swift`'s draw doc comment (uniform only in the unrestricted/Q6-restricted scenarios; ban-active pools skew — no behavioral impact; one-line comment fix). NITPICK-2: `RepetitionCurveTests.ceaseDayAttribution`'s mechanical `ceased.state` signature fix (license (d)) is unlisted in the notes above. No MAJOR findings; nothing blocks commit once MINOR-1 lands.

**Disposition (orchestrator, 2026-09-09):** MINOR-1 APPLIED — `BondLedgerPropertyTests.check()` re-pinned to ≤ 3 moments / ≤ 2 `.questCompleted` / ≤ 1 `.bondStageReached` always last (quest moments first), with the can't-reach-a-double comment and the `doubleCompletionLoops` live-coverage pointer; suite header doc kept in step. NITPICK-1 FIXED — both `QuestGeneration.swift` uniformity claims scoped to the two star-shaped scenarios with the REVIEW-TASK-018 NITPICK-1 pointer. NITPICK-2 RECORDED — bookkeeping line added to the supersession notes below. **Contract corrections recorded (both favor the implementation):** (1) Req 1b's "TOGETHER lack" wording, read in isolation, suggested the weak Q6-credit reading; the adjudication CLARIFIES it through Req 1c's own tightest-case arithmetic — the strong reading (credit iff both priors carry Q6) is the normative one and the code conforms; (2) Req 5's "at most one completion per event structurally" premise and license (a)'s named re-pin inherited a disproven premise — the tick loop is correct, and the re-pin now says so. Suite re-run post-disposition: `swift test` = 314 tests / 36 suites, 0 failures.

## Completion Evidence
- Tests: `swift build --build-tests` + `swift test` — **314 tests / 36 suites, 0 failures** post-disposition (pre-task baseline 273/32; +41/+4). Warnings: only the two pre-existing ones (EngineClockTests `var original`; `/opt/extra/lib` linker search path).
- Review: `.claude/tasks/reviews/REVIEW-TASK-018.md` — APPROVED_WITH_MINOR_NOTES (0 MAJOR / 1 MINOR / 2 NITPICK); MINOR-1 + both NITPICKs disposed pre-commit (mechanical, §11 proportionality — no fresh re-review required).
- Commit: this commit (atomic; sources + tests + task file + review file). Hash recorded in `.claude/tasks/status.md` at housekeeping.


