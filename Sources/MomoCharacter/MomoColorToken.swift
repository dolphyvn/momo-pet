import SwiftUI

/// A light/dark color token — the value type behind every color Momo renders
/// (single canonical design-system pass: project.md §18 UI + the 04 §8.4
/// character slots, 04 Appendix B item 3).
///
/// Structure is the guardrail: both variants are non-optional stored
/// properties, so "a light and a dark value exist for every token" is a
/// compile-time property, and the memberwise-style initializer is internal,
/// so new tokens can only be born inside the palette files — the only files
/// where hex literals are permitted (R4; pinned by `TokenPurityTests`).
///
/// Dark values are deliberate choices for the calm-premium intent (project.md
/// §18): warmed and dimmed for evening/bedside use, never a mechanical
/// inversion of the light values.
public struct MomoColorToken: Sendable {

    /// The light-appearance value.
    public let light: Color

    /// The dark-appearance value (deliberate, not inverted).
    public let dark: Color

    /// 0xRRGGBB construction — callable only from this module, so hex
    /// literals stay inside the two palette files.
    init(light: UInt32, dark: UInt32) {
        self.light = Color(hexRGB: light)
        self.dark = Color(hexRGB: dark)
    }

    /// Resolves the variant for a color scheme: `.dark` selects the dark
    /// value; every other scheme selects the light value.
    public func resolve(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? dark : light
    }
}

extension Color {
    /// 0xRRGGBB → opaque sRGB color (palette-file plumbing; no literals here).
    init(hexRGB value: UInt32) {
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}
