# REVIEW-TASK-040-delta — verification of the F-1/F-2 fix unit

- **Delta scope**: REVIEW-TASK-040 findings **F-1** (HIGH — the reset marker's launch-load site and erase-save site resolved different directories) and **F-2** (MEDIUM — the test gap that let it through), as one fix unit per the original review's §7. F-3…F-8 are accepted notes and were explicitly NOT re-litigated. Everything outside the fix unit was checked for accidental change (hash reconciliation below).
- **Delta review date**: 2026-09-11
- **Reviewer**: independent §11 delta-review agent (fresh Jupiter session; adversarial stance — every fix-agent claim verified at source, plus independent mutation probes)
- **Tree state**: branch `feature/EPIC-008-watch-sync`, HEAD `c5430f3` (unchanged throughout), implementation UNCOMMITTED in the working tree. Working tree inspected, probe-mutated, and left byte-identical — both probe cycles sha256-restored (records below).

---

## 1. F-1 closed — both runtime paths resolve to the SAME directory (verified at source)

**Launch-load path**: `Apps/Momo/MomoAppModel.swift:384` (`self.watchResetMarkerEraseCount = Self.loadResetMarkerEraseCount()`) → static helper `loadResetMarkerEraseCount()` at `Apps/Momo/MomoAppModel+Watch.swift:60-71` → **`try StoreRules.watchResetMarkerDirectory()`** (`+Watch.swift:63`) → `WatchResetMarkerStore(directory:).load()?.eraseCount ?? 0` (`:69-70`).

**Erase-save path**: `Apps/Momo/MomoAppModel+Settings.swift:100` (`markerDirectory = try StoreRules.watchResetMarkerDirectory()`) → load +1 → `markerStore.save(...)` (`:106-108`).

Both call the SAME `StoreRules.watchResetMarkerDirectory()` (StoreRules.swift:141-143 = `defaultDirectory().deletingLastPathComponent()` = the Application Support ROOT; `defaultDirectory()` = `Application Support/Momo/`, StoreRules.swift:162-170). The pre-fix divergence (load = store tree) is structurally gone: the init no longer constructs a `WatchResetMarkerStore` at all (grep + guard leg 2). Erase → relaunch now re-reads the marker the erase wrote, so `watchResetMarkerEraseCount` restores and every subsequent context carries the count (`pushWatchSnapshot()` at `+Watch.swift:121` reads the stored property).

**Failure-path discipline mirrors the erase site**: the helper's catch does `Self.debugLoud(...)` + the same throwaway `FileManager.default.temporaryDirectory/Momo-marker-fallback` fallback (`+Watch.swift:65-67`) exactly as `+Settings.swift:102-104`; in the fallback the `load()` naturally returns nil → 0. Degraded semantics UNCHANGED (missing/garbled marker → 0 → no erase pending). `Self.debugLoud` is a `static func` (`MomoAppModel.swift:795`), so the static hop is legal. **OBS-1 holds**: the load remains the same init call site joining the ONE sanctioned synchronous launch read — a static hop, no new I/O site, KB-scale.

**Line budget held**: the init swap was line-neutral (4 lines → 4 lines, `MomoAppModel.swift:381-384`); `wc -l` = **800/800** (F-8's zero headroom respected). The helper lives in `+Watch.swift` per the D-8 extension-file pattern.

## 2. Guard 4 — structure and non-vacuity (verified at source)

`Tests/MomoKitTests/Support/WatchWiringScan.swift:201-239` — `markerDirectoryViolations(files:)`, name `"reset marker → one directory rule"`, four legs, all on comment-stripped text (`MomoKitDisciplineScan.strippingComments`, verified: strips `//` and `/* */` while tracking string-literal state, MomoKitDisciplineScan.swift:139-169):

1. `MomoAppModel.swift` must route the init load through `loadResetMarkerEraseCount()` (:207-212);
2. `MomoAppModel.swift` must construct NO `WatchResetMarkerStore(` directly (:213-218) — the F-1 shape in the init;
3. `+Watch.swift` (launch-load derivation) must cite `watchResetMarkerDirectory()` (:231-236);
4. `+Settings.swift` (erase-save derivation) must cite the same token (:231-236) — a ONE-SIDED future edit of either site goes red.

Missing files yield findings ("file missing from Apps/Momo"), so the guard cannot pass vacuously over a renamed/absent app target.

**Test deliverable**: 7 new tests in `MomoWatchWiringScanTests.swift` (suite 14 → 21 — count verified by reading the file and by the post-restore filtered run reporting "21 tests in 1 suite"): per-site derivation-off-rule reds (`markerLoadOffRuleFails`, `markerSaveOffRuleFails` — each asserting the finding's file and "derivation" detail), the F-1 init-reversion shape → **both** main legs, count == 2 (`markerInitDirectStoreLoadFails`), comment-only rule token must NOT green either derivation (`markerLoadCommentOnlyTokenFails`, `markerSaveCommentOnlyTokenFails` — the D-10 stripper discipline), a green fixture (`markerDirectoryGreenFixturePasses`), and the standing real-tree test `realTreeMarkerLoadMatchesSaveRule` (`:333-338`) which reads the ACTUAL `Apps/Momo` sources via `KitRepo.momoAppSources()` (verified: directory listing of `Apps/Momo` anchored at `#filePath`, KitRepo.swift:43-52). No tautologies: red and green fixtures differ by exactly the load-bearing token; the comment-only fixtures pair a legal token position with an off-rule code line. (Known textual-guard limit, same class as guards 1–3 and accepted in the D-10 adjudication: a token inside a string literal would satisfy `contains` — the stripper deliberately leaves string literals intact. Not a finding.)

## 3. Independent mutation probes (delta reviewer's own; both full-suite; every restore sha256-verified)

| Probe | File (sha256 before == after) | Mutation | Result |
|---|---|---|---|
| D1 | `Apps/Momo/MomoAppModel+Watch.swift` `de900215050e5437…` | `try StoreRules.watchResetMarkerDirectory()` → `try StoreRules.defaultDirectory()` (:63) — the EXACT F-1 reversion (load reverts to the store tree) | Full suite: **995 tests run, EXACTLY ONE failure** — the new standing test `realTreeMarkerLoadMatchesSaveRule`, sole finding `guardName: "reset marker → one directory rule"`, `file: "MomoAppModel+Watch.swift"`, detail "the launch-load derivation does not cite StoreRules.watchResetMarkerDirectory()…". Nothing else red. Mutated hash `b4a7253b04166d8e…` (matches the fix agent's recorded bite hash — the identical mutation). Restored; hash byte-identical. |
| D2 | `Apps/Momo/MomoAppModel.swift` `ef7d2d5a7efb9bf1…` | init line → `WatchResetMarkerStore(directory: directory).load()?.eraseCount ?? 0` — the LITERAL pre-fix F-1 code | Full suite: **995 tests run, EXACTLY ONE failure** — the same standing test, with **BOTH main legs** (count == 2, both `file: "MomoAppModel.swift"`): "does not route through loadResetMarkerEraseCount()" + "constructs a WatchResetMarkerStore directly". Matches the fixture test's prediction. Nothing else red. Restored; hash byte-identical. |

Restores verified: post-restore hashes equal the fix agent's table exactly; post-restore `swift test --filter MomoWatchWiringScanTests` = 21/21 PASSED; `git diff Sources/MomoCore/` still 0 bytes; `git status --porcelain` file set unchanged (20 entries, same set as before the probes).

**The F-2 blind spot is closed**: the original review's Probe C (load redirected to a nonexistent directory → 988/988 green) has no modern equivalent — every reversion shape of the divergence class now turns the standing test red, at real-tree level, on the exact production files.

## 4. Nothing outside the fix unit changed (hash reconciliation)

All 18 files of the original handoff's hash table recomputed with `shasum -a 256`:

- **14 non-fix files** match the original handoff table's truncated hashes exactly: `StoreRules.swift` `f426dd39b0d824b3…`, `SyncDTOs.swift` `ba947350cea5a044…`, `WatchSnapshotBuilder.swift` `13f4837ee325231b…`, `WatchReceivePlan.swift` `efb4b52ce90386b3…`, `WatchResetMarker.swift` `b016a90e4d05c972…`, `WatchResetMarkerStore.swift` `995d4967edf16d5b…`, `MomoAppModel+Settings.swift` `71fd3900ba006dd8…`, `MomoWatchTransport.swift` `4e3e0b8ceef85085…`, `MomoApp.swift` `54e51f4c50f7424f…`, `WatchResetMarkerTests.swift` `2d0fdd8ad1d5c111…`, `WatchReceivePlanTests.swift` `2fab68f167447ab8…`, `StoreRulesPinnedTests.swift` `0a858c99696e1ed1…`, `Support/KitRepo.swift` `5973deb63979f6b6…`, `project.pbxproj` `bd8f2910c0f4ea18…`.
- **4 fix-touched files** match the fix agent's full-hash table exactly: `MomoAppModel.swift` `ef7d2d5a7efb9bf1ce73bc4c3b1af0a87c5d64a274b9d3f5421e4caba6143ccf`, `MomoAppModel+Watch.swift` `de900215050e543725ec4764a01494821c700297ff5809e7f03f7f1885637e2f`, `MomoWatchWiringScanTests.swift` `620b52d30b139b6888273124f215927c282dde22790b35da5fd4ceb9708a6219`, `Support/WatchWiringScan.swift` `61dc21635fb3243f32ad993e1132f0983152dc70a10878c51e459d0b533fe867`. The fix table's pre-fix values also equal the original handoff table (chain consistent).
- `git status --porcelain`: identical FILE SET to the reviewed tree (the fix touched only already-modified/untracked files; the task file gained its appendix). Branch and HEAD unchanged. **Zero accidental changes.**

## 5. Gate reproduction (all re-run by the delta reviewer at the fixed tree)

- `swift test`: **995 tests / 100 suites PASSED** (review baseline 988 + the 7 guard-4 tests; run twice — fixed tree and post-probe-restore filtered confirmation).
- `xcodebuild -project Momo.xcodeproj -scheme Momo -destination 'id=1F25E487-A78E-464C-95AF-0BD1A9B3E1BE' build`: **BUILD SUCCEEDED** (the load-site helper lives in the app target, which `swift test` does not compile — the build gate is load-bearing and was run).
- `git diff Sources/MomoCore/`: **EMPTY** (0 bytes).
- `wc -l Apps/Momo/MomoAppModel.swift`: **800** (budget exact); `MomoAppModel+Watch.swift` 193 (≤ budget).

## 6. Delta findings

None new. One §25-honesty cross-check: the fix agent disclosed that its FIRST bite pre-dated the fixed-state hash snapshot (evidence from a second, properly captured cycle) — this delta review's own D1 cycle reproduces the identical mutated hash (`b4a7253b04166d8e…`) and the identical single-failure result, independently supplying the before/during/after evidence chain. The fix-agent appendix's claims were verified true in every particular.

## 7. Verdict

**DELTA VERIFIED — F-1/F-2 closed; TASK-040 review cycle complete; final status: APPROVED_WITH_MINOR_NOTES** (the notes being F-3…F-8 as accepted by the orchestrator).

The fix is minimal, correctly placed (ADR-013 extension-file pattern; the 800-line budget held via a line-neutral swap), mirrors the erase site's degraded-path discipline, and is pinned by a four-leg structural guard whose standing test this delta reviewer independently mutation-proved load-bearing at real-tree level — twice, full-suite, exactly one red each time, byte-identical restores. The task may proceed to the single atomic closeout commit per §12/§13.
