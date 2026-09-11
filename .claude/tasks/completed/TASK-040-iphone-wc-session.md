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
IMPLEMENTATION COMPLETE (2026-09-11, same agent) — R1–R6 landed, quality gate green (988 tests / 100 suites; coverage 91.65 %; app build SUCCEEDED; MomoCore diff 0 bytes). Awaiting §10 independent-review dispatch. Not committed (per contract).
REVIEW CHANGES_REQUIRED (2026-09-11, REVIEW-TASK-040) — F-1 HIGH + F-2 MEDIUM fix unit; F-3…F-8 accepted notes.
FIX COMPLETE (2026-09-11, fresh §11 fix agent) — F-1/F-2 closed; gate re-green (995 tests / 100 suites).
DONE (2026-09-11) — delta-verified APPROVED_WITH_MINOR_NOTES (REVIEW-TASK-040-delta); committed and pushed; see Completion Evidence.

## Implementation Notes
(implementation agent fills: what landed where, deviations + disclosures, the R3 adjudication, the R4 transport record, test evidence with counts, coverage number, bite records with sha256s)

### R4 — WC VERIFY-AT-BUILD transport record (AC-6) — ALL FOUR DETERMINATIONS RESOLVED, 2026-09-11

**Evidence inspected (identity + provenance):**
- SDK header: `WCSession.h` from `iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk/System/Library/Frameworks/WatchConnectivity.framework/Headers/` (Xcode-bundled, the SDK this task builds against). Verified BYTE-IDENTICAL (`diff -q`) to the `iPhoneSimulator.platform/.../iPhoneSimulator.sdk` copy — sim vs device headers carry no behavioral divergence. Read in full (200 lines); `WCError.h`, `WCDefines.h`, `WatchConnectivity.h`, `WCSessionFile.h`, `WCSessionUserInfoTransfer.h`, and `WatchConnectivity.apinotes` also inspected.
- Apple Developer Documentation (developer.apple.com, JSON endpoints, fetched 2026-09-11): `wcsession/updateapplicationcontext(_:)` and `wcsession/transferuserinfo(_:)`.
- Entitlement/capability sweep: grep across ALL WatchConnectivity framework headers for entitlement / capability / `UIBackgroundModes` / Info.plist keys — zero occurrences (only behavioral doc sentences about "background transfers", never a capability precondition).

**(a) Application-context delivery — RESOLVED (launch delivery, opportunistic timing, sender may be dead):**
- WCSession.h:106-107 — "Setting the applicationContext is a way to transfer the latest state of an app. After updating the applicationContext, the system initiates the data transfer at an appropriate time, which can occur after the app exits. The counterpart app will receive a delegate callback on next launch if the applicationContext has successfully arrived… The applicationContext dictionary can only accept the property list types."
- WCSession.h:182 — `didReceiveApplicationContext:` "Will be called on startup if an applicationContext is available."
- Docs — "The system sends context data when the opportunity arises, with the goal of having the data ready to use by the time the counterpart wakes up." Also: "You may call this method when the counterpart is not currently reachable."
- Design consequence honored: latest-wins; no delivery-latency or reachability assumption anywhere in the receive design.

**(b) transferUserInfo — RESOLVED (queued, FIFO, persists across suspension/termination, launch delivery):**
- Docs (explicit ordering guarantee) — "Dictionaries sent using this method are queued on the other device and **delivered in the order in which they were sent**. After a transfer begins, the transfer operation continues even if the app is suspended."
- WCSession.h:115 — "The system will enqueue the user info dictionary and transfer it to the counterpart app at an opportune time. The transfer of user info will continue after the sending app has exited. The counterpart app will receive a delegate callback on next launch if the file has successfully arrived."
- WCSession.h:99-104 — "Background transfers continue transferring when the sending app exits. The counterpart app (other side) is not required to be running for background transfers to continue. The system will transfer content at opportune times."
- WCSession.h:123 — `outstandingUserInfoTransfers` (in-flight queue inspectable); WCSession.h:189 — `didReceiveUserInfo:` "Will be called on startup if the user info finished transferring when the receiver was not running."
- Design consequence honored: FIFO contract stream is real (the INV-10 exactly-once pin tests against it); O2's at-most-once-under-shuffle adjudication remains correct because the gate itself does not depend on delivery order.

**(c) Required background capability / Info.plist key / entitlement — RESOLVED: NONE (working expectation CONFIRMED at SDK level).**
- Zero references to any entitlement, background-mode key, or capability requirement anywhere in the WatchConnectivity framework headers (grep sweep, all 7 header files + apinotes). The framework's own background-transfer documentation sections state behavior without any capability precondition.
- Design consequence: NO Info.plist / entitlement / capability changes in this task (none were added). Honest caveat recorded: headers/docs are not a runtime enforcement contract — §10.4's paired-hardware verification (TASK-044, §25) remains the runtime proof point; nothing here substitutes for it.

**(d) Rapid-successive context updates — RESOLVED: COALESCE; the counterpart observes only the last value.**
- Docs (explicit) — "**This method replaces the previous dictionary that was set**, so you should use this method to communicate state changes or to deliver data that is updated frequently anyway."
- WCSession.h:111 — `receivedApplicationContext` "Stores the **most recently received** applicationContext from the counterpart app."
- Design consequence: exactly the ADR-003 latest-wins contract. Push-on-every-change means ATTEMPTED on every change; the counterpart is guaranteed only the newest value — hence the watermark pair rides EVERY context (never rely on intermediate contexts having been observed).

**Additional evidenced constraints the implementation honors (same inspection):**
- WCSession.h:25-28 — "On start up an app should set a delegate on the default session and call activate. This will allow the system to populate the state properties and deliver any outstanding background transfers." + WCSession.h:45 — activateSession "must be activated on startup… Calling activate without a delegate set is undefined." → transport sets delegate BEFORE activating, at launch.
- WCSession.h:34 — `isSupported` "Session is always available on WatchOS" → iOS-only guard; the Watch side never guards.
- WCSession.h:136-139 — "All delegate methods will be called on the same queue. The delegate queue is a non-main serial queue. It is the client's responsibility to dispatch to another queue" → delegate hops to the main actor before touching executor state.
- WCSession.h:143-152 — the three REQUIRED (pre-`@optional`) delegate methods: `session:activationDidCompleteWithState:error:` (iOS 9.3+), `sessionDidBecomeInactive:` (iOS 9.3+, WATCHOS_UNAVAILABLE), `sessionDidDeactivate:` (iOS 9.3+). All three implemented in the live wrapper.
- WCSession.h:107/:115 — payload dictionaries accept ONLY property-list types → the wrapper carries the JSON-encoded snapshot/event as a `Data` value inside the plist dict (Data is a plist type), never a nested non-plist shape.
- WCError.h:20-25 — error codes 7004 (SessionNotActivated), 7005 (DeviceNotPaired), 7006 (WatchAppNotInstalled), 7009 (PayloadTooLarge) enumerated for the wrapper's catch/log-no-crash handling.
- Docs (transferUserInfo page) — "Always test Watch Connectivity data transfers on paired devices. The Simulator app doesn't support the sendMessage method." → direct support for TASK-044's paired-hardware obligation; note it names `sendMessage` (the optimization-only path, TASK-042) as the simulator-unsupported API — the context/userInfo paths used here are not called out as sim-unsupported, but the docs' blanket paired-device advice stands and TASK-044 already owns hardware verification (§25).

**Errata check (R4 closing clause): NO contradictions with 05 §6 found.** The spec's transport table (context latest-wins ↓, userInfo FIFO journal ↑, sendMessage reachable-only optimization) matches the evidenced SDK behavior on every determination. One nuance worth stating, not an erratum: 05 §6's "push on every state change" is delivered by the SDK as "attempted on every change, coalesced to latest" — this is precisely what ADR-003 and the watermark-in-every-context design already assume, so no doc change is routed.

**R4 addendum (2026-09-11, caught at first app build):** the Swift OVERLAY renames the C-header's `activateSession()` to `activate()` — `xcodebuild` failed with "'activateSession()' has been renamed to 'activate()'" ("obsoleted in Swift 3"). The R4 record's WCSession.h citations are C-spelling and stand; the wrapper calls `activate()` and carries a comment noting the overlay rename. No behavioral determination changes.

### What landed where (R1/R2/R3/R5)

**MomoKit (pure logic, headless-testable):**
- `WatchReceivePlan.swift` (NEW) — R2's pure core: `decide(event:sync:seenIntentIDs:)` → `.apply(postSync:)` / `.ignore`. Calls `sync.shouldApply(event, seenIntentIDs:)` internally (O5's accessor rule — call sites never touch watermarks); `.apply` carries `sync.recordingApplied(event)`. 8-test suite (`WatchReceivePlanTests`): the 5-case gate matrix, FIFO exactly-once stream (distinct + duplicate + full replay + stale straggler → in-order exactly-once, second pass zero), 3-seeded shuffles (O2 at-most-once, NOT strengthened), the F-1 propagation loop (snapshot → decide → `AppModelPlanCore.plan(.interaction)` → next snapshot carries the updated pair — the blind-spot leg pinned behaviorally), no-op leaves snapshot content untouched.
- `WatchResetMarker.swift` / `WatchResetMarkerStore.swift` (NEW) — R3's record + persistence, mirroring `SyncStateStore` exactly (temp write → replace-when-present / move-when-absent commit point; missing/garbled → nil silently, the sibling-store stance; never throws).
- `SyncDTOs.swift` — `WatchSnapshot.resetMarkerEraseCount: Int?` (additive OPTIONAL — see adjudication below).
- `WatchSnapshotBuilder.swift` — trailing `resetMarkerEraseCount: Int?` passthrough.
- `StoreRules.swift` — `watchResetMarkerDirectory()` (see revision note below), marker/temp file-name constants, `zeroWatchSyncEpoch` (all-zero UUID sentinel, pin-tested inert).

**Apps/Momo (ADR-013 placement):**
- `MomoWatchTransport.swift` (NEW) — R1's `MomoWatchTransporting` protocol (activate / send(contextData:) / onUserInfoData sink) + `LiveWatchTransport` (thin WCSession wrapper: delegate-before-activate, `.activated`-gated sends degrade to logged drops, plist `["payload": data]` wrap/unwrap, all three REQUIRED delegate methods, `didReceiveApplicationContext` deliberately NOT implemented — ADR-003 makes Watch→iPhone transferUserInfo-only).
- `MomoAppModel+Watch.swift` (NEW) — the executor half: `bindWatchTransport()` (sink first, activate second — WCSession.h:42-45), `pushWatchSnapshot()` (the armed seam), `receiveWatchEvent(_:)` (decode-or-skip → `WatchReceivePlan.decide` → record postSync + epoch BEFORE apply (F-1) → `apply(trigger: .interaction(event.intent))` → unconditional sync persist), `MomoWatchSyncPersister` actor (the sync-state file's ONE writer, O1).
- `MomoAppModel.swift` — stored props (`watchSyncState`, `watchSyncEpoch`, `watchTransport`), init param (nil = session disabled → previews/headless; production passes `LiveWatchTransport()`), sync-state + marker join the sanctioned launch read, `bindWatchTransport()` as the last init statement, the `.pushWatchSnapshot` arm. Now exactly 800/800 lines (was 789 pre-task; contract said 775 — it had grown to 789 by EPIC-007 close).
- `MomoAppModel+Settings.swift` — `eraseAllData()` step 1 is now the marker bump (signal-first: read → +1 → save → THEN delete the store tree), plus the in-memory sync reset.
- `MomoApp.swift` — production construction passes `LiveWatchTransport()`.

**Tests:** `WatchResetMarkerTests` (13), `WatchReceivePlanTests` (8), `MomoWatchWiringScanTests` (14) — plus 4 new pins in `StoreRulesPinnedTests` (zero-epoch bytes, marker file name, temp name, marker directory OUTSIDE the store tree).

### Disclosures and adjudications

**D-1 · R3 schema adjudication (AC-5): ADDITIVE OPTIONAL, NO schemaVersion bump.** `decodeIfPresent`/`encodeIfPresent`; nil → key omitted from the wire. Compatibility is bidirectional: a PRE-marker decoder reading a marker-carrying payload succeeds (it gates on the UNCHANGED schemaVersion and never requests the new key — hand-written Codable reads by CodingKeys, unknown keys are simply not requested); a marker-carrying decoder reading a pre-marker payload succeeds (`decodeIfPresent` → nil; pinned by the compatibility test). A version BUMP was rejected because both DTO decoders gate `schemaVersion ==` strictly: every pre-bump decoder would DROP whole payloads, and the OBS-3 parity-fixture obligation would fire, expanding scope into persistence-side work. The optional rides the existing version.

**D-2 · R3 marker location REVISED mid-implementation (self-caught design error, §25 honesty).** The first design put the marker INSIDE the store tree and claimed its loss on erase was safe — WRONG: a lost marker means a fresh 0-init watermark, which ADMITS stale pre-erase journal entries (exactly the §6.6 bug the marker exists to prevent). Redesigned: the marker lives OUTSIDE the store tree, at the Application Support ROOT, via `StoreRules.watchResetMarkerDirectory()` = `defaultDirectory().deletingLastPathComponent()` — DERIVED from the one sanctioned ambient read, so the discipline-scan "exactly one applicationSupportDirectory read" pin holds UNAMENDED (not weakened). Ordering is signal-first: read → +1 → save → THEN delete the store tree; by the time pet data is gone, the wipe instruction is durable. Crash windows: before the save → previous marker stands (already-consumed count, inert); after the save, before the delete → the Watch wipes unnecessarily — harmless (the Watch holds no authority; the next context re-syncs it). Marker survival across erase + relaunch is pinned (including a second erase → count 2).

**D-3 · Degraded paths (never a crash).** Marker save I/O failure → skipped signal, DEBUG-loud (the pre-TASK-040 status quo — the erase still completes; disclosed per R3's contract line). Marker directory lookup failure → DEBUG-loud + throwaway temp fallback directory. Snapshot encode failure → logged skip. Undecodable receive frame → logged skip (garbled or future-version frame must never wedge the iPhone). Context send on an inactive/unsupported session → logged drop (latest-wins: the next push supersedes).

**D-4 · R2's no-outcome-change apply edge (contract: analyze and DISCLOSE, don't assume away).** An apply whose engine outcome is unchanged (fold-to-now onto an already-satisfied state) would, if the sync persist rode the plan's IFF-changed steps, drop its watermark. Handled by construction: the watermark pair is recorded from the PLAN's decision (`postSync`) BEFORE the apply, and the receive path persists sync state UNCONDITIONALLY after the apply — outside the plan's IFF-changed step list. The next changed-outcome push therefore always carries the updated pair. No engine call was made to special-case this.

**D-5 · Push-arm persist decision (seq durability).** The push spends a `snapshotSeq`; without persisting `nextSync`, a relaunch would rewind the seq to the last receive-persisted state and REUSE seqs across restarts. The push therefore persists sync state after sending — through the same single-writer actor as the receive persist (O1: one file, one writer path, submissions from the main actor in FIFO order; even a hypothetical reorder degrades conservatively — a stale persisted watermark only prunes less on the Watch, and the engine's `processedIntents` belt still guards replays).

**D-6 · OBS-1 launch-read extension.** The sync-state load and marker load join the ONE sanctioned synchronous main-thread launch read (both KB-scale, same directory as the store). The receive hot path does NO file I/O on WCSession's queue: the sink re-isolates via `Task { @MainActor }` and the sync persist is handed to the `MomoWatchSyncPersister` actor (off-main).

**D-7 · AC-1's "headless-tested with a recording fake" — honest scope note.** The app target has NO test target in this project (all tests live in `Tests/MomoKitTests`, which cannot import `Apps/Momo`). The executor ARM is therefore covered STRUCTURALLY (wiring-scan guard 1, bitten) rather than behaviorally; the COMPOSITION the arm performs (makeWatchSnapshot from current state → gate/decide → next snapshot carries the pair) IS behaviorally pinned at kit level (the F-1 loop test). The protocol seam exists precisely so a future app-target test target — or the TASK-041/042 Watch twin — can drive a recording fake; the reviewer may weigh whether that debt is acceptable now.

**D-8 · MomoAppModel.swift budget.** 789 → 800 EXACTLY (stored props, init seams, arm). Everything with room to breathe lives in `MomoAppModel+Watch.swift` (166 lines). The `clock` and `watchTransport` stored properties moved from `private` to internal (file-scoped `private` is invisible to same-target extensions in other files — the `storeDirectory` precedent, target-scoped only, doc-noted).

**D-9 · pbxproj change — the contract's "expected NO pbxproj change" assumption is FALSE for this project, and the mandatory D-R3 check ran and PASSED.** The project does not use synchronized folder groups: sources are explicit `PBXFileReference` + `PBXBuildFile` entries with hand-minted IDs (the existing convention: `8A4x…` BuildFile / `8A5x…` FileRef, suffixes in use through 0059). Four registrations were added for the two new app files (suffixes 005A `MomoWatchTransport.swift`, 005B `MomoAppModel+Watch.swift`): BuildFile lines, FileReference lines, Momo group children (`8A6…0004`), Momo Sources phase (`8A2…000D`). **D-R3 record:** Momo target `dependencies = ()` EMPTY; MomoWatch target `dependencies = ()` EMPTY; the only non-empty dependency sections are the two PRE-EXISTING UI-test targets on their app-under-test (standard runner arrangement, not app-to-app); both app targets' `packageProductDependencies` are MomoCore + MomoCharacter + MomoKit — the iPhone target carries NO MomoWatch package product. No app-to-app target dependency exists or was added.

**D-10 · Structural-guard shape vs contract wording.** The contract's guard-2 wording offered "routes through `SyncState.shouldApply` / the receive-plan core" — the guard pins `WatchReceivePlan.decide(` (which internally calls `shouldApply`) plus ZERO `WatchSyncGate` tokens in comment-stripped app code (O5's actual rule: the app names the plan, never the gate). Guard 1 is two legs (arm → `pushWatchSnapshot()`; push body → `watchTransport.send(contextData:`); guard 3 pins the marker write AND its signal-first ordering (save index < delete index). All three predicates scan comment-stripped text; fixture self-tests prove both stub directions (token stripped → red; token only in a comment → red), and a comment-only `WatchSyncGate` citation stays legal (the stripper must not mute the +Watch doc's citation of the banned gate).

**D-11 · In-passing correction (disclosed, in-scope).** `MomoAppModel+Settings.swift`'s extension header claimed the main file "already stands past the 800-line budget" — stale text from the pre-TASK-039 overage (the file was 789 at task start). Corrected to the present-tense truth while editing that file for the erase wiring. No other out-of-scope edits.

**D-12 · Unrelated work discovered → recorded, NOT fixed (§22):** `AppModelPlan.swift` still carries doc comments describing the push step as a reserved no-op / "executor: TASK-031" language from before EPIC-008 — now inaccurate (the seam is armed). The contract froze the plan core's content; a doc-only touch-up there is left to the orchestrator to route (one-line comment edits, zero behavior).

### Mutation-bite records (each flip → EXACTLY its guard's real-tree test failed; restores sha256-verified)

| Bite | File (sha256 before == after, truncated) | Mutation | Result |
|---|---|---|---|
| 1 | `Apps/Momo/MomoAppModel.swift` `535b5098cbf917ab…` | arm's `pushWatchSnapshot()` → `_ = 0` | ONLY "wires the push arm" red (finding: arm does not call pushWatchSnapshot()); erase + receive guards green |
| 2 | `Apps/Momo/MomoAppModel+Watch.swift` `868f8bfec39860c4…` | `WatchReceivePlan.decide(` → `WatchSyncGate.shouldApply(` | ONLY "decides receives through the plan core" red (both legs: decide missing + raw gate in code); push + erase green |
| 3 | `Apps/Momo/MomoAppModel+Settings.swift` `71fd3900ba006dd8…` | marker save moved BELOW the store-tree delete | ONLY "writes the reset marker before the store deletion" red (ordering leg alone); push + receive green |

### Final file hashes (sha256, truncated to 16 hex)

`StoreRules.swift` `f426dd39b0d824b3` · `SyncDTOs.swift` `ba947350cea5a044` · `WatchSnapshotBuilder.swift` `13f4837ee325231b` · `WatchReceivePlan.swift` `efb4b52ce90386b3` · `WatchResetMarker.swift` `b016a90e4d05c972` · `WatchResetMarkerStore.swift` `995d4967edf16d5b` · `MomoAppModel.swift` `535b5098cbf917ab` · `MomoAppModel+Settings.swift` `71fd3900ba006dd8` · `MomoAppModel+Watch.swift` `868f8bfec39860c4` · `MomoWatchTransport.swift` `4e3e0b8ceef85085` · `MomoApp.swift` `54e51f4c50f7424f` · `WatchResetMarkerTests.swift` `2d0fdd8ad1d5c111` · `WatchReceivePlanTests.swift` `2fab68f167447ab8` · `StoreRulesPinnedTests.swift` `0a858c99696e1ed1` · `MomoWatchWiringScanTests.swift` `7697af7f57de0c66` · `Support/WatchWiringScan.swift` `823274070567fe21` · `Support/KitRepo.swift` `5973deb63979f6b6` · `project.pbxproj` `bd8f2910c0f4ea18`

(Note: earlier in-progress notes recorded `StoreRules.swift` at `ee9e79b2…` then `1e800da9…` — both pre-date the D-2 derivation fix; the final hash is the `f426dd39…` above. The R3-suite files' hashes match their recorded post-bite values.)

### Quality-gate evidence

- `swift test`: **988 tests / 100 suites PASSED** (baseline 949/97; +39 = 13 `WatchResetMarkerTests` + 8 `WatchReceivePlanTests` + 14 `MomoWatchWiringScanTests` + 4 new `StoreRulesPinnedTests` pins; +3 suites).
- MomoKit coverage (llvm-cov, measured immediately after `--enable-code-coverage`): **91.65 % regions / 92.62 % functions / 92.47 % lines** — above the 80 % floor (previous reading 91.42 %).
- `xcodebuild -project Momo.xcodeproj -scheme Momo -destination 'id=1F25E487-A78E-464C-95AF-0BD1A9B3E1BE' build`: **BUILD SUCCEEDED** (build only, no simulator driving). Only pre-existing project-level warnings (`ld` search path `/opt/extra/lib` ×2, AppIntents metadata-processor note) — ZERO warnings from any touched file.
- Frozen surfaces: `git diff --stat Sources/MomoCore/` EMPTY; `Sources/MomoCharacter/`, `Apps/MomoWatch/`, all Views, and the String Catalog untouched; the only `.claude/tasks` file modified is this one. Branch `feature/EPIC-008-watch-sync`.
- Discipline scans (part of the green suite): import whitelist, ambient time/paths, the one-applicationSupportDirectory-read pin — all green, no new exemptions (D-2's derivation was chosen specifically to keep the pin unamended).
- No WC live session was started in any test (per constraint; the R4 record additionally shows the simulator does not support WC data-transfer testing — TASK-044 owns paired-hardware verification).

## Reviewer Findings

**Reviewed 2026-09-11 by the independent §10/§33 agent (fresh, unprimed; spec re-derived from 05 §5.5–5.6/§6.1–6.6 + ADR-003/013 before any code was read). Full record: `.claude/tasks/reviews/REVIEW-TASK-040.md`. Tree left byte-identical; all reviewer probes sha256-restored.**

**Verdict: CHANGES_REQUIRED** — one HIGH finding; everything else verified PASS or note-level.

- **F-1 (HIGH — the driver)**: the reset marker's launch-LOAD and erase-SAVE sites use different directories. Load: `MomoAppModel.swift:383-384` loads via the executor's STORE TREE directory (`Application Support/Momo/watch-reset-marker.json`); save: `+Settings.swift:100,106-108` saves via `StoreRules.watchResetMarkerDirectory()` = the Application Support ROOT (`Application Support/watch-reset-marker.json`, StoreRules.swift:141-143). The load can never observe the save → after erase + relaunch the count inits to 0 → no context ever carries the marker → the Watch never learns of the wipe → stale pre-erase journal entries apply warm onto the fresh pet — the exact §6.6 hazard D-2 says the marker exists to prevent, reintroduced in the wiring. AC-4's "survives erase + relaunch (pinned)" passes only at STORE level (`markerOutlivesTheErasedStoreTree` saves/loads through one directory — structurally blind to the divergence; the F-1 blind-spot shape). **Fix**: load via `try StoreRules.watchResetMarkerDirectory()` (same DEBUG-loud + fallback discipline as the erase path), plus a pin binding the load site to the same rule.
- **F-2 (MEDIUM, fix with F-1)**: the enabling test gap — no test reaches the executor's launch-load path. Reviewer Probe C: redirecting the load to a never-existing directory leaves the FULL suite 988/988 green. Close the gap with the pin above.
- **F-3 (LOW, note for TASK-041/044)**: release-build marker-save failure is silent (DEBUG-loud per D-3, house posture) — the Watch side could self-defend by validating its journal epoch against the incoming snapshot's.
- **F-4/F-5/F-6/F-7/F-8 (notes)**: D-5 best-effort seq durability sound (display-level only); `watchSyncEpoch` transient reversion inert (delayed pruning only); D-7 structural-only arm coverage accepted as disclosed; D-12 AppModelPlan doc comments routed to orchestrator (doc-only); MomoAppModel.swift at exactly 800/800 — no headroom.
- **Verified PASS**: AC-1/2/3/5/6/7 and Required Tests 1/2/4/5. AC-4 fails only on the wiring leg above. O1 census clean (sync-state file: exactly one writer, the `MomoWatchSyncPersister` actor, two call sites; marker file: exactly two production sites — the divergent pair in F-1; journal/stores untouched). O5 clean (zero raw `WatchSyncGate` tokens in comment-stripped app code). OBS-1 clean (receive hot path I/O-free; launch read still the single sanctioned site). D-1 adjudication verified sound against the strict `==` gates both directions. R4 record re-verified at source (WCSession.h byte-identical device/sim, all cited lines hold, zero-hit entitlement sweep → determination (c) stands; paired-hardware proof correctly deferred to TASK-044). D-R3 verified at pbxproj (`dependencies = ()` both app targets). §22/§26/§27 clean. All gate claims reproduced exactly: 988 tests / 100 suites (×3 runs); MomoKit coverage 91.65 % regions (exact match); `xcodebuild` Momo BUILD SUCCEEDED; MomoCore diff 0.
- **Reviewer probes (record with sha256s in the full review record)**: A — `send(contextData:` → `send(context:` in `+Watch.swift` (`868f8bfe…` before == after) → ONLY the push-arm guard's real-tree test red. B — drop `recordingApplied` from `WatchReceivePlan.decide` (`efb4b52c…` before == after) → 4 tests red incl. the FIFO exactly-once stream and the F-1 propagation pin (the pins are genuinely semantic). C — marker load pointed at a nonexistent directory (`535b5098…` before == after) → full suite stays green (the F-1/F-2 blind-spot proof).
- **DELTA REVIEW (2026-09-11, independent §11 delta agent; full record `.claude/tasks/reviews/REVIEW-TASK-040-delta.md`)**: F-1/F-2 fix unit VERIFIED. Both marker paths traced to the same `watchResetMarkerDirectory()` rule with mirrored degraded discipline (load `+Watch.swift:60-71` == save `+Settings.swift:98-108`); guard 4's four legs and 7 tests verified genuine at source; the F-2 blind spot closed. All 18 handoff hashes recomputed — 14 non-fix files byte-identical to the original table, 4 fix files byte-identical to the fix table. Delta reviewer's OWN probes (both full-suite, restores sha256-verified): D1 helper derivation → `defaultDirectory()` (exact F-1 reversion, `de900215…` → `b4a7253b…` → `de900215…`) → exactly ONE red (the new standing test); D2 init restored to the literal pre-fix store-tree load (`ef7d2d5a…` → `6176ba33…` → `ef7d2d5a…`) → exactly ONE red, BOTH main legs (count == 2). Gates re-reproduced: swift test 995/100 PASSED; xcodebuild BUILD SUCCEEDED; MomoCore diff 0; `MomoAppModel.swift` 800/800. No new findings.
- **DELTA VERDICT**: `DELTA VERIFIED — F-1/F-2 closed; TASK-040 review cycle complete; final status: APPROVED_WITH_MINOR_NOTES` (the notes being F-3…F-8 as accepted by the orchestrator).

## Completion Evidence
- Implementation: R1–R6 complete per the Handoff above (fresh Jupiter agent; 12 disclosures D-1…D-12; 3 bitten structural guards).
- Independent review (§10/§33): `.claude/tasks/reviews/REVIEW-TASK-040.md` — verdict CHANGES_REQUIRED: F-1 HIGH (reset-marker launch-load read the store tree while the erase-save wrote the Application Support root — the marker could never survive a relaunch; the exact §6.6 hazard, proven invisible to the suite by Probe C) + F-2 MEDIUM (the enabling test gap); F-3…F-8 accepted notes (dispositioned personally by the orchestrator at source).
- Fix cycle (§11, fresh fix agent): F-1 — the init's marker load routes through the new static `loadResetMarkerEraseCount()` (`MomoAppModel+Watch.swift`), deriving via `try StoreRules.watchResetMarkerDirectory()` with the erase site's DEBUG-loud + throwaway-fallback discipline; 800/800 held via a line-neutral swap. F-2 — new guard 4 `markerDirectoryViolations` (4 comment-stripped legs binding BOTH marker sites to the one directory rule, incl. a direct-store-construction ban) + 7 new tests with both-direction non-vacuity; full-suite bite → exactly one red.
- Delta verification (§11, fresh delta reviewer): `.claude/tasks/reviews/REVIEW-TASK-040-delta.md` — DELTA VERIFIED: reviewer's own probes (exact F-1 reversion → exactly one red; pre-fix load reverted → exactly one red on both main legs), all restores sha256-verified; all 18 handoff hashes reconciled (14 untouched files byte-identical). **FINAL STATUS: APPROVED_WITH_MINOR_NOTES** (notes = F-3…F-8 as accepted).
- Final gate (orchestrator-personal, on this commit's tree): `swift test` **995 tests / 100 suites PASSED** (baseline 949/97; +46 = 13 ResetMarker + 8 ReceivePlan + 21 WiringScan + 4 StoreRules pins); MomoKit coverage **91.65 % regions / 92.47 % lines** (floor 80 %); xcodebuild Momo + MomoWatch **BUILD SUCCEEDED** on the pinned simulators, zero touched-file warnings; `git diff Sources/MomoCore/` empty; discipline scans green (one-applicationSupportDirectory-read pin unamended); `MomoAppModel.swift` exactly 800/800.
- Commit: (this commit) — feat(sync): TASK-040 iPhone-side WC session — context push, intent receive, reset-marker leg
- Push: (this push pending) — `feature/EPIC-008-watch-sync` → origin
- Accepted notes carried forward: F-3 (release-build marker-save silence → note routed to TASK-041/044 consumption design), F-4/F-5 (documented inert), F-6 (D-7 posture stands; revisit if TASK-041/042 land without a Watch-side harness), F-7 (`AppModelPlan.swift` stale doc comments — orchestrator doc-only follow-up), F-8 (executor at 800/800 zero headroom — future executor work lands in extension files).

## Handoff
When implementation is COMPLETE (all requirements + tests green at the final tree), fill the Handoff fields below and THEN append, as the very last line of this file at column 0, the exact marker: `HANDOFF-COMPLETE TASK-040` — the orchestrator's monitor keys on that exact line-start string. Do not write that marker anywhere else in this file, and do not write it until everything above is genuinely done (§25).

### Completed
- R1 — `.pushWatchSnapshot` arm armed: builds the latest-wins snapshot (display + today's questInputs + haptics + watermark pair via `zeroWatchSyncEpoch` sentinel pre-any-apply + marker count) and delivers through the `MomoWatchTransporting` protocol; `LiveWatchTransport` wraps WCSession (ADR-013 placement); plan core untouched.
- R2 — `WatchReceivePlan` pure core (accessor-driven gate, O5) + `receiveWatchEvent` executor path (decode-or-skip → decide → record-before-apply (F-1) → facade interaction apply → unconditional sync persist via the one-writer actor, O1); exactly-once/at-most-once pins per INV-10/O2.
- R3 — additive `resetMarkerEraseCount` (no bump, D-1); `WatchResetMarker`/`WatchResetMarkerStore` outside the store tree (D-2 revision); signal-first erase bump; count rides every context until Watch consumption (TASK-041/044).
- R4 — all four determinations RESOLVED against the real SDK (headers byte-identical device/sim, Apple docs JSON endpoints), recorded above with citations; no entitlement/capability/Info.plist change required (determination (c)) — none added.
- R5 — placement per ADR-013; executor wiring in new `MomoAppModel+Watch.swift`; pbxproj registrations + D-R3 check recorded (D-9); three structural guards with both-stub-direction non-vacuity, each mutation-bitten, sha256-restored.
- R6 — 39 new tests across 3 new suites + 4 pins; all evidence in Quality-gate evidence above.

### Files Changed
- NEW `Sources/MomoKit/`: `WatchReceivePlan.swift`, `WatchResetMarker.swift`, `WatchResetMarkerStore.swift`
- MOD `Sources/MomoKit/`: `SyncDTOs.swift`, `WatchSnapshotBuilder.swift`, `StoreRules.swift`
- NEW `Apps/Momo/`: `MomoWatchTransport.swift`, `MomoAppModel+Watch.swift`
- MOD `Apps/Momo/`: `MomoAppModel.swift` (800/800), `MomoAppModel+Settings.swift`, `MomoApp.swift`, `Momo.xcodeproj/project.pbxproj` (4 registrations; D-9)
- NEW `Tests/MomoKitTests/`: `WatchResetMarkerTests.swift`, `WatchReceivePlanTests.swift`, `MomoWatchWiringScanTests.swift`, `Support/WatchWiringScan.swift`
- MOD `Tests/MomoKitTests/`: `StoreRulesPinnedTests.swift` (+4 pins), `Support/KitRepo.swift` (`momoAppSources()` reader)
- MOD `.claude/tasks/active/TASK-040-iphone-wc-session.md` (this file — the only `.claude/tasks` file touched)

### Tests Run
- `swift test` (full suite, multiple runs incl. final) — plus per-suite `--filter` runs during bites.
- Three mutation bites: `swift test --filter MomoWatchWiringScanTests` under each flip, then byte-identical restores.
- `swift test --enable-code-coverage` → immediate llvm-cov report on `Sources/MomoKit`.
- `xcodebuild -project Momo.xcodeproj -scheme Momo -destination 'id=1F25E487-A78E-464C-95AF-0BD1A9B3E1BE' build` (build only).
- Frozen-surface checks: `git diff --stat Sources/MomoCore/`, `git status --short`.

### Test Results
- 988 tests / 100 suites PASSED (baseline 949/97). Coverage 91.65 % regions / 92.47 % lines (floor 80 %). App build SUCCEEDED, zero warnings from touched files. D-R3 PASS. MomoCore diff 0 bytes. All bite restores hash-verified. Details in Quality-gate evidence.

### Known Issues
- R4's determinations are header/doc-level evidence; RUNTIME paired-device verification remains TASK-044's obligation (§25) — nothing here substitutes for it.
- AC-1's executor-arm behavioral test is out of reach at package level (no app-target test target exists); covered structurally + by the kit-level F-1 pin — D-7 discloses; reviewer to adjudicate.
- Pre-existing build warnings (ld `/opt/extra/lib` search path, AppIntents metadata note) are untouched project-level noise.
- `AppModelPlan.swift`'s stale "reserved no-op" doc comments now inaccurate — D-12 follow-up for the orchestrator (doc-only).
- The simulator cannot exercise WC data transfers at all (R4/Apple docs) — first live proof is TASK-044 on hardware.

### Decisions Made
- D-1 additive-optional marker field, no schemaVersion bump. D-2 marker moved OUTSIDE the store tree (self-caught §6.6 hazard), signal-first erase ordering, ambient-read discipline pin kept unamended via derivation. D-3 all failure paths degrade to logged no-ops. D-4 receive persists sync unconditionally (no-outcome-change edge). D-5 push persists spent seq (restart-safe). D-6 sync+marker loads joined the sanctioned launch read; receive hot path I/O-free. D-8 `clock`/`watchTransport` opened to internal (file-scoped-private limits). D-9 pbxproj registrations + D-R3 record. D-10 guard shapes pin the plan core + raw-gate absence.

### Reviewer Status
NOT YET REVIEWED — awaiting orchestrator dispatch of the fresh, unprimed §10/§33 reviewer (record to `.claude/tasks/reviews/REVIEW-TASK-040.md`).

### Commit
NONE — the implementer did not commit (contract). Orchestrator commits after the review cycle: `feat(sync): TASK-040 iPhone-side WC session — context push, intent receive, reset-marker leg`.

### Push
NONE — no commit exists to push (contract).

### Recommended Next Step
Orchestrator: dispatch the independent reviewer for TASK-040 (unprimed; re-derives 05 §6 + ADR-003 before reading the code; verify AC-1…7, mutation-probe the gate wiring and one structural guard, audit every sync-state write site for O1, check D-1/D-2 and the R4 record). After APPROVED disposition + commit/push, proceed to TASK-041 (the Watch twin mirrors `MomoWatchTransport` per ADR-013 and consumes the context this task now emits).

HANDOFF-COMPLETE TASK-040

## Post-Review Fix Notes (F-1/F-2)

Fix agent, 2026-09-11 — the CHANGES_REQUIRED fix unit exactly as adjudicated (F-1 + F-2 as one unit; F-3…F-8 untouched, still with their owners). No commit, no push, no branch operations (the orchestrator commits after re-verification). Nothing below modifies any section above; the Handoff marker above is left untouched where it stands.

### F-1 — the launch load now derives from the same rule the erase uses

The divergence (review F-1): the init loaded the marker from the executor's STORE TREE (`WatchResetMarkerStore(directory: directory)` → `Application Support/Momo/watch-reset-marker.json`) while the erase saves to the Application Support ROOT (`StoreRules.watchResetMarkerDirectory()` = `defaultDirectory().deletingLastPathComponent()` → `Application Support/watch-reset-marker.json`). The two paths can never meet — after erase + relaunch the count read 0 and no context ever carried the marker.

- `Apps/Momo/MomoAppModel.swift:381-384` — the init's marker load now routes through a static helper; the adjacent comment states the truth (the SAME §6.6 root the erase writes; OUTSIDE the store tree, so the erase's deletion can never touch it; Missing/garbled → 0). The replacement was made line-NEUTRAL (4 lines → 4 lines) to hold the 800-line budget (F-8: zero headroom).
- `Apps/Momo/MomoAppModel+Watch.swift:46-69` — NEW `static func loadResetMarkerEraseCount() -> Int` (the D-8 extension-file pattern; static is init-callable before full initialization): derives the directory via `try StoreRules.watchResetMarkerDirectory()` (:63), mirroring the erase site's degraded-path discipline (`+Settings.swift:98-105`): do/catch → `Self.debugLoud` + the same throwaway `Momo-marker-fallback` temp directory, where `load()` naturally returns nil. Degraded semantics unchanged (missing/garbled → 0: no erase pending). The load remains part of the ONE sanctioned synchronous launch read (OBS-1; D-6) — same call site, KB-scale, static hop only.

### F-2 — guard 4 closes the blind spot (the divergence class is unrepeatable)

`Tests/MomoKitTests/Support/WatchWiringScan.swift` — NEW guard 4, `markerDirectoryViolations(files:)`, name `"reset marker → one directory rule"`, every leg on comment-stripped text (`MomoKitDisciplineScan.strippingComments`), D-10 house shape. Predicate (4 legs):

1. `MomoAppModel.swift` (stripped) must route the init's load through `loadResetMarkerEraseCount()`;
2. `MomoAppModel.swift` (stripped) must construct NO `WatchResetMarkerStore(` directly (the sanctioned constructions are the `+Watch` load helper and the `+Settings` erase site — a store-tree load in the init IS F-1);
3. `MomoAppModel+Watch.swift` (stripped) must cite `watchResetMarkerDirectory()` (the launch-load derivation);
4. `MomoAppModel+Settings.swift` (stripped) must cite the same token (the erase-save derivation) — so a future ONE-SIDED edit of either site goes red.

`Tests/MomoKitTests/MomoWatchWiringScanTests.swift` — 7 new tests (suite 14 → 21): both-direction non-vacuity per D-10 (derivation off the rule → red, per site; the F-1 reversion shape in the init → BOTH main legs red, count == 2; a comment-only rule token cannot green EITHER derivation — the stripper refuses fake compliance; green fixture), plus the standing real-tree test "Apps/Momo as it stands loads the reset marker from the same directory rule the erase saves with".

**Bite evidence** (mutation: the helper's derivation flipped to `StoreRules.defaultDirectory()` — the exact F-1 store-tree reversion):

- Full-suite run under the mutation: 995 tests / 100 suites, EXACTLY ONE failure — the new standing test, finding `guardName: "reset marker → one directory rule"`, `file: "MomoAppModel+Watch.swift"`, detail "the launch-load derivation does not cite StoreRules.watchResetMarkerDirectory() — the marker's load and save must share the one directory rule (review F-1)". Nothing else red.
- Hash-captured cycle: before `de900215050e5437…` → mutated `b4a7253b04166d8e…` → restored `de900215050e5437…` (byte-identical; the filtered guard-suite run under this cycle showed the same single red test, 21-run 1 failure).

### §25 honesty notes

- The FIRST bite was applied before the fixed-state hash was snapshotted. The restore was byte-exact by construction (a single-line exact-match Edit and its exact reverse), but the sha256 before==after evidence above comes from a SECOND, properly captured bite cycle on the restored file.
- Two compile errors were introduced and fixed while editing the test file (a duplicated Fixtures section from a bad edit anchor): caught by the first guard-suite run, repaired before any gate was claimed.

### Sync-state convention observation (deliberately OUT of this fix unit, per contract)

`MomoAppModel.swift:387` (`SyncStateStore(directory: directory).load()`) remains consistent with its persist path (`persistWatchSyncState()` reads `storeDirectory` — the same value the init stored at :367) only by CONVENTION, as the reviewer verified; guard 4 deliberately does not reach it (scoped to the marker per the fix contract — covering it structurally would drag in unrelated machinery). Worth a future contract's consideration if/when the D-7 app-target test seam lands.

### Gate numbers (all re-run at the fixed tree)

- `swift test`: **995 tests / 100 suites PASSED** (review baseline 988/100 + 7 new guard-4 tests; no new suite).
- Discipline scans green inside the suite; re-run explicitly: `StoreRulesPinnedTests` 14/14, including "the default directory is Application Support/Momo, created if missing (the one sanctioned ambient-path site)" — the one-applicationSupportDirectory ambient-read pin holds UNAMENDED (the fix derives via the rule; no ambient read added).
- `xcodebuild -project Momo.xcodeproj -scheme Momo -destination 'id=1F25E487-A78E-464C-95AF-0BD1A9B3E1BE' build`: **BUILD SUCCEEDED**. Warnings census: 3 total, all pre-existing project-level noise (`ld: warning: search path '/opt/extra/lib' not found` ×2; AppIntents metadata-processor note) — ZERO warnings from any touched file. (The load site lives in the app target, which `swift test` does not compile — hence the mandatory build.)
- `git diff Sources/MomoCore/`: EMPTY (frozen). `git status --porcelain`: byte-identical FILE SET to the reviewed tree (this fix touched only files already modified/untracked in it) — nothing new appeared.
- Line counts: `MomoAppModel.swift` **800/800** (line-neutral swap); `MomoAppModel+Watch.swift` 193; `MomoWatchWiringScanTests.swift` 371; `WatchWiringScan.swift` 240 — all ≤ budget, functions < 50 lines. §26: no TODO/FIXME/HACK/TEMP in any touched file (grep).

### Final sha256s (full hashes, every file this fix touched)

- `Apps/Momo/MomoAppModel.swift` `ef7d2d5a7efb9bf1ce73bc4c3b1af0a87c5d64a274b9d3f5421e4caba6143ccf` (pre-fix `535b5098cbf917ab…`)
- `Apps/Momo/MomoAppModel+Watch.swift` `de900215050e543725ec4764a01494821c700297ff5809e7f03f7f1885637e2f` (pre-fix `868f8bfec39860c4…`; == the bite-restored hash)
- `Tests/MomoKitTests/MomoWatchWiringScanTests.swift` `620b52d30b139b6888273124f215927c282dde22790b35da5fd4ceb9708a6219` (pre-fix `7697af7f57de0c66…`)
- `Tests/MomoKitTests/Support/WatchWiringScan.swift` `61dc21635fb3243f32ad993e1132f0983152dc70a10878c51e459d0b533fe867` (pre-fix `823274070567fe21…`)
- This task file was also modified (this appendix only; its pre-appendix hash was `16f28d487e889b14…`).

### Fix-unit next step

Orchestrator: delta review of this fix unit only (per REVIEW-TASK-040 §7) → on approval, the single atomic TASK-040 closeout commit (`feat(sync): TASK-040 iPhone-side WC session — context push, intent receive, reset-marker leg`).
