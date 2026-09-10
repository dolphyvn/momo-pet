# ADR-009 — Rig composition order: one composed matrix per slot (R1)

## Status

Accepted (TASK-027, discharges REVIEW-TASK-026 MINOR-1b)

## Context

TASK-026 shipped two composition algorithms for the rig: `RigLayerTree.affineTransform(of:at:)` — the normative CG matrix composing per stage `S·R·T` about the stage anchor, child stages applying before ancestors — and `MomoRigView`'s SwiftUI modifier chain applying per-stage offset → `rotationEffect` → `scaleEffect` ancestor-first. SwiftUI modifiers apply in LISTING order (first-listed innermost), so the two algorithms agree only while the body's anchored pure scale is the sole non-identity channel. The review flagged this as blocking: no ear/tail/head channel may emit non-identity values before the reconciliation lands, because a multi-channel pose would render differently through the view than the matrix promises.

## Decision

Option 1: ONE composed transform per slot. `MomoRigView` renders each slot inside a single `Canvas` `drawLayer` that concatenates `RigLayerTree.affineTransform(of:at:)` and fills the slot's path through the slot's opacity channel. The normative matrix becomes the ONLY composition algorithm; the per-stage modifier chain is deleted. §2.2's anchor law (`anchor⁻¹·S·R·T·anchor`, child-first) is unchanged and stays documented at the matrix.

## Alternatives Considered

- **Option 2 (mirror the view's order in the matrix).** Re-derives SwiftUI's modifier semantics into the geometry core — the core would then encode presentation-order accidents, and SwiftUI's rules are exactly what we must not "re-derive from memory" per the settlement rule.
- **Option 3 (one-non-identity-freedom-per-stage constraint).** Keeps two algorithms correct only under a motion-model restriction enforced by convention; the constraint's proof burden recurs on every future channel, and LOD tiers already vary stage sets.

## Consequences

- The matrix and the render can no longer disagree structurally — they are the same code path's output.
- Numerical proof landed in `Tests/MomoCharacterTests/R1CompositionTests.swift`: (1) point probes — the composed matrix maps probe points to the same places as an independent step-by-step evaluation of the §2.2 law at a fully-loaded multi-channel pose (≥ 15 slots, > 75 points, 1e-6 grid units), with an order-sensitivity control proving the probe catches a swapped stage walk (misses by units); (2) pixel probes — the full rig through the view's verbatim `drawLayer` loop renders pixel-equal (≤ 8 boundary-antialiasing pixels of ~10⁶) to the same slots through a raw y-flipped `CGContext`, and demonstrably differs from the `.rest` render (> 1000 px) so the probe is not comparing two still lifes.
- `.rest` composes to exactly `CGAffineTransform.identity` at every tier (pin).
- Motion tests may now hand-construct schedules and pose assertions against the matrix law; the view renders whatever pose arrives.
- Anchors remain fixed points of their own stage (ground under body-only rotation); children ride ancestors (the neck moves ~18 grid units under a 2.5° body rotation) — pinned.

## Date

2026-09-09 (TASK-027 implementation)
