import Foundation
import Testing

// MARK: - CatalogCopyLawTests — the 12-word copy law over the shipped
// catalog (TASK-033 Requirement 5; 04-character-system §10.1 rule 1; OBS-2)

/// OBS-2's catalog-era obligation: the 12-word hard max is now REAL, so a
/// scanner pins it against the shipped file (the TASK-010 banned-vocabulary
/// scan's sibling — structure/tone laws there, LENGTH law here). Scope per
/// OBS-2: the VISUAL BODY-COPY classes `momo.line.<slot>.<nn>` for the four
/// time slots plus `momo.line.moment` and — by TASK-033's disclosure — the
/// three return greetings, which render in the same single-line visual slot
/// on Home. TASK-035's disclosure extends the law to the care-moment
/// visuals (`momo.line.care-moment.01–03` — the contextual line's top
/// tier) and to the SPOKEN react pools (UX-8: announced under VoiceOver —
/// the ear deserves the same length law as the eye). A line longer than 12
/// whitespace-separated words fails with the key attributed. The word
/// COUNT is measured strictly (whitespace tokens — punctuation and the
/// ellipsis are not words), so the pin cannot be gamed by joining with
/// commas.
@Suite("Catalog copy law — 12-word max over the visual and spoken line classes (TASK-033 + TASK-035)")
struct CatalogCopyLawTests {

    /// The scanned classes: the four time slots (ten lines each), the moment
    /// placeholder (same visual class), the greetings (disclosed
    /// strict — see the header), the care-moment visuals, and the four
    /// spoken react pools.
    private static let scannedPattern =
        "^momo\\.line\\.(morning|day|evening|night|moment|care-moment)\\.\\d{2}$"
    private static let greetingPattern =
        "^momo\\.line\\.greeting\\.\\d{2}$"
    private static let reactPattern =
        "^momo\\.line\\.react\\.(touch|feed|play|care)\\.\\d{2}$"

    /// The hard max (04 §10.1 rule 1: ≤ 8 typical, ≤ 12 absolute).
    private static let maxWords = 12

    /// `Issue.record` wants an Error — the violations ride one.
    private struct CopyLawViolations: Error, CustomStringConvertible {
        let descriptions: [String]
        var description: String { descriptions.joined(separator: "\n") }
    }

    @Test("every visual and spoken line class stays within the 12-word hard max")
    func twelveWordMaxOverVisualClasses() throws {
        var scanned = 0
        var violations: [String] = []
        for (key, value) in try Self.scannedEntries() {
            scanned += 1
            let words = value.split(whereSeparator: { $0.isWhitespace }).count
            if words > Self.maxWords {
                violations.append("\(key): \(words) words — '\(value)'")
            }
        }
        // Never vacuous: the TASK-033 landing's 40 slot lines + the moment
        // placeholder + the 3 greetings, TASK-035's 3 care-moment visuals,
        // and the 23 react lines (TASK-034's 5 touch + TASK-035's 18) are
        // all in scope.
        #expect(scanned == 70, "expected 70 scanned lines (40 slots + 1 moment + 3 greetings + 3 care-moments + 23 react); found \(scanned) — a new visual or spoken class needs this law's scope review")
        if !violations.isEmpty {
            Issue.record(
                CopyLawViolations(descriptions: violations),
                "the 12-word hard max failed — see the recorded violations"
            )
        }
        #expect(violations.isEmpty)
    }

    @Test("every scanned PRODUCT line carries actual copy, not a template remnant")
    func scannedLinesAreRealCopy() throws {
        for (key, value) in try Self.scannedEntries() {
            // The moment namespace's placeholder seed is exempt — its
            // PLACEHOLDER marking is the scaffolding suite's pin; this law
            // governs length, and the seed must stay scannable until the
            // moment surfaces land.
            guard !key.hasPrefix("momo.line.moment.") else { continue }
            #expect(!value.lowercased().contains("placeholder"), "'\(key)' still reads as a placeholder")
            #expect(value.contains(" "), "'\(key)' is suspiciously terse for a body-copy line: '\(value)'")
        }
    }

    // MARK: - Parsing helpers

    private struct CatalogStructureError: Error, CustomStringConvertible {
        let description: String
    }

    /// (key, en value) pairs for the scanned classes, from the real repo
    /// tree (the `RepoTree.appStringCatalogs` discovery — never vacuous).
    private static func scannedEntries() throws -> [(key: String, value: String)] {
        let catalogs = try RepoTree.appStringCatalogs()
        guard let catalog = catalogs.first else {
            throw CatalogStructureError(description: "Apps/Shared/MomoCopy.xcstrings not found in the repo tree")
        }
        let data = try Data(contentsOf: catalog.url)
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let strings = root["strings"] as? [String: Any] else {
            throw CatalogStructureError(description: "\(catalog.name): not a String Catalog shape")
        }
        var entries: [(key: String, value: String)] = []
        for (key, entryAny) in strings {
            let inScope = key.range(of: scannedPattern, options: .regularExpression) != nil
                || key.range(of: greetingPattern, options: .regularExpression) != nil
                || key.range(of: reactPattern, options: .regularExpression) != nil
            guard inScope, let entry = entryAny as? [String: Any],
                  let localizations = entry["localizations"] as? [String: Any],
                  let en = localizations["en"] as? [String: Any],
                  let unit = en["stringUnit"] as? [String: Any],
                  let value = unit["value"] as? String else { continue }
            entries.append((key: key, value: value))
        }
        return entries.sorted { $0.key < $1.key }
    }
}
