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
READY — dispatched 2026-09-09 (branch `feature/EPIC-005-persistence` @ `b5a390e`; baseline 451/49 green).

## Implementation Notes
(implementation agent fills: API shape, design decisions + disclosures, test inventory, suite results, §28 Handoff.)

## Reviewer Findings
(reviewer fills; verdict record at `.claude/tasks/reviews/REVIEW-TASK-023.md`.)

## Completion Evidence
(orchestrator fills at housekeeping.)
