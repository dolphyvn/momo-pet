import MomoCore
import Testing

@testable import MomoCharacter

// MARK: - The clip table (TASK-028 R1/R2/R10/R11)

/// The 21-key vocabulary pinned digit-for-digit to 04 §4.3/§6.1/§7.1/§6.3
/// (and the ReactionKeys catalog): raw strings, durations, channel budgets,
/// tempo scoping, and the press/cycle shapes. The case-set pins are the
/// exhaustive-switch guarantee — `ReactionID` is a String struct (INV-11),
/// so a future engine key fails HERE first (the literal 21-string census),
/// and any clip-table gap fails the build (no `default` in either switch).
struct MomoReactionClipTests {

    // MARK: R1 — the closed key set, digit-for-digit

    /// The literal census: exactly these 21 engine keys mint clips. A new
    /// engine key without a clip row breaks this test; a new clip without
    /// an engine key breaks it too.
    @Test("The vocabulary is exactly the 21 minted engine keys (digit-for-digit)")
    func keyCensus() {
        let expected = [
            "react.tap.head", "react.tap.belly", "react.tap", "react.doubleTap",
            "react.longPress.head", "react.longPress.belly", "react.longPress",
            "react.stroke.head", "react.stroke.belly", "react.stroke",
            "react.stir", "react.politelyFull", "react.gentleDecline",
            "react.sleepyNibbles", "react.settling", "react.blanketAdjust",
            "state.eating", "react.nibble", "react.playReady", "react.cheer",
            "react.decline",
        ]
        #expect(MomoReactionKey.allCases.count == 21)
        #expect(MomoReactionKey.allCases.map(\.rawValue) == expected)
        // The mapping is total over the catalog: every minted key opens its
        // clip; an unminted key does not.
        for name in expected {
            #expect(MomoReactionKey(ReactionID(rawValue: name)) != nil)
        }
        #expect(MomoReactionKey(ReactionID(rawValue: "react.unminted")) == nil)
    }

    // MARK: R1 — durations (§6.1 touch map; §4.3/§7.1 bands)

    /// Doc-pinned baselines, digit-for-digit. AUTHORED rows cite their band
    /// in `authority` and are pinned to their authored value here.
    @Test("Baseline durations pin the doc rows digit-for-digit")
    func durationPins() {
        let pins: [(MomoReactionKey, Double)] = [
            (.tapHead, 0.4), (.tapBelly, 0.45), (.tap, 0.6),
            (.doubleTap, 0.7),
            (.longPressHead, 0.6), (.longPressBelly, 0.9), (.longPress, 0.9),
            (.strokeHead, 1.2), (.strokeBelly, 1.0), (.stroke, 1.2),
            (.stir, 1.0), (.politelyFull, 1.2), (.gentleDecline, 1.0),
            (.sleepyNibbles, 3.5), (.settling, 3.0), (.blanketAdjust, 1.5),
            (.eating, 3.2), (.nibble, 1.6), (.playReady, 2.4),
            (.cheer, 0.6), (.decline, 1.0),
        ]
        #expect(pins.count == 21)
        for (key, seconds) in pins {
            #expect(
                MomoReactionClips.spec(for: key).baselineSeconds == seconds,
                "\(key.rawValue) baseline drifted from its doc/authored row")
        }
    }

    /// §7.1's master rows: one-shot reactions land in 0.4–1.2 s, the meal
    /// in 2.5–4.0 s, the settle in its 2.5–3.5 s band, wake in 1.8–2.5 s,
    /// the play invite ≤ 3 s. (Cyclical rows are per-cycle.)
    @Test("Every fixed one-shot sits inside its §7.1 master band")
    func bandMembership() {
        for key in MomoReactionKey.allCases {
            let spec = MomoReactionClips.spec(for: key)
            if spec.cyclical {
                // §6.1's stroke rows: ~1.0–1.2 s per cycle.
                #expect((1.0...1.2).contains(spec.baselineSeconds),
                        "\(key.rawValue) cycle outside §6.1's ~1 s/cycle read")
            } else if key == .eating || key == .sleepyNibbles || key == .settling {
                #expect((2.5...4.0).contains(spec.baselineSeconds),
                        "\(key.rawValue) outside §7.1's 2.5–4.0 state row")
            } else if key == .nibble {
                #expect(spec.baselineSeconds < 2.5,
                        "the nibble is the shortened eating animation")
            } else if key == .blanketAdjust {
                // §4.3's own state-beat row (1.5 s) — not a one-shot.
                #expect(spec.baselineSeconds == 1.5,
                        "\(key.rawValue) drifted from its §4.3 row")
            } else if key == .playReady {
                #expect(spec.baselineSeconds <= 3.0,
                        "§6.3 phase 1 invite ≤ 3 s")
            } else {
                #expect((0.4...1.2).contains(spec.baselineSeconds),
                        "\(key.rawValue) outside §7.1's 0.4–1.2 reaction row")
            }
        }
    }

    // MARK: R11 — the ≤ 8 concurrent-channel budget, pinned per clip

    @Test("No clip animates more than 8 rig channels (§9.4's render budget)")
    func channelBudget() {
        for key in MomoReactionKey.allCases {
            let spec = MomoReactionClips.spec(for: key)
            let channelCount = spec.channels.rawValue.nonzeroBitCount
            #expect(!spec.channels.isEmpty, "\(key.rawValue) animates nothing")
            #expect(channelCount <= 8,
                    "\(key.rawValue) exceeds the 8-channel budget")
        }
        // The budget peaks where the choreography is richest: the meal
        // (mouth + food + face + gaze) is the 8-channel clip.
        #expect(MomoReactionClips.spec(for: .eating).channelCount == 8)
    }

    // MARK: Shapes — press-length and cycles are §6.1's, exactly

    @Test("Exactly the long-press rows are press-shaped; exactly the strokes are cyclical")
    func shapePins() {
        for key in MomoReactionKey.allCases {
            let spec = MomoReactionClips.spec(for: key)
            #expect(spec.pressShaped == (key == .longPressHead || key == .longPressBelly),
                    "\(key.rawValue) press-shape drifted")
            #expect(spec.cyclical == (key == .strokeHead || key == .strokeBelly || key == .stroke),
                    "\(key.rawValue) cyclicity drifted")
        }
        // MINOR-1: the press rows carry their AUTHORED release beats —
        // the visible exhale the slot end resolves from (the belly's 0.45
        // against its 0.9 s rock row; the head's release IS its 0.6
        // baseline). Every other row's baseline is the beat.
        #expect(MomoReactionClips.spec(for: .longPressBelly).pressReleaseSeconds == 0.45)
        #expect(MomoReactionClips.spec(for: .longPressHead).pressReleaseSeconds == 0.6)
        for key in MomoReactionKey.allCases
        where key != .longPressHead && key != .longPressBelly {
            #expect(MomoReactionClips.spec(for: key).pressReleaseSeconds == nil,
                    "\(key.rawValue) grew a press release")
        }
    }

    // MARK: R2 — the band tempo law

    @Test("The tempo law: drowsy ×1.4 (doc-literal), exhausted ×1.5 (authored), awake ×1")
    func tempoValues() {
        #expect(MomoReactionTempo.multiplier(for: .energetic) == 1)
        #expect(MomoReactionTempo.multiplier(for: .relaxed) == 1)
        #expect(MomoReactionTempo.multiplier(for: .drowsy) == 1.4)
        #expect(MomoReactionTempo.multiplier(for: .exhausted) == 1.5)
    }

    /// Tempo scopes strictly the touch family; the stir is the EXEMPT
    /// asleep beat, and the state beats carry their own pacing.
    @Test("Tempo scales exactly the touch-family clips; the stir is exempt")
    func tempoScoping() {
        let touchFamily: [MomoReactionKey] = [
            .tapHead, .tapBelly, .tap, .doubleTap,
            .longPressHead, .longPressBelly, .longPress,
            .strokeHead, .strokeBelly, .stroke,
        ]
        for key in MomoReactionKey.allCases {
            let spec = MomoReactionClips.spec(for: key)
            #expect(spec.tempoScaled == touchFamily.contains(key),
                    "\(key.rawValue) tempo scoping drifted")
        }
        // The exempt stir at drowsy keeps its authored duration.
        let stir = MomoReactionClips.spec(for: .stir)
        #expect(stir.duration(tempo: MomoReactionTempo.drowsyMultiplier) == 1.0)
        #expect(stir.duration(tempo: MomoReactionTempo.exhaustedMultiplier) == 1.0)
        // A touch clip stretches by exactly the multiplier (the drawn value
        // moves; the baseline stays its doc row — the sequencer's reading).
        let tap = MomoReactionClips.spec(for: .tapHead)
        #expect(tap.baselineSeconds == 0.4)
        // Baseline × multiplier to folding precision (0.4 × 1.4 is not a
        // dyadic double).
        #expect(abs(tap.duration(tempo: MomoReactionTempo.drowsyMultiplier) - 0.56) < 1e-9)
        #expect(abs(tap.duration(tempo: MomoReactionTempo.exhaustedMultiplier) - 0.6) < 1e-9)
    }

    // MARK: R10 — curves per §7.2 (spring response, caps)

    @Test("The touch spring family rides §7.2's 0.35 s response and ≤ 15 % overshoot")
    func touchSpringDiscipline() {
        #expect(MomoCurves.touchSpringResponseSeconds == 0.35)
        #expect(MomoCurves.touchOvershootMax == 0.15)
        // The choreography's spring (ζ = 0.8) overshoots once, softly, and
        // never beyond the cap — the shared soft-overshoot judge (the same
        // one the celebrations ride) rejects repeated bounces outright.
        let response = MomoCurves.touchSpringResponseSeconds
        let trajectory = samples(until: response * 2, count: 400)
            .map { MomoReactionChoreography.spring($0) }
        #expect(MomoCurves.isSingleSoftOvershoot(
            trajectory, target: 1, cap: MomoCurves.touchOvershootMax))
        #expect(trajectory.max()! <= 1 + MomoCurves.touchOvershootMax)
        // Held at 1 past two response times (the spring has settled).
        #expect(abs(MomoReactionChoreography.spring(response * 2) - 1) < 0.001)
        #expect(MomoReactionChoreography.spring(0) == 0)
    }

    // MARK: The AUTHORED disclosures (cited in the task file)

    @Test("The AUTHORED rows carry their authority citations")
    func authoredDisclosures() {
        let authoredKeys: [MomoReactionKey] = [
            .tap, .longPress, .longPressHead, .longPressBelly, .stroke,
            .stir, .sleepyNibbles, .settling, .eating, .nibble,
            .playReady, .cheer, .decline,
        ]
        for key in authoredKeys {
            #expect(
                MomoReactionClips.spec(for: key).authority.contains("AUTHORED"),
                "\(key.rawValue) is doc-pinned but labeled AUTHORED, or the reverse")
        }
        // Long-press·belly carries both: the doc's 0.9 rock PLUS the
        // authored 0.45 release beat.
        #expect(MomoReactionClips.spec(for: .longPressBelly).authority
            .contains("§6.1") && MomoReactionClips.spec(for: .longPressBelly)
            .authority.contains("AUTHORED"))
        // NOTE-1: the zone-less long-press is the doc's belly-row digit
        // AUTHORED into the band — it stays 0.9 but is disclosure-labeled.
        #expect(MomoReactionClips.spec(for: .longPress).baselineSeconds == 0.9)
        let docPinned: [MomoReactionKey] = [
            .tapHead, .tapBelly, .doubleTap,
            .strokeHead, .strokeBelly, .politelyFull, .gentleDecline,
            .blanketAdjust,
        ]
        for key in docPinned {
            #expect(
                !MomoReactionClips.spec(for: key).authority.contains("AUTHORED"),
                "\(key.rawValue) cites a doc row")
        }
    }
}
