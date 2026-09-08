# EPIC-003 — Pet Domain Model

## Objective
Define the MomoCore domain as pure, `Sendable` value types with invariant-enforcing boundaries and pure band/stage derivations (05 §3.1), so every later epic (engine, persistence, character, UI) consumes one provable model. The PRD §3 tables are the single numeric source of truth.

## User / Product Value
No end-user value yet by design. This epic makes the domain *executable and provably matching the PRD tables before any dynamics exist* — the "domain before UI" precondition (delivery plan §4.1 rule 3) and the foundation the engine (EPIC-004), store (EPIC-005), and character interface (EPIC-006) all consume.

## Scope
- All 05 §3.1 value types: `Pet`, `PetState`, band types, `BondStage`, `DayRecord`, `QuestProgress`, `InteractionIntent`, `SettingsState`.
- Interface types from 04 §9.2 (`CharacterDisplayState`, `CharacterMoment`, `ResponsePlan`, `CharacterReport`, `HandshakeKind`) as `Sendable` value types in `MomoCore` (05 §3.1 placement; consumed by `MomoCharacter` in EPIC-006).
- Pure derivations `makeMoodBand` / `makeEnergyBand` / `makeBondStage` — PRD §3 tables as the single source.
- `dayKey` derivation via an injected calendar (D20 — no ambient `Date()`/`Calendar.current` inside the model).
- Invariants INV-1…11 enforced at type boundaries (where type-system enforcement is possible; the rest pinned by tests).
- Exhaustive property tests (TASK-013) sweeping the full value ranges against PRD §3.1–3.2.

## Non-Goals
No engine dynamics (`reduce`, attractor/floor/ceiling logic — EPIC-004); no persistence or sync (EPIC-005); no UI or rig code; no timer/observer machinery (ADR-004 bans them); no Phase-2 seams.

## Dependencies
- EPIC-002 complete (package exists; `MomoCore` target is Foundation-only per D-R1, enforced by the live import-whitelist scan).

## Tasks
Branch: `feature/EPIC-003-domain-model` (from `main`).

| TASK | Title | Size | Depends on |
|---|---|---|---|
| TASK-012 | Define MomoCore domain model (05 §3.1) | S | TASK-009 |
| TASK-013 | Domain-model property tests (FR-9 AC-1) | S | TASK-012 |

## Acceptance Criteria
1. All 05 §3.1 value types + 04 §9.2 interface types exist as `Sendable` value types in `MomoCore`.
2. Pure derivations match PRD §3 tables exactly (band cut-offs 20/45/75; bond stages 149/399/749).
3. `dayKey` derives via an injected calendar — deterministic, no ambient clock.
4. Invariants INV-1…11 enforced at type boundaries or pinned by tests.
5. Exhaustive property tests (0…100 bands, 0…1000 bond) green headlessly; no numeric leakage types exist (FR-9 core rule + FR-9 AC-4 domain half; citation corrected per REVIEW-TASK-013 NITPICK-1 — AC-1 itself is the band-matching property).

## Test Requirements
- Focused unit tests in-task (TASK-012: name invariant, `dayKey` derivation).
- Exhaustive full-range property tests (TASK-013, `MomoCoreTests`).
- `swift test` green throughout; coverage recorded informationally (floors enforced from TASK-020/024).

## Definition of Done
Both tasks DONE per CLAUDE.md §18 (implemented → independently reviewed → findings addressed → atomic TASK-ID commits on `feature/EPIC-003-domain-model` → pushed). Domain demonstrable headlessly: `swift test` proves the model against the PRD tables. Epic branch merged to `main` (direct merge per CLAUDE.md §14 owner rule). `.claude/tasks/status.md` updated.

## Status
IN_PROGRESS (1/2) — TASK-012 DONE (`bc95cb9`, REVIEW-TASK-012 APPROVED_WITH_MINOR_NOTES 0/1/3, disposition applied; swift test 64/11 green). TASK-013 next (task file READY in `.claude/tasks/active/`).
