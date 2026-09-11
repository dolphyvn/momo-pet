import Foundation
import Testing
import MomoCore
@testable import MomoCharacter

/// Standing tests over the shipped String Catalog (TASK-011 Requirements 2
/// and 4; TASK-033 Requirement 5's catalog-era split; TASK-034's touch
/// pool; TASK-037's room + tab classes). These run against the real file
/// in the repo tree — they assert
/// the catalog exists (never vacuous), parses, exposes the `momo.line.*`
/// namespaces, keeps every key inside the law (the frozen validator's
/// grammar OR one of the enumerated fixed-lookup grammars), carries the
/// per-class counts the TASK-033/TASK-034/TASK-035/TASK-036/TASK-037
/// landings
/// committed to, and pins the contract copy VERBATIM (the touch pool's
/// AC-5 pattern, extended to TASK-035's care loop, TASK-036's moment
/// lines, and TASK-037's room lines and tab labels). The catalog carries
/// NO placeholder entries since TASK-036
/// replaced the last one — a future placeholder must re-land its
/// `.00`-convention pin with itself. (Tone over VALUES is the TASK-010
/// banned-vocabulary scan's job, with the 12-word rule pinned in
/// `CatalogCopyLawTests`; not duplicated here.)
@Suite("String Catalog scaffolding (momo.line.*, momo.tab.*)")
struct MomoCatalogScaffoldingTests {

    /// The approved-namespace law (INV-11), TASK-033-era shape:
    /// 1. the FROZEN validator's grammar (variational classes: time slots,
    ///    react families, moment — any two-digit index);
    /// 2. the ENUMERATED fixed-lookup grammars the validator deliberately
    ///    does not know (they are lookups, not selections): the OBS-1
    ///    vocabulary, the TASK-033 status words, the quest wishes,
    ///    TASK-037's room lines, and TASK-037's `momo.tab.*` chrome class —
    ///    their case lists are spelled out here so an out-of-catalog band
    ///    name or quest id fails LOUDLY here instead of shipping.
    private static func isInApprovedNamespaceOrFixedLookup(_ key: String) -> Bool {
        if CopyKey.isInApprovedNamespace(key) { return true }
        let bandCases = "joyful|content|wistful|low|energetic|relaxed|drowsy|exhausted|newFriends|gettingClose|bestFriends|soulCompanions"
        let fixedPatterns = [
            "^momo\\.line\\.vocab\\.(mood|energy|stage)\\.(\(bandCases))$",
            "^momo\\.line\\.status\\.(energy|stage)\\.(\(bandCases))$",
            "^momo\\.line\\.quest\\.q[1-7]$",
            "^momo\\.line\\.room\\.\\d{2}$",
            "^momo\\.tab\\.(home|room|settings)$",
        ]
        return fixedPatterns.contains { key.range(of: $0, options: .regularExpression) != nil }
    }

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

    @Test("every catalog key stays inside the law: the validator's grammar or an enumerated fixed-lookup grammar (INV-11)")
    func everyKeyIsInApprovedNamespace() throws {
        for key in try Self.catalogKeys() {
            #expect(Self.isInApprovedNamespaceOrFixedLookup(key), "'\(key)' is outside the approved namespaces")
        }
    }

    /// The per-class counts the TASK-033/TASK-034/TASK-035/TASK-036/
    /// TASK-037 landings committed to (04 §10.3's ten lines per time slot;
    /// the OBS-1
    /// vocabulary's 12; the status words' 8; the PRD §5.2 wishes' 7; the
    /// three return greetings; TASK-034's five spoken touch lines;
    /// TASK-035's six spoken lines per feed/play/care and the three
    /// care-moment visuals; TASK-036's two moment lines, FIXED lookups;
    /// TASK-037's two room lines, FIXED lookups, and the three tab
    /// labels) — 103 keys in all. A new class or count lands only with its
    /// own task,
    /// its own epoch bump when variational (§4.10), and this pin's update.
    @Test("the per-class key counts match the TASK-033 + TASK-034 + TASK-035 + TASK-036 + TASK-037 landings: 40 slot lines, 3 greetings, 12 vocab, 8 status, 7 quest, 23 react, 3 care-moment, 2 moment, 2 room, 3 tab")
    func perClassCountsPinned() throws {
        let keys = try Self.catalogKeys()
        func count(matching pattern: String) -> Int {
            keys.filter { $0.range(of: pattern, options: .regularExpression) != nil }.count
        }
        let slotCases = "morning|day|evening|night"
        #expect(count(matching: "^momo\\.line\\.(\(slotCases))\\.\\d{2}$") == 40, "the four time-slot pools are ten lines each")
        #expect(count(matching: "^momo\\.line\\.morning\\.\\d{2}$") == 10)
        #expect(count(matching: "^momo\\.line\\.day\\.\\d{2}$") == 10)
        #expect(count(matching: "^momo\\.line\\.evening\\.\\d{2}$") == 10)
        #expect(count(matching: "^momo\\.line\\.night\\.\\d{2}$") == 10)
        #expect(count(matching: "^momo\\.line\\.greeting\\.\\d{2}$") == 3, "the return-greeting pool is the fixed 01–03 lookup")
        #expect(count(matching: "^momo\\.line\\.vocab\\.") == 12, "the OBS-1 vocabulary: 4 mood + 4 energy + 4 stage")
        #expect(count(matching: "^momo\\.line\\.status\\.") == 8, "the status words: 4 energy + 4 stage")
        #expect(count(matching: "^momo\\.line\\.quest\\.q[1-7]$") == 7, "PRD §5.2's seven wishes")
        #expect(count(matching: "^momo\\.line\\.moment\\.\\d{2}$") == 2, "the moment class is the fixed 01–02 lookup (TASK-036)")
        #expect(count(matching: "^momo\\.line\\.react\\.") == 23, "the react namespace is touch's 5 + TASK-035's 6+6+6")
        #expect(count(matching: "^momo\\.line\\.react\\.touch\\.\\d{2}$") == 5, "the touch pool is exactly five lines")
        #expect(count(matching: "^momo\\.line\\.react\\.feed\\.\\d{2}$") == 6, "the feed pool is exactly six lines")
        #expect(count(matching: "^momo\\.line\\.react\\.play\\.\\d{2}$") == 6, "the play pool is exactly six lines")
        #expect(count(matching: "^momo\\.line\\.react\\.care\\.\\d{2}$") == 6, "the care pool is exactly six lines")
        #expect(count(matching: "^momo\\.line\\.care-moment\\.\\d{2}$") == 3, "the care-moment class is the fixed 01–03 lookup")
        #expect(count(matching: "^momo\\.line\\.room\\.\\d{2}$") == 2, "the room class is the fixed 01–02 lookup (TASK-037)")
        #expect(count(matching: "^momo\\.tab\\.(home|room|settings)$") == 3, "the tab chrome class is the fixed three labels (TASK-037)")
        #expect(keys.count == 103, "the whole catalog is exactly the classes above")
    }

    // MARK: The touch pool's verbatim lines (TASK-034 AC-5)

    /// TASK-034 landed the §6.1 spoken touch pool; its five entries are the
    /// contract's verbatim copy — the `catalogCarriesTheVocabularyVerbatim`
    /// pattern extended to the pool (AC-5), so the words can only change as
    /// a spec change, with this pin failing. The lines are
    /// ACCESSIBILITY-ONLY (UX-8: announced under VoiceOver, never rendered
    /// as body copy).
    private static let touchPoolVerbatim: [(key: String, text: String)] = [
        ("momo.line.react.touch.00", "Momo nuzzles into your hand."), // the 03 §5.1 example line
        ("momo.line.react.touch.01", "Momo leans into the touch."),
        ("momo.line.react.touch.02", "Momo blinks slowly, content."),
        ("momo.line.react.touch.03", "Momo’s tail curls happily."),
        ("momo.line.react.touch.04", "Momo presses closer for a moment."),
    ]

    @Test("the shipped catalog carries the touch pool's five lines verbatim (TASK-034's landing, AC-5)")
    func catalogCarriesTheTouchPoolVerbatim() throws {
        #expect(Self.touchPoolVerbatim.count == CopyRules.reactLineCount(for: .touch),
                "the verbatim table and the pool constant must move together")
        let strings = try Self.stringsDictionary()
        for (key, text) in Self.touchPoolVerbatim {
            let entry = try #require(
                strings[key] as? [String: Any],
                "'\(key)' is missing from the shipped catalog")
            let localizations = try #require(entry["localizations"] as? [String: Any], "'\(key)' has no localizations")
            let en = try #require(localizations["en"] as? [String: Any], "'\(key)' has no en localization")
            let unit = try #require(en["stringUnit"] as? [String: Any], "'\(key)' has no stringUnit")
            #expect(unit["value"] as? String == text, "'\(key)' must read verbatim: '\(text)'")
        }
    }

    // MARK: The feed/play/care pools + the care-moment visuals (TASK-035 R5)

    /// TASK-035 landed the §5.2–§5.4 spoken pools and the §10.1 rule 7
    /// visual care-moment lines; the catalog's contract copy is pinned
    /// VERBATIM (the same pattern as the touch pool — the apostrophe is
    /// U+2019 everywhere, touch.03's catalog value normalized to it). The
    /// react lines are ACCESSIBILITY-ONLY (UX-8); the care-moment lines
    /// RENDER in the contextual line's visual slot.
    private static let careLoopVerbatim: [(key: String, text: String)] = [
        ("momo.line.react.feed.00", "Momo’s ears perk up at the meal."),
        ("momo.line.react.feed.01", "Momo circles the tray, delighted."),
        ("momo.line.react.feed.02", "Momo takes a tiny, polite bite."),
        ("momo.line.react.feed.03", "Momo munches with quiet little sounds."),
        ("momo.line.react.feed.04", "Momo settles back, warmly full."),
        ("momo.line.react.feed.05", "Momo looks up as if to say thanks."),
        ("momo.line.react.play.00", "Momo perks up, ready to play."),
        ("momo.line.react.play.01", "Momo bounces once on the spot."),
        ("momo.line.react.play.02", "Momo’s tail wiggles with excitement."),
        ("momo.line.react.play.03", "Momo spins in a small happy circle."),
        ("momo.line.react.play.04", "Momo crouches low, ready to pounce."),
        ("momo.line.react.play.05", "Momo glances at you, eyes bright."),
        ("momo.line.react.care.00", "Momo snuggles under the blanket."),
        ("momo.line.react.care.01", "Momo’s breathing slows, soft and even."),
        ("momo.line.react.care.02", "Momo curls into a round little ball."),
        ("momo.line.react.care.03", "Momo yawns a tiny yawn."),
        ("momo.line.react.care.04", "Momo tucks its paws in close."),
        ("momo.line.react.care.05", "Momo drifts off, warm and safe."),
        ("momo.line.care-moment.01", "Momo snuggles down under the blanket."),
        ("momo.line.care-moment.02", "Momo is full and thanks you with a nod."),
        ("momo.line.care-moment.03", "Momo shifts sleepily under the blanket."),
    ]

    @Test("the shipped catalog carries the feed/play/care pools and care-moment lines verbatim (TASK-035 R5)")
    func catalogCarriesTheCareLoopVerbatim() throws {
        #expect(Self.careLoopVerbatim.count == 21,
                "18 react lines + 3 care-moment lines")
        let strings = try Self.stringsDictionary()
        for (key, text) in Self.careLoopVerbatim {
            let entry = try #require(
                strings[key] as? [String: Any],
                "'\(key)' is missing from the shipped catalog")
            let localizations = try #require(entry["localizations"] as? [String: Any], "'\(key)' has no localizations")
            let en = try #require(localizations["en"] as? [String: Any], "'\(key)' has no en localization")
            let unit = try #require(en["stringUnit"] as? [String: Any], "'\(key)' has no stringUnit")
            #expect(unit["value"] as? String == text, "'\(key)' must read verbatim: '\(text)'")
        }
    }

    // MARK: The moment lines (TASK-036 R6; UX §5.5–§5.6's celebration class)

    /// TASK-036 landed the celebration class as FIXED lookups (the OBS-D
    /// adjudication: a celebration line must say THE celebration — zero
    /// variation, never a seeded draw). The two entries are the contract's
    /// verbatim copy: `.01` is the M2 banner's %1$@/%2$@ TEMPLATE (positional
    /// placeholders so a localized reordering stays locale-correct), `.02`
    /// the M3 all-done warm note. The composer appends the bond-descriptor
    /// sentence to `.01` — the catalog entry itself stays the template.
    private static let momentVerbatim: [(key: String, text: String)] = [
        ("momo.line.moment.01", "%1$@ and you are now %2$@."),
        ("momo.line.moment.02", "Momo had a lovely day."),
    ]

    @Test("the shipped catalog carries the moment lines verbatim (TASK-036 R6)")
    func catalogCarriesTheMomentLinesVerbatim() throws {
        #expect(Self.momentVerbatim.count == 2,
                "the moment class is exactly the two FIXED lookups")
        let strings = try Self.stringsDictionary()
        for (key, text) in Self.momentVerbatim {
            let entry = try #require(
                strings[key] as? [String: Any],
                "'\(key)' is missing from the shipped catalog")
            let localizations = try #require(entry["localizations"] as? [String: Any], "'\(key)' has no localizations")
            let en = try #require(localizations["en"] as? [String: Any], "'\(key)' has no en localization")
            let unit = try #require(en["stringUnit"] as? [String: Any], "'\(key)' has no stringUnit")
            #expect(unit["value"] as? String == text, "'\(key)' must read verbatim: '\(text)'")
        }
    }

    // MARK: The room lines + tab labels (TASK-037 R4)

    /// TASK-037 landed the Room tab's copy as FIXED lookups (the `moment.01`
    /// precedent: a named line, never a seeded draw) plus the shell's
    /// `momo.tab.*` chrome class. The five entries are the contract's
    /// verbatim copy: `.01` is the scene label's %1$@ TEMPLATE (one
    /// positional placeholder for the pet name so a localized reordering
    /// stays locale-correct), `.02` the caption beneath the scene, and the
    /// three one-word tab labels the shell's D12 render rides. The
    /// apostrophe is U+2019, per the catalog convention.
    private static let roomVerbatim: [(key: String, text: String)] = [
        ("momo.line.room.01", "%1$@’s cozy room"),
        ("momo.line.room.02", "Somewhere soft to come home to."),
        ("momo.tab.home", "Home"),
        ("momo.tab.room", "Room"),
        ("momo.tab.settings", "Settings"),
    ]

    @Test("the shipped catalog carries the room lines and tab labels verbatim (TASK-037 R4)")
    func catalogCarriesTheRoomLinesVerbatim() throws {
        #expect(Self.roomVerbatim.count == 5,
                "2 room lines + 3 tab labels")
        let strings = try Self.stringsDictionary()
        for (key, text) in Self.roomVerbatim {
            let entry = try #require(
                strings[key] as? [String: Any],
                "'\(key)' is missing from the shipped catalog")
            let localizations = try #require(entry["localizations"] as? [String: Any], "'\(key)' has no localizations")
            let en = try #require(localizations["en"] as? [String: Any], "'\(key)' has no en localization")
            let unit = try #require(en["stringUnit"] as? [String: Any], "'\(key)' has no stringUnit")
            #expect(unit["value"] as? String == text, "'\(key)' must read verbatim: '\(text)'")
        }
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
