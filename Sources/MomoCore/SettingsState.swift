import Foundation

/// Settings (Phase 1 per FR-19 + 04 §11: NO sound toggle, NO audio)
/// (05-technical-architecture §3.1).
///
/// All properties are `let`: value semantics, immutable by construction —
/// persistence produces a new value on each write (EPIC-005).
public struct SettingsState: Equatable, Sendable {

    /// Written atomically at the Enter tap (UX S3).
    public let onboardingComplete: Bool

    /// Syncs to the Watch in the snapshot (UX-13).
    public let hapticsEnabled: Bool

    public init(onboardingComplete: Bool, hapticsEnabled: Bool) {
        self.onboardingComplete = onboardingComplete
        self.hapticsEnabled = hapticsEnabled
    }
}
