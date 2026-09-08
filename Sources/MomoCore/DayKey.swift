import Foundation

/// Local-day key derivation (D20; FR-11 AC-4; INV-9).
///
/// `dayKey` is a derived `"YYYY-MM-DD"` string in the user's calendar — never
/// a stored timezone-dependent date type. This function is the single
/// sanctioned derivation path: the caller injects both the instant and the
/// calendar (whose `timeZone` supplies the locality), so the result is fully
/// deterministic and testable. Model code never touches `Date()` or
/// `Calendar.current` (D20 / TASK-012 requirement).
public enum DayKey {

    /// Derives the `"YYYY-MM-DD"` key for `instant` as seen through
    /// `calendar` (its `timeZone` decides the local day, so the same UTC
    /// instant can land on different days in different timezones — by design;
    /// DST and calendar-identifier differences are handled by `Calendar`
    /// itself).
    public static func make(from instant: Instant, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: instant)
        guard let year = components.year, let month = components.month, let day = components.day else {
            // Unreachable for the requested components of a valid calendar
            // date; fail loudly in debug and return an empty string rather
            // than silently fabricating a day (house pattern: DEBUG-loud,
            // release-safe fallback — MomoCopy.resolve).
            assertionFailure("DayKey: calendar returned missing date components")
            return ""
        }
        return String(format: "%04d-%02d-%02d", year, month, day)
    }
}
