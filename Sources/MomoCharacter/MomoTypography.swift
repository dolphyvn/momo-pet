import SwiftUI

/// Typography tokens (project.md §18: Apple's system typography — no custom
/// faces absent a design-team reason; "excellent typography"). Text styles
/// keep Dynamic Type working (§20 accessibility is launch-blocking).
public enum MomoTypography {

    /// Hero moments — the M2 stage banner (04 §10.1 rule 7).
    public static let display = Font.system(.largeTitle, design: .default, weight: .semibold)

    /// Section and glance headlines (W1 status slot).
    public static let heading = Font.system(.title2, design: .default, weight: .semibold)

    /// Body copy — the few visual copy surfaces of §10.1 rule 7 (contextual
    /// line, greeting, care moments).
    public static let body = Font.system(.body, design: .default)

    /// Captions, quest footnotes, secondary hints.
    public static let caption = Font.system(.footnote, design: .default)
}
