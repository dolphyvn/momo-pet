# TASK-021 — Implement SnapshotStore: envelope, atomic writes, generational recovery (05 §5.1–5.3, ADR-002)

## Parent Epic
EPIC-005 — Persistence & Sync Logic (MomoKit). Epic acceptance criteria served: AC-1 (force-quit ≤ 1 in-flight event — structural here, cadence wiring is EPIC-007's), AC-2 (corruption recovers via generations; total destruction yields fresh default, silently).

## Objective
The `MomoKit` `SnapshotStore` per 05 §5.1–§5.3 and ADR-002: the Codable envelope `{schemaVersion, savedAt (UTC), checksum (SHA-256 of payload JSON), payload}`; the write path encode → temp file → atomic rename with generational demotion across EXACTLY `state.json` / `state.prev.json` / `state.prev2.json`; serialized (total-ordered) write-through saves; and the read path current → `.prev` → `.prev2` → injected fresh default that NEVER surfaces an error to the caller (UX §9: indistinguishable from a normal open). Everything headlessly testable on macOS: injected directory, injected clock.

## Context
- Module: `Sources/MomoKit/` — currently only `MomoKitPlaceholder.swift` (remove it when real files land; TASK-012 precedent). Package graph is wired: `MomoKit` target depends on `MomoCore` only (D-R2), `MomoKitTests` test target exists (`Package.swift:37,41`).
- MomoCore provides the load-bearing pieces — REUSE, never re-implement: repo-owned FIPS 180-4 `SHA256` (TASK-014; D-R4 bans CryptoKit — **the envelope checksum MUST use `MomoCore.SHA256`**), `EngineClock` protocol + `ManualEngineClock` (TASK-014) for `savedAt`, and the `EngineState` value type (TASK-014) as the payload.
- **The payload type graph is NOT yet Codable (verified 2026-09-09: zero `Codable` conformances in MomoCore).** Adding additive `Codable` conformances across the persisted graph is IN SCOPE as a disclosed, sanctioned enabler (§22 directly-necessary change): `EngineState` and everything it transitively contains — `Pet`, `PetState` (+ its enums), `DayRecord`, `QuestSet`/`QuestProgress`, `SettingsState`, `Handshake` (+ `HandshakeKind`), `BondStage`, `GreetingStamp` (+ `GreetingKind`), etc. (enumerate exhaustively in Implementation Notes). **Conformance-only discipline:** no stored field renamed/removed/re-tped, no semantics change, no behavior change in any existing test. Enums with associated values: prefer compiler-synthesized Codable (Swift synthesizes for enums when all payloads are Codable); if a type cannot synthesize, a hand-written conformance is a DISCLOSURE with justification, and any change beyond conformance (init tweaks, new stored fields) triggers the defect protocol — record it, do not silently expand.
- The intent ledger (`EngineState.processedIntents`) travels INSIDE the payload automatically (05 §5.3) — no separate ledger file exists in Phase 1's iPhone store.
- 05 §5.2 fixes the directory layout and file names EXACTLY: store directory contains `state.json`, `state.prev.json`, `state.prev2.json`. The store's directory is INJECTED (`URL`); a small default-directory factory computing `Application Support/Momo/` (creating it if missing) is allowed Foundation code so EPIC-007 wiring is one call — the default path must not be hardcoded anywhere else.
- Fresh default: MomoCore has NO `EngineState.initial` factory (verified) — do not invent onboarding state in MomoKit. The read path's final fallback returns an INJECTED fresh-default (`load(fallback:)` parameter or an init-injected factory — implementer's choice); total-destruction tests prove the injected value is returned.
- TASK-015's Known-Issue note: ledger pruning (7-day `DayRecord` retention, `processedIntents` ≤ 64) belongs to EPIC-005 — but to TASK-022, NOT this task. The engine stays append-only; TASK-021 saves what it is given.
- NSFileProtectionComplete (05 §5.2) is an iOS-app-layer concern — Phase 1 headless macOS tests have no file protection. Do NOT add platform-conditional code; the VERIFY-AT-BUILD register already owns the note.

## Requirements
1. **Envelope exactness.** `schemaVersion: Int`, `savedAt: Instant` (= `Date`, UTC, from the injected clock), `checksum: String` (lowercase hex of SHA-256), `payload: EngineState`. Pin the checksum recipe precisely: payload JSON bytes = `JSONEncoder` output for `EngineState` with **`.sortedKeys` output formatting REQUIRED** (JSONEncoder key order is otherwise unspecified — an unstable recipe would make checksums unverifiable run-to-run); checksum = `MomoCore.SHA256` over exactly those bytes; envelope encoding also uses `.sortedKeys`. Date encoding strategy: default (document it in a header comment). Verification recomputes EXACTLY this recipe — independent of how the payload is embedded in the envelope file.
2. **Write path.** Per save: encode payload → compute checksum → write temp file → atomic rename onto `state.json`, demoting previous generations down the chain (`state.prev.json` → `state.prev2.json`). Document the demotion ORDER in a header comment WITH a crash-window analysis (which generation can be lost/stale at each interruption point); the guarantee to hold: after an interruption at ANY point of the sequence, a subsequent load succeeds with the new state, the previous state, or an older-but-valid state — never an error, never a mix. Tests construct each intermediate filesystem state directly and assert a valid load (Requirement 8's test list).
3. **Read path, no error surface.** Try `state.json` → verify checksum against the recipe → decode payload → on ANY failure (missing file, garbage bytes, truncated/torn file, checksum mismatch, decode failure, unsupported schemaVersion) fall to `.prev`, then `.prev2`, then return the injected fresh default. The public load API does not throw (Swift `throws`-free or internally total — implementer's shape; the caller-visible contract is "always returns a state"). Corrupting a generation must never corrupt the survivors.
4. **Serialized writes.** Saves are total-ordered (actor or serial queue — implementer's choice, justify in one comment); concurrent saves converge to a consistent chain where the newest completed save is current. Loads concurrent with a save observe either the old or the new state, never a torn file (atomic rename guarantees this — pin it with a bounded stress test).
5. **Versioning hook.** A constants home (house pattern — e.g. `StoreRules` enum namespace with authority labels, mirroring `CopyRules`/`FoldRules`): `currentSchemaVersion = 1`, the three file names, generation count = 3 — each single-sourced with raw-literal pins in tests. Read-path behavior for an UNKNOWN (higher) schemaVersion: treat that generation as unreadable → fall through the chain (safe total behavior; the migrate chain itself is TASK-022 — do not implement it).
6. **Clock + import discipline.** `savedAt` comes ONLY from the injected `EngineClock`; no ambient `Date()`/`Date.now` anywhere in `Sources/MomoKit` (the one sanctioned ambient read lives in MomoCore's `SystemEngineClock`, scanner-exempted there — MomoKit gets none). MomoKit sources import Foundation only (D-R2 + macOS headless). Pin both with a small standing scan test in `MomoKitTests` mirroring the MomoCore scanner mechanism (non-vacuous both directions, seeded-violation proof like `EnginePurityScanTests`).
7. **Payload graph completeness.** The Codable additions must cover the WHOLE transitive closure of `EngineState` (enumerate it in Implementation Notes with the file each type lives in); a type omitted from the closure = compile error at `: Codable` on `EngineState` anyway — the real completeness requirement is the roundtrip matrix of Requirement 8 exercising EVERY persisted enum case.
8. **Focused test suite** (TASK-024 owns the full §32 matrix + floors; this task's suite is the store's own):
   - Roundtrip: a fully-populated `EngineState` fixture (every field non-default: populated day ledger, pending handshake, greeting stamp, processed intents, both handshake kinds' worth of state) encodes → decodes → `==` holds; plus EVERY case of EVERY persisted enum roundtrips (case-exhaustive — reuse the compile-pinned case-set discipline where one exists).
   - Envelope pins: on-disk envelope has `schemaVersion == 1`, `checksum` equals the recomputed recipe, `savedAt` equals the injected clock's value.
   - Generational chain: after three saves the three files carry N, N−1, N−2 (content-identifiable states); the documented demotion order holds.
   - Crash-window matrix: for each intermediate state of the write sequence (e.g. current present + prev missing + prev2 stale; current missing + prev present; prev2 absent entirely), a load succeeds with a valid state and no error.
   - Corruption recovery: truncated current → loads `.prev`'s state; payload byte flipped (checksum mismatch) → `.prev`; garbage-bytes file → `.prev`; empty file → `.prev`; ALL THREE corrupted → injected fresh default; missing directory entirely → fresh default. Zero throws to the caller in every case.
   - Unknown schemaVersion (e.g. 2) written by hand → that generation skipped → `.prev` served.
   - Concurrency: a bounded stress property (e.g. concurrent saves from multiple tasks over one store) leaves a consistent chain with a total order; a load concurrent with saves never fails.
   - Determinism: two saves of the same state produce byte-identical `state.json` except where `savedAt` legitimately differs (pin that the payload/checksum portion is stable — the `.sortedKeys` discipline made-to-pay).
   - Standing scans (Requirement 6) green + proven non-vacuous.

## Files / Areas Likely Affected
- NEW `Sources/MomoKit/SnapshotStore.swift` (store, envelope, read/write paths, serialization)
- NEW `Sources/MomoKit/StoreRules.swift` (constants home) — or folded into SnapshotStore.swift if small (implementer's call; house favors small files)
- MODIFIED `Sources/MomoCore/*.swift` — additive `Codable` conformances across the persisted graph ONLY (disclosed list required)
- REMOVE `Sources/MomoKit/MomoKitPlaceholder.swift`
- NEW `Tests/MomoKitTests/SnapshotStoreTests.swift` (+ a minimal local fixture — MomoKitTests may need `"MomoCore"` added to its target dependencies in `Package.swift` to `@testable import MomoCore` for building populated states; a one-line disclosed build-config change)
- NOT touched: engine semantics (`Reduce`, `TimeFold`, …), `Thresholds`, docs, `MomoCopy.xcstrings`, app targets, `Package.swift` dependencies graph beyond the disclosed test-target line.

## Dependencies
- TASK-012 (domain types), TASK-014 (`EngineState`, `EngineClock`, `SHA256`) — merged to `main`.
- Branch: `feature/EPIC-005-persistence` (cut from `main` @ `04d07d6`, the EPIC-004 merge).

## Constraints
- D-R2 (MomoKit → MomoCore only), D-R4 (zero external deps), D-R6 (engine never imports persistence; no engine changes beyond additive conformances), D-R1 spirit (Foundation-only MomoKit).
- No `CryptoKit` — checksum via `MomoCore.SHA256`.
- No ambient time or paths in MomoKit (Requirement 6).
- Swift 6 strict concurrency clean (module convention); `SnapshotStore` `Sendable` as a boundary type.
- Anti-echo: every constant (file names, version 1, generation count 3) single-sourced + raw-pinned; no duplicated literals in tests.
- No doc/xcstrings/ADR changes (ADR-002 already records the decision); discoveries that would change the RECORD (not the code) go in Implementation Notes for the orchestrator to route.

## Acceptance Criteria
1. `swift test` green — including all existing suites (369/43 baseline; no regression from the Codable additions).
2. Save → load roundtrips a fully-populated state exactly; the envelope carries schemaVersion 1 + a verifiable checksum + the injected clock's `savedAt`.
3. Three-generation demotion works per the documented order; every crash-window intermediate state loads valid.
4. Each corruption mode (truncated, garbage, empty, checksum mismatch, all-generations-lost, missing directory, unknown schemaVersion) recovers to the right generation or the injected default — caller-visible behavior always "a state", never an error.
5. No ambient `Date`/path access in `Sources/MomoKit`; imports Foundation-only — both scan-pinned and proven non-vacuous.
6. The Codable closure over `EngineState` is complete and enumerated; every persisted enum case roundtrips.

## Required Tests
As Requirement 8 (roundtrip matrix, envelope pins, generational chain, crash-window matrix, corruption modes, unknown-version, concurrency stress, byte-stability, scans). Naming should make each pin's clause findable (house style). Mutational teeth: at minimum, the reviewer will expect that flipping `.sortedKeys` off, or swapping the checksum recipe, visibly breaks the envelope pins — write the pins so they would.

## Review Requirements
Standard independent adversarial review (CLAUDE.md §10/§33). Reviewer MUST:
- Re-derive the checksum recipe from 05 §5.2 + this contract BEFORE reading Implementation Notes; verify the on-disk envelope against an independently recomputed SHA-256.
- Verify the Codable closure is genuinely additive: `git diff Sources/MomoCore/` shows conformances (+ at most disclosed mechanical necessities), zero semantic drift, and the existing 369-test suite stays green unchanged.
- Attempt the crash-window matrix independently (construct at least one intermediate state this contract did not name) and try to make the store return an error or a mixed state.
- Probe the serialization claim (concurrent saves) and the no-error claim (every corruption mode through the PUBLIC API).
- Perform at least two sanctioned mutations with exact attribution + byte-identical restore (candidates: `currentSchemaVersion` 1→2 — unknown-version path must serve `.prev`; demotion order swap; `.sortedKeys` removal).
- Confirm the standing scans are non-vacuous (seeded violation → red).

## Git Requirements
- Branch `feature/EPIC-005-persistence`; implementation agent does NOT commit.
- Orchestrator commits atomically: `feat(persistence): TASK-021 SnapshotStore — envelope, atomic writes, generational recovery`.
- "(this commit)" convention for the task file's Completion Evidence.

## Status
IN_PROGRESS — dispatched 2026-09-09.

## Implementation Notes
(impl agent fills: decisions, the Codable closure enumeration, demotion order + crash-window analysis, API shape + serialization mechanism, test inventory, suite results.)

## Reviewer Findings
(reviewer fills; verdict + findings recorded in `.claude/tasks/reviews/REVIEW-TASK-021.md`.)

## Completion Evidence
(orchestrator fills at housekeeping.)

## Handoff
### Completed
### Files Changed
### Tests Run
### Test Results
### Known Issues
### Decisions Made
### Reviewer Status
### Commit
### Push
### Recommended Next Step
