import Testing
import Foundation
@testable import MomoKit

// MARK: - RoomCopyKeyTests — the Room tab's copy-key pins (TASK-037 R4/R7;
// FR-3; UX §1.2 S5)

/// The KIT-side half of the room copy's gluing: `HomeCopyKeys` mints FIXED
/// catalog keys, and the catalog-side VERBATIM pins live in
/// `MomoCatalogScaffoldingTests` (character target) — these pin the minting
/// surface itself, so a key renamed on either side fails here or there and
/// never silently diverges. Includes the positional-placeholder composition
/// pin: the minted key is resolved against the SHIPPED catalog file (the
/// `KitRepo` anchor — the headless target cannot reach the app bundle's
/// compiled copy that `MomoCopyText` reads), and the resolved TEMPLATE must
/// compose through `String(format:)` with the pet name in the `%1$@` slot
/// (the `MomoAppModel` banner composition's precedent), so the
/// name-interpolated VoiceOver label is proven, not assumed.
@Suite
struct RoomCopyKeyTests {

    @Test("the room scene's label key is the fixed momo.line.room.01 lookup")
    func roomSceneLabelKeyIsFixed() {
        #expect(HomeCopyKeys.roomSceneLabelTemplateKey == "momo.line.room.01")
    }

    @Test("the room caption key is the fixed momo.line.room.02 lookup")
    func roomCaptionKeyIsFixed() {
        #expect(HomeCopyKeys.roomCaptionKey == "momo.line.room.02")
    }

    @Test("every tab resolves to its momo.tab.<tab> label key (exhaustive)")
    func tabLabelKeysAreExhaustive() {
        // The Tab domain is exactly the three flat tabs (UX-1) — a new tab
        // must extend this pin and the catalog together.
        #expect(HomeCopyKeys.Tab.allCases == [.home, .room, .settings])
        #expect(HomeCopyKeys.tabLabelKey(for: .home) == "momo.tab.home")
        #expect(HomeCopyKeys.tabLabelKey(for: .room) == "momo.tab.room")
        #expect(HomeCopyKeys.tabLabelKey(for: .settings) == "momo.tab.settings")
    }

    @Test("the scene label template composes the pet name through the positional placeholder")
    func sceneLabelTemplateComposesTheName() throws {
        // Resolve the minted key against the shipped catalog, then compose
        // — exactly the two halves the view performs at render (key from
        // `HomeCopyKeys`, template from the catalog, `String(format:)` for
        // the name).
        let url = URL(fileURLWithPath: KitRepo.repoRoot + "/Apps/Shared/MomoCopy.xcstrings")
        let root = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
        let strings = try #require(root?["strings"] as? [String: Any])
        let entry = try #require(
            strings[HomeCopyKeys.roomSceneLabelTemplateKey] as? [String: Any],
            "the minted scene-label key is missing from the shipped catalog")
        let unit = try #require(
            ((entry["localizations"] as? [String: Any])?["en"]
                as? [String: Any])?["stringUnit"] as? [String: Any])
        let template = try #require(unit["value"] as? String)

        #expect(template.contains("%1$@"), "the template carries the positional placeholder")
        #expect(
            String(format: template, "Momo") == "Momo\u{2019}s cozy room",
            "the template composes the name into the spoken label")
    }
}
