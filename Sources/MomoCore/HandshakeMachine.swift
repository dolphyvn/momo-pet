import Foundation

// MARK: - Wakefulness machine + handshake application (05-technical-architecture
// §4.7; INV-8; 04-character-system §9.2; TASK-015 Requirements 5–6)

/// The handshake half of the wakefulness machine: applies a character report
/// to a state that has already been folded to now (§4.2: "fold-to-now, then
/// report handling"), under INV-8's legal-transition discipline.
///
/// **Report matching (the idempotency contract, §4.7 / 04 §9.2).** Reports
/// arrive token-less — 04 §9.2's `CharacterReport` vocabulary (normative
/// shape; "TASK-006 finalizes exact types") carries no UUID field — so the
/// engine matches a report against the single `pendingHandshake` by KIND, and
/// the pending token's UUID is what makes a re-issued handshake a distinct
/// value. The tolerance §4.7 requires ("a late, duplicate, or stale report …
/// is accepted and applied or discarded without stranding") falls out:
///
/// - **Apply:** a report applies only while the matching handshake is pending
///   AND the pet is in the report's source state (`.settleFinished` from
///   `.settling`, `.wakeFinished`-equivalent from `.waking`). Applying clears
///   the pending handshake, so a duplicate report is a no-op.
/// - **Stale discard:** the pending kind matches but the pet has moved past
///   the report's source state (e.g. a fold landed `.asleep` over a
///   `.settling` pet whose settle choreography then finished late) — the
///   transition is rejected as illegal (INV-8) and the dead handshake is
///   cleared so the engine is never left waiting on a report that will never
///   come. The TimeFold side clears orphans proactively at fold transitions;
///   this path covers reports that outlive their handshake any other way.
/// - **No-op:** nothing pending, or a different kind pending — the report is
///   a tolerated no-op (nothing strands, nothing changes).
///
/// **Interpretation recorded for review:** the residual race a token-less
/// vocabulary cannot distinguish — a cancelled generation's report arriving
/// after a NEWER same-kind handshake was issued — applies the newer
/// handshake's completion one report early (warm, state-consistent: the
/// pet simply settles/asleep a beat sooner). Eliminating it would require
/// widening 04 §9.2's report payloads with token echoes, a character-contract
/// change this task deliberately does not make.
///
/// The wakefulness TRANSITIONS themselves are exactly §4.7's diagram:
/// `settling ──settleFinished──► asleep`,
/// `settling ──handshakeCancelled(.settle)──► awake` (the preemption edge —
/// REVIEW-TASK-015 MINOR-2), and `waking ──(report)──► awake` (never
/// cancelled — completing on return), and nothing else through this path.
/// The fold's own edges (night onset → `.asleep`, morning/nap-end → `.waking`)
/// live in `TimeFold` — §4.3's closing paragraph, the documented silent
/// compression of the diagram's choreographed path when no character is
/// listening. Illegal transitions are therefore unrepresentable: every path
/// into a wakefulness change is one of those enumerated edges.
enum HandshakeMachine {

    /// Applies `report` to `state` (already folded to `instant` by `reduce`).
    /// Returns the new state and the moments the application raised (the
    /// unified cease's `.questCompleted` emissions — a report-path completion
    /// emits on the report event; contract Req 6's threading). The instant +
    /// calendar are injected so the play round's unified-cease effects
    /// attribute to the CEASE instant's ledger day (TASK-016 Requirement 7 —
    /// a round authorized 23:58 ceasing 00:01 counts on the new day). Pure.
    static func apply(_ report: CharacterReport, to state: EngineState, at instant: Instant, calendar: Calendar) -> (state: EngineState, moments: [CharacterMoment]) {
        switch report {
        case .settleFinished:
            return (complete(kind: .settle, from: .settling, to: .asleep, state: state), [])

        case .wakeFinished:
            // §4.7: `waking ──wakeFinished──► awake` — never cancelled;
            // app-hide pauses the stretch and it completes on return.
            return (complete(kind: .wake, from: .waking, to: .awake, state: state), [])

        case .playRoundFinished:
            // The unified play cease (04 §9.6 item 4, confirmed 05 §4.7;
            // TASK-016 Requirement 7): the round's effects + `playCount` land
            // HERE at the single instant the round ceases.
            return completePlayRound(state: state, at: instant, calendar: calendar)

        case .handshakeCancelled(let kind):
            // The preemption path (04 §9.2): clears the matching pending
            // handshake, idempotently — no matching pending token is a no-op.
            // §4.7's diagram routes a settle preemption back to `.awake` —
            // cancellation exists "so the engine is never stranded in an
            // intermediate wakefulness" (04 §9.2; REVIEW-TASK-015 MINOR-2).
            // The wake stretch is never cancelled (04 §9.2: app-hide pauses
            // it and it completes on return).
            guard state.pendingHandshake?.kind == kind else { return (state, []) }
            if kind == .settle, state.state.wakefulness == .settling {
                return (complete(kind: .settle, from: .settling, to: .awake, state: state), [])
            }
            if kind == .play {
                // Cancellation is the SAME unified cease (TASK-016 Req 7):
                // the round ends here — effects + count once, exactly as a
                // finished round.
                return completePlayRound(state: state, at: instant, calendar: calendar)
            }
            return (state.with(pendingHandshake: nil), [])

        case .reactionFinished, .momentFinished:
            // No handshake association: reaction completion is presentation
            // bookkeeping; moment display is presentation-side. A tolerated
            // no-op at the engine core.
            return (state, [])
        }
    }

    /// The unified play-round cease, shared by `playRoundFinished` and
    /// `handshakeCancelled(.play)`: with a `.play` handshake pending, the
    /// round's effects + count apply exactly once (`InteractionEffects.
    /// applyPlayRoundEffects` — the cease instant's ledger day, repetition
    /// curve, ceiling-clamped mood, and the §4.8 `.play` quest tick whose
    /// moments surface here), the token clears, and the playing activity
    /// clears with the round. Nothing pending → tolerated no-op that applies
    /// nothing (a stale/duplicate report must not re-count — idempotency by
    /// structure). Pure.
    private static func completePlayRound(state: EngineState, at instant: Instant, calendar: Calendar) -> (state: EngineState, moments: [CharacterMoment]) {
        guard state.pendingHandshake?.kind == .play else {
            return (state, []) // stale/duplicate — nothing to cease, applies nothing
        }
        let ceased = InteractionEffects.applyPlayRoundEffects(to: state, at: instant, calendar: calendar)
        return (ceased.state.with(pendingHandshake: nil), ceased.moments)
    }

    /// The shared transition path (completion AND the settle preemption
    /// edge): applies the legal transition when the matching handshake is
    /// pending from the expected source state; discards stale reports and
    /// un-strands their dead handshake; no-ops otherwise.
    private static func complete(kind: HandshakeKind, from source: Wakefulness, to target: Wakefulness, state: EngineState) -> EngineState {
        guard let pending = state.pendingHandshake, pending.kind == kind else {
            return state // late/duplicate/stray report — tolerated no-op
        }
        guard state.state.wakefulness == source else {
            // Stale: the pet moved past this choreography's source state.
            // Reject the illegal transition (INV-8) and clear the dead token —
            // "discarded without stranding" (§4.7).
            return state.with(pendingHandshake: nil)
        }
        let settled = PetState(
            mood: state.state.mood,
            energy: state.state.energy,
            bond: state.state.bond,
            wakefulness: target,
            // REVIEW-TASK-016 MINOR-1: the activity clears with the settle
            // kinds only — a `.wake` completion preserves it, so a nap
            // accepted during the waking stretch (band-gated, contract Req 9)
            // survives to be completed by the next fold (+20) instead of
            // being voided by a zero-elapsed report while its careCount
            // already stands. Settle paths always carry `activity == nil`
            // (everything declines warm during settling).
            activity: kind == .wake ? state.state.activity : nil,
            lastFedAt: state.state.lastFedAt,
            satietyPhase: state.state.satietyPhase
        )!
        return state
            .with(state: settled)
            .with(pendingHandshake: nil)
    }
}

// MARK: - EngineState functional update (module-private helpers)

extension EngineState {

    /// A copy with `petState` replaced — the module's immutability convention
    /// (construct new values; zero `var` storage).
    func with(state petState: PetState) -> EngineState {
        EngineState(
            pet: pet,
            state: petState,
            days: days,
            settings: settings,
            pendingHandshake: pendingHandshake,
            processedIntents: processedIntents,
            highestCelebratedStage: highestCelebratedStage,
            lastOpenedAt: lastOpenedAt,
            lastEvaluatedAt: lastEvaluatedAt
        )
    }

    /// A copy with `pendingHandshake` replaced.
    func with(pendingHandshake: Handshake?) -> EngineState {
        EngineState(
            pet: pet,
            state: state,
            days: days,
            settings: settings,
            pendingHandshake: pendingHandshake,
            processedIntents: processedIntents,
            highestCelebratedStage: highestCelebratedStage,
            lastOpenedAt: lastOpenedAt,
            lastEvaluatedAt: lastEvaluatedAt
        )
    }

    /// A copy with `days` replaced.
    func with(days: [DayRecord]) -> EngineState {
        EngineState(
            pet: pet,
            state: state,
            days: days,
            settings: settings,
            pendingHandshake: pendingHandshake,
            processedIntents: processedIntents,
            highestCelebratedStage: highestCelebratedStage,
            lastOpenedAt: lastOpenedAt,
            lastEvaluatedAt: lastEvaluatedAt
        )
    }

    /// A copy with `processedIntents` replaced.
    func with(processedIntents: [UUID]) -> EngineState {
        EngineState(
            pet: pet,
            state: state,
            days: days,
            settings: settings,
            pendingHandshake: pendingHandshake,
            processedIntents: processedIntents,
            highestCelebratedStage: highestCelebratedStage,
            lastOpenedAt: lastOpenedAt,
            lastEvaluatedAt: lastEvaluatedAt
        )
    }

    /// A copy with the evaluation ledger stamps replaced.
    func with(stamps lastOpenedAt: Instant?, lastEvaluatedAt: Instant) -> EngineState {
        EngineState(
            pet: pet,
            state: state,
            days: days,
            settings: settings,
            pendingHandshake: pendingHandshake,
            processedIntents: processedIntents,
            highestCelebratedStage: highestCelebratedStage,
            lastOpenedAt: lastOpenedAt ?? self.lastOpenedAt,
            lastEvaluatedAt: lastEvaluatedAt
        )
    }

    /// A copy with `highestCelebratedStage` replaced — the §4.6 once-guard
    /// advance (`BondLedger.reconcileStage`, TASK-017: it advances only WITH
    /// the `bondStageReached` emission, so each crossing emits exactly once).
    func with(highestCelebratedStage: BondStage) -> EngineState {
        EngineState(
            pet: pet,
            state: state,
            days: days,
            settings: settings,
            pendingHandshake: pendingHandshake,
            processedIntents: processedIntents,
            highestCelebratedStage: highestCelebratedStage,
            lastOpenedAt: lastOpenedAt,
            lastEvaluatedAt: lastEvaluatedAt
        )
    }
}
