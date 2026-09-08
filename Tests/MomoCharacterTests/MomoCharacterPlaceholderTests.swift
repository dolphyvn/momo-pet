import Testing
@testable import MomoCharacter

/// Proves `swift test` hostability of `MomoCharacter` (SwiftUI-importing) on
/// macOS (TASK-009 AC-4; the swift-test VERIFY item from 05 Appendix B) with a
/// non-empty smoke test (TASK-010 Requirement 1). Idle-sequencer determinism
/// and Reduce Motion pose-mapping coverage lands in EPIC-006 (05 §10.1).
@Suite("MomoCharacter placeholder suite")
struct MomoCharacterPlaceholderTests {

    /// Smoke: the target compiles, links and its anchor symbol is reachable.
    @Test("placeholder anchor is reachable through the module")
    func placeholderAnchorIsReachable() {
        #expect(MomoCharacterPlaceholder.isPlaceholder == true)
    }
}
