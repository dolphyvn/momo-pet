import CoreGraphics
import MomoCore
import Testing

@testable import MomoCharacter

// MARK: - Shared TASK-028 fixtures (deterministic; timeline-injected only)

/// The reaction/state battery's shared helpers: display states, plans, and
/// the director fold. No randomness, no ambient time — every instant is an
/// explicit argument (the determinism law the twin tests pin).
enum ReactionFixtures {

    /// A display state with every band named (defaults: the calm awake
    /// baseline — Content, Relaxed, Best Friends, awake, no activity).
    static func displayState(
        mood: MoodBand = .content,
        energy: EnergyBand = .relaxed,
        bond: BondStage = .bestFriends,
        wakefulness: Wakefulness = .awake,
        activity: Activity? = nil,
        momentRequest: CharacterMoment? = nil
    ) -> CharacterDisplayState {
        CharacterDisplayState(
            moodBand: mood, energyBand: energy, bondStage: bond,
            wakefulness: wakefulness, activity: activity,
            satietyHint: nil, momentRequest: momentRequest)
    }

    /// The calm awake baseline the battery's non-band pins use.
    static let content = displayState()

    /// A plan event with no line and no haptic (those seams are the UI's).
    static func plan(_ id: ReactionID, at t: Double) -> MomoCharacterEvent {
        .plan(ResponsePlan(reaction: id, lineKey: nil, haptic: nil), at: t)
    }

    /// Folds `events` in order into a fresh director state.
    static func fold(
        _ events: [MomoCharacterEvent],
        into state: MomoDirectorState = MomoDirectorState(displayState: content)
    ) -> MomoDirectorState {
        var state = state
        for event in events { state.apply(event) }
        return state
    }

    /// The reports matching a `CharacterReport` identity, regardless of
    /// instant (the exactly-once checks count these).
    static func reports(
        matching identity: String, in state: MomoDirectorState
    ) -> [MomoReportEntry] {
        state.reports.filter { $0.identity == identity }
    }

    /// Report identities for the battery.
    static func finished(_ id: ReactionID) -> String {
        "reaction:\(id.rawValue)"
    }
    static let playRound = "playRound"
    static let settleCancelled = "cancelled:settle"
    static let playCancelled = "cancelled:play"
    static let settleFinished = "settle"
    static let wakeFinished = "wake"
}

/// Sampling grid for trajectory sweeps: 120 evenly spaced instants across
/// `0...end` — dense enough that envelope shape violations (double
/// overshoots, missed fades) cannot hide between samples.
func samples(until end: Double, count: Int = 120) -> [Double] {
    guard count > 1 else { return [0] }
    return (0..<count).map { Double($0) * end / Double(count - 1) }
}
