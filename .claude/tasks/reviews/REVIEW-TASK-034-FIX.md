# REVIEW-TASK-034-FIX — Delta re-review of the F-1/F-2 fixes (§11 review/fix loop)

- **Task:** TASK-034 — touch & petting (EPIC-007 — iPhone Home Experience); post-fix delta re-review mandated by REVIEW-TASK-034's CHANGES_REQUIRED verdict
- **Branch:** `feature/EPIC-007-iphone-home`
- **HEAD:** `134284a400ea22df454aac498a188dd56a2f5aa7` (tree uncommitted, same base as the first review)
- **Review date:** 2026-09-11
- **Reviewer:** fresh independent delta-review agent (Jupiter); received the first review + fix agent's claims as CLAIMS ONLY — every claim re-derived from primary sources per §33 (adversarial posture: attempted to disprove, not confirm)
- **Method:** scope-exactness verification via `git status`/`git diff`; primary-source reads of the changed files, the frozen rig/director surfaces, and 05-technical-architecture §4.2; my own mutation bite with sha256-proven restoration; my own full `swift test` + `xcodebuild build` + full UI suite on the pinned simulator. No source, test, catalog, or project file was modified or staged; the only file written is this review. The mutation bite's single sanctioned file edit was restored byte-identically (hashes below).

---

## 1. Scope inspected — delta exactness VERIFIED

Dirty set: **17 modified + 6 untracked**. First review §1 recorded 16 modified + 5 new. The delta against that set is **exactly**:

1. `Tests/MomoCharacterTests/RigDisciplineTests.swift` — newly modified (was clean in round 1); its entire diff vs HEAD is the guard helper + guard test + non-vacuity pin (§4 below).
2. `.claude/tasks/reviews/REVIEW-TASK-034.md` — the first reviewer's own document (untracked).

Everything else is the round-1-reviewed set. Frozen surfaces re-verified: `git diff -- Sources/MomoCharacter/` is **EMPTY**; `Sources/MomoCore/` touches only `CopyRules.swift` (the round-1-reviewed carveout); `docs/` untouched. No third file, no stray edits. The re-review delta is exactly the three files named by the mandate.

## 2. (a) F-1 resolution — VERIFIED RESOLVED

- `Apps/Momo/HomeView.swift:119-125` — `canvasBody` now constructs `MomoRigView(displayState:tier:clock:stageSide:reactionMotion: appModel.reactionMotion())`; the diff vs HEAD shows this is the ONLY new content in the file beyond the round-1-reviewed hunks (doc comment, custom actions, touch-surface overlay, `accessibilityActions`).
- Signature match against the frozen initializer (`Sources/MomoCharacter/MomoRigView.swift:79-90`): the parameter is `reactionMotion: @escaping @Sendable (Double, Bool) -> MomoReactionMotion` (default `{ _, _ in .identity }`); the factory returns exactly `@Sendable (Double, Bool) -> MomoReactionMotion`. Labeled call site, so position is immaterial; label + type match.
- Factory (`Apps/Momo/MomoAppModel.swift:370-377`): captures `let director = self.director` **by value** (:371) and returns a closure selecting `director.overlay(at:)` / `reduceMotionOverlay(at:)` by the resolved RM flag. `MomoAppModel` is `@MainActor` (:62), so the call site in `canvasBody` is main-actor; the returned closure touches only the captured value, so `@Sendable` is sound.
- Per-frame sampling re-confirmed in the frozen rig: `renderedPose(at:)` calls `reactionMotion(time, reduceMotion)` on every `TimelineView` frame (`MomoRigView.swift:140-147`). With the non-identity closure now injected, the L1 press layer, §6.1 clips, stir, and coalescing render on the composed Home. The `@Observable` director property (:163) is read through `reactionMotion()` during body evaluation, so each fold re-renders with a fresh closure. R3's rendering leg and AC-1's through-the-composed-Home requirement are now wired. **F-1 closed.**

## 3. (b) F-2 resolution — VERIFIED RESOLVED; comment now truthful

- `Apps/Momo/MomoAppModel.swift:279-295` — the case is split exactly as the first review suggested: `.background` → `foldDirector(.appHidden)` + `backgrounded()`; `.inactive` → `foldDirector(.appHidden)` **only** (:287-292), with an in-case comment citing §4.2's missing `.inactive` row.
- Doc comment (:267-278) rewritten to describe precisely this: `.inactive` "triggers NOTHING in §4.2's table — its fold below is the DIRECTOR's clock-pause gate ONLY"; "Only `.background` ALSO runs the §4.2 backgrounding side"; ".inactive leaves the engine semantics untouched". Verified true against the code: `.inactive` calls no `foregrounded()`/`backgrounded()`/`apply()` — the engine is untouched, matching TASK-031's reviewed semantics (05-technical-architecture.md §4.2 trigger table, doc lines 278-284: rows are `scenePhase → active`, interaction, report, `in-session only` boundary, time change — **`.inactive` has no row**; HEAD's code was `case .inactive: break`). **F-2 closed; §25 truthfulness restored.**

## 4. (c) Behavioral-delta adjudication — ACCEPTABLE AND TRUTHFULLY DISCLOSED

The disclosed delta vs round 1: during `.inactive`, `isForeground` stays `true` and a live `boundaryTask` is not cancelled, so a boundary firing mid-transition now proceeds to its fold instead of being refused. Adversarial analysis:

- **Authority:** 05 §4.2 scopes the boundary row "in-session only". `.inactive` (app-switcher overlay) is still in-session — process and scene alive; the doc's "if the app is backgrounded first, the scheduled call simply does not matter" now keys off real backgrounding only. The fixed code matches the doc's letter at least as well as round 1 did; the fold that now proceeds is the same deterministic engine catch-up the doc prescribes for a boundary instant.
- **No corruption:** `MomoAppModel` is `@MainActor` (:62); `foldDirector` (:383) and the async `apply` loop serialize on one actor — a boundary fold interleaved with scene-phase folds cannot race.
- **No double-fold on `.active`:** a boundary that fires during `.inactive` is consumed — `scheduleBoundary` (:484-496) cancels and re-derives the next instant ("re-schedule, never replay"); the subsequent `.active` catch-up (`foregrounded()` :500-503 → `.foreground` trigger) is segment folding (05 §4.2: "each segment applies its rule once") — idempotent, no replay. The director's display-state feed is equality-gated (:434-439), so no duplicate director folds either.
- **Double `.appHidden` (.inactive → .background) is not new** — round 1 had the same two-fold shape, and the frozen director is guarded: `applyHidden` reports cancellation once per slot (reported flags, `MomoReactionDirector.swift:590-596`), nils `stateLayer`, and `applyShown` (:617-631) clears all slots and restarts choreography from 0 (ADR-010).
- Residual honesty check: the delta means an engine fold can run while the user holds the switcher open. Its effects (state change + store save, next boundary re-derived) are exactly what would happen one second later on `.active`; the end state is identical. **No defect follows.** Verdict: acceptable-and-truthfully-disclosed.

## 5. (d) Guard soundness — ATTACKED, HELD

- **Fails under the regression:** empirically — my own bite (below) removed the argument; `homeWiresReactionMotion` failed. The guard reads the live file at test time (`readRigFile`, `RigDisciplineTests.swift:152-155`, via `RepoTree.repoRoot` built from `#filePath` — `Tests/MomoCharacterTests/Support/RepoTree.swift:12-17`; no CWD dependence, no build dependency — pure text scan).
- **Non-vacuity pin is non-tautological:** helper stubbed to `true` → the pin's `#expect(!mentionsHomeReactionWiring(in: <F-1 shape>))` (:328-336) fails; stubbed to `false` → the live-source expect (:323) fails. The helper cannot be vacuous while the test passes.
- **Bypass shapes probed:** a literal identity closure (`reactionMotion: { _, _ in .identity }`) does NOT contain the required `reactionMotion: appModel.reactionMotion()` substring → caught. Wiring moved out of `HomeView.swift` → the read file lacks the string → caught (safe false-alarm direction). A second `MomoRigView(` construction elsewhere in the file satisfying the AND while the canvas one regresses is theoretically possible but contrived — and the rig's identity default itself is frozen (`Sources/MomoCharacter/` diff empty), so the fallback cannot be weakened. The guard pins exactly the F-1 shape; depth is appropriate for a structural wire check.
- **File access precedent:** `readRigFile` and `RepoTree` are pre-existing suite infrastructure (used at :196, :205, :234, :243, :266, :274, :295, :312, :351, :369, :380 for `Sources/` files; the same `#filePath`-walk pattern also exists in `Tests/MomoCoreTests/Support/TestRepo.swift:10`). Reading `Apps/Momo/HomeView.swift` is a **first** (no prior `Apps/` read in this suite) but mechanically identical — a rename/move of HomeView fails the test loudly, which is the safe direction. New capability, no new fragility.
- **Mutation bite (my own run):** removed the single `reactionMotion: appModel.reactionMotion()` line from `Apps/Momo/HomeView.swift`; `swift test --filter homeWiresReactionMotion` → **"Test run with 1 test in 1 suite failed after 0.001 seconds with 1 issue"** — exactly one failure, the guard itself. Restored from a pre-bite copy: sha256 before `b1cd33e987f58493a80ef0d45481ccecdabfb53116c3979ecb674e7f81f8cd85` == after restore (byte-identical); `git diff` returned to the reviewed 21-insertion/2-deletion shape; post-run `git status` shows the same 23-entry dirty set. Bite residue: none.

## 6. (e) Regressions — NONE FOUND

- All three files' diffs vs HEAD reconcile hunk-for-hunk with the round-1-reviewed content plus only the F-1 line, the F-2 case split + comment, and the guard test (§1).
- **Full package suite (my run): `swift test` → "Test run with 887 tests in 91 suites passed"** — matches the fix agent's claim; delta vs round 1's 886 = exactly the new guard test.
- **UI suite (my run):** `xcodebuild test -scheme Momo -only-testing:MomoUITests` on pinned simulator `1F25E487-A78E-464C-95AF-0BD1A9B3E1BE` → **13 tests, 13 passed, TEST SUCCEEDED** (~3m47s), including `testCanvasGesturesRouteThroughTheAppModelInPlace` and `testPettingMovesNoStageWords` against the now-wired rig.
- **App target build (my run):** `xcodebuild build -scheme Momo` on the pinned simulator → **BUILD SUCCEEDED, exit 0** (only pre-existing `/opt/extra/lib` ld search-path warnings).

## 7. (f) Hygiene — CLEAN

- TODO/FIXME/HACK/XXX, print/debugPrint/NSLog across the three delta files: **0 hits**.
- Lengths: HomeView.swift 151, MomoAppModel.swift 563 (grew 9 lines with the F-2 comment — still ≤ 800), RigDisciplineTests.swift 383.
- Imports: view/app files within the sanctioned view-layer set; `Tests` file Foundation/SwiftUI/Testing; `Sources/MomoKit/` imports no `MomoCharacter` (grep-verified).
- Frozen surfaces and docs untouched (§1).

## 8. Fix-agent disclosure adjudication

| # | Claim | Verdict |
|---|-------|---------|
| 1 | HomeView ~:124 passes `reactionMotion: appModel.reactionMotion()` as the 5th rig argument | **VERIFIED** (HomeView.swift:119-125; label/type match the frozen init, MomoRigView.swift:79-90) |
| 2 | MomoAppModel :267-292 case split + corrected comment + disclosed `.inactive` behavioral delta | **VERIFIED** (:267-278 comment; :279-295 switch; delta exactly as disclosed — adjudicated acceptable, §4) |
| 3 | Structural guard in RigDisciplineTests with non-vacuity pin; mutation-bitten (exactly 1 failure), restored byte-identically | **VERIFIED** (helper :141-151, test :320-337; my independent bite reproduced exactly 1 failure; my restoration hash-matched) |
| 4 | swift test 887/91 PASSED; app UI suite 13/13 on the pinned simulator; dirty set = round-1 set + the guard test file + the two documents | **VERIFIED** (my own runs reproduce all three numbers; §1 confirms the set) |

## 9. Non-blocking notes carried from round 1

N1 (superseded maturation task not cancelled), O1 (straight apostrophe in `touch.03`, contract-faithful), O2 (pbxproj exactness) — unchanged by the delta, all non-blocking.

## VERDICT

**APPROVED**

- F-1 (HIGH): resolved — the composed Home now samples the director per frame through a correctly-captured, correctly-typed closure; R3's rendering leg and AC-1 are wired.
- F-2 (MEDIUM): resolved — `.inactive` folds the director gate only; `.background` alone runs backgrounding; the doc comment is truthful and matches TASK-031/05 §4.2 semantics.
- The disclosed behavioral delta is acceptable and truthfully disclosed; no defect follows from it.
- The structural guard bites (empirically re-proven) and is non-vacuous.
- My own reproduction: 887 tests / 91 suites passed; UI suite 13/13 passed; app build succeeded; frozen surfaces intact; hygiene clean.

No findings remain. TASK-034 is clear for the §19 gate → commit → push.
