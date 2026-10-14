import AppKit
import SwiftUI

/// Borderless dark-glass window that can still become key, so its text fields take typing.
final class GlassWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    // Borderless windows have no close button, so ⌘W and Esc would only beep.
    override func performClose(_ sender: Any?) { close() }
    override func cancelOperation(_ sender: Any?) { close() }

    static func make<Content: View>(
        size: NSSize,
        minSize: NSSize? = nil,
        resizable: Bool,
        level: NSWindow.Level,
        autosaveName: String? = nil,
        content: Content
    ) -> GlassWindow {
        let w = GlassWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: resizable ? [.borderless, .resizable] : [.borderless],
            backing: .buffered,
            defer: false
        )
        w.level = level
        w.isMovableByWindowBackground = true
        w.backgroundColor = .clear
        w.isOpaque = false
        w.hasShadow = true
        w.collectionBehavior = level == .floating
            ? [.canJoinAllSpaces, .fullScreenAuxiliary]
            : [.moveToActiveSpace]
        w.isReleasedWhenClosed = false
        if let minSize { w.minSize = minSize }
        w.appearance = NSAppearance(named: .darkAqua)
        w.contentView = NSHostingView(rootView: content)
        w.center()
        if let autosaveName {
            w.setFrameUsingName(autosaveName)
            w.setFrameAutosaveName(autosaveName)
        }
        return w
    }
}
