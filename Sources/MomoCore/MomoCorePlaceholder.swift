import Foundation

/// Placeholder anchor for the `MomoCore` target (EPIC-002).
///
/// `MomoCore` will own the domain types, the pure Pet State Engine, the quest
/// generator/cascade and the DisplayState/CharacterDisplayState derivations
/// (05-technical-architecture §2.1, EPIC-003/004). Until then this symbol only
/// proves the target exists, compiles with Foundation-only imports (D-R1), and
/// is importable by its dependents. Replaced by real domain sources in EPIC-003.
public enum MomoCorePlaceholder {
    /// Marks the module as the EPIC-002 placeholder shell.
    public static let isPlaceholder = true
}
