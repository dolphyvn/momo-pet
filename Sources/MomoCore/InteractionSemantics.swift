import Foundation

// MARK: - InteractionSemantics — the PRD §4 response matrix as pure derivation
// (05-technical-architecture §4.4 + §4.5; 04-character-system §6.1–6.3, §9.2,
// §9.6 items 4 and 8; TASK-016 Requirements 1–2, 6–9)

/// The response/effect half of the interaction layer: one fresh
/// `InteractionIntent` in, one `ResponsePlan` + new `EngineState` out —
/// deterministic over (state, intent, calendar, rng) exactly as `reduce`
/// requires (FR-13 AC-3; TASK-016 Requirement 10). The numeric arithmetic and
/// ledger writes live in `InteractionEffects`; the wakefulness/handshake
/// transitions this file triggers (tuck-in settle) follow INV-8's enumerated
/// edges; the fold (already applied by `reduce` at the intent's instant) owns
/// time-derived state — satiety read here is the fold-derived phase.
///
/// **D18 everywhere (state-gated, never limit-gated, always warm — INV-6).**
/// No cell rejects, locks, or punishes: a state-mismatched offer yields the
/// qualitatively-different still-warm beat, and repetition only SOFTENS
/// (multipliers ≤ 1) — the 4th+ same-family instance has zero numeric effect
/// and still counts and still responds.
///
/// **Counting honesty (05 §4.4's I-1 asymmetry):** feed counts always
/// (refusal and asleep decline still increment); play counts on ROUND
/// COMPLETION only (a stir-only state never starts a round, so nothing
/// counts; effects land at the unified cease — `HandshakeMachine`); pat
/// counts always, any state; care counts when performed (in-window tuck-in
/// including blanket-adjust; nap). The SAME events write the bond-ledger
/// families (`BondLedger.recordFamilyUse` — §4.6's variety input, TASK-017).
/// An expired-dayKey intent (no ledger entry)
/// keeps its current-state effects and drops all day attribution
/// (`InteractionEffects.updatingDay` no-ops) — bond included: the hello flag
/// and the cap context both live on the ledger, so an un-ledgered touch earns
/// nothing (TASK-017 Requirement 6).
///
/// **§9.6 item 8 — the formal confirmation this file records.** During
/// `.settling` every interaction declines warm and NOTHING queues: the
/// engine's single-slot `pendingHandshake` makes queueing unrepresentable
/// (a queued choreography would need a second slot), so the warm-decline
/// reading is not a choice the engine made — it is the only state the
/// machine can represent. Settling answers: feed → gentle decline (sleepy),
/// play → the declined-warm stir, touch → the soft stir, a second tuck-in →
/// the blanket-adjust reaffirm, nap → gentle decline; none touch the pending
/// `.settle` token, which still completes.
///
/// **During `.waking` (04 §6.2 + §9.6 item 8's waking half):** interactions
/// apply normally (band-gated) and the pending `.wake` handshake is NEVER
/// cancelled or cleared — wake is never cancelled (04 §9.2). Pat, feed, and
/// nap apply and leave the token alone. The two choreography-STARTING
/// interactions decline warm here — a play round and a tuck-in settle would
/// each need the single handshake slot, and minting into it would silently
/// displace the never-cancelled `.wake` token (recorded interpretation,
/// TASK-016 Requirement 9's guard; the interaction's ResponsePlan still
/// fires).
enum InteractionSemantics {

    /// Applies `intent` to `state` (already folded to the intent's instant by
    /// `reduce`). Returns the new state, the plan the character executes, and
    /// the `.questCompleted` moments the counting events raised (§4.8's
    /// window-checked ticks ride exactly the events that count — TASK-018).
    /// Pure; consumes rng draws ONLY when a choreography token is minted
    /// (play authorization, tuck-in settle — two draws each, the shared
    /// `mintToken` pattern); every other path draws nothing (quest ticks
    /// draw none — the generation/tick draw lineages are separate).
    static func apply(
        _ intent: InteractionIntent,
        to state: EngineState,
        calendar: Calendar,
        rng: inout SeededGenerator
    ) -> (state: EngineState, response: ResponsePlan, moments: [CharacterMoment]) {
        switch intent.kind {
        case .pat(let gesture, let zone):
            return applyPat(intent, gesture: gesture, zone: zone, to: state, calendar: calendar)
        case .feed:
            return applyFeed(intent, to: state, calendar: calendar)
        case .play:
            return applyPlay(intent, to: state, rng: &rng)
        case .tuckIn:
            return applyTuckIn(intent, to: state, calendar: calendar, rng: &rng)
        case .nap:
            return applyNap(intent, to: state, calendar: calendar)
        }
    }

    // MARK: Touch (PRD §4 pet/touch row; 04 §6.1; FR-5)

    /// Touch is never refused (FR-5 AC-2): +2 mood in EVERY state — the
    /// asleep stir is a touch that happened (05 §4.4's pet/touch row lists no
    /// state exemption) — × the pet-family repetition curve, `patCount` +1.
    /// The day's FIRST touch also carries the §4.6 hello (+8 once, via
    /// `BondLedger.awardHello` — device-agnostic, never window-gated); every
    /// later pat moves no bond (G2/FR-10 AC-3). The mood/repetition
    /// arithmetic is untouched by the hello — it wraps the finished pat
    /// result. Reaction per §6.1's gesture×zone map; asleep
    /// and settling collapse to the stir (the §6.2 sleeping cell / the
    /// settling soft-stir), napping counts as sleeping. The pending
    /// handshake is never touched (a mid-`.wake` pat leaves the stretch
    /// intact). The pat serves the `.greet` (Q1) AND `.pet` (Q7) quest
    /// families: after the counter increment and the hello award, the §4.8
    /// tick runs at the intent's own instant (window-checked — a post-noon
    /// pat counts but ticks nothing for Q1).
    private static func applyPat(
        _ intent: InteractionIntent,
        gesture: PatGesture,
        zone: TouchZone?,
        to state: EngineState,
        calendar: Calendar
    ) -> (EngineState, ResponsePlan, [CharacterMoment]) {
        let pet = state.state
        let reaction: ReactionID
        switch pet.wakefulness {
        case .asleep, .settling:
            reaction = ReactionKeys.stir
        case .awake, .waking:
            reaction = pet.activity == .napping
                ? ReactionKeys.stir // napping IS sleeping to a touch (§6.2)
                : touchReaction(gesture: gesture, zone: zone)
        }
        let multiplier = InteractionEffects.repetitionMultiplier(in: state, dayKey: intent.localDayKey, familyCount: \.patCount)
        let mood = InteractionEffects.moodAfterGain(pet.mood, InteractionRules.touchMoodDelta * multiplier)
        // INV-2 holds: the gain is ≥ 0 into an in-range mood, energy/bond untouched.
        let petted = PetState(
            mood: mood,
            energy: pet.energy,
            bond: pet.bond,
            wakefulness: pet.wakefulness,
            activity: pet.activity,
            lastFedAt: pet.lastFedAt,
            satietyPhase: pet.satietyPhase
        )!
        let next = InteractionEffects.updatingDay(state.with(state: petted), intent.localDayKey) {
            InteractionEffects.incremented($0, pat: 1)
        }
        // The §4.6 hello rides the same event that counted the pat — once per
        // dayKey, then an exact no-op (G2: pats beyond the first move nothing).
        // The quest tick follows the ledger writes (counter → hello → tick,
        // the pinned site order).
        let helloed = BondLedger.awardHello(to: next, dayKey: intent.localDayKey)
        let ticked = QuestTick.tick(
            families: [.greet, .pet],
            to: helloed,
            dayKey: intent.localDayKey,
            instant: intent.timestamp,
            calendar: calendar
        )
        return (ticked.state, plan(reaction, for: intent, in: state), ticked.moments)
    }

    /// 04 §6.1's gesture×zone map (FR-5 AC-1 — distinguishable). Double-tap
    /// has one row for both zones (§6.1), so no zone split exists; the
    /// zone-less Watch path (FR-17's `.pat(.tap, nil)`) uses the §8.4
    /// convention's optional-zone form.
    private static func touchReaction(gesture: PatGesture, zone: TouchZone?) -> ReactionID {
        switch gesture {
        case .tap:
            switch zone {
            case .head: return ReactionKeys.tapHead
            case .belly: return ReactionKeys.tapBelly
            case nil: return ReactionKeys.tap
            }
        case .doubleTap:
            return ReactionKeys.doubleTap
        case .longPress:
            switch zone {
            case .head: return ReactionKeys.longPressHead
            case .belly: return ReactionKeys.longPressBelly
            case nil: return ReactionKeys.longPress
            }
        case .stroke:
            switch zone {
            case .head: return ReactionKeys.strokeHead
            case .belly: return ReactionKeys.strokeBelly
            case nil: return ReactionKeys.stroke
            }
        }
    }

    // MARK: Feed (PRD §4 amended feed row; FR-6; 05 §4.4–4.5)

    /// The satiety classes gate the response: `.full` → politely-full
    /// refusal (zero state effect, the clock untouched — no meal happened);
    /// `.recentlyFed` → the contented nibble (effects ×0.25 — I-2,
    /// normative); `.hungry` → the full meal. Effects multiply the
    /// feed-family repetition curve (read before the increment, independent
    /// of satiety — the 2nd meal is softer even 2 h later). An eaten feed
    /// (both non-refusal classes) sets `lastFedAt` = the intent's instant
    /// and `.full` (§4.5). Asleep/settling → the gentle decline (§4.3 —
    /// half-turn away, eyes stay closed): counts, zero effect, no clock
    /// write. Every feed counts (I-1) AND records the `.feed` family use —
    /// refusal and asleep decline included (§4.6's variety input,
    /// `BondLedger.recordFamilyUse`; the variety award rides the
    /// trio-completing event). The beat follows 04 §6.2's state
    /// gating: Drowsy/Exhausted → `sleepyNibbles` (§4.3's L2-variant — the
    /// PRD matrix's "nibbles happily, smaller effect" / "sleepy nibbles"
    /// cells; tempo is character-side), otherwise hungry → the `state.eating`
    /// beat (§4.2 — the eating state IS the response) and recentlyFed → the
    /// `react.nibble` I-2 beat. No `activity` write: nothing in the report
    /// vocabulary clears `.eating`, so the meal is carried by the plan, not
    /// by the activity slot (recorded interpretation; §4.2's eating is a
    /// 2.5–4 s one-shot). The feed serves the `.feed` quest family: the
    /// §4.8 tick rides the same count closure (counter → family record →
    /// tick) at the intent's own instant — refusals and asleep declines
    /// count, so they tick too.
    private static func applyFeed(_ intent: InteractionIntent, to state: EngineState, calendar: Calendar) -> (EngineState, ResponsePlan, [CharacterMoment]) {
        let pet = state.state
        let count = { (s: EngineState) in
            QuestTick.tick(
                families: [.feed],
                to: BondLedger.recordFamilyUse(.feed, to: InteractionEffects.updatingDay(s, intent.localDayKey) {
                    InteractionEffects.incremented($0, feed: 1)
                }, dayKey: intent.localDayKey),
                dayKey: intent.localDayKey,
                instant: intent.timestamp,
                calendar: calendar
            )
        }
        guard !isSleeping(pet), pet.wakefulness != .settling else {
            // Gentle decline-warm: counts, zero state effect, clock untouched.
            let counted = count(state)
            return (counted.state, plan(ReactionKeys.gentleDecline, for: intent, in: state), counted.moments)
        }
        guard pet.satietyPhase != .full else {
            // Politely full (§6.2 — a sated sigh, never a rejection): counts,
            // zero state effect, `lastFedAt` untouched.
            let counted = count(state)
            return (counted.state, plan(ReactionKeys.politelyFull, for: intent, in: state), counted.moments)
        }
        let satietyFactor = pet.satietyPhase == .recentlyFed ? InteractionRules.nibbleEffectMultiplier : 1.0
        let multiplier = InteractionEffects.repetitionMultiplier(in: state, dayKey: intent.localDayKey, familyCount: \.feedCount) * satietyFactor
        let energy = InteractionEffects.energyAfterDelta(pet.energy, InteractionRules.mealEnergyDelta * multiplier)
        let mood = InteractionEffects.moodAfterGain(pet.mood, InteractionRules.mealMoodDelta * multiplier)
        let beat: ReactionID
        switch makeEnergyBand(pet.energy) {
        case .drowsy, .exhausted:
            beat = ReactionKeys.sleepyNibbles
        case .energetic, .relaxed:
            beat = pet.satietyPhase == .recentlyFed ? ReactionKeys.nibble : ReactionKeys.eating
        }
        let fed = PetState(
            mood: mood,
            energy: energy,
            bond: pet.bond,
            wakefulness: pet.wakefulness,
            activity: pet.activity,
            lastFedAt: intent.timestamp,
            satietyPhase: .full
        )!
        let counted = count(state.with(state: fed))
        return (counted.state, plan(beat, for: intent, in: state), counted.moments)
    }

    // MARK: Play (PRD §4 play row; FR-7; 04 §6.3; 05 §4.4's unified cease)

    /// Authorization (Energetic/Relaxed/Drowsy — Drowsy's "short low-key
    /// round" is character-side pacing, same authorization and same effects,
    /// recorded interpretation): `activity = .playing`, a seeded `.play`
    /// token minted into the single handshake slot (two rng draws), and the
    /// round-start beat — the round IS the response. No effects, no count
    /// here: both land at the unified cease instant via `HandshakeMachine`
    /// (`playRoundFinished` OR `handshakeCancelled(.play)`). Exhausted and
    /// any sleeping/settling state → the gentle stir only: no round, no
    /// token, no count (a round that never started did not happen, FR-7
    /// AC-2). Mid-round play → the small cheer (04 §9.2 item 6 — never
    /// resets or extends), full no-op. A waking pet declines warm (the
    /// header's recorded interpretation — the slot holds the wake token).
    /// No quest tick here: the authorization is not a counting event —
    /// effects, count, and the `.play` tick land at the unified cease.
    private static func applyPlay(_ intent: InteractionIntent, to state: EngineState, rng: inout SeededGenerator) -> (EngineState, ResponsePlan, [CharacterMoment]) {
        let pet = state.state
        if pet.activity == .playing {
            return (state, plan(ReactionKeys.cheer, for: intent, in: state), []) // round intact — never resets or extends
        }
        if isSleeping(pet) {
            return (state, plan(ReactionKeys.stir, for: intent, in: state), []) // sleeping: gentle stir only
        }
        switch pet.wakefulness {
        case .settling:
            return (state, plan(ReactionKeys.stir, for: intent, in: state), []) // declined-warm (§9.6 item 8)
        case .waking:
            return (state, plan(ReactionKeys.decline, for: intent, in: state), []) // the slot holds the never-cancelled .wake token
        case .asleep, .awake:
            break
        }
        guard makeEnergyBand(pet.energy) != .exhausted else {
            return (state, plan(ReactionKeys.stir, for: intent, in: state), []) // exhausted: gentle stir only
        }
        let authorized = state
            .with(state: PetState(
                mood: pet.mood,
                energy: pet.energy,
                bond: pet.bond,
                wakefulness: pet.wakefulness,
                activity: .playing,
                lastFedAt: pet.lastFedAt,
                satietyPhase: pet.satietyPhase
            )!)
            .with(pendingHandshake: Handshake(kind: .play, token: mintToken(rng: &rng)))
        return (authorized, plan(ReactionKeys.playReady, for: intent, in: state), [])
    }

    // MARK: Care — tuck-in (PRD §4 care row; FR-8 AC-1; 05 §4.4 I-2 note)

    /// The 20:00-local clock gate (FR-8 AC-1 — evaluated at the intent's own
    /// timestamp through the injected calendar, D20/DST-safe). Out of window
    /// the offer does not exist: gentle warm decline, no settle, no count, no
    /// family use ("in its window" qualifies WHEN care is performed — recorded
    /// interpretation; §4.6: no care count ⇒ no family record). In window: a waking pet settles (+3/+2, `careCount`
    /// +1, `.settling` with a minted `.settle` token — this is what makes
    /// settling reachable and TASK-015's preemption edge live); an asleep
    /// pet gets the blanket-adjust moment (still counts, effects still the
    /// care row's — the care happened; no wakefulness change, no new token);
    /// a settling pet gets the warm reaffirm (no state change, no second
    /// token, no count — the settle's care was counted at authorization);
    /// a waking pet declines (the header's recorded interpretation). A pet
    /// with a round in flight declines until the round ceases — settling
    /// into the single slot would orphan the unified-cease application
    /// (recorded interpretation). Both counting paths quest-tick `.care`
    /// (§4.8) at the intent's own instant — D20 day-ownership means a
    /// 00:30 tuck-in ticks the NEW day's Q6.
    private static func applyTuckIn(
        _ intent: InteractionIntent,
        to state: EngineState,
        calendar: Calendar,
        rng: inout SeededGenerator
    ) -> (EngineState, ResponsePlan, [CharacterMoment]) {
        let pet = state.state
        guard InteractionRules.isTuckInWindow(intent.timestamp, calendar: calendar) else {
            return (state, plan(ReactionKeys.decline, for: intent, in: state), []) // no count — no tick
        }
        if isSleeping(pet) {
            // Blanket-adjust: counts, care effects, stays asleep exactly as it is.
            let mood = InteractionEffects.moodAfterGain(pet.mood, InteractionRules.tuckInMoodDelta)
            let energy = InteractionEffects.energyAfterDelta(pet.energy, InteractionRules.tuckInEnergyDelta)
            let adjusted = PetState(
                mood: mood,
                energy: energy,
                bond: pet.bond,
                wakefulness: pet.wakefulness,
                activity: pet.activity,
                lastFedAt: pet.lastFedAt,
                satietyPhase: pet.satietyPhase
            )!
            let next = InteractionEffects.updatingDay(state.with(state: adjusted), intent.localDayKey) {
                InteractionEffects.incremented($0, care: 1)
            }
            // The care happened — counts AND records the family (§4.6), and
            // ticks the `.care` quest (§4.8).
            let counted = QuestTick.tick(
                families: [.care],
                to: BondLedger.recordFamilyUse(.care, to: next, dayKey: intent.localDayKey),
                dayKey: intent.localDayKey,
                instant: intent.timestamp,
                calendar: calendar
            )
            return (counted.state, plan(ReactionKeys.blanketAdjust, for: intent, in: state), counted.moments)
        }
        if pet.wakefulness == .settling {
            return (state, plan(ReactionKeys.blanketAdjust, for: intent, in: state), []) // warm reaffirm — token untouched, settle still completes
        }
        if pet.wakefulness == .waking {
            return (state, plan(ReactionKeys.decline, for: intent, in: state), []) // the slot holds the never-cancelled .wake token
        }
        if pet.activity == .playing {
            return (state, plan(ReactionKeys.decline, for: intent, in: state), []) // round in flight — cease first
        }
        let mood = InteractionEffects.moodAfterGain(pet.mood, InteractionRules.tuckInMoodDelta)
        let energy = InteractionEffects.energyAfterDelta(pet.energy, InteractionRules.tuckInEnergyDelta)
        let settling = PetState(
            mood: mood,
            energy: energy,
            bond: pet.bond,
            wakefulness: .settling,
            activity: nil,
            lastFedAt: pet.lastFedAt,
            satietyPhase: pet.satietyPhase
        )!
        let next = InteractionEffects.updatingDay(
            state
                .with(state: settling)
                .with(pendingHandshake: Handshake(kind: .settle, token: mintToken(rng: &rng))),
            intent.localDayKey
        ) {
            InteractionEffects.incremented($0, care: 1)
        }
        // Settle-authorization is the care event — counts AND records the
        // family (§4.6), and ticks the `.care` quest (§4.8). The reaffirm
        // path above returns early: its care was counted here, so no second
        // record.
        let counted = QuestTick.tick(
            families: [.care],
            to: BondLedger.recordFamilyUse(.care, to: next, dayKey: intent.localDayKey),
            dayKey: intent.localDayKey,
            instant: intent.timestamp,
            calendar: calendar
        )
        return (counted.state, plan(ReactionKeys.settling, for: intent, in: state), counted.moments)
    }

    // MARK: Care — nap (PRD §4 care row; 05 §4.4's nap row)

    /// Offered only in Drowsy/Exhausted (band-gated — "not offered" in
    /// Energetic/Relaxed is the warm decline): `activity = .napping`,
    /// `careCount` +1, the settle-down beat; the fold completes the nap
    /// (+20 over the nap, landing `.waking`/`.asleep` — TASK-015). Applies
    /// in `.awake` AND `.waking` (band-gated interactions apply during
    /// waking, and the nap touches no handshake slot). Already sleeping
    /// (asleep or mid-nap) → the warm no-op decline; settling → the gentle
    /// decline (§9.6 item 8); a round in flight declines until it ceases.
    /// No repetition multiplier (care is exempt), no token, no rng. Nap
    /// acceptance quest-ticks `.care` (§4.8) at the intent's own instant.
    private static func applyNap(_ intent: InteractionIntent, to state: EngineState, calendar: Calendar) -> (EngineState, ResponsePlan, [CharacterMoment]) {
        let pet = state.state
        if isSleeping(pet) {
            return (state, plan(ReactionKeys.gentleDecline, for: intent, in: state), []) // already sleeping — warm no-op
        }
        if pet.wakefulness == .settling {
            return (state, plan(ReactionKeys.gentleDecline, for: intent, in: state), []) // §9.6 item 8
        }
        if pet.activity == .playing {
            return (state, plan(ReactionKeys.decline, for: intent, in: state), []) // round in flight — cease first
        }
        switch makeEnergyBand(pet.energy) {
        case .drowsy, .exhausted:
            let napping = PetState(
                mood: pet.mood,
                energy: pet.energy,
                bond: pet.bond,
                wakefulness: pet.wakefulness,
                activity: .napping,
                lastFedAt: pet.lastFedAt,
                satietyPhase: pet.satietyPhase
            )!
            let next = InteractionEffects.updatingDay(state.with(state: napping), intent.localDayKey) {
                InteractionEffects.incremented($0, care: 1)
            }
            // Nap acceptance is the care event — counts AND records the
            // family (§4.6) and ticks the `.care` quest (§4.8); the decline
            // paths above record nothing.
            let counted = QuestTick.tick(
                families: [.care],
                to: BondLedger.recordFamilyUse(.care, to: next, dayKey: intent.localDayKey),
                dayKey: intent.localDayKey,
                instant: intent.timestamp,
                calendar: calendar
            )
            return (counted.state, plan(ReactionKeys.settling, for: intent, in: state), counted.moments)
        case .energetic, .relaxed:
            return (state, plan(ReactionKeys.decline, for: intent, in: state), []) // not offered in these bands
        }
    }

    // MARK: Helpers

    /// Sleeping, to an interaction: night-asleep OR mid-nap (the napping pet
    /// has `wakefulness == .awake` with the nap activity — a touch, feed, or
    /// play offer meets a sleeping pet).
    private static func isSleeping(_ pet: PetState) -> Bool {
        pet.wakefulness == .asleep || pet.activity == .napping
    }

    /// The interaction plan shape: the reaction plus the family's day-stable
    /// react line key — `momo.line.react.<family>.<nn>` (§4.9, TASK-019; the
    /// documented TASK-016 nil seam is filled). The family is the INTENT's
    /// (04 §10.4: pat → touch, feed → feed, play → play, tuck-in/nap → care
    /// — every plan is announced, declined/asleep paths included), and the
    /// key is stable per (pet, the intent's dayKey, family) via the `.copy`
    /// salt seed. `haptic` stays presentation-owned vocabulary (04 §9.2) —
    /// the one seam still nil on every engine-minted plan.
    private static func plan(
        _ reaction: ReactionID,
        for intent: InteractionIntent,
        in state: EngineState
    ) -> ResponsePlan {
        ResponsePlan(
            reaction: reaction,
            lineKey: LineSelection.reactLineKey(
                petID: state.pet.id,
                dayKey: intent.localDayKey,
                family: CopyRules.ReactFamily(intent.kind)
            ),
            haptic: nil
        )
    }
}
