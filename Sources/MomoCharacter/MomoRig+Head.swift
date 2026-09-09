//
//  MomoRig+Head.swift
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


/// The Direction-C rig's Head layer group(s) (04 §2.2).
///
/// The full rig's part accounting: 04 §2.2 counts 17 parts
/// (mouth counted once as a 3-pose slot); ADR-001's Direction-C
/// delta adds the two hind feet. The mouth slot ships its three
/// pre-built poses as separate constants (R1: crossfaded, never
/// re-tessellated).

/// 1000×1000 normalized design space (04 §2.1). y-down; ground y = 1000.

extension MomoRig {


    /// **head** - Head group.
    /// Channels: rotation (tilt +/-6 deg), position (bob, lean-in), scaleY (settle squash).
    /// Round head with full cheeks (ADR-001); overlaps the body so the creature reads as one continuous form (R2).
    public static let head: Path = Path { p in
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
    }
}
