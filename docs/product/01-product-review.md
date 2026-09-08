# Momo — Product Review

| | |
|---|---|
| Task | TASK-002 — Step 1 Product Review (project.md §40 Step 1) |
| Date | 2026-09-08 |
| Inputs | `project.md`, `CLAUDE.md`, `.claude/tasks/status.md` |
| Status | DRAFT — pending independent review (CLAUDE.md §10) |
| Scope guard | The North Star (§45), product philosophy (§1, §3), and MVP scope protection (§27–28) are treated as fixed. This review clarifies and de-risks; it does not redefine. |

---

## 0. Executive Summary

The specification is unusually coherent. The philosophy (§1, §3), the anti-pattern lists (§15, §28), the phase discipline (§27), the edge-case test list (§32), and the final product test (§44) all pull in the same direction. Nothing found here requires changing the vision or the MVP composition.

Findings at a glance:

- **7 contradictions / inconsistencies** (C1–C7): 2 hard (quest content precedes its data source; onboarding offers a choice the MVP cannot provide), 3 tensions needing explicit reconciliation, 2 low-severity (an example-level model drift; an ambiguous engine input).
- **21 unknowns** (U1–U21): 17 resolved here with documented low-risk defaults (project.md §42), 4 escalated to the human owner (CLAUDE.md §36 criteria).
- **Unnecessary complexity**: 6 spec areas recommended for SIMPLIFY/DEFER; all deferrals are already consistent with §27 phasing — this section mainly prevents Phase 2/3 structures from leaking into Phase 1 designs.
- **Top technical risks**: Watch↔iPhone sync assumptions, WidgetKit refresh budget vs. "living window" ambition, battery cost of always-on idle animation, and the misconception that SwiftData syncs across devices.
- **Top product risks**: emotional-tone drift, retention metrics pulling against the no-guilt philosophy, inclusivity of fixed step-count quests, and an unconfirmed character direction.
- **Verdict**: no hard blocker for TASK-003 (PRD), provided the PRD honors D1, D3, D4, D6, and D10 at minimum (Section 8).

---

## 1. Contradictions and Inconsistencies

### C1 — Quest content precedes its data source (HIGH)

§7 defines quests such as "Take 3,000 steps", "Complete a short walk", and "Reach an activity milestone", and §6's daily loop includes "Discover today's small activity". §10 (Home) and §27 (Watch Phase 1: "today's quest") place the quest system in Phase 1 — but the data those quests need comes from HealthKit, which §27 schedules for Phase 2. As written, Phase 1 ships a quest surface with no deliverable health/activity quest content.

**Resolution:** D1. Phase 1 quests are interaction-based only (feed and play are §7's own examples; caring is grounded in §4's interaction list and §24's `careCount`). Step/activity quests activate with HealthKit in Phase 2.

### C2 — Onboarding offers a choice the MVP cannot provide (HIGH)

§11 step 2 is "Choose a pet" and §24's example model has a `species` field, but §27 Phase 1 mandates exactly one pet ("one production-quality pet") and places additional pets in Phase 3. Presenting a species choice with one option is either broken or dishonest.

**Resolution:** D2. Phase 1 onboarding = Meet → Name → Enter, preserving §11 step 4 ("Meet your new friend") as the payoff beat (steps 1, 3–5). The choice step returns in Phase 3.

### C3 — Watch independence vs. iPhone-authoritative state (MEDIUM)

§2 and §12 demand the Watch be designed independently, and §44 tests "Does the Watch experience provide value independently?" — yet §21 makes the iPhone the primary authoritative pet state, and §32 requires tests for "Watch → iPhone interaction", i.e., the Watch writes state. These are reconcilable but only with an explicit model; left implicit, later agents will improvise conflicting ones.

**Resolution:** D5. Independent *UX*, single *source of truth*: Watch writes are queued, idempotent intent events reconciled on the iPhone; offline Watch shows last-synced state. Final mechanism is an ADR in TASK-006.

### C4 — "Sync" conflates device sync and cloud sync (MEDIUM)

§27 Phase 1 requires Watch "reliable synchronization" and §30 requires a "Sync strategy" document before implementation, yet §27 Phase 2 lists "robust iCloud/sync if justified" and §21 says "CloudKit/iCloud where justified". A literal reader can conclude all sync is Phase 2 — which would silently violate the Phase 1 Watch contract.

**Resolution:** D6. Phase 1 sync scope = device-to-device (WatchConnectivity as default direction, VERIFY-AT-BUILD). iCloud/CloudKit is a Phase 2 decision with a written justification gate. "Sync strategy" (§30 item 19) covers device sync for Phase 1.

### C5 — Example data model runs ahead of MVP scope (LOW)

§24's `DailyProgress.steps` requires HealthKit (Phase 2, §27) and `Pet.outfit` belongs to Phase 3 (§27). §24 explicitly warns "Do not blindly implement this example", so this is not a real defect — but the fields invite Phase-1 modeling of Phase-2/3 data.

**Resolution:** noted for TASK-006: model Phase 1 fields only; make future fields explicit extension points rather than present-but-empty columns.

### C6 — Retention analytics vs. minimal-data, no-backend MVP (MEDIUM)

§34 requires measuring D1/D7/D30 retention, but §3 Principle 6 mandates minimum data collection, §21 mandates local-first with "do not add a backend merely because one can be built", and cross-day retention measurement inherently requires a persistent identifier and somewhere to aggregate events. The spec does not say how these coexist, and §34's own "Minimize personal data" does not resolve it.

**Resolution:** D7. No analytics SDK or telemetry in Phase 1; the §30 item 21 taxonomy is designed on paper only. Retention instrumentation is a Phase 2 decision with a pseudonymous, no-PII design. Stricter than §34: no HealthKit-derived data ever leaves the device for analytics.

### C7 — "Sleep period" engine input is ambiguous (LOW)

§23 lists "sleep period" among engine inputs. Read one way it is a time-of-day window (consistent with §8); read another it implies HealthKit sleep analysis — which would contradict §27 phasing and §25's data-minimization posture.

**Resolution:** D11. "Sleep period" = the local-time night window, not HealthKit sleep data.

### Clarifications — apparent contradictions the spec already resolves

Recorded so later agents do not "fix" non-problems:

- **§8 vs. §23 (determinism).** §8 forbids fully deterministic behavior; §23 demands determinism "where tests require". These compose: the engine is deterministic *given a seed and a time input*; randomness is injectable (seeded RNG, injected clock). Not a contradiction.
- **§12 vs. §13 (Watch status).** §12 allows Mood/Energy/Bond on Watch "where useful"; §13 forbids displaying "the entire pet state". Consistent: one glanceable summary, never a dashboard.
- **§26 vs. §28 (characters).** Premium "additional characters" does not violate the "dozens of pets" non-goal; the non-goal targets unbounded catalog sprawl, not staged expansion.

---

## 2. Unknowns and Open Questions

Classification per project.md §42 and CLAUDE.md §36: **RESOLVED** = decided here with a documented low-risk, reversible default (see Section 6); **ESCALATED** = product-defining, privacy-sensitive, expensive-to-reverse, or monetization-related, so it goes to the human owner (Section 7).

| ID | Open question | Raised by | Classification |
|----|---------------|-----------|----------------|
| U1 | What quest content exists in Phase 1 without HealthKit? | §6, §7, §27 | RESOLVED → D1 |
| U2 | How does "Choose a pet" work with one pet? | §11, §24, §27 | RESOLVED → D2 |
| U3 | Can Bond decrease? What does absence cost? | §3 P4, §5 | RESOLVED → D3 |
| U4 | How do mood/energy behave during user inactivity? | §3 P4 ("Momo missed you"), §23 | RESOLVED → D4 |
| U5 | How are iPhone/Watch state conflicts resolved? | §2, §21, §32 | RESOLVED → D5 (principle; ADR in TASK-006) |
| U6 | What is the Phase 1 sync transport? | §21, §27 | RESOLVED → D6 |
| U7 | When (if ever) does iCloud/CloudKit enter? | §21, §27 | RESOLVED → D6 |
| U8 | Which analytics approach satisfies §34 without violating §3 P6/§21? | §34 | RESOLVED → D7 |
| U9 | Monetization model: lifetime vs. subscription vs. packs | §26 | ESCALATED → E1 |
| U10 | What species/character *is* Momo? | §4, §11, §24 | ESCALATED → E2 (gate at TASK-005) |
| U11 | Location/weather features and their permission | §9, §25 | ESCALATED → E3 (hard privacy gate) |
| U12 | Is "Momo" clear to use as a product name? | §1 (name), release risk | ESCALATED → E4 (gate at release, TASK-007) |
| U13 | What defines "night"? What did §23 mean by "sleep period"? | §8, §23 | RESOLVED → D11 |
| U14 | Mood/energy scales and bond stage thresholds | §5, §23 | RESOLVED → D10 (numbers set in TASK-003) |
| U15 | Languages/localization for dialogue | §4, §8, §23 (dialogue output) | RESOLVED → D12 |
| U16 | Which iPhone tabs exist in Phase 1? | §10, §27 | RESOLVED → D13 |
| U17 | Persistence technology | §21, §24 | RESOLVED → D14 (default direction; TASK-006 ADR is binding) |
| U18 | Minimum deployment targets / OS versions | §21 | RESOLVED → D15 (policy; exact versions in TASK-006) |
| U19 | What does Reduce Motion do to the pet? | §20 | RESOLVED → D16 |
| U20 | Are fixed step targets acceptable for all users? | §7 | RESOLVED → D17 |
| U21 | How is feed-spam prevented without limits/currency? | §6, §28 | RESOLVED → D18 |

Every open question is either resolved-with-default or escalated; none is left implicit.

---

## 3. Unnecessary Complexity (KEEP / SIMPLIFY / DEFER)

Calls use §27 phasing, §22 ("keep architecture proportional"), §30 ("do not create documentation merely for volume"), and §44 ("would removing any feature make the product simpler…?") as authority.

| # | Area | Spec | Call | Rationale |
|---|------|------|------|-----------|
| K1 | 23 required documents | §30 | **SIMPLIFY** | Do not produce 23 artifacts. Consolidate into the five Phase-0 deliverables (Steps 2–6 of §40) plus ADRs; treat the §30 list as a *coverage checklist* each deliverable must tick. |
| K2 | 14 conceptual domains | §22 | **SIMPLIFY** | Phase 1 modeled domains: Pet, PetState, PetStateEngine, Bond, DailyProgress, Quest, Settings. DEFER modeling of Inventory, Customization, Room-as-domain (Phase 3 per §27); Notification is a Phase 2 thin wrapper (§27). Sync stays Phase 1 (D6). |
| K3 | Character state inventory (14 states) | §4, §19 | **KEEP intent, SIMPLIFY MVP set** | The aliveness goal (§1, §44) needs idle/breathing/blinking/sleeping/happy/eating/playing/low-energy plus touch reactions. Full inventory is specified in TASK-005; Phase 1 ships the minimal set above. |
| K4 | Room objects and interactivity | §16 | **DEFER** | §27 Phase 1 says "basic room": ship a static, charming scene. Interactive objects and the §16 object list are Phase 3 (§27 room customization). |
| K5 | Collection tab | §10 | **DEFER** | §27 puts achievements/collections in Phase 3. Phase 1 IA per D13 (Home, Room, Settings) — trimming §10's "primary areas" list. |
| K6 | App Intents | §21 | **DEFER** | No consumer exists in the MVP. Revisit only when interactive widgets land (Phase 2, §14). |
| K7 | CloudKit/iCloud | §21, §27 | **DEFER** | Per D6. Local-first MVP (§21) has no cloud requirement with one iPhone + one Watch. |
| K8 | DailyProgress counters | §24 | **KEEP** | Small, cheap, directly feeds quests and the engine (§23). `steps` stays nil until Phase 2 (see C5). |
| K9 | Analytics event taxonomy | §34 | **KEEP design, DEFER instrumentation** | Per D7: design on paper now; no SDK in Phase 1. |
| K10 | Notifications | §15 | **KEEP philosophy, DEFER to Phase 2** | Matches §27 exactly. The philosophy text also becomes the tone checklist for Phase 2 implementation review. |

No KEEP/SIMPLIFY/DEFER recommendation touches the North Star (§45) or the Phase 1 experience set (§27).

---

## 4. Technical Risks (Apple Platform)

Dating note: today is 2026-09; Apple ships a new major OS generation each September, so exact version numbers must not be pinned in a document task. Per §21 ("verify APIs and deployment requirements against current official Apple documentation"), uncertain API claims below are marked **VERIFY-AT-BUILD** and resolved in TASK-006.

- **TR1 — Watch↔iPhone sync is the highest-risk subsystem.** §27 requires Phase 1 "reliable synchronization" and §32 requires disconnection/staleness/conflict tests. Pitfalls: background delivery is not immediate; `updateApplicationContext` delivers only the latest snapshot (fine for state, wrong for interaction events); transfers can duplicate or arrive out of order. Mitigation per D5: idempotent queued intent events + last-synced display state. Transport default WatchConnectivity — **VERIFY-AT-BUILD** (ADR, TASK-006).
- **TR2 — WidgetKit refresh budget vs. "living window".** §2 and §14 want widgets that feel present; WidgetKit reloads are system-budgeted (order of dozens per day for well-used apps) and pre-computed timeline entries are the real mechanism for time-of-day changes (§8). Do not promise reactive mood updates. Schedule timeline entries at day-phase boundaries; interactive widgets (App Intents) can trigger updates — **VERIFY-AT-BUILD** for current-generation support on iOS and watchOS.
- **TR3 — Battery cost of the idle animation.** §19 and §33 both demand battery efficiency. Infinite breathing/blink loops must pause when the scene is not active (`scenePhase`) and on the Watch in always-on display mode. This constraint must be stated in the motion spec (TASK-005) before assets are produced, or it will be retrofitted.
- **TR4 — SwiftData does not sync devices** (§21 local-first; §27 Phase 2 "robust iCloud/sync if justified"). SwiftData (iOS 17+/watchOS 10+ era APIs) has no device-to-device sync without CloudKit. Two separate stores on iPhone and Watch are just that. The sync layer must move DTOs, never assume shared storage. Also: SwiftData may be more machinery than a one-pet data volume needs — a plain Codable file store is a legitimate fallback (D14) — **VERIFY-AT-BUILD** on current watchOS maturity (ADR, TASK-006).
- **TR5 — HealthKit realities (Phase 2, but plan early).** (a) Data arrives late and retroactively — Watch-recorded steps sync to iPhone minutes-to-hours later, and statistics can be revised; quest completion must tolerate same-day retroactive fulfillment. (b) Read-permission state is intentionally opaque: "denied" and "no data" are indistinguishable — the UI must treat empty data gracefully (maps to §32 "no Health permission" and §44 "useful when HealthKit is denied"). (c) Background delivery requires a specific background mode. (d) HealthKit data cannot be shared to third parties — reinforces D7. Resolved in the TASK-006 HealthKit strategy.
- **TR6 — API availability and version churn.** The 2026 fall OS releases are imminent or fresh at build time; every availability assumption (widget capabilities, watchOS frameworks, Observation, Swift 6 strict concurrency semantics) carries **VERIFY-AT-BUILD**. Design impact now: model the engine as `Sendable` value types with an injected clock and seeded RNG (§23) so it survives strict concurrency checking unchanged.
- **TR7 — Time, timezone, DST, and clock manipulation.** §32 already lists timezone/DST/rollover edge cases — adopt as-is (D20). Store UTC instants; derive "today" through the user's calendar. Clock manipulation ("time travel" farming of quests/bond) is low-stakes because there is no currency (§28), but the engine should anchor to monotonic references where practical. TASK-006 detail.
- **TR8 — Asset pipeline weight.** §33 requires attention to asset sizes; the character/motion pipeline choice (vector-drawn SwiftUI vs. pre-rendered frames) made in TASK-005 drives memory, battery (TR3), and app size. Decide pipeline with a budget before producing assets.
- **TR9 — Watch app lifecycle.** watchOS suspends and terminates apps aggressively; the Watch must persist a display snapshot on every background transition or the "few seconds" interaction (§2) starts cold and stale. §32's termination/relaunch tests cover it — implementation must not defer snapshotting.
- **TR10 — Toolchain availability.** `.claude/tasks/status.md` records Xcode availability as unverified on this machine. Irrelevant for Phase 0; must be verified before EPIC-002 build work.

---

## 5. Product Risks

- **PR1 — Emotional-tone drift.** Dialogue and micro-animation *are* the product (§1, §4, §19); one line of cringe copy or one hyperactive animation breaks "Calm × Premium" faster than any missing feature. Mitigation: character bible + copy tone guide in TASK-005, and a tone check as a standing review-gate item (§15's good/bad lists are the seed).
- **PR2 — Metrics pulling against philosophy.** §34's retention/engagement measurements exist to answer questions, but the moment they become targets, the product drifts toward the "Addictive" pole §1 forbids and §45 rejects. Mitigation: D7 (no Phase 1 instrumentation), explicit anti-metrics policy (no streak-loss mechanics, no guilt copy — §3 P4, §15), and PM review of any metric-driven change.
- **PR3 — Manipulative-engagement creep via quests.** §7 calls quests "an important retention mechanism" — the phrase itself is the risk. Guardrails: D1 (small, honest quest set), D3 (bond never punishes), D18 (no limit/currency gates), §28's "aggressive streak mechanics" non-goal, and §15's bad-copy list as review criteria.
- **PR4 — Inclusivity of health quests.** A fixed "Take 3,000 steps" (§7) excludes users with mobility impairments and reads as obligation. Mitigation: D17 — quest pools include non-activity quests; step targets adaptive or lenient when HealthKit arrives.
- **PR5 — Childish drift vs. premium feel.** Pastel + cute is one lazy decision away from "Childish", the first forbidden word in §1. §18's typographic and restraint rules are the defense; enforce them in design review, not just in the doc.
- **PR6 — Watch value ambiguity.** If the Watch is only a mirror of the phone, users disable it (§44 demands independent value). The single interaction (§27) must be genuinely delightful on-wrist; this is a design-quality risk, flagged for TASK-004/TASK-005.
- **PR7 — Scope creep vectors.** In rough order of likelihood: AI-chat features (post-LLM-era temptation; §28 excludes "AI chatbot pet"), weather/location (§9; gated by E3), pet count multiplying asset cost in Phase 3 (§27), sharing/postcards (Phase 4, §27). All pass through §38's KEEP/LATER/REJECT gate with the PM owning it — this review adds: any weather feature requires the E3 owner gate first.
- **PR8 — Bond-progress legibility.** §5 wants progression that feels "relational rather than like conventional XP grinding" — but invisible progress frustrates and visible progress bars game-ify. Resolving this tension is a genuine TASK-003/TASK-004 design problem, flagged here so it is not improvised.
- **PR9 — Single-pet depth over time.** One pet plus a static room must hold interest between Phase 1 and Phase 3 content. Not MVP-blocking; the Phase 2 plan (notifications, quests, widgets) carries cadence. Record as a roadmap consideration for TASK-007.

---

## 6. Decisions Log

Autonomous defaults per project.md §42. These are binding inputs to TASK-003 through TASK-007; the orchestrator mirrors them into `.claude/tasks/status.md`. Nothing here contradicts the North Star (§45) or §27–28.

- **D1 — Phase 1 quests are interaction-based only** (feed, play, care). Step/walk/activity quests ship in Phase 2 with HealthKit. Resolves C1.
- **D2 — Phase 1 onboarding = Meet → Name → Enter.** §11 steps 1, 3–5, with step 4 ("Meet your new friend") preserved as the payoff beat inside Enter; the "Choose a pet" step (§11) activates in Phase 3 with additional pets. Resolves C2.
- **D3 — Bond is monotonic.** It never decreases. Absence freezes growth; it never costs progress. "Momo missed you" (§3 P4) is a warm greeting referencing absence, not a state penalty. This is the operational reading of Principle 4 for §5.
- **D4 — Inactivity drifts mood/energy toward neutral-calm, never toward distress.** The user can never cause suffering by leaving; the engine must not manufacture guilt. Exact drift rates are set in the TASK-006 engine spec.
- **D5 — Conflict-resolution principle:** iPhone is authoritative (§21); Watch-originated interactions are queued, idempotent intent events; the offline Watch shows last-synced state. Independent UX, single truth. Mechanism finalized in a TASK-006 ADR. Resolves C3.
- **D6 — Phase 1 sync is device-to-device only** (default direction: WatchConnectivity, VERIFY-AT-BUILD). No CloudKit in the MVP; iCloud is a Phase 2 decision requiring a written justification. Resolves C4/U6/U7.
- **D7 — No analytics SDK or telemetry in Phase 1.** The §30 item 21 taxonomy is designed on paper only. Retention instrumentation is a Phase 2 decision with a pseudonymous, no-PII cohort design. Note: App Store Connect provides aggregate D1/D7/D30 retention with zero in-app instrumentation, partially answering §34 in Phase 1 without breaching this rule. Stricter than §34: HealthKit-derived data never leaves the device for analytics, ever. Resolves C6/U8.
- **D8 — The MVP ships entirely free** with zero monetization code paths, honoring §26 ("do not optimize monetization before emotional product quality"). The §26 model choice is escalated (E1) and needed before Phase 3, not before Phase 1.
- **D9 — Character direction is produced in TASK-005 with owner sign-off** (E2). The spec does not define the species (§4, §24 `species`); §19's "ear/tail movement" implies an animal form, and the anatomy must support §4's head/belly touch zones and eye-follow on iPhone.
- **D10 — State scales:** mood and energy are continuous 0–100 scalars internally with four presentation bands for UI; bond is monotonic progress across §5's four named stages (New Friends → Getting Close → Best Friends → Soul Companions). Numeric thresholds and band cut-offs are defined in TASK-003.
- **D11 — Night window defaults to local 22:00–07:00** (user-adjustable later). Daily reset at local calendar midnight. §23's "sleep period" means this time window, not HealthKit sleep analysis. Resolves C7/U13.
- **D12 — English-first, localization-ready.** All dialogue and UI strings externalized via String Catalogs from day one; additional languages deferred.
- **D13 — Phase 1 iPhone IA = Home, Room (static "basic room"), Settings.** Collection tab, room customization, and interactive room objects defer to Phase 3. Watch = pet state + one interaction + today's (interaction) quest + haptic response (§27). Trims §10 against §27.
- **D14 — Persistence default direction for the TASK-006 ADR:** SwiftData, *or* a plain Codable file store if SwiftData adds no value at this data volume (one pet, small daily records). Either way, sync transfers DTOs, never raw stores (TR4). VERIFY-AT-BUILD. The ADR, not this review, is binding.
- **D15 — Deployment targets:** exact versions chosen in the TASK-006 ADR under the policy "latest stable shipping OS at build start; support current, consider N-1". All API availability claims VERIFY-AT-BUILD per §21.
- **D16 — Reduce Motion behavior:** looping idle animation is replaced with subtle static poses; all animation pauses when the app is not visible or the Watch is in always-on display. Accessibility (§20) is launch scope, including non-color state communication.
- **D17 — Quest inclusivity:** the quest pool always includes non-activity quests; step targets are adaptive or lenient when HealthKit arrives in Phase 2.
- **D18 — Interactions are state-gated, not limit-gated.** A full or sleeping Momo responds differently to feeding; there are no cooldown timers, no currencies, no rejection as punishment (§3 P4, §6, §28). Exact rules in the engine spec (TASK-006).
- **D19 — No location permission in any phase without explicit owner approval.** §9's weather/seasonal features are permanently gated behind that approval (§25, E3).
- **D20 — Time handling:** store UTC instants; derive "today" via the user's calendar; adopt §32's timezone/DST/rollover edge cases as a required test matrix for the engine and persistence layers.

---

## 7. Escalations to the Human Owner

Per CLAUDE.md §36 and project.md §42 (steps 3–4). Each states why it exceeds autonomous authority and what the team does meanwhile.

- **E1 — Monetization model (§26).** Lifetime vs. subscription vs. cosmetic packs is product-defining and monetization-related. **Meanwhile:** no cost to Phase 1 (D8); decision needed before Phase 3 content work. Recommend deciding no earlier than after Phase 1 quality is proven, per §26's own ordering.
- **E2 — Character/species direction (§4, §11, §24).** The identity of Momo is the single most product-defining choice in the spec, and §29 assigns it to Character Design — but final direction warrants owner sign-off. **Meanwhile:** TASK-005 prepares 2–3 character directions with anatomy constraints (D9); owner picks one. This gate should be scheduled *early*, since TASK-004 (UX) and the PRD reference the character.
- **E3 — Location/weather features (§9, §25).** Privacy-sensitive; a location permission request can never be taken back cleanly. **Meanwhile:** Phase 3 only, and only after approval (D19). Nothing in Phases 1–2 needs location.
- **E4 — "Momo" name/trademark clearance.** The name is load-bearing brand equity; a post-launch rename is expensive-to-reverse. **Meanwhile:** non-blocking for Phase 0–1 development; formal clearance (app-store collision + trademark search) gated at release planning in TASK-007.

---

## 8. Handoff to TASK-003 (PRD)

**No hard blocker.** The PRD can be written now provided it:

1. Honors D1 (interaction-only quest catalog for Phase 1), D3/D4 (no-penalty state semantics), D6 (device sync in Phase 1), D8 (free MVP), D10 (scale/threshold definitions — the PRD owns the numbers), D11 (day/night windows), D13 (IA).
2. Defines concretely: the Phase 1 quest catalog, bond thresholds and curve, mood/energy band cut-offs, and product-level interaction semantics under D18 (the exact engine rules per D18 remain in TASK-006).
3. States monetization as "free at launch; model under decision E1" and non-goals by restating §28.
4. Flags E2 (character direction) as an early TASK-005 dependency so UX flows do not presume an unconfirmed character.
5. Inherits the complexity calls of Section 3 as scope constraints (no Collection tab, static room, no App Intents, no cloud, no analytics instrumentation in Phase 1).

**Successor task notes:** TASK-005 must include the battery/motion constraints (TR3, TR8, D16); TASK-006 must produce ADRs for D5/D6/D14/D15 and resolve TR1/TR2/TR5 with VERIFY-AT-BUILD checks; TASK-007 must include E4 clearance and the TR10 toolchain verification gate.
