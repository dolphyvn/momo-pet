//
//  MomoRig+Eyes.swift
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


/// The Direction-C rig's Eyes layer group(s) (04 §2.2).
///
/// The full rig's part accounting: 04 §2.2 counts 17 parts
/// (mouth counted once as a 3-pose slot); ADR-001's Direction-C
/// delta adds the two hind feet. The mouth slot ships its three
/// pre-built poses as separate constants (R1: crossfaded, never
/// re-tessellated).

/// 1000×1000 normalized design space (04 §2.1). y-down; ground y = 1000.

extension MomoRig {


    /// **eyeLeftBase** - Eyes group.
    /// Channels: static base; the eye group carries lid scaleY + pupil offset.
    /// Left eye base (the iris oval, section 2.1 eye landmark).
    public static let eyeLeftBase: Path = Path { p in
        p.move(to: CGPoint(x: 480.000, y: 390.000))
        p.addCurve(
            to: CGPoint(x: 430.000, y: 446.000),
            control1: CGPoint(x: 480.000, y: 420.928),
            control2: CGPoint(x: 457.614, y: 446.000))
        p.addCurve(
            to: CGPoint(x: 380.000, y: 390.000),
            control1: CGPoint(x: 402.386, y: 446.000),
            control2: CGPoint(x: 380.000, y: 420.928))
        p.addCurve(
            to: CGPoint(x: 430.000, y: 334.000),
            control1: CGPoint(x: 380.000, y: 359.072),
            control2: CGPoint(x: 402.386, y: 334.000))
        p.addCurve(
            to: CGPoint(x: 480.000, y: 390.000),
            control1: CGPoint(x: 457.614, y: 334.000),
            control2: CGPoint(x: 480.000, y: 359.072))
        p.closeSubpath()
    }

    /// **eyeLeftPupil** - Eyes group.
    /// Channels: pupil offset (gaze, clamped to 30% of eye radius - section 2.4).
    /// Left pupil at its neutral, centered pose; gaze offsets apply as render-time transforms (R1).
    public static let eyeLeftPupil: Path = Path { p in
        p.move(to: CGPoint(x: 453.000, y: 390.000))
        p.addCurve(
            to: CGPoint(x: 430.000, y: 415.000),
            control1: CGPoint(x: 453.000, y: 403.807),
            control2: CGPoint(x: 442.703, y: 415.000))
        p.addCurve(
            to: CGPoint(x: 407.000, y: 390.000),
            control1: CGPoint(x: 417.297, y: 415.000),
            control2: CGPoint(x: 407.000, y: 403.807))
        p.addCurve(
            to: CGPoint(x: 430.000, y: 365.000),
            control1: CGPoint(x: 407.000, y: 376.193),
            control2: CGPoint(x: 417.297, y: 365.000))
        p.addCurve(
            to: CGPoint(x: 453.000, y: 390.000),
            control1: CGPoint(x: 442.703, y: 365.000),
            control2: CGPoint(x: 453.000, y: 376.193))
        p.closeSubpath()
    }

    /// **eyeLeftLid** - Eyes group.
    /// Channels: lid scaleY (blink/aperture), anchored at the eye's top.
    /// Left lid - the pre-built upper-lid half-oval; at rest it sits above the pupil line and trims only the eye's top arc (calm aperture). Blink and aperture scale it over the base, never re-tessellate (R1).
    public static let eyeLeftLid: Path = Path { p in
        p.move(to: CGPoint(x: 378.000, y: 360.000))
        p.addCurve(
            to: CGPoint(x: 430.000, y: 304.000),
            control1: CGPoint(x: 378.000, y: 329.072),
            control2: CGPoint(x: 401.281, y: 304.000))
        p.addCurve(
            to: CGPoint(x: 482.000, y: 360.000),
            control1: CGPoint(x: 458.719, y: 304.000),
            control2: CGPoint(x: 482.000, y: 329.072))
        p.closeSubpath()
    }

    /// **eyeRightBase** - Eyes group.
    /// Channels: static base; the eye group carries lid scaleY + pupil offset.
    /// Right eye base (the iris oval, section 2.1 eye landmark).
    public static let eyeRightBase: Path = Path { p in
        p.move(to: CGPoint(x: 620.000, y: 390.000))
        p.addCurve(
            to: CGPoint(x: 570.000, y: 446.000),
            control1: CGPoint(x: 620.000, y: 420.928),
            control2: CGPoint(x: 597.614, y: 446.000))
        p.addCurve(
            to: CGPoint(x: 520.000, y: 390.000),
            control1: CGPoint(x: 542.386, y: 446.000),
            control2: CGPoint(x: 520.000, y: 420.928))
        p.addCurve(
            to: CGPoint(x: 570.000, y: 334.000),
            control1: CGPoint(x: 520.000, y: 359.072),
            control2: CGPoint(x: 542.386, y: 334.000))
        p.addCurve(
            to: CGPoint(x: 620.000, y: 390.000),
            control1: CGPoint(x: 597.614, y: 334.000),
            control2: CGPoint(x: 620.000, y: 359.072))
        p.closeSubpath()
    }

    /// **eyeRightPupil** - Eyes group.
    /// Channels: pupil offset (gaze, clamped to 30% of eye radius - section 2.4).
    /// Right pupil at its neutral, centered pose; gaze offsets apply as render-time transforms (R1).
    public static let eyeRightPupil: Path = Path { p in
        p.move(to: CGPoint(x: 593.000, y: 390.000))
        p.addCurve(
            to: CGPoint(x: 570.000, y: 415.000),
            control1: CGPoint(x: 593.000, y: 403.807),
            control2: CGPoint(x: 582.703, y: 415.000))
        p.addCurve(
            to: CGPoint(x: 547.000, y: 390.000),
            control1: CGPoint(x: 557.297, y: 415.000),
            control2: CGPoint(x: 547.000, y: 403.807))
        p.addCurve(
            to: CGPoint(x: 570.000, y: 365.000),
            control1: CGPoint(x: 547.000, y: 376.193),
            control2: CGPoint(x: 557.297, y: 365.000))
        p.addCurve(
            to: CGPoint(x: 593.000, y: 390.000),
            control1: CGPoint(x: 582.703, y: 365.000),
            control2: CGPoint(x: 593.000, y: 376.193))
        p.closeSubpath()
    }

    /// **eyeRightLid** - Eyes group.
    /// Channels: lid scaleY (blink/aperture), anchored at the eye's top.
    /// Right lid - the pre-built upper-lid half-oval, resting above the pupil line like the left.
    public static let eyeRightLid: Path = Path { p in
        p.move(to: CGPoint(x: 518.000, y: 360.000))
        p.addCurve(
            to: CGPoint(x: 570.000, y: 304.000),
            control1: CGPoint(x: 518.000, y: 329.072),
            control2: CGPoint(x: 541.281, y: 304.000))
        p.addCurve(
            to: CGPoint(x: 622.000, y: 360.000),
            control1: CGPoint(x: 598.719, y: 304.000),
            control2: CGPoint(x: 622.000, y: 329.072))
        p.closeSubpath()
    }
}
