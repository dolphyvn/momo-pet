import Testing
@testable import MomoCore

/// SplitMix64 reference-vector pins + generator behavior (TASK-014
/// Requirement 6 / AC-3).
///
/// Source of truth: the canonical SplitMix64 core (Steele, Lea & Flood,
/// OOPSLA 2014, doi:10.1145/2714064.2660195) as published in Sebastiano
/// Vigna's public-domain `splitmix64.c/.h` reference (vendored at
/// bashtage/randomgen `randomgen/src/splitmix64/`), byte-identical constants
/// in the Zig stdlib `Random.SplitMix64`. The expectations below were
/// computed with an INDEPENDENT reimplementation of that reference in Python
/// (`(state += 0x9E3779B97F4A7C15); z = state; z = (z^(z>>30)) *
/// 0xBF58476D1CE4E5B9; z = (z^(z>>27)) * 0x94D049BB133111EB; return z^(z>>31)`
/// over 64-bit wrapping arithmetic) — e.g. seed 0 draws
/// `0xe220a8397b1dcdaf, 0x6e789e6aa1b965f4, 0x06c45d188009454f,
/// 0xf88bb8a8724c81ec`; seed 1 opens `0x910a2dec89025cc1`; seed 2 opens
/// `0x975835de1c9756ce`.
@Suite("SeededGenerator (SplitMix64-class)")
struct SeededGeneratorTests {

    // MARK: - Reference vectors

    @Test("seed 0: first four outputs match the reference computation")
    func seed0Vector() {
        var generator = SeededGenerator(seed: 0)
        #expect(generator.next() == 0xE220A8397B1DCDAF)
        #expect(generator.next() == 0x6E789E6AA1B965F4)
        #expect(generator.next() == 0x06C45D188009454F)
        #expect(generator.next() == 0xF88BB8A8724C81EC)
    }

    @Test("seeds 1 and 2: first two outputs match the reference computation")
    func seed1And2Vectors() {
        var one = SeededGenerator(seed: 1)
        #expect(one.next() == 0x910A2DEC89025CC1)
        #expect(one.next() == 0xBEEB8DA1658EEC67)
        var two = SeededGenerator(seed: 2)
        #expect(two.next() == 0x975835DE1C9756CE)
        #expect(two.next() == 0xBFC846100BFC1E42)
    }

    // MARK: - Determinism and statefulness

    @Test("same seed ⇒ identical sequence; the state advances per draw")
    func determinismAndStatefulness() {
        let draws = { (seed: UInt64) -> [UInt64] in
            var generator = SeededGenerator(seed: seed)
            return (0..<32).map { _ in generator.next() }
        }
        #expect(draws(0xDEADBEEF) == draws(0xDEADBEEF))
        #expect(draws(0xDEADBEEF) != draws(0xDEADBEEF - 1))

        // Statefulness: consuming one draw shifts the whole tail by one.
        var a = SeededGenerator(seed: 42)
        let aHead = (0..<8).map { _ in a.next() }               // draws 1…8
        var b = SeededGenerator(seed: 42)
        _ = b.next()                                            // skip draw 1
        let bTail = (0..<8).map { _ in b.next() }               // draws 2…9
        #expect(aHead != bTail)
        #expect(bTail == Array(aHead.dropFirst()) + [a.next()]) // b's tail is a's tail shifted by one
        #expect(a.state == b.state)                             // equal consumption ⇒ aligned state
    }

    @Test("conforms to RandomNumberGenerator: stdlib draws are deterministic per seed")
    func randomNumberGeneratorConformance() {
        func roll(seed: UInt64) -> [UInt64] {
            var generator = SeededGenerator(seed: seed)
            return (0..<5).map { _ in UInt64.random(in: .min ... .max, using: &generator) }
        }
        #expect(roll(seed: 7) == roll(seed: 7))
        #expect(roll(seed: 7) != roll(seed: 8))
    }

    @Test("Sendable by value: a copy never observes later draws of the original")
    func valueSemantics() {
        var original = SeededGenerator(seed: 9)
        let copy = original
        _ = original.next()
        _ = original.next()
        // The copy still sits before the first draw of seed 9.
        #expect(copy.state == 9)
        var thawed = copy
        #expect(thawed.next() == 0xAEAF52FEBE706064) // seed-9 first draw, reference computation
    }
}
