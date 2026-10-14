import Foundation

enum TimerState: Equatable {
    case idle
    case running
    case paused
    case finished
}

struct TimerPreset: Identifiable, Codable, Equatable {
    let id: UUID
    let minutes: Int
    var label: String

    init(minutes: Int, label: String? = nil) {
        self.id = UUID()
        self.minutes = minutes
        self.label = label ?? "\(minutes)"
    }

    static let defaults: [TimerPreset] = [
        TimerPreset(minutes: 5),
        TimerPreset(minutes: 10),
        TimerPreset(minutes: 15),
        TimerPreset(minutes: 25),
        TimerPreset(minutes: 30),
        TimerPreset(minutes: 45),
        TimerPreset(minutes: 60, label: "60"),
    ]
}

struct PomodoroSegment: Identifiable, Codable, Equatable {
    let id: UUID
    var label: String
    var minutes: Int

    init(label: String, minutes: Int) {
        self.id = UUID()
        self.label = label
        self.minutes = minutes
    }

    var duration: TimeInterval {
        TimeInterval(minutes * 60)
    }
}

struct Playlist: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var segments: [PomodoroSegment]
    var isEnabled: Bool

    init(name: String, segments: [PomodoroSegment], isEnabled: Bool = true) {
        self.id = UUID()
        self.name = name
        self.segments = segments
        self.isEnabled = isEnabled
    }

    static let defaultPlaylists: [Playlist] = [
        Playlist(name: "Pomodoro", segments: [
            PomodoroSegment(label: "Work", minutes: 25),
            PomodoroSegment(label: "Rest", minutes: 5),
            PomodoroSegment(label: "Work", minutes: 25),
            PomodoroSegment(label: "Rest", minutes: 5),
            PomodoroSegment(label: "Work", minutes: 25),
            PomodoroSegment(label: "Long Rest", minutes: 15),
        ]),
        Playlist(name: "Focus", segments: [
            PomodoroSegment(label: "Focus", minutes: 50),
            PomodoroSegment(label: "Break", minutes: 10),
            PomodoroSegment(label: "Focus", minutes: 50),
            PomodoroSegment(label: "Break", minutes: 10),
        ]),
    ]
}
