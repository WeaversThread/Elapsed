import SwiftUI

struct ActiveTimerView: View {
    @ObservedObject var engine: TimerEngine

    var body: some View {
        VStack(spacing: 14) {
            // Slider showing progress
            TimerSliderView(
                minutes: .constant(engine.selectedMinutes),
                isRunning: true,
                progress: engine.progress,
                showCustomInput: .constant(false),
                isBreak: engine.isBreakSegment
            )
            .allowsHitTesting(false)

            // Controls row
            HStack(spacing: 0) {
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
                    engine.onOpenWindow?()
                } label: {
                    Image(systemName: "macwindow")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.white.opacity(0.35))
                        .frame(width: 24, height: 24)
                }

                Spacer()

                if !engine.currentSegmentLabel.isEmpty {
                    Text(engine.currentSegmentLabel)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(Color.white.opacity(0.35))
                }
            }

            Spacer(minLength: 0)

            // Bottom row: pause + time
            HStack(alignment: .bottom) {
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

                Spacer()

                Text(engine.displayTime)
                    .font(Font.helveticaNeue(size: 42))
                    .monospacedDigit()
                    .foregroundStyle(Color.white.opacity(0.85))
                    .shadow(color: (engine.isBreakSegment ? Color.blue : Color.red).opacity(0.15), radius: 10, y: 0)
                    .contentTransition(.numericText())
                    .animation(.linear(duration: 0.1), value: engine.displayTime)
            }
        }
    }
}

// MARK: - Shared text modifier for control labels

extension View {
    func timerControl() -> some View {
        self
            .font(.system(size: 13, weight: .regular))
            .foregroundStyle(Color.white.opacity(0.45))
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
    }
}
