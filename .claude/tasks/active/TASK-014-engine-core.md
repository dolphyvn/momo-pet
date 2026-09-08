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
READY (first EPIC-004 task; branch cut from `main` @ `bf2dcb7`)

## Implementation Notes
- (agent fills in)

## Reviewer Findings
- (orchestrator records)

## Completion Evidence
- (commit hash + push, by orchestrator)
