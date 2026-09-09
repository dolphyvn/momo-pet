import Foundation

/// The MomoKit discipline scans (TASK-021 Requirement 6) — pure text
/// functions over literal fixture sources, the `EnginePurityScan` mechanism
/// mirrored for the persistence era. Three families:
///
/// 1. **Ambient time** — MomoKit has NO sanctioned `Date` site (the one
///    ambient read lives in MomoCore's `SystemEngineClock`, scanner-exempted
///    THERE; MomoKit gets none). Every file is scanned unexempted.
/// 2. **Ambient paths** — the injected-directory constraint. The ONE
///    sanctioned site is `StoreRules.defaultDirectory()` (05 §5.2's
///    Application Support factory): exactly `StoreRules.swift` is exempt for
///    exactly the path family, mirroring MomoCore's per-file exemption.
/// 3. **Imports** — Foundation + MomoCore only (D-R2 + macOS headless).
///
/// Comment stripping reuses the `ImportWhitelistScan` algorithm (duplicated
/// per house test-support convention): comments are removed while string
/// literals are left untouched, so a spec citation like "see §5.2's savedAt
/// Date" in a doc comment can never fake or mute a violation.
enum MomoKitDisciplineScan {

    struct Violation: Equatable {
        let file: String
        let literal: String
    }

    /// Banned ambient-time literals. `Date(` catches `Date()`/`Date(timeIntervalSince…)`;
    /// `Date.now` catches the postfix form. MomoKit has no exemption for this
    /// family — not even `StoreRules.swift`.
    static let bannedTimeLiterals = ["Date(", "Date.now"]

    /// Banned ambient-path literals — the Foundation spellings of "compute
    /// the container from the ambient environment": home directory (both
    /// forms), the Application Support / temporary directory lookups.
    /// `StoreRules.swift` is the single documented exemption (its
    /// `defaultDirectory()` factory).
    static let bannedPathLiterals = [
        "NSHomeDirectory(",
        "homeDirectoryForCurrentUser",
        "applicationSupportDirectory",
        "NSTemporaryDirectory(",
        "temporaryDirectory",
    ]

    /// The one file exempted from the path family (and only the path family).
    static let pathExemptFileName = "StoreRules.swift"

    /// The exemption matches the bare name or any path ending in it, so both
    /// calling conventions (lastPathComponent names from `KitRepo`, relative
    /// paths from the fixtures) are served by one rule.
    private static func exemptionMatches(_ exemptName: String, in fileName: String) -> Bool {
        fileName == exemptName || fileName.hasSuffix("/" + exemptName)
    }

    /// Import whitelist for `Sources/MomoKit` (D-R2: MomoKit depends on
    /// MomoCore only; macOS-headless Foundation). Everything else violates.
    static let importWhitelist: Set<String> = ["Foundation", "MomoCore"]

    /// Ambient-time violations over the given files, comment-stripped, sorted
    /// by (file, literal) for deterministic reporting.
    static func timeViolations(files: [(name: String, contents: String)]) -> [Violation] {
        literalViolations(
            files: files,
            literals: bannedTimeLiterals,
            exemptFileNames: []
        )
    }

    /// Ambient-path violations over the given files; exactly
    /// `pathExemptFileName` is spared, and only for this family.
    static func pathViolations(files: [(name: String, contents: String)]) -> [Violation] {
        literalViolations(
            files: files,
            literals: bannedPathLiterals,
            exemptFileNames: [pathExemptFileName]
        )
    }

    /// Import violations: every `import` whose module is outside the
    /// whitelist, attributed to its file.
    static func importViolations(files: [(name: String, contents: String)]) -> [Violation] {
        files
            .flatMap { file in
                importedModules(in: strippingComments(from: file.contents))
                    .subtracting(importWhitelist)
                    .sorted()
                    .map { Violation(file: file.name, literal: $0) }
            }
            .sorted { ($0.file, $0.literal) < ($1.file, $1.literal) }
    }

    // MARK: - Internals

    private static func literalViolations(
        files: [(name: String, contents: String)],
        literals: [String],
        exemptFileNames: Set<String>
    ) -> [Violation] {
        files
            .flatMap { file -> [Violation] in
                guard !exemptFileNames.contains(where: { exemptionMatches($0, in: file.name) }) else { return [] }
                let stripped = strippingComments(from: file.contents)
                return literals.filter { stripped.contains($0) }
                    .map { Violation(file: file.name, literal: $0) }
            }
            .sorted { ($0.file, $0.literal) < ($1.file, $1.literal) }
    }

    /// Extracts imported module names — the `ImportWhitelistScan` algorithm
    /// (handles `@testable`/`@_exported` and scoped `import struct Module.X`
    /// forms; module = the first `.`-separated identifier).
    private static func importedModules(in source: String) -> Set<String> {
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
    /// string literals untouched — the `ImportWhitelistScan.strippingComments`
    /// algorithm verbatim (duplicated per test-support convention; see that
    /// file for the design notes and the documented model limit).
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
