import Foundation

// MARK: - QuestGeneration — daily set generation + Watch quest cascade
// (05-technical-architecture §4.8; PRD §5.1–5.5, FR-14–16; TASK-018
// Requirements 1–4, 7–8)

/// The §4.8 quest home: the by-construction daily set generator, the current
/// generator epoch, and the Watch quest cascade — one cohesive §4.8 surface
/// (contract Req 8). Pure: every function is a value-in/value-out derivation
/// over injected values — no clocks, no calendars of its own, no ambient
/// state, no system randomness; the generator seeds its OWN per-call
/// `SeededGenerator` from the given seed (never the choreography rng passed
/// through `reduce` — contract Constraints; the fold's draw lineage is
/// untouched). Numbers flow exclusively from `Thresholds.Quest` and
/// `QuestCatalog`; raw literals live only in the pin tests.
///
/// **Authorities.** PRD §5.3 is normative for the variation constraints
/// (exactly-3 sets with the Q1 anchor; Q6 in every rolling 3-day window; no
/// consecutive-repeat of the non-anchor pair); 05 §4.8 for the generation
/// signature, the by-construction filtering, the window-check rule, and the
/// cascade; PRD §5.5 (as amended 2026-09-08, OPEN-1) for the cascade's six
/// rules; FR-14–16 for the ACs.
///
/// **Recorded readings (for review):**
///
/// 1. **Epoch-interface fidelity (contract Req 3).** `generate` accepts
///    `questGenEpoch` per §4.8's signature but does not mix it into the RNG
///    seed: the epoch's determinism role flows entirely through the CALLER,
///    which derives the seed from `DaySeed.make(…, epoch:, salt: .quest)`
///    (§4.10's salt separation — an epoch change resalts the domain without
///    touching the other domains). Re-mixing it inside `generate` would hash
///    the epoch twice into the same derivation for no additional guarantee;
///    the parameter stays so the signature stays the spec's and so a future
///    in-generator epoch use is a local change. `dayKey` is likewise
///    interface-only: determinism flows through the seed, and the parameter
///    keeps the function's mirror of the stored record auditable.
/// 2. **Rules 3–4 scan in-set only (contract Req 7).** The PRD's rules 3–4
///    omit an in-set qualifier; §5.5's opening ("one quest, chosen from
///    relevance"), rule 5's explicit in-set gating, and the argument that an
///    out-of-set quest can never progress (ticks scope to the day's set)
///    jointly justify scoping: surfacing an out-of-set quest would promise
///    an uncompletable wish.
/// 3. **The draw reads "two quests, by construction" (see `generate`).** The
///    candidate space is the filtered PAIRS, and the two draws pick the
///    pair's two members: first pick from the pool's quest universe, second
///    pick from that quest's in-pool partners. Every constraint holds by
///    construction (the drawn pair is always a pool member); the induced
///    pair weights are uniform in the two star-shaped scenarios (the
///    unrestricted 15-pair space and the Q6-restricted 5-star — verified
///    arithmetically, REVIEW-TASK-018 NITPICK-1), while ban-active non-star
///    pools skew, which no normative text forbids (§5.3/§4.8 require
///    determinism + by-construction constraints, both held).
public enum QuestGeneration {

    /// The current quest generator epoch (05 §4.8's generator version;
    /// engine-owned). `0` is the pre-generation placeholder marker (the
    /// TASK-015 rollover seam's era); rollover stamps newly generated
    /// records with this value. Changing it resalts every day's quest seed
    /// (via the caller's `DaySeed` derivation) and reshuffles every set.
    public static let currentEpoch: Int = 1

    // MARK: The candidate space (PRD §5.3; 05 §4.8)

    /// The non-anchor catalog ids in catalog order (Q2…Q7). Q1 is the
    /// mandatory anchor of every set (FR-14 AC-3) and is never drawn.
    private static var nonAnchorQuests: [QuestID] {
        QuestCatalog.all.map(\.id).filter { $0 != .q1 }
    }

    /// The full candidate space: the 15 unordered pairs of the non-anchor
    /// quests, each pair's members in catalog order, pairs in enumeration
    /// order — a stable, order-documented universe for the constraint
    /// filters and the draw.
    static func allCandidatePairs() -> [[QuestID]] {
        let quests = nonAnchorQuests
        var pairs: [[QuestID]] = []
        for i in 0..<quests.count {
            for j in (i + 1)..<quests.count {
                pairs.append([quests[i], quests[j]])
            }
        }
        return pairs
    }

    /// Whether the two quest groups name the same unordered pair (the
    /// consecutive-repeat ban compares SETS, not orders — PRD §5.3 "the same
    /// pair of non-anchor quests MUST NOT repeat").
    private static func isSamePair(_ a: [QuestID], _ b: [QuestID]) -> Bool {
        Set(a) == Set(b)
    }

    /// The by-construction candidate pool (05 §4.8): the full pair space
    /// minus yesterday's pair (consecutive-repeat ban), then — if the prior
    /// sets together lack Q6 — restricted to the pairs containing Q6.
    /// `priorTwoSets` holds the non-anchor quests of the two most recent
    /// records, NEWEST FIRST; a missing tail (fresh install, first day) is
    /// unknown prior and counts as "no Q6 credit" (day 1 always includes
    /// Q6 — 05 §4.8). Filters run BEFORE drawing, so no drawn set is ever
    /// rejected and the draw never retries.
    ///
    /// The pool is never empty: the ban removes at most one pair, and when
    /// the Q6 restriction is active the pool keeps at least 4 pairs. The
    /// contract's tightest case IS reachable — yesterday's pair contains Q6
    /// while the OLDER prior lacks it (Q6 credit needs BOTH priors), so the
    /// ban first removes that Q6 pair and the restriction keeps the
    /// remaining 5 − 1 = 4; every other no-credit case keeps all 5.
    static func candidatePool(priorTwoSets: [[QuestProgress]]) -> [[QuestID]] {
        var pool = allCandidatePairs()
        // (a) Consecutive-repeat ban: yesterday's pair (the newest prior's
        // non-anchor quests, when they form a well-formed pair) is removed.
        if let yesterday = priorTwoSets.first, yesterday.count == Thresholds.Quest.questsPerDay - 1 {
            let yesterdayIDs = yesterday.map(\.questID)
            pool = pool.filter { !isSamePair($0, yesterdayIDs) }
        }
        // (b) Q6 3-day window: any missing or Q6-lacking prior counts as no
        // Q6 credit — the restriction fires unless BOTH known priors carry
        // Q6 (fresh-install day 1 has no priors at all → Q6 forced).
        let q6Credit = priorTwoSets.allSatisfy { prior in
            prior.contains { $0.questID == .q6 }
        } && priorTwoSets.count == 2
        if !q6Credit {
            pool = pool.filter { $0.contains(.q6) }
        }
        return pool
    }

    // MARK: The generator (05 §4.8's signature)

    /// Generates one local day's quest set: `[Q1, pairA, pairB]` — the
    /// mandatory anchor plus the drawn pair (members in catalog order), all
    /// zero progress, not completed, INV-6-satisfying. Deterministic given
    /// the inputs (FR-15 AC-1): identical arguments yield identical sets.
    ///
    /// **The draw (recorded reading 3).** Exactly two draws of a per-call
    /// `SeededGenerator(seed: seed)` produce the pair:
    ///
    /// 1. first pick — one quest from the pool's quest universe (the
    ///    distinct quests appearing in the surviving pairs, catalog order);
    /// 2. second pick — that quest's partner, from the REMAINDER: the
    ///    in-pool partners of the first pick (catalog order). A pool pair
    ///    containing both picks is the drawn pair itself, so every
    ///    constraint holds by construction — nothing is drawn that a filter
    ///    would reject.
    ///
    /// The pair weights are uniform in the two star-shaped scenarios — the
    /// unrestricted pool and the Q6-restricted 5-star (every surviving pair
    /// is {X, Q6}); ban-active non-star pools skew by the two-stage draw's
    /// shape, which no normative text forbids (REVIEW-TASK-018 NITPICK-1).
    /// Exactly two draws are consumed — pinned by the generation tests, so
    /// the seed→set mapping is stable.
    public static func generate(
        dayKey: String,
        seed: UInt64,
        priorTwoSets: [[QuestProgress]],
        questGenEpoch: Int
    ) -> [QuestProgress] {
        // dayKey and questGenEpoch are interface-only (recorded reading 1):
        // determinism flows through `seed`, which the caller derives FROM
        // the epoch and the dayKey via `DaySeed.make`.
        let pool = candidatePool(priorTwoSets: priorTwoSets)
        let universe = nonAnchorQuests.filter { quest in
            pool.contains { $0.contains(quest) }
        }
        var rng = SeededGenerator(seed: seed)
        let first = universe[Int(rng.next() % UInt64(universe.count))]
        let partners = nonAnchorQuests.filter { partner in
            partner != first && pool.contains { $0.contains(first) && $0.contains(partner) }
        }
        let second = partners[Int(rng.next() % UInt64(partners.count))]
        let catalogOrder = nonAnchorQuests
        let pair = [first, second].sorted { catalogOrder.firstIndex(of: $0)! < catalogOrder.firstIndex(of: $1)! }
        // Unreachable: Q1 is always valid at zero progress and the drawn
        // pair's targets are the catalog's (INV-6 by construction).
        return [.q1, pair[0], pair[1]].compactMap { QuestProgress(questID: $0, progress: 0, completed: false) }
    }

    // MARK: The Watch cascade (§5.5, amended rule 1; 05 §4.8)

    /// The cascade's answer: the one quest to surface, or the all-done
    /// state. An enum rather than a nullable `QuestID` — a nil would lose
    /// the all-done state from "wish pending" (contract Req 7; 05 §4.11's
    /// `DisplayState.questLine`). Rendering (copy keys, widgets) is
    /// TASK-036/EPIC-007/008's; Phase 2 widgets reuse this function (§8).
    public enum QuestLine: Equatable, Sendable {

        /// Surface this quest as the Watch's one wish.
        case wish(QuestID)

        /// Every quest in today's set is complete — "All done — see you
        /// soon" (the copy is presentation's; this is the state).
        case allDone
    }

    /// The §5.5 Watch quest cascade — six rules IN ORDER, first match wins
    /// (amended rule 1, owner-approved 2026-09-08):
    ///
    /// 1. Q6, if in today's set ∧ incomplete ∧ the hour is inside Q6's
    ///    window (≥ 20:00 ∨ < 07:00);
    /// 2. else Q1, if the hour is before its window close ∧ incomplete
    ///    (Q1 is the anchor — the in-set check is defensive, recorded with
    ///    rules 3–4's scoping);
    /// 3. else the first incomplete FEED-family quest in catalog order,
    ///    scoped to today's set (recorded reading 2);
    /// 4. else the first incomplete PLAY-family quest in catalog order,
    ///    scoped to today's set;
    /// 5. else Q7, if in today's set ∧ incomplete;
    /// 6. else the all-done state.
    ///
    /// Pure; the hour is the caller's local hour (0–23) — the Watch passes
    /// its own; read-models derive it from the injected calendar.
    public static func cascade(questSet: [QuestProgress], localHour: Int) -> QuestLine {
        func inSet(_ id: QuestID) -> Bool {
            questSet.contains { $0.questID == id }
        }
        func incomplete(_ id: QuestID) -> Bool {
            questSet.first { $0.questID == id }.map { !$0.completed } ?? false
        }
        // Rule 1 — the owner-amended Q6 rule (OPEN-1): the window's
        // early-morning tail now surfaces Q6 (a 02:00 tuck-in with Q1 done
        // selects Q6 — the named test).
        if inSet(.q6), incomplete(.q6), QuestCatalog.entry(for: .q6).window.contains(hour: localHour) {
            return .wish(.q6)
        }
        // Rule 2 — the morning anchor.
        if localHour < Thresholds.Quest.q1WindowClosesAtHour, inSet(.q1), incomplete(.q1) {
            return .wish(.q1)
        }
        // Rules 3–4 — first incomplete of the family, in catalog order,
        // IN-SET only (recorded reading 2: an out-of-set quest can never
        // progress, so surfacing it would promise an uncompletable wish).
        for family in [QuestFamily.feed, .play] {
            if let id = QuestCatalog.all.first(where: {
                $0.family == family && inSet($0.id) && incomplete($0.id)
            })?.id {
                return .wish(id)
            }
        }
        // Rule 5 — the pet-family quest, in-set gated (the PRD's own
        // qualifier).
        if inSet(.q7), incomplete(.q7) {
            return .wish(.q7)
        }
        // Rule 6 — all done.
        return .allDone
    }
}
