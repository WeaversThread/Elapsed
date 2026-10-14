import Combine
import Foundation

/// What just finished, for the alarm and the notification.
struct TimerCompletion {
    let label: String
    let next: PomodoroSegment?
    /// The playlist moved on by itself; only chime once.
    let autoAdvanced: Bool
}

@MainActor
final class TimerEngine: ObservableObject {
    @Published var state: TimerState = .idle
    @Published var remainingSeconds: TimeInterval = 0
    @Published var totalSeconds: TimeInterval = 0
    @Published var selectedMinutes: Int
    @Published var overtimeSeconds: TimeInterval = 0

    @Published var currentSegmentIndex: Int = 0
    @Published var currentSegmentLabel: String = ""
    @Published var currentSegmentKind: SegmentKind = .focus
    /// Set while counting down to a clock time ("until 14:30").
    @Published private(set) var targetDate: Date?
    @Published private(set) var endDate: Date?

    private(set) var activePlaylist: Playlist?
    /// Overtime stops counting after an hour, so a forgotten timer doesn't tick all night.
    static let overtimeLimit: TimeInterval = 3600
    /// Fires once, exactly when the countdown ends.
    private var endTimer: Timer?
    /// Fires once a second, just after the shown time changes. Off while the screen sleeps.
    private var displayTimer: Timer?
    private var isDisplayAsleep = false
    private var pausedRemaining: TimeInterval = 0
    private var finishedAt: Date?
    private var activity: NSObjectProtocol?
    private let store: UserDefaultsStore

    var onTimerComplete: ((TimerCompletion) -> Void)?
    var onOpenWindow: (() -> Void)?
    var onOpenSettings: (() -> Void)?

    init(store: UserDefaultsStore = .shared) {
        self.store = store
        self.selectedMinutes = store.lastUsedMinutes
        restore()
    }

    // MARK: - Computed

    var progress: Double {
        guard totalSeconds > 0 else { return 0 }
        return 1.0 - (remainingSeconds / totalSeconds)
    }

    var isBreakSegment: Bool {
        currentSegmentKind == .rest
    }

    var nextSegmentIndex: Int? {
        guard let playlist = activePlaylist, !playlist.segments.isEmpty else { return nil }
        let next = currentSegmentIndex + 1
        if next < playlist.segments.count { return next }
        return playlist.repeats ? 0 : nil
    }

    var nextSegment: PomodoroSegment? {
        guard let playlist = activePlaylist, let index = nextSegmentIndex else { return nil }
        return playlist.segments[index]
    }

    var hasMoreSegments: Bool {
        nextSegmentIndex != nil
    }

    // MARK: - Display

    var displayTime: String {
        if state == .finished {
            return store.prefs.overtime ? "+" + Self.formatTime(seconds: Int(overtimeSeconds)) : "0:00"
        }
        return Self.formatTime(seconds: max(0, Int(remainingSeconds)))
    }

    var idleDisplayTime: String {
        Self.formatTime(seconds: selectedMinutes * 60)
    }

    /// Segment name, "until 14:30" or "ends 14:55" — whatever explains the running timer.
    var contextLabel: String {
        if !currentSegmentLabel.isEmpty { return currentSegmentLabel }
        if let targetDate { return "until " + Self.clock(targetDate) }
        if state == .running, let endDate { return "ends " + Self.clock(endDate) }
        return ""
    }

    static func formatTime(seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%d:%02d", m, s)
    }

    static func clock(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    // MARK: - Controls

    func start() {
        let minutes = PomodoroSegment.clampMinutes(selectedMinutes)
        store.lastUsedMinutes = minutes
        clearContext()
        begin(duration: TimeInterval(minutes * 60))
    }

    func start(minutes: Int) {
        selectedMinutes = PomodoroSegment.clampMinutes(minutes)
        start()
    }

    /// Count down to a clock time instead of for a duration.
    func start(until target: Date) {
        let duration = target.timeIntervalSinceNow
        guard duration > 0 else { return }
        clearContext()
        targetDate = target
        begin(duration: duration)
    }

    func pause() {
        guard state == .running else { return }
        pausedRemaining = max(0, endDate?.timeIntervalSinceNow ?? remainingSeconds)
        remainingSeconds = pausedRemaining
        stopTicking()
        endDate = nil
        state = .paused
        persist()
    }

    func resume() {
        guard state == .paused else { return }
        // A paused "until" timer no longer ends at that time.
        targetDate = nil
        run(remaining: pausedRemaining)
    }

    func cancel() {
        stopTicking()
        state = .idle
        remainingSeconds = 0
        totalSeconds = 0
        overtimeSeconds = 0
        endDate = nil
        finishedAt = nil
        clearContext()
        persist()
    }

    func restart() {
        guard totalSeconds > 0 else { return }
        targetDate = nil
        begin(duration: totalSeconds)
    }

    /// Another few minutes of the same timer, from the finished state.
    func snooze() {
        guard state == .finished || state == .idle else { return }
        targetDate = nil
        begin(duration: TimeInterval(max(1, store.prefs.snoozeMinutes) * 60))
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
        let all = store.playlists
        guard all.indices.contains(index) else { return }
        startPlaylist(all[index])
    }

    @discardableResult
    func startPlaylist(named name: String) -> Bool {
        guard let playlist = store.playlists.first(where: {
            $0.name.compare(name, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }) else { return false }
        startPlaylist(playlist)
        return true
    }

    private func startPlaylist(_ playlist: Playlist) {
        guard !playlist.segments.isEmpty else { return }
        clearContext()
        activePlaylist = playlist
        startSegment(at: 0)
    }

    func advancePlaylist() {
        guard let next = nextSegmentIndex else { cancel(); return }
        startSegment(at: next)
    }

    private func startSegment(at index: Int) {
        guard let playlist = activePlaylist, playlist.segments.indices.contains(index) else {
            cancel()
            return
        }
        let segment = playlist.segments[index]
        currentSegmentIndex = index
        currentSegmentLabel = segment.label
        currentSegmentKind = segment.kind
        targetDate = nil
        begin(duration: segment.duration)
    }

    private func clearContext() {
        activePlaylist = nil
        currentSegmentIndex = 0
        currentSegmentLabel = ""
        currentSegmentKind = .focus
        targetDate = nil
    }

    // MARK: - Tick

    private func begin(duration: TimeInterval) {
        totalSeconds = duration
        overtimeSeconds = 0
        finishedAt = nil
        run(remaining: duration)
    }

    private func run(remaining: TimeInterval) {
        remainingSeconds = remaining
        endDate = Date().addingTimeInterval(remaining)
        state = .running
        startTicking()
        persist()
    }

    /// No polling: one precise timer for the end, plus a once-a-second display tick
    /// lined up with the second boundaries, so the app wakes only when something changes.
    private func startTicking() {
        stopTicking()
        guard let endDate else { return }
        beginActivity()
        endTimer = makeTimer(fire: endDate, every: nil, tolerance: 0) { engine in
            guard engine.state == .running, let end = engine.endDate else { return }
            engine.finish(at: end)
        }
        startDisplayTicks()
    }

    private func stopTicking() {
        endTimer?.invalidate()
        endTimer = nil
        stopDisplayTicks()
        endActivity()
    }

    /// The shown time counts whole seconds from this date: the end while running,
    /// the finish while counting overtime.
    private var tickReference: Date? {
        switch state {
        case .running:  endDate
        case .finished: store.prefs.overtime && overtimeSeconds < Self.overtimeLimit ? finishedAt : nil
        case .idle, .paused: nil
        }
    }

    private func startDisplayTicks() {
        stopDisplayTicks()
        guard !isDisplayAsleep, let reference = tickReference else { return }
        let now = Date()
        let offset = now.timeIntervalSince(reference)
        var untilNextSecond = offset.rounded(.up) - offset
        if untilNextSecond < 0.01 { untilNextSecond += 1 }
        // A hair past the boundary, so the new second is what gets shown.
        displayTimer = makeTimer(fire: now.addingTimeInterval(untilNextSecond + 0.01), every: 1, tolerance: 0.05) {
            $0.tick(Date())
        }
    }

    private func stopDisplayTicks() {
        displayTimer?.invalidate()
        displayTimer = nil
    }

    /// While the screen is off nobody can see the seconds, so only the end timer stays.
    func setDisplayAsleep(_ asleep: Bool) {
        guard asleep != isDisplayAsleep else { return }
        isDisplayAsleep = asleep
        if asleep {
            stopDisplayTicks()
        } else {
            tick(Date())
            startDisplayTicks()
        }
    }

    private func makeTimer(
        fire date: Date,
        every interval: TimeInterval?,
        tolerance: TimeInterval,
        action: @escaping @MainActor @Sendable (TimerEngine) -> Void
    ) -> Timer {
        let timer = Timer(fire: date, interval: interval ?? 0, repeats: interval != nil) { [weak self] _ in
            // Scheduled on the main run loop.
            MainActor.assumeIsolated {
                guard let self else { return }
                action(self)
            }
        }
        timer.tolerance = tolerance
        RunLoop.main.add(timer, forMode: .common)
        return timer
    }

    private func tick(_ now: Date) {
        switch state {
        case .running:
            guard let endDate else { return }
            let remaining = endDate.timeIntervalSince(now)
            if remaining <= 0 {
                finish(at: endDate)
            } else {
                remainingSeconds = remaining
            }
        case .finished:
            guard let finishedAt else { return }
            overtimeSeconds = min(max(0, now.timeIntervalSince(finishedAt)), Self.overtimeLimit)
            if overtimeSeconds >= Self.overtimeLimit { stopDisplayTicks() }
        case .idle, .paused:
            break
        }
    }

    private func finish(at end: Date) {
        stopTicking()
        remainingSeconds = 0
        endDate = nil

        if let playlist = activePlaylist, playlist.autoAdvance, let next = nextSegmentIndex {
            onTimerComplete?(TimerCompletion(
                label: currentSegmentLabel,
                next: playlist.segments[next],
                autoAdvanced: true
            ))
            startSegment(at: next)
            return
        }

        finishedAt = end
        overtimeSeconds = min(max(0, Date().timeIntervalSince(end)), Self.overtimeLimit)
        state = .finished
        // Overtime is display only: it doesn't hold off App Nap.
        startDisplayTicks()
        persist()
        onTimerComplete?(TimerCompletion(label: currentSegmentLabel, next: nextSegment, autoAdvanced: false))
    }

    // MARK: - App Nap

    /// Keeps App Nap from delaying the end of a running countdown.
    private func beginActivity() {
        guard activity == nil else { return }
        activity = ProcessInfo.processInfo.beginActivity(
            options: .userInitiatedAllowingIdleSystemSleep,
            reason: "Elapsed timer running"
        )
    }

    private func endActivity() {
        guard let activity else { return }
        ProcessInfo.processInfo.endActivity(activity)
        self.activity = nil
    }

    // MARK: - Persistence

    private func persist() {
        switch state {
        case .running, .paused:
            store.snapshot = TimerSnapshot(
                isPaused: state == .paused,
                endDate: endDate,
                remaining: state == .paused ? pausedRemaining : remainingSeconds,
                total: totalSeconds,
                label: currentSegmentLabel,
                kind: currentSegmentKind,
                playlistID: activePlaylist?.id,
                segmentIndex: currentSegmentIndex,
                targetDate: targetDate
            )
        case .idle, .finished:
            store.snapshot = nil
        }
    }

    /// Picks up a timer that was running or paused when the app last quit.
    /// One that ran out while the app was closed goes quietly back to idle.
    private func restore() {
        guard let snap = store.snapshot else { return }

        if let id = snap.playlistID,
           let playlist = store.playlists.first(where: { $0.id == id }),
           playlist.segments.indices.contains(snap.segmentIndex) {
            activePlaylist = playlist
            currentSegmentIndex = snap.segmentIndex
        }
        currentSegmentLabel = snap.label
        currentSegmentKind = snap.kind
        targetDate = snap.targetDate
        totalSeconds = snap.total

        if snap.isPaused, snap.remaining > 0 {
            pausedRemaining = snap.remaining
            remainingSeconds = snap.remaining
            state = .paused
        } else if let end = snap.endDate, end.timeIntervalSinceNow > 0 {
            remainingSeconds = end.timeIntervalSinceNow
            endDate = end
            state = .running
            startTicking()
        } else {
            cancel()
        }
    }
}
