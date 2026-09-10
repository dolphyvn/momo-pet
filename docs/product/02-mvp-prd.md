# Momo — MVP Product Requirements Document (PRD)

| | |
|---|---|
| Task | TASK-003 — Step 2: MVP Product Specification (project.md §40 Step 2, §30 items 1–8) |
| Date | 2026-09-08 |
| Inputs | `project.md`, `docs/product/01-product-review.md` (decisions D1–D20 binding), `CLAUDE.md` |
| Status | DRAFT — pending independent review (CLAUDE.md §10) |
| Scope | Phase 1 (MVP) only, per project.md §27. Nothing from Phases 2–4 appears as a requirement. |
| Authority | Where this PRD is more specific than `project.md`, it implements the Phase 1 reading mandated by the TASK-002 decision log. Conflicts resolve toward `project.md` §45 (North Star) and the TASK-002 decisions. |

**Normative language.** MUST = binding and testable. SHOULD = goal; deviations require a written note in the implementing task. MAY = permitted, not required. Quantities labeled *(starting value)* are PRD-owned defaults the TASK-006 engine spec implements verbatim unless review changes them; quantities labeled **normative** may only change via a PRD revision.

---

## 0. Product Summary

Momo is a tiny companion that quietly shares the user's everyday life. One pet, three dimensions (Mood ❤️, Energy ⚡, Bond ✨), a small set of warm interactions, three small daily wishes, and a Watch that keeps Momo present at a glance.

Emotional target: **Cute × Calm × Minimal × Alive × Premium** — never Childish × Noisy × Addictive × Complicated × Game-heavy. The product creates affection, not obligation: it never punishes absence, never guilt-trips, never gates affection behind limits or currency.

Distribution: **free at launch; monetization model is OPEN-DECISION E1** (no purchase, paywall, or monetization code path ships in Phase 1 — D8).

---

## 1. Target Users & Personas

Momo launches for people who want a small, low-demand source of warmth — not players looking for progression, collection, or economy systems (served by other products by design).

### P1 — "The micro-break commuter" (primary)

- **Who:** 20s–30s professional, iPhone + Apple Watch, dense days, short attention pockets (transit, queue, coffee line).
- **Jobs-to-be-done:**
  - "Give me a 30-second moment of warmth between obligations, without demanding anything back."
  - "Let me check on something alive and gentle at a glance from my wrist."
- **Success for P1:** Opens Momo, sees Momo react, maybe pats or feeds, leaves in under a minute feeling lighter. The Watch glance replaces the app open most days.

### P2 — "The gentle routine builder" (primary)

- **Who:** Remote worker or student prone to losing daily rhythm; may be recovering from burnout; sensitive to pressure mechanics and guilt copy.
- **Jobs-to-be-done:**
  - "Give me a soft morning and evening anchor (a hello, a tuck-in) that never becomes another obligation."
  - "Let me care for something small and have it care back, at a pace I control."
- **Success for P2:** Momo's day rhythm (wake → day → tuck-in → sleep) mirrors a healthy rhythm without streaks, counts, or nagging. Skipping days costs nothing visible.

### P3 — "The quiet caretaker" (secondary)

- **Who:** Any age; likes pets, can't have one (allergies, housing, schedule); keeps the app on the Home screen.
- **Jobs-to-be-done:**
  - "Give me a small daily act of care — a meal, a tuck-in — that feels meaningful rather than chore-like."
  - "Show me, over weeks, that this relationship is quietly growing."
- **Success for P3:** Bond stages advance over weeks of ordinary affection; the stage moments ("Getting Close", "Best Friends") land as emotional beats, not level-ups.

**Anti-persona (by design):** the optimization-driven gamer who wants XP efficiency, collections, or daily-mandatory loops. Momo deliberately offers nothing to optimize (see §2 anti-grind guarantees and §5 quest rules).

---

## 2. Core Daily Loop

Phase 1 loop, mapped to project.md §6:

1. **Wake / open** → Momo greets (time-aware: good morning, active day, winding down, or "Shhh… Momo is sleeping" at night).
2. **See Momo** → current mood band, energy band, bond stage, one contextual line (§ FR-2).
3. **Discover today's small activity** → today's 3 quest wishes (§5).
4. **User interacts** → pet / feed / play / care, each state-gated and always available (§4) — or does nothing; the loop does not require it.
5. **Momo reacts** → animation + micro-uplifts to mood; energy shifts.
6. **Bond / progress changes** → small daily bond events accrue (§3.3); quests tick.
7. **Tiny reward** → a gentle celebration moment on quest completion; a stage celebration on bond transitions.
8. **Return naturally later** → typically evening: tuck Momo in. No notification pulls the user back in Phase 1 (notifications are Phase 2, §27).

**Explicitly excluded loops (normative):** Feed → Feed → Feed → Grind → Currency. Three structural guarantees make grinding pointless, not merely discouraged:

- **G1 — Bond is capped per day** (+20 max, §3.3): no volume of play accelerates the relationship.
- **G2 — Touches bank nothing**: raw petting affects in-the-moment mood only and never moves Bond (§3.3). Affection is expressed, not accumulated.
- **G3 — No sinks, no currencies**: there is no coin, energy-drink, inventory, or shop in Phase 1 (§8 non-goals); there is nothing to grind *for*.

---

## 3. The Three-Dimension Model (PRD-owned numbers)

The only user-facing pet dimensions are Mood ❤️, Energy ⚡, Bond ✨ (project.md §5). Internal helpers (e.g., same-day interaction satiety, last-fed time) are permitted but MUST NOT surface as additional stats.

### 3.1 Mood ❤️ — how Momo feels right now

Internal continuous scalar **0–100** (D10). The UI MUST present the band (label + glyph + contextual line), never the raw number (no statistics dashboard, §5/§24).

| Band | Range | Meaning | Expression |
|---|---|---|---|
| Joyful | 75–100 | Bright, playful, engaged | Lively idle, eager reactions |
| Content *(attractor: 60)* | 45–74 | Calm, at ease — the resting state | Soft idle, gentle reactions |
| Wistful | 20–44 | Subdued, sleepy-hearted | Quieter idle, extra-warm responses to care |
| Low | 0–19 | Reserved headroom | **Not produced by any Phase 1 mechanic** (see below) |

**Normative Phase 1 mood rules:**

- **Attractor:** with no input, mood eases toward **60 (Content)** — inactivity drifts toward neutral-calm, never distress (D4).
- **Floor:** Phase 1 dynamics MUST NOT take mood below **25**. The Low band exists so the presentation scale is complete and honest; producing it is reserved for later phases and requires a PRD revision.
- **Energy coupling:** while Energy is in Drowsy or Exhausted **during waking hours**, mood gains a gentle downward pull toward 35 (never below 25). It relieves itself when Energy recovers — the user fixes it by letting Momo rest, or simply by the next night's sleep. This is the only downward mood pressure in Phase 1; it is self-healing, produces no message of guilt, and never touches Bond.
- **Ceiling:** normal play MUST NOT push mood above **92**; only celebratory moments (quest set complete, bond stage change) may reach the top of Joyful.
- **No negative user actions:** feeding a full Momo, petting "too much", skipping quests, missing days — none of these reduce mood. Repetition only yields smaller positive effects (§4).

### 3.2 Energy ⚡ — current activity state

Internal continuous scalar **0–100** (D10). Presentation identical to mood: band only.

| Band | Range | Meaning |
|---|---|---|
| Energetic | 75–100 | Up for full play |
| Relaxed | 45–74 | Calm activity, short play |
| Drowsy | 20–44 | Low-key play at most; nap offered |
| Exhausted | 0–19 | Ready for sleep; play becomes a gentle stir; nap offered |

**Normative Phase 1 energy rules (directions normative; rates are starting values for TASK-006):**

- Momo starts the day at **85** *(starting value)* after a full night's sleep.
- Passive decline during waking hours ~1–2 points/hour *(starting value)* → naturally Drowsy by late evening.
- **Play costs** energy (~10/round *(starting value)*); **feeding restores** some (~6 *(starting value)*); **care/nap restores** more (~20 *(starting value)*).
- **Night (22:00–07:00 local, D11):** Momo sleeps; energy restores to ≥ 75 by 07:00. Night rest is automatic — no user action required to avoid harm.
- Exact drift/restore rates are owned by the TASK-006 engine spec within these directions and band definitions.

### 3.3 Bond ✨ — the relationship (monotonic, relational, never XP)

Internal cumulative scalar **0–1000**, **normative**. Bond NEVER decreases (D3). Absence freezes growth; it never costs progress. Bond is earned only by the three daily relationship events below — never by raw tap volume.

**Stage thresholds (normative):**

| Stage | Points | Descriptor line |
|---|---|---|
| New Friends | 0–149 | "Just getting to know each other." |
| Getting Close | 150–399 | "Momo perks up when you arrive." |
| Best Friends | 400–749 | "Momo knows your rhythms." |
| Soul Companions | 750–1000 | "Quietly inseparable." |

**Bond earning (normative; per local day, D11):**

| Event | Bond | Notes |
|---|---|---|
| Daily hello — first touch of the local day | +8 | One per day; the "greeting" moment |
| Each quest completed (max 3/day) | +4 each | Up to +12 |
| Variety bonus — all three families (feed, play, care) used in one day | +6 | Encourages a full small day, not volume; it is what allows a 2-quest varied day to reach the +20 cap (on 3-quest days the cap is already reached via hello + quests) |
| **Daily cap** | **+20 max** | Enforced; no combination may exceed 20/day (testable) |

**Pacing intent:** a fully engaged day = +20 → *Getting Close* in ~8 days minimum; typical relaxed use reaches it in ~2–3 weeks; *Best Friends* ~1 month in; *Soul Companions* is a realistic 2–3 month arc. Bond is designed so that **showing up across days is the only path** — the cap (G1) makes grinding mechanically worthless.

**Legibility rules (normative, resolves review risk PR8):**

- The UI MUST NOT display bond as a numeric XP value or a filling XP-style progress meter on Home. Bond is communicated by **stage name + descriptor line**, and stage transitions are one-time gentle celebrations.
- Within-stage position MAY be hinted (TASK-004 decides presentation) but MUST NOT read as a game progress bar.
- 1000 is a plateau, not an end: after *Soul Companions*, Momo's affection continues unchanged; no post-cap content in Phase 1.
- Absence is referenced warmly at most: after ≥ 36 h since last open, the first greeting MAY be a special warm variant ("Momo missed you") — with the same +8, never more, never less. No absence penalty, no guilt copy (D3, §3 P4).

---

## 4. Interaction Semantics (D18 — state-gated, never limit-gated)

Product-level semantics; exact engine curves/rates are TASK-006's. Normative rules:

- Every interaction button/state is **always available**. There are no cooldown timers, no locks, no currencies, no counters that cut the user off.
- A state-mismatched interaction produces a **qualitatively different, still-warm response** — never a punishment, never a mood loss.
- Same-family repetition yields smoothly diminishing effect (first instance full, ~zero effect by the 3rd–4th repeat *(starting curve)*). The button never changes to "locked"; the response just softens.

**Response matrix (normative):**

| Interaction | Energetic / Relaxed | Drowsy | Exhausted | Sleeping (night window) | Just fed (full) |
|---|---|---|---|---|---|
| **Pet / touch** (tap, double-tap, long-press, stroke) | Distinct happy reactions per gesture; eyes-follow where technically appropriate | Soft, slower reaction | Soft, slower reaction | Momo stirs, tiny heart; stays asleep | (unaffected) |
| **Feed** | Enjoys the meal (mood+, energy+) | Nibbles happily, smaller effect | Sleepy nibbles, small effect | Gently declines, sleepy ("zzz…") | Politely full — cute refusal, zero penalty (0–30 min fed); **recently fed 30–90 min: small contented nibble — shortened eating animation, ×0.25 state effects** (owner decision 2026-09-08, I-2) |
| **Play** (one simple play interaction, ~15–30 s per round) | Full round | Short low-key round, ends in a yawn | Gentle stir only | Gentle stir only | (unaffected) |
| **Care — Tuck in** | — | — | — | Offered from **20:00 local** through the night window; eases Momo toward sleep (mood+, small energy+); if already asleep, a blanket-adjust moment (still counts) | (unaffected) |
| **Care — Nap** | Not offered | Offered; restores energy | Offered; restores energy | (asleep) | (unaffected) |

*Errata (REVIEW-TASK-016 adjudication 8, 2026-09-09): in the Feed row, the mood band selects the response **beat** (the sleepy-nibbles presentation) while the satiety phase selects the state **effects** — so a hungry Drowsy/Exhausted feed lands at full meal effect with the sleepy beat, and these cells' "smaller effect" prose is realized only through the recently-fed nibble (×0.25, the I-2 refinement in this row's Just-fed cell), never as an additional band multiplier.*

Every interaction in the matrix is countable and feeds DailyProgress counters (feedCount, playCount, careCount, patCount) — the Phase 1 field set only (K8; no `steps` until Phase 2, C5).

---

## 5. Quests — Design Rules & Phase 1 Catalog

### 5.1 Design rules (normative)

1. **Interaction-only in Phase 1 (D1):** every quest is completed by petting, feeding, playing, or caring — in-app interactions. Step/walk/activity quests arrive with HealthKit in Phase 2 and MUST NOT appear now.
2. **Small and achievable:** any single quest is completable in ≤ ~2 minutes of ordinary use; targets never exceed what natural use already looks like (≤ 3 plays, ≤ 2 feeds, 1 care, 3 pats).
3. **Non-manipulative:** no streaks, no catch-up penalties, no FOMO language, no completion pressure. Quests are Momo's small wishes, framed as wishes ("Momo feels like playing"), never tasks ("Don't forget to…").
4. **Always something easy (D17):** every daily set includes the low-effort anchor quest, so a user with 30 seconds can always complete something. In Phase 1 all quests are non-activity quests, satisfying D17 trivially.
5. **Bounded:** exactly 3 quests per day. No carryover, no extra quests for fast completers.
6. **Silent expiry:** unfinished wishes expire at local midnight with zero consequence — no message, no mark, no bond/mood effect (D3, D4). **Exception — per-quest windows override this general expiry:** Q1 silently expires at 12:00 local when its window closes; Q6's window is 20:00–07:00 local. **Q6 day-ownership (D20):** a tuck-in is attributed to the calendar day of its timestamp — tuck-ins completed 00:00–07:00 belong to the NEW day and can complete that day's Q6 (its window includes early morning), never the previous day's.
7. **Deterministic variation (§8):** the daily set is derived from the date via the seeded RNG (testable), with variation constraints (§5.3).

### 5.2 Phase 1 quest catalog (normative — complete list)

| ID | Quest (user-facing framing) | Target | Window | Family |
|---|---|---|---|---|
| Q1 | Morning hello — say hello to Momo | First touch of the day | Until 12:00 local | Greet |
| Q2 | Mealtime — Momo would like a meal | Feed ×1 | All day | Feed |
| Q3 | Second helping — Momo is extra hungry today | Feed ×2 | All day | Feed |
| Q4 | Playtime — Momo feels like playing | Play ×2 rounds | All day | Play |
| Q5 | Extra playful — Momo has lots of energy today | Play ×3 rounds | All day | Play |
| Q6 | Tuck-in — Momo is getting sleepy | Care ×1 (tuck in) | 20:00–07:00 local | Care |
| Q7 | Gentle pats — Momo wouldn't mind some pats | Pet ×3 | All day | Pet |

### 5.3 Daily set generation (normative)

- Each local day's set = **Q1 (anchor, always)** + **2 drawn from {Q2…Q7}** via the date-seeded RNG, subject to:
  - no duplicate quests in one set;
  - Q6 (Tuck-in) appears at least once in every 3-day window (keeps the evening anchor present);
    *Clarification (REVIEW-TASK-018, open question 1, 2026-09-09 — normative reading): the window check earns a new day Q6 credit only when BOTH prior day-sets contain Q6; unknown or missing priors count as no credit and force Q6 (so a fresh install always opens with Q6). This strong reading is normative: the invariant above holds under it, and 05 §4.8's tightest-case non-emptiness arithmetic (≥ 4 pairs) is coherent and reachable only under it.*
  - the same pair of non-anchor quests MUST NOT repeat on two consecutive days.
- Generation is deterministic given (date, seed) — required test.

### 5.4 Completion & celebration

- Completion is **automatic** on meeting the target — no claim button, no modal interruption (MAY be a subtle inline card state change + small in-scene moment + optional light haptic).
- Completing all 3 wishes MAY trigger a slightly warmer end-of-day moment; it MUST NOT gate anything or be demanded.

### 5.5 Watch quest surfacing (normative)

The Watch shows **one** quest, chosen deterministically at render time by relevance:

1. Q6 Tuck-in, if Q6 is in today's set and (local time ≥ 20:00 **or local time < 07:00**) and incomplete; *(rule 1 widened to Q6's full 20:00–07:00 window — owner-approved fix 2026-09-08, closing the 00:00–07:00 tail gap surfaced by TASK-006 as OPEN-1)*
2. else Q1 Morning hello, if local time < 12:00 and incomplete;
3. else the first incomplete feed-family quest;
4. else the first incomplete play-family quest;
5. else Q7 Gentle pats, if Q7 is in today's set and incomplete;
6. else the all-complete / nothing-selectable state ("All done — see you soon" + happy Momo).

---

## 6. Functional Requirements

Grouped A–F; acceptance criteria (AC) inline. All FRs are Phase 1 scope.

### A. First run & shell

**FR-1 — Onboarding: Meet → Name → Enter (D2).**
Exactly three steps: (1) "Meet Momo" — a short character introduction; (2) "Name" — pre-filled suggestion "Momo", editable, required non-empty (whitespace rejected); (3) "Enter" — the payoff beat ("Meet your new friend") transitioning to Home.
- AC-1: Fresh install shows exactly these 3 steps, in order, with zero system permission dialogs at any point during onboarding.
- AC-2: Killing the app before Enter restarts onboarding; after Enter, relaunch goes straight to Home.
- AC-3: The pet name is changeable later in Settings (FR-19).
- AC-4: Onboarding completes without any account, sign-in, or network activity.

**FR-2 — Home composition (3-second rule, project.md §10, P2/P3).**
Home presents: Momo as the visual focus; current mood band; current energy band; current bond stage; one contextual line; today's quest card (3 wishes + progress).
- AC-1a: On the smallest supported device (device matrix defined in TASK-006) at the default Dynamic Type size, all listed Home elements are visible without scrolling.
- AC-1b: At larger accessibility Dynamic Type sizes, all content remains fully reachable with standard scrolling and no loss of function (consistent with FR-20/NFR-6).
- AC-2: A delightful interaction (touch Momo and see a reaction) is reachable within 3 taps from app open (P3, Principle 3).
- AC-3: No numeric mood/energy/bond values and no XP-style bar appear anywhere on Home (§3.3 legibility rule).
- AC-4: Phase 1 Home contains no Collection tab and no customization entry points (D13).

**FR-3 — Room (static, D13/K4).**
One charming static room scene, reachable from Home (e.g., a tab/segment). Momo MAY be visible in the room; the room is not interactive and has no objects to acquire.
- AC-1: Room renders offline, requires no additional permissions, and contains no purchasable/interactive elements.
- AC-2: No room customization UI exists in Phase 1.

### B. Character & interaction

**FR-4 — Idle aliveness (§4, §8, K3, TR3, D16).**
Momo is alive without input: minimal state set — idle/breathing, blinking, occasional looking around, sleeping, waking, happy, eating, playing, low-energy — with controlled variation via seeded randomness so the same animation does not repeat identically day to day.
- AC-1: Opening the app 5 mornings in a row produces observable variation in idle behavior (not frame-identical).
- AC-2: All looping animation pauses when the app is backgrounded/not visible (scenePhase) and on the Watch in always-on display (D16, TR3).
- AC-3: With Reduce Motion enabled, looping idle animation is replaced by subtle static poses (D16).
- AC-4: The full 15-state inventory (project.md §4) is NOT required; the minimal set above is the Phase 1 contract (K3).

**FR-5 — Touch & petting (§4, D18).**
Tap, double-tap, long-press, and stroke/pet (where technically appropriate) each produce a distinct, gentle reaction; eyes MAY follow the touch on iPhone. Petting gives small mood uplift with same-day diminishing returns; petting banks no bond (§3.3 G2).
- AC-1: Each of the four gesture classes produces a distinguishable reaction in a Content-state Momo.
- AC-2: Petting is available in every state, including sleeping (stir + stay asleep) — never refused, never locked.
- AC-3: 10 rapid pats produce no lock, no penalty, and no mood reduction; later pats simply have smaller effect.
- AC-4: Touch zones include at least head and belly with different response characters (D9 anatomy constraint; exact zones finalized with the character in TASK-005 — OPEN-DECISION E2).

**FR-6 — Feeding (§4, D18).**
One feed interaction. Response is state-gated per §4: hungry → enjoys meal (mood+, energy+); recently fed → politely full, zero penalty. **Refinement (owner decision 2026-09-08, I-2):** within the recently-fed span, 0–30 min keeps the politely-full refusal (zero state effects); 30–90 min after a meal gets a small contented nibble — shortened eating animation, ×0.25 state effects — instead of refusing (anti-gaming preserved: the §4 repetition curve multiplies repeated feeds toward ~0). Countable for quests/DailyProgress.
- AC-1: Feeding a full Momo shows a gentle "I'm full" class of response and changes no state negatively.
- AC-2: Feeding is available at any time; no cooldown exists.
- AC-3: Each feed increments the day's feedCount (persisted across relaunch).

**FR-7 — Playing (§4, §27 "simple play", D18).**
One simple play interaction (a single short round, ~15–30 s; exact form TASK-004/TASK-005). Each round costs energy, gives mood, and counts toward play quests.
- AC-1: A round is completable in ≤ 30 s and produces a clear delightful payoff moment.
- AC-2: Round completion increments playCount; quest Q4/Q5 progress reflects it.
- AC-3: In Drowsy state, play yields the short low-key variant per §4; in sleeping state, a gentle stir only. Play is never locked.

**FR-8 — Care: Tuck in & Nap (§4, D18).**
Tuck-in is offered from 20:00 local through the night window and eases Momo toward sleep. Nap is offered when Drowsy or Exhausted. Both count as care; Q6 counts only the evening/night tuck-in.
- AC-1: Tuck-in is absent (or visibly not offered) during daytime waking hours; present from 20:00.
- AC-2: Tucking in during the Q6 window ticks Q6 exactly once per day.
- AC-3: After tuck-in, Momo transitions to settling/sleeping states consistent with the night model (FR-11).

### C. Pet state model

**FR-9 — Mood & energy model (D10).**
Internal continuous 0–100 scalars; four presentation bands each, with the cut-offs and normative rules of §3.1–3.2. UI presents bands (label + glyph + line), never raw numbers.
- AC-1: Given any mood/energy values, the presented band matches the §3 tables (property-style test over the range).
- AC-2: With no user input over simulated hours, mood eases toward 60 and never falls below 25 (D4).
- AC-3: Sustained daytime Drowsy/Exhausted state produces the §3.1 energy-coupling mood pull, which self-reverses on energy recovery.
- AC-4: No UI surface renders mood/energy/bond as numeric values.

**FR-10 — Bond model (D3, D10).**
Cumulative monotonic 0–1000; stages and thresholds per §3.3; earning strictly limited to the three daily events with the +20 cap.
- AC-1: No sequence of actions in a single local day moves bond by more than +20 (engine property test).
- AC-2: No gameplay action, absence duration, or sync conflict ever decreases bond (property test; D3). (Erase-all data deletion — FR-19 — is not a gameplay action; it is governed by FR-19 AC-2.)
- AC-3: Touch/pet volume alone (even 1000 pats) yields zero bond.
- AC-4: Crossing a stage threshold triggers a one-time stage celebration; the stage label + descriptor update everywhere (Home, Watch) at the next sync.
- AC-5: Bond stage transitions are testable deterministically via injected clock + seeded RNG (FR-13).

**FR-11 — Time model (D11, D20).**
Night window = local 22:00–07:00. Daily reset at local calendar midnight: quests reset, daily counters reset, daily bond events reset. Store UTC instants; derive "today" via the user's calendar.
- AC-1: At 21:59 local Momo is in evening states; at 22:00+ Momo transitions toward sleep; opening the app in the night window shows the sleeping response ("Shhh… Momo is sleeping") and no feed/play disruption.
- AC-2: Crossing local midnight rolls quests/counters exactly once, using the user's calendar (DST-safe).
- AC-3: The §32 edge cases (timezone change mid-day, DST transition, date rollover, clock changes) produce no duplicate resets, no lost quests, and no negative state — required engine + persistence tests.
- AC-4: All persisted timestamps are UTC; no stored value depends on local timezone.

**FR-12 — Absence & inactivity (D3, D4, §3 P4).**
The user can never cause suffering by leaving. Mood/energy drift toward their calm attractors; bond simply pauses; the return greeting is warm.
- AC-1: After 7 simulated days of no opens, mood ∈ Content band, energy restored per night model, bond unchanged, quests for those days silently empty.
- AC-2: First open after ≥ 36 h shows the warm "Momo missed you"-class greeting; the copy contains no guilt vocabulary (see tone guardrails below).
- AC-3: Absence never queues penalties, notifications, or "Momo is sad because you left" states.

**Tone guardrails (normative, applies to ALL user-facing copy in Phase 1):** no guilt ("you forgot me"), no obligation ("don't forget to…"), no countdowns/urgency, no streak language, no loss framing. §15's bad-copy list is the review checklist even though notifications are Phase 2 (PR1).

**FR-13 — Persistence, determinism & corruption safety (§21, §23, TR4, TR7, D14, D20).**
Full pet state persists locally and survives relaunch/termination. The engine is deterministic given (state, injected clock, seeded RNG). Persistence technology is TASK-006's ADR (D14); this PRD requires only the behavior.
- AC-1: Force-quit at any point (mid-interaction included) loses at most the final ≤1 second of interaction state before the force-quit.
- AC-2: A corrupted store recovers to the last valid snapshot; the pet is never destroyed by a bad write (worst case loses ≤ last snapshot interval).
- AC-3: Engine tests reproduce identical outcomes given identical (state, clock, seed).
- AC-4: Model contains Phase 1 fields only (K2, C5): no steps, no outfits, no inventory.

### D. Quests

**FR-14 — Quest catalog (D1).**
The Phase 1 quest system contains exactly the 7 quests of §5.2 — interaction-based only.
- AC-1: No quest references steps, walks, distance, or any HealthKit concept.
- AC-2: Every catalog quest is completable within its window using only §4 interactions.
- AC-3: Every daily set includes Q1 (always-achievable anchor, D17).

**FR-15 — Daily set generation (§5.3, §8, D20).**
Sets are generated deterministically from (local date, seed) with the three variation constraints.
- AC-1: Same date + seed ⇒ same set (determinism test).
- AC-2: Generated over 30 simulated days: Q6 appears ≥ once per rolling 3-day window; no identical non-anchor pair on consecutive days; always exactly 3 quests; in addition, the generator MUST guarantee these constraints by construction (TASK-006 obligation — the 30-day simulation is a sanity test, not the proof).

**FR-16 — Completion & expiry (§5.4, D3, D4).**
Automatic completion on target; silent expiry (per-quest windows per §5.1).
- AC-1: Meeting a target completes the quest within the same session without user claim action and without a modal.
- AC-2: At local midnight, unfinished quests reset with no stored record of failure and no state penalty; per-quest windows (Q1 12:00, Q6 20:00–07:00) apply as defined in §5.
- AC-3: Quest completion awards +4 bond each, respecting the +20 daily cap.

### E. Watch & sync

**FR-17 — Watch experience (§2, §12, §27; PR6).**
The Watch app shows Momo + current emotional state at a glance, today's single quest (§5.5 rule), and supports one quick affectionate interaction (pat) with a subtle haptic response. Independent value, not a phone mirror: the glance + one quick pat must stand alone.
- AC-1: From raise-to-wake to completed pat is achievable in ≤ 5 s.
- AC-2: The pat produces immediate on-wrist feedback (micro-animation + subtle haptic) even when the iPhone is unreachable (offline-first).
- AC-3: When sync is unavailable, the Watch shows last-synced state with no error state and no guilt copy (D5).
- AC-4: The Watch never displays the full pet state dashboard (one glanceable summary, §13).
- AC-5: All looping Watch animation pauses in always-on display (D16).

**FR-18 — Device-to-device sync (D5, D6, TR1).**
Phase 1 sync is device-to-device only (default transport WatchConnectivity — VERIFY-AT-BUILD in TASK-006). iPhone is authoritative. Watch-originated interactions are queued, idempotent intent events reconciled on the iPhone. No iCloud/CloudKit in Phase 1 (K7).
- AC-1: An offline Watch pat applies exactly once on the iPhone after reconnection (idempotent: replay/duplicate delivery does not double-apply).
- AC-2: Watch pat counts tick the same daily counters/quests as iPhone pats (e.g., Q7).
- AC-3: iPhone state changes (bond stage, band, quest progress) appear on the Watch at the next sync opportunity; background delivery is not assumed immediate (test: within a foreground reconnect).
- AC-4: Disconnection, stale data, conflict, and app termination/relaunch cases (§32) pass: the pet state is consistent, bond never regresses, and the user never sees a sync error.
- AC-5: No data leaves the two devices (no cloud endpoint exists in Phase 1).

### F. Platform & policy

**FR-19 — Settings (D13).**
Settings contains: rename pet; sound on/off (present only if Phase 1 ships any audio — audio scope is decided by TASK-005; otherwise the toggle is omitted); haptics on/off; "Erase all data" (with explicit confirmation); About (version, short privacy statement). It MUST NOT contain: account/sign-in, notification toggles (no notifications in Phase 1), HealthKit status (no HealthKit in Phase 1), monetization/purchase UI.
- AC-1: Every listed item functions; rename is reflected on Home and Watch after sync.
- AC-2: Erase all data deletes every local store on iPhone and resets the Watch snapshot at next sync; the app returns to the FR-1 onboarding state, fresh.
- AC-3: Settings renders correctly with VoiceOver and at large Dynamic Type sizes.

**FR-20 — Privacy, accessibility & free-product guarantees (§3 P6, §20, §25, D7, D8, D12, D19).**
- **Privacy:** all data on-device; the only outbound channel is paired-device Watch sync; no third-party SDKs of any kind; no analytics/telemetry instrumentation (D7); no location permission (D19); no HealthKit, no notifications permission in Phase 1; App Store privacy label target: **"Data Not Collected"**.
- **Accessibility (launch requirement, §20):** Dynamic Type supported without loss of function; VoiceOver labels communicate pet state in words ("Momo feels content and has plenty of energy"); pet state never communicated by color alone (glyph + label + text); Reduce Motion honored (D16); touch targets ≥ 44 pt; text contrast ≥ 4.5:1.
- **Localization (D12):** English-first; every string externalized in String Catalogs from day one; no hardcoded copy.
- **Free (D8):** zero monetization code paths — no StoreKit, no paywalls, no purchases, no ads, anywhere in Phase 1. Monetization model remains OPEN-DECISION E1.

- AC-1: A network-traffic audit of a full session (onboard → interact → sync → settings) shows traffic only between the paired iPhone and Watch.
- AC-2: The accessibility criteria above each pass a manual/automated audit on the core loop (onboard, Home, one interaction each family, quest completion, settings, Watch pat).
- AC-3: Repo/build contains no StoreKit, analytics, location, or HealthKit references.
- AC-4: All user-visible strings resolve from String Catalogs (no string literals in views).

---

## 7. Non-Functional Requirements

| # | Area | Requirement | Verification |
|---|---|---|---|
| NFR-1 | Performance | Cold launch to interactive Home ≤ 2.0 s on reference hardware (device matrix per TASK-006/D15); idle animation runs smoothly with no sustained stutter on supported devices. Measure, don't guess (§33). | Measured on-device during EPIC-002; recorded in task evidence |
| NFR-2 | Battery | No background work beyond Watch sync delivery; all idle animation pauses when not visible / on AOD (D16); Xcode energy gauge "Low" during a 10-minute idle session. | Xcode energy gauge + on-device battery trace |
| NFR-3 | Memory | Steady-state memory budget ≤ 150 MB during Home idle *(provisional; tune with TASK-005 asset decisions, TR8)* | Instruments during animation soak |
| NFR-4 | App size | Download size budget ≤ 60 MB *(provisional; depends on TASK-005 pipeline choice, TR8)* | Archive report |
| NFR-5 | Privacy | §FR-20 privacy guarantees; privacy manifest accurate; disclosures match implementation (§25, §44) | Privacy/security review task before release |
| NFR-6 | Accessibility | §FR-20 accessibility criteria are launch-blocking (not stretch) | Accessibility audit in each UI task |
| NFR-7 | Reliability | Fully functional offline (both devices); atomic saves; corruption recovery (FR-13); §32 edge-case matrix = required test set (D20), explicitly including the §32 **upgrade** edge (schema/migration on app upgrade; fresh-install vs upgrade paths) | Test suite + §32 matrix execution |
| NFR-8 | Compatibility | Latest stable shipping iOS/watchOS at build start; support current, consider N−1 (D15 policy; exact versions TASK-006). All API claims VERIFY-AT-BUILD | TASK-006 ADRs |
| NFR-9 | Watch efficiency | Watch app persists a display snapshot on every background transition (TR9) so interactions never start cold/stale | §32 termination/relaunch tests |

---

## 8. MVP Scope & Non-Goals

### 8.1 In scope — Phase 1 (per §27, verified against D13)

**iPhone:** one production-quality pet; onboarding (FR-1); Home experience (FR-2); static room (FR-3); idle aliveness (FR-4); pet interaction (FR-5); feed (FR-6); simple play (FR-7); care (FR-8); mood/energy/bond (FR-9/10); quests (FR-14–16); persistence (FR-13); settings + data deletion (FR-19).

**Apple Watch:** pet + mood/state glance (FR-17); today's quest (FR-17, §5.5); one interaction + haptic (FR-17); reliable device-to-device sync (FR-18).

**Explicitly inherited complexity calls (K-calls, binding as scope constraints):** no Collection tab (K5), static non-interactive room (K4), no App Intents (K6), no CloudKit (K7), no analytics instrumentation (K9), no notifications (K10), Phase 1 domains only: Pet, PetState, PetStateEngine, Bond, DailyProgress, Quest, Settings (K2).

### 8.2 Non-goals — product red lines (restated from §28)

Excluded unless Product Management (owner) explicitly approves otherwise: social network · chat system · follower system · public profiles · leaderboard · PvP · complex economy · loot boxes · advertisements · large backend platform · AI chatbot pet · multiplayer · dozens of pets · excessive currencies · pet death · aggressive streak mechanics.

### 8.3 Non-goals — phase discipline (correct sequencing, not abandonment)

- **Phase 2 (not now):** HealthKit steps & activity quests (D1), notifications (§15 philosophy preserved as future tone checklist), widgets & Watch complications, iCloud/CloudKit sync (only with written justification, D6), analytics instrumentation (D7), App Intents (K6).
- **Phase 3 (not now):** additional pets (pet choice returns to onboarding, D2), outfits & customization, room customization & interactive objects (§16), achievements/collections.
- **Phase 4 (not now):** sharing/postcards, premium catalog, expanded character universe.
- **Any phase, owner-gated:** location/weather (never without owner approval — E3/D19); monetization (E1); name/trademark confirmation (E4).

---

## 9. Success Metrics (D7-aware)

**Phase 1 measurement surface (normative):** App Store Connect aggregate analytics + Apple's system crash diagnostics (user-governed, OS-level) only. **No in-app analytics, no telemetry SDK, no third-party SDKs** (D7). HealthKit-derived data never leaves the device for analytics — n/a in Phase 1, and permanently true by policy.

| Question | Phase 1 answer | Target *(provisional — revisit after first cohort)* |
|---|---|---|
| Do people come back? | ASC aggregate D1/D7/D30 retention | D1 ≥ 30%, D7 ≥ 15% |
| Is it stable? | Xcode Organizer crash-free sessions | ≥ 99.5% |
| Do people love it? | App Store ratings + review text (qualitative) | ≥ 4.5 average; zero reviews citing guilt/pressure mechanics |
| Is the Watch valued? | Qualitative only in Phase 1 (reviews; §44 self-test) | — |
| Is the tone right? | Qualitative review against §44 checklist + tone guardrails (FR-12) | Pass |

**Not measurable in Phase 1 — and accepted:** interaction frequency, quest completion rate, Watch/widget adoption numbers (§34). The event taxonomy below is designed **on paper** (K9) so the Phase 2 instrumentation decision starts from an intent-respecting design, not from scratch.

**Paper taxonomy (aligned to §34; uninstrumented):** `onboarding_completed`, `pet_interacted` (family: pet/feed/play/care), `quest_completed` (quest id), `bond_stage_reached` (stage), `watch_interaction`, `day_returned` (local-day first open), `day_returned_after_absence` (≥ 36 h). Definition rules: no PII, no device identifiers, no HealthKit values as event payloads — ever (D7).

**Anti-metrics policy (PR2, normative):** session length, opens/day, and quest-pressuring KPIs MUST NOT become optimization targets. Any metric-driven change proposal passes PM review against §3 P4 and §45 first.

**Release-gate qualitative bar:** the §44 final product test is executed and answered before calling Phase 1 done (e.g., "Does Momo feel alive while idle?", "Does the product avoid guilt and manipulative engagement?").

---

## 10. Open Decisions & Cross-Task Dependencies

**OPEN-DECISION E1 — Monetization model.** Phase 1 ships free with zero monetization code paths (D8). Decision required before Phase 3 content work, not before Phase 1. This PRD invents nothing here.

**OPEN-DECISION E2 — Character direction (EARLY — flag for TASK-004 and TASK-005).** The species/character of Momo is owner-sign-off gated at TASK-005 (D9). Until then:
- This PRD references the pet only abstractly ("Momo"); no requirement presumes species-specific traits.
- TASK-004 (UX) MUST design IA, screens, and flows **character-agnostic** (pet canvas as a placeholder surface), and MUST NOT bake in unconfirmed anatomy beyond the PRD's contract: head + belly touch zones, eye-follow capability on iPhone, expressions for the FR-4 state set.
- This gate should be scheduled early precisely so TASK-004/005 don't rework flows around a late character choice.

**OPEN-DECISION E3 — Location/weather.** No location permission in any phase without owner approval (D19). Nothing in this PRD requires it.

**OPEN-DECISION E4 — Name/trademark.** "Momo" naming assumed for Phase 1; formal clearance is a TASK-007 release gate (E4).

**Downstream obligations this PRD creates:**
- TASK-004 (UX): implement §13 IA (Home, Room static, Settings), FR-2 3-second rule, bond legibility rules (§3.3), quest presentation (§5), tone guardrails (FR-12), character-agnostic flows (E2 above).
- TASK-005 (Character): FR-4 minimal state set + battery/motion constraints (TR3, TR8, D16); head/belly zones + eye-follow anatomy (D9); tone guide; asset pipeline with budget; audio scope decision (whether Phase 1 ships any audio — determines whether FR-19's sound toggle exists).
- TASK-006 (Architecture): engine spec implementing §3–§5 numbers and starting values; ADRs for D5/D6/D14/D15; §32 edge matrix (D20) with an explicit upgrade obligation (persistence schema/migration on app upgrade; fresh-install vs upgrade paths); daily-set generator MUST guarantee the §5.3 variation constraints by construction (FR-15 AC-2); VERIFY-AT-BUILD items (sync transport, API availability).

---

## Appendix A — Decision Traceability (TASK-002 D1–D20 → PRD)

All 20 review decisions are **adopted**; none challenged. Disposition:

| Decision | Disposition | Where |
|---|---|---|
| D1 interaction-only quests | Adopted | §5.2 catalog; FR-14 |
| D2 onboarding Meet→Name→Enter | Adopted | FR-1 |
| D3 bond monotonic, absence never penalizes | Adopted | §3.3; FR-10, FR-12 |
| D4 inactivity drifts to neutral-calm | Adopted | §3.1 attractor; FR-9, FR-12 |
| D5 iPhone authoritative; queued idempotent intents | Adopted | FR-18 |
| D6 device-to-device sync only | Adopted | FR-18; §8.3 |
| D7 no Phase 1 telemetry; ASC aggregate | Adopted | §9; FR-20 |
| D8 free MVP, no monetization paths | Adopted | §0; FR-20; §8.3 |
| D9 character direction in TASK-005 w/ sign-off | Adopted | §10 E2; FR-5 AC-4 |
| D10 0–100 scalars, 4 bands, 4 bond stages | Adopted — **numbers defined here** | §3.1–3.3 |
| D11 night 22:00–07:00 local; midnight reset | Adopted | FR-11; §5.2 Q6 window |
| D12 English-first, String Catalogs | Adopted | FR-20 |
| D13 IA = Home, Room static, Settings | Adopted | FR-2, FR-3, FR-19; §8.1 |
| D14 persistence via TASK-006 ADR | Adopted (behavior owned here, tech delegated) | FR-13 |
| D15 deployment policy (exact versions TASK-006) | Adopted | NFR-8 |
| D16 Reduce Motion → static poses; pause when hidden | Adopted | FR-4, FR-17; NFR-2 |
| D17 non-activity quests always present | Adopted (trivially true in Phase 1; anchor rule adds guarantee) | §5.1 rule 4; FR-14 AC-3 |
| D18 state-gated, not limit-gated | Adopted — **product semantics defined here** (engine rules delegated to TASK-006) | §4 matrix; FR-5–8 |
| D19 no location without owner approval | Adopted | §8.3; FR-20 |
| D20 UTC instants; local-calendar "today"; §32 matrix | Adopted | FR-11, FR-13; NFR-7; §5.1 (Q6 day-ownership) |

K-calls (K1–K10) inherited as scope constraints — §8.1. Relevant risks carried forward: TR1→FR-18, TR3→FR-4/NFR-2, TR8→NFR-3/4 + TASK-005, TR9→NFR-9, TR10→TASK-007 gate.

## Appendix B — §30 Coverage Checklist (K1 consolidation)

Items 1–8 (Vision, PRD, MVP scope, non-goals, personas/JTBD, core journeys, IA, screen inventory): this PRD covers 1–5 + 6 (core loop; full journeys in TASK-004); 7–8 are TASK-004's (UX architecture) and constrained here by FR-2/FR-3/FR-19 and D13. Items 9–23 are owned by Steps 3–6 deliverables (TASK-004 through TASK-007) per the review's K1 simplification.
