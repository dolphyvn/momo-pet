# EPIC-003 — Pet Domain Model

## Objective
Define the MomoCore domain model exactly per 05 §3.1: `Sendable` value types (`Pet`, `PetState`, mood/energy bands, `BondStage`, `DayRecord`, `QuestProgress`, `InteractionIntent`, `SettingsState`) plus the interface types of 04 §9.2 (`CharacterDisplayState`, `CharacterMoment`, `ResponsePlan`, `CharacterReport`, `HandshakeKind`), with pure derivations (`makeMoodBand` / `makeEnergyBand` / `makeBondStage`, `dayKey`) whose single source of truth is the PRD §3 tables — and prove them with property tests.

## User / Product Value
The domain is the product's soul rendered as types: mood, energy, bond, and the day model become executable and provably faithful to the PRD before any dynamics or UI exist. Every later epic consumes these types; none may redefine them.

## Scope
- All 05 §3.1 value types with invariants INV-1…11 enforced at type boundaries (name invariant, monotonic bond, caps, dayKey-keyed counters).
- Interface types from 04 §9.2 / 05 §4.11 so EPIC-006 can build against fixed shapes (parallel-lane enabler).
- Pure band/stage derivations implementing PRD §3.1–3.3 cut-offs (20/45/75; stages 149/399/749) — no dynamics, no attractors, no time folds (EPIC-004).
- `dayKey` via injected calendar (D20, TZ-safe).
- Property tests over the full 0…100 ranges (FR-9 AC-1).

## Non-Goals
Engine behavior, time folding, interaction effects, quest logic, persistence encoding decisions, any UI. No Swift-window date APIs without injected clock.

## Dependencies
- EPIC-002 (TASK-009: the package exists).

## Tasks
Branch: `feature/EPIC-003-domain-model` (from `main`).

| TASK | Title | Size | Depends on |
|---|---|---|---|
| TASK-012 | Define MomoCore domain model (05 §3.1 + 04 §9.2 interface types) | S | TASK-009 |
| TASK-013 | Add domain-model property tests (FR-9 AC-1) | S | TASK-012 |

## Acceptance Criteria
1. Every 05 §3.1 type exists in `MomoCore`, `Sendable`, Foundation-only (import-whitelist scan stays green).
2. Band derivations match PRD §3 tables across the full range (property tests, not samples).
3. Stage thresholds exactly 149/399/749; bond type cannot express decrease (INV-3 at the type level).
4. `dayKey` derives from an injected calendar; no `Date()` / `Calendar.current` inside derivations (D20).
5. 04 §9.2 interface types fixed for downstream epics; INV-1…11 represented.

## Test Requirements
- project.md §32 Domain row (derivation half): band/stage property tests over 0…100 in `MomoCoreTests` (FR-9 AC-1).
- dayKey derivation tests across TZ boundaries.
- Name-invariant test (INV-1).

## Definition of Done
Both tasks DONE per CLAUDE.md §18; property tests green via `swift test`; reviews APPROVED; atomic TASK-ID commits on `feature/EPIC-003-domain-model`, pushed; epic merged to `main`; orchestrator status update.

## Status
TODO
