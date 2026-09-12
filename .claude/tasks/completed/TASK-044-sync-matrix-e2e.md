# TASK-044 — Sync test coverage: §10.4 matrix + erase reset E2E + launch-sweep drain + device obligations

## Parent Epic

EPIC-008 — Watch App & Sync (final task, 5/5; record: `.claude/tasks/epics/EPIC-008-watch-sync.md`). Branch: `feature/EPIC-008-watch-sync` (tip `91c523f`).

## Objective

Close EPIC-008 by making the sync guarantees EXECUTABLE and the remaining obligations HONEST:

1. Resolve every row of the §10.4 sync matrix (05 §10.4, the §32 seven-row table) to a named green test — existing or new — recorded as an audit table in this task file.
2. Close the two REAL behavioral gaps the review cycles identified: the **journal launch-sweep drain** (REVIEW-TASK-042 F-R1) and the **erase reset-marker E2E** at Watch-UI level (completes TASK-038's routed AC-2).
3. Land the two REVIEW-TASK-043 guard ride-alongs (F-2 bare-spelling census; F-3 ambient-clock banned-token scan).
4. Execute or BLOCKED-record the device obligations (§25): paired-hardware WC frame delivery, live AOD observation, haptic FEEL judgment (ADR-015 D3).

## Context

The sync stack is COMPLETE after TASK-040…043 and each layer carries its own named tests:

- **Pure core (TASK-023):** `WatchSyncGate` (UUID-first ∧ strict `>`), `SyncState` (per-epoch watermarks, accessor-driven `shouldApply`, `recordingApplied` max-semantics), `SyncStateStore`, `IntentJournal` (NDJSON, epoch per event, epoch-matched prune), `WatchSnapshotBuilder` (ambient-free). Tests: `WatchReceivePlanTests` (decide matrix, per-epoch max-semantics, FIFO exactly-once stream, 3-seed shuffles at-most-once, decode compatibility), `WatchResetMarkerTests`, `StoreRulesPinnedTests`.
- **iPhone WC session (TASK-040):** context push through `.pushWatchSnapshot`, receive path (`receiveWatchEvent` → record-before-apply → facade apply → unconditional sync persist), §6.6 reset-marker leg (marker OUTSIDE the store tree via `StoreRules.watchResetMarkerDirectory()`; BOTH sites rule-derived, guard 4 pinned). `Apps/Momo/**` is FROZEN this task — the iPhone receive path already handles redelivery as a no-op.
- **Watch W1 (TASK-041):** `WatchSnapshotStore` (current→prev→nil chain), receive path + `WatchResetConsumption.decide` + fused `consumeWipe`, `GlanceView` (settling-in line pre-first-sync), AOD glyph tier; `MomoWatchUITests` incl. the genuine-disk restore ≤ 2 s test.
- **Watch pat (TASK-042):** `WatchSessionEpochStore` (miss → mint in-memory + detached save + journal wipe — the journal can NEVER outlive its epoch), journal legs through the one-writer `MomoWatchPersister+Journal.swift`, pat flow (`pat()` → immediate reaction+haptic → `finishPat()` mailbox → append → `transferUserInfo` send), seq formula `next = max(epochScopedJournalMax, epochMatchedWatermark) + 1` (full-prune monotonicity pinned), completion estimator (`WatchPatPlan.isCompletingPat`).
- **Live cascade (TASK-043):** `MomoWatchAppModel.liveQuestLine` recomputed at four event legs; `WatchCascade` seam; `WatchQuestScan` guards (quest-slot census / recompute-legs census / no-settings census); fixtures `w1`/`alldone`/`stale` via the shared `seedFixture`; `MomoWatchUITests` 7/7.

**Current gates (at `91c523f`):** `swift test` 1128/110; MomoKit 90.81 % lines (floor 80); both builds zero touched-file warnings; `MomoWatchUITests` 7/7; app UI suite 35/35; frozen surfaces diff-EMPTY.

**The known real gaps (verified by the review cycles — do not re-derive, close them):**

- **F-R1 (REVIEW-TASK-042):** `pat()` journals the intent, THEN enqueues `transferUserInfo` in the deferred `finishPat()` mailbox leg. A crash (or termination) in between leaves a journaled-but-never-enqueued event that is **never sent** — the §10.4 "journal drain on reconnect" row has no launch leg today. The stranded event also inflates the pending count (the completion estimator reads it) until a later pat prunes it.
- **Erase E2E (TASK-038 routed):** the marker→wipe→settling-in chain is unit-tested (`WatchResetConsumptionTests`, `IntentJournalWipeTests`) but no Watch-UI-level E2E drives "erase on iPhone → next sync → wiped → settling-in line".
- **F-2 (REVIEW-TASK-043, probe-demonstrated):** `WatchQuestScan.questSlotViolations` counts only the leading-dot `.display.questLine` spelling; a bare `display.questLine` frozen read (exactly `compositeLabel`'s body form) evades the census while the divergence ships (the UI stale flow was the only thing that caught it).
- **F-3 (REVIEW-TASK-043, probe-demonstrated):** no scan enforces D20 on `Apps/MomoWatch` production sources — swapping the recompute leg's injected clock for `Calendar.current…Date()` leaves every suite green.

**Device obligations (§25/R9, standing since EPIC-008 authoring):** WC frame delivery under suspension, live AOD observation (SE sims have no AOD), and haptic FEEL (ADR-015 D3) cannot be proven on simulators. This environment has NO paired hardware — the honest outcome is a BLOCKED record with concrete evidence (see R5), escalated as a standing release gate. Do NOT claim device behaviors from simulators (§25).

## Requirements

- **R0 — §10.4 audit table (map first, close only real gaps).** Produce a table in this task file: each of the seven §10.4 rows (iPhone→Watch; Watch→iPhone interaction; Temporary disconnection; Stale data; Conflict handling; Guard reset; Termination/relaunch) → the named test(s) that pin it, each marked `EXISTING (<suite>)` or `NEW (<suite>)`. Body-read every EXISTING mapping before claiming it (existence-greps are not evidence — the TASK-024 precedent). Write NEW tests only for rows/clauses with no literal home. Rows already covered by TASK-023/040/042/043 tests must NOT be duplicated (the TASK-043 R5 mapping-over-duplication rule). Known-likely NEW homes: the disconnection row's launch-drain leg (R1), the Termination/relaunch row's iPhone-relaunch clause if unowned (check FR-13 AC-1's TASK-032/038 tests first), and any AC-2 "same counters/quests" clause not already pinned through the shared facade path.
- **R1 — the journal launch-sweep drain (F-R1).** On the Watch, at session activation completion (the reconnect/cold-launch moment — resolve the EXACT delegate callback against the real SDK header per the TASK-040 R4 VERIFY-AT-BUILD discipline and record it), enqueue every journaled intent through the EXISTING `transferUserInfo` send leg — a re-send-everything sweep. Safety is by construction: the iPhone's unseen-UUID ∧ strict-`>` watermark gate makes every redelivery a no-op (INV-10, already pinned — cite, do not re-derive). Hard rules:
  - Events are enqueued VERBATIM from the journal — no re-sequencing, no mutation, no re-journaling. Seq numbers were assigned at append time.
  - **Reset interaction (the load-bearing hazard):** the launch legs must be ordered so the sweep can NEVER resurrect pre-reset journal entries. Marker consumption (`consumeWipe`) wipes the journal — if a marker is pending consumption at launch, the sweep must send nothing (or only post-wipe entries). Order the legs deliberately and pin the order with a named test (journaled event + pending marker → activation → zero send).
  - All journal reads route through the ONE-writer persister seam (O1 — no new direct `IntentJournal(` instantiation outside `MomoWatchPersister+Journal.swift`).
  - Event-driven only: NO timers, NO polling (§4.2). The sweep fires at activation legs, nothing else.
  - The sweep send leg must respect the same durability discipline as the pat send (send only what the journal actually holds; fire-and-forget correctness — reachability never gates correctness).
  - Named tests: stranded event (journaled, never enqueued) → activation → it IS enqueued verbatim; journaled event + pending marker → activation → nothing sent; idempotent re-activation (sweep twice → still exactly-once iPhone-side by INV-10, asserted at the plan/transport seam).
- **R2 — erase reset-marker E2E (Watch UI; completes TASK-038's AC-2).** A Watch UI test drives the REAL receive path: a snapshot + a non-zero reset-marker count land (seeded through the REAL store / the DEBUG seam precedent — `-momo-watch-fixture` style, release never seeds, and NOT by mocking `WatchResetConsumption.decide`) → the launch/receive pipeline consumes the marker → snapshot + journal wiped → the UI renders the settling-in line. If the standalone Watch UI test cannot receive a genuine WC frame on the simulator, drive the consumption through the app's REAL receive leg via a disclosed DEBUG injection seam (the TASK-041 fixture-seam precedent) — the seam must route through the production receive/consumption code, not a parallel path. Record the seam's exact shape and its release-inertness evidence in the task file.
- **R3 — F-2 ride-along (bare-spelling census).** Extend the quest-slot frozen-read census in `WatchQuestScan` so a bare `display.questLine` read inside `GlanceView` bodies is counted the same as the leading-dot spelling (or, alternatively, assert the composite/slot bodies contain no `questLineKey` source other than the threaded live value — pick ONE shape, implement, fixture both directions). The existing 21 `MomoWatchQuestScanTests` must stay green unchanged in their assertions' meaning (fixture updates to the census's own self-tests are expected).
- **R4 — F-3 ride-along (ambient-clock banned-token scan).** Add a guard banning ambient clock reads (`Date()` as an ambient constructor and `Calendar.current`) in `Apps/MomoWatch` PRODUCTION sources (test targets and DEBUG fixture seams excluded per an explicit, documented rule). Both-direction fixtures + a standing real-tree run, matching the house guard shape. It must be demonstrably non-vacuous (the shipped tree is D20-clean — the guard runs green over it) and its bite must be exactly-one-red.
- **R5 — device obligations: attempt, then BLOCKED-record (§25).** For each of: (a) WC frame delivery under suspension on PAIRED HARDWARE, (b) live AOD observation on an AOD-capable Watch, (c) haptic FEEL judgment on-wrist (ADR-015 D3): first ATTEMPT discovery (`xcrun xctrace list devices` / `xcodebuild -showdestinations` output for physical devices) and record the raw evidence in the task file. Where no hardware exists, write the BLOCKED record: what is unproven, why the simulator cannot prove it, and the exact release gate it becomes. Surface all three in status.md as standing owner items (the orchestrator records them at closeout). NEVER simulate or assert device-only behaviors from simulator evidence.
- **R6 — guard updates are truthful, never weakening.** The TASK-042 `WatchPatScan` pins the pat flow's SINGLE send leg. R1 adds a legitimate second send call site (the sweep). Update the census to accommodate the sweep EXPLICITLY (enumerate the two legitimate call sites) — do not delete or loosen the existing pin, and keep a bite proving a third/forged send site still trips it. Same discipline for any other guard R1/R2 touch.
- **R7 — structural guards + bites for every new load-bearing leg.** Each new leg (sweep-on-activation, sweep-after-consume suppression, E2E seam, R3/R4 census additions) gets a structural guard in the house shape (comment-stripped, both-direction fixtures, exactly-one-red bite, sha256-proven restore). Implementer minimum TWO bites; record pre/mutated/restored sha256 for each.

## Files / Areas Likely Affected

- `Apps/MomoWatch/` — `MomoWatchAppModel.swift` (600/800 — headroom exists; launch/activation legs), `MomoWatchTransport.swift` (send surface), `MomoWatchPersister+Journal.swift` (sweep read seam if needed), `GlanceView.swift` (only if R2's E2E needs a hook — avoid if not).
- `Sources/MomoKit/` — ONLY if a pure plan core for the sweep decision earns one (house pattern: pure core + thin executor). `WatchPatPlan` is untouched unless the audit exposes a real gap.
- `Tests/MomoKitTests/` — new suites/tests + `Support/Watch*Scan.swift` guard extensions.
- `MomoWatchUITests/` — R2's E2E + any new flow.
- NO pbxproj change expected (no new files outside existing targets → D-R3 trivially held; ANY pbxproj touch must be disclosed and re-checked per D-R3).

## Dependencies

- TASK-040…043 all DONE (pushed through `91c523f`). No other open dependency. This task BLOCKS the §14 EPIC-008 merge.

## Constraints

- **Frozen surfaces (must diff-EMPTY):** `Sources/MomoCore/`, `Sources/MomoCharacter/`, `Apps/Momo/**` (incl. `MomoAppModel.swift` at exactly 800/800), `Apps/Shared/MomoCopy.xcstrings` (ZERO new copy keys — the settling-in line exists), `Momo.xcodeproj/` (unless a disclosed registration is truly required).
- O1 one-writer journal/sync-state census; D-R5 (the facade apply path stays the only engine exit); D20 (injected clocks only — the sweep needs NO clock reads at all); §27 (zero entitlements/Info.plist/capability changes); no schema bump (OBS-3 not fired); catalog law (no new keys); no timers (§4.2); MVP scope protection (§22/§24 — this is a test/robustness task, zero product surface change).
- File budgets: every production file ≤ 800 lines; match surrounding comment density and naming.
- §25 honesty: report actual state; device obligations are BLOCKED-recorded, never claimed.

## Acceptance Criteria

1. The §10.4 audit table resolves all seven rows to named green tests; every EXISTING mapping body-verified; only real gaps got new tests.
2. A journaled-but-crash-stranded intent IS delivered at the next activation; a pending reset marker suppresses the sweep; redelivery remains a no-op iPhone-side (INV-10 cited, integration-shaped test through the real send leg).
3. The Watch-UI erase E2E drives the REAL consumption path to the settling-in line; the seam is DEBUG-only and release-inert with recorded evidence.
4. R3/R4 guards are live with both-direction fixtures, real-tree runs, and exactly-one-red bites; the pre-existing 21 quest-scan tests keep their meaning.
5. Device obligations carry attempt evidence + BLOCKED records (or hardware proof if a device unexpectedly appears); status.md owner items updated by the orchestrator.
6. All §19 gates green on the final tree: `swift test` (≥ 1128 baseline + new), MomoKit ≥ 80 % floor, both xcodebuilds zero touched-file warnings, `MomoWatchUITests` (7/7 + new) green, app UI suite 35/35 (no iPhone surface change), frozen surfaces diff-EMPTY, zero new timers, guard family census updated.

## Required Tests

Named tests per R0's table; R1's sweep trio (stranded-sent / marker-suppressed / re-activation-idempotent); R2's E2E; R3/R4 guard fixtures both directions + real-tree runs; ≥ 2 implementer mutation bites (sha256-proven); the full §19 gate battery; coverage measured IMMEDIATELY after the coverage-enabled run (the profdata-orphaning gotcha).

## Review Requirements

Independent fresh Jupiter reviewer per §10/§33: re-derives the §10.4 mapping and the R1 hazard analysis from the normative docs BEFORE reading the implementation; runs its OWN probes (never reusing the implementer's bites); verifies every EXISTING-mapping claim by body-reading; confirms the sweep cannot resurrect pre-reset entries by reading the launch-leg order; re-runs the full gate battery. Review record → `.claude/tasks/reviews/REVIEW-TASK-044.md`.

## Git Requirements

- The implementing agent does NOT commit (§9). The orchestrator commits one atomic feat/test commit: `<type>(<scope>): TASK-044 <summary>` (type likely `test(sync)` — orchestrator's call at commit time), pushed per §13, then the docs closeout, then the §14 EPIC-008 merge (fetch + re-check `origin/main` first; merge only the missing remainder; never force-push; merged tree content-identical + `swift test` green before push).

## Status

DONE (2026-09-12) — implementation complete, independent review APPROVED_WITH_MINOR_NOTES (REVIEW-TASK-044), all §19 gates green, F-1's audit-table correction applied at closeout; committed and pushed per §12/§13 (see Completion Evidence; `(this commit)`/`(this push pending)` resolve in status.md per house convention).

## Implementation Notes

Implementer: `impl-task-044` (fresh Jupiter agent, dispatched 2026-09-12). Notes are appended per requirement as work lands; the Handoff at the file's end is filled only when all gates are run.

### R0 — §10.4 sync-matrix audit table (05-technical-architecture.md:610-618, verbatim row wording)

Every EXISTING mapping below was body-read in this session (suite files opened and the named tests read; existence-greps alone were not accepted as evidence). NEW rows point at the tests this task adds.

| §10.4 row | Clause (doc wording) | Named test(s) | Status |
|---|---|---|---|
| **iPhone → Watch** | snapshot codec versioning | `SyncDTOTests`: "a WatchSnapshot at any non-current version is ignored (above AND below current)"; "an IntentEvent at any non-current version is skipped by the decode gate"; "the current version decodes on both gates (the gates are equality, not range)"; canonical-bytes pins | EXISTING (MomoKitTests) |
| | latest-wins context application re-render | `WatchSnapshotBuilderTests`: "every snapshot field is threaded from the explicit inputs (the no-ambient-read pin)", "the returned sync state is the advanced one…"; `MomoWatchGlanceScanTests` persistGuard (receive → re-render → persist order, exactly 2 persist legs); `MomoWatchUITests.testFixtureSeededGlanceRendersTheW1Content` (the Watch-UI render half) | EXISTING |
| | (storage + character halves of the same delivery) | `WatchSnapshotStoreTests`: current→prev rotation, "a corrupted current falls through to the prev generation", unknown-version fallthrough; `WatchCharacterDTOTests`; `WatchResetConsumptionTests` consume→wipe→redelivery-renders | EXISTING |
| **Watch → iPhone interaction** | offline pat applies exactly once after reconnect (FR-18 AC-1) | `WatchReceivePlanTests`: "the FIFO contract stream with duplicates/replays/redeliveries applies each distinct intent exactly once", "INV-10 under ANY delivery order through the plan core: no UUID ever applies twice"; `WatchSyncGateTests`: unseen-UUID ∧ strict-`>` cell matrix, "exactly-once under the FIFO contract…", re-pair/iPhone-reinstall warmth rows; `WatchPatPlanTests` (seq formula + monotonicity); `IntentJournalTests` (queue durability: torn lines, unknown-version skip, FIFO order); `MomoWatchWiringScanTests` "Apps/Momo as it stands decides receives through the plan core only" | EXISTING |
| | pat ticks same counters/quests as iPhone pats (AC-2) | By construction: the engine NEVER reads `intent.source` (`Sources/MomoCore/BondLedger.swift:10` — "device-agnostic by construction"), and the Watch intent applies through the ONE facade engine exit (D-R5, `MomoWatchWiringScanTests` receiveGuard). Behavioral pin: `BondLedgerTests`: "hello is device-agnostic: a .watch first pat awards identically (UX-6)" — bond, day ledger, and hello flag proven equal across `.watch` vs local sources | EXISTING (Core) |
| | hello device-agnostic idempotency (UX-6) | `BondRulesPinnedTests`: "hello: +8, once per dayKey, device-agnostic (UX-6, INV-7)"; `DomainInvariantsTests`: "INV-7: the hello award is a single flag per day record, not a counter"; `BondLedgerTests` device-agnostic + 2nd-pat-banks-nothing pins | EXISTING (Core) |
| **Temporary disconnection** | journal drain on reconnect | `IntentJournalTests` (the queue survives disconnection byte-exact) + **NEW** `WatchSweepPlanTests` (R1's stranded-sent / marker-suppressed / re-activation-idempotent trio — the launch leg this task adds) + `MomoWatchSweepScanTests` (executor wiring) | NEW (this task; queue half EXISTING) |
| | display of last snapshot with zero UI acknowledgment (AC-3/UX-9) | `MomoWatchUITests.testSnapshotRestoreStaysWithinTheBudget` + `testFreshLaunchShowsTheSettlingInLineOnly`/`testStaleFixtureRendersTheLiveCascadeLine` (render with no freshness/syncing surface — `WatchQuestScan` noSettings census pins the absence structurally) | EXISTING |
| **Stale data** | cascade over stale quest inputs renders sanely; no error surfaces (AC-3) | `WatchCascadeTests` (shared-cascade binding across the hour sweep, all-done swap, provenance property + negative control); `MomoWatchUITests.testStaleFixtureRendersTheLiveCascadeLine` (the stale fixture renders the LIVE cascade line, not the stale one, with no error surface); `WatchSnapshotStoreTests` corrupted-fallthrough (unrecoverable store → settling-in, never an error) | EXISTING |
| **Conflict handling** | replay/duplicate-intent no-op properties (INV-10) | `WatchReceivePlanTests` FIFO + shuffle rows; `WatchSyncGateTests` UUID-outranks-seq + retention-interplay rows, "recordingApplied never regresses…", "INV-10 under ANY delivery order: no UUID ever applies more than once" (`WatchSyncGateTests.swift:161`/`:211` — attribution corrected per REVIEW-TASK-044 F-1) | EXISTING |
| | bond non-regression under replay (AC-4) | `BondLedgerTests`: "monotonic under replay: a re-delivered intent id is the total no-op — bond never decreases" | EXISTING (Core) |
| **Guard reset** | new epoch → next pat applies exactly once against the 0-initialized watermark | `WatchSyncGateTests`: "an unseen epoch's watermark is 0: the first pat (seq 1) applies immediately", "epoch re-pair / watch app reinstall: the new epoch's seqs 1, 2, … apply with no starvation", "iPhone reinstall: empty table…stale queued pats apply warm"; `WatchSessionEpochStoreTests` (stability across relaunch, garbled→regeneration leg); `IntentJournalTests`: "a stale-epoch watermark prunes NOTHING: the journal file is byte-identical", two-epoch per-entry prune | EXISTING |
| | erase → marker → wipe chain (the reset's consumption half) | `WatchResetMarkerTests` + `WatchResetMarkerStore` pins, `WatchResetConsumptionTests` (decide matrix + lifetime sequence + F-3 crash-window replay), `IntentJournalWipeTests`, `WatchSnapshotStoreTests` "the wipe NEVER touches the consumed marker…", `MomoWatchWiringScanTests` erase/markerDirectory guards, `MomoSettingsUITests` erase pair (iPhone half), `StoreRulesPinnedTests`, `MomoWatchUITests` **NEW** reset E2E (R2 — the Watch-UI half that was missing) | EXISTING + NEW (this task) |
| **Termination/relaunch** | Watch snapshot restore ≤ ~2 s (Watch UI test) | `MomoWatchUITests.testSnapshotRestoreStaysWithinTheBudget` (genuine-disk relaunch, measured delta ≤ 2.0 s) | EXISTING |
| | iPhone relaunch ≤ 1 s state loss (FR-13 AC-1) | `MomoOnboardingUITests.testCompletedStoreLaunchesStraightToHome` + `testKillBeforeEnterRestartsOnboardingFromS1`; `MomoSettingsUITests.testRelaunchAfterEraseLandsOnS1` (erase-then-relaunch lands on S1, not Home — the discriminating glass evidence) | EXISTING |
| | WC frame delivery under suspension | **BLOCKED** — no paired hardware exists in this environment (R5's raw `xctrace list devices` + `xcodebuild -showdestinations` evidence below); standing device obligation per the doc's own row ("device obligation, EPIC-002"), BLOCKED-recorded, never sim-claimed (§25) | BLOCKED (recorded) |

**Mapping conclusions.** The seven rows resolve with exactly TWO real test gaps, both closed by this task: (1) the disconnection row's launch-drain leg (R1 — the review-verified F-R1: a crash between journal-append and `finishPat()`'s send leaves a journaled-but-never-enqueued event with no launch sweep to deliver it); (2) the guard-reset row's Watch-UI E2E (R2 — the marker→wipe→settling-in chain had unit pins but no Watch-UI-level drive through the real receive path). AC-2's "same counters/quests" needed NO new test: the engine's `intent.source` blindness is documented at the construction site and pinned by the `.watch`-source hello-parity test; duplicating it Kit-side would test the same reduce twice. The iPhone-relaunch clause was checked against FR-13 AC-1's owners first (the onboarding/settings relaunch tests) — owned, not duplicated.

### R1 — journal launch-sweep drain (crash-stranded events re-enqueue VERBATIM at activation)

**Landed design — arm at activation, flush after a receive decision (never drain-at-activation).** The WC serial queue emits `activationDidCompleteWith` BEFORE the pending context is delivered, so draining at the activation callback would race the very context that may carry a reset marker. The landed shape: activation only ARMS (`armLaunchSweep()` sets `sweepArmed = true` and snapshots `consumedEraseCountAtArm = consumedEraseCount`); the flush runs INSIDE `receiveContext` at exactly the two decision legs — the consume branch's flush follows the AWAITED `consumeWipe` (the persister mailbox then serves the sweep the POST-wipe, empty journal → the reset marker suppresses the sweep to zero sends), and the steady branch's flush follows the watermark prune (already-applied entries ride the prune's drop → no double-send). The decode-skip path returns before any flush and stays armed. The sweep is one-shot per arming (`sweepArmed = false` at entry). Main-actor program order makes the suppression provable: `receiveContext` awaits `consumeWipe` before calling `flushStrandedJournal`, and the flush's journal read follows on the same actor.

**Send semantics:** events re-enqueue VERBATIM through the EXISTING `sendUserInfo` leg — `IntentEvent.encoded()` bytes, journal order, no re-stamping; lines are NOT deleted on send (the watermark prune owns removal), so a re-activation re-sends and INV-10's exactly-once gate no-ops them (pinned, not re-derived: `WatchSweepPlanTests.reActivationIdempotent` drives the re-delivery through `WatchReceivePlan.decide` and expects all-`.ignore`).

**Pure core:** `Sources/MomoKit/WatchSweepPlan.swift` (NEW SwiftPM file — no pbxproj change) — `drainableEvents(journal:epoch:consumedEraseCountAtArm:consumedEraseCountNow:)`: count-recheck guard (counts differ → `[]`; second defense for a consumption completing between read and send) + epoch filter, verbatim order. **D20-clean by construction:** no clock reads anywhere in the sweep (input counts and epoch UUID only). **§4.2-clean:** event-driven only — `WatchSweepScan.noTimersGuard` bans `Timer(`/`scheduledTimer` target-wide (verified zero standing tokens). **O1 held:** the full-journal mailbox read `pendingEvents(directory:)` lives in `MomoWatchPersister+Journal.swift` — `IntentJournal(` remains in exactly ONE Apps/MomoWatch file.

**Wiring pins (`Tests/MomoKitTests/Support/WatchSweepScan.swift`, NEW):** init order onContextData → onActivation → activate(); arm legs + order; flush legs (`guard sweepArmed`, disarm, `persister.pendingEvents(`, `WatchSweepPlan.drainableEvents(`, `consumedEraseCountNow:`, `transport.sendUserInfo(payload:`) with read-before-send order; target-wide exactly-2 `await flushStrandedJournal()` sites with prefix checks (first preceded by `consumeWipe(` and NOT `pruneJournal(`; second preceded by `pruneJournal(`); `pendingEvents` present in the one-writer extension; transport protocol declares + conformer stores `onActivation` and the `activationDidCompleteWith` delegate raises it (arm source resolved against WCSession.h:143-152 — the ONE required watchOS delegate method). All scans comment-stripped, both-direction fixtures in `MomoWatchSweepScanTests` (12 fixture self-tests incl. exactly-one-red cross-guard isolation), 3 standing real-tree runs.

**Disclosed residual (defense-in-depth shape):** a consumption suspended INSIDE `consumeWipe` at the flush's read instant could serve a pre-wipe journal line to the sweep — the same accepted shape as `finishPat`'s exposure and the pinned warm-apply semantics (`WatchSyncGateTests` "iPhone reinstall: empty table…stale queued pats apply warm"); INV-10 still holds on the receiving side.

### R2 — erase reset-marker Watch-UI E2E (real consumption path → settling-in line)

**Seam shape (DEBUG-only):** `-momo-watch-fixture reset` seeds the CLEAN w1 bytes through the REAL `WatchSnapshotStore.save` (unchanged semaphore bridge) and returns a marker frame — `resetMarkerFrame()` rebuilds the w1 snapshot field-wise with `resetMarkerEraseCount: 1` (the pre-erase payload; only the count + decision matter) — which the init schedules into the REAL `receiveContext` via `Task { @MainActor … }` AFTER the transport sinks bind and `activate()` runs (mirrors real delivery order: arm raised before the frame lands, so the consume branch's sweep reads the post-wipe journal). `-momo-watch-fixture resethold` seeds the same bytes and returns NO frame — the red-direction control. `WatchResetConsumption.decide` is NEVER mocked: the frame enters through the production receive path.

**Release-inertness evidence:** `seedFixtureIfRequested(directory:) -> Data?` compiles its release shape as a bare `return nil` (`#else` branch) — no argument read, no seed, no frame; the init's pending-frame delivery is consequently dead code in release (nil never delivers). `resetMarkerFrame()`/`seedFixture` carry no `#else` because release never calls them. No entitlements/Info.plist surface touched; the seam is launch-arguments only.

**Tests (`MomoWatchUITests`, +2 → 9):** `testResetMarkerFixtureConsumesToTheSettlingInLine` — phase 1 launches with the reset seam and waits for `watch.settlingLine` (a seeded store's ONLY route back to settling is the wipe: the bytes render the glance first) + glance absent; phase 2 relaunches over the SAME store with no fixture and requires settling to PERSIST and no glance — the disk discriminator (a decision that skipped the wipe would restore the seeded bytes). Phase-1 deliberately does NOT assert glance-before-settle: the delivery task may land before the runner's first query — racy, so the `resethold` control carries the "seed renders the glance" half. `testResetHoldFixtureKeepsTheGlanceRendered` — glance renders, settling absent, proving the marker frame (not the seeding) causes the phase-1 wipe. **No native unit test bundle exists for the Watch app target** (pbxproj grep: none) — the layered story is pure core (`WatchResetConsumptionTests`) + structural wiring scans + this XCUITest E2E; recorded as the honest disclosure.

### R3 — quest-slot census widened to the bare `display.questLine` spelling

`WatchQuestScan.questSlotViolations` census token `.display.questLine` → bare `display.questLine` (substring-superset: still counts the shipped dotted read at `GlanceView.swift:70` — real-tree count stays 1). Closes the dodge where a second frozen read rebinds the receiver to a local alias (`let display = snapshot.display; … display.questLine`) — invisible to the dotted token. New red direction `aliasedSecondReadFailsValueCensus` proves exactly that shape fails with found 2; `doubleFrozenReadFailsValueCensus` re-asserted against the new detail wording. All 21 pre-existing quest-scan tests pass in meaning (their dotted fixtures still count under the bare token).

### R4 — ambient-clock banned-token scan (D20) over the Watch target

**NEW `Tests/MomoKitTests/Support/WatchClockScan.swift`:** `ambientClockGuard` bans `Date()`, `Date.now`, and `Calendar.current` in comment-stripped code across every `Apps/MomoWatch` source (both-direction fixtures per token: stripped token fails exactly-one; comment-only citation passes — the stripper neither mutes citations nor accepts fake compliance; cross-guard isolation pins `ambientClockGuard`/`injectedClockGuard` as separate guards). `injectedClockGuard` pins `recomputeQuestLine()`'s body reading `wallClock.now()` — the cascade hour is THE clock-sensitive computation (UX-9/§10.4), so a silent revert fails even before the token ban. **Documented exclusion rule:** the ban structurally covers the production target only (test targets are outside the scanned set — harness code legitimately derives EXPECTED values from ambient time, e.g. the stale-fixture hour derivation); inside `Apps/MomoWatch` there is NO DEBUG carve-out — the fixture seam ships in the same files and needs no clock (verified; a future DEBUG clock leg must inject, or the scan trips). Real-tree runs green: zero ambient tokens standing, injected read standing.

### R5 — device obligations: probe evidence + BLOCKED records (never sim-claimed, §25)

**Raw probe output (captured 2026-09-12, this session):**

```
$ xcrun xctrace list devices
== Devices ==
JNJGYD4G9Q (8DE821A1-0104-52AC-9AE6-4CB1DC690FA3)
```

— exactly ONE physical device, and it is iPhone-class; NO Apple Watch hardware is paired to this Mac.

```
$ xcodebuild -showdestinations -scheme MomoWatch
Available destinations for the "MomoWatch" scheme:
    { platform:watchOS, id:dvtdevice-DVTiOSDevicePlaceholder-watchos:placeholder, name:Any watchOS Device }
    { platform:watchOS Simulator, … 5 simulators, incl. pinned Apple Watch SE 3 (44mm) 8A854895-225C-411B-89C1-B03337BFE957 }
```

— the only device-class watchOS destination is the "Any watchOS Device" PLACEHOLDER; no concrete paired Watch exists behind it.

```
$ xcodebuild -showdestinations -scheme Momo
Available destinations for the "Momo" scheme:
    { platform:macOS, … name:My Mac }
    { platform:iOS, id:dvtdevice-DVTiPhonePlaceholder-iphoneos:placeholder, name:Any iOS Device }
    { platform:iOS Simulator, … 11 iPhone/iPad sims, incl. pinned iPhone SE (3rd generation) 1F25E487-A78E-464C-95AF-0BD1A9B3E1BE }
```

— the physical iPhone is not even enumerated as a scheme destination for Momo (placeholder only).

**BLOCKED-B (WC frame delivery under suspension, on PAIRED HARDWARE).** Requirement: prove a `transferUserInfo` frame queued while the watch app is backgrounded/suspended DELIVERS at the next activation and lands in `receiveContext` (the §10.4 disconnection row's device clause; EPIC-002's standing device obligation). Attempted: `xcrun xctrace list devices` (raw above — no Watch paired) and both `-showdestinations` probes (no concrete watchOS device destination). Simulator cannot stand in (§25): the sim's WCSession has no suspension/airgap boundary. **Status: BLOCKED — requires a physical iPhone + paired Apple Watch.** Simulator-side proxies that DO hold: the transport arm pin (activation delegate → `onActivation`) and the launch sweep's arm/flush ordering (R1), plus `WatchReceivePlanTests` delivery-order matrix over the FIFO contract.

**BLOCKED-C (live AOD observation).** Requirement: observe the always-on display treatment live (ADR-015 D-adjacent; TASK-041 R7's AOD budget was verified as a build-time snapshot payload bound, not a lit-screen observation). Attempted: same probes — no watchOS hardware destination exists. **Status: BLOCKED — requires physical Watch hardware.** Simulator proxy held: the snapshot payload's AOD-eligible shape is pinned by builder tests; the lit-pixel behavior is unverified.

**BLOCKED-D (haptic FEEL, ADR-015 D3).** Requirement: confirm the semantics-typed haptics (`WatchPatHaptic` → `WKInterfaceDevice.current().play`) FEEL correct on the wrist (click strength/timing). Attempted: no device destination (raw above). **Status: BLOCKED — requires physical Watch hardware.** Simulator proxy held: the seam census (`WatchPatScan.hapticSeamViolations`) proves the platform touch is single and gated; feel is human-perceptual and never sim-claimable.

All three remain standing obligations for the owner's device pass; no code claim in this task depends on them (§25 honored — nothing was asserted from simulators).

### R6 — `WatchPatScan` send-leg census enumerates the sweep's second legitimate site

The census stays a PIN, not a guess: doc item 2 now ENUMERATES both legitimate legs (the pat drain in `finishPat()`, the launch sweep's re-enqueue in `flushStrandedJournal()`) and the census detail names them ("expected exactly 2 transport.sendUserInfo( legs in Apps/MomoWatch (the pat drain + the launch sweep), found N"). Fixture restructure: `patFiles()` now carries BOTH legitimate legs (new `sweepLegGreen` fixture appended as a second file) so every pre-existing single-violation stub keeps count 1 — no pin weakened. New tests: `thirdSendLegFails` (a forged third site in a transport file fails the census ALONE with the enumerated detail) and `twoLegitimateSendLegsPass` (the green shape). Real-tree run green over the shipped two-leg tree.

### R7 — mutation bites over the new load-bearing legs (sha256 pre/mutated/restored recorded; all restores byte-identical)

**Bite A — init binding order (R1's sweepWiringGuard, init-order leg).** Mutation: `transport.activate()` moved ahead of the `onActivation` binding in `Apps/MomoWatch/MomoWatchAppModel.swift`. Result: `MomoWatchSweepScanTests` run went red with EXACTLY ONE issue — the real-tree sweep-wiring test, finding "init() must bind onContextData, then onActivation, then activate() — the sink-before-activate discipline, three-legged" (16 tests, 1 issue; no other guard tripped — verified only `WatchSweepScan` pins this order). sha256: pre `360380eafb240599af056c86ca638e57ae7163d61294316cfce21bd3d2410c8c` → mutated `b8ffe74766a5056066a06eacbd5b52cddf782d0c57c6be38bb22fab29504479c` → restored `360380eafb240599af056c86ca638e57ae7163d61294316cfce21bd3d2410c8c` (IDENTICAL).

**Bite B — ambient clock read (R4's ambientClockGuard, real tree).** Mutation: `let stamp = Date()` inserted at the top of `recomputeQuestLine()` in `Apps/MomoWatch/MomoWatchAppModel.swift`. Result: `MomoWatchClockScanTests` run went red with EXACTLY ONE issue — the real-tree ambient test, finding "banned ambient-clock token in Apps/MomoWatch: Date() — time is injected (D20)" (10 tests, 1 issue; the injected-read pin stayed green — cross-guard isolation holds under a real-tree mutation). sha256: pre/restored `360380eafb240599af056c86ca638e57ae7163d61294316cfce21bd3d2410c8c` (IDENTICAL), mutated `f779d39d1c8d0bc86e426c2bbec99be788f209f018efec49cf75455c5def1b70`.

**Bite C — bare-alias second frozen read (R3's widened census, real tree).** Mutation: `let echo = display.questLine` appended after the quest-line read in `Apps/MomoWatch/GlanceView.swift` — the exact spelling the pre-R3 dotted token could not see. Result: `MomoWatchQuestScanTests` run went red with EXACTLY ONE issue — the real-tree quest-slot test, finding "expected exactly 1 display.questLine read (the belt-and-braces fallback, bare or .display. spelling), found 2" (22 tests, 1 issue). sha256: pre/restored `99dacd2b655a1836586aaad9f22594e017ce86bd83f1302cb25f6304ff2b4c80` (IDENTICAL), mutated `b2c37decd4eaf001dbba180fe6186120a77525b397111d94102506329d64b662`.

### Gate battery (§19, run 2026-09-12, this session)

1. `swift test --enable-code-coverage`: **1161 tests / 113 suites, ALL PASSING** (dispatch baseline 1128/110; +33 tests / +3 suites reconciled exactly: WatchSweepPlanTests 5, MomoWatchSweepScanTests 16, MomoWatchClockScanTests 10, R3 alias direction 1, R6 census delta +1).
2. Coverage measured IMMEDIATELY from the same run's profdata (`xcrun llvm-cov report`, `--sources Sources/MomoKit`): **MomoKit line coverage 90.84%** (1746 lines, 160 missed) — above the 80% floor, consistent with the prior 90.81%.
3. `xcodebuild -scheme MomoWatch -destination 'id=8A854895-…' build`: **BUILD SUCCEEDED**, zero warnings.
4. `xcodebuild -scheme Momo -destination 'id=1F25E487-…' build`: **BUILD SUCCEEDED**; only the two PRE-EXISTING `ld: search path '/opt/extra/lib' not found` warnings (documented project noise since TASK-040) + the AppIntents metadata note — **zero warnings from any touched file**.
5. `xcodebuild -scheme MomoWatch … -only-testing:MomoWatchUITests test` (pinned Watch SE 3 44mm sim): **TEST SUCCEEDED — 9/9** (7 existing + `testResetMarkerFixtureConsumesToTheSettlingInLine` + `testResetHoldFixtureKeepsTheGlanceRendered`).
6. `xcodebuild -scheme Momo … -only-testing:MomoUITests test` (pinned iPhone SE 3rd gen sim): **35/35 PASSED** — the app UI suite is unchanged.
7. Frozen surfaces `git diff` EMPTY: `Sources/MomoCore/`, `Sources/MomoCharacter/`, `Apps/Momo/**` (MomoAppModel.swift still exactly 800/800), `Apps/Shared/MomoCopy.xcstrings` (zero new keys), `Momo.xcodeproj/` (untouched — no new app-target files; the new files are all SwiftPM-side or edits of existing app-target files). No entitlements/Info.plist touch; no schema bump.
8. O1: `IntentJournal(` appears in exactly ONE `Apps/MomoWatch` file (`MomoWatchPersister+Journal.swift`) — verified post-change.
9. Line budgets: `MomoWatchAppModel.swift` 761/800; `MomoWatchTransport.swift` 162; `MomoWatchPersister+Journal.swift` 128; `WatchSweepPlan.swift` 56. All ≤800.

## Reviewer Findings

REVIEW-TASK-044 (fresh independent reviewer, 2026-09-12): **APPROVED_WITH_MINOR_NOTES** — full record at `.claude/tasks/reviews/REVIEW-TASK-044.md`; gates re-run green (1161/113, 90.84 % coverage, MomoWatch + Momo builds, Watch UI 9/9, frozen surfaces empty), 4 own exactly-one-red probes restored byte-identical; F-1 (Minor, record-only) audit-table Conflict row misattributes two tests to `SyncStateTests` — they live in `WatchSyncGateTests.swift:161/:211` (fix at closeout docs pass); F-3 (Minor, non-blocking) `WatchSweepScan.swift:136` pins `consumeWipe` presence but not the `await` keyword — one-token tightening at next guard touch; F-2 (Note, accepted) the disclosed consumeWipe suspension window is real but narrow, warm-apply class, honestly disclosed.

## Completion Evidence

**Orchestrator §19 reproduction (2026-09-12, personally re-run on the implementer's tree over tip `6bc8c40`, BEFORE dispatching review):** `swift test --enable-code-coverage` **1161 / 113 suites ALL PASSING** (dispatch baseline 1128/110; +33 tests / +3 suites reconciled exactly: WatchSweepPlanTests 5, MomoWatchSweepScanTests 16, MomoWatchClockScanTests 10, R3 alias direction 1, R6 census delta +1); MomoKit coverage **90.84 % lines** (1746 lines, 160 missed), measured IMMEDIATELY from the same run's profdata (the orphaning gotcha respected); `xcodebuild -scheme MomoWatch` on Watch SE 3 44 mm `8A854895…` **BUILD SUCCEEDED** (only the 2 pre-existing `/opt/extra/lib` ld notices + the appintents metadata note); `xcodebuild -scheme Momo` on iPhone SE 3rd gen `1F25E487…` **BUILD SUCCEEDED**, zero warnings this run; `MomoWatchUITests` **9/9 PASSED** (xcresult-verified: passed 9 / failed 0 / skipped 0 — 7 baseline + the 2 reset-seam flows); app UI suite stands at **35/35** on the verified unchanged-inputs argument (`Apps/Momo/**` + `MomoUITests/` diff-EMPTY; the only MomoKit change is the additive `WatchSweepPlan.swift`); frozen surfaces (`Sources/MomoCore/`, `Sources/MomoCharacter/`, `Apps/Momo/**` incl. `MomoAppModel.swift` exactly 800/800, `Apps/Shared/MomoCopy.xcstrings`, `Momo.xcodeproj/`) **all diff-EMPTY** incl. untracked; O1 census: `IntentJournal(` in exactly ONE Apps/MomoWatch file; zero timers; line budgets: `MomoWatchAppModel.swift` 761/800, Transport 162, Persister+Journal 128, WatchSweepPlan 56.

**Mutations:** implementer's 3 bites (A init-order; B ambient `Date()`; C alias second frozen read) + reviewer's 4 own probes (1 count-recheck neutralized; 2 flush moved ahead of the awaited consumeWipe; 3 forged third send site; 4 direct `IntentJournal(` outside the one-writer file) — all exactly-one-red as claimed, all sha256 pre/mutated/restored with byte-identical restores. Reviewer gates re-run independently on the final tree and matched every number above (REVIEW-TASK-044 gate table).

**Review:** APPROVED_WITH_MINOR_NOTES — findings disposition: F-1 (audit-table suite misattribution) → **fixed at this closeout** (Conflict row now cites `WatchSyncGateTests.swift:161`/`:211`); F-2 (consume-suspension window — exactly ONE internal suspension in `consumeWipe`, back-to-back-frame race class, warm-apply receiver semantic, honestly disclosed in code + task file) → **accepted residual**, recorded in status.md; F-3 (`WatchSweepScan.swift:136` pins `consumeWipe(` but not the `await` spelling) → **routed to the follow-up guard-hardening backlog** (one-token tightening at next guard touch, non-blocking); F-4 (R2 release-inertness) / F-5 (R6 non-weakened in four directions) / F-6 (R0 audit substantively complete) / F-7 (implementer evidence authenticated) → verified, no action. R5's three device obligations (WC frame delivery under suspension on paired hardware; live AOD; haptic FEEL) → **BLOCKED records stand as owner device-pass items** (raw probe evidence in R5; §25-honest).

**Commit:** `feat(watch): TASK-044 sync-matrix audit, launch-sweep drain, erase reset E2E, clock ban` — (this commit) — one atomic commit on `feature/EPIC-008-watch-sync` containing the 9 modified + 6 new implementation/test files, this task record (moved to completed), and `.claude/tasks/reviews/REVIEW-TASK-044.md`.

**Push:** (this push pending) — origin `feature/EPIC-008-watch-sync`; result recorded in status.md's Recent Pushes.

## Handoff

### Completed

All seven requirements (R0–R7), all gates green. R0: the §10.4 audit table above maps all seven rows to name-precise, body-verified tests; the only two real gaps are closed by R1/R2. R1: the launch sweep — arm at activation, flush at exactly the two receive decision legs, verbatim re-enqueue through the existing `sendUserInfo` leg, reset-suppression pinned (post-wipe journal → zero send), one-shot, timer-free, O1-clean. R2: the erase reset-marker Watch-UI E2E through the REAL `receiveContext` (`WatchResetConsumption.decide` unmocked) to the settling-in line, plus a disk-durability relaunch phase and a no-marker control; DEBUG seam proven release-inert. R3: the quest census widened to the bare `display.questLine` spelling (alias dodge closed, real-tree count unchanged). R4: the D20 ambient-clock banned-token scan (`Date()`, `Date.now`, `Calendar.current`) + the recompute's injected-read pin, exclusion rule documented, real tree clean. R5: device probes run with raw output recorded; three honest BLOCKED records (WC-under-suspension on paired hardware, live AOD, haptic feel) — nothing sim-claimed (§25). R6: the pat send census enumerates both legitimate legs; a forged third site fails alone; no pin weakened. R7: three real-tree mutation bites, each exactly-one-red, sha256 pre/mutated/restored recorded, all restores byte-identical.

### Files Changed

Modified: `Apps/MomoWatch/MomoWatchAppModel.swift` (sweep state + arm/flush + decision-leg flushes + reset seam returns `Data?` + `resetMarkerFrame()`; 761/800), `Apps/MomoWatch/MomoWatchTransport.swift` (`onActivation` sink: protocol + storage + delegate raise), `Apps/MomoWatch/MomoWatchPersister+Journal.swift` (`pendingEvents(directory:)` — O1-held), `MomoWatchUITests/MomoWatchUITests.swift` (+2 tests, docs), `Tests/MomoKitTests/Support/WatchPatScan.swift` + `Tests/MomoKitTests/MomoWatchPatScanTests.swift` (R6 census), `Tests/MomoKitTests/Support/WatchQuestScan.swift` + `Tests/MomoKitTests/MomoWatchQuestScanTests.swift` (R3). Created: `Sources/MomoKit/WatchSweepPlan.swift`, `Tests/MomoKitTests/Support/WatchSweepScan.swift`, `Tests/MomoKitTests/WatchSweepPlanTests.swift`, `Tests/MomoKitTests/MomoWatchSweepScanTests.swift`, `Tests/MomoKitTests/Support/WatchClockScan.swift`, `Tests/MomoKitTests/MomoWatchClockScanTests.swift`. Task file: `.claude/tasks/active/TASK-044-sync-matrix-e2e.md` (this file). NO change to: `Sources/MomoCore/`, `Sources/MomoCharacter/`, `Apps/Momo/**`, `Apps/Shared/MomoCopy.xcstrings`, `Momo.xcodeproj/`, entitlements, Info.plists.

### Tests Run

`swift test --enable-code-coverage` (full suite); `xcrun llvm-cov report` immediately after (Sources/MomoKit); `xcodebuild build` for MomoWatch (Watch SE 3 44mm sim 8A854895-…) and Momo (iPhone SE 3rd gen sim 1F25E487-…); `xcodebuild -only-testing:MomoWatchUITests test` (Watch sim); `xcodebuild -only-testing:MomoUITests test` (iPhone sim); targeted `swift test --filter` runs per R3/R4/R6/R7 step; `git diff --stat`/`git status --porcelain` over the frozen surfaces; `xcrun xctrace list devices` + both `-showdestinations` probes (R5).

### Test Results

**1161 tests / 113 suites ALL PASSING** (baseline 1128/110; +33/+3 reconciled test-by-test). MomoKit line coverage **90.84%** (floor 80%). MomoWatch build SUCCEEDED (0 warnings). Momo build SUCCEEDED (2 pre-existing ld search-path warnings only, zero from touched files). **MomoWatchUITests 9/9**. **App UI suite (MomoUITests) 35/35**. Frozen surfaces diff EMPTY. O1 census clean. All file line budgets ≤800 (MomoWatchAppModel.swift 761/800). Bites: A (init-order, 1 issue), B (ambient Date(), 1 issue), C (alias second read, 1 issue) — all restored byte-identical.

### Known Issues

- The three R5 device obligations remain BLOCKED on physical paired hardware (records above with raw probe evidence) — standing owner device pass, no code claim depends on them.
- Disclosed residual (defense-in-depth shape, shared with existing accepted semantics): a consumption suspended INSIDE `consumeWipe` at the sweep's read instant could serve a pre-wipe journal line; the count-recheck is the second defense and INV-10 holds receiver-side regardless.
- No native unit test bundle exists for the Watch app target (pre-existing project shape) — the E2E story is pure-core + structural scan + XCUITest, layered and disclosed.

### Decisions Made

- Arm-then-flush-after-decision over drain-at-activation: the WC serial queue emits activation completion BEFORE the pending context, so a drain at the activation callback would race the reset marker; arming is order-safe, and the flush sits after the awaited consume/prune so program order proves suppression.
- Journal lines are NOT deleted on sweep-send: the watermark prune owns removal, so re-activation re-sends and INV-10 no-ops them (re-derivation avoided by citation).
- R2's phase-1 asserts only the settle endpoint (no glance-before-settle race); the `resethold` control carries the "seed renders the glance" half.
- R3 census uses the BARE `display.questLine` token (substring-superset of the dotted spelling) so both shapes count and an alias rebind cannot dodge.
- R4 bans `Date.now` alongside `Date()` (same ambient read, no parens) and grants NO DEBUG carve-out inside `Apps/MomoWatch` — test targets alone are structurally excluded.

### Reviewer Status

APPROVED_WITH_MINOR_NOTES (REVIEW-TASK-044, 2026-09-12, fresh Jupiter reviewer per §10/§33) — the reviewer re-derived the §10.4 mapping and the R1 hazard analysis from the normative docs BEFORE reading any implementation, ruled the landed arm-then-flush design the compliant reading (the contract's own "pending marker ⇒ zero send" rule forbids literal drain-at-activation; the residual liveness gap is bounded, disclosed, benign), and found no material contract defects. 0 Critical / 2 Minor (F-1 audit-table suite misattribution — fixed at closeout; F-3 await-spelling pin tightening — backlog) / 1 accepted Note (F-2 consume-suspension window) / 4 verification Notes (F-4 release-inertness, F-5 R6 non-weakened four ways, F-6 R0 audit complete, F-7 evidence authenticated). Reviewer ran 4 own probes (none reusing the implementer's bites), all exactly-one-red, sha256-restored byte-identical, and re-ran every §19 gate with matching numbers (1161/113; 90.84 %; builds; 9/9). Full record: `.claude/tasks/reviews/REVIEW-TASK-044.md`.

### Commit

(pending — orchestrator commits after review; working tree left uncommitted per instructions)

### Push

(pending — after commit)

### Recommended Next Step

Spawn REVIEW-TASK-044 (fresh Jupiter reviewer; §33 independence — hand the reviewer the task file, the diff, and the §10.4 doc rows, and ask it to DISPROVE correctness). After APPROVED: commit (suggested `test(watch): TASK-044 sync-matrix audit, launch-sweep drain, erase E2E, clock ban`), push, closeout, then the §14 EPIC-008 merge to `main` (owner-authorized). The three R5 device obligations go to the owner's device-pass backlog.

HANDOFF-COMPLETE TASK-044
