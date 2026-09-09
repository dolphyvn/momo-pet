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
READY (2026-09-09 — contract materialized by the orchestration agent from 05 §4.8, PRD §5.1–5.5 + FR-14–16, amended §5.5 rule 1, delivery plan TASK-018 row, and the committed TASK-012/014–017 code shapes).

## Implementation Notes
(To be filled by the implementation agent — include the §28 Handoff block before reporting.)

## Reviewer Findings
(To be filled by the review agent.)

## Completion Evidence
(To be filled at disposition: test command + counts, review file, commit hash.)
