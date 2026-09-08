import Testing
@testable import MomoCharacter

/// Empty suite — exists only to prove `swift test` hostability of `MomoCharacter`
/// (SwiftUI-importing) on macOS (TASK-009 AC-4; the swift-test VERIFY item from
/// 05 Appendix B). Idle-sequencer determinism and Reduce Motion pose-mapping
/// coverage lands in EPIC-006 (05 §10.1).
@Suite("MomoCharacter placeholder suite")
struct MomoCharacterPlaceholderTests {
}
