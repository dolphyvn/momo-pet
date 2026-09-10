# REVIEW-TASK-031 — App model facade: evaluate/apply loop + persistence wiring + boundary scheduling

- **Task:** `.claude/tasks/active/TASK-031-app-model-facade.md` (EPIC-007 1/9)
- **Date:** 2026-09-10
- **Reviewer:** fresh, independent adversarial review agent (Jupiter). No prior context on this task; the task file's Implementation Notes were treated as CLAIMS and verified or disproven against the specs and the engine's own interfaces — never trusted. Per CLAUDE.md §33, the method was re-derive the obligations from the normative docs BEFORE opening any implementation file, then attempt to disprove.
- **Scope of review:** 8 new files + `Apps/Momo/MomoApp.swift` + `Momo.xcodeproj/project.pbxproj` + the task file (tree left DIRTY; nothing committed by this review).

---

## Phase 1 — Obligations re-derived from the specs (before comparing)

From 05 §4.1 (facade), §4.2 (tick model + trigger table), §2.1 (charters), §2.3 (D-R2/D-R5/D-R6), §4.10 (clock & randomness), §5.2–5.3 (store design / corruption stance), §12 (budgets), 04 §5.1 (choreography epoch prose), 06 TASK-031 row:

1. **Fixed-order effect plan (05 §4.1).** Per engine application: apply `newState` (step 0) → persist IFF `changed` (write-through via `SnapshotStore`, the actor) → deliver `response` if non-nil → deliver `moments` if non-empty → Watch push IFF `changed`, **RESERVED SEAM ONLY** (documented no-op; NO WatchConnectivity / WCSession / `WatchSnapshotBuilder` calls anywhere — EPIC-008 owns the transport). `changed == false` ⇒ no write, no push, but response/moments still deliver. Delivery exactly-once per application, in plan order.
2. **All five §4.2 triggers routed:** foreground/`scenePhase → active`; interaction; character report; scheduled boundary (in-session: 22:00 onset, 07:00 wake, local midnight, nap-end); significant time change. Fold-to-now precedes interaction/report **through the engine's own interface** — the `reduce` header (Sources/MomoCore/Reduce.swift) is the authority: `.interaction` folds internally to the intent's own timestamp; `.characterReport` folds to the injected clock's `now()`. The facade's obligation is correct submission; the observable (facade composition == manual evaluate→interact composition) must be pinned.
3. **Exactly ONE next boundary, scheduled from the folded state after every evaluation; strictly after `now` (no replay); re-schedule, never replay; backgrounded ⇒ inert, next foreground catches up.** Boundary constants sourced from `FoldRules` ONLY (`nightOnsetHour` 22, `morningWakeHour` 7; midnight = next local day start by definition) — no restated 22:00/07:00 literals in production arithmetic.
4. **Launch path (05 §5.2–5.3):** ONE synchronous main-thread store read at launch (the sanctioned launch I/O — OBS-1 review-attention item); fresh/absent ⇒ `requiresOnboarding` input surfaced (no onboarding UI this task); loaded ⇒ the launch IS the first open (foreground fold). Corruption recovery invisible (§5.3 — no dialog, no surface; falls through to the injected fresh default).
5. **Clock + seed discipline (05 §4.10):** production `SystemEngineClock`; every engine time read through the injected clock; the facade owns no seed arithmetic beyond the documented app-side convention. The `reduce` header fixes that convention: the app layer seeds a fresh `SeededGenerator` per application from `DaySeed.make(petID:localDayKey:epoch:salt: .choreography)`. 04 §5.1's prose gives `choreographyEpoch` no numeric value ("changes only when the idle-variant catalog changes"); the house precedent for a starting epoch is 1 (`CopyRules.copyEpoch = 1`, `QuestGeneration.currentEpoch = 1`), and `0` is the documented placeholder marker in this codebase — so an epoch home of **1** is the only sourced reading.
6. **D-R5 by construction:** the engine is invoked only through the facade; app-target engine imports confined to the facade file. **D-R2:** no SwiftUI in package targets. **D-R6/freeze:** zero edits to MomoCore/MomoCharacter/Package.swift.
7. **Executor mechanical duties:** construct store+clock; observe `scenePhase` + `significantTimeChangeNotification`; schedule the boundary via the current-idiomatic mechanism (the §4.2 VERIFY-AT-BUILD — choice recorded); execute plans; `@MainActor` explicit; Swift 6 clean; zero new warnings; files ≤ 800 lines; no third-party deps.
8. **Scope control:** placeholder shell persists; no onboarding UI, no Home composition, no gesture surface, no new catalog keys.
9. **Tests:** fixed-order plan; persist-iff-changed incl. `changed == false` deliveries; exactly-once; reserved seam inert; trigger routing + composition equality; boundary table incl. asleep/nap/midnight edges + DST + reschedule-never-replay + strictly-after; launch fresh/loaded/corruption; determinism with teeth; delta accounted; frozen modules untouched.

## Phase 2/3 — What I checked and what I saw

### Engine-interface verification (Phase 2 preconditions)
- `reduce(_ state:_ event:clock:calendar:rng:)` — Sources/MomoCore/Reduce.swift: the header documents the app-side choreography-seed lineage (`DaySeed.make(…, salt: .choreography)`), the per-event fold targets, the forward-only fold mark, and `changed = newState != state`. The implementation's seed call and trigger routing match this header claim-for-claim.
- `FoldRules.nightOnsetHour = 22` / `morningWakeHour = 7` exist and are the ONLY hour sources in `NextBoundary.swift` (grep for restated literals in production arithmetic: none).
- `TimeFold` recorded interpretation 3 ("nap spans the fold; completes at fold end; no nap-start instant exists in the domain model") — this is the engine's own documented basis for the `.napEnd` reading (Finding NOTE-2).
- `SnapshotStore.load(fallback:)` is `public nonisolated func` returning `EngineState`, never throwing (SnapshotStore.swift:265) — the synchronous launch read is exactly the designed use. `StoreRules.generationFileNamesInReadOrder`, `currentStateFileName`, `previousStateFileName`, `defaultDirectory() throws` all exist as consumed. `EngineState` field list matches the executor's fresh default field-for-field; `SettingsState(onboardingComplete:hapticsEnabled:)`, `Thresholds.Bond.minimum = 0` verified.

### §19 gate (run personally)
- `swift test` run 1: **exit 0 — 850 tests / 85 suites passed**. Run 2: **exit 0 — 850/85**. Warning census on the full log: **0**. (Third green run inside the coverage pass below.)
- Delta vs pinned baseline 825/82 @ `13a75bf`: exactly **+25 tests / +3 suites** = the new suites' `@Test` counts (9 + 12 + 4, grepped). `git diff --stat -- Tests/` EMPTY — no existing test file touched.
- `xcodebuild -project Momo.xcodeproj -scheme Momo -destination 'platform=iOS Simulator,name=iPhone SE (3rd generation),OS=26.5' build` — re-run MYSELF: **exit 0, BUILD SUCCEEDED**, zero source warnings beyond the two disclosed environment notices (machine-level `ld: search path '/opt/extra/lib'`; appintentsmetadataprocessor tool notice). The implementer's `/tmp/task031_xcodebuild.log` is genuine.
- Launch evidence re-produced LIVE on the booted simulator `1F25E487…` after a fresh install: pid 92689 logged `[com.momo.app:app-model] app model live — fresh store, onboarding input surfaced`; relaunch pid 98876 logged `app model live — loaded store, launch is the first open`. Both launch-origin branches work end-to-end, and the second launch proves the first launch's foreground fold persisted a readable store (save→load round trip). The implementer's claim is real.
- Coverage (AC-6 floor, which the implementer did NOT measure — I measured): `swift test --enable-code-coverage` + llvm-cov, MomoKit rows: 825 lines / 77 missed ≈ **90.7%** — the ≥ 80% floor HOLDS. New files: AppModelLaunch 100%, NextBoundary 100%, AppModelPlan 91.67% regions / 100% lines.

### Freeze, purity, D-R5, reserved seam
- `git diff --stat -- Sources/MomoCore Sources/MomoCharacter Package.swift` **EMPTY**; no untracked files under either frozen module; no third-party dependency added (Package.swift untouched).
- D-R2: the three new MomoKit files import Foundation + MomoCore only (the single "SwiftUI" hit is a doc-comment).
- D-R5: `grep -rl "import MomoCore" Apps/Momo/` → **MomoAppModel.swift only**; `reduce` is called only inside the plan core; `MomoApp.swift` wires `@State` app model + `.environment` + `scenePhase` onChange; placeholder views untouched (scope intact; no new xcstrings keys).
- Reserved Watch seam: `grep -rn "WatchConnectivity|WCSession|WatchSnapshotBuilder"` over all new/modified code → **comments only** (three doc-comments naming the seam as reserved). The `.pushWatchSnapshot` step is a documented no-op in the executor loop. No transport code exists.
- Boundary constants: production hour sources are `FoldRules.nightOnsetHour` / `morningWakeHour` / hour-0-midnight-by-definition; the boundary walk mirrors `TimeFold`'s `enumerateDates(.nextTime)` shape (banned `nextDate(after:)` avoided, consistent with the engine's scanner constraint), with a cross-pin test against `TimeFold.segments`.

### Mutation bites (sha256-proven restore)
Pristine hashes recorded first: `AppModelPlan.swift 339217035ddf…`, `NextBoundary.swift e9ab085b3a06…`.
- **Bite A — persist IFF changed removed** (`steps.append(.persist)` unconditional): exactly `duplicateIntentIsTotalNoOp` fails (9-test suite: 1 issue). The IFF rule has teeth.
- **Bite B — asleep wake-preference removed** (asleep branch → earliest-of-all): exactly the three asleep rows fail (`asleepSchedulesMorningWakePastMidnight`, `asleepMorningEdgeSchedulesTomorrowWake`, fall-back DST row); awake rows stay green. The recorded asleep interpretation is pinned, not decorative.
- **Bite C — seed salt `.choreography` → `.copy`**: **all 25 tests stay GREEN**. Executable proof of MINOR-1 below: the composition-equality tests are seed-for-seed only relative to the production seed function itself; the seed SHAPE (salt, epoch value, dayKey sourcing) is test-unpinned.
- Both files restored byte-identically (hashes re-verified; tree left exactly as found).

### Interleaving analysis of the executor (probe a)
- State chain: `plan` and `state = plan.appliedState` are synchronous on the @MainActor before the first `await`, so a second apply always folds from the previous apply's outcome — no lost update.
- Save order: the store actor receives saves in plan-computation order (each apply's first suspension IS its save submission), so persistence order is total and matches the state chain.
- Per-application delivery: the plan loop delivers each step exactly once, in order; no double-delivery path exists.
- The boundary task vs a user trigger: cancel-on-re-derivation + `!Task.isCancelled` + the `isForeground` guard + the boundary instant carried in the event make replay structurally impossible and a backgrounded boundary inert.
- Residual (MINOR-2): with two applies racing, the LAST-COMPLETED apply's `scheduleBoundary` wins, so the live schedule can derive from the earlier apply's plan (stale by one event). Self-correcting at the next fire (folds are catch-up; derivation strictly-after its own fold instant); no state loss, no replay, no missed boundary — worst case one redundant evaluation.

---

## Findings

**MINOR-1 — The choreography-seed SHAPE and `choreographyEpoch`'s value are test-unpinned (anti-echo gap).**
Evidence: all five seed uses in tests go through `AppModelPlanCore.choreographySeed` (AppModelPlanTests.swift:186,237,287,296; NextBoundaryTests.swift:186); no test restates `DaySeed.make(…, epoch: 1, salt: .choreography)` independently, and no test pins `choreographyEpoch == 1`. Bite C (salt swap) leaves 25/25 green — a wrong salt, wrong epoch, or wrong dayKey source would ship green. The shipped convention itself is CORRECT (verified against the `reduce` header; epoch 1 is the only sourced reading per 04 §5.1 + `CopyRules.copyEpoch`/`QuestGeneration.currentEpoch` precedent, with 0 = placeholder marker). Suggested disposition: one test-side pin (`choreographySeed(...) == DaySeed.make(petID:, localDayKey: "2026-03-03", epoch: 1, salt: .choreography)` + a `choreographyEpoch == 1` raw pin) riding the TASK-031 commit or a named follow-up. House precedent: TASK-013/020 anti-echo discipline treats exactly this shape as a test-completeness gap, not a behavioral defect.

**MINOR-2 — Executor: the live boundary schedule can derive from a pre-interleave plan under concurrent applies.**
Evidence: MomoAppModel.swift:255–304 — `scheduleBoundary(from:)` runs at :284 AFTER the `await store.save` suspension at :271; with apply A (changed, slow save) and apply B (no persist) racing, B schedules from the newest state, then A resumes and its stale-plan schedule wins. Consequences bounded and self-correcting: the next fire folds from the CURRENT state and re-derives; no replay (strictly-after), no missed state, no ordering violation of §4.1's per-application fixed order. Suggested disposition (implementer's/orchestrator's call): move `scheduleBoundary(from:)` to immediately after `state = plan.appliedState` (the boundary depends only on `appliedState`, and scheduling is not a §4.1 effect step), or serialize applies, or accept and document. Not blocking.

**NOTE-1 — `.characterReport` foldInstant makes a second `clock.now()` read** (AppModelPlan.swift:216) distinct from the engine's internal one: the seed dayKey and the scheduling `now` can differ from the engine's actual fold target by microseconds (a nanosecond-scale midnight razor edge changes only which valid day-seed is used). Harmless; ManualEngineClock-based tests are exactly deterministic. No action required.

**NOTE-2 — The two recorded phase→boundary interpretations are SOURCED and pinned, confirmed.** `.napEnd` = earliest calendar boundary relabeled is the only implementable reading given TimeFold interpretation 3 + the documented absence of any nap-start instant/duration (inventing a duration would be un-sourced arithmetic, as the header says). Asleep ⇒ next 07:00 even past midnight is coherent with the engine's landing-day rollover (the wake fold performs the same decomposition; the midnight reset serves the interactive session). Both are disclosed in the task file (Decision 2), pinned by tests (including the nap chain 15:00 → napEnd 22:00 → asleep → 07:00), and mutation-bite-proven (Bite B). No unsourced semantics found.

**NOTE-3 — Coverage was not measured by the implementer** (AC-6 says the floor "holds"). Reviewer measurement: MomoKit ≈ 90.7% lines — floor holds with margin. Suggest recording this number in the task file's completion evidence at close.

**NOTE-4 — `interact(_:)`/`submit(_:)` and the delivery closures have no callers this task** — correct scope posture (they are the facade's public surface; gesture/flow/character wiring is TASK-032/033's). Not dead code.

**NOTE-5 — Evidence nit:** `/tmp/task031_run1.log` and `run2.log` have identical byte SIZES but are genuinely distinct runs (timestamps 10 s apart, different build times) — the "two runs" claim is real.

### Explicitly probed and CLEAN
Five triggers all routed (foreground `:217`, interaction `:230`, report `:245`, scheduled boundary `:299`, significant time change `:194/:323`); fold-to-now via correct submission with seed-for-seed composition pins incl. the full session chain; one-boundary strictly-after semantics (`enumerateDates(startingAfter:)`, `.nextTime` DST rows correct: spring-forward wake 11:00Z = wall 07:00 EDT, fall-back 12:00Z = wall 07:00 EST); OBS-1 launch read genuinely the only synchronous main-thread I/O (everything else awaits the store actor; `defaultDirectory()` catch path is bounded, DEBUG-loud, release-functional, honest); §5.3 corruption fall-through pinned end-to-end (corrupt-all-generations → probe still "loaded" → fallback served invisibly); `@unchecked Sendable` box is the minimal honest crossing (token used only for `removeObserver`; queue `.main` makes `assumeIsolated` sound; `isolated deinit` legal at tools 6.2); determinism suite has a real tooth (petID divergence); no `print(`; files ≤ 800 lines (max 371); pbxproj registered at all 4 house sites; delta +25/+3 exact; placeholder shell untouched.

---

## VERDICT: APPROVED_WITH_MINOR_NOTES

Approval rests on: spec re-derived before comparing; two independent full green runs (850/85, 0 warnings) reproduced by this reviewer; independent BUILD SUCCEEDED; both launch-origin log lines reproduced live on-device; frozen modules byte-clean; D-R5/reserved-seam/boundary-sourcing greps clean; three mutation bites — two with exact predicted failures proving the IFF and asleep-interpretation pins, one proving MINOR-1's gap. MINOR-1 (add the seed-shape/epoch pin, test-side) and MINOR-2 (schedule-before-await reorder, or accept-and-document) are at the orchestrator's disposition; neither blocks commit.

---

## Disposition (orchestrator, 2026-09-10)

Both MINOR findings were verified personally against the code before disposition (MINOR-1: all five test references construct the seed via `AppModelPlanCore.choreographySeed` itself — tautological, confirmed; MINOR-2: `scheduleBoundary` sat after the `await store.save` suspension point — confirmed), then APPLIED:

- **MINOR-1 → APPLIED (test-side).** New pin test `choreographySeedShapePinnedToTheEngine` (`Tests/MomoKitTests/AppModelPlanTests.swift`): derives the expected seed directly from `DaySeed.make(petID:localDayKey:epoch: 1, salt: .choreography)` — LITERAL epoch and spec salt, never the wrapper — over `DayKey.make` of the injected instant, plus `#expect(AppModelPlanCore.choreographyEpoch == 1)`. A salt/epoch/dayKey-source regression now trips the suite.
- **MINOR-2 → APPLIED (one-line reorder).** `scheduleBoundary(from: plan)` moved from after the effect loop's awaits to immediately after step-0 apply (`state = plan.appliedState`), with a comment recording the race rationale. Under two racing applies the surviving schedule is now always the one derived by the LATEST apply to start (each plan reads the freshest applied state at its own start); the one-event-stale-resume window is closed.
- **NOTE-3 → RECORDED.** MomoKit coverage re-measured by the orchestrator post-fix: **91.42 % lines (341/373)** — the ≥ 80 % floor holds (llvm-cov over `default.profdata`).
- **NOTE-1** accepted (microsecond clock-read skew, harmless). **NOTE-2** confirmed sound. **NOTE-4** correct scope posture. **NOTE-5** noted.

**§19 re-run post-fix (orchestrator-run):** `swift test` green ×3 — 851 tests / 85 suites (1.855 s coverage run / 1.630 s / 1.674 s coverage run); delta 850 → 851 is exactly the one added pin test; zero source warnings (the `ld: warning: search path '/opt/extra/lib' not found` line is the machine-environment linker notice the implementer disclosed — it surfaces only when a link phase runs after cache invalidation, never from source).
