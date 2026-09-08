import SwiftUI
import Testing
@testable import MomoCharacter

/// Design-token structural pins (TASK-011 AC-1): the 8 character slots exist
/// with the slot names of 04-character-system §8.4 **verbatim** and in
/// document order; every token carries both variants and resolves them per
/// scheme. (Both variants being non-optional stored properties makes their
/// existence a compile-time property; these tests pin the §8.4 names and the
/// resolution mapping on top.)
@Suite("Design tokens (04 §8.4 + project.md §18)")
struct MomoDesignTokensTests {

    private static let section84Slots = [
        "momo.fur.base",
        "momo.fur.shade",
        "momo.ear.inner",
        "momo.eye.base",
        "momo.eye.highlight",
        "momo.cheek",
        "momo.blanket",
        "momo.sparkle",
    ]

    @Test("character slots are pinned verbatim to 04 §8.4, in document order")
    func characterSlotsMatchSection84Verbatim() {
        #expect(MomoCharacterPalette.allSlots.map(\.slot) == Self.section84Slots)
        #expect(MomoCharacterPalette.allSlots.count == 8)
    }

    @Test("every character slot resolves its light and dark variant per scheme")
    func characterSlotsResolveBothVariants() {
        for (slot, token) in MomoCharacterPalette.allSlots {
            #expect(token.resolve(.light) == token.light, "\(slot): .light must select the light variant")
            #expect(token.resolve(.dark) == token.dark, "\(slot): .dark must select the dark variant")
        }
    }

    @Test("every UI token resolves its light and dark variant per scheme")
    func uiTokensResolveBothVariants() {
        let uiTokens: [(name: String, token: MomoColorToken)] = [
            ("background", MomoUIColors.background),
            ("surface", MomoUIColors.surface),
            ("border", MomoUIColors.border),
            ("textPrimary", MomoUIColors.textPrimary),
            ("textSecondary", MomoUIColors.textSecondary),
            ("accent", MomoUIColors.accent),
        ]
        for (name, token) in uiTokens {
            #expect(token.resolve(.light) == token.light, "\(name): .light must select the light variant")
            #expect(token.resolve(.dark) == token.dark, "\(name): .dark must select the dark variant")
        }
    }

    @Test("typography, spacing and radius tokens exist as the only scale source")
    func metricAndTypographyTokensExist() {
        // Existence pins: these are the tokens views must use; the compiler
        // enforces the rest (non-optional constants).
        _ = MomoTypography.display
        _ = MomoTypography.heading
        _ = MomoTypography.body
        _ = MomoTypography.caption
        #expect(MomoSpacing.extraLarge > MomoSpacing.large)
        #expect(MomoSpacing.large > MomoSpacing.medium)
        #expect(MomoSpacing.medium > MomoSpacing.small)
        #expect(MomoSpacing.small > MomoSpacing.extraSmall)
        #expect(MomoRadius.large > MomoRadius.medium)
        #expect(MomoRadius.medium > MomoRadius.small)
    }
}
