# TASK-011 — Design-System Token Pass + String Catalog Scaffolding

## Parent Epic
EPIC-002 — Foundation & Build Baseline

## Objective
Execute the single design-system palette pass from 04 Appendix B item 3: assign all UI tokens (project.md §18) and all 8 character color slots (04 §8.4) in one coherent light/dark system as Swift constants, and scaffold the String Catalogs with the `momo.line.*` copy namespaces — so that no downstream task ever hardcodes a color, a font, or a string.

## Context
04 §8.4 requires the rig to consume named token slots (R4: zero hex in the character pipeline), and project.md §18 defines the calm premium visual language. Doing UI + character palettes in ONE pass (04 Appendix B, "EPIC-002 design-system pass") prevents drift between Momo's body colors and the app chrome. Copy classes (`momo.line.<slot>.<nn>`, `momo.line.react.<family>.<nn>`, `momo.line.moment.<nn>`) are fixed by 04 §10.1; pools are filled by engine/read-model tasks later — here only the catalog structure and lookup exist. The banned-vocabulary scan (TASK-010) consumes these catalogs.

## Requirements
1. Token module (Swift constants living in `MomoCharacter`, which both apps already import):
   - All 8 character slots per 04 §8.4 **exactly as named there** (fur base/shade through sparkle family) — light and dark variants.
   - UI tokens per project.md §18: semantic background/surface/text colors (light+dark), typography styles, spacing scale, corner radii.
   - Single source of truth: hex values allowed ONLY inside the token file; everything downstream resolves tokens (R4).
2. Light/dark correctness: both variants defined for every token; dark values chosen deliberately (not inverted) per the calm-premium intent.
3. Contrast baseline: chosen text/surface pairs recorded with their computed contrast ratios in Implementation Notes (full audit is TASK-047; here we record intent — target ≥ 4.5:1 for body text).
4. String Catalog scaffolding:
   - Catalog file(s) exposing the three copy namespaces with type-safe lookup helpers (a `CopyKey` enum or function resolving `momo.line.*` keys; missing keys fail loudly in DEBUG per String Catalog defaults).
   - Seed a minimal placeholder set ONLY as required to prove lookup (marked clearly, replaced by real tone-guide pools in engine tasks — note which keys are placeholders).
   - Catalogs must parse and be scannable by the TASK-010 banned-vocabulary test.
5. Both app targets compile against the tokens; one placeholder surface per app visibly consumes a token (proves the plumbing).

## Files / Areas Likely Affected
- `Sources/MomoCharacter/DesignTokens.swift` (or the layout TASK-009 recorded)
- String Catalog files (app-level, shared with Watch)
- Lookup helpers in the package; placeholder-consumption touches in `Momo`/`MomoWatch` placeholder shells

## Dependencies
- TASK-009 (targets exist). Should land after/beside TASK-010 so the scans can consume the catalogs.

## Constraints
- Jupiter model, fresh agent, no commit by agent.
- Tone guide rules apply even to placeholder copy (banned list forbidden everywhere; placeholders kept neutral and few).
- Do not design new art or invent a second palette style — this is the single canonical pass (04 Appendix B item 3).
- No copy-writing of real lines (engine/read-model tasks own pools; FR-12 binds them).

## Acceptance Criteria
- AC-1: All 8 character slots + project.md §18 UI tokens exist with light/dark variants, exactly named per 04 §8.4 / §18.
- AC-2: Hex literals exist only in the token file (grep-verifiable); both placeholder shells render via tokens.
- AC-3: String Catalogs exist with the three `momo.line.*` namespaces; type-safe lookup resolves keys; placeholder keys are marked.
- AC-4: TASK-010's banned-vocabulary scan runs green against these catalogs.
- AC-5: Contrast baselines recorded; build green on both simulators.

## Required Tests
- Build verification both simulators; catalog lookup unit test (key resolves, missing key surfaces); token-file purity check (simple test asserting no hex outside the token source — or documented grep evidence). Evidence in Implementation Notes.

## Review Requirements
- Fresh reviewer verifies: slot names vs 04 §8.4 verbatim; single-palette-pass coherence (calm, not garish; dark mode deliberate); no real copy written; lookup API shape sane for engine key emission (05 §4.11 INV-11). Record in `.claude/tasks/reviews/REVIEW-TASK-011.md`.

## Git Requirements
- Branch: `feature/EPIC-002-foundation`
- Commit: `feat(design): TASK-011 design-system token pass and String Catalog scaffolding`
- Push to origin after orchestrator commit; record hash in Completion Evidence.

## Status
TODO (blocked by TASK-009; coordinate with TASK-010 for scan-consumption ordering)

## Implementation Notes
- (agent fills in)

## Reviewer Findings
- (orchestrator records)

## Completion Evidence
- (commit hash + push, by orchestrator)
