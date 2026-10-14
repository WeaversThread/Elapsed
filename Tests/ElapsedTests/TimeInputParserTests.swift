import Foundation
import Testing
@testable import Elapsed

@Suite struct TimeInputParserTests {
    let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return c
    }()

    /// Wednesday 14 Oct 2026, 13:05.
    var now: Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: 14, hour: 13, minute: 5))!
    }

    func parse(_ text: String) -> TimeInput? {
        TimeInputParser.parse(text, now: now, calendar: calendar)
    }

    func until(day: Int, hour: Int, minute: Int) -> TimeInput {
        .until(calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute))!)
    }

    @Test(arguments: [
        ("90", 90), ("1:30", 90), ("1h30", 90), ("1h", 60), ("2 hours", 120),
        ("45m", 45), ("45 min", 45), ("3000", 1440),
    ])
    func durations(text: String, minutes: Int) {
        #expect(parse(text) == .minutes(minutes))
    }

    @Test(arguments: ["", "0", "1:75", "abc", "@25:00", "@13pm"])
    func rejects(text: String) {
        #expect(parse(text) == nil)
    }

    @Test func clockTimes() {
        #expect(parse("@14:30") == until(day: 14, hour: 14, minute: 30))
        #expect(parse("at 14:30") == until(day: 14, hour: 14, minute: 30))
        #expect(parse("until 1430") == until(day: 14, hour: 14, minute: 30))
        #expect(parse("@2:30pm") == until(day: 14, hour: 14, minute: 30))
        #expect(parse("@2pm") == until(day: 14, hour: 14, minute: 0))
    }

    @Test func ambiguousHourPicksTheNextOne() {
        // 13:05 now: "2:30" is 14:30 today, not 02:30 tomorrow.
        #expect(parse("@2:30") == until(day: 14, hour: 14, minute: 30))
        #expect(parse("@9") == until(day: 14, hour: 21, minute: 0))
        #expect(parse("@12") == until(day: 15, hour: 0, minute: 0))
    }

    @Test func pastTimesRollToTomorrow() {
        #expect(parse("@13:00") == until(day: 15, hour: 13, minute: 0))
        #expect(parse("@930am") == until(day: 15, hour: 9, minute: 30))
    }
}
