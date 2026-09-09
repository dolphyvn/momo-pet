# REVIEW-TASK-019 — Display read-models + copy-key selection

**Reviewer:** independent fresh review agent (CLAUDE.md §10/§33), Jupiter
**Date:** 2026-09-09
**Branch:** `feature/EPIC-004-engine` @ `8201b6d` (untouched through the review — re-verified after all probes)
**Task file:** `.claude/tasks/active/TASK-019-display-read-models.md` (Status IN_REVIEW)
**Verdict: APPROVED_WITH_MINOR_NOTES**

---

## 0. Independence statement

This review was conducted adversarially per §33: normative claims were re-derived from the documents
BEFORE comparing against the implementation or its notes. The implementer's notes (Requirements,
judgment calls, supersession ledger) were treated as claims, not evidence. Every doc-sourced number
below (36 h, 22:00–07:00, 04 §3.5 wording, PRD §3.3 descriptors, §4.9/§4.10/§4.11 semantics) was
re-read from `docs/` in this session, not taken from the task file. The two constants divergences
sanctioned by the review brief (below) were the only writes to tracked sources; both were restored
and the full suite re-verified green afterward.

## 1. State reconciliation

- `git rev-parse HEAD` = `8201b6de7c1f6290b6e2c414329dcc77f5c91f19` before AND after the review probes. Untouched.
- Working inventory: **28 paths = 19 M + 9 ??** (enumerated in §4/license audit). The 9 untracked are
  exactly the 3 new Sources + 6 new test suites. The 18 code modifications are exactly the license-(a)–(e)
  set + the task file itself. Nothing outside the contract's Files-Affected + license appears.
- **Absent from the diff (verified by absence):** `Apps/Shared/MomoCopy.xcstrings` (the 3-placeholder-key
  seed stands), `Sources/MomoCore/CharacterInterface.swift` (frozen shapes untouched),
  `Sources/MomoCore/QuestGeneration.swift` + `QuestCatalog` (TASK-018 reviewed surface untouched),
  `DomainInvariantsTests` (deliberately untouched per the ledger — its INV-11 type-shape construction is
  not an engine-minted plan; correct).
- Baseline claim reproduced twice: `swift build --build-tests` green;
  `swift test` → **"Test run with 361 tests in 42 suites passed"** (before probes and again after
  restore; baseline 314/36 ⇒ +47 tests, +6 suites — matches the implementer's claim exactly).

## 2. Independent derivations — the ten adversarial targets

### T1. Greeting precedence + edges — SOUND
Re-derived rule order from the docs myself: FR-12 AC-2 (PRD, normative, unconditional: "first open
after ≥ 36 h shows the warm missed-you greeting") vs UX §4 flow 8's night-open rule (subordinate
design doc). **missedYou outranking nightGlance is correct**: a night-shift usage pattern (opens only
22:00–07:00) would otherwise NEVER see missedYou for any absence, voiding the PRD guarantee. The
selector's order (floor → missedYou → nightGlance → freshMorning → welcomeBack) matches the contract's
Req 5 order exactly. Edges:
- **≥ 36 h inside the night window** → missedYou (absence outranks hour) — pinned by the discriminating
  pair `missedYouEvenAtNight`: 36 h exact → `.missedYou`; 36 h − 60 s at the same open (hour 1) →
  `.nightGlance`. Half-open bound (≥, not >) correct per AC-2's "≥ 36 h".
- **06:30 first open** → hour 6 < 7 → `.nightGlance` before the dayKey comparison — matches UX §4's
  night-open rule; a "morning" greeting at 06:30 would contradict D11.
- **14:00 first open** → dayKey changed, hour 14 outside window → `.freshMorning` — pinned explicitly.
- **Midnight crossing** (23:50 → 00:10) → nightGlance, not freshMorning (hour governs before dayKey) —
  pinned; correct (00:10 is not a "morning").
- **Floor gate** — 5-min floor is engine-owned (contract names it "recorded judgment call"); half-open
  (below → nil, at → greets) pinned both sides; backward gap (now < previousOpen) → negative gap < floor
  → nil — "no greeting invented for time that did not pass" is sound and pinned.
- **PRE-stamp read PROVEN**, structurally and behaviorally. Structural: in `Reduce.swift` `evaluate()`,
  `Greeting.select(previousOpen: state.lastOpenedAt, …)` is the FIRST statement, reading the INPUT
  state; the stamp `next.with(lastGreeting: …)` and `lastOpenedAt = now` happen later on `next`.
  Behavioral: `evaluateEmitsGreetingFirstAndStamps` sets `lastEvaluatedAt = now − 300 s` (a 5-min fold)
  with `lastOpenedAt` 23 h + one dayKey earlier — a `.freshMorning` fires, which a post-stamp read
  (gap 0 < floor → nil) could not produce. `zeroGapEvaluateStaysSilent` proves a silent re-evaluation
  neither clears nor re-stamps.

### T2. `lastGreeting` stamp necessity + minimality — NECESSARY, MINIMAL
Tried to disprove: §4.11 pins `makeCharacterDisplayState(_ state: EngineState)` as a derivation over
the STATE ALONE (no `now`, no event stream). `CharacterDisplayState.momentRequest` must therefore be a
function of state. Quest/stage moments are event-transient (delivered via `EngineOutcome.moments` and
gone); the greeting is the only L4 request that must outlive its event ("the greeting in effect for
the current open"). No alternative state carries it: `lastOpenedAt` cannot distinguish kinds or
suppress onboarding-era non-greetings. Hence a state field is forced. Minimality: `GreetingStamp` is
(kind + at), both `let`, Equatable+Sendable — `kind` is what both read-models project; `at` is the
honest carrier for presentation-owned fading/transience (the contract mandates "kind + instant" and
the presentation owns the timer — a kind-only stamp would force the presentation to invent a start
time). Nil initial value = onboarding's own flow is the greeting (S1–S3) — correct reading.
Claim NOT disproved.

### T3. The `momo.line.vocab.<field>.<band>` fourth keyspace — SOUND
§4.9's "exactly three catalog namespaces" (slots/react/moment) cannot govern the fixed state
vocabulary, because §4.11's OWN DisplayState sketch requires resolved keys for moodWord/energyPhrase/
bondDescriptor — fields outside all three variational classes. Read "exactly three" as governing the
VARIATIONAL classes or the architecture doc self-contradicts. The fourth namespace under the §8.4 dot
convention is the coherent resolution; it is a fixed LOOKUP (zero variation — not a §4.9 "selection"),
so §4.9's seed/epoch machinery rightly does not apply to it. Pin MAPPINGS verified against the docs:
- Wistful → key `momo.line.vocab.mood.wistful`, band-named, with the 04 §3.5 "quiet" remap pinned BY
  NAME as a catalog obligation (`wistfulKeyStaysBandNamed` asserts the key does NOT contain "quiet" —
  the remap must live in the entry, not the key, or the band→key lookup stops being total/mechanical).
  Correct: encoding the display word in the key would fork the lookup table from the band enum.
- Energy ×4 / descriptors ×4: the KEYS are pinned band-for-band (`momo.line.vocab.energy.*`,
  `momo.line.vocab.stage.*`); the VERBATIM phrases are NOT machine-pinned anywhere — see MINOR-1.
- Keyspace shape pinned: 12 distinct keys, all under `momo.line.vocab.`, no spaces (INV-11).
- Doc ratification (05 §4.9 / 04 §8.4 acknowledging the fourth namespace) is a follow-up (OBS-4).

### T4. Day-stable selection — SOUND, mutation-proven
Seed lineage verified: `LineSelection.copySeed = DaySeed.make(petID:localDayKey:epoch: CopyRules.copyEpoch, salt: .copy)`
— §4.10's copy-domain derivation, pet + LOCAL day key + epoch + the `.copy` salt (salt-separation from
choreography/quest domains pinned by inequality in `epochAndSaltParticipate`). Pinned draw recipe:
`oneDrawRecipePin` replays ONE `rng.next() % poolCount` draw independently over pools [1,2,3,5,8] —
an extra/reordered draw or different reduction fails (TASK-018 twoDrawPin pattern). Day-stability:
twin determinism per family/slot; within-day sweep across all 24 hours (the wall clock never enters the
seed); cross-day variation sweep 30 days × pools 1–5 (pool 1 constant by arithmetic; pools ≥ 2 must
vary). Generators are call-local — the choreography rng lineage is untouched (`rngDrawDiscipline`
unchanged and green; `Reduce`'s two-draw comment still accurate; greeting selection consumes no rng).

### T5. Slot windows — D11-EXACT, NO CROSS-DOMAIN ALIASING
Night = hours ≥ 22 OR < 7 via `FoldRules.nightOnsetHour`/`morningWakeHour` — the SAME normative window
as the wakefulness fold, ONE encoding (referenced, never restated — dedup, not coupling; both constants
carry D11 labels). Subdivision 12/18 lives in `CopyRules` as engine-owned labeled constants per the
contract's explicit delegation. **Aliasing check (the specific adversarial ask):**
`Thresholds.Quest.q6WindowEndHour == 7` is a DISTINCT constant used only in `Quest.swift`'s quest
window logic; the slot's morning start is `FoldRules.morningWakeHour`. Two authorities, two constants,
no symbol shared — a q6 retune cannot move the slot table and vice versa. Boundary rule "cut-off hour
opens the NEXT slot" pinned eight ways (AC-4's exact rows) plus an exhaustive raw 0–23 table
(`rawSlotTable`) that fails with the exact hour attributed (bite-verified, §3). `timeSlot` provably
never returns the context slots (`greeting`/`care-moment`) — pinned over all 24 hours; context-slot
keyspace exposure only, correct per the recorded reading.

### T6. `lineKey` seam — FILLED AT ALL 21 SITES; HAPTICS NIL; one stale doc
`InteractionSemantics.plan(_:for:in:)` mints `LineSelection.reactLineKey(petID: state.pet.id, dayKey:
intent.localDayKey, family: CopyRules.ReactFamily(intent.kind))`. All 21 call sites verified threaded
(touch 1 + feed 3 + play 6 + tuck-in 6 + nap 5). Family mapping pinned: pat→touch (tap AND stroke,
incl. asleep-stir and waking soft-stir), feed→feed (warm meals AND polite refusal AND declines),
play→play (cheer AND declines), tuckIn/nap→care (settling, decline, blanketAdjust, asleep). Declined/
asleep paths carry keys — every plan is announced, per AC-5. `haptic` nil at every plan site and every
test assertion (the presentation seam stands). The task-file count of test-pin updates reconciles with
the diffs: InteractionResponseTests (matrix + per-line + `planShapeAndSeams` scenario rewrite, keys
restated as raw literals WITHOUT calling the production helper — no circular expectations),
CareInteractionTests ×9, PlayRoundTests ×2, WakefulnessHandshakeTests:260, TimeFoldTests:490,
BondLedgerTests:406, EngineReduceTests `evaluateStampsBoth` + `interactionPassThrough` per-index table.
One stale doc remains: `ReactionKeys.swift`'s header still says the task "leaves both nil" — see MINOR-2.

### T7. The ≤ 3-moment property re-pin — license (a) HONORED
`BondLedgerPropertyTests`: `check` now receives the step kind; the moment loop is an EXHAUSTIVE switch
(the `default: Issue.record` was removed — greeting/questCompleted/bondStageReached are all of
`CharacterMoment`, so exhaustiveness is compiler-enforced). New discipline: `.greeting` requires
`kind == .evaluate`, ≤ 1, FIRST (asserts `questCount == 0 && !stageSeen`); ≤ 2 questCompleted before
stage; ≤ 1 stage LAST with the guard-advances-with-emission check preserved; overall ≤ 3 preserved.
The suite header documents that its 10–20-minute steps exceed the 5-minute floor, so evaluate steps
WILL greet — exactly the contract's Req 6 demand. `interactionsNeverGreet` / `reportsNeverGreet` pin
the evaluate-only claim at the path level; `zeroGapEvaluateStaysSilent` pins stamp persistence.

### T8. Inventory / license audit — CLEAN
Every changed file accounted (§1). License check, item by item:
(a) `BondLedgerPropertyTests` re-pin — exactly as named, nothing more.
(b) `Reduce.swift` DaySeed header re-scoped to quest + copy domains — verified; the purity argument
carries over (copy derivation is pure, injected-value-only).
(c) `EngineState` +`GreetingStamp`/`lastGreeting` as LAST field, NO init default; threading verified at
ALL 8 EngineState construction sites (fixture 1, EngineReduceTests ×3, QuestGenerationTests,
QuestTickTests, TimeFoldTests, WakefulnessHandshakeTests) + six `with(...)` helpers + new
`with(lastGreeting:)` in `HandshakeMachine.swift`.
(d) `ResponsePlan.lineKey` nil → filled at the plan-minting helper + 21 sites.
(e) Mechanical test updates: every hunk in the 12 modified test files is either `lastGreeting: nil`
threading, a family-key literal, or the two documented supersessions (`evaluateStampsBoth`,
`planShapeAndSeams`) — each annotated "TASK-019 supersession (in place, per the contract)". No
unrelated logic changed; `rngDrawDiscipline` untouched.
Frozen shapes (`CharacterDisplayState`/`ResponsePlan`/`CharacterMoment`/`GreetingKind`), quest surface,
xcstrings — all untouched (§1). Nothing beyond (a)–(e) except the task file's own bookkeeping.

### T9. Constants anti-echo — BITTEN MYSELF (four divergences, all with attribution, all restored)
See §3. Raw-literal audit: 5/36 only in `Thresholds.Greeting`; 12/18 only in `CopyRules`; 22/7 only in
`FoldRules`; epoch 1 only in `CopyRules`; no stray copy-domain literals elsewhere in Sources. Key
TEMPLATES in `VocabularyKeys`/`LineSelection` are namespace structure per Req 7's explicit sanction.
Pin-test files carry the raw literals (the sanctioned exception).

### T10. Suite reproduction — CLAIM HOLDS
`swift build --build-tests` green; `swift test` → 361 tests / 42 suites / 0 failures, reproduced twice
(pre-probe and post-restore). Only warning is the pre-existing environmental `ld: warning: search path
'/opt/extra/lib' not found`.

## 3. Mutation/probe table (all performed by this reviewer; all restored; final `swift test` green; HEAD unchanged)

| # | Divergence | Failing pins (exact attribution) | Behavior suites | Restored |
|---|---|---|---|---|
| A | `missedYouAfterHours` 36 → 37 | `CopySelectionPinnedTests.swift:123` `(→ 37) == 36`; `ThresholdsPinnedToPRDTests.swift:169` `(→ 37) == 36` | green (constant-relative by design) | 36 ✓ |
| B | `regreetFloorMinutes` 5 → 6 | `CopySelectionPinnedTests.swift:122` `(→ 6) == 5`; `ThresholdsPinnedToPRDTests.swift:174` `(→ 6) == 5` | green (same design) | 5 ✓ |
| C | `daySlotStartHour` 12 → 13 | `CopySelectionPinnedTests.swift:46` `(→ 13) == 12`; `CopySelectionPinnedTests.swift:63` `(→ .morning) == (.day)` **at the exact hour** | green (table rows are constant-relative) | 12 ✓ |
| D | `copyEpoch` 1 → 2 | `CopySelectionPinnedTests.swift:29` `(→ 2) == 1` (the epoch-bump obligation's tooth; keys stay `.00` while pools are 1 — correct) | green (seed equality is constant-relative) | 1 ✓ |

The division of labor holds exactly as designed: behavior suites prove the RULES over named constants
(a retune moves the table with the constant); raw pins carry the TEETH with attribution. Required
Test 7 satisfied and independently demonstrated.

## 4. Acceptance-criteria sweep

- **AC-1** §4.11 fidelity + goldens — **SATISFIED.** `DisplayState` field-for-field vs the §4.11 sketch
  (independently re-read); `makeDisplayState` golden vector; absent-record → empty-set cascade →
  `.allDone`; night-hour cascade (+ fully-complete set at the same hour → `.allDone`); greeting-stamp
  projection both nil and stamped; **DST-adjacent injected-calendar proof** (07:30Z = 03:30 EDT → Q6's
  tail under America/New_York vs Q1 under UTC on the same instant — the calendar is provably the
  injected one and the day record is matched by the LOCAL dayKey); character golden + corner matrix
  (bands × stage × wakefulness corners with raw-value expectations).
- **AC-2** OBS-1 vocabulary pins — **SATISFIED for keys, PARTIAL for verbatim prose** (MINOR-1): keys
  exact ×12 + Wistful-by-name; the four energy phrases and four descriptors are recorded only in
  `LineSelection.swift` doc comments, not pinned machine-checkably anywhere.
- **AC-3** day-stability — **SATISFIED** (T4: twins, 24-hour sweep, 30-day × pools 1–5 sweep, one-draw
  recipe pin, epoch participation pinned by DaySeed inequality).
- **AC-4** slot table — **SATISFIED** (eight boundary rows + 24-hour totality + context-slot exclusion +
  raw 0–23 table; night D11-exact via FoldRules; no q6 aliasing, T5).
- **AC-5** seam — **SATISFIED** (T6: all four families, declined/asleep included, haptics nil, 21 sites,
  token/twin determinism pins green unchanged, `rngDrawDiscipline` untouched).
- **AC-6** greeting — **SATISFIED** (T1: full rule table incl. the 36 h discriminating pair, midnight
  crossing, 14:00 first open, floor edges, backward gap; PRE-stamp read proven structurally +
  behaviorally; stamp projects into both read-models; property re-pin green).
- **AC-7** INV-11 + scans — **SATISFIED.** New code outputs keys/enums only (DisplayState field
  inventory verified); the in-suite purity/import/banned-vocabulary scanners ran green inside the 361;
  no new exemptions.
- **AC-8** build + test — **SATISFIED**, reproduced independently twice.

Required Tests 1–8 all present and map to the suites as the contract intends (1 DisplayStateTests,
2 VocabularyKeyTests, 3 CopySlotTests+raw table, 4 LineSelectionTests+recipe pin, 5
LineSelectionTests-plan integration+epoch, 6 GreetingSelectionTests+property re-pin, 7 pinned suite +
bite-proven, 8 in-suite scanners).

## 5. Judgment-call adjudication (implementer's nine)

1. Wistful key band-named — **SOUND** (T3; total mechanical lookup preserved; remap pinned by name).
2. Fourth keyspace — **SOUND** (T3; coherent resolution of §4.9's internal tension).
3. Night = D11 via FoldRules; 12/18 engine-owned; cut-off-opens-next — **SOUND** (T5).
4. One-draw recipe — **SOUND** (T4; recipe pinned, rng lineage untouched).
5. Stamp persists until next greeting — **SOUND** (T2; the only reading consistent with §4.11's
   state-alone derivation; persistence pinned).
6. Rule order incl. missedYou-over-hour and hour-over-day — **SOUND** (T1).
7. INV-10 replay stays response-nil; day-stability proven via two DISTINCT fresh intents — **SOUND**:
   a duplicate replay mints nothing (INV-10), so it cannot carry a plan key; the day-stability claim is
   properly about distinct same-family intents (`duplicateIntentReplayCarriesSamePlanKey` is the right test).
8. No init default for `lastGreeting` — **SOUND** (license (c)'s letter; house explicit-memberwise style;
   threading proven at all 8 sites).
9. `pick` traps on pool 0 — **ACCEPTABLE** (pool counts come from the constants home; a documented trap
   beats a fabricated index; unreachable in the placeholder era).

## 6. Findings ledger

No MAJOR findings. No CRITICAL/MAJOR regressions, no scope creep, no purity violations.

### MINOR-1 — AC-2's verbatim pins (energy ×4, descriptors ×4) are not machine-enforced
**Evidence:** repo-wide grep — "has plenty of energy" / "is relaxed" / "is getting sleepy" / "is very
sleepy" and the four PRD §3.3 descriptors exist ONLY in `Sources/MomoCore/LineSelection.swift` doc
comments (lines ~108–121). An EPIC-007 mis-transcription of any phrase would fail no pin today. The
keys themselves are exact and pinned; the gap is the catalog-ENTRY obligation.
**Adjudication:** the contract is internally tensioned (Req 3 says "the four phrases verbatim, mapped
from EnergyBand"; the OBS-1 resolution + Req 3's own "MomoCore mints the key strings only" forbids
carrying the prose in MomoCore). The implementation's resolution (keys + doc-comment record + EPIC-007
entry obligation) is the defensible one — test fixtures are not engine OUTPUT, so pins may carry the
literals (the `ThresholdsPinnedToPRDTests` precedent pins PRD text in tests).
**Fix text (recommended, small):** add to `VocabularyKeyTests` one test, e.g.
`catalogObligationsAreRecorded`: pin the four energy phrases and four descriptors as test-file
constants, keyed one-to-one to `VocabularyKeys.energyPhraseKey(for:)`/`bondDescriptorKey(for:)`, with a
doc comment declaring them the EPIC-007 catalog-entry contract ("the entry for this key MUST read
verbatim; a catalog change to these words is a PRD/04 §3.5 spec change"). This converts AC-2's letter
into a machine check without touching MomoCore output.
**Disposition options:** (i) apply the fix in this task's disposition; or (ii) accept as-is and record
the obligation in the EPIC-007 epic file. Either is acceptable; (i) is preferred (cheap, closes AC-2's
letter now).

### MINOR-2 — stale `ReactionKeys.swift` header
**Evidence:** the header still reads "lineKey/haptic seams (documented, this task leaves both nil).
Copy selection is TASK-019's" — false as of this task (lineKey filled; only haptic remains nil).
**Adjudication:** the implementer was RIGHT not to touch it (outside license (a)–(e)'s letter —
"Everything else stands"). The staleness is real and will mislead the next reader.
**Fix text:** orchestrator-authorized one-line doc touch-up riding the disposition commit, e.g.
"…seams (lineKey filled by TASK-019; haptic stays the presentation seam)". Precedent: TASK-017's
reviewer-authorized prose touch-up. Alternatively a follow-up task; riding the disposition commit is
cheaper and keeps the docs truthful at the commit boundary.

### NITPICK-1 — no daytime ≥ 36 h pin
The missedYou-vs-nightGlance ordering is pinned by the discriminating pair; missedYou-vs-freshMorning
is not (a ≥ 36 h gap at 14:00 is untested directly). The code path is trivially correct (rule order)
and the raw 36 h pin backs it, so this is a coverage nicety, not a defect.
**Fix text:** one assertion in `GreetingSelectionTests`: 36 h+ gap landing at 14:00 → `.missedYou`.

### OBSERVATIONS (no action required for this task; record for the catalog era)
- **OBS-A — cross-context seed lockstep:** one `copySeed(petID, dayKey)` is shared by ALL families AND
  slots, with the one-draw-% recipe: once pools exceed 1, equal pool counts yield the SAME index across
  contexts on a day (touch.03 / feed.03 / morning.03). Contract-conformant today (the contract's own
  seed formula omits context; AC-3 requires only day-stability + cross-day variation), but a latent
  catalog-era property: if varied-feeling lines are wanted, per-context seeds (or a context segment in
  the seed) will be needed — an epoch-bump-class change. Recommend a sentence in `CopyRules` or the
  EPIC-006 epic file when pools land.
- **OBS-B — declined/warm share the family key:** `politelyFull` (feed refusal) and `eating` both carry
  `momo.line.react.feed.00` — spec-conformant (04 §10.4's keyspace is per-family; AC-5 demands every
  plan be announced), but the catalog era must decide whether declined cells warrant their own entries
  (a pool split → epoch bump). Record in EPIC-006/007.
- **OBS-C — pre-existing doc inconsistency:** 04 §10.3's sample-line headers read Day 12:00–16:59 /
  Evening 17:00–21:59, vs the contract's engine-owned 12:00/18:00 cut-offs this task implements. Not
  introduced by TASK-019; reconcile when catalogs land (OBS-4 rides the same pass).
- **OBS-D — doc ratification of the fourth keyspace:** amend 05 §4.9 / 04 §8.4 to acknowledge
  `momo.line.vocab` when the docs are next touched.

## 7. Verdict

**APPROVED_WITH_MINOR_NOTES.** The implementation satisfies all nine requirements and AC-1, AC-3–AC-8
outright; AC-2 is satisfied in substance with one machine-check gap (MINOR-1). Every adversarial target
was disprovable in principle and none was disproved in fact; the two constants the brief permitted me to
diverge bit exactly as the pins promise, with attribution, and were restored. The findings are all
doc/test-adjacent: MINOR-1 (recommended in-disposition), MINOR-2 (recommended one-line doc touch-up
riding the disposition commit), NITPICK-1 (optional one-liner). None blocks commit. Per CLAUDE.md §10
the task may proceed to disposition once the orchestrator rules on MINOR-1/MINOR-2 (apply now vs
follow-up) — review status is not CHANGES_REQUIRED either way, since both findings are outside the
implementation's licensed surface.

**Recommended disposition:** commit as specified in Git Requirements (after ruling MINOR-1/MINOR-2);
update the task's Reviewer Findings (done by this review) and Completion Evidence; record OBS-A–D in
status.md / the EPIC-006/007 epic files.
