# REVIEW-TASK-027 — Independent Adversarial Review

## Header

- **Task:** TASK-027 — deterministic idle sequencer + expression system (idle sampler, §5.2 schedulers, variant catalog, §3 expression model, motion-model render, R1–R4 routings)
- **Date:** 2026-09-10
- **Reviewer:** fresh independent adversarial review agent (no implementer context; CLAUDE.md §10/§33)
- **Reviewed state:** working tree, uncommitted (implementer does not commit per Git Requirements). Changeset = 6 modified sources, 5 new sources, 3 modified test files, 6 new test suites, ADR-009, task file (`git status --porcelain`, 22 entries, no strays — verified twice, before and after mutation bites).
- **Mandate:** try to DISPROVE correctness; approval requires concrete positive evidence, not absence of complaints.

## Verdict

**CHANGES_REQUIRED**

Two MAJOR findings require disposition (an ADR/decision record or a code fix, plus the contract-mandated test) before this task may commit. Everything else examined — determinism, distributions, geometry conversion, conflict law, arbiter, R1–R4, INV-5/6, scope, hygiene — checked out against the doc and the contract, with the implementer's claimed numbers reproduced and three mutation bites showing the pins have teeth.

## Methodology

1. Read CLAUDE.md, the task contract (requirements, acceptance criteria, Required Tests 1–10), `docs/design/04-character-system.md` (§3, §5, §7.1, §7.2, §7.4, §9.3–9.5), REVIEW-TASK-026, ADR-009.
2. Read every new/changed source line-by-line: `MomoIdleRandom`, `MomoIdleEvents`, `MomoIdleVariants`, `MomoExpressions`, `MomoIdleSequencer`, `RigMotionModel` (diff), `MomoCurves` (diff), `MomoRigView` (diff), `RigLayerTree` (diff), `RigPose` (diff), `CharacterClock` (diff), `RigChannel` (unchanged, canonicalOrder pin intact).
3. Read all six new test suites and the diffs of the three modified test files; re-derived the aperture→lidScaleY algebra independently against the generated eye/lid geometry in `MomoRig+Eyes.swift`.
4. Ran `swift test` on the untouched tree FIRST: **716 tests / 71 suites passed, exit 0** (matches the implementer's claim).
5. Built a reviewer-owned probe package in `/tmp/momo_review_probe` (never committed) that drives the real `RigMotionModel.pose` through the shipped code path.
6. Three mutation bites with `shasum -a 256` byte-identity proof before/after; full suite re-run after restoration.
7. Independent hygiene scans (TODO/FIXME, hex, system randomness) in addition to the suite's own `RigDisciplineTests` scanners.
8. Adjudicated the moved/replaced test pins, the pause-semantics change, and the mid-flight fix claim.

## Findings

### MAJOR-1 — §7.2 "pure sine" breath is clipped flat over 29–50 % of every cycle on Joyful, Wistful, Low, and the asleep row (posture×breath product clamp)

- **Where:** `Sources/MomoCharacter/RigMotionModel.swift:68-71` (composes `expression.postureScaleY * breathScaleY(...)`), `:137-139` (clamps the PRODUCT via `clampedPostureScaleY`); the clamp is documented as deliberate at `Sources/MomoCharacter/MomoCurves.swift:53-57` ("The motion model clamps every composed posture into this range").
- **What's wrong:** with posture at the band edge, the product leaves `[0.95, 1.03]` for half (or part) of the sine, and the clamp freezes it. §7.2 (`04-character-system.md:449`) says "Breathing | pure sine"; the contract Requirement 2 says "breath stays pure sine".
- **Empirical proof (reviewer probe through the real model, empty schedule, 20 000 samples/cycle):**
  - Joyful awake: **50.00 %** of every 4.0 s cycle flat at exactly 1.03 (rendered range [1.00734, 1.03] — the entire inhale half carries zero motion)
  - Content: **0 %** — clean sine [0.98, 1.02] (the canonical row is correct)
  - Wistful: **29.00 %** flat at 0.95
  - Low: **50.00 %** flat at 0.95
  - Joyful asleep (the night/AOD sight): **50.00 %** flat at 1.03
- **Disclosure state:** the only disclosure is one test comment (`MomoIdleRenderTests.swift:291-294`) naming the Joyful-asleep **peak** clamp ("the trough carries the visible motion") — true, but it masks that the **entire half-cycle** is flat; Low and Wistful are never mentioned; the task file's Implementation Notes are silent.
- **Root cause is a doc over-constraint:** §3.1's table (`:206-207`) lists **Posture** (+3 %…−5 %) and **Breath** (§7.1 amplitude) as separate vocabulary rows sharing the body-scaleY channel. Joyful authored at 1.03 with amp 0.022 cannot satisfy "posture ≤ 1.03", "amplitude 1.5–2.5 %", and "pure sine" simultaneously if the clamp applies to the composed product. Clamping only the **static posture offset** (letting breath ride to 1.0522 at peaks) satisfies §7.1's amplitude row and §7.2's sine law under the separate-rows reading; alternatively re-author Joyful's posture to ≤ 1.008 or shrink band-edge amplitude.
- **Failure scenario:** the aliveness floor is THE product register ("reads as breath, not whole-body deformation", §7.1). On 3 of 4 mood bands plus sleep, the rendered breath is a rise-less dip-only wave every cycle.
- **Severity rationale:** MAJOR, not CRITICAL — motion is preserved in the other half-cycle, the deviation is ≤ 2.2 % scaleY, and the composed clamp is source-documented as an intentional channel-value law; but it contradicts an explicit contract sentence and a doc curve law, is measurable, and the disclosure understates the extent. I record the doc ambiguity rather than resolving it by assumption; disposition (ADR recording the composed-clamp reading + its cost, or the posture-offset fix, or a re-authored Joyful row) must precede commit.

### MAJOR-2 — Required Test 3 (resume discipline) has no explicit test, and Req 8/AC-2's continuation-equality semantics contradict the shipped zero-on-pause clock — unadjudicated

- **Where:** contract `:61` (Req 8: "resume NEVER replays or bursts … identical continuation to an uninterrupted run from T + gap"), `:85` (AC-2 "resume skips (never replays) pre-gap events"), `:99` (RT-3 "no replay/burst; continuation equality vs. uninterrupted reference"); `Sources/MomoCharacter/CharacterClock.swift:58-77` (pause zeroes; elapsed ≡ 0 while stopped; resume re-anchors, restarting from 0).
- **What's wrong:** under the shipped TASK-026-approved clock, after pause+resume the pose replays the whole log from t = 0 — the resumed run equals an uninterrupted run from 0, **not** from T + gap; pre-gap events literally replay (in real time). The contract's demanded simulation ("consume to T, resume at T + gap, assert … identical continuation") is therefore unsatisfiable as written — and the contract's own constraint at `:67` (existing suites stay green UNCHANGED) forbids changing the TASK-026 pins that embody zero-on-pause. The contract is internally inconsistent here, and no test implementing RT-3 exists: the greps over `Tests/MomoCharacterTests/` find resume coverage only in pre-existing `CharacterClockTests` pins (no-burst via `resumeAfterPauseRestartsFromZero`) plus the moved pause-routing pin (`pausedClockStopsEveryChannel`).
- **What IS satisfied:** no-burst (elapsed restarts at 0, replay is real-time; pinned), determinism (purity makes replay byte-stable), "the next event is scheduled after the resume point" (vacuously — the timeline zeroes, so no between-pause events exist).
- **Disclosure state:** the Implementation Notes adjudicate other tensions in detail but never mention the Req-8-vs-zero-on-pause contradiction. CLAUDE.md §21 (decisions must not live only in conversation) and the review contract (Required Tests are obligations) both make this a pre-commit disposition: either an ADR recording "resume discipline under zero-on-pause = replay-from-0 in real time, no burst" **plus** an explicit test of that executable form, or an owner decision to change clock semantics (which would break TASK-026 pins — worse).
- **Severity rationale:** MAJOR — a contract-required test is absent and a contract requirement is contradicted-by-design without a recorded decision. Not CRITICAL — the shipped behavior was already reviewed and approved in TASK-026, is deterministic and burst-free, and is arguably the better product behavior (§5.3 freshness after background dwell).

### MINOR-1 — §5.3 no-distraction budget breached on 4/200 sampled windows under the strict reading; the ≤ 0.20 max tier is implementer-authored

- **Where:** `04-character-system.md:361` ("motionless ~85–90 % of **any** 30-second window"); contract Req 7 ("≤ 15 % of sampled 30 s windows"); disclosure in task-file Known Issues and Implementation Notes; pin in `MomoIdleSequencerTests` occupancy battery (mean ≤ 0.15, p95 ≤ 0.15, max ≤ 0.20).
- **What's wrong:** measured mean 0.1102 / p95 0.1419 / max **0.1700** — 4 of 200 windows exceed 0.15 motion, i.e. 83.0 % motionless, below the doc's ~85 % floor. The notes call this "not a violation — bounded by the ≤ 0.20 max pin", but the 0.20 tier appears nowhere in the doc; it is a self-granted second tier. Honest disclosure and the doc's tilde (~) mitigate; the "not a violation" framing does not.
- **Suggested fix:** either tighten the authored subranges (gaze-return 0.60–0.70 and crossfade 0.30–0.33 sit at their band's motion-maximizing ends) until max ≤ 0.15, or record an ADR for the two-tier budget (p95 ≤ 0.15 with a hard 0.20 escape) so the doc and the pin agree.

### MINOR-2 — RT-7's letter ("R1 probes … at sampled times from seeded logs") is not literally implemented; shipped probes dominate it

- **Where:** `Tests/MomoCharacterTests/R1CompositionTests.swift:32-47` — the probe pose is hand-built (`loadedPose`), not sampled from seeded logs at time instants.
- **Assessment:** the shipped probes are **stronger** in matrix terms: every channel live at once (beyond what the §7.4 arbiter would co-admit), independent §2.2 law at ≥ 15 slots / > 75 points / 1e-6, order-sensitivity control, pixel probes view-verbatim vs y-flipped CGContext with a non-vacuity control, `.rest` → exact identity at all tiers, anchor/hierarchy semantics pinned. Any pose the model can emit is a lower-complexity case of this loaded pose, and the view path is pose-agnostic. Recorded as a letter-vs-substance deviation, not a defect. No action needed beyond a one-line note in the task file if the orchestrator cares about the letter.

### NOTE-3 — crossfade-family variant envelopes are pinned only at hold; a linear fade regression would pass

The mid-flight fix ("crossfade variants multiplied magnitudes by raw elapsed seconds instead of the envelope shape") is correctly landed — `RigMotionModel.render` evaluates `envelopeProgress` for the crossfade family, and the render tests pin hold values digit-for-digit (weightShift exactly ±8/±2.5°, cheekPressRest `clampedPostureScaleY(breath × 0.985)`, calmCoexist aperture ×0.55). Blink and gaze pin **mid-envelope** smoothstep, so a shared-smoothstep regression is caught — but no crossfade variant is sampled mid-fade (e.g. t = 0.15 with a 0.3 s fade). A variant-specific envelope regression would pass the suite. Low risk; add one mid-fade pin when convenient.

### NOTE-4 — `MomoRigView` header comment contradicts the clock's pause semantics

`Sources/MomoCharacter/MomoRigView.swift` header: "a stopped clock freezes the **current pose**" — the clock actually freezes at the **t = 0 unaged band pose** (`CharacterClock.swift:58-77` states it correctly; `pausedClockStopsEveryChannel` pins it). Doc-only fix; the AOD/glyph-tier claim built on that sentence should be re-read when fixed.

### NOTE-5 — adjudications recorded (no action or one-line task-file notes)

- **Moved pause pin** (`CharacterClockTests.pausedClockStopsEveryChannel`): the first assertion `frozen == model.pose(at: 0)` is a **routing** test (elapsed() ≡ 0 after pause makes the equality composite, not an independent content pin); content strictness is carried by `RigMotionModelTests.modelAtZeroIsTheExpressionBase` (full digit-for-digit t = 0 pin). Aggregate strictness equals the old `.rest` pin. The inline "equally strict, digit-for-digit" claim holds at suite level. Accepted.
- **Mouth follow-up**: "tiny content curve" has no generated geometry; routing as a geometry-owner follow-up is exactly what the contract ordered (O2 precedent). INV-5 held — idle writes mouth `.neutral` / cheekOpacity 1 unconditionally (value-neutral; bypasses the channel gates but no idle path can change these channels).
- **Sequencer docstrings** initially suspected stale ("9–21"/"14–30" vs constants 10–21/16–30): re-checked — they cite the **doc band** and declare the subrange with rationale inline. Accurate; not a finding.
- **`blinkClosure` double-blink modulo**: re-derived with concrete numbers (close 0.16 / open 0.14 / gap 0.09) — the `(pair + gap)` phase divisor is correct and continuous across the double. Not a finding.
- **Clamp-then-×tempo ordering** for blink intervals: preserves the exact ×1.4 Drowsy ratio (multiply-after-clamp would distort at the clamp edges). The doc-faithful choice; verified by the per-seed-paired 1e-9 test.

## Positive evidence (what approval is based on, once the MAJORs are dispositioned)

1. **Purity/determinism**: log is a pure function of `(idleSeed, displayState, windowEnd)`; four SplitMix64 substreams (master draws 1–4); no clock/wall-time/system-random reads anywhere in the stack; prefix-stable; whole-log digit-for-digit vector pins (seeds 0/1/42) plus 25-seed × 6-state determinism; `RigDisciplineTests` §9.4 scanner with self-tests scans all 13 rig files (count-pinned), and my independent grep corroborates.
2. **§5.2 distributions**: blink N(6,2) with both clamp bounds hit exactly, mean/σ pins (6.0387/1.9262), doubles 11.75 %; clamp-before-tempo ×1.4 Drowsy pinned to 1e-9; Wistful ×1.2 durations to 1e-12; gaze U(10,21) inside doc 9–21 with five targets, atUser weight 0.25, Joyful ×1.4 ratio pinned (1.2594 measured vs 1.2727 theory); variants U(16,30) inside doc 14–30, Energetic ÷1.5 ratio pinned; calmCoexist bond-gated (0.1875 measured); headNod energy-gated; yawn U(45,90) Drowsy-only and awake-only.
3. **Aperture conversion re-derived independently**: `lidScaleY(a) = (142 − 112a)/56` verified digit-for-digit against the generated geometry landmarks (eye top 334, eye bottom 446, lid anchor 304, lid rest bottom 360); closed = 2.5357…; band landings and Drowsy ×0.7 flow through the one conversion; round-trip < 1e-12.
4. **Conflict law**: 16-cell truth table (tempo-only conflict resolution; the normative Drowsy-aperture exception), bond dials pinned, INV-6 full 4096-cross-product audit, Low = quiet resting.
5. **§7.4 rule 4** (`:475` "≤ 3 properties concurrently"): greedy arbiter sorted by kind rawValue — blink (0) is never displaced; same-kind overlap is impossible under authored parameters (min intervals exceed max durations); sampled battery ≤ 3; no-new-bits admission tested.
6. **R1–R4 all genuinely discharge REVIEW-TASK-026's MINORs**: R1 = ADR-009 option 1 with modifier chain deleted and point+pixel probes with non-vacuity and order-sensitivity controls; R2 tolerance admits ζ = 0.75…0.85 settling while rejecting real bounces (bite 3 proves teeth); R3 settle exponent raw-pinned; R4 model-side ±25°/±10° clamps with gating bites; doc-comment labels now correct.
7. **Scope and hygiene**: changeset is exactly the claimed set; no §6 vocabulary, no reactions/Reduce-Motion/props work, no new geometry (generated buckets absent from `git status`), zero hex, zero TODO/FIXME debt, zero system randomness; art budgets re-measured and recorded; Known Issues honest (occupancy, mouth, pre-existing ld warning).
8. **Pin provenance**: raw literals mirrored from an independent Python SplitMix64 validated against `SeededGeneratorTests` (documented in the suite docstrings); `uniformMapping` ties the sampler to MomoCore's pinned generator output; my bite 2 independently proves the vector pins bind the implementation.

## Attack the implementer's suite would NOT catch (mandate obligation)

The **flat-top breath probe** (MAJOR-1): the suite pins Joyful-asleep breath at t = 0, t = 1.8 (a point inside the flat region), t = 5.4, and pins Content's floor at t = 5 — but no test sweeps any band's breath cycle, so the 50 %/29 %/50 % flat extents on Joyful/Low/Wistful are invisible to all 716 tests. The `/tmp/momo_review_probe` harness measured them through the real model. Mutation bites 1–3 additionally confirm the strongest pins (posture clamp band, substream draw order, R2 tolerance) all fail under mutation, i.e. they are not decorative.

## Mutation-bite log (sha256 proof of byte-identical restoration)

All bites applied to the working tree, tested, then restored from a pre-bite copy; `shasum -a 256` recorded before and after each.

| # | File | Mutation | Result | sha256 before | sha256 after | Identical |
|---|------|----------|--------|---------------|--------------|-----------|
| 1 | `Sources/MomoCharacter/MomoCurves.swift` | `postureScaleYRange` upper bound 1.03 → 1.04 | 3 failures / 2 suites: `MomoCurvesTask027Tests` clamp-constant pin (`:130`), clamp-function pin (`:146`, saw 1.04), `MomoIdleRenderTests.asleepRenders` (`:294`, peak read 1.04) | `a90feebfd5c5b12fdcd6dd6595f51ff55507b9bd47d710fc1f97c8c63cc2309a` | `a90feebfd5c5b12fdcd6dd6595f51ff55507b9bd47d710fc1f97c8c63cc2309a` | YES |
| 2 | `Sources/MomoCharacter/MomoIdleSequencer.swift` | extra master draw inserted between gaze and variant substream seeds (draw-order contract violated) | all 3 whole-log vector pins failed (seeds 0, 1, 42 — kinds, starts, durations all diverged) | `5d8f37ec37ecd865ac450fed964f34bfeb9d0f8fb1e179d0e403d00da3261658` | `5d8f37ec37ecd865ac450fed964f34bfeb9d0f8fb1e179d0e403d00da3261658` | YES |
| 3 | `Sources/MomoCharacter/MomoCurves.swift` | `softCrossingTolerance` 0.01 → 0.0001 | R2 suite failed (8 failure records): sub-tolerance settling rejected (`:61`), single-soft crossing rejected (`:65`), from-above settle rejected (`:82`) — proves the R2 discharge test has teeth | `a90feebfd5c5b12fdcd6dd6595f51ff55507b9bd47d710fc1f97c8c63cc2309a` | `a90feebfd5c5b12fdcd6dd6595f51ff55507b9bd47d710fc1f97c8c63cc2309a` | YES |

Restoration method: `cp` from a pre-bite backup copy (never `git checkout` — the TASK-027 changes are themselves uncommitted). `diff` of the before/after sha records is empty for all three bites.

## Test results

- **Before any bite (untouched tree):** `swift test` → **716 tests / 71 suites passed**, exit 0.
- **After all bites restored:** `swift test` → **716 tests / 71 suites passed**, exit 0 — identical pass counts.
- During bites (expected failures, then restored): bite 1 → 50 tests / 3 suites run, 3 issues; bite 2 → sequencer suite vector-pin failures; bite 3 → R2 suite failures.
- `git status --porcelain` before and after the bites: same 22 entries — the reviewer left exactly the implementer's changeset, nothing more.

## What I could NOT verify

- **On-device rendering**: all evidence is headless (static analysis + Swift Testing + CGContext/ImageRenderer probes). Device-level scenePhase observation, AOD glyph tier, and Watch behavior are routed to EPIC-007/008 per the view's authority split.
- **The claimed independent Python pin mirror**: I did not re-run `/tmp/momo_verify_pins.py`; instead I verified the chain differently (`MomoIdleRandomTests.uniformMapping` pins `Double(output >> 11)/2^53` against MomoCore's pinned SplitMix64 output, and bite 2 proves the whole-log pins bind this implementation).
- **Whether a 50 %-flat breath "reads as breath"** (§7.1's own quality bar): needs a human/product eye in a SwiftUI preview; the numbers alone cannot settle MAJOR-1's product severity.
- **Per-source occupancy contributors**: which authored subrange dominates the 4 over-budget windows was not decomposed.
- **"Zero NEW warnings"**: test runs showed no new warnings, but warm builds do not re-print warnings; a fully clean build was not re-run by this review.

## Recommended disposition (for the orchestrator — not executed by this reviewer)

1. **MAJOR-2 (do first, cheapest):** write ADR-010 "resume discipline under the zero-on-pause clock" recording the executable semantics (replay-from-0, real-time, no burst) and add one explicit test (resume at wall-time T + gap ⇒ elapsed == 0, no time-jump render, log replays identically). Alternatively escalate to the owner to change clock semantics — not recommended.
2. **MAJOR-1:** owner-level choice between (a) clamp the static posture only — breath rides outside §3.1's band as its own §7.1 channel, sine preserved everywhere; (b) re-author Joyful posture ≤ 1.008 (inside the band at amp 0.022); (c) keep the composed clamp and record its cost in the doc (§7.2 gains an exception note) — with (c), also disclose Low/Wistful, and pin the flat extents so the behavior is deliberate and regression-guarded rather than accidental.
3. **MINOR-1:** tighten subranges or ADR the two-tier occupancy budget.
4. NOTE-4's comment fix and the mid-fade pin (NOTE-3) can ride along with any of the above.
