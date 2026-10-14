import ServiceManagement
import SwiftUI

// MARK: - Timer

struct TimerSettingsTab: View {
    @EnvironmentObject private var store: UserDefaultsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsSection(
                title: "Presets",
                footer: "Click the time in the timer to type one: 90, 1:30 — or @14:30 to count down to a time of day."
            ) {
                PresetEditor(presets: $store.prefs.presets)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 9)
            }

            SettingsSection(title: "When time is up") {
                SettingsRow(label: "Count overtime (+0:42)") {
                    GlassSwitch(isOn: $store.prefs.overtime)
                }
                SettingsDivider()
                SettingsRow(label: "Snooze") {
                    GlassStepper(value: $store.prefs.snoozeMinutes, range: Preferences.snoozeRange, suffix: " min")
                }
            }
        }
    }
}

// MARK: - Look

struct LookSettingsTab: View {
    @EnvironmentObject private var store: UserDefaultsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsSection(title: "Colors") {
                SettingsRow(label: "Focus") {
                    SwatchPicker(selection: $store.prefs.focusAccent)
                }
                SettingsDivider()
                SettingsRow(label: "Rest") {
                    SwatchPicker(selection: $store.prefs.restAccent)
                }
            }

            SettingsSection(title: "Menu bar") {
                HStack(spacing: 6) {
                    ForEach(StatusStyle.allCases) { style in
                        stylePreview(style)
                    }
                }
                .padding(6)
            }

            SettingsSection(title: "Timer") {
                SettingsRow(label: "Presets row") {
                    GlassSwitch(isOn: $store.prefs.showPresets)
                }
                SettingsDivider()
                SettingsRow(label: "Playlists") {
                    GlassSwitch(isOn: $store.prefs.showPlaylists)
                }
            }

            SettingsSection(title: "Floating window") {
                SettingsRow(label: "Show bars") {
                    GlassSwitch(isOn: $store.prefs.windowShowsBars)
                }
            }
        }
    }

    private func stylePreview(_ style: StatusStyle) -> some View {
        let isSelected = store.prefs.statusStyle == style
        return HoverButton {
            withAnimation(.spring(duration: 0.2)) { store.prefs.statusStyle = style }
        } label: {
            VStack(spacing: 7) {
                Image(nsImage: StatusBarFace(
                    text: "14:59",
                    style: style,
                    state: .running,
                    progress: 0.4,
                    accent: store.prefs.focusAccent
                ).image())

                Text(style.rawValue)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(Color.white.opacity(isSelected ? 0.85 : 0.35))
            }
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 5).fill(Color.white.opacity(isSelected ? 0.1 : 0)))
        }
    }
}

// MARK: - Sound

struct SoundSettingsTab: View {
    let audio: AudioManager
    @EnvironmentObject private var store: UserDefaultsStore
    @State private var sounds = AudioManager.availableSounds
    @State private var hoveredSound: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsSection(title: "Alarm") {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        ForEach(sounds, id: \.self) { name in
                            soundRow(name)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .frame(height: 176)
            }

            SettingsSection(title: "Playback") {
                SettingsRow(label: "Volume") {
                    VolumeBars(value: $store.prefs.alarmVolume, onCommit: preview)
                }
                SettingsDivider()
                SettingsRow(label: "Length") {
                    GlassChoice(options: AlarmLength.allCases, selection: $store.prefs.alarmLength) { $0.title }
                }
            }
        }
        .onDisappear { audio.stop() }
    }

    private func soundRow(_ name: String) -> some View {
        let isSelected = store.prefs.alarmSound == name
        return Button {
            store.prefs.alarmSound = name
            preview()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "checkmark")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.8))
                    .opacity(isSelected ? 1 : 0)
                    .frame(width: 12)
                Text(name == AlarmSound.bundled ? "Elapsed" : name)
                    .font(.system(size: 12, weight: isSelected ? .medium : .regular))
                    .foregroundStyle(Color.white.opacity(isSelected ? 0.9 : 0.55))
                Spacer()
                Image(systemName: "play.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(Color.white.opacity(hoveredSound == name ? 0.5 : 0))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.white.opacity(hoveredSound == name ? 0.06 : 0))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            hoveredSound = hovering ? name : (hoveredSound == name ? nil : hoveredSound)
        }
    }

    private func preview() {
        audio.playOnce(store.prefs.alarmSound, volume: store.prefs.alarmVolume)
    }
}

// MARK: - General

struct GeneralSettingsTab: View {
    @EnvironmentObject private var store: UserDefaultsStore
    @State private var loginStatus = SMAppService.mainApp.status

    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "Elapsed \(short) (\(build))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsSection(title: "Startup") {
                SettingsRow(
                    label: "Launch at login",
                    detail: loginStatus == .requiresApproval ? "Allow Elapsed in System Settings › Login Items" : nil
                ) {
                    GlassSwitch(isOn: Binding(
                        get: { loginStatus == .enabled || loginStatus == .requiresApproval },
                        set: setLaunchAtLogin
                    ))
                }
            }

            SettingsSection(title: "When time is up") {
                SettingsRow(label: "Open timer when done") {
                    GlassSwitch(isOn: $store.prefs.openPopoverOnFinish)
                }
                SettingsDivider()
                SettingsRow(label: "Notifications") {
                    GlassSwitch(isOn: $store.prefs.notifications)
                }
            }

            SettingsSection(title: "Shortcuts") {
                ForEach(Array(HotkeyAction.allCases.enumerated()), id: \.element) { index, action in
                    if index > 0 { SettingsDivider() }
                    SettingsRow(label: action.title) {
                        HotkeyRecorder(hotkey: hotkeyBinding(action))
                    }
                }
            }

            HStack(spacing: 4) {
                Text(version)
                    .font(.system(size: 10))
                    .foregroundStyle(Color.white.opacity(0.25))
                Spacer()
                HoverButton {
                    withAnimation(.spring(duration: 0.2)) { store.resetPreferences() }
                } label: {
                    Text("reset to defaults")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.white.opacity(0.4))
                        .padding(.horizontal, 4)
                }
                HoverButton {
                    NSApp.terminate(nil)
                } label: {
                    Text("quit Elapsed")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.white.opacity(0.6))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.white.opacity(0.08)))
                }
            }
            .padding(.top, 2)
        }
        .onAppear { loginStatus = SMAppService.mainApp.status }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSSound.beep()
        }
        withAnimation(.spring(duration: 0.2)) {
            loginStatus = SMAppService.mainApp.status
        }
    }

    /// Recording a combo that another action already uses moves it here.
    private func hotkeyBinding(_ action: HotkeyAction) -> Binding<Hotkey?> {
        Binding(
            get: { store.prefs.hotkeys[action.rawValue] },
            set: { newValue in
                var hotkeys = store.prefs.hotkeys
                if let newValue {
                    for (key, existing) in hotkeys
                    where existing.keyCode == newValue.keyCode && existing.modifiers == newValue.modifiers {
                        hotkeys[key] = nil
                    }
                }
                hotkeys[action.rawValue] = newValue
                store.prefs.hotkeys = hotkeys
            }
        )
    }
}
