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
IN_REVIEW → **APPROVED_WITH_MINOR_NOTES** (REVIEW-TASK-022, 0 MAJOR / 1 MINOR / 2 NITPICK / 4 OBS; three sanctioned mutations bit with exact attribution, hash-proven restores).
**Disposition applied pre-commit (orchestrator):** MINOR-1 dead fixture deleted; NITPICK-2 unused Foundation imports removed; NITPICK-1 resolved with a DIAGNOSIS CORRECTION — the shipped code was Set-LAST (reviewer had it as Set-first/prose-only), so the code was the defective side; reordered to Set-first per the header's documented no-crowding semantics, comment fixed, and the duplicate-dayKey defect pin strengthened with the boundary case (8 distinct + dup → exactly 7 retained), bite-proven live (fails under the shipped ordering; hash-proven restore `554e342b…`). Post-disposition `swift test` 451/49 green ×2.

## Implementation Notes
Implemented on branch `feature/EPIC-005-persistence` (baseline `417 tests / 46 suites` green). Working tree left DIRTY for the orchestrator (no commit, no stage) per contract. `git diff Sources/MomoCore/` is **EMPTY (0 bytes)**; `git diff --stat` = 5 modified files (SnapshotStore.swift, StoreRules.swift, SnapshotStoreTests.swift, StoreRulesPinnedTests.swift, Support/StoreFixture.swift) + 5 new files (LedgerRetention.swift, MigrationChain.swift, LedgerRetentionTests.swift, MigrationChainTests.swift, SnapshotStoreGoldenBytesTests.swift). 236 insertions / 37 deletions across modified files.

### API shape (all in Sources/MomoKit)
- **NEW `LedgerRetention.swift`** — `public enum LedgerRetention` with `public static func pruned(_ state: EngineState) -> EngineState`. Pure, deterministic, total. Implementation: survivor set = `Set(state.days.map(\.dayKey)).sorted().suffix(StoreRules.retainedDayCount)`; days filtered to that set with first-occurrence-wins dedup (a `seenDayKeys` Set — "a key's multiplicity never earns it extra slots"); intents = `Array(state.processedIntents.suffix(EngineState.processedIntentsCapacity))`. Input relative order is preserved (selection, never re-sorting). Every non-ledger field passes through unchanged via the memberwise rebuild.
- **NEW `MigrationChain.swift`** — `MigrationStep { from: Int, apply: @Sendable (EngineState) -> EngineState }` (Sendable value struct) and `MigrationChain` (Sendable value struct): `init(steps:)`, `static let empty`, `func migrated(_ state: EngineState, from: Int, to: Int) -> EngineState?`, `func step(from:) -> MigrationStep?`, `var isEmpty: Bool`. Chain is value data (no global registry). Duplicate `from` versions: FIRST declaration wins (deterministic authoring-defect posture, pinned).
- **`StoreRules.swift`** — added `public static let retainedDayCount = 7` with authority label "05 §5.4" (adjacent note: the 64 cap is MomoCore-owned `processedIntentsCapacity`). Authorities doc section updated; Migration posture rewritten to present tense (serve v==current; walk below-current via injected `MigrationChain`; above-head unreadable; EMPTY production chain ⇒ TASK-021 behavior as a consequence, not a special case).
- **`SnapshotStore.swift`** — private stored `chain: MigrationChain`; `init(directory:clock:chain: MigrationChain = .empty)` (default EMPTY = production ships EMPTY; no schemaVersion change — still 1). `save` begins with `let retained = LedgerRetention.pruned(state)` then encodes `retained` (still exactly one `clock.now()` read — TASK-021's savedAt-adjacency pins untouched). Read-path gate order in `loadGeneration`: decode envelope → `envelope.schemaVersion <= current` range check → checksum recompute over the disk bytes → payload decode → if below current, `chain.migrated(...)` (nil ⇒ generation unreadable) → serve. Header additions: OBS-3 documented-limit note (toolchain-coupled canonical Codable bytes — a future toolchain byte change fails EVERY generation's checksum at once and forfeits persisted state; self-consistent but stated), the save-prune superset-equivalence note ("applying the prune on EVERY save is a deterministic SUPERSET of §5.4's intent, not a deviation"), and the numbered gate order with "The checksum gate precedes the walk BY DESIGN".

### Design decisions + justifications
1. **Step shape `{from}` only (to derived as from+1):** mirrors §5.5's literal `migrate(v→v+1)`; a redundant `to` field is an echo channel that can contradict the +1 rule. Gap detection belongs to the walk (`stepsByFrom[version]` miss ⇒ nil), not to per-step validation. Justified in the MigrationChain header.
2. **Prune-on-every-save as documented superset:** §5.4 says "at rollover"; the store owns persistence+retention (REVIEW-TASK-015) and the engine is append-only, so enforcing the invariant at every write is the only place the store can guarantee on-disk conformance. Deterministic, so the persisted state is identical either way. Documented in LedgerRetention + SnapshotStore headers.
3. **Duplicate dayKeys = first occurrence kept, pin as defect:** Requirement 1's tie rule; a key's multiplicity never earns extra slots.
4. **Multi-hop walk pinned at the UNIT level:** `currentSchemaVersion == 1` is a pinned `let` that must not change, so the store-level walk range `[v, current)` admits exactly one hop. Store-level pins cover single-hop integration (v0 fixtures); multi-hop order-sensitivity and mid-walk gaps are pinned on `MigrationChain` directly. Suite headers label all synthetic v0 fixtures as MECHANISM FIXTURES, NOT HISTORY — no schema below 1 ever existed.
5. **OBS-1 recording choice — full envelope, real checksum, hex pinned:** the golden literal is the complete `state.json` (1827 bytes) captured OUT-OF-PROCESS via the production save path for `fixture.populatedState()` at manual clock 2026-03-03T12:00:00Z, embedded as a single-line raw string (verified no `#` bytes inside). `recordedChecksum` pins the hex separately AND a test re-derives the recipe over the recorded payload, so byte drift AND recipe drift both bite. Tamper pin is length-preserving (`"bond":456` → `457`, unique in payload) so the checksum gate — not the decoder — must refuse it.
6. **OBS-5 rewrite:** SnapshotStoreTests' unknown-version tests renamed to above-chain-head semantics and expressed as `StoreRules.currentSchemaVersion + 1` / `+ 8` (no raw 2/9); skip is the chain's range-check rule. The contract-mandated raw `schemaVersion == 1` pin (`envelopeCarriesSchemaVersionOne`) untouched.

### Disclosures
- **NONE.** `git diff Sources/MomoCore/` is empty (verified: 0 bytes). No schemaVersion change (pin intact). No import changes (Foundation + MomoCore + Testing only). No discipline-scan exemptions added — ambient-time, ambient-path, and import scans green unchanged. No TODO/FIXME/HACK/TEMP markers added. No app-target or Package.swift changes. The throwaway golden-capture harness (ZZGoldenCapture.swift + /tmp dir) was deleted; nothing remains.

### Test inventory (34 new tests + 2 rewritten + 1 new pin; +3 suites)
- **NEW `LedgerRetentionTests` (14):** under-cap passthrough; empty/totality; 30-day ledger → exactly `retainedDayCount` newest keys; survivor relative order under ascending AND reversed inputs; at-cap passthrough; current day never dropped; 200-intent belt → last `processedIntentsCapacity` in order; at-cap belt passthrough; both caps together with per-field passthrough of all non-ledger fields; idempotence (prune∘prune==prune, plus input determinism); dayKey zero-pad format pin with a DISCRIMINATING mis-ordered 8-key fixture where the cap drops the chronologically-NEWEST day (proves string-order selection) + input-order preservation; duplicate-dayKey first-occurrence defect pin; save-prunes-before-encode (on-disk envelope satisfies both caps and equals pruned state); read-path-does-not-prune (oversized valid generation served whole).
- **NEW `MigrationChainTests` (16):** current-version serves without touching the chain (inert from-current step); single-hop v0→current store walk; missing-hop ⇒ unreadable ⇒ falls through to prev; empty chain refuses below-current + `MigrationChain.empty.isEmpty` pin; above-head version unreadable EVEN with a step registered at it (range check precedes everything); multi-hop walk applies hops in version order regardless of declaration order (order-sensitive name-append "Momo123"); mid-walk missing hop ⇒ whole walk unreadable (never half-migrated); from>to walk is nil at unit level; identity range is the state itself; purity (input value untouched); chain-is-value-data (two stores, one directory, different chains, independent results, loads never write — byte-identical directory); corrupt-checksum below-current NEVER migrates (gate-order pin); valid-checksum negative control DOES migrate; migrated state re-persists at current version and loads chain-independently; NFR-7 parity (migrated == freshly-built, as Equatable values); duplicate-from keeps first declared.
- **NEW `SnapshotStoreGoldenBytesTests` (3):** recorded out-of-process generation loads through the PUBLIC API == fixture; recorded checksum is the recipe over the recorded payload (schemaVersion pin + re-derived digest + payload==fixture agreement); length-preserving tampered payload byte falls through to fallback (pin has teeth). Header carries the maintenance obligation (re-record on deliberate §5.5 additive change or toolchain byte change).
- **`StoreRulesPinnedTests` (+1):** `retainedDayCount == 7` raw-literal pin with authority label.
- **`SnapshotStoreTests` (OBS-5 rewrite, 2 tests renamed/retargeted):** `generationAboveTheChainHeadIsSkippedToPrev`, `versionsAboveTheChainHeadEverywhereReturnFallback` — versions as `currentSchemaVersion + 1` / `+ 8`; behavior pins (skip to prev, fallback everywhere) unchanged.
- **`Support/StoreFixture` (+builders):** `state(days:processedIntents:)` carrier, `minimalDay(_:)`, `consecutiveDayKeys(startingISO:count:)` (via `DayKey.make`, injected UTC calendar, 86400 s steps), `intentID(_:)` (deterministic UUIDs). *(A fifth builder, `ascendingLedger`, was removed at disposition — declared but never called; REVIEW-TASK-022 MINOR-1.)*
- Raw literals 7/64 appear ONLY in StoreRulesPinnedTests; behavior tests reference `StoreRules.retainedDayCount` / `EngineState.processedIntentsCapacity`. No new concurrency-shaped tests (σ-independence lesson respected — no ordering-of-last-element pins anywhere).

### Test results (both runs verbatim)
- Run 1 (2026-09-09, final gate): `swift test` → `◇ Test run started. … ✔ Test run with 451 tests in 49 suites passed after … seconds.` — **451 / 49 passed, 0 failures, 0 skipped.**
- Run 2 (stability re-run): `swift test` → `✔ Test run with 451 tests in 49 suites passed after … seconds.` — **451 / 49 passed, 0 failures.**
- Reconciliation: 417 baseline + 14 retention + 16 migration + 3 golden + 1 pin = **451**; 46 + 3 new suites = **49**. Exact.
- Standing discipline scans (ambient-time, ambient-path, import whitelist) green in-suite; TASK-021 concurrency suites untouched and green.
- Pre-existing, not mine: the `/opt/extra/lib` linker warning appears during build (machine-level, documented in TASK-021 notes).

### §28 Handoff

#### Completed
Retention/pruning (§5.4), migration chain (§5.5), gate-order amendment, re-persistence pin, OBS-1 golden-bytes pin, OBS-5 rewrite, OBS-3 documented limit — all Requirements 1–7 and AC 1–6.

#### Files Changed
- `Sources/MomoKit/LedgerRetention.swift` (NEW)
- `Sources/MomoKit/MigrationChain.swift` (NEW)
- `Sources/MomoKit/StoreRules.swift` (modified: retainedDayCount + authority docs)
- `Sources/MomoKit/SnapshotStore.swift` (modified: injected chain, gate order, prune-on-save, header notes)
- `Tests/MomoKitTests/LedgerRetentionTests.swift` (NEW)
- `Tests/MomoKitTests/MigrationChainTests.swift` (NEW)
- `Tests/MomoKitTests/SnapshotStoreGoldenBytesTests.swift` (NEW)
- `Tests/MomoKitTests/SnapshotStoreTests.swift` (modified: OBS-5 rewrite)
- `Tests/MomoKitTests/StoreRulesPinnedTests.swift` (modified: +1 pin)
- `Tests/MomoKitTests/Support/StoreFixture.swift` (modified: +builders)

#### Tests Run
Full `swift test` (all 49 suites incl. discipline scans and concurrency suites), twice.

#### Test Results
451 tests / 49 suites passed in BOTH runs; 0 failures; baseline 417/46 reconciled exactly.

#### Known Issues
- Golden-bytes pin carries a maintenance obligation (documented in its header): a deliberate §5.5 additive payload change or a toolchain canonical-bytes change breaks it BY DESIGN — re-record out-of-process, do not loosen.
- Store-level multi-hop walk is untestable while `currentSchemaVersion == 1` is pinned; multi-hop is pinned at the MigrationChain unit level instead (documented in suite header). Not a gap in the mechanism.
- OBS-3's documented limit stands: a future toolchain changing canonical Codable byte shape fails every generation's checksum at once → fresh default; self-consistent and contract-compliant; note lives in the SnapshotStore header.

#### Decisions Made
See "Design decisions + justifications" above (from-only step shape; prune-on-save superset equivalence; first-declaration-wins duplicate steps; multi-hop pinned at unit level; full-envelope golden literal with separately pinned hex; OBS-5 versions expressed as current+delta).

#### Reviewer Status
PENDING — independent adversarial review required (Review Requirements above, incl. sanctioned mutations: retainedDayCount 7→6, gate-order swap, both with byte-identical restore proof). Verdict to `.claude/tasks/reviews/REVIEW-TASK-022.md`.

#### Commit
None — implementation agent does not commit (CLAUDE.md §9). Working tree intentionally dirty for the orchestrator.

#### Push
None — nothing committed to push.

#### Recommended Next Step
Orchestrator: verify `git status` shows exactly the 10 files above (5 modified + 5 new, nothing under Sources/MomoCore), spawn the fresh Jupiter review agent per Review Requirements, record verdict in `.claude/tasks/reviews/REVIEW-TASK-022.md`; on APPROVED, commit atomically as `feat(persistence): TASK-022 migration chain + retention/pruning` and push.

## Reviewer Findings
**VERDICT: APPROVED_WITH_MINOR_NOTES** (0 MAJOR, 1 MINOR, 2 NITPICK, 4 OBSERVATION) — full record at `.claude/tasks/reviews/REVIEW-TASK-022.md` (2026-09-09, independent adversarial reviewer, branch @ `241f9cf`).

- Retention arithmetic re-derived from 05 §5.4 + §4.1 BEFORE reading the implementation; implementation matches on every point (Set-first distinct-key selection, first-occurrence dedup, order preservation, suffix-64 belt, full-value rebuild).
- Affirmative evidence for all Requirements 1–7 / AC 1–6: `git diff Sources/MomoCore/` = 0 bytes; zero literal `64` in Sources/MomoKit (capacity reused from MomoCore); literal `7` only in the authority-labeled StoreRules declaration + prose; exactly one `clock.now()` (SnapshotStore.swift:211); loads never write (byte-identical-directory pin + read-does-not-prune pin); concurrency suites and discipline scans 0-byte diff, scans live-enumerate Sources/MomoKit so the new files ARE covered; OBS-3 limit documented in the SnapshotStore header; OBS-5 rewritten against the chain.
- Golden-bytes pin independently verified: literal extracted = 1827 bytes, valid envelope, schemaVersion 1, checksum equals the separately pinned hex, tamper target `"bond":456` unique and length-preserving; byte AND recipe drift both bite (2/3 golden tests failed under Mutation A).
- Sanctioned mutations (all restored byte-identically, sha256-proven; full 10-file hash record diffed EMPTY): **A** `currentSchemaVersion` 1→2 → exactly the designed 10 bites (both raw pins, 2/3 golden tests, walk/parity/re-persistence/chain-value tests, above-head-with-steps). **B** gate-order swap (walk before checksum) → exactly 1 bite: `corruptChecksumBelowCurrentNeverMigrates`. **C** `retainedDayCount` 7→6 → exactly 2 bites: the raw pin + the discriminating mis-ordered-fixture format pin; all constant-fed tests stayed green (designed anti-echo division of labor confirmed).
- Reviewer's own intermediates: exact cap+1 boundary probe (8 days / 65 intents → 7 / 64, order preserved — 14/14 green); chain-gap and mid-walk-gap shapes already pinned; above-head-with-steps pinned; duplicate-dayKey pin content-discriminated; migration re-persistence chain-independent; negative-version generations conformant (OBS-D in the review record).
- Suite: `swift test` **451/49 green ×3** (implementer's two runs reproduced: 0.734 s / 0.694 s; reviewer's post-restore confirming run 0.492 s); reconciliation 417 + 14 + 16 + 3 + 1 = 451, 46 + 3 = 49 — exact.
- **MINOR-1:** `StoreFixture.ascendingLedger(startingISO:count:)` is dead fixture code — declared, doc-commented, claimed in Implementation Notes, called by no test. *Disposition: delete (or wire into one retention test) before commit — mechanical, test-file-only.*
- **NITPICK-1:** LedgerRetention.swift's selection comment inverts the pipeline order ("sorted/suffix over the multiset, then Set") — the CODE is Set-first, which is the correct no-crowding semantics; prose-only. **NITPICK-2:** unused `import Foundation` in LedgerRetention.swift / MigrationChain.swift (cosmetic). Both may ride MINOR-1's touch.
- OBSERVATIONS (no action): store-level multi-hop untestable at pinned v1 (disclosed, wiring verified); prune-on-save superset note sound; golden literal's out-of-process provenance not post-hoc verifiable but every property the pin needs is machine-verified; negative-version walkability noted for the next bump's author.
- Reviewer left the tree byte-identical to the as-found state (no stage, no commit) — commit-ready after the MINOR-1 disposition call by the orchestrator.

## Completion Evidence
(orchestrator fills at housekeeping.)
