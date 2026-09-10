# ADR-011 — Body scaleY composition law: the posture band governs the static channel, motion composes unclamped

## Status

Accepted (TASK-027 fix round 1 — REVIEW-TASK-027 MAJOR-1)

## Context

Three doc clauses constrain one shared channel — body scaleY — and a model-side clamp that wrapped their composition made them mutually contradictory:

- 04 §3.1 gives every mood band a static posture scaling ("Joyful +3% tall … Low −5% slouch"), summarized by `MomoCurves.postureScaleYRange = 0.95…1.03`.
- 04 §7.1 gives every band a breath amplitude (e.g. Joyful ±2.2 % at 4.0 s) and 04 §7.2 mandates the breath be a "pure sine".
- 04 §5.2 lets idle events add motion (weight shifts, cheek-press relaxations) on the same channel.

The first TASK-027 implementation clamped the COMPOSED body scaleY back into the §3.1 band at the model write site. That clamp cannot satisfy §7.2: a pure sine clipped at the band edge is no longer a pure sine — on Joyful (band top 1.03, posture base 1.03), every breath peak landed exactly on the clamp, and the reviewer's sweep found flat samples on the oscillation. Resolving the conflict by re-authoring the Joyful row (dropping the band so posture + breath fits inside it) would rewrite §3.1/§7.1's published numbers; resolving it with a per-channel clamp exception re-introduces the same non-sine at the exception boundary.

## Decision

The §3.1 posture band governs the STATIC posture channel only. The expression layer (`MomoExpressions.expression`) pre-clamps the band base × energy overlays into `postureScaleYRange`; motion then composes MULTIPLICATIVELY on top and is never re-clamped into the band:

```
body.scaleY = postureScaleY  (expression layer, clamped to §3.1)
            × breathScaleY   (§7.1/§7.2, pure sine)
            × idle-event envelopes (§5.2)
```

Each motion contributor is bounded by its own authored magnitudes (the §7.1 amplitude, the §5.2 event amplitudes) — not by the posture band. Consequence: the composed body scaleY transiently exceeds the §3.1 band by exactly the authored motion amount (Joyful peaks at 1.03 × 1.022 ≈ 1.052); the band's guarantee moves to the static posture, which is what §3.1's rows describe ("+3 % tall" is a posture, not a motion envelope).

## Alternatives Considered

- **Keep the composed clamp (original implementation).** Fails §7.2's pure-sine mandate — flat samples wherever posture sits at a band edge (Joyful everywhere). REVIEW-TASK-027 MAJOR-1.
- **Re-author the Joyful band row so posture + breath fits inside the band.** Rewrites §3.1/§7.1's published numbers (out of scope for the task; the doc rows are the product contract) and still clips under §5.2 event stacking.
- **Clamp-only-when-breathing exception.** The same non-sine distortion returns at the clamp boundary for large breath amplitudes; adds a second, harder-to-test law.

## Consequences

- `RigMotionModel` writes the composed body scaleY unclamped; the model-side clamp list (ears, tail, pupils, head/body micro-motion bounds) does not include the posture band, and its header says so.
- `MomoCurves.postureScaleYRange`'s documentation states the two-channel reading and cites this ADR; `clampedPostureScaleY` is documented as an expression-layer tool.
- `MomoIdleRenderTests` pins the law digit-for-digit: per-band breath sweeps require every rendered sample to equal `postureScaleY × breathScaleY` exactly (bitwise), zero flat samples on any band, and the asleep amplitude reduction to apply exactly (× `1 − sleepAmplitudeReduction`); the Joyful-asleep peak pin now expects the unclamped value (> the band top), which is possible only under this law.
- Expression-layer clamp tests (`MomoExpressionTests`, `MomoCurvesTask027Tests`) are unaffected — the band still holds where the doc states it.

## Date

2026-09-10 (TASK-027 fix round 1)
