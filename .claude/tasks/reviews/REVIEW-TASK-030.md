# REVIEW-TASK-030 — Character test suites: MomoCharacterTests audit + determinism-property coverage record + art budgets

Reviewer: independent fresh agent (CLAUDE.md §10/§33). Did not implement; mandate was to disprove.
Reviewed: the uncommitted working-tree changeset on `feature/EPIC-006-character` @ `7174048` — modified `Tests/MomoCharacterTests/MomoExpressionTests.swift` (+1 §3.5 grayscale anchor test + suite-header mention) and modified `.claude/tasks/active/TASK-030-character-test-suites.md` (audit tables A–E, pure-file coverage record, §8.3 budget table, run history, disclosures, handoff). One tree change explicitly OUT of scope per the dispatch: a one-line in-flight orchestrator edit to `.claude/tasks/status.md` (merge pre-flight note) — confirmed present, left untouched.
Method: re-derived the audit matrix from `docs/design/04-character-system.md` (§2.1, §3.2–3.5, §5.1–5.3, §6.1–6.3, §7.1–7.4, §8.3–8.5, §9.4–9.5), `docs/architecture/05-technical-architecture.md` §10.1–10.2, the delivery-plan TASK-030 row + §-coverage table, and ADR-001 BEFORE comparing to the implementer's tables; body-read every spot-checked pin (all of table C, plus A1/A2, B1/B2/B3/B5/B6, D's census/band/moments/handshake rows, E3/E8, and the non-obvious pure-file rows); verified the new test's carrier set against the actual `MomoExpression` struct field-for-field; re-measured every §8.3 row with exact byte counts; executed the sanctioned mutation bite in two stages; ran the suite ×2.

## VERDICT: APPROVED_WITH_MINOR_NOTES

The changeset's central claims all verify. The audit tables map clauses to tests whose bodies genuinely pin them (spot-read evidence below); the one claimed gap (§3.5's missing in-suite anchor) was real and the closure is sound: the new test walks all 16 §3.2–3.3 cells, compares 120 pairs over a carrier set that IS the complete hue-free description of the composed expression (verified field-for-field against `MomoExpression`'s 12 fields, with R4's state-free color as the load-bearing precondition), pins non-vacuity, and fails with an actionable message naming the colliding pair. The pure-file record's structure is honest (view file explicitly excluded with its pure-seam pins; generated/constants files dispositioned as constants-only with their pinning suites named; no MomoCharacter coverage number invented, correctly). The §8.3 budget table reproduced DIGIT-FOR-DIGIT on every number including the 9-file rig breakdown. Scope is exactly as disclosed: production EMPTY, `Sources/MomoCore`/`MomoKit`/docs/epics EMPTY, no test weakened/deleted/skipped, no marker debt, no new exemptions, green ×2 at 825/82 with zero warnings (delta +1 verified by diff arithmetic). One sanctioned bite executed in two stages: the implementer's suggested recipe is INERT (disproven by execution — see MINOR-1) and my corrected two-gate mutation fails on exactly the predicted pair, restoring byte-identically. Two MINOR findings (both record-accuracy defects in the deliverable whose entire purpose is accuracy — one proven by execution, one arithmetic) and three NOTEs; none behavioral, none in test or production code.

Reproduced: `swift test` run 1 → **✔ 825 tests / 82 suites passed after 1.451 s**; run 2 → **✔ 825 tests / 82 suites passed after 1.472 s**; `grep -ci warning` = 0 on run 1's full log and on the implementer's own run-2/run-3 logs. Matches the claim (824/82 baseline + 1 = 825; +1 `@Test` in the diff; the −3 lines are a doc-comment re-wrap, no test touched).

---

## MINOR findings

### MINOR-1 — The task file's reviewer bite recipe is INERT against the test it advertises (proven by execution)

- Evidence: task file table C row C11 + Handoff "Reviewer Status": "bite recipe for the reviewer: flip `MomoExpressions.yawnEnabled` to also return true for `.exhausted` ⇒ exactly Low+Drowsy vs Low+Exhausted ties on all 12 carriers and this test fails." The prediction's premise is false: `headNodEnabled(energy:)` (`Sources/MomoCharacter/MomoExpressions.swift:200-202`) is the SAME Drowsy-only gate and still separates the pair, so the pair never ties on all 12 carriers.
- Execution proof (stage 1): applied the recipe exactly — `yawnEnabled` → `energy == .drowsy || energy == .exhausted`, everything else untouched. `swift test --filter grayscaleLegibilityAcrossExpressionCells` → **PASSED after 0.001 s**. The mutation was verifiably live in production behavior: the A12 census "§5.2 yawn: Drowsy-only, authored 1.4 s envelope…" FAILED in the same mutated tree (`yawns.isEmpty → false` — Exhausted now emits yawns into the schedule).
- Corrected bite (stage 2, the sanctioned bite's actual strike): ALSO flipped `headNodEnabled` to `energy == .drowsy || energy == .exhausted`. PREDICTED before running: exactly one §3.5 failure, naming only Low+Drowsy vs Low+Exhausted (the pair is unique: every other drowsy-vs-exhausted pair differs in `postureScaleY` — joyful 1.03 vs 0.9991, content 1.0 vs 0.97, wistful 0.96 vs 0.9312 — while Low's 0.95 × 0.97 = 0.9215 clamps back to the 0.95 floor, `MomoCurves.swift:251-253`). ACTUAL: exactly 1 failure — "§3.5 violation: .low/.drowsy and .low/.exhausted are indistinguishable without hue (no hue-free carrier differs)" at `MomoExpressionTests.swift:393`. The test itself is exactly as strong as claimed; only the recorded recipe is wrong.
- Why it matters: the recipe is the task file's own demonstration that the audit mapping is executable truth. A future reviewer following it verbatim would see the test stay green and could wrongly conclude the anchor is vacuous.
- Suggested disposition: reword the C11/Handoff recipe to the two-gate mutation (flip both `yawnEnabled` and `headNodEnabled` to include `.exhausted` ⇒ the §3.5 test fails on exactly the Low+Drowsy/Low+Exhausted pair; A12's yawn AND headNod census tests fail alongside — which strengthens the audit claim). One-line task-file edit; no code or test change.

### MINOR-2 — Twin-corpus stream counts misstated: "11 corpus + 7 adversarial" / "18 streams" vs 13 actual

- Evidence: task file C9 ("fold-twin whole-state equality over 11 corpus + 7 adversarial streams"), A3 ("twin equality over the 18-stream corpora"), pure-file record row `MomoReduceMotion.swift` ("Fold-twin whole-state equality over 18 streams"). Actual count in `MomoReduceMotionTwinTests.swift`: **13 distinct streams** — 8 named stream constants (`storm` :47, `coalescerStorm` :85, `queueChurn` :99, `hideShowMatrix` :112, `pacerNoRest` :130, `pacerRest` :137, `pacerDrowsy` :143, `pressOnly` :153) plus `holdSweep(_:)` (:161) at 5 hold values (0.1/0.5/0.8/2.0/5.5, :274). The "7 adversarial" subset matches the file's 7 adversarial storm/pacer streams; "11 corpus" matches nothing in the file. The file is unchanged since TASK-029 (`git diff 9a46641..HEAD` on it is empty), so the 11+7=18 figure is inherited from TASK-029's epic record (EPIC-006 file carries the same phrase), not introduced here — but this deliverable restates it as its own evidence, and this task's contract is precisely that recorded numbers are verified truth.
- The LAW itself is genuinely pinned: `twinCheck` (:185-238) does real work in all three layers (fold/report equality, flag-visibility probe over per-event sampled instants with real `mustDiffer` non-vacuity, prefix-by-prefix tracker twins) over all 13 streams.
- Suggested disposition: correct the three places to "13 distinct streams (8 named + a 5-value hold sweep)"; add one backlog line for the orchestrator to correct the inherited phrasing in EPIC-006's TASK-029 record (docs are not editable by this task).

## NOTE findings

### NOTE-1 — New test's doc comment: "cycle-only" understates the relaxed-vs-energetic deltas
`MomoExpressionTests.swift:350-351` calls the four relaxed-vs-energetic same-mood pairs weakest "cycle-only". They differ in THREE carriers: `breathCycleSeconds` ×0.96 (`energeticBreathMultiplier`, `MomoExpressions.swift:175,367`), `intervalMultiplier` (energetic tempo 0.95, :159-162), and `variantIntervalMultiplier` (1.0/1.5, :170,380). The Low+Drowsy/Low+Exhausted "yawn/nod-gate-only" characterization IS exact (verified: posture clamps to equality for that pair; both sleepy bands share the 7.2 s cycle). The test is STRONGER than the comment claims — comment-only correction, foldable into MINOR-1's touch-up.

### NOTE-2 — Stale per-suite test counts in the pure-file record (all understatements)
Record claims vs `grep -c '@Test'` actual: `MomoHandshakeTests` (13) vs **19**; `RigLayerTreeTests` (15) vs **18**; `RigMotionModelTests` (12) vs **13**. Every other stated count reproduces exactly (Mapping 17, Twin 7, EndPose 9, CharacterClock 10, Moments 7, CurveRules 14, CurvesTask027 14, RigLODTier 12, ReactionTwin 3, ReactionDirector 13, ReactionComposite 10, IdleSequencer 22, IdleRandom 10, Expressions 17). Direction is conservative (record understates real coverage — likely snapshots taken before the TASK-028 fix round), but a record whose value is verification should carry current digits. Update the three parentheticals.

### NOTE-3 — EPIC-006 record carries the same 18-stream phrasing (backlog routing, not this changeset)
Root source of MINOR-2: the epic file's TASK-029 entry ("pinned over 11 corpus streams plus 7 reviewer-authored adversarial ones"). Out of this changeset's reach (no doc edits per contract); route to the orchestrator's doc-clarification backlog alongside MINOR-2's fix.

---

## Verification appendix

### A. Re-derived audit matrix vs the implementer's tables (spot-read evidence, bodies read not existence-grepped)

All five tables re-derived from the docs before comparison. The implementer's clause enumeration is COMPLETE against my re-derivation — no missed clause found. Spot-reads (each verified as a genuine pin of its row's clause):

- **Table A** — A1: `MomoIdleSequencerTests` determinism battery (25 seeds × 6 states, whole-log `first == second`, reports included) — the 05 §10.2 bounded-seeded meta-property in executable form. A2: `idleStackIsSeededOnly` (`RigDisciplineTests.swift:217-232`) scans all 22 rig files for system-entropy patterns with BOTH-direction non-vacuity (fires on fixtures, sees the seeded `SeededGenerator` in `MomoIdleRandom.swift`). A12's yawn census independently confirmed live by the stage-1 bite (see MINOR-1).
- **Table B** — B1: `CharacterClockTests` = exactly the claimed 10 tests (init-stopped-at-zero, resume-from-zero, pause-zeroes, no-backlog resume, double-pause idempotent, double-resume, resume-without-pause, `elapsed(at:)` purity, backward clamp, paused-clock-stops-every-channel). B2: `MomoIdleResumeTests` (both bodies read): real-time replay with dwell discard, resumed log == fresh log byte-for-byte, no-burst guards (`Set(starts).count == count`, all starts > 0, quiet resume instant), 20-step pose equality against the fresh run. B3: `RigMotionModelTests` gating battery present and real (bodyScale-off ⇒ exact identity, bodyScale-alone breathes, tailRotation no-op-when-still/real-bite-when-wagging) + `MomoReactionPropsTests.propChannelGating` (:164). B5/B6: `scenePhaseMapping`/`viewWiresScenePhase`/`glyphTierIsFlagFree` (`RigDisciplineTests.swift:289-350`) all genuine with non-vacuity counterparts.
- **Table C** — EVERY row's body read (the mandate's highest-risk table). C1–C8 map 1:1 onto `MomoReduceMotionMappingTests` R2–R9 test bodies with real pins and non-vacuity counterparts (window 5.0 opens/5.15 closes, endpoints exact + monotone, overwrite-snap, press keyframes 0.8/0.45, payoff 19.4, drowsy 15.4, settle report 4.0, wake report 4.0). C5's end-pose partition (`MomoReduceMotionEndPoseTests`, 9 tests) verified present with the identity/expressed key split. C9/C10: `twinCheck`'s three layers verified genuine (see MINOR-2 for the count correction). C11: the new test verified in full (below).
- **Table D** — §7.1 census row: `MomoReactionClipTests` 21-key literal census (count == 21, per-key duration pins incl. `.nibble, 1.6`) + the band-membership test with the EXPLICIT `.nibble < 2.5` branch ("the nibble is the shortened eating animation", :80-82) — the "no §7.1 gap / nibble scope exact" claim verified. Moments: 1.0/1.8 authored pins inside 0.9–1.2/1.6–2.0 bands (`MomoMomentTests.swift:19-23`) + exactly-once. Handshake: settle 3.0 / wake 2.0 / roundBound 22.4 / no-rest baseline 19.4 / rest-solo 17.4 / still-in-grace 19.4 / drowsy 15.4 (8.0 follow) / hide-cancel-exactly-once — all present as named tests (`MomoHandshakeTests` 19 tests).
- **Table E** — E3 (the ADR-001 load-bearing row): `MomoRigGeometryTests.earRule` (:103-126) measures the at-base chord via `PathMeasuring.widthAtY` at the ear-root line with ratio ≥ 0.12, and its comment records exactly why bbox width cannot catch a thin tilted ear (120.5 bbox vs 64.9 at-base) — the TASK-025 fix-round standard, intact. `earRoundedTips` pins w10 ≥ 50 % / w6 ≥ 30 %. E8: `RigLayerTreeTests` 25/11/3 draw orders, slot-path==generated-constant, part→token mapping "state never by color" — all present.

### B. The new §3.5 test, verified independently

- Scope: 16 cells = the full 4×4 §3.2–3.3 cross-product under the suite's awake `state()` fixture — matches the clause's scope ("every expression state in §3.2–3.3"); 120 pairs; `#expect(cells.count == 16)` is the non-vacuity pin; the failure message names both colliding cells.
- Carrier completeness: the 12-tuple carrier list is EXACTLY the field list of `MomoExpressions.MomoExpression` (`MomoExpressions.swift:320-332`) in the same order. Given R4's state-free static coloring (pinned by `RigLayerTreeTests` part→token mapping), the composed expression IS the complete hue-free rendering description — design decision 2 is TRUE as stated.
- Honesty: the doc comment's weakest-pair disclosure is genuine (Low+Drowsy/Low+Exhausted is truly the thinnest pair at 2 carriers; verified by the stage-2 bite), the RM collision cross-reference checks against `MomoReduceMotionEndPoseTests`'s R11 test, and the comment's one inaccuracy is NOTE-1 (an understatement of the test's own strength).

### C. Sanctioned mutation bite (sha256-proven, two stages)

Pristine sha256 of `Sources/MomoCharacter/MomoExpressions.swift` (recorded before any mutation): `92902afbdcbb12e31b0a2aab40b2041d748d882e663bb0255d6cf71d1c40380c`; production `git diff` EMPTY at that point.

- Stage 1 (the implementer's recipe, run to test its claim): `yawnEnabled` → `energy == .drowsy || energy == .exhausted`. PREDICTED (mine, before running): §3.5 test stays GREEN (`headNodEnabled` still differs), A12 yawn census fails. ACTUAL: exactly that — §3.5 passed; "§5.2 yawn: Drowsy-only…" failed at `MomoIdleSequencerTests.swift:512`.
- Stage 2 (corrected bite): additionally `headNodEnabled` → `energy == .drowsy || energy == .exhausted`. PREDICTED: exactly one §3.5 failure naming only Low+Drowsy vs Low+Exhausted (posture clamp argument). ACTUAL: exactly 1 failure — "§3.5 violation: .low/.drowsy and .low/.exhausted are indistinguishable without hue" at `MomoExpressionTests.swift:393`. 120th-pair arithmetic confirmed: no other pair tied.
- Restore: both gates reverted by exact inverse edits. Post-restore sha256 **== `92902afb…` exactly**; `git diff --stat Sources/MomoCharacter/` EMPTY; `git status --porcelain` back to exactly the 3 disclosed files.

### D. Budget re-measurement (Python `os.path.getsize`, exact bytes — every number reproduced digit-for-digit)

| §8.3 row | Claimed | My measurement | Verdict |
|---|---|---|---|
| Rig bucket (9 × `MomoRig+*.swift`) | 50,096 B — Body 5,642; Ears 3,181; Eyes 6,782; FaceDetails 5,438; FrontPaws 3,122; Glyph 8,504; Head 2,110; LODGlance 13,233; Tail 2,084 | **identical on all 9 digits + total** | PASS, 16.3 % of 307,200 |
| Room + props | 12,861 + 7,786 = 20,647 B | **identical** | PASS, 8.1 % of 256,000 |
| Generated art total | 70,743 B | **identical** | PASS, 4.5 % of 1,572,864 |
| All 40 sources | 351,863 B | **identical (40 files)** | 22.4 % |
| O8 basis: `MomoRig.swift` anchor OUTSIDE the rig bucket | 1,810 B | **identical** | note verified |

### E. Commands and counts

- `swift test` ×2 on the dirty tree — **825 tests / 82 suites passed** (1.451 s / 1.472 s), exit 0 both. `grep -ci warning` = 0 on run 1's full log and on the implementer's `/tmp/task030_run2.log` + `/tmp/task030_run3.log`.
- Delta arithmetic from the diff (no stash, per dispatch): `MomoExpressionTests.swift` +78/−3; exactly +1 `@Test`; the −3 lines are the suite doc-comment re-wrap (header gains the §3.5 mention; zero test content removed) → 824 + 1 = 825, suites 82 unchanged. ✓
- Bite runs: `swift test --filter grayscaleLegibilityAcrossExpressionCells` (stage 1: PASS; stage 2: 1 predicted failure); `swift test --filter yawn` (stage 1: A12 census fails as predicted).
- Scope greps: `git status --porcelain` = exactly the 3 disclosed modified files, no untracked; `git diff Sources/MomoCore/ Sources/MomoKit/ docs/ .claude/tasks/epics/` EMPTY; `git diff Sources/MomoCharacter/` EMPTY (before bite, after restore).
- Hygiene: diff greps for TODO/FIXME/HACK/TEMP/skip/disabled — no markers introduced, no test skipped or weakened, no new scan-exemption lines (only task-file prose matches).
- Per-suite `@Test` counts cross-checked against the pure-file record (see NOTE-2 for the three stale ones; all others exact).

### F. What held up

- The audit's central premise: every spot-checked row's "named test" genuinely pins its clause in its body — no existence-grepped mappings found, no row where the cited test merely "touches the area". The one real gap (§3.5's anchor) was correctly identified, and the closure form (carrier-field pairwise distinguishability over pose-equality) is the honest choice — a static-channel-only test would have been FALSE given the four coincide-at-instants tempo pairs, exactly as the design decision records.
- "Zero §7.1 gaps" verified where spot-checked: the nibble exclusion is itself a named pin; the moments and handshake rows are digit-pinned.
- The pure-file record's honesty architecture: view file excluded with reasons and its pure-seam pins enumerated; generated/constants files dispositioned as constants-only with named pinning suites; no invented MomoCharacter coverage number (correctly resisted — 05 §10.2's floors are Core/Kit only).
- Budgets: every recorded digit reproduces. The implementer ran this measurement correctly (exact `getsize`, never `du -k`).
- Production discipline: EMPTY production diff held through the entire review including the bite/restore cycle.

## Recommended disposition

APPROVED_WITH_MINOR_NOTES → address MINOR-1 and MINOR-2 and NOTE-1/NOTE-2 as one task-file touch-up (the two-gate recipe wording; "13 distinct streams" in three places; the "cycle-only" comment in `MomoExpressionTests.swift` — the only test-file change, comment-only; the three stale suite counts); route NOTE-3 to the orchestrator's doc backlog (EPIC-006 TASK-029 record's inherited phrasing). No code or behavioral change required; no test change beyond the one comment. Then the atomic commit per the task's Git Requirements, followed by the EPIC-006 merge pre-flight already noted in status.md.
