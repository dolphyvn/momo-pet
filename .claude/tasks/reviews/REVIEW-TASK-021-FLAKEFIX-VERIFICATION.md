# REVIEW-TASK-021-FLAKEFIX-VERIFICATION — Independent delta verification of the post-review concurrency-flake fix

- **Date:** 2026-09-09
- **Reviewer:** fresh adversarial delta-verification agent (CLAUDE.md §10/§33), spawned by the orchestrator solely to try to DISPROVE that the corrected test still proves TASK-021 Requirement 4.
- **Repo:** /opt/works/personal/github/momo-pet, branch `feature/EPIC-005-persistence`, HEAD `d4c8156c64ef13e01149c1063378ed18280ad547`.
- **Delta under review:** the post-disposition rewrite of `Tests/MomoKitTests/SnapshotStoreConcurrencyTests.swift` + the `### Post-review flake fix (orchestrator-dispositioned)` subsection of `.claude/tasks/active/TASK-021-snapshot-store.md`. The original REVIEW-TASK-021 (APPROVED_WITH_MINOR_NOTES) stands; this record does not re-audit its surface except where the delta touches it.

## Verdict

**CHANGES_REQUIRED** — one MAJOR finding (convergence clause of Requirement 4 unpinned; task-file evidence overstates what the pins prove). The de-flaking itself SUCCEEDED: the rewrite is sound (order-independent pins cannot flake on scheduler order) and stable (my own 16/16 focused + 3/3 full green runs). The gap is proof sufficiency, not soundness. The prescribed repair is a small, surgical test change — no production code is implicated (both pristine hashes verified byte-identical).

## 0. Independence statement

This reviewer had no prior context on TASK-021; all facts below were re-derived from the repository, the toolchain, and my own test runs. The fixer's claims (task-file subsection) were treated as claims and checked, not trusted. The original reviewer's records were used as baseline descriptions only (hashes, diff shape, pre-rewrite pin list). No agent message was treated as authorization beyond the orchestrator's written scope, which sanctioned exactly one optional mutation class (a swap of two rename/demotion steps inside the save path) with mandatory byte-identical restore.

## 1. State reconciliation (scope item 1)

- HEAD `d4c8156…` on `feature/EPIC-005-persistence` — matches the brief.
- `shasum -a 256`:
  - `StoreRules.swift` = `2b0913c48b65e56adc27e337990d2c5651d336a687b9ccb3a510ac22955a5c6a` — equals the original reviewer's pristine record.
  - `SnapshotStore.swift` = `ddd7e38a6e32d644c17991f77e6eb411b1bff7a9e0996f8ce65ef84fbabcb159` — equals the pristine record. (Re-verified again after my sanctioned mutation + restore; see §5.)
- `git diff --stat HEAD -- Sources/ Package.swift Tests/` = **11 files changed, +93/−45** — exactly the audited shape (Package.swift, 8 MomoCore files, 2 placeholder deletions). The concurrency test file is untracked (new file, never committed) — accounted for separately below.
- `git status --porcelain`: only expected paths — the TASK-021 deliverables (2 new sources, 4 new test files, `Support/`), the task file + status.md (orchestration state), and `REVIEW-TASK-021.md`. No unexpected paths.
- **Post-review change surface:** file mtimes place `SnapshotStoreConcurrencyTests.swift` at 11:28:08, AFTER the review record (11:07:01); every other test and production file (10:00–10:58) predates it. Combined with the pristine hashes: the fixer's "only the concurrency test file changed — zero production-source changes" is CONFIRMED.

## 2. Task-file confinement (scope item 2)

`git diff -U0` on the task file: first hunk `@@ -84 +84 @@` — the Status body line only (`IN_PROGRESS` → `REVIEWED…`); the `## Status` header sits at line 83 and Git Requirements at lines 78–81 — the contract sections (lines 1–83) are byte-untouched. All remaining hunks are additive at lines ≥ 87 (Implementation Notes content, including the flake-fix subsection at lines 146–156). CONFIRMED: fixer additions confined to Status-and-below.

## 3. Root cause (scope item 3)

CONFIRMED, on three legs:

1. **`TickingClock` mechanics** (`Tests/MomoKitTests/Support/StoreFixture.swift:9-28`): `final class` (reference semantics — the store's private copy concern is real and handled), `NSLock`-guarded, **returns current then advances by `step` (default 1 s)**. Each `save` reads the clock exactly once (`SnapshotStore.swift:146`, the only reader in the store) inside the actor-isolated body. Therefore the n saves of a test receive exactly the deterministic tick set {base+0s, …, base+(n−1)s}, assigned to bonds in the actor's execution order σ. This grounding claim in the fixer's subsection is accurate.
2. **No FIFO guarantee — reasoned first-principles analysis (labeled as such), consistent with the documented guarantee set:** Swift actors document and implement mutual exclusion — at most one job executes against the actor's isolated state at a time (SE-0306; The Swift Programming Language, Concurrency) — and guarantee nothing about service ORDER. The default executor's queue is priority-aware with priority escalation (SE-0338-era runtime), so enqueue order does not determine dequeue order; independently, task-group children reach their first suspension point (`await store.save`) in an unspecified order because the cooperative pool starts child tasks nondeterministically. σ is therefore an arbitrary permutation of the issued saves. I did not fabricate citations for a "no FIFO" sentence — the load-bearing evidence is empirical: **the original flake itself** (σ observed ending (…, 23, 24, 22) against issue order 1…24) is direct proof of non-FIFO execution on this very toolchain.
3. **Store behavior is order-correct:** save bodies are actor-isolated (one at a time), each save's demotion sequence is fixed and self-contained, and `load` is `nonisolated` but gated per-generation (checksum + schema). For EVERY σ, after n completed saves the slots hold σ(n), σ(n−1), σ(n−2) with strictly increasing ticks in chain order. The old pins (`current == bond 24`, chain `== {24, 23, 22}`, test-2 `== bond 16`) all assumed σ == issue order — the TEST was unsound, the STORE was not. The fixer's root cause stands.

## 4. Invariant sufficiency + teeth (scope item 4 — the core question)

The rewritten pins, verified against the test source: (a) `load(fallback:)` == current envelope's payload (line 52); (b) three chain bonds pairwise-distinct members of the saved set (55–57); (c) `savedAt` strictly descending down the chain (64); test-2 in-race membership (99) and post-completion membership ∈ 1…16 (112). Soundness: all σ-independent — the rewrite cannot flake on scheduler order. Requirement 4 reads: "concurrent saves converge to a consistent chain **where the newest completed save is current**."

Adversarial thought experiments, answered:

- **(i) Non-serialized saves interleaving rename steps:** partially caught. Interleavings that misorder ticks into slots break pin (c); those that lose/duplicate slot contents break pin (b); shared-temp clobbers surface at pin (a) (load falls through a gate-invalid "current"). A temporally-disjoint non-serialized store is behaviorally serialized and passes — correctly, since Requirement 4's observable behavior then holds. Probabilistic detection is inherent to bounded black-box concurrency tests; this matches the original review's own assessment.
- **(ii) Wrong demotion order:** split verdict, and this is where the MAJOR lives. Slot-ORDER errors are caught — demonstrated empirically (§5). But **chain-≠-last-three-completed via generation LOSS is not caught at all**: a store that silently no-ops saves after the third (or drops any interior subset while keeping its last-written three consistent) passes every pin in both tests — slots populated, `load` == current payload, bonds distinct and in-range, ticks descending *within* whatever three it kept, test-2 membership satisfied. The production save path even contains the shape of such a bug today (the silent early-return at `SnapshotStore.swift:148-154`). The old pins — unsound as written — were the only detectors of this class, and the rewrite replaced them with nothing.
- **(iii) Nothing sound was dropped:** CONFIRMED. All three dropped pins assume σ-positions (the flake disproved that assumption). Retained pins (descending savedAt, in-race membership, load == current envelope) are the sound cores. However, the *sound form* of the dropped class — pinning absolute tick positions — was available and not taken. See MAJOR-1.
- **(iv) Lose / duplicate / fabricate:** duplicates — caught (distinctness, line 57). Out-of-set fabrication — caught (range, line 56; a gate-invalid fabricated current is additionally caught at line 52 through the store's own checksum gates). **Loss — passes** (the counterexample above). An in-set phantom save (re-saving a real bond with a fresh tick) also passes the current pins.

**MAJOR-1 (the disproof I was sent to find):** the rewritten test does not prove Requirement 4's convergence clause. The fixer's own task-file claim — "(b) the chain's three bonds are pairwise-distinct members of the saved set 1...24 — no lost, duplicated, or fabricated generation" — overstates the pins: distinctness+range prove no-duplicate and no-out-of-set-fabricate, but **not no-lost**, and "lost" is exactly the case a convergence pin exists for. Under §25 (no fake completion) the stated guarantee exceeds the delivered proof.

**Prescribed repair (small, sound, strictly stronger — no production change):** pin savedAt **adjacency** instead of (or in addition to) descending order. Because `TickingClock` ticks deterministically and is read exactly once per save, the tick schedule is fully σ-independent:

- Test 1 (24 saves; hold the clock in a local `let`): `current.savedAt == base + 23 s`, `previous.savedAt == base + 22 s`, `oldest.savedAt == base + 21 s` (TickingClock returns-then-advances ⇒ k-th read = base+(k−1)s; the chain's three slots must hold the 22nd/23rd/24th reads). This subsumes descending (64) and adds: newest completed save is current, chain = last three completed, no interior skip, exactly 24 saves processed.
- Test 2 (8 × 16 = 128 saves): post-completion, read the current envelope (the `readEnvelope` helper already exists) and pin `savedAt == base + 127 s`, keeping the membership pin as a coarser companion.
- Document in a test comment the load-bearing assumption (one clock read per save, at `SnapshotStore.swift:146`, and nothing else reads the clock) so a future second read inside `save` forces the fixture to expose tick counts instead of offsets.

Soundness check of the prescription: on the correct store the pins hold for every σ (they depend only on save COUNT, not order); they remain deterministic (no new flake surface).

## 5. Sanctioned mutation — teeth proof (scope item 5)

PERFORMED, one mutation, in the sanctioned class (swap of two rename/demotion steps inside the save path):

- **Before:** `SnapshotStore.swift` sha256 `ddd7e38a…` (pristine backup copied to `/tmp/t21v-pristine-SnapshotStore.swift`, same hash).
- **Mutation A:** the step-1 block (`prev → prev2`, lines 162–167) and step-2 block (`current → prev`, lines 168–171) swapped, bodies unchanged.
- **Result:** `swift test --filter SnapshotStoreConcurrencyTests` → **FAILED**, exactly as predicted: `Test "concurrent saves converge to a consistent chain…" recorded an issue at SnapshotStoreConcurrencyTests.swift:48:28` — the `state.prev.json` slot `#require` → nil (the swapped sequence leaves the prev slot permanently empty; simulation and observation agree). Log: `/tmp/t21v-mutationA.log`. Test 2 passed under the mutation, as expected (it pins membership, and the mutated store still serves a valid current).
- **Restore:** `cp` from the pristine backup → `cmp` byte-identical → `shasum -a 256` = `ddd7e38a…` == pristine. Post-restore focused run green; `StoreRules.swift` re-hashed `2b0913c4…` == pristine. No residue.

Teeth verdict: the rewritten test demonstrably bites on a real demotion-order bug. Note the bite landed on the slot `#require` (line 48), not the savedAt pin (line 64) — my enumeration of all legal two-block permutations of the three renames shows every one leaves a chain slot empty or aborts saves, so the slot pins are the primary teeth for reorderings; the savedAt pin's incremental teeth apply to populated-chain slot-order violations (the review record's original claim, which remains true). Under the CURRENT pins no enumerated bug class passes silently — except precisely the loss/freeze class of MAJOR-1, which is not a demotion-order mutation and was therefore not mutated (outside the sanctioned class); it is established analytically in §4 and is airtight.

## 6. Independent stability protocol (scope item 6 — my own runs)

- `swift test --filter SnapshotStoreConcurrencyTests`: **16 consecutive green runs** (`/tmp/t21v-focused-1..16.log`; any failure would have reset the count; achieved 16/16). Gate ≥ 15 — PASSED.
- `swift test` (full): **3 consecutive green runs**, each `Test run with 417 tests in 46 suites passed` (`/tmp/t21v-full-1..3.log`). Gate ≥ 2 — PASSED.
- Post-restore confirmation focused run: green (`/tmp/t21v-postrestore.log`).
- The suite's de-flaking goal is confirmed achieved by my own runs: the rewritten pins are deterministic under every σ.

## 7. Fixer evidence sanity check (scope item 7)

- `/tmp/t21-stab-1..20.log` (20 files, 11:28–11:29): each ends `Test run with 2 tests in 1 suite passed` — consistent with the claimed 20-run focused protocol.
- `/tmp/t21-full-1..3.log`: each ends `Test run with 417 tests in 46 suites passed` — consistent with the claimed 3 full runs; suite counts preserved vs baseline.
- "Only the concurrency test file changed" — corroborated by mtimes + pristine hashes (§1).
- The root-cause narrative (observed chain {current 22, previous 24, oldest 23} ⇒ σ ending (…, 23, 24, 22)) is internally consistent.
- **One overstatement found** (folded into MAJOR-1): the "(b) … no lost … generation" claim, and by extension the subsection's framing that the new pins deliver "the last three completed saves of σ" (Grounding paragraph) — the Grounding text correctly describes what the STORE does; the pins do not fully pin it. No other inconsistencies.

## Findings ledger

- **MAJOR-1** — Requirement 4's convergence clause ("newest completed save is current" / chain = last three completed saves) is unpinned by the rewritten tests: a store that freezes after ≥ 3 saves or drops interior saves passes every pin in both tests. The task-file subsection's "no lost … generation" claim overstates the pins. Repair: savedAt adjacency pins (§4 prescription) — sound, deterministic, strictly stronger.
- **MINOR-1** — Test 2's post-completion comment justifies the membership pin with "a straggler saver can still be mid-loop when every other saver has finished"; at the pin's execution point (after the task group's join) no child is mid-loop. The correct rationale is that σ's final element is scheduler-chosen. The pin itself is correct and sound; only the comment's mechanism is wrong. Correct the comment while applying MAJOR-1's repair.
- **OBSERVATION-1** — Empirical teeth structure: demotion REORDERINGS are caught by the slot `#require`s (demonstrated, line 48); the savedAt pin covers populated-chain slot-order violations; the loss class is the sole silent gap (MAJOR-1).
- **OBSERVATION-2** — The fixer's stability evidence is genuine and internally consistent (§7); my own counts supersede and agree.
- **NITPICK** — The test-file comment "Unsynchronized saves could interleave their rename steps and break this monotonicity" is true only for a subset of interleavings (see §4-i); harmless as a comment.

## Recommendation to the orchestrator

1. Mark the flake fix CHANGES_REQUIRED per MAJOR-1; do not commit TASK-021 with the current pins.
2. Spawn a fresh fixer (small, bounded scope): apply the §4 savedAt-adjacency prescription to both tests, fix the MINOR-1 comment, and correct the task-file subsection's "no lost … generation" wording to match the delivered pins.
3. Re-verify with the same stability protocol (≥ 15 focused + ≥ 2 full) and a delta re-check of this record's scope items 1–2; the adjacency pins' own teeth can be spot-proven by the same sanctioned-mutation discipline (e.g., the freeze counterexample, if the orchestrator sanctions a second mutation class).
4. Production code is NOT implicated — pristine hashes verified before and after my mutation; no production change is requested.

---

# Round 2 — re-verification of the savedAt-adjacency repair (2026-09-09)

## Verdict

**APPROVED.** MAJOR-1 is closed: the convergence clause of Requirement 4 ("the newest completed save is current") is now pinned by exact savedAt adjacency, soundly and deterministically. MINOR-1 is closed. My round-1 counterexample now fails the suite — demonstrated empirically with a sanctioned mutation. No new findings above OBSERVATION grade.

## (a) The repaired test — verified against the prescription

`Tests/MomoKitTests/SnapshotStoreConcurrencyTests.swift` (rewritten 12:03:38, the only file changed this round besides the task file; production mtimes/hashes untouched):

- Test 1 (24 saves): the strict-descent pin is REPLACED by exact adjacency — `current.savedAt == base.addingTimeInterval(TimeInterval(total - 1))` (= base+23 s), `previous == base+22 s`, `oldest == base+21 s` (lines 69–71). Arithmetic verified against `TickingClock`'s returns-then-advances stride (k-th read = base+(k−1) s): 24 saves ⇒ 24 reads ⇒ the last three completed saves must sit on the 22nd/23rd/24th ticks. Exactly as prescribed; no pin loosened — load == current payload (53), distinctness + range (56–58), slot `#require`s (48–50) all retained; the removed descending pin is subsumed (23 > 22 > 21).
- Test 2 (8 × 16 = 128 saves): post-completion now reads the CURRENT ENVELOPE via the existing `readEnvelope` helper and pins `savedAt == base.addingTimeInterval(TimeInterval(savers * total - 1))` (= base+127 s, line 127) — correct placement (`EngineState` carries no `savedAt`), correct arithmetic — plus a sound bonus pin `final == finalCurrent.payload` (126; deterministic post-join). The bond-membership pin (124) and in-race membership pin (107) are kept.
- MINOR-1 FIXED: test 2's comment (113–122) no longer claims a straggler saver mid-loop; it now gives the correct rationale (the task group joins every saver; σ's final element is scheduler-chosen across the savers' interleavings), and pins the snapshot time on the envelope.
- The load-bearing assumption is documented in the test comment (59–68): single `clock.now()` per save at `SnapshotStore.swift:146`, loads consume no ticks, k completed saves leave the clock at tick base+(k−1), and both failure modes (silently skipped save; double-read clock) are named as detected.

## (b) Load-bearing single-read assumption — re-verified in current source

`grep 'now()' Sources/MomoKit/` → exactly ONE site, `SnapshotStore.swift:146` (the claim "the single `clock.now()` site in MomoKit" in the task-file amendment is accurate). `load`/`loadGeneration` never touch the clock; `readEnvelope` is file-read + decode only; `TickingClock` is the only `now()` in `StoreFixture.swift` and `fixture.state(bond:)` consumes no ticks (no `Date()`/`Date.now` anywhere in the fixture). Each test constructs its own `TickingClock` inline. Assumption holds.

## (c) Independent stability protocol (my own runs)

- `swift test --filter SnapshotStoreConcurrencyTests`: **16 consecutive green** (`/tmp/t21r2-focused-1..16.log`). Gate ≥ 15 — PASSED.
- `swift test` (full): **3 consecutive green**, each `417 tests in 46 suites passed` (`/tmp/t21r2-full-1..3.log`). Gate ≥ 2 — PASSED.
- Fixer's round-2 claims cross-checked: `/tmp/t21r2-stab-1..20.log` (20 files, green tails) and `/tmp/t21r2-full-1..3.log` (3 files, `417/46 passed`) exist and are consistent with the amendment's stated gates.

## (d) Sanctioned mutation — the round-1 counterexample, made executable

One mutation, in the sanctioned class ("make one save silently skip"), chosen as the direct MAJOR-1 counterexample: an early `return` at the top of `save` once the chain is full (`oldest` exists) — skipped saves consume no clock tick, so a store that freezes after 3 saves is exactly the silent-loss store of round 1.

- **Before:** sha256 `ddd7e38a…` (pristine backup `/tmp/t21r2-pristine-SnapshotStore.swift`).
- **Observed failure:** `swift test --filter SnapshotStoreConcurrencyTests` → FAILED with exactly the designed bites and no others:
  - Test 1, lines 69/70/71: `current.savedAt → 12:00:02` vs `12:00:23`, `previous → 12:00:01` vs `12:00:22`, `oldest → 12:00:00` vs `12:00:21` — the 3-tick arithmetic exposed verbatim in the failure output;
  - Test 2, line 127: `finalCurrent.savedAt → 12:00:02` vs `12:02:07` (base+127 s);
  - and CRUCIALLY the round-1-passing pins all still PASSED under the mutation (slot `#require`s, load == current payload, distinctness, membership) — adjacency is the sole detector of this class, exactly as prescribed. Log: `/tmp/t21r2-mutation.log`.
- **Restore:** `cp` from pristine backup → `cmp` byte-identical → `sha256` `2b0913c4…` (StoreRules) / `ddd7e38a…` (SnapshotStore) == pristine; post-restore focused run green (`/tmp/t21r2-postrestore.log`). One transient compile error during mutation authoring (`fileManager` used before declaration) was fixed within the mutation window; final mutated file compiled and ran. No residue.

**Freeze counterexample, restated against the new pins (scope a):** a store that silently no-ops any save after the chain fills completes only 3 of 24 saves, consuming ticks base+0..+2; the chain holds {σ3, σ2, σ1} with savedAt 12:00:00/01/02. Round-1 pins all passed on this store; round 2, `current.savedAt == base+23 s` (and previous/oldest, and test 2's base+127 s) fail arithmetically — empirically confirmed above. Interior-skip and double-read variants shift the same arithmetic and fail the same pins (the test comment names both).

## Residual findings

- **OBSERVATION-R2-1** — the adjacency pins make tick bookkeeping part of the tested contract: any future second clock read inside `save` will (correctly, and per the documented assumption) fail the suite. This is a feature, not a defect; the comment already says so.
- No other findings. MAJOR-1 and MINOR-1 both closed; nothing sound was lost in the repair (round-1 pins retained or subsumed; two sound bonus pins added).

## Recommendation to the orchestrator

TASK-021 is commit-ready from the delta-verification standpoint: apply the disposition flow of the original review (atomic commit per the task's Git Requirements, push, record hash, update status.md, move the task to completed). The original REVIEW-TASK-021 verdict and this record's Round-1 CHANGES_REQUIRED are both superseded by this Round-2 APPROVED for the flake-fix delta.
