# REVIEW-TASK-023 — Sync DTOs + intent journal + watermark arithmetic

Reviewer: independent adversarial review agent (fresh context; Jupiter). Branch: `feature/EPIC-005-persistence`. Working tree under review: uncommitted TASK-023 implementation (6 new production files, 6 new test files + fixture, StoreRules growth) as left by the TASK-023 implementation agent after fix-loop round 1.

Method per CLAUDE.md §10/§33 and the review contract: independent re-derivation from the DOC before reading any implementation, then disproof-by-reading, then sanctioned mutations with byte-identical restore proof. The implementation's own claims (task-file Implementation Notes, fix-loop narrative) were treated as claims, not evidence.

## Verdict

**APPROVED_WITH_MINOR_NOTES.**

Zero MAJOR findings. The §6.4 formula, the epoch-matched prune, the 0-init accessor, the watermark max-semantics, and the fix-loop's replace-when-present/move-when-absent commit point all match my independent derivation from 05 §6.2/§6.4/§6.6 + ADR-003. All four sanctioned mutations bit (one as the exact Code-516 DEBUG trap the fix loop documented), every restore is sha256-proven byte-identical, the suite is 515/54 green (baseline claim verified, not trusted), `git diff Sources/MomoCore/` is 0 bytes, and TASK-021/022 production files are untouched. The notes below are NITPICK/OBSERVATION-grade; none block commit.

---

## 1. Independent re-derivation (written before reading the implementation)

Sources: `docs/architecture/05-technical-architecture.md` §6.2, §6.4, §6.6; `.claude/tasks/decisions/ADR-003-watch-sync-strategy.md`. Derived WITHOUT looking at the code:

1. **Delivery gate (§6.4 step 2).** Apply an received intent iff (a) its UUID is unseen — INV-10's seen-set guard — AND (b) `intent.watchSeq > lastAppliedIntentSeq` **for that intent's own `watchSessionEpoch`**. The watermark is a PER-EPOCH table ("the iPhone stores the watermark per epoch"); lookup is keyed by the event's epoch, never a global seq.
2. **Unseen-epoch initialization (§6.4 + §6.6).** An unseen epoch's watermark initializes at **0**, so seqs 1, 2, … apply immediately after re-pair / watch-app reinstall / new Watch — no starvation. A stale-epoch watermark must never gate another epoch's events.
3. **Prune (§6.4 step 4).** The snapshot carries `lastAppliedIntentSeq` + `lastAppliedEpoch` as ONE pair. The Watch prunes journal entries `watchSeq ≤ watermark` ONLY when the watermark's epoch matches — "a stale-epoch watermark never prunes a newer journal". The boundary is `≤` because the watermark is the *highest applied* seq: seq == watermark has been applied and is prunable; strictly-greater entries stay queued.
4. **Watermark value semantics.** "Highest Watch intent applied, per watchSessionEpoch" ⇒ **max**: recording a lower seq (out-of-order/duplicate recording) must never regress the watermark, else a replayed seq re-opens the gate.
5. **Two-guard composition (ADR-003).** UUID set (iPhone, retention-capped) and per-epoch watermark are independent: duplicate UUID + higher seq ⇒ UUID guard no-ops (UUID outranks seq); unseen UUID + stale seq after the 64-intent belt evicted the UUID ⇒ watermark guard no-ops — this interplay is precisely why the second guard exists.
6. **DTO shapes (§6.2 sketch).** `WatchSnapshot{schemaVersion, snapshotSeq, display, questInputs, hapticsEnabled, lastAppliedIntentSeq, lastAppliedEpoch}`; `IntentEvent{intent, watchSessionEpoch, watchSeq}` (+ task-mandated per-DTO schemaVersion). The snapshot's watermark pair is coherent by construction (the seq belongs to the epoch it travels with). `snapshotSeq` is monotonic and iPhone-assigned.
7. **Journal.** NDJSON append-only queue behind `transferUserInfo` (FIFO, duplicates possible). Torn trailing line skipped, never fatal. Per-event `watchSessionEpoch` is already mandated by the §6.2 sketch, so per-entry epoch matching (vs a header line) is derivable from the doc.

**Comparison outcome:** the implementation matches the derivation at every point. `WatchSyncGate.shouldApply` is the formula with the UUID guard first (WatchSyncGate.swift:56-69); `SyncState.watermark(for:)` is the single `?? 0` site (SyncState.swift:60-62); `recordingApplied` is max-semantics (SyncState.swift:69-74); `IntentJournal.pruned` is `epoch == watermarkEpoch AND watchSeq > watermarkSeq` (IntentJournal.swift:145-148); `makeWatchSnapshot` threads both watermark-pair fields from the one `watermarkEpoch` input (WatchSnapshotBuilder.swift:46-53). **No divergence.**

## 2. Disproof attempts (per area, with evidence)

### INV-10 two-guard composition
- **Duplicate UUID + higher seq:** UUID guard at WatchSyncGate.swift:65 runs before any seq arithmetic; a seq-99 redelivery of a seen id cannot re-apply. Pinned by `duplicateUUIDIsNoOpEvenWithHigherSeq` (incl. the seq-99 inflation case). **Survived.**
- **Unseen UUID + stale seq after belt prune:** the retention interplay — `replayedSeqIsNoOpEvenWhenUUIDUnseen` pins seq 1 and 2 against watermark 2 with an empty seen-set; guard 2 rejects. This is exactly the case the doc gives as the watermark's raison d'être. **Survived.**
- **Watermark regression via out-of-order recording:** `recordingApplied`'s `max` (SyncState.swift:70) makes regression unrepresentable; pinned by `recordingAppliedNeverRegresses` and exercised inside both INV-10 properties. **Survived.**
- **Shuffled-delivery honesty:** I checked the suite's INV-10 property against the contract's letter ("shuffled/duplicated delivery … exactly-once"). The implementation pins exactly-once under FIFO+pollution and *at-most-once* under 3 seeded shuffles, with the written rationale (task-file decision 8) that a seq-5-first shuffle legitimately blocks seq 3 by the `>` rule. My derivation agrees: the doc's formula under non-FIFO order drops laggards — pinning full application under shuffles would pin a falsehood against §6.4. The second-pass-zero claim is sound (any unapplied event has seq ≤ the final watermark by construction). **APPROVED deviation from the Required-Test letter — honest, doc-faithful.**

### Journal (IntentJournal.swift)
- **Torn trailing line:** `tornTrailingLineIsSkipped` truncates 5 bytes inside the last line (breaking the closing `}` — a strict prefix of canonical JSON is never valid JSON, so a torn canonical line always fails decode). Prefix survives. **Survived.**
- **Append-time torn-line seal:** append appends `0x0A` when the file doesn't end with one (IntentJournal.swift:96-98) BEFORE the new line, so a tear stays a discrete skipped line and can never glue onto the new event; `appendAfterTearPreservesTheNewEvent` pins the post-tear state `[e1, e2, fresh]`. Note the benign inverse: a crash between writing the final `}` and the `\n` leaves a complete parsable object that the seal then terminates — the event *survives* (the durable direction; no double-apply risk, the gate owns that). **Survived.**
- **Mid-file corruption:** handled by the same decode-skip (`midFileGarbageLineIsSkipped`, blank lines via `split(separator:)`, unknown-version lines via the DTO gate). **Survived.**
- **Two-epoch journal + prune from either epoch:** per-entry epoch match drops only the matching epoch's rows (`twoEpochJournalPrunesOnlyMatchingEpoch`, `epochIdentityHeldAcrossPrune`, `staleEpochWatermarkPrunesNothing` byte-identical pin). **Survived.**
- **Prune atomic rewrite + empty-survivor removal:** survivors always imply the source file existed (they were parsed from it), so `replaceItemAt` always has its original; empty survivors → `removeItem` (absent ≡ empty, pinned `absentJournalIsEmptyAndStaysAbsent`). See NITPICK N1 on the removal path's loudness. **Survived.**

### DTOs (SyncDTOs.swift)
- **Round-trip exactness:** every `InteractionIntent.Kind` case (4 gestures × 3 zone shapes + 4 no-payload kinds = 16 argument rows, with a direct kind assertion so the `==` pin can't pass vacuously), both `QuestLine` cases ×8, all 5 greeting shapes (incl. null), both `Source` cases; `attributionSurvivesVerbatim` pins dayKey + exact `timeIntervalSinceReferenceDate` through the default Date strategy (`Instant` is `Date`, MomoCore/Instant.swift:8 — the "load-bearing default strategy" claim is true). An independent test-side encoder cross-checks production bytes (`productionEncoderMatchesIndependentEncoder`), so the codec cannot agree only with itself. **Survived.**
- **Enum maps:** `Source` ×2, `PatGesture` ×4, `TouchZone` ×2, `Kind` ×5, `QuestID` guarded via `init(rawValue:)`, `BondStage`/`Wakefulness` decode as MomoCore Codable enums — all exhaustive; a new MomoCore case breaks the build in SyncDTOs.swift (the disclosed compile-time pin). Unknown strings throw → journal skips. **Survived.**
- **Version gates:** equality gates (above AND below current → nil), pinned with +1/+99/0, plus garbage/empty bytes → nil. Note the gate runs AFTER full decode; a future-version payload with an incompatible shape fails at decode rather than the gate — same nil/skip outcome either way (see OBSERVATION O4). **Survived.**
- **`IntentEvent.==`:** field-wise incl. per-kind payload comparison; pinned by 9 single-field mutations. **Survived.**

### SyncStateStore.save (the FIXED path)
- Read independently: encode → write temp → `fileExists(current)` ? `replaceItemAt` : `moveItem`; catch removes the temp and keeps the previous file (SyncStateStore.swift:78-93). No removeItem-then-move (no loss window over the watermark table). TOCTOU both directions are safe: file vanishing between check and replace → replace throws → catch (previous = absent state stands); file appearing before the move → move throws Code 516 → catch. **Survived.**
- **Fix-loop mutation (step 4) — the regression pins BITE:** reverting the commit point to unconditional `try fileManager.moveItem(at: temporary, to: current)` and running only SyncStateTests crashed the run at the double-save pin with the EXACT documented defect: `Fatal error: SyncStateStore: save failed (Error Domain=NSCocoaErrorDomain Code=516 … because an item with the same name already exists)` via the DEBUG-loud trap at SyncStateStore.swift:103. Both second-save pins are non-vacuous. **Pin verified with teeth.**

### WatchSnapshotBuilder
- Nothing ambient (verified by reading; the in-suite discipline scan also passed): display/questInputs verbatim, `hapticsEnabled ← state.settings.hapticsEnabled` (the field exists — SettingsState.swift:14), watermark pair coherent from the single `watermarkEpoch` input (epoch1's watermark proven not to leak), seq consumed through the returned state (1,2,3 pin), determinism pin. **Survived.**

### Concurrency / Sendable
- All new types' Sendable claims hold by composition (value structs of Sendable `let`s; `URL` fields in IntentJournal/SyncStateStore; stateless enums). Immutability discipline throughout (`recordingApplied`/`consumingSnapshotSeq` rebuild; no mutation of shared state). Pure halves take only parameters — no clock/calendar/filesystem in gate/SyncState/pure-prune/builder. See OBSERVATION O2 for the single-writer assumption on journal/save files.

## 3. Sanctioned mutations — table (suite = full `swift test` unless noted)

| # | Mutation | Site | Bite (exact) | Restore sha256 (== pre-mutation) |
|---|---|---|---|---|
| a | `pruned`: `>` → `>=` | IntentJournal.swift:147 | 5 tests failed / 9 issues: "prune drops watchSeq ≤ watermark … (the boundary is ≤)" (2), "the pure prune core is total …" (3), "journal epoch identity is held across the prune …" (2), "a matched prune rewrites the file …" (1), "a two-epoch journal prunes per entry …" (1). Run: `515 tests in 54 suites failed … with 9 issues` | `22d3e08e3072d785a8390f37c9a3c0152ec0a45f7e11db3d53f6c21cd763152f` ✓ |
| b | `pruned`: epoch-match removed | IntentJournal.swift:146 | 2 expectation failures ("a two-epoch journal prunes per entry …", "journal epoch identity …"), then the run CRASHED at IntentJournalTests.swift:181 (`staleEpochWatermarkPrunesNothing`: epoch-less prune with watermark 99 deleted the whole file → `readBytes` force-unwrap nil). Crash IS a bite — the byte-identical pin is what killed it | `22d3e08e3072d785a8390f37c9a3c0152ec0a45f7e11db3d53f6c21cd763152f` ✓ |
| c | `watermark(for:)`: `?? 0` → `?? 1` | SyncState.swift:61 | 7 tests failed / 8 issues: "an unseen epoch reads watermark 0 …" (direct pin), "an unseen epoch's watermark is 0: the first pat (seq 1) applies immediately" (2), "a stale-epoch watermark never gates …", "epoch re-pair / watch app reinstall …", "recordingApplied advances …", "exactly-once under the FIFO contract …", "an empty sync state yields lastAppliedIntentSeq 0 and seq 1 …" | `4112bc981b931c6d214c4e7c7bf82e230fc34595dbefb9f978193cb5b8b8e845` ✓ |
| 4 | `save` commit reverted to unconditional `moveItem` | SyncStateStore.swift:78-87 | SyncStateTests ONLY: CRASH at the double-save pin — `NSCocoaErrorDomain Code=516` into the DEBUG trap (SyncStateStore.swift:103), twice (both second-save pins). The fix-loop regression pins are non-vacuous | `959addc7d87a608fe7997f53b19f7853222666753859005fec5db9605fc85657` ✓ |

All restores verified byte-identical by sha256 against hashes recorded BEFORE any mutation; after restores the full suite is green: **`Test run with 515 tests in 54 suites passed`**.

## 4. Suite, scope, and discipline verification

- **Baseline:** `swift test` = **515 tests / 54 suites passed** (reproduced this session, start and end). Matches the task-file claim exactly (451/49 → +64/+5, incl. the 2 fix-loop pins).
- **`git diff Sources/MomoCore/` = 0 bytes** (checked twice: pre- and post-mutations). `SnapshotStore.swift` / `LedgerRetention.swift` / `MigrationChain.swift`: 0-byte diffs. TASK-021/022 suites untouched (only `StoreRulesPinnedTests.swift` grew, +20, as contracted).
- **Production scope confined:** tracked diff = `StoreRules.swift` (+44, authority-labeled constants); untracked production = the 6 sanctioned new files. Modified `.claude/tasks/{status.md, TASK-023…}` and untracked `TASK-024…md` are orchestration artifacts (the next dispatch's contract), not implementation scope.
- **No dead code found; no TODO/FIXME/HACK/TEMP anywhere in the new files (grep clean).** Standing scans run in-suite and green; the only exemption is the pre-existing, self-verifying `StoreRules.swift` path exemption — no new exemptions.
- **Nothing staged, nothing committed** by this review; tree left exactly as received (mutations reverted with proof).

## 5. Findings

**MAJOR:** none.

**MINOR:** none.

**NITPICK:**

- **N1 — Silent failure on the prune's empty-survivor removal path.** IntentJournal.swift:165: `try? fileManager.removeItem(at: url)` — if removal fails, the journal keeps already-applied entries and nothing is recorded, while the sibling rewrite path (line 196) is DEBUG-loud on failure. No correctness outcome is possible (the watermark gate no-ops applied entries; the next prune retries the cleanup), so this is a loudness-discipline inconsistency only. Suggest a DEBUG print/assert in a future touch; not blocking.

**OBSERVATION:**

- **O1 — Single-writer assumption on journal and sync-state files.** `append` is a whole-file read-modify-write and `save`/`prune` use fixed temp names; two concurrent writers could interleave/lose updates. TASK-023's contract (unlike TASK-021's) does not demand serialized-writer pins, and §6.1 makes each file single-owner (journal: the Watch; sync state: the iPhone). EPIC-008's wiring should keep appends/saves on one dispatch path per file.
- **O2 — INV-10 property letter-vs-spirit deviation (APPROVED).** The contract's Required-Test line says "shuffled/duplicated delivery … yields exactly-once"; the suite pins exactly-once under the FIFO contract shape and at-most-once under seeded shuffles, with written justification. My independent derivation from §6.4's `>` formula agrees the shuffle-blocking behavior is the guard working, not a defect. Recorded so the deviation is visible in the review trail.
- **O3 — Sync-state file has no schemaVersion.** Deliberate and documented (StoreRules syncStateFileName comment: a future breaking shape change adds one; SyncStateStore header: regenerable bookkeeping, garbled → fresh). A future incompatible shape change silently resets watermarks to fresh — consequences documented on the type (UUID belt remains the guard). Accepted posture.
- **O4 — Version gate evaluates after full decode.** `decoded(from:)` decodes the whole payload before the equality check, so an incompatible future payload fails at decode rather than the version gate — identical nil/skip outcome. The DTO header already flags peek-first as the future reader's option. No current impact.
- **O5 — Raw gate is public.** `WatchSyncGate.shouldApply` accepts a pre-resolved watermark, so a wiring call could resolve the wrong epoch's; `SyncState.shouldApply` is the documented accessor-driven path EPIC-008 should call. Header-documented; noted for EPIC-008 review attention.

## 6. Contract cell coverage (Required Tests → evidence)

Codec: roundtrips ✓, byte-stability ✓, independent-encoder cross-check ✓, unknown-version gates ×3 each ✓, attribution verbatim ✓. Journal: append/parse N ✓, torn trailing ✓, append-after-tear ✓, mid-file garbage ✓, blank ✓, unknown-version ✓, prune boundary == dropped / > kept ✓ (bit mutation a), stale-epoch byte-identical ✓ (bit mutation b), two-epoch per-entry ✓, epoch identity across prune ✓, no temp ✓, absent-absent ✓, pure core total ✓. Gate/watermark: full §6.4 cell matrix ✓, §6.6 epoch-reset ✓ + iPhone-reinstall ✓, expired-dayKey pass-through shape ✓, recordingApplied advance + max ✓, INV-10 FIFO exactly-once + second-pass zero ✓, seeded shuffles ×3 ✓. Sync state: roundtrip ✓, 0-init accessor ✓ (bit mutation c), strictly monotone seq 1,2,3 ✓, seeded seq ✓, multi-epoch durable ✓, plain-JSON no-envelope ✓, absent/garbled/empty → fresh ✓, record→save→load identity ✓, no temp ✓, **second-save lands ✓ (bit fix-loop mutation 4)**, second-save no temp ✓. Builder: field-for-field ✓, no epoch leak ✓, haptics both values ✓, seq 1,2,3 threaded ✓, origin totality ✓, determinism ✓. StoreRules pins +3 ✓.

Unnamed intermediates from the contract: duplicate-UUID/higher-seq (pinned, code-confirmed), unseen-UUID/stale-seq retention interplay (pinned), two-epoch journal (pinned), snapshotSeq-after-file-loss (documented as per-file-lifetime monotonicity + display no-op justification on `SyncState`'s header; the reset shape falls out of absent-file → fresh, seq 1).

## 7. Verdict rationale

The implementation is a faithful, total, ambient-free realization of §6.2/§6.4/§6.6 and ADR-003; the fix-loop round 1 is correctly shaped (atomic replace-when-present, no loss window) and its regression pins demonstrably bite (reproduced Code-516 trap). Every pin the contract called "must bite" bit under mutation, all restores are hash-proven, and the only findings are one NITPICK and five OBSERVATIONs — none blocks the atomic commit `feat(sync): TASK-023 sync DTOs, intent journal, watermark arithmetic` on `feature/EPIC-005-persistence`.

---

## 8. Orchestrator Disposition (2026-09-09, pre-commit)

Reviewed verdict accepted after personal verification: restore hashes re-checked independently (`22d3e08e…` IntentJournal, `4112bc98…` SyncState, `959addc7…` SyncStateStore — all match), mutation-4's Code-516 message cross-checked against the DEBUG-loud text verified live during orchestrator verification, suite reproduced 515/54 before disposition.

- **N1 — APPLIED (with a diagnosis refinement).** The finding is confirmed (silent `try?` vs the sibling path's DEBUG-loud discipline), but the suggested bare DEBUG print/assert would FALSE-POSITIVE on the pinned-normal absent-journal case (`removeItem` on a missing file throws; `absentJournalIsEmptyAndStaysAbsent` pins that as correct). Applied instead: an exists-guard that skips the absent case (behavior unchanged) and routes a removal failure over an EXISTING file through `debugLoudFailure`. Full suite re-run green post-fix: `Test run with 515 tests in 54 suites passed`. The loud path is untestable-by-design (assertionFailure path — noted per the TASK-020 coverage-note convention).
- **O2 — ACCEPTED DEVIATION (concur, independently).** The contract's Required-Test letter ("shuffled … yields exactly-once") is over-broad against its own normative source: §6.4's `>` formula + max-watermark legitimately BLOCK unseen laggards under non-FIFO order, so a full-application-under-shuffle pin would pin a falsehood. The contract itself says "where they disagree, cite the doc." The shipped shape — exactly-once under the FIFO contract stream, at-most-once under 3 seeded shuffles, σ-independent — is the doc-faithful reading; epic Test Requirements ("idempotency properties over duplicate and reordered delivery streams") are satisfied under it. No doc change required; recorded here for the trail.
- **O1 + O5 — ROUTED to EPIC-008** (recorded in status.md Important Context): sync wiring must keep one writer per journal/sync-state file on a single dispatch path, and must call the accessor-driven `SyncState.shouldApply`, never resolving watermarks at call sites.
- **O3, O4 — ACCEPTED as documented posture** (versionless sync-state file; gate-after-decode equivalence). No action.

Post-disposition state: `swift test` = 515 tests / 54 suites green. Commit follows this disposition.
