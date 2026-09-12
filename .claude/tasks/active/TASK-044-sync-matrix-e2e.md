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

IN_PROGRESS (dispatched 2026-09-12).

## Implementation Notes

(implementer fills: per-requirement notes, disclosures, D-adjudications, gate numbers, bite records)

## Reviewer Findings

(reviewer fills)

## Completion Evidence

(orchestrator fills at closeout)

## Handoff

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

HANDOFF-COMPLETE TASK-044
