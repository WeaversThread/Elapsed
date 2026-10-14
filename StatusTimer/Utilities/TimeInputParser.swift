import Foundation

enum TimeInput: Equatable {
    case minutes(Int)
    case until(Date)
}

/// Turns what's typed into the custom field into a duration or a clock time.
///
/// - `90` → 90 min, `1:30` → 1 h 30 min, `1h30`, `1h`, `45m`, `45 min`
/// - `@14:30`, `@2:30pm`, `@9`, `at 14:30`, `until 1430` → count down to that time,
///   tomorrow if it has already passed today. Without am/pm, `@2:30` means whichever
///   of 2:30 and 14:30 comes next.
enum TimeInputParser {
    static func parse(_ text: String, now: Date = Date(), calendar: Calendar = .current) -> TimeInput? {
        let input = text.trimmingCharacters(in: .whitespaces).lowercased()
        guard !input.isEmpty else { return nil }

        for prefix in ["@", "at ", "until "] where input.hasPrefix(prefix) {
            let rest = input.dropFirst(prefix.count).trimmingCharacters(in: .whitespaces)
            return clockTime(rest, now: now, calendar: calendar).map(TimeInput.until)
        }
        return duration(input).map(TimeInput.minutes)
    }

    // MARK: - Duration

    private static func duration(_ input: String) -> Int? {
        let minutes: Int?
        if let m = input.wholeMatch(of: #/(\d+)/#) {
            minutes = Int(m.1)
        } else if let m = input.wholeMatch(of: #/(\d+):(\d{1,2})/#) {
            minutes = combine(hours: m.1, minutes: m.2)
        } else if let m = input.wholeMatch(of: #/(\d+)\s*h(?:ours?|rs?)?\s*(?:(\d+)\s*(?:m|min|mins|minutes?)?)?/#) {
            minutes = combine(hours: m.1, minutes: m.2)
        } else if let m = input.wholeMatch(of: #/(\d+)\s*(?:m|min|mins|minutes?)/#) {
            minutes = Int(m.1)
        } else {
            minutes = nil
        }
        guard let minutes, minutes > 0 else { return nil }
        return PomodoroSegment.clampMinutes(minutes)
    }

    private static func combine(hours: Substring, minutes: Substring?) -> Int? {
        guard let h = Int(hours) else { return nil }
        let m = minutes.flatMap { Int($0) } ?? 0
        guard m < 60 else { return nil }
        return h * 60 + m
    }

    // MARK: - Clock time

    private static func clockTime(_ input: String, now: Date, calendar: Calendar) -> Date? {
        guard let m = input.wholeMatch(of: #/(\d{1,2})(?:[:.]?(\d{2}))?\s*(am|pm|a|p)?/#),
              let hour = Int(m.1) else { return nil }
        let minute = m.2.flatMap { Int($0) } ?? 0
        guard minute < 60 else { return nil }

        let candidates: [Int]
        switch m.3.map({ String($0.prefix(1)) }) {
        case "a":
            guard (1...12).contains(hour) else { return nil }
            candidates = [hour % 12]
        case "p":
            guard (1...12).contains(hour) else { return nil }
            candidates = [hour % 12 + 12]
        default:
            guard hour < 24 else { return nil }
            switch hour {
            case 12:     candidates = [12, 0]
            case 1...11: candidates = [hour, hour + 12]
            default:     candidates = [hour]
            }
        }

        return candidates
            .compactMap { next(hour: $0, minute: minute, after: now, calendar: calendar) }
            .min()
    }

    private static func next(hour: Int, minute: Int, after now: Date, calendar: Calendar) -> Date? {
        calendar.nextDate(
            after: now,
            matching: DateComponents(hour: hour, minute: minute, second: 0),
            matchingPolicy: .nextTime
        )
    }
}
