# REVIEW-TASK-036 — Quest moments + celebrations

- **Reviewer:** fresh independent review agent (Jupiter), per CLAUDE.md §10/§33 — not the implementation agent; mandate was to disprove correctness, not confirm it.
- **Date:** 2026-09-11
- **Task:** `.claude/tasks/active/TASK-036-quest-moments.md`
- **Scope under review:** the uncommitted working-tree delta on `feature/EPIC-007-iphone-home` at HEAD `94bf69b`. No commit, push, or branch operation was performed by this review; the only repository writes were mutation bites (each restored byte-identically, sha256-proven) and this record.

## Scope Audited

19-file surface, verified live via `git status` / `git diff --shortstat`:

- 16 tracked modified files, shortstat **+980/−81**; of these the task file accounts for **+123/−6**, so the **source delta is +857/−75 across 15 modified files** — exactly matching the implementation handoff.
- 3 new files: `Sources/MomoKit/QuestMomentSupport.swift` (114 lines), `Tests/MomoCharacterTests/MomoMomentQueueTests.swift` (217), `Tests/MomoKitTests/QuestMomentTests.swift` (154).

Files: `MomoReactionState.swift`, `MomoReactionDirector.swift`, `MomoAppModel.swift`, `QuestMomentSupport.swift` (new), `HomeQuestCardView.swift`, `HomeView.swift`, `MomoApp.swift`, `HomeReadModel.swift`, `HomeCopyKeys.swift`, `MomoCopy.xcstrings`, `RigDisciplineTests.swift`, `MomoMomentQueueTests.swift` (new), `QuestMomentTests.swift` (new), `HomeReadModelTests.swift`, `MomoReduceMotionTwinTests.swift`, `CatalogCopyLawTests.swift`, `MomoCatalogScaffoldingTests.swift`, `MomoHomeUITests.swift`, task file.

**Requirements audit:** R1–R10 and Acceptance Criteria 1–7 each traced to diff evidence and found landed: R1 event-born door + state-born greeting split; R2 FIFO queue with three guarded advance sites and exactly-once reports; R3 flip diff → swell + haptic + announcement; R4 celebration banner (auto-fade 4.0 s, crossfade 0.3 s, tap-dismiss, composed line); R5 hour-aware `isAllDone` + warm note; R6 fixed-lookup copy law; R7 gated delivery haptics; R8 RM surfaces untouched + twin suites green; R9e–g three new structural guards with violation fixtures; R10 gates recorded. No requirement found unmet.

**Scope walls — all held.** No diff touches `MomoMoments.swift`, `MomoReduceMotion.swift` (source), `CopyRules.swift`, `LineSelection.swift`, anything under `Sources/MomoCore/`, the Watch targets, or `AppModelPlan.swift`. `MomoCharacter` changes are confined to the two authorized files. `CopyRules.copyEpoch` remains **4** (`CopyRules.swift:65`, pinned at `CopySelectionPinnedTests.swift:29`) — **no epoch bump**. Epoch-4 residue pins verified verbatim green: copy slots `.07`, react.touch `.02`, pools `.01`, CareInteractionTests `2026-09-09`→`.04` / `2026-09-08`→`.01`. Exhaustive-switch census accurate: only `MomoReduceMotionTwinTests` needed the new-case extension.

**Semantic verifications (all seven):**
1. **Greeting exclusion + fold ordering** — `.deliverMoments` arm filters via `QuestMomentSupport.eventBornMoments` *before* `foldDirector(.moments(...))`; the greeting rides only the state-born `.displayState` door whose transition is the dedupe. No double-play path found.
2. **Director FIFO exactly-once** — `pendingMoments` appended under `applyMoments` (empty batch no-ops), advanced at three sites (idle fold, L4 completion block at `moment.start + duration`, `applyShown` behind the deferred-greeting branch), each guarded `!hidden, moment == nil`; `.momentFinished` reports exactly once via the `reported` flag + slot clear.
3. **UX-10 once-semantics** — engine-owned `highestCelebratedStage`; banner presentation is stateless (no persistence), so a repeated crossing re-banners but never re-celebrates the stage record.
4. **Haptics gated at the seam** — `MomentHapticKind.deliveryKinds(for:hapticsEnabled:)` gates the whole batch on `state.settings.hapticsEnabled` at delivery, RM-independent; grep-proven `ResponsePlan.haptic` remains nil at its only construction site (`InteractionSemantics.swift:480`) — the engine haptic law is untouched.
5. **Cascade-derived `isAllDone`** — `HomeReadModel.isAllDone` is `QuestGeneration.cascade(questSet:localHour:) == .allDone` and nothing else; `allDoneTruth` pins the hour-aware legs.
6. **Fixed-lookup moment copy** — `momo.line.moment.01` (positional template) and `.02` landed verbatim; `.00` placeholder removed; the catalog scan count rose 70→71 with the placeholder exemption removed; no epoch bump (OBS-D precedent correctly applied).
7. **Greeting LineSelection/pools unchanged** — no diff hunk touches the greeting selection path or pool sizes.

## Findings

| # | Severity | Finding | Evidence | Disposition |
|---|----------|---------|----------|-------------|
| F-1 | MINOR | **Undisclosed deviation:** the `deliverMoments` app-model closure was removed (delivery implemented inline in the `.deliverMoments` arm), while the task contract (Context, note on the closure seam) says the closure "stays an unfilled shell seam … do NOT remove the closures." Disclosed only in a code comment (`MomoAppModel.swift`, pre-arm comment block); absent from the task file's Known Deviations. | Contract text vs. working tree (no `deliverMoments` closure remains); behavior verified correct by semantic checks 1–7 above. | No code change. Orchestrator appends this deviation to the task file's Known Deviations at closeout (§25/§26 record-keeping). |
| F-2 | MINOR | **R9e is blind to sink-invocation removal** — the guard pins the gate expression and the fan-out call, but not `momentHapticSink(kind)` itself. A regression that silently drops the haptic wire would pass R9e. Proven live by negative bite 4 (below). Current runtime behavior is correct and unit-covered (`QuestMomentTests`). | Bite 4: `momentHapticSink(kind)` → `_ = kind`; focused `RigDisciplineTests` run **23/23 PASSED** — no guard noticed. | One-line follow-up: add `momentHapticSink(kind)` as a fifth leg of `mentionsMomentFanOut` (+ its violation-fixture update). Recommend bundling into the next fix cycle; non-blocking. |
| F-3 | OBS | `isAllDone` is **hour-aware**, so the M3 warm note can appear or disappear as the local hour passes (feed/play families surface all day; Q1 morning-only, Q6 evening) even with quests complete. By contract (AC pins cascade-derived truth) and pinned by `allDoneTruth`, but product-facing and worth owner awareness. | `HomeReadModel.swift` derivation; `QuestGeneration.swift:211-245` rules; `allDoneTruth` test. | No change; surfaced for owner visibility. |
| F-4 | NITPICK | The `", done"` / `", pending"` label composition is duplicated between `HomeQuestCardView.swift:106` (a11y label) and the app-model announcement path. | Side-by-side read. | Acceptable (different surfaces, different lifetimes); optional extraction later. |
| F-5 | NITPICK | Two consecutive accessibility announcements in one batch (quest-done + stage line) may coalesce under VoiceOver on some OS versions. The composed banner line already merges celebration copy into one utterance, which bounds the impact. | Announcement call sites. | None. |
| F-6 | OBS | `celebrationLine(for:)` recomputes copy per render. | Read. | Negligible cost; not worth caching. |

No MAJOR findings. No correctness, concurrency, security/privacy, or scope violation found.

## Mutation Bites (duty D — guards proven to bite)

Every mutation was edit-restored afterward; restoration is sha256-proven. Bites 1–3 are runtime-identical refactor mutations that isolate a textual guard leg (the guard should fail, the app should not change behavior); bite 4 is a deliberately runtime-changing negative probe.

| # | Guard / target | File | Mutation | Focused-suite result | Restoration proof |
|---|----------------|------|----------|----------------------|-------------------|
| 1 | R9e `mentionsMomentFanOut` — gate leg | `Apps/Momo/MomoAppModel.swift` | Hoisted `let hapticsAllowed = state.settings.hapticsEnabled`; call reads `hapticsEnabled: hapticsAllowed` (exact-string leg broken; behavior identical) | `swift test --filter RigDisciplineTests`: **exactly 1 failure** — `RigDisciplineTests.swift:499:9` | Edit-reverted; final file sha256 `90133e211587855727f6aae658a3251fb0b5cce1e515e58845027057cdf205f5` |
| 2 | R9f `mentionsMomentQueueAdvance` — single leg | `Sources/MomoCharacter/MomoReactionDirector.swift` | Hoisted `let momentEnd = moment.start + MomoMoments.duration(for: moment.moment)`; report + advance sites read `momentEnd` | **Exactly 1 failure** — `RigDisciplineTests.swift:517:9`; behavioral neighbor `MomoMomentQueueTests` **7/7 PASSED** under the mutation (runtime-identity proof) | Edit-reverted; file sha256 `64d868e2d4b1cc16c9a4f6e2fd06ad9ece36025becd9afbd5093cdbd9cd0f358` |
| 3 | R9g `mentionsCelebrationAutoFade` | `Apps/Momo/MomoAppModel.swift` | `Task { await autoFadeCelebration() }` → `Task { await self.autoFadeCelebration() }` | **Exactly 1 failure** — `RigDisciplineTests.swift:537:9` | Edit-reverted; covered by the final `MomoAppModel.swift` sha256 above (bites 1, 3, 4 share the file) |
| 4 | **Negative probe** — R9e blindness (F-2 evidence) | `Apps/Momo/MomoAppModel.swift` | `momentHapticSink(kind)` → `_ = kind` (runtime-CHANGING: dead haptic wire) | `RigDisciplineTests`: **23/23 PASSED** — guard blind, as F-2 records | Edit-reverted; sha256 re-verified after all restorations |

Each of R9e/R9f/R9g fails with exactly its own test under its own bite and nothing else — no self-biting, no collateral failures. The negative probe additionally proves the one real gap (F-2).

## Full-Suite Results (duty E)

- **Pre-bite baseline:** `swift test` → **925 tests / 94 suites, all PASSED**.
- **After all restorations (final run):** `swift test` → **925 tests / 94 suites, all PASSED**, with both bitten files sha256-verified byte-identical to their pristine state (`90133e21…`, `64d868e2…`). The working tree is bit-for-bit what the implementer handed off.
- **UI suite / Watch build:** NOT executed by this reviewer (mandate: no UI-test run, no pinned simulators). Accepted on the implementation handoff's recorded evidence (UI 21/21 on the pinned SE; Watch scheme BUILD SUCCEEDED); the orchestrator owns the §19 glass gate before commit.

## Disclosure Audit (duty F)

Both disclosed deviations (import fix in `HomeQuestCardView`; M1 flourish/haptic un-assertable at the glass) were verified as stated in the task file. One undisclosed deviation found: **F-1** (closure removal, disclosed only in code). No other undisclosed deviation found — the fixture enabler's store-infeasibility verdict and the banner non-deferral are recorded as claimed.

## §10 Checklist Sweep (duty G)

Correctness (semantic checks 1–7), task-requirement trace (R1–R10, AC1–7), architectural consistency (two-doors moment architecture preserved; engine/presentation boundary respected), regressions (epoch-4 residue verbatim; pools untouched), edge cases (empty batch, hidden accumulation, maximal 3-batch, reversal/absent-day diffs — all unit-pinned), test quality (18 new tests; both-direction violation fixtures; bite-proven guards), error handling (unknown fixture kind asserts in DEBUG), concurrency (@MainActor isolation; boundary scheduling precedes the effect await), performance (F-6 negligible), security/privacy (no secrets, no new entitlements, no network), accessibility (labels in words, hidden decoratives, full-line banner announcement; F-5 platform note), Apple-platform conventions (UIKit-default haptic sink injection; Reduce Motion honored), dead code (`.00` removed rather than retained), unnecessary complexity (none found), scope creep (none — 19-file surface exactly matches contract).

## Overall Status

**APPROVED_WITH_MINOR_NOTES**

The implementation is correct, complete against its contract, and within scope; all three new structural guards demonstrably bite. The two MINOR findings are record-keeping (F-1: append the disclosed-in-code closure removal to the task file) and guard-hardening (F-2: one added R9e leg + fixture) — neither blocks commit. Dispositions for F-1/F-2 belong to the orchestrator's closeout and the next fix cycle respectively.

REVIEW-COMPLETE TASK-036
