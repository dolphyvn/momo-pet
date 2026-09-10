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

READY — contract authored 2026-09-10; fresh implementation agent dispatching.

## Implementation Notes

(impl agent fills: architecture decisions, disclosures with authority labels, deviations, line/size accounting.)

## Reviewer Findings

(none yet)

## Completion Evidence

(to be filled: test counts, budgets, frozen-module checks, suite reproductions)
