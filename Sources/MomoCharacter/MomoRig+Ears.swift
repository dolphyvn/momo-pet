//
//  MomoRig+Ears.swift
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


/// The Direction-C rig's Ears layer group(s) (04 §2.2).
///
/// The full rig's part accounting: 04 §2.2 counts 17 parts
/// (mouth counted once as a 3-pose slot); ADR-001's Direction-C
/// delta adds the two hind feet. The mouth slot ships its three
/// pre-built poses as separate constants (R1: crossfaded, never
/// re-tessellated).

/// 1000×1000 normalized design space (04 §2.1). y-down; ground y = 1000.

extension MomoRig {


    /// **earLeft** - Ears group.
    /// Channels: rotation (-25..+25 deg), scaleY (twitch).
    /// Left ear - thick short-to-medium oval, rounded tip, calm perked posture. Separate part: per-ear rotation is an expression channel (ADR-001).
    public static let earLeft: Path = Path { p in
        p.move(to: CGPoint(x: 481.143, y: 149.326))
        p.addCurve(
            to: CGPoint(x: 443.126, y: 267.727),
            control1: CGPoint(x: 491.693, y: 209.154),
            control2: CGPoint(x: 474.672, y: 262.164))
        p.addCurve(
            to: CGPoint(x: 366.906, y: 169.469),
            control1: CGPoint(x: 411.580, y: 273.289),
            control2: CGPoint(x: 377.455, y: 229.298))
        p.addCurve(
            to: CGPoint(x: 404.923, y: 51.069),
            control1: CGPoint(x: 356.356, y: 109.641),
            control2: CGPoint(x: 373.377, y: 56.631))
        p.addCurve(
            to: CGPoint(x: 481.143, y: 149.326),
            control1: CGPoint(x: 436.469, y: 45.506),
            control2: CGPoint(x: 470.594, y: 89.498))
        p.closeSubpath()
    }

    /// **earRight** - Ears group.
    /// Channels: rotation (-25..+25 deg), scaleY (twitch).
    /// Right ear - mirror of the left. Separate part: asymmetry (one-up-one-down) is a deliberate expression state (ADR-001).
    public static let earRight: Path = Path { p in
        p.move(to: CGPoint(x: 633.094, y: 169.469))
        p.addCurve(
            to: CGPoint(x: 556.874, y: 267.727),
            control1: CGPoint(x: 622.545, y: 229.298),
            control2: CGPoint(x: 588.420, y: 273.289))
        p.addCurve(
            to: CGPoint(x: 518.857, y: 149.326),
            control1: CGPoint(x: 525.328, y: 262.164),
            control2: CGPoint(x: 508.307, y: 209.154))
        p.addCurve(
            to: CGPoint(x: 595.077, y: 51.069),
            control1: CGPoint(x: 529.406, y: 89.498),
            control2: CGPoint(x: 563.531, y: 45.506))
        p.addCurve(
            to: CGPoint(x: 633.094, y: 169.469),
            control1: CGPoint(x: 626.623, y: 56.631),
            control2: CGPoint(x: 643.644, y: 109.641))
        p.closeSubpath()
    }
}
