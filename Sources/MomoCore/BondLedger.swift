import Foundation

// MARK: - BondLedger — the §4.6 bond ledger: clamp-at-award, hello, variety,
// quest award, stage reconciliation (05-technical-architecture §4.6; FR-10;
// TASK-017 Requirements 2–7)

/// The engine's ONLY writer of bond and its day-ledger mirrors
/// (`helloAwarded`, `familiesUsed`, `bondAwarded`). Pure: every function is a
/// value-in/value-out derivation over injected state — no clocks, no
/// randomness, no `intent.source` reads (device-agnostic by construction,
/// UX-6/INV-7). Numbers live exclusively in `BondRules`; the 0…1000 range and
/// stage thresholds stay in `Thresholds.Bond` (anti-echo, contract Req 1/8).
///
/// **Clamp-at-award (§4.6; the single award mechanism).** Every award —
/// hello, quest, variety — flows through `award(_:)`, which applies
/// `min(event, dailyBondCap − day.bondAwarded, 1000 − pet.bond)` and writes
/// back EXACTLY what was applied. Both clamp bounds are monotone in what they
/// bound, so `applied ≥ 0` by construction; that one formula makes INV-5
/// (per-dayKey sum ≤ +20), INV-3 (bond monotonic, 0…1000), and PRD §3.3's
/// "1000 is a plateau, not an end" structural rather than checked. The day
/// ledger records what was ACTUALLY applied, so the invariant is exact, not
/// nominal.
///
/// **Expired-dayKey disposition (contract Req 6's recorded interpretation).**
/// Every ledger read/write goes through `InteractionEffects`' keyed access,
/// which no-ops on a missing entry: an intent whose dayKey has no ledger
/// entry keeps its current-state effects (TASK-016 convention) but earns NO
/// bond and sets NO flag — an un-ledgered award would be un-idempotent and
/// un-clampable (INV-5 must stay verifiable). No retroactive `DayRecord` is
/// ever created; the engine stays append-only.
///
/// **Stage reconciliation (FR-10 AC-4, UX-10).** State-based and event-agnostic:
/// `reduce` runs `reconcileStage` after every path's mutation. A
/// `makeBondStage(pet.bond)` above `highestCelebratedStage` emits
/// `momentRequest(.bondStageReached(stage))` and advances the guard WITH the
/// emission — so each crossing emits exactly once ever, including crossings
/// that happened while the app was closed (they surface at the next
/// evaluation of any kind). A multi-stage jump (a big award over a threshold
/// pair) emits ONE moment carrying the CURRENT stage — the singular form of
/// §4.6's `momentRequest(.bondStageReached(newStage))`.
enum BondLedger {

    // MARK: The single award mechanism (§4.6's clamp-at-award)

    /// Applies `delta` bond through the clamp, returning the new state and
    /// the amount actually applied. `applied ≥ 0` by construction (both
    /// bounds are monotone); `applied == 0` returns the state unchanged. The
    /// day entry must exist — every caller is on an intent/report path whose
    /// dayKey is checked first, and a missing entry no-ops (expired-dayKey:
    /// no bond, no ledger write).
    static func award(_ delta: Int, to state: EngineState, dayKey: String) -> (state: EngineState, applied: Int) {
        guard delta > 0, let entry = InteractionEffects.dayEntry(in: state, dayKey: dayKey) else {
            return (state, 0)
        }
        // applied = min(event, cap − awarded, 1000 − bond): ≥ 0 by
        // construction — bondAwarded ≤ cap and bond ≤ 1000 at the model
        // boundary (INV-5/INV-3), so both clamp subtractions are ≥ 0.
        let applied = min(delta,
                          BondRules.dailyBondCap - entry.bondAwarded,
                          Thresholds.Bond.maximum - state.state.bond)
        guard applied > 0 else { return (state, 0) }
        let awarded = InteractionEffects.updatingDay(state, dayKey) {
            rebuilding($0, bondAwarded: $0.bondAwarded + applied)
        }
        let pet = state.state
        // INV-3 cannot fail: applied ≤ 1000 − pet.bond keeps the sum in
        // 0...1000, so the failable init succeeds (house pattern: DEBUG-loud
        // on invariant regression, release keeps the unchanged pet).
        let raised = PetState(
            mood: pet.mood,
            energy: pet.energy,
            bond: pet.bond + applied,
            wakefulness: pet.wakefulness,
            activity: pet.activity,
            lastFedAt: pet.lastFedAt,
            satietyPhase: pet.satietyPhase
        )
        guard let raised else {
            assertionFailure("BondLedger: clamp-at-award produced an out-of-range bond")
            return (state, 0)
        }
        return (awarded.with(state: raised), applied)
    }

    // MARK: The daily hello (INV-7, UX-6)

    /// The first touch (pat) intent attributed to `dayKey` awards +8 once:
    /// gated on `!day.helloAwarded`, which the award sets — idempotent per
    /// dayKey, device-agnostic (no source read), never window-gated (a 14:00
    /// or 23:50 first touch awards identically; Q1's expiry is irrelevant —
    /// the shared trigger has different windows, 03 §Appendix). The flag sets
    /// even when the award clamps to 0 (the day is capped/plateaued — the
    /// touch still happened once; the ledger records the truth of both).
    static func awardHello(to state: EngineState, dayKey: String) -> EngineState {
        guard let entry = InteractionEffects.dayEntry(in: state, dayKey: dayKey),
              !entry.helloAwarded
        else { return state }
        let flagged = InteractionEffects.updatingDay(state, dayKey) {
            rebuilding($0, helloAwarded: true)
        }
        return award(BondRules.helloBondDelta, to: flagged, dayKey: dayKey).state
    }

    // MARK: The family ledger + variety bonus (PRD §3.3; §4.6)

    /// Records one family use on `dayKey` and, when that use completes the
    /// feed/play/care trio, applies the variety award at THIS event ("fired
    /// at the moment all three families are used") — set membership makes the
    /// bonus once-per-day by construction. A family already recorded is a
    /// no-op; a missing day entry no-ops (expired-dayKey earns nothing).
    /// Callers pass exactly the events that count (§4.4's I-1 mirror): feed →
    /// every feed intent; play → the unified cease only; care →
    /// settle-authorization, blanket-adjust, nap-acceptance.
    static func recordFamilyUse(_ family: QuestFamily, to state: EngineState, dayKey: String) -> EngineState {
        guard let entry = InteractionEffects.dayEntry(in: state, dayKey: dayKey),
              !entry.familiesUsed.contains(family)
        else { return state }
        let families = entry.familiesUsed.union([family])
        let completesTrio = !BondRules.varietyTrio.isSubset(of: entry.familiesUsed)
            && BondRules.varietyTrio.isSubset(of: families)
        let recorded = InteractionEffects.updatingDay(state, dayKey) {
            rebuilding($0, familiesUsed: families)
        }
        guard completesTrio else { return recorded }
        return award(BondRules.varietyBondDelta, to: recorded, dayKey: dayKey).state
    }

    // MARK: The quest award (driven by §4.8's quest ticks — TASK-018)

    /// Awards one completed quest's +4 through the clamp. The §4.8
    /// window-checked tick (`QuestTick`) calls this at each completion;
    /// tests drive it directly too.
    static func awardQuestCompletion(to state: EngineState, dayKey: String) -> EngineState {
        award(BondRules.questBondDelta, to: state, dayKey: dayKey).state
    }

    // MARK: Stage reconciliation (FR-10 AC-4, UX-10)

    /// Reconciles the celebrated stage against the derived stage: a crossing
    /// emits `momentRequest(.bondStageReached(currentStage))` exactly once
    /// (the guard advances WITH the emission) and is state-based, so it runs
    /// identically on every event path — interactions, reports, and the
    /// evaluations that surface crossings that happened while closed.
    static func reconcileStage(_ state: EngineState) -> (state: EngineState, moments: [CharacterMoment]) {
        let stage = makeBondStage(state.state.bond)
        guard rank(stage) > rank(state.highestCelebratedStage) else {
            return (state, [])
        }
        return (state.with(highestCelebratedStage: stage), [.bondStageReached(stage)])
    }

    /// Stage precedence (PRD §3.3's ordering). A local rank — `BondStage` is
    /// presentation vocabulary and deliberately unordered; the ledger owns
    /// the comparison.
    private static func rank(_ stage: BondStage) -> Int {
        switch stage {
        case .newFriends: return 0
        case .gettingClose: return 1
        case .bestFriends: return 2
        case .soulCompanions: return 3
        }
    }

    // MARK: Ledger-record rebuild (house pattern)

    /// A copy of `record` with the given bond-ledger fields replaced. The
    /// rebuild cannot fail — `bondAwarded` only grows by `applied ≤ cap −
    /// awarded` (INV-5 preserved) and every other field is carried; failure
    /// would be a programmer error (house pattern: DEBUG-loud, release keeps
    /// the unchanged record rather than corrupting the ledger).
    private static func rebuilding(
        _ record: DayRecord,
        helloAwarded: Bool? = nil,
        familiesUsed: Set<QuestFamily>? = nil,
        bondAwarded: Int? = nil
    ) -> DayRecord {
        guard let updated = DayRecord(
            dayKey: record.dayKey,
            feedCount: record.feedCount,
            playCount: record.playCount,
            careCount: record.careCount,
            patCount: record.patCount,
            questSet: record.questSet,
            helloAwarded: helloAwarded ?? record.helloAwarded,
            familiesUsed: familiesUsed ?? record.familiesUsed,
            bondAwarded: bondAwarded ?? record.bondAwarded,
            questGenEpoch: record.questGenEpoch
        ) else {
            assertionFailure("BondLedger: bond-ledger update rejected — invariant regression")
            return record
        }
        return updated
    }
}
