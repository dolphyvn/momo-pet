import Testing

/// Self-tests + the standing scan for the D-R1 import whitelist
/// (TASK-010 Requirements 4 and 6; 05 §10.2). The scanner is exercised as a
/// pure function over literal fixture sources — no scratch commits.
@Suite("D-R1 import-whitelist scan")
struct ImportWhitelistScanTests {

    // MARK: - Fixture self-tests (failure and success paths)

    @Test("violating fixture: a non-Foundation import fails")
    func violatingFixtureFails() {
        let violations = ImportWhitelistScan.violations(
            files: [("Fixtures/Violating.swift", "import Foundation\nimport UIKit\nstruct X {}\n")],
            whitelist: ImportWhitelistScan.momoCoreWhitelist
        )
        #expect(violations == [ImportWhitelistScan.Violation(file: "Fixtures/Violating.swift", module: "UIKit")])
    }

    @Test("clean fixture: Foundation-only source passes")
    func cleanFixturePasses() {
        let violations = ImportWhitelistScan.violations(
            files: [("Fixtures/Clean.swift", "import Foundation\nstruct X {}\n")],
            whitelist: ImportWhitelistScan.momoCoreWhitelist
        )
        #expect(violations.isEmpty)
    }

    @Test("commented-out import does not fake a violation")
    func commentedOutImportIsIgnored() {
        let source = """
        import Foundation
        // import UIKit
        /* import SwiftUI */
        /// See also: import Combine
        struct X {}
        """
        let violations = ImportWhitelistScan.violations(
            files: [("Fixtures/Comments.swift", source)],
            whitelist: ImportWhitelistScan.momoCoreWhitelist
        )
        #expect(violations.isEmpty)
    }

    @Test("import mentioned inside a string literal does not fake a violation")
    func importInsideStringLiteralIsIgnored() {
        let source = """
        import Foundation
        let usage = "import UIKit to use this API"
        struct X {}
        """
        let violations = ImportWhitelistScan.violations(
            files: [("Fixtures/StringLiteral.swift", source)],
            whitelist: ImportWhitelistScan.momoCoreWhitelist
        )
        #expect(violations.isEmpty)
    }

    @Test("@testable and scoped imports are still attributed to their module")
    func testableAndScopedImportsAreCaught() {
        let source = """
        import Foundation
        @testable import SwiftUI
        import struct Combine.Publishers
        """
        let violations = ImportWhitelistScan.violations(
            files: [("Fixtures/Scoped.swift", source)],
            whitelist: ImportWhitelistScan.momoCoreWhitelist
        )
        #expect(violations == [
            ImportWhitelistScan.Violation(file: "Fixtures/Scoped.swift", module: "Combine"),
            ImportWhitelistScan.Violation(file: "Fixtures/Scoped.swift", module: "SwiftUI"),
        ])
    }

    // MARK: - The standing scan over the real MomoCore sources

    @Test("MomoCore as it stands passes the D-R1 whitelist (non-empty source set)")
    func momoCorePassesWhitelist() throws {
        let sources = try TestRepo.momoCoreSources()
        // The scan must not be able to pass vacuously: a missing or renamed
        // module directory fails here instead of greening the scan.
        #expect(!sources.isEmpty, "Sources/MomoCore must exist and contain Swift sources")
        let violations = ImportWhitelistScan.violations(
            files: sources,
            whitelist: ImportWhitelistScan.momoCoreWhitelist
        )
        #expect(violations.isEmpty, "D-R1 violation: \(violations.map { "\($0.file): import \($0.module)" })")
    }
}
