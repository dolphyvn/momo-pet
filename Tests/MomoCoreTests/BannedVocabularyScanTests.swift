import Foundation
import Testing

/// Self-tests + the standing scan for the banned-vocabulary list
/// (TASK-010 Requirements 5 and 6; 05 §10.2; source of truth
/// docs/design/04-character-system.md §10.2). The scanner is exercised as a
/// pure function over literal fixture catalog JSON — no scratch commits.
/// On today's tree (no String Catalogs yet; TASK-011 creates them) the
/// real-tree scan is vacuously green by design.
@Suite("FR-12 banned-vocabulary scan")
struct BannedVocabularyScanTests {

    // MARK: - Fixtures

    /// Minimal valid String Catalog JSON with one clean and one violating entry.
    private func catalogJSON(_ strings: String) -> Data {
        Data("""
        {
          "sourceLanguage" : "en",
          "version" : "1.0",
          "strings" : { \(strings) }
        }
        """ .utf8)
    }

    private func entry(key: String, value: String) -> String {
        """
        "\(key)" : {
          "localizations" : {
            "en" : { "stringUnit" : { "state" : "translated", "value" : "\(value)" } }
          }
        }
        """
    }

    // MARK: - List integrity (verbatim source-of-truth guard)

    @Test("banned list matches 04 §10.2 exactly (12 entries, document order)")
    func bannedListMatchesSourceOfTruth() {
        #expect(BannedVocabularyScan.entries.map(\.display) == [
            "forgot",
            "lonely",
            "sad",
            "waiting for you",
            "hurry",
            "don't forget",
            "last chance",
            "only X left",
            "streak",
            "miss out",
            "failed",
            "penalty",
        ])
        #expect(BannedVocabularyScan.entries.count == 12)
    }

    // MARK: - Failure and success paths

    @Test("violating fixture: banned term in a value fails with full attribution")
    func bannedTermInValueFails() {
        let data = catalogJSON(entry(key: "momo.line.greeting.02", value: "You forgot about Momo..."))
        let violations = BannedVocabularyScan.violations(inCatalogJSON: data, file: "Fixtures/Violating.xcstrings")
        #expect(violations == [
            BannedVocabularyScan.Violation(
                file: "Fixtures/Violating.xcstrings",
                catalogKey: "momo.line.greeting.02",
                language: "en",
                term: "forgot",
                value: "You forgot about Momo..."
            )
        ])
    }

    @Test("clean fixture passes")
    func cleanFixturePasses() {
        let data = catalogJSON([
            entry(key: "momo.line.morning.01", value: "Good morning. Momo just woke up."),
            entry(key: "momo.line.night.01", value: "Shhh... Momo is sleeping."),
        ].joined(separator: ", "))
        #expect(BannedVocabularyScan.violations(inCatalogJSON: data, file: "Fixtures/Clean.xcstrings").isEmpty)
    }

    @Test("the sanctioned absence reference passes (PRD §3.3)")
    func sanctionedAbsenceReferencePasses() {
        let data = catalogJSON(entry(key: "momo.line.greeting.long", value: "Momo missed you."))
        #expect(BannedVocabularyScan.violations(inCatalogJSON: data, file: "Fixtures/Sanctioned.xcstrings").isEmpty)
    }

    @Test("typographic apostrophe normalizes: 'Don’t forget' is caught")
    func typographicApostropheIsCaught() {
        let data = catalogJSON(entry(key: "momo.quest.reminder", value: "Don’t forget to feed Momo!"))
        let violations = BannedVocabularyScan.violations(inCatalogJSON: data, file: "Fixtures/Apostrophe.xcstrings")
        #expect(violations.count == 1)
        #expect(violations.first?.term == "don't forget")
    }

    @Test("template term: 'Only 3 quests left' is caught by the 'only X left' reading")
    func templateTermIsCaught() {
        let data = catalogJSON(entry(key: "momo.line.moment.bad", value: "Only 3 quests left! Keep going!"))
        let violations = BannedVocabularyScan.violations(inCatalogJSON: data, file: "Fixtures/Template.xcstrings")
        #expect(violations.count == 1)
        #expect(violations.first?.term == "only X left")
    }

    @Test("matching is case-insensitive")
    func matchingIsCaseInsensitive() {
        let data = catalogJSON(entry(key: "momo.line.care.bad", value: "HURRY — tuck Momo in before midnight!"))
        #expect(BannedVocabularyScan.violations(inCatalogJSON: data, file: "Fixtures/Case.xcstrings").count == 1)
    }

    @Test("catalog keys are not scanned — only values (Requirement 5 wording)")
    func keysAreNotScanned() {
        // A banned term in the developer-facing key is not user-facing copy.
        let data = catalogJSON(entry(key: "hurry.deleted.line", value: "Momo is dozing with one ear up."))
        #expect(BannedVocabularyScan.violations(inCatalogJSON: data, file: "Fixtures/KeysOnly.xcstrings").isEmpty)
    }

    @Test("every localization is scanned, not just the source language")
    func allLocalizationsAreScanned() {
        let data = Data("""
        {
          "sourceLanguage" : "en",
          "version" : "1.0",
          "strings" : {
            "momo.line.day.01" : {
              "localizations" : {
                "en" : { "stringUnit" : { "state" : "translated", "value" : "Momo is watching dust drift in the light." } },
                "de" : { "stringUnit" : { "state" : "translated", "value" : "Your streak is gone." } }
              }
            }
          }
        }
        """ .utf8)
        let violations = BannedVocabularyScan.violations(inCatalogJSON: data, file: "Fixtures/Localized.xcstrings")
        #expect(violations.count == 1)
        #expect(violations.first?.language == "de")
        #expect(violations.first?.term == "streak")
    }

    @Test("unparsable catalog fails loudly instead of passing silently")
    func unparsableCatalogFails() {
        let violations = BannedVocabularyScan.violations(inCatalogJSON: Data("{ not json".utf8), file: "Fixtures/Broken.xcstrings")
        #expect(violations.count == 1)
        #expect(violations.first?.term == "<unparsable catalog>")
    }

    // MARK: - The standing scan over the real tree

    @Test("real tree: every String Catalog that exists is clean (vacuous until TASK-011)")
    func realTreeCatalogsAreClean() throws {
        let catalogs = try TestRepo.stringCatalogs()
        let violations = try catalogs.flatMap { catalog in
            BannedVocabularyScan.violations(
                inCatalogJSON: try Data(contentsOf: catalog.url),
                file: catalog.name
            )
        }
        #expect(violations.isEmpty, "FR-12 violation: \(violations.map { "\($0.file)#\($0.catalogKey) [\($0.language)] term '\($0.term)' in '\($0.value)'" })")
    }
}
