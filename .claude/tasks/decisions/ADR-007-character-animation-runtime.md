# ADR-007 — Character Animation Runtime: SwiftUI-Native Parametric Vector Rig (Ratification)

## Status
ACCEPTED — decided in TASK-005 (`docs/design/04-character-system.md` §8.1–8.2) and ratified here for the decision log; this ADR makes no new choice.

## Context
The asset-pipeline choice (TR8) drives download size, memory, battery, eye-follow capability, Reduce Motion variants, Watch/AOD tiers, and the dependency posture. TASK-005 owned and made the decision with a full alternatives table; project.md §40 Step 5 asks architectural decisions to be recorded as ADRs, so it is logged here with TASK-006's placement consequence.

## Decision
**SwiftUI-native parametric vector rig:** character authored in a vector tool, exported via a small repo-local build-time script into generated Swift `Path` constants (committed and reviewable); poses/expression parameters are Swift data; motion is transform-only on pre-built layers, driven by the single CharacterClock; zero runtime dependencies. TASK-006 adds only placement: the rig, CharacterClock, sequencer (pure files), and LOD tiers (full / LOD-glance / glyph) live in the `MomoCharacter` package target (ADR-005), consumed by both app targets. Battery rules (04 §7.4) carry into EPIC-002 verification obligations.

## Alternatives Considered
Recorded by TASK-005 §8.1 and binding here:
- **Lottie (lottie-ios):** designer-loop advantage outweighed by hard contract mismatches — eye-follow hostility, partial dynamic color, watchOS support overhead, and a third-party runtime dependency colliding with the local-first/minimal-surface and no-third-party-SDK posture (FR-20 AC-3).
- **Pre-rendered frames (PNG sequences):** fails the 60 MB size budget outright at 3× scales; no dynamic color; triples asset count for Reduce Motion; scale explosion on Watch/AOD.

## Consequences
- Zero runtime dependencies; art contributes ≤ ~1.5 MB of a ≤ 60 MB app (04 §8.3, NFR-4); memory stays trivial (vector layers, NFR-3).
- Eye-follow (pupils as rig parts), token-driven recoloring (R4), one-clock pausability (TR3/D16), and the AOD glyph tier are native capabilities, not adaptations.
- Authoring effort for organic curves is bounded and one-time for a single pet (mitigated by the export script + SwiftUI Previews loop); export tooling choice VERIFY-AT-BUILD at EPIC-002.
- Direction-C-specific rig commitments apply (ADR-001): ~11 body parts / ~17-part full rig, per-ear rotation channels, ear-thickness glyph rule below ~32 pt.

## Date
2026-09-08 (decision 2026-09-08, TASK-005 §8.2; ratified as an ADR 2026-09-08)
