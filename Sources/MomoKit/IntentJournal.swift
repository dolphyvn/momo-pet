import Foundation
import MomoCore

// MARK: - IntentJournal (05-technical-architecture §6.4 steps 1/4; ADR-003;
// TASK-023)

/// The Watch → iPhone intent journal — the append-only NDJSON queue behind
/// `transferUserInfo` (05 §6.4 step 1: "intent appended to the journal"),
/// pure journaling over an INJECTED directory: append / parse / prune, none
/// of which ever throw to the caller.
///
/// **On-disk format.** `StoreRules.intentJournalFileName`, one `IntentEvent`
/// JSON object per line — `IntentEvent.encoded()`'s canonical bytes
/// (`.sortedKeys`, Foundation-default Date strategy) — newline-terminated
/// (`\n` is the sole terminator; a trailing newline closes the last line, so
/// a file not ending in `\n` has a TORN trailing line).
///
/// **The journal's epoch representation — per-event, decided.** The
/// contract left the choice (per-file epoch header line vs per-event field);
/// this journal uses the per-event field the §6.2 sketch already mandates
/// (`IntentEvent.watchSessionEpoch`) — no second format to version, and the
/// prune rule degrades correctly for a journal holding TWO epochs (a
/// defensive case the wipe discipline should never produce, but
/// `transferUserInfo` redelivery might): each entry is matched against the
/// applying watermark's epoch individually, so only the matching epoch's
/// entries are ever dropped.
///
/// **Append and its crash window.** Append is a read-modify-write of the
/// whole file (journal sizes are a handful of pats between syncs) with a
/// PLAIN, in-place write — the journal's designed crash tolerance is
/// exactly the torn trailing line, so the append path deliberately does NOT
/// use the store's temp-rename commit point. Before appending, a file that
/// does not end in `\n` gets the newline SEALED first: the torn line stays
/// a discrete (unparsable, skipped) line instead of being glued onto the
/// new event, so a post-tear append can never corrupt the NEW event's
/// parseability. Every interruption mid-append therefore leaves complete
/// lines plus at worst one torn trailing line — nothing before the tear is
/// ever lost (pinned).
///
/// **Parse and its skip semantics.** Lines decode through the version gate
/// (`IntentEvent.decoded(from:)`); an unparsable line — the torn trailing
/// line from a mid-append crash, mid-file corruption, or an unknown
/// future-version line — is SKIPPED, never fatal (§6.4's crash tolerance;
/// FR-18 AC-4's no-error-surface). Blank lines are ignored (not events, not
/// defects). A skipped line is recorded DEBUG-loud without trapping (see
/// `recordSkippedLine`).
///
/// **Prune (§6.4 step 4, the epoch-matched rule).** `prune` drops entries
/// with `watchSeq ≤ watermark` ONLY when the entry's
/// `watchSessionEpoch` equals the applying watermark's epoch — a
/// stale-epoch watermark (a snapshot from before a Watch re-pair) NEVER
/// prunes a newer journal (pinned byte-identical). The survivors' rewrite
/// is the one place the journal uses the atomic commit point
/// (temp + `replaceItemAt`): the prune SHRINKS the queue, and a torn
/// in-place prune could truncate away still-unapplied pats — the atomic
/// replace keeps the journal whole-or-new, never smaller-by-tearing. An
/// empty survivor set removes the file (an absent file parses to `[]`, so
/// the two shapes are the same state).
public struct IntentJournal {

    /// The injected directory (the app layer passes
    /// `StoreRules.defaultDirectory()`; tests inject a throwaway).
    private let directory: URL

    /// - Parameter directory: the directory holding
    ///   `StoreRules.intentJournalFileName`; created by `append`/`prune` if
    ///   missing (`events()` over a missing directory is a valid empty
    ///   queue).
    public init(directory: URL) {
        self.directory = directory
    }

    // MARK: Append (§6.4 step 1)

    /// Appends one event as a canonical, newline-terminated line (the type
    /// header's crash-window analysis). Never throws: an encoding or I/O
    /// failure trips the DEBUG-loud discipline and leaves the journal as it
    /// stands. Returns whether the line LANDED — the caller's durability
    /// signal (TASK-042's send gate: the `transferUserInfo` drain goes out
    /// only for journaled events, so a declined watermark seq can never be
    /// handed to a later pat).
    @discardableResult
    public func append(_ event: IntentEvent) -> Bool {
        guard var line = event.encoded() else {
            // A valid `IntentEvent` that cannot encode is a domain-model
            // regression (every field is JSON-native). DEBUG-loud; nothing
            // is appended.
            Self.debugLoudFailure("IntentJournal: event encoding failed — append skipped")
            return false
        }
        line.append(0x0A) // the newline terminator (ASCII \n)
        let fileManager = FileManager.default
        do {
            try Self.createDirectoryIfMissing(directory, fileManager: fileManager)
            let url = directory.appendingPathComponent(StoreRules.intentJournalFileName)
            var contents = (try? Data(contentsOf: url)) ?? Data()
            // Seal a torn trailing line before gluing on the new event (the
            // type header's append analysis): the torn line stays discrete
            // and skipped; the new line parses cleanly.
            if !contents.isEmpty, contents.last != 0x0A {
                contents.append(0x0A)
            }
            contents.append(line)
            try contents.write(to: url)
            return true
        } catch {
            // Crash-window honesty: an interruption MID-write leaves a torn
            // prefix (complete lines + torn trailing line) — the parse path's
            // designed input, never a loss of pre-tear lines. A failed write
            // (not a crash) is an I/O regression: DEBUG-loud, journal keeps
            // whatever survived.
            Self.debugLoudFailure("IntentJournal: append failed (\(error)) — journal kept as-is")
            return false
        }
    }

    // MARK: Parse (§6.4 step 2's inbox)

    /// The queued events, in append (FIFO) order. Never throws; skips
    /// unparsable/unknown-version lines per the type header's skip
    /// semantics (a torn trailing line from a mid-append crash loses only
    /// itself — never the earlier entries).
    public func events() -> [IntentEvent] {
        let url = directory.appendingPathComponent(StoreRules.intentJournalFileName)
        guard let data = try? Data(contentsOf: url), !data.isEmpty else { return [] }
        var events: [IntentEvent] = []
        // `omittingEmptySubsequences` drops blank lines silently (not events,
        // not defects — see the type header).
        for line in data.split(separator: 0x0A) {
            guard let event = IntentEvent.decoded(from: Data(line)) else {
                Self.recordSkippedLine()
                continue
            }
            events.append(event)
        }
        return events
    }

    // MARK: Prune (§6.4 step 4 — epoch-matched ONLY)

    /// The pure prune core: the entries surviving `watchSeq ≤ watermark`
    /// application, WHERE the watermark's epoch matches the entry's — a
    /// stale-epoch watermark matches nothing and prunes nothing. Total:
    /// defined on every input (empty, boundary `watchSeq == watermark`,
    /// mixed epochs, oversized).
    public static func pruned(
        _ events: [IntentEvent],
        watermarkEpoch: UUID,
        watermarkSeq: Int
    ) -> [IntentEvent] {
        events.filter { event in
            guard event.watchSessionEpoch == watermarkEpoch else { return true }
            return event.watchSeq > watermarkSeq
        }
    }

    /// Applies the epoch-matched prune to the on-disk journal: parse → pure
    /// core → atomic rewrite of the survivors (the type header's shrink
    /// analysis). Never throws; on any internal failure the journal file is
    /// left untouched. An empty survivor set removes the file — an absent
    /// journal IS an empty one.
    public func prune(watermarkEpoch: UUID, watermarkSeq: Int) {
        let survivors = Self.pruned(
            events(),
            watermarkEpoch: watermarkEpoch,
            watermarkSeq: watermarkSeq
        )
        let fileManager = FileManager.default
        let url = directory.appendingPathComponent(StoreRules.intentJournalFileName)
        guard !survivors.isEmpty else {
            // An ABSENT journal is already the empty state (removing it would
            // throw; nothing to do — pinned `absentJournalIsEmptyAndStaysAbsent`).
            // A removal failure over an EXISTING file is an I/O regression:
            // DEBUG-loud like the rewrite path below — the leftovers are inert
            // (the watermark gate absorbs already-applied entries) and the
            // next prune retries the cleanup.
            if fileManager.fileExists(atPath: url.path(percentEncoded: false)) {
                do {
                    try fileManager.removeItem(at: url)
                } catch {
                    Self.debugLoudFailure(
                        "IntentJournal: survivor-free prune failed to remove the journal (\(error)) — applied entries left in place, inert under the watermark gate"
                    )
                }
            }
            return
        }
        var contents = Data()
        for event in survivors {
            guard var line = event.encoded() else {
                Self.debugLoudFailure("IntentJournal: survivor encoding failed — prune skipped")
                return
            }
            line.append(0x0A)
            contents.append(line)
        }
        do {
            try Self.createDirectoryIfMissing(directory, fileManager: fileManager)
            let temporary = directory.appendingPathComponent(StoreRules.temporaryIntentJournalFileName)
            try contents.write(to: temporary)
            // The atomic replace: the journal is whole-or-new, never smaller
            // by tearing (survivors are still-unapplied pats — the type
            // header's shrink analysis). Non-empty survivors imply the file
            // exists (they were parsed from it), so the replace has its
            // original.
            _ = try fileManager.replaceItemAt(
                url,
                withItemAt: temporary,
                backupItemName: nil,
                options: []
            )
        } catch {
            try? fileManager.removeItem(
                at: directory.appendingPathComponent(StoreRules.temporaryIntentJournalFileName)
            )
            Self.debugLoudFailure("IntentJournal: prune failed (\(error)) — journal kept as-is")
        }
    }

    // MARK: Wipe (§6.6's journal half; TASK-042 R2c)

    /// Removes the journal file — the §6.6 consumption's journal half AND
    /// the epoch (re)generation's F-3 self-defense (stale-epoch entries can
    /// never apply and must never linger). Never throws; an ABSENT journal
    /// is already the wiped state (removing it would throw; nothing to do —
    /// the same shape `prune`'s empty-survivor branch documents). MUST be
    /// idempotent: a crash between any wipe leg and the consumed-marker
    /// record replays the whole consumption, and the replay must be a no-op
    /// second time. Deliberately touches NOTHING else in the directory —
    /// only the journal file named by `StoreRules.intentJournalFileName`
    /// (the temp is prune's own in-flight artifact and is removed by the
    /// prune path's cleanup, not here; a wipe racing a prune's temp leaves
    /// an inert orphan the next prune overwrites).
    public func wipe() {
        let fileManager = FileManager.default
        let url = directory.appendingPathComponent(StoreRules.intentJournalFileName)
        guard fileManager.fileExists(atPath: url.path(percentEncoded: false)) else { return }
        do {
            try fileManager.removeItem(at: url)
        } catch {
            // A removal failure over an EXISTING file is an I/O regression:
            // DEBUG-loud like the prune's removal branch — the leftovers are
            // inert (stale-epoch entries can never apply; same-epoch entries
            // sit above the watermark gate) and the next wipe/prune retries
            // the cleanup.
            Self.debugLoudFailure(
                "IntentJournal: wipe failed to remove the journal (\(error)) — leftovers left in place, inert under the watermark gate"
            )
        }
    }

    // MARK: The two DEBUG-loud flavors (deliberately different — see each)

    /// The I/O / encoding-regression discipline (`MomoCopy`, `SnapshotStore`):
    /// trip the debugger in debug builds, stay silent in release where the
    /// documented recovery (journal kept as-is) governs.
    private static func debugLoudFailure(_ message: String) {
        #if DEBUG
        assertionFailure(message)
        #endif
    }

    /// The DEFINED skip events' recording: loud in debug builds WITHOUT
    /// trapping, because skipping is the journal's designed crash tolerance
    /// (§6.4), not a defect — trapping would turn crash recovery itself into
    /// a crash on a debug device (and every torn-line test into a trap).
    /// `print` is the only non-trapping loud channel available under the
    /// Foundation+MomoCore import rule (os.log would need `import os`).
    private static func recordSkippedLine() {
        #if DEBUG
        print("IntentJournal: skipped an unparsable or unknown-version journal line (a torn trailing line from a mid-append crash is the designed case)")
        #endif
    }

    private static func createDirectoryIfMissing(_ directory: URL, fileManager: FileManager) throws {
        var isDirectory: ObjCBool = false
        if !fileManager.fileExists(atPath: directory.path(percentEncoded: false), isDirectory: &isDirectory) || !isDirectory.boolValue {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }
}
