import SwiftUI

enum SettingsTab: String, CaseIterable, Identifiable {
    case timer, playlists, look, sound, general

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

/// The settings window: a dark-glass panel with a text tab row.
/// Every change applies immediately — there's no Save.
struct SettingsView: View {
    let audio: AudioManager
    var onClose: () -> Void

    @State private var tab: SettingsTab = .timer
    @State private var isHovered = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)

            VStack(spacing: 0) {
                tabRow
                    .padding(.top, 14)
                    .padding(.bottom, 10)

                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 1)

                ScrollView(.vertical, showsIndicators: false) {
                    Group {
                        switch tab {
                        case .timer:     TimerSettingsTab()
                        case .playlists: PlaylistsSettingsTab()
                        case .look:      LookSettingsTab()
                        case .sound:     SoundSettingsTab(audio: audio)
                        case .general:   GeneralSettingsTab()
                        }
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            // Close button — top left, on hover
            Button(action: onClose) {
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
        }
        .frame(width: 380, height: 460)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
        )
        .onHover { isHovered = $0 }
    }

    private var tabRow: some View {
        HStack(spacing: 16) {
            ForEach(SettingsTab.allCases) { item in
                HoverButton {
                    withAnimation(.spring(duration: 0.2)) { tab = item }
                } label: {
                    Text(item.title)
                        .font(.system(size: 12, weight: tab == item ? .semibold : .regular))
                        .foregroundStyle(Color.white.opacity(tab == item ? 0.85 : 0.35))
                        .padding(.vertical, 2)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}
