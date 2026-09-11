import Foundation
import Testing
import MomoCore
@testable import MomoCharacter

/// Standing tests over the shipped String Catalog (TASK-011 Requirements 2
/// and 4; TASK-033 Requirement 5's catalog-era split; TASK-034's touch
/// pool; TASK-037's room + tab classes; TASK-038's settings surface). These
/// run against the real file
/// in the repo tree — they assert
/// the catalog exists (never vacuous), parses, exposes the `momo.line.*`
/// namespaces, keeps every key inside the law (the frozen validator's
/// grammar OR one of the enumerated fixed-lookup grammars), carries the
/// per-class counts the TASK-033/TASK-034/TASK-035/TASK-036/TASK-037/
/// TASK-038 landings
/// committed to, and pins the contract copy VERBATIM (the touch pool's
/// AC-5 pattern, extended to TASK-035's care loop, TASK-036's moment
/// lines, TASK-037's room lines and tab labels, TASK-038's settings
/// keys, and — TASK-039 R1, REVIEW-TASK-033 MINOR-1 — the FULL TASK-033
/// landing: every slot line, greeting, status word, and wish). The catalog carries
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
    ///    TASK-037's room lines, TASK-037's `momo.tab.*` chrome class, and
    ///    TASK-038's `momo.settings.*` surface class —
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
            "^momo\\.settings\\.(rename\\.(field\\.label|save)|haptics\\.toggle|erase\\.(row|alert\\.(title|message|confirm|cancel))|about\\.(version\\.label|privacy))$",
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
    /// TASK-037/TASK-038 landings committed to (04 §10.3's ten lines per
    /// time slot; the OBS-1
    /// vocabulary's 12; the status words' 8; the PRD §5.2 wishes' 7; the
    /// three return greetings; TASK-034's five spoken touch lines;
    /// TASK-035's six spoken lines per feed/play/care and the three
    /// care-moment visuals; TASK-036's two moment lines, FIXED lookups;
    /// TASK-037's two room lines, FIXED lookups, and the three tab
    /// labels; TASK-038's ten `momo.settings.*` surface keys, FIXED
    /// lookups) — 113 keys in all. A new class or count lands only with its
    /// own task,
    /// its own epoch bump when variational (§4.10), and this pin's update.
    @Test("the per-class key counts match the TASK-033 + TASK-034 + TASK-035 + TASK-036 + TASK-037 + TASK-038 landings: 40 slot lines, 3 greetings, 12 vocab, 8 status, 7 quest, 23 react, 3 care-moment, 2 moment, 2 room, 3 tab, 10 settings")
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
        #expect(count(matching: "^momo\\.settings\\.") == 10, "the settings surface class is the fixed ten FR-19 keys (TASK-038)")
        #expect(keys.count == 113, "the whole catalog is exactly the classes above")
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

    // MARK: The settings surface keys (TASK-038 R2; FR-19; UX §1.2 S6)

    /// TASK-038 landed the Settings tab's copy as FIXED lookups (the
    /// `room.01` precedent) — the FR-19 inventory's exact ten keys. The
    /// entries are the contract's verbatim copy: the S6.2 alert's title,
    /// message TEMPLATE (positional `%1$@`, the name interpolating TWICE —
    /// delete clause + Watch clause), confirm, and cancel TEMPLATE (`Keep
    /// {name}`); the two templates compose at render via `String(format:)`
    /// (pinned kit-side in `SettingsCopyKeyTests`, including the assembled
    /// title + message against the full verbatim S6.2 line). The
    /// apostrophes are U+2019, per the catalog convention. NO sound key
    /// exists (FR-19 ships it only if Phase 1 ships audio; 04 §11 shipped
    /// none).
    private static let settingsVerbatim: [(key: String, text: String)] = [
        ("momo.settings.rename.field.label", "Pet name"),
        ("momo.settings.rename.save", "Save"),
        ("momo.settings.haptics.toggle", "Haptics"),
        ("momo.settings.erase.row", "Erase all data"),
        ("momo.settings.erase.alert.title", "Erase everything?"),
        ("momo.settings.erase.alert.message", "This deletes %1$@ and all memories on this iPhone; %1$@’s Watch snapshot resets at its next sync. This can’t be undone."),
        ("momo.settings.erase.alert.confirm", "Erase"),
        ("momo.settings.erase.alert.cancel", "Keep %1$@"),
        ("momo.settings.about.version.label", "Version"),
        ("momo.settings.about.privacy", "Everything stays on this iPhone. Nothing about Momo ever leaves."),
    ]

    @Test("the shipped catalog carries the settings keys verbatim (TASK-038 R2)")
    func catalogCarriesTheSettingsKeysVerbatim() throws {
        #expect(Self.settingsVerbatim.count == 10,
                "the FR-19 inventory is exactly ten keys")
        let strings = try Self.stringsDictionary()
        for (key, text) in Self.settingsVerbatim {
            let entry = try #require(
                strings[key] as? [String: Any],
                "'\(key)' is missing from the shipped catalog")
            let localizations = try #require(entry["localizations"] as? [String: Any], "'\(key)' has no localizations")
            let en = try #require(localizations["en"] as? [String: Any], "'\(key)' has no en localization")
            let unit = try #require(en["stringUnit"] as? [String: Any], "'\(key)' has no stringUnit")
            #expect(unit["value"] as? String == text, "'\(key)' must read verbatim: '\(text)'")
        }
    }

    // MARK: The TASK-033 landing's verbatim values (TASK-039 R1; REVIEW-TASK-033 MINOR-1)

    /// REVIEW-TASK-033 MINOR-1: the TASK-033 landing shipped 58 values with
    /// no verbatim VALUE pins — a slot-line rewrite passed every
    /// catalog-facing test. This table closes that hole: EVERY unpinned
    /// TASK-033 value, byte-exact against the shipped catalog (values were
    /// read FROM the catalog file into this table; the pin's point is that
    /// a future edit fails here). Covered: the 40 time-slot lines (four
    /// pools × `.00`–`.09`), the 3 return greetings (`.01`–`.03`), the 8
    /// status words (4 energy + 4 stage, the enumerated fixed lookups), and
    /// the 7 quest wishes (`q1`–`q7`). The 12 OBS-1 vocab entries are
    /// pinned kit-side (`VocabularyKeyTests`); the later keyspaces (react
    /// touch, care moments, quest moments, room, tab, settings) are pinned
    /// by their own tasks' tables above — NOT duplicated here. The
    /// apostrophes are U+2019, the ellipsis in `night.00` is U+2026, the
    /// quest dashes are U+2014 — byte-exact per the catalog convention. NO
    /// epoch movement: this pin changes no values.
    private static let landingVerbatim: [(key: String, text: String)] = [
        ("momo.line.morning.00", "Good morning. Momo just woke up."),
        ("momo.line.morning.01", "Momo is stretching off the sleep."),
        ("momo.line.morning.02", "A soft start to the day."),
        ("momo.line.morning.03", "Momo perked up the moment you arrived."),
        ("momo.line.morning.04", "Morning light suits Momo."),
        ("momo.line.morning.05", "Momo was dreaming about breakfast."),
        ("momo.line.morning.06", "Slow blinks. Momo is glad you're here."),
        ("momo.line.morning.07", "The day is quiet so far. Momo likes it."),
        ("momo.line.morning.08", "Momo is doing small morning stretches."),
        ("momo.line.morning.09", "You two have a whole day ahead."),
        ("momo.line.day.00", "Momo is watching dust drift in the light."),
        ("momo.line.day.01", "A calm afternoon. Momo is content."),
        ("momo.line.day.02", "Momo is dozing with one ear up."),
        ("momo.line.day.03", "Momo wouldn't mind a little company."),
        ("momo.line.day.04", "Momo feels like playing, maybe."),
        ("momo.line.day.05", "Everything is peaceful. Momo approves."),
        ("momo.line.day.06", "Momo is loafed in a warm spot."),
        ("momo.line.day.07", "Momo tilts an ear toward you."),
        ("momo.line.day.08", "A quiet hour. Momo is rested and easy."),
        ("momo.line.day.09", "Momo is saving energy for the evening."),
        ("momo.line.evening.00", "The light is going soft. Momo is slowing down."),
        ("momo.line.evening.01", "Momo is getting sleepy."),
        ("momo.line.evening.02", "Momo had a good day."),
        ("momo.line.evening.03", "Momo is winding down beside you."),
        ("momo.line.evening.04", "A cozy hour. Momo's ears are at half-mast."),
        ("momo.line.evening.05", "Momo yawned. That's an evening signal."),
        ("momo.line.evening.06", "Momo wouldn't mind a tuck-in soon."),
        ("momo.line.evening.07", "The day is settling. So is Momo."),
        ("momo.line.evening.08", "Momo is curled a little tighter."),
        ("momo.line.evening.09", "Tonight looks good for an early night."),
        ("momo.line.night.00", "Shhh… Momo is sleeping."),
        ("momo.line.night.01", "Momo is curled up, fast asleep."),
        ("momo.line.night.02", "Momo's ear twitched. Still asleep."),
        ("momo.line.night.03", "A small snore. Momo is deep in a dream."),
        ("momo.line.night.04", "Momo sleeps best on quiet nights."),
        ("momo.line.night.05", "All tucked in. Momo is warm."),
        ("momo.line.night.06", "Momo stirs, then settles again."),
        ("momo.line.night.07", "The house is quiet. Momo is resting."),
        ("momo.line.night.08", "Momo will be ready for morning."),
        ("momo.line.night.09", "Sweet dreams are in progress."),
        ("momo.line.greeting.01", "Momo looked up right away."),
        ("momo.line.greeting.02", "Momo missed you."),
        ("momo.line.greeting.03", "Momo is up and starting the day."),
        ("momo.line.status.energy.energetic", "Energetic"),
        ("momo.line.status.energy.relaxed", "Relaxed"),
        ("momo.line.status.energy.drowsy", "Drowsy"),
        ("momo.line.status.energy.exhausted", "Exhausted"),
        ("momo.line.status.stage.newFriends", "New Friends"),
        ("momo.line.status.stage.gettingClose", "Getting Close"),
        ("momo.line.status.stage.bestFriends", "Best Friends"),
        ("momo.line.status.stage.soulCompanions", "Soul Companions"),
        ("momo.line.quest.q1", "Morning hello — say hello to Momo"),
        ("momo.line.quest.q2", "Mealtime — Momo would like a meal"),
        ("momo.line.quest.q3", "Second helping — Momo is extra hungry today"),
        ("momo.line.quest.q4", "Playtime — Momo feels like playing"),
        ("momo.line.quest.q5", "Extra playful — Momo has lots of energy today"),
        ("momo.line.quest.q6", "Tuck-in — Momo is getting sleepy"),
        ("momo.line.quest.q7", "Gentle pats — Momo wouldn't mind some pats"),
    ]

    /// The EXACT key set the landing table must cover: the four slot pools'
    /// `.00`–`.09` ranges, the greeting pool's `.01`–`.03`, the enumerated
    /// status cases, and the seven wishes — nothing more, nothing less.
    private static var landingKeySet: Set<String> {
        var keys = Set<String>()
        for band in ["morning", "day", "evening", "night"] {
            for index in 0...9 {
                keys.insert("momo.line.\(band).\(String(format: "%02d", index))")
            }
        }
        for index in 1...3 {
            keys.insert("momo.line.greeting.\(String(format: "%02d", index))")
        }
        for band in ["energetic", "relaxed", "drowsy", "exhausted"] {
            keys.insert("momo.line.status.energy.\(band)")
        }
        for band in ["newFriends", "gettingClose", "bestFriends", "soulCompanions"] {
            keys.insert("momo.line.status.stage.\(band)")
        }
        for wish in 1...7 {
            keys.insert("momo.line.quest.q\(wish)")
        }
        return keys
    }

    @Test("the shipped catalog carries the TASK-033 landing verbatim: 40 slot lines, 3 greetings, 8 status words, 7 wishes (TASK-039 R1)")
    func catalogCarriesTheTASK033LandingVerbatim() throws {
        // Non-vacuity: the table is non-empty and covers EXACTLY the four
        // intended namespaces — the key set equality proves both coverage
        // (no missing key) and no-scope-creep (no extra key), and the
        // 40/3/8/7 counts are pinned per class.
        let tableKeys = Set(Self.landingVerbatim.map(\.key))
        #expect(!tableKeys.isEmpty, "the landing table must not be empty")
        #expect(tableKeys == Self.landingKeySet,
                "the landing table must cover exactly the TASK-033 namespaces (missing: \(Self.landingKeySet.subtracting(tableKeys).sorted()); extra: \(tableKeys.subtracting(Self.landingKeySet).sorted()))")
        func tableCount(matching pattern: String) -> Int {
            Self.landingVerbatim.filter {
                $0.key.range(of: pattern, options: .regularExpression) != nil
            }.count
        }
        let slotPattern = "^momo\\.line\\.(morning|day|evening|night)\\.\\d{2}$"
        #expect(tableCount(matching: slotPattern) == 40, "the slot pools are ten lines each — 40 in all")
        #expect(tableCount(matching: "^momo\\.line\\.greeting\\.\\d{2}$") == 3, "the greeting pool is exactly three")
        #expect(tableCount(matching: "^momo\\.line\\.status\\.") == 8, "the status words are exactly eight")
        #expect(tableCount(matching: "^momo\\.line\\.quest\\.q[1-7]$") == 7, "the wishes are exactly seven")
        #expect(Self.landingVerbatim.count == 58, "40 + 3 + 8 + 7 = 58 — the whole TASK-033 landing")
        // Byte-exact values against the shipped catalog.
        let strings = try Self.stringsDictionary()
        for (key, text) in Self.landingVerbatim {
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
