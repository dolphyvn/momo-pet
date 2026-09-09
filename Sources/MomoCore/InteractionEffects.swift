import Foundation

// MARK: - InteractionEffects — numeric effects, clamps, day-ledger writes, and
// the unified play cease (05-technical-architecture §4.4; TASK-016
// Requirements 2, 3, 5, 7)

/// The effect/count arithmetic half of the interaction layer. Pure: every
/// function is a value-in/value-out derivation over injected state — no
/// clocks, calendars of its own, or randomness (ADR-004; the purity scan
/// holds over this file). The response half lives in `InteractionSemantics`.
///
/// **Counting honesty (05 §4.4's I-1 asymmetry).** Counter writes land on
/// the intent's `localDayKey` ledger entry WHEN ONE EXISTS; an
/// **expired-dayKey intent** (05 §4.4's note — no entry after §5.4 pruning
/// or pre-dating the pet) applies its current-state effects and drops ALL
/// day-ledger attribution: no counters, no retroactive `DayRecord`, and its
/// repetition instance reads as 1 (full effect). Quest-progress ticking is
/// TASK-018's; `familiesUsed` stays engine-untouched here (the variety
/// bonus's input is TASK-017's to consume/write — recorded seam, §22).
enum InteractionEffects {

    // MARK: Clamps

    /// Interaction-path mood write: the gain is applied, then the §3.1
    /// ceiling 92 clamps the GAIN — never the level (D18: an interaction
    /// never lowers mood, so a pet already above the ceiling holds instead
    /// of being pulled down; TASK-016 Requirement 3's recorded
    /// interpretation). INV-2's 0–100 domain is preserved by construction
    /// (gain ≥ 0 into an in-range mood).
    static func moodAfterGain(_ mood: Double, _ gain: Double) -> Double {
        let raised = mood + gain
        return min(raised, max(mood, InteractionRules.interactionMoodCeiling))
    }

    /// Energy write clamped to the INV-2 0–100 domain.
    static func energyAfterDelta(_ energy: Double, _ delta: Double) -> Double {
        min(Thresholds.Scalar.upper, max(Thresholds.Scalar.lower, energy + delta))
    }

    // MARK: Day-ledger writes

    /// The ledger entry for `dayKey`, if one exists. An expired-dayKey
    /// intent finds none (see the enum header).
    static func dayEntry(in state: EngineState, dayKey: String) -> DayRecord? {
        state.days.first { $0.dayKey == dayKey }
    }

    /// Applies `transform` to the ledger entry with `dayKey`; a missing entry
    /// is a no-op (expired-dayKey: effects without attribution — no counters,
    /// no retroactive record).
    static func updatingDay(_ state: EngineState, _ dayKey: String, _ transform: (DayRecord) -> DayRecord) -> EngineState {
        guard let index = state.days.firstIndex(where: { $0.dayKey == dayKey }) else {
            return state
        }
        var days = state.days
        days[index] = transform(days[index])
        return state.with(days: days)
    }

    /// A copy of `record` with the given counters incremented. The rebuild
    /// cannot fail — counters only grow by non-negative deltas and every
    /// other field is preserved, so INV-4/INV-5 and the exactly-3 quest set
    /// all hold; failure would be a programmer error (house pattern:
    /// DEBUG-loud, release keeps the unchanged record rather than
    /// corrupting the ledger).
    static func incremented(_ record: DayRecord, feed: Int = 0, play: Int = 0, care: Int = 0, pat: Int = 0) -> DayRecord {
        guard let updated = DayRecord(
            dayKey: record.dayKey,
            feedCount: record.feedCount + feed,
            playCount: record.playCount + play,
            careCount: record.careCount + care,
            patCount: record.patCount + pat,
            questSet: record.questSet,
            helloAwarded: record.helloAwarded,
            familiesUsed: record.familiesUsed,
            bondAwarded: record.bondAwarded,
            questGenEpoch: record.questGenEpoch
        ) else {
            assertionFailure("InteractionEffects: counter update rejected — invariant regression")
            return record
        }
        return updated
    }

    /// The same-family repetition multiplier for an interaction landing on
    /// `dayKey`: the family's day counter is read BEFORE the interaction
    /// increments it (05 §4.5 — the 2nd instance is the counter's 1). A day
    /// with no ledger entry reads as instance 1 (expired-dayKey: full
    /// effect, no count). Care callers never ask — care carries no
    /// multiplier (§4.4's I-2 note).
    static func repetitionMultiplier(in state: EngineState, dayKey: String, familyCount keyPath: KeyPath<DayRecord, Int>) -> Double {
        let priorCount = dayEntry(in: state, dayKey: dayKey)?[keyPath: keyPath] ?? 0
        return InteractionRules.repetitionMultiplier(instanceIndex: priorCount)
    }

    // MARK: The unified play cease (04 §9.6 item 4)

    /// The play round's effects + count, applied at the SINGLE instant the
    /// round ceases — `HandshakeMachine` routes both `playRoundFinished` and
    /// `handshakeCancelled(.play)` here, and a report with nothing pending
    /// never reaches this function, so application is exactly-once by
    /// structure (TASK-016 Requirement 7). The repetition multiplier reads
    /// the CEASE instant's ledger day (a round authorized 23:58 ceasing
    /// 00:01 counts on the new day, softened by THAT day's curve — the
    /// cease instant is when the round "happened", FR-7 AC-2); a cease on a
    /// day with no ledger entry applies instance-1 effects and drops the
    /// count. The mood ceiling 92 clamps the mood gain (PRD §3.1's
    /// representative case); the activity clears with the round.
    static func applyPlayRoundEffects(to state: EngineState, at ceaseInstant: Instant, calendar: Calendar) -> EngineState {
        let pet = state.state
        let dayKey = DayKey.make(from: ceaseInstant, calendar: calendar)
        let multiplier = repetitionMultiplier(in: state, dayKey: dayKey, familyCount: \.playCount)
        let energy = energyAfterDelta(pet.energy, InteractionRules.playRoundEnergyDelta * multiplier)
        let mood = moodAfterGain(pet.mood, InteractionRules.playRoundMoodDelta * multiplier)
        // INV-2 cannot fail here: `moodAfterGain`/`energyAfterDelta` keep
        // both scalars in 0...100 from an in-range `pet` (house pattern:
        // the force-unwrap documents the invariant).
        let ceased = PetState(
            mood: mood,
            energy: energy,
            bond: pet.bond,
            wakefulness: pet.wakefulness,
            activity: nil,
            lastFedAt: pet.lastFedAt,
            satietyPhase: pet.satietyPhase
        )!
        return updatingDay(state.with(state: ceased), dayKey) { incremented($0, play: 1) }
    }
}
