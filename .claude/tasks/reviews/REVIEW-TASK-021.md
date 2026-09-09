# REVIEW-TASK-021 — SnapshotStore: envelope, atomic writes, generational recovery

**Reviewer:** independent adversarial review agent (Jupiter), fresh context, no prior conversation with the implementer (CLAUDE.md §10/§33).
**Date:** 2026-09-09
**Task:** `.claude/tasks/active/TASK-021-snapshot-store.md`
**Verdict: APPROVED_WITH_MINOR_NOTES** — 0 MAJOR, 2 MINOR (both doc-accuracy in the task file's Implementation Notes; no code change), 5 OBSERVATION, 2 NITPICK. All acceptance criteria verified against evidence I produced myself.

---

## 1. Independence statement

I am a fresh agent spawned solely for this review. I read the binding contract (task file sections above "## Implementation Notes"), 05-technical-architecture §5 (lines 438–477), and ADR-002 **before** weighing any implementer claim, and re-derived the normative requirements independently:

- Envelope `{schemaVersion: Int (=1), savedAt: Date (UTC, injected clock), checksum: lowercase-hex SHA-256 of the payload's `.sortedKeys` JSON, payload: EngineState}`; envelope itself `.sortedKeys`.
- Layout: exactly `state.json` / `state.prev.json` / `state.prev2.json` in an injected directory (+ the sanctioned Application Support/Momo default factory); temp file for atomic rename.
- Write: encode → checksum → temp → atomic rename with demotion; documented order + crash-window analysis; serialized (total-ordered) saves.
- Read: current → prev → prev2 → injected fallback; checksum + schemaVersion gate per generation; public API never throws, never serves an error or a torn/mixed state; unknown higher schemaVersion ⇒ generation unreadable, no migration in this task.

The implementation matches this derivation on every point. The implementer's Implementation Notes were then compared against my derivation; two of their prose claims proved wrong (§11, MINOR-1/MINOR-2) — the code is right, the Notes' descriptions are not.

## 2. State reconciliation

| Check | Result |
|---|---|
| HEAD at review start | `3e1decad8bbab38b2a6e6fae387063954615b8b` on `feature/EPIC-005-persistence` — verified with `git rev-parse` before any probe |
| HEAD at review end | `d4c8156c64ef13e01149c1063378ed18280ad547` — **moved mid-review by the orchestrator**, not by me. `git show --stat HEAD`: docs-only commit touching `.claude/tasks/status.md` (+5/−3) ("TASK-021 impl complete (417/46 verified), review cycle in flight"). Nothing in the audited scope changed; TASK-021 work remains uncommitted in the working tree. Full suite re-run green on top of this HEAD. |
| Working-tree inventory | Exactly the Handoff's list: 8 MomoCore files + `Package.swift` modified, 2 placeholder files deleted, 9 new untracked files under `Sources/MomoKit` / `Tests/MomoKitTests` (incl. `Support/`), task file Status-below sections updated. `git diff --stat HEAD -- Sources/ Package.swift Tests/`: 11 files, +93/−45 — matches the Handoff's claim exactly. |
| Task-file contract integrity | `git diff -U0` on the task file: all hunks at line ≥ 84 (Status and below). Objective through Git Requirements untouched. |

## 3. MomoCore diff audit (checklist D) — conformance-only, mechanically confirmed

`git diff Sources/MomoCore/ Package.swift`, negative-line audit (`grep '^-'`): **every** removed line is a type declaration list replaced by its `, Codable` superset (16 lines) plus the single pre-sanctioned `Package.swift` test-target line. Zero field, signature, or semantic drift.

- Synthesized `, Codable` additions, 15 types — verified name-for-name against the disclosed enumeration: `Handshake`, `GreetingStamp`, `EngineState` (EngineState.swift); `Pet` (Pet.swift); `Wakefulness`, `Activity`, `SatietyPhase`, `PetState` (PetState.swift); `QuestID`, `QuestFamily`, `QuestProgress` (Quest.swift); `SettingsState` (SettingsState.swift); `BondStage` (Bands.swift); `GreetingKind`, `HandshakeKind` (CharacterInterface.swift). **16 total with the hand-written `DayRecord` — the "16-type closure" claim is accurate.**
- DayRecord hand-written conformance: CodingKeys cover exactly its 10 stored fields (compile-pinned by `init(from:)` total initialization); `persistenceOrder` is an exhaustive switch over all 5 `QuestFamily` cases with NO `default` — a new case fails the build here, so the persistence byte-format must grow deliberately; decode maps back into a `Set`. Field names/types/values untouched.
- Closure verification: `EngineState`'s fields are `Pet`, `PetState`, `[DayRecord]`, `SettingsState`, `Handshake?`, `[UUID]`, `BondStage`, `Instant`, `Instant`, `GreetingStamp?`; `Instant = Date` (Instant.swift:8); `QuestProgress` carries only `questID`/`progress`/`completed`. **`familiesUsed` is the only `Set` in the whole closure** — the claim that DayRecord is the only type needing custom handling is correct. The "deliberately untouched" list (`MoodBand`, `EnergyBand`, `QuestWindow`, `QuestCatalogEntry`, `EngineEvent`, …) is genuinely out of the closure and out of the diff.

## 4. Checksum recipe + envelope — independently reproduced (checklist C)

I built a scratch probe executable in `/tmp/momo-review-probe` (SwiftPM path-dependency package, later linked against the repo's own build objects — **zero repo mutation**), with my OWN populated fixture (5-element `familiesUsed`, 2-day ledger, all fields non-default; fixed UUIDs/dates) and my OWN encoder + `MomoCore.SHA256` — never calling store helpers. One `store.save` at a pinned `ManualEngineClock` instant, then inspection of the raw `state.json`:

| Probe C assertion | Result |
|---|---|
| my independently computed recipe digest == envelope `checksum` field | **true** |
| checksum is 64-char lowercase hex | true |
| `savedAt` == injected clock value | **true** |
| envelope keys == exactly `{schemaVersion, savedAt, checksum, payload}` | true |
| `schemaVersion` on disk | 1 |
| payload `.sortedKeys` bytes embedded **verbatim** in the file (sortedKeys envelope) | true |
| raw bytes after `"savedAt":` | `810641472` — a JSON **number** (seconds since reference date) — see MINOR-1 |

## 5. Per-process checksum stability + disclosure necessity (checklist E)

- **Cross-process re-verification PASSES.** The file saved by probe process 1 was loaded by **three further fresh processes** (new hash seed each): `load` returned the saved state and my recipe re-derivation matched the stored checksum every time. The hand-written `DayRecord` conformance makes files self-verifying across processes.
- **The disclosure's necessity claim is TRUE.** Probe mode SET printed the SYNTHESIZED `Set<QuestFamily>` encoding in 4 separate processes: 4 different element orders (`[pet,feed,play,greet,care]`, `[play,pet,care,greet,feed]`, `[greet,play,care,pet,feed]`, `[play,feed,care,greet,pet]`). A synthesized `DayRecord` would indeed fail its own checksum in the next process — the hand-written conformance is necessary, not gratuitous.
- Note: the shipped suite itself always saves and loads within one test process (fresh temp dirs per run), so this cross-process property is real but **not pinned by the suite** — see OBSERVATION-1.

## 6. Crash-window matrix + no-error claim — extended adversarially (checklists F, G)

All six of the implementation's windows have real suite pins (verified by reading the tests). I then constructed **eleven filesystem states the implementation's table does not name**, all through the PUBLIC `load(fallback:)` API only:

| Probe | Constructed state | Expected | Observed |
|---|---|---|---|
| F1a | valid current + **garbage prev** + valid prev2 | current served | PASS |
| F1b | F1a then corrupt current | garbage prev **skipped without error**, prev2 served | PASS |
| F2 | valid envelope under `state.json.tmp` only, no generations | temp never read → fallback | PASS |
| F3 | `state.json` is a **directory**; prev valid | current skipped, no throw, prev served | PASS |
| F4 | hand-crafted envelope, payload bytes **equivalent-but-unsorted**, checksum valid over exactly those bytes | recipe gate refuses (re-encode is canonical/sorted) → fallback | PASS |
| F5 | envelope missing the `checksum` field | decode fails → fallback | PASS |
| F6 | **uppercase** checksum of the correct digest | refused (case-sensitive lowercase gate); prev served | PASS |
| F7 | current missing + **truncated prev** + valid prev2 | prev2 served | PASS |
| F8 | valid envelope + extra unknown top-level key | still loads (additive envelope evolution) | PASS |
| F9 | payload with an **extra field**, checksum over those bytes | re-encode drops it → digest differs → refused; prev served | PASS |
| F10 | garbage current + **empty prev** + valid prev2 | prev2 served | PASS |
| F11 | UTF-8 **BOM** prefixed to a valid current | (my expectation: refused) | served correctly — see OBSERVATION-2 |

**No probe made `load` throw, hang, or return a mixed/invalid state.** The unknown-version gate: code order verified (`SnapshotStore.swift:219-227` — version gate precedes the checksum), and the suite's version-2-with-valid-checksum pin exercises exactly that order; sanctioned mutation 1 below proves the gate reads `StoreRules`.

## 7. Sanctioned mutations (checklist H) — exact attribution, byte-identical restore

Pre-probe: pristine copies of both untracked sources saved to `/tmp/momo-review-probe/pristine/` with SHA-256 hashes; post-restore: `cmp` + `shasum -a 256` both match (`StoreRules.swift 2b0913c4…`, `SnapshotStore.swift ddd7e38a…`).

**Mutation 1 — `StoreRules.currentSchemaVersion` 1→2.** `swift test --filter "SnapshotStoreTests|StoreRulesPinnedTests|SnapshotStoreConcurrencyTests"` → 4 distinct pins fail:
- `StoreRulesPinnedTests.swift:22` (raw `== 1` pin)
- `SnapshotStoreTests.swift:190` ("the on-disk envelope carries schemaVersion == 1 (raw pin with mutation teeth)" — its designed bite)
- `SnapshotStoreTests.swift:396` (unknown-version-skip test: the version-2 envelope now loads as current — the gate demonstrably reads `StoreRules.currentSchemaVersion`)
- `SnapshotStoreTests.swift:418` (unknown-everywhere test: version-2 generations are no longer unknown)

The unknown-version fall-through provably bites. Restored → byte-identical.

**Mutation 2 — `.sortedKeys` removed from `SnapshotStore.payloadJSONData`.** `swift test --filter "SnapshotStoreTests|StoreRulesPinnedTests|SnapshotStoreConcurrencyTests"` → **"Test run with 39 tests in 3 suites failed … with 38 issues"** — the entire store test surface collapses, including the designed bite `envelopeChecksumEqualsRecomputedRecipe` (the suite's independent sorted-recipe re-derivation) and `populatedStateRoundtripsExactly` (the store refuses its OWN last write). I chased the mechanism to first principles (probes m2–m6 in /tmp): on this toolchain, unsorted `JSONEncoder` output is **not a canonical function of the value even within one process** — two encodes of the same decoded payload produced different top-level key orders (`{"pendingHandshake":…}` vs `{"days":…}`), so the save-time digest and the load-time re-encode digest can never be relied upon to agree. Requirement 1's ".sortedKeys REQUIRED" is not merely a cross-process nicety; it is load-bearing for the recipe itself, and the pins catch its removal catastrophically. Restored → byte-identical; full suite re-run: **417/46 green**.

Mutation 3 (demotion-order swap, optional) not executed: both mandated mutations completed with exact attribution; the demotion order was instead verified by code walkthrough (destination-free guarantee of steps 1→2→3) plus the crash-window and chain pins.

## 8. Concurrency (checklist I)

Read both stress tests critically; they are real, not vacuous: (a) 24 concurrent saves via `withTaskGroup` → final chain pinned content-wise to bonds {24, 23, 22} AND `savedAt` strictly decreasing down the chain — without actor serialization, interleaved rename sequences would desynchronize savedAt order from demotion order and break the monotonicity pin; (b) 8 savers × 16 states racing 4 loaders × 40 loads with a membership pin over every observed bond. The tests' own comment honestly acknowledges what the pin cannot distinguish (a torn read is structurally indistinguishable from a fall-through) — but POSIX same-directory rename atomicity makes torn reads impossible, and the membership pin would catch fabricated/mixed payloads. The `nonisolated load` design means the race is genuinely exercised rather than masked by the actor queue. I could not weaken the total-order claim.

## 9. Discipline scans (checklist J) + adjudications

- Real-tree scans green (part of 417/46): no ambient time anywhere in `Sources/MomoKit` (zero exemptions); no ambient path outside `StoreRules.swift`; imports Foundation+MomoCore only (grep + suite agree).
- Non-vacuity is layered and proven in-suite: per-literal matcher proof (`everyPatternMatchesSomething` — each banned literal must match a canonical fixture), seeded-violation fixtures turn every scan red with exact attribution (`ambientTimeFails`, `ambientPathsFail`, `foreignImportFails`), comment-immunity proof, per-file+per-family exemption proof, and the exemption is liveness+occurrence-pinned (exactly one `StoreRules.swift` with exactly one `applicationSupportDirectory` occurrence — REVIEW-TASK-014 MINOR-2's discipline). My independent greps confirm: no `Date(`/`Date.now` in MomoKit; no `print`/`NSLog`/`debugPrint`; no raw file-name literals outside `StoreRulesPinnedTests`.
- **Default-clock adjudication (`init(clock: SystemEngineClock())`): ACCEPTABLE.** Requirement 6 bans ambient `Date()`/`Date.now` reads in MomoKit; the default argument is a type reference, and the actual ambient read stays inside MomoCore's one sanctioned, scanner-exempted `SystemEngineClock` — strictly cleaner than the contract-sanctioned `defaultDirectory()` factory, which performs its ambient read inside MomoKit. Tests inject `ManualEngineClock` (verified: the suite's `savedAt == injected clock` pin passes). The symmetry the contract granted for the directory factory covers the clock default.

## 10. Requirement-by-requirement verdict (contract AC 1–6 / Requirements 1–8)

| Requirement | Verdict | Evidence |
|---|---|---|
| 1 Envelope exactness | **PASS** | §4 table; raw-byte checks; header documents the recipe and the (correct) date strategy |
| 2 Write path + demotion + crash analysis | **PASS** | code walkthrough (destination-free 3-step sequence, in-directory temp, catch-cleanup, DEBUG-loud failure); header table; 5 crash-window pins + my 11 unnamed states |
| 3 Read path, no error surface | **PASS** | non-throwing signatures; 7 named corruption modes in suite + 12 probe states; survivors-untouched + loads-never-write pins |
| 4 Serialized writes | **PASS** | actor save; justified `nonisolated` load; §8 stress analysis |
| 5 StoreRules + unknown-version hook | **PASS** | constants single-sourced with authority labels; raw-literal pins; mutation 1 |
| 6 Clock + import discipline | **PASS** | §9; default-clock adjudicated acceptable |
| 7 Closure completeness | **PASS** | §3; every persisted enum case roundtrips via compile-pinned case-parameterized matrix (incl. `Activity?.none`), all 7 QuestIDs + all 5 families coverage-pinned |
| 8 Focused suite | **PASS** | all 8 bullet families present and named per house style; mutation-proven teeth |

**AC-1** `swift test` green: 417 tests / 46 suites — reproduced by me twice (before mutations, after restore). Pre-existing warnings confirmed outside the diff (`Tests/MomoCoreTests/EngineClockTests.swift:46` — file untouched; toolchain `ld: search path '/opt/extra/lib' not found` — also appears in my /tmp probe build, i.e. machine/toolchain-level). **AC-2–AC-6**: PASS per the table above.

## 11. Findings

**MINOR-1 (doc accuracy — task file, not code):** Implementation Notes claim the Date strategy is "Foundation default (**ISO-8601-with-fragments**…)". The actual bytes are a JSON **number** (seconds since the reference date; probe C raw token `810641472`). The `SnapshotStore.swift` header states it correctly. Foundation's default is `.deferredToDate` (a number), not ISO-8601. Correct the Notes when archiving the task; no code change.

**MINOR-2 (doc precision — task file, not code):** Disclosure 1 attributes the checksum instability solely to "the runtime's per-process hash-seeded order" of the `Set`. True as far as it goes (proved, §5), but my mutation-2 investigation shows unsorted JSONEncoder output is non-canonical **even within one process** (per-encode-call key-order variance). The design conclusion (`.sortedKeys` REQUIRED + sorted set) is validated *more* strongly than claimed; the Notes' mechanism description should be broadened when archiving. No code change.

**OBSERVATION-1:** The suite never loads a file across processes (fresh temp dirs per test process), so cross-process checksum re-verification — the exact failure mode Disclosure 1 guards against — is real (my probe, 4 processes) but unpinned. Candidate for TASK-022/024: a pin that crafts a generation file from a recorded payload-byte fixture and loads it.
**OBSERVATION-2:** Foundation's `JSONDecoder` on this toolchain tolerates a UTF-8 BOM: a BOM-prefixed current generation still verifies (checksum over the payload is intact) and serves. Within contract (a state, never an error; integrity gate is the checksum), recorded for completeness.
**OBSERVATION-3:** The recipe is coupled to the toolchain's canonical Codable byte shape (this toolchain encodes simple enums as keyed objects, e.g. `{"settle":{}}`, not the classic string). A future toolchain that changes canonical bytes would fail checksums for ALL generations at once → fresh default. Self-consistent (write and read share the encoder) and compliant with the contract's recipe; worth an ADR-002/TASK-022 note as a documented limit of the re-encode verification design.
**OBSERVATION-4:** `StoreRulesPinnedTests.defaultDirectory()` touches the real `~/Library/Application Support/Momo`. Idempotent and contract-sanctioned, but it is user-home I/O from a unit test; fine to keep, noting the hygiene.
**OBSERVATION-5:** The unknown-version tests construct versions with raw `2`/`9` rather than `StoreRules.currentSchemaVersion + 1`; a TASK-022 version bump would break them loudly (acceptable — they get rewritten with the migrate chain). NITPICK-graded deviation from strict anti-echo; the `schemaVersion == 1` raw pin is contract-mandated, not a violation.

**NITPICK-1:** The code header's crash-window table labels saves as N (current on disk = N) while the task file's table labels them N−1 — same substance, different framing; harmless.
**NITPICK-2:** `SnapshotEnvelope` is internal with the tests reaching it via `@testable` — deliberate and documented; fine, just noting the surface decision is load-bearing for the pins.

## 12. Recommendation to the orchestrator

Proceed: verdict **APPROVED_WITH_MINOR_NOTES**. The two MINORs are task-file doc corrections (apply while archiving the task; no re-review needed — no code change). Commit atomically per the task's Git Requirements (`feat(persistence): TASK-021 SnapshotStore — envelope, atomic writes, generational recovery`), push, record the hash, move the task to completed. My probes mutated nothing permanently: both sanctioned mutations restored byte-identically (cmp + SHA-256 verified), scratch work confined to /tmp and cleaned, HEAD reconciliation documented in §2.

## Probe / mutation ledger

| Action | Target | Restore proof |
|---|---|---|
| Mutation 1 | `StoreRules.swift` line 28: `1` → `2` | `cmp` OK; sha256 `2b0913c4…` == pristine |
| Mutation 2 | `SnapshotStore.swift` `payloadJSONData`: `.sortedKeys` line removed | `cmp` OK; sha256 `ddd7e38a…` == pristine |
| Scratch | `/tmp/momo-review-probe/` (probe package, m2–m6 probes, `work*/` dirs) | work dirs deleted; package remains in /tmp only, no repo path touched |

Final state at review end: HEAD `d4c8156` (orchestrator's docs-only commit, see §2); working tree inventory identical to review start; `swift test` = 417 tests / 46 suites, all passed.
