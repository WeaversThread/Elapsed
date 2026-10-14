import Foundation
import Testing
@testable import Elapsed

@MainActor
@Suite struct TimerEngineTests {
    let defaults: UserDefaults
    let store: UserDefaultsStore

    init() {
        let suite = "ElapsedTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        store = UserDefaultsStore(defaults: defaults)
        store.playlists = [
            Playlist(name: "Short", segments: [
                PomodoroSegment(label: "Work", minutes: 25, kind: .focus),
                PomodoroSegment(label: "Pause", minutes: 5, kind: .rest),
            ], repeats: true),
        ]
    }

    @Test func playlistDoesNotTouchSelectedTime() {
        let engine = TimerEngine(store: store)
        let lastUsed = store.lastUsedMinutes
        engine.selectedMinutes = 7
        #expect(engine.startPlaylist(named: "short"))
        #expect(engine.selectedMinutes == 7)
        #expect(store.lastUsedMinutes == lastUsed)
        engine.cancel()
    }

    @Test func breakColorComesFromKindNotLabel() {
        let engine = TimerEngine(store: store)
        engine.startPlaylist(named: "Short")
        #expect(!engine.isBreakSegment)
        engine.advancePlaylist()
        #expect(engine.currentSegmentLabel == "Pause")
        #expect(engine.isBreakSegment)
        engine.cancel()
    }

    @Test func repeatWrapsToFirstSegment() {
        let engine = TimerEngine(store: store)
        engine.startPlaylist(named: "Short")
        engine.advancePlaylist()
        #expect(engine.nextSegment?.label == "Work")
        engine.advancePlaylist()
        #expect(engine.currentSegmentIndex == 0)
        engine.cancel()
    }

    @Test func runningTimerIsRestored() {
        let engine = TimerEngine(store: store)
        engine.start(minutes: 10)
        #expect(store.snapshot?.isPaused == false)

        let relaunched = TimerEngine(store: store)
        #expect(relaunched.state == .running)
        #expect(relaunched.remainingSeconds > 590)
        relaunched.cancel()
        #expect(store.snapshot == nil)
    }

    @Test func expiredTimerGoesQuietlyIdle() {
        store.snapshot = TimerSnapshot(
            isPaused: false, endDate: Date().addingTimeInterval(-30), remaining: 0, total: 60,
            label: "", kind: .focus, playlistID: nil, segmentIndex: 0, targetDate: nil
        )
        var completed = false
        let engine = TimerEngine(store: store)
        engine.onTimerComplete = { _ in completed = true }
        #expect(engine.state == .idle)
        #expect(store.snapshot == nil)
        #expect(!completed)
    }

    @Test func finishedTimerCountsOvertime() async throws {
        let engine = TimerEngine(store: store)
        var completion: TimerCompletion?
        engine.onTimerComplete = { completion = $0 }
        engine.start(until: Date().addingTimeInterval(0.3))
        try await Task.sleep(for: .seconds(1.6))

        #expect(engine.state == .finished)
        #expect(completion != nil)
        #expect(store.snapshot == nil)
        #expect(engine.overtimeSeconds >= 1)
        #expect(engine.displayTime.hasPrefix("+0:0"))
        engine.cancel()
    }

    @Test func countdownToClockTimeIsLabelled() {
        let engine = TimerEngine(store: store)
        engine.start(until: Date().addingTimeInterval(3600))
        #expect(engine.contextLabel.hasPrefix("until "))
        engine.pause()
        engine.resume()
        // Paused and resumed, it no longer ends at that time.
        #expect(engine.contextLabel.hasPrefix("ends "))
        engine.cancel()
    }
}
