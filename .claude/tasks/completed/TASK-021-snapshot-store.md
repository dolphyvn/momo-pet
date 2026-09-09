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
DONE — committed as (this commit). Implementation complete 2026-09-09 (no commit by the agent, per Git Requirements); REVIEW-TASK-021 **APPROVED_WITH_MINOR_NOTES** (0 MAJOR / 2 MINOR / 5 OBSERVATION / 2 NITPICK; full record at `.claude/tasks/reviews/REVIEW-TASK-021.md`). Orchestrator disposition applied pre-commit: MINOR-1 + MINOR-2 doc corrections in Implementation Notes (mechanical, no code change); default-clock param adjudicated ACCEPTABLE; OBS-1 routed to the TASK-022 contract (cross-process/golden-bytes load pin); OBS-2/3/4 recorded in the review + status.md; OBS-5 rides TASK-022's version-bump rewrite; NITPICKs noted, no change.
Post-review suite flake (~14 %) root-caused to unsound order-pins in the concurrency suite (store correct; neither task-group child scheduling nor actor job execution is FIFO — only the total order is). Fix round 1 made the pins order-independent; delta verification (REVIEW-TASK-021-FLAKEFIX-VERIFICATION) round 1 returned CHANGES_REQUIRED (MAJOR: pins missed Requirement 4's convergence clause — a silently frozen store passes; the silent early-return shape at `SnapshotStore.swift:148-154` is real), round 2 **APPROVED** after the prescribed savedAt ADJACENCY repair (TickingClock 1 s/read, one read per save → 24 saves pin base+23/22/21, 128 saves pin base+127; adjacency subsumes descent and fails any frozen/dropping store — proven by the verifier's executable freeze mutation, which every round-1 pin survived and the adjacency pins bit). Stability at close: fixer 20/20 focused + 3/3 full, verifier 16/16 + 3/3, orchestrator 417/46 reproduced twice. MINOR-1 of the verification (comment rationale) closed. Production code byte-identical to the original review's pristine hashes throughout both fix rounds.

## Implementation Notes

### API shape (Sources/MomoKit/SnapshotStore.swift)
- `struct SnapshotEnvelope: Codable` — `{schemaVersion: Int, savedAt: Instant (Date), checksum: String, payload: EngineState}`. Both payload and envelope encode with `.sortedKeys` (Requirement 1). Date strategy: **Foundation default** (`.deferredToDate` — a JSON NUMBER of seconds since the reference date; reviewer probe C's raw token `810641472` at the pinned clock; CORRECTED per REVIEW-TASK-021 MINOR-1 — the Notes originally mis-stated ISO-8601) — documented in the header; the exact spelling is irrelevant to correctness because checksums are computed over the payload JSON the store itself produces and re-verified against the same recipe on read, and `savedAt` roundtrips through the same encoder/decoder pair.
- `public actor SnapshotStore` — `init(directory: URL, clock: any EngineClock = SystemEngineClock())`; `save(_ state: EngineState)` is actor-isolated (the serialization mechanism — Requirement 4's total order falls out of the actor mailbox; non-throwing by signature, internally total: an I/O failure removes the temp file, leaves the demoted chain untouched, and raises a DEBUG-only `assertionFailure` — release behavior is "keep last-known-good chain", never an error surface). `load(fallback: EngineState) -> EngineState` is deliberately **`nonisolated`**: reads do NOT queue behind the save actor, so the concurrency stress tests exercise the atomic-rename guarantee for real instead of being masked by the actor queue. Checksum = lowercase-hex `MomoCore.SHA256` over the `.sortedKeys` payload JSON bytes (D-R4 honored — no CryptoKit).
- Read-path gate order per generation (`loadGeneration`): bytes readable → envelope decodes → `schemaVersion == StoreRules.currentSchemaVersion` (checked BEFORE the checksum — an unknown version is skipped without decoding semantics) → recomputed recipe `==` envelope.checksum → payload decodes. Any failure falls through `.prev` → `.prev2` → the injected `fallback` (Requirement 3: no `throws` on the public API; fresh default is the injected `fallback` parameter — no `EngineState.initial` invented, per Context).
- `Sources/MomoKit/StoreRules.swift` — constants home (`currentSchemaVersion = 1`, `generationCount = 3`, the three generation file names + temp name, `generationFileNamesInReadOrder`) plus `defaultDirectory()` — the ONE sanctioned ambient-path site (Application Support/Momo, created if missing; scanner-exempted per-file, occurrence-pinned to exactly one `applicationSupportDirectory` read).

### Demotion order + crash-window analysis (SnapshotStore header, reproduced)
Save sequence, in this exact order:
1. `state.prev2.json` removed (if present)
2. `state.prev.json` → `state.prev2.json` (rename)
3. `state.json` → `state.prev.json` (rename)
4. envelope bytes → `state.json.tmp` (write)
5. `state.json.tmp` → `state.json` (rename — the atomic commit point)

Crash windows (N = the state being saved, N−1/N−2 its predecessors):

| Crash between | state.json | state.prev.json | state.prev2.json | load serves |
|---|---|---|---|---|
| before any step | N−1 | N−2 | N−3 | N−1 |
| 1–2 (oldest removed) | N−1 | N−2 | — | N−1 |
| 2–3 | N−1 | N−2 | N−2 (copy-in-flight impossible: rename is atomic) | N−1 |
| 3–4 (current demoted) | — | N−1 | N−2 | N−1 |
| 4–5 (temp written) | — (temp ignored) | N−1 | N−2 | N−1 |
| 5 (torn temp) | — | N−1 | N−2 | N−1 |

Guarantee holds structurally: every window leaves at least one complete older generation, the only removal target is the outgoing N−3, and `state.json.tmp` is either absent (ignored by the read path) or removed by the save's catch block. All six windows are pinned by tests that construct the intermediate filesystem directly.

### Codable closure over `EngineState` — complete enumeration (16 types)
Synthesized (conformance-only, `, Codable` added to the existing conformance list — zero field/semantic change):
- `EngineState`, `Handshake`, `GreetingStamp` — `Sources/MomoCore/EngineState.swift`
- `Pet` — `Sources/MomoCore/Pet.swift`
- `PetState`, `Wakefulness`, `Activity`, `SatietyPhase` — `Sources/MomoCore/PetState.swift`
- `QuestID`, `QuestFamily`, `QuestProgress` — `Sources/MomoCore/Quest.swift`
- `SettingsState` — `Sources/MomoCore/SettingsState.swift`
- `BondStage` — `Sources/MomoCore/Bands.swift`
- `GreetingKind`, `HandshakeKind` — `Sources/MomoCore/CharacterInterface.swift`
(`processedIntents` is `[UUID]` — Foundation-Codable, no custom type; `Instant` = `Date`.)
Verified NOT in the closure, deliberately untouched: `MoodBand`, `EnergyBand`, `QuestWindow`, `QuestCatalogEntry`, `EngineEvent`, `EngineOutcome`, `CharacterMoment`, `ResponsePlan`, `DisplayState`, `CharacterDisplayState`, `InteractionIntent`, `ReactionID`, `HapticID`, `CharacterReport`.
The compiler enforces closure completeness (`EngineState: Codable` fails if anything transitive is missing); the roundtrip matrix additionally exercises EVERY case of every persisted enum via compile-pinned case-set fixtures.

### Disclosures
1. **`DayRecord` Codable is hand-written (both requirements)** — `Sources/MomoCore/DayRecord.swift`. Necessity: `familiesUsed: Set<QuestFamily>`; synthesized set-encoding emits elements in the runtime's per-process hash-seeded order — and unsorted JSONEncoder output is non-canonical even WITHIN one process (per-encode-call keyed-container ordering variance, reviewer-proven in REVIEW-TASK-021 §5/§7 mutation-2 investigation; mechanism broadened per MINOR-2) — so without canonical bytes the checksum input would differ across processes AND across encode calls, and a file could fail its OWN checksum, silently defeating the recovery chain. The conformance encodes the set as an array sorted by a private declaration-order `persistenceOrder` (exhaustive switch, no `default` — a new `QuestFamily` case fails the build) and decodes back into a `Set`. Field names/types/values untouched.
2. **Synthesized decode bypasses the failable initializers' INV checks** (INV-1/4/5/7 etc. are not re-run when decoding) — deliberate, shared by all 16 conformances: the envelope checksum gates the bytes before the payload is trusted (05 §5.2's integrity model). Recorded here for the reviewer; behavior documented in the DayRecord conformance comment.
3. **`init(clock: SystemEngineClock())` default parameter** — the one ambient-time reference in MomoKit's signature surface (production wiring convenience for EPIC-007's one-call store creation); no ambient read occurs inside MomoKit's code paths, and the scanner (which bans `Date(`/`Date.now` literals) stays green because `SystemEngineClock` is a MomoCore type name.
4. **`Package.swift` one-line change (pre-sanctioned)**: `MomoKitTests` test target dependencies gained `"MomoCore"` (`@testable import MomoCore` for building populated states).
5. **Date strategy = Foundation default** (see API shape) — documented in the SnapshotStore header.

### Test inventory (`Tests/MomoKitTests/`)
- `SnapshotStoreTests.swift` (29 tests): roundtrip matrix (fully-populated fixture + case-parameterized over every persisted enum: `Wakefulness`, `Activity`+`nil`, `SatietyPhase`, `HandshakeKind`, `GreetingKind`, `BondStage`), compile-pinned default-free case-set switches, fixture QuestID/Family coverage pins, envelope pins (schemaVersion `== 1` raw with mutation teeth; checksum = independent re-derivation of the recipe NOT calling store helpers; `savedAt` == injected clock; key set via JSONSerialization), generational chain (1/2/3 saves → N/N−1/N−2), crash-window intermediates (stale prev2; post-step-1 `{N−1, N−2, —}`; post-step-3 `{—, N−1, N−2}`; orphan temp ignored; lone prev2 survivor), corruption modes (truncated → prev, garbage → prev, empty → prev, checksum mismatch → prev, all three corrupted → fallback, missing directory → fallback; survivors never damaged; loads never write), unknown schemaVersion (version-2 envelope with a VALID checksum still skipped → prev; all-unknown → fallback), byte-stability (two saves differ only in the `savedAt` digits — payload/checksum regions byte-identical, split pinned around the `"savedAt":` marker).
- `StoreRulesPinnedTests.swift`: raw-literal pins for all names, version, count, read order, temp name, default-directory suffix + existence (the ONLY raw-literal site, per anti-echo).
- `SnapshotStoreConcurrencyTests.swift`: 24 concurrent saves converge to a consistent chain — load serves the current envelope's payload, the chain holds three distinct members of the saved set, and `savedAt` is exactly adjacent on the clock's final three ticks (order-independent pins; see the post-review flake-fix note below); 8 savers × 16 states racing 4 loaders × 40 loads — every load lands on the fallback or a savable state, never torn, never fails, and the post-completion load serves a saved state carrying the final (128th) tick (membership + adjacency, not a pinned bond index).
- `MomoKitDisciplineScanTests.swift` + `Support/MomoKitDisciplineScan.swift` + `Support/KitRepo.swift`: standing scans over the real `Sources/MomoKit` (no ambient time anywhere — zero exemptions; no ambient path outside `StoreRules.swift`; imports Foundation+MomoCore only), non-vacuous both directions: seeded-violation fixtures turn each scan red (per-literal matcher pins, per-file+per-family exemption proof, comment-immunity proof), the real-tree tests are the restore-green halves, and the exemption is liveness-pinned (file exists, exactly one `applicationSupportDirectory` occurrence — REVIEW-TASK-014 MINOR-2's discipline).
- `Support/StoreFixture.swift`: the populated-state builder (`state(bond:)` content-identifiable markers; `populatedState()` with every field non-default), compile-pinned enum case sets, and `TickingClock` (a reference-type `EngineClock` — `ManualEngineClock` is a value type so a store holds a private copy that cannot be advanced externally; `TickingClock` advances per read so multi-save `savedAt` ordering is real).

### Suite results (exact command + counts)
- Command: `swift test` (repo root, branch `feature/EPIC-005-persistence`).
- Final: **417 tests in 46 suites, all passed** (baseline 369/43 before TASK-021; placeholder suite removed, 4 suites added). Clean rebuild (`swift package clean && swift build --build-tests`) warning-free for every TASK-021 file; two PRE-EXISTING warnings remain, both outside this task's diff: `Tests/MomoCoreTests/EngineClockTests.swift:46` (`var` never mutated → `let`; TASK-008-era file, untouched here) and a toolchain-level `ld: warning: search path '/opt/extra/lib' not found`. Recorded for the orchestrator to route (§22) — not fixed here to keep the diff scope-clean.

### Post-review flake fix (orchestrator-dispositioned)
**Root cause (independently verified before fixing):** `concurrentSavesConvergeToTheTotalOrder` pinned WHICH total order the actor imposes — `load == state(bond: 24)` plus chain bonds {24, 23, 22}. That over-specifies: the 24 task-group children reach the `await store.save` suspension point in an unspecified order, and Swift's actor runtime guarantees only that saves are total-ordered — it makes NO FIFO guarantee about job execution order — so the serialized execution order σ can be ANY permutation of the saved set. The observed intermittent failure ({current 22, previous 24, oldest 23}) is exactly σ ending (…, 23, 24, 22): the store behaved correctly; the test asserted more than Requirement 4 provides. Same defect species at the old post-completion pin of `loadsRacingSavesObserveOnlyCompleteGenerations`: 8 savers interleave through the actor, so the globally-last completed save can come from a straggler saver still mid-loop — not necessarily bond 16.

**Grounding (verified in source before rewriting):** each `save` reads the injected clock exactly once, inside the actor-isolated body (`SnapshotStore.swift`, `savedAt: clock.now()`), and `TickingClock` (StoreFixture.swift) returns strictly increasing instants per read — so `savedAt` strictly increases along σ; the demotion sequence (prev→prev2, current→prev, temp→current, all actor-isolated) leaves the on-disk chain as exactly the last three completed saves of σ.

**New pins (order-independent by construction):** test 1 (renamed `concurrentSavesConvergeToAConsistentChain`) now asserts (a) `load(fallback:)` == the current envelope's payload (the read path serves the newest completed generation); (b) the chain's three bonds are pairwise-distinct members of the saved set 1...24 (corrected by the amendment below: this proves no-duplicate and no-out-of-set-fabrication only — not no-lost); (c) `savedAt` strictly descends current > previous > oldest (superseded by the amendment below: replaced by exact savedAt adjacency). The load-bearing guarantee was (b)+(c), not which bond lands in current. Test 2's post-completion pin became membership: the final load's bond ∈ 1...16 (a real saved state, never the fallback). In-race membership pins untouched (already sound). The Test-inventory bullet above was updated to match; only `Tests/MomoKitTests/SnapshotStoreConcurrencyTests.swift` changed — zero production-source changes.

**Stability evidence (exact commands, repo root):**
- `swift test --filter SnapshotStoreConcurrencyTests` — **20 consecutive green runs** (logs `/tmp/t21-stab-1..20.log`), zero failures, no streak reset (gate: ≥ 20 consecutive).
- `swift test` — **3 consecutive green runs**, each `Test run with 417 tests in 46 suites passed` (baseline counts preserved exactly; logs `/tmp/t21-full-1..3.log`).
- Original-flake reproduction: not attempted (optional/non-blocking per the disposition; the mechanism is established analytically above and consistent with the observed permutation).

**Amendment (verification round 1, MAJOR-1): savedAt adjacency repair.** The delta verification (`.claude/tasks/reviews/REVIEW-TASK-021-FLAKEFIX-VERIFICATION.md`, CHANGES_REQUIRED) proved the round-1 pins sound but insufficient for Requirement 4's convergence clause: a store that silently freezes after k ≥ 3 saves (the encoding-failure early-return at `SnapshotStore.swift:148-154` is exactly that shape) passes load == current, distinct-in-set, AND strict descent — the first three saves of any σ prefix satisfy all three, so round-1's "no lost generation" was overclaimed. Repair (test file only): strict descent REPLACED by exact savedAt adjacency over the deterministic tick schedule — `TickingClock` returns-then-advances exactly 1 s per read, each save reads the clock exactly once (`SnapshotStore.swift:146`, the single `clock.now()` site in MomoKit, inside the actor), and loads consume no ticks, so k completed saves leave the clock at exactly tick base+(k−1): test 1's 24 saves must land the chain at base+23 / base+22 / base+21, and test 2's 8 × 16 = 128 saves must leave the current envelope at base+127 (pinned on the envelope via the existing `readEnvelope` helper — `EngineState` carries no `savedAt` — with load == envelope payload tying it to the served state). Exact adjacency proves ALL saves completed, none skipped, no double tick, and the chain = the last three completed saves, whichever σ the scheduler chose; a frozen/lossy store shifts the arithmetic and fails. MINOR-1 applied: test 2's post-completion comment no longer claims a straggler saver mid-loop (none can exist after the task group's join) — the correct rationale is that σ's final element is scheduler-chosen across the savers' interleavings. Mechanical companion: test 2's signature became `async throws` (the envelope `#require` needs a throwing context, matching test 1's shape). Re-run gates: `swift test --filter SnapshotStoreConcurrencyTests` — **20 consecutive green**, no resets (logs `/tmp/t21r2-stab-1..20.log`); `swift test` — **3 consecutive green**, each `417 tests in 46 suites passed` (logs `/tmp/t21r2-full-1..3.log`). Exact adjacency verified green on the first real run — no arithmetic discrepancy.

## Reviewer Findings
**Verdict: APPROVED_WITH_MINOR_NOTES** (independent adversarial review, 2026-09-09; full record with evidence: `.claude/tasks/reviews/REVIEW-TASK-021.md`).

All 8 requirements PASS; AC-1 reproduced twice by the reviewer (`swift test` = 417 tests / 46 suites, all passed, on both review-start HEAD `3e1deca` and post-restore). Independent recipe re-derivation matches the on-disk checksum; envelope shape, verbatim embedded sorted payload, and injected-clock `savedAt` verified at the raw-byte level. MomoCore diff mechanically confirmed conformance-only (every removed line is a declaration list replaced by its `, Codable` superset; 16-type closure accurate; `familiesUsed` is the only Set). Cross-process checksum re-verification PROVEN (file saved in one process loads + re-verifies in three fresh processes), confirming Disclosure 1's necessity. Eleven unnamed/adversarial filesystem intermediates constructed via the public API (garbage/empty/truncated/directory-as-file/BOM/unsorted-equivalent/missing-checksum/uppercase-checksum/extra-envelope-key/payload-extra-field/mixed) — none made `load` throw or serve a mixed state; unknown-version gate order (version before checksum) verified in code and behaviorally, and bite-proven by sanctioned mutation 1 (`currentSchemaVersion` 1→2 → exactly 4 pin failures, named lines). Mutation 2 (`.sortedKeys` removed from `payloadJSONData`) collapsed the whole store surface (39 tests failed) — with stronger teeth than claimed: unsorted `JSONEncoder` output is non-canonical even within one process on this toolchain. Both mutations restored byte-identically (cmp + SHA-256); scratch confined to /tmp. Concurrency tests assessed real (monotonic `savedAt` + membership pins; `nonisolated` load design genuinely exercises rename atomicity). Discipline scans non-vacuous (red-proofed fixtures + liveness/occurrence pins); the `init(clock: SystemEngineClock())` default adjudicated ACCEPTABLE (ambient read stays in MomoCore's sanctioned site; no `Date` literal in MomoKit).

**Findings requiring action:** none blocking. Two MINOR doc corrections for the orchestrator to apply when archiving this task (no code change, no re-review):
1. MINOR-1 — Implementation Notes' "API shape" claims the Foundation-default Date strategy is "ISO-8601-with-fragments"; the on-disk bytes are a JSON **number** (seconds since the reference date — raw token `810641472` at the pinned clock). The SnapshotStore header's statement ("seconds since the reference date, a JSON number") is the correct one; fix the Notes to match.
2. MINOR-2 — Disclosure 1 attributes checksum instability solely to per-process hash-seeded `Set` order; the reviewer proved instability ALSO arises per-encode-call from unsorted keyed-container ordering (same process, same value, different byte output). Broaden the mechanism note; the design conclusion (`.sortedKeys` REQUIRED + sorted-set encoding) is validated more strongly than stated.

**Observations (no action required in TASK-021):** (1) cross-process checksum re-verification is real but unpinned by the suite — candidate pin for TASK-022/024 (load a generation crafted from recorded payload bytes); (2) Foundation's decoder tolerates a UTF-8 BOM on a generation file (within contract — a state, never an error); (3) the recipe is coupled to this toolchain's canonical Codable byte shape (enums encode as keyed objects, e.g. `{"settle":{}}`) — a toolchain byte-format change would fail checksums for ALL generations at once → fresh default; worth an ADR-002/TASK-022 note; (4) `StoreRulesPinnedTests.defaultDirectory()` touches the real `~/Library/Application Support/Momo` (idempotent; test-hygiene note); (5) unknown-version tests use raw `2`/`9` rather than `currentSchemaVersion + 1` (nitpick; acceptable — rewritten with the TASK-022 migrate chain). Nitpicks: crash-window table N vs N−1 labeling differs between the code header and the task file (same substance); `SnapshotEnvelope` internal + `@testable` is deliberate and load-bearing for the pins.

Reviewer probe/mutation restore proof: `StoreRules.swift` sha256 `2b0913c4…` and `SnapshotStore.swift` sha256 `ddd7e38a…` both byte-identical to pristine after testing. Reviewer did not commit or push; HEAD moved mid-review to `d4c8156` solely via the orchestrator's docs-only `status.md` commit (documented in the review record §2).

### Flake-fix verification (REVIEW-TASK-021-FLAKEFIX-VERIFICATION)

**Verdict: CHANGES_REQUIRED** (independent delta-verification, 2026-09-09; full record: `.claude/tasks/reviews/REVIEW-TASK-021-FLAKEFIX-VERIFICATION.md`). Basis: the rewrite is SOUND and stable — all pins are order-independent, pristine hashes verified untouched (`2b0913c4…`/`ddd7e38a…`), 16/16 consecutive focused + 3/3 full green runs, and the sanctioned step-swap mutation bit exactly as predicted (`SnapshotStoreConcurrencyTests.swift:48`, slot `#require` nil; restored byte-identically, cmp + sha256) — but the new pins do NOT prove Requirement 4's convergence clause ("the newest completed save is current"): a store that silently freezes after ≥ 3 saves or drops interior saves passes every pin (MAJOR-1), so the subsection's "no lost … generation" claim overstates what the pins deliver; a sound, strictly stronger savedAt-adjacency pin is available (TickingClock ticks deterministically, one read per save ⇒ expected current/prev/oldest = base+23/22/21 s in test 1, base+127 s post-completion in test 2) and is prescribed, along with a MINOR-1 comment-mechanism correction in test 2. Production code is not implicated.

Round 2 (2026-09-09): **APPROVED** — MAJOR-1 closed (adjacency pins exact and as prescribed; single-clock-read assumption re-verified; my 16/16 focused + 3/3 full green; sanctioned freeze mutation failed exactly the new pins at lines 69–71 + 127 and no others; restored byte-identically, cmp + sha256 `2b0913c4…`/`ddd7e38a…`) — see the Round 2 section of `.claude/tasks/reviews/REVIEW-TASK-021-FLAKEFIX-VERIFICATION.md`.

## Completion Evidence
AC-1 `swift test` green: **417 tests / 46 suites passed** (baseline 369/43; +48 net) — reproduced independently by the implementation agent, the adversarial reviewer (×2), the delta-verification reviewer (×3 across rounds), and the orchestrator (×2 post-fix). AC-2–AC-6 verified requirement-by-requirement in REVIEW-TASK-021 §10 (envelope exactness incl. cross-process checksum re-derivation over 4 fresh processes; write path + crash windows incl. 11 unnamed intermediates; no-error read path across 19 corruption/probe states; serialized writes incl. the adjacency convergence pins; StoreRules single-sourcing with mutation-attributed pins; clock/import discipline scans non-vacuous; 16-type Codable closure audited conformance-only; case-exhaustive roundtrip matrix). Review: APPROVED_WITH_MINOR_NOTES + delta verification APPROVED (round 2) after the §11 fix loop (2 rounds, test-file only, production code byte-identical to the reviewed pristine hashes throughout). Post-review warnings routed: EngineClockTests.swift:46 var→let (separate chore commit) + toolchain ld path (machine-level). Commit: (this commit) `feat(persistence): TASK-021 SnapshotStore — envelope, atomic writes, generational recovery` on `feature/EPIC-005-persistence`; push immediately follows (hash recorded in status.md at housekeeping).

## Handoff
### Completed
All 8 contract requirements implemented and test-pinned: envelope (exact shape, `.sortedKeys` payload + envelope, MomoCore-SHA256 lowercase-hex checksum, injected-clock `savedAt`); write path (temp-then-atomic-rename with the documented 5-step demotion order + crash-window table); read path (current → prev → prev2 → injected fallback, non-throwing, checksum- and schema-gated); serialized saves (actor) with `nonisolated` loads; `StoreRules` constants home with raw-literal pins; clock + import discipline scans (non-vacuous both directions); complete Codable closure (16 types, enumerated in Implementation Notes); full test suite green.

### Files Changed
- NEW `Sources/MomoKit/SnapshotStore.swift` (+281)
- NEW `Sources/MomoKit/StoreRules.swift` (+79)
- DELETED `Sources/MomoKit/MomoKitPlaceholder.swift` (−13)
- MODIFIED (additive `Codable` only): `Sources/MomoCore/EngineState.swift` (+3 conformance entries across 3 types), `Pet.swift`, `PetState.swift` (4 types), `Quest.swift` (3 types), `SettingsState.swift`, `Bands.swift` (BondStage only), `CharacterInterface.swift` (2 types)
- MODIFIED `Sources/MomoCore/DayRecord.swift` (+77: hand-written Codable + `persistenceOrder` — DISCLOSURE 1)
- MODIFIED `Package.swift` (+1−1: `MomoCore` added to MomoKitTests deps — pre-sanctioned disclosure 4)
- DELETED `Tests/MomoKitTests/MomoKitPlaceholderTests.swift` (−16)
- NEW tests: `Tests/MomoKitTests/SnapshotStoreTests.swift` (+467), `StoreRulesPinnedTests.swift` (+54), `SnapshotStoreConcurrencyTests.swift` (+102), `MomoKitDisciplineScanTests.swift` (+157), `Support/StoreFixture.swift` (+305), `Support/MomoKitDisciplineScan.swift` (+202), `Support/KitRepo.swift` (+35)
- Tracked-file diff vs HEAD: 11 files, +93/−45; plus the 9 new untracked files above.

### Tests Run
`swift test` (repo root). Clean-rebuild warning audit: `swift package clean && swift build --build-tests`.

### Test Results
417 tests / 46 suites — ALL PASSED (baseline 369/43; +48 net: placeholder suite removed, store suites added). Zero warnings from any TASK-021 file; two pre-existing warnings remain outside this diff (EngineClockTests.swift:46 `var`→`let` candidate; toolchain `/opt/extra/lib` ld search path) — recorded in Implementation Notes for the orchestrator to route.

### Known Issues
None in TASK-021 scope. (Pre-existing warnings above are the only build output blemishes; ledger pruning/sync-DTO scope is TASK-022/023 as contracted.)

### Decisions Made
See Implementation Notes "Disclosures" (5 items: hand-written DayRecord Codable for Set-ordering checksum determinism; decode-does-not-recheck-INVs posture gated by checksum; `SystemEngineClock()` default clock param; Package.swift test-target line; Foundation-default Date strategy) and "API shape" (actor save / `nonisolated` load rationale; gate order schemaVersion-before-checksum).

### Reviewer Status
REVIEWED (orchestrator update at close) — REVIEW-TASK-021 **APPROVED_WITH_MINOR_NOTES** (independent adversarial review: checksum recipe re-derived + cross-process-verified, conformance-only diff audit, 11 unnamed crash-window states, 2 sanctioned mutations with exact attribution); both MINORs were doc-only, dispositioned by the orchestrator. Post-review flake → two-round §11 fix loop on the test file only, delta-verified by a fresh reviewer: **REVIEW-TASK-021-FLAKEFIX-VERIFICATION round 2 APPROVED** (MAJOR-1 convergence gap closed by savedAt adjacency pins, proven by an executable freeze mutation; MINOR-1 comment closed). No CHANGES_REQUIRED outstanding.

### Commit
(this commit) — `feat(persistence): TASK-021 SnapshotStore — envelope, atomic writes, generational recovery` on `feature/EPIC-005-persistence` (orchestrator; atomic: sources, tests, Package.swift, task file, both review records).

### Push
`feature/EPIC-005-persistence` → `origin` immediately after (this commit); status recorded in status.md at housekeeping.

### Recommended Next Step
Orchestrator: spawn the fresh independent review agent (Jupiter) against this task file + the working-tree diff; on APPROVED (findings addressed), commit atomically as `feat(persistence): TASK-021 SnapshotStore — envelope, atomic writes, generational recovery` and push; then TASK-022 (migration/pruning).
