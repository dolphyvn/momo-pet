import SwiftUI
import Foundation

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
    @State private var appModel = MomoAppModel(storeDirectory: MomoApp.testStoreDirectory())

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
        }
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
