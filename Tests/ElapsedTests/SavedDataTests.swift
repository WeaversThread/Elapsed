import Foundation
import Testing
@testable import Elapsed

/// Data saved by older versions has to keep decoding, or the app silently falls back to defaults.
@Suite struct SavedDataTests {
    @Test func playlistsFromVersionOne() throws {
        // 1.0 had no kind, autoAdvance or repeats, and allowed 0 minutes.
        let json = #"""
        [{"name":"Focus","id":"5C1E7A0E-6B8A-4D7E-9F00-000000000001","isEnabled":true,"segments":[
          {"label":"Focus","minutes":50,"id":"5C1E7A0E-6B8A-4D7E-9F00-000000000002"},
          {"label":"Long Break","minutes":0,"id":"5C1E7A0E-6B8A-4D7E-9F00-000000000003"}]}]
        """#
        let playlists = try JSONDecoder().decode([Playlist].self, from: Data(json.utf8))
        let focus = try #require(playlists.first)
        #expect(focus.name == "Focus")
        #expect(focus.isEnabled)
        #expect(!focus.autoAdvance && !focus.repeats)
        #expect(focus.segments.map(\.kind) == [.focus, .rest])
        #expect(focus.segments.map(\.minutes) == [50, 1])
    }

    @Test func preferencesSurviveUnknownAndRemovedValues() throws {
        // An accent that no longer exists, the removed "minimal" style and hotkeys field,
        // and presets that collapse to fewer than three.
        let json = #"{"focusAccent":"magenta","statusStyle":"minimal","hotkeys":{},"presets":[30,5,5],"snoozeMinutes":10}"#
        let prefs = try JSONDecoder().decode(Preferences.self, from: Data(json.utf8))
        #expect(prefs.focusAccent == .red)
        #expect(prefs.statusStyle == .capsule)
        #expect(prefs.presets == Preferences().presets)
        #expect(prefs.snoozeMinutes == 10)
    }

    @Test func presetsAreSortedUniqueAndCapped() {
        #expect(Preferences.normalizedPresets([60, 5, 25, 5, 0]) == [1, 5, 25, 60])
        #expect(Preferences.normalizedPresets(Array(1...20)).count == 9)
    }
}
