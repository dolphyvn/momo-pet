# TASK-014 — Engine Core: reduce, EngineClock, Seeded RNG, Day-Stable Seeds

## Parent Epic
EPIC-004 — Pet State Engine

## Objective
Stand up the engine's deterministic skeleton per 05 §4.1 + §4.10 (ADR-004): the `EngineState`/`EngineEvent`/`EngineOutcome` types, the single pure `reduce` entry point, the injectable `EngineClock`, the repo-owned seeded generator, and SHA-256-seeded day-stable seed derivation — with the dynamic behaviors (fold, response matrix, bond, quests) deliberately left to TASK-015…018 and the skeleton honest about that.

## Context
05 §4.1 is the shape spec (read it first — the sketch is normative for names/shapes; TASK-012's deviations precedent applies: immutability wins over sketch `var`). §4.10 is the clock/randomness spec. The engine lives in MomoCore (Foundation-only, D-R1, enforced by the live import-whitelist scan). ADR-004 bans timers/background work — the engine only ever runs inside `reduce`. **D-R1 vs SHA-256:** `Foundation` alone provides no SHA-256, and D-R1 bans importing CryptoKit in MomoCore — therefore implement a repo-owned SHA-256 (FIPS 180-4, ~60–80 lines, no dependency, D-R6-clean) and pin it against official NIST test vectors in tests. Document this as a deliberate decision in the task file (candidate note for the ADR log if the reviewer agrees it rises to that level). **Swift `Clock` idiom VERIFY item (05 Appendix B):** TASK-014 owns resolving how `EngineClock` maps to the current Swift `Clock`/concurrency idioms — record the resolution explicitly in Implementation Notes.

## Requirements
1. `EngineState` per 05 §4.1 — `pet`, `state`, `days` (7-day ledger, newest last), `settings`, `pendingHandshake`, `processedIntents` (≤ 64), `highestCelebratedStage`, `lastOpenedAt`, `lastEvaluatedAt`. `Sendable` value type; define the minimal `Handshake` value type it needs (§4.7's settle/wake/play tokens — machine semantics are TASK-015's; if §4.7's shape is underspecified for a skeleton, define the minimal honest form and flag it).
2. `EngineEvent` per §4.1 — `.interaction(InteractionIntent)`, `.characterReport(CharacterReport)` (incl. `handshakeCancelled`), `.evaluate(now: Instant)`.
3. `EngineOutcome` per §4.1 — `newState`, `response: ResponsePlan?`, `moments: [CharacterMoment]`, `changed: Bool`.
4. Single pure entry point `reduce(_ state:_ event:clock:rng:) -> EngineOutcome` per §4.1's signature. In THIS task its event semantics are deliberately minimal and honest: bookkeeping only (e.g. `.evaluate` stamps `lastOpenedAt`/`lastEvaluatedAt`; interactions pass through without dynamics, `changed` false unless bookkeeping changed) — with doc comments naming the owning tasks (015–018). No fake dynamics.
5. `EngineClock` protocol (`now() -> Instant`) + a production clock (Swift `Clock`-idiomatic — resolve the VERIFY item) + a manually-advanceable test clock. Every engine time read goes through it.
6. `SeededGenerator`: repo-owned SplitMix64-class generator (~20 lines) conforming to `RandomNumberGenerator`, `Sendable`-usable via `inout` per §4.1; pin against known SplitMix64 reference vectors.
7. Day-stable seeds per §4.10: `seed = SHA-256(petID ‖ localDayKey ‖ epoch ‖ salt)` truncated to 64 bits; salts `choreography`/`copy`/`quest`; same day ⇒ same seed; expose the derivation as a pure function. SHA-256 pinned to NIST vectors.
8. Purity enforced: no I/O, no `Date()`, no `Calendar.current`, no `TimeZone.current`, no system randomness (`random()`, `arc4random`, `UUID()`) anywhere in the new engine sources — add a standing source-scan test (banned-vocab-scan pattern) over the engine files so this stays mechanically true.
9. Focused tests: determinism spot tests (identical `(state, event, clock, seed)` ⇒ identical outcome, incl. draws from the generator); SplitMix64 vectors; SHA-256 NIST vectors; day-stable-seed properties (day-stability, salt separation, epoch sensitivity); clock protocol behavior; engine scan test green and non-vacuous.

## Files / Areas Likely Affected
- `Sources/MomoCore/` (new engine files: EngineState/EngineEvent/EngineOutcome/Handshake, Reduce, EngineClock, SeededGenerator, DaySeed, SHA256 — layout implementer's choice, documented)
- `Tests/MomoCoreTests/` (focused engine tests + the new standing scan)
- No Package.swift/pbxproj change expected

## Dependencies
- TASK-012 (domain model on `main`). TASK-015 (fold/wakefulness/handshakes) is OUT of this task — its file is materialized alongside.

## Constraints
- Jupiter model, fresh agent, no commit by agent.
- **D-R1: MomoCore imports Foundation only** — this task must NOT import CryptoKit; SHA-256 is repo-owned (see Context). Import-whitelist scan stays green.
- No new external dependencies (D-R6); no `print(`; no TODO debt (§26).
- Scope control (§22): fold rules, response matrix, bond ledger, quest logic → record as owning-task notes, do not implement.
- Engine reads time ONLY via `EngineClock`; derivations already take injected calendars (TASK-012 pattern).

## Acceptance Criteria
- AC-1: §4.1 types exist per spec names/shapes; `reduce` is the single pure entry point with minimal honest bookkeeping semantics and no fake dynamics.
- AC-2: `EngineClock` (protocol + production + manual test clock) exists; the Swift `Clock` idiom VERIFY item is resolved and recorded.
- AC-3: `SeededGenerator` (SplitMix64-class, `RandomNumberGenerator`) + day-stable seed derivation (`choreography`/`copy`/`quest`) exist; SHA-256 repo-owned and NIST-pinned; SplitMix64 reference-vector-pinned.
- AC-4: Purity scan test exists, green, non-vacuous (proven by a seeded violation in a scratch run reverted before review — TASK-010 harness-self-test pattern).
- AC-5: Determinism spot tests green (identical inputs ⇒ identical outcome, including generator draws); full `swift test` green with standing scans; baseline 80/14 preserved + new tests recorded.

## Required Tests
See Requirement 9. Verbatim `swift test` output recorded in Implementation Notes; coverage informational via the TASK-010 llvm-cov command.

## Review Requirements
- Fresh reviewer verifies: §4.1/§4.10 fidelity byte-level; purity claim (scan + grep + probe); SHA-256 correctness (NIST vectors actually assert, not smoke); SplitMix64 vectors real; day-stable seed properties hold (incl. epoch/salt separation); `changed` semantics honest; no dynamic-behavior scope creep; VERIFY item resolution sound. Record in `.claude/tasks/reviews/REVIEW-TASK-014.md`.

## Git Requirements
- Branch: `feature/EPIC-004-engine`
- Commit: `feat(engine): TASK-014 engine core — reduce, clock, seeded randomness, day-stable seeds`
- Push to origin after orchestrator commit; record hash in Completion Evidence.

## Status
APPROVED — REVIEW-TASK-014 returned **APPROVED_WITH_MINOR_NOTES** (0 MAJOR, all constants independently re-derived); orchestrator disposition applied (4 mechanical fixes, MINOR-1's full allowlist declined as redundant); `swift test` **126 tests / 20 suites green**; committing + pushing (never DONE until commit+push)

## Implementation Notes

### File layout (7 new sources + 7 new test files, house layout preserved)
- `Sources/MomoCore/SHA256.swift` — repo-owned FIPS 180-4 digest, zero imports (pure stdlib), ~70 lines of algorithm; `digest(_ message: [UInt8]) -> [UInt8]`.
- `Sources/MomoCore/SeededGenerator.swift` — SplitMix64 `RandomNumberGenerator`, no imports; `init(seed: UInt64)` + `next()`.
- `Sources/MomoCore/DaySeed.swift` — `DaySeed.make(petID:localDayKey:epoch:salt:) -> UInt64`, `Salt` enum (`choreography`/`copy`/`quest`), internal `preimage` for encoding pins.
- `Sources/MomoCore/EngineState.swift` — `EngineState` (§4.1 fields, all `let`, `Equatable`+`Sendable`) + minimal `Handshake` + `processedIntentsCapacity = 64`.
- `Sources/MomoCore/EngineEvent.swift` — `EngineEvent` (`.interaction`/`.characterReport`/`.evaluate(now:)`, Sendable-only like the sketch) + `EngineOutcome` (`Equatable` beyond the sketch, for FR-13 determinism assertions).
- `Sources/MomoCore/EngineClock.swift` — `EngineClock` protocol (`now() -> Instant`, `Sendable`) + `SystemEngineClock` + `ManualEngineClock` (value semantics, in MomoCore so every package test target reuses it).
- `Sources/MomoCore/Reduce.swift` — the single pure entry point, bookkeeping-only semantics, owner tasks documented in the doc comment.
- Tests: `SHA256Tests`, `SeededGeneratorTests`, `DaySeedTests`, `EngineClockTests`, `EngineReduceTests`, `EnginePurityScanTests` + `Tests/MomoCoreTests/Support/EnginePurityScan.swift` (pure scanner, ImportWhitelistScan's comment-stripper reused).

### Seed derivation byte encoding (the ‖-concatenation, documented in DaySeed.swift)
Length-framed fields, fixed order petID → localDayKey → epoch → salt; each field = 4-byte big-endian byte count + payload. Chosen over naive concatenation (ambiguous: ("ab","c") ≡ ("a","bc") — would silently reseed everything on any future field re-partition) and over field tags (the salt already separates domains). Payloads: petID = `UUID.uuid` 16-byte RFC 4122 form via `withUnsafeBytes` (NOT the hyphenated string); dayKey = UTF-8; epoch = fixed 8-byte BE two's-complement `Int` bit pattern; salt = UTF-8 of the raw value. Truncation = digest's first 8 bytes, big-endian ("leftmost 64 bits"). Pinned by golden-byte preimage test (54 bytes for the all-zero-petID fixture), a frame-parser round-trip test (proves self-delimitation), and a seed==first-8-BE-digest truncation test.

### SHA-256 + SplitMix64 vector provenance (full transparency)
- SHA-256: expectations are the official NIST/FIPS 180-4 example digests ("abc", empty, 56-byte two-block, one-million-'a') — all four cross-checked against the system `shasum -a 256` (OpenSSL) oracle BEFORE pinning; padding boundary cases (55/63/64/65 bytes) computed by the same oracle. The K/H constant tables in SHA256.swift were additionally verified by an independent Python computation (fractional parts of prime cube/square roots) — exact match.
- SplitMix64: algorithm fidelity is pinned to the canonical reference — Sebastiano Vigna's public-domain `splitmix64.c/.h` (fetched from bashtage/randomgen `randomgen/src/splitmix64/`, which cites OOPSLA'14 doi:10.1145/2714064.2660195 and Java 8 SplittableRandom); constants byte-identical in Zig stdlib `Random.SplitMix64`. **No published vector table was fetchable this session** (web search backends unavailable; grep.app/Bing blocked). Vectors are therefore computed by an independent Python reimplementation of that exact canonical form (Python source quoted in the test file header): seed 0 → `0xE220A8397B1DCDAF, 0x6E789E6AA1B965F4, 0x06C45D188009454F, 0xF88BB8A8724C81EC`; seed 1 → `0x910A2DEC89025CC1, 0xBEEB8DA1658EEC67`; seed 2 → `0x975835DE1C9756CE, 0xBFC846100BFC1E42`; seed 9 → `0xAEAF52FEBE706064`. Reviewer can rerun the Python one-liner to confirm. Discipline note: one constant was initially written from imperfect recall and was COMPUTED and corrected before first commit (never asserted unverified).
- Coverage of new engine files (informational, TASK-010 llvm-cov pipeline): DaySeed 100%, EngineClock 100%, EngineEvent 100%, EngineState 100%, Reduce 100%, SHA256 100%, SeededGenerator 100% lines; package TOTAL 97.12% lines.

### VERIFY item resolution (05 Appendix B "Swift Clock/concurrency idioms") — RESOLVED
Recorded in full in the `EngineClock` header. `EngineClock` deliberately does NOT adopt the stdlib `Clock` protocol: its shipped instances (ContinuousClock/SuspendingClock) are monotonic and cannot see the manual wall-clock changes §4.3 folds, nor feed calendar dayKey derivation; `ContinuousClock.Instant` has no `Date` conversion (probe evidence below); the async `Clock` machinery is §4.2's in-session scheduling, which is app-layer (ADR-004: the engine never schedules). Production clock reads Foundation's wall clock (`Date.now`) — the one sanctioned ambient read in MomoCore, scanner-exempted per-pattern. Probe (recorded verbatim): `swift clockprobe.swift` with `let a = ContinuousClock.now; let b = Date(a)` → `error: no exact matches in call to initializer … (got 'ContinuousClock.Instant')` on this toolchain (swift-tools-version 6.2 host).

### Engine-purity scan — non-vacuity evidence (seeded violation, scratch run, reverted)
After the suite was green, a violation was seeded into `Reduce.swift` (`private let seededViolationProbe = Date()` + `private let seededUUIDProbe = UUID()`; backup taken first since the file is untracked), then `swift test --filter EnginePurityScanTests`:
```
✘ Test "MomoCore as it stands is engine-pure (non-empty source set)" recorded an issue at EnginePurityScanTests.swift:119:9: Expectation failed: (violations → [Violation(file: "Sources/MomoCore/Reduce.swift", literal: "Date("), Violation(file: "Sources/MomoCore/Reduce.swift", literal: "UUID(")]).isEmpty → false
↳ engine-purity violation: ["Sources/MomoCore/Reduce.swift: Date(", "Sources/MomoCore/Reduce.swift: UUID("]
✘ Test run with 8 tests in 1 suite failed after 0.013 seconds with 1 issue.
```
File restored from the /tmp backup (byte-diff verified) before this handoff — the violation is NOT in the tree. In-test non-vacuity layers: every banned literal is proven to match a canonical fixture; the exemption is proven live (file exists + still contains `Date.now` + same content elsewhere fails + randomness still banned in the exempted file).

### Verbatim final test output (clean tree, final state)
```
✔ Suite "SeededGenerator (SplitMix64-class)" passed after 0.060 seconds.
✔ Suite "EngineClock (protocol + production + manual)" passed after 0.060 seconds.
✔ Suite "Engine purity scan (no ambient time/calendar/randomness)" passed after 0.060 seconds.
✔ Suite "reduce — engine core bookkeeping (TASK-014)" passed after 0.060 seconds.
✔ Suite "DaySeed (SHA-256 → 64-bit day-stable seeds)" passed after 0.060 seconds.
✔ Suite "D-R1 import-whitelist scan" passed after 0.060 seconds.
✔ Suite "FR-12 banned-vocabulary scan" passed after 0.060 seconds.
✔ Suite "Token purity (R4: hex only in the palette files)" passed after 0.063 seconds.
✔ Suite "SHA-256 (FIPS 180-64 repo-owned)" … passed (full line: 0.367 seconds).
✔ Test run with 125 tests in 20 suites passed after 0.368 seconds.
```
Baseline recorded before any change: `Test run with 80 tests in 14 suites passed after 0.051 seconds` (exit 0). Delta: +45 tests / +6 suites. Standing scans all green (D-R1 whitelist, banned vocabulary, token purity, engine purity).

### Judgment calls flagged for the reviewer (most scrutiny-worthy first)
1. **TokenPurityTests.swift (existing TASK-011 test) was edited** — outside this task's "new files only" letter, within its spirit (§22 small-necessary-change): the R4 hex-literal scan flagged the FIPS K/H tables (72 literals) and SplitMix64 constants (3) as "hex color literals outside the palette files". Resolution: a documented `nonColorHexFiles` carve-out with per-file non-vacuity pins (each carved file must still contain hex; missing-from-tree fails), mirroring the scanner's existing palette mechanism. Decimal constants were rejected (destroys FIPS auditability). Alternative reading: reviewer may prefer relocating the engine algorithm files' hex into a form the original scanner tolerates — rejecting the carve-out would require that follow-up.
2. **`.evaluate` stamps BOTH `lastOpenedAt` and `lastEvaluatedAt` with the event's own instant — literal stamp, no monotonicity guard.** A backward `.evaluate(now:)` would move both stamps backwards in this skeleton. Deliberate: the fold machinery (TASK-015) owns time-segment decomposition and boundary monotonicity; faking a `max()` here would be undocumented dynamics. `changed` = full `EngineState` equality (honest by construction). The clock parameter and rng are deliberately UNREAD in this task — pinned by two probes (rng-draw conservation; clock-independence of outcomes).
3. **VERIFY resolution rejects stdlib `Clock` adoption** (rationale + compile-probe in EngineClock header and above). If the reviewer prefers an anchored ContinuousClock bridge, that is a small localized change — but §4.3's clock-change folding is the deciding requirement.
4. **Purity scan covers ALL of `Sources/MomoCore`**, not only the new engine files — stricter than Requirement 8's letter, enforcing the pre-existing D20/TASK-012 prose rule ("model code never touches `Date()`/`Calendar.current`") module-wide; one per-pattern exemption.
5. `Handshake` = exactly §4.7's "kind + UUID" (Equatable/Hashable); issuance/clearance/report-matching semantics untouched (TASK-015). `processedIntentsCapacity = 64` lives on `EngineState`, NOT Thresholds — it is a §4.1 shape bound, not a PRD number (Thresholds remains the PRD §3/§5 single source).
6. `ManualEngineClock` ships in MomoCore (not the test target) so MomoKit/Character test targets reuse it; value semantics; `advance(to:)` moves absolutely, including backwards (§4.3 clock-change cases).

### Constraints compliance
- New files in `Sources/MomoCore/` + `Tests/MomoCoreTests/` only — EXCEPT the flagged, minimal, necessary edit to `Tests/MomoCharacterTests/TokenPurityTests.swift` (judgment call 1). No Package.swift/pbxproj/docs edits. status.md untouched (orchestrator's).
- D-R1: new sources import Foundation only (SHA256/SeededGenerator import nothing at all); import-whitelist scan green. No CryptoKit anywhere.
- No `print(`, no TODO/FIXME/HACK debt (§26), no new dependencies (D-R6), no secrets (§27). Engine numbers: none introduced beyond §4.1's capacity bound (τ=3h, −1.5/h, effects etc. left to TASK-015+ as instructed).

## Handoff

### Completed
- All Requirements 1–9 and AC-1…AC-5 as specified; §4.1/§4.10 shapes per spec (immutable `let` deviation per TASK-012 precedent, Equatable additions documented); reduce is the single pure entry point with honest bookkeeping-only semantics and no fake dynamics.

### Files Changed
- New sources (7): `Sources/MomoCore/{SHA256,SeededGenerator,DaySeed,EngineState,EngineEvent,EngineClock,Reduce}.swift`
- New tests (7): `Tests/MomoCoreTests/{SHA256Tests,SeededGeneratorTests,DaySeedTests,EngineClockTests,EngineReduceTests,EnginePurityScanTests}.swift`, `Tests/MomoCoreTests/Support/EnginePurityScan.swift`
- Modified (1, flagged): `Tests/MomoCharacterTests/TokenPurityTests.swift` — documented non-color-hex carve-out + non-vacuity pins
- Task file: Status/Implementation Notes/Handoff (this)

### Tests Run
- `swift test` (baseline, before changes) → 80 tests / 14 suites passed
- `swift test` (final) → 125 tests / 20 suites passed
- `swift test --filter EnginePurityScanTests` (seeded-violation scratch run) → RED with attribution, then restored clean
- `swift test --enable-code-coverage` + `xcrun llvm-cov report .build/arm64-apple-macosx/debug/MomoPackageTests.xctest/Contents/MacOS/MomoPackageTests -instr-profile .build/debug/codecov/default.profdata`

### Test Results
- Final: **125 tests / 20 suites, all passed, exit 0**. Coverage informational: all 7 new engine files 100.00% lines; package TOTAL 97.12% lines (2364 lines). Standing scans green in-suite.

### Known Issues
- None blocking. SplitMix64 vectors are independent-computation-pinned (no fetchable published table this session) — provenance documented in Implementation Notes for reviewer verification.

### Decisions Made
- See "Judgment calls flagged for the reviewer" above (6 items, ranked).

### Reviewer Status
- Not yet reviewed — fresh reviewer to verify per Review Requirements (§4.1/§4.10 byte-level fidelity; purity claim via scan+grep+probe; NIST/SplitMix vectors assert for real; day-seed properties incl. epoch/salt separation; `changed` honesty; no dynamic scope creep; VERIFY resolution). Review file: `.claude/tasks/reviews/REVIEW-TASK-014.md` (orchestrator records).

### Commit
- None by agent (§9) — orchestrator commits after review. Suggested message: `feat(engine): TASK-014 engine core — reduce, clock, seeded randomness, day-stable seeds`

### Push
- After orchestrator commit, per Git Requirements.

### Recommended Next Step
- Fresh adversarial reviewer for this task; then TASK-015 (time-fold + wakefulness + handshakes) per delivery plan §3 — it consumes `Handshake`, `EngineClock`, `reduce`'s evaluate path, and the `processedIntents` ledger this task laid down.

## Reviewer Findings
Full record: `.claude/tasks/reviews/REVIEW-TASK-014.md`. **VERDICT: APPROVED_WITH_MINOR_NOTES** (2026-09-08, fresh adversarial reviewer, nothing trusted):

Independent re-derivations — all match: SHA-256 8/8 pinned vectors == OS `shasum -a 256` + 12/12 unseen random inputs repo==OS + K/H tables 64/64 + 8/8 re-derived from prime roots; SplitMix64 9/9 pinned outputs == a from-scratch Python implementation, and the disclosed seed-9 correction `0xAEAF52FEBE706064` confirmed genuinely correct; golden seed preimage 54 bytes hand-built in Python, byte-identical, seed `0xBAFE58EAC15B140B` triple-confirmed (RFC 4122 byte order, negative-epoch BE, framing injectivity verified); `swift test` 125/20 reproduced with delta +45/+6 hand-reconciled; coverage 7×100% / TOTAL 97.12% reproduced; seeded-violation RED output matched verbatim; stdlib-Clock compile probe reproduced live.

Findings: **MAJOR — none.** MINOR-1 — TokenPurityTests carve-out is file-granular (a color hex pasted into a carved file would be excused). MINOR-2 — EngineClock purity exemption is file+pattern but not occurrence-pinned (a second ambient `Date` inside EngineClock.swift would be excused). NITPICK-1 — `processedIntentsCapacity == 64` unpinned. NITPICK-2 — determinism fixture reuses `petID` as intent id. Verified-benign adjudications: TokenPurityTests edit accepted (§22, necessity reproduced at exactly 72+3 literals); no-monotonicity-guard deliberate+documented; stdlib-Clock rejection sound; module-wide scan scope stricter-than-letter; `ManualEngineClock` in MomoCore reasonable; `changed` honest by construction.

### Disposition (orchestrator, 2026-09-08)
| Finding | Disposition |
|---|---|
| MINOR-1 | **Fixed (narrowed)** — carve-out pins hardened from "≥1 hex present" to exact frozen counts (SHA256.swift == 72 = 64 K + 8 H; SeededGenerator.swift == 3): an added color hex changes the count and fails; a replaced constant fails the NIST/canonical vector pins. The reviewer's full exact-literal allowlist declined as redundant with those vector pins. |
| MINOR-2 | **Fixed** — `exemptionIsLive` now occurrence-pins: exactly one `Date` occurrence in comment-stripped EngineClock.swift (a second ambient read in that file now fails; a second `Date` anywhere else already failed). |
| NITPICK-1 | **Fixed** — new `processedIntentsCapacityPinned` test pins `EngineState.processedIntentsCapacity == 64` (§4.1 spec bound). |
| NITPICK-2 | **Fixed** — determinism fixture uses a fixed, distinct intent id (comment names the habit TASK-015 must not inherit). |

Post-fix verification: `swift test` → **126 tests / 20 suites passed** (125 + the new capacity pin; exit 0). All standing scans green in-suite.

## Completion Evidence
- Commit: **(this commit)** — `feat(engine): TASK-014 engine core — reduce, clock, seeded randomness, day-stable seeds` on `feature/EPIC-004-engine` (hash recorded in status.md at housekeeping); pushed to `origin` per Git Requirements.
- Review: REVIEW-TASK-014 APPROVED_WITH_MINOR_NOTES → disposition applied → `swift test` 126/20 green (verbatim output in Reviewer Findings above).
