# REVIEW-TASK-004 — Independent Review: UX Architecture

| | |
|---|---|
| Date | 2026-09-08 |
| Reviewer | task-004-reviewer (fresh, independent — CLAUDE.md §10, §33; unprimed; adversarial brief: attempt to disprove) |
| Artifact | `docs/design/03-ux-architecture.md` (TASK-004 deliverable) |
| Inputs used | `project.md`, `docs/product/01-product-review.md` (D1–D20 binding), `docs/product/02-mvp-prd.md` (normative), `.claude/tasks/active/TASK-004-ux-architecture.md`, `CLAUDE.md` |
| Method | Full read of artifact + all three ground-truth documents; line-level cross-reference audit; FR-2 AC-1a layout arithmetic; per-copy FR-12 tone sweep; per-screen accessibility and phase-discipline checks; all five §11.2 interpretations independently adjudicated against PRD text. Read-only review of the artifact; no artifact changes made. |
| Verdict | **APPROVED_WITH_MINOR_NOTES** |

---

## Verified Compliant

No CRITICAL or MAJOR findings. The document is faithful to the PRD and the D1–D20 decision log on every adversarial axis checked. Summary of what was attacked and held:

- **D2 (onboarding exactly Meet→Name→Enter):** three screens; S1's "Say hello" is the Meet step's advance button and is explicitly *not* a pet touch (doc line 130), so it is neither a covert 4th step nor a premature daily hello. Atomic completion-flag write at the S3 tap (line 155) satisfies FR-1 AC-2; zero dialogs/network/accounts satisfies AC-1/AC-4. The task file's 5-step "≤ 5 steps" text is satisfied (3 ≤ 5); its "choose" step is D2-deferred to Phase 3 (D2's own resolution of C2).
- **D3/D4 (no punishment surface anywhere):** Q1 expiry silent (line 296); night behavior = §4 matrix responses only (line 197); just-fed = zero penalty (line 260); absence = warm greeting only (line 172); explicit branch-guarantees statement (line 201). The erase alert's "This can't be undone" (line 414) was examined as a possible loss-framing violation and **cleared**: it is informed-consent language required by FR-19 AC-2's explicit-confirmation rule for an irreversible destructive action, not engagement/retention loss framing.
- **D13 (IA exact):** UX-1 = Home/Room/Settings native tabs; Collection rejected per K5/D13 (line 76); no customization entry points on Home (FR-2 AC-4). Flat IA; the erase alert is the only modal.
- **D16 (Reduce Motion per screen):** §10 Reduce Motion column populated for all 7 inventory IDs; UX-14 (eye-follow → single glance) is an in-spirit extension; M1–M3 → crossfade + haptic; AOD static pose on Watch.
- **D18 (nothing limit-gated):** Feed/Play always present, always respond (§5.2–5.3); same-family repetition softens while the button never changes (line 237); care chips contextual per the §4 matrix's own "Not offered" cells; the ≤30 s play round is FR-7 AC-1's own shape, not a gate; "Done" early-exit pill is an affordance, not a lock.
- **E2 character-agnostic discipline:** pet-canvas placeholder declared in the header (line 9); the only presumed anatomy is the PRD contract (head/belly zones, eye-follow, FR-4 expressions). Play = fingertip-follow (line 266); meal form deferred to TASK-005 (line 248); VoiceOver canvas line "A small creature looks up at you" uses only contracted anatomy (eyes); room scene species-neutral; motion verbs ("bounds/spins/nuzzles") are body-generic, not species-presuming.
- **Phase discipline:** §7 is reservation-only — no Phase 2 design work; Phase 2 open questions explicitly "deliberately untouched" (line 372). §8.2 is strategy-only with no designed screens — and is in fact *required* by the task file ("Permission flow strategy (HealthKit, notifications: when asked, with what copy, what happens when denied)"). The DisplayState read-model recommendation to TASK-006 is a Phase 1 concern (Home/W1 already share state) with Phase 2 portability as a byproduct, not a leak. Rejected-surfaces list correctly defers Collection/pet-picker (Phase 3), shop (D8), widgets (§27).
- **FR-2 AC-1a arithmetic (adversarial check requested):** smallest plausible supported device is SE-class (375×667 pt). Usable vertical ≈ 667 − 20 (status) − 49 (tab bar) ≈ 598 pt. Elements at default 17 pt type: status row ~32 + contextual line ~32 + action row ~52 (44 pt pill + padding) + quest card ~156 (header ~26 + 3 wish rows ~38 each + card padding ~16) + pet canvas ~269 (~45% of usable height) ≈ **541 pt — fits with ~55 pt slack**. Residual risk: PRD catalog copy renders verbatim (line 292), and "Mealtime — Momo would like a meal" (34 chars) wraps at ~320 pt text width; three wrapped rows (+66 pt) would break the budget. The doc does not claim proof — it correctly routes verification to the TASK-006 device matrix (line 485) — so this is PASS-WITH-NOTE (MINOR-2/3), not an overclaim.
- **FR-17 (Watch ≤5 s / offline / no dashboard):** snapshot-restore path protects ≤5 s (lines 333, 485); offline pat queues as idempotent intent events, replay exactly once, no error/badge/guilt copy (§6.4 = FR-17 AC-3, FR-18 AC-1/AC-3); W1 hierarchy (mood words + stage + pose + single quest + one pat) is one glanceable summary, not a dashboard — energy rendered as pose only is permitted by project.md §12's "where useful".
- **FR-18:** idempotent replay exactly once (line 352); next-sync-opportunity updates (line 353 = FR-18 AC-3); conflicts never user-visible (FR-18 AC-4).

## Findings

Severity legend: CRITICAL/MAJOR would block commit; MINOR should be fixed before commit; NITPICK is advisory. **5 MINOR, 6 NITPICK.** Line numbers refer to `docs/design/03-ux-architecture.md`.

### MINOR-1 — Internal vocabulary collision: §0 forbids "banners", §5.6 designs one
- Location: line 24 ("No dots, banners, progress rings, or notification badges anywhere in Phase 1") vs. line 304 (M2 = "Calm in-scene banner over Home").
- Evidence: The governing-principles table literally prohibits the form §5.6 later specifies. Intent is recoverable (§2 line 103 correctly distinguishes persistent chrome from transient in-scene moments), but a builder honoring §0 as written would either reject M2's form or learn §0 is aspirational.
- Correction: Reword §0 to "no *persistent* banners/badges/dots/rings" or rename M2 a "calm in-scene moment."

### MINOR-2 — Broken cross-references and a dangling label
- Location: line 431 ("no scroll (§1.1 budget)") and line 485 ("the §1.1 no-scroll budget"); the budget annotation actually lives in §5.1 (line 210). §1.1 is the screen-inventory table and contains no budget. Also line 481: "Audio scope decision (N2)" — no "N2" label exists anywhere in the PRD; the audio decision is PRD §10's TASK-005 obligation, unlabeled.
- Correction: Point both budget references to §5.1; replace "(N2)" with "(PRD §10, TASK-005)".

### MINOR-3 — FR-2 AC-1a budget is plausible but thin, and silently assumes single-line wish rows
- Location: §5.1 (line 210), §10 S4 row (line 431).
- Evidence: Arithmetic above fits (~541/598 pt), but the PRD catalog copy is verbatim and "Mealtime — Momo would like a meal" wraps to two lines at 375 pt width; three wrapped rows add ~66 pt and break the budget. The document never states the single-line assumption.
- Correction: Add one line to §5.1 stating the budget assumes single-line wish rows at default Dynamic Type, and make wish-copy length a TASK-005 tone-guide constraint (truncation is forbidden by the calm bar, so length is a copy-design obligation).

### MINOR-4 — Q1 completion and the +8 hello are coupled as one atomic event, but their windows differ in the PRD
- Location: line 160 ("the first pet touch of the day completes Q1 and earns the day's hello (+8)"), line 185 ("first-touch-of-day = hello (+8 bond, Q1 ticks)"), line 337 (Watch: "it is the hello (+8, Q1)").
- Evidence: PRD §3.3 (line 138) grants the hello to the "first touch of the local day — one per day" with **no window**; Q1's 12:00 expiry (PRD §5.2) governs the quest, not the bond table ("Bond earning (normative)" is §3.3's exclusive domain). A user whose first touch is at 14:00 earns the hello but cannot complete Q1. The doc's coupled phrasing invites TASK-006 to window-gate the hello — silently denying +8 to late starters, an unjustified bond loss in tension with D3/D4's no-penalty posture.
- Correction: Add one clarifying sentence (in §5.5 or §11.3): the trigger is shared, the windows are not — hello awarded once per local day whenever the first touch occurs (iPhone or Watch, per UX-6), regardless of Q1's 12:00 expiry; Q1 ticks only when the first touch lands before 12:00. If window-gating the hello is instead intended, that is a PRD ambiguity (§3.3 has no window; §5.2 does) to escalate to the PRD owner — not something TASK-006 should resolve silently.

### MINOR-5 — Settings enumeration in §1.2 is incomplete against FR-19
- Location: line 67: "Trust and control: rename, haptics, erase-all-data, honest privacy statement."
- Evidence: PRD FR-19 requires About (version, short privacy statement) and a conditional sound toggle. "Version" appears nowhere in the document; the sound toggle exists only in §11.3's handoff note, not in the S6 inventory. S6 nominally "owns FR-19" wholesale, but a screen-inventory deliverable should reflect the full contents.
- Correction: Amend §1.2 S6 to "rename, sound (conditional on TASK-005 audio scope), haptics, erase-all-data, About (version + privacy statement)."

### NITPICK-1 — M2 celebration lacks a VoiceOver announcement
§10 (line 431) covers status row/canvas/quest card for VoiceOver; §5.6 (line 304) covers only the visual banner. Sighted users get the stage moment; VO users should get an accessibility announcement.

### NITPICK-2 — S2 name validation hides the whitespace rule from VoiceOver
Lines 139–143: a button that "simply stays unavailable" with no error copy is calm for sighted users but leaves VO users without an explanation. Add an accessibility hint; keep the calm visual.

### NITPICK-3 — Pre-onboarding Watch copy slightly dishonest
Line 407: "say hello on iPhone" — before onboarding there is no hello to say; "meet Momo on iPhone" is more accurate and equally warm.

### NITPICK-4 — W1 quest-line mid-progress rendering unspecified
Line 332: for Q7 (pat ×3), does the line change at 1–2 pats? One sentence closes it (recommended: line unchanged until complete).

### NITPICK-5 — §5.1 wireframe omits mood/energy glyphs
Line 211 shows a glyph only for bond (✨) while §10 (line 431) and PRD §3.1 require glyph + label for mood/energy too; wireframe shorthand should include glyph placeholders.

### NITPICK-6 — Erase copy timing imprecision
Line 414: delete promise says data is removed "on this iPhone and Apple Watch," but the Watch snapshot resets only "at next sync" (the row's own Watch cell). Fine at intent level; the final string should reflect the timing.

## Verification Results

### FR / Decision compliance table

| Check | Result | Evidence |
|---|---|---|
| D2 (Meet→Name→Enter exactly) | PASS | 3 screens (§3); "Say hello" is S1's advance button, explicitly not a pet touch (line 130) — no covert 4th step, no premature hello. 3 steps satisfy the task file's "≤ 5 steps"; "choose" is D2-deferred (Phase 3). Atomic flag write (line 155) = FR-1 AC-2. |
| D3/D4 (no punishment surface) | PASS | Q1 expiry silent (line 296); night = matrix responses (line 197); just-fed zero penalty (line 260); absence warm-only (line 172); branch guarantees (line 201). Erase alert cleared (see Verified Compliant). |
| D13 (IA exact) | PASS | UX-1 = Home/Room/Settings native tabs (§2); Collection rejected per K5/D13 (line 76); no customization entry points (FR-2 AC-4). |
| D16 (Reduce Motion per screen) | PASS | §10 column complete for all 7 inventory IDs; UX-14 in-spirit extension; M1–M3 crossfade + haptic; AOD static (FR-17 AC-5). |
| D18 (nothing limit-gated) | PASS | Feed/Play always present and responsive (§5.2–5.3); repetition softens, button never changes (line 237); contextual chips = matrix's own "Not offered" cells; ≤30 s round is FR-7 AC-1's shape. |
| FR-1 (onboarding) | PASS | §3 covers AC-1 (3 steps, zero dialogs), AC-2 (atomic flag, restart semantics), AC-3 (rename in S6.1), AC-4 (no account/network). |
| FR-2 AC-1a | PASS-WITH-NOTE | Arithmetic fits (~541/598 pt) but thin; single-line-wish assumption unstated — MINOR-2/3. Verification correctly delegated to TASK-006 device matrix (line 485). |
| FR-2 AC-1b/2/3/4 | PASS | Standard scroll at accessibility sizes, no function loss (§10); 1-tap delight path (§0); no numbers/XP bar (UX-2/4); no Collection (UX-1). |
| FR-5 (touch & petting) | PASS | All four gesture classes with distinct reactions (§5.1 table); available in every state incl. sleeping stir (§9 night row); 10-rapid-pat softening, never locked (D18); head/belly zones deferred to TASK-005 per AC-4/E2. |
| FR-6 (feed) | PASS | §5.2 state table matches the §4 matrix exactly, incl. "politely full — zero penalty" (AC-1), no cooldown (AC-2), feedCount tick (AC-3). |
| FR-7 (play) | PASS | UX-3 three-phase shell: invite ≤3 s + follow 10–20 s + payoff ≤5 s = ≤28 s ≤ FR-7 AC-1's 30 s with a clear payoff; Drowsy/Exhausted/sleeping variants match the matrix (AC-3); never locked. |
| FR-8 (care) | PASS | Tuck in from 20:00 through night window, blanket-adjust when asleep, Q6 once/day (AC-2); Nap when Drowsy/Exhausted; daytime = absent per AC-1's sanctioned "absent" option. |
| FR-9/FR-10 (bands, bond legibility) | PASS | Words + glyph only (UX-2/UX-4, §10 template); stage word + descriptor = §3.3's mandated communication; no within-stage meter — permitted ("MAY be hinted" is optional) and deliberately resolves PR8; M2 one-time celebration with next-open deferral consistent with FR-10 AC-4. |
| FR-11/FR-12 (time, absence) | PASS | Night 22:00–07:00 (D11); midnight silent reset (line 198 = AC-2); §9 covers DST/timezone/clock-change row; ≥36 h warm greeting, no guilt (AC-2); absent-day quests silently empty (AC-1); nothing queues penalties (AC-3). |
| FR-13 (persistence) | PASS | Atomic flag write (line 155); ≤1 s force-quit loss row (§9 = AC-1); corruption row "recovers to last valid snapshot, slightly older state" is exactly AC-2's own semantics, cadence handed to TASK-006. |
| FR-14–16 (quests) | PASS | Catalog copy verbatim (line 292); wish framing, no "don't forget"/deadlines/counts (line 292); auto-complete, no claim button, no modal (M1 = FR-16 AC-1); silent expiry incl. Q1 12:00 and Q6 window rules = FR-16 AC-2; +4/cap respected in §4 item 6. |
| FR-17 (≤5 s, offline, no dashboard) | PASS | Snapshot-restore path to ≤5 s (lines 333, 485); offline pat queues idempotently with immediate on-wrist feedback, no error/badge/guilt (§6.4 = AC-2/AC-3); one glanceable summary, energy as pose (AC-4); AOD pause (§6.5 = AC-5). |
| FR-18 (sync) | PASS | Idempotent replay exactly once (line 352 = AC-1); same counters/quests as iPhone pats (AC-2); next-sync-opportunity, no immediacy assumed (AC-3); conflicts never visible (AC-4); no cloud (AC-5 implicit — paired-device channel only, §8.1). |
| FR-19 (Settings) | PASS-WITH-NOTE | Contents match FR-19 except the enumeration gaps in MINOR-5; sound toggle correctly conditional on TASK-005 audio scope (line 481); erase confirmation + FR-1 return (S6.2, §9); MUST-NOT list honored (no notification/HealthKit/account rows — lines 79, 389). |
| FR-20 / NFR-6 (privacy + accessibility) | PASS | §8 zero-permission strategy matches FR-1 AC-1 + FR-20; "Data Not Collected" label target; String Catalogs for all strings incl. accessibility (lines 241, 424); §10 audit scope = FR-20 AC-2 core loop, launch-blocking per NFR-6; contrast/44 pt/color-independence per FR-20. |
| E2 character-agnostic | PASS | Header scope (line 9); contracted anatomy only; see Verified Compliant. |
| Phase discipline | PASS | §7 reservation-only; §8.2 strategy-only (and task-mandated); §1.3 rejections correct per §27/D13/D8; §5.7's Phase 2 revisit gate is a gate, not design. |
| §30/§40 Step 3 coverage | PASS | All nine Step 3 deliverables present; task-file requirements 7–11 map to §30 items 7–11. |

### The five §11.2 interpretation flags — independent judgments

1. **UX-5 (wish lines render inside their windows; morning of a Q6-day shows 2 lines)** — **LEGITIMATE, and arguably the only PRD-consistent reading.** Three independent PRD facts support it: (a) §5.2's catalog copy is normative-verbatim, so time-neutral Q6 rewording is unavailable without a PRD change; (b) the PRD already establishes windowed rendering via Q1's 12:00 silent expiry — "3 wishes" (FR-2) is a per-day generation quantity, not a continuously visible line count; (c) the normative Watch cascade (PRD §5.5 rule 1) itself refuses to surface Q6 before 20:00. The state-honesty rationale ("Momo is getting sleepy" is false at 09:00 against a status row reading "Energetic", Momo starting the day at 85 per PRD §3.2) is sound. No contradiction with FR-2's normative text. Not scope creep.
2. **UX-6 (Watch pat = daily hello, device-agnostic, idempotent)** — **LEGITIMATE.** FR-18 AC-2 equalizes pat counters/quests across devices; device-gating the hello would require the engine to distinguish pat origin, contradicting that equalization. "First touch of the local day" in PRD §3.3 is not device-qualified. Correctly recorded as a TASK-006 engine obligation. Caveat: see MINOR-4 — the doc's coupling of the hello to Q1's 12:00 window needs the clarifying sentence, since §3.3's hello has no window.
3. **D18 vs. contextual care chips** — **LEGITIMATE.** The §4 matrix itself contains "Not offered" cells (Nap in Energetic/Relaxed; Tuck-in before 20:00), so offering is matrix-gated by the PRD's own design. "Whatever is offered is never disabled or limited" is exactly D18's text. Reconciliation is faithful, not inventive.
4. **FR-8 "absent" over "visibly not offered"** — **LEGITIMATE.** Explicitly one of the two PRD-sanctioned options (AC-1: "absent (or visibly not offered)"). The calm/no-dead-button rationale is consistent with §0 and §18 and the no-guilt posture. The right call for this product.
5. **Play "just-fed: (unaffected)" reading** — **LEGITIMATE and trivial.** Both readings of the parenthetical (play unaffected by fed-state; fed-state unaffected by play) converge on "play follows its own state column," which is exactly what §5.3 specifies. No alternative interpretation produces a different design.

### Tone audit (FR-12) — PASS

Every copy suggestion in the document was swept for guilt, obligation, countdown/urgency, streak, and loss framing. Checked specifically: greetings incl. the absence variant ("Momo missed you" class — sanctioned by FR-12 AC-2), "Momo had a lovely day." (sanctioned by PRD §5.4's optional warmer moment; its absence on incomplete days carries no counter-message), "All done — see you soon" (PRD's own cascade copy), "Shhh… Momo is sleeping" and the sleepy "zzz…" decline (PRD's own §8/§4 copy), the Watch "settling in" line, night pat behavior, Q1 quiet disappearance ("never 'missed', never marked"), M2 "{name} and you are now {Stage}. {descriptor}." (relational, not level-up framing), the erase confirmation (cleared — informed consent, not engagement loss-framing), and Watch quest lines ("no urgency copy" stated explicitly, line 332). **No violation found.** §15's bad-copy list is correctly applied as a standing checklist despite notifications being Phase 2 (line 28), matching FR-12's normative scope.

### Section completeness (task file's 10 required sections) — ALL 10 PRESENT

1. Sitemap + screen inventory, every screen justified, plus a rejected-surfaces list (§1) — exceeds requirement.
2. Navigation model with rationale and rejected alternatives (§2).
3. Onboarding flow (§3).
4. Primary daily flow (§4).
5. iPhone interaction flows — all four gesture classes, feed, play, head/belly-specific reactions (§5.1–5.4).
6. Apple Watch flow — pet view, one interaction, today's quest, status, haptic rules (§6).
7. Widget/complication surfaces for Phase 1 — answered as "none in Phase 1" + reservation, which is the correct answer to the task's "what is NOT" (§7).
8. Permission flow strategy incl. denied paths, Phase 1 = zero permissions (§8).
9. Empty/failure/offline states per surface (§9 — 12 rows, both device columns).
10. Accessibility intent per screen (§10 — all 7 inventory IDs, all five required dimensions).

Every Phase 1 PRD screen is covered (FR-1 ×3, FR-2 Home, FR-3 Room, FR-17 W1, FR-19 incl. rename + erase alert). Cross-document consistency spot-checked: quest cascade outputs vs. card rendering (consistent, incl. "All done" state), M2 deferral vs FR-10 AC-4 ("shown once, deferred to next open" still satisfies "one-time"), UX-9 no-freshness-indicator vs §9 table rows (consistent; no stale badge anywhere), §9 corruption row vs FR-13 AC-2 ("slightly older state" ≤ last snapshot interval is exactly the PRD's own semantics, cadence correctly handed to TASK-006). All consistent.

## Verdict Evidence

The review attempted to disprove the document on eight fronts — PRD/decision compliance, the five self-flagged interpretations, character-agnostic discipline, tone, phase discipline, testability/consistency, accessibility completeness, and over-specification — and failed everywhere except wording-level precision. The five interpretation flags all hold against the PRD's own machinery; most decisively UX-5, where the PRD's normative verbatim catalog copy, its own Q1 12:00 expiry precedent, and its own Watch cascade independently force window rendering, making the doc's choice the only state-honest option rather than scope creep. No punishment surface survives scrutiny (the one candidate, the erase alert, is FR-19 AC-2-mandated informed consent). Character-agnostic discipline is clean — only the contracted anatomy is presumed, and play's fingertip-follow form is species-neutral by construction. Phase discipline holds: §7 designs nothing for Phase 2, and §8.2's Phase 2 content is the task file's own requirement. The no-scroll budget survives arithmetic (~541 pt of ~598 available on a 667 pt device) though with modest slack and an unstated single-line-wish assumption, and the document correctly routes verification to the TASK-006 device matrix rather than claiming proof. What remains are five MINOR defects — the §0/§5.6 banner self-contradiction, two mislabeled cross-references plus the un-itemized budget assumption, the Q1/hello window coupling that could silently cost late starters their +8 hello if implemented as written, and the incomplete Settings enumeration — each a one-to-three-line fix with no structural consequence, plus six advisory NITPICKs. **APPROVED_WITH_MINOR_NOTES: commit may proceed once the five MINOR findings are applied.**

*Orchestrator note (outside this review's scope): PRD §5.5 cascade rule 1 ("local time ≥ 20:00") literally misses Q6's 00:00–07:00 window tail when Q1 is already complete (e.g., at 02:00). The UX doc inherits this without error (it renders the cascade's output), but TASK-006 implementing the cascade should flag it to the PRD owner.*

---

**Final status: APPROVED_WITH_MINOR_NOTES — 5 MINOR + 6 NITPICK, none blocking after the MINOR fixes are applied. Review performed by an independent fresh agent; artifact unmodified by the reviewer; no commit made.**

---

## Disposition (orchestrator)

No CRITICAL/MAJOR findings ⇒ no separate fix agent required (CLAUDE.md §11: fix agents are for distinct tasks or substantial revisions). All 11 findings applied to `docs/design/03-ux-architecture.md` by the orchestration agent as mechanical one-line edits:

| Finding | Fix applied |
|---|---|
| MINOR-1 | §0 scoped to *persistent* banners/rings/badges; M2 cross-referenced as transient in-scene, not chrome |
| MINOR-2 | Both budget cross-refs repointed §1.1 → §5.1 (§10 S4 row, §11.3); "(N2)" → "(PRD §10, TASK-005 obligation)" |
| MINOR-3 | §5.1 budget-assumption note added: single-line wish rows at default Dynamic Type; wish copy = length-constrained class owned by the TASK-005 tone guide (truncation forbidden); TASK-006 verifies against the device matrix |
| MINOR-4 | §11.3 hello/Q1 clarification added: shared trigger, different windows — hello awarded once per local day whenever the first touch occurs (PRD §3.3), Q1 ticks only before 12:00 (PRD §5.2); "the hello must never be implemented as window-gated" |
| MINOR-5 | §1.2 S6 enumerated in full: rename, sound (conditional on TASK-005 audio scope), haptics, erase-all-data, About (version + short privacy statement) |
| NITPICK-1 | §5.6: M2 posts a VoiceOver accessibility announcement; M1 spoken via quest-card done-state |
| NITPICK-2 | §3 S2: accessibility hint on the unavailable Continue button for VO users |
| NITPICK-3 | §9 pre-onboarding Watch line: "meet Momo on iPhone" |
| NITPICK-4 | §6.1: quest line frozen mid-progress (Q7 identical at 0/1/2 pats; swaps only on completion) |
| NITPICK-5 | §5.1 wireframe: {mood glyph}/{energy glyph} placeholders added to the status row |
| NITPICK-6 | §9 erase copy now reflects Watch reset-at-next-sync timing |

The review's orchestrator note (PRD §5.5 cascade rule 1 misses Q6's 00:00–07:00 tail when Q1 is complete, e.g., 02:00 tuck-in) is carried into `status.md` as a TASK-006 intake obligation — the UX doc inherits the cascade's output without error.

**Final status after fixes: APPROVED — cleared for commit and push.**
