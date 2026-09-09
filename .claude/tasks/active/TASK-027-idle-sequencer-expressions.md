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

READY — contract authored by the orchestration agent; fresh implementation agent dispatched.

## Implementation Notes

(filled by the implementation agent)

## Reviewer Findings

(filled by the review agent / orchestrator disposition)

## Completion Evidence

(filled at close: commit hash, test counts, review verdict, budgets)
