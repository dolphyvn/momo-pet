# EPIC-005 — Persistence & Sync Logic (MomoKit)

## Objective
Implement MomoKit per ADR-002 and ADR-003's pure logic: the Codable `SnapshotStore` (envelope `{schemaVersion, savedAt, checksum, payload}`, atomic writes, 3-generation recovery), the additive-first migration chain with retention/pruning, and the sync layer's pure halves — versioned DTOs, the append-only intent journal, and epoch-scoped watermark arithmetic — proven by the §32 Persistence matrix, sync idempotency properties, and the Kit ≥ 80 % coverage floor.

## User / Product Value
Momo's memory. Nothing the user does may be lost to a crash, a corrupt file, or an OS update (FR-13, NFR-7), and nothing the Watch does may happen twice (FR-18). This epic makes both guarantees provable before any transport exists.

## Scope
- `SnapshotStore` (05 §5.1–5.3): write-temp-then-atomic-rename, serialized per event, write-through; read path current → `.prev` → `.prev2` → fresh default with **no error surface**; intent ledger travels inside the payload.
- Retention/pruning (05 §5.4): 7-day DayRecord retention, processedIntents ≤ 64, deterministic.
- Migration (05 §5.5): additive decode defaults; explicit pure `migrate(v→v+1)` chain for breaking changes; fresh-install vs upgrade parity (NFR-7).
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
4. Pruning deterministic; 7-day/64-item caps hold (05 §5.4 + §4.1 `processedIntentsCapacity`). *(Errata fixed 2026-09-09: the §5.4/§5.5 section refs were swapped and "INV-9" was a mis-citation — INV-9 is the UTC-timestamps invariant, already satisfied by the envelope's `Instant` fields.)*
5. Watermark arithmetic: duplicate delivery and replay are no-ops; unseen epoch initializes at 0; stale-epoch intents never prune (INV-10); expired-dayKey rule implemented.
6. MomoKit ≥ 80 % line coverage recorded.

## Test Requirements
- project.md §32 **Persistence matrix (complete)** per 05 §10.4-pure: save/load roundtrip, migration, corruption/recovery.
- Sync pure halves: exactly-once/idempotency properties over duplicate and reordered delivery streams; watermark arithmetic; codec round-trips across schema versions.
- All green via `swift test` on macOS.

## Definition of Done
All four tasks DONE per CLAUDE.md §18; persistence + sync-pure suites green with coverage floor recorded; reviews APPROVED; atomic TASK-ID commits on `feature/EPIC-005-persistence`, pushed; epic merged to `main`; orchestrator status update.

## Status
IN_PROGRESS (2/4) — branch `feature/EPIC-005-persistence` cut from `main` @ `04d07d6` (the EPIC-004 merge).
- **TASK-021 DONE** — commit `5cca031` (pushed; + chore `0ca305f` routed warning fix). SnapshotStore: envelope `{schemaVersion, savedAt, checksum, payload}`, atomic writes with documented demotion + crash windows, generational recovery, no-error read path, serialized saves/nonisolated loads, StoreRules constants home, non-vacuous discipline scans. Disclosed enabler landed as contracted: 16-type additive Codable closure (conformance-only; `DayRecord` hand-written — `Set<QuestFamily>` bytes are non-canonical without declaration-order encoding, per-process AND per-encode-call). `swift test` 417/46 green (baseline was 369/43). Review: APPROVED_WITH_MINOR_NOTES (REVIEW-TASK-021) + a post-review flake (~14 %, unsound FIFO-assumption order-pins) fixed through a two-round §11 loop delta-verified APPROVED (REVIEW-TASK-021-FLAKEFIX-VERIFICATION; savedAt adjacency pins prove the convergence clause — an executable freeze mutation kills every weaker pin). Observation routings: OBS-1/OBS-5 → TASK-022 contract; OBS-3 documented-limit note rides TASK-022.
- **TASK-022 DONE** — commit `3acc54f` (pushed). Migration chain + retention/pruning (05 §5.4 retention, §5.5 migration; NFR-7): `LedgerRetention` (pure/total prune — 7 newest dayKeys via `StoreRules.retainedDayCount`, last-64 belt REUSING MomoCore's `processedIntentsCapacity`, applied on the save path; engine stays append-only, REVIEW-TASK-015 routing discharged), `MigrationChain` (injected value-data `{from, apply}` steps, to = from+1 derived, nil on missing hop / above head), SnapshotStore amended (injected chain default `.empty` — production ships EMPTY, NO schemaVersion bump; gate order decode → range → checksum → walk → serve, checksum precedes migration by construction; prune-before-encode with the single `clock.now()` preserved so TASK-021's savedAt-adjacency pins hold). All three TASK-021 routings landed: OBS-1 golden-bytes pin (1827-byte out-of-process literal, tamper-refusing, documented re-record obligation), OBS-5 unknown-version tests rewritten against the chain (raw `== 1` pin intact), OBS-3 documented toolchain-bytes limit. `swift test` **451/49 green** (baseline 417/46). REVIEW-TASK-022 **APPROVED_WITH_MINOR_NOTES** (0 MAJOR; retention arithmetic re-derived before comparing; mutations A/B/C bit exactly: 10/1/2 designed bites, hash-proven restores). Disposition pre-commit: MINOR-1 dead fixture deleted, NITPICK-2 unused imports removed, NITPICK-1 resolved with a diagnosis correction — the shipped selection was Set-LAST (reviewer read it as Set-first/prose-only); reordered to Set-first matching the documented no-crowding semantics, comment fixed, duplicate-dayKey defect pin strengthened with the boundary case, bite-proven live (`554e342b…` hash-proven across the mutation). MomoCore diff EMPTY throughout.
- Next: TASK-023 sync DTOs + intent journal + watermark arithmetic (05 §6.2, §6.4, ADR-003).
