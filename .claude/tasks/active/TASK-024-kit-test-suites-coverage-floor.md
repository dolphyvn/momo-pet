# TASK-024 — MomoKit suite audit: §32 persistence + §10.4 sync-matrix Kit rows + ≥ 80 % coverage floor (05 §10.2, §10.4; delivery plan TASK-024)

## Parent Epic
EPIC-005 — Persistence & Sync Logic (MomoKit), task 4 of 4 (size M) — the EPIC CLOSER. Epic acceptance criteria served: AC-6 (MomoKit ≥ 80 % line coverage recorded) plus the audit that AC-1–AC-5's claims each resolve to a named, actually-green test. Follows the TASK-020 precedent (Core's matrix audit + coverage floor) applied to Kit.

## Objective
Close EPIC-005's test obligations (05 §10.2; delivery-plan TASK-024 row):
1. **§32 Persistence matrix audit (project.md §32 rows: save/load, migration, corruption/recovery):** every row resolves to named, green tests in `MomoKitTests` — with the audit's adversarial standard: a named test COUNTS only if reading it shows it actually pins that row's clause (a test that touches the area without pinning the clause does not count — find or write the one that does).
2. **§10.4 sync-matrix Kit-share audit (05 §10.4):** each row's KIT portion maps to named green tests; each row's non-Kit portion (Watch UI test, UI tests, device obligations) is explicitly routed to its owning epic (EPIC-008 / UI-test epics / EPIC-002 VERIFY-AT-BUILD) in the audit table — routed, never silently dropped.
3. **MomoKit ≥ 80 % line coverage floor, measured and recorded (05 §10.2):** llvm-cov recipe, per-file table over the 10 production files, TOTAL recorded; if below floor, close with named tests and re-measure.

**This is an AUDIT-and-floor task, not a rewrite.** TASK-020's finding stands: existing coverage is extensive — the implementer's first job is a VERIFIED GAP ANALYSIS. Expect to write few or zero new tests; every new test must close a named gap from the audit tables, never pad the percentage.

## Context
- **Codebase state:** TASK-023 complete (`9109457`). MomoKit production surface = EXACTLY 10 files: `SnapshotStore`, `StoreRules`, `LedgerRetention`, `MigrationChain`, `SyncDTOs` (`WatchSnapshot`/`IntentEvent`), `IntentJournal`, `SyncState`, `SyncStateStore`, `WatchSnapshotBuilder`, `WatchSyncGate`. Baseline `swift test` = **515 tests / 54 suites green** @ `9109457`.
- **Coverage recipe (TASK-010/TASK-020 precedent, works on this toolchain):**
  `swift test --enable-code-coverage`
  `xcrun llvm-cov report .build/arm64-apple-macosx/debug/MomoPackageTests.xctest/Contents/MacOS/MomoPackageTests -instr-profile .build/debug/codecov/default.profdata`
  (xccov CANNOT read SwiftPM's raw profdata — use llvm-cov directly. Filter to the `Sources/MomoKit` rows.)
- **Precedent for the record:** TASK-020's Completion Evidence carries the per-file table verbatim + TOTAL + exact command + the exact closing-test names for any gap. Mirror that format for Kit. TASK-020's Core TOTAL was 97.68 % — Kit need not match Core's number; it must clear **80 %**.
- **Where the matrix rows already live (audit STARTING points, verify each — do not take this list on faith):**
  - save/load roundtrip, corruption/generation recovery, torn-write windows, concurrency pins → `SnapshotStoreTests`, `SnapshotStoreConcurrencyTests`, `SnapshotStoreGoldenBytesTests`
  - migration (chain walk, missing hop, above-head, corrupt-below-current-never-migrates, fresh-vs-upgrade parity shape) → `MigrationChainTests` + SnapshotStore's version-gate tests; **check whether an explicit NFR-7 fresh-vs-upgrade parity test exists** — if not, that is a REAL gap (epic AC-3: "upgrade path produces identical engine-visible state to a fresh install seeded with the same history")
  - retention/prune determinism, caps → `LedgerRetentionTests` (+ `StoreRulesPinnedTests` pins)
  - codec versioning (DTO round-trips, unknown-version gates), journal (torn line, epoch-matched prune), watermark arithmetic (INV-10 exactly-once property, epoch reset, stale epoch), sync-state durability → the TASK-023 suites
- **Known likely gaps to evaluate (candidates, not conclusions — verify before acting):** an NFR-7 fresh-vs-upgrade parity pin (above); the golden-bytes test being excluded from a coverage run is EXPECTED (it runs out-of-process recording only at authoring time) — do not chase its lines; `assertionFailure`/`print` DEBUG-loud paths are legitimately unexercisable and get a noted reason per TASK-020's format.
- **Kit discipline:** any new test file follows the house conventions (`@Test`/`#expect`, injected directories, no ambient reads, fixtures in `Support/`); the standing scans (`MomoKitDisciplineScanTests`) must stay green with NO new exemptions; no `Sources/MomoCore/` changes; production diff expected EMPTY — any production touch is a DISCLOSURE with justification.

## Requirements
1. **Audit table 1 — §32 Persistence rows:** for each of save/load, migration, corruption/recovery: the clause restated from the docs, the named green test(s) that pin it, and the pin verification (one line: what would break if the clause regressed). Gaps close with named tests.
2. **Audit table 2 — §10.4 sync matrix, all seven rows:** per row, the KIT-share mapping (named green tests) AND the explicit routing of the non-Kit share (owning epic). The seven rows: iPhone→Watch; Watch→iPhone interaction; temporary disconnection; stale data; conflict handling; guard reset; termination/relaunch. Note: several rows' Kit-share is exactly the TASK-023 gate/journal/codec suites — the audit must confirm the named tests pin the row's CLAUSE (e.g. "offline pat applies exactly once after reconnect" is the INV-10 exactly-once property + journal-drain, not merely a gate unit test).
3. **Coverage floor:** run the llvm-cov recipe; produce the per-file table for the 10 MomoKit files + Kit TOTAL; if TOTAL < 80 %, write the named closing tests, re-run, and report the closing set; record command + table + TOTAL in Completion Evidence. Note every file's deliberately-unexercisable lines with reasons.
4. **No scope creep:** no transport, no UI, no engine changes, no MomoCore changes, no new production code unless a gap genuinely requires it (then DISCLOSURE + justification). No schemaVersion bumps. Do not weaken or delete existing tests to move the number — that is a BLOCKED-level finding.
5. **Suite hygiene:** final `swift test` green ×2 with zero warnings; record exact counts; suite runtime stays bounded (no new unbounded loops; any property test is seeded and bounded per house discipline).

## Files / Areas Likely Affected
- Mostly NOTHING in production; possibly NEW `Tests/MomoKitTests/` files for named gap closures (e.g. an NFR-7 parity test) and small additions to existing suites.
- This task file (audit tables in Implementation Notes, coverage table in Completion Evidence).
- NOT affected: `Sources/MomoKit/` (expected diff EMPTY), `Sources/MomoCore/` (must stay EMPTY), docs.

## Dependencies
- TASK-021…023 (all landed on `feature/EPIC-005-persistence`).

## Constraints
- Fresh agent, Jupiter, no commit rights; house 200–400-line file discipline for any new test file; scans green, no new exemptions; baseline count pinned at dispatch by the orchestrator.
- The coverage run is EVIDENCE, not a test — the reviewer reproduces the command and compares tables.

## Acceptance Criteria
1. Audit table 1 complete: all three §32 persistence rows → named green tests, gaps (if any) closed and named.
2. Audit table 2 complete: all seven §10.4 rows → Kit-share mapping + non-Kit routing, nothing silently dropped.
3. MomoKit line coverage ≥ 80 % measured via the llvm-cov recipe; per-file table + TOTAL + exact command recorded; any gap closed with named tests.
4. Final `swift test` green ×2, zero warnings, standing scans green with no new exemptions.
5. Production diff EMPTY (or disclosed + justified); `Sources/MomoCore/` diff EMPTY.

## Required Tests
- The audit's closing tests (only those the gap analysis justifies — expected: an NFR-7 fresh-vs-upgrade parity pin if genuinely absent).
- The coverage measurement run (llvm-cov) with the recorded table.

## Review Requirements
- Independent fresh reviewer (CLAUDE.md §10/§33), adversarial, unprimed:
  - Re-derive BOTH audit tables from 05 §10.4 / project.md §32 and the doc clauses BEFORE comparing to the implementer's tables; name any clause the tables miss or map to a test that does not actually pin it.
  - Re-run the llvm-cov coverage command; compare the per-file table and TOTAL; reject any table that cannot be reproduced.
  - Mutation-bite the audit's central claim: pick ONE audit-mapped clause, apply a small mutation to the production code it pins, and verify the named test ACTUALLY fails (the audit counts only if the mapping is executable truth). Restore byte-identical (record the sha256 before/after).
  - Verify the suite is green ×2 and the scans carry no new exemptions.
  - Verify `git diff` scope: production EMPTY-or-disclosed, MomoCore EMPTY.
  - Review file: `.claude/tasks/reviews/REVIEW-TASK-024.md`.

## Git Requirements
- No commit by the implementation agent. Orchestrator commits after review disposition: `test(kit): TASK-024 MomoKit suite audit, §10.4 mapping, coverage floor` — atomic, TASK-ID included.
- This is the EPIC-005 closer: after this task's housekeeping, the epic merges to `main` per CLAUDE.md §14 (owner-authorized, no PR; `git fetch` + check `origin/main` FIRST; merge only the remainder; never force-push).

## Status
REVIEWED — implementation complete 2026-09-09 by the fresh TASK-024 agent (Jupiter); Reviewer Status **APPROVED_WITH_MINOR_NOTES** (REVIEW-TASK-024, 2026-09-09: 0 MAJOR / 1 MINOR / 0 NITPICK / 3 OBSERVATIONs). **MINOR-1's prose correction APPLIED** (both overclaiming NFR-7 verification sentences narrowed to the populated fields, with the OBS-3 standing obligation recorded inline); OBS-1 routed via status.md; OBS-3 recorded as a standing obligation; full disposition in REVIEW-TASK-024 §8. Commit authorized. Was READY — contract materialized by the orchestration agent from 05 §10.2/§10.4, project.md §32, the delivery-plan TASK-024 row (docs/product/06-delivery-plan.md:91), the TASK-010 coverage recipe, and the TASK-020 audit precedent. Baseline count pinned at dispatch.

## Implementation Notes
Implemented 2026-09-09 by the fresh TASK-024 agent (Jupiter), branch `feature/EPIC-005-persistence` @ `9baa49d`, uncommitted (working tree left DIRTY for the orchestrator; nothing staged). Method: audit first, verify every named test's body, measure, close only what the audit names. **Zero new tests written; zero production changes; the audit found the candidate NFR-7 gap to be ALREADY PINNED (evaluation below).** Baseline 515/54 → final **515 tests / 54 suites green ×2** (delta 0/0 — no test added, none weakened, none deleted).

### Audit table 1 — project.md §32 Persistence rows → named green tests

Legend: every named test was READ, not just existence-grepped; the pin-verification line states what regresses if the clause breaks. All tests green in the final runs.

**Row: save/load** — clause (§32 "save/load"; 05 §5.2): pet state faithfully persisted per engine event — encode payload → checksum → temp → atomic rename → generational demotion; read = envelope decode → version gate → checksum re-verify → payload decode; writes serialized, total order.

| Clause element | Named green test(s) | Suite file | Pin verification (what breaks if the clause regresses) |
|---|---|---|---|
| Save→load fidelity, full closure over `EngineState` | `populatedStateRoundtripsExactly`; case-parameterized `wakefulnessCaseRoundtrips` / `activityCaseRoundtrips` / `satietyPhaseCaseRoundtrips` / `handshakeKindCaseRoundtrips` / `greetingKindCaseRoundtrips` / `bondStageCaseRoundtrips`; closure completeness `persistedEnumCasePinsAreComplete` + `populatedFixtureReachesEveryQuestCase` | SnapshotStoreTests.swift | A new persisted field/enum case left out of the Codable closure fails the compile-pinned case-set pins; an aliased/dropped field fails the exact-equality roundtrip. |
| Envelope contract (`schemaVersion` 1, checksum = recipe, `savedAt` = injected clock, exact key set) | `envelopeCarriesSchemaVersionOne`, `envelopeChecksumEqualsRecomputedRecipe` (recipe re-derived independently of store helpers), `envelopeSavedAtEqualsInjectedClock`, `envelopeKeySetIsExactlyTheSpecShape` | SnapshotStoreTests.swift | A checksum-recipe change, an added/renamed envelope key, or a non-injected clock fails the corresponding pin byte-precisely (`envelopeChecksumEqualsRecomputedRecipe` recomputes SHA-256 over the payload JSON itself). |
| Generational chain (demotion order) | `firstSaveLeavesASingleGeneration`, `secondSaveLeavesATwoGenerationChain`, `threeSavesLeaveTheFullDemotedChain` | SnapshotStoreTests.swift | A demotion-order swap serves the wrong generation in the chain pins. |
| Write-through per event, serialized, NO save lost | `concurrentSavesConvergeToAConsistentChain` (24 saves → savedAt EXACT adjacency base+23/22/21 on the chain), `loadsRacingSavesObserveOnlyCompleteGenerations` (128 saves → current envelope at base+127) | SnapshotStoreConcurrencyTests.swift | A silently frozen/skipping store shifts the adjacency arithmetic and fails — the TASK-021 flake-fix pins make "any permutation, but ALL saves landed" executable. |
| Retention enforced on the write path only | `savePrunesBeforeEncode` (on-disk envelope satisfies both caps), `loadDoesNotPrune` (oversized valid generation served whole) | LedgerRetentionTests.swift | A store that stops pruning fails the on-disk caps; a read path that prunes fails `loadDoesNotPrune`. |
| Canonical bytes | `sameStateSavesAreByteStableExceptSavedAt`; `StoreRulesPinnedTests` (all constants raw-pinned) | SnapshotStoreTests.swift / StoreRulesPinnedTests.swift | Encoder `.sortedKeys` removal or constant drift fails byte-stability / the raw pins. |

**Row: migration** — clause (§32 "migration"; 05 §5.5): breaking changes bump `schemaVersion` and register explicit `migrate(v→v+1)`; the read path walks the chain; missing hop / above-head unreadable; migrations pure and total; unit-tested in BOTH directions — fresh-install path and upgrade path produce identical behavior afterwards; migration invisible to the user.

| Clause element | Named green test(s) | Suite file | Pin verification |
|---|---|---|---|
| Chain walk (below-current serves through the chain) | `singleHopWalkMigratesBelowCurrentGeneration` (store-level v0 → current through the public API); `multiHopWalkAppliesStepsInOrder` (order-SENSITIVE name-append marker, unit level); `currentVersionServesWithoutTouchingTheChain` (inert step at current) | MigrationChainTests.swift | Out-of-order application fails the order-sensitive marker; a walk that touches current-version payloads fails the inert-step pin. |
| Missing hop / above head ⇒ unreadable (never half-migrated) | `missingStepMakesBelowCurrentGenerationUnreadable`, `missingStepHalfwayThroughMultiHopWalkIsUnreadable`, `aboveHeadVersionIsUnreadableEvenWithStepsRegistered`, `walkAboveHeadIsNilAtTheUnitLevel`, `emptyChainCannotReadBelowCurrent`; store-level above-head: `generationAboveTheChainHeadIsSkippedToPrev`, `versionsAboveTheChainHeadEverywhereReturnFallback` | MigrationChainTests.swift / SnapshotStoreTests.swift | A walk that applies steps past a gap fails the mid-walk pin; decoding an above-head version fails both above-head pins (falls to prev/fallback instead). |
| Gate ORDER: checksum precedes the walk | `corruptChecksumBelowCurrentNeverMigrates` + negative control `validChecksumBelowCurrentDoesMigrate` | MigrationChainTests.swift | Swapping the gates (migrate before checksum) fails the corrupt-checksum pin — the negative control proves the step itself was live. |
| Purity / value semantics / determinism | `walkIsPureOnItsInput`, `identityRangeIsTheStateItself`, `theChainIsValueDataStoresAreIndependent`, `duplicateFromKeepsTheFirstDeclaredStep` | MigrationChainTests.swift | A mutating step fails the purity pin; a global registry fails the chain-is-value pin; last-wins duplicate handling fails the first-declared pin. |
| **BOTH directions — fresh-install ≡ upgrade (NFR-7 / epic AC-3)** | `migratedStateEqualsTheFreshlyBuiltState` (mechanism parity: `chain.migrated(v0 history) ==` the fresh-built state as WHOLE `Equatable` values) + `migratedStateRepersistsAtCurrentVersion` (identical behavior AFTERWARDS: re-persists at the current version with a fresh checksum, loads chain-independently from a plain store) + `singleHopWalkMigratesBelowCurrentGeneration` (upgrade path through disk bytes serves exactly the fresh-equivalent state) + the roundtrip matrix (fresh-path fidelity) | MigrationChainTests.swift | A migration that drops or defaults any POPULATED carried field — the days ledger, settings (true/true), pet identity, `highestCelebratedStage`, the open/evaluate stamps, and the PetState dimensions — fails the whole-value parity pin; a post-migration save that doesn't stamp the current version fails the re-persistence pin. **[Orchestrator disposition per REVIEW-TASK-024 MINOR-1: the parity fixture carries `processedIntents: []`, `pendingHandshake: nil`, `lastGreeting: nil` (StoreFixture.swift:210–215), so the pin has NO teeth over those fields through the walk — they gain coverage only via the fresh-path roundtrip matrix over `populatedState()`. OBS-3 standing obligation: when a real schemaVersion bump ships, the parity fixture must carry a populated belt/handshake/greeting through the walk.]** **See the NFR-7 gap evaluation below — this clause was the dispatch's named gap candidate; it is PINNED, not a gap.** |

**Row: corruption/recovery assumptions** — clause (§32 "corruption/recovery assumptions"; 05 §5.3): read tries `state.json` → checksum+decode → `.prev` → `.prev2` → fresh default; caller-visible behavior always "a state", never an error; worst case ≤ last snapshot interval (1 event); torn-write windows never lose a complete generation.

| Clause element | Named green test(s) | Suite file | Pin verification |
|---|---|---|---|
| Per-mode recovery (truncated / garbage / empty / checksum mismatch / all-lost / no directory) | `truncatedCurrentFallsBackToPrev`, `garbageCurrentFallsBackToPrev`, `emptyCurrentFallsBackToPrev`, `checksumMismatchFallsBackToPrev` (digest of a DIFFERENT payload — isolates the checksum gate from the decode gate), `allGenerationsCorruptedReturnsFallback`, `missingDirectoryReturnsFallback` | SnapshotStoreTests.swift | An error surface, a mixed state, or a served corrupt generation fails the mode pins (each asserts the EXACT serving generation + never-throws). |
| Survivors never damaged; loads never write | `corruptingOneGenerationLeavesSurvivorsIntact` (byte-identical survivors at every stage) | SnapshotStoreTests.swift | A load path that repairs/rewrites fails the byte-identity assertion. |
| Torn-write / crash windows (every intermediate loads a valid state) | `crashWindowCurrentPlusStalePrev2`, `crashWindowAfterPrevDemotion`, `crashWindowAfterCurrentDemotion`, `crashWindowOrphanedTempIsIgnored`, `crashWindowOnlyOldestSurvivorServes` (intermediate filesystems constructed directly) | SnapshotStoreTests.swift | A write path that opens a loss window (e.g. remove-then-move, wrong demotion order) fails the window intermediates. |
| Out-of-process byte agreement (the recipe survives process boundaries; tamper refused by the GATE) | `recordedOutOfProcessGenerationLoadsThroughThePublicAPI`, `recordedChecksumIsTheRecipeOverTheRecordedPayload`, `aTamperedPayloadByteFallsThroughToTheFallback` (length-preserving tamper — the checksum, not the decoder, must refuse) | SnapshotStoreGoldenBytesTests.swift | Recipe/encoder drift fails the re-derivation pin; a gate that trusts unverified bytes serves the tampered generation and fails the tamper pin. |
| No torn state ever served under concurrency | `loadsRacingSavesObserveOnlyCompleteGenerations` (every load = fallback or a complete savable state) | SnapshotStoreConcurrencyTests.swift | A non-atomic commit fails the never-torn membership pin. |

### Audit table 2 — 05 §10.4 sync matrix, all seven rows: KIT share → named tests; non-Kit share → owning epic (routed, never dropped)

**Row 1 — iPhone → Watch** ("snapshot codec versioning; latest-wins context application re-render — Kit tests + Watch UI test")
- KIT: codec versioning → `SyncDTOTests`: `watchSnapshotRoundtripsExactly`, `unknownSnapshotVersionIsIgnored` (×3 — the equality gate), `currentVersionDecodes`, `encodingIsByteStable`, `snapshotCanonicalBytesPinned`, `garbageBytesDecodeToNil`; payload construction → `WatchSnapshotBuilderTests`: `fieldsThreadFromExplicitInputs` (every field incl. `lastAppliedIntentSeq`/`lastAppliedEpoch` threading; wrong-epoch watermark would fail), `repeatedBuildsConsumeMonotoneSeqs` + `emptySyncStateYieldsDefinedOrigin` (each push is a strictly-newer snapshot — the iPhone half of latest-wins), `buildsAreDeterministic`. Pin: a codec that mis-decodes a CURRENT-version snapshot fails the roundtrip/canonical pins; a version-gate regression fails `unknownSnapshotVersionIsIgnored`.
- Non-Kit routed: "latest-wins context application + re-render" on the Watch (replace-stored-snapshot-never-queue, §5.6 Watch store + re-render) → **EPIC-008 Watch UI test**; `updateApplicationContext` delivery semantics/coalescing → **EPIC-002 VERIFY-AT-BUILD**.

**Row 2 — Watch → iPhone interaction** ("offline pat applies exactly once after reconnect (FR-18 AC-1); pat ticks same counters/quests as iPhone pats (AC-2); hello device-agnostic idempotency (UX-6) — Core + Kit")
- KIT: exactly-once delivery arithmetic → `WatchSyncGateTests`: `exactlyOnceUnderFIFOWithDuplicatesReplaysRedeliveries` (FIFO batch + immediate duplicate of every event + out-of-order replay + FULL redelivery ⇒ each distinct pat applied exactly once in order; whole-stream second pass = 0 applications — this is the INV-10 exactly-once property the contract's row clause names), `atMostOnceUnderShuffledDelivery` (3 seeded shuffles of the doubled multiset — no UUID ever double-applies); queue durability → `IntentJournalTests.appendThenParseRoundtripsInOrder`, `appendCreatesMissingDirectory`; watermark bookkeeping → `recordingAppliedAdvancesWatermark`, `recordingAppliedNeverRegresses`. Pin: a gate that double-applies under duplicate delivery fails the exactly-once stream pin (applied list diverges from the distinct list); a watermark regression reopens replays and fails `recordingAppliedNeverRegresses` + the shuffle property.
- Non-Kit routed: AC-2 (same counters/quests as iPhone pats) + UX-6 (hello device-agnostic idempotency) are ENGINE intent-application semantics → **EPIC-004 (landed; verified in tree)**: `DomainInvariantsTests.inv10IntentIdempotencyKey`, `BondLedgerTests.monotonicUnderReplay`; `transferUserInfo` transport reliability → **EPIC-008** wiring + **EPIC-002** device obligations.

**Row 3 — Temporary disconnection** ("journal drain on reconnect; display of last snapshot with zero UI acknowledgment — Kit + Watch UI")
- KIT: the drain's mechanics — the queue survives the disconnected window (`appendThenParseRoundtripsInOrder`; `tornTrailingLineIsSkipped`, `appendAfterTearPreservesTheNewEvent`, `midFileGarbageLineIsSkipped`, `blankLinesAreIgnored`, `unknownVersionLineIsSkipped`) and drains exactly per the epoch-matched watermark: `pruneBoundaryIsInclusive` (≤ dropped exactly, boundary pinned both sides), `twoEpochJournalPrunesOnlyMatchingEpoch`, `staleEpochWatermarkPrunesNothing` (byte-identical file), `epochIdentityHeldAcrossPrune`, `matchedPruneByteShape`, `pruneLeavesNoTemp`, `purePruneCoreIsTotal`, `absentJournalIsEmptyAndStaysAbsent`. Pin: a prune boundary flip (`<` vs `≤`) fails `pruneBoundaryIsInclusive`; a stale-epoch wipe fails the byte-identical pin. (Applied-exactly-once-then-pruned is the row-2 gate property COMPOSED with these prune pins.)
- Non-Kit routed: "display of last snapshot with zero UI acknowledgment" (AC-3/UX-9 — no staleness/syncing UI exists anywhere) → **EPIC-008 Watch UI test** (absence-of-UI is a view-audit obligation, not headlessly testable).

**Row 4 — Stale data** ("cascade over stale quest inputs renders sanely; no error surfaces (AC-3) — Core")
- KIT (carry-only share): stale inputs reach the cascade UNCHANGED → `WatchSnapshotBuilderTests.fieldsThreadFromExplicitInputs` (questInputs verbatim), `SyncDTOTests.questLineCaseRoundtrips` (×8), `attributionSurvivesVerbatim`. Pin: a builder that mutates/drops questInputs fails the field-threading pin; a codec that loses a QuestLine case fails the ×8 roundtrip.
- Non-Kit routed: "renders sanely, no error surfaces" over stale inputs = cascade TOTALITY → **EPIC-004 (landed)**: `QuestCascadeTests.cascadeIsTotalOverEveryHour` (+ `sixRuleTable`, `cascadeTwins` — defined selection for every input); Watch display side → **EPIC-008**.

**Row 5 — Conflict handling** ("structural argument (§6.5) verified by replay/duplicate-intent no-op properties (INV-10); bond non-regression under replay (AC-4) — Core")
- KIT (the delivery-seam enforcement of the structural argument): `WatchSyncGateTests.duplicateUUIDIsNoOpEvenWithHigherSeq` (UUID outranks seq — a hostile resend cannot double-apply), `replayedSeqIsNoOpEvenWhenUUIDUnseen` (retention interplay), `boundarySeqEqualsWatermarkIsNoOp` (strictly-greater `>`), `bothGuardsPassApplies`; plus row 2's INV-10 properties. Pin: removing the UUID guard fails `duplicateUUIDIsNoOpEvenWithHigherSeq`; swapping guard order fails the same pin; `>` → `>=` fails `boundarySeqEqualsWatermarkIsNoOp`.
- Non-Kit routed: bond non-regression under replay (AC-4) → **EPIC-004 (landed)**: `BondLedgerTests.monotonicUnderReplay`; the structural argument itself is architecture (05 §6.5 — commutative additive intents + single-writer derivation, no code exists to test); its enforceable halves are the properties mapped here and in row 2.

**Row 6 — Guard reset** ("new `watchSessionEpoch` — re-pair / reinstall / new Watch: next pat applies exactly once against the 0-initialized watermark; stale-epoch snapshot watermark never prunes the new journal — Core + Kit")
- KIT: 0-init accessor → `SyncStateTests.unseenEpochReadsZero` (read does not mutate); reset without starvation → `WatchSyncGateTests.epochResetAppliesWithoutStarvation` (new epoch's seqs 1…3 apply; old watermark untouched) + `freshEpochAppliesAtSeqOne` + `staleEpochWatermarkNeverGates`; iPhone reinstall → `iPhoneReinstallAppliesWarm`; stale-epoch watermark never prunes → `IntentJournalTests.staleEpochWatermarkPrunesNothing` + `twoEpochJournalPrunesOnlyMatchingEpoch` + `epochIdentityHeldAcrossPrune`; table durability across relaunch → `SyncStateTests.recordedWatermarkSurvivesRePersistence`, `multiEpochStateRoundtripsThroughStore`, `secondSaveOverExistingFileLands`. Pin: a nonzero default watermark fails `unseenEpochReadsZero` AND `epochResetAppliesWithoutStarvation` (starvation returns); removing the prune's epoch-match condition fails the byte-identical stale-epoch pin.
- Non-Kit routed: epoch GENERATION/persistence on the Watch (§5.6) → **EPIC-008**; engine-side UUID belt → **EPIC-004 (landed)** (`inv10IntentIdempotencyKey`); system-wipe re-pair mechanics → **EPIC-002 VERIFY-AT-BUILD**.

**Row 7 — Termination/relaunch** ("Watch snapshot restore ≤ ~2 s measured in Watch UI test; iPhone relaunch ≤ 1 s state loss (FR-13 AC-1) — UI tests; WC frame delivery under suspension = device obligation, EPIC-002")
- KIT (the persistence primitives that make relaunch lossless): iPhone state — every save lands (savedAt-adjacency pins, `SnapshotStoreConcurrencyTests`) + the full recovery matrix (table 1 row 3) so a mid-save termination loses ≤ 1 event and serves a valid state; sync bookkeeping — `SyncStateTests.recordedWatermarkSurvivesRePersistence` (watermark survives relaunch — INV-10's cross-launch half), `absentFileLoadsFresh`/`garbledFileLoadsFresh` (defined fresh state, never throws), `persistedBytesArePlainJSON`, `saveLeavesNoTempBehind`, `secondSaveOverExistingFileLands` (the TASK-023 fix-loop regression pin — the second save after relaunch LANDS); journal — append durability + tear tolerance (row 3). Pin: a save that doesn't land fails the adjacency arithmetic; a watermark lost on relaunch fails `recordedWatermarkSurvivesRePersistence`.
- Non-Kit routed: Watch snapshot restore ≤ ~2 s → **EPIC-008 Watch UI test** (timing cannot be measured headlessly — §25: never claimed from unit tests); iPhone end-to-end relaunch ≤ 1 s → **EPIC-007 UI tests**; WC frame delivery under suspension → **EPIC-002 device obligation (VERIFY-AT-BUILD)**.

**Nothing silently dropped:** every one of the seven rows carries both an explicit KIT mapping and an explicit non-Kit routing; §10.5's "Upgrade" edge (fresh vs upgrade parity, NFR-7 — Kit) is audited in table 1's migration row and the evaluation below.

### NFR-7 fresh-vs-upgrade parity — gap evaluation (the dispatch's named candidate): NOT a gap, verified

The contract asked me to verify whether an explicit NFR-7 parity pin exists (epic AC-3: "upgrade path produces identical engine-visible state to a fresh install seeded with the same history"). **It exists, and it pins the clause.** `MigrationChainTests.migratedStateEqualsTheFreshlyBuiltState` (line 291; test string names "NFR-7 parity" verbatim) was authored by TASK-022 for exactly this clause. I read its body adversarially for circularity: it asserts `chain.migrated(fixture.state(bond: 5), from: 0, to: current) == fixture.state(bond: 42)` — the fixture builder is the only fresh-state constructor, and the v0 payload IS the same history at bond 5, so the comparison is "post-migration state ≡ fresh-built state with the same history" as WHOLE `Equatable` values. The migration step (`replacing(bond:in:)`) rebuilds the state field-by-field, so a migration that dropped or defaulted any POPULATED carried field (the days ledger, settings, pet identity, the open/evaluate stamps, the PetState dimensions) would fail the equality — the pin is not vacuous. *[Narrowed per REVIEW-TASK-024 MINOR-1: the parity fixture carries `processedIntents: []` and `nil` handshake/greeting, so those fields have no teeth through the walk — covered only by the fresh-path roundtrip matrix over `populatedState()`; OBS-3 obliges populating them when a real migration ships.]* The AC-3 clause's full store-level shape is then completed by composition: `singleHopWalkMigratesBelowCurrentGeneration` (the upgrade path through real envelope bytes → version gate → checksum → decode → migrate serves exactly the fresh-equivalent state via the public API), `migratedStateRepersistsAtCurrentVersion` ("identical behavior afterwards": the migrated state re-persists at the current version and loads chain-independently from a plain store — the upgrade leaves no trace), and the roundtrip matrix (fresh-path fidelity). **Verdict: AC-3 resolves to four named green tests; no new test written — a fifth would restate the composition and pad the count, which the contract forbids.**

### Coverage floor (deliverable 3): TOTAL 88.86 % lines — floor ≥ 80 % MET; no closing tests required

Command (verbatim; the trailing path filters rows to MomoKit production sources; the report must be REGENERATED after any plain `swift test` — an uninstrumented rebuild invalidates the profdata, TASK-020's recorded caveat):

```
swift test --enable-code-coverage
xcrun llvm-cov report .build/arm64-apple-macosx/debug/MomoPackageTests.xctest/Contents/MacOS/MomoPackageTests -instr-profile .build/debug/codecov/default.profdata Sources/MomoKit
```

**TOTAL: 691 lines, 77 missed → 88.86 % lines (325 regions 90.77 %, 69 functions 91.30 %). The ≥ 80 % floor is met.** The table reproduced IDENTICALLY across two instrumented runs (pre- and post-warning-fix), so no TASK-020-style bimodality affects these totals.

Per-file table (verbatim from the final instrumented run):

```
Filename                       Regions    Missed Regions     Cover   Functions  Missed Functions  Executed       Lines      Missed Lines     Cover
----------------------------------------------------------------------------------------------------------------------------------------
SyncDTOs.swift                     162                 8    95.06%          20                 0   100.00%         252                20    92.06%
LedgerRetention.swift                5                 0   100.00%           3                 0   100.00%          42                 0   100.00%
WatchSyncGate.swift                  3                 0   100.00%           1                 0   100.00%          10                 0   100.00%
IntentJournal.swift                 52                11    78.85%          12                 2    83.33%         131                28    78.63%
MigrationChain.swift                13                 0   100.00%           5                 0   100.00%          26                 0   100.00%
SyncStateStore.swift                28                 4    85.71%           7                 2    71.43%          53                12    77.36%
StoreRules.swift                     7                 2    71.43%           2                 0   100.00%          16                 1    93.75%
SnapshotStore.swift                 48                 5    89.58%          12                 2    83.33%         122                16    86.89%
SyncState.swift                      6                 0   100.00%           6                 0   100.00%          27                 0   100.00%
WatchSnapshotBuilder.swift           1                 0   100.00%           1                 0   100.00%          12                 0   100.00%
----------------------------------------------------------------------------------------------------------------------------------------
TOTAL                              325                30    90.77%          69                 6    91.30%         691                77    88.86%
```

All 77 missed lines inventoried from `llvm-cov show` (line-level), classified per TASK-020's format:

- **DEBUG-loud invariant-regression arms, unexercisable by construction (crash the DEBUG test process)** — `debugLoudFailure` + `assertionFailure` bodies and their encode-guard callers: SnapshotStore.swift 214–218 + 361–365, SyncStateStore.swift 68–71 + 109–113, IntentJournal.swift 81–85 + 185–186 + 219–223. House DEBUG-loud/release-safe pattern (mirrors TASK-020's noted `assertionFailure` guards); exercising them means crashing the suite.
- **I/O-failure catch arms, not exercised because the house harness has no fault-injecting FileManager** (release behavior documented in-line: keep last-known-good / journal as-is / previous sync state): SnapshotStore.swift 243–249, SyncStateStore.swift 89–92, IntentJournal.swift 102–107 + 207–210.
- **SyncDTOs.swift 147–150, 315–318, 420–423, 428–431, 443–446 (20 lines)** — the decode-refusal `throw DecodingError.dataCorruptedError` arms for unknown enum raw values (QuestID, intent source, pat gesture, touch zone, kind shape). Exercisable in principle (a well-formed JSON carrying an unknown enum string), but the defined refusal behavior they implement — `decoded → nil → skip` — is pinned at every entry point (`garbageBytesDecodeToNil` for both DTOs; journal `midFileGarbageLineIsSkipped` / `unknownVersionLineIsSkipped`); no doc clause names per-arm behavior. Left unpinned under the no-padding rule; recorded here for the reviewer.
- **IntentJournal.swift 172–178 (7 lines)** — the survivor-free prune's file-removal + catch (the header-documented "removes the file entirely when nothing survives" shape). Exercisable (prune a matched journal past its highest seq), but below any doc clause's altitude: with zero survivors `events() == []` either way, and the absence invariant is pinned by `absentJournalIsEmptyAndStaysAbsent`. Exercisable residual, accepted.
- **StoreRules.swift 137 (1 line)** — the create-if-missing arm of `defaultDirectory()`. Environment-conditional: this host already has `~/Library/Application Support/Momo` (created by earlier runs of the pinned test), so the branch no longer executes here; it runs on a fresh host, and `StoreRulesPinnedTests.defaultDirectory()` asserts the returned URL exists either way.

### Suite health + run history (honest)

- Baseline @ `9baa49d` (pre-work): `swift test` → **515 tests / 54 suites passed** (0.560 s). Green first try — no test-expectation mistakes occurred (no new tests were written), so there was no failed first run to disclose.
- After the one-line warning fix (the only edit): run 1 → **515/54 passed** (0.499 s), run 2 → **515/54 passed** (0.550 s) — the contract's ×2, zero compiler warnings, zero failures, zero skips.
- Final instrumented run (`swift test --enable-code-coverage`): **515/54 passed** (0.656 s); the full-recompile warning census shows the ONLY warning is the pre-existing environmental `ld: warning: search path '/opt/extra/lib' not found` (machine-level, not repo content, documented since TASK-021).
- Standing discipline scans ran IN-SUITE and green (ambient-time, ambient-path, import whitelist); **zero new exemptions** — the one-line edit touches no scan surface.
- Observation for the record: the pre-existing `EngineClockTests.swift:46` var-never-mutated compiler warning (recorded by TASK-021) did NOT reproduce in any run today, including the full instrumented recompile. It lives in `MomoCoreTests` (outside this task's boundary); nothing done about it here.

### Disclosures

1. **One test-file edit (the only diff): `Tests/MomoKitTests/SnapshotStoreGoldenBytesTests.swift` (2 insertions / 2 deletions).** A PRE-EXISTING compiler warning (introduced with the file at TASK-022's commit `3acc54f`; not visible in TASK-023's incremental builds, re-emitted by today's instrumented full recompile): `'#[require(_:_:)]' is redundant because 'try JSONDecoder().decode' …` at line 72. Fix: `let envelope = try #require(try JSONDecoder().decode(...))` → `let envelope = try JSONDecoder().decode(...)` — behavior-identical (`decode` throws into the `throws` test; `#require` wrapped a non-optional). Justification: the warning sat in `MomoKitTests` — this task's exact audit scope — and Requirement 5 demands zero warnings; unlike TASK-021's routed `EngineClockTests` warning, this one is inside the boundary this task owns. Verified: the final instrumented full recompile is warning-free.
2. **Production diff EMPTY** (`git diff Sources/MomoKit/` = 0 bytes) and **`git diff Sources/MomoCore/` = 0 bytes** (verified). No schemaVersion bump, no exemption added, no TODO/FIXME/HACK/TEMP markers added, no doc changes.
3. No defect was exposed by the audit — nothing fixed in production, no pin weakened, no test deleted.

### Design decisions

1. **Audit-and-floor, literally:** the verified gap analysis found every §32 persistence clause and every §10.4 Kit share already pinned by named green tests from TASK-021–023 (plus the EPIC-004 Core halves for the routed shares). The expected NFR-7 gap was verified PRESENT (pinned). Writing zero new tests is the honest outcome, not an omission — the contract's own standard ("every new test must close a named gap … never pad") names no gap to close.
2. **Per-line inventory instead of hand-waving the residuals:** every one of the 77 missed lines is classified above with a reason, so the reviewer can mutation-bite the table's claims without re-deriving the classification.
3. **Non-Kit routing made explicit per row** (EPIC-008 / EPIC-007 / EPIC-002 / EPIC-004-landed) so the sync matrix's obligations are traceable without this task file after the epic merges.

## Handoff (§28)

### Completed
- Audit table 1: all three §32 persistence rows → named green tests with pin-verification lines (above).
- Audit table 2: all seven §10.4 sync-matrix rows → Kit-share test mappings + explicit non-Kit routing (EPIC-008/007/002/004) — nothing silently dropped.
- NFR-7 gap candidate evaluated and resolved: PINNED already (`migratedStateEqualsTheFreshlyBuiltState` + three composing pins); no new test.
- Coverage floor measured and recorded: MomoKit TOTAL 88.86 % lines ≥ 80 % — command, per-file table, and all-77-missed-line classification recorded; no closing tests required.
- Suite hygiene: 515/54 green ×2, zero compiler warnings (only the environmental `ld` note), scans green with zero new exemptions.

### Files Changed
- MODIFIED `Tests/MomoKitTests/SnapshotStoreGoldenBytesTests.swift` (2+/2− — the pre-existing-warning fix; Disclosure 1).
- MODIFIED this task file (Status / Implementation Notes / Handoff / Completion Evidence).
- NOTHING else. `git diff Sources/MomoKit/` = 0 bytes; `git diff Sources/MomoCore/` = 0 bytes; no new files.

### Tests Run
`swift test` (baseline @ `9baa49d`, then ×2 post-fix); `swift test --enable-code-coverage` + the llvm-cov report command (twice — table reproduced identically); per-file `llvm-cov show` for the missed-line inventory.

### Test Results
**515 tests / 54 suites PASSED** on every run (baseline, ×2 final, instrumented); 0 failures, 0 skips; zero new compiler warnings; coverage TOTAL 88.86 % lines.

### Known Issues
None open. (Environmental `ld /opt/extra/lib` note pre-exists and is not repo content; the TASK-021-recorded `EngineClockTests.swift:46` warning did not reproduce today — observation recorded, file outside this task's boundary.)

### Decisions Made
Zero new tests (audit verified the suites pin every clause; NFR-7 already pinned); one-line pre-existing-warning fix inside this task's audit scope, disclosed; all 77 missed coverage lines classified with reasons; no production or MomoCore changes.

### Reviewer Status
PENDING — no review has occurred. Review file: `.claude/tasks/reviews/REVIEW-TASK-024.md`.

### Commit
(None by the implementation agent per contract.) Orchestrator, after review disposition: `test(kit): TASK-024 MomoKit suite audit, §10.4 mapping, coverage floor`.

### Push
Not applicable yet — orchestrator pushes after the atomic commit (branch `feature/EPIC-005-persistence`).

### Recommended Next Step
Spawn the independent REVIEW-TASK-024 agent (adversarial, unprimed: re-derive both audit tables from the docs FIRST; re-run the llvm-cov command and compare the table; mutation-bite ONE audit-mapped clause with byte-identical restore; verify 515/54 ×2 and empty production/MomoCore diffs).

## Completion Evidence
Implementation-agent entries (2026-09-09; orchestrator disposition entries pending):

- Test command + counts: `swift test` → **"Test run with 515 tests in 54 suites passed after 0.499 seconds."** (run 1) and **"… passed after 0.550 seconds."** (run 2) — the contract's ×2; baseline @ `9baa49d` identical at 515/54; zero failures/skips on every run today.
- Coverage: llvm-cov **TOTAL 88.86 % lines** (90.77 % regions, 91.30 % functions) — exact command + full per-file table + all-77-missed-line classification in Implementation Notes above; the reviewer reproduces the command and compares the table (it reproduced identically across two instrumented runs).
- Diff scope: `git diff --stat` = exactly `Tests/MomoKitTests/SnapshotStoreGoldenBytesTests.swift | 2 ++--` (Disclosure 1); `git diff Sources/MomoCore/` = 0 bytes; `git diff Sources/MomoKit/` = 0 bytes; tree DIRTY, nothing staged or committed.
- Commit hash: (pending orchestrator — atomic commit with TASK-ID per Git Requirements; this is the EPIC-005 closer, after which the epic merges to `main` per CLAUDE.md §14).

## Reviewer Findings
**REVIEW-TASK-024 — APPROVED_WITH_MINOR_NOTES** (independent fresh adversarial reviewer, 2026-09-09; full record: `.claude/tasks/reviews/REVIEW-TASK-024.md`). 0 MAJOR / 1 MINOR / 0 NITPICK / 3 OBSERVATIONs.

- **Both audit tables re-derived independently from 05 §10.4 / project.md §32 / §5.2–§5.5 / §6.1–§6.6 BEFORE comparison: no clause missed, no mapping found pointing at a test that fails to pin its clause** (bodies read, not existence-grepped: SnapshotStoreTests, MigrationChainTests, SnapshotStoreConcurrencyTests, WatchSyncGateTests, StoreFixture in full; targeted bodies across SyncDTO/Builder/SyncState/Journal suites; routed Core pins spot-read). Non-Kit routings all explicit and correctly owned; nothing silently dropped.
- **Coverage reproduced digit-for-digit:** llvm-cov TOTAL 691/77 = **88.86 % lines** (90.77 % regions, 91.30 % functions), every per-file row matching; missed-line classifications spot-verified live (SnapshotStore 214–218/243–249, StoreRules 137). Floor ≥ 80 % MET.
- **Mutation bite landed exactly as the audit's own pin-verification line claimed:** `WatchSyncGate.swift:68` `>` → `>=` failed `boundarySeqEqualsWatermarkIsNoOp` (WatchSyncGateTests.swift:69) + the replay cell as a bonus, all other 11 suite tests green (attributable failure). Restore sha256-proven: before = after = `806df6dbb789d113f9d9ac5b21a1f718111244c9a205f35e68e83e74430f6c4c`; `git diff Sources/MomoKit/` = 0 bytes after restore.
- **Suite verified:** 515/54 ×2 (0.574 s / 0.626 s) + instrumented run 515/54; the full instrumented recompile's only warning is the environmental `ld /opt/extra/lib` note — zero repo warnings; the TASK-021 `EngineClockTests` warning non-reproduction confirmed (OBS-2).
- **Scope verified:** `Sources/MomoKit/` and `Sources/MomoCore/` diffs 0 bytes; `git status --short` = exactly the two disclosed files; no untracked files; scan suites + `Support/` unmodified → zero new exemptions; no test weakened or deleted (the whole test-tree diff is the one reformed statement); no new TODO/FIXME debt.
- **Golden-bytes disclosure judged sound:** the `try #require(try …)` construct arrived with the file at `3acc54f` (file's only prior commit); `#require` wrapped a non-optional throwing expression → behavior-identical pass/fail under both forms; assertions untouched; post-fix recompile warning-free.
- **NFR-7 gap evaluation judged honest:** `migratedStateEqualsTheFreshlyBuiltState` (MigrationChainTests.swift:291, "NFR-7 parity" verbatim) is not circular (two independent constructors must agree as whole `Equatable` values) and not vacuous; AC-3 resolves by composition with `singleHopWalkMigratesBelowCurrentGeneration` + `migratedStateRepersistsAtCurrentVersion` + the fresh-path roundtrip matrix, at the mechanism level the suite header discloses.

**MINOR-1 — the NFR-7 pin-verification line overclaims per-field teeth (fix the task-file prose; no test change required).** In `StoreFixture.state(bond:)` — the fixture both sides of the parity pin compare — `processedIntents` is `[]` and `pendingHandshake`/`lastGreeting` are `nil`, so a hypothetical migration dropping exactly those fields would PASS `migratedStateEqualsTheFreshlyBuiltState`; the pin's real teeth cover the populated fields (days, settings true/true, pet identity, open/evaluate stamps, PetState dimensions). The belt/handshake/greeting gain coverage only through the fresh-path roundtrip matrix over `populatedState()`, not through the walk. MINOR because the clause resolution stands (composition + honest mechanism-fixture disclosure + production ships `MigrationChain.empty`). **Required disposition:** correct audit table 1's migration-row verification line to name only the populated fields; optionally add the standing note (OBS-3: grow the parity fixture's belt when a real schemaVersion bump ships).

**OBS-1** — audit table 1's save/load restatement leaves two §5.2 elements untested AND unrouted ("main thread never blocks on I/O beyond launch's initial read" — app-side threading property; "NSFileProtectionComplete — VERIFY-AT-BUILD" — EPIC-002-register obligation); table 2's routing discipline should extend to them in the orchestrator's EPIC-007/008 tracking. **OBS-2** — `EngineClockTests.swift:46` warning non-reproduction confirmed across all three of today's runs (standing TASK-021 record unchanged). **OBS-3** — when the first real migration ships, the parity fixture must carry a populated `processedIntents`/handshake/greeting through the walk (MINOR-1's remedy becomes a test obligation then) — record at epic merge.

**Verdict: APPROVED_WITH_MINOR_NOTES** — task may proceed to commit after MINOR-1's prose correction is applied to this task file.

## Completion Evidence
(orchestrator fills at housekeeping)
