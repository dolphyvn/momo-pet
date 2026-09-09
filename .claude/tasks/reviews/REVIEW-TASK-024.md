# REVIEW-TASK-024 — MomoKit suite audit: §32 persistence rows + §10.4 sync matrix + coverage floor

- **Reviewed:** TASK-024 implementation (uncommitted working tree, branch `feature/EPIC-005-persistence` @ `9baa49d`)
- **Reviewer:** Independent fresh adversarial review agent (Jupiter), per CLAUDE.md §10/§33 — assigned to DISPROVE correctness, unprimed by the implementer
- **Date:** 2026-09-09
- **Verdict: APPROVED_WITH_MINOR_NOTES** (0 MAJOR / 1 MINOR / 0 NITPICK / 3 OBSERVATIONS)
- **Dispositions:** MINOR-1 — fix the audit table's pin-verification line (prose correction in the task file; no test change required); OBS-1/OBS-2/OBS-3 — record, no action required now.

---

## 1. Method

Every review requirement from the task contract was executed in the contract's order:

1. Derived BOTH audit tables independently from the normative docs FIRST (05 §10.4 and §32 read verbatim; persistence clauses re-derived from 05 §5.2/§5.3/§5.5; sync clauses from 05 §6.1–§6.6), BEFORE opening the implementation's tables; then diffed mine against theirs clause by clause.
2. Read the BODY of every load-bearing named test (not existence-grep): SnapshotStoreTests (full), MigrationChainTests (full), SnapshotStoreConcurrencyTests (full), WatchSyncGateTests (full), StoreFixture (full), plus targeted bodies in SyncDTOTests / WatchSnapshotBuilderTests / SyncStateTests / IntentJournalTests, and the routed Core tests (`inv10IntentIdempotencyKey`, `cascadeIsTotalOverEveryHour`, `sixRuleTable`, `cascadeTwins`, `monotonicUnderReplay` existence).
3. Re-ran the coverage measurement from a clean instrumented build and compared per-file table + TOTAL.
4. Mutation-bite on an audit-mapped clause with sha256-proven byte-identical restore.
5. Suite green ×2 + warning census on a full instrumented recompile.
6. Scope, scan-exemption, weakening, TODO-debt, and dead-code checks over the entire diff.

## 2. Independent re-derivation of the audit tables — divergences named

### 2.1 My derivation, and where it agrees

**Table 1 (§32 Persistence rows).** From §32 ("save/load", "migration", "corruption/recovery assumptions") + §5.2/§5.3/§5.5 I derived: envelope shape `{schemaVersion, savedAt, checksum, payload}`; write path encode → checksum → temp → atomic rename with generational demotion; serialized total-ordered writes; read = decode → version gate → checksum re-verify → decode; fidelity closure over all persisted fields/enum cases; chain walk with missing-hop/above-head unreadable; gate order (checksum precedes walk); purity/totality; fresh-vs-upgrade both-directions parity (NFR-7); re-persistence at current version; recovery modes truncated/garbage/empty/checksum-mismatch/all-lost/missing-directory; never-an-error; survivors never damaged / loads never write; torn-write crash windows; worst case ≤ 1 event. **Every one of these resolves to a named test whose body I read and which pins the clause as the implementation's table claims.** Pin-verification lines sampled all accurate except MINOR-1 below. Specific body verifications worth recording:

- `checksumMismatchFallsBackToPrev` (SnapshotStoreTests.swift:310) really isolates the checksum gate: decodable envelope for `state(bond: 3)` carrying the digest of a DIFFERENT payload (`state(bond: 1)`) — exactly as the table's parenthetical claims.
- `corruptingOneGenerationLeavesSurvivorsIntact` (:363) pins byte-identity of survivors across two successive corruptions — the loads-never-write clause.
- The five crash-window tests (:258–:295) construct every intermediate filesystem shape directly — the torn-write clause.
- The concurrency adjacency pins (SnapshotStoreConcurrencyTests.swift:69–71 and :127) pin exactly base+23/22/21 over 24 saves and base+127 over 128 saves — the convergence/no-silent-loss clause, in the TASK-021-flake σ-independent form.
- `corruptChecksumBelowCurrentNeverMigrates` + `validChecksumBelowCurrentDoesMigrate` (MigrationChainTests.swift:241/258) — the gate-order pin with its live negative control.
- The migration unreadable shapes (missing hop, mid-walk missing hop, above-head with steps registered, unit-level above-head, empty chain) all exist and assert nil/fall-through as claimed; `duplicateFromKeepsTheFirstDeclaredStep` (:305) pins first-declared-wins.

**Table 2 (§10.4 seven rows).** I re-derived the seven rows verbatim from 05 §10.4:611–617. The implementation's row texts quote the doc faithfully; every KIT-share mapping names real tests whose bodies I verified: the INV-10 exactly-once property (`exactlyOnceUnderFIFOWithDuplicatesReplaysRedeliveries` — FIFO batch + per-event duplicates + out-of-order replay + FULL redelivery ⇒ `applied == distinct` in order, second pass zero; this IS the row-2 clause, not a mere gate unit test), the σ-independent at-most-once property over 3 seeded shuffles of the doubled multiset, the §6.4 cell matrix (UUID-outranks-seq with the seq-99 inflation, retention interplay, strict `>` boundary, both-guards apply), the §6.6 reset cells (0-init accessor `unseenEpochReadsZero` with the read-does-not-mutate pin, epoch reset without starvation, iPhone-reinstall-warm), the epoch-matched prune pins (`pruneBoundaryIsInclusive` pins ≤ on both sides of the boundary; `staleEpochWatermarkPrunesNothing` pins byte-identical file), the codec versioning pins (`unknownSnapshotVersionIsIgnored` really is ×3 — above head +1/+99 and 0 below; `questLineCaseRoundtrips` really is ×8), and the builder pins (`fieldsThreadFromExplicitInputs` pins every field incl. the wrong-epoch watermark non-leak; `repeatedBuildsConsumeMonotoneSeqs` pins seqs `[1,2,3]` — the iPhone half of latest-wins). **Every non-Kit share is explicitly routed (EPIC-008 / EPIC-007 / EPIC-002 VERIFY-AT-BUILD / EPIC-004-landed with named Core tests) and matches the doc's own attribution column; nothing is silently dropped.** §10.5's "Upgrade" edge is additionally covered via table 1's migration row, as the implementation notes.

### 2.2 Divergences found

- **MINOR-1 — the NFR-7 pin-verification line overclaims per-field teeth** (detail in §5).
- **OBS-1 — table 1's save/load restatement leaves two §5.2 elements untested AND unrouted:** "the main thread never blocks on I/O beyond launch's initial read" (a caller-side threading property — untestable headlessly, owned by the app/UI epics) and "NSFileProtectionComplete — VERIFY-AT-BUILD" (an EPIC-002-register verify-at-build obligation). Table 2's format routes non-Kit shares explicitly; table 1 has no routing column and these two §5.2 elements appear in neither table. The substance is safe — the store is an actor (serialization by construction and pinned) and file protection is an app-target property outside MomoKit — but the audit's own standard ("routed, never silently dropped") is applied only in table 2. Record both obligations where the orchestrator tracks EPIC-007/008 scope.
- **OBS-2 — `EngineClockTests.swift:46` non-reproduction confirmed:** the TASK-021-recorded warning did not appear in any of today's three full-suite runs including the instrumented full recompile — matches the implementation's honest observation note; file is outside this task's boundary (MomoCoreTests).
- **OBS-3 — the parity pin is a mechanism fixture while `currentSchemaVersion == 1` (disclosed):** the suite header states it plainly, and the shipped production chain is `MigrationChain.empty`, so no real migration exists to exercise. When a real schemaVersion bump ships, the parity fixture MUST grow the populated-field coverage (see MINOR-1) — worth a standing note in the epic-merge record so the obligation survives the task file.

No clause of either table was found MISSING, and no mapping was found pointing at a test that does not pin its clause, except as MINOR-1 narrows one verification line.

## 3. Coverage measurement — reproduced

Command executed verbatim (after a plain `swift test` had invalidated the profdata, the instrumented run was re-executed first, per the recorded caveat):

```
swift test --enable-code-coverage
xcrun llvm-cov report .build/arm64-apple-macosx/debug/MomoPackageTests.xctest/Contents/MacOS/MomoPackageTests -instr-profile .build/debug/codecov/default.profdata Sources/MomoKit
```

**Reproduced digit-for-digit. TOTAL: 691 lines, 77 missed → 88.86 % lines** (regions 325/30 → 90.77 %; functions 69/6 → 91.30 %). Every per-file row matches the recorded table exactly (SyncDTOs 92.06, LedgerRetention 100, WatchSyncGate 100, IntentJournal 78.63, MigrationChain 100, SyncStateStore 77.36, StoreRules 93.75, SnapshotStore 86.89, SyncState 100, WatchSnapshotBuilder 100). The floor (≥ 80 %) is MET.

Missed-line classifications spot-verified live with `llvm-cov show`:

- `SnapshotStore.swift` 214–218: the DEBUG-loud encode-guard, 0 executions — matches "unexercisable by construction" (executing it crashes the DEBUG process). 243–249: the I/O catch arm — matches the no-fault-injecting-FileManager classification.
- `StoreRules.swift` 137: the create-if-missing arm of `defaultDirectory()`, 0 executions on this host because the directory exists — matches the environment-conditional classification exactly.

The 20 SyncDTOs decode-refusal lines (exercisable-in-principle, below clause altitude, entry-point refusal behavior pinned by `garbageBytesDecodeToNil` + journal skip pins) are accepted under the no-padding rule — the classification is honest and the entry-point behavior IS pinned.

## 4. Mutation bite — the audit is executable truth

**Target:** audit table 2, row 5 (Conflict handling), whose pin-verification line claims verbatim: "`>` → `>=` fails `boundarySeqEqualsWatermarkIsNoOp`."

**Mutation:** `Sources/MomoKit/WatchSyncGate.swift:68` — `return event.watchSeq > watermarkForEpoch` → `return event.watchSeq >= watermarkForEpoch` (one character).

**Result — the named test failed exactly as claimed:**

```
✘ Test "the boundary is strictly greater: seq == watermark is a no-op" recorded an issue
  at WatchSyncGateTests.swift:69:9: Expectation failed: !(WatchSyncGate.shouldApply(... seq: 5 ...,
  watermarkForEpoch: 5) → true)
✘ Test "the boundary is strictly greater: seq == watermark is a no-op" failed after 0.010 seconds with 1 issue.
```

`replayedSeqIsNoOpEvenWhenUUIDUnseen` (the retention-interplay replay cell) failed as a bonus bite — the mutation trips every `seq == watermark` cell, which is the correct semantics of the defect. The other 11 tests in the suite stayed green — the failure is ATTRIBUTABLE to the boundary clause, not a cascade.

**Restore proof:**

| Stage | `shasum -a 256 Sources/MomoKit/WatchSyncGate.swift` |
|---|---|
| Before mutation | `806df6dbb789d113f9d9ac5b21a1f718111244c9a205f35e68e83e74430f6c4c` |
| After restore | `806df6dbb789d113f9d9ac5b21a1f718111244c9a205f35e68e83e74430f6c4c` |

`git diff Sources/MomoKit/` = 0 bytes after restore; tree restored to exactly the two disclosed modified files. No commit was made at any point.

## 5. Findings

### MINOR-1 — the NFR-7 parity pin's per-field teeth are narrower than the audit's pin-verification line claims

**Evidence.** Audit table 1's migration row states: "A migration that drops/defaults ANY carried field (days, processedIntents, settings, pet identity, stamps) fails the whole-value parity pin." In `StoreFixture.state(bond:)` (Support/StoreFixture.swift:172–200) — the fixture BOTH sides of `migratedStateEqualsTheFreshlyBuiltState` (MigrationChainTests.swift:291) compare — `processedIntents` is `[]`, `pendingHandshake` is `nil`, `lastGreeting` is `nil` (also `lastFedAt`/`activity` nil). A hypothetical migration step that dropped exactly `processedIntents` (or the handshake/greeting stamps) would PASS the parity pin, because both sides carry empty/nil for those fields; the pin's real teeth cover the populated fields (days ledger 1 record, settings true/true — `SettingsState` has no memberwise defaults, pet identity, open/evaluate stamps, and the PetState dimensions). Every migration-side test (`singleHopWalk…`, `migratedStateRepersists…`) uses the same fixture, so the belt/handshake/greeting are never exercised through the walk populated.

**Why this is MINOR, not MAJOR.** The clause (epic AC-3 / NFR-7: "upgrade path produces identical engine-visible state to a fresh install seeded with the same history") is still genuinely resolved: the parity pin is NOT circular (the expectation `fixture.state(bond: 42)` is built by a DIFFERENT constructor than the migration step's `replacing(bond: 42, in: _)` — the two must agree as whole `Equatable` values), not vacuous, and the composition with `singleHopWalkMigratesBelowCurrentGeneration` (real envelope bytes through the public API), `migratedStateRepersistsAtCurrentVersion` (identical behavior afterwards), and the roundtrip matrix (fresh-path fidelity over the fully-populated `populatedState()`) covers the clause at the mechanism level the suite header honestly discloses ("MECHANISM FIXTURES, NOT HISTORY"). Production ships `MigrationChain.empty` — no real migration exists that could drop these fields today. The defect is in the audit table's VERIFICATION-LINE WORDING, not in the clause resolution or the tests.

**Required disposition.** Correct the task file's pin-verification line to name only the fields the fixture populates (e.g. "a migration that drops or defaults any POPULATED carried field — days, settings, pet identity, open/evaluate stamps, PetState dimensions — fails the whole-value parity pin; the belt/handshake/greeting are nil-or-empty in the parity fixture and gain teeth only through the fresh-path roundtrip matrix over `populatedState()`"). Optionally add OBS-3's standing note (grow the parity fixture's belt when a real migration ships). No test change required.

### OBSERVATIONS (no action required now)

- **OBS-1** — route table 1's two unhandled §5.2 elements (main-thread non-blocking; NSFileProtectionComplete VERIFY-AT-BUILD) into the orchestrator's EPIC-007/008/EPIC-002-register tracking, matching table 2's routing discipline. See §2.2.
- **OBS-2** — `EngineClockTests.swift:46` warning non-reproduction confirmed across all three of today's runs; the implementation's note is accurate. Standing TASK-021 record unchanged.
- **OBS-3** — when a real schemaVersion bump ships (the first non-empty production `MigrationChain`), the NFR-7 parity fixture must carry a populated `processedIntents` belt/handshake/greeting through the walk (MINOR-1's remedy becomes a test obligation then). Record at epic merge.

## 6. Suite health, scope, hygiene — all verified

- **Suite green ×2:** run 1 → **515 tests / 54 suites passed** (0.574 s); run 2 (post-mutation-restore) → **515/54 passed** (0.626 s); instrumented run → **515/54 passed** (0.556 s). Zero failures, zero skips on every run. The recorded 515/54 is real and stable.
- **Warning census:** the instrumented full recompile's complete log contains exactly ONE warning — the pre-existing machine-level `ld: warning: search path '/opt/extra/lib' not found`. Zero repo-content warnings.
- **Scope:** `git diff Sources/MomoKit/` = 0 bytes; `git diff Sources/MomoCore/` = 0 bytes; `git status --short` = exactly `.claude/tasks/active/TASK-024-…md` + `Tests/MomoKitTests/SnapshotStoreGoldenBytesTests.swift`; `git ls-files --others` = empty. Zero production change is confirmed, not merely claimed.
- **Scan exemptions:** `MomoKitDisciplineScanTests.swift` and everything under `Support/` are unmodified, and production is unmodified — no exemption surface changed anywhere; the scans ran in-suite green in all three runs.
- **The disclosed golden-bytes edit is behavior-identical and genuinely pre-existing:** the `try #require(try JSONDecoder().decode(...))` construct arrived with the file at `3acc54f` (the file's only prior commit — verified via `git log`/`git show`); `#require` wrapped a non-optional throwing expression, so the test fails identically under both forms (thrown error → test issue vs thrown error → test failure); the assertions after it are untouched. NOT a weakening — post-fix, the full recompile is warning-free.
- **No weakened or deleted tests:** the entire test-tree diff is that one reformed statement (2+/2−); no `@Test` removed, no assertion loosened, no fixture weakened.
- **No new TODO/FIXME/HACK/TEMP debt:** the diff introduces none.
- **Dead code / scope creep:** none — the deliverable is the audit + measurement, and that is what the diff contains.

## 7. Verdict

**APPROVED_WITH_MINOR_NOTES.** Both audit tables are executable truth as re-derived independently (one verification line narrowed by MINOR-1); the coverage table reproduces digit-for-digit at 88.86 % ≥ 80 %; the mutation bite failed the exact named test the audit's own pin-verification line predicted, with a sha256-proven byte-identical restore; the suite is 515/54 green ×2 with zero repo warnings; scope is exactly as disclosed with zero production and zero MomoCore changes; nothing was weakened or deleted. The zero-new-tests outcome is verified honest: every clause I tried to find unpinned was pinned, and the one genuinely thin spot (MINOR-1) is an audit-prose overclaim, not a missing test.

Task may proceed to commit after MINOR-1's prose correction is applied to the task file.

---

## 8. Orchestrator Disposition (post-review, pre-commit)

Recorded 2026-09-09 by the orchestration agent after personal verification of every finding's diagnosis.

- **MINOR-1 — ACCEPTED and APPLIED.** The diagnosis was reproduced personally before disposition: `StoreFixture.state(bond:)` (Support/StoreFixture.swift:210–215) carries `pendingHandshake: nil`, `processedIntents: []`, `lastGreeting: nil` — the parity pin therefore has no teeth over those fields through the walk, exactly as found. Both overclaiming sentences in the task file were corrected: the table-1 migration-row pin-verification line and the NFR-7 gap-evaluation paragraph now name only the populated fields, with the belt/handshake/greeting coverage route (fresh-path roundtrip matrix over `populatedState()`) and the OBS-3 standing obligation recorded inline. No test change required — concurred with the reviewer's severity reasoning (clause resolution stands via the four-test composition; production ships `MigrationChain.empty`).
- **OBS-1 — ACCEPTED, routed.** Both §5.2 elements are recorded in status.md as orchestrator-tracked obligations: "main thread never blocks on I/O beyond launch's initial read" → app-layer property, routed to EPIC-007/EPIC-008 scope; "NSFileProtectionComplete" → EPIC-002 VERIFY-AT-BUILD register.
- **OBS-2 — recorded.** Confirms the implementation's honest observation; the standing TASK-021 record is unchanged.
- **OBS-3 — ACCEPTED, recorded as a standing obligation** in status.md's Important Context (survives the task file): when the first real schemaVersion bump ships, `migratedStateEqualsTheFreshlyBuiltState`'s fixture must carry a populated `processedIntents` belt / `pendingHandshake` / `lastGreeting` through the walk — MINOR-1's narrowed claim becomes a test obligation at that point.
- **Mutation bite independently confirmed:** the restore hash `806df6dbb789d113f9d9ac5b21a1f718111244c9a205f35e68e83e74430f6c4c` was re-verified by the orchestrator against the working tree post-review (`shasum -a 256` + `git diff Sources/MomoKit/` = 0 bytes).
- **Orchestrator verification (pre-review) summary, for the record:** HEAD `9baa49d` unmoved; tree confined to the two disclosed files; production and MomoCore diffs 0 bytes; all 117 named audit identifiers resolved to real test funcs (zero phantom mappings); NFR-7 parity test body read personally (non-circular); `swift test` 515/54 green ×2; llvm-cov table reproduced line-for-line at 88.86 %.

Post-disposition state: prose-only markdown edits since the reviewer's green ×2 runs (no code change); final `swift test` re-run before the atomic commit as §19 confirmation.
