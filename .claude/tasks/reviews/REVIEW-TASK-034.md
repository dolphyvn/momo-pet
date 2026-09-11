# REVIEW-TASK-034 — Touch & Petting (§10 independent review)

- **Task:** TASK-034 — touch & petting (EPIC-007 — iPhone Home Experience)
- **Branch:** `feature/EPIC-007-iphone-home`
- **Base commit reviewed:** `134284a400ea22df454aac498a188dd56a2f5aa7` (HEAD; tree uncommitted)
- **Review date:** 2026-09-11
- **Reviewer:** fresh independent review agent (Jupiter); received task requirements + repo only — not primed with implementation claims
- **Review method:** §33 independence — every implementer claim re-derived from primary sources (contract, normative docs, `git diff`, source reads), all tests executed by this agent, plus one contract-sanctioned mutation bite with sha256-proven restoration. No source, test, catalog, or project file was modified or staged; the only file written is this review.

---

## 1. Scope inspected

Full working-tree diff against `134284a` (16 modified + 5 new files), each new file read in full; the five normative spec surfaces (02-mvp-prd FR-5/FR-10/G2, 03-ux-architecture §5.1/§10/UX-8/UX-14, 04-character-system §2.1/§2.3/§2.4/§6.1/§6.2/§9.2/§10.1/§10.2, 05-technical-architecture §4.9/§4.10/D-R5); the frozen surfaces re-diffed for regression; all new and re-pinned test files read; the epoch-3 selection chain re-derived independently outside the repo (Python scratch, `/tmp/review-task-034/`); the Xcode 26.5 SDK swiftinterface grepped directly for disclosure (b).

## 2. Independently derived requirements (authorities checked, not the implementer's restatement)

1. **04 §2.3 zone partition** — y-down normalized grid, rule line y = 550, head `y < 550`, belly `y ≥ 550`; the canvas is ONE VoiceOver element with custom actions "Pat"/"Cuddle" ONLY (feed/play/care stay buttons; 03 §5.1, 04 §10 no-rotor-duplication).
2. **04 §6.1 gesture×zone rows** — tap·head, tap·belly, one zone-less double-tap row, long-press·head/belly, stroke·head/belly; §6.2 state gating (sleeping → stir, stays asleep).
3. **R3** (contract :86): each §6.1 class **renders** its engine-distinct clip through the director. **AC-1** (contract :156): every row's response arrives **through the composed Home** (director-level evidence per row; UI smoke for tap-family rows).
4. **FR-5 AC-2/3/4** — reactions available in every state incl. sleeping; no lock/penalty; zones respected. **FR-10 AC-3 + G2** — pet volume moves ZERO bond (once-daily hello excepted).
5. **04 §10.1 rule 7 / §4.9 OBS-2** — micro-reactions carry no visual text; `react.*` lines are VoiceOver-announcement-only surfaces; UX-8 gate admits the touch pool only.
6. **05 §4.10** — catalog change ⇒ bump `copyEpoch`; DaySeed = length-framed SHA-256 preimage, first-8-bytes BE, canonical SplitMix64, one draw reduced mod pool count.
7. **Frozen surfaces** — `MomoDirectorState`/`MomoCharacterEvent`, `MomoRigView` signature, `MomoPressState`, `pressLostBoundarySeconds` 5.0 must be untouched; D-R5 (views contain no engine logic); 800-line cap; import whitelists.

## 3. Findings

### F-1 — HIGH — The Home rig never samples the director: no touch reaction, press feedback, or clip EVER renders on Home

**Evidence (all verified this session):**
- `Apps/Momo/MomoAppModel.swift:361` — the contract-mandated R3 closure factory `func reactionMotion() -> @Sendable (Double, Bool) -> MomoReactionMotion` exists, correctly captures the director BY VALUE, and is documented as "The Home rig's `reactionMotion` closure (R3)".
- Repo-wide grep for `reactionMotion`: inside `Apps/` the ONLY occurrences are the factory's declaration and its doc comments (`MomoAppModel.swift:159,361,452`). **There is no call site.** Every other hit is `MomoCharacter`'s internal overlay plumbing.
- `Apps/Momo/HomeView.swift:118-126` — `canvasBody` constructs `MomoRigView(displayState:tier:clock:stageSide:)` with **no `reactionMotion:` argument**.
- `Sources/MomoCharacter/MomoRigView.swift:86` — the omitted parameter defaults to `{ _, _ in .identity }`, and `MomoRigView.swift:140` samples exactly that closure per frame. The director folds every event (verified: `.plan`, `.touchBegan/.touchEnded`, `.appHidden/.appShown` all mutate the overlay correctly — `MomoTouchSemanticsTests` proves the fold shape), but **the rig is permanently handed the identity overlay**. Consequence: the L1 press layer, every §6.1 clip, the stir, and rapid-pat coalescing are invisible in the app. Only the VoiceOver announcement seam works.

**Why this refutes the handoff:** the task's Handoff states "R1–R12 all implemented per contract; AC-1…AC-6 satisfied." R3's operative verb is *renders* and AC-1 requires the response *through the composed Home*. The director half is complete and correct; the rendering half is missing. This is not a disclosure — the Handoff affirmatively claims the opposite.

**Why the green suites did not catch it (checked, not assumed):** `MomoUITests.testCanvasGesturesRouteThroughTheAppModelInPlace` (`MomoHomeUITests.swift:243-268`) drives every gesture class through the composed canvas but asserts only in-place navigation and zero alerts/sheets; `testPettingMovesNoStageWords` (:299-318) asserts the stage words do **not** change. Both are structurally insensitive to an identity overlay. The headless suites prove the director fold (`MomoTouchSemanticsTests.pressLayerFoldsFromTouchBoundaries` samples `director.overlay(at:)` directly), never the view→rig wiring.

**Suggested fix (one line):** in `HomeView.canvasBody`, pass `reactionMotion: appModel.reactionMotion()` to the `MomoRigView` initializer. The factory is already correct, `@MainActor`-isolated at the call site, and its doc comment describes exactly this consumption ("reading this method from the view's body tracks `director`"). After the fix, AC-1's director-level evidence per row already exists in `MomoTouchSemanticsTests`; consider one UI-level sanity check that a gesture visibly perturbs the rig (even a reduced-motion-off frame snapshot) so this class of wiring regression cannot pass green again.

### F-2 — MEDIUM — `.inactive` now triggers `backgrounded()`, contradicting the file's own doc comment and TASK-031's reviewed semantics, undisclosed

**Evidence:**
- `Apps/Momo/MomoAppModel.swift:269-270` — doc comment (unchanged this task, carried from reviewed TASK-031): "`.inactive` is transitional (app switcher) and **triggers nothing** in §4.2's table".
- `Apps/Momo/MomoAppModel.swift:281-283` — `case .background, .inactive:` routes BOTH phases through `foldDirector(.appHidden…)` **and** `backgrounded()` (:496-504), which sets `isForeground = false` and cancels `boundaryTask`.
- Disclosure (c) scopes the change to the director fold only: "`.appHidden` folds on `.inactive` **too**" — it never mentions the boundary-task/foreground-flag side effects. Disclosure (c) is therefore PARTIAL (see §4).

**Impact assessment (performed, not guessed):** benign in practice — `foregrounded()` (:491-494) re-sets `isForeground = true` and re-folds on `.active`; a boundary that fires mid-transition is refused by the `isForeground` guard in the task closure (:481-483); the next foreground fold catches up; the director `.appHidden` fold on `.inactive` is itself defensible (the paused-clock tear argument holds). But it is a real behavior change beyond the disclosed scope, sitting directly beneath a comment it contradicts — §25 requires the claim to match the code, and §26's discipline forbids leaving the stale comment as the only trace.

**Suggested fix:** either split the case (`case .background:` → hidden+backgrounded; `case .inactive:` → hidden only) or keep the current behavior, disclose the `backgrounded()` leg in (c), and correct the :269-270 comment in the same change.

### N1 — NITPICK — Stale maturation task is replaced without cancelling its `pendingTap`

`HomeCanvasTouchLayer.swift` (`scheduleMaturation`): in the unpaired-repark path (only reachable when a clock reset precedes a new tap), the old `Task` is left running while a new one is scheduled. Provably benign — the stale task's probe instant (`upAt_A + window`) strictly postdates the new task's, and `maturing(now:)` re-checks the CURRENT pending tap, so the stale task can only ever drain the successor's tap at its own later wake (identical outcome to its own firing) — but cancelling the superseded task would make the seam self-evidently correct. Cosmetic.

### O1 — OBSERVATION — Catalog `touch.03` uses a straight apostrophe (U+0027)

`Apps/Shared/MomoCopy.xcstrings`, `momo.line.react.touch.03` = "Momo's tail curls happily." — byte-compared against the contract's own line: the CONTRACT pins the straight apostrophe (`6d 6f 6d 6f 27 73`), so the catalog is verbatim-faithful and this is NOT a defect. Recorded only because TASK-033's catalog used U+2019 in equivalent positions; if the house typographic convention is curly, the contract line and catalog should move together in a later pass. Not blocking.

### O2 — OBSERVATION — pbxproj registration is exactly as claimed

4 added lines: `8A4000000000000000000053` (PBXBuildFile) + `8A5000000000000000000053` (PBXFileReference), wired into the group children and the app target's Sources phase. No stray entries.

## 4. Disclosure adjudication (§22/§25)

| # | Claim | Verdict | Evidence |
|---|-------|---------|----------|
| a | react.touch lines are announcement-ONLY; no view renders them | **VERIFIED** | Repo-wide: no `MomoCopy.resolve`/render of `react.touch.*` outside `announceSpokenLine` (app model) and the Watch glance's a11y label; INV-11 holds below the view. |
| b | Xcode 26.5 SDK has no `.accessibilityCustomActions`/`AccessibilityCustomAction`; `.accessibilityActions` is the surface | **VERIFIED** | My own grep of the installed `arm64-apple-ios-simulator.swiftinterface`: 0 hits for both rejected names; `.accessibilityActions` present (iOS 16+ ViewBuilder). HomeView uses it (:99) with the two-action vocabulary pinned in `CanvasTouchTests`. |
| c | `.appHidden` folds on `.inactive` too (director-gate scope only) | **PARTIAL — see F-2** | The director fold is real and defensible, but the same case also calls `backgrounded()` (foreground flag + boundary-task cancel), which the disclosure does not cover and the in-file comment contradicts. |
| d | Cancel seam cannot wedge (view reset + model force-close + 5.0 s director backstop) | **VERIFIED** | Adversarial sequences: `touchBegan` force-closes a stale open press before opening; `applyHidden` (:577-584) clears press/lastTouch/coalescer and supersedes visible L3; `pressLostBoundarySeconds` backstop (:668-686) bounds any naked press; `@GestureState` reset fires before `onEnded` (empirically: the gesture UI test passes with the reset seam doing the cancellation). Residual same-location re-tap over-count is disclosed and bounded (one misread hold). |
| e | No Watch source changed; glance key resolves to real copy | **VERIFIED** | `git diff` over `Apps/MomoWatch/` is empty; `PlaceholderGlanceView.swift:42` speaks `react.touch` index 0 through the a11y label — a legitimate SPOKEN surface under 04 §10.1 rule 7 (disclosure (a) covers why index 0 ≠ the iPhone's epoch draw). MomoWatch scheme builds (my run). |
| f | `.fingertip` not wired — recorded non-goal (R11) | **VERIFIED** | Consistent with the frozen event surface and the UX-14 recorded non-goal; no half-wiring present. |
| g | Single-tap dispatch deferred ~0.35 s (double-tap window) | **VERIFIED** | Inherent to §6.1's zone-less double-tap row on a single-element canvas; `maturing` dispatches at `upAt + window`, and the edge is probed strictly past (disclosure k-1's own fix). |
| h | 60 grid units ≈ 15.6 pt at the 260-pt stage | **VERIFIED** | 60/1000 × 260 = 15.6. |
| i | Epoch-3 pin sweep over six extra MomoCoreTests files, all sharing the fixture | **VERIFIED** | All six diffs (BondLedger, EngineReduce, InteractionResponse, TimeFold, WakefulnessHandshake, plus CopySelectionPinned) change ONLY `touch.00`→`touch.02` literals and their comments; feed/play stay `.00`. My independent derivation (below) confirms `.02` is the correct epoch-3 draw for the shared fixture. |
| j | TASK-019 structural restatement is not a weakening | **VERIFIED** | Read both diffs: the old "pool count − 1" derivation became prefix+range membership checks (`hasPrefix("momo.line.react.<family>.")` + suffix in `0..<reactLineCount(family)`), which do NOT self-derive the expected value; the concrete day-stable draws stay raw in `CopySelectionPinnedTests`. A family rename, an out-of-pool draw, or a pool-count regression each still fails a distinct test. Sound. |
| k | Two first-draft test expectations were wrong, not the code | **VERIFIED** | (1) fp-edge probe moved strictly past the window with an honest comment (`CanvasTouchTests.swift:72-75`). (2) 3 s hold + sub-stroke movement is a long-press per §6.1 (stroke bar missed ⇒ hold decides), test corrected (`:55-58`). Both corrections match the normative rows. |

## 5. Test reproduction (this agent's own runs)

1. **`swift test`** (full package): **886 tests in 91 suites — PASSED, exit 0.** (Matches the handoff claim.)
2. **`xcodebuild test`** MomoUITests on the pinned SE 3rd-gen simulator `1F25E487-A78E-464C-95AF-0BD1A9B3E1BE`: **13 tests, 0 failures, TEST SUCCEEDED, exit 0** (226.95 s).
3. **`xcodebuild build`** MomoWatch on pinned watchOS simulator `8A854895-225C-411B-89C1-B03337BFE957`: **BUILD SUCCEEDED, exit 0.**

## 6. Mutation bite (contract-sanctioned; sha256-proven restoration)

**Epoch-literal flip** — changed `CopyRules.copyEpoch` 3 → 2 and ran `swift test --filter CopySelectionPinnedTests`:

- Exactly **one** failure: `copyEpochIsThree` (`Expectation failed: (CopyRules.copyEpoch → 2) == 3`).
- `rawKeysPinned` ("epoch 3 draws .02 in the ten-line slots AND the touch pool") **still passed** — executable confirmation that epochs 2 and 3 are same-residue (my independent derivation: epoch 2 draw `0xadb400753cec859e` % 5 = 2; epoch 3 draw `0xdc227781a4980eaa` % 5 = 2). The dedicated literal test is the ONLY net over the epoch dimension, exactly as the contract's "EPOCH TRAP" note warns.

**Restoration:** `shasum -a 256` after restore = `36142222dc9f98804c949578e8eb97f7128d3dcee7561dfae542bb39be4e7307`, byte-identical to the pre-bite hash; `git diff --stat Sources/MomoCore/CopyRules.swift` shows only the implementer's own 29/20 carveout change. Working tree returned to its reviewed state.

**Independent epoch derivation (pre-bite, outside the repo):** reimplementing DaySeed (length-framed preimage: 4-byte BE length + RFC-4122 bytes of `7C47A9C4-2E5F-4B8A-9C1D-3E6F8A2B4C0D` + UTF-8 `2026-09-08` + 8-byte BE epoch + salt), SHA-256, first-8-bytes BE, canonical SplitMix64, one draw mod pool count: epoch 1 → index 9, epoch 2 → index 2, epoch 3 → **index 2** (`seed 0x13ec67b5bdf1e2f7`, draw `0xdc227781a4980eaa`). Matches every pinned literal in the diff.

## 7. §19 / §26 / hygiene scans (my own greps)

- TODO/FIXME/HACK/XXX across every changed source/test: **0 hits**.
- print/debugPrint/NSLog: **0 hits**; the one `Logger` is the pre-existing os.log subsystem constant (`MomoAppModel.swift:68`, present at HEAD).
- File lengths: max 554 (`MomoAppModel.swift`) ≤ 800; new files 190/198/405 lines.
- Import whitelists: `CanvasTouch.swift` = Foundation + MomoCore only; view-layer files import SwiftUI/MomoCharacter/MomoKit/MomoCore (sanctioned).
- Frozen surfaces: `git diff -- Sources/MomoCharacter/` is EMPTY; `Sources/MomoCore/` touched only in `CopyRules.swift`; `MomoRigView`'s public signature and all frozen enums unchanged.
- D-R5: `HomeView` touches the director only through the app model's one method (ironically, the method F-1 shows is never called by the view).

## 8. Verification summary

The engine, vocabulary, catalog, epoch machinery, announcement gate, cancel seam, custom actions, zero-bond pins, and every re-pinned suite are **correct and well-tested** — this review confirms the carveout exactness, the epoch-3 draw bit-for-bit, the §6.1 classifier/pairing rows, zone totality (NaN→belly, negatives→head), disclosure (b) against the SDK itself, and disclosure (j)'s soundness. The single decisive defect is a **one-line missing view wiring** (F-1) that severs the entire visual half of the feature from the fully-functional machinery behind it, claimed complete in the Handoff and invisible to every green suite. F-2 is a smaller but real disclosure-vs-code gap. Both are cheap to fix; neither invalidates the surrounding architecture.

## VERDICT

**CHANGES_REQUIRED**

- F-1 (HIGH): the composed Home never renders director reactions — R3's rendering leg and AC-1 unmet despite the Handoff's claim. Fix: wire `reactionMotion: appModel.reactionMotion()` into `HomeView.canvasBody`'s `MomoRigView`.
- F-2 (MEDIUM): undisclosed `.inactive` → `backgrounded()` contradicting the in-file comment; split the case or disclose + correct the comment.
- Re-review required after the fix (material change); N1/O1/O2 are non-blocking notes.
