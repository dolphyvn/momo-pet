# TASK-019 — Display read-models + copy-key selection

## Parent Epic
EPIC-004 — Pet State Engine (task 6 of 7).

## Objective
Implement 05-technical-architecture §4.9 + §4.11: (1) the `DisplayState` surface read-model and `makeDisplayState(_:at:calendar:)`, (2) the `makeCharacterDisplayState(_)` derivation over 04 §9.2's existing shape, (3) the §4.9 copy-selection surface — the VoiceOver word/phrase keys per 04 §3.5 (OBS-1), the day-stable `momo.line.react.<family>.<nn>` lineKey selection that fills TASK-016's documented nil seam, and the time-slot derivation with its day-stable pick — and (4) the greeting selector + `.evaluate`-path greeting moment emission (the code's own provenance: "greeting is TASK-019+'s", `EngineEvent.swift`). INV-11 throughout: the engine outputs catalog keys, never composed prose.

## Context
- **Normative sources (read all before coding):**
  - `docs/architecture/05-technical-architecture.md` §4.11 (the `DisplayState` sketch — field-for-field normative — and `makeCharacterDisplayState`; the consumption paragraph), §4.9 (copy selection; **OBS-1 resolution**: the VoiceOver formula is 04 §3.5's, `DisplayState` carries resolved word/phrase KEYS, the a11y formatter renders the formula from the catalog; **OBS-2 resolution**: the 12-word max scopes to the `momo.line.<slot>` visual classes, `momo.line.moment` exempt), §4.10 (day-stable seeds; the `.copy` salt; epoch semantics), §4.2 trigger table ("Foreground / scenePhase → active … absence greeting"), §4.1 (`moments` includes greeting).
  - `docs/design/04-character-system.md` §3.5 (the binding VoiceOver formula "*{Name} feels {mood word} and {energy phrase}*" + stage sentence; mood words **joyful / content / quiet / low** with **Wistful announced as "quiet"**; energy phrases **"has plenty of energy" / "is relaxed" / "is getting sleepy" / "is very sleepy"**), §9.2 (`CharacterDisplayState`, `ResponsePlan.lineKey` — types already in MomoCore), §10.1 rule 7 + §10.4 (the line classes; slots morning/day/evening/night/greeting/care-moment; react families **touch/feed/play/care**; "Slot selection by local time (D11 windows); within a slot, the engine selects via the seeded RNG (day-stable — same day, same line per context)"; react lines are accessibility-only, never body copy), §8.4 (the dot key-namespace convention).
  - `docs/product/02-mvp-prd.md` §3.3 (the four stage descriptor lines — **normative prose**: "Just getting to know each other." / "Momo perks up when you arrive." / "Momo knows your rhythms." / "Quietly inseparable."), FR-12 AC-2 (first open after **≥ 36 h** shows the warm missed-you greeting, no guilt vocabulary), FR-20 AC-4 (no string literals in views — keys only).
  - `docs/design/03-ux-architecture.md` §4 (open flow: morning first-open greeting class; ≥ 36 h → missed-you class; **night open 22:00–07:00 → "Shhh… Momo is sleeping"**), §7 reservation (the five presentation units; one read-model, three surfaces), §10 (the a11y template — **superseded by 04 §3.5 per OBS-1**; the status row's mood/energy/stage words), UX-12 (contextual line priority reaction > greeting > ambient — PRESENTATION-side; not this task's).
  - `docs/product/01-product-review.md` **D11**: night window = local 22:00–07:00.
  - `docs/product/06-delivery-plan.md` TASK-019 row (scope + verification column: "Derivation golden tests; slot-window selection tests; day-stability of picks").
- **What already exists (all committed):** `EngineState` (`lastOpenedAt` stamped by `.evaluate` — "every in-session evaluation is an open of the pet, the TASK-014 convention the greeting consumer will read"; `pet.name`; `state.mood/.energy/.bond/.wakefulness/.activity/.satietyPhase`; `days` ledger newest-last); `CharacterDisplayState`/`ResponsePlan`(with the nil `lineKey`)/`CharacterMoment`(with `.greeting(GreetingKind)`)/`GreetingKind`(`freshMorning/welcomeBack/missedYou/nightGlance`)/`HapticID` in `CharacterInterface.swift`; `ReactionKeys` (whose header documents the seam: "Copy selection is TASK-019's"); `Bands.makeMoodBand/makeEnergyBand/makeBondStage`; `QuestGeneration.QuestLine` (`.wish(QuestID)`/`.allDone`) + `cascade(questSet:localHour:)`; `QuestCatalog`; `DaySeed.make(petID:localDayKey:epoch:salt:)` with the `.copy` salt already vector-pinned; `SeededGenerator`; `Thresholds`; `DayKey.make(from:calendar:)`; the four pre-existing moment/kind paths (quest ticks TASK-018, stage reconcile TASK-017).
- **Dependencies:** TASK-014/015/016/017/018 — all DONE on this branch.

## Requirements

1. **`DisplayState` + `makeDisplayState(_:at:calendar:)` (05 §4.11).** The type field-for-field per the §4.11 sketch: `petName: String` (= `pet.name`); `moodWordKey`/`energyPhraseKey` (Req 3's keys); `bondStage: BondStage` (= `makeBondStage(state.bond)`) + `bondDescriptorKey` (Req 3); `questLine: QuestLine` (= `QuestGeneration.cascade(questSet:localHour:)` — the cascade output type TASK-018 shipped; the wish's own copy key is rendering's, EPIC-007/008; the local hour comes from `now` via the INJECTED calendar — never any ambient read); `wakefulness: Wakefulness`; `greeting: GreetingKind?` (Req 5 — the stamp's kind). The set input to the cascade is today's `DayRecord.questSet` (the record matching `DayKey.make(from: now, calendar:)`); an absent record cascades over an empty set → `.allDone` (no wishes can exist without a record; matches the engine's absent-days-stay-absent semantics — recorded reading).
2. **`makeCharacterDisplayState(_)` (04 §9.2 via 05 §4.11).** Pure derivation over `EngineState` alone: `moodBand`/`energyBand` via the `Bands` derivations, `bondStage` via `makeBondStage`, `wakefulness`/`activity` direct, `satietyHint` from `state.satietyPhase` (the phase is total — carry it; the field's optionality is the 04 §9.2 shape's, keep it optional), `momentRequest` = the in-effect L4 request = the current greeting stamp's kind (Req 5), else nil (recorded reading — stage/quest moments are event-transient and already delivered via `EngineOutcome.moments`; the only L4 request that OUTLIVES its event is the open greeting).
3. **The OBS-1 vocabulary keys (04 §3.5 + PRD §3.3).** Key selection with ZERO variation — a fixed lookup, one string per band/stage:
   - mood word: joyful→joyful / content→content / **wistful→"quiet" (the 04 §3.5 remap — pin it by name)** / low→low;
   - energy phrase: the four 04 §3.5 verb phrases verbatim, mapped from EnergyBand in band order;
   - bond descriptor: the four PRD §3.3 descriptor lines verbatim, mapped from BondStage.
   **Recorded reading (keyspace):** §4.9's "exactly three catalog namespaces" governs the VARIATIONAL line classes (slots, react, moment); the fixed state vocabulary is a lookup, not a selection, and gets its own keyspace under the §8.4 dot convention — `momo.line.vocab.<field>.<band>` (e.g. `momo.line.vocab.mood.wistful`, `momo.line.vocab.energy.drowsy`, `momo.line.vocab.stage.gettingClose`) — so the three variational classes stay pure and the INV-11 discipline (keys, never prose) holds uniformly. Catalog ENTRIES for these keys land in the presentation era (EPIC-007); MomoCore mints the key strings only — `Apps/Shared/MomoCopy.xcstrings` is untouched by this task.
4. **The §4.9 copy-selection surface (constants home + pure selection).** One new MomoCore home (suggested: `CopyRules` constants + a `LineSelection` pure surface; naming/cohesion is yours, keep it cohesive and document authorities like `BondRules`/`FoldRules`):
   a. **React-family line keys:** every `ResponsePlan` the engine mints gains `lineKey = momo.line.react.<family>.<nn>` — `<family>` from the intent's family (pat/greet → `touch`, feed → `feed`, play → `play`, care → `care`, per 04 §10.4), `<nn>` a **day-stable seeded pick** per (petID, the intent's dayKey, family): seed = `DaySeed.make(petID:, localDayKey:, epoch:, salt: .copy)`, then a deterministic seeded draw (recipe yours — but PIN the draw count/recipe exactly like TASK-018's `twoDrawPin`, so the seed→key mapping is stable). The pool size is an explicit input from the constants home (`reactLineCount[family]`, currently **1** — the placeholder era; real pools land EPIC-006/007, and the home documents the bump obligation: a catalog change ⇒ bump the copy epoch per §4.10's salt-epoch semantics). The selection function is pure over an explicit pool size so tests exercise real variation with synthetic sizes.
   b. **Time slots + slot line keys:** the four time slots from the local hour — **night = D11's 22:00–07:00 (normative)**; the awake complement subdivides as morning 07:00–12:00, day 12:00–18:00, evening 18:00–22:00 (engine-owned subdivision — constants with authority labels; boundary rule: the cut-off hour opens the NEXT slot, matching the house convention, e.g. 12:00 is `day`, 22:00 is `night`). A day-stable slot line key (`momo.line.<slot>.<nn>`, same seeded-pick shape as (a)). The `greeting` and `care-moment` slots are CONTEXT slots (chosen by UX-12's presentation priority), not time slots — expose the keyspace only, no derivation (recorded reading).
   c. **Copy epoch:** `CopyRules` carries the current copy-selection epoch (value **1**; `0` = the pre-selection placeholder marker, mirroring the `QuestGeneration.currentEpoch` discipline) used by the `.copy` seed derivation.
   d. **The Reduce header sentence (named supersession):** TASK-018 scoped it to "the quest domain"; re-scope to "the quest and copy domains" (the derivation remains pure/injected-value-only — the same argument TASK-018 recorded).
5. **The greeting selector + emission.** The code's own provenance assigns greeting to this task ("greeting is TASK-019+'s", `EngineEvent.swift`; `EngineState.lastOpenedAt` "greeting selection consumes it"). A pure selector over (previousOpen, now, calendar):
   - gap below the re-greet floor → nil (an in-session re-evaluation is not an arrival; floor = a `Thresholds.Greeting` constant, engine-owned, value 5 minutes — scenePhase flapping must not re-greet; recorded judgment call);
   - gap ≥ **36 h** (FR-12 AC-2 — a `Thresholds.Greeting` constant) → `.missedYou`;
   - `now` inside the night window (D11 22:00–07:00) → `.nightGlance` (UX §4 flow 8's "Shhh… Momo is sleeping" class);
   - the previous open's local dayKey ≠ now's (first open of the local day) → `.freshMorning` (UX §4 flow 1);
   - else → `.welcomeBack`.
   The `.evaluate` path applies the selector to the PRE-stamp `lastOpenedAt` (the previous open — before `reduce` stamps `lastOpenedAt = now`), and on a non-nil kind: emits `.greeting(kind)` in the outcome's `moments` AND stamps a new `EngineState` field `lastGreeting` (kind + instant — the minimal honest carrier; named supersession (c)). `DisplayState.greeting` and `CharacterDisplayState.momentRequest` read the stamp; the presentation layer owns transience/fading (a stamp persists until the next greeting — it is "the greeting in effect for the current open", not a timer). The initial-state value is nil (onboarding's own flow is S1–S3's, not a greeting).
6. **Moment contract extension (TASK-018's ≤ 3 bound survives).** `.greeting` is possible ONLY on the evaluate path, at most one, and FIRST when present (the open's hello precedes any stage reconciliation from the fold); `≤ 2 questCompleted` stays interaction/report-only; `≤ 1 bondStageReached` stays LAST; overall ≤ 3 per event still holds (evaluate emits at most greeting + stage = 2). Extend the `BondLedgerPropertyTests` moment re-pin accordingly (named supersession (a) continuation: allow `.greeting`, ≤ 1, first, on evaluate steps; the property's `.evaluate` steps WILL greet — the fixture clock advances 10–20 min per step, past the floor — document that in the pin).
7. **Constants home + anti-echo.** Every number — 36 h, the re-greet floor, the night window, the slot hours, pool counts, the copy epoch — flows from the constants homes (`Thresholds` for thresholds; `CopyRules` for selection shape); raw literals appear ONLY in pin-test files. Key-string TEMPLATES (`momo.line.react.` + family + index) are namespace structure, not composed prose — the INV-11/no-string-literal discipline and the banned-vocabulary scan stay green; OBS-2's 12-word rule is a catalog-era constraint enforced by the TASK-010 scanner when real pools land (nothing to scan in MomoCore).
8. **Purity.** Foundation-only; no `Bundle`, no `Locale`, no `Calendar.current`, no `Date()`, no ambient state; `makeDisplayState`'s only time input is `now` + the injected calendar; `makeCharacterDisplayState` takes state alone; all new selection functions are value-in/value-out with locally-seeded generators (never the choreography rng — TASK-018's lineage discipline).
9. **No UI, no catalog prose, no Watch code.** `ResponsePlan.haptic` stays nil (presentation-owned vocabulary); no app-target file changes; `MomoCopy.xcstrings` untouched.

## Files / Areas Likely Affected
- New: `Sources/MomoCore/DisplayState.swift` (or a §4.11-named home) hosting `DisplayState` + both derivations; a `CopyRules`/selection home (Req 4); focused test suites under `Tests/MomoCoreTests/`.
- Modified: `EngineState.swift` (`lastGreeting` field + init), `Reduce.swift` (evaluate-path greeting + the header sentence re-scope), `InteractionSemantics.swift` (lineKey fill at plan minting), possibly `EngineEvent.swift` (moment doc provenance), `Thresholds.swift` (`Greeting` namespace), `Tests/MomoCoreTests/BondLedgerPropertyTests.swift` (Req 6 re-pin extension), mechanical plan/moment pin updates in `InteractionResponseTests`/`EngineReduceTests`, fixture updates for the new state field.

## Dependencies
TASK-014, TASK-015, TASK-016, TASK-017, TASK-018 (all DONE, branch `feature/EPIC-004-engine` @ `d52c146` or later).

## Constraints
- **Supersession license (narrow, named):** (a) `BondLedgerPropertyTests`' moment re-pin — extended for `.greeting` per Req 6; (b) `Reduce.swift`'s DaySeed header sentence — re-scoped to quest + copy domains; (c) `EngineState` gains `lastGreeting` (+ every construction site/fixture threads it); (d) `ResponsePlan.lineKey` nil → filled (TASK-016's documented seam); (e) mechanical updates to tests pinning exact plan/moment contents (`InteractionResponseTests`, `EngineReduceTests`, `RepetitionCurveTests` cease pins, `QuestTickTests` where plans are asserted). Everything else stands.
- Do not touch `CharacterDisplayState`/`ResponsePlan`/`CharacterMoment`/`GreetingKind` shapes (04 §9.2 frozen — the derivations consume them as-is).
- Do not touch `QuestGeneration.cascade` or `QuestCatalog` (TASK-018 reviewed surface).
- MomoCore stays Foundation-only (D-R1); zero mutable module state; immutability house style; no debug residue.
- No catalog edits (`MomoCopy.xcstrings` seed stays exactly 3 placeholder keys — TASK-011's pin suite enforces it).

## Acceptance Criteria
- AC-1 (§4.11 fidelity + delivery row): `DisplayState` matches the §4.11 sketch field-for-field; both derivations are golden-tested (full-vector golden tests, one per consumer family, on a fixed fixture state + fixed instants incl. a DST-adjacent instant).
- AC-2 (OBS-1): the vocabulary map is exact and pinned — the Wistful→"quiet" remap by name; the four energy phrases and four stage descriptors verbatim against 04 §3.5 / PRD §3.3.
- AC-3 (day-stability): same (petID, dayKey, family/slot) ⇒ same key all day; different days vary (statistically proven across a seeded multi-day sweep with synthetic pool sizes ≥ 2); the draw recipe is pinned (a reordered/extra draw changes the mapping and fails — the TASK-018 twoDrawPin pattern).
- AC-4 (slots): the boundary table is exhaustively pinned — 06:59 night / 07:00 morning / 11:59 morning / 12:00 day / 17:59 day / 18:00 evening / 21:59 evening / 22:00 night (D11-exact night; engine-owned subdivision constants).
- AC-5 (seam): every engine-minted `ResponsePlan` carries its family's day-stable react lineKey (all four families; declined/asleep paths included — every plan is announced); haptics stay nil; existing token/twin determinism pins stay green unchanged.
- AC-6 (greeting): the rule table is exhaustively tested — floor gate (below → nil), 36 h (≥ → missedYou even inside the night window), nightGlance (window open, gap ≥ floor), freshMorning (dayKey change outside the window, incl. the 14:00 first-open case), welcomeBack (same-day return ≥ floor); the evaluate path emits the moment + stamps the state reading the PRE-stamp `lastOpenedAt`; the stamp projects into both read-models; the property re-pin (Req 6) is green.
- AC-7 (INV-11): no composed user-facing strings anywhere new; the standing scans (D-R1, banned vocabulary, token purity, engine purity) stay green with no new exemptions.
- AC-8: `swift build --build-tests` + `swift test` fully green; every new test passing; no pre-existing failure introduced.

## Required Tests
Delivery-plan verification column ("Derivation golden tests; slot-window selection tests; day-stability of picks") plus:
1. Golden `makeDisplayState` vectors (incl. absent-day-record `.allDone`, night-hour cascade, greeting stamp projection) and golden `makeCharacterDisplayState` vectors (all bands × stage × wakefulness corner at least once).
2. Vocabulary pins: mood ×4 incl. the named Wistful→quiet pin; energy ×4 verbatim; descriptors ×4 verbatim.
3. Slot boundary table (AC-4's eight rows) + 24-hour totality sweep.
4. Day-stability: twin determinism; within-day stability across many hours; cross-day variation sweep (multiple seeds, synthetic pool sizes 1–5); draw-recipe pin (exactly the pinned draws).
5. React lineKey integration: one plan per family carries the right keyspace + day-stable key; duplicate-intent replay produces the same plan; the copy epoch participates in the seed (bump ⇒ different key — pin the epoch's role via the DaySeed derivation).
6. Greeting table (AC-6) + evaluate-path emission/stamp pins + the property-suite re-pin; a midnight-crossing open (dayKey change during the night window → nightGlance, not freshMorning).
7. Constants anti-echo: a seeded divergence bites with exact attribution (TASK-018's proven pattern).
8. Purity scan green over all new/modified files.

## Review Requirements
Independent fresh reviewer (CLAUDE.md §10/§33), adversarial: re-derive the greeting precedence order and its edge cases (36 h during the night window; first-open at 06:30; first-open at 14:00; floor-gated flapping); probe the vocab-keyspace reading against §4.9's "exactly three namespaces" and INV-11; challenge whether `lastGreeting` is the minimal honest carrier (could `DisplayState.greeting` be derived without a state stamp? try and disprove); verify the OBS-1 key-carriage split (DisplayState carries keys; the formatter renders); re-derive the slot boundaries against D11; mutation-bite the constants (36 h, floor, slot hours, epoch); confirm the choreography-rng lineage is untouched; audit the supersession license (nothing beyond (a)–(e)). Review file: `.claude/tasks/reviews/REVIEW-TASK-019.md`.

## Git Requirements
No commit by the implementation agent. Orchestrator commits after review disposition: `feat(engine): TASK-019 display read-models and copy-key selection` — atomic, TASK-ID included.

## Status
REVIEWED — disposition applied 2026-09-09 (APPROVED_WITH_MINOR_NOTES, 0 MAJOR; MINOR-1/MINOR-2/NITPICK-1 fixed in-disposition, OBS-A–D recorded; suite re-verified 363/42 green; atomic task commit follows this edit). Was IN_REVIEW — implementation complete, fully green; was READY — contract materialized by the orchestration agent from 05 §4.9/§4.10/§4.11, 04 §3.5/§9.2/§10.1/§10.4, PRD §3.3 + FR-12, UX §4/§7/§10, D11, delivery plan TASK-019 row, and the committed TASK-012–018 code shapes.

## Implementation Notes
Implementation complete 2026-09-09 (implementation agent, Jupiter). `swift build --build-tests` green; `swift test` → **"Test run with 361 tests in 42 suites passed after 0.437 seconds."** (baseline 314/36 ⇒ +47 tests, +6 suites; only warning is the environmental `ld: warning: search path '/opt/extra/lib' not found`, present at baseline). **Not committed/pushed — awaiting independent review per CLAUDE.md §9–11.**

### New files
- `Sources/MomoCore/CopyRules.swift` — the §4.9 constants home (copyEpoch, slot cut-offs, LineSlot, ReactFamily, pool counts; per-constant authority labels; FoldRules hours referenced, never restated).
- `Sources/MomoCore/LineSelection.swift` — `LineSelection` (copySeed / pick / reactLineKey / slotLineKey) + `VocabularyKeys` (the OBS-1 fixed lookup).
- `Sources/MomoCore/DisplayState.swift` — `DisplayState`, `makeDisplayState(_:at:calendar:)`, `makeCharacterDisplayState(_:)`, `Greeting.select`.
- Tests: `VocabularyKeyTests`, `CopySlotTests`, `LineSelectionTests`, `GreetingSelectionTests`, `CopySelectionPinnedTests`, `DisplayStateTests` (Required Tests 1–7; purity scan auto-covers — Required Test 8 green).

### Modified files
- `Thresholds.swift` — +`Greeting` namespace (regreetFloorMinutes 5 engine-owned; missedYouAfterHours 36 FR-12 AC-2 PRD-normative).
- `EngineState.swift` — +`GreetingStamp` struct, +`lastGreeting: GreetingStamp?` as LAST field, NO init default (license (c) threading honored).
- `HandshakeMachine.swift` — all six `with(...)` helpers thread `lastGreeting`; +`with(lastGreeting:)`.
- `Reduce.swift` — evaluate path: `Greeting.select` over the PRE-stamp `lastOpenedAt`, stamp written after mint/stamps, moments = greeting FIRST + reconciled; header DaySeed paragraph re-scoped to "quest-domain … and copy-domain" (license (b)).
- `InteractionSemantics.swift` — plan helper now family-aware (`LineSelection.reactLineKey`); all 21 call sites pass the intent (license (d)).
- `EngineEvent.swift` — moments doc provenance sentence.

### Test supersession ledger (license (a)/(e), mechanical)
- `InteractionFixture.swift` + 5 suites: `lastGreeting: nil` threaded at all 8 EngineState construction sites (QuestGenerationTests, WakefulnessHandshakeTests, EngineReduceTests ×3, QuestTickTests, TimeFoldTests).
- Plan pins filled with the family's `.00` key: InteractionResponseTests (23, per-line by family incl. `planShapeAndSeams` scenario rewrite + header), CareInteractionTests (9, care), PlayRoundTests (2, play), WakefulnessHandshakeTests:260 (touch), TimeFoldTests:490 (touch), BondLedgerTests:406 (touch). EngineReduceTests: `evaluateStampsBoth` moments → `[.greeting(.freshMorning)]` + stamp pin; `interactionPassThrough` per-index key table. DomainInvariantsTests:276 deliberately UNTOUCHED (INV-11 type-shape construction, not an engine-minted plan).
- `BondLedgerPropertyTests` re-pin (license (a)): StepKind threaded into `check`; `.greeting` ≤ 1 FIRST, evaluate-only; switch now exhaustive (no default); suite header documents that evaluate steps WILL greet (10–20-min steps > 5-min floor; fixture anchors lastOpenedAt at the prior step).
- `ThresholdsPinnedToPRDTests` — +greeting thresholds raw pins (5/36).

### Judgment calls (ranked)
1. **Wistful key is band-named** (`momo.line.vocab.mood.wistful`), catalog entry announces 04 §3.5's "quiet" — keeps the band→key lookup total/mechanical; remap pinned by name in `VocabularyKeyTests.wistfulKeyStaysBandNamed`. (Req 3's "pin by name".)
2. **Vocabulary gets its own keyspace** `momo.line.vocab.<field>.<band>` rather than folding into a variational class — it is a lookup (zero variation), not a §4.9 selection; keeps the three variational classes pure.
3. **Night rule = D11 normative, cut-offs 12/18 engine-owned** per §4.9's text; slot derivation REFERENCES FoldRules (no restatement). Cut-off hour opens the NEXT slot; `timeSlot` provably never returns the context slots.
4. **The pinned draw recipe is exactly ONE draw** (seed → `% poolCount`), mirroring TASK-018's twoDrawPin discipline; generators are call-local — the choreography rng is never touched (proven by `rngDrawDiscipline` staying green).
5. **`GreetingStamp` persists until the next greeting** — the greeting is the only L4 moment that outlives its event (both read-models project it); presentation owns fading. Initial nil = onboarding's own flow is the greeting.
6. **Rule order in the selector**: floor → missedYou (outranks the hour) → nightGlance (outranks the dayKey change — midnight crossing is nightGlance, not freshMorning) → freshMorning → welcomeBack. Backward gaps fall out as nil.
7. **`interactionPassThrough`'s replay pin stays response-nil** (INV-10 no-op) — the "duplicate-intent replay same plan" contract point is covered by two DISTINCT fresh same-family intents carrying the same day-stable key (`LineSelectionTests.duplicateIntentReplayCarriesSamePlanKey`), which is the day-stability claim; an INV-10 replay mints no plan at all.
8. **`EngineState` init keeps NO default for `lastGreeting`** — license (c) says thread it; house convention is explicit memberwise args.
9. **`pick` traps on pool 0 by modulo panic** (documented) rather than fabricating an index — pool counts come from the constants home, never 0 there.

### Known issues / follow-ups (non-blocking)
- `ReactionKeys.swift` header ("lineKey/haptic seams … this task leaves both nil") is now historically stale — OUTSIDE the supersession license (not one of the five named files), so untouched; one-line doc fix recommended during review or as a reviewer-authorized mechanical touch-up.
- The `.00` index in behavior-test expectations derives from the pool-count constant (`count − 1`); raw `.00` literals live only in `CopySelectionPinnedTests` (they bite together with the epoch-bump obligation).

## Handoff

### Completed
All 9 contract requirements; Required Tests 1–8; supersession license (a)–(e) exercised exactly as named.

### Files Changed
New: `Sources/MomoCore/{CopyRules,LineSelection,DisplayState}.swift`; `Tests/MomoCoreTests/{VocabularyKeyTests,CopySlotTests,LineSelectionTests,GreetingSelectionTests,CopySelectionPinnedTests,DisplayStateTests}.swift`. Modified: `Sources/MomoCore/{Thresholds,EngineState,HandshakeMachine,Reduce,InteractionSemantics,EngineEvent}.swift`; `Tests/MomoCoreTests/{BondLedgerPropertyTests,BondLedgerTests,CareInteractionTests,EngineReduceTests,InteractionResponseTests,PlayRoundTests,QuestGenerationTests,QuestTickTests,ThresholdsPinnedToPRDTests,TimeFoldTests,WakefulnessHandshakeTests}.swift` + `Support/InteractionFixture.swift`.

### Tests Run
`swift build --build-tests` && `swift test` (full suite, in-suite scanners included).

### Test Results
`Test run with 361 tests in 42 suites passed after 0.437 seconds.` — 0 failures, 0 skipped. Baseline 314/36. Purity scan + import whitelist + banned-vocabulary scanners green, no new exemptions. `MomoCopy.xcstrings` untouched (3 placeholder keys stand). `ResponsePlan.haptic` nil everywhere.

### Known Issues
See follow-ups above (stale ReactionKeys header only).

### Decisions Made
Judgment calls 1–9 above.

### Reviewer Status
APPROVED_WITH_MINOR_NOTES (REVIEW-TASK-019, 0 MAJOR) — disposition applied: MINOR-1 pin added, MINOR-2 header fixed, NITPICK-1 assertion added, OBS-A–D recorded.

### Commit
`feat(engine): TASK-019 display read-models and copy-key selection` — the atomic task commit including the disposition fixes (hash recorded in status.md at housekeeping).

### Push
Pushed to `origin/feature/EPIC-004-engine` immediately after the commit (status recorded in status.md).

### Recommended Next Step
Spawn the independent review agent (§10, §33 — unprimed): diff = the files above on `feature/EPIC-004-engine`.


## Reviewer Findings
**VERDICT: APPROVED_WITH_MINOR_NOTES** (independent fresh review agent, Jupiter, 2026-09-09; full record in `.claude/tasks/reviews/REVIEW-TASK-019.md`).

Independently re-derived from the docs before reading the implementation: greeting precedence (missedYou outranking nightGlance is CORRECT — FR-12 AC-2 is unconditional; a night-only usage pattern would otherwise never see missedYou), all edges (06:30 → nightGlance, 14:00 → freshMorning, midnight crossing → nightGlance, backward gap → nil), the PRE-stamp read (proven structurally — `Greeting.select` is `evaluate`'s first statement on the input state — and behaviorally), the `lastGreeting` stamp's necessity (§4.11's state-alone `makeCharacterDisplayState` forces it; `instant` is the honest fading carrier), the fourth vocab keyspace (§4.9's "exactly three" must govern the variational classes or the doc self-contradicts), D11-exact night via FoldRules with NO `q6WindowEndHour` aliasing (distinct constants, distinct authorities), the one-draw recipe + §4.10 seed lineage, the exhaustive license (a)–(e) audit (28-path inventory: 19 M + 9 ??; frozen shapes, quest surface, `MomoCopy.xcstrings`, `DomainInvariantsTests` all untouched), and the anti-echo discipline — four sanctioned mutation bites (36 h→37, floor 5→6, 12→13, epoch 1→2) each failing the exact raw pin with attribution, all restored, HEAD unchanged at `8201b6d`, suite re-verified green after restore.

Reproduced: `swift build --build-tests` green; `swift test` → **361 tests / 42 suites, 0 failures** (twice: pre-probe and post-restore). All nine judgment calls adjudicated SOUND. All pinned supersessions verified mechanical + attributed.

**Findings (none blocking):**
- **MINOR-1** — AC-2's verbatim pins (energy ×4, descriptors ×4) are not machine-enforced: the phrases exist only in `LineSelection.swift` doc comments; an EPIC-007 mis-transcription would fail no pin today. Recommended fix: a `catalogObligationsAreRecorded` test in `VocabularyKeyTests` pinning the 8 strings as the EPIC-007 catalog-entry contract (test fixtures are not engine output — `ThresholdsPinnedToPRDTests` precedent). Apply in-disposition or record in the EPIC-007 epic file.
- **MINOR-2** — `ReactionKeys.swift` header still claims the task "leaves both nil" (now false for lineKey). The implementer was right to leave it (outside the license letter); recommend an orchestrator-authorized one-line doc touch-up riding the disposition commit (TASK-017 precedent).
- **NITPICK-1** — no daytime ≥ 36 h pin (missedYou-vs-freshMorning untested directly; missedYou-vs-nightGlance is). Optional one-assertion fix in `GreetingSelectionTests`.
- **OBS-A** — seed lockstep: one copy seed shared by all families+slots means equal pools will yield the same index across contexts on a day once pools > 1 (contract-conformant; catalog-era consideration for EPIC-006).
- **OBS-B** — declined and warm cells share the family key (e.g. `politelyFull` == `eating` → `feed.00`); spec-conformant per 04 §10.4; catalog era decides whether declined cells need own entries (epoch-bump event).
- **OBS-C/OBS-D** — pre-existing doc inconsistencies to reconcile when catalogs land: 04 §10.3 sample headers (Day …16:59 / Evening 17:00–21:59) vs the 12/18 cut-offs; 05 §4.9 / 04 §8.4 ratification of the `momo.line.vocab` namespace.

Review status: **APPROVED_WITH_MINOR_NOTES** — eligible for disposition; orchestrator rules on MINOR-1/MINOR-2 (apply now vs follow-up). No source/test edits were made by the reviewer beyond the four restored mutation probes.

**Orchestrator disposition (2026-09-09):** MINOR-1 — APPLY (reviewer's preferred option i): `catalogObligationsAreRecorded` added to `VocabularyKeyTests` — the 8 verbatim strings (04 §3.5 energy ×4, PRD §3.3 descriptors ×4) as test-file constants one-to-one with the minted keys, the EPIC-007 catalog-entry contract. MINOR-2 — APPLY: one-line `ReactionKeys.swift` seam-header touch-up ("lineKey filled as of TASK-019; haptics remain the presentation seam") riding this disposition commit (TASK-017 precedent; doc-only, outside the supersession license by explicit orchestrator authorization). NITPICK-1 — APPLY: `missedYouOutranksFreshMorning` added to `GreetingSelectionTests` (36 h exact → 14:00 daytime on a new dayKey → `.missedYou`). OBS-A–D — recorded in `status.md`; OBS-A/OBS-B migrate into the EPIC-006 epic file, OBS-C/OBS-D into the standing doc-chain follow-ups. All three fixes are test/doc-only — zero production behavior change; the reviewer's approval stands unamended. Post-disposition suite: `swift test` → **363 tests / 42 suites, 0 failures** (+2 disposition pins).

## Completion Evidence
- **Requirements:** all 9 contract requirements implemented; Required Tests 1–8 present; supersession license (a)–(e) exercised exactly as named (reviewer-audited, §T8 of the review).
- **Tests:** `swift build --build-tests` green; `swift test` → `Test run with 363 tests in 42 suites passed after 0.422 seconds.` (handoff 361/42 + 2 disposition pins; baseline 314/36 ⇒ +49 tests, +6 suites). In-suite purity/import-whitelist/banned-vocabulary scanners green, no new exemptions; `MomoCopy.xcstrings` untouched (3 placeholder keys stand); `ResponsePlan.haptic` nil at every plan site.
- **Review:** `.claude/tasks/reviews/REVIEW-TASK-019.md` — APPROVED_WITH_MINOR_NOTES, 0 MAJOR, 10 adversarial targets all survived, 4 sanctioned mutation bites with exact attribution; disposition applied as above.
- **Commit:** `feat(engine): TASK-019 display read-models and copy-key selection` — this task's atomic commit (hash recorded in status.md and in the housekeeping update).
