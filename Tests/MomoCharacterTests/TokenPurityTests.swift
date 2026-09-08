import Foundation
import Testing

/// Token-purity scan (TASK-011 AC-2 / R4: hex values live only in the token
/// files — "everything downstream resolves tokens"). Scans every Swift source
/// under `Sources/` and `Apps/` for hex color literals; only the two palette
/// files may contain them. Non-vacuous by construction: the allowlisted
/// palette files must themselves contain hex literals, and the scanned tree
/// must be non-trivial.
@Suite("Token purity (R4: hex only in the palette files)")
struct TokenPurityTests {

    /// The only files where hex color literals are permitted (the dispatch's
    /// "hex allowed ONLY in the token file(s)").
    private static let paletteFiles: Set<String> = [
        "Sources/MomoCharacter/MomoCharacterPalette.swift",
        "Sources/MomoCharacter/MomoUIColors.swift",
    ]

    /// 0x… or #… followed by six or more hex digits (6+ so 0xRRGGBBAA also
    /// trips), not preceded by an identifier character. Lookbehind is ICU
    /// (NSRegularExpression) — supported.
    private static let hexLiteral = try! NSRegularExpression(
        pattern: "(?<![0-9A-Za-z])(?:0x|#)[0-9A-Fa-f]{6,}"
    )

    @Test("no hex color literal outside the two palette files")
    func hexLiteralsConfinedToPaletteFiles() throws {
        let files = try RepoTree.packageSources() + RepoTree.appSources()
        #expect(files.count > 10, "scanned tree is trivially small — check RepoTree anchors")

        var violations: [String] = []
        var paletteFileHits = 0
        for file in files {
            let range = NSRange(file.contents.startIndex..., in: file.contents)
            let matches = Self.hexLiteral.numberOfMatches(in: file.contents, range: range)
            if Self.paletteFiles.contains(file.name) {
                paletteFileHits += matches
            } else if matches > 0 {
                violations.append("\(file.name): \(matches) hex literal(s)")
            }
        }
        #expect(
            violations.isEmpty,
            "R4 violation — hex color literals outside \(Self.paletteFiles.sorted()): \(violations)"
        )
        // Non-vacuity: the palettes genuinely hold the literals.
        #expect(paletteFileHits >= 2, "palette files contain no hex literals — purity scan is vacuous")
        #expect(Self.paletteFiles.allSatisfy { name in files.contains { $0.name == name } },
                "a palette file is missing from the scanned tree")
    }
}
