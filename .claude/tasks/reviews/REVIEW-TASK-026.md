# REVIEW-TASK-026 — Independent Adversarial Review

**Task:** TASK-026 — RigLayerTree + CharacterClock + LOD tiers + curve law + size-ladder evidence
**Reviewer:** Independent adversarial review agent (Jupiter), per CLAUDE.md §10/§33 — mandate: attempt to DISPROVE correctness; assume nothing in the implementer's notes until verified with own tooling.
**Date:** 2026-09-09
**Verdict:** **APPROVED_WITH_MINOR_NOTES**
(4 MINOR findings, 6 NOTEs, zero MAJOR. One doc-only pre-commit correction required — see MINOR-1a. All other findings route to TASK-027/028 contracts.)

---

## 1. Method (what this review independently executed)

1. Re-derived the 04 §2.2 channel table from the design doc BEFORE opening `RigChannel.swift`; then compared name-for-name.
2. R1 violation hunt with own greps + file reads; attacked every RigDiscipline scanner for under-matching.
3. Built a reviewer-owned probe harness in /tmp (never committed): compiled the package's built modules plus a fresh `SteppedClock` and probe mains (`/tmp/task026-review/probe*`) covering clock interleavings, curve-law attacks, and CG-vs-SwiftUI composition counterexamples.
4. Verified every §7.1/§7.2 pin digit-for-digit; attacked `isSingleSoftOvershoot`/`overshootFraction` with constructed curves (bouncing ball, band-edge damped springs, exact-target excursions, boundary caps, empty input).
5. Audited LOD tier selection (exhaustiveness, watch-never-full, tier↔constant-set mapping vs the TASK-025 44-constant catalog).
6. Executed EXACTLY the two sanctioned mutation bites with sha256 before/restore proof and observed the named pins fail.
7. Audited token application (INV-5) including the three disclosed non-obvious mappings.
8. Adjudicated the four routed questions (view/harness equivalence; ear/tail bounds; prop channels; ear.inner).
9. Wrote own CoreGraphics pixel probes over all 8 committed evidence PNGs (vision reads treated as untrusted; pixel measurement as ground truth per Disclosure 10's transport warning).
10. Ran `swift test` myself (twice: pre-bite and post-restore), warnings scan, art-budget measurement.
11. Scope + hygiene: `git status` vs the disclosed set; TODO/FIXME/HACK/TEMP scan; secrets scan.

## 2. Verified-clean results (reviewer's own numbers)

| Check | Result |
|---|---|
| §2.2 derivation vs `RigChannel.canonicalOrder`/`RigPose`/`RigLayerTree` | Exact match — 28 channels, name-for-name, group order matches, props row matches |
| R1 (transform-only) | Clean. No `Path` construction/mutation, no Shape builders in any of the 8 rig files (independent grep + read) |
| R4 | No hex/RGB outside palette files (one doc-comment grep hit at `MomoCurves.swift:45` is the word "anchored", a false positive) |
| R3 | No ambient-time reads in clock/view; scenePhase wiring present and pure-mapped (`.active→resume` else `pause`) |
| CharacterClock interleavings (probes A1–A8) | All pass: pause/pause/resume/resume with a 1000 s stopped dwell → no backlog replay; `elapsed(at:)` before the anchor clamps to 0; repeated queries pure (3.0/3.0/3.0); stopped clock returns 0 at −100 s…1e9 s; backward source clamps at 0 and the anchor is unchanged by the jump; zero-length toggle runs accumulate correctly; pose == `.rest` while paused and immediately after resume, breath re-peaks at 1.02 one quarter-cycle after resume |
| §7.1/§7.2 pins (`MomoCurveRulesTests`) | Digit-for-digit vs design doc: damping 0.75–0.85; touch 0.15 / 0.35 s; celebration 0.08 + no-bounce; breath bands 3.8–4.2 / 4.6–5.2 / 5.8–6.4 / 6.5–8.0; amplitude 0.015–0.025; sleep −0.30; driver 4.9 s / 0.02; pure sine incl. loop slope continuity |
| Breath, pixel-verified (probes on PNGs) | rest bbox 494 px → inhale 504 px = **+2.02 %** (§7.1's 2 %); bottoms both y=519 (bottom-anchored); width constant 406 px (no shear) |
| LOD | Exhaustive switch (no `default`), `surfaceEnumerationIsTotal` pins count == 4, `watchNeverFull` sweeps `allCases`; tier stage bands 220–280 / 60–80 / 24–32 pt; part sets 21 / 11 / 3 match the catalog |
| INV-5 / token application | 39-entry part→token map pinned; disclosed mappings confirmed: pupil→`momo.eye.highlight`, mouth→`momo.eye.base`, bellyPatch+food→`momo.fur.shade`; pixel census agrees per tier (glance = furBase+furShade+eyeBase only; glyph = furShade silhouette + 2 eyeBase dots) |
| Evidence sizes | 520 / 140 / 56 px @2x = 260 / 70 / 28 pt — inside §bands |
| Art budgets | Generated rig sources ≈ 72 KB, props 8 KB (≪ 300 KB / 250 KB); evidence dir 292 KB (≪ 1.5 MB) |
| My `swift test` | **627 tests / 65 suites passed, 0 warnings, exit 0** — run 1 (pre-bite) and run 2 (post-restore) identical |
| Scope | `git status` = exactly the disclosed TASK-026 set (8 sources, 7 test files, 1 evidence harness, 8 PNGs, task-file notes) |
| Hygiene | No TODO/FIXME/HACK/TEMP/XXX; no secrets (only benign `token` property names) |

## 3. Mutation bites (sanctioned; both restored, sha256-proven)

**Bite (a) — CharacterClock resume keeps a stale anchor.**
Removed `state.resumeAnchor = timeSource.now()` (`Sources/MomoCharacter/CharacterClock.swift:51`).
- Before sha256: `66c91652cd8ebaa566d1cadbe41de2859d3b8e488fe82d6c1a1dc8af9886b083`
- After restore: `66c91652cd8ebaa566d1cadbe41de2859d3b8e488fe82d6c1a1dc8af9886b083` — identical.
- Failing pins (exactly the predicted two): `Resume after pause restarts from zero — no backlog replay (04 §5.3)` (elapsed **14.5** vs 1.5) and `Double pause is idempotent: still zero, still restarts from zero` (**8.0** vs 1.0). Other 8 clock tests unaffected. **Teeth confirmed.**

**Bite (b) — watchForeground → .full.**
Changed `Sources/MomoCharacter/RigLODTier.swift:35` from `.glance` to `.full`.
- Before sha256: `2b63b5491f4ab8a3274a70894482fb9e30a9309e226afb27ad5dda981bb54015`
- After restore: `2b63b5491f4ab8a3274a70894482fb9e30a9309e226afb27ad5dda981bb54015` — identical.
- Failing pins (exactly the predicted two): `Watch foreground → glance rig` and `WATCH-NEVER-FULL: no non-iPhone surface ever selects the full tier`. Other 10 LOD tests unaffected. **Teeth confirmed.**

Post-restore: both suites 22/22 green; full run 627/65 green. No other file was touched.

## 4. Findings

### MINOR-1 — The view/harness "same transform" claim in code is false for composed hierarchies (latent TASK-027 trap; zero behavioral divergence today)

`RigLayerTree.swift:283-291` and the inline comment at `:297-299` ("scale → rotate → translate **matches the SwiftUI chain**"), plus `MomoRigView.swift:149` ("chain structurally identical"), claim equivalence that does not hold:

- **Within a stage:** the harness composes S·R·T (scale applied first); the view chains `.offset → .rotationEffect → .scaleEffect` (`MomoRigView.swift:123-142`), and the FIRST modifier is innermost (applies first) → the view applies T first, then R, then S. The comment even misdescribes the view's actual within-stage order.
- **Across stages:** the harness prepends each stage, so child-local applies FIRST (ancestors last); the SwiftUI chain places stage 0 (ancestor/body) closest to the content, so the ancestor applies FIRST. The orders are opposite.

Measured counterexamples (reviewer probes, grid units on the 1000-grid):
- body scaleY 1.02 + head bob −20: neck Y **harness 561.4 vs view-order 561.8** (Δ 0.4).
- head 6° + ear 10°: ear tip **Δ (0.56, 6.01)** — the view pivots the ear about the authored anchor *after* the head has swung it; the harness pivots first, then rides the head.
- within-stage tilt 10° + bob −30: probe point **Δ (5.21, 0.46)**.
- breath-only (today's only non-identity channel): **exact equality** — which is why no current test or render diverges.

**Adjudication (mandate question 8a):** today's behavior is correct and every current pin is honest about the harness; the defect is the false equivalence documentation plus the latent trap — the moment TASK-027 enables head/ear/tail channels, the unit-tested math and the rendered view diverge visibly.
**Required action:** (a) correct the three comment sites in the TASK-026 commit (doc-only, no behavior); (b) route the composition decision — view adopts the composed matrix (`.transformEffect` per slot) OR the harness mirrors the view order OR channels are constrained to one non-identity freedom per stage — into the TASK-027 contract as a blocking decision for that task.

### MINOR-2 — `isSingleSoftOvershoot` rejects the step response of EVERY damping value in the sanctioned §7.2 band

`MomoCurves.swift:89-107` counts all full crossings (`crossings <= 1`, line 102). Sampled unit-step responses: ζ=0.75 → 2 crossings (+2.84 % overshoot, −0.081 % undershoot) REJECTED; ζ=0.80 → 2 crossings (+1.52 %, −0.023 %) REJECTED; ζ=0.85 → 2 crossings (+0.63 %, −0.004 %) REJECTED; still 2 crossings at coarse 11-sample resolution. The doc comment (lines 84-85) says "at most one **excursion past it**" — an in-band spring has exactly one past-target excursion but two crossings (the return through target), so the code is stricter than its own stated law and than §7.2's physics. TASK-027 consumes this predicate; validating a real spring's output with fine sampling will false-positive. Fix (TASK-027 contract): tolerance-filter the crossings (e.g. ignore excursions below a visible-motion threshold) or restate the doc/intent to "authored keyframe settle curves".

### MINOR-3 — Requirement 5's "settle/sleep ease-in decelerating into stillness" has no constant or pin

Task contract Requirement 5 (task file line 27) lists it among the §7.2 pins; `MomoCurves.swift` carries spring/touch/celebration/breath constants only. The settle/sleep ease-in row of §7.2 is unpinned. Route: add the constant + raw-literal pin (small follow-up, or into TASK-027 which consumes it).

### MINOR-4 — `lidScaleY` doc comment and a test name state inverted semantics

`RigPose.swift:61`: "Lid coverage, 1 = fully open (the authored geometry), 0 = closed." The anchor math says the opposite: the lid is anchored at the eye's TOP (`RigLayerTreeTests.swift:269`, anchor 430,304); scaleY 0.5 lifts the lid bottom 360→332 (UP, revealing more eye) — so scaleY<1 = more open, 0 = no lid = maximally open, and closing beyond authored coverage requires scaleY>1. The test NAME at `RigLayerTreeTests.swift:264` ("closing pulls the lid bottom down") contradicts its own correctly-pinned numbers at `:271`. The math is right; only the semantic labels are inverted. TASK-027's blink/drowsy driver consumes this channel — a driver written against the doc scales the wrong way. Fix both labels (doc-only).

### NOTE-1 — Discipline scanners under-match several violation shapes
`pathConstructionPatterns` misses `.strokedPath`, `.union`, `.subtracting`, `.intersection`, `.flattening`, `.trimmedPath`, `.offsetBy`, and Shape-based geometry (`Circle()`, `Capsule()`); `hexColorPatterns` misses `Color(.sRGB, red:`, `Color(hue:`, `.init(red:`; `ambientTimePatterns` misses `Instant.now`, `Date(timeIntervalSinceNow:`, `ProcessInfo…systemUptime`, `DispatchWallTime`. The current files are verifiably clean (independent grep + read), and the scanners are fixture-tested non-vacuous for the patterns they do carry — non-blocking. Extend opportunistically.

### NOTE-2 — Exact-target crossing hole in the no-bounce predicate
`[0, 1.05, 1.0, 1.05, 1.0]` (target 1) is accepted: a sample exactly on target counts as "a settle, not a crossing" (`MomoCurves.swift:96-99`), so a double excursion bridged by exact-target samples vanishes. Contrived (requires exact FP equality mid-flight); documented intent. Accept.

### NOTE-3 — Empty samples are vacuously accepted
`isSingleSoftOvershoot([], …) == true` (`MomoCurves.swift:92`). Fine for tests; document before any runtime-gate use.

### NOTE-4 — The glyph tier still drives the shared clock
`MomoRigView.swift:73` renders `.rest` and never reads the clock, but `.onChange(of: scenePhase)` (`:83`) wraps the whole Group, so glyph surfaces pause/resume the clock anyway. R3-compliant today; footgun only if a future branch diverges. Consider scoping the wiring in a later task.

### NOTE-5 — Disclosure 3 misstates the ear.inner fact
Task file line 136: "`ear.inner` generated constant is NOT drawn" — no such constant exists anywhere (44-constant `GeneratedRigCatalog` confirmed; `Tools/character-pipeline/parts.py` has no inner-ear part; my pixel census found zero genuine earInner pixels — the 68 classified pixels are furBase/cheek anti-aliasing bleed). The real fact: the `momo.ear.inner` palette token (`MomoCharacterPalette.swift:23-24`) is unused, and §2.2's table has no inner-ear part, so this is NOT a fidelity gap. Correct the wording in the task file at commit time.

### NOTE-6 — O2/O3 adjudication at true sizes (mandate item 9) — pixel probes as ground truth
- **O2 full tier:** the eye dark clusters measure 51×44 px (h/w **0.86**) — ~14 % vertical compression → the "drowsy at close inspection" read is CONFIRMED. The implementer's routing to the TASK-025 geometry owner is correct: TASK-026's lid channel is identity at rest and the cause is authored geometry (frozen files). Not a TASK-026 defect.
- **O2 glance:** two 13×15 px dots (h/w 1.15, no lid flattening) — calm. **ACCEPTED.**
- **O2 glyph:** exactly two 4×4 round dots, symmetric about the canvas center (x 23.6/31.4 of 56), silhouette in furShade — calm and legible at 28 pt. **ACCEPTED.**
- **O3 tail:** furShade bump present in both zooms (glance zoom: 8368 shade px vs 9296 base px). At true glance size it reads as a body bump; the disclosed "accept with polish note" is defensible. **ACCEPTED with the polish note standing.**

### Adjudications of the remaining routed questions
- **8b (ear/tail bounds):** the −25°…+25° ear / ±10° tail clamps are NOT required by TASK-026's contract text (Requirements/AC name only the §2.4 pupil clamp, which is implemented and model-side). Driver-time obligation → route explicitly into the TASK-027 contract.
- **8c (prop channels without stages):** props are channel-inert in the view (no stages, default opacity 1) and transform-inert under breath (`RigLayerTreeTests.headRidesBreathPropsDoNot`). Contract-compliant via the TASK-028 wiring disclosure. No action.

## 5. Test evidence (reviewer-run)

- Full suite: `swift test` → **627 tests / 65 suites passed**, 0 warnings, exit 0 (pre-bite AND post-restore).
- Bite (a): `swift test --filter CharacterClockTests` → 10 tests, **2 failed** (the two named pins), 8 passed.
- Bite (b): `swift test --filter RigLODTierTests` → 12 tests, **2 failed** (the two named pins), 10 passed.
- Post-restore confirmation: both suites 22/22 green.

## 6. Verdict rationale

No MAJOR findings: every acceptance criterion was verified with reviewer-owned tooling; current behavior is correct (clock semantics, LOD discipline, token application, breath physics — the last pixel-measured at +2.02 % bottom-anchored); both sanctioned bites prove the named pins have real teeth; scope and hygiene are clean; 627/65 green. The four MINORs are precision/forward-looking: none changes current behavior, but MINOR-1a's false code comments and MINOR-4's inverted labels must not ship as-is (they will mislead TASK-027's fresh agent), and MINOR-1b/2/3 are blocking contract items for TASK-027, not for this task.

**APPROVED_WITH_MINOR_NOTES**, with these conditions recorded:
1. Pre-commit (doc-only): correct `RigLayerTree.swift:283-291` + `:297-299`, `MomoRigView.swift:149`, `RigPose.swift:61`, the test name at `RigLayerTreeTests.swift:264`, and the Disclosure-3 wording in the task file.
2. Routing (TASK-027 contract, blocking there): composition-order decision (MINOR-1b); crossing-tolerance or intent restatement for the no-bounce predicate (MINOR-2); settle/sleep ease-in constant + pin (MINOR-3); ear/tail bounds (8b).
3. Routing (TASK-028): prop channel wiring (8c, already disclosed).

*Reviewer scratch (probes, bite hashes) lives under /tmp/task026-review/ and is intentionally not committed.*
