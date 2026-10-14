import AppKit
import Testing
@testable import Elapsed

@MainActor
@Suite struct StatusBarFaceTests {
    /// Draws a face the way the menu bar does, in both appearances.
    func render(_ face: StatusBarFace) {
        for name in [NSAppearance.Name.darkAqua, .aqua] {
            let rep = NSBitmapImageRep(
                bitmapDataPlanes: nil, pixelsWide: 136, pixelsHigh: 36, bitsPerSample: 8,
                samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                bytesPerRow: 0, bitsPerPixel: 0
            )!
            rep.size = StatusBarFace.size
            NSAppearance(named: name)!.performAsCurrentDrawingAppearance {
                NSGraphicsContext.saveGraphicsState()
                NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
                face.image().draw(in: NSRect(origin: .zero, size: StatusBarFace.size))
                NSGraphicsContext.restoreGraphicsState()
            }
        }
    }

    @Test(arguments: [StatusStyle.capsule, .progress])
    func drawsEveryState(style: StatusStyle) {
        for state in [TimerState.idle, .running, .paused, .finished] {
            for progress in [0, 0.04, 0.4, 0.5, 1.0] {
                for accent in Accent.allCases {
                    render(StatusBarFace(text: "25:00", style: style, state: state, progress: progress, accent: accent, glow: 0.5))
                }
            }
        }
        render(StatusBarFace(text: "+1:00:00", style: style, state: .finished, progress: 1, accent: .red))
    }
}
