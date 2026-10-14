import SwiftUI

struct PlaylistsSettingsTab: View {
    @EnvironmentObject private var store: UserDefaultsStore
    @State private var expandedID: UUID?
    @State private var hoveredID: UUID?

    var body: some View {
        VStack(spacing: 8) {
            ForEach(store.playlists) { playlist in
                playlistSection(playlist)
            }

            // Add playlist
            Button {
                withAnimation(.spring(duration: 0.2)) {
                    let new = Playlist(name: "New Playlist", segments: [
                        PomodoroSegment(label: "Work", minutes: 25, kind: .focus),
                        PomodoroSegment(label: "Break", minutes: 5, kind: .rest),
                    ])
                    store.playlists.append(new)
                    expandedID = new.id
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .medium))
                    Text("Add playlist")
                        .font(.system(size: 11))
                }
                .foregroundStyle(Color.white.opacity(0.4))
                .padding(.top, 2)
            }
            .buttonStyle(.plain)
        }
        .onAppear {
            if expandedID == nil { expandedID = store.playlists.first?.id }
        }
    }

    // MARK: - Playlist Section

    private func playlistSection(_ playlist: Playlist) -> some View {
        let id = playlist.id
        let isExpanded = expandedID == id
        let index = store.playlists.firstIndex { $0.id == id } ?? 0

        return VStack(spacing: 0) {
            // Header row — tap to expand/collapse
            HStack(spacing: 8) {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.3))
                    .frame(width: 12)

                TextField("Name", text: playlistBinding(id, \.name, fallback: ""))
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.85))

                Spacer()

                if hoveredID == id && store.playlists.count > 1 {
                    HStack(spacing: 2) {
                        moveButton("chevron.up", id: id, by: -1, disabled: index == 0)
                        moveButton("chevron.down", id: id, by: 1, disabled: index == store.playlists.count - 1)
                    }
                    .transition(.opacity)
                }

                GlassSwitch(isOn: playlistBinding(id, \.isEnabled, fallback: false))
                    .accessibilityLabel("Show in timer")

                if store.playlists.count > 1 {
                    Button {
                        withAnimation(.spring(duration: 0.2)) {
                            store.playlists.removeAll { $0.id == id }
                            if expandedID == id { expandedID = nil }
                        }
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.white.opacity(0.25))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Delete playlist")
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.spring(duration: 0.2)) {
                    expandedID = isExpanded ? nil : id
                }
            }

            // Expanded segments
            if isExpanded {
                VStack(spacing: 4) {
                    ForEach(playlist.segments) { segment in
                        segmentRow(playlistID: id, segment: segment)
                    }

                    Button {
                        withAnimation(.spring(duration: 0.2)) { addSegment(to: id) }
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

                    optionRow("Auto-advance", detail: "Start the next segment without waiting",
                              isOn: playlistBinding(id, \.autoAdvance, fallback: false))
                    optionRow("Repeat", detail: "Start over after the last segment",
                              isOn: playlistBinding(id, \.repeats, fallback: false))
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 8)
            }
        }
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                hoveredID = hovering ? id : (hoveredID == id ? nil : hoveredID)
            }
        }
    }

    private func segmentRow(playlistID: UUID, segment: PomodoroSegment) -> some View {
        let kind = segmentBinding(playlistID, segment.id, \.kind, fallback: .focus)

        return HStack(spacing: 8) {
            // Focus or rest: picks the color the timer uses
            HoverButton {
                withAnimation(.spring(duration: 0.2)) {
                    kind.wrappedValue = kind.wrappedValue == .focus ? .rest : .focus
                }
            } label: {
                Circle()
                    .fill(store.prefs.accent(for: segment.kind).opacity(0.8))
                    .frame(width: 7, height: 7)
                    .frame(width: 14, height: 14)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(segment.kind == .focus ? "Focus" : "Rest")

            TextField("Label", text: segmentBinding(playlistID, segment.id, \.label, fallback: ""))
                .textFieldStyle(.plain)
                .font(.system(size: 11))
                .foregroundStyle(Color.white.opacity(0.7))
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(segment.kind == .focus ? "focus" : "rest")
                .font(.system(size: 9))
                .foregroundStyle(Color.white.opacity(0.25))

            TextField("Min", value: segmentBinding(playlistID, segment.id, \.minutes, fallback: 25), format: .number)
                .textFieldStyle(.plain)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.7))
                .frame(width: 36)
                .multilineTextAlignment(.trailing)

            Text("min")
                .font(.system(size: 9))
                .foregroundStyle(Color.white.opacity(0.25))

            Button {
                withAnimation(.spring(duration: 0.2)) {
                    updatePlaylist(playlistID) { $0.segments.removeAll { $0.id == segment.id } }
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.25))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove segment")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 3))
    }

    private func optionRow(_ label: String, detail: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.white.opacity(0.7))
                Text(detail)
                    .font(.system(size: 9))
                    .foregroundStyle(Color.white.opacity(0.3))
            }
            Spacer()
            GlassSwitch(isOn: isOn)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }

    private func moveButton(_ symbol: String, id: UUID, by offset: Int, disabled: Bool) -> some View {
        HoverButton {
            guard let from = store.playlists.firstIndex(where: { $0.id == id }) else { return }
            let to = from + offset
            guard store.playlists.indices.contains(to) else { return }
            withAnimation(.spring(duration: 0.2)) { store.playlists.swapAt(from, to) }
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(Color.white.opacity(disabled ? 0.1 : 0.4))
                .frame(width: 16, height: 16)
        }
        .disabled(disabled)
        .accessibilityLabel(offset < 0 ? "Move up" : "Move down")
    }

    // MARK: - Editing by id (never by a stale index)

    private func updatePlaylist(_ id: UUID, _ change: (inout Playlist) -> Void) {
        guard let i = store.playlists.firstIndex(where: { $0.id == id }) else { return }
        change(&store.playlists[i])
    }

    private func addSegment(to id: UUID) {
        updatePlaylist(id) { playlist in
            let next: PomodoroSegment = playlist.segments.last?.kind == .focus
                ? PomodoroSegment(label: "Break", minutes: 5, kind: .rest)
                : PomodoroSegment(label: "Work", minutes: 25, kind: .focus)
            playlist.segments.append(next)
        }
    }

    private func playlistBinding<T>(_ id: UUID, _ keyPath: WritableKeyPath<Playlist, T>, fallback: T) -> Binding<T> {
        Binding(
            get: { store.playlists.first { $0.id == id }?[keyPath: keyPath] ?? fallback },
            set: { value in updatePlaylist(id) { $0[keyPath: keyPath] = value } }
        )
    }

    private func segmentBinding<T>(
        _ playlistID: UUID, _ segmentID: UUID,
        _ keyPath: WritableKeyPath<PomodoroSegment, T>, fallback: T
    ) -> Binding<T> {
        Binding(
            get: {
                store.playlists.first { $0.id == playlistID }?
                    .segments.first { $0.id == segmentID }?[keyPath: keyPath] ?? fallback
            },
            set: { value in
                updatePlaylist(playlistID) { playlist in
                    guard let s = playlist.segments.firstIndex(where: { $0.id == segmentID }) else { return }
                    playlist.segments[s][keyPath: keyPath] = value
                    // 0 or negative minutes would end the segment instantly.
                    playlist.segments[s].minutes = PomodoroSegment.clampMinutes(playlist.segments[s].minutes)
                }
            }
        )
    }
}
