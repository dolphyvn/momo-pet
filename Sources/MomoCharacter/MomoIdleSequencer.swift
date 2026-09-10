import MomoCore

/// The idle sequencer (04 §5.1–5.2): turns `(idleSeed, displayState,
/// timeline window)` into the idle event log. PURE and DETERMINISTIC — the
/// same triple always yields the same schedule, byte-for-byte (the tests pin
/// whole logs and the prefix property). All randomness flows from the
/// engine-injected 64-bit seed through `MomoIdleRandom` over the repo-owned
/// SplitMix64 `SeededGenerator`; the sequencer never touches system
/// randomness (§9.4).
///
/// Draw discipline: the master seed derives four INDEPENDENT substream
/// seeds (master draws 1–4 = blink / gaze / variant / yawn); each scheduler
/// consumes only its own substream, and each scheduler's draw ORDER is
/// fixed and documented at its loop below — reordering draws changes the
/// schedule and fails the vector pins, so the order is part of the
/// contract.
public enum MomoIdleSequencer {

    // MARK: - §5.2 authored scheduling constants (tests pin them)

    /// Blink interval ~ N(6 s, σ = 2 s), clamped to this band.
    public static let blinkIntervalMeanSeconds: Double = 6.0
    public static let blinkIntervalSigmaSeconds: Double = 2.0
    public static let blinkIntervalClamp: ClosedRange<Double> = 2.5...12.0

    /// 12 % of blinks are doubles.
    public static let doubleBlinkProbability: Double = 0.12

    /// The authored pause between the two closings of a double blink
    /// (constant, not a draw — keeps the blink scheduler's draw order at
    /// four draws per blink).
    public static let doubleBlinkGapSeconds: Double = 0.09

    /// Look-around every 9–21 s (§5.2). Authored draw: the band's calmer
    /// end — §5.3's no-distraction budget drives the subrange (every draw
    /// stays inside the doc band).
    public static let lookAroundIntervalRange: ClosedRange<Double> = 10.0...21.0

    /// The gaze hold at the target (§5.2: 1.5–4 s of stillness).
    public static let gazeHoldRange: ClosedRange<Double> = 1.5...4.0

    /// Idle variants every 14–30 s (§5.2). Authored draw: the band's
    /// sparser end — §5.3's no-distraction budget drives the subrange.
    public static let variantIntervalRange: ClosedRange<Double> = 16.0...30.0

    /// The yawn interval (§5.2: 45–90 s, Drowsy only).
    public static let yawnIntervalRange: ClosedRange<Double> = 45.0...90.0

    /// The yawn's authored 0.45 / 0.5 / 0.45 split of §7.1's 1.4 s.
    public static let yawnCloseSeconds: Double = 0.45
    public static let yawnHoldSeconds: Double = 0.5
    public static let yawnOpenSeconds: Double = 0.45

    /// Joyful's look-around prefers meeting the user's eyes: `atUser`
    /// draws ×1.4 before renormalizing (§5.2).
    public static let joyfulAtUserWeightMultiplier: Double = 1.4

    /// The gaze shift draw: §7.1's 220–320 ms band, authored at its unhurried
    /// low half (§5.3's budget drives the subrange).
    public static let gazeShiftRange: ClosedRange<Double> = 0.22...0.28

    /// The gaze return draw: §7.1's 600–900 ms band, authored at its prompt
    /// low end — a glance settles back quickly, keeping the stage still
    /// (§5.3's budget drives the subrange).
    public static let gazeReturnRange: ClosedRange<Double> = 0.60...0.70

    /// The crossfade-family entry/exit draw: §7.1's 300–400 ms band,
    /// authored at its crisp low end (shorter transitions leave more
    /// stillness; §5.3's budget drives the subrange).
    public static let crossfadeRange: ClosedRange<Double> = 0.30...0.33

    /// The variant mirror coin: a sided variant (weight shift, ear twitch,
    /// tail flick, curious asymmetry) draws left/right 50/50.
    public static let mirroredProbability: Double = 0.5

    // MARK: - The schedule

    /// The idle event log for the half-open window [0, `windowEnd`]:
    /// every event with `start ≤ windowEnd`, sorted by (start, kind).
    /// Non-awake states schedule NOTHING — the sequencer emits events only
    /// while `.awake` (asleep is stillness, §5.2; settling/waking
    /// choreography is TASK-028's, so those states schedule nothing too).
    public static func schedule(
        idleSeed: UInt64,
        displayState: CharacterDisplayState,
        windowEnd: Double
    ) -> [MomoIdleEvent] {
        guard displayState.wakefulness == .awake, windowEnd >= 0 else { return [] }

        // Four independent substreams from the one seed (master draws 1–4).
        var master = SeededGenerator(seed: idleSeed)
        let blinkSeed = master.next()
        let gazeSeed = master.next()
        let variantSeed = master.next()
        let yawnSeed = master.next()

        var events: [MomoIdleEvent] = []
        events.append(
            contentsOf: blinkSchedule(
                seed: blinkSeed, displayState: displayState, windowEnd: windowEnd))
        events.append(
            contentsOf: gazeSchedule(
                seed: gazeSeed, displayState: displayState, windowEnd: windowEnd))
        events.append(
            contentsOf: variantSchedule(
                seed: variantSeed, displayState: displayState, windowEnd: windowEnd))
        events.append(
            contentsOf: yawnSchedule(
                seed: yawnSeed, displayState: displayState, windowEnd: windowEnd))

        return events.sorted {
            ($0.start, $0.kind.rawValue) < ($1.start, $1.kind.rawValue)
        }
    }

    // MARK: - Scheduler 1: blinking (§5.2)

    /// Blink scheduler. Draw order per blink, all from the blink substream:
    /// 1. interval ~ clamped N(6, 2) × interval tempo,
    /// 2. close ~ U(§7.1 close band) × duration multiplier,
    /// 3. open ~ U(§7.1 open band) × duration multiplier,
    /// 4. double coin ~ U < 12 %.
    /// The interval tempo is the expression system's conflict-law-resolved
    /// multiplier (Drowsy ×1.4 normative); Wistful's ×1.2 (and Low's ×1.3)
    /// duration multipliers stretch the drawn close/open, not the band.
    private static func blinkSchedule(
        seed: UInt64, displayState: CharacterDisplayState, windowEnd: Double
    ) -> [MomoIdleEvent] {
        let expression = MomoExpressions.expression(for: displayState)
        var random = MomoIdleRandom(seed: seed)
        var events: [MomoIdleEvent] = []
        var cursor = 0.0

        while true {
            let interval = min(
                max(
                    random.nextNormal(
                        mean: blinkIntervalMeanSeconds,
                        standardDeviation: blinkIntervalSigmaSeconds),
                    blinkIntervalClamp.lowerBound),
                blinkIntervalClamp.upperBound
            ) * expression.intervalMultiplier

            let close = random.nextUniform(
                in: MomoCurves.blinkCloseSeconds) * expression.blinkDurationMultiplier
            let open = random.nextUniform(
                in: MomoCurves.blinkOpenSeconds) * expression.blinkDurationMultiplier
            let isDouble = random.nextUniform() < doubleBlinkProbability

            let start = cursor + interval
            guard start <= windowEnd else { break }

            let envelope = MomoBlinkEnvelope(
                isDouble: isDouble, closeSeconds: close, openSeconds: open,
                interBlinkGapSeconds: doubleBlinkGapSeconds)
            let duration =
                isDouble
                ? 2 * (close + open) + doubleBlinkGapSeconds
                : close + open
            events.append(
                MomoIdleEvent(
                    kind: .blink, start: start, duration: duration,
                    payload: .blink(envelope)))
            cursor = start
        }
        return events
    }

    // MARK: - Scheduler 2: looking around (§5.2)

    /// Look-around scheduler. Draw order per look: 1. interval ~ U(9, 21)
    /// × interval tempo; 2. target (weighted five-point set, Joyful's
    /// `atUser` ×1.4 before renormalizing); 3. shift ~ U(§7.1 gaze band);
    /// 4. hold ~ U(1.5, 4); 5. return ~ U(§7.1 return band).
    private static func gazeSchedule(
        seed: UInt64, displayState: CharacterDisplayState, windowEnd: Double
    ) -> [MomoIdleEvent] {
        let expression = MomoExpressions.expression(for: displayState)
        var random = MomoIdleRandom(seed: seed)

        // The target weights for this state: the base set, with Joyful's
        // at-user boost. Canonical order = `MomoGazeTarget.baseWeights`.
        let weights: [(value: MomoGazeTarget, weight: Double)] =
            MomoGazeTarget.baseWeights.map { entry in
                let weight =
                    (entry.value == .atUser && displayState.moodBand == .joyful)
                    ? entry.weight * joyfulAtUserWeightMultiplier
                    : entry.weight
                return (entry.value, weight)
            }

        var events: [MomoIdleEvent] = []
        var cursor = 0.0

        while true {
            let interval = random.nextUniform(in: lookAroundIntervalRange)
                * expression.intervalMultiplier

            let target = random.nextWeighted(weights) ?? .atUser
            let shift = random.nextUniform(in: gazeShiftRange)
            let hold = random.nextUniform(in: gazeHoldRange)
            let back = random.nextUniform(in: gazeReturnRange)

            let start = cursor + interval
            guard start <= windowEnd else { break }

            let duration = shift + hold + back
            events.append(
                MomoIdleEvent(
                    kind: .gaze, start: start, duration: duration,
                    payload: .gaze(
                        MomoGazeEnvelope(
                            target: target, shiftSeconds: shift,
                            holdSeconds: hold, returnSeconds: back))))
            cursor = start
        }
        return events
    }

    // MARK: - Scheduler 3: idle variants (§5.2, catalog as data)

    /// Variant scheduler. Draw order per variant: 1. interval ~ U(14, 30)
    /// × interval tempo × the energy's variant tempo (Energetic ×1.5
    /// frequency = ÷1.5 interval); 2. variant id (weighted, gated
    /// selectable set); 3. mirror coin; 4. hold ~ U(row's hold range);
    /// 5. crossfade ~ U(§7.1 state-crossfade band) — spring-family
    /// variants skip draw 5 and fix entry/exit to the idle spring
    /// response.
    private static func variantSchedule(
        seed: UInt64, displayState: CharacterDisplayState, windowEnd: Double
    ) -> [MomoIdleEvent] {
        let expression = MomoExpressions.expression(for: displayState)
        var random = MomoIdleRandom(seed: seed)
        let selectable = MomoIdleVariantCatalog.selectableWeights(
            mood: displayState.moodBand,
            energy: displayState.energyBand,
            bondStage: displayState.bondStage)

        var events: [MomoIdleEvent] = []
        var cursor = 0.0

        while true {
            let interval = random.nextUniform(in: variantIntervalRange)
                * expression.intervalMultiplier
                * expression.variantIntervalMultiplier

            guard let id = random.nextWeighted(selectable) else { break }
            let mirrored = random.nextUniform() < mirroredProbability
            let hold: Double
            let fadeIn: Double
            let fadeOut: Double
            if let spec = MomoIdleVariantCatalog.spec(for: id) {
                hold = random.nextUniform(in: spec.holdRange)
                if spec.usesSpringEnvelope {
                    fadeIn = MomoCurves.idleSpringResponseSeconds
                    fadeOut = MomoCurves.idleSpringResponseSeconds
                } else {
                    fadeIn = random.nextUniform(in: crossfadeRange)
                    fadeOut = random.nextUniform(in: crossfadeRange)
                }
            } else {
                // Unknown (forward-compatible) id: skip rendering data but
                // keep the draw count pinned — mirror + generic hold/in/out.
                _ = random.nextUniform()
                hold = random.nextUniform(in: 0.5...2.0)
                fadeIn = random.nextUniform(in: crossfadeRange)
                fadeOut = random.nextUniform(in: crossfadeRange)
            }

            let start = cursor + interval
            guard start <= windowEnd else { break }

            let duration = fadeIn + hold + fadeOut
            events.append(
                MomoIdleEvent(
                    kind: .variant, start: start, duration: duration,
                    payload: .variant(
                        MomoVariantEnvelope(
                            id: id, mirrored: mirrored, inSeconds: fadeIn,
                            holdSeconds: hold, outSeconds: fadeOut))))
            cursor = start
        }
        return events
    }

    // MARK: - Scheduler 4: yawning (§5.2, Drowsy only)

    /// Yawn scheduler. Draw order per yawn: 1. interval ~ U(45, 90)
    /// × interval tempo. The envelope itself is fully authored
    /// (0.45 / 0.5 / 0.45 of §7.1's 1.4 s) — no further draws. The whole
    /// scheduler runs only when the expression system enables the yawn
    /// (strictly the Drowsy band).
    private static func yawnSchedule(
        seed: UInt64, displayState: CharacterDisplayState, windowEnd: Double
    ) -> [MomoIdleEvent] {
        let expression = MomoExpressions.expression(for: displayState)
        guard expression.yawnEnabled else { return [] }

        var random = MomoIdleRandom(seed: seed)
        var events: [MomoIdleEvent] = []
        var cursor = 0.0

        while true {
            let interval = random.nextUniform(in: yawnIntervalRange)
                * expression.intervalMultiplier

            let start = cursor + interval
            guard start <= windowEnd else { break }

            events.append(
                MomoIdleEvent(
                    kind: .yawn, start: start, duration: MomoCurves.yawnSeconds,
                    payload: .yawn(
                        MomoYawnEnvelope(
                            closeSeconds: yawnCloseSeconds,
                            holdSeconds: yawnHoldSeconds,
                            openSeconds: yawnOpenSeconds))))
            cursor = start
        }
        return events
    }
}
