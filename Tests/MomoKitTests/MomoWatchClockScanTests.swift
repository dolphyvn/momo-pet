import Foundation
import Testing
@testable import MomoKit

/// The TASK-044 R4 structural suite for D20's no-ambient-time law over
/// `Apps/MomoWatch` (the `MomoWatchSweepScanTests` shape): both directions
/// per pin — a green fixture with the exact shipped shape, and stub
/// directions that break each leg EXACTLY once — plus the standing
/// real-tree runs over `KitRepo.momoWatchSources()`. The behavioral half
/// (the cascade genuinely follows the injected hour) is pinned by
/// `WatchCascadeTests`; this suite pins the TARGET-WIDE ban and the
/// recompute's injected read.
@Suite("MomoWatchClockScan — the Watch target reads time only through injection (TASK-044 R4)")
struct MomoWatchClockScanTests {

    // MARK: - Fixtures

    /// The green model: the recompute reads the INJECTED wall clock, and
    /// nothing in the file spells ambient time.
    private static let greenModel = """
    final class MomoWatchAppModel {
        let wallClock: any EngineClock
        let calendar: Calendar

        private func recomputeQuestLine() {
            let localHour = calendar.component(.hour, from: wallClock.now())
            liveQuestLine = WatchCascade.liveQuestLine(localHour: localHour)
        }
    }
    """

    /// A green non-model production file: the pat stamp also flows from the
    /// injected clock (the shipped `MomoWatchPat.swift` shape).
    private static let greenPat = """
    func finishPat() async {
        let stamp = wallClock.now()
        _ = stamp
    }
    """

    private func clockFiles(model: String = greenModel, pat: String = greenPat) -> [(name: String, contents: String)] {
        [
            (name: WatchClockScan.appModelFileName, contents: model),
            (name: "MomoWatchPat.swift", contents: pat),
        ]
    }

    // MARK: - The green fixtures

    @Test("green fixture: injected-clock usage across the target produces no finding")
    func greenFixtures() {
        #expect(WatchClockScan.ambientClockViolations(files: clockFiles()).isEmpty)
        #expect(WatchClockScan.injectedClockViolations(files: clockFiles()).isEmpty)
    }

    // MARK: - Guard 1 stub directions: the ambient ban

    @Test("stub direction: an ambient Date() call fails the ban alone; the recompute pin stays green")
    func ambientDateCallFails() {
        let timed = Self.greenModel.replacingOccurrences(
            of: "        let localHour =",
            with: "        let stamp = Date()\n        let localHour ="
        )
        let files = clockFiles(model: timed)
        let ambient = WatchClockScan.ambientClockViolations(files: files)
        #expect(ambient.count == 1, "\(ambient)")
        #expect(ambient.first?.guardName == WatchClockScan.ambientClockGuard)
        #expect(ambient.first?.detail.contains("Date()") == true)
        #expect(WatchClockScan.injectedClockViolations(files: files).isEmpty,
                "the ambient ban is its own guard — a Date() mutation bites exactly one")
    }

    @Test("stub direction: the bare Date.now static fails the ban too")
    func ambientDateNowFails() {
        let timed = Self.greenPat.replacingOccurrences(
            of: "let stamp = wallClock.now()",
            with: "let stamp = Date.now"
        )
        let findings = WatchClockScan.ambientClockViolations(files: clockFiles(pat: timed))
        #expect(findings.count == 1, "\(findings)")
        #expect(findings.first?.detail.contains("Date.now") == true)
    }

    @Test("stub direction: Calendar.current fails the ban alone")
    func ambientCalendarCurrentFails() {
        let timed = Self.greenModel.replacingOccurrences(
            of: "calendar.component(",
            with: "Calendar.current.component("
        )
        let files = clockFiles(model: timed)
        let ambient = WatchClockScan.ambientClockViolations(files: files)
        #expect(ambient.count == 1, "\(ambient)")
        #expect(ambient.first?.detail.contains("Calendar.current") == true)
        #expect(WatchClockScan.injectedClockViolations(files: files).isEmpty,
                "the ambient ban is its own guard — a Calendar.current mutation bites exactly one")
    }

    @Test("ambient tokens cited only in a doc comment stay legal (the stripper must not mute citations)")
    func ambientCommentCitationPasses() {
        let cited = Self.greenModel
            + "\n    // Never read Date() or Calendar.current here — D20 injects the hour."
        let findings = WatchClockScan.ambientClockViolations(files: clockFiles(model: cited))
        #expect(findings.isEmpty, "\(findings)")
    }

    // MARK: - Guard 2 stub directions: the recompute's injected read

    @Test("stub direction: a recompute with no injected read fails its pin alone; the ban stays green")
    func recomputeWithoutInjectedReadFails() {
        let hardcoded = Self.greenModel.replacingOccurrences(
            of: "        let localHour = calendar.component(.hour, from: wallClock.now())",
            with: "        let localHour = 9"
        )
        let files = clockFiles(model: hardcoded)
        let injected = WatchClockScan.injectedClockViolations(files: files)
        #expect(injected.count == 1, "\(injected)")
        #expect(injected.first?.guardName == WatchClockScan.injectedClockGuard)
        #expect(injected.first?.detail.contains("reads no injected clock") == true)
        #expect(WatchClockScan.ambientClockViolations(files: files).isEmpty,
                "the injected-read pin is its own guard — a silent revert bites exactly one")
    }

    @Test("stub direction: a missing app model fails the recompute pin")
    func missingModelFileFails() {
        let findings = WatchClockScan.injectedClockViolations(files: [
            (name: "MomoWatchPat.swift", contents: Self.greenPat),
        ])
        #expect(findings.count == 1, "\(findings)")
        #expect(findings.first?.detail.contains("file missing") == true)
    }

    @Test("stub direction: a recompute spelled differently fails the recompute pin")
    func renamedRecomputeFails() {
        let renamed = Self.greenModel.replacingOccurrences(
            of: "func recomputeQuestLine", with: "func refreshLine"
        )
        let findings = WatchClockScan.injectedClockViolations(files: clockFiles(model: renamed))
        #expect(findings.count == 1, "\(findings)")
        #expect(findings.first?.detail.contains("body not found") == true)
    }

    // MARK: - The standing real-tree runs

    @Test("Apps/MomoWatch as it stands reads no ambient clock")
    func realTreeNoAmbientClock() throws {
        let findings = WatchClockScan.ambientClockViolations(files: try KitRepo.momoWatchSources())
        #expect(findings.isEmpty, "ambient-clock violation: \(findings)")
    }

    @Test("the quest recompute as it stands reads the injected wall clock")
    func realTreeRecomputeReadsInjectedClock() throws {
        let findings = WatchClockScan.injectedClockViolations(files: try KitRepo.momoWatchSources())
        #expect(findings.isEmpty, "injected-clock violation: \(findings)")
    }
}
