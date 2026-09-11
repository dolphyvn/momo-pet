import Testing
import Foundation

/// Body-text contrast (TASK-039 R6; FR-20's "text contrast ≥ 4.5:1 against
/// both light and dark grounds"): the four body-text token pairs
/// (`textPrimary`/`textSecondary` over `background`/`surface`) are pinned
/// with the WCAG 2.x relative-luminance ratio, computed from the SHIPPED
/// hex values — parsed out of `MomoUIColors.swift`'s source text (the
/// structural-guard precedent: headless suites read the tree), so a token
/// edit that regresses contrast fails here, and a test-side constant that
/// drifts from the file fails here too.
///
/// The header of `MomoUIColors` documents the baselines these computations
/// must reproduce (13.57/14.64, 14.51/13.09, 5.41/6.56, 5.78/5.86) — the
/// baseline-equality legs below are the helper's own non-vacuity proof: a
/// luminance bug would drift from the documented numbers even while
/// clearing 4.5:1.
@Suite("Body-text contrast — WCAG ≥ 4.5:1 on both grounds (TASK-039 R6)")
struct MomoUIColorContrastTests {

    // MARK: The WCAG math

    /// WCAG 2.x relative luminance of an 0xRRGGBB value: sRGB channels
    /// linearized, then the 0.2126/0.7152/0.0722 luma weights.
    private func relativeLuminance(_ hex: UInt32) -> Double {
        func linearize(_ channel: Double) -> Double {
            channel <= 0.03928 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
        }
        let r = linearize(Double((hex >> 16) & 0xFF) / 255.0)
        let g = linearize(Double((hex >> 8) & 0xFF) / 255.0)
        let b = linearize(Double(hex & 0xFF) / 255.0)
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    }

    /// The WCAG contrast ratio of two luminances — (L1 + 0.05)/(L2 + 0.05)
    /// with the lighter first.
    private func contrastRatio(_ a: UInt32, _ b: UInt32) -> Double {
        let la = relativeLuminance(a)
        let lb = relativeLuminance(b)
        let lighter = max(la, lb)
        let darker = min(la, lb)
        return (lighter + 0.05) / (darker + 0.05)
    }

    // MARK: The shipped tokens, read from the source

    /// Extracts each token's `(light, dark)` hex pair from the
    /// `MomoUIColors.swift` source text — `MomoColorToken`'s hex
    /// construction is module-internal by design, so the VALUES travel
    /// through the file text, and the pin tracks the shipped palette
    /// exactly.
    private func tokenHexPairs() throws -> [String: (light: UInt32, dark: UInt32)] {
        let source = try RigDiscipline.readRigFile("Sources/MomoCharacter/MomoUIColors.swift")
        var tokens: [String: (light: UInt32, dark: UInt32)] = [:]
        for name in ["background", "surface", "textPrimary", "textSecondary"] {
            let pattern = "static let \(name) = MomoColorToken\\(light: 0x([0-9A-F]{6}), dark: 0x([0-9A-F]{6})\\)"
            guard let match = source.range(of: pattern, options: .regularExpression) else {
                Issue.record("token \(name) not found in MomoUIColors.swift — the pin reads the shipped palette and the palette moved")
                continue
            }
            let matched = source[match]
            let hexes = matched.ranges(of: /0x[0-9A-F]{6}/).map { matched[$0] }
            guard hexes.count == 2,
                  let light = UInt32(hexes[0].dropFirst(2), radix: 16),
                  let dark = UInt32(hexes[1].dropFirst(2), radix: 16)
            else {
                Issue.record("token \(name): could not parse hex pair from '\(matched)'")
                continue
            }
            tokens[name] = (light, dark)
        }
        return tokens
    }

    // MARK: The pin

    /// The four body-text pairs, each ≥ 4.5:1 on BOTH grounds — and equal
    /// to `MomoUIColors`' documented baselines (the helper's non-vacuity
    /// proof; a math bug drifts from the documented numbers).
    @Test("the four body-text pairs clear 4.5:1 on light and dark, at the documented baselines")
    func bodyTextPairsClear45OnBothGrounds() throws {
        let tokens = try tokenHexPairs()
        try #require(tokens.count == 4, "all four tokens must parse from the shipped palette")
        let documented: [String: (light: Double, dark: Double)] = [
            "textPrimary/background": (13.57, 14.64),
            "textPrimary/surface": (14.51, 13.09),
            "textSecondary/background": (5.41, 6.56),
            "textSecondary/surface": (5.78, 5.86),
        ]
        for (pair, baselines) in documented {
            let names = pair.split(separator: "/").map(String.init)
            let tokenPair = try #require(
                tokens[names[0]].flatMap { fg in tokens[names[1]].map { (fg, $0) } },
                "\(pair): both tokens must be present")
            let light = contrastRatio(tokenPair.0.light, tokenPair.1.light)
            let dark = contrastRatio(tokenPair.0.dark, tokenPair.1.dark)
            #expect(light >= 4.5, "\(pair) light: \(light) must be ≥ 4.5:1 (FR-20)")
            #expect(dark >= 4.5, "\(pair) dark: \(dark) must be ≥ 4.5:1 (FR-20)")
            #expect(abs(light - baselines.light) < 0.005,
                "\(pair) light \(light) must reproduce the documented \(baselines.light)")
            #expect(abs(dark - baselines.dark) < 0.005,
                "\(pair) dark \(dark) must reproduce the documented \(baselines.dark)")
        }
    }
}
