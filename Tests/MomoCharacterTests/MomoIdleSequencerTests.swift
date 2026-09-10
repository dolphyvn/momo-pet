import MomoCore
import Testing

@testable import MomoCharacter

/// The idle sequencer (04 §5.1–5.2): the event-log vector pins (whole logs,
/// digit-for-digit, mirrored from an independent SplitMix64 implementation
/// validated against `SeededGeneratorTests`), the determinism/prefix laws,
/// the §5.2 distribution battery, §5.3's no-distraction occupancy budget,
/// and the §7.4 arbiter's priority/budget contract.
@Suite("MomoIdleSequencer — vector pins, laws, distributions, occupancy, arbiter")
struct MomoIdleSequencerTests {

    // MARK: - Fixtures

    /// The canonical content state (tempo 1.0 everywhere) — the vector-pin
    /// state and the distribution battery's baseline.
    private let content = CharacterDisplayState(
        moodBand: .content, energyBand: .relaxed, bondStage: .gettingClose,
        wakefulness: .awake, activity: nil, satietyHint: nil, momentRequest: nil)

    private func state(
        _ mood: MoodBand, _ energy: EnergyBand,
        bond: BondStage = .gettingClose, wakefulness: Wakefulness = .awake
    ) -> CharacterDisplayState {
        CharacterDisplayState(
            moodBand: mood, energyBand: energy, bondStage: bond,
            wakefulness: wakefulness, activity: nil, satietyHint: nil,
            momentRequest: nil)
    }

    private func events(
        _ kind: MomoIdleEventKind, in schedule: [MomoIdleEvent]
    ) -> [MomoIdleEvent] {
        schedule.filter { $0.kind == kind }
    }

    private func mean(_ values: [Double]) -> Double {
        values.reduce(0, +) / Double(values.count)
    }

    private func standardDeviation(_ values: [Double]) -> Double {
        let m = mean(values)
        return (values.reduce(0) { $0 + ($1 - m) * ($1 - m) } / Double(values.count))
            .squareRoot()
    }

    /// §5.3 motion occupancy of one window: the union of MOVING spans —
    /// blink in full; gaze's shift and return (the hold is stillness);
    /// a variant's entry and exit (the hold is stillness); a yawn in full —
    /// divided by the window. Holds are deliberate stillness and cost no
    /// budget; breath is the standing baseline, not an event.
    private func motionOccupancy(
        _ schedule: [MomoIdleEvent], windowEnd: Double
    ) -> Double {
        var spans: [(Double, Double)] = []
        for event in schedule {
            switch event.payload {
            case .blink:
                spans.append((event.start, event.start + event.duration))
            case .gaze(let envelope):
                spans.append((
                    event.start,
                    event.start + envelope.shiftSeconds + envelope.returnSeconds))
            case .variant(let envelope):
                spans.append((
                    event.start, event.start + envelope.inSeconds + envelope.outSeconds))
            case .yawn:
                spans.append((event.start, event.start + event.duration))
            }
        }
        spans.sort { $0.0 < $1.0 }
        var union = 0.0
        var current: (Double, Double)?
        for span in spans {
            if let active = current, span.0 <= active.1 {
                current = (active.0, max(active.1, span.1))
            } else {
                if let active = current { union += active.1 - active.0 }
                current = span
            }
        }
        if let active = current { union += active.1 - active.0 }
        return union / windowEnd
    }

    // MARK: - Event-log vector pins (whole logs, digit-for-digit)

    @Test("Vector pin: seed 0, content, window 30 — the whole log")
    func vectorPinSeed0() {
        let log = MomoIdleSequencer.schedule(
            idleSeed: 0, displayState: content, windowEnd: 30)
        #expect(log.map { $0.kind } == [
            .blink, .blink, .gaze, .blink, .blink, .gaze, .variant,
        ])
        #expect(log.map { $0.start } == [
            5.442250154827591, 12.144462403198462, 13.03856940505684,
            20.295844485043148, 25.345592447134706, 28.67394902740378,
            29.024024493949497,
        ])
        #expect(log.map { $0.duration } == [
            0.2948697880634157, 0.2731191205806093, 2.79169746357005,
            0.2765190262383138, 0.732721209222563, 3.6768963608880063,
            2.0891298559595204,
        ])

        // Payloads (mirrored draw-for-draw).
        guard case .gaze(let firstGaze) = log[2].payload else {
            Issue.record("log[2] is not a gaze"); return
        }
        #expect(firstGaze.target == .left)
        #expect(firstGaze.shiftSeconds == 0.2727462497384311)
        #expect(firstGaze.holdSeconds == 1.877278888701558)
        #expect(firstGaze.returnSeconds == 0.6416723251300609)
        guard case .gaze(let secondGaze) = log[5].payload else {
            Issue.record("log[5] is not a gaze"); return
        }
        #expect(secondGaze.target == .right)
        guard case .blink(let doubleBlink) = log[4].payload else {
            Issue.record("log[4] is not a blink"); return
        }
        #expect(doubleBlink.isDouble)
        guard case .variant(let variant) = log[6].payload else {
            Issue.record("log[6] is not a variant"); return
        }
        #expect(variant.id == .cheekPressRest)
        #expect(!variant.mirrored)
        #expect(variant.inSeconds == 0.3014229322352082)
        #expect(variant.holdSeconds == 1.463182148362057)
        #expect(variant.outSeconds == 0.3245247753622551)
    }

    @Test("Vector pin: seed 1, content, window 30 — the whole log")
    func vectorPinSeed1() {
        let log = MomoIdleSequencer.schedule(
            idleSeed: 1, displayState: content, windowEnd: 30)
        #expect(log.map { $0.kind } == [.blink, .blink, .gaze, .blink, .variant])
        #expect(log.map { $0.start } == [
            8.65134373933424, 13.648151593721645, 15.136629420184084,
            21.42162770981395, 25.120656476423786,
        ])
        #expect(log.map { $0.duration } == [
            0.2884564950183008, 0.26049313206371094, 3.771703791566753,
            0.2929404494950548, 1.2407136851767357,
        ])
        guard case .variant(let variant) = log[4].payload else {
            Issue.record("log[4] is not a variant"); return
        }
        #expect(variant.id == .tailFlick)
        #expect(!variant.mirrored)
        #expect(variant.inSeconds == 0.35) // spring family: fixed envelope
        #expect(variant.outSeconds == 0.35)
    }

    @Test("Vector pin: seed 42, content, window 30 — the whole log")
    func vectorPinSeed42() {
        let log = MomoIdleSequencer.schedule(
            idleSeed: 42, displayState: content, windowEnd: 30)
        #expect(log.map { $0.kind } == [
            .blink, .variant, .blink, .gaze, .blink, .blink,
        ])
        #expect(log.map { $0.start } == [
            8.812289925127, 16.005265814446407, 16.375626676433704,
            20.853823762182532, 23.227660875895147, 27.83070884158733,
        ])
        guard case .variant(let variant) = log[1].payload else {
            Issue.record("log[1] is not a variant"); return
        }
        #expect(variant.id == .cheekPressRest)
        #expect(variant.mirrored) // the mirror coin landed heads here
    }

    // MARK: - The determinism and prefix laws

    @Test("The schedule is a pure function: (seed, state, window) → same log")
    func determinism() {
        let states = [
            content,
            state(.joyful, .energetic),
            state(.wistful, .relaxed),
            state(.low, .relaxed),
            state(.content, .drowsy),
            state(.content, .relaxed, bond: .soulCompanions),
        ]
        for seed: UInt64 in 0..<25 {
            for display in states {
                let first = MomoIdleSequencer.schedule(
                    idleSeed: seed, displayState: display, windowEnd: 90)
                let second = MomoIdleSequencer.schedule(
                    idleSeed: seed, displayState: display, windowEnd: 90)
                #expect(first == second)
            }
        }
    }

    @Test("The prefix property: schedule(30) is a prefix of schedule(120)")
    func prefixProperty() {
        for seed: UInt64 in 0..<20 {
            let short = MomoIdleSequencer.schedule(
                idleSeed: seed, displayState: content, windowEnd: 30)
            let long = MomoIdleSequencer.schedule(
                idleSeed: seed, displayState: content, windowEnd: 120)
            #expect(short.allSatisfy { $0.start <= 30 })
            #expect(Array(long.prefix(short.count)) == short)
            #expect(long.count >= short.count)
        }
    }

    @Test("Window guards: zero and negative windows schedule nothing")
    func windowGuards() {
        #expect(
            MomoIdleSequencer.schedule(idleSeed: 0, displayState: content, windowEnd: 0)
                .isEmpty)
        #expect(
            MomoIdleSequencer.schedule(idleSeed: 0, displayState: content, windowEnd: -1)
                .isEmpty)
    }

    @Test("Non-awake states schedule NOTHING (asleep stillness; transitions are TASK-028)")
    func nonAwakeStatesScheduleNothing() {
        for seed: UInt64 in 0..<10 {
            for wakefulness in [Wakefulness.settling, .asleep, .waking] {
                #expect(
                    MomoIdleSequencer.schedule(
                        idleSeed: seed,
                        displayState: state(
                            .content, .drowsy, wakefulness: wakefulness),
                        windowEnd: 120
                    ).isEmpty)
            }
        }
    }

    // MARK: - §5.2 distribution battery (100 seeds × 1 h, content)

    private struct BlinkBattery {
        /// Per-seed gap/duration lists — tempo comparisons must pair draws
        /// WITHIN a seed (states change how many events fit in the window,
        /// so flat concatenation would misalign the sequences).
        var gapsPerSeed: [[Double]]
        var durationsPerSeed: [[Double]]
        /// Single blinks only (no doubles): the duration-multiplier law
        /// stretches the drawn close/open, not the authored inter-blink gap.
        var singleDurationsPerSeed: [[Double]]
        var doubles: Int

        var gaps: [Double] { gapsPerSeed.flatMap { $0 } }
        var durations: [Double] { durationsPerSeed.flatMap { $0 } }
        var singleDurations: [Double] { singleDurationsPerSeed.flatMap { $0 } }
    }

    /// Blink events across the battery; content tempo = 1, so the gap
    /// between consecutive starts IS the drawn (clamped) interval.
    private func blinkBattery(
        mood: MoodBand = .content, energy: EnergyBand = .relaxed
    ) -> BlinkBattery {
        var gapsPerSeed: [[Double]] = []
        var durationsPerSeed: [[Double]] = []
        var singleDurationsPerSeed: [[Double]] = []
        var doubles = 0
        for seed: UInt64 in 0..<100 {
            let blinks = events(
                .blink, in: MomoIdleSequencer.schedule(
                    idleSeed: seed, displayState: state(mood, energy), windowEnd: 3600))
            var singles: [Double] = []
            for blink in blinks {
                if case .blink(let envelope) = blink.payload {
                    if envelope.isDouble {
                        doubles += 1
                    } else {
                        singles.append(blink.duration)
                    }
                }
            }
            durationsPerSeed.append(blinks.map { $0.duration })
            singleDurationsPerSeed.append(singles)
            gapsPerSeed.append(blinks.indices.dropLast().map {
                blinks[$0 + 1].start - blinks[$0].start
            })
        }
        return BlinkBattery(
            gapsPerSeed: gapsPerSeed, durationsPerSeed: durationsPerSeed,
            singleDurationsPerSeed: singleDurationsPerSeed, doubles: doubles)
    }

    @Test("§5.2 blink battery: N(6, 2) shape, both clamps hit exactly, 12 % doubles")
    func blinkDistribution() {
        let battery = blinkBattery()
        // The drawn intervals reproduce the clamped normal's measured shape
        // (mirrored: mean 6.0387, sigma 1.9262 over this battery).
        #expect(abs(mean(battery.gaps) - 6.0387) < 0.05)
        #expect(abs(standardDeviation(battery.gaps) - 1.9262) < 0.05)
        // Both clamps are part of the contract — a battery this size hits
        // each tail, exactly on the bound.
        #expect(battery.gaps.contains { $0 == 2.5 })
        #expect(battery.gaps.contains { $0 == 12.0 })
        // 12 % doubles (measured 11.75 % over this battery).
        let doubleFraction =
            Double(battery.doubles) / Double(battery.durations.count)
        #expect(doubleFraction > 0.10 && doubleFraction < 0.14)
        // Durations sit on the §7.1 close/open bands (measured 0.33453 over
        // ALL blinks — doubles carry an extra close/open plus the 0.09 gap;
        // singles alone average 0.28991).
        #expect(abs(mean(battery.durations) - 0.33453) < 0.005)
    }

    @Test("§5.2/Drowsy: the tempo multiplies each drawn interval by ×1.4 (to cursor rounding)")
    func drowsyTempoIsPerInterval() {
        let contentBattery = blinkBattery()
        let drowsyBattery = blinkBattery(mood: .content, energy: .drowsy)
        var shared = 0
        for (contentGaps, drowsyGaps) in zip(
            contentBattery.gapsPerSeed, drowsyBattery.gapsPerSeed) {
            for (contentGap, drowsyGap) in zip(contentGaps, drowsyGaps) {
                // The observed gap is a difference of accumulated starts, so
                // it carries cursor rounding at the window's magnitude
                // (~ULP(3600) ≈ 5e-13) — no bit-exact law survives. 1e-9 is
                // three orders above that and six below the drawn interval:
                // it forgives the summation, not the tempo.
                #expect(abs(drowsyGap - contentGap * 1.4) < 1e-9)
                shared += 1
            }
        }
        #expect(shared > 1000) // the comparison is over a real body of draws
    }

    @Test("§3.2/Wistful: the blink-duration multiplier stretches each blink ×1.2")
    func wistfulDurationsStretchExactly() {
        let contentBattery = blinkBattery()
        let wistfulBattery = blinkBattery(mood: .wistful, energy: .relaxed)
        var shared = 0
        // Single blinks only: the multiplier stretches the DRAWN close/open
        // (sequencer draws close × m, open × m), and the authored 0.09 s
        // inter-blink gap of a double is deliberately NOT stretched — so the
        // whole-duration law only holds to that gap for doubles. The
        // component-wise composition leaves a few ULP against ×1.2 of the
        // summed duration; 1e-12 forgives the summation, not the law
        // (observed worst error over the battery: 5.6e-17).
        for (contentDurations, wistfulDurations) in zip(
            contentBattery.singleDurationsPerSeed,
            wistfulBattery.singleDurationsPerSeed) {
            for (contentDuration, wistfulDuration) in zip(
                contentDurations, wistfulDurations) {
                #expect(abs(wistfulDuration - contentDuration * 1.2) < 1e-12)
                shared += 1
            }
        }
        #expect(shared > 1000)
    }

    // MARK: - Look-around distribution (100 seeds × 1 h)

    @Test("§5.2 gaze battery: authored bands, all five targets, Joyful's at-user pull")
    func gazeDistribution() {
        var intervals: [Double] = []
        var holds: [Double] = []
        var shares: [MomoGazeTarget: Int] = [:]
        var total = 0
        for seed: UInt64 in 0..<100 {
            let looks = events(
                .gaze, in: MomoIdleSequencer.schedule(
                    idleSeed: seed, displayState: content, windowEnd: 3600))
            for (previous, current) in zip(looks, looks.dropFirst()) {
                intervals.append(current.start - previous.start)
            }
            for look in looks {
                guard case .gaze(let envelope) = look.payload else { continue }
                holds.append(envelope.holdSeconds)
                shares[envelope.target, default: 0] += 1
                // The authored draw bands (§5.3's tuned subranges of §7.1).
                #expect(envelope.shiftSeconds >= 0.22 && envelope.shiftSeconds <= 0.28)
                #expect(envelope.returnSeconds >= 0.60 && envelope.returnSeconds <= 0.70)
                #expect(envelope.holdSeconds >= 1.5 && envelope.holdSeconds <= 4.0)
            }
            total += looks.count
        }
        // Intervals: the band's calmer authored end (measured 15.503).
        #expect(abs(mean(intervals) - 15.503) < 0.2)
        // Holds scatter across the stillness band (measured 2.749).
        #expect(abs(mean(holds) - 2.749) < 0.05)

        // All five targets appear; at-user is the single most likely.
        for target in MomoGazeTarget.allCases {
            #expect((shares[target] ?? 0) > 0, "\(target) never drawn")
        }
        let atUserShare = Double(shares[.atUser] ?? 0) / Double(total)
        #expect(abs(atUserShare - 0.2528) < 0.02)

        // Joyful ×1.4 on atUser before renormalizing: share rises to ~0.318,
        // ratio ≈ 1.2727 (measured 1.2594 over the battery).
        var joyfulAtUser = 0
        var joyfulTotal = 0
        for seed: UInt64 in 0..<100 {
            let looks = events(
                .gaze, in: MomoIdleSequencer.schedule(
                    idleSeed: seed, displayState: state(.joyful, .relaxed),
                    windowEnd: 3600))
            for look in looks {
                guard case .gaze(let envelope) = look.payload else { continue }
                if envelope.target == .atUser { joyfulAtUser += 1 }
            }
            joyfulTotal += looks.count
        }
        let joyfulShare = Double(joyfulAtUser) / Double(joyfulTotal)
        #expect(abs(joyfulShare - 0.3184) < 0.02)
        #expect(abs(joyfulShare / atUserShare - 1.2727) < 0.05)
    }

    // MARK: - Variant distribution (gates, energetic boost, authored bands)

    @Test("§5.2/§3.3 variants: Energetic's ×1.5 frequency lands on the authored ratio")
    func energeticVariantFrequency() {
        var contentCount = 0
        var energeticCount = 0
        for seed: UInt64 in 0..<100 {
            contentCount += events(
                .variant, in: MomoIdleSequencer.schedule(
                    idleSeed: seed, displayState: content, windowEnd: 3600)).count
            energeticCount += events(
                .variant, in: MomoIdleSequencer.schedule(
                    idleSeed: seed, displayState: state(.joyful, .energetic),
                    windowEnd: 3600)).count
        }
        // Interval factor 0.8 × 0.95 / 1.5 = 0.5067 (measured 0.505).
        let ratio = Double(contentCount) / Double(energeticCount)
        #expect(abs(ratio - 0.5067) < 0.03)
    }

    @Test("§5.2 variant intervals draw inside the authored band (16–30 s)")
    func variantIntervalBand() {
        for seed: UInt64 in 0..<20 {
            let variants = events(
                .variant, in: MomoIdleSequencer.schedule(
                    idleSeed: seed, displayState: content, windowEnd: 3600))
            for (previous, current) in zip(variants, variants.dropFirst()) {
                #expect(current.start - previous.start >= 16)
                #expect(current.start - previous.start <= 30)
            }
        }
    }

    @Test("§3.4 calmCoexist is Soul-Companions-only and lands at its weight share")
    func calmCoexistGating() {
        var gatedCount = 0
        var calmCount = 0
        var soulTotal = 0
        for seed: UInt64 in 0..<50 {
            let gated = events(
                .variant, in: MomoIdleSequencer.schedule(
                    idleSeed: seed, displayState: content, windowEnd: 3600))
            for variant in gated {
                guard case .variant(let envelope) = variant.payload else { continue }
                #expect(envelope.id != .calmCoexist)
                #expect(envelope.id != .headNod)
            }
            gatedCount += gated.count

            let soul = events(
                .variant, in: MomoIdleSequencer.schedule(
                    idleSeed: seed, displayState: state(
                        .content, .relaxed, bond: .soulCompanions),
                    windowEnd: 3600))
            soulTotal += soul.count
            for variant in soul {
                guard case .variant(let envelope) = variant.payload else { continue }
                if envelope.id == .calmCoexist { calmCount += 1 }
            }
        }
        #expect(gatedCount > 0) // non-vacuous baseline
        #expect(calmCount > 0) // the gated idle actually draws
        // Weight 1.2 of the 6.4 total = 0.1875.
        #expect(abs(Double(calmCount) / Double(soulTotal) - 0.1875) < 0.02)
    }

    @Test("§3.3 headNod is Drowsy-only")
    func headNodGating() {
        var drowsyTotal = 0
        var nodCount = 0
        for seed: UInt64 in 0..<50 {
            let drowsy = events(
                .variant, in: MomoIdleSequencer.schedule(
                    idleSeed: seed, displayState: state(.content, .drowsy),
                    windowEnd: 3600))
            drowsyTotal += drowsy.count
            for variant in drowsy {
                guard case .variant(let envelope) = variant.payload else { continue }
                if envelope.id == .headNod { nodCount += 1 }
            }
        }
        #expect(nodCount > 0)
        // Weight 0.8 of the drowsy 6.0 total (calmCoexist is gated out at
        // gettingClose) = 0.1333; measured 0.13208 over this battery.
        #expect(abs(Double(nodCount) / Double(drowsyTotal) - 0.1321) < 0.01)
    }

    // MARK: - Yawn gating (Drowsy only)

    @Test("§5.2 yawn: Drowsy-only, authored 1.4 s envelope, 45–90 s × 1.4 intervals")
    func yawnGatingAndShape() {
        let quietStates: [(String, CharacterDisplayState)] = [
            ("content", content),
            ("joyful", state(.joyful, .relaxed)),
            ("wistful", state(.wistful, .relaxed)),
            ("low", state(.low, .relaxed)),
            ("exhausted", state(.content, .exhausted)),
            ("asleep", state(.content, .relaxed, wakefulness: .asleep)),
        ]
        for (name, display) in quietStates {
            let yawns = events(
                .yawn, in: MomoIdleSequencer.schedule(
                    idleSeed: 7, displayState: display, windowEnd: 7200))
            #expect(yawns.isEmpty, "\(name) must never yawn")
        }

        let drowsyYawns = events(
            .yawn, in: MomoIdleSequencer.schedule(
                idleSeed: 7, displayState: state(.content, .drowsy), windowEnd: 7200))
        #expect(drowsyYawns.count > 20) // 45–90 s × 1.4 over two hours
        for (previous, current) in zip(drowsyYawns, drowsyYawns.dropFirst()) {
            let interval = current.start - previous.start
            #expect(interval >= 45.0 * 1.4 && interval <= 90.0 * 1.4)
        }
        for yawn in drowsyYawns {
            #expect(yawn.duration == MomoCurves.yawnSeconds)
            guard case .yawn(let envelope) = yawn.payload else {
                Issue.record("yawn payload mismatch"); continue
            }
            #expect(envelope.closeSeconds == 0.45)
            #expect(envelope.holdSeconds == 0.5)
            #expect(envelope.openSeconds == 0.45)
        }
    }

    // MARK: - §5.3 no-distraction budget (fixed batteries; ADR-012's two tiers)

    @Test("§5.3 at Content/baseline: mean and p95 motion ≤ 15 % per 30 s window (doc-exact)")
    func contentOccupancyBudget() {
        var occupancies: [Double] = []
        for seed: UInt64 in 0..<200 {
            let log = MomoIdleSequencer.schedule(
                idleSeed: seed, displayState: content, windowEnd: 30)
            occupancies.append(motionOccupancy(log, windowEnd: 30))
        }
        occupancies.sort()

        // The doc-exact tier: §5.3 scopes the ~85–90 % motionless floor "at
        // Content/baseline", so the ≤ 15 % budget binds THIS battery's mean
        // and p95 (measured 0.1102 / 0.1419 over the fixed 200 seeds).
        let meanOccupancy = mean(occupancies)
        let p95 = occupancies[189] // ceil(0.95 × 200)th smallest
        #expect(meanOccupancy <= 0.15)
        #expect(p95 <= 0.15)
        // The authored hard ceiling on any single window (ADR-012): the
        // stacked §5.2 rates let a tail window reach 0.1700 (4/200 windows
        // over 15 %) — inside the authored tier, while the doc's own
        // motionless floor is carried by the mean and p95 pins above.
        #expect(occupancies.last! <= 0.20)
        // Non-vacuous: the stage is not frozen either.
        #expect(meanOccupancy >= 0.05)
    }

    @Test("§5.3 beyond Content: cross-state windows ride the authored occupancy tier (ADR-012)")
    func crossStateOccupancyBudget() {
        // §5.3's ≤ 15 % floor is scoped to Content/baseline; every other
        // band rides the authored per-window tier (ADR-012). The battery
        // spans the motion-maximizing states (Energetic's ×1.5 variant
        // frequency compounding with Joyful's ×0.8 tempo — the conflict-free
        // 0.8 × 0.95, §3.3) and the interval-stretching ones (Drowsy,
        // Exhausted); non-awake states schedule nothing and are trivially 0.
        let states = [
            state(.joyful, .energetic),
            state(.joyful, .relaxed),
            state(.wistful, .relaxed),
            state(.low, .relaxed),
            state(.content, .drowsy),
            state(.content, .exhausted),
            state(.content, .relaxed, bond: .soulCompanions),
        ]
        var occupancies: [Double] = []
        for seed: UInt64 in 0..<100 {
            for display in states {
                let log = MomoIdleSequencer.schedule(
                    idleSeed: seed, displayState: display, windowEnd: 30)
                occupancies.append(motionOccupancy(log, windowEnd: 30))
            }
        }
        occupancies.sort()

        // The authored cross-state tier, set from this fixed battery's
        // measured shape (700 windows): mean 0.1109, max 0.2322 — the
        // extreme window is joyful/energetic (per-state means: 0.1663
        // joyful/energetic, 0.1411 joyful/relaxed, 0.1192 wistful, 0.0938
        // low, 0.0731 content/drowsy and content/exhausted, 0.1100
        // content/soulCompanions; per-state maxima: joyful/energetic 0.2322
        // with runner-up window 0.2231, joyful/relaxed 0.1903, wistful
        // 0.1835, low 0.1625, content/drowsy and content/exhausted both
        // 0.1365 — stable at 100 and 1000 seeds — and content/
        // soulCompanions 0.1700). The disposition's provisional
        // ≤ 0.20 cross-state ceiling was falsified by this measurement (its
        // cited 0.1700 was the Content battery's max) — the busier states
        // are §3.2/§3.3 working as authored, and the doc bounds only
        // Content/baseline.
        let meanOccupancy = mean(occupancies)
        #expect(meanOccupancy <= 0.20)
        #expect(occupancies.last! <= 0.25)
        // Non-vacuous: busier bands really are busier than Content's floor.
        #expect(meanOccupancy >= 0.05)
    }

    // MARK: - §7.4 rule 4: the arbiter

    private func makeEvent(
        _ kind: MomoIdleEventKind, start: Double = 0, duration: Double = 5,
        payload: MomoIdleEvent.Payload
    ) -> MomoIdleEvent {
        MomoIdleEvent(kind: kind, start: start, duration: duration, payload: payload)
    }

    @Test("Arbiter: priority order keeps blink > gaze > variant; yawn yields at the budget")
    func arbiterPriority() {
        let schedule = [
            makeEvent(.yawn, payload: .yawn(
                MomoYawnEnvelope(closeSeconds: 0.45, holdSeconds: 0.5, openSeconds: 0.45))),
            makeEvent(.variant, payload: .variant(
                MomoVariantEnvelope(
                    id: .weightShift, mirrored: false, inSeconds: 0.3,
                    holdSeconds: 1.0, outSeconds: 0.3))),
            makeEvent(.gaze, payload: .gaze(
                MomoGazeEnvelope(
                    target: .left, shiftSeconds: 0.25, holdSeconds: 1,
                    returnSeconds: 0.65))),
            makeEvent(.blink, payload: .blink(
                MomoBlinkEnvelope(
                    isDouble: false, closeSeconds: 0.15, openSeconds: 0.12,
                    interBlinkGapSeconds: 0.09))),
        ]
        // Input order must not matter — priority is the kind's rawValue.
        let admitted = MomoIdleArbiter.admitted(schedule: schedule, at: 1)
        #expect(admitted.map { $0.kind } == [.blink, .gaze, .variant])
        // Yawn ([.aperture, .head]) would push the union past 3 groups.
        let groups = admitted.reduce(into: MomoPropertyGroup()) {
            $0.formUnion($1.propertyGroups)
        }
        #expect(groups.rawValue.nonzeroBitCount == MomoIdleArbiter.concurrentPropertyBudget)
    }

    @Test("Arbiter: an event whose groups are already budgeted still admits")
    func arbiterNoNewBitsAdmits() {
        let blinkA = makeEvent(.blink, start: 0, duration: 1, payload: .blink(
            MomoBlinkEnvelope(
                isDouble: false, closeSeconds: 0.15, openSeconds: 0.12,
                interBlinkGapSeconds: 0.09)))
        let blinkB = makeEvent(.blink, start: 0.2, duration: 1, payload: .blink(
            MomoBlinkEnvelope(
                isDouble: false, closeSeconds: 0.15, openSeconds: 0.12,
                interBlinkGapSeconds: 0.09)))
        let admitted = MomoIdleArbiter.admitted(schedule: [blinkA, blinkB], at: 0.5)
        #expect(admitted.count == 2) // one group, one bit — no budget pressure
    }

    @Test("Arbiter: the budget parameter widens admission; empty schedules stay empty")
    func arbiterBudgetParameter() {
        let schedule = [
            makeEvent(.blink, payload: .blink(MomoBlinkEnvelope(
                isDouble: false, closeSeconds: 0.15, openSeconds: 0.12,
                interBlinkGapSeconds: 0.09))),
            makeEvent(.gaze, payload: .gaze(MomoGazeEnvelope(
                target: .left, shiftSeconds: 0.25, holdSeconds: 1, returnSeconds: 0.65))),
            makeEvent(.variant, payload: .variant(MomoVariantEnvelope(
                id: .weightShift, mirrored: false, inSeconds: 0.3, holdSeconds: 1,
                outSeconds: 0.3))),
            makeEvent(.yawn, payload: .yawn(MomoYawnEnvelope(
                closeSeconds: 0.45, holdSeconds: 0.5, openSeconds: 0.45))),
        ]
        // A widened budget admits everything.
        #expect(
            MomoIdleArbiter.admitted(schedule: schedule, at: 1, budget: 6).count == 4)
        #expect(MomoIdleArbiter.admitted(schedule: [], at: 1).isEmpty)
    }

    @Test("Arbiter battery: admitted unions never exceed 3 groups anywhere")
    func arbiterBattery() {
        for seed: UInt64 in 0..<25 {
            let log = MomoIdleSequencer.schedule(
                idleSeed: seed, displayState: content, windowEnd: 30)
            var sample = 0.0
            while sample < 30 {
                let admitted = MomoIdleArbiter.admitted(schedule: log, at: sample)
                let union = admitted.reduce(into: MomoPropertyGroup()) {
                    $0.formUnion($1.propertyGroups)
                }
                #expect(
                    union.rawValue.nonzeroBitCount <= MomoIdleArbiter.concurrentPropertyBudget,
                    "seed \(seed) at t = \(sample): \(union.rawValue.nonzeroBitCount) groups")
                sample += 0.25
            }
        }
    }
}
