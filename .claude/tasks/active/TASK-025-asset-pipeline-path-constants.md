# TASK-025 — Asset export pipeline + generated Path constants (04 §8.2, §8.5; ADR-007; delivery-plan TASK-025)

## Parent Epic
EPIC-006 — Character Rendering (MomoCharacter), task 1 of 6 (size M) — LANE B opens here. Follows the delivery-plan TASK-025 row; carries risk R6's mitigation ("keeps the pipeline repo-local + committed output — reviewable, re-runnable; budget ≤ 1.5 MB enforced").

## Objective
Stand up the repo-local export pipeline (ADR-007's ratified runtime decision) and produce the committed, reviewable Swift `Path` constants for the Direction-C rig and its variants — the geometry substrate every later EPIC-006 task consumes:
1. **The pipeline:** a repo-local, re-runnable script (tooling choice VERIFY-AT-BUILD — record the choice + on-host verification in the task file, never assume) that generates Swift `Path`-constant source from a geometry source-of-truth held in this repo. Output is COMMITTED and reviewable: re-running the pipeline must reproduce the committed output (byte-identical, or a documented-and-pinned deterministic ordering — a diff-varying generator is a defect, R6).
2. **The geometry, Direction C (ADR-001 + 04 §2.1/§2.2):** the full rig's ~17 parts on the 1000×1000 normalized grid (§2.1 landmarks: ground y=1000; body center ≈ (500, 640) r≈300; head ≈ (500, 400); eye centers ≈ (430, 390)/(570, 390) r≈52; ear roots ≈ (440, 250)/(560, 250); tail anchor ≈ (720, 800)); honoring the ADR-001 hard rules — pear body, round cheeks, puff tail, hind feet visible at rest, **ear ≥ 12 % of body width at base with rounded tips**, per-ear rotation channels as separate parts, **no bounce-loops anywhere**.
3. **The variants (§8.5):** full rig (iPhone, all §2.2 parts); LOD-glance variant (Watch foreground — no pupil-tracking split, simplified paws); glyph variant (complication/AOD — silhouette-preserving, ears merged into the head outline per ADR-001's below-~32 pt rule).
4. **Room scene + props (§8.5):** one static charming room (FR-3, K4; may include the pom as static decor) + props food, blanket, 2 sparkles (sparkles are moment-scoped by consumers later).
5. **Budgets measured (§8.3):** rig ≤ 300 KB source contribution; room + props ≤ 250 KB; total art ≤ 1.5 MB (target ~0.5 MB). Measure and record actuals — never assert.

**Authoring posture (agent-era reality, disclosed in the task file):** 04 §8.2's "authored in a vector tool, exported" step has no human designer in this loop — the implementation authors the geometry as parametric definitions INSIDE the repo-local generator (the agent-era equivalent of the vector-tool step), anchored to the §2.1 landmarks and ADR-001's rules. This is exactly what keeps the pipeline's promise: a future human vector-tool pass replaces the parametric source WITHOUT touching any consumer of the generated constants. Geometry quality bar: calm, rounded, premium (§1.3's proportions; the philosophy guardrail) — verified visually by rendering debug canvases in this task's evidence, and refined by later EPIC-006 tasks against real surfaces.

## Context
- **Codebase state:** `main` @ EPIC-005 merge lineage (`fdb5cb5`); baseline `swift test` = **515 tests / 54 suites green**. `Sources/MomoCharacter/` currently holds the TASK-011 token/copy layer ONLY: `MomoCharacterPalette.swift`, `MomoColorToken.swift`, `MomoUIColors.swift`, `MomoTypography.swift`, `MomoMetrics.swift`, `MomoCopy.swift`, `MomoCharacterPlaceholder.swift`. The token slots this task's consumers will use already exist (§8.4 slots assigned by the EPIC-002 palette pass) — geometry constants are COLOR-LESS (R4): the rig carries shapes; tokens are applied at render time (TASK-026+).
- **Naming (§8.4, binding):** rig parts `MomoRig.<part>` (e.g. `MomoRig.earLeft`, `MomoRig.eyeLeftPupil`); files `MomoRig+<Group>.swift` per the §2.2 layer groups (Body, Head, Ears, Tail, Eyes, FaceDetails, FrontPaws) + room/props namespace (`momo.room.base`, `momo.room.pom` for bundled data names — constants may group under `MomoRoom`/`MomoProps` as long as §8.4's namespace discipline holds); every generated file carries a "GENERATED — do not edit; re-run the pipeline" header with the generating command.
- **Precedent for "module becomes real":** EPIC-003 removed MomoCore's placeholder when real sources landed. If the generated rig sources make the placeholder redundant and nothing references it, remove it in this task (disclose; keep the module compiling and tests meaningful).
- **Tooling constraint:** zero runtime dependencies (ADR-007; D-R1 posture) — the pipeline is a BUILD-TIME/repo tool, never a package dependency. Whatever script language is chosen must run on this macOS host (verified by actually running it — §25: no unverified-tool claims) and produce deterministic output. SwiftUI `Path` compiles in this package's macOS test host (the TASK-011 token tests already build in `MomoCharacterTests`).
- **What TASK-025 does NOT build (scope control §22):** no layer tree, no clock, no animation, no sequencer, no reactions, no View that renders the rig beyond debug-canvas evidence (TASK-026+); no color application (R4 — shapes only); no Watch surfaces (variants are DATA here); no catalog/copy changes.

## Requirements
1. Pipeline lives in the repo (e.g. `Tools/character-pipeline/` — name it well), documented (README or header: how to run, what it generates, the VERIFY-AT-BUILD tooling record), re-runnable, deterministic.
2. Generated constants compile in `Sources/MomoCharacter/` under the §8.4 naming; a generated-code header convention on every generated file; hand-written wrappers (if any) stay clearly separated from generated output.
3. Geometry pins in `MomoCharacterTests` (headless, deterministic — SwiftUI `Path` geometry is queryable): §2.1 landmark anchors within tolerance; the ADR-001 ear rule measurable and pinned (ear base width ≥ 12 % of body width at base, from the actual exported numbers); part-count + part-name pins against the §2.2 enumeration (compile-pinned case/name sets where enums are natural); glyph variant pins (ears merged: no separate ear paths in the glyph set; pear silhouette landmarks retained); LOD-glance pins (no pupil split, simplified paws); all geometry on the normalized grid (pins reject absolute-pixel leakage).
4. Reproducibility pin: a test (or scripted check recorded as evidence) that re-runs the pipeline and asserts the committed output is reproduced byte-identically (or fails loudly) — R6's executable form.
5. Budgets: measure generated-source bytes per §8.3 bucket; record actuals in the task file; the ≤ 1.5 MB total and the 300 KB / 250 KB sub-budgets hold.
6. Visual evidence: render the full rig + glyph variant to debug-canvas screenshots (simulator or canvas harness) committed under a docs/evidence path or recorded in the task file — the review must be able to see the rabbit, not just its numbers. (A calm, rounded, Direction-C rabbit — the reviewer judges against §1.3/ADR-001.)
7. Suite hygiene: final `swift test` green ×2, zero new warnings; standing scans stay green with no new exemptions (the TASK-011 hex-confinement discipline extends naturally: generated geometry files contain NO hex — pin it).

## Files / Areas Likely Affected
- NEW `Tools/character-pipeline/` (script + geometry source + README).
- NEW generated `Sources/MomoCharacter/MomoRig+*.swift` (+ room/props constants).
- POSSIBLY removed: `MomoCharacterPlaceholder.swift` (+ its test) per the module-real precedent.
- NEW tests in `Tests/MomoCharacterTests/` (geometry pins, reproducibility, budget-measurement helper if testable).
- This task file. NOT affected: MomoCore, MomoKit, apps, catalogs, token files (read-only consumers).

## Dependencies
- TASK-009 (package targets), TASK-011 (tokens/copy layer — the palette slots exist).
- EPIC-003 interface types exist (TASK-012) though this task may not consume them yet.

## Constraints
- Fresh agent, Jupiter, no commit rights; house file discipline (200–400 lines typical, 800 max — split generated output by group); zero new runtime dependencies; §25 honesty on every tooling claim; the pipeline + geometry source must make the ART reviewable as diffs (R6's whole point).

## Acceptance Criteria
1. Pipeline runs reproducibly on this host; re-run reproduces the committed output (pinned).
2. Generated constants compile; §8.4 naming + generated-headers hold; no hex in any generated file.
3. Direction-C geometry honors ADR-001 (ear rule pinned numerically; glyph merges ears; no bounce-loop shapes) on the §2.1 grid with landmarks pinned within tolerance.
4. All three rig variants + room + 4 props exist per §8.5; variant-distinguishing pins green.
5. Budgets measured and recorded; all §8.3 numbers hold.
6. Visual evidence committed/recorded; `swift test` green ×2 with the new pins; scans green, no new exemptions.

## Required Tests
- The geometry/variant/naming/reproducibility pins above (new `MomoCharacterTests` files, house conventions).
- The budget measurement (evidence, recorded — like TASK-024's coverage recipe).

## Review Requirements
- Independent fresh reviewer (CLAUDE.md §10/§33), adversarial, unprimed:
  - Re-derive the part inventory from 04 §2.2 + ADR-001 BEFORE comparing to the generated constants (names, counts, per-part channels' implication for geometry: separate ear parts, 6-part eye group, mouth as 3 pose shapes, 2 cheek accents).
  - Recompute the ADR-001 ear-thickness rule from the exported numbers themselves; try to find a violated hard rule (ear rule, glyph merge, no-bounce, normalized-grid leakage, hex presence).
  - Re-run the pipeline (or its pinned reproducibility check) and diff against the committed output.
  - Verify budgets by measurement, not by reading the claim.
  - Judge the visual evidence against §1.3/ADR-001 (calm/rounded/premium; pear silhouette; a rabbit, not a generic mascot).
  - ONE mutation-bite on a geometry pin (e.g. shift a landmark or break the ear ratio in the geometry source, regenerate, watch a named pin fail) with sha256-proven restore.
  - Review file: `.claude/tasks/reviews/REVIEW-TASK-025.md`.

## Git Requirements
- No commit by the implementation agent. Orchestrator commits after review disposition: `feat(character): TASK-025 asset pipeline + generated rig Path constants` — atomic, TASK-ID included.

## Status
READY — contract materialized by the orchestration agent from 04 §2.1–2.2/§8.1–8.5, ADR-001, ADR-007, the delivery-plan TASK-025 row (docs/product/06-delivery-plan.md:99) and risk R6, and the TASK-011 token-layer state. Baseline pinned at dispatch: `swift test` = 515/54 @ `fdb5cb5` (main; EPIC-005 merged `cd22acd`).

## Implementation Notes
(implementation agent fills)

## Reviewer Findings
(reviewer fills)

## Completion Evidence
(orchestrator fills at housekeeping)
