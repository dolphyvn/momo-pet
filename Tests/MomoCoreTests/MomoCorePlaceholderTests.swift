import Testing
@testable import MomoCore

/// Proves `swift test` hostability of `MomoCore` on macOS (TASK-009 AC-4; the
/// swift-test VERIFY item from 05 Appendix B) with a non-empty smoke test
/// (TASK-010 Requirement 1). Engine/quest/cascade/DisplayState coverage lands
/// in EPIC-003/004 (05 §10.1); this target also hosts the TASK-010 static
/// scans (import whitelist, banned vocabulary).
@Suite("MomoCore placeholder suite")
struct MomoCorePlaceholderTests {

    /// Smoke: the target compiles, links and its anchor symbol is reachable.
    @Test("placeholder anchor is reachable through the module")
    func placeholderAnchorIsReachable() {
        #expect(MomoCorePlaceholder.isPlaceholder == true)
    }
}
