import Foundation

/// FR-12 static tone scan (05 §10.2; TASK-010 Requirement 5).
///
/// Scans String Catalog (`.xcstrings`) values for the banned-vocabulary list of
/// `docs/design/04-character-system.md` §10.2 ("Banned vocabulary (hard list)"),
/// consumed VERBATIM and in document order — no extra terms, no missing terms.
/// A hit fails the scan (`#expect` failure ⇒ `swift test` failure), which is the
/// structural FR-12 guard (05 §4.9: guilt is structurally impossible).
///
/// Pure functions over `Data`/`String`: no filesystem access, no subprocesses.
/// The fixture self-tests feed literal catalog JSON; the real-tree test
/// enumerates the catalogs that exist today via `TestRepo` (none until
/// TASK-011 — vacuously green by design).
enum BannedVocabularyScan {

    /// One banned term. `.substring` terms match case-insensitively as
    /// substrings (deliberately aggressive — a hard list fails loudly and a
    /// human re-words any false positive). `.template` is the mechanical
    /// reading of the doc's own placeholder form.
    enum Entry: Equatable {
        case substring(String)
        /// "only X left" — the doc's X is a placeholder for a quantity word,
        /// e.g. "only 2 left", "only 3 quests left". Bounded 0–2 word gap
        /// between "only" and "left".
        case template(display: String, pattern: String)

        /// The term exactly as it appears in 04 §10.2.
        var display: String {
            switch self {
            case .substring(let term): return term
            case .template(let display, _): return display
            }
        }

        /// The mechanical matcher for the term.
        var pattern: String {
            switch self {
            case .substring(let term): return NSRegularExpression.escapedPattern(for: term)
            case .template(_, let pattern): return pattern
            }
        }

        func matches(in value: String) -> Bool {
            // Typographic apostrophes normalize to ASCII before matching, so
            // copy like "Don’t forget" is caught although the list entry uses
            // the doc's ASCII apostrophe (normalization of the haystack is a
            // matching rule, not an extra banned term).
            let normalized = value.replacingOccurrences(of: "\u{2019}", with: "'")
            return normalized.range(
                of: pattern,
                options: [.regularExpression, .caseInsensitive]
            ) != nil
        }
    }

    /// The banned list, verbatim from 04-character-system §10.2, in document order:
    /// "forgot · lonely · sad · waiting for you · hurry · don't forget · last chance ·
    ///  only X left · streak · miss out · failed · penalty"
    /// ("Missed you" is the single sanctioned absence reference, per PRD §3.3 —
    /// it is NOT on the list and must not be added.)
    static let entries: [Entry] = [
        .substring("forgot"),
        .substring("lonely"),
        .substring("sad"),
        .substring("waiting for you"),
        .substring("hurry"),
        .substring("don't forget"),
        .substring("last chance"),
        .template(display: "only X left", pattern: "only(?:\\s+\\S+){0,2}\\s+left"),
        .substring("streak"),
        .substring("miss out"),
        .substring("failed"),
        .substring("penalty"),
    ]

    /// One banned-term hit (or one unparsable catalog), attributed for reporting.
    struct Violation: Equatable {
        let file: String
        let catalogKey: String
        let language: String
        let term: String
        let value: String
    }

    /// Parses String Catalog JSON and returns every banned-term hit in any
    /// localization value, sorted for deterministic reporting. Only values are
    /// scanned (TASK-010 Requirement 5: "appears in any value") — catalog keys
    /// are developer identifiers, not user-facing copy. A catalog that does not
    /// parse yields a single unparsable violation: the scan fails loudly rather
    /// than silently skipping a file.
    static func violations(inCatalogJSON data: Data, file: String) -> [Violation] {
        let root: Any
        do {
            root = try JSONSerialization.jsonObject(with: data, options: [])
        } catch {
            return [Violation(
                file: file,
                catalogKey: "<catalog>",
                language: "-",
                term: "<unparsable catalog>",
                value: error.localizedDescription
            )]
        }
        guard let dictionary = root as? [String: Any],
              let strings = dictionary["strings"] as? [String: Any] else {
            return [Violation(
                file: file,
                catalogKey: "<catalog>",
                language: "-",
                term: "<unparsable catalog>",
                value: "no \"strings\" dictionary at the catalog root"
            )]
        }
        var found: [Violation] = []
        for (key, entry) in strings.sorted(by: { $0.key < $1.key }) {
            var values: [(language: String, value: String)] = []
            collectStringUnitValues(in: entry, language: "-", into: &values)
            for (language, value) in values {
                for term in entries where term.matches(in: value) {
                    found.append(Violation(
                        file: file,
                        catalogKey: key,
                        language: language,
                        term: term.display,
                        value: value
                    ))
                }
            }
        }
        return found.sorted {
            ($0.file, $0.catalogKey, $0.language, $0.term) < ($1.file, $1.catalogKey, $1.language, $1.term)
        }
    }

    // MARK: - Catalog walking

    /// Recursively collects every `stringUnit.value` string under `node`,
    /// best-effort attributing each to its language tag (the `localizations`
    /// dictionary is keyed by language; `variations` nest stringUnits deeper).
    private static func collectStringUnitValues(
        in node: Any,
        language: String,
        into values: inout [(language: String, value: String)]
    ) {
        if let dictionary = node as? [String: Any] {
            if let stringUnit = dictionary["stringUnit"] as? [String: Any],
               let value = stringUnit["value"] as? String {
                values.append((language: language, value: value))
            }
            for (key, child) in dictionary where key != "stringUnit" {
                collectStringUnitValues(in: child, language: childLanguage(key, current: language), into: &values)
            }
        } else if let array = node as? [Any] {
            for child in array {
                collectStringUnitValues(in: child, language: language, into: &values)
            }
        }
    }

    /// Keys that look like BCP-47 language tags ("en", "de-CH") become the
    /// attribution language for their subtree; anything else inherits.
    private static func childLanguage(_ key: String, current: String) -> String {
        let parts = key.split(separator: "-")
        guard let first = parts.first, (2...3).contains(first.count),
              first.allSatisfy(\.isLetter) else {
            return current
        }
        let remainderIsTagLike = parts.dropFirst().allSatisfy { part in
            part.allSatisfy(\.isLetter) || part.allSatisfy(\.isNumber)
        }
        return remainderIsTagLike ? key : current
    }
}
