# REVIEW-TASK-022 — Migration chain + retention/pruning (05 §5.4, §5.5; NFR-7)

Reviewer: fresh independent adversarial review agent (CLAUDE.md §10/§33)
Date: 2026-09-09
Branch: `feature/EPIC-005-persistence` @ `241f9cf` (working tree DIRTY with the TASK-022 implementation — reviewed as-found, uncommitted)
Scope reviewed: 5 modified files + 5 new files (exactly the contract's set); `git diff Sources/MomoCore/` verified **0 bytes**.

**VERDICT: APPROVED_WITH_MINOR_NOTES** (0 MAJOR, 1 MINOR, 2 NITPICK, 4 OBSERVATION)

---

## 1. Method

Normative sources re-read FIRST, retention arithmetic re-derived BEFORE the implementation was read, then compared: 05 §5.4 (7-day window, ≤ 64 recent, deterministic, unit-tested), §5.5 (additive norm, `migrate(v→v+1)` chain, pure/total, fresh-install ≡ upgrade), §5.1–§5.3 (store/recovery stance), §4.1 (`days` newest-last, `processedIntents` ≤ 64 belt), PRD NFR-7, ADR-002. Every Implementation-Notes claim treated as an assertion and independently verified.

### Independent derivation (written before reading the code)

1. **Days**: keep the 7 lexicographically-GREATEST DISTINCT dayKeys (Set-of-keys → sort → suffix(7); a duplicate key must count ONCE toward the cap — Set-first, so multiplicity can never crowd a distinct key out of the window); survivors filtered through the input array preserving input relative order; duplicates of a survivor key keep their FIRST record (defect); total on empty/under/at/oversized; idempotent.
2. **Intents**: `suffix(64)` in array order (last 64, order preserved); cap REUSED from `MomoCore` `EngineState.processedIntentsCapacity` (EngineState.swift:74).
3. **Current day never dropped**: subsumed by keep-newest-7 (current = newest key under normal engine operation), pinned anyway.
4. **Write path**: prune BEFORE encode; read path never prunes (loads never write/mutate).
5. **Gate order**: bytes → envelope decode (payload rides inside the envelope) → version RANGE check (above head unreadable before any integrity work) → checksum re-derived (TASK-021 recipe: `.sortedKeys` re-encode of the decoded payload, lowercase-hex SHA-256) → migration walk (below-current only; missing hop ⇒ unreadable) → serve; v == current never consults the chain.
6. **Migration**: pure, total, value-data chain (no global registry); steps `{from → from+1}` applied in ascending version order; first-declared-wins on duplicate `from`.

**Result: the implementation matches the derivation on every point.** No divergence found in arithmetic, ordering, dedup, gate order, or walk semantics.

## 2. Claim-by-claim verification (affirmative evidence)

| # | Claim | Evidence | Result |
|---|---|---|---|
| 1 | MomoCore diff EMPTY | `git diff Sources/MomoCore/` = 0 bytes | VERIFIED |
| 2 | No schemaVersion bump | `StoreRules.swift:35` still `= 1`; raw pins at `StoreRulesPinnedTests` ("the current schema version is 1") and `SnapshotStoreTests:191` ("the on-disk envelope carries schemaVersion == 1") — BOTH proven to bite (Mutation A, §3) | VERIFIED |
| 3 | 64-cap REUSED, not redeclared | `grep -rn '\b64\b' Sources/MomoKit/` → **zero hits**; `LedgerRetention.swift:77` uses `EngineState.processedIntentsCapacity` | VERIFIED |
| 4 | `retainedDayCount` new normative surface in StoreRules, authority-labeled | `StoreRules.swift:37–46`, authority "05 §5.4" + three-consumer note + MomoCore-owns-the-belt note; raw-literal pin `StoreRulesPinnedTests` `retainedDayCount == 7` present and biting (Mutation C) | VERIFIED |
| 5 | Literal 7 appears only in StoreRules + pins | `grep -rn '\b7\b' Sources/MomoKit/` → only doc prose and the authority-labeled declaration | VERIFIED |
| 6 | Gate order decode → range → checksum → walk → serve | Read at `SnapshotStore.swift:285–313`; header documents the numbered order (lines 117–132) with "checksum gate precedes the walk BY DESIGN" | VERIFIED |
| 7 | Single `clock.now()` in Sources/MomoKit | grep → exactly one hit, `SnapshotStore.swift:211` (in `save`, as before); no `Date()`/`Date.now` anywhere in MomoKit | VERIFIED |
| 8 | Loads never write | `theChainIsValueDataStoresAreIndependent` asserts byte-identical directory across loads by two differently-chained stores; `loadDoesNotPrune` serves an oversized valid generation un-pruned | VERIFIED |
| 9 | Concurrency suites untouched | `git diff Tests/MomoKitTests/SnapshotStoreConcurrencyTests.swift` = 0 bytes; suite green in all three full runs | VERIFIED |
| 10 | Discipline scans untouched, green, non-vacuous | `git diff` on `MomoKitDisciplineScanTests.swift` + `Support/MomoKitDisciplineScan.swift` = 0 bytes; live scans enumerate the REAL `Sources/MomoKit` directory via `KitRepo.momoKitSources()` (filesystem, not git), so the new untracked files ARE scanned; `pathExemptionIsLive` occurrence-pins StoreRules's one sanctioned read | VERIFIED |
| 11 | OBS-3 documented limit | `SnapshotStore.swift:30–43` header section: toolchain-coupled canonical Codable bytes, fails EVERY generation's checksum at once → fresh default; stated as self-consistent, contract-compliant, and a REAL limit | VERIFIED |
| 12 | OBS-5 rewrite against the chain | Both unknown-version tests renamed to above-chain-head semantics, versions expressed as `currentSchemaVersion + 1` / `+ 8` (no raw 2/9); behavior pins unchanged; the empty-chain case makes TASK-021's rule a consequence of the walk (also unit-pinned via `MigrationChain.empty.isEmpty`) | VERIFIED |
| 13 | Prune-on-save superset note | Present in `SnapshotStore` header (lines 100–112) and `LedgerRetention` header; the write-through argument is sound (a state-changing rollover is immediately followed by a save; identical payloads wherever the caps can bind) | VERIFIED |
| 14 | Golden literal is genuinely literal | Independently extracted from the source line: **1827 bytes** (matches claim), valid JSON envelope `{checksum, payload, savedAt, schemaVersion}`, `schemaVersion: 1`, checksum equals the separately-pinned hex `6025fd1e…ea2`, 3 days / 2 intents (under caps); tamper target `"bond":456` occurs EXACTLY ONCE in the literal (byte-count verified) | VERIFIED |
| 15 | Golden pin has teeth (byte AND recipe drift) | Test 1: byte drift → checksum refusal → fallback ≠ fixture. Test 2: recipe drift → re-derived digest ≠ recorded hex; also asserts envelope.schemaVersion == current (bit in Mutation A). Test 3: length-preserving tamper (`456→457`) falls through — the CHECKSUM gate refuses it, not the decoder (length equality asserted). Mutation A failed 2 of the 3 golden tests — the suite demonstrably bites | VERIFIED |
| 16 | 451/49 both runs | Run 1: `Test run with 451 tests in 49 suites passed after 0.734 seconds.` Run 2: `…passed after 0.694 seconds.` Reviewer's post-restore confirming run: `…passed after 0.492 seconds.` Reconciliation: 417 + 14 retention + 16 migration + 3 golden + 1 pin = 451; 46 + 3 suites = 49 — exact | VERIFIED ×3 |
| 17 | No TODO/FIXME/HACK/TEMP, no prints | grep over all 10 files → none | VERIFIED |
| 18 | Scope confinement | `git status --short` shows exactly the contracted 5 modified + 5 new files (+ the task file's own Implementation Notes); no Package.swift, app-target, or MomoCore touches | VERIFIED |

## 3. Sanctioned mutations (hash discipline: sha256 before each mutation; restore proven by matching sha256 against the pre-mutation record; post-run `diff` of full 10-file hash record: ALL BYTE-IDENTICAL)

**Pre-mutation hash record** (all 10 touched files) kept at `/tmp/task022-review-hashes-before.txt`; post-restore record diffed EMPTY.

### Mutation A — `currentSchemaVersion` 1→2 (`StoreRules.swift`)
Designed outcome: at v=2 every generation is below-current with a missing hop (production ships an EMPTY chain), and the raw pins fire.
**Result: exactly the designed bites — 10 failures / 4 suites, nothing else:**
- `the current schema version is 1 (initial schema)` — raw pin
- `the on-disk envelope carries schemaVersion == 1 (raw pin with mutation teeth)` — second raw pin
- `the recorded out-of-process generation loads through the public API…` — v1 < 2, empty chain → fallback (golden pin bites)
- `the recorded checksum is the recipe over the recorded payload…` — schemaVersion pin inside the golden suite
- `a below-current generation walks the injected step (v0 → current)` — missing 0→1… wait, v0→2 needs hops at 0 AND 1; hop at 1 missing → unreadable
- `negative control: the same generation with a valid checksum DOES migrate` — same missing hop
- `NFR-7 parity` — walk 0→2 → nil → `#require` throws
- `a state loaded through migration re-persists…` — migrated = fallback ≠ expected
- `a version above the chain head is unreadable even when steps are registered at it` — v2 now AT head → served → ≠ fallback (range check moves with the constant, as designed)
- `the chain is per-store value data…` — store A's walk now incomplete → fallback

Tests that must survive a bump survived (corruption recovery, crash windows, OBS-5 above-head tests at current+1, retention tests). Restore: sha256 `3184f808…` == pre-mutation hash. **Bites confirmed.**

### Mutation B — gate-order swap in `loadGeneration` (walk before checksum) (`SnapshotStore.swift`)
**Result: exactly ONE failure** — `a below-current generation that FAILS its checksum falls through — it never migrates` (the gate-order pin). Surgical attribution: the pin guards precisely this ordering; every corruption/golden/current-version test stayed green. Restore: sha256 `46d484a3…` == pre-mutation hash. **Bite confirmed.**

### Mutation C — `retainedDayCount` 7→6 (`StoreRules.swift`)
**Result: exactly 2 failures (3 issues)** — the raw-literal pin (`retainedDayCount == 7`) and the discriminating format pin (`dayKeysOrderLexicographicallyBecauseTheyAreZeroPadded`: its 8-key mis-ordered fixture under a 6-cap drops TWO keys, failing both the survivor-set and survivor-order assertions). All constant-fed behavior tests stayed green — the designed anti-echo division of labor (formula-shape pins follow the constant; raw pins carry the value teeth). Restore: sha256 `3184f808…` == pre-mutation hash. **Bites confirmed.**

## 4. Reviewer's own unnamed intermediates

1. **Exact cap+1 boundary** (not covered as-is by the shipped fixtures): temporarily re-pointed the oversized fixtures at `retainedDayCount + 1` = 8 days and `processedIntentsCapacity + 1` = 65 intents (review probe, restore-proven byte-identical) → `LedgerRetentionTests` **14/14 green**: 8 days → exactly the 7 greatest keys; 65 intents → exactly the last 64; order preserved. Boundary correct.
2. **Chain with a gap**: store-level `missingStepMakesBelowCurrentGenerationUnreadable` (step registered at 1 only, v0 generation → unreadable → prev serves) and unit-level `missingStepHalfwayThroughMultiHopWalkIsUnreadable` (0→3 walk with hop 1 missing → nil, never half-migrated). Both pinned; no defect found.
3. **Above-head WITH steps registered**: `aboveHeadVersionIsUnreadableEvenWithStepsRegistered` — range check precedes everything; registered future steps are inert. (Mutation A additionally proved the range check tracks the constant.)
4. **Duplicate dayKey**: `duplicateDayKeysKeepTheFirstOccurrence` — content-discriminated (first record carries `feed: 1`, duplicate is minimal); survivor content asserted, not just the key set. Set-first selection means duplicates can never crowd a distinct key out of the window (verified by code reading; the shipped `sorted().suffix` operates on the deduplicated key set).
5. **Migration idempotence through save**: `migratedStateRepersistsAtCurrentVersion` — load-migrated → save → envelope at current version with fresh checksum → a plain (chain-free) store reads the same state. Chain-independence of re-persisted state pinned.
6. **Negative schemaVersion generation** (v ≤ 0): passes the range check (≤ current), and is walkable IF a step is registered at that `from` — contract-conformant (below-current + complete chain = readable); with the production empty chain it is unreadable. No defect; recorded for the archive.
7. **Multi-hop at store level**: impossible while `currentSchemaVersion == 1` is pinned — implementer's disclosure accepted; the walk wiring (`from: envelope.schemaVersion, to: currentSchemaVersion`) verified by reading, single-hop integration pinned through the public API, multi-hop order-sensitivity pinned at the unit level with a non-commutative transform ("Momo123" under scrambled declaration order).

## 5. Findings

### MAJOR — none.

### MINOR
- **MINOR-1 (dead fixture code, claims-accuracy):** `StoreFixture.ascendingLedger(startingISO:count:)` (StoreFixture.swift:273) is declared, doc-commented, and listed in the Implementation Notes inventory — but **no test calls it** (grep: declaration only). Retention tests build ledgers via `consecutiveDayKeys(...).map { fixture.minimalDay($0) }` directly. Dead test-support code; also a small inaccuracy in the handoff inventory. *Disposition: delete the builder (or wire it into one retention test) before commit — a mechanical, test-only touch.*

### NITPICK
- **NITPICK-1 (comment/code inversion):** `LedgerRetention.swift:56–59` describes the selection as "`.sorted().suffix(n)` over the multiset of keys, then Set" — the CODE is Set-first (`Set(...).sorted().suffix(...)`). The code is the CORRECT order (Set-first is exactly what prevents duplicate crowding; the comment's literal pipeline would NOT guarantee that, e.g. one distinct low key among many duplicates of a high key). Prose-only; the stated intent ("a duplicated key cannot crowd out a distinct one") matches the code. *Disposition: one-line comment fix, may ride MINOR-1's touch.*
- **NITPICK-2 (unused imports):** `LedgerRetention.swift` and `MigrationChain.swift` import Foundation without using any Foundation symbol (stdlib only). Whitelist-compliant and consistent with neighbors; cosmetic. *Disposition: optional; may ride the same touch or be left.*

### OBSERVATION (no action required)
- **OBS-A:** Store-level multi-hop walk untestable at the pinned `currentSchemaVersion == 1` — honestly disclosed; wiring verified + unit-level multi-hop pins adequate (see §4.7).
- **OBS-B:** "Prune on EVERY save" vs §5.4's "at each rollover" is a documented superset equivalence; the write-through argument is sound and the note lives in both headers (Requirement-1 placement verified on the write path only; read path pinned un-pruned).
- **OBS-C:** The golden literal's out-of-process capture cannot be re-verified post hoc by a reviewer; what IS machine-verified is everything the pin needs — the bytes are literal, self-consistent with the in-process recipe, equal to the in-process fixture, tamper-refusing, and mutation-proven to bite (2/3 golden tests failed under Mutation A). The re-record maintenance obligation is documented in the suite header.
- **OBS-D:** Negative `schemaVersion` generations are walkable when a step is registered at that `from` — conformant (§5.5 has no below-floor rule); noted so a future bump's author registers steps from ≥ 0 or accepts the semantics deliberately.

## 6. Test evidence

- Full `swift test` on the as-found tree — Run 1: `✔ Test run with 451 tests in 49 suites passed after 0.734 seconds.`; Run 2: `✔ Test run with 451 tests in 49 suites passed after 0.694 seconds.` (both 0 failures, 0 skipped)
- Mutation runs: A → 10 failures/4 suites (all designed); B → 1 failure (the gate-order pin); C → 2 failures/3 issues (raw pin + format pin)
- Boundary probe (cap+1 fixtures): LedgerRetentionTests 14/14 green
- Post-restore confirming run: `✔ Test run with 451 tests in 49 suites passed after 0.492 seconds.` — restored tree green
- Reconciliation vs baseline 417/46: +34 tests (+3 suites) — exact

## 7. Verdict

**APPROVED_WITH_MINOR_NOTES** — every Requirement (1–7) and Acceptance Criterion (1–6) verified with concrete affirmative evidence; three sanctioned mutations bit with exact attribution; seven additional reviewer intermediates found no defect; all TASK-021 deliverables survive untouched. The one MINOR (dead fixture builder `ascendingLedger`) and two NITPICKs are mechanical disposition items that do not gate the commit; recommended disposition is the test-file-only touch-up described above, then commit as `feat(persistence): TASK-022 migration chain + retention/pruning` and push. All reviewer mutations restored byte-identically (10/10 sha256 matches; `git status` shows exactly the original TASK-022 file set).

## 8. Orchestrator Disposition (pre-commit, 2026-09-09)

Verdict basis: **APPROVED_WITH_MINOR_NOTES** — commit proceeds after this disposition.

- **MINOR-1 (dead fixture `ascendingLedger`): FIXED** — the never-called builder deleted from `StoreFixture.swift` (its Implementation-Notes claim corrected in the task file).
- **NITPICK-1 (comment/code disagreement): RESOLVED — with a correction to the reviewer's diagnosis.** The reviewer stated the code was Set-first and the comment the sole defect ("prose-only"). Orchestrator re-verification found the opposite: the shipped code was `Set(state.days.map(\.dayKey).sorted().suffix(n))` — Set applied LAST over the multiset — so the comment's no-crowding CLAIM was false and the code was the defective side (a duplicate at the window boundary wastes a slot: 8 distinct days + 1 duplicate retained only 6). Live bite-proof: with the shipped ordering restored, the strengthened pin `duplicateDayKeysKeepTheFirstOccurrence` FAILS (1 issue); with the fix it passes. Disposition applied: code reordered to Set-first (`Set(...).sorted().suffix(...)`) matching the header's documented semantics and the contract's "keep the 7 most-recent DayRecords"; inline comment corrected; the duplicate-dayKey defect pin strengthened with the boundary-discriminating case (8 distinct + dup of newest → exactly the 7 newest, in order). File hash-proven across the mutation (`554e342b…` before and after).
- **NITPICK-2 (unused `import Foundation`): FIXED** — removed from `LedgerRetention.swift` and `MigrationChain.swift`.
- **OBS-A–D:** no action (recorded; OBS-D noted for the future bump's author).
- Post-disposition suite: `swift test` **451 / 49 green ×2** (test count unchanged — the strengthened case extended the existing defect pin).

All disposition edits are inside the TASK-022 diff's sanctioned file set (2 MomoKit sources, 1 test suite, 1 fixture); no other file touched.
