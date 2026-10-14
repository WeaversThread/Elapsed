import SwiftUI

struct StatusBarLabel: View {
    @ObservedObject var engine: TimerEngine
    @EnvironmentObject private var store: UserDefaultsStore
    @State private var pauseBlink = false

    private var isActive: Bool {
        engine.state == .running || engine.state == .paused || engine.state == .finished
    }

    var body: some View {
        StatusBarFace(
            text: isActive ? engine.displayTime : engine.idleDisplayTime,
            style: store.prefs.statusStyle,
            state: engine.state,
            progress: engine.state == .finished ? 1 : engine.progress,
            accent: engine.currentSegmentKind == .rest ? store.prefs.restAccent : store.prefs.focusAccent,
            pauseBlink: pauseBlink
        )
        .animation(.spring(duration: 0.25), value: engine.state)
        .onAppear { updateBlink(engine.state) }
        .onChange(of: engine.state) { _, newState in
            updateBlink(newState)
        }
    }

    private func updateBlink(_ state: TimerState) {
        withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
            pauseBlink = state == .paused
        }
    }
}

/// The menu bar time in its capsule, in either style. Follows the menu bar:
/// white on a dark one, black on a light one. Also drawn as a preview in Look settings.
struct StatusBarFace: View {
    let text: String
    let style: StatusStyle
    let state: TimerState
    let progress: Double
    let accent: Accent
    var pauseBlink = false

    @Environment(\.colorScheme) private var colorScheme

    private var isDark: Bool { colorScheme == .dark }
    private var isActive: Bool { state != .idle }
    private var ink: Color { isDark ? .white : .black }

    var body: some View {
        Group {
            if !isActive {
                ZStack {
                    Capsule().strokeBorder(Color(white: isDark ? 0.7 : 0.3).opacity(0.5), lineWidth: 1)
                    label(Color(white: isDark ? 0.85 : 0.15))
                }
            } else if style == .capsule {
                ZStack {
                    Capsule().fill(ink.opacity(
                        state == .paused ? (pauseBlink ? 0.5 : 0.3) : (isDark ? 0.85 : 0.8)
                    ))
                    label(isDark ? Color(white: 0.08) : .white)
                }
            } else {
                progressFace
            }
        }
        .frame(width: 68, height: 18)
        .contentTransition(.numericText())
    }

    /// The accent fills left to right as time elapses; the text flips color where the fill passes.
    private var progressFace: some View {
        GeometryReader { geo in
            let filled = geo.size.width * min(max(progress, 0), 1)
            ZStack(alignment: .leading) {
                Rectangle().fill(ink.opacity(0.18))
                Rectangle()
                    .fill(accent.color.opacity(state == .paused ? (pauseBlink ? 0.75 : 0.45) : 0.8))
                    .frame(width: filled)
                label(ink.opacity(0.95))
                label(accent.isLight ? Color(white: 0.08) : .white)
                    .mask(alignment: .leading) {
                        Rectangle().frame(width: filled)
                    }
            }
        }
        .clipShape(Capsule())
    }

    private func label(_ color: Color) -> some View {
        Text(text)
            .font(.system(size: 11, weight: isActive ? .medium : .regular, design: .monospaced))
            .foregroundStyle(color)
            .minimumScaleFactor(0.6)
            .lineLimit(1)
            .frame(maxWidth: .infinity)
    }
}
