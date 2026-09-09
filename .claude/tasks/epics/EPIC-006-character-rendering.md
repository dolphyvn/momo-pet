# EPIC-006 — Character Rendering (MomoCharacter)

## Objective
Make Momo visibly ALIVE before any real Home exists: the Direction-C "Round Rabbit" rig (ADR-001) as a SwiftUI-native parametric vector rig (ADR-007) — exported geometry constants, a transform-only layer tree, a single pausable CharacterClock, the deterministic idle sequencer, the L0–L4 reaction vocabulary and state choreography, and the Reduce Motion + token-theming mapping — proven by the `MomoCharacterTests` determinism/pause/RM suites (05 §10.1–10.2). Slice (delivery plan): "Momo renders alive (idle + reactions) on a debug canvas, pausing correctly."

## User / Product Value
The "Alive" pillar of Cute × Calm × Minimal × Alive × Premium is the product's core emotional mechanism (FR-4: Momo feels alive without demanding attention). Everything downstream — Home (EPIC-007), Watch glance (EPIC-008) — renders THIS rig; the aliveness quality is decided here, once, for every surface.

## Scope
- **Asset pipeline (04 §8.2, ADR-007):** repo-local build-time script exporting Direction-C geometry into committed, reviewable Swift `Path` constants — full rig (~17 parts, §2.2), LOD-glance variant, glyph variant (ADR-001: below ~32 pt ears merge into the head outline, pear silhouette preserved), room scene + props (food, blanket, 2 sparkles, static pom decor). Zero runtime dependencies. Budgets (§8.3): rig ≤ 300 KB source, room + props ≤ 250 KB, total art ≤ 1.5 MB (target ~0.5 MB).
- **Rig + clock + LOD (04 §2, §7.4, §9.5):** transform-only motion on pre-built layers under the hard rig rules R1–R4 (no per-frame path re-generation; one continuous creature; every channel independently pausable; token colors only, zero hex); the single `CharacterClock` gates L0–L4 and is zeroed on `scenePhase ≠ active` / AOD with one call; LOD tiers full / LOD-glance / glyph selected per surface (§2.1 stage table).
- **Idle sequencer + expressions (04 §3, §5):** pure deterministic sequencer (scheduler parameters §5.2, variant catalog §5.2, deterministic given `(idleSeed, timeline)`); mood-band expressions (§3.2), energy modulation (§3.3), bond behavior dials (§3.4) — posture-led, no suffering visuals (INV-6); timings/curves per §7.1–7.2; aliveness-floor fallback (§5.3).
- **Reactions + choreography + CharacterReport (04 §4, §6, §9.2):** L0–L4 priority classes with the §4.1 coherence rules (blink preemptible; L2 crossfade; rapid-pat coalescing per the 500 ms window; sleeping accepts only stir; app-hide pauses everything); §6.1 gesture×zone reactions (7 distinct + stir + warm refusals); play-round character-side pacing inside UX-3's ≤ 30 s shell (§6.3); emits idempotent `CharacterReport` incl. `handshakeCancelled(kind)` — the engine owns what/when, the character never applies effects (§9.3).
- **Reduce Motion + theming (04 §7.3, §8.4):** the full §7.3 binding mapping table (static poses, crossfades, milestone poses for play); RM never removes information (static pose + glyph/label/text channels); grayscale legibility per expression state (§3.5); the rig reads only the §8.4 token slots (`momo.fur.base` … `momo.sparkle`) — values assigned by the landed EPIC-002 palette pass (Appendix B item 3).
- **Test suites (TASK-030, 05 §10.1–10.2):** sequencer determinism properties, pause discipline, RM pose mapping, reaction bounds; pure files fully determinism-property covered.

## Non-Goals
Home composition, touch handling, feed/play/care flows, quests UI, settings (EPIC-007); the Watch app surfaces themselves and all sync (EPIC-008 — this epic builds the LOD-glance/glyph VARIANTS as rig data, not the surfaces that show them); haptics delivery (app layer; the flag only threads through what this epic renders); copy pool contents (engine/read-model owned since TASK-019; catalog text lands via EPIC-002's scaffolding + EPIC-007); outfits, accessories, seasonal variants, additional pets, walking/locomotion, interactive room objects (04 §8.5 "NOT in Phase 1"); Lottie/frames pipelines (rejected, ADR-007).

## Dependencies
- EPIC-002 (TASK-009 package/targets; TASK-011 design tokens + `MomoCopy` — the palette pass already assigned the character token slots).
- EPIC-003's `MomoCore` interface types (all five 04 §9.2 types landed in TASK-012).
- LANE B: runs beside LANE A (EPIC-005 — now merged); the lanes converge at EPIC-007. No dependency on EPIC-005.

## Tasks
Branch: `feature/EPIC-006-character` (from `main`).

| TASK | Title | Size | Depends on |
|---|---|---|---|
| TASK-025 | Asset export pipeline + generated Path constants (04 §8.2, §8.5; ADR-007) | M | TASK-009, TASK-011 |
| TASK-026 | MomoRig layer tree + CharacterClock + LOD tiers (04 §2, §7.4, §9.5) | L | TASK-025, TASK-012 |
| TASK-027 | Idle sequencer + expression system (04 §3, §5) | L | TASK-026 |
| TASK-028 | Reaction vocabulary + state choreography + CharacterReport (04 §4, §6, §9.2) | L | TASK-027 |
| TASK-029 | Reduce Motion mapping + token-driven theming (04 §7.3, §8.4) | M | TASK-028 |
| TASK-030 | Character test suites (05 §10.1 MomoCharacterTests) | S | TASK-026…029 |

## Acceptance Criteria
1. Pipeline reproducible (re-run yields the committed output); committed constants compile; Direction-C geometry honors ADR-001's hard rules (ear ≥ 12 % of body width at base, rounded tips; glyph merges ears below ~32 pt; no bounce-loops); budgets measured, not asserted (§8.3).
2. Rig motion is transform-only on pre-built layers (R1), one continuous creature (R2), every channel independently pausable via the single CharacterClock (R3), token colors only with zero hex in rig code (R4); clock zeroing on `scenePhase ≠ active` / AOD is one call and demonstrably stops L0–L4.
3. The idle sequencer is deterministic given `(idleSeed, timeline)` (same inputs ⇒ same event log), falls back to the §5.3 aliveness floor, and never produces suffering visuals (INV-6) — expressions are posture-led per §3.2–3.4.
4. The L0–L4 reaction system honors every §4.1 coherence rule and the §6.1 vocabulary; play-round pacing fits UX-3's ≤ 30 s shell; `CharacterReport` emissions are idempotent and include `handshakeCancelled(kind)`; the character never applies engine effects (§9.3).
5. Reduce Motion follows the §7.3 table exactly and never removes information; grayscale legibility per §3.5 is verified per expression state; the rig is hex-free (R4) under the standing purity scans.
6. `MomoCharacterTests` green via `swift test`; sequencer/pause/RM pure parts fully determinism-property covered per 05 §10.2; art budgets recorded against §8.3.

## Test Requirements
- project.md §32 row "rendering" per 05 §10.4-UI-support: sequencer determinism properties; clock pause/resume with every channel independently pausable; RM pose-mapping table fully covered; reaction duration bounds per §7.1; geometry pins over the §2.1 normalized grid (Direction-C landmarks + the ADR-001 ear rule measurable from exported data).
- All green via `swift test` on macOS; MomoCharacter discipline scans (hex confinement per TASK-011 precedent) stay green with no new exemptions.

## Definition of Done
All six tasks DONE per CLAUDE.md §18; `MomoCharacterTests` green with the coverage/determinism floors recorded; reviews APPROVED; atomic TASK-ID commits on `feature/EPIC-006-character`, pushed; epic merged to `main` per §14; orchestrator status update.

## Status
IN_PROGRESS (0/6) — branch cut from `main` @ the EPIC-005 merge lineage (`cd22acd` + docs). TASK-025 contract dispatched first (delivery-plan TASK-025 row; risk R6 mitigation: repo-local pipeline + committed reviewable output).
