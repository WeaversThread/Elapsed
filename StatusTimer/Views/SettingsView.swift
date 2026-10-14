import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var playlists: [Playlist]
    @State private var expandedIndex: Int? = 0

    init() {
        _playlists = State(initialValue: UserDefaultsStore.shared.playlists)
    }

    var body: some View {
        ZStack {
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)

            VStack(spacing: 10) {
                // Header
                HStack {
                    Text("Playlists")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.9))
                    Spacer()
                }

                Divider().overlay(Color.white.opacity(0.1))

                // Playlist list
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 8) {
                        ForEach(Array(playlists.enumerated()), id: \.element.id) { index, _ in
                            playlistSection(at: index)
                        }
                    }
                }

                // Add playlist
                Button {
                    withAnimation(.spring(duration: 0.2)) {
                        let new = Playlist(name: "New Playlist", segments: [
                            PomodoroSegment(label: "Work", minutes: 25),
                            PomodoroSegment(label: "Break", minutes: 5),
                        ])
                        playlists.append(new)
                        expandedIndex = playlists.count - 1
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .medium))
                        Text("Add playlist")
                            .font(.system(size: 11))
                    }
                    .foregroundStyle(Color.white.opacity(0.4))
                }
                .buttonStyle(.plain)

                Spacer(minLength: 0)

                // Bottom buttons
                HStack {
                    HoverButton { dismiss() } label: {
                        Text("Cancel").timerControl()
                    }
                    Spacer()
                    HoverButton {
                        UserDefaultsStore.shared.playlists = playlists
                        dismiss()
                    } label: {
                        Text("Save").timerControl()
                    }
                }
            }
            .padding(18)
        }
        .frame(width: 320, height: 400)
    }

    // MARK: - Playlist Section

    private func playlistSection(at index: Int) -> some View {
        let isExpanded = expandedIndex == index

        return VStack(spacing: 0) {
            // Header row — tap to expand/collapse
            HStack(spacing: 8) {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.3))
                    .frame(width: 12)

                TextField("Name", text: Binding(
                    get: { playlists[index].name },
                    set: { playlists[index].name = $0 }
                ))
                .textFieldStyle(.plain)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.85))

                Spacer()

                Toggle("", isOn: Binding(
                    get: { playlists[index].isEnabled },
                    set: { playlists[index].isEnabled = $0 }
                ))
                .toggleStyle(.switch)
                .controlSize(.mini)

                if playlists.count > 1 {
                    Button {
                        withAnimation(.spring(duration: 0.2)) {
                            let _ = playlists.remove(at: index)
                            if expandedIndex == index { expandedIndex = nil }
                            else if let exp = expandedIndex, exp > index { expandedIndex = exp - 1 }
                        }
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.white.opacity(0.25))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.spring(duration: 0.2)) {
                    expandedIndex = isExpanded ? nil : index
                }
            }

            // Expanded segments
            if isExpanded {
                VStack(spacing: 4) {
                    ForEach(Array(playlists[index].segments.enumerated()), id: \.element.id) { segIdx, _ in
                        segmentRow(playlistIndex: index, segmentIndex: segIdx)
                    }

                    Button {
                        withAnimation(.spring(duration: 0.2)) {
                            playlists[index].segments.append(PomodoroSegment(label: "Work", minutes: 25))
                        }
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "plus")
                                .font(.system(size: 9, weight: .medium))
                            Text("Add segment")
                                .font(.system(size: 10))
                        }
                        .foregroundStyle(Color.white.opacity(0.3))
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 6)
            }
        }
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func segmentRow(playlistIndex: Int, segmentIndex: Int) -> some View {
        HStack(spacing: 8) {
            TextField("Label", text: Binding(
                get: { playlists[playlistIndex].segments[segmentIndex].label },
                set: { playlists[playlistIndex].segments[segmentIndex].label = $0 }
            ))
            .textFieldStyle(.plain)
            .font(.system(size: 11))
            .foregroundStyle(Color.white.opacity(0.7))
            .frame(maxWidth: .infinity, alignment: .leading)

            TextField("Min", value: Binding(
                get: { playlists[playlistIndex].segments[segmentIndex].minutes },
                set: { playlists[playlistIndex].segments[segmentIndex].minutes = $0 }
            ), format: .number)
            .textFieldStyle(.plain)
            .font(.system(size: 11, design: .monospaced))
            .foregroundStyle(Color.white.opacity(0.7))
            .frame(width: 32)
            .multilineTextAlignment(.trailing)

            Text("min")
                .font(.system(size: 9))
                .foregroundStyle(Color.white.opacity(0.25))

            Button {
                withAnimation(.spring(duration: 0.2)) {
                    let _ = playlists[playlistIndex].segments.remove(at: segmentIndex)
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.25))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 3))
    }
}
