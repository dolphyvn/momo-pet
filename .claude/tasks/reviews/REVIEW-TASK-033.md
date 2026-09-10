# REVIEW-TASK-033 — Home composition (independent review)

- Task: `.claude/tasks/active/TASK-033-home-composition.md`
- Branch: `feature/EPIC-007-iphone-home` · HEAD `8bf6ff4` (unmoved; working tree received dirty-by-design and returned byte-identical)
- Reviewer: independent Jupiter review agent (CLAUDE.md §10/§33 — no implementation-agent context)
- Date: 2026-09-10
- Review status: **APPROVED_WITH_MINOR_NOTES**

## Method

Docs-first: requirements were re-derived from 03-ux-architecture §5.1/§5.4/§5.5/§11.2, 04-character-system §10.1–10.4 + §3.5, 02-mvp-prd §3.2/§3.3/§5.2, 05-technical-architecture §4.9–4.11 + D-R5 **before** the implementation was read (full derivation preserved at `/tmp/review-task-033/derived-requirements.md`). Then: diff inspection (frozen-module discipline), byte-level catalog comparison (Python, not eyeballing), independent test execution, sanctioned mutation bites with sha256-proven restoration, and an independent re-derivation of the seeded draw.

## 1. Catalog fidelity — PASS

Byte-compared all 69 doc-sourced strings against `Apps/Shared/MomoCopy.xcstrings` (Python JSON parse, exact `str ==`):

- 40 slot lines (04 §10.3 doc line n → index n−1, per the CopyRules "Indexing truth" paragraph): all byte-identical, including U+2019 apostrophes ("Momo's", "wouldn't") and the U+2026 in "Shhh… Momo is sleeping."
- 3 greetings: regular/missedYou byte-identical to 04 §10.3; freshMorning is the one disclosed authored line (§10.1 allowance, contract R1).
- 12 vocabulary entries incl. the wistful→"quiet" remap: byte-identical.
- 8 status words, 7 PRD §5.2 wishes ("Morning hello — say hello to Momo" …), 4 stage names + 4 descriptors: byte-identical.
- The two placeholders (`momo.line.care-moment.00`, `momo.line.react.touch.00`) are byte-untouched from HEAD; `day.00` now carries real copy; no `greeting.00` exists in the catalog; 72 keys total. Count pins (40/10×4/3/12/8/7/1/1 = 72) match.

## 2. Frozen-module discipline — PASS

`git diff HEAD -- Sources/MomoCore/` contains **exactly** the R4 CopyRules carveout (copyEpoch 1→2; slotLineCount 10/1; the indexing-truth paragraph). No other MomoCore file differs. `git diff HEAD -- Sources/MomoCharacter/` is empty.

## 3. The 0-based picker reading — PASS

`LineSelection.slotLineKey` formats `%02d` over a 0-based draw; `slotLineCount` is the real pool (10/1), so no placeholder key is reachable from the slot path: slot keys land in `.00`–`.09` over full pools. The greeting fixed-map emits `.01`–`.03` only (`.00` unreachable). `CopySlotTests` (pre-existing, frozen) pins `timeSlot != .greeting/.careMoment`, closing the last theoretical route to `greeting.00`. `day.00` is real copy, so even draw 0 is safe in all four time slots.

## 4. Scanner split — SOUND

`isInApprovedNamespaceOrFixedLookup` = frozen `CopyKeyRules.isValidKey` **or** three enumerated regexes (slot/greeting-family/status-word/quest-id shapes + the vocab band alternation). Defensible as test-owned scaffolding (the frozen validator cannot know TASK-033's new keyspaces). The shared band alternation across mood|energy|stage is grammar-loose, but fully defended one layer down: `VocabularyKeyTests.catalogCarriesTheVocabularyVerbatim` enumerates the exact 12 expected keys, so a cross-wired key fails as "missing from the shipped catalog" (NOTE-1 below).

## 5. AC-3 no-numeric-leakage + a11y formula — PASS

`HomeStatusRowView` builds exactly 04 §3.5's binding formula: `"{petName} feels {moodWord} and {energyPhrase}"` and `"{stageName}. {descriptor}"`, both resolved through `MomoCopy.resolve` (keys never rendered); glyphs are `accessibilityHidden`. The quest rows speak `"{wish}, done/pending"`. The UI test asserts non-empty, digit-free labels over status row, contextual line, and every visible quest row. The mood word for Wistful is "quiet" (catalog + verbatim pin), so the spoken sentence never leaks a band name or number.

## 6. Disclosure: the launch-open kick in MomoApp — JUSTIFIED

Root cause is real and material: 05 §4.2 trigger-table row 1 normatively requires evaluation on **every open** ("Foreground / scenePhase → active | every open"), and `onChange(of: scenePhase)` installed inside an already-`.active` scene never fires on cold launch — the R7 two-instant restart pattern (and day-1 quest landing) depends on it. The kick (`MomoApp.swift:44–48` `.task { appModel.scenePhaseChanged(to: scenePhase) }`) is minimal, directly necessary, and disclosed. Double-fire (`.task` + `onChange` both firing on a real foreground transition) is idempotent: the engine's zero-elapsed fold short-circuits and persist is IFF-changed; re-greeting is floored at 5 minutes. `import MomoCore` in MomoApp + the D-R5 amendment naming two sanctioned importers: compliant — MomoApp is the composition entry point constructing a clock for injection, not a view, and invokes no engine API directly. §22 satisfied (small, necessary, disclosed).

## 7. Disclosure: the R7 `-momo-fixed-clock` enabler — SOUND (one NITPICK)

DEBUG-gated (release builds ignore the flag entirely); unparseable value → `assertionFailure` (the MomoCopy loud-missing discipline) with a system-clock fallback; the UTC Gregorian calendar pinning is correct and necessary (the quest/pill windows are local-hour-governed; without it the suite would be timezone-flaky). NITPICK-1: a flag **without a value** exits the compound guard at `MomoApp.swift:90–96` before the parse, silently returning the system clock with no `assertionFailure` — a malformed launch-argument pair would run the suite on the host clock and flake on the hour-governed windows. Test-only, DEBUG-only, low likelihood.

## 8. Disclosure: UI-test determinism + the contract-defect correction — SOUND, correction VERIFIED

The two-instant restart is forced by the engine, not a whim: a fresh carrier pre-stamps `lastEvaluatedAt`, and a zero-elapsed fold short-circuits before the landing-day rollover, so a single frozen launch can never mint day 1's record; relaunching the same store at a later pinned instant gives the launch-open evaluate its one-minute gap. I re-derived the window arithmetic from frozen `QuestWindow.contains` (morningOnly `hour < 12`; eveningAndEarlyMorning `hour ≥ 20 ∨ hour < 7`) and the day-1 set `[Q1, X, Q6]`: at 09:00 the open windows are {Q1, X} = 2 rows; at 20:30 they are {X, Q6} = 2 rows; Q1 and Q6 windows never overlap, so **3 simultaneous rows is unreachable at any hour** — the contract's R8.3 "3 rows at 20:30" was unreachable as written and the implementer's 2+2 correction is the correct reading (their prose "disjoint windows" is imprecise — the windows do overlap on [0,7), where 3 rows can show on a *day-2+* morning; the 06:30 unit test pins that math correctly). The tests pin the true law.

## 9. Independent re-derivation of an epoch-2 draw — PASS (pin is not tautological)

Computed from the documented framing alone (no test constants): framed preimage (4-byte BE length + payload; RFC-4122 UUID bytes; UTF-8 day key; 8-byte BE Int64 epoch; `"copy"` salt) → SHA-256 → first 8 bytes BE → SplitMix64 first draw → `% 10`. For the pinned fixture (pet `7C47A9C4-…`, day `2026-09-08`, epoch 2): seed `0x2553f1ec8e780d4f`, draw `0xadb400753cec859e`, **index 2** = `momo.line.morning.02` — matching all four slot pins. Cross-check: the epoch-1 draw lands on index **9**, so the pins genuinely bind epoch 2 — they are not tautologies of the format. Script: `/tmp/review-task-033/seed-rederive.py`.

## 10. AC-1a/AC-1b layout law — VERIFIED

AC-1a: 45% of the SE's 667-pt screen = 300.15 pt; the floor constant is 305 pt (governs over the 0.46 × content-height term, which is only ≈275 pt at SE safe-area height — the comment's screen-vs-content distinction is correct); `canvas.frame.height ≥ app.frame.height × 0.45` and `scrollViews.count == 0` are pinned by the UI test at default type. AC-1b: the accessibility branch scrolls; the canvas is fixed at 260 pt, inside `RigLOD.fullStagePoints`' 220–280 band (verified in `Sources/MomoCharacter/RigLODTier.swift:44`); full function (pills, quest card) reachable and tappable inside the scroll is pinned by the XXL test. The region-backed accessibility element (element = the flexed region, not the rig's fixed stage frame) is the right construction for the 45% budget to be measurable at all.

## Verification executed (this agent, this tree)

1. `swift test` → **868 tests in 88 suites passed** (exit 0) — matches the implementer's claim.
2. Mutation bites (each restored; all seven sha256 hashes + `git status --porcelain` (23 entries) + stash count (0) + HEAD `8bf6ff4` re-verified byte-identical afterwards):

| Mutant | Predicted bite | Actual bite |
|---|---|---|
| `copyEpoch` 2→3 | `copyEpochIsTwo` | ✘ `copyEpochIsTwo` (exact attribution). `rawKeysPinned` survives **correctly**: my derivation shows epoch 3 ≡ 2 (mod 10) — see NOTE-2 |
| tuck-in gate `>=`→`>` (HomeReadModel.swift:182) | pill-gate test | ✘ "action pills: windows and bands gate tuck-in and nap" (20:30 → 2 pills ≠ 3) |
| `welcomeBack` → greeting.02 (HomeCopyKeys.swift:52) | greeting-tier test | ✘ "contextual line: greeting kinds route their pool, others fall to ambient" |
| wistful value "quiet"→"still" | verbatim-pin test | ✘ `VocabularyKeyTests.catalogCarriesTheVocabularyVerbatim` — the 12-vocab keyspace IS verbatim-pinned |
| slot-line value rewrite (`morning.02` → different legal words) | (hypothesis: none) | **survives all 36 catalog-facing tests** — evidences MINOR-1 below |

3. `xcodebuild test -project Momo.xcodeproj -scheme Momo -destination 'platform=iOS Simulator,id=1F25E487-A78E-464C-95AF-0BD1A9B3E1BE'` on the pristine tree: **TEST SUCCEEDED — see "xcodebuild UI result" below (ran twice: the primary run at 17:34 and a confirmation re-run at 22:03, both 10 tests / 0 failures, exit 0).**

## Findings

- **MINOR-1 — No automated verbatim pins for the landed non-vocab values.** `VocabularyKeyTests` pins the 12 vocab entries verbatim, but the 40 slot lines, 3 greetings, 8 status words, and 7 wishes have no value pins: the mutation experiment proved a slot-line rewrite passes all 36 catalog-facing tests. Fidelity currently rests on this review's byte-comparison, the epoch law, and the review gate. Fix sketch: extend the `catalogCarriesTheVocabularyVerbatim` pattern (enumerate expected `key: text`) to the full TASK-033 landing in a small follow-up test task. Non-blocking for this commit — the values are verified correct as of this review.
- **NITPICK-1 —** `MomoApp.swift:90–96`: `-momo-fixed-clock` without a value silently falls back to the system clock (guard exits before the parse; no `assertionFailure`, unlike the unparseable-value path at :101).
- **NITPICK-2 —** `HomeContextualLineView.swift:23` `lineLimit(2)`: the §5.1 sketch reads as a one-line element. All landed copy fits one line at default type, so nothing visibly diverges today; align or document.
- **NITPICK-3 —** `CopyRules.swift:30`/`:135` say care-moment "waits for TASK-034/035"; the contract attributes the care-moment producer to TASK-035 (034 owns the spoken reaction tier). Comment imprecision only.
- **NOTE-1 —** The scaffolding split grammar's band alternation is shared across mood|energy|stage, so a cross-wired vocab key would pass the grammar; the verbatim pins catch it one layer down. Defense in depth is adequate.
- **NOTE-2 —** `CopySelectionPinnedTests.rawKeysPinned`'s doc comment ("the full-key pins below fail until both move together") overpromises: a same-residue epoch bump (2→3) leaves the full-key pins green (proved by mutation + derivation). The dedicated `copyEpochIsTwo` literal is the real guard — comment inaccuracy only.
- **OBSERVATION-A (for the orchestrator, product question) —** Greeting domination: `lastGreeting` persists until replaced by the next greeting, and `Greeting.select` fires on any open ≥5 min apart, so in practice the contextual line almost always renders a greeting and the 40-line ambient pools rarely surface. This is the contract-specified resolver + frozen engine semantics, not a TASK-033 defect — but the orchestrator may want a product-level look at ambient-line exposure.
- **OBSERVATION-B (doc errata, OBS-C family) —** UX §5.5's "Q6 renders earlier only if already completed in the 00–07 tail" vs the frozen engine's unconditional `hour < 7` window. The contract pinned the engine's truth (06:30 all-open); recommend recording the doc tension in the errata backlog.

## Disclosure adjudication summary

- Launch-open kick (item 6): **JUSTIFIED** — §4.2 row-1 normative requirement; minimal, necessary, disclosed; double-fire idempotent.
- R7 enabler (item 7): **SOUND** — DEBUG-gated, loud on bad values (with NITPICK-1 on the missing-value path), UTC pinning correct.
- Two-instant restart + R8.3 correction (item 8): **SOUND** — engine-forced pattern; the 2+2 window law is the true one (re-derived independently).
- `import MomoCore` in MomoApp + D-R5 two-importer amendment: **COMPLIANT**.

## Verification summary

- swift test: 868/88 green (reproduced).
- xcodebuild UI suite: see below.
- Mutations: 4 bites as predicted, 1 documented survivor (MINOR-1 evidence); tree restored byte-identical (7/7 sha256 match, 23 porcelain entries, 0 stashes, HEAD unmoved).

## xcodebuild UI result

Two genuine runs of the full `xcodebuild test -project Momo.xcodeproj -scheme Momo -destination 'platform=iOS Simulator,id=1F25E487-A78E-464C-95AF-0BD1A9B3E1BE'` suite on the pristine tree (evidence: `/tmp/review-task-033/xcodebuild-ui-result.txt`, `/tmp/review-task-033/xcodebuild-ui-rerun-full.log`):

1. Primary run — started 2026-09-10 17:34:29 (post-mutation-restore, pre-review-file): `Test Suite 'All tests' passed` — **Executed 10 tests, with 0 failures (0 unexpected) in 173.508 seconds** — `** TEST SUCCEEDED **`, exit=0. (MomoHomeUITests 5, MomoOnboardingUITests 4, MomoUITests 1.)
2. Confirmation re-run — started 22:03:31 local, finished 22:06:21: `MomoHomeUITests` passed 22:05:25 (5 tests / 0 failures, 114.2s), `MomoOnboardingUITests` passed 22:06:13 (4 tests / 0 failures, 48.1s), `MomoUITests` passed 22:06:21 (1 test / 0 failures, 7.9s) — **Executed 10 tests, with 0 failures (0 unexpected) in 170.316 seconds** — `** TEST SUCCEEDED **`, exit=0.

Matches the implementer's Completion Evidence claim (10 tests, 0 failures).

## VERDICT

APPROVED_WITH_MINOR_NOTES

## Orchestrator dispositions (2026-09-10, closeout)

Every finding verified personally before disposition (direct code reads; the anti-tautology derivation independently reproduced bit-for-bit — epoch 2 → index 2, epoch 1 → index 9, epoch 3 → index 2, confirming both the pins' binding and NOTE-2):

- **NITPICK-1 — FIXED pre-commit:** `MomoApp.fixedTimeSources()` guard split; a flag without a value now `assertionFailure`s (same discipline as the unparseable path) instead of silently riding the system clock. Doc comment updated to "UNPARSEABLE or MISSING".
- **NITPICK-2 — DOCUMENTED:** comment added at `HomeContextualLineView`'s `.lineLimit(2)` — single line at default type, the cap lets accessibility sizes wrap without truncation.
- **NITPICK-3 — FIXED pre-commit:** both `CopyRules` care-moment comments now say TASK-035 (034 owns the spoken reaction tier only).
- **NOTE-2 — FIXED pre-commit:** `rawKeysPinned`'s doc comment reworded — same-residue epoch bumps leave the full-key pins green; the `copyEpochIsTwo` literal is the epoch guard.
- **NOTE-1 — no action:** defense in depth judged adequate as reviewed.
- **MINOR-1 — ROUTED to TASK-039's contract** (complete verbatim catalog pins: 40 slot lines, 3 greetings, 8 status words, 7 wishes — extend the `catalogCarriesTheVocabularyVerbatim` pattern). Recorded in status.md; AC-5 of TASK-034's contract already requires the pattern for the new react.touch pool at landing.
- **OBSERVATION-A — ROUTED to the owner** (product question: greeting domination / ambient-line exposure). Recorded in status.md's owner items; not blocking (behavior is contract-specified + frozen-engine semantics).
- **OBSERVATION-B — RECORDED into the doc chain:** dated engine-truth errata note added under 03 §5.5's window-rendering bullet (Q6 opens unconditionally `hour ≥ 20 ∨ hour < 7`; day-2+ early-morning shows 3 lines; engine normative). Recorded alongside OBS-C's discharge.
- **OBS-C — DISCHARGED:** dated slot-boundary reconciliation note added at 04 §10.3's head (headers are illustrative groupings; the engine's `CopyRules.timeSlot` cut-offs — Day/Evening split at 18:00 — are normative; no line moved).

Post-disposition §19 gate at the final tree (orchestrator, this tree): `swift test` → **868 tests / 88 suites passed**; full app suite on pinned sim `1F25E487-A78E-464C-95AF-0BD1A9B3E1BE` → **Executed 10 tests, with 0 failures — `** TEST SUCCEEDED **`**.
