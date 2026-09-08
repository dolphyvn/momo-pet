# ADR-002 — Local-First Persistence: Plain Codable File Store (not SwiftData)

## Status
PROPOSED — under review (TASK-006). Becomes ACCEPTED upon REVIEW-TASK-006 approval. Implements TASK-002 D14 ("SwiftData, *or* a plain Codable file store if SwiftData adds no value at this data volume… The ADR, not this review, is binding").

## Context
Phase 1's entire dataset is one pet: scalars, one 7-day day-ledger, quest progress, settings — a few KB of value types (05-technical-architecture §3). The binding requirements are behavioral, not relational: atomic saves (PRD NFR-7), force-quit loss ≤ 1 s (FR-13 AC-1), corruption recovery to the last valid snapshot with no user-visible surface (FR-13 AC-2, UX §9), invisible migration on upgrade (NFR-7, §32 "upgrade" edge), and headless testability. Sync transfers DTOs, never raw stores (TR4), so no persistence technology is shared with the Watch. project.md §21 mandates local-first; §22 forbids enterprise abstractions without demonstrated value.

## Decision
**A plain Codable file store owned by `MomoKit`**: JSON envelope `{schemaVersion, savedAt, checksum, payload}`; write path = encode → temp file → atomic rename, serialized per event (write-through); three retained generations (`state.json`, `.prev`, `.prev2`) for corruption recovery; read path = current → prev → prev2 → fresh default, all invisible; additive schema evolution with decode defaults, explicit `migrate(v→v+1)` chain only for breaking changes; 7-day day-ledger retention with deterministic pruning. Full spec: 05-technical-architecture §5.

## Alternatives Considered
- **SwiftData:** first-party, offers querying, relationships, migration tooling, and a Phase 2 CloudKit path. Rejected for Phase 1: at one-pet data volume its query/relationship machinery buys nothing; its store semantics (atomicity exposure, corruption behavior) sit *inside* the guarantees FR-13 makes, so a custom snapshot/generation layer would be built around it anyway; in-memory test containers and migration semantics are heavier to test than pure encode/decode. Revisit gate: if Phase 2 approves iCloud sync (D6's justification gate), the store sits behind one narrow protocol and SwiftData+CloudKit vs custom is re-decided with real requirements.
- **UserDefaults:** no generational control, required-reason API under privacy manifests (VERIFY-AT-BUILD), property-list size semantics — rejected.
- **Core Data:** strictly more machinery than SwiftData for less type safety — rejected.
- **SQLite direct:** no query needs exist — rejected.

## Consequences
- FR-13 AC-1/AC-2 hold by construction: write-through bounds loss to the in-flight event; a single bad write recovers to the previous generation invisibly. Total loss of all generations (catastrophic disk failure) regenerates a fresh pet — documented limit, not silently hidden (§5.3).
- Migration is explicit and auditable; fresh-install and upgrade paths are first-class tests (NFR-7).
- `MomoCore` stays persistence-free (value types only), preserving engine purity and macOS-headless tests.
- No CloudKit, SwiftData, or third-party storage dependency exists in Phase 1 (FR-20 AC-3 posture preserved).
- Phase 2 note: an app-group container for widgets (§8) would move file protection to `CompleteUntilFirstUnlock` — an enumerated, VERIFY-AT-BUILD change.

## Date
2026-09-08
