import AppKit
import Combine
import SwiftUI
import UserNotifications

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private let engine = TimerEngine()
    private let audio = AudioManager()
    private var eventMonitor: Any?
    private var stateObserver: AnyCancellable?
    private var timerWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupPopover()
        setupCallbacks()
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func applicationWillTerminate(_ notification: Notification) {
        audio.stop()
        removeEventMonitor()
    }

    // MARK: - Setup

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: 72)
        guard let button = statusItem.button else { return }
        button.action = #selector(handleClick)
        button.target = self
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])

        let hostingView = NSHostingView(rootView: StatusBarLabel(engine: engine))
        hostingView.frame = NSRect(x: 0, y: 0, width: 72, height: 22)
        button.addSubview(hostingView)
        button.frame = hostingView.frame
    }

    private func setupPopover() {
        popover = NSPopover()
        popover.contentSize = NSSize(width: 320, height: 190)
        popover.behavior = .transient
        popover.animates = false
        popover.contentViewController = NSHostingController(
            rootView: TimerPopoverView(engine: engine)
        )
    }

    private func setupCallbacks() {
        engine.onTimerComplete = { [weak self] in
            guard let self else { return }
            audio.playLooping()
            sendNotification()
            if !(timerWindow?.isVisible ?? false) {
                openPopover()
            }
        }

        engine.onOpenWindow = { [weak self] in
            self?.toggleTimerWindow()
        }

        stateObserver = engine.$state
            .removeDuplicates()
            .sink { [weak self] state in
                if state != .finished {
                    self?.audio.stop()
                }
            }
    }

    // MARK: - Clicks

    @objc private func handleClick() {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            if popover.isShown { closePopover() }
            engine.toggleFromStatusBar()
        } else {
            // Always open on left click — don't toggle, just ensure it's shown
            openPopover()
        }
    }

    private func openPopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown { return }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()

        removeEventMonitor()
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.closePopover()
        }
    }

    private func closePopover() {
        popover.performClose(nil)
        removeEventMonitor()
    }

    private func removeEventMonitor() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    // MARK: - Timer Window

    private func toggleTimerWindow() {
        if let w = timerWindow, w.isVisible {
            w.close()
            return
        }

        if let w = timerWindow {
            NSApp.activate(ignoringOtherApps: true)
            w.makeKeyAndOrderFront(nil)
            return
        }

        let w = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 160),
            styleMask: [.borderless, .resizable],
            backing: .buffered,
            defer: false
        )
        w.level = .floating
        w.isMovableByWindowBackground = true
        w.backgroundColor = .clear
        w.isOpaque = false
        w.hasShadow = true
        w.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        w.isReleasedWhenClosed = false
        w.minSize = NSSize(width: 200, height: 120)
        w.appearance = NSAppearance(named: .darkAqua)
        w.center()
        w.contentView = NSHostingView(
            rootView: TimerWindowView(engine: engine, onClose: { [weak self] in
                self?.timerWindow?.close()
            })
        )

        NSApp.activate(ignoringOtherApps: true)
        w.makeKeyAndOrderFront(nil)
        timerWindow = w
    }

    // MARK: - Notification

    private func sendNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Timer Complete"
        content.body = engine.currentSegmentLabel.isEmpty
            ? "Your timer has finished"
            : "\(engine.currentSegmentLabel) session finished"
        content.sound = .default
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        )
    }
}

// MARK: - Status Bar Label

struct StatusBarLabel: View {
    @ObservedObject var engine: TimerEngine
    @State private var pauseBlink = false

    private var isActive: Bool {
        engine.state == .running || engine.state == .paused || engine.state == .finished
    }

    var body: some View {
        ZStack {
            if isActive {
                Capsule().fill(Color.white.opacity(
                    engine.state == .paused ? (pauseBlink ? 0.5 : 0.3) : 0.85
                ))
            } else {
                Capsule().strokeBorder(Color(white: 0.7).opacity(0.5), lineWidth: 1)
            }

            Text(engine.state == .finished ? "0:00" : (isActive ? engine.displayTime : engine.idleDisplayTime))
                .font(.system(size: 11, weight: isActive ? .medium : .regular, design: .monospaced))
                .foregroundStyle(isActive ? Color(white: 0.08) : Color(white: 0.85))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
        .frame(width: 68, height: 18)
        .contentTransition(.numericText())
        .animation(.spring(duration: 0.25), value: engine.state)
        .onChange(of: engine.state) { _, newState in
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                pauseBlink = newState == .paused
            }
        }
    }
}
