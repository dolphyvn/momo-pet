# TASK-012 — Define MomoCore Domain Model

## Parent Epic
EPIC-003 — Pet Domain Model

## Objective
Define all MomoCore domain value types per 05 §3.1 plus the 04 §9.2 character interface types, with pure band/stage derivations whose numbers come from the PRD §3 tables (single source) and invariants INV-1…11 enforced at type boundaries — so the engine (EPIC-004), store (EPIC-005), and rig (EPIC-006) consume one provable model.

## Context
Delivery plan §3 (backlog of record) and 05 §3.1 are the type spec; 04 §9.2 defines the five character-facing interface types that must live in `MomoCore` so EPIC-006 (LANE B) can start against them. `MomoCore` is **Foundation-only** (D-R1, ADR-005) — enforced by the live import-whitelist scan from TASK-010. Pure derivations only: no engine dynamics (attractor/floor/ceiling, event reduction — EPIC-004), no persistence (EPIC-005), no timers/observers (ADR-004). Normative numbers already owner-confirmed: Bond 0–1000 monotonic; stages at 149/399/749; mood/energy band cut-offs 20/45/75.

## Requirements
1. Value types per 05 §3.1 — read it first and follow its names/shapes exactly: `Pet`, `PetState`, band types, `BondStage`, `DayRecord`, `QuestProgress`, `InteractionIntent`, `SettingsState`.
2. Interface types per 04 §9.2 — `CharacterDisplayState`, `CharacterMoment`, `ResponsePlan`, `CharacterReport`, `HandshakeKind` — as `Sendable` value types, placed where 05 §3.1 says they live.
3. All public types `Sendable`; immutable (`let` properties); value semantics; Swift 6 strict-concurrency clean.
4. Pure derivations `makeMoodBand` / `makeEnergyBand` / `makeBondStage` — inputs → band/stage with cut-offs from PRD §3.1–3.2 (20/45/75 bands; 149/399/749 stages). No hidden state, no clock, no RNG.
5. `dayKey` derivation via an injected calendar/`Date` (D20) — deterministic and testable; no ambient `Date()` / `Calendar.current` inside model code.
6. Invariants INV-1…11 (05 §4): enforce at type boundaries wherever the type system allows (failing initializers/factories, non-representable invalid states); the rest are pinned by the focused unit tests. Document per-invariant where it is enforced (code comment or notes).
7. Focused unit tests in-task: name invariant (a representative invalid construction is impossible or throws) and `dayKey` derivation (injected calendar, known instants → expected keys, incl. day-boundary and timezone-dependence via the injected calendar).

## Files / Areas Likely Affected
- `Sources/MomoCore/` (new type files; layout per 05 §3.1 grouping or one-file-per-type — implementer's choice, documented)
- `Tests/MomoCoreTests/` (focused unit tests)
- No `Package.swift` change expected (target pre-declared); **no pbxproj change expected** (app targets consume the package whole)

## Dependencies
- TASK-009 (package exists, TASK-010/011 conventions in place). TASK-013 (exhaustive property sweeps) is deliberately OUT of this task's scope — focused unit tests only.

## Constraints
- Jupiter model, fresh agent, no commit by agent.
- **D-R1: `MomoCore` imports Foundation only** — the import-whitelist scan fails the suite otherwise.
- No `print(`; no secrets; no new external dependencies (D-R6); no numeric literals duplicated from the PRD — each cut-off/threshold defined once (single source), referenced everywhere else.
- Scope control (§22): engine-adjacent logic discovered along the way → record as follow-up, do not implement.

## Acceptance Criteria
- AC-1: All 05 §3.1 value types + 04 §9.2 interface types exist, `Sendable`, immutable, with the doc-specified names.
- AC-2: `makeMoodBand` / `makeEnergyBand` / `makeBondStage` match PRD §3.1–3.2 tables; thresholds defined exactly once.
- AC-3: `dayKey` derives via injected calendar; no ambient clock in the module.
- AC-4: INV-1…11 each either type-enforced or test-pinned, with a per-invariant disposition note.
- AC-5: Focused unit tests green (`swift test`); existing 35-test baseline still green.

## Required Tests
- Focused unit tests: name invariant; `dayKey` derivation (known instants, day boundary, injected-timezone variation).
- Full `swift test` run green; record test count delta in Implementation Notes.

## Review Requirements
- Fresh reviewer verifies: type set vs 05 §3.1 complete and exact; interface types vs 04 §9.2; derivation numbers vs PRD §3 tables (byte-level); single-source threshold rule (no duplicated literals); D-R1 holds; INV-1…11 disposition honest; Sendable/immutable claim real (not just declared). Record in `.claude/tasks/reviews/REVIEW-TASK-012.md`.

## Git Requirements
- Branch: `feature/EPIC-003-domain-model`
- Commit: `feat(domain): TASK-012 define MomoCore domain model (05 §3.1)`
- Push to origin after orchestrator commit; record hash in Completion Evidence.

## Status
READY (task file materialized 2026-09-08; dispatch imminent)

## Implementation Notes
- (agent fills in)

## Reviewer Findings
- (orchestrator records)

## Completion Evidence
- (commit hash + push, by orchestrator)
