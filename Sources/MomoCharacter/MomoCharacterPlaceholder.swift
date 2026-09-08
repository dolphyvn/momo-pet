import SwiftUI

/// Placeholder anchor for the `MomoCharacter` target (EPIC-002).
///
/// The rig, CharacterClock, idle sequencer and LOD tiers land here in EPIC-006
/// (04-character-system §8, 05-technical-architecture §2.2). This file exercises
/// the one D-R2-permitted extra edge — `MomoCharacter` may import MomoCore and
/// SwiftUI — so the edge is proven to compile and link on macOS (`swift test`)
/// and on both app-target SDKs. The D-R1 SwiftUI residual this creates for
/// `MomoCore` itself is closed mechanically by TASK-010's import-whitelist scan.
public enum MomoCharacterPlaceholder {
    /// Marks the module as the EPIC-002 placeholder shell.
    public static let isPlaceholder = true
}

/// Inert view proving the SwiftUI edge compiles and links. Replaced by the rig in EPIC-006.
struct MomoCharacterPlaceholderView: View {
    var body: some View {
        EmptyView()
    }
}
