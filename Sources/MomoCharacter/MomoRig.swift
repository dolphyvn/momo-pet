import SwiftUI

/// Namespace anchors for the generated character geometry — the §8.4 naming
/// law's Swift side (`MomoRig.earLeft`, `MomoRig.eyeLeftPupil`, …; room and
/// props grouped under `MomoRoom` / `MomoProps`, implementing the bundled
/// data names `momo.room.base` / `momo.room.pom`).
///
/// HAND-WRITTEN FILE — the only non-generated file of the geometry layer.
/// Every `MomoRig+*.swift`, `MomoRoom.swift` and `MomoProps.swift` file is
/// pipeline output carrying the "GENERATED FILE — DO NOT EDIT" header; edit
/// the parametric source (`Tools/character-pipeline/parts.py`) and re-run
/// `python3 Tools/character-pipeline/generate.py` instead. Geometry is
/// colorless (R4): these constants carry shapes only — the §8.4 token slots
/// are applied at render time (EPIC-006 TASK-026+).
///
/// Rig rules the constants are bound by (04 §2.2): R1 transform-only motion
/// on these pre-built layers (pose shapes are crossfaded, never
/// re-tessellated), R2 one continuous creature, R3 every channel pausable
/// through the single CharacterClock (TASK-026), R4 token colors only.
public enum MomoRig {
    // Members are the generated `Path` constants in `MomoRig+<Group>.swift`
    // (Body, Head, Ears, Tail, Eyes, FaceDetails, FrontPaws, LODGlance,
    // Glyph).
}

/// The static room scene (§8.5): floor/rug/window (`base`) and the hanging
/// pom decor (`pom`). Members are the generated constants in
/// `MomoRoom.swift`.
public enum MomoRoom {
    // Generated `Path` constants live in `MomoRoom.swift`.
}

/// The four interaction-scoped props (§2.2 props row): food, blanket, and
/// the two moment-scoped sparkles. Members are the generated constants in
/// `MomoProps.swift`.
public enum MomoProps {
    // Generated `Path` constants live in `MomoProps.swift`.
}
