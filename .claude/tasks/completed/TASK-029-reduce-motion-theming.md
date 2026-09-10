# TASK-029 — Reduce Motion mapping + token-driven theming (04 §7.3, §8.4)

## Parent Epic

EPIC-006 — Character Rendering (`.claude/tasks/epics/EPIC-006-character-rendering.md`, task 5/6).

## Objective

Make the §7.3 Reduce Motion (D16 — **binding**) mapping table executable over the TASK-025–028 character surface, and complete the theming half of 04 §8.4 as an AUDIT + EVIDENCE pass (the token seam itself is already landed — see Context). Reduce Motion is **render-only**: it changes what the character's motion LOOKS like (static poses, end-pose swaps, milestone stills, short crossfades) and NEVER changes what the ENGINE observes (the `CharacterReport` stream, pacing, round completion are identical under RM).

## Context

**Current state (verified by the orchestrator 2026-09-10):**

- **§7.3 is entirely unimplemented**: `grep -rn "reduceMotion" Sources/ Tests/` → zero hits. Every animation surface runs full choreography unconditionally.
- **The theming half is already substantially landed** and must NOT be re-implemented: every `RigLayerTree` slot carries a `MomoColorToken` + its verbatim §8.4 slot name and is filled via `slot.token.resolve(colorScheme)` (`MomoRigView.rigCanvas`, `RigLayerTree.swift:39-62`); the 8 §8.4 character slots live in `MomoCharacterPalette.swift` (light/dark pairs, compile-enforced); hex is confined to the 2 palette files under the standing `TokenPurityTests` + `RigDisciplineTests` scans (R4). TASK-029's theming work = close any residual gaps the audit finds + pin the audit + deliver the §3.5 grayscale evidence.
- **§3.5 grayscale legibility** is a standing REVIEW OBLIGATION (04 :248): every §3.2–3.3 expression state must remain distinguishable in pure grayscale; the delivery plan requires "grayscale preview checks recorded".
- **Architecture the RM mapping must respect** (all frozen laws from TASK-026–028):
  - ALL motion is already a pure function of time: `RigMotionModel.pose(at:displayState:reactionMotion:)` composes band pose + idle channels + the TASK-028 reaction overlay through `RigChannel` gates; the overlay comes from the pure fold `MomoReactionDirector` (`MomoDirectorState.overlay(at:)`).
  - **The fold is load-bearing for engine semantics**: reaction/handshake/moment REPORT instants resolve at folds past completion instants, handshake choreography durations pace `settleFinished`/`wakeFinished`/`playRoundFinished`, and the play pacer resolves cease evidence. **Under RM the fold and clock must keep running** — collapsing rendered motion must never delay or drop a report (FR-7 AC-1/2 unaffected is the doc's own letter, §7.3 play row).
  - `MomoRigView` already maps SwiftUI environment → pure parameters (`@Environment(\.scenePhase)` → the clock's one call; `@Environment(\.colorScheme)` → token resolution). RM rides the same pattern.
  - `MomoReactionDirector.swift` is at **792/800 lines** — RM additions must live in NEW files, not the director.

**Product lens:** RM here is an accessibility contract, not a low-power mode — static poses still carry the state's meaning (§7.3's closing law: "Reduce Motion never removes information").

## Requirements

**R1 — The RM policy is an injected, pure, render-only flag.**
- Public shape: `reduceMotion: Bool` accepted by `MomoRigView` (the view may read `@Environment(\.accessibilityReduceMotion)` as its DEFAULT source — the `scenePhase` precedent — but every PURE layer consumes the injected `Bool`; no `UIAccessibility`/ambient accessibility read anywhere outside the view's environment mapping).
- Default `false` is an exact no-op: with the flag off, every existing test pin holds byte-equivalently and rendered trajectories are unchanged.
- The pure layers (motion model, overlay sampling, sequencer consumers) must remain deterministic functions of `(inputs, reduceMotion)` — twin-equal under same flag, and the flag is the ONLY new freedom.

**R2 — Idle loop row (§7.3 :459):** under RM, the rendered idle surface is the **static pose per state** — breath sine off, L1 idle schedulers (blink, gaze wander, variants, idle yawn) contribute NOTHING to the rendered pose; every rendered frame of a quiescent character equals the band/state's static base pose. (Whether the sequencer is bypassed or its output masked is an implementation freedom; the OBSERVABLE law is the static pose at every `t`.)

**R3 — Blink row (:460):** eyes hold the band's **natural aperture** under RM at every instant — the blink substream never displaces aperture. (Note the natural-aperture definition must come from the existing expression layer's band base — no new aperture constant.)

**R4 — Look-around / eye-follow row (:461):** idle gaze wander is suppressed; the replacement is a **single static "looks toward you" glance on touch, released on touch end**. Map this onto the EXISTING surfaces: the glance may reuse the TASK-028 glance-up's gaze posture (static, non-animated) or the expression layer's gaze channel held at the touch; "released on touch end" means the gaze returns to the static pose at the touch boundary. **Scope note (record, do not implement):** §2.4's continuous pupil-follow is EPIC-007 touch wiring and does not exist yet — its RM behavior rides that epic (record the routing in Implementation Notes; do not build §2.4 here).

**R5 — State changes row (:462):** band/state changes render as a crossfade between static poses, duration **within the doc band 0.15–0.20 s** (or instant) — AUTHOR one value in band (suggest 0.15, the doc band's floor, calm-by-default), pin the digit, cite "04 §7.3 state changes row". A state change under RM never animates posture through intermediate motion — the previous static pose crossfades to the new static pose.

**R6 — Touch reactions row (:463): each rendered reaction run becomes an END-POSE SWAP with a 150 ms crossfade — "the reaction's final pose carries its meaning".**
- For each of the 21 keys: the RM render is a crossfade (150 ms — this row's digit is exact, unlike R5's band) from the pre-arrival rendered pose to the run's **end pose**, then holds that end pose until the slot resolves (its normal end / supersede / hide), then the normal exit applies.
- **End-pose extraction is director-owned**: the director's slot model already resolves each run's end instant (incl. press lost-boundary resolution at `start + 5.0` and release ends from `pressReleaseSeconds`); the RM end pose = the choreography's channel values evaluated AT the resolved end. Pin per-key that the RM hold pose equals the full choreography's pose at the slot end (the "carries its meaning" law, executable per key).
- The director's slot machinery (coalescer, queue, supersede, hide epochs, exactly-once reports) runs UNCHANGED under RM — only the motion a slot RENDERS is transformed.
- Press-shaped runs while the touch is still down: hold the press-down end pose (the hold keyframe); on `touchEnded`/lost-boundary resolution, crossfade to the release end pose. (The choreography's existing keyframes are the source — no new authored poses required.)

**R7 — Celebrations / sparkles row (:464): a moment renders as its STATIC MOMENT POSE + haptic; no motion.**
- The moment's rendered motion is its expressive key pose held statically for the moment's duration (AUTHORED: the settled post-overshoot pose of the existing moment choreography is the default; any deviation disclosed). No bounce, no sparkle animation under RM.
- **Haptic routing (scope control §22):** the haptic itself is the EPIC-007 presentation seam (the engine's haptic channel is nil by design since TASK-016) — the character module's obligation is that the `momentRequest`/moment surface still fires so the UI channel can react. Record the routing; do not build haptics.

**R8 — Waking / settling row (:465): a handshake renders as a single static pose of the END state.**
- Settle: static sleeping end pose (no yawn/lie-down choreography visible); `settleFinished` still lands at the SAME instant (the fold still runs the 3.0 s handshake for pacing/reports — see Context). Wake: static waking end pose, `wakeFinished` unchanged. Play invite/payoff keyframe stills follow R9.
- The information law bites here: the static end poses must be the states' own static poses (asleep ≠ content) so the state change remains legible (R11).

**R9 — Playing row (:466): under RM, play renders a STATIC POSE SEQUENCE at round milestones (start pose, mid pose, end pose)** — mapped from the pacer's existing phase structure (invite ≈ start, follow ≈ mid, payoff ≈ end; exact mapping authored + disclosed). **"The round still completes for engine purposes (FR-7 AC-1/2 unaffected)"** — `playRoundFinished` / cease resolution / `handshakeCancelled(.play)` behave identically; milestone stills swap at phase boundaries (crossfade per R5's authored value or instant — pick one, disclose).

**R10 — Coherence with the TASK-028 laws under RM.**
- The §4.1 coherence rules continue to govern WHAT renders (L1/L2/L3 precedence, coalescing, queue, glance-up-on-eating, hide/show epochs) — RM changes HOW a rendered run moves, never WHICH run renders. An RM mode where two reactions render simultaneously or a queue absorbs differently is a defect.
- Pause/hide orthogonality: hide still zeroes the clock and still cancels/disciplines slots exactly as pinned; RM neither substitutes for pause nor interacts with it.

**R11 — RM never removes information (§7.3 :468): the static pose set is distinguishable.**
- The static poses the RM mode renders — the 7 mood-band poses (§3.2), the energy overlays (§3.3), and the distinct end-state poses RM introduces (asleep/settle end, waking end, play milestones, reaction end poses) — must remain pairwise distinguishable (aperture/ear/posture differ). Pin a distinguishability property over the set (geometry differs — the pin is over POSE VALUES, not pixels).

**R12 — Grayscale legibility evidence (§3.5 :248, delivery-plan "checks recorded").**
- Produce committed, deterministic grayscale evidence: rasters of the §3.2–3.3 expression states (and the RM static end poses) rendered with hue removed — extend the TASK-026 evidence-harness pattern (`render_rig_evidence.swift` or a sibling script; PNGs committed under the established evidence location).
- Pair the evidence with a programmatic check: since poses are pure geometry, the honest check is that each state's pose-defining channels (aperture/ear angle/posture/lid) differ pairwise in GRAYSCALE-equivalent terms (geometry, not color) — a numeric test over the pose set, with the PNG evidence as the human-reviewable record. Do NOT fake a perceptual claim the test cannot carry; disclose exactly what the numeric check proves.

**R13 — Theming audit (R4 / §8.4 :518) — verify and pin, do not re-implement.**
- Audit that EVERY rendered surface (rig slots, props, room) resolves through §8.4 slots / the established palette — no hex outside the 2 palette files (standing scans must stay green and proven non-vacuous), both color schemes resolve, `momo.ear.inner`'s known-unused status stays documented (TASK-026 disposition).
- Pin the audit: the slot-name ↔ token mapping is complete over the enumeration (every slot in `RigLayerTree` cites its verbatim §8.4 name — extend the existing pin if any gap shows). Record the audit result in Implementation Notes; any REAL gap found is fixed here (small, disclosed); any gap needing palette DESIGN changes routes to the owner (§36 — palette values are owner-domain).

**R14 — Determinism + discipline invariants (standing, all green at close).**
- Twin equality under RM for identical (events, seed, flag) streams; divergence observability when the flag differs (the RM flag IS observable in rendered motion — that difference is the point — but never in reports; see R15).
- No `Date()`/`UUID()`/`Timer`/ambient accessibility reads in package sources (discipline scanners extended if needed); no `default:` over reaction keys; every file ≤ 800 lines; MomoCore/MomoKit 0-byte diff.

**R15 — The RM-render-only twin law (the task's headline property): for ANY event stream, the `CharacterReport` sequence (kinds, payloads, instants) is IDENTICAL with `reduceMotion == true` and `reduceMotion == false`.**
- Adversarially: replay the TASK-028 test storms (coalescer storms, hold sweeps, hide/show matrix, pacer adversarial streams) under BOTH flag values and assert stream equality. A report that shifts, duplicates, or drops under RM is a defect regardless of how the motion looks.

## Files / Areas Likely Affected

- NEW (expected): `Sources/MomoCharacter/MomoReduceMotion.swift` (policy + the §7.3 mapping constants with authority labels), an RM motion transformation on the overlay/pose seam, RM evidence harness (`Tools/character-pipeline/` sibling or `Tests/` helper + committed PNGs).
- MODIFIED (expected, small): `MomoRigView.swift` (flag parameter + environment default), `RigMotionModel.swift` (the pose seam gains the RM path — keep the existing write-path discipline R-A), the reaction overlay application seam (`MomoReactionMotion`/`MomoReactionOverlay` may gain the end-pose/crossfade motion shapes), `RigDisciplineTests.swift` (scan list + new pins).
- Tests: new suite(s) under `Tests/MomoCharacterTests/` (mapping-table pins, R15 twin property, distinguishability, end-pose extraction, grayscale numeric check).
- **DO NOT TOUCH**: `MomoReactionDirector.swift` beyond what a thin seam requires (792/800 — additions belong in new files); `Sources/MomoCore/**`, `Sources/MomoKit/**` (0-byte diff enforced); generated `MomoRig+*.swift` constants; the palette VALUES (owner-domain).

## Dependencies

- TASK-028 (DONE, `cc98b06`) — the overlay/director surface RM maps. TASK-025–027 surfaces non-regressed.
- Standing routings into this task: NONE blocking (TASK-028's FIX1-NOTE-1 → EPIC-007 touch wiring; NOTE-5/NOTE-6 → doc-clarification backlog; O2/O4 → geometry owners).

## Constraints

- Frozen modules: `git diff --stat Sources/MomoCore Sources/MomoKit` must be EMPTY at every checkpoint.
- Determinism: no ambient time/randomness/accessibility reads in package code outside the view's environment mapping; the RM flag is injected into every pure surface.
- The director stays ≤ 800 lines; every file ≤ 800 lines; no new external dependencies; art Path-constant bucket unchanged (no geometry edits).
- §12/§22 scope discipline: this task does NOT build §2.4 continuous eye-follow, haptics, EPIC-007 app wiring, or palette redesigns — record them as routings.
- Watch surfaces: the glyph tier is already static (TASK-026) — RM must leave glyph-tier rendering byte-identical (pin it); glance-tier RM behavior follows the same mapping (pose-level, disclosed if the tier masks channels RM would otherwise move).

## Acceptance Criteria

1. Every §7.3 row (idle, blink, look-around, state changes, touch reactions, celebrations, waking/settling, playing) is executable and digit-pinned (R2–R9), with authored choices in doc bands disclosed with authority labels.
2. R15's RM-render-only twin law holds over adversarial streams (reports identical under both flag values).
3. RM never removes information: static-pose distinguishability pinned (R11); grayscale evidence recorded (R12).
4. Theming audit complete and pinned: rig reads only token slots, zero hex outside the palette files, both schemes resolve (R13).
5. Default flag = exact no-op (R1); all TASK-025–028 pins green untouched; `swift test` fully green with the new suites; zero new warnings.
6. Scope discipline held: §2.4/haptics/app-wiring/palette routes recorded, not built.

## Required Tests

- §7.3 mapping-table suite: one test per row, digit-pinned (crossfade 150 ms reaction digit; 0.15–0.20 state-change band; natural aperture; static idle pose equality at multiple `t`; handshake static end poses; play milestone sequence).
- R15 twin suite: report-stream equality RM-on/off over the TASK-028 adversarial stream corpus (coalescer storm, hold sweep 0.1–5.0 s, hide/show matrix, pacer streams, queue formation/clearing) + at least one whole-trajectory motion twin PER flag value.
- End-pose extraction: per-key (21) RM hold pose == choreography end pose; press hold/release behavior across the boundary.
- Non-vacuity: the RM pins FAIL under a mutation that restores full motion under the flag (sanctioned mutation bite for the review; sha256-proven restore).
- Distinguishability + grayscale numeric check (R11/R12).
- RM-off no-op: existing suites green byte-equivalently (baseline 789/79).
- Discipline scans extended where the new sources require it (ambient reads, exhaustiveness, ≤ 800 lines).

## Review Requirements

Fresh adversarial reviewer per CLAUDE.md §10/§33: re-derive the §7.3 table from 04 BEFORE reading the implementation; verify the R15 law independently with its OWN streams; sanctioned mutation bites; the orchestrator personally verifies every finding's diagnosis before disposition (standing rule). Review record: `.claude/tasks/reviews/REVIEW-TASK-029.md`.

## Git Requirements

- Branch `feature/EPIC-006-character`. No commit by the implementer. One atomic commit after review approval: `feat(character): TASK-029 Reduce Motion mapping + token theming audit`.

## Status

DONE 2026-09-10 — commit `9a46641` (pushed `34c2e04..9a46641` to `origin/feature/EPIC-006-character`). REVIEW-TASK-029 APPROVED_WITH_MINOR_NOTES; all 8 dispositions applied (fresh fix agent) and orchestrator-verified (incl. a bite on the new overwrite pin); §19 gate green at 824/82.

## Implementation Notes

### Architecture (the north star, held)

ALL RM logic lives in one new file, `Sources/MomoCharacter/MomoReduceMotion.swift` (515 lines); the director is untouched (`git diff` on `MomoReactionDirector.swift` is EMPTY; still 792/800). The fold and clock keep running under RM — they pace the reports — and RM only transforms rendered motion, at the overlay/pose seam:

- `MomoReduceMotion` — the §7.3 constants enum, every digit with its authority label: `reactionCrossfadeSeconds = 0.15` (exact row digit), `stateCrossfadeSeconds = 0.15` (AUTHORED = band floor; cite "04 §7.3 state changes row", band 0.15–0.20), play/glance/press/greeting key instants (all taken from the existing choreographies — no new authored poses).
- `MomoReduceMotionTransition` — the R5 state-change crossfade value.
- `MomoReduceMotionStateTracker` — folds the SAME `.displayState` events the director consumes into 0.15 s crossfade windows (rapid changes overwrite; non-changes open nothing); never writes back into the director.
- `MomoReactionMotion.lerped(to:amount:)` — guarded endpoints (p≤0 returns `self` EXACTLY, p≥1 returns `other` EXACTLY — the exact-equality pins rest on this); `RigPose.blend(_:amount:)` steps the discrete `lowerLid` slot at 0.5.
- `MomoDirectorState.reduceMotionOverlay(at:)` (in the new file, as an extension) — mirrors `overlay(at:)`'s layer STRUCTURE exactly (§4.1 still governs WHAT renders; L1/L2/L3 precedence, coalescing, supersede, hide epochs all unchanged), replacing each layer's motion with its static reading: L1 press unchanged; L2 fading/incoming at the 0.15 digit; L3 slots via `reduceMotionSlotMotion` (`identity.lerped(to: holdPose, p_in).lerped(to: endPose, p_out)`; supersede fades unchanged); moments as static key-pose holds.
- `RigMotionModel` RM path (default `reduceMotion: false` = exact no-op): breath amplitude 0, blink/gaze-wander/variant/yawn schedule contributions contribute nothing, `staticPoseTransition` applied.
- `MomoRigView`: new defaulted params `reduceMotion: Bool?` (nil → `@Environment(\.accessibilityReduceMotion)` — the ONE ambient read, view-scoped and pinned) and `staticPoseTransition:`; `reactionMotion` closure is now `(Double, Bool) -> MomoReactionMotion` (the resolved flag handed to the overlay closure). Defaulted — source-compatible; every TASK-025–028 suite green unmodified.

### Per-row pins (suites: MomoReduceMotionMappingTests 17, MomoReduceMotionTwinTests 7, MomoReduceMotionEndPoseTests 9; +2 in RigDisciplineTests)

- **R2/R3**: static pose t-invariant at every sampled t over all four mood bands (body scaleY == posture base, lids == expression aperture, pupils zero, ears == clamped expression, tail 0); a literal blink event closes the eye in full motion and does NOTHING under RM. Natural aperture = the expression layer's band base (no new constant).
- **R4**: idle gaze-wander suppressed (pupils pinned zero under an up-toward-user event); the replacement static touch glance is the EXISTING L1 press feedback, held while down, released at `touchEnded` — flag-INVARIANT by design (pinned). §2.4 continuous pupil-follow → **EPIC-007** (recorded, not built).
- **R5**: tracker windows pinned before/at/inside/after 5.0…5.15; crossfade endpoints exact (content static → joyful static); posture never animates through intermediate motion (ears monotone RISING between the two statics' values, pinned); asleep lands closed.
- **R6**: per-key over the 15 non-press L3 keys (the 4 routed keys render as the L2 handshake/play/eating rows): RM render at the resolved end == `MomoReactionChoreography.motion` AT the director-resolved end, computed by the TEST through the same dispatch (drift fails); settled tail equality; per-key non-vacuity (full motion diverges somewhere in every run). Press: hold keyframe (head 0.8 s / belly 0.45 s) stands while down; release crossfades to the release end pose; **short press renders the pose its hold EARNED** (`holdElapsed = min(keyInstant, holdSeconds)` — continuity across the release boundary pinned within 0.02 aperture / 0.5° / `~=` pupils); lost-boundary resolution (5.0 s) follows the same law; abbreviation and glance-up routing unchanged (both pinned).
- **R7**: quest/celebration render their settled post-overshoot key poses, held, at window edges; **deviation disclosed**: greetings hold from each kind's own expressive key instant (`0.88/0.2/0.875/0.7` s — `MomoReduceMotion.greetingKeyInstant`; welcomeBack/missedYou are PEAK instants — perk mid-attack / bounce mid-decay — NOT settled ones), not a duration-long single hold; haptics → **EPIC-007 presentation seam** (recorded; moment surface still fires — the twin corpus folds momentRequest events identically).
- **R8**: settle renders the literal end static (posture 0.94, blanket 3°/−14) from the crossfade on; `settleFinished`/`wakeFinished` land at the SAME instants (3.0/2.0 s folds unchanged — report pins). **Disclosure**: waking renders the awake static itself — the end state of waking IS awake, so its "static end pose" is the band static.
- **R9**: play milestone stills (invite ears 10/tail 6 → follow → payoff cheek 0.85) swap with 0.15 s crossfades at the pacer's phase boundaries (invite at start; follow resolved at the pacer's cease — 12.0 baseline / 8.0 drowsy — payoff end +4.0); round completes identically (`playRoundFinished` at 19.4 / 15.4 pinned); drowsy round's yawn suppressed (aperture pinned at 1 mid-round).
- **R10**: overlay layer structure == full overlay's (same slots, same visibility); hide/show epochs untouched (twin corpus matrix).
- **R11**: the RM static set (4 mood + 3 energy + asleep) pairwise distinct over pose values EXCEPT the one disclosed collision: **Content+Energetic == Content+Relaxed exactly** — Energetic's only rendered deltas are its breath cycle (×0.96) and scheduler intervals, both RM-masked; full-motion divergence is pinned over seed-5 schedules, proving the collision is RM-only. **Expression-design gap → owner (§36)**; a future Energetic static accent fixes it without touching this transform. Expressed end motions pairwise distinct.
- **R12**: `Tools/character-pipeline/render_reduce_motion_evidence.swift` (320 lines; rerunnable, header recipe as in TASK-026's harness) rendered **25 committed PNGs** (`docs/evidence/character/rm-*.png`): 8 statics (4 mood + 3 energy + asleep) + 8 eye zooms + 9 end poses (6 expressed one-shots, glance-up plateau, press-hold keyframe, settle end), tones = `resolve(.light)` collapsed to BT.709 luminance (no hand-picked grays — derived, R4-clean). **Byte-identical across two runs (sha256-proven)**. The honest numeric check is the geometry-channel pairwise law in `MomoReduceMotionEndPoseTests`; the script prints a channel digest and explicitly disclaims any perceptual/contrast claim.
- **R13**: audit clean — every `RigLayerTree` slot cites its verbatim §8.4 slot name with its token (standing pins green, 19/19 incl. non-vacuity both directions); hex/RGB literals exist ONLY in the two palette files (+ the token TYPE's UInt decoder in `MomoColorToken.swift`, not a color literal); both schemes resolve; **`momo.ear.inner`'s unused status stands documented** (TASK-026 completed record: no inner-ear geometry constant exists, the token has nothing to paint; re-verified this session — zero `RigLayerTree` consumers).
- **R14/R15**: see twin suite below; discipline scans extended with the environment-scoping pin and the **glyph-tier byte-identity pin** (the AOD branch renders the constant `.rest` — no clock, no model, no flag input; structural wire check + transform purity + non-vacuity). Glance tier rides the SAME pose seam (LOD masks parts, never adds motion) — nothing further to pin, disclosed here.

### R15 twin suite — honest scoping

`apply(_:)` takes NO flag — the fold cannot fork on RM by construction (plus the environment-scoping pin: the flag enters the module ONLY through the view). Behaviorally pinned over 11 corpus streams (TASK-028's verbatim adversarial storm, coalescer storm, queue churn, hide/show matrix, 3 pacer streams, press-only, hold sweep 0.1–5.5): (1) fold twins — whole-state equality incl. report logs, per stream and per flag value's own determinism; (2) flag visibility probed on MID-FLIGHT prefix snapshots (the final state forgets completed layers — the director prunes them with their reports; probes sample each event's wake, which is what a live session renders), every `mustDiffer` stream actually diverges under RM; (3) tracker twins prefix-by-prefix. The press-only stream pins the R4 flag-INVARIANCE (its one legitimate non-divergence).

### Disclosures register (for the reviewer's checklist)

1. L1 press feedback unchanged (flag-invariant) — R4's letter; pinned.
2. Waking renders the awake static — R8's letter; end state IS awake.
3. Greetings hold from per-kind expressive key instants (welcomeBack/missedYou are peak instants, not settled ones), not full-duration — R7 deviation, values from the existing choreographies.
4. Nine identity-ending one-shots render NOTHING under RM — the band static throughout the slot (no crossfade, no settle-back motion; R6's letter taken literally — "the choreography's channel values AT the resolved end" IS the band static for these keys). Combined with Disclosure 5, 11 of 15 non-press keys have no visible touch acknowledgment under RM; the acknowledgment currently rides the haptic/presentation seams (EPIC-007), and an authored acknowledge-static is an OWNER decision explicitly not to be implemented opportunistically (§24).
5. decline/politelyFull end at explicitly-NEUTRAL values (structurally non-identity, rendered end == band static) — the choreography's own authored decay, NOT a transform choice; disclosed in the R12 digest + test comments.
6. Energetic==Relaxed static collision — owner routing (expression design).
7. Play stills swap via 0.15 s crossfades (R5's authored value applied to R9's disclosed choice).
8. Render-side state crossfade runs at 0.15 while the director's own L2 fold crossfade stays 0.35 — the fold paces reports and is untouched; only the render re-times.
9. View API: `reactionMotion` closure now `(Double, Bool) -> MomoReactionMotion`; `reduceMotion`/`staticPoseTransition` init params defaulted (source-compatible).
10. Short-press refinement: `holdElapsed = min(keyInstant, holdSeconds)` so a released-early press renders the pose it earned (continuity pinned across the boundary).
11. `approxEqual` (1e-9, channel-wise) used ONLY for the belly-press hold pins: the RM render re-derives elapsed through the slot clock (`(start + key) − start`), and the cyclical rock's sine carries ~1e-15 ulp dust at zero crossings. End-pose pins remain EXACT (identical `end − start` arithmetic on both sides).
12. Twin probes sample mid-flight prefixes (final state prunes completed layers — a director-design fact, not a defect).
13. The tracker's two-changes-in-one-window overwrite snaps the blend to the intermediate static at the overwrite instant (a visible discontinuity — measured > 5° ear-channel jump — defensible under §7.3's "150–200 ms crossfade (or instant)"; pinned in the mapping suite, "R5: a second state change inside the window overwrites — the blend snaps to the intermediate static").
14. The glance-up's RM render holds its plateau posture to the slot's end, where the slot is pruned — a hard exit cut the full motion does not have (its bump has decayed to ≈ identity by the end); consistent with RM's static-swap philosophy (expressed one-shots cut identically under both flags), now disclosed.
15. The R5 state-crossfade blend composes AFTER the overlay in the pose seam (`RigMotionModel.pose`), so during a state-change window with an active overlay the blend scales the overlay's contribution toward the from-state's no-overlay static; endpoints exact, deterministic — recorded for future composition-order readers.

### Line/size accounting

New/changed sources: MomoReduceMotion.swift 515 (NEW), RigMotionModel.swift 500, MomoRigView.swift 174, MomoReactionOverlay.swift (small: lerped/blend homes). Tests: mapping 498, twin 278, end-pose 403, RigDiscipline 351. Harness 320. All ≤ 800 (max source 515; director untouched at 792).

## Reviewer Findings

**REVIEW-TASK-029 — APPROVED_WITH_MINOR_NOTES** (record: `.claude/tasks/reviews/REVIEW-TASK-029.md`). Reviewer re-derived §7.3 from 04 before reading the implementation; verified every constant's doc authority; R15 held under 7 of the reviewer's OWN adversarial streams at both seams; API compatibility verified at every call site (no test or app code passes an explicit view closure — Disclosure 9 verified, not asserted); 5 PNGs decoded with ImageIO; 823/82 reproduced 3×, zero warnings; 2 sha256-proven mutation bites bit exactly as predicted (press `min()` → exactly `shortPressIsContinuous`; `stateCrossfadeSeconds` 0.15→0.2 → exactly the 3 predicted mapping pins) and restored byte-identically.

Findings — 2 MINOR / 4 NOTE, all test-completeness/documentation, none behavioral (no code change required):

- **MINOR-1**: the tracker's two-changes-in-one-window overwrite path had NO pin, and its render snap (> 5° ear jump at the overwrite instant) was not in the Disclosures register — a keep-older-window regression would have passed the whole suite. → **DISPOSITION: register item 13 + one new mapping test** (live-semantics sampling disclosed inline; exact-equality snap pin; > 5° non-vacuity; landed t-invariance).
- **MINOR-2**: Disclosure 4 over-stated ("calm settle-back") — the nine identity-ending one-shots render NOTHING (band static throughout; the harness itself rasters none of them). Honest statement: 11/15 non-press keys have no visible touch acknowledgment under RM (with Disclosure 5). → **DISPOSITION: Disclosure 4 rewritten** + owner follow-up line (authored acknowledge-static = owner decision, §24, rides the EPIC-007 haptic/presentation seams).
- **NOTE-1** glance-up hard exit cut (RM holds the plateau to the slot's end; full motion has already decayed) → **register item 14**.
- **NOTE-2** two doc-comment arithmetic misstatements (invite plateau is [0.5, 1.7], not [1.2, 2.4); freshMorning 0.88 is mid-plateau [0.25, 1.15) with bright ≈ 98 %, not "release starts at 0.88 / complete") — all four authored instant VALUES valid → **comments corrected** (verified by the orchestrator's own arithmetic: bump hold = duration − attack − release; smoothstep(0.88/0.96) ≈ 0.980) + task-file wording aligned to "expressive key instant".
- **NOTE-3** the "23–26 luminance levels" evidence metric not reproducible as stated (ImageIO: 146–248 distinct gray bytes incl. AA) → **retracted** in Completion Evidence; the substantive claims (pure grayscale, exact dims, well-painted) all verify — independently confirmed by the reviewer AND the orchestrator.
- **NOTE-4** R5 blend composes after the overlay (cosmetic) → **register item 15**.

**Orchestrator verification of the disposition round** (every diagnosis personally verified before application — standing rule; the reviewer's findings were checked against the sources and 04/§5 arithmetic): fix round by a fresh agent touched exactly 3 files (2 doc-comment blocks in `MomoReduceMotion.swift` — diffed against a pristine snapshot, executable lines byte-identical, post-fix sha256 `39322c2b…`; one new mapping test; task-file register/wording/evidence). **Bite on the NEW pin** (orchestrator): `fold` mutated to keep the older window on a second change → **exactly the new test failed, at exactly its two overwrite assertions** (stale `(content, 5.0)` window surfaced at :260; mid-blend pose −4.54° vs joyful 16.5° at :281); all 16 other mapping tests green; restored sha256 == `39322c2b…` exactly. §19 gate: **824/82 green, zero new compiler warnings**.

**Delta-review judgment (§11)**: the fix round adds one pin test and comment/record corrections — no behavioral change to any source line; per §11's materiality bar no fresh delta reviewer was spawned; the orchestrator's bite above stands as the verification of the new pin (the reviewer's own Bite B had already proven the suite's sensitivity to the state digit).

**Routings from review + disposition**: owner-visible product line — 11/15 non-press keys render no visible touch acknowledgment under RM (Disclosure 4/5); an authored acknowledge-static is the owner's call (§24). Content+Energetic == Content+Relaxed static collision → owner (expression design, Disclosure 6). §2.4 continuous pupil-follow + haptics delivery → EPIC-007.

## Completion Evidence

- **Test battery**: `swift test` → **✔ Test run with 823 tests in 82 suites passed after 1.477 s** — zero new compiler warnings. Baseline 789/79 → +34 tests / +3 suites (mapping 16, twin 7, end-pose 9, discipline +2: environment scoping + glyph flag-free). Every TASK-025–028 suite green unmodified (default flag = exact no-op is itself a pinned test over a live 60-sample schedule).
- **Sanctioned mutation bite (RED → sha-proven restore → GREEN)**: pre-mutation sha256 of `MomoReduceMotion.swift` = `d7b7acf740a4674406a45ac6856a2a2ad0ddc01aad8a81174c549724263bc07f` (recorded in /tmp/rm-sha-before.txt before the bite). Mutation: `reduceMotionOverlay(at:)` reduced to `return overlay(at: t)` (raw full-motion passthrough). `swift test --filter MomoReduceMotion` → **30 failures** across all three suites (twin `differs` probes false; end-pose pins received full-motion values, e.g. tap-head pin got the mid-decay ear 5.026° class of values). Restore → `shasum -a 256` **== d7b7acf7… exactly** → rerun → **32 tests in 3 suites passed**.
- **Frozen modules**: `git diff --stat Sources/MomoCore Sources/MomoKit` → EMPTY (checked at session start, mid-session, and close). Director diff EMPTY.
- **Evidence**: 25 PNGs under `docs/evidence/character/rm-*.png`, byte-identical across two renderer runs (sorted sha256 lists equal); programmatic verification: pure grayscale (R==G==B for every pixel — independently verified with a real ImageIO decode), exact dimensions (520×520 fulls / 752×564 zooms), well-painted (37–97 % non-blank). The earlier "23–26 luminance levels" metric is RETRACTED — not reproducible from the committed PNGs (an ImageIO decode counts 146–248 distinct gray byte values per image, anti-aliasing blends included; the harness digest prints pose channels, not tone counts, so there is no pre-AA tone count to redefine the number as). Renderer rerunnable per its header recipe.
- **Theming audit**: TokenPurityTests + MomoDesignTokensTests + RigDisciplineTests → 19/19 green (scanners proven non-vacuous in both directions); `momo.ear.inner` unused status re-verified against TASK-026's record.
- **No commit made** (per Git Requirements) — working tree holds: new MomoReduceMotion.swift + 3 test suites + harness + 25 PNGs; modified RigMotionModel.swift, MomoRigView.swift, MomoReactionOverlay.swift, RigDisciplineTests.swift.
- **Disposition round (post-REVIEW-TASK-029)**: fresh fix agent applied all 8 items (see Reviewer Findings); suite → **824/82** (mapping 16 → 17); orchestrator bite on the new overwrite pin (RED → sha-proven restore → GREEN, `39322c2b…`); final §19 gate green.

## Handoff

### Completed
All contract requirements R1–R15; the §7.3 table executable at the overlay/pose seams with the fold untouched; R11/R12 grayscale statics + end poses + evidence; R13 theming audit; review + full disposition round.

### Files Changed
Sources: MomoReduceMotion.swift (NEW, 516 ln), RigMotionModel.swift, MomoRigView.swift, MomoReactionOverlay.swift. Tests: 3 new RM suites (mapping 17 / twin 7 / end-pose 9) + RigDisciplineTests (+2). Harness: Tools/character-pipeline/render_reduce_motion_evidence.swift. Evidence: 25 PNGs. Commit `9a46641` = 34 files, +2233/−24.

### Tests Run
`swift test` (full) ×4 across the cycle (impl, reviewer ×3, fixer ×2, orchestrator ×2 incl. bite restore); filtered runs under 3 mutation bites.

### Test Results
**824 tests / 82 suites passed**, zero new compiler warnings (baseline 789/79 → +35/+3).

### Known Issues
None blocking. Register items 13–15 document intentional render artifacts (overwrite snap, glance-up exit cut, blend-after-overlay composition). Product tension disclosed: 11/15 non-press keys render no visible touch acknowledgment under RM (owner line in Reviewer Findings).

### Decisions Made
RM is render-only at the overlay/pose seams (fold/clock untouched — R15 by construction + pinned); state crossfade authored at the 0.15 band floor; press = end-pose swap via hold-keyframe + release crossfade with the earned-pose `min()` refinement; greetings at per-kind expressive instants; play = milestone stills at pacer boundaries. View API: `(Double, Bool)` overlay closure + defaulted RM params (zero existing consumers — EPIC-007 is the first).

### Reviewer Status
REVIEW-TASK-029 **APPROVED_WITH_MINOR_NOTES** — 2 MINOR + 4 NOTE, all dispositions applied and orchestrator-verified; delta judgment: fix round non-material (test + comments/records only), no fresh delta reviewer per §11; bite verification recorded.

### Commit
`9a46641` — feat(character): TASK-029 Reduce Motion mapping + token theming audit

### Push
`34c2e04..9a46641` → `origin/feature/EPIC-006-character` — SUCCESS 2026-09-10

### Recommended Next Step
TASK-030 (character test suites, 05 §10.1–10.2 — S-size closing/audit task: sequencer determinism-property completeness + RM pose-mapping coverage; NO character line-coverage floor exists), then EPIC-006 merge to `main` per §14 (git fetch + origin/main check first).
