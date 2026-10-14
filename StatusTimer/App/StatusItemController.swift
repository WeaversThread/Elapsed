import AppKit
import Combine

/// Draws the menu bar item, and only when what it shows actually changes.
@MainActor
final class StatusItemController {
    private let button: NSStatusBarButton
    private let engine: TimerEngine
    private let store: UserDefaultsStore
    private var cancellables = Set<AnyCancellable>()
    private var shown: StatusBarFace?

    private var breathTimer: Timer?
    private var pausedAt: Date?
    private var glow: Double = 0

    /// Paused breathes smoothly for a few breaths, then settles into a once-a-second step
    /// so a long pause doesn't redraw the menu bar many times a second.
    private static let breathPeriod: TimeInterval = 2
    private static let smoothBreaths = 3
    private static let smoothFPS: Double = 15

    init(button: NSStatusBarButton, engine: TimerEngine, store: UserDefaultsStore) {
        self.button = button
        self.engine = engine
        self.store = store
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleNone

        // objectWillChange fires before the new value lands, so draw on the next pass.
        engine.objectWillChange
            .merge(with: store.objectWillChange)
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.render() }
            .store(in: &cancellables)
        render()
    }

    private func render() {
        updateBreathing()
        let isActive = engine.state != .idle
        let face = StatusBarFace(
            text: isActive ? engine.displayTime : engine.idleDisplayTime,
            style: store.prefs.statusStyle,
            state: engine.state,
            progress: engine.state == .finished ? 1 : engine.progress,
            accent: engine.currentSegmentKind == .rest ? store.prefs.restAccent : store.prefs.focusAccent,
            glow: glow
        )
        guard face != shown else { return }
        shown = face
        button.image = face.image()
        button.setAccessibilityValue(face.text)
    }

    // MARK: - Paused breathing

    private func updateBreathing() {
        guard engine.state == .paused else {
            breathTimer?.invalidate()
            breathTimer = nil
            pausedAt = nil
            glow = 0
            return
        }
        guard pausedAt == nil else { return }
        pausedAt = Date()
        startBreathTimer(interval: 1 / Self.smoothFPS, tolerance: 0.005)
    }

    private func startBreathTimer(interval: TimeInterval, tolerance: TimeInterval) {
        breathTimer?.invalidate()
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.breathe()
            }
        }
        timer.tolerance = tolerance
        RunLoop.main.add(timer, forMode: .common)
        breathTimer = timer
    }

    private func breathe() {
        guard let pausedAt else { return }
        let elapsed = Date().timeIntervalSince(pausedAt)
        let smoothDuration = Self.breathPeriod * Double(Self.smoothBreaths)

        if elapsed < smoothDuration {
            // Starts dim, swells to bright and back: one breath per period.
            glow = (1 - cos(2 * .pi * elapsed / Self.breathPeriod)) / 2
        } else {
            if breathTimer?.timeInterval != 1 {
                startBreathTimer(interval: 1, tolerance: 0.1)
            }
            // Bright on even seconds, dim on odd ones.
            glow = Int(elapsed - smoothDuration) % 2 == 0 ? 1 : 0
        }
        render()
    }
}
