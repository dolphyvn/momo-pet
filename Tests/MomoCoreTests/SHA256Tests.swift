import Foundation
import Testing
@testable import MomoCore

/// SHA-256 correctness pins (TASK-014 Requirement 7 / AC-3).
///
/// The first four cases are the official NIST example digests published with
/// FIPS 180-4 (and in NIST's example-hash tables); the boundary cases cover
/// the padding paths (longest one-block message, exact-block, block+1).
/// Every expectation below was independently cross-checked against the
/// system `shasum -a 256` (OpenSSL) before being pinned — the assertions are
/// real digests, not smoke checks.
@Suite("SHA-256 (FIPS 180-4, repo-owned)")
struct SHA256Tests {

    /// Renders a digest as lowercase hex for readable expectations.
    private func hex(_ digest: [UInt8]) -> String {
        digest.map { String(format: "%02x", $0) }.joined()
    }

    private func digestBytes(_ string: String) -> String {
        hex(SHA256.digest(Array(string.utf8)))
    }

    // MARK: - NIST example vectors

    @Test("NIST: the 3-byte \"abc\" vector")
    func nistAbc() {
        #expect(digestBytes("abc") == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    }

    @Test("NIST: the empty-message vector")
    func nistEmpty() {
        #expect(digestBytes("") == "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
    }

    @Test("NIST: the 56-byte two-block vector")
    func nist56Bytes() {
        let message = "abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq"
        #expect(message.utf8.count == 56)
        #expect(digestBytes(message) == "248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1")
    }

    @Test("NIST: one million 'a' bytes")
    func nistMillionA() {
        let millionA = Array(repeating: UInt8(ascii: "a"), count: 1_000_000)
        #expect(hex(SHA256.digest(millionA)) == "cdc76e5c9914fb9281a1c7e284d73e67f1809a48a497200e046d39ccc7112cd0")
    }

    // MARK: - Padding boundary paths (expectations verified via `shasum -a 256`)

    @Test("55 bytes: the longest message that fits one block after padding")
    func boundary55Bytes() {
        let message = "abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnop"
        #expect(message.utf8.count == 55)
        #expect(digestBytes(message) == "aa353e009edbaebfc6e494c8d847696896cb8b398e0173a4b5c1b636292d87c7")
    }

    @Test("63/64/65 bytes: straddling the block boundary")
    func boundaryAroundOneBlock() {
        let bytes63 = Array(UInt8(0)..<UInt8(63))       // 0x00...0x3E
        let bytes64 = Array(UInt8(0)..<UInt8(64))       // 0x00...0x3F
        let bytes65 = Array(UInt8(0)..<UInt8(65))       // 0x00...0x40
        #expect(hex(SHA256.digest(bytes63)) == "29af2686fd53374a36b0846694cc342177e428d1647515f078784d69cdb9e488")
        #expect(hex(SHA256.digest(bytes64)) == "fdeab9acf3710362bd2658cdc9a29e8f9c757fcf9811603a8c447cd1d9151108")
        #expect(hex(SHA256.digest(bytes65)) == "4bfd2c8b6f1eec7a2afeb48b934ee4b2694182027e6d0fc075074f2fabb31781")
    }

    // MARK: - Contract shape

    @Test("digest length is exactly 32 bytes and the function is deterministic")
    func digestLengthAndDeterminism() {
        let input = Array("momo".utf8)
        #expect(SHA256.digest(input).count == 32)
        #expect(SHA256.digest(input) == SHA256.digest(input))
    }
}
