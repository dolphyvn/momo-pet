import Foundation

// MARK: - TimeFold — segment-fold catch-up (05-technical-architecture §4.2–4.3;
// ADR-004; TASK-015 Requirements 1–4)

/// One segment of the elapsed-time decomposition (§4.2: "elapsed wall time
/// since `lastEvaluatedAt` is decomposed into segments (waking hours / night
/// windows / local-midnight boundaries / nap intervals) using the user's
/// calendar, and each segment applies its rule once, in order").
///
/// Segments alternate at the two night-window bounds (22:00 local onset,
/// 07:00 local wake — `FoldRules`); local midnight needs no split point
/// because it is interior to the night window and the day rollover is keyed
/// on `dayKey` (below), not on segment arithmetic. DST transitions change the
/// segments' real durations only (§4.3 "DST transitions change segment
/// arithmetic only") — `Calendar`'s boundary enumeration (`enumerateDates`,
/// policy `.nextTime`) resolves each bound's true instant, including the
/// fall-back night's extra hour and the spring-forward night's missing hour.
/// (The equivalent `nextDate(after:)` API is avoided because its name contains
/// the engine-purity scanner's banned `Date(` literal — TASK-015's disclosed
/// constraint, no scanner exemption.)
struct FoldSegment: Equatable {

    /// Segment start (inclusive).
    let start: Instant

    /// Segment end (exclusive; equals the next segment's start or the fold target).
    let end: Instant

    /// True inside the night window (local hour ≥ 22:00 or < 07:00).
    let isNight: Bool
}

/// The fold's answer: new pet dynamics + ledger + the fold-side handshake
/// disposition (see `FoldResult.pendingHandshake`).
struct FoldResult: Equatable {

    /// The pet state after the fold (all ranges clamped — INV-2 holds).
    let petState: PetState

    /// The ledger after the fold: at most the landing day appended (below).
    let days: [DayRecord]

    /// The pending handshake after the fold. Untouched for folds that do not
    /// transition the wakefulness; cleared proactively when a night/morning
    /// transition orphans it — §4.7: "the engine is never left waiting on a
    /// report that will never come". (`handshakeCancelled` remains the
    /// character-side path and stays tolerated idempotently; a report arriving
    /// after the fold cleared its handshake is simply discarded.)
    let pendingHandshake: Handshake?
}

/// The pure segment-fold catch-up. No clocks, no calendars of its own, no
/// randomness — everything is injected (ADR-004; the purity scan holds over
/// this file).
///
/// **Interpretations this implementation pins** (each is a TASK-015 judgment
/// recorded for review):
///
/// 1. **Segment resolution.** §4.3's numbers apply once per segment, in
///    order. The mood-coupling target is chosen from the segment-start energy
///    band; a band crossing inside a segment takes effect at the next
///    segment. Finer splitting (at band crossings) was rejected — the spec's
///    segment set is waking/night/midnight/nap, and the coupling is
///    self-healing by design (PRD §3.1).
/// 2. **Night ramp slope.** The restore ramps linearly toward
///    `FoldRules.nightRestoreTarget` (85) at 07:00 with the slope anchored to
///    the containing local night's FULL duration (onset→wake, real seconds —
///    DST-correct). Entering mid-night anchors the fold-carried energy at the
///    night's nominal onset (the fold never invents history before
///    `lastEvaluatedAt`), so partial/late nights restore proportionally and
///    the wake clamp stays meaningful — a pet asleep only 06:30–07:00 wakes
///    clamped to ≥ 75, not restored to 85. The ramp never drains (a pet above
///    85 holds steady) and never overshoots 85.
/// 3. **Nap spans the fold.** The domain model has no nap-start instant (05
///    §3.1), so a fold that starts with `activity == .napping` treats the nap
///    as spanning it: waking decline is suppressed, night ramps still apply,
///    and at fold end the nap completes — `FoldRules.napRestoreEnergy` added
///    (clamped ≤ 100), activity cleared, wakefulness landed per §4.7's
///    `napping → waking` edge, except a landing inside the night window merges
///    into sleep (`.asleep`) — the pet slept through the night.
/// 4. **Landing-day rollover.** Only the day the fold LANDS in gets its
///    `DayRecord` (appended when the ledger lacks its `dayKey`): absent days
///    stay silently empty (FR-12 AC-1), and the append is keyed — a backward
///    clock re-deriving an awarded `dayKey` finds it present, so no second
///    record and no reset of any kind (FR-11/D20, exactly-once by structure).
///    The placeholder quest set is the documented TASK-018 seam (real seeded
///    generation replaces the content; the shape/append/exactly-once
///    semantics are what TASK-015 delivers).
enum TimeFold {

    // MARK: Decomposition

    /// Decomposes `[from, to)` into alternating waking/night segments (empty
    /// when `from >= to` — folds are forward-only; reduce guards that too).
    static func segments(from: Instant, to: Instant, calendar: Calendar) -> [FoldSegment] {
        guard from < to else { return [] }
        var result: [FoldSegment] = []
        var cursor = from
        while cursor < to {
            let isNight = isInNightWindow(cursor, calendar: calendar)
            let end = min(nextBoundary(after: cursor, calendar: calendar) ?? to, to)
            guard end > cursor else { break } // pathological-calendar safety: never loop
            result.append(FoldSegment(start: cursor, end: end, isNight: isNight))
            cursor = end
        }
        return result
    }

    /// Whether `instant`'s local time is inside the night window (D11 bounds
    /// from `FoldRules`): [22:00, 07:00) local.
    static func isInNightWindow(_ instant: Instant, calendar: Calendar) -> Bool {
        let hour = calendar.component(.hour, from: instant)
        return hour >= FoldRules.nightOnsetHour || hour < FoldRules.morningWakeHour
    }

    /// The earliest local boundary strictly after `instant`: the next 22:00
    /// or the next 07:00. `.nextTime` resolves DST-skipped/repeated walls.
    private static func nextBoundary(after instant: Instant, calendar: Calendar) -> Instant? {
        let onset = nextHourBound(FoldRules.nightOnsetHour, after: instant, calendar: calendar)
        let wake = nextHourBound(FoldRules.morningWakeHour, after: instant, calendar: calendar)
        switch (onset, wake) {
        case let (o?, w?): return min(o, w)
        case let (o?, nil): return o
        case let (nil, w?): return w
        default: return nil
        }
    }

    private static func nextHourBound(_ hour: Int, after instant: Instant, calendar: Calendar) -> Instant? {
        var components = DateComponents()
        components.hour = hour
        var found: Instant?
        calendar.enumerateDates(
            startingAfter: instant,
            matching: components,
            matchingPolicy: .nextTime
        ) { date, _, stop in
            if let date {
                found = date
                stop = true
            }
        }
        return found
    }

    // MARK: Application

    /// Applies §4.3's rules segment by segment, in order, then lands the
    /// wakefulness/nap/rollover bookkeeping. Pure: the caller injects state,
    /// span, and calendar.
    static func apply(
        petState: PetState,
        days: [DayRecord],
        pendingHandshake: Handshake?,
        from: Instant,
        to: Instant,
        calendar: Calendar
    ) -> FoldResult {
        guard from < to else {
            return FoldResult(petState: petState, days: days, pendingHandshake: pendingHandshake)
        }

        var energy = petState.energy
        var mood = petState.mood
        var wakefulness = petState.wakefulness
        var activity = petState.activity
        let nappingCarried = petState.activity == .napping
        let incomingWakefulness = petState.wakefulness

        for segment in segments(from: from, to: to, calendar: calendar) {
            let hours = segment.end.timeIntervalSince(segment.start) / 3600.0
            if segment.isNight {
                energy = nightRamp(energy, segmentStart: segment.start, segmentEnd: segment.end, calendar: calendar)
                // Night onset crossed: the pet sleeps (§4.3 closing paragraph —
                // the app-closed fold lands `.asleep` directly, the documented
                // silent compression of §4.7's awake→settling→asleep path when
                // no character is listening; no handshake).
                if wakefulness != .asleep { wakefulness = .asleep }
                // Night calm: plain attractor (coupling requires waking hours).
                mood = attractorStep(mood, target: FoldRules.moodAttractorTarget, hours: hours)
            } else {
                // Coupling band reads the SEGMENT-START energy (interpretation
                // 1): a band crossing inside the segment takes effect at the
                // next segment. REVIEW-TASK-015 MINOR-1: this read originally
                // sat after the decline (segment-end) — the discriminating pin
                // `couplingBandReadsSegmentStart` locks the documented reading.
                let bandAtSegmentStart = makeEnergyBand(energy)
                if !nappingCarried {
                    energy = max(Thresholds.Scalar.lower, energy + FoldRules.wakingEnergyDeclinePerHour * hours)
                }
                let couplingActive = !nappingCarried
                    && (bandAtSegmentStart == .drowsy || bandAtSegmentStart == .exhausted)
                let target = couplingActive ? FoldRules.moodCoupledTarget : FoldRules.moodAttractorTarget
                mood = attractorStep(mood, target: target, hours: hours)
            }

            // Wake boundary crossed OUT of the night: the pet wakes (§4.3
            // closing — lands `.waking`; the waking stretch is offered by the
            // NEXT in-session evaluation via handshake, reduce's job).
            if segment.isNight, !isInNightWindow(segment.end, calendar: calendar) {
                energy = max(energy, FoldRules.wakeEnergyClamp)
                if wakefulness != .waking { wakefulness = .waking }
            }
        }

        // Nap completion at fold end (interpretation 3).
        if nappingCarried {
            energy = min(Thresholds.Scalar.upper, energy + FoldRules.napRestoreEnergy)
            activity = nil
            let landedInNight = isInNightWindow(to, calendar: calendar)
            wakefulness = landedInNight ? .asleep : .waking
        }

        // INV-2 clamps (mood floor is PRD-normative; the attractor alone can
        // never push below its target, so the clamp is the structural guarantee).
        mood = max(FoldRules.moodFloor, min(Thresholds.Scalar.upper, mood))
        energy = max(Thresholds.Scalar.lower, min(Thresholds.Scalar.upper, energy))

        // Fold-side handshake disposition (see FoldResult.pendingHandshake):
        // a transition that orphans the pending handshake clears it; a `.wake`
        // token survives a landing in `.waking` (it IS the wake stretch's
        // token). A `.play` token orphaned by a wakefulness transition ends
        // its round HERE WITHOUT effects or count (disclosed TASK-016 edit,
        // out of TASK-015's letter: night overtook the round — no report can
        // arrive for a token the fold cleared, and leaving `activity ==
        // .playing` would strand it forever; the unified cease stays the
        // character reports' alone, so this path applies no arithmetic).
        var foldedHandshake = pendingHandshake
        var foldedActivity = activity
        if wakefulness != incomingWakefulness, let pending = pendingHandshake {
            let survives = (wakefulness == .waking && pending.kind == .wake)
            if !survives {
                foldedHandshake = nil
                if pending.kind == .play { foldedActivity = nil }
            }
        }

        let foldedState = PetState(
            mood: mood,
            energy: energy,
            bond: petState.bond,
            wakefulness: wakefulness,
            activity: foldedActivity,
            lastFedAt: petState.lastFedAt,
            // §4.5 satiety derivation — the fold owns time-derived state
            // (TASK-016 Requirement 4): the phase at the fold's END instant.
            satietyPhase: satietyPhase(lastFedAt: petState.lastFedAt, at: to)
        )!

        let foldedDays = rollover(days: days, landingDay: DayKey.make(from: to, calendar: calendar))

        return FoldResult(petState: foldedState, days: foldedDays, pendingHandshake: foldedHandshake)
    }

    /// §4.5's satiety window derivation, from `lastFedAt` to `instant`:
    /// no `lastFedAt` (never fed) or ≥ 90 min → `.hungry`; [0, 30) min →
    /// `.full`; [30, 90) min → `.recentlyFed` — half-open windows per the
    /// DECISION table (30:00 is recentlyFed's first minute, 90:00 hungry's).
    /// Window values come from `InteractionRules` (the constants home).
    /// Negative elapsed (unreachable under forward-only folds) reads `.full`
    /// — the feed is still "just now".
    static func satietyPhase(lastFedAt: Instant?, at instant: Instant) -> SatietyPhase {
        guard let lastFedAt else { return .hungry }
        let minutes = instant.timeIntervalSince(lastFedAt) / 60.0
        if minutes < Double(InteractionRules.satietySplitMinutes) { return .full }
        if minutes < Double(InteractionRules.satietyWindowMinutes) { return .recentlyFed }
        return .hungry
    }

    // MARK: Segment rules

    /// §4.3 night restore: linear ramp toward `nightRestoreTarget` at 07:00,
    /// slope anchored to the containing night's full duration; never drains,
    /// never overshoots (interpretation 2).
    private static func nightRamp(_ energy: Double, segmentStart: Instant, segmentEnd: Instant, calendar: Calendar) -> Double {
        guard let bounds = nightBounds(containing: segmentStart, calendar: calendar) else { return energy }
        let fullNight = bounds.wake.timeIntervalSince(bounds.onset)
        guard fullNight > 0 else { return energy }
        let slope = (FoldRules.nightRestoreTarget - energy) / fullNight
        let restored = energy + slope * segmentEnd.timeIntervalSince(segmentStart)
        return min(FoldRules.nightRestoreTarget, max(energy, restored))
    }

    /// The local night containing `instant`: onset = 22:00 of the night's
    /// local day (the previous day for the 00:00–07:00 shoulder, the same day
    /// from 22:00 on), wake = 07:00 of the following day. Built by component
    /// arithmetic so `Calendar` itself resolves each wall time — DST-correct:
    /// the fall-back night's 07:00 exists once (in standard time) and the
    /// spring-forward night's wall components skip the gap, giving real
    /// durations of 10 h and 8 h respectively.
    private static func nightBounds(containing instant: Instant, calendar: Calendar) -> (onset: Instant, wake: Instant)? {
        let hour = calendar.component(.hour, from: instant)
        var day = calendar.dateComponents([.year, .month, .day], from: instant)
        if hour < FoldRules.nightOnsetHour {
            // Before 22:00 (the whole morning shoulder included): this
            // night's onset was the previous local day's 22:00.
            guard let dayStart = calendar.date(from: day),
                  let previous = calendar.date(byAdding: .day, value: -1, to: dayStart)
            else { return nil }
            day = calendar.dateComponents([.year, .month, .day], from: previous)
        }
        var onsetComponents = day
        onsetComponents.hour = FoldRules.nightOnsetHour
        guard let onset = calendar.date(from: onsetComponents) else { return nil }

        guard let onsetDay = calendar.date(from: day),
              let nextDay = calendar.date(byAdding: .day, value: 1, to: onsetDay)
        else { return nil }
        var wakeComponents = calendar.dateComponents([.year, .month, .day], from: nextDay)
        wakeComponents.hour = FoldRules.morningWakeHour
        guard let wake = calendar.date(from: wakeComponents) else { return nil }
        return (onset, wake)
    }

    /// The mood attractor step, exact over the segment (§4.3:
    /// `mood += (target − mood) × (1 − e^(−Δt/τ))`).
    private static func attractorStep(_ mood: Double, target: Double, hours: Double) -> Double {
        mood + (target - mood) * (1 - exp(-hours / FoldRules.moodAttractorTauHours))
    }

    // MARK: Day rollover

    /// FR-11/D20: guarantees the landing day's record exists — appended when
    /// absent (the daily reset: zero counters, fresh quest slots, hello
    /// un-awarded), untouched when present (backward clocks re-derive the
    /// awarded `dayKey` and find it — no double reset, no double hello;
    /// exactly-once by structure). Absent intermediate days are never
    /// retro-created (FR-12 AC-1).
    private static func rollover(days: [DayRecord], landingDay: String) -> [DayRecord] {
        guard !days.contains(where: { $0.dayKey == landingDay }) else { return days }
        // TASK-018 seam: real seeded quest generation replaces the placeholder
        // set (Q1 + Q2 + Q6, zero progress). The set must satisfy DayRecord's
        // exactly-3 invariant today; `questGenEpoch: 0` marks the placeholder.
        let placeholderQuests = [QuestID.q1, .q2, .q6].compactMap { QuestProgress(questID: $0, progress: 0, completed: false) }
        guard let record = DayRecord(
            dayKey: landingDay,
            feedCount: 0,
            playCount: 0,
            careCount: 0,
            patCount: 0,
            questSet: placeholderQuests,
            helloAwarded: false,
            familiesUsed: [],
            bondAwarded: 0,
            questGenEpoch: 0
        ) else {
            // Unreachable: zero counters satisfy INV-4, 0 satisfies INV-5, and
            // the placeholder set has exactly 3 distinct quests. Constructing
            // the ledger entry is structural, so failure here is a programmer
            // error — loud in debug, and the ledger is left unchanged rather
            // than corrupted (house pattern: DEBUG-loud, release-safe).
            assertionFailure("TimeFold: placeholder DayRecord rejected — invariant regression")
            return days
        }
        return days + [record]
    }
}
