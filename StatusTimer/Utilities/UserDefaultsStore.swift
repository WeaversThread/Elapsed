import Foundation

final class UserDefaultsStore: @unchecked Sendable {
    @MainActor static let shared = UserDefaultsStore()

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let lastUsedMinutes = "lastUsedMinutes"
        static let playlists = "playlists_v2"
    }

    var lastUsedMinutes: Int {
        get {
            let val = defaults.integer(forKey: Keys.lastUsedMinutes)
            return val > 0 ? val : 5
        }
        set { defaults.set(newValue, forKey: Keys.lastUsedMinutes) }
    }

    var playlists: [Playlist] {
        get {
            guard let data = defaults.data(forKey: Keys.playlists),
                  let decoded = try? JSONDecoder().decode([Playlist].self, from: data) else {
                return Playlist.defaultPlaylists
            }
            return decoded
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: Keys.playlists)
            }
        }
    }
}
