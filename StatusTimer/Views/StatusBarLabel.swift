import SwiftUI

struct StatusBarLabel: View {
    @ObservedObject var engine: TimerEngine
    @EnvironmentObject private var store: UserDefaultsStore
    @State private var pauseBlink = false

    private var isActive: Bool {
        engine.state == .running || engine.state == .paused || engine.state == .finished
    }

    private var style: StatusStyle {
        store.prefs.statusStyle
    }

    var body: some View {
        ZStack {
            StatusBarBackground(
                style: style,
                state: engine.state,
                progress: engine.state == .finished ? 1 : engine.progress,
                accent: store.prefs.accent(for: engine.currentSegmentKind),
                pauseBlink: pauseBlink
            )

            Text(isActive ? engine.displayTime : engine.idleDisplayTime)
                .font(.system(size: 11, weight: isActive ? .medium : .regular, design: .monospaced))
                .foregroundStyle(StatusBarBackground.textColor(style: style, isActive: isActive))
                .shadow(color: style == .progress && isActive ? .black.opacity(0.35) : .clear, radius: 1)
                .opacity(textOpacity)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
        .frame(width: 68, height: 18)
        .contentTransition(.numericText())
        .animation(.spring(duration: 0.25), value: engine.state)
        .onAppear { updateBlink(engine.state) }
        .onChange(of: engine.state) { _, newState in
            updateBlink(newState)
        }
    }

    /// Minimal has no capsule to blink, so the text does it.
    private var textOpacity: Double {
        guard style == .minimal else { return 1 }
        switch engine.state {
        case .paused: return pauseBlink ? 0.85 : 0.4
        case .idle:   return 0.6
        default:      return 1
        }
    }

    private func updateBlink(_ state: TimerState) {
        withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
            pauseBlink = state == .paused
        }
    }
}

/// The capsule behind the menu bar time, in each of the three styles.
/// Also drawn as a preview in the Look settings.
struct StatusBarBackground: View {
    let style: StatusStyle
    let state: TimerState
    let progress: Double
    let accent: Color
    var pauseBlink = false

    private var isActive: Bool { state != .idle }

    var body: some View {
        switch style {
        case .capsule:
            if isActive {
                Capsule().fill(Color.white.opacity(
                    state == .paused ? (pauseBlink ? 0.5 : 0.3) : 0.85
                ))
            } else {
                idleOutline
            }
        case .progress:
            if isActive {
                // Fills with the accent as time elapses.
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle().fill(Color.white.opacity(0.18))
                        Rectangle()
                            .fill(accent.opacity(state == .paused ? (pauseBlink ? 0.75 : 0.45) : 0.75))
                            .frame(width: geo.size.width * min(max(progress, 0), 1))
                    }
                }
                .clipShape(Capsule())
            } else {
                idleOutline
            }
        case .minimal:
            Color.clear
        }
    }

    private var idleOutline: some View {
        Capsule().strokeBorder(Color(white: 0.7).opacity(0.5), lineWidth: 1)
    }

    static func textColor(style: StatusStyle, isActive: Bool) -> Color {
        switch style {
        case .capsule:  isActive ? Color(white: 0.08) : Color(white: 0.85)
        case .progress: Color(white: isActive ? 0.97 : 0.85)
        case .minimal:  Color(white: 0.92)
        }
    }
}
