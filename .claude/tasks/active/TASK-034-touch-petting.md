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

READY (gates on TASK-033's commit).

## Implementation Notes

(to be filled by the implementation agent)

## Reviewer Findings

(to be filled by the review agent)

## Completion Evidence

(to be filled at closeout)
