import Foundation

/// Placeholder anchor for the `MomoKit` target (EPIC-002).
///
/// `MomoKit` will own the SnapshotStore (ADR-002), the intent journal +
/// watermarks and the Watch snapshot DTOs (ADR-003) in EPIC-005
/// (05-technical-architecture §2.1). WatchConnectivity wrapper code lives in the
/// app targets by decision (ADR-005), so this module stays Foundation-only and
/// macOS-clean — exactly the property `swift test` relies on.
public enum MomoKitPlaceholder {
    /// Marks the module as the EPIC-002 placeholder shell.
    public static let isPlaceholder = true
}
