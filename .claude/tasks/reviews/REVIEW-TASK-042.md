# REVIEW-TASK-042 — Watch pat + journal drain (independent adversarial review)

Reviewer: fresh Jupiter review agent (independent of the implementation agent)
Date: 2026-09-12
Branch: `feature/EPIC-008-watch-sync` (implementation uncommitted on base `692b5d2`)
Verdict: **APPROVED_WITH_MINOR_NOTES**

## Status

APPROVED_WITH_MINOR_NOTES — 1 Minor finding (F-R1, degradation-window product gap,
not a contract violation; follow-up recommended), 4 Notes. All gates green, all
three reviewer mutation probes bit exactly their pinning tests, tree restored and
verified byte-identical.

## Method (per CLAUDE.md §33 — independent disproof)

Spec was re-derived from the normative sources BEFORE any implementation source was
opened, in the mandated order: CLAUDE.md, `.claude/tasks/status.md`, the TASK-042
task file (the binding contract), ADR-015 (D1/D2/D3) + ADR-014 (F-2 fold), then
`docs/architecture/05-technical-architecture.md` §6.4/§6.6,
`docs/design/03-ux-architecture.md` §6.2–6.4, `docs/design/04-character-system.md`
§6.4, `docs/product/02-mvp-prd.md` FR-17/FR-18. Every changed/new file was then read
against the derived spec (full `git diff` vs `692b5d2` + full reads of all 8 new
files and 6 modified files).

## Spec Derivation (recorded before reading implementation)

1. Epoch identity persisted per install/session; generation wipes any journal
   present (TASK-040 F-3 self-defense carries into the store).
2. Journal legs: append (durability-gated), prune epoch-matched ≤ watermark,
   consumeWipe in F-3 order (snapshot pair → journal → consumed marker), plus
   `IntentJournal.wipe()` idempotent.
3. Pat capture: reaction + haptic decision BEFORE durable work; seq =
   `max(epochScopedJournalMax, epochMatchedWatermark) + 1` with the watermark term
   inert on epoch mismatch; event is `.watch` / `.pat(.tap, nil)` with its own
   dayKey; send only if the append landed.
4. Transport: `transferUserInfo` (reliable FIFO, duplicates possible ⇒ iPhone-side
   idempotency), fire-and-forget, no activation dependency.
5. ADR-015: D1 reaction binding via the existing sampler seam (zero MomoCharacter
   edits, no heart art); D2 completion haptic by local estimation — strict
   `progress + pending + 1 == target`, double REPLACES tick, estimate decides the
   haptic only; D3 haptic types VERIFY-AT-BUILD with recorded citations.
6. F-1: nil-character DEBUG-loud log once per snapshotSeq; F-2: nil-character
   wording = HELD slot (doc reconciliation landed in ADR-014).
7. R9: settling-in exposes NO pat targets; glance composite a11y with the pill as
   its own element; zero catalog changes.
8. Constraints: `Apps/Momo/**` diff EMPTY; pbxproj registration-only with D-R3
   (`dependencies = ()` on app targets); no entitlements; no TODO debt.

## Adversarial targets — disproof attempts that FAILED (implementation survives)

1. **appendPat mailbox ordering (racing receive)** — neither seq reuse nor pruning
   of the fresh event is reachable. The watermark pair is read on the main actor
   immediately before submission (no suspension between), the append runs as a
   mailbox job on the persister actor, and the iPhone's watermark can only count
   journaled-and-sent events, so an epoch-matched watermark is always ≤ the journal
   max at any interleaving. Both orderings (receive-before-submission,
   receive-after) verified against the FIFO argument in
   `Apps/MomoWatch/MomoWatchPersister+Journal.swift:53-87`.
2. **nextWatchSeq full-prune / stale-epoch / mixed-epoch** — formula semantics
   correct in all three cases; pinned by named tests (and probe P2 below).
3. **consumeWipe F-3 order + idempotent replay** — store wipe → journal wipe →
   marker record with no suspension between journal wipe and record
   (`Apps/MomoWatch/MomoWatchAppModel.swift:46-52`, `:303-311`); replay decisions
   are marker-driven and safe.
4. **epoch-mint init racing the first pat** — the epoch is set synchronously in
   init (`:216-227`); only save+wipe are deferred, both epoch-scoped-safe (stale
   entries are invisible to `journalMaxSeq`/`pendingPatCount`/prune), and a crash
   before the save lands repeats generation+wipe on the next launch.
5. **O1 one-writer census** — every `IntentJournal(` touch (read and write) is
   confined to `MomoWatchPersister+Journal.swift`; scan guard + standing test +
   manual grep all agree.
6. **F-1 once-per-snapshot memo** — `:147, :270-271` (`@ObservationIgnored`
   memo keyed on snapshotSeq).
7. **Haptic gate placement** — gate read at pat time, play inside the gate and
   before the append (`MomoWatchPat.swift:127-135` vs `:142`); scan-pinned.
8. **settling-in exposes no pat targets; glyph/AOD binds no sampler** — the only
   two pat targets are the live glance's canvas tap (`GlanceView.swift:136`) and
   pill button (`:157`); the glyph tier rig carries no `reactionMotion`.
9. **send-only-if-journaled** — `guard let event = … appendPat(…) else return`
   before the single send leg (`MomoWatchPat.swift:142-156`); exactly one
   `transport.sendUserInfo(` in the target (scan-pinned).
10. **Frozen surfaces** — `git status` vs `692b5d2`: zero entries under `Apps/Momo/`;
    `Sources/MomoCore/`, `Sources/MomoCharacter/` untouched; pbxproj is exactly 8
    added registration lines with D-R3 verified (`dependencies = ()` on both app
    targets); no entitlements/capability/catalog changes; no TODO/FIXME debt in the
    new files.

## Findings

| ID | Severity | Finding | Evidence |
|----|----------|---------|----------|
| F-R1 | **Minor** | **Journaled-but-never-sent drain gap.** A crash in the window after `journal.append` lands but before `transferUserInfo` enqueues strands that pat: pats send only their own NEW event and there is no launch-time journal sweep, so the intent never applies on the iPhone, and its ghost line inflates `pendingPatCount` until the next successful pat's apply prunes it (ghost at the completing position turns that pat's celebration into a tick — false negative; strict `==` keeps false positives impossible from this). Distinct from the disclosed "lost journal line" degradation (append FAILURE) and from disclosed delta 4 (concurrent-estimate race). Contract letter not violated — R2/R3 name exactly three journal legs and no sweep leg was required; window is crash-narrow; consequences are one lost pat + presentation-only haptic. Recommend a follow-up task (launch-time sweep draining epoch-matched un-sent journaled pats once the transport activates). | `Apps/MomoWatch/MomoWatchPat.swift:142-156`; `Apps/MomoWatch/MomoWatchAppModel.swift:201-205` (launch read = snapshot + marker only) |
| F-R2 | Note | Launch-read comments still say "the snapshot + the consumed marker"; the launch read now also loads `WatchSessionEpochStore`. Cosmetic doc drift — fold into the fix loop or closeout. | `Apps/MomoWatch/MomoWatchAppModel.swift:64-65, :201-202` vs `:216` |
| F-R3 | Note | Transport doc claims "a send while the session is not yet activated is WC's to queue" without a header citation, in a file that otherwise cites WCSession.h:326. Behavior is standard WC (`transferUserInfo` queues while inactive) — no action needed; noted for citation discipline. | `Apps/MomoWatch/MomoWatchTransport.swift:43-44` vs `:102-103` |
| F-R4 | Note | `reactionKind`'s `.waking → .bounce` / `.settling → .stir` extend 04 §6.4's two named states with documented judgment calls; pinned by test (probe P3 proved the pin). Accepted. | `Sources/MomoKit/WatchPatPlan.swift:126-138` |
| F-R5 | Note | Two hair-trigger pats can both read the same pre-append pending count (read and append are separate mailbox jobs with the haptic between) → duplicate celebration, exactly as disclosed (benign, presentation-only). An inverse micro-window (second estimate reads after the first haptic but before the first append) yields tick-instead-of-double from the same mechanism — same severity, same acceptance. Disclosure accurate in substance. | `Apps/MomoWatch/MomoWatchPat.swift:121-142` |

## Gates (run personally)

| Gate | Result |
|------|--------|
| `swift test` | **PASS — 1102 tests in 108 suites passed** (matches handoff claim digit-for-digit) |
| `xcodebuild -scheme MomoWatch -destination 'id=8A854895-225C-411B-89C1-B03337BFE957' build` | **BUILD SUCCEEDED**, zero warnings from touched files |
| `xcodebuild -scheme Momo -destination 'id=1F25E487-A78E-464C-95AF-0BD1A9B3E1BE' build` | **BUILD SUCCEEDED**, zero warnings from touched files |
| `xcodebuild -scheme MomoWatch -destination 'id=8A854895…' -only-testing:MomoWatchUITests test` | **TEST SUCCEEDED — 5/5** (canvas-tap, pill-tap, fixture W1, fresh-launch settling-in, snapshot-restore budget) |

## Reviewer mutation probes (own design, distinct from the implementer's bites)

Target file: `Sources/MomoKit/WatchPatPlan.swift`
sha256 before P1 / after each restore:
`6a0c1aa32f6e5ea17e9de1a30252b5c46adfcde03c160328d5434b483293cd39` (identical every
time). Suite run per probe: `swift test --filter WatchPatPlanTests` (16 tests).

| Probe | Mutation | Tests that went red | Restore |
|-------|----------|--------------------|---------|
| P1 | Removed the `.wish(.q7)` quest-line guard from `isCompletingPat` | `ESTIMATE: a non-Q7 quest line estimates false (Q6 wish, all-done)` — 2 issues (both `.wish(.q6)` and `.allDone` flipped to true); 15/16 otherwise green | Byte-identical (sha256 verified) |
| P2 | Dropped the epoch filter in `journalMaxSeq` (foreign epochs counted) | `a MIXED-EPOCH journal never inflates this epoch's derivation` — 2 issues (`journalMaxSeq → 99` vs 2; `next → 100` vs 3); 15/16 otherwise green | Byte-identical (sha256 verified) |
| P3 | Split the switch so `.waking` returns `.stir` | `reaction kinds: awake/waking bounce, settling/asleep stir` — 1 issue (`.waking → .stir ≠ .bounce`); the other three map cases stayed green | Byte-identical (sha256 verified) |

No probe failed nothing — each bit exactly the test(s) that pin the mutated
invariant, and nothing else. The estimator's D2 gate, the seq formula's epoch
scoping, and the four-case reaction map are each genuinely load-bearing and
precisely pinned.

## Tree integrity

Final sweep: sha256 over all 18 touched files (10 modified + 8 new, incl. ADR-014
and the task file) — every hash identical to the pre-probe baseline captured before
probing began. `git status` shows exactly the implementation's file set and nothing
else. The only reviewer-authored changes are this file and the one-line verdict
under `## Reviewer Findings` in `.claude/tasks/active/TASK-042-watch-pat.md`.

## Verdict

**APPROVED_WITH_MINOR_NOTES.** The implementation matches the contract and the
normative sources; every disclosed deviation checks out; the adversarial targets do
not break it. F-R1 is accepted as-is for this task (contract-conformant), with a
recommended follow-up task for the launch-time journal sweep; F-R2 may be folded
into the fix loop as a comment-only touch if convenient, otherwise closeout.
