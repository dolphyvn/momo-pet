import Foundation
import MomoKit

// MARK: - MomoAppModel + Settings — the Settings surface's executor entries
// (TASK-038; FR-19; UX §1.2 S6)

/// The three Settings operations at the executor level (TASK-038):
/// `renamePet(to:)` and `setHapticsEnabled(_:)` ride the plan core as the
/// pre-engine triggers `.petRenamed` / `.hapticsToggled` (the
/// `onboardingCompleted` precedent: dispatched before engine routing, pure
/// transformations, persist-IFF-changed); `eraseAllData()` is the
/// launch-path-symmetric store-lifecycle operation — deliberately NOT a
/// plan trigger (the adjudication below).
///
/// This same-target extension exists because `MomoAppModel.swift` stands at
/// its 800-line file budget (the contract's disclosed extraction path — the
/// pre-existing overage, not growth from later tasks, was the TASK-039
/// consolidation candidate). Swift's `private` is file-scoped,
/// so the extension rides the handful of `internal` seams annotated in the
/// main file — `storeDirectory`, `watchResetMarkerEraseCount` (TASK-040),
/// `apply(trigger:)`, `debugLoud`, `resetTransientPresentationState()`,
/// `installFreshDefaultState()` — and no accessor leaves the target.
extension MomoAppModel {

    /// S6.1's rename save (R3): trims and rejects whitespace-only names at
    /// the tap — the executor half of the onboarding-completion division of
    /// labor (the Settings Save button is the first gate, disabled for
    /// empty input) — then applies `.petRenamed`. The plan core re-honors
    /// INV-1 (the `Pet` failable init) and pins the pet's identity (id +
    /// createdAt carried); Home and Room reflect the name immediately
    /// (every read-model reads `state.pet.name`). Views never touch
    /// `AppModelPlan` directly (D-R5).
    func renamePet(to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            Self.debugLoud("MomoAppModel: rename rejected a whitespace-only name")
            return
        }
        let petID = state.pet.id
        Task { await apply(trigger: .petRenamed(petID: petID, name: trimmed)) }
    }

    /// The haptics toggle (R4): applies `.hapticsToggled` — the flag flips
    /// through the plan core with `onboardingComplete` preserved and
    /// everything else carried field-for-field. The effect is immediate at
    /// the NEXT moment delivery: the TASK-036 sink gate reads
    /// `state.settings.hapticsEnabled` at delivery time, so this surface
    /// performs no haptic work of its own.
    func setHapticsEnabled(_ enabled: Bool) {
        Task { await apply(trigger: .hapticsToggled(enabled: enabled)) }
    }

    /// Erase all data (R5; FR-19 AC-2) — the launch-path-symmetric,
    /// EXECUTOR-LEVEL store-lifecycle operation. Adjudication (why not a
    /// plan trigger): an `.allDataErased` plan that re-persisted after the
    /// deletion would (a) leave the pre-erase bytes in `SnapshotStore`'s
    /// `prev`/`prev2` rotation behind — failing AC-2's "deletes every local
    /// store" — and (b) resurrect a store a fresh install does not have —
    /// failing NFR-7's fresh-install indistinguishability. The sequence:
    ///
    /// 1. bump the reset marker FIRST (TASK-040 R3; 05 §6.6): read the
    ///    persisted count, save +1. The marker lives OUTSIDE the store
    ///    tree (`StoreRules.watchResetMarkerDirectory()` — Application
    ///    Support/ itself) precisely so the deletion below can never touch
    ///    the signal — the marker's persistence OUTLIVES the erased
    ///    stores, and no read-before-delete ordering hazard exists.
    ///    Signal-first ordering: by the time pet data is gone, the Watch's
    ///    wipe instruction is already durable. A crash BEFORE the save
    ///    changes nothing (the previous marker stands — an
    ///    already-consumed count, inert); a crash AFTER the save but
    ///    before the deletion makes the Watch wipe its journal
    ///    unnecessarily — harmless (the Watch holds no authority; the next
    ///    context re-syncs it). A save I/O failure degrades to a skipped
    ///    signal (DEBUG-loud in the store), the pre-TASK-040 status quo —
    ///    disclosed in the task file.
    /// 2. delete the store directory tree (`FileManager`, idempotent if
    ///    already absent). The crash window between the delete and the
    ///    swap lands on the store's fresh fallback — FR-13's invisible
    ///    recovery, and the correct landing.
    /// 3. reset every transient presentation state to post-init values
    ///    (`resetTransientPresentationState()` — the boundary schedule, the
    ///    play round, the celebration banner, the flip flourish, the
    ///    care-moment memory, the open touch).
    /// 4. swap in memory to `freshDefaultState(clock:)` — the SAME factory
    ///    the init path uses (`installFreshDefaultState()`), so erase and
    ///    fresh-install are indistinguishable and `requiresOnboarding`
    ///    routes to S1 with zero new machinery.
    /// 5. NO persist — the first write remains the onboarding completion
    ///    write (`SnapshotStore` recreates the directory then). The count
    ///    rides EVERY context from the erase until Watch-side consumption
    ///    (TASK-041/044); the iPhone never clears the marker.
    func eraseAllData() {
        // The marker directory's lookup failing is not an expected path
        // (StoreRules creates Application Support on the way) — the init's
        // DEBUG-loud + throwaway-fallback precedent keeps the erase
        // functional with the signal degraded to the pre-TASK-040 status
        // quo (disclosed in the task file).
        let markerDirectory: URL
        do {
            markerDirectory = try StoreRules.watchResetMarkerDirectory()
        } catch {
            Self.debugLoud("eraseAllData: marker directory lookup failed (\(error))")
            markerDirectory = FileManager.default.temporaryDirectory
                .appendingPathComponent("Momo-marker-fallback", isDirectory: true)
        }
        let markerStore = WatchResetMarkerStore(directory: markerDirectory)
        let newEraseCount = (markerStore.load()?.eraseCount ?? 0) + 1
        markerStore.save(WatchResetMarker(eraseCount: newEraseCount))
        watchResetMarkerEraseCount = newEraseCount
        try? FileManager.default.removeItem(at: storeDirectory)
        resetTransientPresentationState()
        installFreshDefaultState()
        // TASK-040: the sync bookkeeping resets WITH the engine — in memory
        // only (its file went with the deleted directory; the next push or
        // receive persists the fresh shape). The epoch clears: the next
        // applied watch intent re-establishes it, and until then the push
        // advertises the inert zero sentinel.
        watchSyncState = SyncState()
        watchSyncEpoch = nil
    }
}
