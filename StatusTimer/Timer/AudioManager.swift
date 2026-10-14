import AppKit

@MainActor
final class AudioManager {
    private var sound: NSSound?

    func playLooping() {
        stop()
        guard let s = loadSound() else { NSSound.beep(); return }
        s.loops = true
        s.play()
        sound = s
    }

    func stop() {
        sound?.stop()
        sound = nil
    }

    private func loadSound() -> NSSound? {
        Bundle.module.url(forResource: "alarm", withExtension: "mp3", subdirectory: "Resources")
            .flatMap { NSSound(contentsOf: $0, byReference: true) }
    }
}
