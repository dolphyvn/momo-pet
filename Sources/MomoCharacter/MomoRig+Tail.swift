//
//  MomoRig+Tail.swift
//  MomoCharacter
//
//  GENERATED FILE - DO NOT EDIT.
//  Regenerate with: python3 Tools/character-pipeline/generate.py
//  (run from the repository root; output must reproduce this file
//  byte-identically - pinned by MomoPipelineReproducibilityTests)
//
//  Source of truth: Tools/character-pipeline/parts.py
//  Normative geometry: docs/design/04-character-system.md §2.1-2.2 (1000×1000
//  normalized grid, y-down, ground y = 1000), ADR-001 (Direction C).
//  Colorless geometry (R4): tokens are applied at render time (§8.4).
//

import SwiftUI


/// The Direction-C rig's Tail layer group(s) (04 §2.2).
///
/// The full rig's part accounting: 04 §2.2 counts 17 parts
/// (mouth counted once as a 3-pose slot); ADR-001's Direction-C
/// delta adds the two hind feet. The mouth slot ships its three
/// pre-built poses as separate constants (R1: crossfaded, never
/// re-tessellated).

/// 1000×1000 normalized design space (04 §2.1). y-down; ground y = 1000.

extension MomoRig {


    /// **tail** - Tail group.
    /// Channels: rotation (metronome +/-10 deg), scaleY (flick).
    /// Puff tail anchored near the section 2.1 tail anchor, peeking past the body's right edge (ADR-001 puff tail).
    public static let tail: Path = Path { p in
        p.move(to: CGPoint(x: 830.000, y: 796.000))
        p.addCurve(
            to: CGPoint(x: 778.000, y: 852.000),
            control1: CGPoint(x: 830.000, y: 826.928),
            control2: CGPoint(x: 806.719, y: 852.000))
        p.addCurve(
            to: CGPoint(x: 726.000, y: 796.000),
            control1: CGPoint(x: 749.281, y: 852.000),
            control2: CGPoint(x: 726.000, y: 826.928))
        p.addCurve(
            to: CGPoint(x: 778.000, y: 740.000),
            control1: CGPoint(x: 726.000, y: 765.072),
            control2: CGPoint(x: 749.281, y: 740.000))
        p.addCurve(
            to: CGPoint(x: 830.000, y: 796.000),
            control1: CGPoint(x: 806.719, y: 740.000),
            control2: CGPoint(x: 830.000, y: 765.072))
        p.closeSubpath()
    }
}
