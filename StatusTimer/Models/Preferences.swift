import SwiftUI

/// Every user-facing setting. All fields have defaults and decode leniently,
/// so adding a field later never wipes what's already saved.
struct Preferences: Codable, Equatable {
    // Timer
    var presets: [Int] = [5, 10, 15, 25, 30, 45, 60]
    var snoozeMinutes: Int = 5
    var overtime: Bool = true

    // Look
    var focusAccent: Accent = .red
    var restAccent: Accent = .blue
    var statusStyle: StatusStyle = .capsule
    var showPresets: Bool = true
    var showPlaylists: Bool = true
    var windowShowsBars: Bool = false

    // Sound
    var alarmSound: String = AlarmSound.bundled
    var alarmVolume: Double = 1.0
    var alarmLength: AlarmLength = .oneMinute

    // General
    var openPopoverOnFinish: Bool = true
    var notifications: Bool = true

    static let presetCountRange = 3...9
    static let snoozeRange = 1...60

    init() {}

    private enum CodingKeys: String, CodingKey {
        case presets, snoozeMinutes, overtime
        case focusAccent, restAccent, statusStyle, showPresets, showPlaylists, windowShowsBars
        case alarmSound, alarmVolume, alarmLength
        case openPopoverOnFinish, notifications
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = Preferences()
        func value<T: Decodable>(_ key: CodingKeys, _ fallback: T) -> T {
            (try? c.decodeIfPresent(T.self, forKey: key)) ?? fallback
        }
        presets = Self.normalizedPresets(value(.presets, d.presets))
        snoozeMinutes = value(.snoozeMinutes, d.snoozeMinutes)
        overtime = value(.overtime, d.overtime)
        focusAccent = value(.focusAccent, d.focusAccent)
        restAccent = value(.restAccent, d.restAccent)
        statusStyle = value(.statusStyle, d.statusStyle)
        showPresets = value(.showPresets, d.showPresets)
        showPlaylists = value(.showPlaylists, d.showPlaylists)
        windowShowsBars = value(.windowShowsBars, d.windowShowsBars)
        alarmSound = value(.alarmSound, d.alarmSound)
        alarmVolume = value(.alarmVolume, d.alarmVolume)
        alarmLength = value(.alarmLength, d.alarmLength)
        openPopoverOnFinish = value(.openPopoverOnFinish, d.openPopoverOnFinish)
        notifications = value(.notifications, d.notifications)
    }

    func accent(for kind: SegmentKind) -> Color {
        (kind == .rest ? restAccent : focusAccent).color
    }

    /// Sorted, unique, within 1–1440, and never fewer than 3 or more than 9.
    static func normalizedPresets(_ values: [Int]) -> [Int] {
        let cleaned = Array(Set(values.map(PomodoroSegment.clampMinutes))).sorted()
        if cleaned.count < presetCountRange.lowerBound { return Preferences().presets }
        return Array(cleaned.prefix(presetCountRange.upperBound))
    }
}

// MARK: - Look

/// A curated set of swatches rather than a free color picker.
enum Accent: String, Codable, CaseIterable, Identifiable {
    case red, orange, yellow, green, teal, blue, violet, white

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .red:    .red
        case .orange: Color(red: 0.96, green: 0.42, blue: 0.10)  // Braun orange
        case .yellow: Color(red: 0.98, green: 0.78, blue: 0.18)
        case .green:  .green
        case .teal:   .teal
        case .blue:   .blue
        case .violet: .purple
        case .white:  .white
        }
    }

    /// Bright enough that text on top of it needs to be dark.
    var isLight: Bool {
        self == .yellow || self == .white
    }
}

enum StatusStyle: String, Codable, CaseIterable, Identifiable {
    case capsule, progress

    var id: String { rawValue }
}

// MARK: - Sound

enum AlarmSound {
    /// The alarm.mp3 that ships inside the app.
    static let bundled = "Elapsed"
}

enum AlarmLength: String, Codable, CaseIterable, Identifiable {
    case once, fifteenSeconds, oneMinute, untilStopped

    var id: String { rawValue }

    var title: String {
        switch self {
        case .once:           "once"
        case .fifteenSeconds: "15 s"
        case .oneMinute:      "1 min"
        case .untilStopped:   "until stopped"
        }
    }

    /// How long the alarm loops; nil for "once" (no loop) and "until stopped" (no limit).
    var loopSeconds: TimeInterval? {
        switch self {
        case .fifteenSeconds: 15
        case .oneMinute:      60
        case .once, .untilStopped: nil
        }
    }
}
