import Foundation
import SwiftUI

import MomoCharacter

/// Compile-pinned catalog of the generated geometry layer (TASK-025).
///
/// The `constant` table references every generated `Path` constant by its
/// §8.4 name: renaming or deleting any constant breaks compilation of this
/// file, which is the strongest possible inventory pin. The per-file name
/// lists mirror the pipeline's emission order (Tools/character-pipeline/
/// parts.py `parts_by_file()`) and are re-derived from the committed files
/// in MomoRigInventoryTests — the two must agree.
enum GeneratedRigCatalog {

    // MARK: - The 44 generated constants, compile-pinned

    /// Full rig (21 constants / 19 counted parts: the mouth slot ships 3
    /// pre-built poses; ADR-001 adds the two hind feet to §2.2's 17).
    static let constant: [String: Path] = [
        "body": MomoRig.body,
        "bellyPatch": MomoRig.bellyPatch,
        "hindFootLeft": MomoRig.hindFootLeft,
        "hindFootRight": MomoRig.hindFootRight,
        "head": MomoRig.head,
        "earLeft": MomoRig.earLeft,
        "earRight": MomoRig.earRight,
        "tail": MomoRig.tail,
        "eyeLeftBase": MomoRig.eyeLeftBase,
        "eyeLeftPupil": MomoRig.eyeLeftPupil,
        "eyeLeftLid": MomoRig.eyeLeftLid,
        "eyeRightBase": MomoRig.eyeRightBase,
        "eyeRightPupil": MomoRig.eyeRightPupil,
        "eyeRightLid": MomoRig.eyeRightLid,
        "mouthNeutral": MomoRig.mouthNeutral,
        "mouthEat": MomoRig.mouthEat,
        "mouthRefuse": MomoRig.mouthRefuse,
        "cheekLeft": MomoRig.cheekLeft,
        "cheekRight": MomoRig.cheekRight,
        "pawLeft": MomoRig.pawLeft,
        "pawRight": MomoRig.pawRight,
        // LOD-glance variant (11 constants).
        "lodBody": MomoRig.lodBody,
        "lodBellyPatch": MomoRig.lodBellyPatch,
        "lodHead": MomoRig.lodHead,
        "lodEarLeft": MomoRig.lodEarLeft,
        "lodEarRight": MomoRig.lodEarRight,
        "lodTail": MomoRig.lodTail,
        "lodHindFootLeft": MomoRig.lodHindFootLeft,
        "lodHindFootRight": MomoRig.lodHindFootRight,
        "lodEyeLeft": MomoRig.lodEyeLeft,
        "lodEyeRight": MomoRig.lodEyeRight,
        "lodPawPair": MomoRig.lodPawPair,
        // Glyph variant (3 constants).
        "glyphSilhouette": MomoRig.glyphSilhouette,
        "glyphEyeLeft": MomoRig.glyphEyeLeft,
        "glyphEyeRight": MomoRig.glyphEyeRight,
        // Room (5 constants; implements momo.room.base / momo.room.pom).
        "floor": MomoRoom.floor,
        "rug": MomoRoom.rug,
        "window": MomoRoom.window,
        "pomString": MomoRoom.pomString,
        "pomPuff": MomoRoom.pomPuff,
        // Props (4 constants).
        "food": MomoProps.food,
        "blanket": MomoProps.blanket,
        "sparkleA": MomoProps.sparkleA,
        "sparkleB": MomoProps.sparkleB,
    ]

    // MARK: - Emission layout (mirrors parts_by_file())

    /// The 11 generated Swift files, repo-relative, in emission order.
    static let generatedFiles: [String] = [
        "Sources/MomoCharacter/MomoRig+Body.swift",
        "Sources/MomoCharacter/MomoRig+Head.swift",
        "Sources/MomoCharacter/MomoRig+Ears.swift",
        "Sources/MomoCharacter/MomoRig+Tail.swift",
        "Sources/MomoCharacter/MomoRig+Eyes.swift",
        "Sources/MomoCharacter/MomoRig+FaceDetails.swift",
        "Sources/MomoCharacter/MomoRig+FrontPaws.swift",
        "Sources/MomoCharacter/MomoRig+LODGlance.swift",
        "Sources/MomoCharacter/MomoRig+Glyph.swift",
        "Sources/MomoCharacter/MomoRoom.swift",
        "Sources/MomoCharacter/MomoProps.swift",
    ]

    /// Expected `static let` names per generated file (emission order).
    static let namesByFile: [String: [String]] = [
        "Sources/MomoCharacter/MomoRig+Body.swift": [
            "body", "bellyPatch", "hindFootLeft", "hindFootRight",
        ],
        "Sources/MomoCharacter/MomoRig+Head.swift": ["head"],
        "Sources/MomoCharacter/MomoRig+Ears.swift": ["earLeft", "earRight"],
        "Sources/MomoCharacter/MomoRig+Tail.swift": ["tail"],
        "Sources/MomoCharacter/MomoRig+Eyes.swift": [
            "eyeLeftBase", "eyeLeftPupil", "eyeLeftLid",
            "eyeRightBase", "eyeRightPupil", "eyeRightLid",
        ],
        "Sources/MomoCharacter/MomoRig+FaceDetails.swift": [
            "mouthNeutral", "mouthEat", "mouthRefuse", "cheekLeft", "cheekRight",
        ],
        "Sources/MomoCharacter/MomoRig+FrontPaws.swift": ["pawLeft", "pawRight"],
        "Sources/MomoCharacter/MomoRig+LODGlance.swift": [
            "lodBody", "lodBellyPatch", "lodHead", "lodEarLeft", "lodEarRight",
            "lodTail", "lodHindFootLeft", "lodHindFootRight", "lodEyeLeft",
            "lodEyeRight", "lodPawPair",
        ],
        "Sources/MomoCharacter/MomoRig+Glyph.swift": [
            "glyphSilhouette", "glyphEyeLeft", "glyphEyeRight",
        ],
        "Sources/MomoCharacter/MomoRoom.swift": [
            "floor", "rug", "window", "pomString", "pomPuff",
        ],
        "Sources/MomoCharacter/MomoProps.swift": [
            "food", "blanket", "sparkleA", "sparkleB",
        ],
    ]

    /// The generate command every GENERATED header must carry.
    static let generateCommand = "python3 Tools/character-pipeline/generate.py"

    // MARK: - File access

    static func readGeneratedFile(_ name: String) throws -> String {
        try String(contentsOf: URL(fileURLWithPath: RepoTree.repoRoot + "/" + name),
                   encoding: .utf8)
    }
}
