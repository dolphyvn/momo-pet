# EPIC-005 — Persistence & Sync Logic (MomoKit)

## Objective
Implement MomoKit per ADR-002 and ADR-003's pure logic: the Codable `SnapshotStore` (envelope `{schemaVersion, savedAt, checksum, payload}`, atomic writes, 3-generation recovery), the additive-first migration chain with retention/pruning, and the sync layer's pure halves — versioned DTOs, the append-only intent journal, and epoch-scoped watermark arithmetic — proven by the §32 Persistence matrix, sync idempotency properties, and the Kit ≥ 80 % coverage floor.

## User / Product Value
Momo's memory. Nothing the user does may be lost to a crash, a corrupt file, or an OS update (FR-13, NFR-7), and nothing the Watch does may happen twice (FR-18). This epic makes both guarantees provable before any transport exists.

## Scope
- `SnapshotStore` (05 §5.1–5.3): write-temp-then-atomic-rename, serialized per event, write-through; read path current → `.prev` → `.prev2` → fresh default with **no error surface**; intent ledger travels inside the payload.
- Migration (05 §5.4): additive decode defaults; explicit pure `migrate(v→v+1)` chain for breaking changes; fresh-install vs upgrade parity (NFR-7).
- Retention/pruning (05 §5.5): 7-day DayRecord retention, processedIntents ≤ 64, deterministic.
- Sync pure logic (05 §6.2, §6.4): `WatchSnapshot` + `IntentEvent` Codable versioned DTOs; NDJSON journal; per-`watchSessionEpoch` watermarks (0-init on unseen epoch, epoch-matched pruning only, INV-10); expired-dayKey intent rule (current-state effects, day attribution dropped).
- Test suites (TASK-024): roundtrip, corruption recovery, torn writes, migration chain, watermark/idempotency properties, codec versioning.

## Non-Goals
WatchConnectivity transport (EPIC-008), any UI, engine logic, iCloud/CloudKit (D6 gate), keychain/entitlements. No error dialogs — persistence failures degrade to fresh-start per contract.

## Dependencies
- EPIC-003 (TASK-012 types); TASK-014's `EngineState` shape for TASK-021.
- Runs as LANE A beside EPIC-004's tail; converges at EPIC-007.

## Tasks
Branch: `feature/EPIC-005-persistence` (from `main`).

| TASK | Title | Size | Depends on |
|---|---|---|---|
| TASK-021 | Implement SnapshotStore — envelope, atomic writes, generational recovery (05 §5.1–5.3, ADR-002) | M | TASK-012, TASK-014 |
| TASK-022 | Implement migration chain + retention/pruning (05 §5.4–5.5) | S | TASK-021 |
| TASK-023 | Implement sync DTOs + intent journal + watermark arithmetic (05 §6.2, §6.4, ADR-003) | M | TASK-012 |
| TASK-024 | Add MomoKit test suites — persistence + sync pure-logic coverage floor (05 §10.2, §10.4 pure halves) | M | TASK-021…023 |

## Acceptance Criteria
1. Force-quit loses ≤ 1 in-flight event (write-through); store read on launch never throws to the caller (AC: FR-13 AC-1).
2. Corrupt/truncated current file recovers via generations; total destruction yields fresh default — silently (05 §5.2).
3. Migration chain pure and total; upgrade path produces identical engine-visible state to a fresh install seeded with the same history (NFR-7 parity test).
4. Pruning deterministic; 7-day/64-item caps hold (INV-9).
5. Watermark arithmetic: duplicate delivery and replay are no-ops; unseen epoch initializes at 0; stale-epoch intents never prune (INV-10); expired-dayKey rule implemented.
6. MomoKit ≥ 80 % line coverage recorded.

## Test Requirements
- project.md §32 **Persistence matrix (complete)** per 05 §10.4-pure: save/load roundtrip, migration, corruption/recovery.
- Sync pure halves: exactly-once/idempotency properties over duplicate and reordered delivery streams; watermark arithmetic; codec round-trips across schema versions.
- All green via `swift test` on macOS.

## Definition of Done
All four tasks DONE per CLAUDE.md §18; persistence + sync-pure suites green with coverage floor recorded; reviews APPROVED; atomic TASK-ID commits on `feature/EPIC-005-persistence`, pushed; epic merged to `main`; orchestrator status update.

## Status
TODO
