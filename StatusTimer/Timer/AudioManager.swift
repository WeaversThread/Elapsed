import AppKit

@MainActor
final class AudioManager {
    private var sound: NSSound?
    private var stopTask: Task<Void, Never>?

    private static let systemSoundsDirectory = URL(fileURLWithPath: "/System/Library/Sounds")

    /// The bundled alarm first, then the macOS system sounds.
    static var availableSounds: [String] {
        let system = (try? FileManager.default.contentsOfDirectory(
            at: systemSoundsDirectory, includingPropertiesForKeys: nil
        )) ?? []
        let names = system
            .filter { ["aiff", "aif", "caf", "wav"].contains($0.pathExtension.lowercased()) }
            .map { $0.deletingPathExtension().lastPathComponent }
            .sorted()
        return [AlarmSound.bundled] + names
    }

    /// The alarm, as configured: once, for a while, or until stopped.
    func play(_ name: String, volume: Double, length: AlarmLength) {
        stop()
        guard let s = loadSound(name) else { NSSound.beep(); return }
        s.volume = Float(min(max(volume, 0), 1))
        s.loops = length != .once
        s.play()
        sound = s

        if let seconds = length.loopSeconds {
            stopTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(seconds))
                guard !Task.isCancelled else { return }
                self?.stop()
            }
        }
    }

    /// A single play of a sound, for the settings preview and auto-advancing playlists.
    func playOnce(_ name: String, volume: Double) {
        play(name, volume: volume, length: .once)
    }

    func stop() {
        stopTask?.cancel()
        stopTask = nil
        sound?.stop()
        sound = nil
    }

    private func loadSound(_ name: String) -> NSSound? {
        let url: URL?
        if name == AlarmSound.bundled {
            // build.sh copies it into Contents/Resources.
            url = Bundle.main.url(forResource: "alarm", withExtension: "mp3")
        } else {
            url = ["aiff", "aif", "caf", "wav"]
                .map { Self.systemSoundsDirectory.appendingPathComponent(name).appendingPathExtension($0) }
                .first { FileManager.default.fileExists(atPath: $0.path) }
        }
        return url.flatMap { NSSound(contentsOf: $0, byReference: true) }
            ?? (name == AlarmSound.bundled ? nil : loadSound(AlarmSound.bundled))
    }
}
