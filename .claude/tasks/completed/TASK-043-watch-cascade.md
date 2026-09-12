# TASK-043 — Watch cascade + settings/haptics propagation

## Parent Epic

EPIC-008 — Watch App & Sync (`.claude/tasks/epics/EPIC-008-watch-sync.md`), task 4 of 5.

## Objective

Make W1's quest line LIVE: the Watch re-runs the SINGLE shared cascade derivation (`QuestGeneration.cascade`, MomoCore, public — 05 §4.8/§4.11) over the snapshot's carried `questInputs` with the WATCH's own local hour, so the line tracks time windows (Q1 before noon, Q6 from 20:00) without waiting for an iPhone push, and the all-done state renders "All done — see you soon" (UX §6.1). Prove the settings/haptics propagation (UX-13: the toggle arrives via snapshot and is honored; NO Watch settings surface exists) with named tests and structural scan guards. Zero Watch-side cascade logic — the Watch consumes, never re-implements.

## Context

- TASK-041 shipped W1 rendering the FROZEN push-time `display.questLine` — `Apps/MomoWatch/GlanceView.swift` quest slot; the code comment there explicitly reserves the Watch-side re-cascade for this task.
- The snapshot ALREADY carries both the push-time cascade output (`display.questLine`) and the raw inputs the cascade needs (`questInputs: [QuestProgress]`) — 05 §4.11's provision, shipped in TASK-023/040. `QuestGeneration.cascade(questSet: [QuestProgress], localHour: Int)` is `public`, pure, and MomoCore-tested (`QuestCascadeTests`, `QuestGenerationPinnedTests`, `DisplayStateTests`) — the Watch target already consumes MomoCore types.
- The all-done copy path already renders: `HomeCopyKeys.allDoneLineKey` → `momo.line.moment.02` ("All done — see you soon", M3's warm line per UX §7). NO new copy keys are expected.
- Haptics propagation is functionally LIVE end-to-end (TASK-040 pushes `hapticsEnabled`; TASK-042 honors it at pat time, structurally guarded by the haptic-seam scan with both-direction fixtures). This task adds the named E2E propagation test only if a gap remains after verification.
- TASK-042 injected `wallClock` (an `EngineClock`-family clock) and `calendar` into `MomoWatchAppModel` — the re-cascade's time inputs already exist.
- **Ride-along (REVIEW-TASK-042 F-R2):** the launch-read comments in `Apps/MomoWatch/MomoWatchAppModel.swift` (~lines 64–65 and ~201–202) still say "snapshot + consumed marker" though the epoch store is now a third launch read (see ~line 216) — one-line comment fixes on this task's incidental touch of that file.

## Requirements

- **R1 — Live re-cascade.** W1's quest line (the visual slot AND the VoiceOver composite — both read it today via the same `questLineKey(for:)` path) renders the output of `QuestGeneration.cascade(questSet: snapshot.questInputs, localHour: <watch local hour>)` instead of the frozen `display.questLine`. Semantics pinned:
  - The local hour derives from the INJECTED `wallClock` + `calendar` (D20 — no ambient reads; `calendar.component(.hour, from: wallClock.now())`, the same shape `makeDisplayState` uses).
  - Recompute at: init/first render, snapshot receive, and scene activation (background→foreground). Recomputed state lands in STORED observable state the view reads (an `@Observable` computed property reading `wallClock.now()` is NOT change-tracked — do not rely on it for reactivity). **NO timers** (§4.2 discipline); the hour-boundary latency (a line going stale until the next render trigger) is ACCEPTED and disclosed — UX-9's no-freshness-indicator calm governs.
  - Day semantics: the cascade always runs over the CARRIED set under the Watch's local hour; the Watch never synthesizes a day's set (no invented quests; the set refreshes only on the next snapshot). Document this reading in code.
  - `display.questLine` STAYS in the DTO (schema untouched; it is the provenance cross-check, R3).
- **R2 — All-done state.** When the cascade yields `.allDone`, W1 shows "All done — see you soon" (the existing key). Covered by a fixture-driven Watch UI test (R6).
- **R3 — Provenance named test (kit-level).** For a built snapshot, `cascade(questSet: questInputs, localHour: <the push instant's local hour>)` == `display.questLine` — the builder's output and the Watch's re-derivation agree at the push instant (this is the test that would catch the DTO/builder drifting from the shared cascade).
- **R4 — Display-only rule + UX-13 guards (structural scans, both-direction fixtures, in the existing scan-test family).**
  - The quest slot exposes NO claim/complete path on the Watch (no tappable quest/claim affordance — display-only per UX §6.1; the pat canvas and Pat pill remain the only pat targets).
  - NO Watch settings surface: a view census over `Apps/MomoWatch` asserting no settings/toggle screen exists (UX-13: settings are iPhone-owned and sync via snapshot).
- **R5 — Haptics propagation named test.** Verify the E2E toggle semantics (snapshot `hapticsEnabled == false` → no haptic on pat; `true` → tick/celebration per TASK-042). If TASK-042's suites already pin this behaviorally at the app-model seam, record the mapping and add only what is genuinely missing — do not duplicate.
- **R6 — Tests.** Named kit tests for the W1 re-cascade binding (identical line at 0/1/2-of-3 progress; swap to `.allDone` only at completion — comes free from the shared cascade, asserted at the binding level); fixture Watch UI tests: all-done fixture renders the M3 line; a stale-set fixture renders sanely under a shifted local hour (§10.4 "stale data" row's Watch-UI share). Structural scan guards (R4) with mutation bites.
- **R7 — Ride-along F-R2.** The stale launch-read comments in `MomoWatchAppModel.swift` corrected in the same change (comment-only lines).

## Files / Areas Likely Affected

- `Apps/MomoWatch/GlanceView.swift` — quest slot + a11y composite read the live value (small).
- `Apps/MomoWatch/MomoWatchAppModel.swift` — stored live-quest-line state + recompute legs (init/receive/scene-activation) + the F-R2 comment fixes (file at 465 ln; 800 budget).
- `Apps/MomoWatch/MomoWatchPat.swift` — ONLY if the pat flow's estimator should read the live line (decide + document: the estimator currently reads `snapshot.display.questLine`; if the live line is more correct, justify the change — otherwise leave and record why).
- `Tests/MomoKitTests/` — new named tests + scan guards (+ `Support/` fixture helpers as needed).
- `MomoWatchUITests/MomoWatchUITests.swift` — +1–2 flows (all-done fixture; stale-hour fixture).
- `Momo.xcodeproj/project.pbxproj` — EXPECTED UNTOUCHED (no new production files anticipated; if tests need a new Support file it is package-side, not pbxproj-side).

## Dependencies

- TASK-040 (snapshot carries `questInputs`), TASK-041 (W1 render + fixture seam + persist legs), TASK-042 (injected `wallClock`/`calendar`; the haptic-seam scan; `MomoWatchPersister+Journal` census).
- MomoCore `QuestGeneration.cascade` public API (frozen; consumed only).
- UX-13/UX §6.1/UX §7 normative; 05 §4.8 (Watch quest cascade) + §4.11 (read-model consumption) + §10.4 ("stale data" row).

## Constraints

- `Sources/MomoCore/` FROZEN — zero edits (the cascade is consumed via its existing public signature).
- `Sources/MomoCharacter/` frozen; **`Apps/Momo/**` must diff EMPTY** (no iPhone-side need exists — the snapshot already carries the inputs; if implementation discovers one is unavoidable, STOP and record a blocker).
- `Apps/Momo/MomoAppModel.swift` remains 800/800 untouched.
- No new copy keys expected; if one proves unavoidable it lands through the catalog law (04 §10.4 namespaces; banned-vocabulary scan covers it; fixed-lookup never drawn).
- No entitlements/Info.plist/capability changes (§27); D-R3 re-verified if (unexpectedly) the pbxproj changes.
- No timers, no background refresh machinery (§4.2); no freshness/error surface (UX-9).
- §24 scope protection: NO settings surface, NO claim path, NO quest UI beyond the line.

## Acceptance Criteria

1. W1's quest line (visual + VoiceOver) is the live cascade output over the carried `questInputs` under the Watch's local hour; identical at 0/1/2-of-3; swaps to "All done — see you soon" only at completion.
2. The provenance test holds: re-cascade at the push hour == carried `display.questLine`.
3. Recompute happens at init/receive/scene-activation with NO timers; hour-boundary latency disclosed as accepted.
4. UX-13 guards green: no claim path in the quest slot; no settings surface in `Apps/MomoWatch` (view census).
5. Haptics propagation pinned by a named E2E test (or its existing coverage mapped and the gap closed).
6. All-done fixture and stale-hour fixture render sanely in the Watch UI suite.
7. F-R2 comments corrected; no other comment/code drift.
8. Frozen surfaces hold: `Sources/MomoCore/`, `Sources/MomoCharacter/`, `Apps/Momo/**` all diff-EMPTY; pbxproj untouched (or D-R3 re-verified if it changes).
9. Gates: `swift test` green (≥ 1102 baseline + this task's additions); MomoKit line coverage ≥ 80 %; both app builds SUCCEEDED with zero touched-file warnings; `MomoWatchUITests` green (5/5 → grown).

## Required Tests

- Kit: provenance test (R3); W1-binding identical-line + all-done-swap tests; UX-13 scan guards with both-direction fixtures + ≥ 2 mutation bites (each exactly-red, sha256-restored); haptics-propagation named test or gap-closure.
- UI: all-done fixture flow; stale-hour flow (§10.4 stale-data Watch share).
- All standing discipline suites stay green (no new exemptions); coverage measured IMMEDIATELY after `swift test --enable-code-coverage` (the orphaned-profdata gotcha).

## Review Requirements

Fresh Jupiter reviewer per §10/§33: re-derive the spec from 05 §4.8/§4.11 + UX §6.1/§7 + UX-13 + this file BEFORE reading implementation; verify frozen surfaces; verify the provenance test's teeth (its own mutation probe: break the builder↔cascade agreement and watch it bite); re-run all gates; ≥ 2 own mutation probes (not reusing the implementer's); tree left byte-identical except `.claude/tasks/reviews/REVIEW-TASK-043.md` + a one-line verdict under `## Reviewer Findings`.

## Git Requirements

- The implementation agent does NOT commit (§9). After APPROVED/APPROVED_WITH_MINOR_NOTES the orchestrator makes ONE atomic commit: `feat(watch): TASK-043 watch cascade — live shared derivation + UX-13 propagation` (hash lands in status.md), then pushes (§13).

## Status

READY — contract authored 2026-09-12 from the orchestrator's grounded source inspection (GlanceView quest slot, SyncDTOs fields, QuestGeneration.cascade signature/publicity, existing MomoCore cascade tests, TASK-042's injections).

## Implementation Notes

Implemented 2026-09-12 by the fresh TASK-043 agent on `feature/EPIC-008-watch-sync` (base `898fe09`). All requirements landed; every disclosed delta is listed under "Disclosed deltas".

### What landed (per requirement)

- **R1 — Live re-cascade.** New stored observable `MomoWatchAppModel.liveQuestLine: QuestGeneration.QuestLine?` (nil exactly when `snapshot` is nil), recomputed by one private method `recomputeQuestLine()` at exactly FOUR legs: (1) init (after the reaction-director seed), (2) receive steady shape (immediately after `self.snapshot = snapshot`, BEFORE the persist leg), (3) receive consume (after `self.snapshot = nil`), (4) `scenePhaseChanged(to: .active)` (gated on the active phase, before the background-persist branch). The hour derives ONLY from the injected clocks: `calendar.component(.hour, from: wallClock.now())` (D20). No timers anywhere; hour-boundary latency accepted and disclosed in code comments + UX-9 governs. `GlanceView.glance(for:)` now computes `let questLine = model.liveQuestLine ?? snapshot.display.questLine` (the ONE frozen read, belt-and-braces fallback; the scan census pins exactly one of each) and threads it into BOTH the visual `questSlot(for:)` and the VoiceOver `compositeLabel(for:questLine:)` — one value, both surfaces. Day semantics documented in code: the cascade always runs over the CARRIED `snapshot.questInputs` under the Watch's local hour; the Watch never synthesizes a day's set; the set refreshes only on the next snapshot.
- **Binding seam (required by the discipline scan).** `WatchGlanceScan.bannedEngineTokens` bans the literal `QuestGeneration.cascade(` from `Apps/MomoWatch` code, so the app model calls a new package-side seam instead: `Sources/MomoKit/WatchQuestCascade.swift` — `WatchCascade.liveQuestLine(questSet:localHour:)` forwarding to `QuestGeneration.cascade` (zero logic added; the shared MomoCore derivation is still the single implementation). Package-side ⇒ **pbxproj stays untouched** (SwiftPM resolves the new file), holding AC-8's pbxproj clause.
- **R2 — All-done.** Renders through the existing `HomeCopyKeys.allDoneLineKey` → `momo.line.moment.02` — see delta D2 on the catalog wording before acting on R2's quoted copy.
- **R3 — Provenance named test.** `WatchCascadeTests.builtSnapshotRecascadesToItsCarriedLineAtThePushHour` (parametrized over two push instants 21:00Z / 09:00Z): builds a REAL day record through the StoreFixture builders, runs the full iPhone push-arm derivation (`makeDisplayState` → day-record lookup → `WatchSnapshotBuilder.makeWatchSnapshot`), then asserts BOTH `display.questLine == <expected cascade output>` AND `WatchCascade.liveQuestLine(questSet: snapshot.questInputs, localHour: <push hour>) == display.questLine`. A companion test `provenanceBitesOnDriftedInputs` proves the predicate's teeth by feeding drifted inputs (`[]` vs the real set) and asserting the property FAILS.
- **R4 — Display-only + UX-13 guards.** New `Tests/MomoKitTests/Support/WatchQuestScan.swift` (3 guards, all comment-stripped via `MomoKitDisciplineScan.strippingComments`, `Finding{guardName,file,detail}` shaped like the prior scans) + `MomoWatchQuestScanTests.swift` (21 tests): guard 1 quest-slot display-only (slot body has `Text(` and zero of `Button(` / `.onTapGesture` / `.accessibilityAction`; whole-file census exactly 1 Button, 1 tap gesture, 1 `model.liveQuestLine`, 1 `.display.questLine`), guard 2 the four recompute legs (exactly 1 definition, calls − definitions == 4, receiveContext body carries a call, `phase == .active` appears BEFORE the recompute inside `scenePhaseChanged`), guard 3 no settings surface (banned tokens `Toggle(`, `SettingsLink(`/`{`, `NavigationStack(`/`{`, `TabView(`/`{`, `.sheet(`/`{`, `Form(`/`{`, `navigationDestination` over every Watch source; whole-target census exactly 1 `: View`). Both-direction fixtures per guard (green + every red predicate isolated to exactly 1 finding; comment-citation cases prove the stripper neither mutes citations nor accepts fake compliance) and 3 real-tree standing tests via `KitRepo.momoWatchSources()`.
- **R5 — Haptics propagation.** Verified as ALREADY pinned end-to-end; mapping recorded, no duplicate test added (per R5's "record the mapping" clause): (1) toggle→snapshot — `WatchSnapshotBuilderTests.hapticsFollowsTheSettings` (builder emits `hapticsEnabled` from `state.settings`, both values tested); (2) snapshot→DTO→Watch — the codec roundtrip anchor in the sync codec tests; (3) the gate honored at pat time — `WatchPatScan.patFlowGuard` pins the haptic call INSIDE `if snapshot.hapticsEnabled` with both-direction fixtures; (4) tick-vs-celebration selection — the five ESTIMATE tests in `WatchPatPlanTests`. UI-level haptic observation is not possible in the simulator; no genuinely-missing gap exists.
- **R6 — Tests.** Kit: `WatchCascadeTests` (5 tests): identical line at 0/1/2-of-3 progress across all 24 hours; `.allDone` ONLY at full completion (parametrized over all 24 hours); hour pass-through over an incomplete [Q1,Q2,Q6] set (3 → Q6, 9 → Q1, 14 → Q2, 21 → Q6 — the window rules); the R3 provenance pair above. UI: `testAllDoneFixtureRendersTheAllDoneLine` (asserts the M3 line "Momo had a lovely day" — the actual `moment.02` value) and `testStaleFixtureRendersTheLiveCascadeLine` (frozen all-done bytes over a fresh incomplete set must re-cascade to the current local hour's wish; the runner accepts this hour's OR the next hour's wish because the runner-read clock and the app's render may straddle a boundary — the disclosed no-timer latency). New DEBUG fixture kinds `alldone` + `stale` ride the existing `-momo-watch-fixture` seam (Release ignores; same DEBUG-only discipline as `w1`).
- **R7 — Ride-along F-R2.** Both stale launch-read comments in `MomoWatchAppModel.swift` corrected (now "three store reads — the snapshot pair, the consumed marker, and the session epoch" / "three KB-scale store reads"). Comment-only; no other comment drift.

### Disclosed deltas

- **D1 — new production file `Sources/MomoKit/WatchQuestCascade.swift` (~44 ln).** The contract anticipated no new production files; the discipline scan's engine-token ban makes a seam structurally required for ANY Watch-side cascade call. It is package-side (SwiftPM), so pbxproj remains untouched as the contract's hard expectation demands. The seam adds zero logic (pure forwarding) and is doc-commented with the carried-set/day semantics.
- **D2 — `moment.02` catalog wording vs R2's quote (ORCHESTRATOR/OWNER ADJUDICATION).** R2 quotes "All done — see you soon", but the shared catalog's `momo.line.moment.02` (which `HomeCopyKeys.allDoneLineKey` resolves to, and which the iPhone M3 card already renders — TASK-036) is **"Momo had a lovely day."** This task rendered through the EXISTING key unchanged: editing the catalog entry would regress the iPhone M3 card (cross-surface shared key), and minting a Watch-only key would fork the all-done copy cross-surface for no approved reason. The M3 line is arguably the better fit for W1's calm register anyway. UI tests assert the actual shipped value. If the owner wants the literal "All done — see you soon" on the Watch, that is a deliberate cross-surface copy decision needing a catalog-law ruling — NOT a code fix on this task.
- **D3 — w1 fixture provenance fix.** The pre-existing `w1` fixture built its snapshot with `questInputs: []`, which cascades to `.allDone` at every hour — contradicting the fixture's own frozen display `.wish(.q7)` and the "Gentle pats" UI assertion once the view renders the live line. The fixture now carries the matching set [Q1 1✓, Q2 1✓, Q7 0-incomplete] so its carried set cascades to Q7 at all hours (test-only file, DEBUG-only seam). Added `alldone` ([Q1✓,Q2✓,Q7 3✓] → `.allDone` at every hour) and `stale` (frozen `.allDone` display over [Q1,Q2,Q6 all 0-incomplete] — live re-cascade can NEVER yield all-done for it, by construction).
- **D4 — pat-completion estimator keeps the FROZEN line (decision of record).** `MomoWatchPat.finishPat` still reads `snapshot.display.questLine`, NOT the live line: ADR-015 D2 defines the completion estimate over the HELD snapshot; substituting the live line would introduce hour-window false negatives (in the evening window Q6 outranks Q7 in `cascade`, so a just-completed Q7 pat could be mis-estimated against a Q6-naming live line). `.display.questLine` legitimately remains in `MomoWatchPat.swift` — the new census is scoped to `GlanceView.swift`.
- **D5 — receive-leg ordering.** The steady-shape recompute lands immediately after `self.snapshot = snapshot` and BEFORE the persist leg: render-critical observable state updates first, then I/O. Persist legs remain exactly two, both background-gated (`WatchGlanceScan.persistGuard` re-verified green on the standing tree).
- **D6 — `scenePhaseChanged` reshaped.** Formerly a single background-guarded persist; now: `.active` → recompute + return; `.background` (with snapshot) → persist. Both behaviors preserved, the activation leg added.
- **D7 — guard-3 token spellings.** SwiftUI trailing-closure containers (`NavigationStack {`, `.sheet {`, `Form {`, `TabView {`, `SettingsLink {`) have no opening paren; the ban list carries both spellings per token. All new tokens verified 0-count on the real standing tree.
- **D8 — stale UI test boundary tolerance.** The stale-fixture test accepts the current OR next hour's wish text: the runner reads its clock before launch, and the app's render may cross an hour boundary — this IS the accepted no-timer latency, asserted honestly rather than flakily.

### Gates (exact numbers)

- `swift test`: **1128 tests / 110 suites, all PASSED** (baseline 1102/108; +5 `WatchCascadeTests`, +21 `MomoWatchQuestScanTests` across 2 new suites).
- MomoKit line coverage (measured immediately after `swift test --enable-code-coverage`; profdata `.build/debug/codecov/default.profdata`, binary `.build/debug/MomoPackageTests.xctest/Contents/MacOS/MomoPackageTests`, source `Sources/MomoKit`): **90.81%** (1741 lines, 160 missed) — floor ≥ 80% held, baseline 90.79% fractionally beaten.
- `xcodebuild -scheme MomoWatch` on Watch SE 3 44mm `8A854895-225C-411B-89C1-B03337BFE957`: **BUILD SUCCEEDED**, **0 warnings on touched files** (GlanceView.swift / MomoWatchAppModel.swift / WatchQuestCascade.swift). 3 total log warnings, all pre-existing and machine-level: the `/opt/extra/lib` ld search-path notice (disclosed in TASK-042) and the appintentsmetadataprocessor "no AppIntents dependency" notice.
- `xcodebuild -scheme Momo` on iPhone SE 3rd gen `1F25E487-A78E-464C-95AF-0BD1A9B3E1BE`: **BUILD SUCCEEDED**; no warning references `Apps/Momo/` or any touched file.
- `MomoWatchUITests`: **7/7 PASSED** (5 baseline + the 2 new TASK-043 flows).
- Frozen surfaces: `git diff --stat -- Sources/MomoCore Sources/MomoCharacter Apps/Momo Momo.xcodeproj/project.pbxproj` → **EMPTY**; `Apps/Momo/MomoAppModel.swift` untouched (800/800); no copy keys added; no entitlements/Info.plist changes; no timers.

### Mutation bites (2, each exactly-red, sha256-restored)

1. **Bite 1 — GlanceView frozen revert** (the live read deleted, frozen line restored in place): `99dacd2b655a1836586aaad9f22594e017ce86bd83f1302cb25f6304ff2b4c80` → mutated `daa11747bd3ec44e8707ffb1ec5c0c15a3f5c0864ef63521aadde152892df8c8`. Exactly 1 test red — `realTreeQuestSlotIsDisplayOnly`, detail "expected exactly 1 model.liveQuestLine read (the stored re-cascade), found 0". Restored byte-identical (`99dacd2b…` re-hashed).
2. **Bite 2 — activation leg removed** (the `recomputeQuestLine()` call + gate deleted from `scenePhaseChanged`): `99847e369db509455b0696d8019f6f46b96f80073e2a223d6a80dd25c4d9ffbe` → mutated `39abe28ee9b9ad40d6e6e361b88e8f14a51a1e26819a4039d38591ddc88ecf26`. Exactly 1 test red — `realTreeRecomputeLegsHold`, detail "expected exactly 4 recomputeQuestLine() call legs … found 3". Restored byte-identical (`99847e36…` re-hashed).

The reviewer runs its OWN ≥ 2 probes (§33) — these two are disclosed as the implementer's, not offered as substitutes.

## Reviewer Findings

REVIEW-TASK-043: APPROVED_WITH_MINOR_NOTES — 2026-09-12 — live re-cascade correct at all four legs, injected-clock clean, no timers, no undeclared writers; provenance test BITES (reviewer Probe A: builder questInputs drift → exactly the property + its field-threading pin red); D2 ruled (B)-refined: W1 all-done normatively "All done — see you soon" (PRD §5.5 item 6, UX §6.1 ×2, UX §9 Watch column), shipped shared `moment.02` = iPhone M3 line — pre-existing TASK-041-era conflation, owner ruling + Watch-side key + docs errata required as follow-up, NO code change on this task; minors F-2 (census misses bare `display.questLine` — UI stale flow supplies the teeth, probe-demonstrated), F-3 (D20 of the recompute leg review-enforced only, probe-demonstrated), F-4/F-5 (analytical scan tolerances); gates re-run: swift test 1128/1128 (110 suites), MomoKit coverage 90.81 %, MomoWatch + Momo BUILD SUCCEEDED (only pre-existing machine notices), MomoWatchUITests 7/7 (xcresult-verified); frozen surfaces diff-empty; all 3 reviewer probes sha256-restored byte-identical; full record in `.claude/tasks/reviews/REVIEW-TASK-043.md`.

## Completion Evidence

**Orchestrator §19 reproduction (2026-09-12, personally re-run on the implementer's tree at base `898fe09`, BEFORE dispatching review):** `swift test` **1128 / 110 suites PASSED** (baseline 1102/108 + 26 new); MomoKit coverage **90.81 % lines** (160/1741 missed; region 91.41 %), measured IMMEDIATELY after `swift test --enable-code-coverage` (the orphaned-profdata gotcha respected; the new seam file 100 %); `xcodebuild -scheme MomoWatch` on Watch SE 3 44 mm `8A854895…` **BUILD SUCCEEDED**, zero warnings on touched files (only the 3 pre-existing machine-level notices); `xcodebuild -scheme Momo` on iPhone SE 3rd gen `1F25E487…` **BUILD SUCCEEDED**, zero warnings; `MomoWatchUITests` **7/7 PASSED** (xcresult-verified: total 7 / failed 0 / skipped 0 — 5 baseline + the 2 new flows); frozen surfaces (`Sources/MomoCore/`, `Sources/MomoCharacter/`, `Apps/Momo/`, `Momo.xcodeproj/`, `Apps/Shared/` catalog) **all diff-EMPTY**; `MomoWatchAppModel.swift` 600/800 lines; zero timers (grep); catalog untouched (no new copy keys). Load-bearing diffs spot-read and consistent with the Handoff (four recompute legs, D20 hour, one live read + one frozen fallback, real push-arm provenance test with negative control, census-based scan guards, boundary-tolerant stale UI flow with a negative assertion).

**Mutations:** implementer's 2 bites (frozen-revert; activation-leg removal) + reviewer's 3 probes (A builder-drift — provenance BITES; B bare-spelling composite revert — kit scan tolerance F-2 demonstrated, UI stale flow RED; C ambient-clock D20 violation — F-3 gap demonstrated) — all exactly-red as claimed, all sha256-restored byte-identical; reviewer's post-restore full `swift test` re-run 1128/1128 clean. Reviewer gates re-run independently and matched every number above (review record §4).

**Review:** APPROVED_WITH_MINOR_NOTES — findings routed: F-1 (D2 ruling (B)-refined: W1 all-done normatively "All done — see you soon"; shipped shared `moment.02` render is a pre-existing TASK-041-era conflation) → **standing owner item** recorded in status.md (owner copy ruling + Watch-side `momo.line.quest.all-done` key + docs errata; non-blocking for this task — no code change either reading); F-2 + F-3 → **TASK-044 ride-along guard hardening**; F-4/F-5/F-6 recorded, no action; F-7 (contract Context mis-citation) — orchestrator-owned, corrected understanding recorded here and in status.md.

**Commit:** `feat(watch): TASK-043 watch cascade — live shared derivation + UX-13 propagation` — (this commit) — one atomic commit on `feature/EPIC-008-watch-sync` containing the 3 modified + 4 new implementation/test files, this task record (moved to completed), and `.claude/tasks/reviews/REVIEW-TASK-043.md`.

**Push:** (this push pending) — origin `feature/EPIC-008-watch-sync`; result recorded in status.md's Recent Pushes.

## Handoff

### Completed

TASK-043 R1–R7 all landed. W1's quest line (visual slot + VoiceOver composite) renders the live shared cascade over the carried `questInputs` under the Watch's local hour, recomputed at exactly four disclosed legs (init / receive steady / receive consume / scene activation), no timers, stored observable state. All-done renders through the existing shared key. Provenance named test + bite prove builder↔cascade agreement. Three structural guards (display-only slot, four legs, no settings surface) with both-direction fixtures, 3 real-tree standing tests, 2 exactly-red sha256-restored bites. Haptics propagation mapped to its four existing pins (R5's no-duplicate clause). F-R2 comment fixes landed. All gates green; frozen surfaces byte-identical.

### Files Changed

- `Sources/MomoKit/WatchQuestCascade.swift` — NEW (~44 ln): the `WatchCascade.liveQuestLine(questSet:localHour:)` binding seam (delta D1; package-side ⇒ pbxproj untouched).
- `Apps/MomoWatch/MomoWatchAppModel.swift` — stored `liveQuestLine`, `recomputeQuestLine()` + the four legs, `scenePhaseChanged` reshape, `w1`/`alldone`/`stale` fixtures via shared `seedFixture(_:to:)`, F-R2 comment fixes (~570 ln of 800).
- `Apps/MomoWatch/GlanceView.swift` — one live read + one frozen fallback, threaded to both the quest slot and the a11y composite.
- `Tests/MomoKitTests/WatchCascadeTests.swift` — NEW (5 tests).
- `Tests/MomoKitTests/Support/WatchQuestScan.swift` — NEW (3 guards).
- `Tests/MomoKitTests/MomoWatchQuestScanTests.swift` — NEW (21 tests).
- `MomoWatchUITests/MomoWatchUITests.swift` — `seededApp(store:fixture:)` refactor + 2 new flows (7 total).
- `.claude/tasks/active/TASK-043-watch-cascade.md` — this file.

### Tests Run

`swift test`; `swift test --enable-code-coverage` + `llvm-cov report` (Sources/MomoKit); `xcodebuild build` MomoWatch (Watch SE 3 44mm sim) and Momo (iPhone SE 3rd gen sim); `xcodebuild -only-testing:MomoWatchUITests test` on the Watch sim; 2 mutation bites with sha256 pre/mutated/post hashes; `git diff --stat` over the four frozen surfaces.

### Test Results

swift test **1128/1128 PASSED** (110 suites; baseline 1102/108 + 26 new). Coverage **90.81%** (floor 80%, baseline 90.79%). Both xcodebuilds **BUILD SUCCEEDED**, zero touched-file warnings (only the pre-existing `/opt/extra/lib` ld + appintents metadata notices). MomoWatchUITests **7/7 PASSED**. Frozen surfaces diff-EMPTY (MomoCore / MomoCharacter / Apps/Momo / pbxproj). Both bites exactly-one-test-red, restored byte-identical.

### Known Issues

- **D2 needs adjudication:** R2's quoted copy "All done — see you soon" is NOT the shipped value — `momo.line.moment.02` = "Momo had a lovely day." (shared with the iPhone M3 card). This task changed nothing in the catalog; see Implementation Notes D2. No code action pending on this task.
- Hour-boundary latency is accepted + disclosed (no timers, per contract); the stale UI test tolerates a ±1-hour boundary crossing for that exact reason (D8).
- Pre-existing machine-level build warnings (`/opt/extra/lib` ld path, appintents metadata) are unchanged from TASK-042's disclosure — not this task's to fix.

### Decisions Made

D1 binding seam file (scan-mandated, zero logic). D2 render through the existing shared key (no catalog edit, no key fork — escalated to orchestrator/owner). D3 w1 fixture inputs corrected to match its own display. D4 estimator keeps the FROZEN line per ADR-015 D2 (hour-window false-negative rationale). D5 recompute-before-persist ordering in the receive leg. D6 scenePhaseChanged reshape (activation leg added, background persist preserved). D7 banned-settings tokens carry both paren and trailing-closure spellings. D8 boundary-tolerant stale-test assertion.

### Reviewer Status

APPROVED_WITH_MINOR_NOTES (REVIEW-TASK-043, 2026-09-12, fresh Jupiter reviewer per §10/§33) — 0 Critical / 1 Major (F-1, explicitly NO code change on this task: the D2 ruling is (B)-refined — W1's all-done string is normatively "All done — see you soon"; the shipped shared-key render is a pre-existing TASK-041-era conflation → owner copy ruling + Watch-side key + docs errata recorded as a standing owner item) / 4 Minor guard-tolerance notes (F-2 bare-spelling census gap + F-3 unenforced D20, both probe-demonstrated → routed as TASK-044 ride-alongs; F-4/F-5 analytical) / 2 Notes (F-6 fallback tradeoff; F-7 the CONTRACT's own Context mis-citation — orchestrator-owned, the implementer correctly disclosed rather than shipping against the corpus). Reviewer ran 3 own probes (none reusing the implementer's bites), all exactly-red and sha256-restored byte-identical, and re-ran every §19 gate with matching numbers. Full record: `.claude/tasks/reviews/REVIEW-TASK-043.md`.

### Commit

NONE — implementation agent does not commit (§9). Working tree on `feature/EPIC-008-watch-sync` holds exactly: 3 modified files + 4 new source/test files + this task file.

### Push

NONE (no commit).

### Recommended Next Step

Orchestration: spawn REVIEW-TASK-043 (fresh Jupiter reviewer) per Review Requirements; after APPROVED/APPROVED_WITH_MINOR_NOTES + D2 adjudication, one atomic commit `feat(watch): TASK-043 watch cascade — live shared derivation + UX-13 propagation`, push (§13), move this file to completed, update status.md; then TASK-044 (final EPIC-008 task).

HANDOFF-COMPLETE TASK-043
