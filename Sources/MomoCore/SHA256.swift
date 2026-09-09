// MARK: - Repo-owned SHA-256 (FIPS 180-4)

/// SHA-256 message digest (FIPS 180-4), implemented in-repo with zero
/// dependencies (TASK-014; ADR-004 "day-stable seeds"; 05 §4.10).
///
/// Why repo-owned: `Foundation` alone provides no SHA-256, and D-R1 bans
/// importing CryptoKit into MomoCore — so the digest the day-stable seed
/// derivation needs (05 §4.10) lives here, ~70 lines, standard library only.
/// Correctness is pinned to the official NIST example vectors (the "abc",
/// empty-message, 56-byte two-block, and one-million-'a' digests published in
/// and alongside FIPS 180-4) plus block-boundary cases, in
/// `SHA256Tests.swift`; the expectations were independently cross-checked
/// against the system `shasum -a 256` (OpenSSL) before being pinned.
///
/// SHA-256 is standardized and stable across OS versions and devices, which
/// is exactly what §4.10 requires: same day ⇒ same seed on iPhone and in
/// tests. This implementation is NOT hardened against side channels (no
/// secret-constant-time concerns — it digests pet identity + calendar day +
/// small integers, never credentials); it is a correctness-pinned
/// deterministic function, not a security boundary.
public enum SHA256 {

    /// The 64 round constants K (FIPS 180-4 §4.2.2: the first 32 bits of the
    /// fractional parts of the cube roots of the first 64 primes).
    private static let roundConstants: [UInt32] = [
        0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
        0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
        0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
        0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
        0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
        0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
        0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
        0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
    ]

    /// The initial hash values H⁽⁰⁾ (FIPS 180-4 §5.3.3: the first 32 bits of
    /// the fractional parts of the square roots of the first 8 primes).
    private static let initialHash: [UInt32] = [
        0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
        0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19,
    ]

    /// Computes the 32-byte SHA-256 digest of `message` (FIPS 180-4 §6.2).
    public static func digest(_ message: [UInt8]) -> [UInt8] {
        var hash = initialHash
        let bitLength = UInt64(message.count) * 8
        for block in paddedBlocks(message, messageBitLength: bitLength) {
            compress(&hash, block: block)
        }
        var output: [UInt8] = []
        output.reserveCapacity(32)
        for word in hash {
            output.append(UInt8(truncatingIfNeeded: word >> 24))
            output.append(UInt8(truncatingIfNeeded: word >> 16))
            output.append(UInt8(truncatingIfNeeded: word >> 8))
            output.append(UInt8(truncatingIfNeeded: word))
        }
        return output
    }

    /// FIPS 180-4 §5.1.1 padding, sliced into 64-byte blocks: append the
    /// 0x80 terminator, zero-fill to 56 bytes mod 64, then the 64-bit
    /// big-endian message bit length.
    private static func paddedBlocks(_ message: [UInt8], messageBitLength: UInt64) -> [[UInt8]] {
        var padded = message
        padded.append(0x80)
        while padded.count % 64 != 56 {
            padded.append(0x00)
        }
        for shift in stride(from: 56, through: 0, by: -8) {
            padded.append(UInt8(truncatingIfNeeded: messageBitLength >> UInt64(shift)))
        }
        return stride(from: 0, to: padded.count, by: 64).map { Array(padded[$0 ..< $0 + 64]) }
    }

    /// The FIPS 180-4 §6.2.2 compression function over one 512-bit block.
    private static func compress(_ hash: inout [UInt32], block: [UInt8]) {
        var w = [UInt32](repeating: 0, count: 64)
        for i in 0..<16 {
            let j = i * 4
            w[i] = (UInt32(block[j]) << 24)
                | (UInt32(block[j + 1]) << 16)
                | (UInt32(block[j + 2]) << 8)
                | UInt32(block[j + 3])
        }
        for i in 16..<64 {
            let s0 = rotr(w[i - 15], 7) ^ rotr(w[i - 15], 18) ^ (w[i - 15] >> 3)
            let s1 = rotr(w[i - 2], 17) ^ rotr(w[i - 2], 19) ^ (w[i - 2] >> 10)
            w[i] = w[i - 16] &+ s0 &+ w[i - 7] &+ s1
        }
        var a = hash[0], b = hash[1], c = hash[2], d = hash[3]
        var e = hash[4], f = hash[5], g = hash[6], h = hash[7]
        for i in 0..<64 {
            let bigS1 = rotr(e, 6) ^ rotr(e, 11) ^ rotr(e, 25)
            let choose = (e & f) ^ (~e & g)
            let temp1 = h &+ bigS1 &+ choose &+ roundConstants[i] &+ w[i]
            let bigS0 = rotr(a, 2) ^ rotr(a, 13) ^ rotr(a, 22)
            let majority = (a & b) ^ (a & c) ^ (b & c)
            let temp2 = bigS0 &+ majority
            h = g
            g = f
            f = e
            e = d &+ temp1
            d = c
            c = b
            b = a
            a = temp1 &+ temp2
        }
        hash[0] = hash[0] &+ a
        hash[1] = hash[1] &+ b
        hash[2] = hash[2] &+ c
        hash[3] = hash[3] &+ d
        hash[4] = hash[4] &+ e
        hash[5] = hash[5] &+ f
        hash[6] = hash[6] &+ g
        hash[7] = hash[7] &+ h
    }

    /// 32-bit rotate right (FIPS 180-4 §3.2 ROTRⁿ(x)).
    private static func rotr(_ x: UInt32, _ n: UInt32) -> UInt32 {
        (x >> n) | (x << (32 - n))
    }
}
