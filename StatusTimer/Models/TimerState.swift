import Foundation

enum TimerState: String, Codable, Equatable {
    case idle
    case running
    case paused
    case finished
}

enum SegmentKind: String, Codable, CaseIterable {
    case focus
    case rest

    /// Saved data from before segments had a kind: guess from the label like 1.0 did.
    static func guess(from label: String) -> SegmentKind {
        let lower = label.lowercased()
        return lower.contains("break") || lower.contains("rest") ? .rest : .focus
    }
}

struct PomodoroSegment: Identifiable, Codable, Equatable {
    let id: UUID
    var label: String
    var minutes: Int
    var kind: SegmentKind

    static let minuteRange = 1...1440

    static func clampMinutes(_ minutes: Int) -> Int {
        min(max(minutes, minuteRange.lowerBound), minuteRange.upperBound)
    }

    init(label: String, minutes: Int, kind: SegmentKind? = nil) {
        self.id = UUID()
        self.label = label
        self.minutes = Self.clampMinutes(minutes)
        self.kind = kind ?? .guess(from: label)
    }

    private enum CodingKeys: String, CodingKey {
        case id, label, minutes, kind
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decodeIfPresent(UUID.self, forKey: .id)) ?? UUID()
        label = (try? c.decodeIfPresent(String.self, forKey: .label)) ?? ""
        minutes = Self.clampMinutes((try? c.decodeIfPresent(Int.self, forKey: .minutes)) ?? 25)
        kind = (try? c.decodeIfPresent(SegmentKind.self, forKey: .kind)) ?? .guess(from: label)
    }

    var duration: TimeInterval {
        TimeInterval(Self.clampMinutes(minutes) * 60)
    }
}

struct Playlist: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var segments: [PomodoroSegment]
    var isEnabled: Bool
    /// Start the next segment on its own instead of waiting for "continue".
    var autoAdvance: Bool
    /// Wrap back to the first segment after the last one.
    var repeats: Bool

    init(name: String, segments: [PomodoroSegment], isEnabled: Bool = true,
         autoAdvance: Bool = false, repeats: Bool = false) {
        self.id = UUID()
        self.name = name
        self.segments = segments
        self.isEnabled = isEnabled
        self.autoAdvance = autoAdvance
        self.repeats = repeats
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, segments, isEnabled, autoAdvance, repeats
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decodeIfPresent(UUID.self, forKey: .id)) ?? UUID()
        name = (try? c.decodeIfPresent(String.self, forKey: .name)) ?? "Playlist"
        segments = (try? c.decodeIfPresent([PomodoroSegment].self, forKey: .segments)) ?? []
        isEnabled = (try? c.decodeIfPresent(Bool.self, forKey: .isEnabled)) ?? true
        autoAdvance = (try? c.decodeIfPresent(Bool.self, forKey: .autoAdvance)) ?? false
        repeats = (try? c.decodeIfPresent(Bool.self, forKey: .repeats)) ?? false
    }

    static let defaultPlaylists: [Playlist] = [
        Playlist(name: "Pomodoro", segments: [
            PomodoroSegment(label: "Work", minutes: 25, kind: .focus),
            PomodoroSegment(label: "Rest", minutes: 5, kind: .rest),
            PomodoroSegment(label: "Work", minutes: 25, kind: .focus),
            PomodoroSegment(label: "Rest", minutes: 5, kind: .rest),
            PomodoroSegment(label: "Work", minutes: 25, kind: .focus),
            PomodoroSegment(label: "Long Rest", minutes: 15, kind: .rest),
        ]),
        Playlist(name: "Focus", segments: [
            PomodoroSegment(label: "Focus", minutes: 50, kind: .focus),
            PomodoroSegment(label: "Break", minutes: 10, kind: .rest),
            PomodoroSegment(label: "Focus", minutes: 50, kind: .focus),
            PomodoroSegment(label: "Break", minutes: 10, kind: .rest),
        ]),
    ]
}

/// A running or paused timer, saved so it survives quit, crash or update.
struct TimerSnapshot: Codable, Equatable {
    var isPaused: Bool
    var endDate: Date?
    var remaining: TimeInterval
    var total: TimeInterval
    var label: String
    var kind: SegmentKind
    var playlistID: UUID?
    var segmentIndex: Int
    var targetDate: Date?
}
