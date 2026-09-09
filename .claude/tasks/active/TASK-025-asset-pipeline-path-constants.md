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
APPROVED — fix round 1 delta APPROVED_WITH_MINOR_NOTES (n2 prose applied; orchestrator disposition below). Proceeding to the atomic commit per §12.

## Implementation Notes

### Implementation agent notes — 2026-09-09 (TASK-025 execution)

**Pipeline** (`Tools/character-pipeline/`, Python stdlib-only, zero runtime deps per ADR-007):
- `geometry.py` — grid constants, §2.1 landmarks, path builders (rotated ellipses via the KAPPA circle approximation, pear body, crescents, rounded rects, sparkles), measurement helpers.
- `parts.py` — THE geometry source of truth: part tables (full rig 21 constants, LOD-glance 11, glyph 3, room 5, props 4 = 44). Shared parameter dicts single-source belly/foot/paw/tail/lid numbers.
- `verify_geometry.py` — pipeline-side contract checks (§2.1 landmarks, ADR-001 ear rule + rounded tips, R2 continuity, hind-foot ground contact, glyph merge, LOD reductions, grid-only). SAME tolerances the Swift pins use — deliberate double entry: Python measures the parametric source, Swift re-measures the committed constants.
- `emit_swift.py` — Swift emitter: GENERATED headers with the regenerate command, `MomoRig.<part>` / `MomoRoom` / `MomoProps` naming (§8.4), per-part doc comments carrying the §2.2 channel descriptions, `public static let <part>: Path`.
- `render_svg.py` — 4 diffable SVG evidence canvases from the same part tables.
- `generate.py` — CLI (`--out-dir/--evidence-dir/--check/--verify-geometry/--report`); ALWAYS runs the geometry contract checks first and exits 1 on any violation before writing anything.
- `render_evidence.swift` — macOS host tool that COMPILES TOGETHER WITH the generated sources and rasterizes the committed `Path` constants to PNG via CoreGraphics/ImageIO — evidence of the shipped bytes, not just the source.

**Part accounting (reviewer re-derivation should land here):** §2.2 counts 17 parts (mouth once as a 3-pose slot: body+belly 2, head 1, ears 2, tail 1, eyes 6, mouth 1, cheeks 2, paws 2). ADR-001's Direction-C delta adds the 2 hind feet → **19 counted parts**. The full rig emits **21 Path constants** because the mouth slot ships its 3 pre-built poses. Plus LOD-glance 11, glyph 3, room 5, props 4 → **44 constants total**.

**Key decisions:**
- VERIFY-AT-BUILD record (§25-honest, verified on THIS host): python3 → 3.12.13 (homebrew PATH) AND `/usr/bin/python3` → 3.9.6 (CLT) both run the pipeline (`--check` green under both); swiftc 6.3.3 compiles the generated sources standalone (the `render_evidence.swift` build doubles as that check); baseline reproduced before changes: `swift test` = 515 tests / 54 suites passed @ `fdb5cb5`. Full record in `Tools/character-pipeline/README.md`.
- Glyph "ears merged" is a compound Path of 6 overlapping subpaths (head, body, ear ×2, hind foot ×2) filling as one union under the nonzero rule — ears baked into the silhouette, no separate ear channel. Pipeline + Swift pins prove the ear bumps remain visible above the head and ground contact is retained.
- Generated constants are `public` (app-target consumers in TASK-026+; matches the token-layer precedent).
- The ADR-001 ear-thickness rule measures the **at-base width** — the chord across the ear at the ear-root landmark line y=250 — as **12.12%** of body width (64.93 / 535.63) against the ≥ 12% floor (margin ~0.12pp). The 120.5-unit bounding-box width is the tilted shaft's mid-shaft maximum (EAR_TILT_DEG = 10), not the base; it serves only as the reference width for the rounded-tips profile check. (CORRECTED in fix round 1 per REVIEW-TASK-025 M1 — this note originally claimed 22.5% from the bbox width.) Ear tips rounded (width at 10% from tip ≥ 50% of max width, at 6% ≥ 30% — both pinned).
- Tail sized ~10% of body height reading of "puff tail" (§2.1 anchor honored); rendered evidence judged: puff clearly visible peeking past the body's right edge.
- Placeholder removed per the module-real precedent: `MomoCharacterPlaceholder.swift` + `MomoCharacterPlaceholderTests.swift` deleted; grep confirmed nothing else referenced them. The D-R2 SwiftUI-edge proof they carried transfers to the generated rig files (44 real `Path` constants now compile in this module).
- Visual QA loop actually executed: first render exposed sleepy/heavy-lidded eyes (lid covered the whole eye), paws hovering ambiguously between belly and feet, and an under-read tail crescent. Fixed in `parts.py` (lid rests above the pupil line, paws rest ON the belly front clear of the feet, tail enlarged/exposed), regenerated, re-rendered, re-judged — final renders read calm/rounded/premium.

**Evidence:** `docs/evidence/character/` — 4 SVGs (byte-pinned by tests) + 3 PNGs (`rig-full`, `rig-glyph`, `room-scene`; rasterized from the committed constants by `render_evidence.swift`; byte-deterministic on the verified host — two consecutive runs compared identical — but not test-pinned because the raster encoder is a host facility, not part of the contract). The reviewer can SEE the rabbit in `rig-full.png`.

**Budget actuals (measured, `generate.py --report`):** rig 50,096 B / 307,200 B limit; room+props 20,647 B / 256,000 B; total 70,743 B / 1,572,864 B (1.5 MB on the same 1024-byte KB basis as the sub-budgets — pinned in `MomoArtBudgetTests` at the §8.3 numbers, and the pipeline's own gate matches). Evidence SVGs 26,325 B (26,365 B after fix round 1's sparkle nudge — see below; not shipped code).

**Test/before-after (exact):** before = 515 tests / 54 suites (baseline @ `fdb5cb5`, reproduced on this host before changes). after = **547 tests / 59 suites passed** — first full run after adding the suites had 1 failure (`namespaceAnchors` check was too blunt: MomoRig.swift's doc comment legitimately *mentions* the GENERATED-header law in prose; re-pinned on the machinery — HAND-WRITTEN marker + absence of the regenerate command — and then green). Green ×2 consecutively after that fix. Zero new compiler warnings (the only warning on this host is a pre-existing `ld: search path '/opt/extra/lib' not found` emitted for every link from the host environment — present in tool-only invocations made before any package build, not introduced by this task).

**Standing scans:** TokenPurityTests green (generated files contain zero hex — additionally pinned inside the new `MomoGeneratedDisciplineTests` with its own hex regex + non-vacuity so the generated layer is policed even if the global allowlists change). No new exemptions anywhere.

### Fix round 1 (§11 fix loop) — 2026-09-09 (fresh fix agent)

Addresses REVIEW-TASK-025: M1, M2, m1, n1, and the O5 sparkle nudge. No geometry re-authoring, no scope expansion, no new dependencies; Python stdlib-only preserved; §8.4 naming and GENERATED-header mechanism untouched; reproducibility + discipline pins green after regeneration.

**M1 — ear rule now measures the at-base width (both checkers).** The ear-thickness gate in `verify_geometry.py` and `MomoRigGeometryTests.earRule` both measure the chord across the ear AT the ear-root landmark line y=250 via the existing helpers (`width_at_y` / `PathMeasuring.widthAtY`) instead of the bounding-box width. True at-base = 64.93 units = 12.12% of body width 535.63 (both ears) — compliant with the ≥ 12% floor, margin ~0.12pp. Failure messages report the at-base numbers and the root line. The bbox width is kept ONLY as the reference for `earRoundedTips` (a tip-shape profile, correctly relative to the shaft's max width — re-labeled "max width" with a comment pointing at `earRule` for the base rule). The stale `parts.py` ear-width comment (magic "116") now states the measurement basis instead.

**M2 — winding uniformity for all non-hole compounds + overlap-seam pins.** `geometry.py` gains `reversed_subpath()` (explicit `move(to:)` at the true start, segments reversed — cubic controls swap, quad control preserved — single trailing `closeSubpath`). `glyph_parts` reverses the two ears and two hind feet to match the head/body sweep; `prop_parts` food reverses the mound (plus the two disjoint kibbles, for table uniformity). The `window`'s intentional counter-wound opening is untouched (`HOLE_COMPOUNDS = ("window",)`). Regenerated output committed. New seam pins — points computed from the committed geometry, strictly inside BOTH overlapping subpaths of each seam (pairwise-verified inside at flatten steps 16/48/96/192/512):
- glyphSilhouette: (455, 245) left ear∩head lens, (545, 245) right ear∩head lens, (396, 927.65) left foot∩body band, (604, 927.65) right foot∩body band. Measured clearances: ear lenses ≥ 13.4 units to the nearest (ear) outline — head-arc distances 16.20 (left) / 13.40 (right), per the delta review's 512-step measurement (n2; the fix-round note's "≥ 16.0" understated the nearest outline); the foot bands are a genuine ~1.5-unit-tall overlap sliver at that x (pin margins ±0.75 vertically, ±3.1 horizontally).
- food: (240, 952) mound∩bowl band (margins 28.3 horizontal / 4.95 vertical).
Pinned BOTH sides: `verify_geometry.check_compound_fill` (winding-sum ≠ 0 over the compound + a winding-sign uniformity gate over every multi-subpath constant) and Swift `MomoRigVariantsTests.glyphSeamsFill` / `foodMoundFills` (SwiftUI `Path.contains`, which defaults to the nonzero rule — the render truth; `PathMeasuring.contains` is even-odd and was the wrong tool here).

**n1 — explicit reversed-subpath emission.** The ccw branch of `rounded_rect_subpath` (and every reversed subpath) now emits an explicit `move(to:)` with no leading `closeSubpath` — the old reversed window opening crashed the pipeline's own `flatten_subpath` (leading Z with no current point), extra justification beyond the CoreGraphics carryover reliance. Window semantics preserved exactly and proven three ways: signed areas +66,827 (frame) / −42,920 (opening) / +6,594 / +7,154 (bars); probe points — opening interior winding 0 (hole), cross-bar intersection +2, frame band +2, corner +1; rendered PNG opening pixels read exactly the background color while remaining unreachable by a border flood (unbroken frame ring).

**m1** — `__pycache__/` added to `.gitignore`.

**O5 nudge (composition only)** — `render_svg.py` gains `SPARKLE_A_NUDGE = (-100.0, 310.0)` (sparkleA center (230, 250) → (130, 560), into the clear left-wall space below the window); `render_evidence.swift` applies the identical delta as a `gridTranslation` on the evidence canvas. Prop `Path` constants untouched. Result: sparkleA canvas bbox y 376–519 vs window frame bottom row 296 — 80 px = 100 grid units of clearance (was overlapping the frame).

**Verification battery (all green; exact numbers):**
1. Geometry contract checks green — they gate every `generate.py` mode; a full regeneration pass emitted byte-identical output (fresh `--check`: 11 Swift + 4 SVG reproduce byte-identically, exit 0).
2. `--check` green under python3 3.12.13 AND /usr/bin/python3 3.9.6.
3. Winding proof (shoelace, 48-step flatten, on the committed constants): glyphSilhouette [−114,974, −218,838, −20,040, −20,040, −8,116, −8,116] all negative; food [−4,089, −1,790, −175, −175] all negative; window [+66,827, −42,920, +6,594, +7,154] intentionally mixed (exempt hole compound); untouched lodPawPair [+, +], pomPuff [+, +, +, +, +], blanket [+, +].
4. `swift test` = **549 tests / 59 suites passed, twice consecutively** (547 + exactly the 2 new seam pins); zero new compiler warnings.
5. Budgets (1024-byte KB basis): rig 50,096 / 307,200 B; room+props 20,647 / 256,000 B; total 70,743 / 1,572,864 B — byte totals unchanged from pre-fix (reversal permutes each subpath's existing coordinates, so segment counts and file sizes are identical). Evidence SVGs 26,365 B (+40 from the sparkle translate attribute).
6. Visual + pixel judgment of the re-rendered PNGs: all four glyph seam pins read solid furShade with ZERO background pixels within a 15×15-px window, and a background flood-scan of the whole ear/head overlap strip (grid y 240–336, x 340–660) found 0 background pixels — no white gaps or notches at the ear bases or foot seams. Window opening renders as a true hole (exact background color, enclosed by an unbroken frame ring); cross bars + frame filled. sparkleA clear of the window by 100 grid units; sparkleB untouched. NOTE: the review's external vision judge reported "white wedge cutouts" at all four seams on this same render — contradicted by the pixel forensics above (flood + per-pixel probes on the committed bytes; the fill-rule math, both checkers, and the rendered pixels agree). Recorded as a vision-judge misread of the pale anti-aliased seams; the flood-scan numbers are the authoritative evidence. Evidence-only nuance: the PNG renderer's `fill()` maps glyphEyeLeft/Right via its `default` case to `fur`, so the glyph eye dots are low-contrast on `furShade` (pre-existing, cosmetic, untouched in this round).
7. PNG determinism re-proven: rebuild of `render_evidence.swift` against the committed sources + re-render reproduces the committed PNGs byte-identically (sha256: rig-full `b6b11a19…79fdb950`, rig-glyph `4d1eb52b…59dce6ec47`, room-scene `6c5a2a58…d4508d3e4f4`).

Files touched in this round: `Tools/character-pipeline/geometry.py`, `parts.py`, `verify_geometry.py`, `render_svg.py`, `render_evidence.swift`, `.gitignore`, `Tests/MomoCharacterTests/MomoRigGeometryTests.swift`, `Tests/MomoCharacterTests/MomoRigVariantsTests.swift`, regenerated `Sources/MomoCharacter/MomoRig+*.swift` / `MomoRoom.swift` / `MomoProps.swift`, re-rendered `docs/evidence/character/` (4 SVGs + 3 PNGs).

## Handoff (§28)

### Completed
- All 6 requirements + 6 acceptance criteria (see above notes for evidence per item).

### Files Changed
- NEW `Tools/character-pipeline/`: geometry.py, parts.py, verify_geometry.py, emit_swift.py, render_svg.py, generate.py, render_evidence.swift, README.md
- NEW generated `Sources/MomoCharacter/`: MomoRig.swift (hand-written anchor), MomoRig+Body/Head/Ears/Tail/Eyes/FaceDetails/FrontPaws/LODGlance/Glyph.swift, MomoRoom.swift, MomoProps.swift
- NEW `Tests/MomoCharacterTests/`: MomoRigGeometryTests, MomoRigInventoryTests, MomoRigVariantsTests, MomoGeneratedDisciplineTests, MomoPipelineReproducibilityTests, MomoArtBudgetTests; Support/PathMeasuring.swift, Support/GeneratedRigCatalog.swift
- NEW `docs/evidence/character/`: rig-full.svg/png, rig-lod-glance.svg, rig-glyph.svg/png, room-scene.svg/png
- REMOVED: MomoCharacterPlaceholder.swift, MomoCharacterPlaceholderTests.swift (disclosed above)
- Task file: this file (status + notes)

### Tests Run
- `swift test` (full suite) — run 1: 1 failure (disclosed), run 2: green, run 3: green
- `python3 Tools/character-pipeline/generate.py --check` — green (11 Swift + 4 SVG byte-identical) under python3 3.12.13 AND /usr/bin/python3 3.9.6
- `python3 Tools/character-pipeline/generate.py --report` — budgets recorded above
- `swiftc Tools/character-pipeline/render_evidence.swift Sources/MomoCharacter/MomoRig*.swift … -o /tmp/momo-render-evidence` + run — compiles the generated sources standalone and writes the committed PNGs
- Fix round 1: full battery re-run — geometry gates green (gating every generate.py mode), `--check` green under both pythons after regeneration, winding-sign proof green, `swift test` 549/59 ×2 consecutive, budgets re-measured (unchanged), PNGs re-rendered + pixel/flood forensics green (details in the Fix round 1 subsection above)

### Test Results
- 547 tests / 59 suites passed ×2 (after the disclosed single-fix iteration); zero new warnings
- Fix round 1: **549 tests / 59 suites passed ×2 consecutively** (547 + glyphSeamsFill + foodMoundFills); zero new warnings

### Known Issues
- None functional. PNG evidence is deterministic on the verified host but intentionally not test-pinned (raster encoder = host facility). The `ld /opt/extra/lib` warning is pre-existing host noise (see notes).
- Fix round 1: the review's external vision judge reported white seam wedges on the re-rendered glyph that pixel forensics disprove (flood scan: 0 background pixels across the overlap strips) — recorded as a vision-judge misread; authoritative numbers in the Fix round 1 subsection. Cosmetic, evidence-only: the PNG renderer maps glyphEyeLeft/Right to `fur` via its `default` fill case (low contrast on the glyph; pre-existing, untouched).

### Decisions Made
- Parametric-source-as-vector-tool posture (04 §8.2 agent-era reality, per task contract); compound-path nonzero union for the glyph merge and the pom/window; public generated constants; mouth = 3 shipped poses (21 ≠ 19 accounting); lid/paw/tail geometry refined from the first visual QA pass; budgets pinned at §8.3 numbers with 1024-byte KB basis.
- Fix round 1: winding discipline = every non-hole compound fills same-wound (reversal at the source, `reversed_subpath`), the window stays the single intentional hole compound; the ADR-001 ear rule measures the at-base chord at the ear-root line (bbox width demoted to the rounded-tips reference); seam pins live both sides with the Swift side on SwiftUI `Path.contains` (nonzero = render truth) because `PathMeasuring.contains` is even-odd; the O5 sparkle fix is canvas composition (`SPARKLE_A_NUDGE` / `gridTranslation`), never prop-geometry edits.

### Reviewer Status
PENDING — independent fresh review required (CLAUDE.md §10/§33; review brief in Review Requirements; file: `.claude/tasks/reviews/REVIEW-TASK-025.md`)
- Fix round 1 complete (2026-09-09) — **awaiting delta review** of the M1/M2/m1/n1/O5 fix delta per §11 before any commit.

### Commit
None — implementation agent has no commit rights; working tree left DIRTY for the orchestrator.

### Push
n/a (no commit)

### Recommended Next Step
Independent review of TASK-025 per the Review Requirements (including the mutation-bite on a geometry pin), then orchestrator commit `feat(character): TASK-025 asset pipeline + generated rig Path constants`, push, and proceed to TASK-026 (rig layer tree + CharacterClock).
- Updated after fix round 1: fresh **delta review** of the fix-round-1 delta (M1 at-base measurement both sides; M2 reversal + seam pins + winding gate; n1 explicit emission; m1 gitignore; O5 sparkle nudge; regeneration + re-render + the verification battery above). On APPROVED/APPROVED_WITH_MINOR_NOTES → orchestrator commit + push, then TASK-026.

## Reviewer Findings
See .claude/tasks/reviews/REVIEW-TASK-025.md — CHANGES_REQUIRED (2 MAJOR / 1 MINOR / 1 NITPICK / 8 OBSERVATIONS)

### Orchestrator disposition (2026-09-09, pre-fix-loop) — every finding's diagnosis verified personally before acting
- **M1 CONFIRMED by independent computation.** From the emitted béziers: true at-base width at the ear-root line y=250 ≈ 64.3–64.9 units (my bézier sampling; reviewer's `width_at_y`: 64.93 = 12.12% of body width 535.63), while the bounding-box width is 120.5 (484.3 − 363.8, including the control-point bulge left of the outer anchor — the implementer's 120.5 and reviewer's 120.46 reconcile). Both checkers measure `box` width (`verify_geometry.py` `base_width = box[2] - box[0]`; `MomoRigGeometryTests` `box.width`) — the wrong quantity, mislabeled "base". The shipped ART complies (12.12% ≥ 12%); the margin is ~0.12pp, materially different headroom than the claimed ~10.5pp.
- **M2 CONFIRMED by independent shoelace arithmetic** on the emitted glyph coordinates: head subpath signed area −142,008 vs ears +25,499 / feet +10,336 (anchor-point approximations; same signs as the reviewer's curve-faithful figures) — mixed winding under nonzero fill ⇒ the ear∩head and foot∩body overlaps cancel to holes. The orchestrator's earlier zoomed-crop read ("continuous fill") was WRONG — the thin lens-shaped holes were misjudged as junction shading; the reviewer's grid scan (~3,924 sq units at the ear seams + foot slivers) and the review's independent vision judge ("white V-notches at the ear bases") are correct. Recorded as an orchestrator verification miss: numeric winding analysis beats visual inspection for fill-rule questions.
- **m1** (gitignore `__pycache__/`) — matches the orchestrator's own pre-review finding; folded into the fix contract.
- **n1** (explicit move/close for reversed subpaths) — accepted, bundled into the M2 emitter touch.
- **O1–O8** — accepted as recorded/routed: O1 (pipeline-side verify is a self-consistency gate; Swift pins are the landmark authority) → standing note in status.md; O2 (drowsy-eye margin) → verify on real surfaces in TASK-026+; O3 (tail weak at evidence scale) → refinement candidate TASK-026+; O4 (glyph true-size 24–32 pt check) → owed at complication surfaces (EPIC-008 routing); O5 (sparkle∩window collision on the committed canvas; low rug/window contrast; tail/blanket clearance) → sparkle canvas nudge included in the fix contract (composition only, not prop geometry); O6 (§3.1 lower-lid poses) → confirm they land in the TASK-027 contract; O7 (no-bounce pin belongs to the animation layer) → carry into the TASK-026 contract explicitly; O8 (budget-bucket basis: hand-written anchor outside buckets) → basis noted, no action.
- **Mutation bite re-verified indirectly:** the reviewer's demonstrated bite (pipeline exit 0 on a moved landmark while the Swift pin failed by name) stands; restore provenance (13/13 sha256 + `--check` green) accepted from the review record.
- Next per §11: fresh fix agent (M1+M2+m1+n1+O5-nudge + regenerate + re-render + overlap-lens pin), then orchestrator re-verification (winding-sign uniformity, hole-free vision judge on the re-rendered glyph, suite ×2, budgets), then a fresh delta-review of the material delta before any commit.
- Fix round 1 delta: see .claude/tasks/reviews/REVIEW-TASK-025-FIXROUND1.md — APPROVED_WITH_MINOR_NOTES (M1/M2/n1/m1/O5 verified by independent measurement on both checkers, incl. the sanctioned one-ear winding mutation bite: gate exit 1 + `glyphSeamsFill` failed by name at (455,245), 12/12 sha256-identical restore, `--check` green under both pythons, 549/59 ×2, PNGs byte-identical re-renders; one prose fix recommended — lens clearance is ≥ 13.4 units to the nearest outline, not ≥ 16.0)

### Orchestrator disposition on the fix round 1 delta (2026-09-09) — post-review, pre-commit
- **Orchestrator re-verification of the fix round (all green, personally executed):** independent shoelace on the committed regenerated Swift (`glyphSilhouette` 6/6 uniform negative [−71,004, −182,352, −12,760 ×2, −5,168 ×2]; `food` 4/4 negative) — winding-uniformity confirmed before reading the delta review; `generate.py --check` byte-identical; `swift test` **549/59 green ×2** (orchestrator's own runs); budgets re-measured unchanged (rig 51,906 B by module glob incl. the 1,810 B hand-written anchor / 50,096 B generated-only; room+props 20,647 B); `__pycache__/` gitignored; corrected Swift ear pin read (`widthAtY(ear, atY: root.y)`); 4× zoom of the re-rendered glyph seam region read personally — solid fill through both ear bases, concave union corners only.
- **n2 — ACCEPTED and APPLIED.** Diagnosis cross-checked by the orchestrator's own curve sampling (ear-arc clearance ≈15.4, also below the claimed 16.0) before adopting the delta review's 512-step figure (13.40 nearest; head arcs 16.20 L / 13.40 R); the lens-clearance line now states the accurate minimum. Pins themselves exact and untouched.
- **Delta-review notes accepted:** counterexample at-base figure difference (3.15% vs ≈6.73%) is ellipse-anchoring convention — both far below the floor while bbox passes, so the demonstrated false-negative class is identical; the empty background-run-2 capture is superseded by the delta reviewer's two direct full-suite greens on hash-identical trees plus the orchestrator's own ×2.
- **Cycle complete per §17/§18:** CHANGES_REQUIRED → fix round 1 (fresh agent) → delta re-review APPROVED_WITH_MINOR_NOTES → prose applied. No open findings. Committing per §12.

## Completion Evidence
(orchestrator fills at housekeeping)
