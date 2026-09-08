import Testing
@testable import MomoKit

/// Empty suite — exists only to prove `swift test` hostability of `MomoKit` on
/// macOS (TASK-009 AC-4; the swift-test VERIFY item from 05 Appendix B).
/// Store roundtrip/atomicity/recovery/migration, journal watermark and DTO codec
/// coverage lands in EPIC-005 (05 §10.1).
@Suite("MomoKit placeholder suite")
struct MomoKitPlaceholderTests {
}
