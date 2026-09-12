VERDICT: APPROVED_WITH_MINOR_NOTES

# REVIEW-TASK-043 — Watch cascade (live shared derivation + UX-13 propagation)

Reviewer: fresh independent Jupiter reviewer (§10/§33), 2026-09-12.
Subject: the uncommitted implementation on `feature/EPIC-008-watch-sync` (base `898fe09`): 3 modified files (`Apps/MomoWatch/GlanceView.swift`, `Apps/MomoWatch/MomoWatchAppModel.swift`, `MomoWatchUITests/MomoWatchUITests.swift`) + 4 new (`Sources/MomoKit/WatchQuestCascade.swift`, `Tests/MomoKitTests/WatchCascadeTests.swift`, `Tests/MomoKitTests/Support/WatchQuestScan.swift`, `Tests/MomoKitTests/MomoWatchQuestScanTests.swift`) + the task file.
Method: spec re-derived from normative docs BEFORE opening any implementation; independent attack-surface analysis; 3 own mutation probes (sha256-restored, none reusing the implementer's disclosed bites); all §19 gates re-run.

## 1. Spec re-derivation (Phase 1, before reading implementation)

Derived independently from 05 §4.8/§4.10/§4.11, §10.4 stale-data row, 03 §5.5/§6.1/§6.4, §7 reservation, UX-13, 04 §10.1 rule 7/§10.2/§10.4, PRD §5.2/§5.4/§5.5 (incl. the owner-amended rule 1, OPEN-1), delivery-plan TASK-043 row, D20 (01-product-review):

- **Render**: W1's quest line (visual slot AND VoiceOver composite) = the ONE shared cascade (`QuestGeneration.cascade`, PRD §5.5 rules 1–6, amended rule 1: Q6 in-set ∧ incomplete ∧ hour ≥ 20 ∨ < 07) re-run over the snapshot's carried quest inputs under the Watch's local hour. Wish text = the PRD §5.2 catalog copy through catalog keys (no literals — D12/INV-11); no progress counts on the line (identical at 0/1/2-of-3 for Q7); all-done swap only on completion.
- **Recompute**: event-driven only (§4.2 — the Watch has no engine, no timers): init/first render, snapshot receive, scene activation. Clock inputs = the INJECTED wallClock + calendar only (D20/§4.10 — no ambient reads).
- **Must NOT exist**: timers/polling; ambient clock reads on the path; Watch-side cascade logic (single shared derivation — delivery-plan row); a claim/complete affordance on the quest line (display-only, UX §6.1); a Watch settings surface (UX-13); any error/freshness surface on stale inputs (§10.4 "stale data", UX-9); new copy keys outside the catalog law.
- **All-done**: the PRD §5.5 item 6 string is "All done — see you soon" (+ happy Momo); the iPhone M3 card note is separately "Momo had a lovely day." (03 §5.5; 04 §10.1 rule 7) — two different surfaces' copy in the corpus. (This tension became D2; ruled in §6.)

The derived spec and the contract's R1–R7 agree on every operative point. One contract defect noted: the Context section asserts `HomeCopyKeys.allDoneLineKey` → "All done — see you soon" and cites "UX §7" — both wrong (the key resolves to "Momo had a lovely day."; the M3 line is §5.5/04 §10.4, while §7 is the Phase-2 widget reservation). The implementer caught the value error and disclosed it as D2 rather than shipping against the corpus — correct.

## 2. Findings

### F-1 — MAJOR (no code change on this task; owner/docs follow-up): W1's all-done copy deviates from the normative string (D2 adjudicated)

W1's all-done quest line renders `HomeCopyKeys.allDoneLineKey` → `momo.line.moment.02` = **"Momo had a lovely day."** (`Sources/MomoKit/HomeCopyKeys.swift:161`; `Apps/Shared/MomoCopy.xcstrings`), but the corpus normatively assigns W1's all-done state the string **"All done — see you soon"** in FOUR places: PRD `02-mvp-prd.md:225` (§5.5 item 6), `03-ux-architecture.md:330` (§6.1 sketch), `:335` (§6.1 rule — "swaps to 'All done — see you soon' only on completion"), and `:420` (§9 table, Watch column). The "Momo had a lovely day." string is the **iPhone M3 card note's** copy (03 §5.5:299; 04 §648 rule 7 "'Momo had a lovely day.' class"; 04 §728: M2+M3 live under `momo.line.moment.<nn>`). "see you soon" appears **zero** times in the shipped catalog; `moment.02` has carried the M3 string since TASK-036 (`3861c7b`).

**Ruling: option (B), refined.** The corpus does NOT sanction superseding the PRD string for W1 — the same UX document that fixed the iPhone card's warmer line (§5.5) keeps "All done — see you soon" for W1 in two places and in the §9 Watch column — so the shipped W1 line is a real (if calm-register, tone-compliant, banned-vocabulary-free) deviation from PRD §5.5 item 6. However: (a) the conflation **predates this task** — the `questLineKey(for:) → allDoneLineKey` binding shipped in TASK-041 and was merely inherited; (b) the contract itself propagated the error (R2's quote + the false Context claim), so the implementer "followed the contract" and correctly refused the two worse alternatives (editing shared `moment.02` would regress the iPhone M3 card — `Apps/Momo/HomeQuestCardView.swift:54` — and a forked Watch-only key is a product-defining copy decision needing catalog law + owner approval, §36); (c) it cannot be fixed on this task either way (frozen `Apps/Momo`; new keys owner-gated). **Required follow-up (record in errata backlog + status.md, resolve before EPIC-008 closeout):** owner ruling to mint a W1 all-done key (the `momo.line.quest.*` namespace exists — e.g. `momo.line.quest.all-done`) + Watch-side key swap in a future task; docs errata for UX §9's iPhone M3 row (which misquotes the PRD string against §5.5) and, if the owner prefers the shared line, PRD §5.5 item 6 + UX §6.1/§9 instead.

### F-2 — MINOR: guard 1's frozen-read census misses the bare-`display.questLine` spelling (probe-demonstrated)

`WatchQuestScan.questSlotViolations` counts the literal `.display.questLine` (leading dot; `Tests/MomoKitTests/Support/WatchQuestScan.swift:136`). A frozen-line read through the local `display` binding — exactly the form `compositeLabel`'s body holds (`display.questLine`, GlanceView.swift:242-249) — does **not** match. Probe B proved it: reverting the VoiceOver composite to `display.questLine` left all 21 scan tests green while the divergence shipped. The layered discipline still caught it at the UI level (`testStaleFixtureRendersTheLiveCascadeLine` red — see Probe B), so this is a belt gap, not a hole to the user. Suggested (future, one line): census the bare spelling too, or assert `compositeLabel`'s body contains no `questLineKey` call other than the threaded value.

### F-3 — MINOR: the D20 injected-clock property of the recompute leg is unenforced by any test (probe-demonstrated)

Probe C replaced `calendar.component(.hour, from: wallClock.now())` with an ambient `Calendar.current…Date()` read in `recomputeQuestLine()` (`Apps/MomoWatch/MomoWatchAppModel.swift:320`): every suite stayed green (21 scan + 5 cascade tests re-run; nothing watches clock tokens on this path — the no-engine scan bans engine derivations, not ambient time). The shipped code is D20-clean (verified by reading: the only clock inputs on the path are the injected pair), but a future regression would ship silently. A banned-token addition (`Date()`, `Calendar.current` in `Apps/MomoWatch` production sources) to a scan would close it. Review-enforced only today.

### F-4 — MINOR (analytical, not probe-demonstrated): guard 1's affordance ban has bypass spellings

`slotBannedActionTokens` bans `Button(`, `.onTapGesture`, `.accessibilityAction` (`WatchQuestScan.swift:76-80`) and the file census counts `Button(`/`.onTapGesture` only. An action affordance spelled `.gesture(TapGesture()…)`, `.highPriorityGesture`, `.simultaneousGesture`, or `.contextMenu` inside the slot body would evade both. Same class of gap as F-2; the shipped view is clean (verified by reading the full GlanceView).

### F-5 — MINOR (analytical): guard 2 censuses `recomputeQuestLine()` calls, not `liveQuestLine` writers

A fifth direct assignment to `liveQuestLine` inside `MomoWatchAppModel.swift` would pass the legs census. Mitigated: the property is `private(set)` (single-file write scope) and the current file has exactly the two assignments inside `recomputeQuestLine()` (lines 317, 321 — verified by grep over the whole target). Low risk today.

### F-6 — NOTE: the frozen fallback could mask a future invariant break silently in release

`model.liveQuestLine ?? snapshot.display.questLine` (GlanceView.swift:70) is genuinely unreachable at every current leg (the snapshot mutation and the recompute are adjacent synchronous statements on the main actor — no render can interleave; verified per leg), and the census pins its single read. But if a future leg ever broke the nil-coherence invariant, release builds would silently render stale lines where a `debugLoud` would have tripped the debugger (the file's own MomoCopy discipline). Acceptable as shipped; noting the design tradeoff.

### F-7 — NOTE: contract Context mis-citation

The contract's Context cites "UX §7" for the M3 all-done line; §7 is the Phase-2 widget reservation — the M3 line is 03 §5.5 + 04 §10.1 rule 7/§10.4. The same slip produced R2's wrong quoted string (F-1). No code impact.

### Verified-correct attack surfaces (no finding)

- **Hour derivation**: `recomputeQuestLine()` reads ONLY the injected `wallClock`/`calendar` (MomoWatchAppModel.swift:320). A grep of the whole Watch target finds no ambient time read on any cascade path (the two `SystemEngineClock()` hits are the pre-existing injected defaults + the presentation `canvasClock`, both outside the cascade path).
- **Recompute legs**: exactly four, matching the disclosure (init after the launch read, receive-steady immediately after `self.snapshot = snapshot` and before the persist legs, receive-consume immediately after the clear, `scenePhaseChanged` gated `phase == .active` first). No fifth writer of `liveQuestLine` exists anywhere (grep; `private(set)`). The nil-coherence invariant ("nil exactly when snapshot nil") holds at every leg with no suspension window.
- **No timers**: no `Timer`/`Task.sleep`/scheduled machinery anywhere in the new code; hour-boundary latency is disclosed in code + task file and governed by UX-9 — consistent with §4.2 and the UX §9 midnight row ("Same at next sync").
- **Frozen fallback reachability**: unreachable at every current leg (see F-6) — it cannot mask any *current* bug; census-pinned at exactly one read.
- **D4 (estimator keeps the FROZEN line)**: correct, and the disclosure's rationale understates the stronger argument — `WatchPatPlan.isCompletingPat` consumes `questLine` AND `questInputs` from the same held snapshot (Sources/MomoKit/WatchPatPlan.swift:112-122); the quest inputs are frozen either way, so pairing a live line with frozen progress would mix epochs. The frozen/frozen pair is the coherent one; the estimate remains presentation-only (ADR-015 D2), and its `.wish(.q7)` guard is exactly what the frozen line supplies at push time. Keeping `.display.questLine` in `MomoWatchPat.swift` with the census scoped to GlanceView is right.
- **Provenance test construction**: builds through the REAL derivation chain (`makeDisplayState` → day-record lookup → `makeWatchSnapshot`) over a windowed set whose two push hours disagree (Q6-in-window vs Q7), so agreement-for-the-wrong-reason cannot pass; asserts the premise (`display.questLine == expected`) before the property. It replicates the real push arm's threading (`MomoAppModel+Watch.swift:118,144-147` — `todaysQuestInputs(now:)`) exactly.
- **Scan-guard fixture discipline**: all three guards are comment-stripped, both-direction fixtures isolate each predicate to exactly one finding, comment-citation cases prove the stripper neither mutes citations nor accepts fake compliance, and three standing tests run over the real tree via `KitRepo.momoWatchSources()` (non-empty asserted). (Token-level tolerances F-2/F-4/F-5 notwithstanding.)
- **D3 fixtures**: verified by cascade arithmetic — `w1` [Q1✓,Q2✓,Q7 0/3] → `.wish(.q7)` at all 24 hours; `alldone` [Q1✓,Q2✓,Q7 3✓] → `.allDone` at all hours; `stale` [Q1 0,Q2 0,Q6 0] → Q6/Q1/Q2 by window (matches the UI test's wish-text map and the `momo.line.quest.q6/q1/q2` catalog strings). D8's ±1-hour tolerance is sound (the disagreement direction is only h→h+1 across the runner-read/render gap; hour 23→0 collapses to the same Q6 text).
- **R5 mapping**: all four anchors verified real — `WatchPatScan` order-pins `haptics.play(` inside `if snapshot.hapticsEnabled` (WatchPatScan.swift:120-123); `WatchSnapshotBuilderTests.hapticsFollowsTheSettings` (:56); the codec roundtrip anchor; the estimate tests in `WatchPatPlanTests`. Mapping over duplication is what R5's clause asked for.
- **D1**: the seam is genuinely scan-mandated — `WatchGlanceScan.bannedEngineTokens` bans `QuestGeneration.cascade(` (WatchGlanceScan.swift:61), so the Watch target cannot call the cascade directly without going red. The seam is zero-logic forwarding, package-side (pbxproj untouched), and its passthrough is pinned at the argument level by three binding tests. Not scope creep.
- **D5/D6/D7**: verified against the code (ordering, reshape, both-spelling tokens all as disclosed).

## 3. Mutation probes (reviewer's own; implementer's two bites NOT reused)

| # | Target | Mutation | Pre-hash | Mutated hash | Expected red | Observed | Restored |
|---|--------|----------|----------|--------------|--------------|----------|----------|
| A | `Sources/MomoKit/WatchSnapshotBuilder.swift` | builder threads `questInputs: []` instead of the passed inputs (a real builder↔cascade drift) | `029ff2294fcefa84a50fd0ba9a93abb7b13a7e9cf8b07a098c6f27575794923d` | (transient) | provenance property red; builder field-threading pin red; negative control green; nothing unrelated | EXACTLY that: `builtSnapshotRecascadesToItsCarriedLineAtThePushHour` red on both arguments (`.allDone` vs carried `.wish(.q6)`/`.wish(.q7)`), `every snapshot field is threaded from the explicit inputs` red (same field, expected family), `provenanceBitesOnDriftedInputs` green, 1128-test run showed no other failure | byte-identical, `029ff229…` re-hashed |
| B | `Apps/MomoWatch/GlanceView.swift:249` | VoiceOver `compositeLabel` reverts to the frozen line (`questLineKey(for: display.questLine)`) — visual slot stays live | `99dacd2b655a1836586aaad9f22594e017ce86bd83f1302cb25f6304ff2b4c80` | (transient) | kit scan red; UI stale flow red | kit scan **stayed green** (bare-spelling census gap → finding F-2); UI `testStaleFixtureRendersTheLiveCascadeLine` **RED** with exact diagnosis: label `'…Today's wish: Momo had a lovely day.. Pat button.'` vs expected hour-1 wish — the UI layer is the real teeth for the one-value-both-surfaces rule | byte-identical, `99dacd2b…` re-hashed |
| C | `Apps/MomoWatch/MomoWatchAppModel.swift:320` | injected clock → ambient `Calendar.current.component(.hour, from: Date())` (D20 violation) | `99847e369db509455b0696d8019f6f46b96f80073e2a223d6a80dd25c4d9ffbe` | (transient) | NO red expected — demonstrates the D20 enforcement gap | EXACTLY that: `MomoWatchQuestScanTests` (21) and `WatchCascadeTests` (5) all green → finding F-3 | byte-identical, `99847e36…` re-hashed |

Post-restore: full `swift test` re-run → **1128/1128 PASSED** (clean-tree confirmation). The two app-file pre-hashes also match the implementer's disclosed bite pre-hashes, corroborating their bite records independently.

## 4. Gates (re-run on the working tree)

| Gate | Result |
|---|---|
| `swift test` | **1128 tests / 110 suites, all PASSED** (baseline 1102/108 + 26 new: 5 `WatchCascadeTests`, 21 `MomoWatchQuestScanTests`) |
| Coverage (measured IMMEDIATELY after `swift test --enable-code-coverage`, same chain: `llvm-cov report … Sources/MomoKit`) | **90.81% lines** (1741 lines, 160 missed; region 91.41%) — floor ≥ 80 % held, matches the implementer's number |
| `xcodebuild -scheme MomoWatch -destination 'id=8A854895-…'` | **BUILD SUCCEEDED**; zero warnings on touched files; only the pre-existing machine-level notices (`/opt/extra/lib` ld search path ×2, appintentsmetadataprocessor) |
| `xcodebuild -scheme Momo -destination 'id=1F25E487-…'` | **BUILD SUCCEEDED**, zero warnings |
| `xcodebuild -scheme MomoWatch … -only-testing:MomoWatchUITests test` | **TEST SUCCEEDED**; `xcresulttool get test-results summary` → **total 7 / passed 7 / failed 0 / skipped 0** (5 baseline + 2 TASK-043 flows) |
| Frozen surfaces | `git diff --name-only -- Sources/MomoCore/ Sources/MomoCharacter/ Apps/Momo/ Momo.xcodeproj/` → **EMPTY**; `Apps/Shared/` diff empty (no copy keys); no entitlements/Info.plist changes; `Apps/Momo/MomoAppModel.swift` untouched |
| Tree integrity after probes | all mutated files sha256-restored byte-identical (§3); final `swift test` green |

## 5. D2 ruling (summary — full evidence in F-1)

**(B), refined:** "All done — see you soon" remains W1's normative all-done string (PRD §5.5 item 6; UX §6.1 twice; UX §9 Watch column); the shipped `moment.02` binding renders the iPhone M3 card's line onto W1 — a pre-existing TASK-041-era conflation the contract itself carried forward. The implementer's escalation (no catalog edit, no key fork, render through the existing key, disclose) was the correct §36 handling and is the right state to ship for THIS task. Follow-up required before EPIC-008 closeout: owner ruling on a W1 all-done key (`momo.line.quest.*` namespace exists) + docs errata (UX §9's iPhone M3 row misquote; PRD §5.5/UX §6.1 if the owner instead adopts the shared line everywhere).

## 6. Scope-creep and dead-code observations

- **Scope**: none. Every delta is contract-traceable (D1 scan-mandated seam; D3 fixtures required by R6 once the live line exists; the `seedFixture` dedup and `seededApp(store:fixture:)` refactor are the minimal generalizations of the existing seams; F-R2 comment fixes are the sanctioned ride-along). The haptics "no new test" resolution is exactly R5's no-duplicate clause.
- **Dead code**: none. The fallback read is census-pinned and documented as belt-and-braces; the seam is test-pinned; every new fixture kind has a consuming test.
- **Comment honesty**: the ride-along comment fixes are accurate (three store reads); the new doc comments state the no-timer latency, day semantics, and D4 decision truthfully.

## 7. Verdict

**APPROVED_WITH_MINOR_NOTES.** The implementation is correct against the re-derived spec at every attacked surface; the provenance test has real teeth (Probe A); the contract's deltas are truthful. F-1 requires an owner/docs follow-up tracked outside this task's code; F-2/F-3/F-4/F-5 are guard-tolerance notes for a future hardening pass (the UI layer currently supplies the missing teeth for F-2). Recommended: orchestrator commits + pushes per §12/§13, records the D2 follow-up in status.md + the errata backlog, and routes F-2/F-3's one-line guard additions into a future task (TASK-044 or a delta).
