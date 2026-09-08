import Foundation
import Testing
@testable import MomoCore

/// Focused `dayKey` derivation tests for TASK-012 (AC-3, D20): known instants
/// → expected keys through an injected calendar, day-boundary exactness,
/// timezone dependence via the injected calendar's time zone, DST safety, and
/// calendar-identifier dependence. No ambient clock anywhere — the instant
/// and the calendar are always injected.
@Suite("DayKey derivation (D20)")
struct DayKeyTests {

    // MARK: - Fixtures (Foundation-parsed, so expectations never run through the SUT)

    /// Parses a UTC wall-clock string into the exact instant.
    private func utcDate(_ iso: String) -> Date {
        ISO8601DateFormatter().date(from: iso)!
    }

    /// A Gregorian calendar pinned to the named time zone — the injected
    /// "user's calendar" of D20.
    private func calendar(
        timeZone identifier: String,
        calendarIdentifier: Calendar.Identifier = .gregorian
    ) -> Calendar {
        var calendar = Calendar(identifier: calendarIdentifier)
        calendar.timeZone = TimeZone(identifier: identifier)!
        return calendar
    }

    // MARK: - Known instants

    @Test("known instant through a UTC calendar produces the expected key")
    func knownInstantUTC() {
        let key = DayKey.make(
            from: utcDate("2026-09-08T12:00:00Z"),
            calendar: calendar(timeZone: "UTC")
        )
        #expect(key == "2026-09-08")
    }

    @Test("derivation is deterministic: same inputs, same key")
    func determinism() {
        let instant = utcDate("2026-09-08T12:34:56Z")
        let cal = calendar(timeZone: "Asia/Tokyo")
        #expect(DayKey.make(from: instant, calendar: cal) == DayKey.make(from: instant, calendar: cal))
    }

    // MARK: - Day boundary (FR-11 AC-2: reset exactly at local midnight)

    @Test("one second either side of local midnight lands in different days")
    func dayBoundary() {
        let utc = calendar(timeZone: "UTC")
        #expect(DayKey.make(from: utcDate("2026-09-08T23:59:59Z"), calendar: utc) == "2026-09-08")
        #expect(DayKey.make(from: utcDate("2026-09-09T00:00:00Z"), calendar: utc) == "2026-09-09")
    }

    // MARK: - Timezone dependence via the injected calendar (D20)

    @Test("same instant, different injected time zones, different days")
    func timezoneVariationAhead() {
        let instant = utcDate("2026-09-08T20:30:00Z") // 05:30 next day in Tokyo (+9)
        #expect(DayKey.make(from: instant, calendar: calendar(timeZone: "UTC")) == "2026-09-08")
        #expect(DayKey.make(from: instant, calendar: calendar(timeZone: "Asia/Tokyo")) == "2026-09-09")
    }

    @Test("the boundary also shifts backwards for western time zones")
    func timezoneVariationBehind() {
        let instant = utcDate("2026-09-08T03:30:00Z") // 23:30 previous day in New York (EDT, −4)
        #expect(DayKey.make(from: instant, calendar: calendar(timeZone: "UTC")) == "2026-09-08")
        #expect(DayKey.make(from: instant, calendar: calendar(timeZone: "America/New_York")) == "2026-09-07")
    }

    // MARK: - DST safety (FR-11 AC-2/AC-3)

    @Test("DST fall-back repeat hour maps both instants to the same local day")
    func dstFallBack() {
        // 2026-11-01: clocks fall back in New York; 05:30Z is 01:30 EDT,
        // 06:30Z is 01:30 EST — the repeated local hour.
        let ny = calendar(timeZone: "America/New_York")
        #expect(DayKey.make(from: utcDate("2026-11-01T05:30:00Z"), calendar: ny) == "2026-11-01")
        #expect(DayKey.make(from: utcDate("2026-11-01T06:30:00Z"), calendar: ny) == "2026-11-01")
    }

    // MARK: - Calendar-identifier dependence (the "user's calendar", D20)

    @Test("a non-Gregorian injected calendar derives its own year")
    func nonGregorianCalendar() {
        let key = DayKey.make(
            from: utcDate("2026-09-08T00:00:00Z"), // 07:00 in Bangkok (+7)
            calendar: calendar(timeZone: "Asia/Bangkok", calendarIdentifier: .buddhist)
        )
        #expect(key == "2569-09-08") // Buddhist era: 2026 + 543
    }

    // MARK: - INV-9 model-side pin

    @Test("INV-9: model stores UTC instants; the day key is caller-derived")
    func modelStoresInstantsAndDerivesKeys() {
        let pet = Pet(id: UUID(), name: "Momo", createdAt: utcDate("2026-09-08T20:30:00Z"))
        #expect(pet != nil)
        #expect(pet?.createdAt == utcDate("2026-09-08T20:30:00Z"))
        // The same instant derives differently per injected calendar — the
        // key never lives in the model as a date value, only as this string.
        #expect(DayKey.make(from: pet!.createdAt, calendar: calendar(timeZone: "UTC")) == "2026-09-08")
        #expect(DayKey.make(from: pet!.createdAt, calendar: calendar(timeZone: "Asia/Tokyo")) == "2026-09-09")
    }
}
