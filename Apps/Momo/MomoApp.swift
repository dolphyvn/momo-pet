import SwiftUI
import Foundation
import MomoCore

/// Momo (iPhone) app entry point (TASK-009 placeholder shell; TASK-031 wires
/// the app model behind it; TASK-032 adds the onboarding gate).
///
/// The app model facade's thin executor (`MomoAppModel`) is constructed here
/// — its launch read (the one sanctioned synchronous main-thread I/O, 05
/// §5.2) happens at that construction — published into the environment as
/// the shell's only state source (D-R5: views never invoke the engine), and
/// handed `scenePhase` so the §4.2 trigger table's foreground/background
/// behavior is driven. The WatchConnectivity iPhone-side session lands in
/// EPIC-008. This target's permitted package edges (MomoCore + MomoCharacter
/// + MomoKit; never MomoWatch — D-R3) are wired as product dependencies in
/// the project's Frameworks phase.
///
/// **The gate (TASK-032 R1; UX §3 post-onboarding; FR-1 AC-2).** The ONLY
/// state that routes is `settings.onboardingComplete`, surfaced as the app
/// model's `requiresOnboarding`: false → the three-step onboarding flow
/// (S1 Meet → S2 Name → S3 Enter), true → `RootTabView`. A fresh store AND
/// an invisibly-recovered store both read false — §5.3's
/// indistinguishable-recovery stance; SwiftUI re-evaluates the branch from
/// the same observable state the completion write flips.
@main
struct MomoApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var appModel = {
        let time = MomoApp.fixedTimeSources()
        return MomoAppModel(
            storeDirectory: MomoApp.testStoreDirectory(),
            clock: time.clock,
            calendar: time.calendar,
            freshDefault: MomoApp.fixtureDefaultState(clock: time.clock, calendar: time.calendar)
        )
    }()

    var body: some Scene {
        WindowGroup {
            Group {
                if appModel.requiresOnboarding {
                    OnboardingFlow()
                } else {
                    RootTabView()
                }
            }
            .environment(appModel)
            .onChange(of: scenePhase) { _, phase in
                appModel.scenePhaseChanged(to: phase)
            }
            .task {
                // §4.2's launch open (TASK-033 discovery, disclosed): by the
                // time this shell's onChange(of: scenePhase) is installed,
                // the scene is already .active — the changed-value contract
                // never fires, so a cold launch never evaluated: no first
                // day record, no greeting flow, an empty Home quest card
                // until the next phase change. Reading the CURRENT phase at
                // first appearance closes the gap; a genuine later change
                // still rides onChange, and a double-fire folds nothing
                // (folds are forward-only — the second is zero-elapsed).
                appModel.scenePhaseChanged(to: scenePhase)
            }
        }
    }

    // MARK: The UI-test clock enabler (TASK-033 R7, disclosed)

    /// The R7 deterministic UI-test enabler: a `-momo-fixed-clock
    /// <ISO-8601-UTC>` launch argument freezes the app's time FOR THAT
    /// LAUNCH, so MomoUITests pin the local-hour-governed Home surfaces —
    /// the quest windows, the action-row windows, the time-slot line — at
    /// chosen hours (e.g. 09:00 vs 20:30) regardless of when or where the
    /// suite runs. Production launches never pass the argument and run on
    /// the system clock and calendar as before. DEBUG-only: release builds
    /// ignore the argument entirely.
    ///
    /// The enabler reuses MomoCore's `ManualEngineClock` (05 §4.10's
    /// manually-settable test clock — inert outside tests) seeded with the
    /// parsed instant; an UNPARSEABLE or MISSING value is an invariant
    /// regression — DEBUG-loud (`assertionFailure`, the MomoCopy discipline;
    /// REVIEW-TASK-033 NITPICK-1 closed the missing-value hole) — and falls
    /// back to the system clock so the session stays functional.
    ///
    /// When the flag is present, the injected calendar is ALSO pinned to
    /// UTC: the Home windows are LOCAL-hour governed (D11's night window,
    /// the quest windows, the copy slots), so pinning the instant alone
    /// would leave them hostage to the host simulator's timezone. UTC
    /// instant + UTC calendar makes 09:00Z read as 09:00 local on any host.
    private static func fixedTimeSources() -> (clock: any EngineClock, calendar: Calendar) {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-momo-fixed-clock") else {
            return (SystemEngineClock(), .current)
        }
        guard index + 1 < arguments.count else {
            // REVIEW-TASK-033 NITPICK-1: a flag WITHOUT a value is the same
            // invariant regression as an unparseable one — DEBUG-loud, not a
            // silent system-clock ride (which would flake the hour-governed
            // windows the suite pins).
            assertionFailure("MomoApp: -momo-fixed-clock present without a value — falling back to the system clock")
            return (SystemEngineClock(), .current)
        }
        let raw = arguments[index + 1]
        if let instant = ISO8601DateFormatter().date(from: raw) {
            var utc = Calendar(identifier: .gregorian)
            utc.timeZone = TimeZone(identifier: "UTC")!
            return (ManualEngineClock(at: instant), utc)
        }
        assertionFailure("MomoApp: -momo-fixed-clock value '\(raw)' is not ISO-8601 UTC — falling back to the system clock")
        #endif
        return (SystemEngineClock(), .current)
    }

    // MARK: The UI-test fixture enabler (TASK-036 R10, disclosed)

    /// The R10 verify-before-trust enabler: a `-momo-fixture <kind>` launch
    /// argument serves a FIXTURE engine state as the store's fresh default
    /// FOR THAT LAUNCH, so MomoUITests can drive the bond/quest surfaces no
    /// fixed-clock interaction sequence can reach (bond crossing 150 in one
    /// tap needs ~139 banked bond; the day's wishes all done needs three
    /// interactions across mutually exclusive windows — Q1 closes at 12:00
    /// before Q6's 20:00 onset). Production launches never pass the
    /// argument and get the onboarding carrier as before. DEBUG-only.
    ///
    /// **Why a fixture STATE, not a fixture STORE (the honest adaptation
    /// the task contract anticipated):** the store-file handoff is
    /// infeasible — the runner and the app-under-test live in different
    /// sandboxes (`testStoreDirectory`'s own doc), so the runner cannot
    /// place a pre-seeded store file the app will read. The fixture rides
    /// the EXISTING injected-fresh-default parameter (05 §5.3 — "the
    /// caller's to inject") on a THROWAWAY store: a fresh store serves the
    /// fixture as the load fallback, exactly the §5.3 fresh path.
    ///
    /// Kinds: `stage-crossing` — bond 149, the day's fresh [Q1, Q2, Q6]
    /// set, hello NOT yet awarded: one pat awards the hello (+8), crosses
    /// 150, completes Q1, and mints `.bondStageReached` + `.questCompleted`
    /// in ONE interaction (the full M1+M2 fan-out). `all-done` — the day's
    /// wishes all complete, so the §4.8 cascade reads `.allDone` and the
    /// card carries the M3 warm note from the first frame.
    private static func fixtureDefaultState(
        clock: any EngineClock,
        calendar: Calendar
    ) -> EngineState? {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-momo-fixture"),
            index + 1 < arguments.count
        else { return nil }
        let now = clock.now()
        let dayKey = DayKey.make(from: now, calendar: calendar)
        func quest(_ id: QuestID, progress: Int, completed: Bool) -> QuestProgress {
            // Unreachable with catalog targets: every fixture below stays
            // within a target's 0...target band (INV-6).
            QuestProgress(questID: id, progress: progress, completed: completed)!
        }
        switch arguments[index + 1] {
        case "stage-crossing":
            return EngineState(
                pet: Pet(id: UUID(), name: "Momo", createdAt: now)!,
                state: PetState(
                    mood: 70, energy: 80, bond: 149,
                    wakefulness: .awake, activity: nil,
                    lastFedAt: nil, satietyPhase: .hungry
                )!,
                days: [DayRecord(
                    dayKey: dayKey,
                    feedCount: 0, playCount: 0, careCount: 0, patCount: 0,
                    questSet: [
                        quest(.q1, progress: 0, completed: false),
                        quest(.q2, progress: 0, completed: false),
                        quest(.q6, progress: 0, completed: false),
                    ],
                    helloAwarded: false,
                    familiesUsed: [],
                    bondAwarded: 0,
                    questGenEpoch: QuestGeneration.currentEpoch
                )!],
                settings: SettingsState(onboardingComplete: true, hapticsEnabled: true),
                pendingHandshake: nil,
                processedIntents: [],
                highestCelebratedStage: .newFriends,
                lastOpenedAt: now,
                lastEvaluatedAt: now,
                lastGreeting: nil
            )
        case "all-done":
            return EngineState(
                pet: Pet(id: UUID(), name: "Momo", createdAt: now)!,
                state: PetState(
                    mood: 80, energy: 70, bond: 40,
                    wakefulness: .awake, activity: nil,
                    lastFedAt: nil, satietyPhase: .hungry
                )!,
                days: [DayRecord(
                    dayKey: dayKey,
                    feedCount: 1, playCount: 0, careCount: 1, patCount: 3,
                    questSet: [
                        quest(.q1, progress: 1, completed: true),
                        quest(.q2, progress: 1, completed: true),
                        quest(.q6, progress: 1, completed: true),
                    ],
                    helloAwarded: true,
                    familiesUsed: [.feed, .care],
                    bondAwarded: 12,
                    questGenEpoch: QuestGeneration.currentEpoch
                )!],
                settings: SettingsState(onboardingComplete: true, hapticsEnabled: true),
                pendingHandshake: nil,
                processedIntents: [],
                highestCelebratedStage: .newFriends,
                lastOpenedAt: now,
                lastEvaluatedAt: now,
                lastGreeting: nil
            )
        default:
            assertionFailure("MomoApp: unknown -momo-fixture kind '\(arguments[index + 1])'")
            return nil
        }
        #else
        return nil
        #endif
    }

    // MARK: The UI-test store enabler (TASK-032 R13, disclosed)

    /// The R13 deterministic UI-test enabler: a `-momo-store-directory
    /// <path>` launch argument overrides the store directory FOR THAT
    /// LAUNCH, so MomoUITests pin fresh-install and restart semantics
    /// against throwaway stores. Production launches never pass the
    /// argument and resolve through `StoreRules.defaultDirectory()` as
    /// before.
    ///
    /// An ABSOLUTE path is honored as-is. A RELATIVE value is resolved
    /// against the APP's own temporary directory — the UI-test runner and
    /// the app-under-test live in different sandboxes, so the runner cannot
    /// hand the app a pre-created absolute path; a unique relative name per
    /// test gives the app a throwaway store that starts fresh every launch
    /// (the `SnapshotStore` creates the directory on first save, and the
    /// fresh-vs-loaded probe reads absence as `freshStore`).
    ///
    /// Reads `ProcessInfo` once, at the property's first evaluation — no
    /// other path in the app touches launch arguments.
    private static func testStoreDirectory() -> URL? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-momo-store-directory"),
              index + 1 < arguments.count
        else { return nil }
        let raw = arguments[index + 1]
        if raw.hasPrefix("/") {
            return URL(fileURLWithPath: raw, isDirectory: true)
        }
        return FileManager.default.temporaryDirectory
            .appendingPathComponent(raw, isDirectory: true)
    }
}
