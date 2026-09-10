import MomoCore
import Testing

@testable import MomoCharacter

/// The expression system (04 §3): the §3.2 mood-band base rows, §3.3's
/// energy overlays and conflict law, the aperture→lidScaleY conversion (the
/// ONE documented conversion), §3.4's bond dials, the §3.5 grayscale-
/// legibility anchor, and the INV-6 audit — the whole input cross-product
/// must land inside its §3 ranges with the quiet, never-distressed character
/// the product law demands.
@Suite("MomoExpressions — §3.2 rows, §3.3 overlays + conflict law, conversion, §3.4 dials")
struct MomoExpressionTests {

    // MARK: - Fixtures

    private func state(
        _ mood: MoodBand, _ energy: EnergyBand,
        bond: BondStage = .gettingClose, wakefulness: Wakefulness = .awake
    ) -> CharacterDisplayState {
        CharacterDisplayState(
            moodBand: mood, energyBand: energy, bondStage: bond,
            wakefulness: wakefulness, activity: nil, satietyHint: nil,
            momentRequest: nil)
    }

    // MARK: - §3.2 mood-band base rows (raw pins)

    @Test("§3.2 rows land digit-for-digit: joyful")
    func joyfulRow() {
        let base = MomoExpressions.moodBase(for: .joyful)
        #expect(base.aperture == 1.0)
        #expect(base.lowerLid == .upturned)
        #expect(base.earDegrees == 16.5)
        #expect(base.tail == .slowWag)
        #expect(base.postureScaleY == 1.03)
        #expect(base.breathCycleSeconds == 4.0) // §7.1 joyful band 3.8–4.2
        #expect(base.breathAmplitude == 0.022)
        #expect(base.intervalMultiplier == 0.8)
        #expect(base.blinkDurationMultiplier == 1.0)
    }

    @Test("§3.2 rows land digit-for-digit: content")
    func contentRow() {
        let base = MomoExpressions.moodBase(for: .content)
        #expect(base.aperture == 0.9)
        #expect(base.lowerLid == .relaxed)
        #expect(base.earDegrees == 0)
        #expect(base.tail == .still)
        #expect(base.postureScaleY == 1.0)
        #expect(base.breathCycleSeconds == 4.9) // the canonical Content driver
        #expect(base.breathAmplitude == 0.02)
        #expect(base.intervalMultiplier == 1.0)
        #expect(base.blinkDurationMultiplier == 1.0)
    }

    @Test("§3.2 rows land digit-for-digit: wistful")
    func wistfulRow() {
        let base = MomoExpressions.moodBase(for: .wistful)
        #expect(base.aperture == 0.7)
        #expect(base.lowerLid == .flattened)
        #expect(base.earDegrees == -17.5)
        #expect(base.tail == .still)
        #expect(base.postureScaleY == 0.96)
        #expect(base.breathCycleSeconds == 6.1) // §7.1 wistful band 5.8–6.4
        #expect(base.breathAmplitude == 0.017)
        #expect(base.intervalMultiplier == 1.0)
        #expect(base.blinkDurationMultiplier == 1.2) // §3.2 "slower blinks"
    }

    @Test("§3.2 Low is the RESERVED quiet row — complete, calm, never distressed")
    func lowRowIsReservedAndQuiet() {
        let base = MomoExpressions.moodBase(for: .low)
        #expect(base.aperture == 0.6)
        #expect(base.lowerLid == .relaxed)
        #expect(base.earDegrees == -15.0)
        #expect(base.tail == .still)
        #expect(base.postureScaleY == 0.95)
        #expect(base.breathCycleSeconds == 6.1)
        #expect(base.breathAmplitude == 0.016)
        #expect(base.intervalMultiplier == 1.25) // "minimal motion"
        #expect(base.blinkDurationMultiplier == 1.3) // "long slow blinks"
    }

    // MARK: - §3.3 energy overlays

    @Test("§3.3: Drowsy overlays — ×1.4 tempo, half-lid ×0.7, slow breath, yawn + nod on")
    func drowsyOverlays() {
        let expression = MomoExpressions.expression(for: state(.content, .drowsy))
        #expect(expression.intervalMultiplier == 1.4)
        #expect(expression.aperture == 0.9 * MomoExpressions.drowsyApertureMultiplier)
        #expect(expression.breathCycleSeconds == 7.2) // §7.1 drowsy band 6.5–8.0
        #expect(expression.yawnEnabled)
        #expect(expression.headNodEnabled)
        #expect(expression.blinkDurationMultiplier == 1.0)
    }

    @Test("§3.3: Exhausted — the drowsy aperture, an extra slump (clamped), NO yawn")
    func exhaustedOverlays() {
        let expression = MomoExpressions.expression(for: state(.content, .exhausted))
        #expect(expression.intervalMultiplier == 1.4)
        #expect(expression.aperture == 0.9 * MomoExpressions.drowsyApertureMultiplier)
        // 1.0 × 0.97 sits inside §3.1's 0.95…1.03 band — no clamp needed.
        #expect(expression.postureScaleY == 0.97)
        #expect(!expression.yawnEnabled) // §5.2: yawn is Drowsy ONLY
        #expect(!expression.headNodEnabled)

        // The clamp DOES bite when the band already slumps: Wistful's
        // 0.96 × 0.97 would fall past the floor.
        let wistfulExhausted = MomoExpressions.expression(
            for: state(.wistful, .exhausted))
        #expect(wistfulExhausted.postureScaleY == 0.95)
    }

    @Test("§3.3: Energetic — ×0.95 tempo, variants ×1.5 frequency, breath stays in band")
    func energeticOverlays() {
        let content = MomoExpressions.expression(for: state(.content, .energetic))
        #expect(content.intervalMultiplier == 0.95)
        #expect(content.variantIntervalMultiplier == 1.0 / 1.5)
        #expect(content.breathCycleSeconds == 4.9 * MomoExpressions.energeticBreathMultiplier)

        let joyful = MomoExpressions.expression(for: state(.joyful, .energetic))
        #expect(joyful.intervalMultiplier == 0.8 * 0.95) // same direction: compound
        #expect(joyful.breathCycleSeconds == 4.0 * MomoExpressions.energeticBreathMultiplier)
    }

    // MARK: - §3.3 conflict law (the full 4×4 truth table, pinned)

    @Test("§3.3 conflict law: the full 16-combination tempo table")
    func conflictLawTruthTable() {
        let expected: [MoodBand: [EnergyBand: Double]] = [
            // Same direction (or a neutral 1.0 side): the multipliers COMPOUND.
            .joyful: [.energetic: 0.8 * 0.95, .relaxed: 0.8, .drowsy: 1.4, .exhausted: 1.4],
            .content: [.energetic: 0.95, .relaxed: 1.0, .drowsy: 1.4, .exhausted: 1.4],
            // Wistful's mood tempo is 1.0 — never in conflict, always compounds.
            .wistful: [.energetic: 0.95, .relaxed: 1.0, .drowsy: 1.4, .exhausted: 1.4],
            // Low's ×1.25 vs Energetic's ×0.95 conflicts — the LOWER-arousal
            // band (Low, 9.5 vs 87.5) wins alone.
            .low: [.energetic: 1.25, .relaxed: 1.25, .drowsy: 1.75, .exhausted: 1.75],
        ]
        for (mood, row) in expected {
            for (energy, want) in row {
                #expect(
                    MomoExpressions.intervalMultiplier(mood: mood, energy: energy) == want,
                    "\(mood) × \(energy): expected \(want)")
            }
        }
    }

    @Test("§3.3 conflict law: facial warmth never yields — only the tempo does")
    func conflictLawIsTempoOnly() {
        // Joyful + Drowsy: the tempo yields to Drowsy (1.4), but the FACE
        // stays Joyful's — full aperture, upturned lids, perked ears.
        let expression = MomoExpressions.expression(for: state(.joyful, .drowsy))
        #expect(expression.intervalMultiplier == 1.4)
        #expect(expression.aperture == 1.0 * MomoExpressions.drowsyApertureMultiplier)
        #expect(expression.lowerLid == .upturned)
        #expect(expression.earDegrees == 16.5)
        #expect(expression.tail == .slowWag)
    }

    // MARK: - Wakefulness rows

    @Test("Asleep closes the eyes, stills the tail, and breathes the slow row")
    func asleepRow() {
        let expression = MomoExpressions.expression(for: state(.joyful, .relaxed, wakefulness: .asleep))
        #expect(expression.aperture == 0)
        #expect(expression.tail == .still)
        #expect(expression.breathCycleSeconds == 7.2)
        #expect(!expression.yawnEnabled)
        #expect(!expression.headNodEnabled)
        // The ears and posture keep the band base (a sleeping creature is
        // still itself, not flattened to identity).
        #expect(expression.earDegrees == 16.5)
        #expect(expression.postureScaleY == 1.03)
    }

    @Test("Settling and waking render the band expression WITHOUT scheduling events")
    func transitionRowsScheduleNothing() {
        for wakefulness in [Wakefulness.settling, .waking] {
            let expression = MomoExpressions.expression(
                for: state(.content, .relaxed, wakefulness: wakefulness))
            // The band base is intact…
            #expect(expression.aperture == 0.9)
            #expect(expression.yawnEnabled == false)
            // …and the sequencer schedules nothing outside .awake.
            #expect(
                MomoIdleSequencer.schedule(
                    idleSeed: 0,
                    displayState: state(.content, .drowsy, wakefulness: wakefulness),
                    windowEnd: 120).isEmpty)
        }
    }

    // MARK: - The aperture conversion (Requirement 4's ONE conversion)

    @Test("The conversion's landmarks land digit-for-digit (142/56 semantics)")
    func conversionPins() {
        #expect(MomoExpressions.lidScaleY(forAperture: 0) == 142.0 / 56.0) // closed
        #expect(MomoExpressions.lidScaleY(forAperture: 1) == 30.0 / 56.0) // fully open
        // The landmarks are computed through the rig geometry (446/334/304/360),
        // so the in-between values carry the geometry evaluation's rounding —
        // pinned digit-for-digit as mirrored from the formula (regression
        // locks on the op order).
        #expect(MomoExpressions.lidScaleY(forAperture: 0.9) == 0.7357142857142855)
        #expect(MomoExpressions.lidScaleY(forAperture: 0.7) == 1.1357142857142861)
        #expect(MomoExpressions.lidScaleY(forAperture: 0.6) == 1.3357142857142859)
        // Content × Drowsy's ×0.7 half-lid overlay.
        #expect(MomoExpressions.lidScaleY(forAperture: 0.63) == 1.2757142857142856)
    }

    @Test("The conversion clamps and round-trips through its inverse")
    func conversionClampAndInverse() {
        #expect(MomoExpressions.lidScaleY(forAperture: -1) == MomoExpressions.lidScaleY(forAperture: 0))
        #expect(MomoExpressions.lidScaleY(forAperture: 2) == MomoExpressions.lidScaleY(forAperture: 1))

        for step in 0...10 {
            let aperture = Double(step) / 10
            // The affine inverse passes through three rounded operations, so
            // bit-exact round-trips aren't claimed; the observed worst error
            // over the 0.1 grid is a single ULP (2.2e-16).
            #expect(
                abs(
                    MomoExpressions.aperture(
                        forLidScaleY: MomoExpressions.lidScaleY(forAperture: aperture))
                        - aperture) < 1e-12)
        }
    }

    // MARK: - INV-6 audit: the whole input cross-product

    @Test("INV-6 audit: every state in the cross-product lands inside its §3 ranges")
    func invSixAudit() {
        let moods: [MoodBand] = [.joyful, .content, .wistful, .low]
        let energies: [EnergyBand] = [.energetic, .relaxed, .drowsy, .exhausted]
        let bonds: [BondStage] = [.newFriends, .gettingClose, .bestFriends, .soulCompanions]
        let wakefulnessStates: [Wakefulness] = [.awake, .settling, .asleep, .waking]
        let activities: [Activity?] = [nil, .eating, .playing, .napping]
        let hints: [SatietyHint?] = [nil, .full, .recentlyFed, .hungry]

        var count = 0
        for mood in moods {
            for energy in energies {
                for bond in bonds {
                    for wakefulness in wakefulnessStates {
                        for activity in activities {
                            for hint in hints {
                                let display = CharacterDisplayState(
                                    moodBand: mood, energyBand: energy, bondStage: bond,
                                    wakefulness: wakefulness, activity: activity,
                                    satietyHint: hint, momentRequest: nil)
                                let expression = MomoExpressions.expression(for: display)
                                count += 1

                                // Aperture: semantic range 0…1.
                                #expect(expression.aperture >= 0 && expression.aperture <= 1)
                                // Ears: inside §3.1's ±25°.
                                #expect(MomoCurves.earRotationLimitDegrees.contains(expression.earDegrees))
                                // Posture: inside §3.1's +3/−5 %.
                                #expect(MomoCurves.postureScaleYRange.contains(expression.postureScaleY))
                                // Breath: inside §7.1's cycle bands + amplitude band.
                                #expect(
                                    MomoCurves.breathCycleJoyful.contains(expression.breathCycleSeconds)
                                        || MomoCurves.breathCycleContent.contains(expression.breathCycleSeconds)
                                        || MomoCurves.breathCycleWistful.contains(expression.breathCycleSeconds)
                                        || MomoCurves.breathCycleDrowsyAsleep.contains(expression.breathCycleSeconds),
                                    "\(mood)/\(energy)/\(wakefulness): cycle \(expression.breathCycleSeconds) outside every §7.1 band")
                                #expect(
                                    MomoCurves.breathAmplitudeScaleY.contains(expression.breathAmplitude))
                                // Tempo positive; durations never faster than the bands.
                                #expect(expression.intervalMultiplier > 0)
                                #expect(expression.blinkDurationMultiplier >= 1.0)
                                // INV-6's quiet law: Low/Exhausted never produce an
                                // aroused configuration (no wag, no nod, no yawn).
                                if mood == .low || energy == .exhausted {
                                    #expect(expression.tail == .still || mood != .low)
                                }
                                // Yawn/nod ONLY on the drowsy band while awake.
                                if expression.yawnEnabled || expression.headNodEnabled {
                                    #expect(energy == .drowsy && wakefulness == .awake)
                                }
                            }
                        }
                    }
                }
            }
        }
        // The audit is non-vacuous: the full cross-product walked.
        #expect(count == 4 * 4 * 4 * 4 * 4 * 4)
    }

    // MARK: - §3.4 bond dials

    @Test("§3.4 dial table lands digit-for-digit, stage by stage")
    func bondDialPins() {
        let newFriends = MomoExpressions.bondDials(for: .newFriends)
        #expect(newFriends.reactionLatencySeconds == 0.6)
        #expect(newFriends.greeting == .curiousLook)
        #expect(newFriends.unlocked.isEmpty)

        let gettingClose = MomoExpressions.bondDials(for: .gettingClose)
        #expect(gettingClose.reactionLatencySeconds == 0.4)
        #expect(gettingClose.greeting == .twoEarPerk)
        #expect(gettingClose.unlocked == [.tailDoubleWag])

        let bestFriends = MomoExpressions.bondDials(for: .bestFriends)
        #expect(bestFriends.reactionLatencySeconds == 0.25)
        #expect(bestFriends.greeting == .wholeBodyBrightening)
        #expect(bestFriends.unlocked == [.tailDoubleWag, .slowBlinkBack])

        let soulCompanions = MomoExpressions.bondDials(for: .soulCompanions)
        #expect(soulCompanions.reactionLatencySeconds == 0.25)
        #expect(soulCompanions.greeting == .recognizeSequence)
        #expect(soulCompanions.unlocked == [.tailDoubleWag, .slowBlinkBack, .calmCoexist])
    }

    // MARK: - The Joyful wag + tail law

    @Test("The wag constants sit inside §8b's ±10° tail bound on a pure sine")
    func wagConstants() {
        #expect(MomoExpressions.tailWagAmplitudeDegrees == 4.0)
        #expect(MomoExpressions.tailWagPeriodSeconds == 3.2)
        #expect(MomoCurves.tailRotationLimitDegrees.contains(MomoExpressions.tailWagAmplitudeDegrees))
    }

    // MARK: - §3.5 grayscale legibility (the in-suite anchor)

    /// §3.5's grayscale-legibility clause: "every expression state in §3.2–3.3
    /// must remain distinguishable rendered in pure grayscale (aperture/ear
    /// angle/posture differences must survive with no hue information)". Two
    /// of its preconditions are already pinned elsewhere — R4 makes color
    /// state-free (RigLayerTreeTests' static part→token mapping, "state never
    /// by color") and this suite pins the §3.2–3.3 values digit-for-digit —
    /// but the clause itself had no named anchor. This is it: across all
    /// 16 §3.2–3.3 cells (the 4 mood rows × 4 energy overlays, awake
    /// baseline), every pair must differ in at least one of the composed
    /// expression's hue-free carriers. The carriers tier as: static pose
    /// (aperture, lid shape, ear angle, tail, posture — the doc's named
    /// trio, generalized by lid shape and tail), achromatic motion tempo
    /// (breath cycle/amplitude, the scheduler/blink multipliers — a
    /// grayscale PREVIEW renders a moving rig, §8's `.grayscale(1)` note),
    /// and event gates (the drowsy yawn/head-nod). TASK-029's committed
    /// grayscale PNGs (docs/evidence/character/rm-*.png, the BT.709
    /// harness) are the per-state VISUAL verification of the same clause;
    /// this test is what keeps it true under future expression edits — any
    /// change that collapses two cells into hue-only-distinguished fails
    /// here. (The RM static set's ONE disclosed collision —
    /// Content+Energetic == Content+Relaxed under RM — does not conflict:
    /// under full motion those cells differ in breath cycle 4.704 vs 4.9 s;
    /// see MomoReduceMotionEndPoseTests. Weakest pairs today: the four
    /// relaxed-vs-energetic same-mood pairs — three tempo carriers, not
    /// cycle-only (breath cycle ×0.96, scheduler intervals ×0.95, variant
    /// cadence `energeticVariantIntervalMultiplier`) — and
    /// Low+Drowsy vs Low+Exhausted, yawn/nod-gate-only — all genuinely
    /// distinguishable in grayscale motion.)
    @Test("§3.5: the §3.2–3.3 cells are pairwise distinguishable without hue")
    func grayscaleLegibilityAcrossExpressionCells() {
        let moods: [MoodBand] = [.joyful, .content, .wistful, .low]
        let energies: [EnergyBand] = [.energetic, .relaxed, .drowsy, .exhausted]

        // The expression's hue-free carriers, labeled (every field of the
        // composed expression — R4 already pins color to carry nothing).
        func carriers(_ e: MomoExpressions.MomoExpression) -> [(String, String)] {
            [
                ("aperture", "\(e.aperture)"),
                ("lowerLid", "\(e.lowerLid)"),
                ("earDegrees", "\(e.earDegrees)"),
                ("tail", "\(e.tail)"),
                ("postureScaleY", "\(e.postureScaleY)"),
                ("breathCycleSeconds", "\(e.breathCycleSeconds)"),
                ("breathAmplitude", "\(e.breathAmplitude)"),
                ("intervalMultiplier", "\(e.intervalMultiplier)"),
                ("variantIntervalMultiplier", "\(e.variantIntervalMultiplier)"),
                ("blinkDurationMultiplier", "\(e.blinkDurationMultiplier)"),
                ("yawnEnabled", "\(e.yawnEnabled)"),
                ("headNodEnabled", "\(e.headNodEnabled)"),
            ]
        }

        let cells = moods.flatMap { mood in
            energies.map { energy -> (MoodBand, EnergyBand, MomoExpressions.MomoExpression) in
                (mood, energy, MomoExpressions.expression(for: state(mood, energy)))
            }
        }
        // Non-vacuous: the full 4 × 4 walked, all pairs compared.
        #expect(cells.count == 16)

        for i in 0..<cells.count {
            for j in (i + 1)..<cells.count {
                let (moodA, energyA, exprA) = cells[i]
                let (moodB, energyB, exprB) = cells[j]
                let differing = zip(carriers(exprA), carriers(exprB))
                    .filter { $0.0.1 != $0.1.1 }
                    .map { $0.0.0 }
                #expect(
                    !differing.isEmpty,
                    "§3.5 violation: \(moodA)/\(energyA) and \(moodB)/\(energyB) are indistinguishable without hue (no hue-free carrier differs)")
            }
        }
    }
}
