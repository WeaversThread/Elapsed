import SwiftUI

struct FinishedTimerView: View {
    @ObservedObject var engine: TimerEngine

    private var hasMoreSegments: Bool {
        engine.activePlaylistIndex != nil && engine.hasMoreSegments
    }

    var body: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 0)

            Text("0:00")
                .font(Font.helveticaNeue(size: 42))
                .monospacedDigit()
                .foregroundStyle(Color.white.opacity(0.85))
                .shadow(color: Color.white.opacity(0.2), radius: 14, y: 0)

            HStack(spacing: 12) {
                if hasMoreSegments {
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
            }

            Spacer(minLength: 0)
        }
    }
}
