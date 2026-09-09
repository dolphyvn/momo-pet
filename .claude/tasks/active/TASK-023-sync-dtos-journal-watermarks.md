# TASK-023 — Sync DTOs + intent journal + watermark arithmetic (05 §6.2, §6.4; ADR-003; INV-10)

## Parent Epic
EPIC-005 — Persistence & Sync Logic (MomoKit), task 3 of 4 (size M). Epic acceptance criteria served: AC-5 (watermark arithmetic: duplicate delivery and replay are no-ops; unseen epoch initializes at 0; stale-epoch intents never prune — INV-10; expired-dayKey rule observed end-to-end at the gate) and the sync-pure halves of AC-1/AC-2 (the exactly-once delivery gate). Closes ADR-003's "pure logic lives in MomoKit where it is headlessly testable" obligation (05 §6.1).

## Objective
The sync layer's three pure halves, fully executable and headlessly testable on macOS — **no transport** (WatchConnectivity wrappers are EPIC-008; §6.1's wrappers are per-target ~100-line files, deliberately out of scope here):
1. **Versioned DTOs (05 §6.2 sketch, verbatim semantics):** `WatchSnapshot` (iPhone → Watch) and `IntentEvent` (Watch → iPhone) — Codable, Sendable, each carrying its own `schemaVersion`.
2. **NDJSON intent journal:** the append-only queue behind `transferUserInfo` — pure journaling (append/parse/prune) over an injected directory, crash-tolerant (a torn trailing line is skipped, never fatal).
3. **Watermark + delivery-gate arithmetic (05 §6.4):** the apply gate (intent UUID unseen — INV-10 — AND `watchSeq > watermark` FOR THAT INTENT'S EPOCH; unseen epoch initializes its watermark at 0), the per-`watchSessionEpoch` watermark table, the monotonic `snapshotSeq` assignment, and the epoch-matched journal-prune rule (a watermark prunes ONLY when its epoch matches the journal's; a stale-epoch watermark never prunes a newer journal).

**Normative source of truth:** `docs/architecture/05-technical-architecture.md` §6.1–6.6 (esp. §6.2 payloads, §6.4 intent path, §6.6 guard-reset cases) and `.claude/tasks/decisions/ADR-003-watch-sync-strategy.md`. The epic's Scope bullet is secondary prose; where they disagree, cite the doc.

## Context
- **Codebase state:** TASK-022 complete (`3acc54f`): `SnapshotStore` (injected migration chain, prune-on-save, gate order documented), `StoreRules` constants home, `LedgerRetention`, `MigrationChain`. Baseline `swift test` = **451 tests / 49 suites green**.
- **Grounded type facts (verified 2026-09-09):**
  - `InteractionIntent` (`Sources/MomoCore/InteractionIntent.swift`) already carries everything: `id: UUID` (the INV-10 key, FR-18 AC-1), `source`, `localDayKey: String` (the §6.4 day-attribution key — a 23:30 pat queues with `dayKey = D`), `timestamp: Instant`, `kind`. WRAP it — never re-invent these fields in the DTO.
  - `QuestProgress` (`Sources/MomoCore/Quest.swift:108`) is already `Equatable, Sendable, Codable` and carries id/progress/target/completion — the §6.2 sketch's `QuestCascadeInputs` maps onto `[QuestProgress]` (today's 3 quests). USE the existing type; do not create a MomoCore `QuestCascadeInputs`.
  - `DisplayState` (TASK-019) is the §4.11 read-model the sketch's `display` field carries. `SettingsState` exists — check whether the `hapticsEnabled` input (UX-13) is derivable from `EngineState.settings`; if it is NOT, a snapshot-BUILDER PARAMETER is the answer (never a MomoCore change).
- **Expired-dayKey rule (§6.4 step 3) is ALREADY ENGINE-SIDE** (TASK-016): `InteractionSemantics` applies current-state effects and drops all day-ledger attribution for an expired dayKey. TASK-023 owns the GATE, not the effects — the contract here is that the gate passes a valid intent through unchanged so the engine's rule can act. Pin the pass-through shape; do not duplicate engine logic.
- **The two independent idempotency guards (ADR-003):** the iPhone's seen-UUID set (`EngineState.processedIntents`, persisted by TASK-021's store) AND the Watch-side per-epoch watermark/journal-prune. Both must be exercised by the suite as no-op properties over duplicate delivery, replay, and redelivery (INV-10, FR-18 AC-1).
- **§6.6 guard-reset cases to pin (Core/Kit rows of the §10.4 matrix):** unseen epoch → watermark 0 (seq 1, 2, … apply immediately, no starvation); a stale-epoch snapshot watermark never prunes the current journal; iPhone-reinstall shape (empty table, no epochs known → everything applies warm, INV-10 UUID set empty).
- **MomoKit discipline:** Foundation + MomoCore imports only; injected directory for every file (no ambient paths); DEBUG-loud failure discipline (mirror `SnapshotStore`); the standing scans must stay green with NO new exemptions. REUSE `StoreRules` as the constants home (journal/sync-state file names get authority labels: 05 §6.2/§6.4 + ADR-003).

## Requirements
1. **DTOs.** `WatchSnapshot { schemaVersion, snapshotSeq, display: DisplayState, questInputs: [QuestProgress], hapticsEnabled: Bool, lastAppliedIntentSeq: Int, lastAppliedEpoch: UUID }` and `IntentEvent { schemaVersion, intent: InteractionIntent, watchSessionEpoch: UUID, watchSeq: Int }` — field-for-field the §6.2 sketch, plus per-DTO `schemaVersion`. Exact `Equatable` semantics for round-trip pins; Codable canonical under the same `.sortedKeys` encoder discipline the store uses (document if a DTO needs a hand-written conformance and why — DISCLOSURE required for any non-synthesized Codable).
2. **Snapshot builder (pure).** A derivation `EngineState + DisplayState + current watermark (+ epoch, seq source) → WatchSnapshot` so EPIC-007/008 wiring is one call. `snapshotSeq` is monotonic and iPhone-assigned: the builder takes the NEXT seq from a sync-state source; it never reads ambient state.
3. **Sync state (the watermark home — contract decision).** A small MomoKit value type holding the per-epoch watermark table `[UUID: Int]` + the next `snapshotSeq`, persisted as its own plain JSON file (write-temp-then-atomic-rename, mirroring the store's commit-point discipline; injected directory; StoreRules file-name constant). Unseen epoch reads as watermark 0 BY the accessor, not by magic defaults sprinkled at call sites. Explicitly OUT: refactoring `SnapshotStore` into a generic store, and any MomoCore change. Re-persistence pin: load → apply gate → save → load == same sync state.
4. **Journal (NDJSON).** Append = one `IntentEvent` JSON object per line (`.sortedKeys`, newline-terminated); parse = decode line-by-line, SKIPPING an unparsable line and recording it DEBUG-loud (a torn trailing line from a mid-append crash must never lose the rest of the queue — pin it); prune = drop entries with `watchSeq ≤ watermark` ONLY when the applying watermark's epoch == the journal's epoch (the journal carries its epoch — pin how: per-file epoch header line or per-event field, implementer's choice, justify); append + read + prune never throw to the caller.
5. **Delivery gate (pure).** `apply-gate(intent, seenUUIDs, watermarkFor(intent.watchSessionEpoch))` → apply iff `!seenUUIDs.contains(intent.id)` AND `intent.watchSeq > watermark`. Pin every §6.4 cell: fresh seq after epoch reset applies (0-init), duplicate UUID is a no-op even with higher seq, replayed old seq is a no-op even when UUID unseen (the INV-10 belt may have been pruned by retention — this is exactly why the watermark guard exists; pin that interplay), stale-epoch watermark never gates (0-init) and never prunes.
6. **No scope creep:** no WC transport/wrappers, no Watch-side store files (§5.6 = EPIC-008), no UI, no engine changes, NO `Sources/MomoCore/` changes at all (expected diff EMPTY; any touch is a DISCLOSURE with justification), no schemaVersion bumps of the store.

## Files / Areas Likely Affected
- NEW `Sources/MomoKit/` files (implementer's split, house ~200–400-line discipline): DTOs, snapshot builder, sync state, journal, gate.
- `Sources/MomoKit/StoreRules.swift` — new constants (file names, journal/snapshot schema versions if separate from the store's, any bounds) with authority labels + raw-literal pins.
- NEW `Tests/MomoKitTests/` suites: DTO codec/versioning, journal (append/parse/torn-line/prune/epoch-match), gate + watermark properties (duplicates, replay, epoch reset, stale epoch, INV-10), snapshot builder, sync-state roundtrip. `Support/StoreFixture` may grow builders.
- NOT affected: `Sources/MomoCore/**` (must be EMPTY diff), `Package.swift`, app targets, the store's existing suites (they may grow only if a shared fixture moves — justify).

## Dependencies
- TASK-021, TASK-022 (complete). TASK-012/016/019 types (complete). No new external dependencies.

## Constraints
- Headless macOS `swift test` only; injected directory/clock everywhere; no ambient time/paths in MomoKit (standing scans — run them in-suite).
- No commits by the implementation agent (orchestrator commits after independent review).
- §26: any unavoidable temporary debt gets an attached explanation in Implementation Notes.

## Acceptance Criteria
1. Both DTOs round-trip byte-stably under the `.sortedKeys` encoder; each carries and gates on its own `schemaVersion` (unknown DTO version behavior defined and pinned — skip/ignore semantics consistent with the store's).
2. Journal: append→parse→prune roundtrip green; a torn trailing line is skipped with the earlier entries intact (pin); prune is epoch-matched ONLY (a stale-epoch watermark leaves the journal byte-identical — pin); ≤ vs < boundary pinned exactly.
3. Gate: unseen epoch applies at seq 1; duplicate UUID no-op; replayed seq no-op; both-guards-pass applies exactly once across duplicate/replay/redelivery streams (INV-10 / FR-18 AC-1 property pin).
4. Sync state: per-epoch table roundtrips; unseen epoch accessor returns 0; `snapshotSeq` strictly monotonic under use; atomic-write discipline mirrors the store's.
5. Snapshot builder: one call from state → `WatchSnapshot` with correctly threaded watermark/epoch/seq; `hapticsEnabled` sourced without ambient reads.
6. Full `swift test` green with standing scans; `Sources/MomoCore/` diff EMPTY; TASK-021/022 suites untouched and green.

## Required Tests
- Codec: roundtrip both DTOs; `.sortedKeys` byte-stability; DTO schemaVersion gate (unknown → defined semantics, pinned); `IntentEvent` preserves `intent.localDayKey`/`timestamp` verbatim through the codec (the §6.4 attribution data).
- Journal: append/parse N events; torn-line tolerance (truncate mid-last-line → N−1 valid events survive); prune at exact watermark boundary (== dropped, > kept); stale-epoch prune request changes nothing; journal-epoch identity held across prune.
- Gate/watermark: the full §6.4 cell matrix from Requirement 5 + the §6.6 reset cases (epoch re-pair/reinstall → 0-init applies; iPhone reinstall → empty table applies warm); INV-10 property: shuffled/duplicated delivery of a fixed event multiset yields exactly-once application.
- Sync state: roundtrip, 0-init accessor, monotonic seq under use, torn/absent file → defined fresh state (never throws).
- Builder: field-for-field pin incl. `lastAppliedEpoch`/`lastAppliedIntentSeq` threading.
- All standing discipline scans green in-suite; new constants raw-literal-pinned in `StoreRulesPinnedTests`.

## Review Requirements
Standard independent adversarial review (CLAUDE.md §10/§33). Reviewer MUST:
- Re-derive the §6.4 gate + prune semantics from the DOC (not the epic prose, not the implementation) BEFORE comparing; verify every Required-Test cell exists with teeth.
- Verify `git diff Sources/MomoCore/` is EMPTY and `SnapshotStore`/`LedgerRetention`/`MigrationChain` are untouched (0-byte diff on those files).
- Sanctioned mutations with byte-identical restore proof (cmp + sha256), at minimum: (a) prune drops `< watermark` instead of `≤` (boundary pin must bite); (b) remove the epoch-match condition on prune (stale-epoch-never-prunes pin must bite); (c) unseen-epoch accessor returns a nonzero default (0-init pins must bite).
- Attempt unnamed intermediates: duplicate UUID with higher seq (must still no-op — UUID outranks seq); unseen UUID with stale seq (must no-op — the retention-interplay case); journal with events from TWO epochs (prune affects only the matching epoch's entries); snapshotSeq reuse after sync-state file loss (defined behavior, documented — state whether monotonicity is per-store-lifetime; a reset seq is a Watch-side display no-op, justify).
- Verify torn-line handling cannot lose non-torn lines, and that a mid-file (not just trailing) corruption is handled by the documented skip semantics.
- Re-run the full suite; confirm the TASK-021/022 suites untouched.

## Git Requirements
- Branch `feature/EPIC-005-persistence`; implementation agent does NOT commit.
- Orchestrator commits atomically: `feat(sync): TASK-023 sync DTOs, intent journal, watermark arithmetic`.
- "(this commit)" convention for the task file's Completion Evidence.

## Status
REVIEWED — APPROVED_WITH_MINOR_NOTES (REVIEW-TASK-023, 2026-09-09; 0 MAJOR / 0 MINOR / 1 NITPICK / 5 OBSERVATIONs; all four sanctioned mutations bit with sha256-proven restores, incl. the fix-loop revert biting as the exact Code-516 DEBUG trap). Disposition applied pre-commit (review §8): N1 fixed with a diagnosis refinement (exists-guard: absent-journal no-op preserved, genuine removal failure now DEBUG-loud; 515/54 green post-fix), O2 accepted as the doc-faithful deviation (independently concurred), O1+O5 routed to EPIC-008, O3/O4 accepted as documented posture. Was IN_REVIEW — implementation + fix-loop round 1 complete; was READY — contract materialized by the orchestration agent from 05 §6.1–6.6, ADR-003, and grounded MomoCore type facts.

## Implementation Notes
Filled by the TASK-023 implementation agent, 2026-09-09.

### API shape (all under `Sources/MomoKit/`, imports Foundation + MomoCore only)

- **`SyncDTOs.swift`** — `WatchSnapshot` and `IntentEvent`: `public struct`, `Sendable`, `Equatable`, hand-written `Codable`. Fields verbatim 05 §6.2: snapshot = `schemaVersion, snapshotSeq, display: DisplayState, questInputs: [QuestProgress], hapticsEnabled: Bool, lastAppliedIntentSeq: Int, lastAppliedEpoch: UUID`; event = `schemaVersion, intent: InteractionIntent, watchSessionEpoch: UUID, watchSeq: Int`. Both inits take `schemaVersion` with a `StoreRules` default. `encoded() -> Data?` single-sources the `.sortedKeys` canonical recipe; `static decoded(from: Data) -> DTO?` is the non-throwing gate: unknown schemaVersion (ANY version ≠ current, above OR below — equality gate, the store's `MigrationChain.empty` analogue), malformed bytes, or unknown enum strings → `nil`.
- **`SyncState.swift`** — `public struct SyncState: Equatable, Sendable, Codable` = `watermarks: [UUID: Int]` + `nextSnapshotSeq: Int` (default 1). `watermark(for:)` is THE one unseen-epoch-0 site. `recordingApplied(_:) -> SyncState` (max semantics, immutable rebuild). `consumingSnapshotSeq() -> (sync:, assignedSeq:)`. `shouldApply(_:seenIntentIDs:)` delegates to the gate.
- **`WatchSyncGate.swift`** — `public enum WatchSyncGate`, `static func shouldApply(_ event:, seenIntentIDs:, watermarkForEpoch:) -> Bool`: UUID guard first (UUID outranks seq), then `event.watchSeq > watermarkForEpoch`. Header carries the full §6.4 cell matrix.
- **`WatchSnapshotBuilder.swift`** — free function `makeWatchSnapshot(state:display:questInputs:watermarkEpoch:sync:) -> (snapshot:, nextSync:)` (house precedent: `makeDisplayState`). No ambient reads: haptics ← `state.settings.hapticsEnabled`, watermark ← `sync.watermark(for: watermarkEpoch)` (that epoch ONLY), epoch ← parameter, seq ← consumed.
- **`IntentJournal.swift`** — `public struct IntentJournal(directory:)` (injected, like SnapshotStore): `append(_:)`, `events() -> [IntentEvent]`, `prune(watermarkEpoch:watermarkSeq:)`, and the pure core `static pruned(_ events:, watermarkEpoch:, watermarkSeq:) -> [IntentEvent]`. Every public API non-throwing by signature. NDJSON, one canonical line per event.
- **`SyncStateStore.swift`** — `public struct SyncStateStore(directory:)`: `load() -> SyncState` (absent/empty/garbled → fresh, silently), `save(_:)` (encode → temp → atomic commit: **replace-when-present via `replaceItemAt` / move-when-absent via `moveItem`**; internal failure → remove temp, previous file stands, DEBUG-loud).
- **`StoreRules.swift`** (+44 lines) — 6 new constants, authority-labeled (05 §6.2/§6.4 + ADR-003): `watchSnapshotSchemaVersion = 1`, `intentEventSchemaVersion = 1`, `intentJournalFileName = "intent-journal.ndjson"`, `temporaryIntentJournalFileName = "intent-journal.ndjson.tmp"`, `syncStateFileName = "sync-state.json"`, `temporarySyncStateFileName = "sync-state.json.tmp"`. All pinned as raw literals in `StoreRulesPinnedTests`.

### Design decisions + justifications

1. **Journal epoch = per-event field** (not a journal-header line): §6.2 mandates it on the wire event; per-entry matching handles defensively mixed-epoch journals (Watch writing through an epoch switch); no second format to version. The prune keeps an entry iff its epoch ≠ watermark epoch OR `watchSeq > watermarkSeq`.
2. **DTO unknown-version = equality gate → `nil`/skip** (any version ≠ current): the sync analogues of the store's below-current-is-unreadable posture under `MigrationChain.empty`; production has no migrations yet. Journal skips unknown-version lines (defined, `#if DEBUG print`-recorded) so a future wedge cannot block the queue.
3. **`hapticsEnabled` sourced from `EngineState.settings`** — the builder takes it from its explicit `state` parameter; no ambient settings read exists in MomoKit.
4. **`snapshotSeq` monotonicity scope = per sync-state-file lifetime** (header-documented): iPhone-assigned; a reset after file loss is a Watch DISPLAY no-op (seq is delivery metadata, never a gate input — the gate uses Watch-owned `watchSeq`, per epoch, EPIC-008's contract). `recordingApplied`'s max semantics make out-of-order recording unable to regress a watermark.
5. **DEBUG-loud split**: invariant/I-O regressions → `assertionFailure` (trap in DEBUG, silent release, SnapshotStore pattern); DEFINED skip paths (torn line, garbage line, blank line, unknown version) → non-trapping `#if DEBUG print` — trapping would make crash recovery itself crash. (`import os` is banned by the whitelist scan.)
6. **Append after a tear seals it**: `append` re-reads, appends `0x0A` if the file doesn't end with one (sealing the torn line as DISCRETE and skipped — never merged into the new event), then appends the new canonical line. Plain in-place write is deliberate: the torn trailing line is the DESIGNED tolerance.
7. **Prune atomicity**: survivors are unapplied pats — losing them would break FR-18, so prune writes temp then `FileManager.replaceItemAt` (atomic replace), removes the file entirely when nothing survives, and never throws.
8. **INV-10 property honesty**: §6.1's transport contract is FIFO (`transferUserInfo`). Shuffled delivery with an advancing watermark legitimately BLOCKS unseen lower-seq events (seq 5 applied first → watermark 5 → seq 3 blocked) — that IS the guard working. So the property suite pins: exactly-once under FIFO + duplicates/replays/redeliveries (the contract's stream shape, second pass complete no-op), and at-most-once under 3 seeded shuffles of a doubled multiset (σ-independent: WHICH members survive the shuffle-order varies, that none double-applies does not).

### DISCLOSURES

1. **Hand-written `Codable` on both DTOs** (task constraint said "synthesize Codable, disclose if hand-written"): `DisplayState` and `QuestGeneration.QuestLine` are not Codable, and `InteractionIntent`'s nested `Source`/`Kind`/`PatGesture`/`TouchZone` are Sendable-only — synthesizing would have required MomoCore changes (FORBIDDEN). The conformances live entirely in MomoKit; MomoCore diff is EMPTY (verified below). Enum encodings delegate to exhaustive case-name string maps; a new MomoCore case breaks the build in `SyncDTOs.swift` (compile-time pin). DisplayState encodes as the nested §4.11 keyed container; QuestLine/toolchain-canonical keyed enums (`{"wish":"Q6"}`, `{"awake":{}}`); greeting encodes explicitly → `null`.
2. **Hand-written `Equatable` on `IntentEvent`** (separate extension, field-wise `==`): `InteractionIntent` itself is not Equatable. Roundtrip pins and the 9-mutation field test depend on it.
3. **`#if DEBUG print`** for defined skip paths (see decision 5) — the only non-trapping loud channel under the Foundation-only import whitelist.
4. **First-run golden-pin correction**: the two hand-statable canonical-bytes expectations initially guessed bare-string `bondStage`/`wakefulness` and a `watchSeq`-terminal object; actual output uses keyed enums (`{"awake":{}}`) and `watchSessionEpoch` sorts last. Production codec unchanged — roundtrips + the independent-encoder cross-check passed on the first run; only my test-side expectations were corrected to the recorded actual bytes.
5. `QuestProgress`'s synthesized Codable decode bypasses its failable init (INV-6 not re-enforced on decode) — noted, no claim made otherwise; the builder threads questInputs verbatim and adds no validation of its own (the engine owns INV-6).

### Per-test inventory

**SyncDTOTests.swift** (16 functions; parameterized cases counted in suite totals): populated snapshot roundtrip; QuestLine ×8 roundtrip; greeting ×5 roundtrip; populated event roundtrip; every kind ×20 roundtrip (+direct kind assertion); attribution (dayKey + timestamp) verbatim; iPhone source roundtrip; encoding byte-stability (both DTOs); production encoder == independent encoder (both DTOs); snapshot canonical bytes pinned (hand-statable string); event canonical shape pinned (keyed kind, null zone, nested intent, key order); unknown snapshot version ×3 → nil; unknown event version ×3 → nil; current version decodes; garbage/empty bytes → nil; IntentEvent `==` field-wise (9 single-field mutations).

**IntentJournalTests.swift** (14): append→parse FIFO roundtrip (+format pins: 0x0A-terminated, N lines); append creates missing directory; torn trailing line skipped, prefix survives; append after tear preserves the new event; mid-file garbage line skipped; blank lines ignored; unknown-version line skipped; prune boundary ≤ (watermark 3 drops seq 3; watermark 2 keeps it); stale-epoch watermark prunes NOTHING (byte-identical); two-epoch journal prunes per entry; epoch identity held across prune; matched prune byte shape; prune leaves no temp; absent journal empty + stays absent; pure prune core total (empty/all-dropped/watermark-0/500-event).

**WatchSyncGateTests.swift** (12 functions, 15 cases): fresh epoch applies at seq 1 (0-init, wrapper + raw); duplicate UUID no-op even at seq 99; unseen-UUID replay at/below watermark no-op (retention interplay); boundary seq == watermark no-op, seq+1 applies; both guards pass applies; stale-epoch watermark never gates; epoch reset applies without starvation (old watermark untouched); iPhone reinstall applies warm; expired-dayKey pass-through (gate never reads dayKey); recordingApplied advances per epoch; recordingApplied never regresses (max); INV-10 exactly-once under FIFO + duplicates + replay + full redelivery (+second-pass no-op); INV-10 at-most-once under 3 seeded shuffles (+subset +second-pass no-op).

**SyncStateTests.swift** (10): unseen epoch reads 0 (read doesn't mutate); known epoch reads back; seq consumption 1,2,3 strictly monotone; seeded next seq continues; multi-epoch state roundtrips through store; persisted bytes are plain sorted JSON, no envelope; absent file → fresh, never creates; garbled/empty bytes → fresh; record→save→load identity (watermark + seq durable); save leaves no temp.

**WatchSnapshotBuilderTests.swift** (6 functions, 7 cases): field-for-field threading (display/questInputs verbatim, haptics from settings, epoch = parameter, watermark of THAT epoch only — no epoch1 leak, seq consumed, schemaVersion current); haptics both values ×2; repeated builds consume 1,2,3 through returned sync; empty sync → seq 1 / watermark 0 origin; determinism (identical inputs → identical snapshot+nextSync).

**StoreRulesPinnedTests.swift** (+3): wire schema versions = 1; sync file names byte-for-byte; sync temp names in-namespace.

### Fix loop round 1 (2026-09-09, routed back by the orchestrator per §11)

**Confirmed MAJOR defect** (orchestrator-verified empirically, REVIEW-TASK-023): `SyncStateStore.save` used a plain `moveItem(at: temporary, to: current)`, which fails (NSCocoaErrorDomain Code=516) whenever the destination exists — i.e. every save AFTER the first. The error fell into the catch → `debugLoudFailure` → `assertionFailure` crash in DEBUG builds on the app's second sync-state save; in release the save silently no-oped and the watermark table stayed frozen at its first-save content, degrading INV-10's cross-launch durability to the 64-entry UUID belt alone.

**Why my green suite missed it**: no test saved twice over an existing file — the original re-persistence pin exercised only a FIRST save into a fresh directory, and `saveLeavesNoTempBehind` passed vacuously on the move path. The bug hid behind the untested second-save path. Honest lesson recorded: a persistence pin must include the save-over-existing-file case.

**Why SnapshotStore does not share it** (untouched): its generation rotation (`removeItem(oldest)` → `moveItem(previous→oldest)` → `moveItem(current→previous)`) VACATES `state.json` before its final move; this store has no rotation, so the plain move was never safe here.

**The fix** (confined to `SyncStateStore.swift`): the commit point is now replace-when-present / move-when-absent — `fileExists(current)` → `replaceItemAt(current, withItemAt: temporary, backupItemName: nil, options: [])` (the atomic whole-or-new commit, same precedent as `IntentJournal.prune`); else the first-save `moveItem`. NOT removeItem-then-move (that opens a loss window over the watermark table). `save`'s doc comment and the type header's "SnapshotStore discipline" claim corrected to state WHY plain `moveItem` is insufficient without generation rotation.

**Regression pins added** (`SyncStateTests.swift`): `secondSaveOverExistingFileLands` (save A → save B over the now-existing file → `load() == B` — the second save must LAND; crashes the suite via the DEBUG-loud path if the defect returns) and `secondSaveLeavesNoTempBehind` (temp cleanup on the replace path). Also surfaced and fixed two latent `var`→`let` warnings in the seq-consumption tests on recompile.

### Suite results (exact)

**Original implementation (pre-fix-loop):**

- **Run 1 (full suite, first pass)**: `Test run with 513 tests in 54 suites failed after 0.699 seconds with 2 issues.` — the 2 issues were the disclosed golden-pin expectation mismatches (test-side only; DISCLOSURE 4); corrected to the recorded actual bytes.
- **Run 2 (after correction)**: `Test run with 513 tests in 54 suites passed after 0.537 seconds.`
- **Run 3 (confirmation)**: `Test run with 513 tests in 54 suites passed after 0.542 seconds.` — 0 ✘ lines.

**After fix loop round 1 (both pins + warning fixes in):**

- **Run A**: `Test run with 515 tests in 54 suites passed after 0.632 seconds.` — 0 ✘ lines; both second-save regression pins pass; build clean of warnings (only the pre-existing environment `ld` search-path note).
- **Run B**: `Test run with 515 tests in 54 suites passed after 0.684 seconds.` — 0 ✘ lines.
- **Baseline 451 tests / 49 suites → now 515 / 54** (+64 cases, +5 suites: SyncDTOTests, IntentJournalTests, WatchSyncGateTests, SyncStateTests (12), WatchSnapshotBuilderTests — plus 3 cases grown into StoreRulesPinnedTests).
- Standing discipline scans ran IN-SUITE and passed (no new exemptions): "MomoKit discipline scan — no ambient time/paths, Foundation+MomoCore imports only" ✔; "D-R1 import-whitelist scan" ✔; token-purity suites ✔.

### Git verification (at report time)

- `git diff Sources/MomoCore/` → **EMPTY** (the forbidden boundary is untouched).
- `git diff --stat` → `.claude/tasks/status.md` (orchestrator's own pre-dispatch edit, untouched by me), `Sources/MomoKit/StoreRules.swift` (+44), `Tests/MomoKitTests/StoreRulesPinnedTests.swift` (+20); 10 new untracked files (6 production, 6 test incl. fixture).
- Working tree left DIRTY by design; **nothing staged, nothing committed**.

## Handoff (§28)

### Completed
DTOs + version gates (Req 1/AC-1); journal append/parse/prune + tolerance (Req 4/AC-2); watermark table + gate + builder (Req 5/AC-3, Req 6/AC-5); sync-state persistence (Req 3/AC-4); StoreRules constants + pins; full test matrix incl. the sanctioned unnamed intermediates (duplicate-UUID/higher-seq, unseen-UUID/stale-seq, two-epoch journal, snapshotSeq after file loss). No transport, no Watch store, no UI, no engine changes, no SnapshotStore refactor, no store schemaVersion bump.

### Files Changed
New: `Sources/MomoKit/{SyncDTOs,SyncState,SyncStateStore,WatchSyncGate,WatchSnapshotBuilder,IntentJournal}.swift`; `Tests/MomoKitTests/{SyncDTOTests,IntentJournalTests,WatchSyncGateTests,SyncStateTests,WatchSnapshotBuilderTests}.swift`; `Tests/MomoKitTests/Support/SyncFixture.swift`. Edited: `Sources/MomoKit/StoreRules.swift`, `Tests/MomoKitTests/StoreRulesPinnedTests.swift`; fix-loop round 1: `Sources/MomoKit/SyncStateStore.swift`, `Tests/MomoKitTests/SyncStateTests.swift`. Untouched: all of `Sources/MomoCore/` (verified empty diff after the fix too) and `SnapshotStore.swift`.

### Tests Run
`swift test` full suite — five complete runs total (three original, two post-fix; exact lines above); `swift build --build-tests` zero warnings (only a pre-existing environment `ld` search-path note).

### Test Results
**515 tests / 54 suites PASSED** on both post-fix runs (runs A–B). History: run 1 = 513/54 with the 2 disclosed golden-pin expectation corrections; runs 2–3 = 513/54 clean; fix loop added 2 regression pins (+2). Baseline delta +64/+5.

### Known Issues
None open. (QuestProgress INV-6 decode bypass noted as disclosure 5 — pre-existing MomoCore shape, out of scope by the MomoCore freeze.)

### Decisions Made
Per-event journal epoch; equality version gates; haptics from engine settings; snapshotSeq per-file-lifetime scope (reset = display no-op); DEBUG-loud split (assertionFailure vs print); tear-sealing append; `replaceItemAt` prune; FIFO-honest INV-10 property design; fix-loop: replace-when-present / move-when-absent sync-state commit point.

### Reviewer Status
PENDING — fix-loop round 1 applied (orchestrator's confirmed MAJOR in `SyncStateStore.save` fixed + pinned; see "Fix loop round 1" above). Reviewer should verify the fix shape (no removeItem-then-move), both regression pins, and re-derive the prune boundary (`≤` + epoch match), the 0-init unseen-epoch default, and the version gates from DOC 05 §6.2/§6.4 independently.

### Commit
None (per contract — orchestrator commits after review).

### Push
None.

### Recommended Next Step
Spawn the fresh independent review agent (REVIEW-TASK-023), then fix-loop if needed, then orchestrator commits (`feat(kit): TASK-023 ...`) and pushes on `feature/EPIC-005-persistence`.

## Reviewer Findings
(reviewer fills; verdict record at `.claude/tasks/reviews/REVIEW-TASK-023.md`.)

## Completion Evidence
(orchestrator fills at housekeeping.)
