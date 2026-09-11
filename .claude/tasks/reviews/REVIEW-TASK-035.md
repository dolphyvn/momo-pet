# REVIEW-TASK-035 — Feed / Play / Care flows (§10 independent review)

- **Task:** TASK-035 — feed/play/care (EPIC-007 — iPhone Home Experience)
- **Branch:** `feature/EPIC-007-iphone-home`
- **Base commit reviewed:** `3a1698b5e0c0b3a2cdd0a3e2041efb39f25071df` (HEAD; implementation tree uncommitted on top)
- **Review date:** 2026-09-11
- **Reviewer:** fresh independent review agent (Jupiter); received task requirements + repo only — not primed with implementation claims
- **Review method:** §33 independence — every implementer claim re-derived from primary sources (contract, normative docs, `git diff`, source reads); all three §19 gates executed by this agent; the epoch-4 selection chain re-derived independently outside the repo (Python scratch) after validating the replica against epochs 2/3's known-correct goldens; **all three R9 structural guards independently mutation-bitten** with sha256-proven byte-identical restoration (three separate bites, each verified to fail exactly its own leg). No source, test, catalog, or project file was modified or staged; the only file written is this review. The task file was NOT edited.

---

## 1. Scope inspected

Full working-tree diff against `3a1698b` (27 modified files, +1532/−200, plus the untracked `Tests/MomoKitTests/CareMomentTests.swift`); each changed file read, new file read in full. Normative surfaces: the contract's R1–R10, `docs/design/03-ux-architecture.md` §5.2–5.4/§10.4/UX-3/UX-8/UX-12, `docs/design/04-character-system.md` rule 7/§10.1/§10.4. Frozen surfaces re-diffed for regression: `Sources/MomoCore/` diff is `CopyRules.swift` ONLY; `Sources/MomoCharacter/` diff is exactly the two disclosed R6 files; `MomoReduceMotion.swift` untouched; `Momo.xcodeproj` not in the diff (byte-identical with HEAD); `docs/` untouched; `MomoUITests/MomoUITests.swift` diff empty (0 lines — see F-3). Sweeps: no `print(`/TODO/FIXME/HACK/TEMP additions (only hits are the task file's own disclosure prose), no secrets, no entropy violations.

## 2. Per-requirement verdicts

**R1 (report drain, exactly-once, ordered) — PASS.**
`MomoAppModel.foldDirector` (`Apps/Momo/MomoAppModel.swift:469-477`) applies the event to a successor, drains the successor (`:472`), stores it, then submits each entry in emission (causal) order (`:474-476`). `submit` (`:376-378`) hops to `apply(trigger: .characterReport)` as a `Task` — no synchronous reentrancy inside the fold; the engine's stale-guard makes cross-Task reordering harmless (a cancel with no matching pending token is a no-op). `drainReports` (`Sources/MomoCharacter/MomoReactionDirector.swift:116-120`) returns AND clears the append-only log, so a report can never be delivered twice. Count semantics verified against the frozen engine: authorization sets `activity = .playing` with NO count; the unified cease fires on `playRoundFinished` OR `handshakeCancelled(.play)`; duplicates are engine no-ops — pinned headless by `AppModelPlanTests.playCountsAtTheReportNotTheAuth` and `.cancelledRoundCountsOnce`. R9(a) guard bites (bite 1, §4).

**R2 (play round UX) — PASS** (with F-1 below — a correct-but-undisclosed supporting mechanism, not a defect).
- In-flight gate: `HomeCanvasTouchLayer.swift:102-104` routes drags to `playGesture` instead of the pat vocabulary while `appModel.isPlayRoundInFlight`; `:134` skips the pat lift when a round started mid-drag; `resolveAsCancellation` (`:231-233`) also clears `playTouchIsDown`.
- Fingertip stream: `playGesture` (`:146-162`) sends a `moving: false` down-bookend (`:152`), then samples with a 1-pt travel threshold (`:159`); offset conversion (`:166-172`) is `(point − stageCenter)/stageSide × CanvasTouchLaws.stageGridSide` (=1000), center-origin, y-down — the frozen choreography's grid (`followMotion` normalizes /300).
- Done pill: authored `donePillDelaySeconds = 5.0` (`MomoAppModel.swift:185` — inside UX-3's 4.5–6 s band, disclosed); the window opens via a REAL-TIME Task (`:626-628`), so the frozen canvas clock cannot defer it; visibility is DERIVED from engine truth (`:212` `isPlayRoundInFlight && isDonePillWindowOpen`), so the pill closes on ANY round end. `HomeView.swift:100` hosts it as an overlay OUTSIDE the canvas's flattened a11y element; identifier `home.playDonePill`, label "Done", tap → `stopPlayRound` (`MomoAppModel.swift:437`) → R6. The UI flow test's assertions have teeth over R1: because pill visibility derives from engine truth, the pill closing after tap transitively proves the drain→cease→`activity` update chain worked at the glass.

**R3 (feed UX) — PASS.** No meal/cooldown/currency UI exists in the diff (D18 red line respected); the tray/meal fade stays frozen choreography; the politely-full refusal renders its VISUAL line through the R5 care-moment contextual slot, glass-pinned by the feed-refusal UI test asserting the verbatim `care-moment.02` string with zero alerts.

**R4 (pill parity) — PASS.** The read-model gating was restated to read exactly the engine's own rules: tuck-in ⟺ `InteractionRules.isTuckInWindow` ∧ wakefulness ≠ `.waking` ∧ ¬in-flight (`Sources/MomoKit/HomeReadModel.swift:206-208`); nap ⟺ (drowsy ∨ exhausted) ∧ ¬(asleep ∨ napping) ∧ ≠ `.settling` ∧ ¬in-flight (`:211-213`) — verified line-by-line against the frozen engine (`applyTuckIn` `InteractionSemantics.swift:326`; nap declines `:412-419`; nap band `:421-447`). A chip can never route into a guarantee-declined state. The `06:30` pin's designed movement 2→3 pills is engine-faithful (the engine accepts tuck-in through 07:00) — verified, not a regression. 20:30 presence is pinned and exercised end-to-end (chip → tap → `care-moment.01` line) by the UI flow test.

**R5 (copy landing + epoch 3→4) — PASS.**
- 21 new keys byte-compared against the contract verbatim (JSON-level: 21/21 exact matches, 0 mismatches; U+2019 throughout; ≤ 12 words; no digits; each key's `comment` cites its authority). `touch.03` normalized to the U+2019 apostrophe per the O1 note, with the TASK-034 verbatim pin updated in place.
- `reactLineCount` touch 5 / feed 6 / play 6 / care 6; `slotLineCount(.careMoment)` stays 1 (`CopyRules.swift:157`); `copyEpoch = 4` (`:65`); all future-tense comments replaced with the landed state.
- `careMomentLineKey(for:)` (`HomeCopyKeys.swift:67`) is a fixed 01/02/03 lookup — verified it never enters any draw recipe (the only `LineSelection` call is the UI-slot `slotLineKey`, `:44`; OBS-D precedent respected). Contextual priority careMoment > greeting > ambient (`:83-91`) pinned for all three kinds, over a stamped greeting, and nil fall-through (`HomeReadModelTests.contextualLineCareMomentPriority`).
- Epoch-4 residue: independently re-derived (§3) — slots `.07`, touch `.02` survives, feed/play/care `.01`, and the `2026-09-09` day fixture draws care `.04`. All match the implementer's claims and the in-place re-pins read this session (`PlayRoundTests` `.00`→`.01` ×2; `InteractionResponseTests` touch `.02`/feed `.01`/play `.01`/care `.01`; `CareInteractionTests` `.01` on the 09-08 day and `.04` on the 09-09 day).

**R6 (the ONE disclosed MomoCharacter seam) — PASS.**
`MomoReactionState.swift:41` adds `case playStopped(at: Double)` with `:51` the single new `eventTime` line (+11 total). `MomoReactionDirector.swift` (+31): the apply case routes to `applyPlayStopped` (`:105`, `:637-643`), which uses the SAME displacement-cancel machinery as `applyHidden`'s play branch (`:613-615` — identical shape), reports `handshakeCancelled(.play)` exactly-once under the instance `reported` flag, and is a tolerated no-op without an in-flight round. Natural completion (`:745-747`) reports `playRoundFinished` and nils the layer, so a late stop reports nothing new — the three report sites (`:307-309` enter/displacement, `:350-352`, `:639-641` stop) are mutually exclusive through the layer's lifetime. Four new director tests pin: stop cancels exactly-once with `overlay(at:) == .identity`; no-op without a round (idle AND clip-owned slot); late stop after resolution is silent; stop never cancels a settle (settleFinished at exactly 4.0). `MomoReduceMotion.swift` is untouched — verified its switches are over presentation state, not events; the RM twin suite (+1 test, 2 corpora) pins the cancelled round's RM render instead. The exhaustive-switch census holds (any missed site is a build failure).

**R7 (announcement gate widening) — PASS.** `Sources/MomoKit/CanvasTouch.swift:209-215`: the gate admits lines with prefix `momo.line.react.` whose remainder starts one of the four family names followed by `.` — `reactx.touch` and `touchX` are excluded by the suffix check; slots/greetings/vocab/care-moment classes lack the prefix. Positive and negative pins landed in `CanvasTouchTests` (day/morning slots, `care-moment.01`, `reactx.touch`, `touchX`, nil), and `lawsPinned` now carries the prefix/family constants. Path discrepancy adjudicated in §5(c).

**R8 (§10.4 verbatim a11y labels) — PASS.** `HomeActionRowView.swift:94-98` is an exhaustive no-`default` switch producing "Pat" / "Feed Momo" / "Play with Momo" / "Tuck Momo in" / "Nap time" — §10.4 verbatim; a missing or wrong label is a compile failure. Visible chrome (`:69`-block) unchanged ("Feed"/"Play"/"Tuck in"/"Nap"); the header comment (`:89`) updated. UI glass pins cover the three gates deterministically reachable under a frozen clock; the nap gate's compile-only status is adjudicated in §5(a).

**R9 (structural guards) — PASS; all three independently proven to bite (§4).** Predicates at `RigDisciplineTests.swift:158-161` (a: drain AND submit), `:171-175` (b: in-flight gate AND fingertip stream), `:180-184` (c: pill identifier AND `appModel.stopPlayRound()`), each a two-leg conjunction, each with an inline violation fixture proving non-vacuity, each read against the REAL file via `readRigFile` (`:183-186`). The TASK-034 F-1 guard (`mentionsHomeReactionWiring`) is untouched and passing.

**R10 (scope pins) — PASS.** `Sources/MomoCore/` diff = `CopyRules.swift` ONLY; `Sources/MomoCharacter/` = exactly the two disclosed files; `MomoReduceMotion.swift` untouched; pbxproj byte-identical with HEAD (not in the diff); `docs/` untouched; no new pills, no meal UI, no quest/Room/Settings/Watch work, no rendered react text; the only added file is `Tests/MomoKitTests/CareMomentTests.swift`; the UI tests extended `MomoHomeUITests.swift` in place per the contract's preference. The interim standalone UI-test file's consolidation (disclosed in the task file) left no residue — `git status` shows exactly the implementation's file set.

## 3. Independent epoch-4 re-derivation

Re-derived from the source-read recipe only (length-framed SHA-256 preimage `uuid16 ‖ utf8(dayKey) ‖ 8-byte BE epoch ‖ utf8(salt)` → first 8 bytes big-endian → SplitMix64 seed; one draw; `pick` = draw mod pool count), in a Python scratch outside the repo.

Replica validation FIRST (per the contract's own method): at epoch 3 the replica reproduces TASK-034's recorded golden seed/draw literals (`0x13ec67b5bdf1e2f7` / `0xdc227781a4980eaa`) — the replica is trustworthy before any epoch-4 number is read.

- **2026-09-08, epoch 4:** seed `0xda4187ce48ff0bb7`, draw `0xfdb4bc3ce6f541d3`.
  - `draw % 5 = 2` → touch `.02` SURVIVES the bump.
  - `draw % 6 = 1` → feed/play/care pin `.01`.
  - `draw % 10 = 7` → all four ten-line slots move `.02` → `.07`.
  All three residues match the contract's R5 numbers, the implementer's recorded derivation, and every executable pin in the diff.
- **2026-09-09, epoch 4 (the day fixture):** seed `0x171fe7d1619511e4`, draw `0x61174cf530709c24`, `draw % 6 = 4` → care `.04`. Confirms `CareInteractionTests`' night-shoulder day pins and the in-place comments explaining the day-stable difference.

No recorded number was trusted without this derivation; all agree.

## 4. Gates (§19) — executed by this agent on the reviewed tree

1. **`swift test` (full package):** "Test run with **906 tests in 92 suites passed**", exit 0. Matches the claim (baseline 887/91 → +19 tests, +1 suite: CareMomentTests 7, handshake 4, plan-core 2, rig 3, RM twins 1, verbatim 1, contextual priority 1).
2. **UI suite** on the pinned simulator (`platform=iOS Simulator,id=1F25E487-A78E-464C-95AF-0BD1A9B3E1BE`, `-only-testing:MomoUITests`): "**Executed 17 tests, with 0 failures (0 unexpected)** in 312.709 s", `** TEST SUCCEEDED **`, exit 0. Matches the claim 17/17 (13 TASK-033/034 baseline + 4 new care-loop tests). No sleep-based waits — assertions use `XCTNSPredicateExpectation`.
3. **Watch scheme build** (`MomoWatch`, watchOS 26.5 simulator SDK): `** BUILD SUCCEEDED **`, exit 0 — R6's seam compiles into the shared-character watch app.
4. **Warnings sweep:** 19 actor-isolation warnings re-emitted from `MomoUITests/MomoUITests.swift` — that file's diff is EMPTY (verified `git diff | wc -l` = 0), so the diagnostics are pre-existing debt re-surfaced by a whole-module recompile of the test target, not code this task introduced. Adjudicated as F-3 below.

## 5. R9 mutation bites — all three guards proven to bite (AC-6)

Each bite: mutate one leg into a plausible failure shape, run the focused suite, confirm EXACTLY the guard's own test fails, restore via edit, prove byte-identical restoration by sha256, re-run green.

| Bite | Mutation | Result | Restoration proof |
|---|---|---|---|
| (a) R1 drain | `MomoAppModel.swift:472` → `let emitted = []` (the contract's own apply-but-never-drain shape) | 19 tests, **exactly 1 issue**: "The app model drains the director's reports into the engine (R1 wire pin)" failed; all sibling guards green | sha256 `aa00873b…9fe79` identical pre/post; `git diff --stat` restored to +170/−17 |
| (b) R2 stream | both `sendFingertip(offset:` call sites (`HomeCanvasTouchLayer.swift:152,161`) → `streamFingertip(` (the "no stream" leg) | 19 tests, **exactly 1 issue**: "The in-flight-play drag branch streams fingertips (R2 wire pin)" failed | sha256 `a4b9007e…2ccf2` identical pre/post |
| (c) R6 stop wire | `HomeView.swift:116` → `appModel.localDismissPill()` (the UI-only-dismissal shape) | 19 tests, **exactly 1 issue**: "The Done pill routes the stop event through the app model (R6 wire pin)" failed | sha256 `cb7aa8b4…2a1fe` identical pre/post |

After all bites: final `swift test --filter RigDisciplineTests` green (19/19) on the restored tree; `git status` file set identical to the pre-review implementation set (28 entries). Zero residue.

## 6. Findings

### F-1 — MEDIUM — The play stillness ticker is load-bearing for AC-2's passive auto-end but is undisclosed in the task file and unguarded by R9

**Evidence (all verified this session):**
- `Apps/Momo/MomoAppModel.swift:180` (`playTickerSeconds = 1.0`), `:610-616` (`runPlayTicker` folds a `moving: false` `.fingertip` sample every 1 s, resuming from `lastPlayFingertipOffset ?? .zero`, guarded by `isPlayRoundInFlight`), started/stopped by `reconcilePlayPresentation` (`:586-592`) at the end of every `apply(trigger:)` (`:576`).
- **Load-bearing:** display-state folds are edge-gated, so during a PASSIVE round (finger never down) the ticker is the ONLY fold source advancing the director's clock. Delete it and a solo round never reaches its completion beat — AC-2's "a full round auto-ends ≤ 30 s and lands exactly one count" fails at the glass — while every suite stays green: the director's solo completion is only tested when folds are supplied, and the UI Done-pill flow cannot catch it (pill visibility is derived from the real-time 5 s Task and the tap path, both ticker-independent).
- **Undisclosed:** the task file's R2 notes, Handoff ("in-flight drag → `.fingertip` stream"), and Known Issues never mention the ticker; R2's letter says "sampling cadence is the drag stream". The mechanism exists only in code comments.
- **Unguarded:** R9's three legs (a)(b)(c) do not cover it; no package test pins the ticker's fold cadence. This is precisely the TASK-034 F-1 failure class ("the default silently serves") recurring one level deeper on this task's own leg.

**Why not CHANGES_REQUIRED:** the ticker's code is CORRECT (verified: cancel-on-round-end, no bogus baseline sample, engine-truth-guarded), no contract requirement is unmet today, and all gates are green. The finding is a disclosure gap plus future fragility, not a present defect.

**Recommended disposition:** before commit (preferred — small, same-scope: one `RigDiscipline` predicate pinning the ticker's construction and fold call in `MomoAppModel.swift`, plus a non-vacuity fixture) or as the immediate follow-up task if the orchestrator prefers not to widen the reviewed diff. One line of guard prevents a repeat of the F-1 class on this exact mechanism.

### F-2 — NOTE — `reconcilePlayPresentation` re-entry relies on main-actor serialization

The double-start guard is instance-state (`playTickerTask == nil`), not per-round identity. Under the serialized `apply(trigger:)` (main-actor FIFO) a successor reconcile always observes cancelled/nil'd tasks from the previous round, so the theoretical hazard — a new round inheriting a predecessor's ticker/done-pill timing — is unreachable today. Record only: if `apply` ever becomes reentrant or off-main, this is the first place to look.

### F-3 — NOTE (pre-existing, routed) — 19 actor-isolation warnings in `MomoUITests/MomoUITests.swift`

Not introduced by this task (file's diff is empty — verified). The same-target test merge triggered a whole-module recompile that re-emits that file's latent diagnostics; it lacks the `@MainActor` annotation the newer suites carry. Not blocking; recommend a small housekeeping task annotating the file so the "zero warnings from touched files" gate stops re-surfacing it.

## 7. Disclosures adjudicated

**(a) Nap pill label compile-only — ACCEPTED.** The exhaustive no-`default` switch makes a wrong or missing "Nap time" label a compile failure; the other three gates are glass-pinned; the nap gate (waking + drowsy/exhausted + not asleep/settling) is not deterministically reachable under a frozen clock without unverified multi-day decay math, and faking reachability would violate §25. The disclosure is honest and the coverage is adequate. Optional future improvement: a read-model-level label pin if a deterministic fixture becomes reachable.

**(b) Care-moment line memory-only — ACCEPTED (contract-conformant, not a deviation).** R5 itself specifies "in memory (never persisted …) … disclose this retention plainly" and routes the item to REVIEW-TASK-033 OBSERVATION-A as its owner. The implementation matches: `latestCareMoment` (`MomoAppModel.swift:223`) is `private(set)` with a single writer (`:560-561`, reading POST-application state, `:523`), and the careMoment > greeting > ambient priority is pinned headless. The UX-12 priority is fully honored within a session; cross-launch persistence remains OBSERVATION-A's scope.

**(c) R7 path discrepancy — ACCEPTED as a contract erratum.** `SpokenReaction`/`CanvasTouchLaws` have lived in `Sources/MomoKit/CanvasTouch.swift` since TASK-031; the contract's stated `Apps/Momo/CanvasTouch.swift` path never existed. The implementer widened the gate at the type's real location and disclosed plainly. Same type, same gate, correctly tested. No action.

## 8. Overall status

**APPROVED_WITH_MINOR_NOTES**

- All ten requirements verified PASS with independent evidence; no contract requirement is unmet.
- All three §19 gates reproduced green by this agent at the reviewed tree (906/92 package, 17/17 UI on the pinned simulator, Watch build).
- Epoch-4 selection chain independently re-derived and matched in full, including the day fixture.
- All three R9 guards independently mutation-bitten — each fails exactly its own leg; restorations sha256-proven byte-identical; zero residue.
- F-1 (MEDIUM, disclosure/fragility) is the lead note: recommended one-guard follow-up before or immediately after commit, at the orchestrator's discretion per §11/§22. F-2/F-3 are notes only.
- The three disclosures are adjudicated ACCEPTED (§7).

This review made no commits and modified no repository file except this record.
