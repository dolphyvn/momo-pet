# TASK-040 — iPhone-side WC session: context push through the reserved seam + intent receive path + §6.6 reset-marker context leg + WC VERIFY-AT-BUILD record

## Parent Epic
EPIC-008 — Watch App & Sync (`.claude/tasks/epics/EPIC-008-watch-sync.md`). Branch: `feature/EPIC-008-watch-sync` (cut from merged `main` @ `b73e3eb`). This is the epic's first task.

## Objective
Activate the `.pushWatchSnapshot` seam reserved since TASK-031 and give the iPhone app its WatchConnectivity receive path: (R1) on every plan-issued push, the iPhone delivers a latest-wins `WatchSnapshot` application context; (R2) Watch-originated `IntentEvent`s drain in via the `transferUserInfo` receive half and apply EXACTLY ONCE through the accessor-driven gate; (R3) the §6.6 erase reset marker rides the context payload; (R4) the WC transport's VERIFY-AT-BUILD behaviors are resolved against the real SDK and recorded. The Watch side of the transport (its session, W1 rendering, pat capture) is NOT in this task — TASK-041/042 own it. Pure decision logic lands in MomoKit (headlessly testable); the WC wrapper lives in the `Momo` app target per ADR-013.

## Context
You are a fresh agent. Read, in this order, before writing any code:
1. `CLAUDE.md` (the project operating contract — esp. §22 scope control, §25 no fake completion, §26 no undocumented debt, §19 test-before-commit; you implement and test but do NOT commit).
2. `.claude/tasks/status.md` (current state) and `.claude/tasks/epics/EPIC-008-watch-sync.md` (this task's epic).
3. `docs/architecture/05-technical-architecture.md` §6.1–6.6 (the NORMATIVE sync spec: transports table, payload structs, the intent path, the §6.6 reset case table) and §5.6 (Watch-side stores — context for what your context push feeds).
4. `.claude/tasks/decisions/ADR-003-watch-sync-strategy.md` (context latest-wins ↓; `transferUserInfo` FIFO journal ↑; `sendMessage` reachable-only = optimizations only) and `.claude/tasks/decisions/ADR-013-standalone-watch-packaging.md` (WC wrapper code duplicated per app target, plain over DRY; NO target dependency between the apps — ever).
5. The merged code this task activates:
   - `Sources/MomoKit/AppModelPlan.swift` — the plan core. `Step.pushWatchSnapshot` is appended at line 252 when `outcome.changed`, and pre-planned `[.persist, .pushWatchSnapshot]` pairs exist at lines 368/433/491 (rename, haptics settings). The fixed side-effect order (persist → response → moments → push) is D-R5's discipline.
   - `Apps/Momo/MomoAppModel.swift` — the `@MainActor @Observable` thin executor. `case .pushWatchSnapshot:` at line 623 is the RESERVED NO-OP this task replaces. The executor owns the clock/store/calendar and ONE boundary task; its apply loop is the single dispatch path.
   - `Sources/MomoKit/SyncDTOs.swift` — `WatchSnapshot` (schemaVersion, snapshotSeq, display, questInputs, hapticsEnabled, lastAppliedIntentSeq, lastAppliedEpoch) and `IntentEvent` (schemaVersion, intent, watchSessionEpoch, watchSeq). BOTH decode with a STRICT `schemaVersion == StoreRules.<dto>SchemaVersion` gate (`decoded(from:)` → nil on mismatch — lines 117 and 290). Hand-written Codable, equality-gated.
   - `Sources/MomoKit/WatchSyncGate.swift` — `shouldApply`: UUID-first, then strict `>` per-epoch watermark (the §6.4 dual-guard matrix documented in its header).
   - `Sources/MomoKit/SyncState.swift` — `watermark(for:)` is THE single 0-init accessor; `recordingApplied` max-semantics; `shouldApply(_:seenIntentIDs:)` is the accessor-driven wrapper so call sites never resolve watermarks themselves.
   - `Sources/MomoKit/SyncStateStore.swift` — load/save with the replace-when-present/move-when-absent commit point.
   - `Sources/MomoKit/WatchSnapshotBuilder.swift` — `makeWatchSnapshot` (ambient-free; watermark pair passed IN, coherent from one epoch input).
   - `Sources/MomoKit/IntentJournal.swift` — the Watch-side journal (its append/drain is TASK-042; its epoch-matched prune consumes YOUR watermark — do not change its semantics).
   - `Apps/Momo/MomoAppModel+Settings.swift` — `eraseAllData()` at line 77: the TASK-038-sanctioned executor-level store lifecycle (delete-first, no-persist, launch-path-symmetric). Its routed AC-2 leg (05 §6.6): erase must reach the Watch as a reset marker in the NEXT context.
   - `Tests/MomoKitTests/` — the TASK-023 pure-logic suites (the gate/store/state semantics are already pinned; do not weaken them).
6. Standing review routings that bind this task: **O1+O5** (REVIEW-TASK-023) — ONE writer per journal/sync-state file on a single dispatch path, and intent application goes through the accessor-driven `SyncState.shouldApply`, NEVER through raw `WatchSyncGate` with watermarks resolved at call sites. **OBS-1** (REVIEW-TASK-024) — the app-layer leg: main thread never blocks on I/O beyond the sanctioned launch read (the store is an actor; keep file I/O off the receive hot path).

## Requirements

### R1 — Context push through the reserved seam
- Replace the `case .pushWatchSnapshot` no-op (`MomoAppModel.swift:623`) with the real arm: build the latest-wins snapshot via `WatchSnapshotBuilder.makeWatchSnapshot` from the CURRENT (just-persisted) engine state + the sync-state watermark pair + the haptics flag, and deliver it as the application context (`updateApplicationContext` = the §6.2 latest-wins down-transport).
- The plan core (`AppModelPlan.swift`) is UNCHANGED — push-IFF-changed is already appended; you implement the executor arm only. The seam remains the ONLY new engine exit (D-R5).
- The WC transport must sit behind a protocol seam (a WCSession-echoing protocol conforming in the app target; the executor depends on the protocol) so push and receive logic is headlessly testable without a live `WCSession`. Keep the live-session wrapper thin: activation, delegate plumbing, encode/decode only.
- Session lifecycle: activate on app launch; handle activation-state transitions without correctness dependence (context is latest-wins — if the counterpart is unreachable, the NEXT context supersedes; nothing is lost by design). Scene-phase transitions must not require compensating pushes (but see R2's watermark note).

### R2 — Intent receive path (Watch → iPhone)
- Implement the `transferUserInfo` receive half: the session delegate's userInfo delivery decodes `IntentEvent` (equality-gated `decoded(from:)` — undecodable events are skipped, never fatal).
- A PURE receive-plan core in MomoKit (new file; name it for what it is, e.g. `WatchReceivePlan`): input = the current engine state + `IntentEvent` + `SyncState` (+ the seen-intent belt source) and now/calendar as already injected elsewhere; output = an apply/ignore decision plus the post-apply sync-state update. Composition: gate through `SyncState.shouldApply(event, seenIntentIDs)` — the UUID half is the engine's own `processedIntents` belt (do NOT invent a second seen-set store; if you conclude one is genuinely required, stop and disclose before building it), the seq half is the per-epoch watermark with 0-init via `watermark(for:)`.
- If APPLY: route the wrapped `InteractionIntent` through the SAME facade interaction path the Home UI uses (`appModel.interact` routing — fold-to-now, engine semantics). Expired-dayKey intents apply current-state effects with day attribution dropped — the engine already owns this; do NOT duplicate any ledger/quest logic app-side. Then `recordingApplied` (max-semantics) and persist: engine state + sync state, in the plan's fixed side-effect order spirit, on the executor's single dispatch path (O1's one-writer rule).
- The NEXT snapshot must carry the updated `lastAppliedIntentSeq`/`lastAppliedEpoch` — i.e. subsequent `makeWatchSnapshot` inputs read the UPDATED sync state. This is exactly the TASK-034 F-1 blind-spot shape (a wiring leg green suites cannot see) — pin it structurally and behaviorally.
- An applied intent always produces a changed outcome in practice (INV-6: no mood-loss path; pat always applies), but if you find a no-outcome-change apply case, the watermark is still recorded and the next changed outcome carries it — analyze and DISCLOSE this edge rather than silently assuming it away.
- Duplicates / replays / redeliveries / stale-seq: full no-ops — no engine persist, no sync-state write, no push (INV-10). Pin exactly-once under the FIFO contract stream with duplicates/replays; pin at-most-once under seeded shuffles (the REVIEW-TASK-023 O2 adjudication — do NOT "strengthen" the shuffle pin; that pins a falsehood against §6.4).

### R3 — §6.6 erase reset-marker context leg
- Add an additive reset-marker element to the context payload: `WatchSnapshot` + `WatchSnapshotBuilder` + the erase executor sets it (`eraseAllData()`).
- **Schema adjudication (decide and DISCLOSE in Implementation Notes):** the DTOs decode with strict `schemaVersion ==` gates, so a version BUMP makes every pre-bump decoder DROP the whole payload. The recommended shape is an additive OPTIONAL field (decodeIfPresent; absent → `nil`) which evolves with NO schemaVersion bump — old payloads decode fine, and the new field rides the existing version. If you instead bump, the OBS-3 standing obligation FIRES: the NFR-7 parity fixture must then carry a populated `processedIntents` belt/handshake/greeting through the migration walk (see status.md Known Issues) — that expands this task's scope into persistence-side work; only choose it with the consequence explicitly accepted and executed. Both apps ship together, so backward compatibility is belt-and-braces — but the additive-optional shape is also simply smaller.
- The marker MUST survive the erase lifecycle: erase deletes stores, and onboarding re-runs before the first post-erase apply pushes a context — so the marker needs persistence that outlives the erased stores and at least one app relaunch (design it: a tiny dedicated record with its own sanctioned file is the expected shape; follow the `StoreRules` constants-home + authority-label + raw-literal-pin discipline). Pin survival with a test.
- Semantics per 05 §6.6: the marker rides EVERY context from erase until consumed. The Watch-side consumption (wipe snapshot + journal → settling-in line) is TASK-041/044 — here you emit + carry + test the payload only. Do not implement Watch consumption, do not clear the marker on the iPhone side beyond what your consumption design requires (record the design).

### R4 — WC VERIFY-AT-BUILD transport record (the 05 Appendix B item this task owns)
Resolve against the ACTUAL SDK you build against (headers/docs — cite what you inspected), and record determinations in Implementation Notes:
- (a) application-context delivery: when/how the counterpart receives it (launch delivery, background behavior, coalescing);
- (b) userInfo transfer: queue persistence across suspension/termination, ordering guarantees;
- (c) whether ANY background capability / Info.plist key / entitlement is required for these two transports (working expectation: none — VERIFY, do not assert from memory; if something IS required, disclose before adding it);
- (d) rapid-successive context updates: coalescing semantics (does the counterpart see every value or only the last?).
If any determination contradicts what 05 §6 assumed, record it as a dated errata candidate in the task file — do NOT edit normative docs silently; the orchestrator routes doc changes.

### R5 — Placement + project discipline
- Wrapper/protocol/live-session code in `Apps/Momo/` (ADR-013: duplicated per target; the Watch twin lands in TASK-041/042). Pure logic in `Sources/MomoKit/`.
- Executor wiring in a NEW extension file (e.g. `MomoAppModel+Watch.swift`) following the `+Canvas`/`+Celebrations`/`+Settings` precedent — `MomoAppModel.swift` is at 775/800 lines and must not grow past budget.
- Expected: NO pbxproj change (folder-group members are picked up by the existing group). VERIFY that assumption; if the pbxproj changes AT ALL, the D-R3 check is mandatory and must be recorded: no app-to-app target dependency, `dependencies = ()` intact for both app targets.
- Structural guards for the wiring legs, in the `RigDisciplineTests` house shape (read the executor source in a package test, pin the exact construction, pin non-vacuity in both stub directions, mutation-bite each): (1) the `.pushWatchSnapshot` arm routes to the real transport call; (2) the receive arm routes through `SyncState.shouldApply` / the receive-plan core and NEVER resolves watermarks at the call site (textually pinned — no raw `WatchSyncGate` in app code); (3) `eraseAllData()` writes the reset marker. Fixtures mirror the R9a–R9d precedent.
- Swift 6 strict-concurrency clean; zero warnings from touched files; files ≤ 800 lines, functions < 50; no `console.log`-style debug residue; immutable patterns; comprehensive error handling (a decode/transport failure degrades to no-op + record, never a crash — §25 honesty about what is and is not covered).

### R6 — Test deliverables
See Required Tests below; every new guard/integration test non-vacuous (bitten + sha256-restored, bites recorded).

## Files / Areas Likely Affected
- `Sources/MomoKit/`: NEW receive-plan core file (+ its test suite); `SyncDTOs.swift` (additive reset-marker field); `WatchSnapshotBuilder.swift` (marker parameter); possibly `StoreRules` (new constants — authority labels + raw-literal pins, the established discipline).
- `Apps/Momo/`: `MomoAppModel.swift` (the `:623` arm — keep growth minimal); NEW `MomoAppModel+Watch.swift` (or equivalent) + NEW transport protocol file + WCSession conformance; `MomoAppModel+Settings.swift` (`eraseAllData()` sets the marker); possibly `MomoApp.swift` (session bootstrap).
- `Tests/MomoKitTests/`: NEW integration suites + structural-guard fixtures.
- **NO changes to:** `Sources/MomoCore/` (FROZEN — diff must be 0 bytes at every checkpoint), `Sources/MomoCharacter/`, any View (D-R5), `Apps/MomoWatch/` (TASK-041/042), the String Catalog (no user-facing copy in this task), `SyncState`/`WatchSyncGate`/`SyncStateStore`/`IntentJournal` semantics (TASK-023 reviewed code — if you conclude a change is needed, STOP and disclose; do not edit silently).

## Dependencies
- EPIC-007 merged (`b73e3eb`): the facade, the reserved seam, the erase executor, the `+Settings` lifecycle.
- TASK-023 merged: the pure sync kit (see Context §5).
- ADR-003 (transport), ADR-013 (placement), ADR-005 (module map / wrapper duplication), ADR-008 (deployment pins).
- Inherited routings: O1+O5 (REVIEW-TASK-023), OBS-1 app-layer leg (REVIEW-TASK-024).

## Constraints
- §22 scope: exactly R1–R6. Out of scope (record as deferred, do NOT implement): `sendMessage` nudges (optimization-only — TASK-042 may carry them), Watch-side code, UI, user-facing copy, notifications, iCloud, anything §24 non-MVP.
- MomoCore frozen; MomoCharacter untouched; no new third-party dependencies (D-R6); no ambient time/paths outside the sanctioned sites; injected calendar/clock only.
- `swift test` green at handoff; MomoKit coverage floor ≥ 80 % must not dip — and since this task is coverage-touching, RE-MEASURE MomoKit coverage at close (llvm-cov; the measurement gotcha is recorded in status.md Test Status: re-run `swift test --enable-code-coverage` and measure immediately). Record the number.
- Do NOT commit; do NOT touch `.claude/tasks/status.md`, `.claude/tasks/epics/`, `.claude/tasks/reviews/`, or any completed-task record. Update ONLY this task file (Implementation Notes + Handoff).

## Acceptance Criteria
1. **AC-1** — The executor's `.pushWatchSnapshot` arm delivers a latest-wins context on every plan-issued push; plan order unchanged; content = display + questInputs + hapticsEnabled + current watermark pair; headless-tested through the protocol seam with a recording fake transport; the arm is structurally guarded.
2. **AC-2** — An unseen, non-stale `IntentEvent` applies exactly once through the accessor-driven gate (fold-to-now → apply → record → persist), and the next built snapshot carries the updated watermark pair (behavioral pin + structural pin).
3. **AC-3** — Duplicate / replay / redelivery / stale-seq events are full no-ops (INV-10: exactly-once under the FIFO contract stream, at-most-once under seeded shuffles per the O2 adjudication).
4. **AC-4** — Erase sets the reset marker; every context from erase onward carries it; the marker survives erase + relaunch (pinned); the first post-onboarding push carries it.
5. **AC-5** — The reset-marker DTO evolution is adjudicated and disclosed; a pre-marker payload decodes cleanly (compatibility test); NO schemaVersion bump unless disclosed with the OBS-3 consequence accepted AND executed.
6. **AC-6** — The WC VERIFY-AT-BUILD transport record exists in Implementation Notes with SDK-evidenced determinations for (a)–(d).
7. **AC-7** — `swift test` green with the new kit-level integration suites; every structural guard mutation-bitten with sha256-proven restores; zero warnings from touched files; MomoKit coverage re-measured and ≥ 80 %; `Sources/MomoCore/` diff 0 bytes; discipline scans (import whitelist, banned vocabulary, D-R5 purity) green with no new exemptions.

## Required Tests
1. **Apply-exactly-once integration** (kit level): FIFO-contract stream with duplicates + replays + redeliveries → each distinct intent's effects land exactly once; seeded shuffles → at-most-once shape (O2).
2. **Watermark propagation**: apply → `recordingApplied` → next `makeWatchSnapshot` carries the updated pair; a no-op receive leaves snapshot content untouched.
3. **Reset marker**: set → build → encode → decode round-trip; pre-marker payload compatibility (decodes cleanly, marker absent); the marker record's own persistence (double-save safe per the `moveItem` lesson — replace-when-present or vacate-then-move, pinned); erase → marker survives relaunch.
4. **Structural guards** (executor source reads): push arm → real transport; receive arm → `SyncState.shouldApply` + no raw `WatchSyncGate` in app code; erase → marker write. Each bites exactly its violation fixture; restores sha256-verified.
5. **Existing suites stay green**; TASK-023's pure-logic pins untouched and passing.

## Review Requirements
- §10/§33 independent review by a fresh, UNPRIMED agent (it re-derives 05 §6 + ADR-003 BEFORE reading your code; do not argue correctness in advance). The reviewer verifies AC-1…7, mutation-probes the gate wiring and at least one structural guard, inspects EVERY sync-state write site for the O1 one-writer rule, and checks the R3 schema adjudication + R4 record for evidence quality.
- Review record: `.claude/tasks/reviews/REVIEW-TASK-040.md` (the reviewer writes it; orchestrator dispositions).
- §27 note: this task touches sync transport + the erase lifecycle — the review must attend to privacy/failure surfaces (no user data leaves the devices; WC is device-to-device).

## Git Requirements
- The implementer does NOT commit. The orchestrator makes ONE atomic commit after the review cycle: `feat(sync): TASK-040 iPhone-side WC session — context push, intent receive, reset-marker leg` (the review record + task-file dispositions ride the closeout commit per house convention).

## Status
READY — contract authored 2026-09-11 by the orchestration agent; implementation dispatched to a fresh Jupiter agent.

## Implementation Notes
(implementation agent fills: what landed where, deviations + disclosures, the R3 adjudication, the R4 transport record, test evidence with counts, coverage number, bite records with sha256s)

## Reviewer Findings
(reviewer fills)

## Completion Evidence
(orchestrator fills at closeout)

## Handoff
When implementation is COMPLETE (all requirements + tests green at the final tree), fill the Handoff fields below and THEN append, as the very last line of this file at column 0, the exact marker: `HANDOFF-COMPLETE TASK-040` — the orchestrator's monitor keys on that exact line-start string. Do not write that marker anywhere else in this file, and do not write it until everything above is genuinely done (§25).

### Completed
### Files Changed
### Tests Run
### Test Results
### Known Issues
### Decisions Made
### Reviewer Status
### Commit
### Push
### Recommended Next Step
