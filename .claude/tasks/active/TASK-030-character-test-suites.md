# TASK-030 — Character test suites: MomoCharacterTests audit + determinism-property coverage record + art-budget recording (05 §10.1–10.2; delivery plan TASK-030)

## Parent Epic
EPIC-006 — Character Rendering (MomoCharacter), task 6 of 6 (size S) — the EPIC CLOSER. Epic acceptance criteria served: AC-6 (`MomoCharacterTests` green via `swift test`; sequencer/pause/RM pure parts fully determinism-property covered per 05 §10.2; **art budgets recorded against §8.3**) plus the audit that AC-1–AC-5's test-visible claims each resolve to a named, actually-green test. Follows the TASK-024 precedent (Kit's matrix audit + coverage floor) and the TASK-020 precedent (Core's matrix audit), applied to Character — **without a coverage floor** (see Objective).

## Objective
Close EPIC-006's test obligations (delivery-plan TASK-030 row: "Sequencer determinism properties, pause discipline, RM pose mapping fully covered; pure files 100 % determinism-property covered per 05 §10.2"; 05 §10.1 MomoCharacterTests target row: "idle sequencer determinism, Reduce Motion pose mapping (pure files)"):

1. **Audit table A — sequencer determinism (04 §5.1–5.3, §9.4; 05 §10.2):** every determinism clause of the idle sequencer resolves to named, green tests — the property (identical `(idleSeed, timeline)` ⇒ identical event log), the meta-determinism property over bounded seeded randomized timelines (05 §10.2's definition), the §5.2 scheduler parameters (every authored interval/subrange inside its doc band, pinned), the §5.3 aliveness-floor fallback, and schedule purity (FR-4 AC-1).
2. **Audit table B — clock pause/resume (04 §7.4, §9.5; epic AC-2 / rig rule R3):** the single `CharacterClock` gating L0–L4, every channel independently pausable, zero-on-pause/resume-from-zero, the one-call scenePhase/AOD zeroing, and the glyph tier's never-binds-the-clock posture — each resolves to named green tests.
3. **Audit table C — Reduce Motion pose mapping (04 §7.3, §3.5):** "fully covered" means EVERY §7.3 binding-table row (idle loop, blink, look-around, state changes, touch reactions, celebrations, waking/settling, playing, plus the §7.3 closing never-removes-information law and the §3.5 grayscale-legibility clause) resolves to named green tests.
4. **Audit table D — reaction duration bounds + curves (04 §7.1, §7.2; §6.3):** every character-owned duration in the §7.1 master timing table resolves to a named test pinning it (and where a value is AUTHORED inside a doc band, the pin names the band + the authored digit); the §7.2 curve laws (incl. the executable no-bounce rule); §6.3 play-round character-side pacing inside UX-3's ≤ 30 s shell.
5. **Audit table E — geometry pins (04 §2.1; ADR-001; epic Test Requirements):** geometry pins over the §2.1 normalized grid — Direction-C landmarks measurable from the exported data (TASK-025's generated constants), the ADR-001 ear rule (≥ 12 % of body width **at base**), and the §2.1 LOD stage-size bands (220–280 / 60–80 / 24–32 pt) resolving to named green tests.
6. **Pure-file determinism-property coverage record (05 §10.2; the delivery-plan TASK-030 row's "100 %" clause):** enumerate the PURE logic files of `Sources/MomoCharacter` (the sequencer/random/events/variants layer, curves, expression system, rig motion model + channel/pose/layer-tree/LOD data, reaction clips/clip-motion/director/state/overlay motion, handshake choreography, moments, RM mapping, clock) and record for EACH the determinism property or twin-equality property that covers it (named tests). View files (`MomoRigView.swift`) are NOT pure — the record must say so explicitly rather than dodge; the §10.2 property (identical inputs ⇒ byte-identical outcome, bounded seeded) is the standard applied to the pure files, and the record is honest where a file's determinism rests on a twin corpus versus an analytic pin. **This record replaces a coverage floor: NO MomoCharacter line-coverage floor exists** — 05 §10.2's floors are MomoCore ≥ 90 % and MomoKit ≥ 80 %, both already recorded (TASK-020: 97.68 %; TASK-024: 88.86 %). Do NOT run or record a MomoCharacter llvm-cov number; do not invent a floor.
7. **Art budgets recorded against §8.3 (epic AC-6):** re-measure the rig bucket (`MomoRig+*.swift` generated constants), room+props bucket (`MomoRoom.swift` + `MomoProps.swift`), total art contribution (`Sources/MomoCharacter/` sources total), against §8.3's budgets (≤ 300 KB / ≤ 250 KB / ≤ 1.5 MB target). Byte counts via exact `getsize`-style measurement (never `du -k` — it inflates). Record basis notes: the hand-written `MomoRig.swift` anchor sits outside the rig bucket (O8 convention); the budgets compare SOURCE BYTES as TASK-025 recorded.

**This is an AUDIT-and-record task, not a rewrite.** TASK-025–029 landed extensive suites (34 suites in `Tests/MomoCharacterTests/`); the implementer's first job is a VERIFIED GAP ANALYSIS with the TASK-024 adversarial standard: **a named test COUNTS only if reading its body shows it actually pins that row's clause** — a test that touches the area without pinning the clause does not count; find or write the one that does. Expect to write few or zero new tests; every new test must close a named gap from the audit tables, never pad a count.

## Context
- **Codebase state:** TASK-029 complete (`9a46641`) + its closeout housekeeping (`a249913`). Branch `feature/EPIC-006-character`, HEAD `a249913`. **Baseline `swift test` = 824 tests / 82 suites green — pinned at dispatch.** All 40 `Sources/MomoCharacter/*.swift` files landed; the character pipeline (`Tools/character-pipeline/`) and its evidence PNGs are TASK-025 artifacts.
- **Normative mapping (re-derive from these; do not take this list on faith):** the delivery-plan TASK-030 row (`docs/product/06-delivery-plan.md`, EPIC-006 table); the delivery-plan §-coverage table's EPIC-006 row ("Domain: deterministic randomness (sequencer); UI-support: pause/RM behaviors (pure parts) → MomoCharacterTests → Sequencer logic fully covered by determinism properties"); 05 §10.1 (MomoCharacterTests target row) + §10.2 (coverage policy, determinism-property definition); the EPIC-006 epic file's Test Requirements + AC-6; project.md §32's Domain row "deterministic randomness" (the epic file's "§32 rendering row" phrasing is shorthand for the delivery-plan coverage-table mapping — project.md §32 itself has no rendering row; use the delivery-plan coverage table as the authoritative mapping and do NOT edit the epic or docs).
- **Where the clauses already live (audit STARTING points — verify each body, do not trust this list):**
  - Sequencer determinism + §5.2 parameter pins + resume discipline → `MomoIdleSequencerTests`, `MomoIdleRandomTests`, `MomoIdleResumeTests` (ADR-010), `MomoIdleRenderTests` (incl. the §5.3 aliveness-floor + ADR-012 occupancy budgets), `MomoCurvesTask027Tests`.
  - Clock/pause → `CharacterClockTests`, `RigDisciplineTests` (the ONE-clock + glyph-tier-never-binds scoping pins), `R1CompositionTests` (ADR-009), `MomoIdleResumeTests` (ADR-010 end-to-end).
  - RM mapping → `MomoReduceMotionMappingTests`, `MomoReduceMotionTwinTests` (fold/R15 law over the corpus), `MomoReduceMotionEndPoseTests` (R6 press law + end-pose partition).
  - Duration bounds/curves → `MomoCurveRulesTests`, `MomoCurvesTask027Tests` (§7.2 + no-bounce), `MomoReactionClipTests` (per-clip durations, tempo scope, pressReleaseSeconds), `MomoReactionDirectorTests` + `MomoHandshakeTests` (choreography durations 3.0/2.0, play pacer ≤ 30 s shell), `MomoMomentTests`.
  - Geometry → `MomoRigGeometryTests` (§2.1 grid + ADR-001 at-base ear rule), `MomoRigInventoryTests` (part/naming inventory), `MomoRigVariantsTests` (LOD-glance/glyph variants + winding/seam pins), `MomoGeneratedDisciplineTests`, `MomoPipelineReproducibilityTests` (AC-1 reproducibility), `MomoArtBudgetTests` (§8.3 budgets as an in-suite test).
  - Twin/meta-determinism properties → `MomoReactionTwinTests`, `MomoReduceMotionTwinTests` (whole-trajectory fold equality); the sequencer's determinism properties live in the Idle suites.
- **Known candidates to evaluate (candidates, not conclusions — verify before acting):** whether the §7.1 table has any character-owned duration row with NO named pin (the strongest expected gap shape — TASK-026–029 pinned their OWN constants, but the audit is against the DOC table); whether every pure file's determinism claim has a named test (e.g. `MomoExpressions`/`MomoIdleVariants`/`RigPose`/`RigChannel`/`RigLayerTree` data files — a pure data file covered by the same properties as its consumers counts, but the record must say WHICH property and WHERE); whether §3.5 grayscale has a named test anchor beyond the TASK-029 evidence harness (the committed PNGs + `MomoArtBudgetTests`-adjacent in-suite checks vs an actual named grayscale test — the epic clause says "grayscale legibility per §3.5 is verified per expression state").
- **House discipline:** any new test file follows the conventions (`@Test`/`#expect`, seeded bounded properties, fixtures in `Support/`, no ambient reads); the standing scans (`RigDisciplineTests` + token/copy/generated discipline) must stay green with NO new exemptions; no `Sources/MomoCore/` or `Sources/MomoKit/` changes; **production diff expected EMPTY** — any production touch is a DISCLOSURE with justification. No doc changes (doc-chain notes route to the orchestrator's backlog, never edited by this task). The TASK-029 Disclosures register in `MomoReduceMotion.swift` is the RM authority — do not restate or edit it.

## Requirements
1. **Audit tables A–E** (one per clause area above): for each row — the clause restated from the docs (with the doc section cited), the named green test(s) that pin it (suite file + test name), and the pin verification (one line: what would break if the clause regressed). Gaps close with named tests. Every named test's BODY read, not existence-grepped.
2. **Pure-file determinism-property coverage record:** the file-by-file table over the pure logic files of `Sources/MomoCharacter` — for each: the covering determinism/twin property (named tests + suite), and an honest one-line statement of the guarantee shape (analytic pin / twin corpus over seeded streams / structural scoping pin). View files explicitly excluded with the reason. This table is the deliverable that satisfies "pure files 100 % determinism-property covered per 05 §10.2" — it must cover EVERY pure file or honestly declare why a file needs no property (e.g. constants-only data with no behavior; say which suite pins its values).
3. **Art budgets table:** §8.3 budget rows × measured bytes (exact byte counts, the O8 basis note included), verdict per row, recorded in Completion Evidence in TASK-025's format.
4. **No scope creep:** no production changes unless a gap genuinely requires one (then DISCLOSURE + justification — expected: none); no coverage-floor invention; no doc edits; no test weakened, deleted, or skipped to make the audit clean — that is a BLOCKED-level finding; no new scan exemptions; no TODO/FIXME/HACK/TEMP debt (§26).
5. **Suite hygiene:** final `swift test` green ×2 with zero warnings; exact counts recorded; suite runtime stays bounded (no new unbounded loops; any new property test is seeded and bounded per house discipline).

## Files / Areas Likely Affected
- Possibly NEW `Tests/MomoCharacterTests/` files for named gap closures and small additions to existing suites (expected: few or none).
- This task file (audit tables + record + budgets in Implementation Notes / Completion Evidence).
- NOT affected: `Sources/MomoCharacter/` (expected diff EMPTY), `Sources/MomoCore/` (must stay EMPTY), `Sources/MomoKit/` (must stay EMPTY), `Apps/`, `Tools/` (evidence harnesses are TASK-025/029 artifacts — do not re-render PNGs; the committed evidence is byte-stable), docs, `.claude/` orchestration files other than this task file.

## Dependencies
- TASK-025…029 (all landed and pushed on `feature/EPIC-006-character`; baseline `a249913`).

## Constraints
- Fresh agent (Jupiter — omit any model override), no commit rights; house 200–400-line file discipline for any new test file; scans green, no new exemptions; baseline count pinned at dispatch (824/82 @ `a249913`); work uncommitted on the branch, tree left DIRTY for the orchestrator.
- The audit tables and the coverage record are EVIDENCE, not code — the reviewer re-derives them from the docs independently.

## Acceptance Criteria
1. Audit tables A–E complete: every clause of each area → named green tests with pin-verification lines; gaps (if any) closed and named.
2. Pure-file determinism-property coverage record complete: every pure `Sources/MomoCharacter` file covered or honestly dispositioned; view files explicitly excluded with reasons.
3. Art budgets table complete: measured bytes vs §8.3 budgets, verdicts recorded (epic AC-6).
4. Final `swift test` green ×2, zero warnings, standing scans green with no new exemptions.
5. Production diff EMPTY (or disclosed + justified); `Sources/MomoCore/` + `Sources/MomoKit/` diffs EMPTY; no doc changes.

## Required Tests
- The audit's closing tests (only those the gap analysis justifies — expected: possibly one §3.5-grayscale named-test anchor and/or any unpinned §7.1 duration row; the audit decides, the contract does not).
- The budget re-measurement (measurement, not a test).

## Review Requirements
- Independent fresh reviewer (CLAUDE.md §10/§33), adversarial, unprimed:
  - Re-derive ALL audit tables (A–E) and the pure-file coverage record from 04 §2.1/§3.5/§5–§7/§8.3/§9.4–9.5, 05 §10.1–10.2, the delivery-plan TASK-030 row + coverage table, and ADR-001 BEFORE comparing to the implementer's tables; name any clause the tables miss or map to a test that does not actually pin it (bodies read, not existence-grepped).
  - Verify the budget table by re-running the byte measurement; reject any number that cannot be reproduced.
  - Mutation-bite the audit's central claim: pick ONE audit-mapped clause, apply a small mutation to the production code it pins, and verify the named test ACTUALLY fails (the audit counts only if the mapping is executable truth). Restore byte-identical (record sha256 before/after).
  - Verify the suite is green ×2 and the scans carry no new exemptions.
  - Verify `git diff` scope: production EMPTY-or-disclosed; MomoCore/MomoKit EMPTY; no doc changes; no `.claude/` touches beyond this task file.
  - Review file: `.claude/tasks/reviews/REVIEW-TASK-030.md`.

## Git Requirements
- No commit by the implementation agent. Orchestrator commits after review disposition: `test(character): TASK-030 character suite audit + determinism-property coverage record` — atomic, TASK-ID included.
- This is the EPIC-006 closer: after this task's housekeeping, the epic merges to `main` per CLAUDE.md §14 (owner-authorized, no PR; `git fetch` + check `origin/main` FIRST — the owner may have PR-merged mid-epic, the EPIC-004 precedent; merge only the remainder; never force-push).

## Status
IN_REVIEW — implementation complete (2026-09-10), tree left DIRTY and unstaged per contract (no commit/push by the implementation agent). Audit done: **1 named gap found and closed (the §3.5 grayscale anchor); zero §7.1 gaps**; production diff EMPTY; suite green ×2 at **825 tests / 82 suites, zero warnings**. REVIEW-TASK-030: **APPROVED_WITH_MINOR_NOTES** (2026-09-10; 2 MINOR + 3 NOTE — all record-accuracy, none behavioral; every finding verified personally by the orchestrator and dispositioned, see Reviewer Findings). (Was READY — contract materialized 2026-09-10; baseline pinned at dispatch: 824 tests / 82 suites green @ `7174048`, the contract commit on top of the TASK-029 closeout `a249913`.)

## Implementation Notes
Implemented by the fresh TASK-030 agent (2026-09-10). Method as contracted: the audit matrix was re-derived from the docs FIRST (04 §2.1, §3.2–3.5, §4.3, §5.1–5.3, §6.1–6.3, §7.1–7.4, §8.3–8.5, §9.4–9.5; 05 §10.1–10.2; the delivery-plan TASK-030 row + coverage table; ADR-001; ADR-009/010/011/012 as recorded interpretations), then EVERY named test's BODY was read (all 34 suite files under `Tests/MomoCharacterTests/`, plus `Support/`) — no existence-greps. Baseline verified pre-work: `swift test` = 824/82 green @ clean `7174048` (log `/tmp/task030_baseline_run1.log`, "passed after 2.382 seconds").

### Run history (exact counts/timings)
| Run | When | Tree | Result | Log |
|---|---|---|---|---|
| 1 (baseline) | 2026-09-10, pre-work | clean `7174048` | **824 tests / 82 suites passed** after 2.382 s | `/tmp/task030_baseline_run1.log` |
| 2 | post-gap-closure | dirty (task work) | **825 tests / 82 suites passed** after 1.436 s, 0 warnings | `/tmp/task030_run2.log` |
| 3 (green ×2) | post-gap-closure | dirty (task work) | **825 tests / 82 suites passed** after 1.442 s, 0 warnings | `/tmp/task030_run3.log` |

Delta vs baseline: **+1 test** (the §3.5 anchor below), same 82 suites. No test weakened, deleted, or skipped; no new scan exemptions; no TODO/FIXME/HACK/TEMP introduced.

### Audit table A — sequencer determinism (04 §5.1–5.3, §9.4; 05 §10.2)
| # | Clause (doc cite) | Named pin(s) | Pin verification (what breaks) |
|---|---|---|---|
| A1 | Property: identical `(idleSeed, timeline)` ⇒ identical event log (§5.1, §9.4; 05 §10.2) | `MomoIdleSequencerTests` — determinism battery, 25 seeds × 6 states, equal whole logs | Any unseeded draw entering scheduling/payload selection yields divergent logs |
| A2 | Engine injects the seed, never system randomness (§9.4) | `MomoIdleSequencerTests` seed-derived==injected + `RigDisciplineTests` idleStackIsSeededOnly (non-vacuous on `MomoIdleRandom.swift`) | `.random(`/`arc4random`/`UUID(` etc. in any of the 22 rig files fails the scan |
| A3 | 05 §10.2 meta-determinism over bounded seeded randomized timelines | A1's battery IS the bounded seeded meta-property (25 seeds, 6 states, whole-log equality); reaction/RM folds carry the twin-corpus form (`MomoReactionTwinTests`, `MomoReduceMotionTwinTests`) | Fold/overlay nondeterminism breaks twin equality over the 13-stream twin corpora (8 named streams + a 5-value hold sweep) |
| A4 | Whole-log vector pins incl. payload draws (§5.1) | `MomoIdleSequencerTests` three vectors (seeds 0/1/42), digit-for-digit | ANY scheduler or payload constant drift changes the log digits |
| A5 | Prefix property: schedule(30) is a prefix of schedule(120) (§5.1) | `MomoIdleSequencerTests` prefix test | Event existence depending on horizon breaks prefix equality |
| A6 | Window guards — every event inside its §5.2 band (§5.1/5.2) | `MomoIdleSequencerTests` window-guard test | Out-of-band event times fail |
| A7 | Non-awake schedules nothing; aliveness floor fallback (§5.1/§5.3) | `MomoIdleSequencerTests` non-awake test + `MomoIdleRenderTests` aliveness-floor test | Motion while asleep / a flatline Content render fails |
| A8 | Blink: N(6,2) clamp [2.5,12], ~12 % doubles, durations (§5.2) | `MomoIdleSequencerTests` blink battery (mean 6.0387/σ 1.9262, clamps 2.5 & 12.0 hit exactly, doubles 10–14 %, durations 0.33453) | Any blink parameter drift moves mean/σ/clamp hits |
| A9 | Drowsy intervals ×1.4 (§5.2) | `MomoIdleSequencerTests` per-interval ×1.4 (tol 1e-9, >1000 draws) | Multiplier loss fails per-interval |
| A10 | Wistful blinks ×1.2 slower (§5.2/§7.1) | `MomoIdleSequencerTests` duration ×1.2 (1e-12) + `MomoExpressionTests` blinkDurationMultiplier pin | Tempo-law regression fails |
| A11 | Look-around: 9–21 s interval, shift/return/hold bands, 5 targets, atUser bias (§5.2) | `MomoIdleSequencerTests` gaze battery (interval 15.503 authored in-band; shift 0.22–0.28, return 0.60–0.70, hold 1.5–4.0; all 5 targets; atUser 0.2528; Joyful 0.3184 = 1.2727×) | Gaze parameter drift breaks band/target/bias pins |
| A12 | Variants 14–30 s; Energetic ×1.5 frequency; Drowsy-only yawn/nod gates (§5.2) | `MomoIdleSequencerTests` variant tests (ratio 0.5067; band 16–30; calmCoexist Soul-only 0.1875; headNod Drowsy-only 0.1321; yawn Drowsy-only, 1.4 s, phases 0.45/0.5/0.45, intervals 45–90 ×1.4) | Variant gating/frequency drift fails |
| A13 | No-distraction occupancy (§5.3; ADR-012 executable form): Content mean+p95 ≤0.15/max ≤0.20; cross-state ≤0.20/≤0.25 | `MomoIdleSequencerTests` two occupancy tests | Channel-usage inflation fails the budgets |
| A14 | Arbiter budget 3, priority blink>gaze>variant (§5.3/§7.4) | `MomoIdleSequencerTests` arbiter test + battery ≤3 groups | A 4th concurrent group or inverted priority fails |
| A15 | Schedule purity (FR-4 AC-1): pure function of (seed, timeline) | A1 + `RigDisciplineTests` ambient-time scan over the idle stack | Any ambient read breaks determinism/purity |

### Audit table B — clock pause/resume (04 §7.4, §9.5; epic AC-2 / rig rule R3)
| # | Clause | Named pin(s) | Pin verification |
|---|---|---|---|
| B1 | ONE `CharacterClock` gates all layers L0–L4 (§9.5, R3) | `CharacterClockTests` (10: init stopped at zero, resume-from-zero, idempotence, elapsed(at:) purity, backward clamp) + `RigDisciplineTests` clock+view ambient-free + `R1CompositionTests` rest==identity all tiers | A second/ambient time source or partial gating fails |
| B2 | Zero-on-pause / resume-from-zero, no backlog (§9.5; ADR-010) | `CharacterClockTests` pause-zeroes/no-backlog + `MomoIdleResumeTests` (real-time replay; resumed log == fresh log byte-for-byte; no burst; poses equal) | Backlog replay or burst-on-resume fails |
| B3 | Every channel independently pausable (R3) | `RigMotionModelTests` gating battery (bodyScale-off ⇒ identity body at 6 instants; bodyScale-alone breathes; tailRotation no-op on still / real bite on wag) + `MomoReactionPropsTests` propChannelGating | Channel leakage through a closed gate fails |
| B4 | Scheduled, never polled (§7.4) | `MomoIdleSequencerTests` (schedule-driven events) + B1's ambient scan | Polling/time-source reads fail |
| B5 | One-call scenePhase/AOD zeroing (§7.4, epic AC-2) | `RigDisciplineTests` scenePhaseMapping (.active→resume; .inactive/.background→pause) + viewWiresScenePhase (structural onChange pin) | A divergent mapping or removed wiring fails |
| B6 | Glyph tier never binds the clock (§7.4; AOD branch renders `.rest`) | `RigDisciplineTests` glyphTierIsFlagFree (structural + recomputed-transforms-equal) + `RigLayerTreeTests` glyphTierOrder | Clock/flag sensitivity in the glyph path fails |

### Audit table C — Reduce Motion pose mapping (04 §7.3, §3.5)
| # | Clause (§7.3 row) | Named pin(s) | Pin verification |
|---|---|---|---|
| C1 | Idle loop → static band pose, t-invariant | `MomoReduceMotionMappingTests` R2 (+ non-vacuity) | Time-dependent static pose fails |
| C2 | Blink → never closes | R3 test | A closing RM blink fails |
| C3 | Look-around → masked (the L1 press glance IS it; flag-invariant incl. release) | R4 tests | Wander surviving RM / glance differing by flag fails |
| C4 | State changes → crossfade (authored 0.15 s, the disclosed band floor) between statics; tracker overwrite snaps to the intermediate | R5 (endpoints exact + monotone; window 5.0 opens/5.15 closes; overwrite-snap pin, TASK-029 fix) | Endpoint drift / silent overwrite / window drift fails |
| C5 | Touch reactions → end-pose swap via the SAME choreography dispatch (R6) | `MomoReduceMotionMappingTests` R6 + `MomoReduceMotionEndPoseTests` (per-key identity/expressed partition: identity tapBelly, longPress, stroke×3, stir, gentleDecline, nibble, blanketAdjust; expressed tapHead, tap, doubleTap, cheer, decline, politelyFull; press keyframes 0.8/0.45 + release boundary 5.0→6.55; short-press earned pose; abbreviated third tap; glance plateau held) | A pose RM renders differently from the dispatch's end pose fails |
| C6 | Celebrations → settled holds + greeting key instants (0.88/0.2/0.875/0.7) | R7 tests | Modal-style celebration motion under RM fails |
| C7 | Waking/settling → end-state statics; reports at unchanged 3.0/2.0 s | R8 (settle end pose 0.94 + blanket, report 4.0; wake identity + wakeFinished) | Timing change or missing end-state fails |
| C8 | Playing → milestone stills at pacer boundaries; round completes identically; drowsy yawn suppressed (DISCLOSED) | R9 (invite ears 10/tail 6; follow input-coupled; payoff cheek 0.85; swap crossfades; report 19.4) | Round-duration change under RM fails |
| C9 | Never-removes-information law (§7.3 closing) | `MomoReduceMotionTwinTests` fold-twin whole-state equality over 13 distinct streams (8 named + a 5-value hold sweep; the earlier "11 corpus + 7 adversarial" phrasing was a miscount inherited from the TASK-029 records — corrected per REVIEW-TASK-030 MINOR-2); `MomoReduceMotionEndPoseTests` R11 statics pairwise-distinct with the ONE disclosed RM-only collision (Content+Energetic == Content+Relaxed; owner-routed) | Information removed without a registered disclosure fails |
| C10 | R1 render-only: fold takes no flag; ONE ambient read = the view's | `MomoReduceMotionTwinTests` press-only flag-INVARIANCE + tracker twins + `RigDisciplineTests` accessibilityReduceMotion-only-in-view all-files scan | Flag input into the fold or a second ambient read fails |
| C11 | §3.5 grayscale legibility per expression state | **GAP CLOSED (the audit's one closure):** NEW `MomoExpressionTests` "§3.5: the §3.2–3.3 cells are pairwise distinguishable without hue" — all 16 §3.2–3.3 cells (4 moods × 4 energies, awake), 120 pairs, each pair must differ in ≥1 hue-free carrier of the composed expression (static pose: aperture/lid shape/ears/tail/posture; achromatic tempo: cycle/amplitude/interval/variant/blink multipliers; event gates: yawn/nod). Preconditions pinned elsewhere: R4 static part→token mapping (`RigLayerTreeTests.partTokenMapping`, state never by color); visual counterpart = TASK-029's committed `docs/evidence/character/rm-*.png` (cited, NOT re-rendered) | Any expression edit collapsing two cells into hue-only-distinguished fails; bite recipe for the reviewer (two-gate — a single-gate flip is INERT because the other Drowsy-only gate still separates the pair, proven by execution in REVIEW-TASK-030 MINOR-1): flip BOTH `MomoExpressions.yawnEnabled` AND `MomoExpressions.headNodEnabled` to also return true for `.exhausted` ⇒ exactly Low+Drowsy vs Low+Exhausted ties on all 12 carriers and this test fails |

### Audit table D — reaction duration bounds + curves (04 §7.1, §7.2, §6.3)
§7.1 master-table rows (each: named pin → what breaks):
| Row (value) | Named pin(s) | Verification |
|---|---|---|
| Breath Joyful 3.8–4.2 s, amp 1.5–2.5 % | `MomoCurveRulesTests` band+amplitude pins; authored 4.0/0.022 digit-pinned in `MomoExpressionTests` | Band exit or amplitude drift fails |
| Breath Content 4.6–5.2 (default) | same; authored 4.9/0.02 | same |
| Breath Wistful 5.8–6.4 | same; authored 6.1/0.017 | same |
| Breath Drowsy/asleep 6.5–8.0, ~30 % amp reduction | band pin; authored 7.2; `MomoIdleRenderTests` asleep row (−30 % amp, unclamped peak) | Sleep-amp law regression fails |
| Blink close 140–180 ms + open 100–160 ms | `MomoCurvesTask027Tests` raw rows + `MomoIdleRenderTests` blink channel (0.33453 s, half-lid law 0.7357…) | Phase timing drift fails |
| Wistful ~1.2× slower blinks | A10 | same |
| Gaze 220–320 ms out / 600–900 ms back | `MomoCurvesTask027Tests` band + A11 authored sub-bands | same |
| State crossfade 300–400 ms | `MomoCurvesTask027Tests` band + `MomoReactionDirectorTests` l2Crossfade 0.35 in-band (full motion); the RM 0.15 floor is the disclosed RM row (C4) | Crossfade outside band fails |
| Micro-event fades ≤100 ms (L1) / ≤120 ms (L3) | `MomoReactionDirectorTests` (0.1 / 0.12 pins; Rule-1 press fade sampled 2°→1°→0 across 100 ms; L3 preempt fade) | Fade-cap breach fails |
| Reactions 0.4–1.2 s | `MomoReactionClipTests` 21-key census: per-key duration digits + band membership | Any clip outside its row fails |
| Yawn 1.4 s | `MomoCurvesTask027Tests` + `MomoIdleSequencerTests` yawn (1.4 s, 3-phase) + `MomoExpressionTests` conversion pins (142/56) | same |
| Eating 2.5–4.0 s (2–3 bites) | `MomoReactionClipTests` meals band (eating 3.2, sleepyNibbles 3.5, settling 3.0) — and `.nibble` explicitly pinned < 2.5 as "the shortened eating animation" (the row's scope is exact, no gap) | Meal-length drift / nibble scope creep fails |
| Waking stretch 1.8–2.5 s | `MomoHandshakeTests` wake 2.0 (authored mid-band) + never-cancel replay-from-zero | same |
| Settling 2.5–3.5 s (yawn→lie→blanket) | `MomoHandshakeTests` settle 3.0 (authored mid-band; completes once at 4.0) + `MomoReactionPropsTests` blanket window (2.2→3.0) | same |
| Quest sparkle 0.9–1.2 s | `MomoMomentTests` 1.0 authored + exactly-once completion at the authored duration | same |
| Stage celebration 1.6–2.0 s | `MomoMomentTests` 1.8 authored + single-soft-overshoot ≤8 % trajectory | same |
| Play round 15–30 s (§6.3 pacing) | `MomoHandshakeTests` roundBound digits (invite 2.4, deadline 16.0, payoff 4.0, max 22.4) + pacer matrix (19.4 no-rest/always-moving, 17.4 rest-solo, 19.4 still-in-grace, 15.4 drowsy; baseline 12.0 exercised at the 15.4 cease in playNeverMoves) | Pacer-law or bound breach fails |
§7.2 curve rows: breathing pure sine + loop continuity + band peak (`MomoCurveRulesTests`); ear/tail damped spring ζ 0.75–0.85, soft overshoot only (`MomoCurveRulesTests` + `MomoCurvesTask027Tests` R2 predicate incl. genuine-bounce rejection, ±1 % tolerance, spring landmarks peak 1.01–1.03 @ ζ0.78); touch ease-in-out / spring ~0.35 s, overshoot ≤15 % (`MomoCurvesTask027Tests` 0.35 == touch constant + cap law); celebrations single soft overshoot ≤8 %, NO bouncing loops (`MomoCurveRulesTests` 0.08 + isSingleSoftOvershoot acceptance/rejection battery + `MomoMomentTests` trajectories); settle ease-in p² (`MomoCurvesTask027Tests` exponent 2.0 + shape). §6.3 play pacing → D's Play-round row (invite ≤3 / follow 10–20 / payoff ≤5 / total ≤30, all digit-pinned). **Result: zero unpinned §7.1 character-owned rows.**

### Audit table E — geometry pins (04 §2.1; ADR-001; epic Test Requirements)
| # | Clause | Named pin(s) | Pin verification |
|---|---|---|---|
| E1 | §2.1 Direction-C landmarks on the 1000×1000 grid | `MomoRigGeometryTests` literal pins with the verify_geometry.py-shared tolerances (body 60, head 40, eyes 20/12, earRoot 30, tail 30, ground 1.0) | Landmark drift beyond tolerance fails |
| E2 | §2.1 shape laws: pear taper, overlaps, ground contact, containment | `MomoRigGeometryTests` (hip ≥1.25× waist; head/body ≥40 overlap; hind feet on ground; face-in-head; belly-in-body) | Silhouette regressions fail |
| E3 | ADR-001 ear rule ≥12 % of body width AT BASE + rounded tips | `MomoRigGeometryTests` at-base chord via `widthAtY` at the root line (comment explicitly records why bbox width cannot catch a thin tilted ear) + tip-rounding pins (w10 ≥50 %, w6 ≥30 %) | Ear thinning/merge/sharp-tip regressions fail |
| E4 | §2.1 LOD stage bands 220–280 / 60–80 / 24–32 pt, disjoint | `RigLODTierTests` raw literals + disjointness + surface→tier mapping + WATCH-NEVER-FULL over the full enumeration + 21/11/3 part sets | Tier misassignment or band drift fails |
| E5 | Grid confinement of every emitted vertex (§2.1) | `MomoGeneratedDisciplineTests` normalizedGrid over all 44 constants (count pinned non-vacuous) | Off-grid vertex fails |
| E6 | Emission layout + naming law + headers (§8.4/§8.5) | `MomoRigInventoryTests` (44 = 21+11+3+5+4; §8.4 naming; GENERATED headers; hand-written anchor markers) + `MomoRigVariantsTests` (glyph 6-subpath merge, seam fills not holes, eye dots smaller, LOD-glance reductions, mouth 3 distinct poses) | Emission drift fails |
| E7 | Pipeline reproducibility (epic AC-1) | `MomoPipelineReproducibilityTests` (Swift output byte-identical; SVG evidence byte-identical; `generate.py --check` exit 0) | Any regeneration drift fails |
| E8 | Slot→constant binding, z-order, static token application | `RigLayerTreeTests` (25/11/3 draw orders; slot.path == the generated constant; part→token mapping, state never by color) + `R1CompositionTests` (ADR-009 child-first composition, point+pixel probed) | Draw-order/token/composition drift fails |

### Pure-file determinism-property coverage record (05 §10.2; Objective item 6)
Standard applied: identical inputs ⇒ byte-identical outcome over bounded seeded streams (analytic pin / twin corpus / structural scoping, honestly labeled). **NO MomoCharacter llvm-cov number was run or recorded; no floor exists for Character** (05 §10.2's floors are Core ≥90 % / Kit ≥80 %, already recorded: TASK-020 97.68 %, TASK-024 88.86 %). 40 files = 1 view (excluded) + 21 pure logic + 11 generated constants + 7 hand-written constants/copy.

**View file — explicitly NOT pure (exclusion):**
- `MomoRigView.swift` — SwiftUI `View` (TimelineView/Canvas) with the environment/scenePhase ambient reads; a View body is not a pure function the §10.2 property can pin. Its decision logic is extracted into pure seams pinned elsewhere: `RigMotionViewMapping.clockAction` (`RigDisciplineTests.scenePhaseMapping`), structural wiring (`viewWiresScenePhase`), glyph AOD branch renders the constant `.rest` (`glyphTierIsFlagFree`), the ONE ambient RM read scoped to this file alone (`reduceMotionEnvironmentReadIsViewScoped`), ambient-time freedom (`clockAndViewAreAmbientFree`).

**Pure logic files (21) — property per file:**
| File | Covering property (named tests) | Guarantee shape |
|---|---|---|
| `CharacterClock.swift` | `CharacterClockTests` (10) + `MomoIdleResumeTests` | Analytic (pause-zero/resume-from-zero, elapsed purity, backward clamp) + end-to-end replay equality |
| `MomoCurves.swift` | `MomoCurveRulesTests` (14) + `MomoCurvesTask027Tests` (14) | Analytic pins (raw §7.1/§7.2 constants, R2 predicate acceptance/rejection, spring landmarks, sine purity) |
| `RigChannel.swift` | `RigMotionModelTests` channelInventory/channelsTileAll | Structural (name-for-name §2.2, tiles `.all` exactly) |
| `RigPose.swift` | `RigMotionModelTests` rest pins + `R1CompositionTests` | Value pin (rest digit-for-digit; rest == identity through every composed transform) |
| `RigMotionModel.swift` | `RigMotionModelTests` (13) + `MomoIdleRenderTests` breathSinePuritySweep (720 samples × 64 states digit-for-digit vs the analytic sine, zero flat samples) + `MomoReactionPropsTests` applied paths | Analytic + exhaustive sweep: `pose(at:displayState:reactionMotion:)` is pure; sweep pins the sine law over the state space |
| `RigLODTier.swift` | `RigLODTierTests` (12) | Structural (mapping, bands, WATCH-NEVER-FULL, part sets) |
| `RigLayerTree.swift` | `RigLayerTreeTests` (18) + `R1CompositionTests` (6) | Structural + point-probed matrix (≥15 slots × >75 pts at 1e-6) + pixel probe (≤8 px, >1000 px non-vacuous) |
| `MomoIdleRandom.swift` | `MomoIdleRandomTests` (10) | Analytic raw-literal pins (uniform/normal vectors, the >>11 / 2^53 mapping, 0xE220A8397B1DCDAF, weighted canonical order, replay) |
| `MomoIdleEvents.swift` | `MomoIdleSequencerTests` whole-log vectors (seeds 0/1/42) + `MomoIdleRenderTests` per-event-kind signatures | Vector + channel-signature pins |
| `MomoIdleVariants.swift` | `MomoIdleSequencerTests` variant battery + `MomoIdleRenderTests` variant signatures | Band/gating pins + signature pins |
| `MomoExpressions.swift` | `MomoExpressionTests` (17: §3.2/§3.3 digit pins, conflict-law 16-cell table, conversion pins, INV-6 4096-state audit, the NEW §3.5 pairwise anchor) | Analytic + cross-product audit |
| `MomoIdleSequencer.swift` | `MomoIdleSequencerTests` (22) + `MomoIdleResumeTests` | The determinism property itself (equal whole logs, 25 seeds × 6 states; prefix property; resume byte-equality) |
| `MomoReactionMotion.swift` | `MomoReduceMotionMappingTests` primitives + `MomoCurvesTask027Tests` spring trajectory passes isSingleSoftOvershoot | Analytic primitive pins |
| `MomoReactionClips.swift` | `MomoReactionClipTests` census (21 keys, durations digit-for-digit, band membership, ≤8 channels) | Literal census |
| `MomoReactionClipMotion.swift` | `MomoReactionClipTests` shape pins + `MomoReactionCompositeTests` | Sampled shape pins (press ×2, cyclical ×3, pressRelease, tempo) |
| `MomoHandshakeChoreography.swift` | `MomoHandshakeTests` (19) + `MomoReactionPropsTests` windows | Duration + trajectory + exactly-once pins |
| `MomoMoments.swift` | `MomoMomentTests` (7) | Duration + overshoot + exactly-once + hide/replay pins |
| `MomoReactionDirector.swift` | `MomoReactionDirectorTests` (13) + `MomoReactionTwinTests` | Twin-equality + structural storm property (≤1 active L3, queue ≤2 over 400 samples, exactly-once) |
| `MomoReactionState.swift` | `MomoReactionTwinTests` (3) | Whole-trajectory twin corpus (state + 300-sample overlay + reports; single-shift breaks equality; deterministic replay) |
| `MomoReactionOverlay.swift` | `MomoReactionCompositeTests` (10) + `MomoReactionPropsTests` appliedFoodPath | Applied-path pins through director→overlay→model→pose |
| `MomoReduceMotion.swift` | `MomoReduceMotionMappingTests` (17) + `MomoReduceMotionTwinTests` (7) + `MomoReduceMotionEndPoseTests` (9) | Fold-twin whole-state equality over 13 distinct streams (8 named + a 5-value hold sweep) + mapping digit pins + end-pose partition (Disclosures register untouched, per contract) |

**Generated constants files (11) — no behavior ⇒ no determinism property needed; pinned by value/reproducibility suites (honest disposition):** `MomoRig+Body/Ears/Eyes/FaceDetails/FrontPaws/Glyph/Head/LODGlance/Tail.swift`, `MomoRoom.swift`, `MomoProps.swift` — pinned by `MomoGeneratedDisciplineTests` (grid + colorless + imports + source-of-truth pointer), `MomoPipelineReproducibilityTests` (byte-identical regeneration, the determinism-grade pin for this layer), `RigLayerTreeTests.slotPathsAreTheGeneratedConstants`, `MomoRigGeometryTests` landmarks, `MomoRigVariantsTests` (glyph/LOD/mouth laws), `MomoRigInventoryTests` (part accounting), `MomoArtBudgetTests` (§8.3).

**Hand-written constants/copy files (7) — constants only; values pinned by:** `MomoRig.swift` (1810 B anchor; `MomoRigInventoryTests.namespaceAnchors` + `R1CompositionTests`), `MomoCharacterPalette.swift` (`MomoDesignTokensTests` §8.4 verbatim-in-order + `TokenPurityTests` non-vacuous allowlist), `MomoUIColors.swift` (`MomoDesignTokensTests` + `TokenPurityTests`), `MomoColorToken.swift` (`MomoDesignTokensTests` resolve-per-scheme; hex confined via internal init), `MomoTypography.swift` + `MomoMetrics.swift` (`MomoDesignTokensTests` existence/monotonicity pins), `MomoCopy.swift` (`MomoCopyTests` grammar + production Bundle lookup + INV-11 rejection).

Coverage-record verdict: **every pure file carries a named property or an honest constants-only disposition; the view file is explicitly excluded with its pure-seam pins enumerated.** Objective item 6 satisfied without a coverage floor, per contract.

### Art budgets re-measured against §8.3 (Objective item 7)
Measurement method: exact byte counts via Python `os.path.getsize` (2026-09-10, working tree; never `du -k`). Budget basis = SOURCE BYTES as TASK-025 recorded. **O8 basis note: the hand-written `MomoRig.swift` anchor (1,810 B) sits OUTSIDE the rig bucket** — the bucket is the pipeline-emitted `MomoRig+*.swift` files only.

| §8.3 row | Budget | Measured | Verdict |
|---|---|---|---|
| Rig bucket (`MomoRig+*.swift`, 9 files) | ≤ 300 KB (307,200 B) | **50,096 B (48.92 KiB)** — Body 5,642; Ears 3,181; Eyes 6,782; FaceDetails 5,438; FrontPaws 3,122; Glyph 8,504; Head 2,110; LODGlance 13,233; Tail 2,084 | PASS (16.3 % of budget) |
| Room + props (`MomoRoom.swift` 12,861 + `MomoProps.swift` 7,786) | ≤ 250 KB (256,000 B) | **20,647 B (20.16 KiB)** | PASS (8.1 %) |
| Total art contribution | ≤ 1.5 MB (1,572,864 B) | Generated art (rig + room + props) **70,743 B (69.08 KiB)** — matches `MomoArtBudgetTests`' in-suite basis; all 40 `Sources/MomoCharacter/*.swift` sources **351,863 B (343.62 KiB)** | PASS (4.5 % / 22.4 %) |

In-suite enforcement: `MomoArtBudgetTests` pins the same buckets (partition-of-11 coverage so no generated file can escape the scan) — consistent with this measurement.

### Disclosures
1. **Production diff EMPTY**: `git diff Sources/MomoCharacter/` = 0 bytes. No production touch, so no §-required production disclosure arises.
2. `git diff Sources/MomoCore/ Sources/MomoKit/ docs/ .claude/tasks/epics/` = 0 bytes (contract-mandated emptiness + no doc changes).
3. Working tree (dirty, unstaged, per contract): `M Tests/MomoCharacterTests/MomoExpressionTests.swift` (+1 test, +header mention), `M .claude/tasks/active/TASK-030-character-test-suites.md` (this record). **Observed, NOT this task's edit:** `.claude/tasks/status.md` carries a one-line in-flight orchestrator edit (the 2026-09-10 `origin/main` merge pre-flight note; mtime 10:30, mid-task, not authored here) — left untouched; flagged for the orchestrator.
4. No new scan exemptions; standing suites (`RigDisciplineTests`, token/copy/generated discipline) green; no test weakened, deleted, or skipped; no TODO/FIXME/HACK/TEMP introduced.

### Design decisions
1. **§3.5 anchor form**: pairwise-distinguishability over carrier FIELDS rather than instantaneous pose equality. Honest because four same-mood relaxed-vs-energetic pairs differ only in breath cycle (coincide at instants, distinct in grayscale MOTION — the doc's own §8 verification suggestion is an animated `.grayscale(1)` preview), and Low+Drowsy vs Low+Exhausted differ only in the yawn/nod gates. A static-channel-only test would be FALSE; the carrier-field form is the clause's truthful executable content ("differences must survive with no hue information").
2. **Carrier set = every field of `MomoExpression`**: R4's static part→token mapping (already pinned) makes color state-free, so the composed expression IS the complete hue-free rendering description; any future tie fails the suite exactly when two states become indistinguishable.
3. **Placement**: appended to `MomoExpressionTests` (the §3.2–3.3 suite; 324→~380 lines) rather than a new file — house file-count discipline, and the test reuses the suite's `state()` fixture.
4. **No §7.1 gap**: `.nibble`'s exclusion from the 2.5–4.0 s Eating row is itself a named pin (`MomoReactionClipTests`: < 2.5, "the shortened eating animation"), so the row's scope is exact and no closure was needed.
5. **No coverage number**: per contract item 6, the pure-file record replaces a floor; no MomoCharacter llvm-cov invocation was made.
6. **Evidence PNGs untouched**: the §3.5 test CITES `docs/evidence/character/rm-*.png` as the visual counterpart; nothing re-rendered.

## Reviewer Findings
REVIEW-TASK-030 — **APPROVED_WITH_MINOR_NOTES** (2026-09-10; `.claude/tasks/reviews/REVIEW-TASK-030.md`). Method: re-derived all five audit tables + the coverage record from the docs BEFORE comparing; body-read every table-C row plus A/B/D/E spot-checks (no existence-grepped mapping found); verified the new test's carrier set field-for-field against `MomoExpression`; reproduced every §8.3 budget digit incl. the 9-file rig breakdown; green ×2 at 825/82, zero warnings; delta +1 verified by diff arithmetic. Bite executed in TWO stages: stage 1 DISPROVED this file's own single-gate recipe (inert — `headNodEnabled` co-gates Drowsy-only, so the §3.5 test stays green while the A12 yawn census fails: mutation verifiably live); stage 2's corrected two-gate bite failed on exactly the predicted Low+Drowsy/Low+Exhausted pair (`MomoExpressionTests.swift:393`); restore sha256-proven (`92902afb…`). Findings — all record-accuracy; no code or behavioral change:
- **MINOR-1** — the bite recipe (C11 + Handoff) was INERT as written. DISPOSITION: reworded to the corrected two-gate mutation in both places.
- **MINOR-2** — stream counts misstated ("11 corpus + 7 adversarial" / "18 streams"); actual = 13 distinct (8 named + holdSweep at 5 values), inherited from the TASK-029 records. DISPOSITION: corrected in A3/C9/the pure-file row here; epic + completed TASK-029 records corrected by the orchestrator in the housekeeping commit (NOTE-3).
- **NOTE-1** — the new test's comment called the relaxed-vs-energetic pairs "cycle-only"; they differ in 3 tempo carriers. DISPOSITION: comment corrected (test stronger than claimed).
- **NOTE-2** — three stale per-suite counts in the pure-file record (Handshake 13→19, RigLayerTree 15→18, RigMotionModel 12→13; all understatements; every other stated count reproduced exactly). DISPOSITION: corrected.
- **NOTE-3** — the epic TASK-029 record carries the same inherited 18-stream phrasing. DISPOSITION: corrected by the orchestrator (housekeeping commit).

Every finding's diagnosis was verified personally by the orchestrator before disposition: gate definitions (`MomoExpressions.swift:195-202` — both `energy == .drowsy`), twin-stream inventory (8 named constants + holdSweep `[0.1, 0.5, 0.8, 2.0, 5.5]`), energetic carrier values (`0.96`/:175, `0.95`/:162, variant cadence/:379), suite counts (grep -c '@Test'), and the restored-file sha256 (matches the pristine hash exactly).

## Completion Evidence
(recorded here by the implementation agent; commit hash to be appended post-disposition by the orchestrator)
- **Tests:** final tree green ×2 — 825 tests / 82 suites passed (1.436 s / 1.442 s), zero warnings; baseline 824/82 @ clean `7174048` reproduced pre-work (2.382 s). Delta +1 test (`§3.5: the §3.2–3.3 cells are pairwise distinguishable without hue` in `MomoExpressionTests`).
- **Gap analysis:** tables A–E complete (above); 1 named gap found and closed (§3.5 anchor); 0 §7.1 gaps; every named test's body read.
- **Budget table (§8.3, exact bytes, os.path.getsize, O8 note included):** rig 50,096 B ≤ 307,200 PASS; room+props 20,647 B ≤ 256,000 PASS; generated total 70,743 B ≤ 1,572,864 PASS (all-sources 351,863 B also ≤ budget).
- **Diff scope:** production EMPTY; MomoCore/MomoKit/docs/epics EMPTY; changed files = 1 test file + this task file (+ the orchestrator's own in-flight status.md edit, disclosed above).
- **Commit:** none by the implementation agent (contract; tree left DIRTY for the orchestrator). Suggested commit after review disposition: `test(character): TASK-030 character suite audit + determinism-property coverage record`.

## Handoff

### Completed
- Audit tables A–E re-derived from the docs first, then verified against READ test bodies (all 34 `Tests/MomoCharacterTests/` suites + `Support/`); every row carries clause / named pin / what-breaks.
- Pure-file determinism-property coverage record complete: 40 files dispositioned (1 view excluded with reasons + its pure-seam pins; 21 logic files with named properties; 11 generated + 7 constants files with honest constants-only dispositions and their pinning suites). No MomoCharacter coverage number run or invented.
- Art budgets re-measured with exact `os.path.getsize` bytes; all three §8.3 rows PASS with the O8 basis note; consistent with `MomoArtBudgetTests`.
- The audit's single named gap CLOSED: the §3.5 grayscale in-suite anchor (new named test, 120-pair property, passes).
- Suite green ×2 at 825/82, zero warnings; standing scans green, no new exemptions; no marker debt.

### Files Changed
- `Tests/MomoCharacterTests/MomoExpressionTests.swift` — +1 test (§3.5 anchor), suite header mentions §3.5; no other test file touched.
- `.claude/tasks/active/TASK-030-character-test-suites.md` — Status IN_REVIEW; this record.
- (Disclosed, not mine: `.claude/tasks/status.md` one-line orchestrator edit — untouched.)

### Tests Run
- `swift test` ×3 total (baseline pre-work; ×2 post-closure). Filtered `MomoExpressionTests` run during the closure's RED→GREEN loop (compile fix: single interpolated literal — Swift Testing `Comment` accepts literals, not concatenated `String` values).

### Test Results
- 824/82 green @ baseline (2.382 s); 825/82 green ×2 (1.436 s / 1.442 s); 0 warnings in all post-closure runs; `grep -ci warning` = 0 on both logs.

### Known Issues
- None in the audited scope. Owner-routed items stand as previously disclosed (RM touch-acknowledgment statics; the Content+Energetic RM static collision) — restated nowhere, per contract.

### Decisions Made
- Six recorded under Implementation Notes → Design decisions (§3.5 anchor form; carrier-set scope; placement; nibble no-gap; no coverage number; evidence untouched).

### Reviewer Status
APPROVED_WITH_MINOR_NOTES — REVIEW-TASK-030 complete (2026-09-10, `.claude/tasks/reviews/REVIEW-TASK-030.md`). The reviewer executed the suggested bite in two stages: the single-gate recipe as written proved INERT (stage 1: test green, A12 census failed — recipe defect, not a test defect), and the corrected TWO-GATE mutation (`yawnEnabled` AND `headNodEnabled` → also `.exhausted`) failed on exactly the Low+Drowsy / Low+Exhausted pair; restore byte-identical, sha256 `92902afb…` before == after. All 5 findings dispositioned (see Reviewer Findings).

### Commit
None per contract — no `git add`/`commit`/`push` by the implementation agent; tree left DIRTY and unstaged on `feature/EPIC-006-character` @ `7174048`.

### Push
n/a (no commit exists to push).

### Recommended Next Step
Orchestrator: dispatch the fresh adversarial reviewer for REVIEW-TASK-030 (re-derive tables A–E + the coverage record from the docs independently; re-run the byte measurement; bite one audit-mapped clause; verify green ×2, scan-exemption absence, and diff scope). After APPROVED disposition: commit per the suggested message, then proceed straight to the EPIC-006 epic-merge procedure (§14: `git fetch` + check `origin/main` FIRST — the status.md pre-flight note records `origin/main @ aa072ea` with the owner's PR #7 merge; merge only the `origin/main..HEAD` remainder, `--no-ff`, never force-push, verify merged tree green before push).
