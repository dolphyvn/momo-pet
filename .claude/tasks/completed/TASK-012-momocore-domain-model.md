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
APPROVED_WITH_MINOR_NOTES (REVIEW-TASK-012, 2026-09-08: 0 MAJOR / 1 MINOR / 3 NITPICKS; all findings dispositioned — committing per §12)

## Implementation Notes

### Type layout (one file per §3.1 block; 04 §9.2 interface types in their own file — MomoCore placement per 05 §2.1/§4.11)
- `Sources/MomoCore/Instant.swift` — `typealias Instant = Date`: the spec's `Instant` realized as Foundation's absolute-time `Date` (timezone-free by construction — INV-9's representation). One place to change.
- `Sources/MomoCore/Thresholds.swift` — **the single source of PRD numbers** (`Thresholds.Scalar` 0/100; `Thresholds.Band` 20/45/75 shared by mood and energy — the two PRD tables use identical ranges; `Thresholds.Bond` minimum 0 / stages 150/400/750 / maximum 1000 / dailyCap 20; `Thresholds.Quest` 3-per-day + window hours 12/20/7).
- `Sources/MomoCore/Pet.swift` — `Pet` (+INV-1 failable init, stores the trimmed name).
- `Sources/MomoCore/PetState.swift` — `PetState` (+INV-2/INV-3 failable init + `isInMoodRange`/`isInEnergyRange`/`isInBondRange`), plus the state enums `Wakefulness`, `Activity`, `SatietyPhase`, and `typealias SatietyHint = SatietyPhase` (one type, both spec names: 05 §3.1 says `satietyPhase`, 04 §9.2 says `satietyHint` — optionality differs per usage site, not per type).
- `Sources/MomoCore/Bands.swift` — `MoodBand`, `EnergyBand`, `BondStage` + the three pure makers.
- `Sources/MomoCore/DayKey.swift` — `DayKey.make(from:calendar:)`: injected instant + injected calendar only; `"YYYY-MM-DD"` formatted from `calendar.dateComponents` (the calendar's `timeZone` decides the local day). DEBUG-loud `assertionFailure` + empty-string fallback on the unreachable missing-components path (house pattern from `MomoCopy.resolve`).
- `Sources/MomoCore/Quest.swift` — `QuestID` (String raw values `"Q1"`–`"Q7"` byte-matching PRD §5.2), `QuestFamily` (greet/feed/play/care/pet — the §5.2 Family column; the variety subset feed/play/care is a documented engine-side usage of PRD §3.3), `QuestWindow` (+pure `contains(hour:)` — windows are hour-aligned so the local hour is exact), `QuestCatalogEntry`, `QuestCatalog` (static table in PRD §5.2 order with the doc's Target column as inline comments), `QuestProgress` (+INV-6 failable init; target looked up from the catalog).
- `Sources/MomoCore/DayRecord.swift` — `DayRecord` (+INV-4/INV-5 failable init; also enforces questSet == exactly 3 (FR-14/15) and no duplicate quest IDs (PRD §5.3)).
- `Sources/MomoCore/InteractionIntent.swift` — `InteractionIntent` (+`Source` with doc-cased `.iPhone`/`.watch`, nested `Kind` incl. `pat(gesture:zone:)`), plus `PatGesture` (tap/doubleTap/longPress/stroke, 04 §6.1) and `TouchZone` (head/belly, 04 §2.3).
- `Sources/MomoCore/SettingsState.swift` — `SettingsState`.
- `Sources/MomoCore/CharacterInterface.swift` — the five 04 §9.2 types: `CharacterDisplayState`, `CharacterMoment` (+`GreetingKind`), `ResponsePlan`, `CharacterReport`, `HandshakeKind`; plus `ReactionID`/`HapticID` as String-backed key structs (see Decisions).
- Removed `Sources/MomoCore/MomoCorePlaceholder.swift` + `Tests/MomoCoreTests/MomoCorePlaceholderTests.swift` — the placeholder documented itself as replaced by real domain sources in EPIC-003 (this task); nothing referenced it outside its own test.

### Deliberate deviations from the sketch lines (all in the docs' own terms)
- **`let` everywhere, not the sketches' `var`:** AC-1/Requirement 3 demand immutable types; 05 §3.0 itself says "immutable-by-convention … the engine produces new state". The engine (EPIC-004) constructs new values per transition — no mutation API exists on any type.
- **Immutability strengthens the invariants:** every failable-init-enforced invariant makes invalid states unrepresentable (the task's "enforce at type boundaries wherever the type system allows").
- **Failing initializers** (failable `init?`) chosen over precondition/crash for input validation at construction; non-failing inits only where nothing can be invalid (InteractionIntent, SettingsState, key structs).
- **Conformances per the docs, plus test-necessitated `Equatable`** (REVIEW-TASK-012 MINOR-1 wording fix): `Sendable` exactly as 05 §3.1/04 §9.2 declare; `Equatable` additionally applied to the band/stage/state enums and `GreetingKind`/`HandshakeKind` (the sketches declare those `Sendable`-only, but the focused `#expect` tests need equality; synthesis is trivial for these enums). `InteractionIntent`/`CharacterReport` correctly keep `Sendable`-only. Nothing else added — no `Codable`, no `Hashable` on the doc-Hashless types. Adding `Codable` now would be speculative API ahead of ADR-002's store design; if EPIC-005 wants it, the conformance belongs in MomoCore (same module — avoids Swift 6 cross-module retroactive conformance). Flagged for the reviewer as a judgment call.
- **`ReactionID`/`HapticID` are String-backed key structs, not enums:** the docs never enumerate literal identifier strings (04 §4.3 gives prose names; §8.4 gives only examples and says the namespace is character/catalog-owned). Inventing enum rawValues would fabricate vocabulary; the key-type approach preserves INV-11 (keys, never prose) without freezing the character's catalog.

### Per-invariant disposition (AC-4)
| INV | Disposition |
|---|---|
| INV-1 | **Type-enforced**: `Pet.init?` trims and rejects empty; stores the trimmed value. Test: "INV-1: whitespace-only names are unrepresentable…". |
| INV-2 | **Type-enforced**: `PetState.init?` rejects mood/energy outside 0...100 (NaN rejected by comparison semantics). Tests: two INV-2 tests (mood, energy). |
| INV-3 | **Range type-enforced** (`PetState.init?` 0...1000, test "INV-3: bond outside 0...1000…"); **monotonic non-decrease is engine/store** (FR-10 AC-2): values are immutable so nothing can decrease in place; the across-mutation guarantee is pinned by EPIC-004/005 property tests — recorded here as the honest split. |
| INV-4 | **≥ 0 type-enforced** (`DayRecord.init?`); monotonic-within-a-day is engine (FR-6 AC-3). Test: "INV-4: negative day counters…". |
| INV-5 | **Stored total range type-enforced** (0...20 via `Thresholds.Bond.minimum...dailyCap`); clamp-at-award arithmetic is engine (§4.6). Test: "INV-5: the stored daily bond total…". |
| INV-6 | **Type-enforced**: `QuestProgress.init?` (progress ≥ 0, ≤ catalog target, completed ⇒ target met); `DayRecord.init?` (exactly 3 quests, no duplicates). Tests: three INV-6 tests. Completion-never-reverses is engine/store (FR-16/TR5) — noted in tests. |
| INV-7 | **Representation-enforced**: `helloAwarded` is a single Bool per DayRecord — "twice" is unrepresentable; one-record-per-dayKey is the store's uniqueness contract (EPIC-005); never-window-gated attribution is engine (§4.6). Test: "INV-7: the hello award is a single flag…" pins the value-level representation. |
| INV-8 | **Case set type-enforced** (closed 4-case enum, pinned by an exhaustive-switch test); the §4.7 legal-transition diagram is the engine's pure reduction — EPIC-004 pins it (05 §10.3). Test: "INV-8: the wakefulness state set…". |
| INV-9 | **Representation-enforced**: all timestamps are `Instant` (= Date, timezone-free); `dayKey`/`localDayKey` exist only as derived strings; `DayKey.make` is the single derivation path with injected calendar (no ambient clock — verified by import/AST: model code touches no `Date()`/`Calendar.current`). Tests: all of DayKeyTests + "INV-9: model stores UTC instants…". |
| INV-10 | **Key type-enforced** (non-optional UUID `id` on every intent, FR-18 AC-1); exactly-once application (UUID set + per-epoch watermark, §6.4) is EPIC-004/005. Test: "INV-10: every intent carries a non-optional UUID idempotency key" (same key = same logical event; different key = distinct event). |
| INV-11 | **Field-inventory-enforced**: `CharacterDisplayState` carries no String at all; `ResponsePlan`'s only strings are the optional `lineKey` key slot + `ReactionID`/`HapticID` key structs. Engine-composes-no-prose is EPIC-004's contract; the catalog side is the standing banned-vocabulary scan (TASK-010/011). Test: "INV-11: character-facing outputs are enums and key slots only". |

### Test evidence (verbatim commands + real outcomes)
- Baseline before changes: `$ swift test` → `✔ Test run with 35 tests in 9 suites passed after 0.011 seconds.`
- After implementation: `$ swift test` → `✔ Test run with 64 tests in 11 suites passed after 0.008 seconds.`
  - Delta: −1 test / −1 suite (removed placeholder), +30 tests / +3 suites (`Band/stage derivations + quest catalog (TASK-012)`, `DayKey derivation (D20)`, `Domain invariants INV-1…11 (TASK-012)`).
- Standing scans still green in-suite: D-R1 import-whitelist scan (non-vacuous, real tree) and banned-vocabulary scan both passed in the same run.
- Self-checks: `grep -rn "print(" Sources/MomoCore/ Tests/MomoCoreTests/` → none; all imports in `Sources/MomoCore/` → `import Foundation` only; every PRD threshold literal appears exactly once (in `Thresholds.swift`); no Package.swift/pbxproj change (git status confirms).

## §28 Handoff

### Completed
- All 05 §3.1 value types + all 04 §9.2 interface types in `Sources/MomoCore/` — `Sendable`, `let`-immutable, value semantics, Swift 6 strict-concurrency clean (`swift build` 6.2 tools, zero warnings emitted).
- Pure derivations `makeMoodBand`/`makeEnergyBand`/`makeBondStage` with PRD §3.1–3.2/§3.3 numbers single-sourced in `Thresholds.swift`.
- `DayKey.make(from:calendar:)` — injected calendar/instant only (D20); DST-safe, calendar-identifier-driven.
- INV-1…11 dispositioned: type-enforced where the type system allows (INV-1/2/4/5/6 fully; INV-3 range; INV-7/9/10/11 representation), engine/store remainder documented per-invariant and in test comments.
- Focused tests only (boundary representatives + named invariants + dayKey suite). Exhaustive sweeps NOT implemented (TASK-013, as instructed).
- Engine-adjacent logic deliberately NOT implemented (§22): satiety window constant + phase derivation, attractor/floor/ceiling, event reduction, quest generation/cascade, DisplayState/makeCharacterDisplayState (§4.11 read-models) — all EPIC-004. No follow-up tasks needed; all are already specced in 05 §4.

### Files Changed
- Added: `Sources/MomoCore/{Instant,Thresholds,Pet,PetState,Bands,DayKey,Quest,DayRecord,InteractionIntent,SettingsState,CharacterInterface}.swift`
- Added: `Tests/MomoCoreTests/{BandDerivationTests,DayKeyTests,DomainInvariantsTests}.swift`
- Deleted: `Sources/MomoCore/MomoCorePlaceholder.swift`, `Tests/MomoCoreTests/MomoCorePlaceholderTests.swift`
- Untouched: `Package.swift`, pbxproj, `docs/`, `status.md`, other task files, `decisions/`, `CLAUDE.md` (its pre-existing working-tree modification is the orchestrator's, not mine).

### Tests Run
- `$ swift test` (three times: baseline, post-implementation, post-`Thresholds.Bond.minimum` refinement).

### Test Results
- Baseline: 35 tests / 9 suites passed. Final: **64 tests / 11 suites passed** (all green; no failures, no skips). D-R1 + banned-vocabulary standing scans green in the same run.

### Known Issues
- None blocking. Two judgment calls flagged for the reviewer: (1) no `Codable` yet (deliberate; see Deviations) — EPIC-005 should add conformances in MomoCore when the ADR-002 store design lands; (2) `QuestCatalog.entry(for:)` force-unwraps a catalog lookup whose one-entry-per-ID invariant is test-pinned.

### Decisions Made
- `Instant` = `Date` via one typealias; `SatietyHint` = `SatietyPhase` via one typealias; `let`-everywhere per AC-1; doc-specified conformances only; quest catalog + windows included as 05 §3.1 static data (targets/window-hours single-sourced); `ReactionID`/`HapticID` as String-backed keys (namespace stays catalog-owned); `Source.iPhone` case keeps the doc's uppercase spelling.

### Reviewer Status
- Not yet reviewed — IN_REVIEW. Suggested scrutiny: type set vs 05 §3.1 completeness/exactness; interface types vs 04 §9.2 field-by-field; derivation constants vs PRD §3 tables byte-level; no duplicated threshold literals outside `Thresholds.swift`; D-R1 via the live scan; INV disposition honesty (especially INV-3/7/8/10/11 engine-store splits); the two judgment calls above.

### Commit
- none — agent does not commit (HEAD untouched at `8ae4970`)

### Push
- none — orchestrator commits and pushes after review

### Recommended Next Step
- Spawn the fresh adversarial reviewer (Jupiter) for `.claude/tasks/reviews/REVIEW-TASK-012.md`; after disposition, commit `feat(domain): TASK-012 define MomoCore domain model (05 §3.1)` and push, then dispatch TASK-013.

## Reviewer Findings
- **REVIEW-TASK-012 — APPROVED_WITH_MINOR_NOTES** (0 MAJOR / 1 MINOR / 3 NITPICKS; full record + orchestrator disposition table in `.claude/tasks/reviews/REVIEW-TASK-012.md`). All claims independently re-executed: swift test 64/11 reproduced; type set vs 05 §3.1 exact; five interface types byte-faithful; every PRD boundary verified (20/45/75; 149/150, 399/400, 749/750, 1000 — the `150/400/750` first-value form faithfully encodes the PRD's inclusive-range table); zero threshold literals outside `Thresholds.swift`; D-R1 11/11 files + non-vacuous in-suite scan; zero `var` in module; INV dispositions all honest and matching 05 §10.3's placement; DST test claim machine-probed; placeholder removal provenance verified; scope clean, HEAD unchanged. MINOR-1 (task-file conformance wording) fixed; NITPICK-3 (`QuestCatalogEntry` init doc note) fixed; NITPICK-1/2 declined as cosmetic. All five impl-flagged judgment calls adjudicated SOUND/faithful.

## Completion Evidence
- (this commit) — `feat(domain): TASK-012 define MomoCore domain model (05 §3.1)`, pushed to origin `feature/EPIC-003-domain-model`. Post-disposition `swift test` (orchestrator, after the two mechanical edits — Quest.swift doc comment, task-file wording): `✔ Test run with 64 tests in 11 suites passed` — D-R1 + banned-vocabulary standing scans green in the same run.
