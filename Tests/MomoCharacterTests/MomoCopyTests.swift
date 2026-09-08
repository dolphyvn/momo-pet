import Foundation
import Testing
@testable import MomoCharacter

/// `CopyKey` grammar + `MomoCopy` resolution (TASK-011 Requirement 4:
/// type-safe lookup for the `momo.line.*` namespaces; 05 §4.11 INV-11:
/// the engine emits keys, catalogs resolve them).
///
/// The lookup path under test is the production path — `Bundle.localizedString`
/// against a synthesized bundle — so the exact code the apps run is exercised
/// on the host (no app bundle needed; package code cannot touch `Bundle.main`).
@Suite("CopyKey + MomoCopy lookup")
struct MomoCopyTests {

    // MARK: - Key grammar

    @Test("builders produce the exact namespace shapes of 04 §10.4")
    func buildersProduceExactKeys() {
        #expect(CopyKey.line(.morning, 1) == "momo.line.morning.01")
        #expect(CopyKey.line(.day, 0) == "momo.line.day.00")
        #expect(CopyKey.line(.evening, 10) == "momo.line.evening.10")
        #expect(CopyKey.line(.night, 3) == "momo.line.night.03")
        #expect(CopyKey.line(.greeting, 2) == "momo.line.greeting.02")
        #expect(CopyKey.line(.careMoment, 12) == "momo.line.care-moment.12")
        #expect(CopyKey.react(.touch, 0) == "momo.line.react.touch.00")
        #expect(CopyKey.react(.feed, 4) == "momo.line.react.feed.04")
        #expect(CopyKey.react(.play, 7) == "momo.line.react.play.07")
        #expect(CopyKey.react(.care, 1) == "momo.line.react.care.01")
        #expect(CopyKey.moment(3) == "momo.line.moment.03")
    }

    @Test("every builder output over the full slot/family space is in an approved namespace")
    func builderOutputsAreApprovedNamespaceKeys() {
        for slot in CopyKey.Slot.allCases {
            #expect(CopyKey.isInApprovedNamespace(CopyKey.line(slot, 1)))
        }
        for family in CopyKey.Family.allCases {
            #expect(CopyKey.isInApprovedNamespace(CopyKey.react(family, 1)))
        }
        #expect(CopyKey.isInApprovedNamespace(CopyKey.moment(1)))
    }

    @Test("keys outside the approved namespaces are rejected (INV-11 conformance check)")
    func nonNamespaceKeysAreRejected() {
        let rejects = [
            "momo.line.unknown.01",          // not a slot
            "momo.line.react.hug.01",        // not a family
            "momo.line.moment.1",            // <nn> requires two digits
            "momo.line.moment.123",          // …and only two
            "momo.line.",                    // truncated
            "Momo missed you.",              // prose, not a key
            "momo.quest.reminder",           // other namespace
            "",
        ]
        for key in rejects {
            #expect(!CopyKey.isInApprovedNamespace(key), "'\(key)' must not pass the namespace check")
        }
    }

    // MARK: - Lookup (production Bundle path over a synthesized bundle)

    @Test("a known key resolves to its catalog value; a missing key surfaces as nil")
    func knownKeyResolvesAndMissingKeySurfaces() throws {
        let bundle = try makeSynthesizedCopyBundle([
            "momo.line.day.00": "Placeholder line — real lines arrive with the engine.",
        ])
        defer { try? FileManager.default.removeItem(at: bundle.bundleURL) }

        #expect(
            MomoCopy.lookup("momo.line.day.00", bundle: bundle) ==
                "Placeholder line — real lines arrive with the engine."
        )
        #expect(MomoCopy.lookup("momo.line.day.99", bundle: bundle) == nil,
                "a missing key must surface (nil), not masquerade as a value")
        #expect(
            MomoCopy.resolve("momo.line.day.00", bundle: bundle) ==
                "Placeholder line — real lines arrive with the engine."
        )
        #expect(MomoCopy.tableName == "MomoCopy", "the table name is the catalog file stem")
    }

    /// Builds a minimal on-disk bundle containing `en.lproj/MomoCopy.strings`
    /// so `Bundle.localizedString` runs for real. (Host-side proof, 2026-09-08
    /// spike: `Bundle(path:)` loads a plain directory containing an `.lproj`
    /// and resolves strings tables from it.)
    private func makeSynthesizedCopyBundle(_ entries: [String: String]) throws -> Bundle {
        let escaped = { (string: String) -> String in
            string.replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
        }
        let body = entries
            .sorted { $0.key < $1.key }
            .map { "\"\(escaped($0.key))\" = \"\(escaped($0.value))\";" }
            .joined(separator: "\n")
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("momo-copy-lookup-tests-\(UUID().uuidString)", isDirectory: true)
        let lproj = directory.appendingPathComponent("en.lproj", isDirectory: true)
        try FileManager.default.createDirectory(at: lproj, withIntermediateDirectories: true)
        try body.write(
            to: lproj.appendingPathComponent("MomoCopy.strings"),
            atomically: true,
            encoding: .utf8
        )
        guard let bundle = Bundle(path: directory.path) else {
            throw CocoaError(.fileReadNoSuchFile, userInfo: [NSFilePathErrorKey: directory.path])
        }
        return bundle
    }
}
