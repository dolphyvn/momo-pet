import MomoCore

// MARK: - Tail behaviors (§3.1's tail row)

/// The tail behaviors the expression system selects. §3.1 names "still ·
/// slow metronome · quick small wag · wrapped tight"; this task renders the
/// two Phase 1 behaviors — the slow wag (Joyful) and stillness (everything
/// else, the no-distraction-preferred choice of §3.2's Content row "slow
/// metronome or still"). "Wrapped tight" / "curled close" are TAIL GEOMETRY
/// the rig does not have (R1: no new geometry) — routed as a geometry-owner
/// follow-up, rendered as stillness meanwhile.
public enum MomoTailBehavior: Equatable, Sendable {
    case still
    case slowWag
}

// MARK: - The mood-band base table (§3.2, one row per band)

/// The §3.2 mood-band expression base: what the band means on the rig
/// before energy/bond overlays. Authored values sit inside the doc ranges;
/// the tests pin them name-for-name.
public struct MomoMoodExpressionBase: Sendable, Equatable {

    /// Semantic aperture — 0 (closed) … 1 (fully open). Converted to the
    /// rig's lidScaleY by `MomoExpressions.lidScaleY(forAperture:)` (ONE
    /// documented conversion — see there for the §3.1 trap).
    public let aperture: Double
    public let lowerLid: RigLowerLidPose
    /// Both ears' base angle in degrees (§3.1: −25 droop … +25 perk).
    public let earDegrees: Double
    public let tail: MomoTailBehavior
    /// Body scaleY about the ground line (§3.1 posture: +3 % tall …
    /// −5 % slouch).
    public let postureScaleY: Double
    /// The band's breath cycle (§7.1 rows) and amplitude (§7.1: 1.5–2.5 %).
    public let breathCycleSeconds: Double
    public let breathAmplitude: Double
    /// The band's tempo: a MULTIPLIER ON SCHEDULER INTERVALS (§3.2 "idle
    /// events more frequent" ⇒ < 1 for Joyful; "minimal motion" ⇒ > 1 for
    /// Low). Subject to §3.3's conflict law — see
    /// `MomoExpressions.intervalMultiplier(mood:energy:)`.
    public let intervalMultiplier: Double
    /// Duration multiplier on blink close/open (§3.2: Wistful "slower
    /// blinks" ×1.2, §7.1; Low's "long slow blinks").
    public let blinkDurationMultiplier: Double
}

/// The expression system (04 §3): maps a `CharacterDisplayState` to concrete
/// rig channel values. POSTURE-LED (§3.2 — mood reads through aperture,
/// lids, ears, tail, posture, breath; the mouth keeps the authored neutral).
/// The system consumes ONLY the given display state (§9.3: the character
/// renders the state it is given; it never applies engine effects).
public enum MomoExpressions {

    // MARK: - The aperture conversion (the §3.1 trap, resolved once)

    /// The generated eye geometry this conversion is DERIVED FROM —
    /// measured on `MomoRig.eyeLeftBase` / `MomoRig.eyeLeftLid`
    /// (Sources/MomoCharacter/MomoRig+Eyes.swift); the tests re-derive these
    /// from the committed Paths so any geometry drift alarms:
    /// - eye box: y 334 (top) … 446 (bottom), 112 units tall;
    /// - lid: anchored at its apex y 304, its bottom edge at authored rest
    ///   y 360 (56 units below the anchor) — i.e. at rest the lid already
    ///   slices 26 of the eye's 112 units (the TASK-026-corrected semantics
    ///   of `lidScaleY`).
    public static let eyeTopY: Double = 334
    public static let eyeBottomY: Double = 446
    public static let lidAnchorY: Double = 304
    public static let lidRestBottomY: Double = 360

    /// The measured eye radius (the eye base's half-width): the §2.4 pupil
    /// clamp bound is 30 % of this.
    public static let eyeRadiusUnits: Double = 50

    /// THE aperture → lidScaleY conversion (Requirement 4's "ONE documented
    /// conversion"). §3.1's table speaks aperture "0 (closed) → 1.0 (open)",
    /// but the rig channel's true semantics (TASK-026-corrected) are:
    /// `lidScaleY = 1` is the AUTHORED REST — the lid already covers the
    /// top 26/112 of the eye; SMALLER lifts the lid bottom (more open,
    /// 0.5357… = fully open); LARGER lowers it (more closed).
    ///
    /// Semantic aperture `a` requires the lid bottom at
    /// `eyeBottomY − (eyeBottomY − eyeTopY)·a`, so
    ///
    ///     lidScaleY(a) = (142 − 112·a) / 56
    ///
    /// (446 − 304 = 142; the rest lid span is 56). Landmarks: a = 0
    /// (closed) → 142/56 = 2.5357…; a = 1 (fully open) → 30/56 = 0.5357…;
    /// Content's ~90 % → 0.7357…; Wistful's ~70 % → 1.1357…; Low's
    /// ~60 % → 1.3357…. Values outside 0…1 clamp.
    public static func lidScaleY(forAperture aperture: Double) -> Double {
        let a = min(max(aperture, 0), 1)
        let lidBottom = eyeBottomY - (eyeBottomY - eyeTopY) * a
        return (lidBottom - lidAnchorY) / (lidRestBottomY - lidAnchorY)
    }

    /// The conversion's inverse (`aperture(forLidScaleY:)`), for tests and
    /// diagnostics: which semantic aperture a lid value expresses.
    public static func aperture(forLidScaleY lidScaleY: Double) -> Double {
        let lidBottom = lidAnchorY + lidScaleY * (lidRestBottomY - lidAnchorY)
        return (eyeBottomY - lidBottom) / (eyeBottomY - eyeTopY)
    }

    // MARK: - §3.2 mood-band base rows (raw values; tests pin them)

    public static func moodBase(for band: MoodBand) -> MomoMoodExpressionBase {
        switch band {
        case .joyful:
            // 100 % aperture, upturned lower lids (warm arcs); perk
            // +8…+25° (authored mid +16.5); slow wag; +3 % tall; breath
            // ~4 s (band 3.8–4.2); idle events more frequent.
            MomoMoodExpressionBase(
                aperture: 1.0, lowerLid: .upturned, earDegrees: 16.5,
                tail: .slowWag, postureScaleY: 1.03,
                breathCycleSeconds: 4.0, breathAmplitude: 0.022,
                intervalMultiplier: 0.8, blinkDurationMultiplier: 1.0)
        case .content:
            // ~90 % aperture, relaxed lids; neutral ±5° (authored base 0);
            // "slow metronome or still" — STILL, the no-distraction
            // choice; neutral posture; breath = the canonical 4.9;
            // baseline scheduling.
            MomoMoodExpressionBase(
                aperture: 0.9, lowerLid: .relaxed, earDegrees: 0,
                tail: .still, postureScaleY: 1.0,
                breathCycleSeconds: 4.9, breathAmplitude: 0.02,
                intervalMultiplier: 1.0, blinkDurationMultiplier: 1.0)
        case .wistful:
            // ~70 % aperture, flattened upper lid (soft, heavy look);
            // droop −10…−25° (authored mid −17.5); still, curled close
            // (curl = geometry follow-up, rendered still); −4 % slouch;
            // breath ~6 s (band 5.8–6.4); slower blinks ×1.2.
            MomoMoodExpressionBase(
                aperture: 0.7, lowerLid: .flattened, earDegrees: -17.5,
                tail: .still, postureScaleY: 0.96,
                breathCycleSeconds: 6.1, breathAmplitude: 0.017,
                intervalMultiplier: 1.0, blinkDurationMultiplier: 1.2)
        case .low:
            // RESERVED (PRD floor 25 — no Phase 1 mechanic produces it):
            // quiet resting, never distress (INV-6). ~60 % aperture, long
            // slow blinks (×1.3, authored); ears settled down; tail
            // wrapped (geometry follow-up, rendered still); −5 % resting
            // slump; breath on the wistful row (authored 6.1); minimal
            // motion (×1.25 intervals). Defined so the presentation scale
            // is complete; shipping it requires a PRD revision.
            MomoMoodExpressionBase(
                aperture: 0.6, lowerLid: .relaxed, earDegrees: -15.0,
                tail: .still, postureScaleY: 0.95,
                breathCycleSeconds: 6.1, breathAmplitude: 0.016,
                intervalMultiplier: 1.25, blinkDurationMultiplier: 1.3)
        }
    }

    // MARK: - §3.3 energy overlays

    /// The energy tempo (interval multiplier) per band. Energetic is
    /// "slightly faster" (authored ×0.95); Drowsy's "all scheduler
    /// intervals ×1.4" is normative; Exhausted reads "minimal and slow"
    /// and inherits the Drowsy rule (authored interpretation). Subject to
    /// the conflict law — see `intervalMultiplier(mood:energy:)`.
    public static func energyIntervalMultiplier(for energy: EnergyBand) -> Double {
        switch energy {
        case .energetic: 0.95
        case .relaxed: 1.0
        case .drowsy, .exhausted: 1.4
        }
    }

    /// Energetic's "idle variation frequency ×1.5" (§3.3) — as an interval
    /// multiplier on the VARIANT scheduler only.
    public static let energeticVariantIntervalMultiplier: Double = 1.0 / 1.5

    /// Energetic's "slightly faster tempo" also nudges the breath (×0.96,
    /// authored) — bounded so every mood's cycle stays inside its §7.1
    /// band (the audit pins this).
    public static let energeticBreathMultiplier: Double = 0.96

    /// Drowsy's "half-lid baseline overlay (aperture ×0.7)" (§3.3).
    /// Exhausted's "eyes half-open" (§3.3) reads as the same overlay
    /// (authored: the exhausted eye is the drowsy eye, sleepier posture
    /// carries the difference).
    public static let drowsyApertureMultiplier: Double = 0.7

    /// Exhausted's near-sleep resting posture (§3.3): an extra ×0.97
    /// slump on top of the mood's posture (authored); the composition
    /// clamps into §3.1's +3 %/−5 % bounds.
    public static let exhaustedPostureMultiplier: Double = 0.97

    /// The Drowsy/exhausted breath overrides the mood row with the §7.1
    /// "Drowsy / asleep" band (6.5–8.0; authored 7.2) — the sleepy body
    /// breathes the slow row even while awake.
    public static let drowsyBreathCycleSeconds: Double = 7.2

    /// §3.3's Drowsy row gates the yawn (§5.2: "Drowsy only" — strictly
    /// the drowsy band; Exhausted's minimal movement excludes it).
    public static func yawnEnabled(energy: EnergyBand) -> Bool {
        energy == .drowsy
    }

    /// §3.3's Drowsy row gates the occasional head-nod micro-motion.
    public static func headNodEnabled(energy: EnergyBand) -> Bool {
        energy == .drowsy
    }

    // MARK: - §3.3's conflict law, executable

    /// Arousal levels for the conflict law (§3.3: "where mood and energy
    /// conflict, the LOWER-energy signal wins on tempo"): the bands'
    /// midpoint positions on the PRD's 0–100 scales (Content's attractor
    /// 60; Joyful 75–100 → 87.5; Wistful 20–44 → 32; Low/Exhausted
    /// 0–19 → 9.5).
    public static func arousalLevel(of band: MoodBand) -> Double {
        switch band {
        case .joyful: 87.5
        case .content: 60
        case .wistful: 32
        case .low: 9.5
        }
    }

    public static func arousalLevel(of band: EnergyBand) -> Double {
        switch band {
        case .energetic: 87.5
        case .relaxed: 60
        case .drowsy: 32
        case .exhausted: 9.5
        }
    }

    /// The composed scheduler-interval tempo under §3.3's conflict law.
    /// Mood and energy tempo multipliers compound — UNLESS they pull in
    /// opposite directions (one < 1, one > 1); in conflict, the signal
    /// from the LOWER-arousal band wins alone ("happy but too tired to
    /// move much": Joyful's ×0.8 never outruns Drowsy's ×1.4). Facial
    /// warmth is NOT subject to this law — the HIGHER mood always owns
    /// aperture/lids/ears (it is only the tempo that yields).
    public static func intervalMultiplier(mood: MoodBand, energy: EnergyBand) -> Double {
        let moodTempo = moodBase(for: mood).intervalMultiplier
        let energyTempo = energyIntervalMultiplier(for: energy)
        let inConflict = moodTempo != 1 && energyTempo != 1
            && (moodTempo < 1) != (energyTempo < 1)
        if inConflict {
            return arousalLevel(of: mood) <= arousalLevel(of: energy)
                ? moodTempo : energyTempo
        }
        return moodTempo * energyTempo
    }

    // MARK: - §3.4 bond dials (data consumed downstream)

    /// §3.4's greeting qualities, stage by stage ("greeting POSES are
    /// TASK-028" — this task only carries the descriptor).
    public enum MomoGreetingQuality: String, Sendable, CaseIterable {
        case curiousLook
        case twoEarPerk
        case wholeBodyBrightening
        case recognizeSequence
    }

    /// §3.4's unlocked-variant flags (consumed by TASK-028's reactions;
    /// `calmCoexist` is ALSO consumed here — the one bond expression this
    /// task renders).
    public struct MomoBondVariantFlags: OptionSet, Hashable, Sendable {

        public let rawValue: UInt

        public init(rawValue: UInt) {
            self.rawValue = rawValue
        }

        /// Getting Close: the double-tap tail-double-wag reaction variant.
        public static let tailDoubleWag = MomoBondVariantFlags(rawValue: 1 << 0)
        /// Best Friends: the slow-blink-back trust signal on long-press.
        public static let slowBlinkBack = MomoBondVariantFlags(rawValue: 1 << 1)
        /// Soul Companions: the calm-coexist idle (§3.4).
        public static let calmCoexist = MomoBondVariantFlags(rawValue: 1 << 2)
    }

    /// §3.4's three dials for a bond stage, as data.
    public struct MomoBondDials: Equatable, Sendable {

        /// §3.4's reaction latency (seconds): 0.6 / 0.4 / 0.25 / 0.25.
        public let reactionLatencySeconds: Double
        public let greeting: MomoGreetingQuality
        public let unlocked: MomoBondVariantFlags
    }

    public static func bondDials(for stage: BondStage) -> MomoBondDials {
        switch stage {
        case .newFriends:
            MomoBondDials(
                reactionLatencySeconds: 0.6, greeting: .curiousLook, unlocked: [])
        case .gettingClose:
            MomoBondDials(
                reactionLatencySeconds: 0.4, greeting: .twoEarPerk,
                unlocked: [.tailDoubleWag])
        case .bestFriends:
            MomoBondDials(
                reactionLatencySeconds: 0.25, greeting: .wholeBodyBrightening,
                unlocked: [.tailDoubleWag, .slowBlinkBack])
        case .soulCompanions:
            MomoBondDials(
                reactionLatencySeconds: 0.25, greeting: .recognizeSequence,
                unlocked: [.tailDoubleWag, .slowBlinkBack, .calmCoexist])
        }
    }

    // MARK: - The composed expression

    /// The full expression for a display state: every rig channel value the
    /// motion model needs, resolved through §3.2 (mood base), §3.3 (energy
    /// overlays + conflict law) and wakefulness.INV-6 holds by
    /// construction — every value sits inside its §3 range and the audit
    /// test walks the whole input cross-product to keep it that way.
    public struct MomoExpression: Equatable, Sendable {

        /// Semantic aperture (0…1); convert with `lidScaleY(forAperture:)`.
        public let aperture: Double
        public let lowerLid: RigLowerLidPose
        public let earDegrees: Double
        public let tail: MomoTailBehavior
        /// Body scaleY (already clamped into §3.1's range).
        public let postureScaleY: Double
        public let breathCycleSeconds: Double
        public let breathAmplitude: Double
        /// The conflict-law-resolved scheduler-interval multiplier.
        public let intervalMultiplier: Double
        /// Energetic's variant-scheduler frequency boost (1 otherwise).
        public let variantIntervalMultiplier: Double
        public let blinkDurationMultiplier: Double
        public let yawnEnabled: Bool
        public let headNodEnabled: Bool
    }

    /// The composed expression for the given display state.
    ///
    /// Wakefulness rows: `.asleep` closes the eyes (aperture 0), drops the
    /// ears to the mood base, keeps the tail still and lets the breath run
    /// on the Drowsy/asleep row at −30 % amplitude (applied by the motion
    /// model, which owns the amplitude law); `.settling`/`.waking` render
    /// the band expression WITHOUT idle events — the transition
    /// choreography itself is TASK-028. `activity`, `satietyHint` and
    /// `momentRequest` do not alter the resting expression (eating/playing
    /// choreography is TASK-028; the character renders only the hint it is
    /// given, §9.3).
    public static func expression(for state: CharacterDisplayState) -> MomoExpression {
        let base = moodBase(for: state.moodBand)
        let energy = state.energyBand

        // Facial warmth (aperture composition, lids, ears) stays the MOOD's
        // — the higher mood wins warmth (§3.3) — except where energy
        // normatively overlays the aperture itself.
        let apertureMultiplier: Double =
            (energy == .drowsy || energy == .exhausted) ? drowsyApertureMultiplier : 1.0
        let aperture = base.aperture * apertureMultiplier

        // Posture: the mood's base, an extra slump when exhausted, clamped.
        let posture = MomoCurves.clampedPostureScaleY(
            base.postureScaleY * (energy == .exhausted ? exhaustedPostureMultiplier : 1.0))

        // Breath: the Drowsy/asleep row overrides while drowsy, exhausted
        // or asleep (§7.1's row name); Energetic nudges the mood cycle —
        // both compositions stay inside §7.1 bands (audit-pinned).
        let sleepy = energy == .drowsy || energy == .exhausted
            || state.wakefulness == .asleep
        let cycle: Double = sleepy
            ? drowsyBreathCycleSeconds
            : base.breathCycleSeconds * (energy == .energetic ? energeticBreathMultiplier : 1.0)

        return MomoExpression(
            aperture: state.wakefulness == .asleep ? 0 : aperture,
            lowerLid: base.lowerLid,
            earDegrees: base.earDegrees,
            tail: state.wakefulness == .asleep ? .still : base.tail,
            postureScaleY: posture,
            breathCycleSeconds: cycle,
            breathAmplitude: base.breathAmplitude,
            intervalMultiplier: intervalMultiplier(
                mood: state.moodBand, energy: energy),
            variantIntervalMultiplier:
                energy == .energetic ? energeticVariantIntervalMultiplier : 1.0,
            blinkDurationMultiplier: base.blinkDurationMultiplier,
            yawnEnabled: yawnEnabled(energy: energy) && state.wakefulness == .awake,
            headNodEnabled: headNodEnabled(energy: energy) && state.wakefulness == .awake)
    }

    // MARK: - Joyful's tail wag (the one non-still tail behavior)

    /// The slow wag's amplitude in degrees (authored, inside the tail's
    /// ±10° bound) and period (authored: slow — a full swing every ~3.2 s;
    /// pure sine like the breath, §7.2).
    public static let tailWagAmplitudeDegrees: Double = 4.0
    public static let tailWagPeriodSeconds: Double = 3.2
}
