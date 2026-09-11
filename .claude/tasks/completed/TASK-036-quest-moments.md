# TASK-036 — Quest moments + celebrations (FR-16; UX §5.5–5.6; 04 §4.3 L4)

## Parent Epic

EPIC-007 — iPhone Home Experience (`.claude/tasks/epics/EPIC-007-iphone-home.md`), task 6 of 9. Depends on TASK-033 (Home composition + catalog) and TASK-018 (the §4.8 cascade/moments engine work). TASK-034/035 precede it on the branch.

## Objective

Close the LAST silent gap in the §4.1 fixed order: the engine already mints quest/bond moments into `EngineOutcome.moments`, and the app model already carries the `.deliverMoments` arm — but the arm forwards to a NIL closure, so **quest completions and stage crossings never reach presentation today**. Wire them through: the L4 moment visuals (sparkle, celebration) play on the canvas via the frozen director machinery, the M1 inline completion flourishes on the quest card, the M2 one-time stage banner shows over Home with its VoiceOver announcement, and the M3 all-done warm line grows onto the quest card. Haptics land at the presentation seam, gated by the existing `hapticsEnabled` setting (the toggle UI itself is TASK-038's).

## Context (verified pins — read these before coding)

- **The delivery gap:** `Sources/MomoCore/EngineEvent.swift:46` — `EngineOutcome.moments: [CharacterMoment]` (greeting by the `.evaluate` selector, `questCompleted` by §4.8 window-checked ticks, `bondStageReached` by `BondLedger.reconcileStage`). `Apps/Momo/MomoAppModel.swift:233-235` declares `deliverResponse`/`deliverMoments` closures ("the shell hosts these closures"); the `.deliverMoments` arm at `:565-566` is exactly `deliverMoments?(moments)` — a NIL seam. The `.deliverResponse` arm (`:548-564`) is the precedent: the REAL delivery is inline in the arm (foldDirector `.plan` + announcements + careMoment memory); the closure stays an unfilled shell seam. Follow that precedent — implement moments delivery INLINE in the `.deliverMoments` arm; do NOT remove the closures.
- **The two doors (architectural statement this task lands):** moments reach the director through exactly two doors. **State-born moments (greetings)** ride the `.displayState` `momentRequest` stamp — `makeCharacterDisplayState` is state-alone and TASK-019 pinned `momentRequest` to carry the greeting kind ONLY ("the greeting is the only moment that must outlive its event"). **Event-born moments (quest/bond)** are transient in `EngineOutcome` — they need a NEW director door. Candidate routes adjudicated: (a) a new `MomoCharacterEvent` case — CHOSEN (R6 precedent: TASK-035's disclosed minimal `case playStopped(at:)`); (b) stamping quest/bond into `CharacterDisplayState.momentRequest` — REJECTED (breaks the TASK-019 state-alone pin; a state-stamp that outlives its event re-fires on unrelated folds); (c) a second presentation-side moment player outside the director — REJECTED (04 §4's L4 is director-owned; two players would fight over the canvas).
- **Ordering pin (verified):** `MomoAppModel.apply(trigger:)` — step 0 applies `newState` and folds `.displayState` (`:529-532`, equality-gated) BEFORE the effects loop runs the `.deliverMoments` arm. So a same-outcome greeting starts via its door first; event-born moments enqueue behind it. Preserve this; the R-guard pins it.
- **The greeting exclusion:** an `.evaluate` outcome can carry `[greeting?, questCompleted…, bondStageReached?]` (greeting first, ≤1). The displayState door already plays the greeting; the new event door MUST forward event-born moments only (filter `.greeting` out) or the greeting plays twice.
- **Director L4 machinery is LIVE and FROZEN in behavior** (`Sources/MomoCharacter/MomoReactionDirector.swift`): fields `moment`/`pendingMomentRequest`/`deferredMoment` (`:59-61`); `applyDisplayState` (`:497-525`) fires on momentRequest TRANSITIONS (the transition IS the dedupe) and defers to `deferredMoment` while hidden; `startMoment` (`:532-534`) REPLACES `self.moment` wholesale — there is NO queue today; the L4 completion block (`:773-781`) reports `.momentFinished` exactly once at `start + MomoMoments.duration(for:)` then clears the slot; `applyShown` (`:655-661`) restarts the deferred moment (replay from 0). Moment visuals + RM statics already render: `MomoMoments.swift` authors `questSparkle` (1.0 s) and `celebration` (1.8 s) motions, and `MomoReduceMotion.reduceMotionMomentMotion` (`MomoReduceMotion.swift:502-515`) holds the settled post-overshoot pose for `.questCompleted`/`.bondStageReached`. **You are wiring delivery, not authoring motion.**
- **`MomoCharacterEvent`** (`Sources/MomoCharacter/MomoReactionState.swift`): 8 cases today; `eventTime` is an exhaustive switch (`:41` area). Consumers census (grep `MomoCharacterEvent`): `MomoAppModel`, `MomoReactionDirector`, `MomoReduceMotion` (the RM state tracker's fold guards on `.displayState` — a new case passes through harmlessly, but ADD a fold assertion test), `Tests/MomoCharacterTests/{MomoHandshakeTests, MomoReactionDirectorTests, MomoReactionTestSupport, MomoReactionTwinTests, MomoReduceMotionTwinTests}`. Census every exhaustive switch before adding the case; fix forward.
- **Quest card today** (`Apps/Momo/HomeQuestCardView.swift`, read in full): header "Today's little wishes"; window-open rows only (`visibleRows`); each row `glyph · wishKey · mark` with `row.isCompleted` already driving ●/○; a11y label "{wish}, done/pending". `HomeQuestRow` (`Sources/MomoKit/HomeReadModel.swift:26-40`) carries `isCompleted`/`isWindowVisible`. **`HomeReadModel` does NOT yet expose the all-done truth** — the M3 line needs it (expose the cascade's `questLine == .allDone` or an equivalent derived flag; the cascade output already exists on the `DisplayState` family — mirror the existing derivation style at `:228-235`).
- **Catalog state** (`Apps/Shared/MomoCopy.xcstrings`): `momo.line.moment.00` exists as "Placeholder moment line." (TASK-033 landing). Stage display names live at `momo.line.status.stage.<stage>`; PRD §3.3 descriptor lines verbatim at `momo.line.vocab.stage.<stage>` (the OBS-D fixed keyspace, `VocabularyKeys.bondDescriptorKey`). Both are already-rendered keys you compose the M2 banner from.
- **Copy selection law** (`Sources/MomoCore/LineSelection.swift` + `CopyRules.swift`): the variational classes are slot/react pools — day-stable seeded draws over `DaySeed(petID, dayKey, epoch: CopyRules.copyEpoch, salt: .copy)`; index `00` is reserved for placeholders, real entries start at `01`.
- **Haptics:** `ResponsePlan.haptic` stays NIL at every plan site (engine-frozen presentation vocabulary — `ReactionKeys.swift:13-16`). `SettingsState.hapticsEnabled` already exists in `EngineState.settings` (default true; `MomoAppModel.swift:699` shows the fresh-install value). UX-13 reduces to haptics for Phase 1 (04 §11 — no sound exists).
- **UX-10 / once-semantics:** PRD FR-10 AC-4 + 05 §355 — a stage crossing while closed is detected at the next OPEN evaluation, which emits `.bondStageReached` exactly once via the engine's `highestCelebratedStage` guard (`BondLedger.swift:140-149` — the guard advances WITH the emission, persisted). **The presentation is therefore STATELESS w.r.t. once-ness** — no banner-shown persistence, no replay-on-relaunch. If the app dies between evaluation and render, the banner is lost; that is the engine's frozen semantics (best-effort one-time). The director's app-hide deferral covers the mid-session hide; the banner (a delivery-time surface) does not defer across backgrounding — accepted, disclose in Implementation Notes.
- **The ≤3 cap (TASK-018 re-pin):** per outcome, at most 2 `.questCompleted` + 1 `.bondStageReached` (plus ≤1 greeting, evaluate-only, first). The event door therefore receives ≤3 per fold; queue depth stays small and bounded — assert it in tests.

## Requirements

**R1 — The event door (the second disclosed MomoCharacter touch).** Add `case moments([CharacterMoment], at: Double)` to `MomoCharacterEvent` (batch, causal order preserved, one fold per outcome; `eventTime` returns `at`). This repeats TASK-035's R6 pattern: minimal, disclosed, behavior-frozen elsewhere. Update `eventTime`, the director's `apply`, and every exhaustive switch the census finds. Empty array = no-op. In `MomoAppModel.deliverMoments`-arm: filter out `.greeting` moments, fold `.moments(eventBorn, at: canvasClock.elapsed())` into the director. The R6 disclosure goes in Implementation Notes (what was touched in MomoCharacter and why nothing else changed).

**R2 — Director FIFO (calm sequential playback, no L4-preempts-L4).** Add a pending queue (`[CharacterMoment]`) for event-born moments. Enqueue on `.moments`; advance (dequeue head → `startMoment`) exactly when: the fold arrives while the moment slot is idle AND not hidden; the L4 completion block clears the slot; or `applyShown` finds the slot idle after its deferred-restart branch (a deferred greeting replays first, the queue follows when it completes). While hidden, moments accumulate; nothing drops. Each queued moment reports `.momentFinished` exactly once through the existing completion path. Bounded: tests pin queue behavior at the ≤3 engine cap. Do NOT touch `MomoMoments` durations/motions, the greeting door's dedupe, or any report ordering.

**R3 — M1: inline quest completion (FR-16 AC-1; UX §5.5).** Completion stays automatic, silent, modal-free (already true — the sparkle moment + row fill are the whole M1 surface; PRD §5.4 "MAY be a subtle inline card state change + small in-scene moment + optional light haptic"). Add: (a) the app model derives which quest(s) flipped completed in the applied transition (diff `questRecords`-derived completion pre/post — pure, headless-testable) into a latest-wins presentation memory in the `latestCareMoment` precedent (never persisted); (b) the quest card plays a TINY flourish on the flipped row (mark fill emphasis — authored, calm, ≤ ~0.6 s, no spring firework) driven by that memory; (c) the light haptic fires at the `.deliverMoments` arm per `.questCompleted` (R7); (d) the quest card's done-state announcement posts under VoiceOver when a row flips (UX §5.5's "spoken through the quest card's done-state announcement" — reuse the app-model announcement pattern from `announceSpokenLine`/UX-8).

**R4 — M2: the one-time stage banner (FR-10 AC-4; UX §5.6; UX-10).** On a `.bondStageReached` delivery: (a) the app model sets a transient `activeCelebrationStage` (replacing any current — engine once-guard makes collision near-impossible) and starts an auto-fade task (AUTHORED 4.0 s, inside UX's "~4 s" band — same authored-digit pattern as TASK-035's 5.0 s Done pill); (b) HomeView renders a calm in-scene banner over the canvas region: the composed line "{name} and you are now {Stage}. {descriptor line}." — name from the read model, stage word via `HomeCopyKeys.stageNameKey`, descriptor via `VocabularyKeys.bondDescriptorKey`/`momo.line.vocab.stage.<stage>`, connective from the new `momo.line.moment.01` template (R6); (c) tap dismisses immediately (`dismissCelebration()`), auto-fade dismisses with a gentle fade (crossfade under RM — D16; no slide/spring); (d) VoiceOver: post an accessibility announcement carrying the FULL line when the banner appears (UX §5.6); the banner visual itself may be a11y-hidden (the announcement + the persistent status row carry the words — disclose the choice); (e) the celebration haptic (R7); (f) the FR-10 AC-4 "stage label updates everywhere" half is ALREADY state-driven (status row renders `stageNameKey` from state) — verify, don't rebuild.

**R5 — M3: the all-done warm line (UX §5.6; PRD §5.4 "slightly warmer end-of-day moment").** Expose the all-done truth on `HomeReadModel` (from the §4.8 cascade's `.allDone` — NOT from "all visible rows completed", which lies when a window expires mid-incompletion). The quest card grows one warm line when all-done: `momo.line.moment.02` ("Momo had a lovely day." class — R6), gentle entrance, no fanfare, nothing gated or demanded. The "soft sparkle" is NOT new machinery: it is the final wish's own `.questCompleted` L4 moment arriving through R1/R2.

**R6 — Copy landing: `momo.line.moment` as a FIXED lookup (the namespace adjudication).** 05 §4.9 lists `momo.line.moment.<nn>` among the three variational namespaces, but a seeded draw serves neither entry: the M2 banner is once-ever per stage (no repeats to vary — the draw machinery's entire purpose) and structurally carries PRD-normative pieces (OBS-2's exemption), and Phase-1 restraint needs exactly one M3 line. **Adjudication (record verbatim in Implementation Notes): `momo.line.moment` lands as a FIXED lookup, zero variation, under the OBS-D precedent (05 §4.9's OBS-D resolution) — the "exactly three" namespace census is untouched; only its selection class is fixed.** Consequences: keys land as `momo.line.moment.01` (banner template, `%@`-interpolated for name and stage word — locale-correct composition) and `momo.line.moment.02` (the all-done line, ≤12 words); the `momo.line.moment.00` placeholder is REMOVED (the 00-reserved convention working as designed); **NO CopyRules/LineSelection/MomoCore change, NO epoch bump** — new fixed keys cannot move existing seeded picks, so the epoch-4 residue pins (slots `.07`, touch `.02`, pools `.01`, CareInteractionTests day fixtures `.04`/`.01`) must stay green VERBATIM. The summary's "epoch 5 reserve seed `0x658c91a15edf4503`" is RETIRED as moot — no drawn pick lands. Extend the catalog-law test coverage to the new keys (banned-vocabulary scan, word-count where the scanner applies, key-shape law), and fix the stale `HomeCopyKeys.swift:48-51` comment (it says the nightGlance line "lands with TASK-034/035" — it didn't; the contextual fallthrough is by-design per 04 §10.1 rule 7 — reword, comment-only).

**R7 — The haptics seam (presentation-owned; the TASK-016/019 seam lands).** Moment haptics fire in the `.deliverMoments` arm: `.questCompleted` → light impact (authored), `.bondStageReached` → a single warm success-notification beat (authored; disclosed — calm, not arcade). Gated on `state.settings.hapticsEnabled` read at delivery. Fire via an INJECTED sink (a protocol or closure property defaulting to the UIKit implementation in the app target) so headless tests assert firing/gating exactly — the `deliverResponse`-closure pattern. Haptics are independent of Reduce Motion (04 §7.3: RM celebrations keep the haptic). `ResponsePlan.haptic` stays nil everywhere (engine-frozen); the TASK-038 toggle row will read the SAME `hapticsEnabled` field — no new state, no Settings UI here.

**R8 — Reduce Motion & twins stay byte-identical.** ZERO changes to `MomoReduceMotion.swift` (the L4 statics already hold the settled pose for `.questCompleted`/`.bondStageReached` at `:510-514`) and ZERO to `MomoMoments.swift`. The render-only law holds: the new event folds through the RM tracker harmlessly (add the fold assertion), banner/flourish entrance animations are view-side and crossfade under RM (D16), and the RM twin suites stay green with the fold never seeing the flag.

**R9 — Structural guards (the R9e+ extension of RigDisciplineTests).** Following the R9a-d pattern (read the REAL file through `readRigFile`, exact-string legs, non-vacuity violation fixtures, fail at the real-file assertion line): pin at minimum (e) the `.deliverMoments` arm's three legs — the greeting-exclusion filter shape, the `.moments(` director fold, and the `state.settings.hapticsEnabled` gate; (f) the director's queue-advance leg inside the L4 completion block; (g) the banner auto-fade task start + `dismissCelebration()` wiring. Each guard gets a violation fixture that contains SOME legs but not all (the F-1 lesson: the guard demands the whole wire). Bites are the REVIEWER's job (§33) — you write guards + fixtures; you do NOT self-bite as proof.

**R10 — Tests & gates (§19).** Package: director tests for the new event (FIFO order, hidden accumulation, advance-on-completion, applyShown ordering behind a deferred greeting, exactly-once reports per moment, empty-array no-op, cap bound); app-model plan tests (the fan-out: `[greeting, questCompleted, bondStageReached]` outcome → displayState greeting fold + `.moments` fold WITHOUT the greeting + banner state set + haptic sink gated by the setting; flipped-quest memory; all-done read-model derivation); HomeCopyKeys/R6 law tests; RM tracker fold assertion; R9e-g guards. UI (`MomoUITests`, pinned sim iPhone SE 3rd gen `1F25E487-A78E-464C-95AF-0BD1A9B3E1BE`): extend the suite for the quest surfaces. **Verify-before-trust:** the `-momo-store-directory` enabler takes a directory — prototype a FIXTURE STORE (pre-seeded store file copied into the injected dir) driving the E2E: q1 one-tap completion (M1 flourish + sparkle in one tap), a near-threshold bond fixture crossing to the M2 banner on one tap, an all-complete fixture rendering the M3 line. If the fixture path proves infeasible, fall back to fixed-clock driven flows and RECORD the adaptation honestly. Gates: full `swift test` green; full app UI suite green; `MomoWatch` scheme builds green (Watch SE 3 40mm, watchOS 26.5 — untouched, regression proof); zero new warnings from touched files; epoch-4 day-fixture pins verbatim.

## Files / Areas Likely Affected

- `Sources/MomoCharacter/MomoReactionState.swift` (enum + `eventTime` — the disclosed touch), `MomoReactionDirector.swift` (apply arm + queue + advance sites)
- `Apps/Momo/MomoAppModel.swift` (`.deliverMoments` arm, celebration state, flipped-quest memory, haptic sink, announcement)
- `Apps/Momo/HomeView.swift` (banner surface), `Apps/Momo/HomeQuestCardView.swift` (M1 flourish, M3 line)
- `Sources/MomoKit/HomeReadModel.swift` (all-done exposure + flipped-quest support if it lives there), `HomeCopyKeys.swift` (moment lookups + stale-comment fix)
- `Apps/Shared/MomoCopy.xcstrings` (moment.01/.02; remove placeholder .00)
- `Tests/MomoCharacterTests/*`, `Tests/MomoKitTests/*`, `Tests/MomoCoreTests/` (law tests if catalog-scoped ones live there), `Apps/MomoUITests/*` (new coverage; the F-3 `@MainActor` debt there is TASK-039's — do not fix it here, just don't worsen it)
- NOT touched: `MomoMoments.swift`, `MomoReduceMotion.swift`, `CopyRules.swift`, `LineSelection.swift`, any `MomoCore` engine file, any Watch target source

## Dependencies

TASK-031 (facade/arms), TASK-033 (composition/catalog/read-models), TASK-018 (engine moments — merged), TASK-035 (the arm's sibling precedent + drain machinery reports `.momentFinished` today). Watch propagation of the stage word is EPIC-008's (snapshot already carries it).

## Constraints

- MomoCharacter touch is confined to the enum, `eventTime`, and the director — disclose every hunk in Implementation Notes (R6/§27 discipline). Behavior of all 8 existing events byte-identical.
- No epoch bump, no MomoCore edits, no new drawn pools, no doc-file edits (the 05 §4.9 selection-class adjudication is RECORDED in this task file; the doc errata edit rides the orchestrator's backlog).
- Scope walls: no Settings UI (TASK-038), no Watch transport, no quest-window/cascade logic changes, no quest identity added to `CharacterMoment` (the frozen bare `.questCompleted` stays bare — the flip diff is presentation-side).
- Presentation stays stateless w.r.t. M2 once-ness (engine owns it — Context pin).
- The banned-vocabulary and calm-tone law applies to both new catalog strings (no "!", no guilt words; "Momo had a lovely day." is the 04 §10.1 rule-7 normative class).
- §22 scope control: unrelated discoveries → Implementation Notes follow-ups, not drive-by fixes.

## Acceptance Criteria

1. A quest completing (any of the §4.8 paths) plays the L4 sparkle on canvas through the new door, fills the row's mark with the M1 flourish, fires the gated light haptic, and announces the done state under VoiceOver — no claim, no modal, silence otherwise (FR-16 AC-1).
2. Crossing a stage threshold (fresh or deferred-from-closed) plays the celebration once, shows the composed banner for ~4 s or until tap, posts its full-line VoiceOver announcement, fires the gated celebration haptic, and never re-shows on relaunch (engine once-guard; FR-10 AC-4, UX-10).
3. Completing all wishes grows the warm line on the quest card with the final wish's sparkle; nothing gates on it (PRD §5.4).
4. Moment haptics fire only when `hapticsEnabled`; the setting is read at the presentation seam; `ResponsePlan.haptic` remains nil everywhere.
5. Expiry (Q1 at 12:00, Q6 from 20:00) and midnight reset stay silent — unchanged behavior, verified not regressed.
6. Reduce Motion: moment statics unchanged (existing RM code), banner/flourish entrance crossfades, haptic kept (D16, 04 §7.3).
7. All R10 gates green; epoch-4 copy pins verbatim; no new warnings; the disclosure record complete.

## Required Tests

Per R10 — named above; minimum one violation fixture per new R-guard; the fan-out test MUST pin the greeting exclusion (the double-play regression it prevents).

## Review Requirements

§10/§33: fresh independent Jupiter reviewer, NOT primed with implementation claims; receives the task file, the diff, and the architecture context (the two-doors statement, OBS-D adjudication, UX-10 reading) and tries to DISPROVE correctness. Reviewer bites every R9e-g guard on the real files (sha256-proven restorations, per the REVIEW-TASK-035-FIX method). Record at `.claude/tasks/reviews/REVIEW-TASK-036.md`. Known watch-items for the reviewer: greeting double-play, queue leak on hide→shown races, banner lingering across scenePhase, haptic firing on UI-test launches, placeholder-removal breaking a catalog-law assumption, epoch-pin drift.

## Git Requirements

Branch `feature/EPIC-007-iphone-home`. One atomic commit: `feat(home): TASK-036 wire quest moments + celebrations — event door, FIFO, banner, M1/M3 surfaces`. No push by the implementation agent — the orchestrator commits after review approval per the established cycle.

## Status

DONE (2026-09-11 — review APPROVED_WITH_MINOR_NOTES, dispositions applied, §19 gates re-verified by the orchestrator, committed and pushed).

## Implementation Notes

### R1/R6 disclosure — EVERY MomoCharacter hunk (only the two authorized files touched)

**Hunk 1 — `Sources/MomoCharacter/MomoReactionState.swift`:**
- Added `case moments([CharacterMoment], at: Double)` to `MomoCharacterEvent` (the batch rides in causal order, one fold per engine outcome) with its doc comment stating the two-doors architecture.
- Extended the exhaustive `private func eventTime` switch with `case .moments(_, let at): at`.

**Hunk 2 — `Sources/MomoCharacter/MomoReactionDirector.swift`:**
- New stored field `var pendingMoments: [CharacterMoment]` (line 69), initialized `[]` in the existing init (line 89). No epoch/awake-reset semantics added — the queue drains at the advance sites and accumulates while hidden (R2's nothing-drops law).
- New `applyMoments(_:at:)` (line 552): empty-batch no-op guard, FIFO append, then the first advance site.
- New `advanceMomentQueue(at:)` (line 564): guarded `!hidden, moment == nil, let next = pendingMoments.first` — starts the head.
- The THREE advance sites: (1) end of `applyMoments` (a fold arriving to an idle visible slot); (2) the L4 completion block (lines ~818-821: the existing exactly-once `.momentFinished` report at `start + MomoMoments.duration(for:)`, then `advanceMomentQueue(at:)` at that same instant); (3) `applyShown` (line 700, after the deferred-greeting re-take / replay-interrupted branch — a no-op while the slot is held).
- The apply switch gained `case .moments(let moments, let at)` → `applyMoments` (line 115). NOTHING else in the director changed: greeting-door dedupe, report ordering, `MomoMoments` durations/motions, and all 8 existing events are behavior-identical (MomoMomentQueueTests + the full twin suites green).

Exhaustive-switch census result: the ONLY repo-wide consumer outside these two files was `MomoReduceMotionTwinTests.swift`'s private `eventTime` helper — extended with the same leg (test-only; `MomoReduceMotion.swift` itself UNTOUCHED, R8).

### R6 adjudication (recorded verbatim per the contract)

> `momo.line.moment` lands as a FIXED lookup, zero variation, under the OBS-D precedent (05 §4.9's OBS-D resolution) — the "exactly three" namespace census is untouched; only its selection class is fixed.

- `momo.line.moment.01` = `%1$@ and you are now %2$@.` — the M2 banner TEMPLATE; positional `%1$@`/`%2$@` keep a localized reordering locale-correct (name, then stage word). The composer appends the descriptor sentence (`momo.line.vocab.stage.<stage>`) — the catalog entry itself stays the template.
- `momo.line.moment.02` = `Momo had a lovely day.` — the M3 all-done warm line (4 words; UX §5.5's named example; 04 §10.1 rule 7).
- `momo.line.moment.00` placeholder REMOVED (the 00-reserved convention working as designed). Catalog: 97 → 98 keys; per-class pin updated (moment class = exactly 2).
- Catalog surgery was TEXT-LEVEL on the HEAD blob (Xcode's exact `" : "` separators preserved): final diff 15 insertions / 3 deletions. NO CopyRules/LineSelection/MomoCore change, NO epoch bump; the epoch-4 residue pins (slots `.07`, touch `.02`, pools `.01`, CareInteractionTests day fixtures `.04`/`.01`) are green VERBATIM inside the full `swift test` run. The summary's "epoch 5 reserve seed 0x658c91a15edf4503" retired as moot (no drawn pick lands).
- Catalog-law tests extended: verbatim pin for both keys (`catalogCarriesTheMomentLinesVerbatim`), the non-vacuity scan count re-pinned to 71 scanned lines (40 slots + 2 moment + 3 greetings + 3 care-moments + 23 react), the placeholder exemption REMOVED from `scannedLinesAreRealCopy` (the `%1$@`/`%2$@` are formatting placeholders, not template remnants), `placeholderKeys` scaffolding tests deleted (catalog is placeholder-free — a future placeholder must re-land its `.00` pin with itself).
- Stale `HomeCopyKeys` nightGlance comment reworded (comment-only: the contextual fallthrough is by-design per 04 §10.1 rule 7; the TASK-036 moment class is the stage celebration, not a nightGlance pool).

### Authored digits (all disclosed, calm, per §5.5–§5.6)

| Surface | Digit | Where |
|---|---|---|
| M2 banner auto-fade | 4.0 s (`celebrationAutoFadeSeconds`, real-time `Task.sleep`) | MomoAppModel |
| M2 banner crossfade | 0.3 s (`HomeLayout.bannerFadeSeconds`, easeInOut, D16) | HomeView |
| M1 flourish hold | 0.6 s (`questFlipFlourishSeconds`, real-time clear task) | MomoAppModel |
| M1 mark swell | 0.3 s ease-out/in, peak ×1.35 (`flipSwellScale`, no spring) | HomeQuestCardView |
| M3 warm note entrance | 0.3 s opacity (`gentleEntranceSeconds`) | HomeQuestCardView |
| Haptics | `.questCompleted` → light impact; `.stageCelebration` → success notification (injected sink defaults to UIKit; gated on `state.settings.hapticsEnabled` at delivery; RM-independent) | QuestMomentSupport + MomoAppModel |

`ResponsePlan.haptic` remains nil everywhere (engine-frozen); the haptic decision is pure (`MomentHapticKind.deliveryKinds`, headless-tested with the gate).

### The fixture-store verdict (R10 verify-before-trust, honest)

A pre-seeded STORE FILE copied into `-momo-store-directory` is INFEASIBLE: the UI-test runner and the app-under-test live in different sandboxes, so the runner cannot place a store file the app will read. The disclosed adaptation: a `-momo-fixture <kind>` launch argument (DEBUG-only, `MomoApp.fixtureDefaultState`) serves a FIXTURE ENGINE STATE as the throwaway store's fresh default — the §5.3 injected-fresh-default parameter's own documented seam. Kinds: `stage-crossing` (bond 149, hello unspent → ONE pat awards +8, crosses 150, completes Q1: the full M1+M2 fan-out) and `all-done` (the day's set complete → the §4.8 cascade reads `.allDone` from frame one). Constraint honored: the fixture only serves on a FRESH store, so each fixture test uses a unique `-momo-store-directory`. Fixture launches land straight on Home (`onboardingComplete: true`) — no onboarding walk. Production launches never pass the argument.

### M1 test premise (verified, not assumed)

Q1 is `.greet`/target 1 (`Quest.swift:80`); the canvas touch path is the ONLY `awardHello` site and quest-ticks `[.greet, .pet]` (`InteractionSemantics.swift:138-145`); onboarding's "Say hello" button routes NO intent (`completeOnboarding` applies only `.onboardingCompleted`). So a prepared-store launch shows Q1 pending, and one head pat completes it — no banner risk (fresh bond 10 + hello ≪ 150). The M1 test uses `preparedHomeApp` (the R13 restart pattern): a single frozen launch never mints the day record, so `freshHomeApp` would show no row at all.

### Structural decomposition (why the tests are where they are)

The fan-out's decision layer is PURE in MomoKit (`QuestMomentSupport`: `eventBornMoments`, `celebrationStage`, `flippedQuests`; `MomentHapticKind.deliveryKinds` with the gate) — headless-tested in `QuestMomentTests` (6 tests). The wiring half lives in the app model's `.deliverMoments` arm (mechanical: filter → fold `.moments` → celebration → haptics), pinned by the R9e-g structural guards (exact-string legs + non-vacuity violation fixtures, 3 new tests in `RigDisciplineTests`, all 23 green) and by the UI glass tests. No self-biting: the guards fire on real violation shapes only (fixtures provided both directions).

### Banner a11y (R4(d) choice, empirically confirmed testable)

The banner visual is `.accessibilityHidden(true)` (the full-line announcement + the persistent status row carry the words — a focusable duplicate button would double-speak the crossing), and XCUITest STILL queries it via `.accessibilityIdentifier` (verified empirically — both M2 glass tests pass with element lookups and taps). R8 held: `MomoReduceMotion.swift` and `MomoMoments.swift` untouched; the new RM-tracker fold assertion (`reduceMotionTrackerFold`) pins `.moments` harmlessness by construction; RM twin suites green with the corpus stream extended.

### Known deviations & corrections (§25 honesty)

1. **App-target import fix:** the first UI-test run FAILED TO BUILD — `HomeQuestCardView` names `QuestID` in its new `celebratingQuests` property and the app target had no `import MomoCore`. The prior session's "app build exit 0" evidence did NOT hold for the final file state (§24 no-fake-completion: recorded, fixed per the `HomeCanvasTouchLayer` precedent, gates re-run green end-to-end).
2. **R10's "flourish + sparkle in one tap" M1 UI ambition:** the sparkle's timing is frozen director behavior already pinned headless (MomoMomentQueueTests); at the glass the flourish/haptic are un-assertable halves — the M1 UI test pins the observable face (row label flips to ", done") and the no-presentation law. The banner-half flourishes ARE glass-pinned (M2 tests).
3. **Banner backgrounding non-deferral:** accepted per the contract's Context pin (delivery-time surface; the engine's `highestCelebratedStage` once-guard owns once-semantics).
4. **`deliverResponse` vestigial-closure removal (REVIEW-TASK-036 F-1, MINOR — dispositioned here at closeout):** the contract's Files/Areas note said "do NOT remove the closures"; the implementation removed the vestigial `deliverResponse` app-model closure (dead since TASK-035's report drain made the arm's inline work complete) and disclosed it only in a code comment, not in this file. The reviewer verified behavior correct (all seven semantic checks pass); this entry completes the §25 record. The `.deliverMoments` closure was likewise removed and inlined — the same disclosure applies.

### Follow-ups recorded (NOT implemented — §22)

- Haptics toggle UI rides TASK-038 (reads the same `hapticsEnabled` field; the sink injection point is ready).
- 05 §4.9 selection-class errata note (moment = fixed lookup) rides the orchestrator's doc-errata backlog.
- Watch propagation of the stage word is EPIC-008's (snapshot already carries it).
- MomoUITests F-3 `@MainActor` debt untouched (TASK-039's, per the contract).
- REVIEW-TASK-036 F-2 (MINOR, non-blocking → TASK-039): R9e is blind to sink-invocation removal — a negative bite (`momentHapticSink(kind)` → `_ = kind`) left RigDisciplineTests 23/23 green. Fix: add `momentHapticSink(kind)` as a fifth R9e leg + fixture update, with a fresh negative-probe re-bite.

## Handoff

### Completed

All of R1–R10: the `.moments` event door (R1), director FIFO with the three advance sites (R2), M1 flip memory + flourish + gated light haptic + done announcement (R3), M2 banner + composed line + tap/auto-fade + full-line announcement + celebration haptic (R4), M3 `isAllDone` + warm note (R5), the fixed-lookup catalog landing with the `.00` removal and law-test extensions (R6), the injected gated haptic sink (R7), zero RM/MomoMoments edits + fold assertion + twins green (R8), R9e-g structural guards with violation fixtures (R9), and the full test battery (R10).

### Files Changed

Modified (15): `Sources/MomoCharacter/MomoReactionState.swift`, `Sources/MomoCharacter/MomoReactionDirector.swift`, `Sources/MomoKit/HomeReadModel.swift`, `Sources/MomoKit/HomeCopyKeys.swift`, `Apps/Momo/MomoAppModel.swift`, `Apps/Momo/MomoApp.swift`, `Apps/Momo/HomeView.swift`, `Apps/Momo/HomeQuestCardView.swift`, `Apps/Shared/MomoCopy.xcstrings`, `MomoUITests/MomoHomeUITests.swift`, `Tests/MomoCharacterTests/{MomoReduceMotionTwinTests, MomoCatalogScaffoldingTests, CatalogCopyLawTests, RigDisciplineTests}.swift`, `Tests/MomoKitTests/HomeReadModelTests.swift`.
New (3): `Sources/MomoKit/QuestMomentSupport.swift`, `Tests/MomoCharacterTests/MomoMomentQueueTests.swift`, `Tests/MomoKitTests/QuestMomentTests.swift`.
Total 857 insertions / 75 deletions. Untouched by rule: `MomoMoments.swift`, `MomoReduceMotion.swift`, all MomoCore, all Watch sources, `.claude/tasks/reviews/`.

### Tests Run

- `swift test` (full SwiftPM suite, final run this session).
- `xcodebuild test -project Momo.xcodeproj -scheme Momo -destination 'platform=iOS Simulator,id=1F25E487-A78E-464C-95AF-0BD1A9B3E1BE' -only-testing:MomoUITests` (full UI suite) — after an initial targeted run of the two M2 tests.
- `xcodebuild -project Momo.xcodeproj -scheme MomoWatch -destination 'platform=watchOS Simulator,name=Apple Watch SE 3 (40mm),OS=26.5' build`.
- Forced-recompile warnings sweep (touch of the 5 app-target/UI-test files + rebuild, all `warning:` lines attributed).
- `git status` / `git diff --stat`.

### Test Results

- **Package: 925 tests in 94 suites, ALL PASSED** (baseline 907/92 + 18 new: MomoMomentQueueTests 7, QuestMomentTests 6, HomeReadModelTests `allDoneTruth` 1, RigDiscipline R9e-g 3, twin/verbatim/law pins). Epoch-4 residue pins green verbatim.
- **UI suite: 21/21 PASSED** — 16 `MomoHomeUITests` (13 existing + `testFirstPatCompletesTheMorningWish`, `testStageBannerRisesAndDismissesOnTap`, `testStageBannerAutoFades`, `testAllDoneCardCarriesTheWarmNote`), 4 `MomoOnboardingUITests`, 1 launch test. `** TEST SUCCEEDED **`.
- **MomoWatch build: `** BUILD SUCCEEDED **`** (only pre-existing environment warnings: `/opt/extra/lib` search path, AppIntents metadata skip).
- **Warnings: ZERO from touched files** (forced-recompile sweep empty; package code warning-free under `swift test`).
- **Repository: clean of illegitimate files** — exactly the 15 modified + 3 new TASK-036 files, branch `feature/EPIC-007-iphone-home` (HEAD `94bf69b` = the TASK-036 contract commit).

### Known Issues

- The first UI-test attempt failed to BUILD (missing `import MomoCore` in `HomeQuestCardView` — see Known deviations §1); fixed and every gate re-run after the fix. No other failures occurred in any final gate run.
- Banner does not defer across backgrounding (accepted per contract Context; disclosed above).

### Decisions Made

- Two-doors architecture landed as contracted (state-born greetings via `.displayState`; event-born moments via the new `.moments` door; one shared L4 slot).
- `momo.line.moment` = FIXED lookup under OBS-D (adjudication recorded verbatim above; no epoch bump).
- Fixture state rides the injected fresh-default seam (fixture-STORE handoff infeasible across sandboxes) — the disclosed R10 adaptation.
- M1's flourish/haptic pinned headless + structurally; the glass test pins the row-label flip (the honest un-assertable halves disclosed).
- Banner visual a11y-hidden with the full-line announcement (R4(d)'s "may be"); empirically confirmed XCUITest-queryable for the glass pins.

### Reviewer Status

**APPROVED_WITH_MINOR_NOTES** — `REVIEW-TASK-036` (fresh independent agent, §33 unprimed; 6 findings: 2 MINOR / 2 NITPICK / 2 OBS, no MAJOR). All three R9e-g guards bite with exactly their own test; negative probe (bite 4) proved F-2's R9e blindness. 925/94 green pre- and post-bite; both bitten files restored sha256-identical. F-1 (undisclosed vestigial-closure removal) dispositioned as Known deviation §4 above; F-2 (R9e 5th leg + fixture) routed to TASK-039 as a Follow-up above.

### Commit

`3861c7b` — `feat(home): TASK-036 wire quest moments + celebrations — event door, FIFO, banner, M1/M3 surfaces` (20 files, +1543/−81; includes this file's dispositions and the review record).

### Push

`94bf69b..3861c7b` → origin — success (recorded in `.claude/tasks/status.md` Recent Pushes).

### §19 gate evidence (orchestrator re-verification, 2026-09-11)

- `swift test`: **925 tests / 94 suites passed** (matches implementer + reviewer counts).
- UI suite (pinned SE 3rd gen `1F25E487`): **21/21 passed** (TEST SUCCEEDED; 16 Home + 4 new glass + 1 legacy).
- `MomoWatch` build (Watch SE 3 44mm `8A854895`, watchOS 26.5): **BUILD SUCCEEDED**, zero warning lines.
- Package suite re-run AFTER the disposition edits (doc-only, source untouched) — the 925/94 run above post-dates them.

### Recommended Next Step

Orchestrator: spawn the fresh independent Jupiter review agent over this task file + the working-tree diff (18 files) per §10/§33; after APPROVAL and any findings-addressed cycle, commit atomically as `feat(home): TASK-036 wire quest moments + celebrations — event door, FIFO, banner, M1/M3 surfaces`, push, and update `.claude/tasks/status.md`.

HANDOFF-COMPLETE TASK-036
