// MARK: - Seeded generator (05-technical-architecture §4.10; ADR-004)

/// The repo-owned seeded random number generator (05 §4.10: "a repo-owned
/// seeded generator (SplitMix64-class, ~20 lines, no dependency) conforming to
/// `RandomNumberGenerator`, injected as `inout`"). Never system randomness
/// inside the engine or the sequencer.
///
/// The algorithm is the canonical **SplitMix64** core (G. L. Steele Jr.,
/// D. Lea, C. N. Flood, "Fast Splittable Pseudorandom Number Generators",
/// OOPSLA 2014, doi:10.1145/2714064.2660195 — the fixed-increment version of
/// Java 8's `SplittableRandom`). The constant/shift sequence below is byte
/// for byte Sebastiano Vigna's public-domain reference `splitmix64.c/.h`
/// (vendored, e.g., in bashtage/randomgen `randomgen/src/splitmix64/`) and
/// matches the Zig standard library's `std.Random.SplitMix64`.
///
/// Determinism is pinned by `SeededGeneratorTests.swift` against reference
/// outputs computed independently (Python reimplementation of the same
/// canonical form, cross-checked against this source); the generator is a
/// seeding/stirring primitive for choreography/copy/quest draws (§4.10), not
/// a cryptographic primitive.
public struct SeededGenerator: RandomNumberGenerator, Sendable {

    /// The mixing state; advanced once per draw. `private(set)` keeps the
    /// sequence observable only through `next()`.
    public private(set) var state: UInt64

    /// Seeds the generator with a 64-bit day seed (§4.10's `DaySeed.make`
    /// output, or any fixed constant in tests).
    public init(seed: UInt64) {
        self.state = seed
    }

    /// The SplitMix64 output function: advance the state by the golden-ratio
    /// constant, then the three-step xor/multiply finalizer.
    public mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
