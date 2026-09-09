//
//  MomoRig+Glyph.swift
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


/// The Direction-C rig's Glyph layer group(s) (04 §2.2).
///
/// The full rig's part accounting: 04 §2.2 counts 17 parts
/// (mouth counted once as a 3-pose slot); ADR-001's Direction-C
/// delta adds the two hind feet. The mouth slot ships its three
/// pre-built poses as separate constants (R1: crossfaded, never
/// re-tessellated).

/// 1000×1000 normalized design space (04 §2.1). y-down; ground y = 1000.

extension MomoRig {


    /// **glyphSilhouette** - Glyph group.
    /// Channels: static; fills as one union (nonzero).
    /// Glyph silhouette: head + pear body + both ears + both hind feet as one compound Path. Ears are merged into the outline (ADR-001 below ~32 pt) while the pear silhouette and ground contact are retained.
    public static let glyphSilhouette: Path = Path { p in
        p.move(to: CGPoint(x: 500.000, y: 590.000))
        p.addCurve(
            to: CGPoint(x: 694.000, y: 412.000),
            control1: CGPoint(x: 628.000, y: 588.000),
            control2: CGPoint(x: 694.000, y: 520.000))
        p.addCurve(
            to: CGPoint(x: 500.000, y: 224.000),
            control1: CGPoint(x: 694.000, y: 308.000),
            control2: CGPoint(x: 626.000, y: 226.000))
        p.addCurve(
            to: CGPoint(x: 306.000, y: 412.000),
            control1: CGPoint(x: 374.000, y: 226.000),
            control2: CGPoint(x: 306.000, y: 308.000))
        p.addCurve(
            to: CGPoint(x: 500.000, y: 590.000),
            control1: CGPoint(x: 306.000, y: 520.000),
            control2: CGPoint(x: 372.000, y: 588.000))
        p.closeSubpath()
        p.move(to: CGPoint(x: 500.000, y: 940.000))
        p.addCurve(
            to: CGPoint(x: 764.000, y: 800.000),
            control1: CGPoint(x: 640.000, y: 940.000),
            control2: CGPoint(x: 752.000, y: 882.000))
        p.addCurve(
            to: CGPoint(x: 712.000, y: 548.000),
            control1: CGPoint(x: 776.000, y: 718.000),
            control2: CGPoint(x: 760.000, y: 610.000))
        p.addCurve(
            to: CGPoint(x: 500.000, y: 428.000),
            control1: CGPoint(x: 668.000, y: 490.000),
            control2: CGPoint(x: 610.000, y: 448.000))
        p.addCurve(
            to: CGPoint(x: 288.000, y: 548.000),
            control1: CGPoint(x: 390.000, y: 448.000),
            control2: CGPoint(x: 332.000, y: 490.000))
        p.addCurve(
            to: CGPoint(x: 236.000, y: 800.000),
            control1: CGPoint(x: 240.000, y: 610.000),
            control2: CGPoint(x: 224.000, y: 718.000))
        p.addCurve(
            to: CGPoint(x: 500.000, y: 940.000),
            control1: CGPoint(x: 248.000, y: 882.000),
            control2: CGPoint(x: 360.000, y: 940.000))
        p.closeSubpath()
        p.move(to: CGPoint(x: 481.143, y: 149.326))
        p.addCurve(
            to: CGPoint(x: 404.923, y: 51.069),
            control1: CGPoint(x: 470.594, y: 89.498),
            control2: CGPoint(x: 436.469, y: 45.506))
        p.addCurve(
            to: CGPoint(x: 366.906, y: 169.469),
            control1: CGPoint(x: 373.377, y: 56.631),
            control2: CGPoint(x: 356.356, y: 109.641))
        p.addCurve(
            to: CGPoint(x: 443.126, y: 267.727),
            control1: CGPoint(x: 377.455, y: 229.298),
            control2: CGPoint(x: 411.580, y: 273.289))
        p.addCurve(
            to: CGPoint(x: 481.143, y: 149.326),
            control1: CGPoint(x: 474.672, y: 262.164),
            control2: CGPoint(x: 491.693, y: 209.154))
        p.closeSubpath()
        p.move(to: CGPoint(x: 633.094, y: 169.469))
        p.addCurve(
            to: CGPoint(x: 595.077, y: 51.069),
            control1: CGPoint(x: 643.644, y: 109.641),
            control2: CGPoint(x: 626.623, y: 56.631))
        p.addCurve(
            to: CGPoint(x: 518.857, y: 149.326),
            control1: CGPoint(x: 563.531, y: 45.506),
            control2: CGPoint(x: 529.406, y: 89.498))
        p.addCurve(
            to: CGPoint(x: 556.874, y: 267.727),
            control1: CGPoint(x: 508.307, y: 209.154),
            control2: CGPoint(x: 525.328, y: 262.164))
        p.addCurve(
            to: CGPoint(x: 633.094, y: 169.469),
            control1: CGPoint(x: 588.420, y: 273.289),
            control2: CGPoint(x: 622.545, y: 229.298))
        p.closeSubpath()
        p.move(to: CGPoint(x: 438.000, y: 962.000))
        p.addCurve(
            to: CGPoint(x: 370.000, y: 924.000),
            control1: CGPoint(x: 438.000, y: 941.013),
            control2: CGPoint(x: 407.555, y: 924.000))
        p.addCurve(
            to: CGPoint(x: 302.000, y: 962.000),
            control1: CGPoint(x: 332.445, y: 924.000),
            control2: CGPoint(x: 302.000, y: 941.013))
        p.addCurve(
            to: CGPoint(x: 370.000, y: 1000.000),
            control1: CGPoint(x: 302.000, y: 982.987),
            control2: CGPoint(x: 332.445, y: 1000.000))
        p.addCurve(
            to: CGPoint(x: 438.000, y: 962.000),
            control1: CGPoint(x: 407.555, y: 1000.000),
            control2: CGPoint(x: 438.000, y: 982.987))
        p.closeSubpath()
        p.move(to: CGPoint(x: 698.000, y: 962.000))
        p.addCurve(
            to: CGPoint(x: 630.000, y: 924.000),
            control1: CGPoint(x: 698.000, y: 941.013),
            control2: CGPoint(x: 667.555, y: 924.000))
        p.addCurve(
            to: CGPoint(x: 562.000, y: 962.000),
            control1: CGPoint(x: 592.445, y: 924.000),
            control2: CGPoint(x: 562.000, y: 941.013))
        p.addCurve(
            to: CGPoint(x: 630.000, y: 1000.000),
            control1: CGPoint(x: 562.000, y: 982.987),
            control2: CGPoint(x: 592.445, y: 1000.000))
        p.addCurve(
            to: CGPoint(x: 698.000, y: 962.000),
            control1: CGPoint(x: 667.555, y: 1000.000),
            control2: CGPoint(x: 698.000, y: 982.987))
        p.closeSubpath()
    }

    /// **glyphEyeLeft** - Glyph group.
    /// Channels: static; opacity-carrying dot.
    /// Glyph left eye - a simple dot that keeps the face legible at 24-32 pt.
    public static let glyphEyeLeft: Path = Path { p in
        p.move(to: CGPoint(x: 472.000, y: 386.000))
        p.addCurve(
            to: CGPoint(x: 432.000, y: 430.000),
            control1: CGPoint(x: 472.000, y: 410.301),
            control2: CGPoint(x: 454.091, y: 430.000))
        p.addCurve(
            to: CGPoint(x: 392.000, y: 386.000),
            control1: CGPoint(x: 409.909, y: 430.000),
            control2: CGPoint(x: 392.000, y: 410.301))
        p.addCurve(
            to: CGPoint(x: 432.000, y: 342.000),
            control1: CGPoint(x: 392.000, y: 361.699),
            control2: CGPoint(x: 409.909, y: 342.000))
        p.addCurve(
            to: CGPoint(x: 472.000, y: 386.000),
            control1: CGPoint(x: 454.091, y: 342.000),
            control2: CGPoint(x: 472.000, y: 361.699))
        p.closeSubpath()
    }

    /// **glyphEyeRight** - Glyph group.
    /// Channels: static; opacity-carrying dot.
    /// Glyph right eye.
    public static let glyphEyeRight: Path = Path { p in
        p.move(to: CGPoint(x: 608.000, y: 386.000))
        p.addCurve(
            to: CGPoint(x: 568.000, y: 430.000),
            control1: CGPoint(x: 608.000, y: 410.301),
            control2: CGPoint(x: 590.091, y: 430.000))
        p.addCurve(
            to: CGPoint(x: 528.000, y: 386.000),
            control1: CGPoint(x: 545.909, y: 430.000),
            control2: CGPoint(x: 528.000, y: 410.301))
        p.addCurve(
            to: CGPoint(x: 568.000, y: 342.000),
            control1: CGPoint(x: 528.000, y: 361.699),
            control2: CGPoint(x: 545.909, y: 342.000))
        p.addCurve(
            to: CGPoint(x: 608.000, y: 386.000),
            control1: CGPoint(x: 590.091, y: 342.000),
            control2: CGPoint(x: 608.000, y: 361.699))
        p.closeSubpath()
    }
}
