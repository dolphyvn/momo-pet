import Foundation
import Testing
@testable import MomoCharacter

/// Standing tests over the shipped String Catalog (TASK-011 Requirements 2
/// and 4). These run against the real file in the repo tree — they assert the
/// catalog exists (never vacuous), parses, exposes all three `momo.line.*`
/// namespaces, keeps every key inside the approved namespace grammar, and
/// marks placeholder entries per the documented convention.
/// (Tone over VALUES is the TASK-010 banned-vocabulary scan's job — it now
/// scans this same file non-vacuously; not duplicated here.)
@Suite("String Catalog scaffolding (momo.line.*)")
struct MomoCatalogScaffoldingTests {

    /// The three placeholder entries seeded to prove lookup — the whole seed
    /// set; real tone-guide pools are owned by the engine/read-model tasks.
    private static let placeholderKeys = [
        "momo.line.day.00",
        "momo.line.moment.00",
        "momo.line.react.touch.00",
    ]

    @Test("the shipped catalog is discovered in the real tree (never vacuous)")
    func shippedCatalogIsDiscovered() throws {
        let catalogs = try RepoTree.appStringCatalogs()
        #expect(catalogs.count == 1,
                "expected exactly the shared app catalog; found \(catalogs.map(\.name))")
        #expect(catalogs.first?.name == "Apps/Shared/MomoCopy.xcstrings")
    }

    @Test("the catalog parses and carries catalog fundamentals")
    func catalogParses() throws {
        let root = try Self.loadCatalogRoot()
        #expect(root["sourceLanguage"] as? String == "en")
        #expect(root["version"] as? String == "1.0")
        #expect(root["strings"] != nil)
    }

    @Test("all three copy namespaces are present")
    func allThreeNamespacesPresent() throws {
        let keys = try Self.catalogKeys()
        #expect(keys.contains { CopyKey.isInApprovedNamespace($0) && $0.contains(".react.") },
                "no momo.line.react.<family>.<nn> key")
        #expect(keys.contains { CopyKey.isInApprovedNamespace($0) && $0.contains("momo.line.moment.") },
                "no momo.line.moment.<nn> key")
        #expect(keys.contains { key in
            CopyKey.isInApprovedNamespace(key) && !key.contains(".react.") && !key.contains("momo.line.moment.")
        }, "no visual body-copy key (momo.line.<slot>.<nn>)")
    }

    @Test("every catalog key stays inside the approved namespace grammar (INV-11)")
    func everyKeyIsInApprovedNamespace() throws {
        for key in try Self.catalogKeys() {
            #expect(CopyKey.isInApprovedNamespace(key), "'\(key)' is outside the approved namespaces")
        }
    }

    @Test("placeholder entries are present and marked per the convention")
    func placeholdersAreMarked() throws {
        let strings = try Self.stringsDictionary()
        for key in Self.placeholderKeys {
            guard let entry = strings[key] as? [String: Any] else {
                Issue.record("placeholder key '\(key)' missing from the shipped catalog")
                continue
            }
            #expect(key.hasSuffix(".00"), "'\(key)': placeholder index must be 00 (real pools start at 01)")
            #expect(entry["extractionState"] as? String == "manual",
                    "'\(key)': hand-authored entries are extractionState manual")
            let comment = entry["comment"] as? String
            #expect(comment?.hasPrefix("PLACEHOLDER") == true,
                    "'\(key)': placeholder entries carry a PLACEHOLDER comment")
        }
        #expect(strings.count == Self.placeholderKeys.count,
                "the seed set is exactly the three placeholders; unlisted keys need their own task")
    }

    @Test("every key carries a non-empty en value")
    func everyKeyHasAValue() throws {
        let strings = try Self.stringsDictionary()
        #expect(!strings.isEmpty)
        for (key, entry) in strings {
            guard let entry = entry as? [String: Any] else {
                Issue.record("'\(key)' entry is not a dictionary")
                continue
            }
            let localizations = entry["localizations"] as? [String: Any]
            let en = localizations?["en"] as? [String: Any]
            let unit = en?["stringUnit"] as? [String: Any]
            let value = unit?["value"] as? String
            #expect(!(value ?? "").isEmpty, "'\(key)' has no en value")
        }
    }

    // MARK: - Parsing helpers

    /// Local error for malformed catalog structure (keeps the failure loud and
    /// attributed without leaning on SDK error-code spelling).
    private struct CatalogStructureError: Error, CustomStringConvertible {
        let description: String
    }

    private static func loadCatalogRoot() throws -> [String: Any] {
        let catalogs = try RepoTree.appStringCatalogs()
        guard let catalog = catalogs.first else {
            throw CatalogStructureError(description: "Apps/Shared/MomoCopy.xcstrings not found in the repo tree")
        }
        let data = try Data(contentsOf: catalog.url)
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw CatalogStructureError(description: "\(catalog.name): not a JSON dictionary")
        }
        return root
    }

    private static func stringsDictionary() throws -> [String: Any] {
        let root = try loadCatalogRoot()
        guard let strings = root["strings"] as? [String: Any] else {
            throw CatalogStructureError(description: "no \"strings\" dictionary at catalog root")
        }
        return strings
    }

    private static func catalogKeys() throws -> [String] {
        try Array(stringsDictionary().keys).sorted()
    }
}
