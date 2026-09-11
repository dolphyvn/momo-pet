# TASK-034 — Touch & petting: canvas gestures, director wiring, spoken reactions

## Parent Epic

EPIC-007 — iPhone Home Experience (FR-5; UX §5.1 gesture map; 04 §2.3–2.4, §6.1–6.2).

## Objective

Wire the composed Home canvas into the interaction loop: every §6.1 gesture×zone
class renders its engine-distinct response through the frozen reaction director,
the canvas stays ONE VoiceOver element and gains the "Pat"/"Cuddle" custom
actions with spoken reaction lines (UX-8), petting banks zero bond (G2), and the
naked lost-boundary press touch-cancel seam (REVIEW-TASK-028 FIX1-NOTE-1) is
owned at the wiring level.

## Context (verify everything before trusting — §5 verify-before-trust)

- TASK-033 landed the composition: `home.canvas` is the region-backed ONE
  a11y element (label = petName) in `Apps/Momo/HomeView.swift`; the rig renders
  via `MomoRigView(displayState:tier:clock:stageSide:)` — NO `reactionMotion`
  closure, NO director state yet. `HomeActionRowView` routes pills through
  `appModel.interact` (the ONE sanctioned path) — mirror that for pats.
- EPIC-006 built the execution side (FROZEN — consume, never edit):
  - `MomoDirectorState` (`Sources/MomoCharacter/MomoReactionDirector.swift`)
    folds `MomoCharacterEvent`s in order via `apply(_:)`: `.plan(ResponsePlan, at:)`,
    `.displayState(_, at:)`, `.touchBegan(zone:at:)`, `.touchEnded(at:)`,
    `.fingertip`, `.appHidden/.appShown`. The overlay reaches the rig through
    `MomoRigView`'s `reactionMotion: { state.overlay(at: $0) }` (or
    `state.reduceMotionOverlay(at: $0)`) closure — note the closure also
    receives the RESOLVED Reduce Motion Bool.
  - `MomoReactionClip` keys map 1:1 onto §6.1's rows: `react.tap.head`,
    `react.tap.belly`, `react.tap`, `react.doubleTap`, `react.longPress.head`,
    `react.longPress.belly`, `react.longPress`, `react.stroke.head`,
    `react.stroke.belly`, `react.stroke` (+ `react.stir`, `react.politelyFull`,
    `react.gentleDecline`, `react.settling`, … — the care rows are TASK-035's).
    `MomoReactionClip.init?(reactionID: ReactionID)` is the failable bridge.
  - Director-owned §6.1 rule-3 constants: `coalesceWindowSeconds` 0.5,
    `abbreviationFraction` 0.5, `coalescedSeconds` 0.45; lost-boundary backstops
    `strokeCycleCap` 4 and `pressLostBoundarySeconds` 5.0.
  - `MomoReportEntry` / `state.reports` — the exactly-once report log; use it
    (or the overlay trajectory) for evidence, not screenshots alone.
- MomoCore (FROZEN) already defines the intent vocabulary
  (`Sources/MomoCore/InteractionIntent.swift`): `PatGesture {tap, doubleTap,
  longPress, stroke}`, `TouchZone {head, belly}`,
  `InteractionIntent.Kind.pat(gesture:zone:)` (Watch convention `.pat(.tap,
  nil)`), and `InteractionSemantics.touchReaction(gesture:zone:) -> ReactionID`
  implementing §6.1 (the double-tap row is zone-less; nil zone falls to the
  zone-less clip rows for every gesture).
- Director-state ownership: `Apps/Momo/MomoAppModel.swift` is the only
  app-target non-view file importing MomoCharacter; it already owns
  `canvasClock: CharacterClock` (character-timeline source — event `at:` values
  come from `canvasClock.elapsed`) and `characterDisplayState`. The
  `MomoDirectorState` belongs beside them. **MomoKit must NOT import
  MomoCharacter** (verified: it does not today — keep it that way).
- The TASK-033 enablers are available for UI tests: `-momo-fixed-clock
  <ISO-8601-UTC>` (pinned instant AND UTC calendar; DEBUG-only) and
  `-momo-store-directory <path>` (throwaway stores). The two-instant restart
  pattern (R13) mints day-1 records for quest/gating states.
- **EPOCH TRAP (verified by orchestrator derivation):** the react-line pool
  growth bumps `copyEpoch` 2→3. Epoch 3's copy-salt draw for the pinned fixture
  (pet `7C47A9C4-2E5F-4B8A-9C1D-3E6F8A2B4C0D`, day `2026-09-08`) is seed
  `0x13ec67b5bdf1e2f7`, draw `0xdc227781a4980eaa` — **index 2, the SAME residue
  as epoch 2**, so `rawKeysPinned` will stay GREEN through the bump and ONLY
  `copyEpochIsTwo` fails. Do not read the green pins as "epoch not needed" —
  re-pin the epoch literal, re-derive the new draw law consciously (temporary
  probe test → run → delete, the TASK-033 precedent), and note that the react
  pick is `draw % reactLineCount(.touch)` over the NEW pool size (derive the
  pinned react index the same way).
- Two stale comments in `MomoAppModel.swift` say "TASK-033's director/report
  wiring" / "director/moments wiring is TASK-033's" (~lines 88 and 138) —
  they predate TASK-033's landed scope; correct them to TASK-034 in this diff.

## Requirements

- **R1 — Gesture recognition on the canvas:** tap, double-tap, long-press
  (hold duration captured — press-length is §6.1 input), stroke (movement-based,
  ≥ a small movement threshold to distinguish from tap), all zone-partitioned
  by 04 §2.3's y=550 normalized split (head above, belly below) as a PURE
  hit-test function of normalized coordinates (unit-testable). The layout laws
  of TASK-033 (≥ 88 pt stage, ≥ 44 pt targets, ONE element) are untouched.
- **R2 — The ONE engine path:** every recognized gesture dispatches
  `InteractionIntent.Kind.pat(gesture:zone:)` through `appModel.interact(…)`
  AND feeds the director `.touchBegan(zone:at:)` / `.touchEnded(at:)` with
  `canvasClock`-timeline instants. Engine plan arrives through the existing
  facade result — feed the director `.plan(ResponsePlan, at:)`.
- **R3 — Distinct responses:** each §6.1 gesture×zone class renders its
  `InteractionSemantics.touchReaction`-derived clip through the director
  (engine-distinct visual response per row; the double-tap row is zone-less).
- **R4 — §6.2 gating:** sleeping accepts only stir and stays asleep; Drowsy
  tempo, waking-queue, and settling semantics are director/engine-owned — wire
  them through, verify E2E where the fixed-clock enabler can reach the state,
  unit/facade-level otherwise.
- **R5 — Rapid-pat coalescing** is director-owned (constants above); verify by
  wiring test + the existing director suite, no reimplementation.
- **R6 — VoiceOver custom actions:** the canvas (still ONE element) exposes
  `accessibilityCustomActions` "Pat" and "Cuddle" (the long-press analog),
  routing the ZONE-LESS conventions `.pat(.tap, nil)` / `.pat(.longPress, nil)`
  (the clip system has zone-less rows; the Watch convention proves the path).
- **R7 — Spoken reaction lines (UX-8):** land the
  `momo.line.react.touch.<nn>` pool — accessibility-only copy (NEVER rendered
  as body copy; announced while VoiceOver runs when a touch reaction fires).
  Contract-pinned pool (5 lines, Momo voice, calm/premium):
  1. `momo.line.react.touch.00` — "Momo nuzzles into your hand." (the 03 §5.1
     example line)
  2. `momo.line.react.touch.01` — "Momo leans into the touch."
  3. `momo.line.react.touch.02` — "Momo blinks slowly, content."
  4. `momo.line.react.touch.03` — "Momo's tail curls happily."
  5. `momo.line.react.touch.04` — "Momo presses closer for a moment."
  `CopyRules.reactLineCount(.touch)` 1→5 with `copyEpoch` 2→3 (the SAME
  R4-review-gated carveout discipline as TASK-033: MomoCore diff = CopyRules
  only). Announcement through the a11y seam; INV-11 holds (keys, never prose,
  below the view).
- **R8 — G2 zero bond:** petting banks zero bond — verify E2E (pat sequence →
  bond value unchanged; engine already guarantees; pin at facade + UI level).
- **R9 — Touch-cancel seam (FIX1-NOTE-1):** the wiring guarantees a
  `touchEnded`-equivalent on gesture cancellation (SwiftUI's `onEnded` covers
  the ordinary cancel paths — VERIFY, don't assume; document the guarantee).
  The naked-press residual (touchBegan with no reaction arrival and no
  boundary) rides the director's `pressLostBoundarySeconds` 5.0 cap as
  backstop. NO MomoCharacter changes for this item — the routing is view-side.
- **R10 — Comment corrections:** the two stale "TASK-033's director wiring"
  comments in `MomoAppModel.swift` (see Context).
- **R11 — Recorded non-goal:** continuous pupil-follow (§2.4) and its RM
  substitution have NO view seam today (no gaze parameter on `MomoRigView`, no
  gaze event in `MomoCharacterEvent`) — do NOT add MomoCharacter surface for
  it; record the follow-up in the task notes at closeout.
- **R12 — Boundaries:** D-R5 (no engine logic in views; the app model owns the
  director fold), INV-11, MomoKit never imports MomoCharacter, no MomoCore
  change beyond the R7 CopyRules carveout, MomoCharacter diff EMPTY expected —
  any touch must be disclosed and minimal (epic Test Requirements).

## Files / Areas Likely Affected

`Apps/Momo/HomeView.swift` (gesture layer + reactionMotion wiring),
`Apps/Momo/MomoAppModel.swift` (director state, event fold, spoken-line
announcement seam), `Apps/Shared/MomoCopy.xcstrings` (react.touch pool),
`Sources/MomoCore/CopyRules.swift` (carveout only),
`Tests/MomoCoreTests/CopySelectionPinnedTests.swift` (epoch re-pin — see the
EPOCH TRAP), new/extended catalog-law tests (verbatim pins for the new pool —
see AC-5), `MomoUITests/MomoHomeUITests.swift` (gesture/custom-action E2E),
`Momo.xcodeproj/project.pbxproj` only if new files are added.

## Dependencies

TASK-033 (committed). Frozen surfaces listed in Context. No new epics.

## Constraints

CLAUDE.md §22/§24 scope discipline; ≤ 800-line files; immutable patterns; no
engine semantics changes (EPIC-004 frozen); no character-motion changes
(EPIC-006 frozen); §4.10 catalog→epoch discipline; banned-vocabulary scan over
the new strings; VoiceOver/AC laws from 03 §10.

## Acceptance Criteria

- **AC-1:** every §6.1 gesture×zone class yields its engine-distinct response
  through the composed Home (director-level evidence per row; UI smoke for the
  tap-family rows on the pinned simulator).
- **AC-2:** sleeping → stir, stays asleep (facade/director-level pinned; UI
  where reachable via the enablers).
- **AC-3:** VoiceOver: canvas ONE element + "Pat"/"Cuddle" custom actions
  present and routing zone-less intents; spoken line announced under VO.
- **AC-4:** petting banks zero bond (E2E).
- **AC-5:** the new react.touch pool is VERBATIM-pinned at landing
  (extend the `catalogCarriesTheVocabularyVerbatim` pattern to the pool) — do
  not re-create REVIEW-TASK-033's MINOR-1 gap for the new strings.
- **AC-6:** `swift test` green (with the epoch-3 re-pin and new law tests) +
  full app UI suite green on the pinned simulator; `git diff` shows MomoCore =
  CopyRules carveout only, MomoCharacter = empty.

## Required Tests

Unit: zone partition hit-test purity; touchReaction→clip exhaustiveness;
director fold-order through the app model (clock timeline from `canvasClock`);
zero-bond facade pin. Catalog: react.touch verbatim pins + epoch-3 law (incl.
the consciously re-derived draw pins). UI: gesture distinction smoke (tap
head/belly, double-tap), custom-action presence, canvas still one element.

## Review Requirements

Fresh independent §10 reviewer; docs-first re-derivation from 04 §2.3/§2.4/
§6.1/§6.2, 03 §5.1/§10 (UX-8, UX-14), PRD FR-5/G2, 05 §4.x/D-R5; adversarial
verification incl. mutation bites on the epoch/carveout and the cancel seam;
no priming.

## Git Requirements

Atomic commit containing TASK-ID, e.g.:
`feat(home): TASK-034 wire canvas touch & petting — gestures, director, spoken reactions`
No attribution trailer. Push after review approval per §13/§14.

## Status

DONE — implemented → REVIEW-TASK-034 (CHANGES_REQUIRED: F-1 HIGH the missing
`reactionMotion:` view wiring, F-2 MEDIUM the undisclosed `.inactive` →
`backgrounded()` route) → fix cycle applied → REVIEW-TASK-034-FIX
(**APPROVED**, 2026-09-11, no remaining findings) → §19 gate green at the
final tree → committed and pushed per §12/§13. N1/O1/O2 carried as
non-blocking notes. Full evidence under Completion Evidence.

## Implementation Notes

(filled by the TASK-034 implementation agent; tree left DIRTY for §10 review —
no commit made by this agent)

### New files

- `Sources/MomoKit/CanvasTouch.swift` — the PURE touch vocabulary (R1):
  `CanvasTouchLaws` (per-constant authority labels: `stageGridSide` 1000 and
  `zoneSplitY` 550 are 04 §2.1/§2.3 doc-normative; `strokeMovementGrid` 60,
  `longPressMinimumSeconds` 0.5, `doubleTapWindowSeconds` 0.35 are
  presentation-owned recognizers; `spokenTouchPrefix` is the UX-8 namespace),
  `CanvasZoneHitTest.zone(normalizedY:)` (pure, TOTAL — out-of-grid y still
  classifies, INV-2's no-dead-zones reading), `CanvasGesture`,
  `CanvasTouchClassifier.completedGesture` (pure per-touch: stroke bar →
  long-press bar → nil = tap-speed, the sequence decides),
  `CanvasTapSequence` (immutable pairing state; pairing requires the second
  tap to END after the first, so the `CharacterClock` pause-zeroing never
  pairs across a reset; `resetting()` is the cancellation seam),
  `CanvasCustomAction` (the R6 vocabulary "Pat"/"Cuddle" → zone-less
  `.pat(.tap, nil)` / `.pat(.longPress, nil)`), and
  `SpokenReaction.announcementKey` (the UX-8 gate: touch-pool prefix ONLY).
  Imports: Foundation + MomoCore. No MomoCharacter import (R12/D-R5).
- `Apps/Momo/HomeCanvasTouchLayer.swift` — `HomeCanvasTouchSurface`, the
  transparent gesture overlay: `DragGesture(minimumDistance: 0)` with a
  `@GestureState` press seam (`.onChange` of the reset → `resolveAsCancellation()`,
  R9), zone from the stage-square geometry (normalized y → `CanvasZoneHitTest`),
  movement accumulated in grid units, gestures dispatched through
  `appModel.interact` (R2's ONE engine path), tap-speed touches fed to
  `CanvasTapSequence` with a scheduled window maturation (the 0.35 s
  single-tap delay, disclosure g).
- `Tests/MomoKitTests/CanvasTouchTests.swift` (11 tests), `PatPlanBondTests.swift`
  (2), `Tests/MomoCharacterTests/MomoTouchSemanticsTests.swift` (4),
  `MomoUITests/MomoHomeUITests.swift` +3 tests (below).

### Edited files

- `Apps/Momo/MomoAppModel.swift` — director ownership: `private(set) var
  director: MomoDirectorState` initialized from the loaded state (local
  `loadedState` first — init-order), `foldDirector(_:)` folding a successor
  value (immutability), `touchBegan(zone:)/touchEnded()` model entries, the
  R3 closure factory `reactionMotion() -> @Sendable (Double, Bool) ->
  MomoReactionMotion` capturing the director VALUE (not self — Sendable-clean,
  D-R5-clean; SwiftUI observation re-renders on folds), `.deliverResponse`
  folding `.plan` + the VoiceOver announcement + `deliverResponse`, the
  apply-loop's equality-gated `.displayState` fold, `scenePhaseChanged`
  folding `.appHidden` on background AND `.inactive` / `.appShown` on active
  (disclosure c), and the R10 stale-comment corrections.
- `Apps/Momo/HomeView.swift` — the canvas gains the touch overlay and
  `.accessibilityActions { canvasCustomActions }` (see disclosure b for the
  API substitution); header doc updated.
- `Momo.xcodeproj/project.pbxproj` — `HomeCanvasTouchLayer.swift` registered
  (4 spots, `8A4…53`/`8A5…53` ids).
- `Apps/Shared/MomoCopy.xcstrings` — the R7 contract pool verbatim
  (`momo.line.react.touch.00`–`04`, the five pinned lines, accessibility-only).
- `Sources/MomoCore/CopyRules.swift` — THE carveout only:
  `reactLineCount(.touch)` 1→5, `copyEpoch` 2→3, doc comments updated.
- `Tests/MomoCharacterTests/MomoCatalogScaffoldingTests.swift` — pool-growth
  re-pins. `Tests/MomoCoreTests/{CopySelectionPinnedTests,InteractionResponseTests,
  EngineReduceTests,WakefulnessHandshakeTests,BondLedgerTests,TimeFoldTests}.swift`
  — epoch-3 re-pins; the shared fixture (petID + day `2026-09-08`) draws
  `momo.line.react.touch.02` at epoch 3 (probe-derived per the EPOCH TRAP;
  `CopySelectionPinnedTests` carries the derivation). Template-level pins in
  `MomoCopyTests` untouched — they pin the key BUILDER, not selection.
- `Tests/MomoCoreTests/CopySlotTests.swift` + `LineSelectionTests.swift` —
  TASK-019 blast radius (disclosure j).

### Disclosures (§22/§25 — read before review)

- **(a) R7 resolved announcement-ONLY.** `HomeCopyKeys` anticipated TASK-034/035
  contextual use of the react slots; resolved AGAINST rendering: the
  react.touch lines are rendered by NO view — their sole consumer is the
  VoiceOver announcement seam (`announceSpokenLine` → `UIAccessibility.post`
  when VoiceOver runs, gated by `SpokenReaction`). INV-11 holds below the view.
- **(b) R6 API substitution (verified, not assumed).** The Xcode 26.5 SDK's
  SwiftUI has NO `AccessibilityCustomAction` type and NO
  `.accessibilityCustomActions(_:)` modifier (swiftinterface grep +
  `swiftc -typecheck` probes); the platform's custom-action surface is
  `.accessibilityActions { }` (ViewBuilder of Buttons, iOS 16+; deployment
  target 26.0). XCUITest cannot enumerate custom actions, so AC-3's
  "present and routing" is pinned in the pure layer
  (`CanvasTouchTests.customActionVocabularyPinned` — exactly `[.pat, .cuddle]`
  with the doc's raw labels; `customActionIntentsAreZoneless`) and the
  announcement gate; the UI layer pins the canvas stays ONE element with the
  pet-name label (`testCanvasIsOneElementLabeledWithThePetName`). The actions
  route through `appModel.interact` — the same sanctioned path as the
  gestures.
- **(c) `.appHidden` folds on `.inactive` too.** `scenePhaseChanged` maps
  `.active` → shown, `.background` AND `.inactive` → hidden. `.inactive` is
  app-switcher/control-center — the rig's clock pauses there, so an animating
  overlay over a paused clock would tear; hiding on the same transition
  mirrors that rule. Proactively-scoped interpretation, disclosed.
- **(d) FIX1-NOTE-1 — two layers.** View side: `@GestureState` reset seam
  cancels the press and drops any parked tap. Model side (the guarantee that
  cannot wedge): `touchBegan` force-closes a stale open press BEFORE opening
  — one finger means no overlap, so a began-while-open proves the layer lost
  the old end, and closing it at THIS instant keeps the invariant. Residual
  benign edge: if SwiftUI coalesces the reset with no body update, a
  same-location re-tap over-counts hold time (worst case: a tap reads as a
  long-press once). The director's `pressLostBoundarySeconds` 5.0 backstop
  still bounds any naked press.
- **(e) Watch:** no Watch source changed; the glance's react.touch key now
  resolves to real copy under the new pool. `MomoWatch` scheme build verified
  (see Handoff).
- **(f) R11/fingertip recorded non-goal:** `.fingertip` events are NOT wired —
  a stroke renders from its plan alone. Continuous fingertip streaming
  (04 §2.4 deepen/pace) has no view seam in the frozen surface beyond the
  director event enum and needs its own task; no MomoCharacter change was
  made or needed.
- **(g) Single-tap dispatch is deferred ~0.35 s** — the double-tap
  disambiguation window; inherent to §6.1's double-tap row on a
  single-element canvas.
- **(h)** `strokeMovementGrid` 60 grid units ≈ 15.6 pt at the Home stage's
  260-pt side (the doc names the class, not a number).
- **(i) Epoch-3 pin sweep** touched six MomoCoreTests files beyond
  `CopySelectionPinnedTests` (listed under Edited) — all share the fixture
  (petID, day) whose epoch-3 touch draw is `.02`.
- **(j) TASK-019 blast radius (contracted carveout's consequences).**
  `CopySlotTests.familyKeySpellings` and `LineSelectionTests.planCarriesFamilyKey`
  derived expected keys as "pool count − 1" — valid only while every react
  pool held one copy. Restated STRUCTURALLY (react-template prefix naming the
  family + suffix index inside the pool); the concrete day-stable draws stay
  raw in `CopySelectionPinnedTests`. No production code touched.
- **(k) Two first-draft test expectations were wrong, not the code.**
  (1) An edge-exact maturation probe (`10 + 0.35 − 10.0`) re-rounds a hair
  BELOW 0.35 in binary and pinned a floating-point artifact — moved clearly
  past the edge with a comment. (2) A 3 s hold with sub-stroke movement IS a
  long-press per §6.1 (once the stroke bar is missed, hold decides), not a
  tap-speed nil. Both fixed in `CanvasTouchTests`.

### Fix cycle (REVIEW-TASK-034)

(filled by the fresh fix agent, 2026-09-11 — EXACTLY the review's two
prescriptions plus its sanctioned regression guard; tree left DIRTY, no
commit/stage/push by this agent)

- **F-1 (HIGH) — FIXED.** `Apps/Momo/HomeView.swift:124` — `canvasBody`'s
  `MomoRigView(…)` now passes `reactionMotion: appModel.reactionMotion()` in
  the frozen initializer's argument position (after `stageSide:`, before the
  defaulted `reduceMotion:`; per `MomoRigView.swift:80-89`). The factory
  itself was NOT touched (review-verified correct: captures the director by
  value; its doc comment already described this exact consumption). The L1
  press layer, every §6.1 clip, the stir, and rapid-pat coalescing now
  actually render on the composed Home.
- **F-2 (MEDIUM) — FIXED.** `Apps/Momo/MomoAppModel.swift:279-292` — the
  compound `case .background, .inactive:` is split: `.background` folds
  `.appHidden` AND calls `backgrounded()` (foreground flag + boundary-task
  cancel — §4.2's machinery); `.inactive` folds `.appHidden` ONLY — the
  director's clock-pause gate; disclosure (c)'s paused-clock tear argument
  still holds on the app-switcher transition, and the engine semantics stay
  untouched (TASK-031's reviewed trigger-table row for `.inactive` is
  restored verbatim). The doc comment above the switch (:267-278) was
  rewritten to state BOTH facts: `.inactive` triggers NOTHING in §4.2's
  trigger table, and the director gate applies to BOTH `.background` and
  `.inactive`. Disclosure (c) is now accurate as written.
- **F-2 behavioral delta (disclosed):** during `.inactive`, `isForeground`
  now stays `true` and a live `boundaryTask` is no longer cancelled — a
  boundary firing mid-transition proceeds to its fold, where the pre-fix
  code refused it (the next foreground fold caught up). On `.active` the
  catch-up fold fires unchanged. No headless or UI test reaches
  `scenePhaseChanged` (grep-verified), so no test adjustment was needed and
  none was made.
- **Regression guard — ADDED (structural, zero new infrastructure).** F-1's
  class (correct machinery, severed view wiring) was invisible to every
  behavioral suite, so the wire is pinned structurally — the same pattern
  the suite already uses for the scenePhase wire: new scanner
  `RigDiscipline.mentionsHomeReactionWiring(in:)` +
  `RigDisciplineTests.homeWiresReactionMotion` in
  `Tests/MomoCharacterTests/RigDisciplineTests.swift:145,321`, reading
  `Apps/Momo/HomeView.swift` through the existing `readRigFile` helper and
  asserting the `MomoRigView(` construction passes
  `reactionMotion: appModel.reactionMotion()`, with the non-vacuity
  direction pinned in-test. **Mutation bite** (sha256-proven restoration;
  pre/post hash identical `b1cd33e9…f8cd85`): with the argument removed the
  guard FAILS with exactly 1 issue; restored, it passes. A UI-level
  rendered-motion assertion was rejected as structurally flaky (XCUITest
  cannot inspect canvas pixels; the idle animation defeats screenshot
  diffing) — the broader UI-consolidation intent stays routed to TASK-039.
- **Fix-cycle test runs (this agent's own numbers, 2026-09-11):**
  1. `swift test` — PASSED: **887 tests in 91 suites, 0 failures**
     (baseline 886/91 + the one guard test).
  2. `xcodebuild test -scheme Momo -destination 'platform=iOS
     Simulator,id=1F25E487-A78E-464C-95AF-0BD1A9B3E1BE'
     -only-testing:MomoUITests` — PASSED: **13 tests, 0 failures, TEST
     SUCCEEDED** (229.2 s; the UI suite gained no test, so 13/13 stands).
  3. Watch build NOT run — the fix cycle touched no `Sources/` and no
     `Apps/Shared/` file (the dispatch's condition for requiring it).
- **`git status --porcelain` after the fix cycle:** identical to the
  reviewed dirty set PLUS exactly one file — `M
  Tests/MomoCharacterTests/RigDisciplineTests.swift` (the guard). Frozen
  surfaces still clean: `git diff -- Sources/MomoCharacter/` EMPTY;
  `Sources/MomoCore/` still CopyRules-carveout-only (29/20, unchanged by
  the fix cycle). File-length cap holds (largest touched file 563 ≤ 800).

## Reviewer Findings

Full record: `.claude/tasks/reviews/REVIEW-TASK-034.md` (fresh independent
agent, 2026-09-11; base `134284a`, dirty tree). Verdict **CHANGES_REQUIRED**.

- **F-1 (HIGH)** — `HomeView.canvasBody`'s `MomoRigView(displayState:tier:
  clock:stageSide:)` omits `reactionMotion:`; the frozen default
  `{ _, _ in .identity }` serves every frame, so the L1 press layer, every
  §6.1 clip, the stir, and rapid-pat coalescing never render (only the
  VoiceOver announcement works). ORCHESTRATOR-VERIFIED: repo-wide grep shows
  no call site of the factory in `Apps/`. Green suites were structurally
  insensitive (they assert navigation/labels, not rendered motion).
  Fix: pass `reactionMotion: appModel.reactionMotion()` in `canvasBody`.
- **F-2 (MEDIUM)** — `case .background, .inactive:` routes `.inactive`
  through `backgrounded()` (foreground flag + boundary-task cancel) beyond
  disclosure (c)'s director-only scope, contradicting the carried TASK-031
  doc comment (".inactive … triggers nothing in §4.2's table").
  ORCHESTRATOR-VERIFIED in the diff. Fix: split the case — `.background`
  keeps hidden+backgrounded; `.inactive` folds the director only — and
  correct the comment to state both facts.
- **N1 (NITPICK, accepted)** — stale maturation task not cancelled; reviewer
  proves benign (probe instant strictly postdates; `maturing(now:)` re-checks
  the current tap). No change.
- **O1 (OBSERVATION, routed)** — `touch.03`'s straight apostrophe is the
  CONTRACT's own pinned byte (verbatim-faithful); the curly-quote
  normalization rides TASK-035's catalog landing (contract line + catalog
  move together).
- **O2 (OBSERVATION)** — pbxproj registration exactly as claimed. No action.
- Disclosures a–k: VERIFIED except (c) PARTIAL (= F-2). Disclosure (b)
  verified against the SDK swiftinterface itself; mutation bite (epoch
  flip) performed with sha256-proven restoration; epoch derivation
  reproduced bit-for-bit (epoch 3 → index 2, seed `0x13ec67b5bdf1e2f7`).
- Reviewer's own runs: swift test 886/91 PASSED; UI suite 13/13 on the
  pinned sim; Watch build SUCCEEDED.

### Delta re-review (REVIEW-TASK-034-FIX, 2026-09-11) — APPROVED

- Fresh §33 reviewer over the fix delta only (three files: `HomeView.swift`,
  `MomoAppModel.swift`, `RigDisciplineTests.swift`); scope exactness
  verified (dirty set = round-1 set + the guard file + the two review
  documents; `git diff -- Sources/MomoCharacter/` EMPTY; `Sources/MomoCore/`
  still CopyRules-only; docs untouched).
- **F-1 VERIFIED RESOLVED** — `HomeView.swift:119-125` passes
  `reactionMotion: appModel.reactionMotion()`; label+type match the frozen
  initializer (`MomoRigView.swift:79-90`); the factory captures the director
  BY VALUE (`MomoAppModel.swift:370-377`, `@MainActor` model); the rig
  samples the closure per frame (`MomoRigView.swift:140-147`); observation
  re-renders per fold.
- **F-2 VERIFIED RESOLVED** — case split (`:279-295`) matches the corrected
  doc comment (`:267-278`) and 05 §4.2's trigger table (no `.inactive` row;
  boundary row "in-session only" — still satisfied).
- **Disclosed `.inactive` behavioral delta adjudicated ACCEPTABLE**: a
  mid-transition boundary is CONSUMED (re-schedule-never-replay), `@MainActor`
  serialization rules out races, the `.active` catch-up is idempotent segment
  folding, the display-state fold is equality-gated; the double-`.appHidden`
  shape predates the fix and the frozen director guards it (reported flags,
  ADR-010 restart-from-0).
- **Guard attacked and held** — the reviewer's own mutation bite (argument
  removed → exactly 1 test, 1 failure; sha256 `b1cd33e9…f8cd85` identical
  before/after; dirty set unchanged); non-vacuity pin defeats helper stubbing
  in BOTH directions; a literal identity closure is caught; `RepoTree` is
  `#filePath`-based (no CWD dependence); reading an `Apps/` file is a first
  in this suite but mechanically identical to existing precedent and fails
  loud on rename.
- Reviewer's own runs: swift test 887/91 PASSED; app build SUCCEEDED (exit 0,
  pre-existing ld warnings only); UI suite 13/13 on the pinned sim (~3m47s).
  Hygiene clean: 0 TODO/FIXME/print/NSLog in the delta files; 563/151/383
  lines; import whitelists hold; MomoKit imports no MomoCharacter.
- ORCHESTRATOR-VERIFIED before dispatch: both fixes, the guard, and the
  dirty set confirmed by direct reads (HomeView :117-126, MomoAppModel
  :265-295, RigDisciplineTests :144-151/:321-335, `git status` set).

## Completion Evidence

- Review chain: REVIEW-TASK-034 CHANGES_REQUIRED (F-1/F-2) → fix cycle
  (Implementation Notes → Fix cycle) → REVIEW-TASK-034-FIX **APPROVED**
  (both documents in `.claude/tasks/reviews/`).
- §19 gate at the FINAL tree (orchestrator's own runs, 2026-09-11):
  - `swift test`: **PASSED — 887 tests in 91 suites, exit 0** (baseline
    869/88 → +18: CanvasTouchTests 11, PatPlanBondTests 2,
    MomoTouchSemanticsTests 4, the F-1 wiring guard 1). Reproduced
    independently 3× (fixer, delta reviewer, orchestrator).
  - App UI suite: **PASSED — 13 tests, 0 failed, TEST SUCCEEDED (229.9 s)**
    on pinned SE 3rd-gen `1F25E487-A78E-464C-95AF-0BD1A9B3E1BE` (reproduced
    independently 3×: fixer 229.2 s; delta reviewer ~3m47s; orchestrator
    229.9 s at the §19 gate).
  - Watch build: NOT re-run at the final tree — condition verified: nothing
    Watch-visible changed after the round-1 green Watch build (the catalog
    `Apps/Shared/MomoCopy.xcstrings` was already present then; the fixes
    touch only `Apps/Momo/` iPhone-target files and one test file; the round-1
    reviewer's Watch build SUCCEEDED with the catalog landed, disclosure e).
  - Hygiene: §19 scans clean (0 TODO/FIXME/HACK; 0 print/NSLog; max file
    563 ≤ 800; import whitelists hold; frozen surfaces untouched).
- AC-1…AC-6 satisfied (round-1 review + delta re-review; F-1's rendering leg
  now wired and structurally guarded against regression).
- Commit: atomic, TASK-ID in the message (see Handoff → Commit); this task
  file moved to `.claude/tasks/completed/` in the same commit (the TASK-033
  precedent); the commit hash is recorded in the next orchestration commit
  and in status.md.

## Handoff

### Completed

R1–R12 all implemented per contract; AC-1…AC-6 satisfied with the disclosed
API substitution (disclosure b). The touch vocabulary, the app-model director
wiring, the react.touch pool + carveout, the cancel seam, the custom actions,
the announcement gate, and the zero-bond pins are in place. Tree left DIRTY
for the §10 review — no commit, no push by this agent.

### Files Changed

New: `Sources/MomoKit/CanvasTouch.swift`, `Apps/Momo/HomeCanvasTouchLayer.swift`,
`Tests/MomoKitTests/CanvasTouchTests.swift`,
`Tests/MomoKitTests/PatPlanBondTests.swift`,
`Tests/MomoCharacterTests/MomoTouchSemanticsTests.swift`.
Edited: `Apps/Momo/MomoAppModel.swift`, `Apps/Momo/HomeView.swift`,
`Apps/Shared/MomoCopy.xcstrings`, `Sources/MomoCore/CopyRules.swift` (the
carveout only), `Momo.xcodeproj/project.pbxproj` (4 added lines),
`MomoUITests/MomoHomeUITests.swift` (+3 tests), and the epoch-3 pin sweep:
`Tests/MomoCharacterTests/MomoCatalogScaffoldingTests.swift`,
`Tests/MomoCoreTests/{CopySelectionPinnedTests, CopySlotTests,
EngineReduceTests, InteractionResponseTests, LineSelectionTests,
TimeFoldTests, WakefulnessHandshakeTests, BondLedgerTests}.swift`.
**Frozen-surface proof:** `git diff -- Sources/MomoCharacter/` is EMPTY
(0 bytes); `Sources/MomoCore/` changed ONLY in `CopyRules.swift`; no
`Sources/MomoKit/` file beyond the new one was touched.

### Tests Run

1. `swift test` — full package suite (twice: pre-fix run surfaced 5 issues,
   all resolved — see Implementation Notes (j)/(k); post-fix run clean).
2. `xcodebuild test -scheme Momo -destination
   'platform=iOS Simulator,id=1F25E487-A78E-464C-95AF-0BD1A9B3E1BE'
   -only-testing:MomoUITests` (pinned SE 3rd-gen simulator).
3. `xcodebuild build -scheme MomoWatch -destination 'platform=watchOS
   Simulator,id=8A854895-225C-411B-89C1-B03337BFE957'`.
4. §19 scans: TODO/FIXME/HACK/TEMP grep (clean), print/debug grep (clean),
   banned-vocabulary scan over the five new catalog strings (clean), file
   lengths (max 554 ≤ 800), import whitelists (MomoKit: Foundation + MomoCore
   only).

### Test Results

1. **`swift test`: PASSED — 886 tests in 91 suites** (baseline 869/88 →
   +17 tests in 3 new suites: CanvasTouchTests 11, PatPlanBondTests 2,
   MomoTouchSemanticsTests 4). The pre-fix run's 5 issues: two of my
   wrong first-draft expectations (disclosure k), two TASK-019
   single-copy-pool derivations (disclosure j), one fp-edge probe (also
   disclosure k).
2. **App UI suite: PASSED — 13 tests, 0 failed, exit 0** (baseline 10 →
   +3 TASK-034 tests, each passing: `testCanvasGesturesRouteThroughTheAppModelInPlace`
   19.9 s, `testCanvasIsOneElementLabeledWithThePetName` 16.1 s,
   `testPettingMovesNoStageWords` 18.8 s).
3. **Watch build: SUCCEEDED, exit 0, zero errors** — the glance's react.touch
   key compiles against the real pool.

### Known Issues

None blocking. Disclosed edges (Implementation Notes a–k): announcement-only
R7 reading; `accessibilityActions` API substitution (the named
`accessibilityCustomActions` surface does not exist in this SDK); `.appHidden`
also on `.inactive`; single-touch assumption with the benign
hold-over-count edge; `.fingertip` unwired (R11 non-goal); ~0.35 s single-tap
dispatch delay; TASK-019 structural restatement in two suites.

### Decisions Made

- The R3 rig closure is a closure FACTORY on the app model capturing the
  director VALUE — Sendable- and D-R5-clean; observation keeps re-renders on
  folds.
- FIX1-NOTE-1's guarantee lives in the MODEL (`touchBegan` force-close), the
  view seam is defense-in-depth — the invariant cannot wedge.
- TASK-019 expected keys restated structurally (template + in-pool index)
  instead of pinning an arbitrary epoch-3 draw outside the pinned suite.
- Two first-draft test expectations corrected against the implementation
  (disclosure k) — implementation judged correct per §6.1 both times.

### Reviewer Status

REVIEW-TASK-034: **CHANGES_REQUIRED** (F-1 HIGH the missing rig-wiring leg,
F-2 MEDIUM the undisclosed `.inactive` → `backgrounded()` route; N1/O1/O2
non-blocking) → fix cycle applied → REVIEW-TASK-034-FIX: **APPROVED**
(2026-09-11; no remaining findings; both documents in
`.claude/tasks/reviews/`). No self-approval at any point: implementation →
reviewer 1 → fixer → reviewer 2, all independent.

### Commit

`feat(home): TASK-034 wire canvas touch & petting — gestures, director,
spoken reactions` — atomic (all code/tests/catalog/pbxproj + this task file
moved to `completed/` + both review documents + status.md/epic refresh).
Hash recorded in the next orchestration commit and in status.md (the
TASK-033 precedent).

### Push

Pushed to `origin/feature/EPIC-007-iphone-home` immediately after the commit
(§13); result recorded in status.md.

### Recommended Next Step

TASK-035 — Feed / Play / Care flows (FR-6/7/8; UX §5.2–5.4; 04 §6.2–6.3):
author the contract from the orchestrator's completed pre-read (react.feed/
.play/.care pools + the care-moment slot + copyEpoch 3→4 with the slot-pin
re-pins — epoch 4 draws `.07` in the ten-line slots while the touch pin
`.02` SURVIVES (mod5=2); SpokenReaction gate widening; `.fingertip` wiring
for the play follow; the disclosed minimal director early-exit event; the
action-row chips per UX §5.4; O1's apostrophe normalization rides the
contract + catalog together), then dispatch the fresh implementation agent.
