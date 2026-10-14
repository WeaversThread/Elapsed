import SwiftUI

struct FinishedTimerView: View {
    @ObservedObject var engine: TimerEngine
    @EnvironmentObject private var store: UserDefaultsStore

    var body: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 0)

            // "0:00", or "+0:42" while counting overtime
            Text(engine.displayTime)
                .font(Font.helveticaNeue(size: 42))
                .monospacedDigit()
                .foregroundStyle(Color.white.opacity(0.85))
                .shadow(color: Color.white.opacity(0.2), radius: 14, y: 0)
                .contentTransition(.numericText())
                .animation(.linear(duration: 0.1), value: engine.displayTime)

            HStack(spacing: 12) {
                if engine.hasMoreSegments {
                    HoverButton {
                        withAnimation(.spring(duration: 0.25)) {
                            engine.advancePlaylist()
                        }
                    } label: {
                        Text("continue")
                            .font(.system(size: 15, weight: .regular))
                            .foregroundStyle(Color.white.opacity(0.7))
                            .frame(width: 100, height: 34)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Capsule())
                    }
                }

                HoverButton {
                    withAnimation(.spring(duration: 0.25)) {
                        engine.cancel()
                    }
                } label: {
                    Text("stop")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(Color.white.opacity(0.7))
                        .frame(width: 80, height: 34)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Capsule())
                }

                HoverButton {
                    withAnimation(.spring(duration: 0.25)) {
                        engine.snooze()
                    }
                } label: {
                    Text("+\(store.prefs.snoozeMinutes)")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(Color.white.opacity(0.7))
                        .frame(width: 50, height: 34)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Capsule())
                }
                .accessibilityLabel("Snooze \(store.prefs.snoozeMinutes) minutes")
            }

            Spacer(minLength: 0)
        }
    }
}
