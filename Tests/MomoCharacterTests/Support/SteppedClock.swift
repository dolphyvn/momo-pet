import Foundation
import MomoCore

/// Reference-semantics test clock for `CharacterClock` (TASK-026): an
/// `EngineClock` whose current instant tests advance directly. A CLASS
/// (deliberately — unlike `ManualEngineClock`'s value semantics) so a clock
/// holding this source observes the test's advances: the character clock is
/// a long-lived object over a shared time source, which is exactly the
/// production shape (`SystemEngineClock`).
final class SteppedClock: EngineClock, @unchecked Sendable {

    private let lock = NSLock()
    private var current: Instant

    init(at instant: Instant = Instant(timeIntervalSince1970: 0)) {
        self.current = instant
    }

    func now() -> Instant {
        lock.withLock { current }
    }

    /// Moves the clock forward (or backward) by `interval` seconds.
    func advance(by interval: TimeInterval) {
        lock.withLock { current = current.addingTimeInterval(interval) }
    }

    /// Moves the clock to `instant` outright.
    func advance(to instant: Instant) {
        lock.withLock { current = instant }
    }
}
