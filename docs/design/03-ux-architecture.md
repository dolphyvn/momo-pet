# Momo — UX Architecture (Phase 1)

| | |
|---|---|
| Task | TASK-004 — Step 3: UX Architecture (project.md §40 Step 3, §30 items 7–11) |
| Date | 2026-09-08 |
| Inputs | `project.md`, `docs/product/01-product-review.md` (D1–D20 binding), `docs/product/02-mvp-prd.md` (normative product source), `CLAUDE.md` |
| Status | REVIEWED — APPROVED_WITH_MINOR_NOTES (`.claude/tasks/reviews/REVIEW-TASK-004.md`); all MINOR + NITPICK fixes applied |
| Scope | Phase 1 only (project.md §27; PRD §8.1). Character-agnostic: the pet is a **pet canvas** placeholder until OPEN-DECISION E2 resolves (PRD §10); the only presumed anatomy is the PRD contract — head + belly touch zones, eye-follow capability, expressions for the FR-4 state set. |
| Authority | The PRD is normative. This document implements its TASK-004 obligations; where the PRD leaves UX form open (play form, bond hint presentation, quest card design), the choices are recorded in §11 and flagged for review. All copy below is intent-level; final strings live in String Catalogs (FR-20 AC-4) and pass the TASK-005 tone guide. |

---

## 0. Product principles as concrete UX rules

These rules govern every screen and flow below. They are how §3 of `project.md` and FR-2/FR-12 manifest in UI.

| Principle | UX rule |
|---|---|
| 3 seconds to understand (FR-2) | Home answers "this is my pet / how it feels / what I can do" with zero reading: pet + three state words + 2–4 labeled buttons. No numbers anywhere (FR-9 AC-4). |
| 3 taps to happiness (FR-2 AC-2) | Primary delight path is **1 tap** (touch the pet). Any interaction payoff is ≤ 3 taps from app open. |
| No punishment (§3 P4, FR-12) | No red states, no locked UI, no dead buttons, no loss/failure copy, no badges, no counters that scold. Every state-mismatched interaction is a warm variant (§4 matrix), never a refusal. |
| Pet first (§2, §10) | The pet canvas owns ≥ ~45% of Home. Controls are quiet pills, never cards competing with the scene. |
| Calm × Minimal (§18) | Exactly one contextual line at a time. No dots, persistent banners, progress rings, or notification badges anywhere in Phase 1 (M2's in-scene moment is transient, not chrome — §5.6). |
| Alive (§4, §8) | Idle behavior varies day to day via seeded randomness (FR-4 AC-1); nothing frame-identical on return visits. |
| State-gated, never limit-gated (D18) | Feed and Play are always present and always respond (never disabled). Care offerings appear contextually per the PRD §4 matrix — an unoffered chip is the matrix's own "not offered", not a lock. |

**Tone guardrails (FR-12, normative) applied to every copy suggestion in this document:** no guilt, no obligation, no countdowns/urgency, no streak language, no loss framing. §15's bad-copy list is the standing review checklist.

---

## 1. Sitemap & Screen Inventory

### 1.1 Sitemap

```
iPhone
├─ Onboarding (fresh install only; FR-1)
│   ├─ S1  Meet
│   ├─ S2  Name
│   └─ S3  Enter (payoff beat → Home)
└─ Main app (TabView, §2)
    ├─ S4  Home  — the daily loop
    ├─ S5  Room  — static scene (FR-3)
    └─ S6  Settings (FR-19)
        ├─ S6.1  Rename pet (sub-screen)
        └─ S6.2  Erase all data — confirmation alert (FR-19 AC-2)

Apple Watch (independent UX, one surface; FR-17)
└─ W1  Pet glance (pet + status words + today's quest + one pat)

Transient in-scene moments (not screens; no modals)
├─ M1  Quest completion tick (§5.4 PRD: inline card state change)
├─ M2  Bond stage celebration (once per threshold; §5.6 here)
└─ M3  All-wishes-done moment (§5.4 PRD: optional warmer moment)
```

### 1.2 Screen inventory — every Phase 1 screen, justified

| ID | Screen | Owns | Why it exists (product value) |
|----|--------|------|-------------------------------|
| S1 | Onboarding — Meet | FR-1 step 1 | First emotional beat. Establishes "this is a friend, not an app to configure" — no forms, no permissions, one line + one button. |
| S2 | Onboarding — Name | FR-1 step 2 | Naming is the seed of ownership and bond (P3's "show me this relationship is growing"). The single input Momo needs from the user, ever. |
| S3 | Onboarding — Enter | FR-1 step 3 | The payoff beat ("Meet your new friend") — the emotional handoff into Home; sets AC-2 restart semantics. |
| S4 | Home | FR-2, §2 loop | The product. Greeting, pet, state words, contextual line, interactions, today's wishes — the entire daily loop lives here. |
| S5 | Room | FR-3 | Momo has a *home*, not just a screen. Static charming scene = warmth and ownership at zero interaction cost; Phase 1's seed of §16/§17. |
| S6 | Settings | FR-19 | Trust and control: rename, sound (conditional on the TASK-005 audio-scope decision), haptics, erase-all-data, About (version + short privacy statement). Data-control features deserve an unmissable entry point. |
| S6.1 | Rename pet | FR-19 AC-1 | Rename reflected on Home and Watch after sync. |
| S6.2 | Erase confirmation | FR-19 AC-2 | Explicit confirmation before irreversible deletion; returns app to FR-1 state. |
| W1 | Watch — Pet glance | FR-17 | Momo present at the wrist; glance + one pat stands alone (§44). Independent value, not a phone mirror (PR6). |

### 1.3 Explicitly rejected surfaces (and why)

| Rejected | Reason |
|----------|--------|
| Collection tab | K5/D13 — Phase 3. |
| Quest detail screen | 3 wishes fit on Home's card (FR-2); a separate surface adds navigation without value. |
| Pet stats / detail page | FR-9 AC-4 forbids numeric state; bands already live in Home's status row. |
| Notification / permission settings screens | No notifications, no HealthKit, no permissions in Phase 1 (FR-19, FR-20). |
| Watch settings screen | Settings are owned by iPhone (FR-19) and sync to Watch (UX-13); a second settings surface is redundancy, not value. |
| Pet picker in onboarding | Phase 3 (D2) — offering one option would be dishonest. |
| Shop / monetization surfaces | D8/FR-20 — zero monetization code paths. |
| Widgets, complications | Phase 2 (§27/§8.3); reservation note only — §7. |

---

## 2. Navigation Model

**Decision UX-1 — three native tabs: Home · Room · Settings.**

```
[ Tab bar ]
┌──────────────┬──────────────┬──────────────┐
│    Home      │     Room     │   Settings   │
│ (house icon) │ (door icon)  │ (gear icon)  │
└──────────────┴──────────────┴──────────────┘
```

Rationale:

- **Matches D13 exactly** — the three approved Phase 1 areas are of equal standing; each tab is one job-to-be-done (daily loop / warmth / trust & control).
- **Native `TabView`** is the most predictable, most accessibility-ready pattern on iOS: VoiceOver, Dynamic Type, and 44 pt targets come free; zero learning cost (§18: prefer native conventions).
- **Flat IA**: no push navigation exists anywhere in Phase 1. The only modal in the product is the erase-all confirmation alert (S6.2). Quest ticks and the bond celebration are in-scene moments, deliberately *not* modals (PRD §5.4).
- **Nothing to manage**: no badges on tabs, no red dots, no counters — calm by construction (§0).

Alternatives considered and rejected:

- *2 tabs + gear icon in Home's corner*: hides a launch-blocking surface (accessibility-relevant settings, erase-all-data) behind a discovery hunt, and breaks parity with D13's "primary areas".
- *Swipe between Home and Room*: invisible affordance, poor VoiceOver story, no label to communicate the place exists.
- *Single scrolling page*: violates FR-2 AC-1a (no scroll at default type on the smallest device) and dilutes the 3-second focus.

Relaunch after onboarding always lands on Home. Tab state does not need preservation across relaunch (there is nothing mid-task to resume).

---

## 3. Onboarding — Meet → Name → Enter (FR-1, D2)

Exactly three steps, forward-only, zero system dialogs, zero network, zero accounts (FR-1 AC-1/AC-4). No progress dots — three trivial steps do not need a funnel indicator (UX-7).

### S1 — Meet

```
S1 Meet
├─ Pet canvas (center, ~50% height) — small greeting animation
├─ Line:      "This little one just moved in."
└─ Button:    "Say hello"        → advances to S2
```

- Character-agnostic copy; no species words (E2 open).
- The button advances onboarding; it is deliberately *not* a pet touch, so the daily hello (+8, §3.3) stays anchored to the first pet touch in the real app (UX-6).
- VoiceOver: canvas described ("A small creature looks up at you"), line read, button labeled.

### S2 — Name

```
S2 Name
├─ Line:      "What should your new friend be called?"
├─ Text field — pre-filled "Momo", clear button, label "Pet name"
└─ Button:    "Continue"  (enabled only when input is non-blank; whitespace rejected)
```

- Pre-filled suggestion "Momo" per FR-1; user may clear and rename anything non-blank.
- Validation is inline and gentle: the button simply stays unavailable until valid; no error copy is needed (calm). An accessibility hint on the button ("A name with at least one letter is needed") tells VoiceOver users why it is unavailable while the visual stays calm.

### S3 — Enter (payoff beat)

```
S3 Enter
├─ Pet canvas (full focus) — meet-and-greet animation
├─ Line:      "Meet your new friend."
│             "This is {name}."
└─ Button:    "Begin"   → writes onboarding-complete flag atomically → Home
```

- **AC-2 semantics:** the completion flag is persisted *at this tap* (atomic write, FR-13 AC-1). Killing the app before this tap ⇒ onboarding restarts cleanly from S1. After it, every launch goes straight to Home.
- **AC-3:** the name is changeable later in Settings → S6.1.

### Post-onboarding

Home opens with the time-aware greeting (§4); the first pet touch of the day completes Q1 and earns the day's hello (+8). Onboarding grants nothing and starts no clocks.

---

## 4. Primary Daily Flow (PRD §2)

The loop, with tap-level annotations. Time branches per FR-11 (night 22:00–07:00 local, D11).

```
1. WAKE / OPEN (morning, first open of local day)
   Launch → Home ≤ 2 s (NFR-1). Momo in a morning pose.
   Contextual line = greeting ("Good morning" class);
   ≥ 36 h since last open → warm "Momo missed you" class, same mechanics, no guilt (FR-12 AC-2).

2. SEE MOMO  (the 3-second read, FR-2)
   Pet + status words (mood · energy · ✨ bond stage) + today's wishes.
   VoiceOver reads the full state in words (§10).

3. DISCOVER TODAY'S SMALL ACTIVITY
   Quest card: today's wishes (§5.5 here). All in-scene, zero chrome.

4. USER INTERACTS — or doesn't; the loop never requires it (PRD §2.4)
   Pet touch (1 tap) → reaction + first-touch-of-day = hello (+8 bond, Q1 ticks)
   Feed / Play / care chips → §5 flows; counters tick; wishes complete inline (M1)

5. MOMO REACTS
   Animation + mood micro-uplift; energy shifts (engine-owned, TASK-006).

6. BOND / PROGRESS CHANGES
   Quest +4 each; variety bonus when all three families used; +20 daily cap (G1).
   Stage threshold crossing → M2 celebration once (deferred to next open if crossed while closed).

7. TINY REWARD
   Inline card sparkle + soft haptic; all-three-done → M3 warm line. No modal, ever (§5.4).

8. RETURN NATURALLY LATER
   Evening: Tuck-in chip present from 20:00 (Q6 line appears, UX-5); tuck Momo in → settling → sleep.
   Night open (22:00–07:00): "Shhh… Momo is sleeping"; all interactions respond per §4 matrix.
   Midnight: silent reset — new wishes, counters reset, no record of yesterday (FR-16 AC-2).
```

Branch guarantees: doing nothing for days drifts Momo toward calm (attractor 60, FR-9 AC-2), bond simply pauses (D3), and the return greeting is warm. Nothing in the flow can produce a penalty surface.

---

## 5. iPhone Interaction Flows

### 5.1 Home (S4) — structure and gesture map

```
S4 Home  (vertical budget at default type, smallest device: no scroll — FR-2 AC-1a)
├─ Status row (1 line):   {mood glyph} {mood word} · {energy glyph} {energy word} · ✨ {bond stage}
├─ Pet canvas (~45% height; character placeholder)
│   ├─ Touch zones: head (soothing register) · belly (playful register) — geometry TASK-005
│   ├─ Eye-follow: subtle tracking of the touch point (E2 capability contract)
│   └─ Gestures: tap · double-tap · long-press · stroke (below)
├─ Contextual line (1 line, rotating slot — UX-12)
├─ Action row (44 pt pills):   [ Feed ]  [ Play ]  ( [ Tuck in ] 20:00+ )  ( [ Nap ] Drowsy/Exhausted )
└─ Quest card: "Today's little wishes"
    ├─ wish 1 … glyph · wish text · soft state mark (○ pending / ● done)
    ├─ wish 2 …
    └─ wish 3 … (present when its window is open — UX-5)
[ Tab bar: Home · Room · Settings ]
```

Budget assumption (FR-2 AC-1a): the no-scroll figure above assumes each wish line renders on a single line at default Dynamic Type — wish copy is therefore a *length-constrained copy class* owned by the TASK-005 tone guide (truncation is not permitted by the calm bar; if catalog copy wraps at 375 pt width, the budget breaks). Verification against the concrete device matrix is TASK-006's obligation (§11.3).

Gesture map (FR-5; all always-available, never locked):

| Gesture | Register | Response character (Content state) |
|---|---|---|
| Tap (pat) | Gentle | Short happy reaction — the 1-tap delight path |
| Double-tap | Playful | Delighted little hop |
| Long-press | Calm | Slow lean-in, extra-warm hold |
| Stroke (drag across canvas) | Affectionate | Momo nuzzles toward the finger |
| Head zone | Soothing | Softer, melt-y variant of the gesture's response |
| Belly zone | Playful | Brighter, sillier variant |
| Eye-follow | Ambient | Eyes follow the touch point |

- Same-family repetition softens smoothly (first full, ~zero by 3rd–4th) — the button never changes, the response just quiets (D18, FR-5 AC-3).
- Petting banks zero bond in any volume (G2, FR-10 AC-3); it is expressed affection, not currency.
- VoiceOver equivalent: the canvas is one element exposing custom actions "Pat" / "Cuddle" (long-press analog); every reaction also announces a short spoken line ("Momo nuzzles into your hand") so the delight channel is not visual-only (UX-8).

Contextual line (UX-12) — one rotating slot, priority: **interaction reaction > greeting > ambient** (ambient pool may include the bond descriptor line, §5.7). All copy classes live in String Catalogs; tone-checked against FR-12.

### 5.2 Feed (FR-6)

```
Tap [ Feed ]
→ a simple meal appears in-scene (character-agnostic form — TASK-005)
→ Momo eats (eating state, FR-4 set) → content flourish
→ meal fades.  feedCount +1; feed-family wish ticks if target met (M1).
```

State variants per PRD §4 matrix (all warm, none locked):

| State | Response |
|---|---|
| Energetic / Relaxed | Enjoys the meal (mood+, energy+) |
| Drowsy | Nibbles happily, smaller effect |
| Exhausted | Sleepy nibbles, small effect |
| Sleeping | Gently declines — sleepy "zzz…" (charming, not punishing) |
| Just fed (full) | Politely full — cute refusal, tray fades, **zero penalty** (FR-6 AC-1) |

No cooldown, no portion limits, no currency (D18). Every feed counts (FR-6 AC-3).

### 5.3 Play (FR-7) — UX form (decision UX-3)

**Play is a short guided round in which Momo playfully follows the user's fingertip** — character-agnostic by construction (fingertip-follow works for any species; eye-follow is in the E2 anatomy contract). No score, no timer, no win/lose — the round is the delight (§1: not game-heavy).

```
Tap [ Play ]
→ Phase 1 · Invite (≤3 s):  Momo perks up in a play-ready pose
→ Phase 2 · Follow (10–20 s): Momo bounds/spins after the fingertip
            (passive is fine — Momo performs solo; participation is optional)
→ Phase 3 · Payoff (≤5 s): joyful flourish + soft sparkle — the clear payoff moment (FR-7 AC-1)
→ wind-down to idle.  playCount +1; play-family wish ticks (M1).
```

Rules: one round ≤ 30 s (FR-7 AC-1); a quiet "Done" pill appears after ~5 s for early exit; auto-ends regardless. State variants: Drowsy → short low-key round ending in a yawn; Exhausted/sleeping → gentle stir only. Never locked (D18).

### 5.4 Care — Tuck in & Nap (FR-8)

Offering is contextual by design — this is the §4 matrix's own "not offered" column, not a limit (D18 reconciliation: everything *offered* is always fully available; nothing offered is ever disabled).

| Chip | Appears | Flow |
|---|---|---|
| **Tuck in** | 20:00 local → through the night window (FR-8 AC-1) | Momo settles (mood+, small energy+) → transitions to sleeping per FR-11. If already asleep: a blanket-adjust moment — still counts (§4 matrix). careCount +1; Q6 ticks at most once/day (FR-8 AC-2). |
| **Nap** | Waking hours, when Drowsy or Exhausted | Momo curls up in-scene; energy restores (~+20 starting value); wakes refreshed or simply stays napping until the next open — duration owned by the engine (TASK-006). careCount +1. |

Daytime: neither chip present — the action row is simply Feed + Play, with no disabled ghosts (calm; FR-8 AC-1 "visibly not offered" ⇒ absent).

### 5.5 Quest card (FR-2, §5 PRD) — presentation (decision UX-4, UX-5)

- **Framing:** wishes, never tasks — card header "Today's little wishes"; each line uses the PRD §5.2 catalog copy verbatim ("Mealtime — Momo would like a meal"). No "Don't forget…", no deadlines, no counts-down.
- **Progress:** per-wish soft state mark only (○ → ● + gentle dim). **No aggregate fraction, no bar, no "2 of 3".** Progress is legible at a glance without reading like a checklist being graded (FR-2 "progress" honored; game framing avoided).
- **Completion (M1):** automatic on meeting the target — the line's mark fills, a tiny in-scene Momo flourish plays, optional light haptic (§5.4 PRD). No claim button, no modal, never (FR-16 AC-1).
- **All three done (M3):** the card grows a one-line warm note ("Momo had a lovely day.") with a soft sparkle. Nothing is gated or demanded (§5.4 PRD).
- **Window rendering (UX-5 — interpretation of FR-2):** a wish line renders inside its window. Q1 shows until 12:00; if uncompleted at 12:00 it quietly disappears — never "missed", never marked (silent expiry, FR-16 AC-2). Q6's line renders from 20:00 (or earlier only if already completed in the 00:00–07:00 tail). Rationale: "Momo is getting sleepy" is only *true* in the evening — Momo starts the day at energy 85 (§3.2); showing it at 09:00 would break state honesty. Consequence: a morning view of a Q6-day shows 2 wish lines; the "3 wishes" contract of FR-2 holds across the day. Flagged for reviewer confirmation (§11).
- **Midnight:** lines reset silently to the new day's set. No "new day!" fanfare required; at most the same gentle variation the rest of the product uses.

### 5.6 Celebrations (transient moments — never modals)

| Moment | Form |
|---|---|
| M1 — wish completes | Inline mark fill + tiny flourish + optional light haptic |
| M2 — bond stage crossing (FR-10 AC-4) | Calm in-scene banner over Home: "{name} and you are now {Stage}. {descriptor line}." Dismisses on tap or auto-fades ~4 s. Shown **once**; if the threshold was crossed while the app was closed, it shows at next open (UX-10). Stage word updates in the status row everywhere at next sync (Watch included). |
| M3 — all wishes done | Warm line on the card + soft sparkle (§5.5) |

Reduce Motion: celebrations become a crossfade + haptic; no flourishes (D16). VoiceOver: M2 also posts an accessibility announcement with its full line ("{name} and you are now {Stage}. {descriptor}.") so the stage moment is never visual-only; M1's completion is spoken through the quest card's done-state announcement (§10).

### 5.7 Bond legibility (PRD §3.3) — decision UX-2

**The UI shows bond as: stage word (status row) + descriptor line. There is no within-stage meter, hint, or indicator anywhere in Phase 1.**

- Stage word in the status row ("✨ Getting Close"); the descriptor line ("Momo perks up when you arrive.") surfaces in the M2 celebration, in the ambient contextual-line pool, and always in VoiceOver.
- Rationale for *no* within-stage hint: any persistent within-stage indicator on Home trends toward progress-bar reading (the exact failure §3.3 forbids), while stage arcs run 2–3 weeks — daily within-stage movement is imperceptible anyway, so the hint buys no legibility. The emotional payoff lives in the stage crossing (M2), which is celebrated. This resolves review risk PR8 in the calmest direction. A within-stage affordance (e.g., remembered-moment vignettes) is a Phase 2 revisit only if post-launch qualitative feedback shows growth feels invisible.

---

## 6. Apple Watch (FR-17, FR-18, §12 project.md)

### 6.1 The one surface (W1)

```
W1 Pet glance
├─ Status:    "Feeling happy"           (mood in words — the glance)
│             "✨ Getting Close"        (bond stage, compact secondary)
├─ Pet canvas (~40% height)  — tappable = pat (UX-11)
├─ Quest line: "{today's single wish}" or "All done — see you soon"
└─ [ Pat ] pill (full-width, ≥44 pt)   — same action as tapping the pet
```

- **One glanceable summary, never a dashboard** (FR-17 AC-4, §13): mood in words + stage word; energy is expressed through Momo's pose, not text; no numbers, no bars anywhere.
- **The single quest** is chosen by the PRD §5.5 cascade (normative there; the Watch renders its output). Quest line is display-only unless completable by pat (e.g., Q7); wishes needing iPhone actions (Q6 tuck-in) show as information, with no on-wrist claim path and no urgency copy. The quest line does not change mid-progress — Q7's line is identical at 0, 1, or 2 of 3 pats and swaps to "All done — see you soon" only on completion.
- **≤ 5 s raise-to-pat (FR-17 AC-1):** watchOS snapshot restore on launch (TR9/NFR-9) means no cold load — raise → glance is instant; one tap anywhere on the pet (or the Pat pill) completes a pat. No navigation depth exists to get lost in.

### 6.2 The pat (the one interaction)

Tap pet or Pat pill → micro-animation (distinct per pet state: happy bounce when awake; **stir + tiny heart, stays asleep** at night) + subtle haptic, immediately, on-wrist, even offline (FR-17 AC-2). Pat counts identically to iPhone pats — same counters, same quest ticks (FR-18 AC-2); petting banks zero bond (G2). If the pat is the first touch of the local day, it is the hello (+8, Q1) — device-agnostic, idempotent (UX-6; engine obligation, TASK-006).

### 6.3 Haptics rules (§12: deliberate, never spam)

| Event | Haptic |
|---|---|
| Pat (user-initiated) | Single soft tick |
| Quest completed *by an on-wrist action* (e.g., 3rd pat completes Q7) | Gentle celebratory double |
| Anything else | **Nothing.** No scheduled, background, or sync-triggered haptics in Phase 1 (no notifications exist to carry them; iPhone-side completions celebrate on the iPhone and reach the Watch silently at next sync). |

All haptics honor the Settings toggle (UX-13).

### 6.4 Offline & freshness (FR-17 AC-3, FR-18, D5)

- Offline Watch shows **last-synced state with no error, no badge, no "reconnecting", no guilt copy** — and by decision **UX-9, no freshness indicator at all**: pet state is timeless companionship, not data with a timestamp.
- Pats always work and queue as idempotent intent events; they replay exactly once on the iPhone (FR-18 AC-1). The user is never told any of this — the pat simply feels local, because it is.
- iPhone-side changes (band, stage, quest progress, name) appear at the next sync opportunity; background delivery is not assumed immediate (FR-18 AC-3). Conflicts are never user-visible (FR-18 AC-4).

### 6.5 Always-on display & lifecycle

Looping animation pauses in AOD; a static pose remains (FR-17 AC-5, D16). The display snapshot persists on every background transition so raise-to-wake never starts cold or stale (NFR-9, TR9).

---

## 7. Widgets & Complications — Phase 2 Reservation (NOT a Phase 1 surface)

**Phase 1 ships no widgets and no complications** (project.md §27 places both in Phase 2; PRD §8.3). This section records only what Phase 1 decisions enable or constrain, so Phase 2 inherits a foundation instead of a rework.

**What Phase 1 reserves for Phase 2:**

1. **A single display-state read-model.** Home, the Watch glance, and any future widget all present the same five presentation units: pet name, mood-in-words, energy-in-words, bond stage, today's single quest line. TASK-006 should define this as one derived `DisplayState` (pet-canvas-independent), so a widget timeline entry is the same DTO the Watch renders — one derivation, three surfaces. *This is the concrete architectural reservation of this document.*
2. **Words-not-numbers is portable.** The state-in-words strings (also the VoiceOver labels) are directly reusable as widget/complication copy and their accessibility labels; the tone guardrails travel with them.
3. **The §5.5 cascade is surface-portable.** "One quest, chosen deterministically at render time" is exactly the shape a precomputed WidgetKit/watchOS timeline entry needs (TR2): render the cascade at entry-build time, no reactive promises.
4. **Calm cadence suits refresh budgets.** Band crossings and stage changes are rare, day-phase-driven events (§8) — the product's natural rhythm already matches system refresh budgets. Phase 1 makes no reactive-update promise anywhere, so Phase 2 inherits no broken expectation.
5. **Glance hierarchy is already proven.** Circular/later complication = pet face (+ mood word at most); rectangular = + quest line. The §13 principle ("never the entire pet state") is enforced on W1 first and simply extends.
6. **Open Phase 2 questions, deliberately untouched:** interactive widgets (App Intents — K6 decision), complication family set, refresh policy. None may leak into Phase 1 build work.

---

## 8. Permission Flow Strategy

### 8.1 Phase 1: the strategy is ZERO permissions

Momo Phase 1 requests **no system permission, ever, on either device** (FR-1 AC-1, FR-20). This is not an omission — it is the strategy:

| Never asked in Phase 1 | Why |
|---|---|
| Notifications | Phase 2 (§27/K10). No Settings toggles exist for it (FR-19). |
| HealthKit | Phase 2 (D1/§27). Quests are interaction-only; no Settings status row exists (FR-19). |
| Location | **Any phase** without explicit owner approval (D19/E3) — a permission that can never be cleanly taken back. |
| Camera, microphone, photos, contacts, local network, tracking/ATT | Nothing in Phase 1 needs them; with zero third-party SDKs there is nothing to track (FR-20 AC-3). |

Consequences already designed in: onboarding is a permission-free three steps (§3); Settings contains no permission rows (FR-19); the App Store privacy label target is **"Data Not Collected"** (FR-20); the only network traffic ever is the paired-device sync channel (FR-20 AC-1).

### 8.2 Phase 2 contextual-ask strategy (strategy only — no screens designed)

Both future asks follow one pattern, per project.md §6/§11 and §15: **explain the value in Momo's own voice first → system dialog → graceful decline → never re-nag.** Never a wall, never at launch, never during onboarding.

- **HealthKit (Phase 2, activity quests):** the trigger is contextual — the moment activity wishes become part of Momo's world, the ask arrives framed as a gift of context, in the §11 register: "Momo would love to know when you go for a walk." Read-only scopes only. **Decline is a first-class outcome:** the app remains fully usable (§44), quest pools keep the D17 always-non-activity-anchor guarantee, and — because read-permission state is indistinguishable from no-data (TR5) — the UI never shows a "denied" state at all; empty data simply means nothing to show. No guilt, no re-ask loop; at most one quiet opt-in row in Settings.
- **Notifications (Phase 2):** requested only when companion-value content exists and the user has shown intent (e.g., choosing to enable "Morning hellos"), never as a launch dialog. Category controls per §15; strict frequency limits; the §15 good/bad copy lists become the standing review checklist (PR1/K10). Decline is silent — absence of notifications is never referenced in any surface (FR-12 AC-3 spirit).
- **Permanent policy either phase:** no HealthKit-derived data ever leaves the device for any purpose (D7); no location (D19); no third-party SDKs (FR-20). "Data Not Collected" is the standing label target for as long as these hold.

---

## 9. Empty, Failure & Offline States

Design stance: **the product has no failure surfaces.** Local-first, offline-first, and corruption-safe mean the honest states below are the complete set; nothing announces errors, data loss, or connectivity. (FR-13, FR-18 AC-4, NFR-7.)

| Scenario | iPhone UX | Watch UX |
|---|---|---|
| Fresh install, pre-onboarding | Onboarding (S1) | Calm single line: "Momo is settling in — meet Momo on iPhone." No error, no retry affordance. |
| Corrupted store (FR-13 AC-2) | **Invisible.** Recovers to last valid snapshot; worst case the pet shows a slightly older state. No dialog, no "we restored…" copy, ever. | Same — restored snapshot, indistinguishable from a normal open. |
| Force-quit mid-interaction | Relaunch ≤ 1 s of state loss (FR-13 AC-1); Momo is simply mid-moment or just after it. | Snapshot restored (NFR-9); pat available instantly. |
| ≥ 36 h absence (FR-12 AC-2) | Warm "Momo missed you"-class greeting; state per attractors; quests for absent days silently empty. Bond unchanged. | Last-synced state; warm state per snapshot; nothing references the absence. |
| Open during night window | "Shhh… Momo is sleeping"; all interactions respond per §4 matrix (stir / gentle decline / blanket-adjust). | Sleeping pose; pat = stir + heart, stays asleep; quest line may show Q6 (window open) as information. |
| Midnight / DST / timezone change / clock change (FR-11 AC-3) | Silent: new wishes appear, counters roll exactly once, no duplicates, nothing lost, nothing announced. | Same at next sync; no freshness marker exists to go stale (UX-9). |
| App upgrade (NFR-7) | Migration invisible; state preserved; fresh-install vs upgrade paths indistinguishable to the user. | Same at next sync. |
| Erase all data (FR-19 AC-2) | Confirmation alert (S6.2: "Erase everything? This deletes {name} and all memories on this iPhone; {name}'s Watch snapshot resets at its next sync. This can't be undone." — Erase / **Keep {name}**) → onboarding, fresh. | Snapshot resets at next sync → back to the settling-in line. No error. |
| Watch offline (FR-17 AC-3) | — (iPhone unaffected) | Last-synced pet + quest, fully present; pat works and queues silently (FR-18 AC-1). No stale badge, no error, no guilt copy — ever. |
| Rename not yet synced | Home shows new name immediately | Old name until next sync — acceptable, invisible, no "syncing…" UI (FR-19 AC-1 "after sync"). |
| All wishes done | M3 warm line on the card | "All done — see you soon" + happy Momo (§5.5 PRD item 6). |
| Q1 window passed uncompleted | Line quietly gone at 12:00; card shows remaining wishes. Never marked, never mentioned. | Cascade moves to the next relevant wish (§5.5 PRD). |

---

## 10. Accessibility Intent per Screen (FR-20, NFR-6 — launch-blocking)

Global commitments: pet state is **never** communicated by color alone (glyph + word + text everywhere); touch targets ≥ 44 pt; text contrast ≥ 4.5:1 against both light and dark grounds (pastel accents are decorative only — never the sole carrier of meaning); all strings — including all accessibility strings — live in String Catalogs (D12, FR-20 AC-4).

**Pet-state-in-words template (VoiceOver):** "{name} feels {mood word} and has {energy phrase}. You two are {stage}." — e.g., "Momo feels content and has plenty of energy. You two are Getting Close." Every state change that updates the status row also updates this announcement.

| Screen | Dynamic Type | VoiceOver | Reduce Motion (D16) | Color-independence | Targets / contrast |
|---|---|---|---|---|---|
| S1–S3 Onboarding | All text scales; layout reflows, buttons remain reachable | Canvas described, then line, then button; name field labeled "Pet name"; heading trait per step | Greeting/meet animations → single gentle pose + haptic | Steps carry text, not color cues | Full-width buttons; 44 pt |
| S4 Home (AC-1a/1b split) | **AC-1a:** default type, smallest supported device → no scroll (§5.1 budget). **AC-1b:** accessibility sizes → standard scroll, zero function loss; pet canvas flexes with a preserved minimum | Status row read as the state-in-words template; action row = labeled buttons ("Feed Momo", "Play with Momo", "Tuck Momo in", "Nap time"); quest card read as wishes with done/pending spoken; **pet canvas = one element with custom actions Pat / Cuddle; reactions announce spoken lines** (UX-8) | Looping idle → subtle static poses; reactions → single pose change + haptic; eye-follow → single brief glance, no tracking (UX-14); M1–M3 → crossfade + haptic | Mood/energy/stage = word + glyph + text; wish done-state = mark fill + dim + spoken state; never color-only | Action pills, card rows ≥ 44 pt; status row ≥ 4.5:1 |
| S5 Room | Scene scales; caption scales | Scene announced as one image element ("{name}'s cozy room") + caption; no actions to discover | Static already | n/a — no state encoded | n/a — nothing interactive |
| S6 Settings | Native list → free Dynamic Type support | Native rows; destructive erase clearly traited | Native | Native | Native 44 pt rows |
| S6.1 Rename | Field scales; standard keyboard flow | Field labeled, value announced, Save labeled | n/a | n/a | Standard |
| S6.2 Erase alert | System alert | System alert (traits correct) | System | System | System |
| W1 Watch glance | watchOS Dynamic Type; layout keeps pat pill reachable at largest sizes | "Momo feels {mood} and has {energy}. {Stage}. Today's wish: {wish}. Pat button." — full state in words; pat = labeled action | AOD + Reduce Motion → static pose | Mood/stage are words; quest state spoken | Pat pill ≥ 44 pt; text ≥ 4.5:1 on watch grounds |

Audit scope (FR-20 AC-2): full core loop — onboard, Home, one interaction per family, quest completion, settings, Watch pat — passes manual + automated accessibility audit before Phase 1 ships (NFR-6: launch-blocking).

---

## 11. UX Decision Log & Handoff

### 11.1 Decisions made by this document

| # | Decision | Where |
|---|----------|-------|
| UX-1 | Navigation = 3 native tabs (Home · Room · Settings); flat IA; erase alert is the only modal | §2 |
| UX-2 | Bond = stage word + descriptor; **no within-stage meter or hint anywhere**; revisit gate = post-launch qualitative feedback | §5.7 |
| UX-3 | Play = character-agnostic fingertip-follow round (≤ 30 s, participation optional, no score/timer, early-exit pill) | §5.3 |
| UX-4 | Quest card = per-wish soft marks; no aggregate fraction/bar; completion inline (M1), all-done line (M3) | §5.5 |
| UX-5 | Wish lines render inside their windows (Q6 line from 20:00) — interpretation of FR-2's "3 wishes" | §5.5 |
| UX-6 | Onboarding completion grants nothing; the daily hello = first pet touch of the local day **on either device**, idempotent (+8 once) | §3, §6.2 |
| UX-7 | No onboarding progress indicators | §3 |
| UX-8 | Pet canvas is a VoiceOver element with custom pat actions; reactions announce spoken lines | §5.1, §10 |
| UX-9 | No sync-freshness indicators on Watch — last-synced is indistinguishable from current, by design | §6.4 |
| UX-10 | Stage celebration = calm in-scene banner, shown once, deferred to next open if crossed while closed | §5.6 |
| UX-11 | Watch pat has two equivalent targets (pet canvas + Pat pill), one action | §6.1 |
| UX-12 | Contextual line = single rotating slot; priority reaction > greeting > ambient (ambient pool includes bond descriptor) | §5.1 |
| UX-13 | Settings values (haptics, sound) are app-wide and sync to Watch; no Watch settings surface | §1.3, §6.3 |
| UX-14 | Eye-follow off under Reduce Motion → single glance | §10 |

### 11.2 PRD points this document had to interpret (for reviewer attention)

1. **FR-2 "3 wishes + progress" vs. Q6's window** — resolved as UX-5 (honest-to-state rendering; 2 visible lines on a Q6-day morning). Alternative: time-neutral Q6 copy shown all day — rejected because §5.2's normative framing ("Momo is getting sleepy") would be false at 09:00.
2. **Does a Watch pat count as the daily hello?** PRD says "first touch of the local day" and FR-18 AC-2 equalizes counters — read as yes, device-agnostic, idempotent (UX-6). Engine obligation for TASK-006.
3. **D18 "always available" vs. contextual care chips** — reconciled: the §4 matrix itself gates *offering*; whatever is offered is never disabled or limited (§5.4).
4. **FR-8 "absent (or visibly not offered)"** — chose *absent*: no disabled ghost buttons (calm §0 rule).
5. **§4 "Play — just fed: (unaffected)"** — read as: play always offered; the just-fed column changes nothing about play.

### 11.3 Handoff obligations

**To TASK-005 (Character):**
- Finalize head/belly zone geometry and gesture-reaction art within the §5.1 registers (soothing/playful); support eye-follow and the FR-4 state set.
- Own the play-round motion art inside the §5.3 three-phase shell (invite/follow/payoff) and the meal/tray visual.
- Tone guide for the copy classes used here (greetings incl. absence variant, reactions per family, sleeping lines, celebration lines, wish copy is PRD-fixed).
- **Audio scope decision (PRD §10, TASK-005 obligation)** determines whether the Settings sound toggle exists (FR-19) — this document's S6 inventory updates accordingly.
- Battery/motion constraints (TR3/TR8/D16) apply to everything in §5–§6; all looping motion pauses off-screen/AOD.

**To TASK-006 (Architecture):**
- Define the single **DisplayState read-model** (name, mood words, energy words, stage, quest line) as the one derivation behind Home, W1, and reserved Phase 2 widget surfaces (§7).
- Device matrix for FR-2 AC-1a ("smallest supported device") — the §5.1 no-scroll budget is verified against it.
- Hello idempotency across devices (UX-6): first touch of the local day, either device, +8 exactly once. **Shared trigger, different windows (review MINOR-4):** the hello has no time window — it is awarded once per local day whenever the first touch occurs (PRD §3.3); Q1 ticks only if that first touch lands before 12:00 (PRD §5.2). A first touch at 14:00 still earns the +8 hello after Q1 has quietly expired — the hello must never be implemented as window-gated.
- Haptics/sound toggle sync semantics to Watch (UX-13).
- Watch snapshot restore ≤ ~2 s to protect the ≤ 5 s pat (NFR-9); corruption snapshot cadence must keep the §9 invisible-recovery contract (worst case ≤ last snapshot interval, FR-13 AC-2).
- Sync cadence for stage/quest/name changes to reach W1 "at the next sync opportunity" (FR-18 AC-3) with zero user-visible sync UI anywhere.

*End of document.*
