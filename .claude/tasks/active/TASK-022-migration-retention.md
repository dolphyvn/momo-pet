# TASK-022 — Migration chain + retention/pruning (05 §5.4 retention, §5.5 migration; NFR-7)

## Parent Epic
EPIC-005 — Persistence & Sync Logic (MomoKit), task 2 of 4 (size S). Epic acceptance criteria served: AC-3 (migration chain pure and total; upgrade path produces identical engine-visible state to a fresh install seeded with the same history — NFR-7 parity), AC-4 (pruning deterministic; 7-day/64-item caps hold). Resolves the REVIEW-TASK-015 ledger-pruning owner note ("the store owns persistence + retention; engine stays append-only").

## Objective
Give the TASK-021 store its two remaining §5 obligations, headlessly testable on macOS: (1) **retention/pruning** — 05 §5.4's 7-day `DayRecord` window and the ≤ 64 `processedIntents` cap, applied deterministically by the store so the persisted payload always satisfies the caps while the engine stays append-only; (2) **the migration chain** — 05 §5.5's explicit pure `migrate(v→v+1)` machinery walked by the read path for below-current versions, with above-chain versions skipping the generation (making TASK-021's unknown-version behavior principled rather than special-cased). NO schemaVersion bump, NO payload-shape change — additive evolution is the norm (§5.5), and v1 is correct as shipped.

**Section-number correction (binds over the epic prose):** in `docs/architecture/05-technical-architecture.md`, **§5.4 is Retention & pruning and §5.5 is Migration policy** (the epic file's Scope prose cites them swapped — fixed at dispatch). Cite the DOC, not the epic, as normative.

**Invariant-citation correction (binds over the epic AC prose):** epic AC-4's "(INV-9)" is a mis-citation — INV-9 is the UTC-timestamps invariant (already satisfied by the envelope's `Instant` fields). The caps' normative sources are **05 §5.4** (7-day window, ≤ 64 "recent", determinism, unit-tested) and **05 §4.1** + the existing MomoCore constant `processedIntentsCapacity = 64` (`Sources/MomoCore/EngineState.swift:74`). The epic AC-4 wording is corrected at dispatch.

## Context
- **Codebase state:** TASK-021 complete (`5cca031`): `Sources/MomoKit/SnapshotStore.swift` (actor saves, `nonisolated` loads, 5-step demotion, gate order decode → schemaVersion-check → checksum → payload decode → serve, unknown version ⇒ generation skipped), `Sources/MomoKit/StoreRules.swift` (constants home: `currentSchemaVersion = 1`, file names, generation count = 3, `defaultDirectory()` — the one sanctioned ambient-path site), test suites `SnapshotStoreTests` / `SnapshotStoreConcurrencyTests` / `StoreRulesPinnedTests` / `MomoKitDisciplineScanTests` + `Support/` (StoreFixture, MomoKitDisciplineScan, KitRepo). Baseline `swift test` = **417 tests / 46 suites green**.
- **Engine is append-only — the store owns retention** (REVIEW-TASK-015 routing, standing note in status.md): `EngineState.days` may exceed 7 in memory; pruning happens in MomoKit on the persist path. Do NOT touch engine/fold code. TASK-018's quest generation reads the in-memory prior-two tail and is unaffected; on restart the loaded state carries ≤ 7 days, which serves all three §5.4 consumers (the rolling 3-day quest-generation window §4.8, late Watch-intent attribution §6.4, dayKey-keyed once-only clock-change resets §4.3). Applying the prune on EVERY save (not literally "at rollover") is a documented, deterministic superset of §5.4's intent — state that equivalence in the code header.
- **REUSE, never re-implement:** the 64 cap MUST be `MomoCore`'s `processedIntentsCapacity` (EngineState.swift:74) — redeclaring a literal 64 in MomoKit is a defect (anti-echo house discipline). The 7-day count is NEW normative surface → declare it in `StoreRules` (e.g. `retainedDayCount = 7`) with an authority label ("05 §5.4") and a raw-literal pin, mirroring the existing constants' discipline.
- **`DayKey` ordering:** `DayKey.make` returns a zero-padded `"YYYY-MM-DD"` string (`Sources/MomoCore/DayKey.swift:26`, `%04d-%02d-%02d`), so **lexicographic order == chronological order**. Retention keeps the 7 lexicographically-greatest dayKeys. PIN this format assumption in a named test (a mis-ordered fixture must fail) — it is load-bearing for determinism.
- **Shapes:** `EngineState.days: [DayRecord]`, `EngineState.processedIntents: [UUID]` (append order = recency order; keep the LAST 64). `DayRecord` carries its `dayKey` string.
- **TASK-021 review routings — MANDATORY folds in this task:**
  - **OBS-1 (cross-process/golden-bytes load pin):** the shipped suite never loads bytes recorded OUTSIDE the running process, so the exact failure mode Disclosure 1 guards against is real but unpinned. Add a pin that crafts a generation file from RECORDED literal payload bytes (a fixture JSON captured from a real save — raw string in the test) and loads it through the public API: checksum over recorded bytes verifies and the fixture state is served exactly.
  - **OBS-5 (unknown-version tests):** `SnapshotStoreTests`' unknown-version tests use raw `2`/`9` with skip semantics. Rewrite them against the chain machinery (below), so the skip is the chain's above-head rule, not a special case. The contract-mandated raw `schemaVersion == 1` pin stays.
  - **OBS-3 (documented limit):** the checksum recipe is coupled to the toolchain's canonical Codable byte shape (this toolchain encodes simple enums as keyed objects, e.g. `{"settle":{}}`). A future toolchain changing canonical bytes fails ALL generations' checksums at once → fresh default; self-consistent (write and read share the encoder) and contract-compliant, but it must be DOCUMENTED as a stated limit — a short note in the `SnapshotStore` header (or `StoreRules`, implementer's choice) and in the task's Implementation Notes. No code beyond the note.
- **Fresh-default/fallback machinery, injected clock, injected directory, `loads-never-write`, and the standing MomoKit discipline scans are all TASK-021 deliverables — preserve their pins.** Any scan exemption change is a DISCLOSURE.
- 05 §5.5's "additive evolution is the norm" means: do not invent a migration for a change that hasn't happened. The production chain ships EMPTY (current = 1). The mechanism is proven with synthetic steps/fixtures injected in tests (see Design), clearly labeled as mechanism tests, not as a record that v0 ever existed.

## Requirements
1. **Retention function (pure, deterministic, total).** A pure `EngineState -> EngineState` prune: keep the 7 most-recent `DayRecord`s by dayKey (lexicographic; ties impossible for distinct dayKeys — if duplicates ever appear, keep the first and treat it as a defect pin), keep at most the 64 most-recent `processedIntents` (array order), preserve relative order of survivors, never drop the current day (subsumed by keep-newest-7; pin it anyway), total on every input (empty, under-cap, at-cap, oversized). Applied in the store's WRITE path (save prunes before encode), so on-disk payloads always satisfy the caps; the read path does NOT prune (loads never write/mutate — TASK-021 pin stands).
2. **Migration chain (injected, pure, total).** A step is `{from: Int, apply: (EngineState) -> EngineState}` (to = from+1; explicit `to` also acceptable — implementer's shape, justify). `SnapshotStore` gains an injected chain parameter (default EMPTY = production). Read-path version gate becomes: `v == current` → serve; `v < current` → walk steps v→v+1→…→current, applying each; any missing step in the walk ⇒ generation unreadable; `v > current` ⇒ generation unreadable (above chain head — the principled form of TASK-021's unknown-version rule). Unreadable ⇒ fall through to the next generation exactly as before (no error surface ever). Migrations are pure and total (05 §5.5: "no failure path — worst case maps to a valid default"). The chain is VALUE data (no global mutable registry — house injection discipline).
3. **Gate order amendment.** The integrity gates run BEFORE migration: decode envelope → version range check → checksum recompute over the DISK bytes → payload decode → migrate walk → serve. Checksum verifies what is on disk; migration is pure in-memory afterward. Document the order in the header and pin it (a migration must never run for a generation that fails its checksum).
4. **Re-persistence semantics.** Saves always stamp `StoreRules.currentSchemaVersion` (unchanged behavior); a state loaded through migration is simply the state in memory — the next save persists it at current version with a fresh checksum. Pin this (load-migrated → save → load == same state).
5. **Golden-bytes pin (OBS-1).** As described in Context: recorded literal payload bytes → crafted generation → public-API load serves the fixture state exactly. The recorded bytes must include a full envelope whose checksum is the REAL recipe output over those payload bytes (compute it at fixture-authoring time and pin the hex, or derive it in-fixture via `MomoCore.SHA256` — implementer's choice, justify; the pin must fail if either the bytes or the recipe drift).
6. **Constants + discipline.** `StoreRules.retainedDayCount = 7` (authority-labeled, raw-literal-pinned); `processedIntentsCapacity` REUSED from MomoCore; no schemaVersion change; imports stay Foundation+MomoCore; no ambient time/paths (the existing scans must stay green with no new exemptions — run them as part of the suite).
7. **No scope creep:** no Watch-side stores (§5.6), no sync DTOs/journal/watermarks (TASK-023), no `DailyProgress.steps` field (C5 is a Phase-2 extension point, NOT a present-but-empty column — 05 §5.5 says so explicitly), no `EngineState`/MomoCore changes at all (expected diff on `Sources/MomoCore/` is EMPTY; any touch is a DISCLOSURE with justification).

## Files / Areas Likely Affected
- `Sources/MomoKit/SnapshotStore.swift` — injected chain param, version-gate amendment, prune-on-save call, header notes (gate order, OBS-3 limit, save-prune equivalence).
- `Sources/MomoKit/StoreRules.swift` — `retainedDayCount` (+ authority label + pin updates in `StoreRulesPinnedTests`).
- NEW `Sources/MomoKit/` file(s) for the retention function and the migration-step type (implementer's split; house file-size discipline, ~200–400 lines typical).
- `Tests/MomoKitTests/` — new retention tests, new migration/chain tests, rewritten unknown-version tests (OBS-5), golden-bytes pin (OBS-1), `StoreRulesPinnedTests` growth. `Support/StoreFixture` may grow builders (oversized states: e.g. 30-day ledgers, 200-intent ledgers).
- NOT affected: `Sources/MomoCore/**` (must be empty diff), `Package.swift`, app targets.

## Dependencies
- TASK-021 (complete, `5cca031`). No new external dependencies.

## Constraints
- Headless macOS `swift test` only; injected directory/clock everywhere; no ambient `Date()`/paths in MomoKit (standing scans).
- No commits by the implementation agent (orchestrator commits after independent review).
- §26: any unavoidable temporary debt gets an attached explanation in Implementation Notes.

## Acceptance Criteria
1. On-disk payloads always satisfy: `days.count ≤ 7` (7 newest by dayKey) and `processedIntents.count ≤ 64` (64 newest) — pinned by tests over oversized fixtures (AC-4; normative sources 05 §5.4 + §4.1 + `processedIntentsCapacity`).
2. Pruning is deterministic (same input → same output; prune∘prune == prune) and total; survivors' relative order preserved; current day never dropped.
3. Read path walks the migration chain for below-current versions; above-head or missing-step generations fall through silently; the public API still never throws and never serves an error or a mixed state (AC-3; TASK-021's no-error pins all still green).
4. NFR-7 parity: for the mechanism fixtures, a generation loaded THROUGH synthetic migration steps yields a state equal to the equivalent freshly-built state (fresh-install vs upgrade identical behavior) — pinned.
5. Golden-bytes pin (OBS-1) green: recorded out-of-process payload bytes load through the public API with checksum verification.
6. Unknown-version tests (OBS-5) rewritten against the chain; `currentSchemaVersion == 1` raw pin unchanged; full `swift test` green with the standing scans; `Sources/MomoCore/` diff EMPTY.

## Required Tests
- Retention: under-cap passthrough (≤ 7 days, ≤ 64 intents unchanged), oversized fixtures (e.g. 30-day ledger → exactly the 7 newest; 200 intents → exactly the last 64), survivor order, current-day-never-dropped, idempotence, empty-ledger totality, dayKey lexicographic==chronological format pin.
- Migration: single-step and multi-step walks; missing-step skip; above-head skip (rewritten OBS-5 tests); purity (no throwing); migrate→save→load roundtrip at current version; NFR-7 parity pin; chain-is-value pin (two stores, different chains, independent).
- Gate-order pin: a generation that FAILS its checksum never migrates (falls through) even when a step exists.
- Golden-bytes (OBS-1) per Requirement 5.
- `StoreRulesPinnedTests` growth for `retainedDayCount`; all standing discipline scans green in-suite.
- Concurrency suites untouched and still green; if any new test shares the concurrency suite's shapes, respect the TASK-021 σ-independence lesson (status.md Important Context).

## Review Requirements
Standard independent adversarial review (CLAUDE.md §10/§33). Reviewer MUST:
- Re-derive the retention arithmetic from 05 §5.4 + §4.1 independently (7-newest-by-dayKey; 64-newest-by-order) BEFORE comparing with the implementation; verify the `processedIntentsCapacity` REUSE (grep for any new literal 64/7 in MomoKit).
- Verify `git diff Sources/MomoCore/` is EMPTY and no schemaVersion bump occurred (raw pin + mutation: change `currentSchemaVersion` 1→2 and observe the designed bites).
- Verify gate ORDER (checksum before migration) — sanctioned mutation: make a below-current generation with a corrupt checksum and a registered step; it must fall through, never migrate.
- Attempt unnamed intermediates: below-current generation + chain with a gap; above-head version with steps registered; oversized ledger at exactly cap+1; duplicate dayKey fixture (defect pin must bite).
- At least two sanctioned mutations with byte-identical restore proof (cmp + sha256), e.g. `retainedDayCount` 7→6 (pins must bite) and the gate-order swap above.
- Verify the OBS-1 golden-bytes pin actually pins bytes (would a recipe or fixture drift fail it?).
- Verify OBS-3's documented limit exists in the header/notes.
- Re-run the full suite; confirm the TASK-021 concurrency suites are untouched.

## Git Requirements
- Branch `feature/EPIC-005-persistence`; implementation agent does NOT commit.
- Orchestrator commits atomically: `feat(persistence): TASK-022 migration chain + retention/pruning`.
- "(this commit)" convention for the task file's Completion Evidence.

## Status
READY — dispatched 2026-09-09 (branch `feature/EPIC-005-persistence` @ `3bda6ff`; baseline 417/46 green).

## Implementation Notes
(implementation agent fills: API shape, design decisions + disclosures, test inventory, suite results, §28 Handoff.)

## Reviewer Findings
(reviewer fills; verdict record at `.claude/tasks/reviews/REVIEW-TASK-022.md`.)

## Completion Evidence
(orchestrator fills at housekeeping.)
