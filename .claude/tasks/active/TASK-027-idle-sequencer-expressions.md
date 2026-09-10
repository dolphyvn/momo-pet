# TASK-027 — Idle sequencer + expression system

## Parent Epic

EPIC-006 — Character Rendering (MomoCharacter), task 3 of 6. Delivery-plan row: "Implement idle sequencer + expression system (04 §3, §5)" — Size L.

## Objective

Make the rig BEHAVE, not just breathe: the deterministic idle event sequencer (04 §5) and the expression system (04 §3 — mood-band expressions §3.2, energy modulation §3.3, bond behavior dials §3.4), rendered through `RigMotionModel` onto the TASK-026 rig. Everything in this task is pure/deterministic given `(idleSeed, timeline, displayState)` — no UIKit/SwiftUI scheduling, no system randomness (04 §9.4). Plus: discharge the four BLOCKING TASK-026 review routings (below) — the composition-order reconciliation MUST land before any ear/tail/head channel emits a non-identity value.

## Context

TASK-026 (commit `d0955e0`) delivered the aliveness plumbing, proven end-to-end on ONE channel (the Content breath):

- `Sources/MomoCharacter/RigPose.swift` — the full pose: `body/head` (`RigGridTransform`: scaleX/scaleY/rotationDegrees/translation), `earLeft/earRight/tail` (`RigRotationScale`), `eyeLeft/eyeRight` (`RigEyePose`: `lidScaleY`, `pupilOffset`, `lowerLid: RigLowerLidPose`), `mouth: RigMouthWeights` (neutral/eat/refuse crossfade weights), `cheekOpacity`, `pawLeft/pawRight`, four props. `.rest` = authored geometry, exactly identity.
- `Sources/MomoCharacter/RigLayerTree.swift` — z-ordered slots (25 full / 11 glance / 3 glyph), per-stage anchor composition, `affineTransform(of:at:)`, per-slot `opacity(_:)`. THE KNOWN ORDER MISMATCH: the normative CG matrix composes S→R→T child-first; the SwiftUI view applies per-stage offset → rotationEffect → scaleEffect, ancestor-first (first-listed modifier applies FIRST/innermost). EXACT-equal only while the body's anchored pure scale is the sole non-identity channel (probe-proven). See the composition doc comments there.
- `Sources/MomoCharacter/RigMotionModel.swift` — `pose(at:displayState:)`, `enabledChannels: RigChannel` gates (RigChannel.swift: 28 named gates + `canonicalOrder` name-for-name pin), `clampedPupilOffset` (§2.4 ≤ 30 % eye radius, applied MODEL-side so every emitted pose satisfies it). Today drives only the Content breath; `displayState` deliberately inert.
- `Sources/MomoCharacter/MomoCurves.swift` — §7.1/§7.2 constants (breath bands by mood, `sleepAmplitudeReduction` 0.30, `springDampingRange` 0.75…0.85, touch/celebration overshoot caps, canonical `breathCycleSeconds` 4.9 / `breathAmplitude` 0.02 + `breathScaleY(at:)`, `overshootFraction`, `isSingleSoftOvershoot`). Law: later tasks CONSUME these values, never restate them. `MomoCurveRulesTests` carries raw-literal teeth.
- `Sources/MomoCharacter/CharacterClock.swift` — the single pause gate (R3): pause zeroes, resume-from-zero, frozen while stopped.
- `Sources/MomoCore/CharacterInterface.swift` — `CharacterDisplayState` (moodBand / energyBand / bondStage / wakefulness / activity / satietyHint / momentRequest). The engine derives it; the character renders the state it is GIVEN (04 §9.3) and never applies engine effects (§9.3).
- `Sources/MomoCore/DaySeed.swift` — `DaySeed.make(petID:localDayKey:epoch:salt: .choreography) -> UInt64`. Seed derivation is ENGINE-owned (§5.1 contract with TASK-006); the character consumes the 64-bit seed as an opaque value. Baseline suite: **627 tests / 65 suites, green, exit 0, zero warnings**.

Normative doc: `docs/design/04-character-system.md` §2.5 (invariants), §3 (all), §5 (all), §7.1–7.2 (timings/curves). The doc sections are authoritative; where this contract restates a value it is convenience only.

## BLOCKING TASK-026 review routings (REVIEW-TASK-026; disposition in the completed TASK-026 task file)

These four are REQUIREMENTS of this task, sequenced before/with the choreography work:

**R1. Composition-order reconciliation (REVIEW-TASK-026 MINOR-1b) — MUST land before any head/ear/tail channel emits non-identity values.** Make the SwiftUI view's rendered transform and `RigLayerTree.affineTransform` provably equal for MULTI-channel poses (e.g. breath + head translation + ear rotation simultaneously). Candidate homes (pick one, justify, document in the composition doc comments; if the choice is structural, record an ADR under `.claude/tasks/decisions/` per existing numbering):
   1. One composed transform per slot — the view applies `RigLayerTree.affineTransform` (anchor pre-compensated) once per slot instead of per-stage modifier chains;
   2. Make the normative matrix mirror the view's listing order (T→R→S per stage, ancestor-first) so matrix and chain are the same algorithm;
   3. A one-non-identity-freedom-per-stage constraint, enforced by the motion model, under which the two orders are algebraically equal.
   Proof is NUMERIC (the TASK-026 settlement rule): point-mapping probes/matrix tests comparing the two compositions digit-for-digit at sampled times across seeded event logs — never re-derived SwiftUI semantics from memory. The known trap: SwiftUI modifiers apply to the content in LISTING ORDER — first-listed applies FIRST (innermost).

**R2. `isSingleSoftOvershoot` tolerance (MINOR-2).** The predicate counts EVERY target crossing; an underdamped in-band spring (ζ = 0.75…0.85) crosses at every sign change of its decaying sinusoid, so the predicate rejects every legal §7.2 spring (ζ = 0.75 ⇒ +2.84 % then −0.081 %, analytically certain even where a 2 s probe window shows one crossing). Fix by tolerance-filtering (re-crossings whose excursion is below a documented "soft" threshold — as a fraction of the approach — count as settling, not bounce) or by restating the predicate's intent; EITHER WAY pin both sides: a ζ = 0.75 spring sampled curve PASSES; a genuine bouncing-ball curve (two comparable-magnitude excursions) FAILS. The tolerance constant lives beside the other §7.2 constants, doc-cited, raw-literal pinned.

**R3. Settle/sleep ease-in constant (MINOR-3).** §7.2's "Settle / sleep: ease-in (gravity-like), decelerating into stillness" has NO constant in `MomoCurves`. Add the constant (+ a small executable ease-in helper if the choreography needs one), doc-cited, raw-literal pinned. (The settle/sleep TRANSITIONS themselves are TASK-028 state choreography; this task lands the curve so the vocabulary exists and the sequencing can already reference it.)

**R4. Ear/tail clamp constants + enforcement homes (REVIEW item 8b).** §3.1: ear rotation −25° (droop) … +25° (perk). The tail's ±10° bound (REVIEW-TASK-026 8b) needs a named constant + home. Enforce MODEL-side like `clampedPupilOffset` (a channel-value law: every emitted pose satisfies the bounds, regardless of what an event requests), constants doc-cited, raw-literal pinned, tests prove both the clamping and that idle variants never request past them unclamped.

## Requirements

1. **Deterministic idle sequencer (04 §5.1–5.2).** A PURE function: given `(idleSeed: UInt64, displayState, timeline window)` it yields the idle event schedule (the full event log over the window; same inputs ⇒ identical log). Repo-owned deterministic RNG seeded from `idleSeed` (documented algorithm, e.g. SplitMix64/xoshiro-style, pinned against known vectors; NO system randomness — 04 §9.4). Schedulers per §5.2 exactly:
   - **Blink:** interval N(6 s, σ 2 s) clamped [2.5, 12] (deterministic normal derivation, documented, e.g. Box–Muller from the seeded uniform stream); 12 % double-blink; interval ×1.4 when Drowsy; NO blinks asleep; Wistful blink durations ×1.2 (§7.1 blink row). L1.
   - **Look-around:** every 9–21 s; gaze target from the 5-point set {left, right, up-toward-user, at-user, eyes-close moment}; hold 1.5–4 s; Joyful raises at-user probability ×1.4. L1.
   - **Micro-motion / idle variants:** every 14–30 s; one variant drawn from the catalog (Req 3). L1/L2-accent.
   - **Yawn:** Drowsy only, every 45–90 s, 1.4 s (§7.1 yawn row). L3.
   Events carry kind, start time, duration, parameters — enough for the motion model to render them.
2. **Sequencer → pose wiring.** Extend `RigMotionModel` to consume the schedule: `pose(at:displayState:)` (schedule supplied or held — your call, but the pose at time T must remain a pure function of `(seed, displayState, T)` so pause/resume discipline is structural). Render events through the existing rig channels: blink = lid envelope (§7.1: close 140–180 ms + open 100–160 ms) overriding band aperture; gaze = `clampedPupilOffset` targets (§7.1: 220–320 ms out ease-out / 600–900 ms return); idle variants and yawn through body/head/ear/tail/mouth channels per §7.2 curves (ears/tail: damped spring within `springDampingRange`, soft overshoot only; breath stays pure sine). **The view renders whatever pose arrives — the only view change allowed is R1's reconciliation.**
3. **Idle-variant catalog (04 §5.2) as DATA, not code — new variants additive without scheduler changes.** Phase 1 Direction-C set: weight-shift left/right · single-ear twitch · tail flick · slow full-body look-around · cheek-press rest · per-ear curious asymmetry. Representation your call (identifier + weights + parameter ranges), but selection must be seed-deterministic.
4. **Expression system (04 §3) — posture-led, state from the given `CharacterDisplayState` only.**
   - **Mood-band table (§3.2):** map each band to aperture / lower-lid pose (`RigLowerLidPose`: relaxed/upturned/flattened — the O6 routing: define what each case MEANS as rig channel values; see the aperture note below) / ear angles (Joyful perk +8…+25°, Content neutral ±5°, Wistful droop −10…−25°) / tail behavior (slow wag · slow metronome or still · still curled close) / posture (Joyful +3 % tall with eager micro weight-shifts; Content neutral; Wistful −4 % slouch) / breath cycle (§7.1 rows: pick one value per band inside each band, Content = the existing canonical 4.9) / tempo (idle events more frequent Joyful, slower blinks Wistful). **Low (0–19) is reserved — define its mapping (quiet resting: ~60 % aperture, long slow blinks, settled, wrapped, resting slump) for presentation completeness, but Phase 1 mechanics never produce it (PRD floor 25).**
   - **Energy overlays (§3.3):** Energetic ×1.5 idle-variation frequency + slightly faster tempo; Drowsy half-lid baseline (aperture ×0.7) + all scheduler intervals ×1.4 + yawn events + occasional head-nod micro-motion; Exhausted near-sleep resting posture while awake (lying, eyes half-open) with minimal slow movement. **Conflict law (§3.3, normative):** where mood and energy conflict, LOWER energy wins on TEMPO, HIGHER mood wins on FACIAL WARMTH (e.g. Joyful + Exhausted = happy but too tired to move much).
   - **Bond dials (§3.4) as DATA consumed downstream:** reaction-latency table per stage (0.6 / 0.4 / 0.25 / 0.25 s), greeting-quality descriptors, unlocked-variant flags. The ONE bond expression this task RENDERS: Soul Companions' **calm-coexist idle** (rests with eyes half-closed, facing you) — an idle-variant catalog entry gated on `bondStage`. Greeting POSES and latency consumption are TASK-028 (reactions); do not implement them here.
   - **APERTURE↔lidScaleY mapping — the known trap.** §3.1's table speaks aperture "0 (closed) → 1.0 (open)", but the rig channel's true semantics (TASK-026-corrected): `lidScaleY = 1` is the AUTHORED REST (lid already slices ~26 of 112 eye units), SMALLER lifts the lid (more open; 0 = no lid at all), LARGER lowers it (more closed). Define ONE documented conversion (aperture → lidScaleY) in the expression layer; derive the closed value from the generated eye/lid geometry (the lid bottom reaching the eye's lower edge — compute from the constants, pin numerically); §3.2's ~90 %/~70 %/~60 % band apertures and §3.3's ×0.7 Drowsy multiplier all flow through it. Tests pin the conversion and each band's landing values.
   - **Mouth:** the three pre-built poses only (`RigMouthWeights`) — R1 forbids new geometry. If §3.1's "tiny content curve" is not the authored neutral mouth, route the gap as a geometry-owner follow-up note (O2 precedent), never synthesize geometry. Idle default = authored neutral.
   - **INV-5 conservative rule:** idle NEVER modulates `cheekOpacity` — cheeks stay at authored rest; their only sanctioned modulation is L4 celebrations (TASK-028+).
5. **INV-6 everywhere.** The worst visual state is sleeping; no suffering visuals in ANY state. Executable form: an audit test enumerating every `(moodBand, energyBand, wakefulness, bondStage)` combination and asserting each mapped expression stays inside the doc ranges (aperture within the mapped scale, ears within ±25°, posture within +3 %/−5 %, tempo non-frantic) — with Low reading as quiet resting, not distress.
6. **Aliveness floor (04 §5.3).** Breath + blink are the floor: with an empty/absent event schedule the model still renders the band breath (and the floor degrades to calm, never frozen stillness while awake). Blink scheduling is independent of variant scheduling so a catalog failure cannot silence the floor. Test-pinned.
7. **No-distraction discipline (04 §5.3).** At Content/baseline the stage is motionless ~85–90 % of any 30 s window — between events only the breath transform runs. Executable form: from the event log (plus known transition envelopes), non-breath motion occupies ≤ 15 % of sampled 30 s windows across a fixed seed battery. Also §7.4 rule 4's concurrency budget: ambient idle animates ≤ 3 properties concurrently — assert from the schedule that overlapping active events never exceed the budget.
8. **Pause/resume discipline (04 §5.3).** All schedulers are next-event timers; no polling; resume NEVER replays or bursts: events strictly between pause and resume are skipped, the next event is scheduled after the resume point. Structural if Req 2's purity holds — test the resume property explicitly (simulate: consume to T, resume at T + gap, assert no duplicated/pre-gap events and identical continuation to an uninterrupted run from T + gap... note determinism means the uninterrupted run from the same seed is THE reference).
9. **Scope guards (§22):** NO reaction vocabulary / §6 gesture map / CharacterReport / play round / state choreography (TASK-028). NO Reduce Motion mapping (TASK-029 — `enabledChannels` stays its hook). Props stay inert (8c → TASK-028). No engine effects (§9.3). No new rig geometry (R1 — geometry gaps get routed, not synthesized). Zero hex in rig code (R4); token colors untouched.

## Files / Areas Likely Affected

- `Sources/MomoCharacter/` — NEW: deterministic RNG, idle sequencer + event model, idle-variant catalog, expression mapping. MODIFIED: `RigMotionModel.swift` (event/band drivers), `MomoCurves.swift` (R2 tolerance, R3 settle constant, R4 clamps — additions only, existing constants untouched), possibly `RigLayerTree.swift`/`MomoRigView.swift` (R1 reconciliation only), `RigChannel` untouched (canonicalOrder is pinned).
- `Tests/MomoCharacterTests/` — new suites (sequencer determinism/distributions/resume/floor/no-distraction/concurrency; expression mapping/INV-6 audit/bond dials/aperture conversion; R2/R3/R4 pins; R1 equivalence probes). Existing suites must stay green UNCHANGED except where R1 reconciliation legitimately moves a composition probe (justify every such move in the task notes).
- `.claude/tasks/decisions/` — possibly one ADR for the R1 choice.

## Dependencies

TASK-026 (DONE, `d0955e0`); MomoCore interface types (landed). No other open dependencies.

## Constraints

- All agents Jupiter; fresh agent per task (CLAUDE.md §3/§9). Pure-Swift sources only in `Sources/MomoCharacter/` (the package target is platform-neutral; no UIKit/SwiftUI INSIDE the model/sequencer — the view file `MomoRigView.swift` is the sole SwiftUI surface).
- R1–R4 rig rules (transform-only, one creature, single clock pausability, token colors) — unchanged and re-verified by the standing scans.
- Hand-written Swift is outside the art budgets (rig ≤ 300 KB source / room+props ≤ 250 KB / total ≤ 1.5 MB are generated-constant buckets — re-measure and record, expect unchanged).
- Immutability + small-file house style; doc comments cite 04 sections; no unexplained TODO/FIXME (§26); no fake completion (§25).
- Baseline 627/65 green, zero warnings — land green with your additions; every new constant doc-cited and raw-literal pinned where it carries a §-number.

## Acceptance Criteria

1. R1–R4 (blocking routings) all landed: composition equivalence proven numerically for multi-channel poses; `isSingleSoftOvershoot` accepts in-band springs and rejects true bounce; settle ease-in constant pinned; ear/tail clamps constant-pinned and model-enforced.
2. The sequencer is pure and deterministic: same `(idleSeed, displayState, timeline)` ⇒ identical event log, property-tested across a fixed seed battery; resume skips (never replays) pre-gap events and continues identically.
3. All four §5.2 schedulers behave per the doc (intervals, clamps, percentages, multipliers, sleep/Wistful/Joyful/Drowsy modulations) — pinned by tests that would fail on any constant drift.
4. The expression system maps every `(mood, energy, wakefulness, bond)` input through §3.2–3.4 (including the tempo/warmth conflict law, Drowsy overlays, Exhausted posture, Low's reserved mapping, calm-coexist gating) — pinned table tests + the INV-6 audit over the full input cross-product.
5. The aperture↔lidScaleY conversion is defined once, documented, and pinned; every band's landing values flow through it.
6. Aliveness floor, no-distraction (≤ 15 % motion occupancy / 30 s window), and ≤ 3-concurrent-property budget all test-pinned.
7. `swift test` green (627 + new), zero new warnings; hex-free scan green; art budgets re-measured and recorded.
8. Task file updated (Implementation Notes + Handoff); no commit by the implementer (orchestrator commits after independent review).

## Required Tests

Swift Testing (`@Suite`/`@Test`), `Tests/MomoCharacterTests/`, following the existing suites' name-for-name pin style:

1. **Sequencer determinism:** identical-log property over ≥ 100 seeds × several (displayState, window) combinations; purity (no clock/calendar/system-random reads — code inspection + byte-stable logs).
2. **Scheduler distribution pins:** blink mean/σ/clamp over large fixed-seed samples; 12 % double-blink; ×1.4 Drowsy; none asleep; ×1.2 Wistful durations; look-around 9–21 / holds 1.5–4; variants 14–30; yawn 45–90 Drowsy-only; Joyful ×1.4 at-user.
3. **Resume discipline:** no replay/burst; continuation equality vs. uninterrupted reference.
4. **Expression tables:** band mappings (§3.2), energy overlays + conflict law (§3.3), bond dials + calm-coexist gate (§3.4), breath rates from §7.1 rows (consumed, not restated), wakefulness rows (asleep: no blink, −30 % amplitude, closed eyes).
5. **Aperture conversion:** closed-value derived from geometry (pinned numerically); band landings; Drowsy ×0.7 composition.
6. **INV-6 audit:** full input cross-product within doc ranges; Low = quiet resting.
7. **R1 probes:** multi-channel composition equality (view-order vs matrix) at sampled times from seeded logs — digit-for-digit.
8. **R2/R3/R4:** ζ = 0.75 spring passes / bounce fails; settle constant raw-literal; ear ±25°/tail ±10° clamped model-side.
9. **Floor / no-distraction / concurrency** (Reqs 6–7).
10. **Regression:** existing 627 stay green (justified moves only).

## Review Requirements

Mandatory independent adversarial review (CLAUDE.md §10/§33) by a FRESH agent after orchestrator verification: reviewer NOT primed with "implementation is correct"; must independently re-derive §3/§5/§7 values name-for-name, attack determinism (any hidden state? any system-random read? any accumulated-schedule replay path?), re-run the numeric composition probes, attempt INV-6 violations via input cross-products, and bite at least one mutation (verify a named pin fails, then sha256-confirm the restore). Findings → `.claude/tasks/reviews/REVIEW-TASK-027.md` with verdict APPROVED / APPROVED_WITH_MINOR_NOTES / CHANGES_REQUIRED / BLOCKED. Orchestrator personally verifies every finding's diagnosis before disposition.

## Git Requirements

- Branch `feature/EPIC-006-character` (already checked out; TASK-026 lineage @ `7295226`).
- Implementer does NOT commit. Orchestrator makes ONE atomic commit: `feat(character): TASK-027 deterministic idle sequencer + expression system` (task ID mandatory, §12), pushed per §13, hash recorded.

## Status

IN_REVIEW — implementation + fix round 1 complete (REVIEW-TASK-027 disposition items 1–6; ADR-010/011/012 written), suite green (721/72), NOT committed (delta review next, then orchestrator commits per §10/§12).

## Implementation Notes

**Landed.** Five new sources + `MomoCurves`/`RigMotionModel`/`RigLayerTree`/`MomoRigView`/`RigPose` edits + six new test suites + discipline-scanner extension. R1–R4 all landed (details below).

**Authored subranges (all inside §5.2/§7.1 doc bands; §5.3's occupancy budget drove the choices).** Gaze: interval U(10, 21), shift U(0.22, 0.28), return U(0.60, 0.70). Variants: interval U(16, 30); crossfade fades U(0.30, 0.33); spring-family fades fixed at the 0.35 response envelope. Double-blink gap 0.09. Yawn envelope 0.45/0.5/0.45 within the 1.4 s row. Each is doc-cited at its scheduler and pinned by distribution tests. Draw order is documented per scheduler: one `MomoIdleRandom` per substream, seeds = master draws 1–4 (blink/gaze/variant/yawn), fixed per-scheduler draw sequences, log sorted by `(start, kind)`.

**R1 → option 1, ADR-009.** `MomoRigView` now renders one `drawLayer` per slot concatenating `RigLayerTree.affineTransform` — the modifier chain is gone; the normative matrix is the only composition algorithm. Proof in `R1CompositionTests`: point probes vs an independent §2.2 evaluation at a fully-loaded pose (order-sensitivity control included), pixel probes view-verbatim vs y-flipped CGContext (≤ 8 boundary-AA pixels; non-vacuous > 1000 px vs rest), `.rest` → exactly identity at every tier.

**R2/R3/R4.** `MomoCurves` additions only: `softCrossingTolerance` 0.01 (R2 significance filter, ζ-band settling admitted, real bounce still rejected); `settleEaseExponent` 2.0 (R3); `earRotationLimitDegrees` ±25 / `tailRotationLimitDegrees` ±10 (R4), enforced MODEL-side like `clampedPupilOffset`.

**Model bug found and fixed by the render tests:** the four crossfade variants multiplied magnitudes by raw elapsed seconds instead of the envelope shape (8 × 0.6 at t = 0.6). `render` now evaluates `envelopeProgress` for the crossfade family; spring family unchanged.

**Floating-point honesty in the laws (each documented at its assertion):** per-seed pairing for tempo/duration laws (flat concatenation misaligns when states change per-seed event counts — the original failure mode of the drowsy tempo test); start-to-start gaps carry cursor rounding ~ULP(3600) ⇒ ×1.4 tempo pinned within 1e-9; the duration multiplier applies to the drawn close/open components (the authored 0.09 inter-blink gap is deliberately NOT stretched) ⇒ singles-only ×1.2 law within 1e-12 (observed worst 5.6e-17); conversion pins lock the geometry-evaluated op order digit-for-digit, round-trip < 1e-12 (worst 1 ULP).

**Measured distribution pins** (mirrored from an independent Python SplitMix64 implementation validated against `SeededGeneratorTests` before embedding; `/tmp/momo_verify_pins.py`): blink gap mean 6.0387 / σ 1.9262, both clamps hit exactly, doubles 11.75 %; duration mean 0.33453 over all blinks (0.28991 singles-only); gaze at-user 0.2528, Joyful ratio 1.2594 (theory 1.2727); content/energetic variant-count ratio 0.505 (theory 0.5067); calmCoexist 0.1875; headNod 0.13208 (theory 0.8/6.0 — calmCoexist gated out at gettingClose); occupancy (200 seeds × 30 s) mean 0.1102, p95 0.1419, max 0.1700 — 4/200 windows exceed 0.15 (bounded by the ≤ 0.20 max pin; the authored-subrange tradeoff, not a violation — mean and p95 pins carry verified margin).

**Justified existing-test moves (each with an inline TASK-027 comment + equally strict digit-for-digit replacements):** `CharacterClockTests.pausedClockStopsEveryChannel` (pause freezes at the model's t = 0 band pose, no longer literally `.rest`); `RigMotionModelTests.modelAtZeroIsRest` → expression-base pin; breath-isolation and inert-displayState pins inverted to their live TASK-027 equivalents. `R1RenderSpikeTests.swift` (uncommitted scratch harness) was deleted; its pixel-evidence idea was rebuilt properly in `R1CompositionTests`.

**Art budgets re-measured (generated buckets — unchanged, this task adds no geometry):** rig 51,906 / 307,200 B (17 %); room+props 20,647 / 256,000 B (8 %); MomoCharacter sources total 204,789 / 1,572,864 B (13 %). TASK-027 hand-written Swift (outside buckets by constraint): MomoIdleRandom 96 lines, MomoIdleEvents ~180, MomoIdleVariants ~150, MomoExpressions ~420, MomoIdleSequencer ~330, + RigMotionModel growth; six test suites.

### Fix Round 1 (2026-09-10 — REVIEW-TASK-027 disposition items 1–6, executed by a fresh fix agent)

**Item 1 (MAJOR-1) — the composed body scaleY writes UNCLAMPED (ADR-011).** `RigMotionModel`'s `.bodyScale` write no longer wraps in `clampedPostureScaleY`; the write-site comment states the law (posture pre-clamped in the expression layer; §7.1 breath and §5.2 idle events compose multiplicatively, each bounded by its own authored magnitudes). `MomoCurves.postureScaleYRange`'s doc now says the band governs the STATIC posture channel and motion is deliberately not re-clamped into it (§3.1/§7.1/§5.2 + ADR-011); `clampedPostureScaleY`'s doc gains the same pointer. Blast radius verified BEFORE the edit: only the TASK-027-authored `asleepRenders` bound the composed clamp; `MomoExpressionTests`/`MomoCurvesTask027Tests` pin the EXPRESSION-layer clamp (unchanged, still green); `RigMotionModelTests`' inequalities hold unclamped (Low-asleep renders ≈ 0.959 < 1.0). `asleepRenders` rewritten for the unclamped law digit-for-digit: peak/trough `== CGFloat(1.03 × breathScaleY(at: 1.8/5.4, cycle: 7.2, amplitude: 0.022 × (1 − sleepAmplitudeReduction)))`, plus a non-vacuity pin that the peak EXCEEDS the band top (possible only under this law). NEW breath-purity sweep (`breathSinePuritySweep` + `analyticBodyScaleY` helper): 4 moods × 4 energies × 4 wakefulness = 64 rows × 720 samples/cycle, empty schedule; every rendered sample must bitwise-equal `postureScaleY × breathScaleY(at:cycle:amplitude:)` with the asleep reduction ×(1 − 0.30) applied exactly; zero flat samples per row; per-row rendered min/max digit-for-digit equal to analytic; battery-level non-vacuity counters (band-top and band-bottom exits > 0).

**Item 2 (MAJOR-2) — resume discipline pinned (ADR-010, new `MomoIdleResumeTests`, 2 tests).** (a) SteppedClock: pause → wall-advance 120 s ⇒ `elapsed() == 0`; resume ⇒ 0; +3 s ⇒ 3 (real-time replay, no dwell debt). (b) Seed 42 through the full pipeline: the post-resume regenerated log `==` the from-zero log, distinct starts (no multi-event burst), nothing active at the resume instant, and the pose at 20 sampled resumed instants `==` a never-paused run's pose at the same character-timeline t. TASK-026's clock pins untouched and authoritative for the clock.

**Item 3 (MINOR-1) — occupancy restructured into two tiers (ADR-012) — DEVIATION on the cross-state ceiling.** `noDistractionOccupancy` → `contentOccupancyBudget` (200 seeds; mean ≤ 0.15 AND p95 ≤ 0.15, doc-exact per 04 §5.3's Content/baseline scoping; max ≤ 0.20 as an authored stability ceiling; measured 0.1102 / 0.1419 / 0.1700) + `crossStateOccupancyBudget` (7 non-baseline states × 100 seeds; pins mean ≤ 0.20 and per-run max ≤ 0.25, non-vacuous ≥ 0.05). DEVIATION: the disposition's provisional cross-state ceiling (≤ 0.20) was FALSIFIED by the measurement — per-state maxima Joyful 0.2322 (runner-up window 0.2231) / Drowsy and Exhausted both 0.1365 / Content+soulCompanions 0.1700 (worst-state mean Joyful 0.1663); the disposition's cited 0.1700 was the Content battery's max, not a cross-state figure. Pinning 0.20 would have failed the shipped sequencer, so the authored tier is mean ≤ 0.20 / max ≤ 0.25 with the full per-state distribution documented in the test and ADR-012. Known Issues reframed honestly (doc scoping + authored tier; no "not a violation" framing).

**Item 4 (MINOR-2) — RT-7 letter vs substance, recorded (no code change):** the disposition's RT-7 test (probes at seeded-log times) is dominated by the shipped hand-built fully-loaded-pose probes — `R1CompositionTests` evaluates a pose exercising every channel at once, while any single sampled-log instant exercises a subset. One-line note recorded here per the disposition.

**Item 5 (NOTE-3) — mid-fade pin (DEVIATION: dual pins, letter AND purpose).** `weightShiftMidFadeTracksTheEnvelope` pins a crossfade variant against `envelopeProgress`'s smoothstep at the midpoint (t = 0.15 of a 0.3 fade) AND at the quarter point (t = 0.075). The quarter point is added because smoothstep(0.5) = 0.5 = linear(0.5): a midpoint-only pin cannot distinguish smoothstep from a linear-fade regression, while smoothstep(0.25) = 0.15625 can. Type split per `RigPose`: translation compared through the house CGFloat wrap, rotationDegrees (Double) compared plain.

**Item 6 (NOTE-4) — `MomoRigView` header fixed:** "freezes the current pose" → freezes at the t = 0 unaged band pose (the band expression base with every motion channel at rest). The glyph/AOD sentence re-read: "the glyph tier's stillness IS the AOD posture" is an independent claim (glyph renders `.rest`; AOD posture is stillness) and survives the base-claim correction unchanged.

**Item 7 (NOTE-5):** no action (adjudications live in the review file).

**Note for the delta reviewer (pre-existing, untouched — outside sanctioned fix-round edits):** `cheekPressRestRenders` and `alivenessFloor` still wrap in `clampedPostureScaleY`; at Content that wrap is a bitwise no-op (band base 1.0 ⇒ clamp identity), so they are correct-but-stale under ADR-011. Cleaning them is the orchestrator's call.

**Fix-round test ledger:** 716/71 → **721 tests / 72 suites, passed, exit 0** (+2 MomoIdleRenderTests: sweep + mid-fade; +1 net MomoIdleSequencerTests: two occupancy tests replace one; +2 MomoIdleResumeTests: new suite). Zero new compiler warnings (build stderr unchanged: only the pre-existing toolchain `/opt/extra/lib` ld note).

## Reviewer Findings

(filled by the review agent / orchestrator disposition)

## Completion Evidence

- **Full suite (2026-09-10, final tree):** `swift test` → **716 tests / 71 suites, passed** (1.4 s), exit 0. Clean-build warning set unchanged: only the pre-existing toolchain `ld: search path '/opt/extra/lib' not found` — zero NEW warnings. (An earlier 714 count predated the RigDisciplineTests +2; both runs green.)
- **New coverage:** 87 tests in 6 new suites — MomoExpressionTests 16, MomoIdleSequencerTests 21, MomoIdleRenderTests 20, MomoCurvesTask027Tests 14, MomoIdleRandomTests 10, R1CompositionTests 6; RigDisciplineTests extended 11 → 13 (§9.4 system-randomness scanners, fixture + whole-stack).
- **Art budgets re-measured:** rig bucket 51,906 / 307,200 B (17 %); room+props 20,647 / 256,000 B (8 %); MomoCharacter sources 204,789 / 1,572,864 B (13 %). No new geometry — generated buckets byte-identical.
- **Fix round 1 (2026-09-10, final tree):** `swift test` → **721 tests / 72 suites, passed** (1.4 s), exit 0; zero NEW warnings (stderr: only the pre-existing toolchain `/opt/extra/lib` ld note). Delta vs the implementation round: +2 MomoIdleRenderTests, +1 net MomoIdleSequencerTests, +2 MomoIdleResumeTests (new suite).
- **Commit:** none by implementer/fix agent (Git Requirements). Working tree holds exactly the TASK-027 changeset: 9 modified sources/tests + 5 new sources + 6 new test files + ADR-009/010/011/012 + this file.

## Handoff

### Completed

- TASK-027 scope in full: seeded idle sampler, event scheduler (blink/gaze/yawn + four blocking routings R1–R4), variant catalog + schedulers, expression model (mood rows, energy overlays + conflict law, bond dials, aperture conversion), motion-model render, `MomoRigView` single-matrix composition, rig discipline extension, ADR-009.
- All four blocking routings landed: R1 (ADR-009 + R1CompositionTests), R2 (`softCrossingTolerance`), R3 (`settleEaseExponent`), R4 (`ear/tailRotationLimitDegrees`, model-side clamps).
- Fix round 1 (REVIEW-TASK-027 items 1–6): composed body scaleY unclamped per the ADR-011 law (expression layer pre-clamps the posture; motion composes unclamped), breath sine-purity sweep + unclamped asleep pin, `MomoIdleResumeTests` for the ADR-010 zero-on-pause discipline, two-tier occupancy battery + ADR-012, mid-fade smoothstep pin, `MomoRigView` header fix, RT-7 note recorded.
- Non-goals respected: no reactions/§6 gestures (TASK-028), no Reduce Motion (TASK-029), INV-5 held (idle never touches mouth/cheeks beyond the pre-built poses), no new geometry, no hex in rig code, existing `MomoCurves` constants untouched (additions only).

### Files Changed

- **New sources:** `Sources/MomoCharacter/MomoIdleRandom.swift`, `MomoIdleEvents.swift`, `MomoIdleVariants.swift`, `MomoExpressions.swift`, `MomoIdleSequencer.swift`
- **Modified sources:** `RigMotionModel.swift` (envelope-shape fix + clamps + variant/overlay wiring), `RigPose.swift` (display-state expression base), `RigLayerTree.swift`, `MomoRigView.swift` (single composed matrix per slot), `MomoCurves.swift` (additions only), `CharacterClock.swift`
- **New tests:** `MomoIdleRandomTests.swift`, `MomoIdleSequencerTests.swift`, `MomoIdleRenderTests.swift`, `MomoExpressionTests.swift`, `MomoCurvesTask027Tests.swift`, `R1CompositionTests.swift`; fix round added `MomoIdleResumeTests.swift`
- **Modified tests:** `RigDisciplineTests.swift` (13-file set + §9.4 scanner), `RigMotionModelTests.swift`, `CharacterClockTests.swift` (justified moves, documented inline); fix round modified `MomoIdleRenderTests.swift` (asleep pin rewrite per Item 1, sweep + mid-fade additions) and `MomoIdleSequencerTests.swift` (occupancy battery restructure per Item 3) — the only sanctioned existing-test edits of the fix round
- **Fix-round source edits:** `RigMotionModel.swift` (unclamp + law comment), `MomoCurves.swift` (doc clarification only), `MomoRigView.swift` (header comment fix)
- **Docs:** `.claude/tasks/decisions/ADR-009-rig-composition-order.md`, `ADR-010-idle-resume-discipline.md`, `ADR-011-body-scaley-composition-law.md`, `ADR-012-occupancy-budget-tiers.md`; this task file.

### Tests Run

`swift test` (full package, repeatedly during development; final full runs on the finished trees: implementation round 2026-09-10 → 716/71, fix round 2026-09-10 → 721/72). Fix round also ran the filtered battery (`MomoIdleRenderTests|MomoIdleSequencerTests|MomoIdleResumeTests` → 46/46) during development.

### Test Results

Implementation round: **716 / 716 passed across 71 suites.** Fix round 1: **721 / 721 passed across 72 suites**, exit 0. Zero new compiler warnings in both rounds. Every failure encountered during development was resolved by fixing either a real model bug (crossfade variants using raw elapsed) or a test-authoring error (stale/miscomputed pins — each replacement verified against an independent Python SplitMix64 mirror that was itself validated against `SeededGeneratorTests` before use). No existing test weakened without an equally strict digit-for-digit replacement, each documented inline; the fix round's only existing-test edits were the two disposition-sanctioned ones (Item 1's asleep pin rewrite, Item 3's occupancy restructure), and no other existing test broke from the unclamp.

### Known Issues

- Occupancy (reframed per disposition Item 3; ADR-012): 04 §5.3's ~85–90 % motionless floor is doc-scoped to Content/baseline and is pinned doc-exact there — over 200 seeds the measured mean is 0.110 and p95 0.142 against the ≤ 0.15 budget, with a 0.170 measured max under a 0.20 authored stability ceiling. Cross-state occupancy has NO doc number; it is bounded by an AUTHORED tier (mean ≤ 0.20, per-run max ≤ 0.25) measured across 7 non-baseline states — worst-state mean Joyful 0.166, worst single runs Joyful 0.232 and Drowsy 0.223. The disposition's provisional ≤ 0.20 cross-state max was falsified by this measurement and the authored tier documents why (ADR-012).
- Mouth "tiny content curve" (04 §3 note on the Content row) has no geometry in the generated rig — flagged as a geometry-owner follow-up, out of TASK-027's no-new-geometry constraint.
- Pre-existing toolchain ld warning (`/opt/extra/lib`) — not ours, unchanged.

### Decisions Made

- R1 → ADR-009: one composed matrix per slot; modifier chain deleted; proof by point + pixel probes with order-sensitivity and non-vacuity controls.
- Aperture → lidScaleY conversion computed THROUGH the rig geometry (lid bottom between eye-top/eye-bottom landmarks, mapped onto the lid's own scale axis about lidAnchorY); pinned digit-for-digit, inverse round-trip ≤ 1 ULP.
- Draw-order contract: master draws 1–4 → substream seeds (blink/gaze/variant/yawn); per-scheduler draw sequences fixed and documented; log sorted by `(start, kind)`.
- Double-blink multiplier stretches the drawn close/open components, not the authored 0.09 inter-blink gap (documented at the sequencer).
- Fix round: ADR-011 — the §3.1 posture band governs the STATIC posture channel; breath/idle motion composes multiplicatively and unclamped (per-band bitwise sine-purity sweep pins the law). ADR-010 — zero-on-pause IS the resume discipline (04 §5.3's backlog sense); the contract's "continuation from T + gap" clause recorded as an over-translation; replay-from-0 pinned through the pipeline. ADR-012 — two occupancy tiers: Content/baseline doc-exact ≤ 0.15 (mean and p95), cross-state authored mean ≤ 0.20 / max ≤ 0.25 (the provisional ≤ 0.20 max was falsified by measurement; per-state distribution documented).

### Reviewer Status

Independent review RAN (REVIEW-TASK-027, verdict CHANGES_REQUIRED — 2 MAJOR / 2 MINOR / 3 NOTE). Fix round 1 executed the orchestrator disposition (items 1–6 + three ADRs) by a fresh fix agent. Delta review per §11 pending (changes are material); task stays IN_REVIEW until it passes.

### Commit

None (implementer/fix agent does not commit — Git Requirements). Suggested message per contract: `feat(character): TASK-027 deterministic idle sequencer + expression system`.

### Push

None (no commit).

### Recommended Next Step

Orchestrator dispatches a fresh delta reviewer (§11) over the fix-round diff — hardest look suggested at: the RigMotionModel unclamp write site + its blast radius (only the sanctioned asleep pin rewrote; expression-layer clamp pins untouched), the breath sweep's bitwise analytic law and its asleep amplitude term, the occupancy tier change (ADR-012's falsified-provisional-ceiling record), and `MomoIdleResumeTests`' equivalence pins. Then commit and push per §12/§13.

## Orchestrator Disposition — Fix Round 1 (2026-09-10)

REVIEW-TASK-027 verdict: **CHANGES_REQUIRED** (2 MAJOR, 2 MINOR, 3 NOTE). Every finding personally re-verified by the orchestrator before disposition: MAJOR-1 reproduced by an independent numeric probe (flat fractions 49.995 % Joyful / 29.005 % Wistful / 49.995 % Low — matching the reviewer's 50/29/50); MAJOR-2 confirmed against `CharacterClock.swift:17-21` and 04 §5.3's own wording; MINOR-1/NOTE anchors spot-checked in source and doc.

1. **MAJOR-1 → FIX, option (a): the §3.1 posture band governs the STATIC posture channel only.** Remove the product clamp at `RigMotionModel.swift:138` — the composed `bodyScaleY` writes unclamped. Static posture is already pre-clamped in the expression layer (`MomoExpressions` applies `clampedPostureScaleY`), so §3.1's +3 %/−5 % still binds the posture; the breath composes multiplicatively and stays a §7.2 pure sine on EVERY band. Chosen over re-authoring Joyful (would weaken a §3.2 authored row) and over the composed-clamp exception (renders breath half-flat on 3 of 4 bands + sleep). `MomoCurves.swift:53-57`'s comment is clarified (its stated intent — "mood and exhaustion overlays can never compose past it" — never targeted the breath). Record the channel-composition law as **ADR-011**. Required: `MomoIdleRenderTests` asleep peak pin + its comment rewritten for the unclamped law; NEW per-band breath sine-purity sweep tests (zero flat samples per cycle; per-band extremes digit-for-digit, including asleep amplitude law).
2. **MAJOR-2 → ADR + the missing RT-3 test.** Zero-on-pause IS the doc semantics (04 §5.3: "app-hide zeroes the CharacterClock and the entire schedule resumes cleanly on return (no event backlog bursts — timers re-schedule, never replay)" — "never replay" is the BACKLOG sense, which the shipped clock satisfies). The contract's Req 8/AC-2 continuation clause ("identical continuation to an uninterrupted run from T + gap") was an over-translation of the doc; adjudicated in **ADR-010** (resume discipline under the zero-on-pause clock: real-time replay-from-0, no burst, seed unchanged). Add the explicit test: pause → wall-advance → resume ⇒ `elapsed() == 0`; the regenerated log equals the log from 0; no catch-up burst (no multi-event catch-up); pose at resumed t equals a fresh run's pose at the same t.
3. **MINOR-1 → ADR + pin restructure.** 04 §5.3's ~85–90 % motionless floor is scoped "at Content/baseline". Restructure the occupancy pins: Content-scoped windows ≤ 0.15 (doc-exact), cross-state windows ≤ 0.20 as an AUTHORED tier with the measured evidence (mean 0.1102 / p95 0.1419 / max 0.1700 over 200 × 30 s). Record the two-tier reading in **ADR-012**. Reframe this file's Known Issues occupancy entry honestly (no "not a violation" framing; cite the doc scoping + the authored tier).
4. **MINOR-2 → one-line task-file note** (RT-7 letter vs substance: hand-built loaded pose dominates any sampled-time probe; recorded, no code change).
5. **NOTE-3 → add one mid-fade crossfade pin** (a crossfade variant sampled mid-fade against `envelopeProgress`'s smoothstep, e.g. half of the fade-in).
6. **NOTE-4 → fix the `MomoRigView` header comment** ("freezes the current pose" → freezes at the t = 0 unaged band pose) and re-read the AOD/glyph-tier sentence built on it.
7. **NOTE-5 → no action** (adjudications recorded in the review file).

ADR numbering: **ADR-010** resume discipline, **ADR-011** body-scaleY composition law, **ADR-012** occupancy budget. (The informal standalone-watch-packaging ADR reservation renumbers to ADR-013 — status.md housekeeping.) Fixes executed by a fresh agent; delta review after (§11 — changes are material); full suite green before commit (§19); no commit by the fix agent.

**Delta review outcome (2026-09-10):** `REVIEW-TASK-027-FIX1.md` — **APPROVED_WITH_MINOR_NOTES** (0 CRITICAL / 0 MAJOR / 1 MINOR / 2 NOTE). All six disposition items independently verified faithful and binding; 4 mutation bites with kills confirmed (3 sha256-proven, 1 disclosed exact-reverse protocol); the fixer's two deviations were both vindicated by bites (a single midpoint fade pin cannot catch linear-fade; a single ≤ 0.15-max battery fails on shipped code at 0.1700). The MINOR — a mis-attributed 0.2231 citation — was personally re-measured by the orchestrator before correction (probe: content/drowsy and content/exhausted both max 0.1365, stable at 100 and 1000 seeds; 0.2231 is joyful/energetic's runner-up window) and fixed in the test comment, ADR-012, and this file. NOTE-1 (ADR-012 overstated the non-vacuity guard as per-state rather than battery-mean) corrected in the same pass. NOTE-2 (two stale no-op `clampedPostureScaleY` wraps in `MomoIdleRenderTests`) deliberately left — harmless, batched into later housekeeping per both reviewers. Open questions adjudicated: keep the ≤ 0.25 cross-state tier (three independent lines of evidence); do not tighten authored subranges. Orchestrator disposition: commit.
