import Foundation
import MomoCore

/// The idle sequencer's deterministic sampler, built ON TOP of MomoCore's
/// repo-owned `SeededGenerator` (SplitMix64, 05-technical-architecture
/// §4.10; pinned by `SeededGeneratorTests`). 04 §9.4: the character never
/// calls system randomness — every draw flows from the injected 64-bit
/// `idleSeed` through this sampler, so the whole idle event log is a pure
/// function of `(idleSeed, displayState, window)`.
///
/// Two derived distributions:
/// - **Uniform** `[0, 1)`: the generator's 64-bit output mapped to the top
///   53 bits, so every double in the range is representable:
///   `Double(z >> 11) / 2^53`.
/// - **Normal**: Box–Muller — `mean + σ·√(−2·ln u1)·cos(2π·u2)` consuming
///   one uniform per factor. `u1 = 0` (probability 2^−53) is clamped to
///   2^−52 so the logarithm stays finite; the clamp is deterministic and
///   the draw order is fixed, so the sequence is reproducible.
public struct MomoIdleRandom: Sendable {

    private var generator: SeededGenerator

    /// Seeds the sampler from the engine-injected idle seed (§5.1: the seed
    /// is an opaque UInt64 to the character).
    public init(seed: UInt64) {
        self.generator = SeededGenerator(seed: seed)
    }

    /// The next uniform draw in `[0, 1)`.
    public mutating func nextUniform() -> Double {
        Double(generator.next() >> 11) * (1.0 / 9_007_199_254_740_992.0) // 2^53
    }

    /// The next draw from N(`mean`, `sigma`) via Box–Muller.
    public mutating func nextNormal(mean: Double, standardDeviation sigma: Double) -> Double {
        // Clamp keeps ln finite at the (measure-zero) zero draw.
        let u1 = max(nextUniform(), 2.220446049250313e-16) // 2^-52
        let u2 = nextUniform()
        let magnitude = (-2 * log(u1)).squareRoot()
        return mean + sigma * magnitude * cos(2 * Double.pi * u2)
    }

    /// A uniform draw from `range`.
    public mutating func nextUniform(in range: ClosedRange<Double>) -> Double {
        range.lowerBound + nextUniform() * (range.upperBound - range.lowerBound)
    }

    /// A weighted draw: `entries` pairs each value with its relative weight
    /// and fixes the scan order (callers pass a literal, canonical order —
    /// never dictionary iteration). Values with weight ≤ 0 never draw;
    /// zero total weight draws nothing. Deterministic for a given sampler
    /// state.
    public mutating func nextWeighted<Value>(
        _ entries: [(value: Value, weight: Double)]
    ) -> Value? {
        let total = entries.reduce(0) { $0 + max(0, $1.weight) }
        guard total > 0 else { return nil }
        var dart = nextUniform() * total
        for entry in entries where entry.weight > 0 {
            dart -= entry.weight
            if dart < 0 { return entry.value }
        }
        // Float fallthrough (dart within rounding of total): the last
        // positive-weight entry.
        return entries.last { $0.weight > 0 }?.value
    }
}
