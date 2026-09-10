import Foundation
import MomoCore
import Testing

@testable import MomoCharacter

/// The idle sequencer's deterministic sampler (04 §5.1/§9.4): every value
/// flows from the seed through MomoCore's pinned SplitMix64 — no system
/// randomness anywhere. Pins carry raw literals mirrored from an
/// independent SplitMix64 implementation (validated against
/// `SeededGeneratorTests`' seed-0/seed-9 vectors before mirroring), so a
/// sampler change shows up as a pin failure, not a silent drift.
@Suite("MomoIdleRandom — seeded uniforms, Box–Muller normals, weighted draws")
struct MomoIdleRandomTests {

    // MARK: - Uniform draws

    @Test("Uniforms are the pinned SplitMix64 stream: raw-literal pins")
    func uniformPins() {
        var random = MomoIdleRandom(seed: 0)
        #expect(random.nextUniform() == 0.88331080821364261)
        #expect(random.nextUniform() == 0.43152799704850997)
        #expect(random.nextUniform() == 0.026433771592597743)
        #expect(random.nextUniform() == 0.97088197815382848)
        #expect(random.nextUniform() == 0.10634669156721244)
        #expect(random.nextUniform() == 0.32732576421812576)
    }

    @Test("A uniform draw is Double(generator.next() >> 11) / 2^53 — the mapping itself")
    func uniformMapping() {
        var random = MomoIdleRandom(seed: 0)
        // Seed 0's first generator output, pinned by SeededGeneratorTests.
        let firstOutput: UInt64 = 0xE220_A839_7B1D_CDAF
        #expect(random.nextUniform() == Double(firstOutput >> 11) / 9_007_199_254_740_992.0)
    }

    @Test("Uniforms land in [0, 1) across a seed battery")
    func uniformRange() {
        for seed: UInt64 in 0..<64 {
            var random = MomoIdleRandom(seed: seed)
            for _ in 0..<64 {
                let draw = random.nextUniform()
                #expect(draw >= 0 && draw < 1)
            }
        }
    }

    @Test("Range draws map into the requested band; the band's span is preserved")
    func rangeDraws() {
        var random = MomoIdleRandom(seed: 7)
        #expect(random.nextUniform(in: 2.0...5.0) == 3.1694892451738146)
        #expect(random.nextUniform(in: 2.0...5.0) == 2.0503648835844683)
        #expect(random.nextUniform(in: 2.0...5.0) == 4.70228204182065)

        var battery = MomoIdleRandom(seed: 3)
        for _ in 0..<128 {
            #expect((1.5...4.0).contains(battery.nextUniform(in: 1.5...4.0)))
        }
    }

    // MARK: - Normal draws (Box–Muller)

    @Test("Normals are the pinned Box–Muller transform of the uniform stream")
    func normalPins() {
        var random = MomoIdleRandom(seed: 0)
        #expect(random.nextNormal(mean: 6, standardDeviation: 2) == 5.0944845195650839)
        #expect(random.nextNormal(mean: 0, standardDeviation: 1) == 2.6506058120796703)
    }

    @Test("Normals reproduce their mean and sigma across a battery")
    func normalDistribution() {
        var random = MomoIdleRandom(seed: 11)
        var sum = 0.0
        var sumSquares = 0.0
        let n = 20_000
        for _ in 0..<n {
            let draw = random.nextNormal(mean: 6, standardDeviation: 2)
            sum += draw
            sumSquares += draw * draw
        }
        let mean = sum / Double(n)
        let sigma = (sumSquares / Double(n) - mean * mean).squareRoot()
        #expect(abs(mean - 6) < 0.05)
        #expect(abs(sigma - 2) < 0.05)
    }

    @Test("Same seed, same sequence — different seed, different sequence")
    func determinism() {
        var a = MomoIdleRandom(seed: 42)
        var b = MomoIdleRandom(seed: 42)
        var c = MomoIdleRandom(seed: 43)
        for _ in 0..<32 {
            let drawA = a.nextUniform()
            #expect(drawA == b.nextUniform())
            #expect(drawA != c.nextUniform())
        }
    }

    // MARK: - Weighted draws

    @Test("Weighted draws follow the weights in the array's canonical order")
    func weightedDraws() {
        var random = MomoIdleRandom(seed: 0)
        let entries = [(value: "a", weight: 1.0), (value: "b", weight: 3.0)]
        let expected = ["b", "b", "a", "b", "a", "b"]
        for want in expected {
            #expect(random.nextWeighted(entries) == want)
        }
    }

    @Test("Zero-weight entries never draw; an all-zero set draws nothing")
    func weightedZeroWeights() {
        var random = MomoIdleRandom(seed: 5)
        // Only the positive-weight entry can ever come out.
        for _ in 0..<32 {
            #expect(
                random.nextWeighted([
                    (value: "never", weight: 0), (value: "always", weight: 2.5),
                ]) == "always")
        }
        #expect(random.nextWeighted([(value: "x", weight: 0)]) == nil)
    }

    @Test("The entry array's order IS the scan contract — replay is deterministic")
    func weightedOrderIsTheContract() {
        // Callers pass a literal canonical order (documented); whatever the
        // order, the same seed replays the same draw sequence byte-for-byte.
        let ab = [(value: "a", weight: 1.0), (value: "b", weight: 1.0)]
        var pinned = MomoIdleRandom(seed: 9)
        let sequence = (0..<8).map { _ in pinned.nextWeighted(ab) }
        var replay = MomoIdleRandom(seed: 9)
        for want in sequence {
            #expect(replay.nextWeighted(ab) == want)
        }
        #expect(sequence.contains("a") && sequence.contains("b"))
    }
}
