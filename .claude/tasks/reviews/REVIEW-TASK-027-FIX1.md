# REVIEW-TASK-027-FIX1 — Delta Review of Fix Round 1

## Header

- **Task:** TASK-027 — deterministic idle sequencer + expression system (delta review of fix round 1, REVIEW-TASK-027 disposition items 1–6)
- **Date:** 2026-09-10
- **Reviewer:** fresh independent delta review agent (CLAUDE.md §10/§11/§33 — no fixer context; dispositions executed by a separate fresh agent)
- **Reviewed state:** working tree, uncommitted, branch `feature/EPIC-006-character`. Changeset = 27 entries (`git status --porcelain`), reconciled exactly as the original review's 22 + ADR-010/011/012 + `MomoIdleResumeTests.swift` (new) + `REVIEW-TASK-027.md` — no stray files, nothing staged.
- **Mandate:** verify each disposition item independently and attack the fixes; do not trust the fixer's self-report. Mutation bites with restoration proof; full suite before and after.

## Verdict

**APPROVED_WITH_MINOR_NOTES**

All six disposition items were executed faithfully and the fixes hold under attack: the composed clamp is gone and the new sweep fails under a re-introduced clamp (bite 1), the resume pins fail under a broken re-anchor (bite 2), the mid-fade pin fails under a linearized envelope — and only at the quarter-fade sample, proving the fixer's dual-pin deviation was necessary (bite 3), and both occupancy tiers fail under an inflated blink rate (bite 4). Full suite 721/72 green before and after. Two MINOR-grade documentation inaccuracies were found in the new measured-evidence records (one reproducibly wrong citation in ADR-012/the test comment/the task notes; one ADR sentence overstatement) plus one NOTE on the two stale no-op clamps the fixer itself flagged. None affects a pin, a decision's substance, or product behavior; all are one-line doc corrections that can ride with disposition housekeeping.

## Methodology

1. Read CLAUDE.md, REVIEW-TASK-027 (the findings being dispositioned), the task contract's disposition section, the fixer's "Fix Round 1" Implementation Notes + Handoff, ADR-010/011/012, and 04 §3.1/§3.2/§5.3/§7.1/§7.2 as the adjudicating doc text.
2. Read the fix sites line-by-line: `RigMotionModel.swift` (write site + composition), `MomoCurves.swift` (rewritten docs; constants verified untouched against the raw-literal pins), `MomoRigView.swift` (header), `MomoExpressions.swift` (pre-clamp path), `CharacterClock.swift` (resume semantics vs ADR-010), all three new/restructured test files.
3. Independently re-derived the blast radius of the unclamp by grep: `clampedPostureScaleY` is now referenced ONLY by the expression layer (`MomoExpressions.swift:357`); `postureScaleYRange` appears only in `MomoCurves` itself, the expression-layer audit (`MomoExpressionTests.swift:259`), the raw-constant/function pins (`MomoCurvesTask027Tests.swift:130,146-148`), and the new non-vacuity pins + two stale wraps in `MomoIdleRenderTests`.
4. Built a reviewer-owned probe package (`/tmp/momo_delta_probe`, never committed) driving the real `RigMotionModel`/`MomoIdleSequencer`/`CharacterClock` through the shipped code paths, with an INDEPENDENT analytic (own sine formula, not `MomoCurves.breathScaleY`) so it cannot restate a bug.
5. Four mutation bites; three with sha256 byte-identity proof, one (bite 4c) with exact-reverse-edit + zero-marker grep + full behavioral-fingerprint proof (disclosed below).
6. Full `swift test` before the bites and after restoration; `git status --porcelain` before and after (27 entries both times).
7. Test-count ledger reconciliation as isolation evidence for the fix round's file scope (716 → 721 = +2 resume +1 sweep +1 mid-fade +1 occupancy split, exactly).

## Disposition-item verification

### Item 1 (MAJOR-1 — composed clamp removed, ADR-011) — VERIFIED, binds

- **Clamp gone:** `RigMotionModel.swift:148` writes `pose.body.scaleY = CGFloat(bodyScaleY)` with no clamp; the gated block (:141-149) and the type header (:18-20) state the ADR-011 law. No other body-scaleY write path exists (the variant renderer accumulates into the same `bodyScaleY` before the single write).
- **Pre-clamp is real:** `MomoExpressions.swift:357-358` applies `clampedPostureScaleY` to the band base × exhausted overlay, and the clamp genuinely binds in the shipped table (Low+exhausted 0.95 × 0.97 = 0.9215 → 0.95), so the expression-layer band is load-bearing, not decorative. §3.1's band therefore still holds wherever the doc states it.
- **The sweep's analytic mirrors the model exactly, keyed identically:** `analyticBodyScaleY` (`MomoIdleRenderTests.swift:329-338`) keys the −30 % asleep reduction off `display.wakefulness == .asleep` — the same predicate the model uses (`RigMotionModel.swift:68`) — and consumes the same expression object's posture/cycle/amplitude. Keying drift (e.g., drowsy-awake reduction) would diverge and fail. Vacuity is blocked three ways: (a) the analytic is test-side, so any model-side clamp diverges; (b) battery-level non-vacuity counters (`:424-425`) require BOTH band edges to be exercised (my probe: 12 top-exit and 32 bottom-exit rows of 64); (c) per-row non-vacuity (`:404-415`) requires the render to follow the analytic out of the band wherever it goes.
- **Independent numeric confirmation (own sine math, 1440 samples/cycle × 64 rows):** worst deviation rendered-vs-analytic = **0.0**, zero flat samples, per-row extremes equal; Joyful/awake analytic peak 1.05266 = 1.03 × 1.022; Joyful-asleep peak(1.8) = **1.045862** and trough(5.4) = **1.014138**, matching the rewritten pins digit-for-digit (`MomoIdleRenderTests.swift:307-316`), with the non-vacuity pin `> 1.03` (:318) impossible under the old clamp.
- **Bite 1 (restore the product clamp):** `breathSinePuritySweep` failed on ALL FOUR assertion classes — diverged at sample 1, `flatSamples = 360` (exactly the 50 % flat half-cycle the original review measured), extremes mismatch, band-top non-vacuity — and `asleepRenders` failed both its peak pin (:308) and non-vacuity pin (:318). The sweep would not pass vacuously if the clamp returned.
- **Other write paths checked:** `cheekPressRestRenders` (:227) and `alivenessFloor` (:456-459) still wrap expectations in `clampedPostureScaleY` — under bite 1 they REMAINED GREEN, proving they are blind no-ops at Content (see NOTE-B; they are not wrong, just stale). `RigMotionModelTests`' pins (t = 0 equality; peak 1 + amplitude; the > 1.0 / < 1.0 inequalities) all hold unclamped — the full suite is green, and none of them referenced the model-side clamp.

### Item 2 (MAJOR-2 — ADR-010 + MomoIdleResumeTests) — VERIFIED, pins match the ADR and bind

ADR-010's five executable semantics each map to an assertion, none weaker than claimed:

1. *Pause ⇒ elapsed 0, stays 0 across the gap* — `MomoIdleResumeTests.swift:30-32` (checked after a 120 s wall advance).
2. *Resume restarts from 0; real-time only; no dwell debt* — :34-40 (elapsed 0 at resume; +3 s wall ⇒ elapsed 3, not 123).
3. *Regeneration byte-identical from the unchanged seed* — :62-66 (`resumedLog == freshLog`, field-wise equality over a pure function).
4. *Replay burst-free* — :71-73 (distinct starts; every start > 0; nothing admitted at the resume instant).
5. *Pose equivalence* — :79-86 (20 sampled instants, pose at resumed t == fresh-run pose at the same timeline t).

Bite 2 (remove `state.resumeAnchor = timeSource.now()` from `resume()`) failed BOTH tests exactly on the ADR's predicted failure modes: resume returned elapsed 137 (the dwell carried forward — the stale fast-forward ADR-010 says zeroing prevents), the real-time pins failed at :35/:40, and pose equivalence diverged from step 1. Points 1/2/5 demonstrably bind; points 3/4 are structural (deterministic regeneration + sorted distinct starts) and asserted.

**ADR-010's adjudication is faithful to the doc's actual wording:** 04 §5.3 (`04-character-system.md:362`) in ONE sentence mandates "app-hide zeroes the CharacterClock" AND forbids "event backlog bursts — timers re-schedule, never replay"; the literal no-recurrence reading would contradict the zeroing the same sentence requires. §7.4 (`:621`, "no backlog replay") repeats the backlog sense. The over-translation ruling is correctly recorded, and the TASK-026 clock pins remain untouched and authoritative.

### Item 3 (MINOR-1 — two-tier occupancy, ADR-012) — VERIFIED with one citation correction (MINOR-A)

- **Independent re-measurement (my probe, identical metric definition, same seeds):** Content 200 seeds → mean **0.11022** / p95 **0.14188** / max **0.17004** / 4 windows > 0.15 — matches the documented 0.1102 / 0.1419 / 0.1700. Cross-state 7 × 100 → overall mean **0.11093**, max **0.23225** (joyful/energetic; worst-state mean 0.16634) — matches 0.1109 / 0.2322 / 0.1663. Per-state means reproduce to 4 decimals for all 7 states.
- **MINOR-A — the "Drowsy 0.2231" citation is wrong.** The test comment (`MomoIdleSequencerTests.swift:595`, per-state maxima list, 6th slot), ADR-012 (`:18` "Drowsy max 0.223", `:20` "Drowsy 0.223 > 0.20"), and the task-file fix notes (Item 3) all attribute max 0.2231 to a Drowsy state. Measured reality: content/drowsy AND content/exhausted max at **0.1365** — stable at 100 seeds AND 1000 seeds; every drowsy/exhausted combination (all four moods) maxes ≤ 0.1483. **0.2231 is joyful/energetic's second-highest window** at the battery's 100 seeds (top-5: 0.2322, 0.2231, 0.2069, 0.2057, 0.2054) — a transcription slip onto the wrong state. The PIN is unaffected and in fact safer (the cited state sits far below the ceiling), and the falsification story stands on Joyful 0.2322 alone, which I reproduced; but three documents currently carry false measured evidence and should get a one-line correction at disposition.
- **Was the restructure necessary?** A strict single ≤ 0.15-max battery would fail on the shipped sequencer (0.1700 > 0.15; 4/200 windows) — yes, the doc-exact Content tier (mean AND p95 ≤ 0.15, satisfied with margin: 0.110/0.142) plus a disclosed authored ceiling is the honest structure. The cross-state battery is NEW coverage the original battery never had.
- **Batteries have teeth (bite 4):** halving the blink interval (6 → 3 s) failed BOTH tiers — Content p95 0.1822 > 0.15 (`:552`) and cross-state max 0.2599 > 0.25 (`:602`) — so neither pin is decorative, and the 0.25 ceiling is genuinely reachable by plausible drift (~0.018 above the measured max).

### Item 4 (MINOR-2 — RT-7 note) — VERIFIED

One-line record present in the task file's Fix Round 1 notes (Item 4): the hand-built fully-loaded pose dominates any sampled-log-time probe (every channel at once vs a subset), letter-vs-substance, no code change. Matches the disposition's ask.

### Item 5 (NOTE-3 — mid-fade pin) — VERIFIED, dual-pin deviation vindicated

`weightShiftMidFadeTracksTheEnvelope` (:185-203) pins the crossfade family's envelope at the midpoint AND quarter-fade. Arithmetic verified: smoothstep(0.25) = 0.0625 × 2.5 = **0.15625** vs linear 0.25 → expected translation 1.25 vs 2.0. **Bite 3 (linearize `envelopeProgress`) failed ONLY this test and ONLY at the quarter sample** (rendered 2.0/0.625 vs expected 1.25/0.390625); the midpoint assertions PASSED (smoothstep(0.5) = linear(0.5) = 0.5) — experimental proof that the disposition's letter ("one mid-fade pin") would NOT have caught a linear-fade regression, and the fixer's added quarter point was necessary, not gold-plating. Since gaze/yawn/crossfade variants all consume the same `envelopeProgress`, the pin guards the family.

### Item 6 (NOTE-4 — MomoRigView header) — VERIFIED

Header now reads "a stopped clock zeroes the timeline, freezing the character at the t = 0 unaged band pose — the band expression base with every motion channel at rest", which matches the clock's actual behavior (`CharacterClock.swift:73-77`: stopped ⇒ elapsed 0 ⇒ pose(0)). The carried AOD/glyph sentence ("the glyph tier's stillness IS the AOD posture") survives: on AOD the clock is paused, so every tier renders the same t = 0 pose — glyph stillness and AOD posture are literally the same rendering. The fixer's re-read is correct.

### The ADRs as records

- **ADR-011:** accurate. Every Consequence clause checks against the code (unclamped write; header states the law; curves docs rewritten — constants verified unchanged against the raw pins; sweep pins the law bitwise; expression-layer pins untouched and green). Alternatives are honestly costed (the composed-clamp option cites the actual review finding; re-authoring and the exception option are correctly rejected). No overclaims found.
- **ADR-010:** accurate; see Item 2 above. The superseded contract clause is explicitly recorded as an over-translation with the doc-faithful reading.
- **ADR-012:** candidly records the falsified provisional ≤ 0.20 ceiling and why pinning it anyway would have shipped a flaky test — verified: my measurement reproduces the falsification (Joyful 0.2322 > 0.20). Two inaccuracies: the Drowsy citation (MINOR-A above) and the "Every tier member stays ≥ 0.05" sentence — the executable pin is the AGGREGATE battery mean ≥ 0.05 (`:604`, `:559`), not a per-member floor, so a future zero-occupancy state would not be caught (NOTE-A; descriptively true of today's measurement, weakest state mean 0.0731).

## Regression

- **Before bites:** `swift test` → **721 tests / 72 suites passed, exit 0** (matches the fixer's claim).
- **After all bites restored:** `swift test` → **721 tests / 72 suites passed, exit 0** — identical.
- **Fix-round file scope:** the +5 tests / +1 suite delta reconciles EXACTLY with the claimed additions (+2 resume, +1 sweep, +1 mid-fade, +1 occupancy split); any other test change anywhere would break the arithmetic. The three TASK-026-era test file diffs vs HEAD contain only the already-reviewed TASK-027-era changes (`CharacterClockTests` moved pause pin, `RigMotionModelTests` expression-base renames, `RigDisciplineTests` 11→13 scanner extension) — no unreviewed hunks. Sources outside the sanctioned fix set (`CharacterClock`, `RigLayerTree`, `RigPose`) diff only with their reviewed TASK-027-era content.
- **Hygiene:** zero TODO/FIXME/HACK/TEMP and zero hex literals in the new sources; `git status --porcelain` unchanged at 27 entries before/after the bites.

## Mutation-bite log

Bites applied to the working tree, tested, restored. sha256 (`shasum -a 256`) recorded before/after; restoration by `cp` from a pre-bite copy (never `git checkout` — the changeset is uncommitted).

| # | File | Mutation | Result | sha256 before | sha256 after | Identical |
|---|------|----------|--------|---------------|--------------|-----------|
| 1 | `Sources/MomoCharacter/RigMotionModel.swift` | re-introduce the composed clamp at the write site (`clampedPostureScaleY(bodyScaleY)`) | `breathSinePuritySweep` fails 4 assertion classes (diverged / flatSamples 360 / extremes / band-top non-vacuity) + `asleepRenders` fails :308 and :318; `cheekPressRestRenders`/`alivenessFloor` stay green (proving those wraps are blind no-ops) | `4ac0d5820d554e8e612442f90d7afc4c76d13c4433688a872c927a2b1261ec16` | `4ac0d5820d554e8e612442f90d7afc4c76d13c4433688a872c927a2b1261ec16` | YES |
| 2 | `Sources/MomoCharacter/CharacterClock.swift` | remove the re-anchor in `resume()` | both `MomoIdleResumeTests` fail exactly on the ADR-010 failure modes (resume at elapsed 137 ≠ 0; timeline 138.5… vs 1.5…; pose equivalence diverges) | `5889fa9a3f81a53bb1ee998c5b1ca12f0023ca08b179f844f4c4debb47fc7ecd` | `5889fa9a3f81a53bb1ee998c5b1ca12f0023ca08b179f844f4c4debb47fc7ecd` | YES |
| 3 | `Sources/MomoCharacter/RigMotionModel.swift` | linearize `envelopeProgress` (in and out) | ONLY `weightShiftMidFadeTracksTheEnvelope` fails, ONLY at the quarter sample (2.0 vs 1.25; 0.625 vs 0.390625) — midpoint assertions pass, proving the quarter pin is the one with teeth | `4ac0d5820d554e8e612442f90d7afc4c76d13c4433688a872c927a2b1261ec16` | `4ac0d5820d554e8e612442f90d7afc4c76d13c4433688a872c927a2b1261ec16` | YES |
| 4a/4b | `Sources/MomoCharacter/MomoExpressions.swift` | `energeticVariantIntervalMultiplier` 1/1.5 → 1/1.2, then 1/2.0 | batteries STAYED green; probe: joyful/energetic max moves only 0.2322 → 0.2368 at ×2 — variants are a minor occupancy share (calibration evidence, see open question 2) | `92902afbdcbb12e31b0a2aab40b2041d748d882e663bb0255d6cf71d1c40380c` | `92902afbdcbb12e31b0a2aab40b2041d748d882e663bb0255d6cf71d1c40380c` | YES |
| 4c | `Sources/MomoCharacter/MomoIdleSequencer.swift` | `blinkIntervalMeanSeconds` 6.0 → 3.0 | BOTH occupancy tiers fail (Content p95 0.1822 > 0.15 at `:552`; cross-state max 0.2599 > 0.25 at `:602`) — the battery pins bind | not recorded pre-bite (protocol deviation, disclosed) | restored by exact reverse edit | see below |

**Bite 4c restoration proof (deviation from the sha protocol, disclosed):** the pre-bite hash was not captured before the sed edit. Restoration was proven instead by (a) exact reverse edit to the verbatim original line (known from this review's earlier grep: `public static let blinkIntervalMeanSeconds: Double = 6.0` at `:22`), (b) `grep -rn "BITE" Sources/ Tests/` → 0 hits, and (c) full behavioral fingerprint equality — the probe re-run reproduced the pre-bite Content mean/p95/max (0.11021734773221452 / 0.14187866165812965 / 0.17004182560838307), cross-state mean/max (0.11093420801364903 / 0.23224981425492963), and sweep (worstDeviation 0.0, flatSamples 0) to full Double precision, and the full suite returned to exactly 721/721 green.

## Findings

### MINOR-A — "Drowsy max 0.2231" measured-evidence citation is a mis-attribution (three documents)

- **Where:** `Tests/MomoCharacterTests/MomoIdleSequencerTests.swift:595` (per-state maxima list, 6th slot); `.claude/tasks/decisions/ADR-012-occupancy-budget-tiers.md:18,20` ("Drowsy max 0.223"); task file Fix Round 1 notes, Item 3 ("Drowsy 0.2231").
- **What's wrong:** no battery state measures 0.2231. content/drowsy and content/exhausted max at 0.1365 (stable across 100 and 1000 seeds; all four moods' drowsy/exhausted rows ≤ 0.1483). 0.2231 is joyful/energetic's runner-up window (my top-5 extraction) — a transcription slip.
- **Impact:** none on the pins (drowsy sits far below the 0.25 ceiling; the falsification of the provisional ≤ 0.20 stands on Joyful 0.2322, reproduced), but the ADR and test comment carry false measured evidence, which matters for a document whose entire purpose is honest measurement.
- **Suggested fix:** one-line correction in ADR-012 + the test comment at disposition housekeeping, e.g. "worst single run 0.232 (Joyful; runner-up 0.223; Drowsy max 0.137)".

### NOTE-A — ADR-012's "Every tier member stays ≥ 0.05" overstates the executable pin

The pinned non-vacuity guard is the AGGREGATE battery mean ≥ 0.05 (`MomoIdleSequencerTests.swift:559,604`), not a per-state floor. Descriptively true today (weakest state mean 0.0731), but the sentence claims a per-member guarantee the pins do not enforce. Reword to "the battery's mean stays ≥ 0.05" or add per-state floors if per-member protection is wanted.

### NOTE-B — the two known-stale no-op wraps (fixer-flagged; orchestrator's open question 1)

`cheekPressRestRenders` (:227) and `alivenessFloor` (:456-459) wrap expectations in `clampedPostureScaleY`, a bitwise no-op at Content. Bite 1 proved they cannot detect a restored clamp — they are harmless to correctness but misleading against ADR-011's "never re-clamped here" narrative (a reader may infer a model-path clamp exists). Judgment: leave them in this round (the disposition sanctioned only two existing-test edits; a third unsanctioned edit would be worse than the smell), clean them in the next housekeeping pass alongside MINOR-A.

**No CRITICAL or MAJOR findings. No regressions found.**

## Open-question judgments (orchestrator's questions, answered independently)

1. **The stale wraps (above, NOTE-B):** harmless-but-stale; do NOT spend a fix round on them — batch with housekeeping. They were disclosed by the fixer proactively, which is the disclosure working as intended.
2. **ADR-012's cross-state max ≤ 0.25 — right calibration, keep it; do NOT tighten subranges this task.** Three independent lines of evidence: (a) the busyness of joyful/energetic is driven by DOC-authored rows — blink N(6,2) (§7.1), tempo ×0.8 (§3.2 "idle events more frequent"), variant frequency ÷1.5 (§3.3) — while bites 4a/4b showed the task-authored variant scheduler barely moves occupancy (max +0.005 at 2× frequency), so tightening authored subranges could not bring Joyful under 0.20 without fighting doc rows; (b) the ceiling is neither decorative nor tight: measured max 0.2322 (margin 0.018), 1000-seed tail 0.2367 (still under), and a halved blink rate trips it at 0.2599 — it guards real drift; (c) §5.3 scopes its floor to Content/baseline, where the doc-exact tier holds with margin, and §3.2/§3.3 author livelier non-baseline states. A "23 % motion window for joyful/energetic" is calm-by-budget under ADR-012's own framing, and the disposition's ADR-over-churn choice was the only doc-faithful option. Recommend only the MINOR-A citation correction so the record matches the measurements.

## Test results

- **Baseline (pre-bite):** `swift test` → 721 tests / 72 suites passed, exit 0.
- **Post-restoration:** `swift test` → 721 tests / 72 suites passed, exit 0 — identical counts.
- During bites (expected failures): bite 1 → sweep + asleepRenders; bite 2 → both resume tests; bite 3 → mid-fade pin only (quarter sample); bite 4c → both occupancy batteries. Bites 4a/4b → no failures (reported as calibration evidence).
- `git status --porcelain`: 27 entries before and after; nothing staged; no strays.
- stderr across runs: only the pre-existing toolchain `ld: search path '/opt/extra/lib' not found` note; zero new warnings observed (warm builds do not reprint warnings — same limitation the original review disclosed).

## What I could NOT verify

- **Byte-level isolation of the fix round inside the three TASK-026-era test files** — no pre-fix snapshot exists and the changeset is uncommitted. Evidence is the exact 716 → 721 ledger reconciliation plus diff content matching the original review's descriptions, not a byte proof.
- **A fully clean-build warning scan** (warm builds do not reprint warnings) — inherited limitation from REVIEW-TASK-027.
- **On-device rendering / product feel**: the unclamped breath peaks (Joyful awake ~1.0527, asleep ~1.0459) satisfy the ADR-011 law and the sweep, but whether the +2.2 % peak "reads as breath" (§7.1's own quality bar) needs a human eye in a SwiftUI preview; device-level scenePhase/AOD observation routes to EPIC-007/008 per the view's authority split.
- **The provenance of "0.2231" as a transcription slip** is inferred (it is joyful/energetic's runner-up; no measured state matches), not reconstructed from the fixer's session.

## Recommended disposition (for the orchestrator — not executed by this reviewer)

1. Commit and push the task per §12/§13 (verdict permits commit; review status APPROVED_WITH_MINOR_NOTES).
2. Ride-along doc corrections (housekeeping, no code): MINOR-A (ADR-012 `:18,20` + test comment `:595` + task-file Item 3 — Drowsy 0.1365, runner-up 0.2231), NOTE-A (ADR-012 aggregate-mean wording), NOTE-B (de-wrap the two stale expectations in a later test-touching task).
3. Record in status.md that ADR-013 is the next free ADR number (the disposition's renumbering note) and that the fix round's two deviations (dual mid-fade pin; measured 0.25 tier) were both vindicated by this review's bites.
