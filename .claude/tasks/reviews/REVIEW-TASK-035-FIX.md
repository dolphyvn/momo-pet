# REVIEW-TASK-035-FIX — Delta review of the F-1 fix (R9d stillness-ticker guard)

- **Task:** TASK-035 — feed/play/care; fix cycle for REVIEW-TASK-035 finding F-1
- **Branch:** `feature/EPIC-007-iphone-home` (working tree dirty, uncommitted on `3a1698b`)
- **Review date:** 2026-09-11
- **Reviewer:** fresh independent delta review agent (Jupiter); received the task requirements and the repo only — not primed with implementation claims
- **Base record:** REVIEW-TASK-035 (APPROVED_WITH_MINOR_NOTES; F-1 = MEDIUM disclosure/fragility, "before commit" guard recommended)
- **Review method:** §33 adversarial — the delta was audited against the first review's recorded scope and hashes, the new predicate was read critically (leg uniqueness grepped, comment false-positive claims re-derived, fixture non-vacuity analyzed), the guard was bitten on the REAL `MomoAppModel.swift` with **three** distinct mutations (the two required plus one), each restored with sha256-proven byte-identical restoration, and the full package suite was rerun. No git writes; the only repository file written or modified by this review is this record (all bites restored — verified).

---

## 1. Delta scope audit — PASS

The reviewed tree (first review §1): 27 modified files, +1532/−200, plus untracked `Tests/MomoKitTests/CareMomentTests.swift`. The current tree: 27 modified files, **+1575/−200** (`git diff --shortstat`), plus the same untracked test file and the first review's own record. **Delta vs the reviewed tree: +43 insertions, 0 deletions.**

| File | Claimed delta | Verified evidence |
|---|---|---|
| `Tests/MomoCharacterTests/RigDisciplineTests.swift` | +38 | numstat **115/0** — zero deletions, so no reviewed line was modified, only insertions. The +38 reconstructs exactly: enum block of 19 (12-line doc for `(d)` + 6-line `mentionsPlayStillnessTicker` + separator) inserted between the pre-existing blank and the `// MARK: - File access` line, and test block of 19 (blank + 18-line `playStillnessTickerDrivesTheSoloRound`) after the `(c)` test. Confirmed by the first review's exact pin `readRigFile :183-186`: in the reviewed tree that accessor sat at :183-186; with 19 lines inserted before it, it now sits at :202-205 — observed. Guard `(a)` still sits at its exact reviewed lines :158-161 (nothing inserted before it). |
| `.claude/tasks/active/TASK-035-feed-play-care.md` | +5 (Handoff/Fix Cycle) | numstat 113/2 (the 2 deletions pre-date the fix — total deletions are unchanged at −200). The fix-cycle addition reconstructs to exactly 5 insertions: `### Fix Cycle (F-1)` heading, blank, the one-paragraph record, blank, `FIX-CYCLE-COMPLETE TASK-035` — with `HANDOFF-COMPLETE TASK-035` pre-existing above the new marker. 38 + 5 = 43 = the whole delta; every other file contributes exactly zero. |
| Every other modified file (25) | 0 | Byte-identity evidence below. |

**`MomoAppModel.swift` (the bite target) is PROVEN byte-identical to the reviewed tree:** its sha256 today is `aa00873bef70557996bccd83299142b306100d71281173b7554a88be8459fe79` — exactly the first review's bite-(a) restoration-proof hash — and its numstat is **+170/−17**, exactly the stat that review recorded post-restore. Every ticker line that review pinned reads exactly as its F-1 evidence quotes: `:180` (`static let playTickerSeconds: Double = 1.0`), `:576` (`reconcilePlayPresentation()` at the end of `apply(trigger:)`), `:586-592` (the reconcile; the start wire at `:591`), `:610-616` (`runPlayTicker`: sleep on the constant at `:612`, the `moving: false` fold at `:615-618` resuming from `lastPlayFingertipOffset ?? .zero`, guarded by `isPlayRoundInFlight`).

**Corroborating mtime forensics:** exactly two files postdate the first review's record (06:10:51) — `RigDisciplineTests.swift` (06:21:06) and the task file (06:23:13). The three sources stamped 06:01–06:07 (`MomoAppModel`, `HomeCanvasTouchLayer`, `HomeView`) are precisely the first reviewer's own bite/restore targets; all other sources sit in the 02:00–02:27 implementation batch. No other file was touched after the review.

**Spot-checks against the first review's pins (all read exactly as that review quotes):** `HomeView.swift` :100 (overlay outside the canvas a11y element) and :116 (`appModel.stopPlayRound()`); `HomeCanvasTouchLayer.swift` :102-104 (in-flight gate) and :152/:159 (both `sendFingertip` call sites); `HomeReadModel.swift` :206-213 (tuck-in/nap parity); `CanvasTouch.swift` :209-215 (four-family gate); `MomoReactionState.swift` :41 (`case playStopped(at: Double)`) and :51 (`eventTime`); `MomoReactionDirector.swift` :637-643 (`applyPlayStopped`, `reported` flag); `CopyRules.swift` :65 (`copyEpoch = 4`) and :156-158 (`greeting, .careMoment → 1`); `HomeActionRowView.swift` :93-99 (verbatim §10.4 labels); `MomoAppModel.swift` :212, :376-378, :437, :469-477. `MomoUITests/MomoUITests.swift` remains diff-empty (`git diff` on it: 0 lines). Final `git status` file set is identical to the pre-review implementation set.

## 2. The R9d predicate — PASS (all four legs load-bearing)

`RigDiscipline.mentionsPlayStillnessTicker` (`RigDisciplineTests.swift:193-198`), tested at `:434-451` (real-file assertion `:437`, violation fixture `:443-450`), reading the real file through the same `readRigFile` accessor as R9a-c. Each leg greps to **exactly one** occurrence in `MomoAppModel.swift`:

| Leg | Substring | Real-file site | Breakage shape it names | Independent bite proof |
|---|---|---|---|---|
| 1 | `static let playTickerSeconds` | :180 (unique) | Ticker deleted (constant gone). Also pins authored-ness: a `var`/computed cadence (ambient-dependent drift) fails this leg while leg 2 still passes. | Constructive (see note N-2); deletion shapes covered by legs 2–4 failing together |
| 2 | `Task.sleep(for: .seconds(Self.playTickerSeconds))` | :612 (unique among the file's four `Task.sleep` sites — :627 pill, :645 schedule don't match) | Cadence literalized / decoupled from the authored constant | **Bite (i)** — proven |
| 3 | `moving: false,` | :617 (unique) | Stillness payload disconnected from the director event path | **Bite (iii)** — proven |
| 4 | `playTickerTask = Task { await runPlayTicker() }` | :591 (unique) | Start wire broken / gating broken — never started | **Bite (ii)** — proven |

**Precision checks that could have falsified the guard, and didn't:**

- **Comment false-positive claim — verified true.** The trailing comma is the discriminator: `MomoAppModel.swift:174` and `:604` (doc comments) contain the bare backticked `` `moving: false` `` with no trailing comma and cannot satisfy leg 3; the only comma-suffixed occurrence is the real fold at :617. The gesture path's own fold (:428) reads `moving: moving,` — leg 3 uniquely pins the TICKER's stillness fold, not the gesture's.
- **Fixture non-vacuity — genuine, and for the right reason.** The violation fixture (:443-450) is valid-Swift-shaped text that **contains leg 2 exactly** (`Task.sleep(for: .seconds(Self.playTickerSeconds))`) while lacking legs 1, 3, and 4 — i.e. the predicate fails it because the fold and the start wire are missing, not by syntactic invalidity or an unrelated accident. It is precisely F-1's shape ("still sleeps on the authored cadence but never folds stillness and is never started") and it additionally demonstrates that leg 2 alone is insufficient — the guard demands the whole wire.
- **Brittleness is by design, not accident.** Exact string shapes mean a deliberate reformat (e.g. reordering the fold's arguments, renaming the task) false-fails until the guard is consciously updated — the same contract as every TASK-026/TASK-034/R9a-c textual guard, whose file header states pins are updated "deliberately." Consistent with the established pattern; not a defect of this fix.
- **Leg 1 is not decoration** — see note N-2 for its one nuance.

## 3. Mutation bites on the real file — all proven to bite, all restored byte-identically

Baseline before any bite: `swift test --filter RigDisciplineTests` = **20 tests in 1 suite passed** (the reviewed 19 + the new R9d test), exit 0.

Each bite: mutate one leg into a plausible failure shape in `Apps/Momo/MomoAppModel.swift`, run the focused suite, confirm EXACTLY the R9d test fails (at `RigDisciplineTests.swift:437:9` — the REAL-file assertion, not the fixture line), restore by edit, prove byte-identical restoration by sha256.

| Bite | Mutation | Result | Restoration proof |
|---|---|---|---|
| (i) cadence literalized | `:612` `Self.playTickerSeconds` → `1.0` (runtime-identical — the constant's value is also 1.0 — so the failure isolates the TEXTUAL leg) | 20 tests, **exactly 1 issue**: "The passive round's stillness ticker folds on the authored cadence (R2 wire pin)" failed at :437:9; all 19 siblings green | mid-bite sha256 `ef4a5900…ae12f3`; restored → **`aa00873b…9fe79`** (identical to the reviewed-tree hash), numstat 170/17 |
| (ii) start wire broken | `:591` `playTickerTask = Task { await runPlayTicker() }` line removed (the loop is never started — the doc-comment's "gating broken" shape) | 20 tests, **exactly 1 issue**: same test, same line; siblings green | mid-bite `5849cd34…ed55c66`; restored → **`aa00873b…9fe79`**, numstat 170/17 |
| (iii) payload perverted (reviewer-added) | `:617` `moving: false,` → `moving: true,` (the ticker feeds MOVEMENT — the semantically-wrong-payload shape) | 20 tests, **exactly 1 issue**: same test, same line; siblings green | mid-bite `d87e97ac…deb2542`; restored → **`aa00873b…9fe79`**, numstat 170/17 |

After all bites: focused suite re-run green (**20/20**) on the restored tree; final `git status` file set identical to the pre-review implementation set; full diff still exactly +1575/−200. Zero residue.

(The `Apps/` sources are not SwiftPM build inputs — the rig guards are file-text scans — so bites could not break the build; each bite was exercised purely through the predicate, exactly as the first review's bites were.)

## 4. Full suite rerun — PASS

`swift test` (full package) on the restored tree: "**Test run with 907 tests in 92 suites passed**", exit 0. The ONLY delta vs the first review's 906/92 is the single new R9d test inside the existing `RigDisciplineTests` suite (suite count unchanged; matches the claim "906/92 → +1; RigDisciplineTests 19 → 20").

## 5. Gate carry-over statement

The first review executed the UI suite (17/17 on the pinned simulator) and the Watch build green **on the reviewed tree**. This delta was required to be test-file-plus-task-file only, and the §1 audit proves exactly that: the delta is +43/0 confined to `RigDisciplineTests.swift` (+38, zero deletions) and the task file (+5); the bite target `MomoAppModel.swift` is byte-identical to the reviewed tree by sha256 equality with that review's own restoration proof; every other source file is unchanged by mtime forensics, exact delta accounting, and line-pin spot-checks. **The carry-over condition holds: the app UI suite and Watch build need not be rerun, and their reviewed-tree results remain valid for the current tree.** The package gate was rerun in full (907/92) because the delta is itself a package test.

## 6. Notes (none blocking, none requiring code changes)

- **N-1 (erratum, task-file prose only):** the fix-cycle note says "The R9 MARK comments **now** read 'four structural wires.'" Both MARKs (`RigDisciplineTests.swift:150` and `:388`) are pre-existing reviewed text — numstat shows zero deletions in the file and guard `(a)` sits at its exact reviewed line — i.e. they already said "four" while only three guards existed (the fix made them true rather than changing them). Cosmetic inaccuracy in the note, not in the code; no correction required for commit.
- **N-2 (leg-1 nuance, documented):** for any COMPILING mutation, leg 1 (`static let playTickerSeconds`) is mostly subsumed by leg 2 (a compiling file cannot keep the sleep reading a deleted constant). Its one independent bite is pinning the constant's authored `static let` SHAPE — replacing it with a `var`/computed cadence fails leg 1 while leg 2 still passes. Load-bearing for that shape; not decoration.
- **N-3 (inherent property of the guard family, pre-existing):** these are substring predicates — a leg's text left present but commented out (or `#if false`d) still satisfies it; the guard sees deletions and manglings (bites i–iii, and the first review's three) but not comment-entombment. This is true of R9a-c, the TASK-034 F-1 guard, and the TASK-026 scanners equally — it is the accepted trade of the textual-guard pattern (accidental refactor is the threat model; adversarial comment-out is not). Recording only; if a future housekeeping pass wants to harden the family, a per-leg "exactly one uncommented occurrence" refinement is the shape.

## 7. Overall status

**APPROVED_WITH_MINOR_NOTES**

- The F-1 fix does exactly what the finding recommended: a fourth structural guard (R9d) pinning the stillness ticker's constant, cadence-sleep, stillness fold, and start wire, with a genuine non-vacuity fixture.
- The delta vs the reviewed tree is provably confined to the test file (+38, zero deletions) and the task file (+5); `MomoAppModel.swift` is byte-identical to the reviewed tree (sha256 equality with the first review's restoration proof).
- The guard was bitten three ways on the real file — cadence literalized, start wire removed, payload perverted — each failing EXACTLY its own test and no sibling, each restored sha256-identically; the full package reruns green at 907/92, the sole delta being the new test.
- The reviewed-tree UI (17/17) and Watch gates carry over validly per §5.
- Notes N-1/N-2/N-3 are records only; no changes are required.

This review made no commits, no git writes, and no repository modification except this record; all three bites were restored byte-identically before this record was written.
