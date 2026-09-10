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
READY (2026-09-10) — contract authored; fresh implementation agent dispatching.

## Implementation Notes
(implementation agent fills: files created, decisions, deviations, test results with counts, build/launch evidence, handoff per CLAUDE.md §28)

## Reviewer Findings
(orchestrator fills post-review)

## Completion Evidence
(orchestrator fills at close: commit hash, push status, §19 run, coverage)
