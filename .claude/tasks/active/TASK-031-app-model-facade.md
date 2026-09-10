# TASK-031 — App model facade: evaluate/apply loop + persistence wiring + boundary scheduling

## Parent Epic
EPIC-007 — iPhone Home Experience (`.claude/tasks/epics/EPIC-007-iphone-home.md`), first task — the lanes (engine/store from EPIC-004/005, character from EPIC-006) converge here.

## Objective
Implement 05 §4.1–4.2's app model: the ONE engine entry point that wraps the pure `reduce` with the fixed-order side effects (apply `newState` → persist if `changed` → deliver `response`/`moments` → Watch push [reserved seam]), drives every §4.2 fold trigger, schedules exactly one next-boundary evaluation in-session, owns the launch read path — and is structured so its decision core is headlessly testable under the 05 §10.1 five-target architecture. Views never invoke the engine directly (D-R5).

## Context
- Read first: `CLAUDE.md`, `.claude/tasks/status.md`, this file, then 05 §2.1 (targets — "engine host + evaluation scheduling" is the `Momo` app target's charter; MomoKit = persistence + sync), §2.3 (D-R2/D-R5/D-R6), §4.1–4.2 (the facade + tick-model spec — NORMATIVE), §4.10 (clock & randomness), §4.11 (read-models), §5.2–5.3 (store design + corruption stance), §12 (launch budget — structural property here; on-device numbers are TASK-045).
- Landed ground to consume (do NOT re-implement): `reduce` + `TimeFold` + `FoldRules` + `InteractionSemantics` + read-models (`makeDisplayState`/`makeCharacterDisplayState`) + seed derivation live in `Sources/MomoCore/` (TASK-014/015/016/019/020); `SnapshotStore` (actor, `nonisolated` loads, 3-generation recovery), `StoreRules`, `SyncStateStore`, `WatchSnapshotBuilder` live in `Sources/MomoKit/` (TASK-021/022/023). The character view API (`MomoRigView`, `MomoReactionDirector.plan(events:at:)`, RM policy) lives in `Sources/MomoCharacter/` (TASK-026…029).
- **Testability constraint that shapes the design:** the 05 §10.1 architecture has NO app-unit-test target — package suites run via `swift test` on macOS; app-target code is covered only by UI tests + review. Therefore the facade MUST be split: (a) a PURE, value-typed plan core (trigger decision table, fold-then-event composition, ordered effect plan, next-boundary derivation) in a PACKAGE target, and (b) a THIN app-target executor (`Apps/Momo/`) that owns the real clock/store/`Task` scheduling/`scenePhase`+time-change observation and executes the plan. Keep the executor genuinely thin — every decision it makes must be either delegated to the plan core or trivially mechanical.
- Placement per charter: pure derivations over engine types → `MomoCore` is the sanctioned home for boundary math ONLY if it is a NEW pure file (§2.1 lists "seed derivation, day-ledger logic" there); the orchestration/plan layer + persistence wiring → `MomoKit` (depends on MomoCore; NO SwiftUI — D-R2). The SwiftUI executor → `Apps/Momo/`.
- Baseline pinned at dispatch: **825/82 @ `13a75bf`** (the EPIC-006 merge; suite verified green on this exact tree).

## Requirements
1. **Fixed-order effect plan (05 §4.1):** each engine application produces an ordered, value-typed plan: apply `newState` → persist IFF `changed` (write-through via `SnapshotStore`; `changed == false` ⇒ no write, no Watch push) → deliver `response` (if non-nil) → deliver `moments` (if non-empty) → Watch push IFF `changed` (**RESERVED SEAM ONLY** — a documented no-op/stub protocol; NO WatchConnectivity, NO WC code, NO WatchSnapshotBuilder calls — EPIC-008 lands the transport). Delivery is exactly-once per application, in plan order.
2. **All five §4.2 triggers route through the facade:** foreground/`scenePhase → active`; any interaction; character report arrival; scheduled boundary evaluation (in-session: 22:00 onset, 07:00 wake, local midnight, nap-end); significant time-change notifications. Fold-to-now precedes interaction/report application per the §4.2 table — realize this through the engine's own documented interface (read how `reduce`/`TimeFold` compose in the engine's tests; if `.interaction` already folds internally, the facade's obligation is correct submission — pin the observable: the facade's composed result equals the manual evaluate-then-interact composition).
3. **Exactly ONE scheduled next-boundary evaluation**, computed from the folded state after every evaluation; schedulers RE-SCHEDULE, never replay (04 §5.3 discipline); backgrounded before the boundary ⇒ the call simply does not matter (no replay; next foreground catches up). Boundary constants come from `FoldRules`/the engine's constants home — NEVER restate 22:00/07:00/midnight literals (single-sourcing house rule).
4. **Launch path (05 §5.2–5.3):** read the store once at launch (`SnapshotStore`'s nonisolated load — corruption recovery already implemented); fresh/absent store ⇒ the "not onboarded" flow input (onboarding itself is TASK-032 — expose the flag, don't build the flow); loaded state ⇒ the launch IS the first open (foreground fold). The launch read is the ONLY synchronous I/O on the main thread; every other I/O is off-main via the store actor (05 §5.2; the OBS-1 property routed from REVIEW-TASK-024 — record it as an explicit review-attention item).
5. **Clock + seed discipline (05 §4.10):** production uses `SystemEngineClock`; every engine time read flows through the injected clock. The facade owns NO seed arithmetic — the engine derives day-stable seeds internally per §4.10's closing bullet; verify the exact production-call convention from the engine's own interface/tests (how `reduce`'s rng parameter is sourced in the established call shape) and REUSE it; record the convention in the facade header.
6. **D-R5 by construction:** the only engine entry is the facade; views/placeholder tabs keep rendering placeholders this task (Home composition is TASK-033) but must already bind through the app model where they consume state. Add the discipline to the extent greppable/reviewable now (e.g., engine imports confined to the facade file in `Apps/Momo`).
7. **Executor mechanical duties (app target):** construct store + clock; observe `scenePhase` + the significant time-change notifications; schedule the boundary via the current-idiomatic mechanism (VERIFY-AT-BUILD noted in 05 §4.2 — record what you chose and why in the task file); execute plans (persist via the actor; deliver response/moments to a UI-facing seam — protocol/closure the placeholder shell can already host); keep `@MainActor` isolation explicit and audit why the launch read is the one sanctioned synchronous call.
8. **Swift 6 strict concurrency clean; zero new warnings; zero new third-party dependencies (D-R4); files ≤ 800 lines (many small files); immutable value patterns.**

## Files / Areas Likely Affected
- NEW `Sources/MomoKit/` — the app-model plan core (suggest `AppModelPlan.swift` + boundary/trigger decision types; names within house convention).
- POSSIBLY NEW `Sources/MomoCore/` — a pure next-boundary derivation file ONLY if needed over existing public types (no edits to existing engine files; if you believe an engine edit is unavoidable, STOP that piece, disclose it in Implementation Notes, and leave the engine untouched).
- NEW `Apps/Momo/` — the thin executor (e.g., `MomoAppModel.swift`), `MomoApp.swift` wiring updated.
- NEW tests under `Tests/MomoKitTests/` (plan core) and possibly `Tests/MomoCoreTests/` (boundary math) — reuse the established injected-clock patterns (`ManualEngineClock`; a stepped clock exists in `Tests/MomoCharacterTests/Support/SteppedClock.swift` as a shape reference).
- `Apps/Shared/MomoCopy.xcstrings` — expected NO new keys this task (placeholder shell persists); if any string is unavoidable it goes through `CopyKey`/`MomoCopy` per TASK-011, never a literal.
- UNTOUCHED: all existing `Sources/MomoCore` engine files, `Sources/MomoCharacter/`, `Sources/MomoKit/` store/sync behavior (consume as-is; an integration defect found in the store = STOP + record, never a silent fix).

## Dependencies
- Requires: TASK-020 (engine, merged), TASK-021 (SnapshotStore, merged); consumes EPIC-006's view API only at the seam level (no character work this task).
- Blocks: every other EPIC-007 task (they all hang off the facade).

## Constraints
- Frozen modules: MomoCore engine semantics, MomoCharacter, SnapshotStore/SyncStateStore behavior — consume-only.
- NO WatchConnectivity / WC transport code (EPIC-008); NO widget/HealthKit/notification code (Phase 2 / never).
- No engine re-entry from views (D-R5); no SwiftUI in package targets (D-R2); no third-party packages (D-R4).
- Scope control (§22): onboarding UI, Home composition, gestures, flows, quests UI, settings UI are LATER tasks — this task ships the facade + executor + placeholder-shell binding only.
- MVP/philosophy guardrails untouched (no new product surface at all in this task).

## Acceptance Criteria
1. A fixed-order, value-typed plan is produced per engine application; persist IFF `changed`; response/moments delivered exactly once in order; the Watch-push slot exists as a documented reserved no-op.
2. All five §4.2 triggers route through the facade; fold-to-now precedes interaction/report (pinned by composition equality against the manual evaluate+interact path).
3. After every evaluation exactly ONE next-boundary evaluation is scheduled at the correct instant for states before/at/after each of 22:00 onset, 07:00 wake, local midnight, and a live nap; re-scheduling (never replay) is pinned; a backgrounded boundary is provably inert (next foreground catches up).
4. Launch: fresh store ⇒ "not onboarded" input surfaced; loaded store ⇒ immediate foreground-fold evaluation; the main thread performs ONLY the launch's initial read (structural + review-recorded, OBS-1).
5. The engine is invocable ONLY through the facade in app-target code (D-R5, review-gated).
6. `swift test` green with the baseline delta accounted (new suites in MomoKitTests + possibly MomoCoreTests); MomoKit ≥ 80 % coverage floor holds; zero new warnings; zero scan regressions (import whitelist, banned vocabulary, token purity, engine purity, MomoKit discipline scans).
7. `xcodebuild build` + `simctl` launch of the Momo scheme on the pinned simulator succeeds with the executor live behind the placeholder shell (TASK-009 record precedent for the procedure).

## Required Tests
- **Facade plan core (MomoKitTests, injected clock):** fixed-order plan emission; persist-iff-changed (including `changed == false` events still delivering non-nil response/moments if the engine produces them); exactly-once delivery; reserved Watch seam inert.
- **Trigger table:** foreground fold; interaction = fold-to-now then interact (composition equality); report = fold-to-now then report; time-change notification path.
- **Boundary scheduling:** next-boundary derivation pinned against FoldRules-derived instants for: waking before 22:00; during evening (next = 22:00); after 22:00 (next = 07:00); post-wake pre-midnight (next = midnight); live nap (next = nap-end); already-asleep morning edge (07:00); re-schedule-on-evaluate; no-replay-under-background; DST-edge behavior via injected calendar (reuse the engine tests' DST fixtures as shape reference).
- **Launch path:** fresh-default detection; loaded-state first-fold; corruption recovery inherited (a torn store lands on `.prev`/fresh without surface).
- **Determinism:** same (state, trigger, clock, calendar) ⇒ equal plans (meta-determinism shape over a bounded seeded sequence).
- **Build/launch verification:** `xcodebuild build` (Momo scheme) + simulator launch + screenshot-or-log evidence recorded in the task file (§19 evidence).

## Review Requirements
Standard CLAUDE.md §10/§33: a fresh adversarial reviewer (Jupiter; never primed) re-derives the facade obligations from 05 §4.1–4.2 + §2.1/§2.3 + §5.2 BEFORE comparing them to the implementation; body-reads the plan core and executor; probes for D-R5 violations, main-thread I/O beyond launch, replay-vs-reschedule violations, seed/clock bypass, scope creep into later tasks' surfaces. Review recorded at `.claude/tasks/reviews/REVIEW-TASK-031.md`.

## Git Requirements
Atomic commit on `feature/EPIC-007-iphone-home` (orchestrator commits after review + §19 gate):
`feat(app): TASK-031 app model facade — evaluate/apply loop, persistence wiring, boundary scheduling`
Message includes the TASK-ID. Push follows the commit. The implementation agent does NOT commit — leave the tree DIRTY.

## Status
IN_REVIEW → findings addressed (2026-09-10): REVIEW-TASK-031 APPROVED_WITH_MINOR_NOTES; MINOR-1 + MINOR-2 applied; §19 green post-fix (851/85 ×3, MomoKit 91.42 %). Committing per §12.

## Implementation Notes

### Completed
- Pure plan core in MomoKit (SwiftUI-free, D-R2): `Sources/MomoKit/AppModelPlan.swift` (`AppModelPlan` + `Step` enum: `.persist` / `.deliverResponse` / `.deliverMoments` / `.pushWatchSnapshot` reserved; `AppModelTrigger` — all five §4.2 entries; `AppModelPlanCore.plan(state:trigger:clock:calendar:)` emitting the §4.1 fixed order with the IFF rules; `choreographyEpoch = 1` + `choreographySeed`), `Sources/MomoKit/NextBoundary.swift` (`NextBoundary` + `NextBoundaryRules.next(from:state:calendar:)`), `Sources/MomoKit/AppModelLaunch.swift` (the presence probe for §5.2 fresh-vs-loaded). No MomoCore file was needed — boundary math lives in MomoKit over `FoldRules` constants; zero new MomoCore files (git diff over Sources/MomoCore/ is EMPTY).
- Thin executor `Apps/Momo/MomoAppModel.swift` (@MainActor @Observable; ~371 lines) + `Apps/Momo/MomoApp.swift` wiring (`@State` app model, `.environment`, `scenePhase` onChange). Placeholder views untouched (placeholders persist; binding seam is the environment injection; Home composition is TASK-032/033).
- pbxproj registration: `MomoAppModel.swift` added at 4 sites following the house `8A…NN` ID pattern.
- Tests: `Tests/MomoKitTests/Support/AppModelFixture.swift` + `AppModelPlanTests.swift` (9 tests) + `NextBoundaryTests.swift` (12) + `AppModelLaunchTests.swift` (4).

### Files Changed
Modified: `Apps/Momo/MomoApp.swift`, `Momo.xcodeproj/project.pbxproj`. New: `Apps/Momo/MomoAppModel.swift`, `Sources/MomoKit/{AppModelPlan,NextBoundary,AppModelLaunch}.swift`, `Tests/MomoKitTests/{AppModelPlanTests,NextBoundaryTests,AppModelLaunchTests}.swift`, `Tests/MomoKitTests/Support/AppModelFixture.swift`. NOTHING under `Sources/MomoCore/` or `Sources/MomoCharacter/` (verified: `git diff` over both = empty; no new files there).

### Decisions Made
1. **Boundary-scheduling mechanism (the 05 §4.2 VERIFY-AT-BUILD)**: ONE cancellable Swift Concurrency `Task` per boundary, `Task.sleep(for:)` over the interval from the injected clock; the scheduled event carries the BOUNDARY instant (scheduler slack never shifts the fold target); `isForeground` guard + cancel in `backgrounded()` + iOS suspension make a backgrounded boundary inert by construction; cancel-on-re-derivation makes "re-schedule, never replay" structural. Documented in the executor type header.
2. **Phase→boundary interpretation** (recorded in `NextBoundary`'s header): napping ⇒ earliest calendar boundary RELABELED `.napEnd` (the domain has no nap-start instant and no nap duration — TimeFold interpretation 3 completes the nap at fold end; inventing a duration would be un-sourced arithmetic); asleep ⇒ next 07:00 even when midnight is first (the wake fold subsumes the rollover; the midnight reset serves the interactive session); otherwise earliest of {22:00, 07:00, midnight} with natural kind. All boundaries strictly AFTER `now` (`enumerateDates(startingAfter:)`, `.nextTime` for DST) = structural no-replay.
3. **Seed/clock convention** (per Requirement 5's verify-then-reuse): the engine's `reduce` takes an EXTERNAL rng; the app-side convention is a fresh `SeededGenerator` per application seeded via `DaySeed.make(petID:localDayKey:epoch:salt: .choreography)` over `DayKey.make(from: foldInstant, calendar:)`. `choreographyEpoch` had NO code home anywhere (verified by grep; 04 §5.1 names it only in prose) → `AppModelPlanCore.choreographyEpoch = 1` is now the single-sourced app-side home (matches `CopyRules.copyEpoch = 1` and `QuestGeneration.currentEpoch`'s epoch-1 start). The executor performs no seed arithmetic.
4. **Fold-to-now via correct submission**: `.interaction` submits the intent as-is (the engine folds internally to the intent's OWN timestamp); `.characterReport` folds to `clock.now()`; foreground/STC/scheduled-boundary submit `.evaluate(now: carriedInstant)`. Pinned seed-for-seed by composition-equality tests (facade foreground→interaction == manual reduce→reduce; facade interaction plan == manually built plan over the same seed).
5. **Fresh-vs-loaded**: `AppModelLaunch.hasGenerations` = existence probe over `StoreRules.generationFileNamesInReadOrder` (presence, never content — a corrupt store still reads "loaded", and `SnapshotStore.load(fallback:)` recovers invisibly per §5.3, landing `requiresOnboarding` on the fallback's own `onboardingComplete = false`). The load is the ONE sanctioned synchronous main-thread operation (executor init; **OBS-1 review-attention item** — header quotes 05 §5.2 and cites the REVIEW-TASK-024 routing).
6. **D-R5 by construction**: `MomoAppModel.swift` is the only app-target file importing MomoCore; `reduce` is called only inside the plan core; views get the app model via `.environment`.
7. **Swift 6 concurrency notes in the executor**: the NotificationCenter observer token is boxed in a private `@unchecked Sendable` struct (its only use is `removeObserver`), registered as the LAST init statement (escaping-closure capture of `self` is legal only after phase-1 init), removed via `isolated deinit`.

### Tests Run
1. `swift test` run 1 — `/tmp/task031_run1.log` — exit 0, **850 tests / 85 suites passed**, `grep -ci warning` = **0**.
2. `swift test` run 2 — `/tmp/task031_run2.log` — exit 0, **850 tests / 85 suites passed**, `grep -ci warning` = **0**.
3. Baseline delta: 825/82 @ `13a75bf` → 850/85 = exactly +25 tests / +3 suites (the three new suites: 9 + 12 + 4). No existing test touched or removed.
4. `xcodebuild -project Momo.xcodeproj -scheme Momo -destination 'platform=iOS Simulator,name=iPhone SE (3rd generation),OS=26.5' build` — exit 0, **BUILD SUCCEEDED** (`/tmp/task031_xcodebuild.log`; only warning line = appintentsmetadataprocessor's "No AppIntents.framework dependency" tool notice, pre-existing placeholder-shell behavior, not source).
5. Launch evidence (simulator UDID `1F25E487-A78E-464C-95AF-0BD1A9B3E1BE`): `simctl install` OK; launch 1 pid 38955 logged `[com.momo.app:app-model] app model live — fresh store, onboarding input surfaced`; terminate + relaunch pid 40150 logged `app model live — loaded store, launch is the first open` — BOTH launch branches proven live behind the placeholder shell, and the second launch proves the first launch's foreground fold persisted a readable store (end-to-end save→load round trip on-device).

### Known Issues
- None functional. Minor: xcodebuild log carries the environment-level `ld: warning: search path '/opt/extra/lib' not found` during some link phases (machine toolchain config, pre-dates this task, absent from `swift test` logs).

### Deviations & Disclosures
- Three test-side premise errors were caught by the engine's own semantics and fixed on the TEST side (implementation untouched): (a) an awake pet folded to exactly 22:00 stays awake — the onset must be CROSSED (TimeFold's segment loop); the reschedule pin now uses the honest chain 21:00→22:00-sharp→midnight; (b) a mid-round play with a FRESH id is NOT a state no-op (the fold's decay + the intent-id recording move the state; `changed` is true) — the test now pins `[persist, cheer, watch]` and the exact deltas; (c) an awake post-midnight session's earliest boundary is the coming 07:00 segment end (kind `.morningWake`), not the evening onset.
- `choreographyEpoch` had no existing code home; `AppModelPlanCore.choreographyEpoch = 1` introduces the single-sourced constant (disclosed above; reviewer should sanity-check the value against 04 §5.1's prose).
- `AppModelLaunchTests` reuses `TickingClock`/`StoreFixture` from the TASK-021 fixtures (same test target) rather than duplicating them.

### Handoff
- **Completed**: all Requirements 1–8; all Acceptance Criteria 1–7 (AC-3's "backgrounded boundary provably inert" is pinned at the plan-core level as strictly-after + the executor's cancel/guard mechanism — the full background/foreground lifecycle is on-device UI-test territory, TASK-045's lane); Required Tests all present.
- **Tests Run / Test Results**: see above — two full green runs with counts and timings, zero warnings, delta accounted.
- **Build & Launch Evidence**: BUILD SUCCEEDED; both launch-origin log lines captured on the pinned simulator.
- **Known Issues**: none functional (see above).
- **Decisions Made**: see the numbered list above.
- **Reviewer Status**: NOT YET REVIEWED — awaiting the fresh adversarial reviewer (review pointers: verify D-R5 confinement, OBS-1 single-synchronous-read claim, the boundary interpretation (Decision 2) against 05 §4.2's table, the seed convention (Decision 3) against the reduce header, and that the reserved Watch seam is inert).
- **Commit**: NOT COMMITTED — tree left DIRTY per instruction (orchestrator commits after review).
- **Push**: not applicable (no commit).
- **Recommended Next Step**: independent review (REVIEW-TASK-031), then orchestrator commit/push; next implementation task = TASK-032 (onboarding flow over `requiresOnboarding` + the delivery seam), per the EPIC-007 task order.

`git status --porcelain` at handoff:
```
 M Apps/Momo/MomoApp.swift
 M Momo.xcodeproj/project.pbxproj
?? Apps/Momo/MomoAppModel.swift
?? Sources/MomoKit/AppModelLaunch.swift
?? Sources/MomoKit/AppModelPlan.swift
?? Sources/MomoKit/NextBoundary.swift
?? Tests/MomoKitTests/AppModelLaunchTests.swift
?? Tests/MomoKitTests/AppModelPlanTests.swift
?? Tests/MomoKitTests/NextBoundaryTests.swift
?? Tests/MomoKitTests/Support/AppModelFixture.swift
```

## Reviewer Findings
**REVIEW-TASK-031 — APPROVED_WITH_MINOR_NOTES** (fresh adversarial reviewer; obligations re-derived from 05 §4.1–4.2/§2.1/§2.3/§4.10/§5.2–5.3 + 04 §5.1 BEFORE comparing; full file at `.claude/tasks/reviews/REVIEW-TASK-031.md`). Reviewer independently reproduced: swift test 850/85 ×2, BUILD SUCCEEDED, both launch-origin log lines live on-device, frozen modules byte-clean, D-R5/reserved-seam/boundary-sourcing greps clean, three mutation bites. Findings: **MINOR-1** choreography-seed shape/epoch test-unpinned (bite-proven); **MINOR-2** executor interleave — scheduleBoundary after the save await let a one-event-stale plan's schedule survive a racing apply; NOTE-1 report-path microsecond clock skew (harmless); NOTE-2 nap/asleep interpretations confirmed sound; NOTE-3 implementer never measured coverage; NOTE-4 uncalled seams = correct scope posture; NOTE-5 run logs genuinely distinct.

**Disposition (orchestrator, both findings verified personally then applied):** MINOR-1 → new pin test `choreographySeedShapePinnedToTheEngine` (expected seed derived from `DaySeed.make` with literal epoch 1 + `.choreography` salt, never the wrapper; epoch constant pinned to 1). MINOR-2 → `scheduleBoundary` moved before the effect awaits (immediately after step-0 apply). NOTE-3 → coverage measured: **MomoKit 91.42 % lines (341/373)**, floor holds. §19 re-run: 851/85 green ×3, zero source warnings. Full disposition appended to the review file.

## Completion Evidence
(orchestrator fills at close: commit hash, push status, §19 run, coverage)
