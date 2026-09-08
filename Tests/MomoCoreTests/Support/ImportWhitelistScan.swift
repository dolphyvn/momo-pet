import Foundation

/// D-R1 import-whitelist scan (05 §10.2; TASK-010 Requirement 4).
///
/// Pure text functions: no filesystem access, no subprocesses — the fixture
/// self-tests feed literal source strings, and the real-tree test supplies the
/// `Sources/MomoCore` file contents read via `TestRepo`. The scan fails loudly
/// on any `import` outside the whitelist, closing D-R1's SwiftUI residual that
/// the macOS build alone cannot catch (SwiftUI exists on macOS; 05 §2.3).
enum ImportWhitelistScan {

    /// Whitelist for `MomoCore` sources (D-R1, 05 §2.3). Committed and
    /// documented; every entry carries a one-line rationale:
    /// - "Foundation": D-R1 names Foundation as `MomoCore`'s single permitted
    ///   import — everything not on this list violates it. Swift's standard
    ///   library (incl. `Swift` itself) needs no import statement.
    static let momoCoreWhitelist: Set<String> = [
        "Foundation",
    ]

    /// One import outside the whitelist, attributed to its source file.
    struct Violation: Equatable {
        let file: String
        let module: String
    }

    /// Scans the given files and returns every whitelisted-module violation,
    /// sorted by (file, module) for stable, deterministic reporting.
    static func violations(
        files: [(name: String, contents: String)],
        whitelist: Set<String>
    ) -> [Violation] {
        files
            .flatMap { file in
                importedModules(in: strippingComments(from: file.contents))
                    .subtracting(whitelist)
                    .sorted()
                    .map { Violation(file: file.name, module: $0) }
            }
            .sorted { ($0.file, $0.module) < ($1.file, $1.module) }
    }

    /// Extracts the imported module names from comment-stripped source text.
    ///
    /// Handles `import Module`, `@testable import Module`,
    /// `@_exported import Module`, and the scoped forms
    /// (`import struct Foundation.Date` — the module is the first `.`-separated
    /// identifier; the declaration keyword is skipped).
    static func importedModules(in source: String) -> Set<String> {
        let declarationKeywords: Set<String> = [
            "struct", "class", "enum", "protocol", "func",
            "var", "let", "typealias", "extension", "operator", "precedencegroup",
        ]
        var modules: Set<String> = []
        for rawLine in source.split(separator: "\n", omittingEmptySubsequences: false) {
            var tokens = rawLine.split(whereSeparator: \.isWhitespace).map(String.init)
            if tokens.first == "@testable" || tokens.first == "@_exported" {
                tokens.removeFirst()
            }
            guard tokens.first == "import" else { continue }
            var name = tokens.count > 1 ? tokens[1] : ""
            if declarationKeywords.contains(name), tokens.count > 2 {
                name = tokens[2]
            }
            if let head = name.split(separator: ".").first, !head.isEmpty {
                modules.insert(String(head))
            }
        }
        return modules
    }

    /// Removes `//` line comments and `/* */` block comments while leaving
    /// string literals untouched, so a quoted `"https://…"` cannot mute the
    /// rest of its line and a commented-out `// import UIKit` cannot fake a
    /// violation. Deliberately conservative: only real (non-literal) text is
    /// stripped, so the scanner can only over-report. Known model limit: a
    /// same-line `; import X` after a statement is not recognized (REVIEW-TASK-010
    /// NITPICK-2); imports at line start — the effectively universal real-world
    /// form — are always caught.
    static func strippingComments(from source: String) -> String {
        enum State { case normal, lineComment, blockComment, stringLiteral }
        var output = ""
        output.reserveCapacity(source.count)
        var state = State.normal
        var index = source.startIndex
        while index < source.endIndex {
            let character = source[index]
            let next = source.index(after: index)
            let hasNext = next < source.endIndex
            let nextCharacter = hasNext ? source[next] : nil
            switch state {
            case .normal:
                if character == "/", nextCharacter == "/" {
                    state = .lineComment
                    index = source.index(next, offsetBy: 1)
                    continue
                }
                if character == "/", nextCharacter == "*" {
                    output.append(" ")
                    state = .blockComment
                    index = source.index(next, offsetBy: 1)
                    continue
                }
                if character == "\"" {
                    state = .stringLiteral
                }
                output.append(character)
                index = next
            case .stringLiteral:
                if character == "\\" {
                    if let nextCharacter {
                        output.append(character)
                        output.append(nextCharacter)
                        index = source.index(next, offsetBy: 1)
                        continue
                    }
                }
                if character == "\"" {
                    state = .normal
                }
                output.append(character)
                index = next
            case .lineComment:
                if character == "\n" {
                    state = .normal
                    output.append(character)
                }
                index = next
            case .blockComment:
                if character == "*", nextCharacter == "/" {
                    state = .normal
                    index = source.index(next, offsetBy: 1)
                    continue
                }
                if character == "\n" {
                    output.append(character)
                }
                index = next
            }
        }
        return output
    }
}
