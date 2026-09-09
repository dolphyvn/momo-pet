import Foundation
import Testing
@testable import MomoCore

/// Day-stable seed derivation properties + encoding pins (TASK-014
/// Requirement 7 / AC-3; 05 §4.10).
@Suite("DaySeed (SHA-256 → 64-bit day-stable seeds)")
struct DaySeedTests {

    /// Fixed, reproducible identity for all derivations in this suite.
    private let petID = UUID(uuidString: "7C47A9C4-2E5F-4B8A-9C1D-3E6F8A2B4C0D")!

    private func seed(dayKey: String, epoch: Int, salt: DaySeed.Salt, petID: UUID? = nil) -> UInt64 {
        DaySeed.make(petID: petID ?? self.petID, localDayKey: dayKey, epoch: epoch, salt: salt)
    }

    // MARK: - Day stability (05 §4.10: same day ⇒ same seed)

    @Test("same inputs derive the identical seed (day stability, repeated)")
    func dayStability() {
        let a = seed(dayKey: "2026-09-08", epoch: 0, salt: .choreography)
        let b = seed(dayKey: "2026-09-08", epoch: 0, salt: .choreography)
        #expect(a == b)
        #expect(a != 0) // a real digest truncation is not the zero seed
    }

    @Test("a different day key derives a different seed")
    func dayVariation() {
        #expect(seed(dayKey: "2026-09-08", epoch: 0, salt: .copy) != seed(dayKey: "2026-09-09", epoch: 0, salt: .copy))
    }

    // MARK: - Salt separation + epoch/pet sensitivity

    @Test("the three salts are pairwise separated for identical other inputs")
    func saltSeparation() {
        let salts: [DaySeed.Salt] = [.choreography, .copy, .quest]
        let seeds = Set(salts.map { seed(dayKey: "2026-09-08", epoch: 0, salt: $0) })
        #expect(seeds.count == 3)
    }

    @Test("epoch change re-seeds (choreographyEpoch / questGenEpoch semantics)")
    func epochSensitivity() {
        let epochZero = seed(dayKey: "2026-09-08", epoch: 0, salt: .choreography)
        let epochOne = seed(dayKey: "2026-09-08", epoch: 1, salt: .choreography)
        let epochHuge = seed(dayKey: "2026-09-08", epoch: Int.max, salt: .choreography)
        #expect(epochZero != epochOne)
        #expect(epochOne != epochHuge)
        #expect(epochZero != epochHuge)
    }

    @Test("pet identity is part of the seed — different pets never share a day seed")
    func petIDSensitivity() {
        let other = UUID(uuidString: "7C47A9C4-2E5F-4B8A-9C1D-3E6F8A2B4C0E")!
        #expect(seed(dayKey: "2026-09-08", epoch: 0, salt: .quest) != seed(dayKey: "2026-09-08", epoch: 0, salt: .quest, petID: other))
    }

    // MARK: - Documented encoding contract

    @Test("salt raw values are the §4.10 strings, byte-for-byte")
    func saltRawValues() {
        #expect(DaySeed.Salt.allCases.map(\.rawValue) == ["choreography", "copy", "quest"])
    }

    @Test("preimage encoding: length-framed fields in the documented order (golden bytes)")
    func preimageGoldenBytes() {
        let zeroID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
        let bytes = DaySeed.preimage(petID: zeroID, localDayKey: "2026-09-08", epoch: 0, salt: .copy)
        let expected: [UInt8] =
            [0x00, 0x00, 0x00, 0x10]                                   // length 16
            + [UInt8](repeating: 0, count: 16)                         // UUID.uuid (16 zero bytes)
            + [0x00, 0x00, 0x00, 0x0A]                                 // length 10
            + Array("2026-09-08".utf8)                                 // day key, UTF-8
            + [0x00, 0x00, 0x00, 0x08]                                 // length 8
            + [UInt8](repeating: 0, count: 8)                          // epoch 0, 8-byte BE
            + [0x00, 0x00, 0x00, 0x04]                                 // length 4
            + Array("copy".utf8)                                       // salt, UTF-8
        #expect(bytes == expected)
        #expect(bytes.count == 54)
    }

    @Test("preimage encoding is self-delimiting: a frame parser round-trips the fields")
    func preimageRoundTrips() {
        let bytes = DaySeed.preimage(petID: petID, localDayKey: "2569-09-08", epoch: 42, salt: .quest)
        let frames = Self.parseFrames(bytes) // throws away nothing; proves unique parsing
        #expect(frames.count == 4)
        #expect(frames[0].count == 16)                       // petID bytes
        #expect(frames[0] == DaySeed.uuidBytes(petID))       // RFC 4122 byte form, not the string
        #expect(String(decoding: frames[1], as: UTF8.self) == "2569-09-08")
        #expect(frames[2] == DaySeedTests.bigEndianBytes(42))
        #expect(String(decoding: frames[3], as: UTF8.self) == "quest")
    }

    @Test("seed equals the first 8 digest bytes, big-endian (documented truncation)")
    func truncationContract() {
        let preimage = DaySeed.preimage(petID: petID, localDayKey: "2026-12-31", epoch: 7, salt: .quest)
        let digest = SHA256.digest(preimage)
        var expected: UInt64 = 0
        for byte in digest.prefix(8) {
            expected = (expected << 8) | UInt64(byte)
        }
        #expect(DaySeed.make(petID: petID, localDayKey: "2026-12-31", epoch: 7, salt: .quest) == expected)
    }

    // MARK: - Helpers

    /// Minimal frame parser — the proof that the length framing is
    /// unambiguous: the fields can be recovered from the byte stream alone.
    private static func parseFrames(_ bytes: [UInt8]) -> [[UInt8]] {
        var frames: [[UInt8]] = []
        var index = 0
        while index < bytes.count {
            var length: UInt32 = 0
            for _ in 0..<4 {
                length = (length << 8) | UInt32(bytes[index])
                index += 1
            }
            frames.append(Array(bytes[index ..< index + Int(length)]))
            index += Int(length)
        }
        return frames
    }

    private static func bigEndianBytes(_ value: Int) -> [UInt8] {
        let bits = UInt64(bitPattern: Int64(value))
        return (0..<8).reversed().map { UInt8(truncatingIfNeeded: bits >> (UInt64($0) * 8)) }
    }
}
