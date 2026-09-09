# EPIC-006 — Character Rendering (MomoCharacter)

## Objective
Build the Direction-C "Round Rabbit" character system per 04 and ADR-001/ADR-007: the repo-local export pipeline producing generated Swift `Path` constants, the transform-only ~17-part rig with a single CharacterClock and LOD tiers, the deterministic idle sequencer, the expression system and reaction vocabulary with state choreography and idempotent `CharacterReport` emission, the Reduce Motion mapping, and token-driven theming — proven by sequencer determinism properties and pause/RM tests.

## User / Product Value
Momo becomes visible and alive. Breathing, blinking, glancing, reacting to touch — the "quietly alive" quality the PRD demands (FR-4/FR-5), with battery-safe motion (NFR-2), accessibility-respecting animation (NFR-6), and premium feel (philosophy guardrail).

## Scope
- Export pipeline (04 §8.2, §8.5): build-time script → committed, reviewable Swift Path constants for the full rig, LOD-glance variant, glyph variant (ear-thickness rule: below ~32 pt ears merge into head outline per ADR-001), room scene + props (food, blanket, 2 sparkles, static pom decor `momo.room.pom`); art budget ≤ 1.5 MB (04 §8.3).
- Rig + clock + LOD (04 §2, §7.4, §9.5): transform-only layers (R1/R2), token colors only (R4), CharacterClock gating L0–L4 with one-call pause on scenePhase ≠ active / AOD; tiers full / LOD-glance / glyph.
- Idle sequencer + expressions (04 §3, §5): pure scheduler files, deterministic given (idleSeed, timeline); mood-band expressions (§3.2), energy modulation (§3.3), bond dials (§3.4); posture-led Low band, no suffering visuals (INV-6); motion timings/curves per §7.1–7.2.
- Reactions + choreography + reports (04 §4, §6, §9.2): L0–L4 priority classes with §4.1 coherence rules (blink preemptible, L2 crossfade, rapid-pat 500 ms coalescing, sleeping accepts only stir); §6.1 gesture×zone reactions (7 distinct + stir + refusals); play-round character pacing inside UX-3's ≤ 30 s shell; idempotent `CharacterReport` incl. `handshakeCancelled(kind)`; character never applies effects (§9.3).
- Reduce Motion + theming (04 §7.3, §8.4): full §7.3 mapping table (static poses, crossfades, milestone poses); RM never removes information; grayscale legibility per §3.5; zero hex (R4).

## Non-Goals
Audio (none in Phase 1 — 04 §11), engine logic (consumes ResponsePlan only), iPhone UI composition (EPIC-007), Watch surfaces (EPIC-008 consumes LOD tiers), new art directions (E2 closed — Direction C), copy writing beyond the seeded tone-guide pools (engine tasks own key selection).

## Dependencies
- EPIC-002 (TASK-009 package, TASK-011 tokens); EPIC-003 interface types (TASK-012, 04 §9.2 shapes).
- Runs as LANE B beside EPIC-004/005; converges at EPIC-007.

## Tasks
Branch: `feature/EPIC-006-character` (from `main`).

| TASK | Title | Size | Depends on |
|---|---|---|---|
| TASK-025 | Build the asset export pipeline + generated Path constants (04 §8.2, §8.5, ADR-007) | M | TASK-009, TASK-011 |
| TASK-026 | Implement MomoRig layer tree + CharacterClock + LOD tiers (04 §2, §7.4, §9.5) | L | TASK-025, TASK-012 |
| TASK-027 | Implement idle sequencer + expression system (04 §3, §5) | L | TASK-026 |
| TASK-028 | Implement reaction vocabulary + state choreography + CharacterReport emission (04 §4, §6, §9.2) | L | TASK-027 |
| TASK-029 | Implement Reduce Motion mapping + token-driven theming (04 §7.3, §8.4) | M | TASK-028 |
| TASK-030 | Add character test suites (05 §10.1 MomoCharacterTests) | S | TASK-026…029 |

## Acceptance Criteria
1. Pipeline reproduces committed Path constants deterministically; art contribution ≤ 1.5 MB measured; glyph variant honors the ear-thickness rule.
2. Every motion is transform-only on pre-built layers; the rig reads token slots exclusively (zero hex literals); all 8 invariants INV-1…8 hold.
3. CharacterClock pauses all channels in one call; scenePhase/AOD zero the clock; resume restores cleanly (NFR-2 structural guarantee).
4. Sequencer is deterministic given (idleSeed, timeline); aliveness floor fallback exists; motionlessness is itself calm (no distraction).
5. Reaction vocabulary matches §6.1 exactly (7 distinct + stir + refusals); coherence rules of §4.1 enforced; reports idempotent incl. cancellation; effects never applied character-side (§9.3).
6. Reduce Motion mapping covers every animated state per §7.3 with zero information loss; grayscale legibility verified per §3.5.

## Test Requirements
- project.md §32 Domain (deterministic-randomness half) via `MomoCharacterTests`: sequencer determinism properties (same seed+timeline ⇒ same event log), pause discipline, RM mapping table.
- Reaction duration bounds per §7.1; grayscale preview checks recorded.
- Pure files fully covered by determinism properties (05 §10.2).

## Definition of Done
All six tasks DONE per CLAUDE.md §18; character suites green via `swift test`; Momo demonstrably alive (idle + reactions) on a debug canvas with correct pause behavior; reviews APPROVED; atomic TASK-ID commits on `feature/EPIC-006-character`, pushed; epic merged to `main`; orchestrator status update.

## Carried-in observations (REVIEW-TASK-019; catalog-era obligations)

- **OBS-A — cross-context seed lockstep:** the engine's one day-stable copy seed (`LineSelection.copySeed`, §4.10 `.copy` salt) is shared by ALL react families AND slots — the contract's own seed formula omits context. Once real pools exceed 1 (TASK-025-era `MomoCopy.xcstrings` work), equal pool counts yield the SAME index across contexts on a day (e.g. `touch.03` / `feed.03` / `morning.03` all day). Contract-conformant; if varied-feeling lines are wanted, add a context segment to the seed — an epoch-bump-class change (`CopyRules.copyEpoch`). Decide when real pools land.
- **OBS-B — declined/warm cells share the family key:** e.g. `politelyFull` (feed refusal) and `eating` both carry `momo.line.react.feed.<nn>` — spec-conformant per 04 §10.4's per-family keyspace. The catalog era decides whether declined cells warrant their own entries (a pool split = an epoch bump).

## Status
TODO
