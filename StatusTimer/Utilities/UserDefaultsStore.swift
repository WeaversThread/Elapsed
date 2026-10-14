import Foundation

@MainActor
final class UserDefaultsStore: ObservableObject {
    static let shared = UserDefaultsStore()

    private let defaults: UserDefaults

    private enum Keys {
        static let lastUsedMinutes = "lastUsedMinutes"
        static let playlists = "playlists_v2"
        static let prefs = "prefs_v1"
        static let snapshot = "snapshot_v1"
        /// Pre-`playlists_v2` keys that nothing reads anymore.
        static let legacy = [
            "pomodoroPlaylist", "playlist2", "playlistName0", "playlistName1",
            "pomodoroEnabled", "playlist2Enabled",
        ]
    }

    @Published var prefs: Preferences {
        didSet { if prefs != oldValue { save(prefs, forKey: Keys.prefs) } }
    }

    @Published var playlists: [Playlist] {
        didSet { if playlists != oldValue { save(playlists, forKey: Keys.playlists) } }
    }

    @Published var lastUsedMinutes: Int {
        didSet { defaults.set(lastUsedMinutes, forKey: Keys.lastUsedMinutes) }
    }

    var snapshot: TimerSnapshot? {
        didSet {
            guard snapshot != oldValue else { return }
            if let snapshot { save(snapshot, forKey: Keys.snapshot) }
            else { defaults.removeObject(forKey: Keys.snapshot) }
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        prefs = Self.load(Preferences.self, key: Keys.prefs, from: defaults) ?? Preferences()
        snapshot = Self.load(TimerSnapshot.self, key: Keys.snapshot, from: defaults)
        let minutes = defaults.integer(forKey: Keys.lastUsedMinutes)
        lastUsedMinutes = minutes > 0 ? minutes : 5

        if let saved = Self.load([Playlist].self, key: Keys.playlists, from: defaults) {
            playlists = saved
            // Only drop the old keys once the current ones are known to decode.
            Keys.legacy.forEach(defaults.removeObject(forKey:))
        } else {
            playlists = Playlist.defaultPlaylists
        }
    }

    func resetPreferences() {
        prefs = Preferences()
    }

    // MARK: - Coding

    private func save<T: Encodable>(_ value: T, forKey key: String) {
        if let data = try? JSONEncoder().encode(value) {
            defaults.set(data, forKey: key)
        }
    }

    private static func load<T: Decodable>(_ type: T.Type, key: String, from defaults: UserDefaults) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
