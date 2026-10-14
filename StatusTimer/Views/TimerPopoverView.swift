import SwiftUI

struct TimerPopoverView: View {
    @ObservedObject var engine: TimerEngine
    @State private var showCustomInput = false
    @State private var showSettings = false
    @State private var playlists: [Playlist] = UserDefaultsStore.shared.playlists
    @State private var scrubHovered = false
    @State private var scrubFraction: CGFloat = 0
    @State private var scrollTarget: Int?

    private let presets = TimerPreset.defaults

    var body: some View {
        ZStack {
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)

            VStack(spacing: 0) {
                if engine.state == .finished {
                    FinishedTimerView(engine: engine)
                        .transition(.opacity)
                } else if engine.state != .idle {
                    ActiveTimerView(engine: engine)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .bottom)),
                            removal: .opacity.combined(with: .move(edge: .top))
                        ))
                } else {
                    idleView
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .top)),
                            removal: .opacity.combined(with: .move(edge: .bottom))
                        ))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .frame(width: 320, height: 190)
        .animation(.spring(duration: 0.3), value: engine.state)
        .sheet(isPresented: $showSettings, onDismiss: {
            playlists = UserDefaultsStore.shared.playlists
        }) {
            SettingsView()
        }
    }

    // MARK: - Idle View

    private var idleView: some View {
        VStack(spacing: 0) {
            TimerSliderView(
                minutes: $engine.selectedMinutes,
                isRunning: false,
                progress: 0,
                showCustomInput: $showCustomInput
            )

            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)
                .padding(.vertical, 10)

            // Presets
            HStack(spacing: 0) {
                ForEach(presets) { preset in
                    HoverButton {
                        withAnimation(.spring(duration: 0.2)) {
                            engine.selectedMinutes = preset.minutes
                            showCustomInput = false
                        }
                    } label: {
                        Text(preset.label)
                            .font(.system(size: 11, weight: engine.selectedMinutes == preset.minutes ? .semibold : .regular))
                            .foregroundStyle(engine.selectedMinutes == preset.minutes ? Color.white : Color.white.opacity(0.35))
                            .frame(maxWidth: .infinity, minHeight: 28)
                            .contentShape(Rectangle())
                    }
                }
            }

            Spacer(minLength: 0)

            // Bottom row
            HStack(alignment: .center, spacing: 8) {
                // Scrollable playlist carousel
                playlistCarousel

                // Scrub bar
                playlistScrubBar

                // Utility buttons
                VStack(spacing: 4) {
                    HoverButton {
                        engine.onOpenWindow?()
                    } label: {
                        Image(systemName: "macwindow")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.white.opacity(0.25))
                            .frame(width: 20, height: 20)
                    }

                    HoverButton {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.white.opacity(0.25))
                            .frame(width: 20, height: 20)
                    }
                }

                Spacer()

                HoverButton {
                    withAnimation(.spring(duration: 0.25)) { engine.start() }
                } label: {
                    Image(systemName: "play.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.white.opacity(0.5))
                        .frame(width: 30, height: 30)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Circle())
                }

                Text(engine.idleDisplayTime)
                    .font(Font.helveticaNeue(size: 36))
                    .monospacedDigit()
                    .foregroundStyle(Color.white.opacity(0.85))
                    .shadow(color: Color.white.opacity(0.1), radius: 10, y: 0)
                    .contentTransition(.numericText())
                    .animation(.spring(duration: 0.2), value: engine.selectedMinutes)
                    .fixedSize()
            }
        }
    }

    private var playlistCarousel: some View {
        let enabled = playlists.enumerated().filter { $0.element.isEnabled }
        return ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(enabled, id: \.element.id) { index, playlist in
                        HoverButton {
                            withAnimation(.spring(duration: 0.25)) {
                                engine.startPlaylist(index)
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 7))
                                    .foregroundStyle(Color.white.opacity(0.4))

                                Text(playlist.name)
                                    .font(.system(size: 10))
                                    .foregroundStyle(Color.white.opacity(0.35))
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                        .id(index)
                    }
                }
            }
            .frame(maxWidth: 80, maxHeight: 44)
            .onChange(of: scrollTarget) { _, target in
                guard let target else { return }
                withAnimation(.spring(duration: 0.2)) {
                    proxy.scrollTo(target, anchor: .center)
                }
            }
        }
    }

    private var playlistScrubBar: some View {
        let enabled = playlists.enumerated().filter { $0.element.isEnabled }
        let count = enabled.count

        return GeometryReader { geo in
            let height = geo.size.height
            let thumbHeight: CGFloat = count > 1 ? max(8, height / CGFloat(count)) : height
            let trackRange = height - thumbHeight
            let thumbY = trackRange * scrubFraction

            ZStack(alignment: .top) {
                // Track
                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 1)

                // Thumb — only visible on hover
                if scrubHovered && count > 1 {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.white.opacity(0.35))
                        .frame(width: 3, height: thumbHeight)
                        .offset(y: thumbY)
                        .transition(.opacity)
                }
            }
            .frame(width: 6, height: height)
            .contentShape(Rectangle())
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) {
                    scrubHovered = hovering
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard count > 1 else { return }
                        let fraction = min(max(value.location.y / height, 0), 1)
                        scrubFraction = fraction
                        let targetIdx = Int(round(fraction * CGFloat(count - 1)))
                        let realIndex = enabled[targetIdx].offset
                        scrollTarget = realIndex
                    }
            )
        }
        .frame(width: 6, height: 40)
    }
}

// MARK: - Hover Button

struct HoverButton<Label: View>: View {
    let action: () -> Void
    @ViewBuilder let label: Label
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            label
                .scaleEffect(isHovered ? 1.08 : 1.0)
                .brightness(isHovered ? 0.15 : 0)
                .animation(.spring(duration: 0.2, bounce: 0.3), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Visual Effect

struct VisualEffectBlur: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        view.appearance = NSAppearance(named: .darkAqua)
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
