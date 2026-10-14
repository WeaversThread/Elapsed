import Combine
import Foundation

@MainActor
final class TimerEngine: ObservableObject {
    @Published var state: TimerState = .idle
    @Published var remainingSeconds: TimeInterval = 0
    @Published var totalSeconds: TimeInterval = 0
    @Published var selectedMinutes: Int

    @Published var currentSegmentIndex: Int = 0
    @Published var currentSegmentLabel: String = ""
    @Published var activePlaylistIndex: Int? = nil

    private var activePlaylist: [PomodoroSegment] = []
    private var timerCancellable: AnyCancellable?
    private var pausedRemaining: TimeInterval = 0
    private let store: UserDefaultsStore

    var onTimerComplete: (() -> Void)?
    var onOpenWindow: (() -> Void)?

    init(store: UserDefaultsStore = .shared) {
        self.store = store
        self.selectedMinutes = store.lastUsedMinutes
    }

    // MARK: - Computed

    var progress: Double {
        guard totalSeconds > 0 else { return 0 }
        return 1.0 - (remainingSeconds / totalSeconds)
    }

    var isBreakSegment: Bool {
        let lower = currentSegmentLabel.lowercased()
        return lower.contains("break") || lower.contains("rest")
    }

    var hasMoreSegments: Bool {
        currentSegmentIndex < activePlaylist.count - 1
    }

    // MARK: - Display

    var displayTime: String {
        formatTime(seconds: max(0, Int(remainingSeconds)))
    }

    var idleDisplayTime: String {
        formatTime(seconds: selectedMinutes * 60)
    }

    private func formatTime(seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%d:%02d", m, s)
    }

    // MARK: - Controls

    func start() {
        activePlaylistIndex = nil
        activePlaylist = []
        start(with: TimeInterval(selectedMinutes * 60))
    }

    func start(with duration: TimeInterval) {
        totalSeconds = duration
        remainingSeconds = duration
        state = .running
        store.lastUsedMinutes = selectedMinutes
        startTicking()
    }

    func pause() {
        guard state == .running else { return }
        pausedRemaining = remainingSeconds
        timerCancellable?.cancel()
        state = .paused
    }

    func resume() {
        guard state == .paused else { return }
        remainingSeconds = pausedRemaining
        state = .running
        startTicking()
    }

    func cancel() {
        timerCancellable?.cancel()
        state = .idle
        remainingSeconds = 0
        totalSeconds = 0
        currentSegmentIndex = 0
        currentSegmentLabel = ""
        activePlaylistIndex = nil
        activePlaylist = []
    }

    func restart() {
        timerCancellable?.cancel()
        start(with: totalSeconds)
    }

    func toggleFromStatusBar() {
        switch state {
        case .idle:     start()
        case .running:  pause()
        case .paused:   resume()
        case .finished: cancel()
        }
    }

    // MARK: - Playlists

    func startPlaylist(_ index: Int) {
        let allPlaylists = store.playlists
        guard index >= 0, index < allPlaylists.count else { return }
        let playlist = allPlaylists[index]
        guard !playlist.segments.isEmpty else { return }

        activePlaylist = playlist.segments
        activePlaylistIndex = index
        currentSegmentIndex = 0
        startSegment(playlist.segments[0])
    }

    func advancePlaylist() {
        currentSegmentIndex += 1
        if currentSegmentIndex < activePlaylist.count {
            startSegment(activePlaylist[currentSegmentIndex])
        } else {
            cancel()
        }
    }

    private func startSegment(_ segment: PomodoroSegment) {
        currentSegmentLabel = segment.label
        selectedMinutes = segment.minutes
        start(with: segment.duration)
    }

    // MARK: - Tick

    private func startTicking() {
        timerCancellable?.cancel()
        let tickStart = Date()
        let initialRemaining = remainingSeconds

        timerCancellable = Timer.publish(every: 0.25, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                let newRemaining = initialRemaining - Date().timeIntervalSince(tickStart)
                if newRemaining <= 0 {
                    self.remainingSeconds = 0
                    self.timerCancellable?.cancel()
                    self.state = .finished
                    self.onTimerComplete?()
                } else {
                    self.remainingSeconds = newRemaining
                }
            }
    }
}
