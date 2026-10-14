import SwiftUI

struct TimerWindowView: View {
    @ObservedObject var engine: TimerEngine
    var onClose: (() -> Void)?
    @EnvironmentObject private var store: UserDefaultsStore
    @State private var isHovered = false
    @State private var autoCloseTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)

            GeometryReader { geo in
                let timeSize = engine.state == .finished
                    ? min(geo.size.width * 0.3, geo.size.height * 0.35)
                    : min(geo.size.width * 0.35, geo.size.height * 0.45)

                VStack(spacing: 0) {
                    Spacer(minLength: 12)

                    // Segment name, "until 14:30" or "ends 14:55" at top
                    if !engine.contextLabel.isEmpty && engine.state != .idle {
                        Text(engine.contextLabel)
                            .font(.system(size: max(11, timeSize * 0.16), weight: .regular))
                            .foregroundStyle(Color.white.opacity(0.4))
                            .padding(.bottom, 4)
                    }

                    Spacer(minLength: 8)

                    // Main time display
                    if engine.state == .idle {
                        Text("No timer running")
                            .font(.system(size: max(12, timeSize * 0.18)))
                            .foregroundStyle(Color.white.opacity(0.3))
                    } else if engine.state == .finished {
                        finishedView(timeSize: timeSize)
                    } else {
                        Text(engine.displayTime)
                            .font(Font.helveticaNeue(size: timeSize))
                            .monospacedDigit()
                            .foregroundStyle(Color.white.opacity(0.85))
                            .shadow(color: shadowColor.opacity(0.15), radius: 14, y: 0)
                            .contentTransition(.numericText())
                            .animation(.linear(duration: 0.1), value: engine.displayTime)

                        if engine.state == .paused {
                            Text("paused")
                                .font(.system(size: max(11, timeSize * 0.16)))
                                .foregroundStyle(Color.white.opacity(0.3))
                                .padding(.top, 4)
                        }

                        if store.prefs.windowShowsBars {
                            TimerSliderView(
                                minutes: .constant(engine.selectedMinutes),
                                isRunning: true,
                                progress: engine.progress,
                                showCustomInput: .constant(false),
                                isBreak: engine.isBreakSegment
                            )
                            .allowsHitTesting(false)
                            .padding(.horizontal, 24)
                            .padding(.top, 6)
                        }
                    }

                    Spacer(minLength: 8)

                    // Hover controls
                    if engine.state != .idle && engine.state != .finished {
                        hoverControls
                            .padding(.bottom, 16)
                            .opacity(isHovered ? 1 : 0)
                            .scaleEffect(isHovered ? 1 : 0.85)
                            .animation(.spring(duration: 0.3, bounce: 0.2), value: isHovered)
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }

            // Close button — top left
            VStack {
                HStack {
                    Button {
                        onClose?()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Color.white.opacity(isHovered ? 0.6 : 0))
                            .frame(width: 20, height: 20)
                            .background(Color.white.opacity(isHovered ? 0.12 : 0))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close")
                    .animation(.easeInOut(duration: 0.15), value: isHovered)
                    .padding(.leading, 10)
                    .padding(.top, 10)

                    Spacer()
                }
                Spacer()
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
        )
        .onHover { hovering in
            isHovered = hovering
        }
        .onChange(of: engine.state) { oldState, newState in
            autoCloseTask?.cancel()
            // Only auto-close after a timer has finished and then been stopped
            if newState == .idle && oldState == .finished {
                startAutoCloseTimer()
            }
        }
    }

    // MARK: - Finished State

    private func finishedView(timeSize: CGFloat) -> some View {
        VStack(spacing: timeSize * 0.15) {
            Text(engine.displayTime)
                .font(Font.helveticaNeue(size: timeSize))
                .monospacedDigit()
                .foregroundStyle(Color.white.opacity(0.85))
                .shadow(color: Color.white.opacity(0.2), radius: 14, y: 0)
                .contentTransition(.numericText())
                .animation(.linear(duration: 0.1), value: engine.displayTime)

            // Drops snooze, then continue, when the window is too narrow for all three.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    if engine.hasMoreSegments { continueButton }
                    stopButton
                    snoozeButton
                }
                HStack(spacing: 12) {
                    if engine.hasMoreSegments { continueButton }
                    stopButton
                }
                stopButton
            }
        }
    }

    private var continueButton: some View {
        HoverButton {
            withAnimation(.spring(duration: 0.25)) {
                autoCloseTask?.cancel()
                engine.advancePlaylist()
            }
        } label: {
            Text("continue")
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(Color.white.opacity(0.7))
                .frame(width: 100, height: 38)
                .background(Color.white.opacity(0.1))
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.1), lineWidth: 1))
        }
    }

    private var stopButton: some View {
        HoverButton {
            withAnimation(.spring(duration: 0.25)) {
                autoCloseTask?.cancel()
                engine.cancel()
            }
        } label: {
            Text("stop")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.85))
                .frame(width: 110, height: 42)
                .background(Color.white.opacity(0.12))
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.15), lineWidth: 1))
        }
    }

    private var snoozeButton: some View {
        HoverButton {
            withAnimation(.spring(duration: 0.25)) {
                autoCloseTask?.cancel()
                engine.snooze()
            }
        } label: {
            Text("+\(store.prefs.snoozeMinutes)")
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(Color.white.opacity(0.7))
                .frame(width: 56, height: 38)
                .background(Color.white.opacity(0.1))
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.1), lineWidth: 1))
        }
        .accessibilityLabel("Snooze \(store.prefs.snoozeMinutes) minutes")
    }

    // MARK: - Hover Controls

    private var hoverControls: some View {
        HStack(spacing: 16) {
            HoverButton {
                withAnimation(.spring(duration: 0.25)) {
                    engine.cancel()
                }
            } label: {
                Text("cancel")
                    .timerControl()
            }

            HoverButton {
                engine.restart()
            } label: {
                Text("restart")
                    .timerControl()
            }

            HoverButton {
                if engine.state == .paused {
                    engine.resume()
                } else {
                    engine.pause()
                }
            } label: {
                Text(engine.state == .paused ? "resume" : "pause")
                    .timerControl()
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.08))
        .clipShape(Capsule())
        .overlay(
            Capsule().strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
        )
    }

    // MARK: - Auto Close

    private func startAutoCloseTimer() {
        autoCloseTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(30))
            guard !Task.isCancelled else { return }
            if engine.state == .finished || engine.state == .idle {
                onClose?()
            }
        }
    }

    private var shadowColor: Color {
        if engine.state == .finished { return .white }
        return store.prefs.accent(for: engine.currentSegmentKind)
    }
}
