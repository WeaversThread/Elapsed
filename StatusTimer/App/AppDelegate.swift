import AppKit
import Carbon.HIToolbox
import Combine
import SwiftUI
import UserNotifications

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var statusItemController: StatusItemController?
    private var popover: NSPopover!
    private var popoverContent: NSHostingController<AnyView>!
    private let store = UserDefaultsStore.shared
    private let engine = TimerEngine()
    private let audio = AudioManager()
    private var eventMonitor: Any?
    private var keyMonitor: Any?
    private var cancellables = Set<AnyCancellable>()
    private var timerWindow: NSWindow?
    private var settingsWindow: NSWindow?
    private var isLaunched = false
    private var pendingURLs: [URL] = []

    private enum Notice {
        static let id = "elapsed.finished"
        static let doneCategory = "TIMER_DONE"
        static let segmentCategory = "SEGMENT_DONE"
        static let stop = "STOP"
        static let snooze = "SNOOZE"
        static let next = "NEXT"
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupPopover()
        setupCallbacks()
        setupNotifications()
        setupHotkeys()
        observeDisplaySleep()
        isLaunched = true
        pendingURLs.forEach(handleURL)
        pendingURLs = []
    }

    func applicationWillTerminate(_ notification: Notification) {
        audio.stop()
        removeEventMonitor()
        removeKeyMonitor()
    }

    // MARK: - Setup

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: 72)
        guard let button = statusItem.button else { return }
        button.action = #selector(handleClick)
        button.target = self
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.setAccessibilityLabel("Elapsed timer")
        statusItemController = StatusItemController(button: button, engine: engine, store: store)
    }

    private func setupPopover() {
        popover = NSPopover()
        popover.contentSize = NSSize(width: 320, height: 190)
        popover.behavior = .transient
        popover.animates = false
        popover.delegate = self
        popoverContent = NSHostingController(rootView: Self.popoverPlaceholder)
        popover.contentViewController = popoverContent
    }

    /// While the popover is closed its content is this, so a running timer
    /// doesn't keep re-rendering a view nobody can see.
    private static var popoverPlaceholder: AnyView {
        AnyView(Color.clear.frame(width: 320, height: 190))
    }

    private func setupCallbacks() {
        engine.onTimerComplete = { [weak self] completion in
            guard let self else { return }
            let prefs = store.prefs
            if completion.autoAdvanced {
                audio.playOnce(prefs.alarmSound, volume: prefs.alarmVolume)
            } else {
                audio.play(prefs.alarmSound, volume: prefs.alarmVolume, length: prefs.alarmLength)
                if prefs.openPopoverOnFinish && !(timerWindow?.isVisible ?? false) {
                    openPopover()
                }
            }
            sendNotification(completion)
        }

        engine.onOpenWindow = { [weak self] in
            self?.toggleTimerWindow()
        }

        engine.onOpenSettings = { [weak self] in
            self?.openSettings()
        }

        engine.$state
            .removeDuplicates()
            .sink { [weak self] state in
                if state != .finished {
                    self?.audio.stop()
                }
            }
            .store(in: &cancellables)
    }

    private func setupHotkeys() {
        HotkeyManager.shared.onAction = { [weak self] action in
            self?.performHotkey(action)
        }
        store.$prefs
            .map(\.hotkeys)
            .removeDuplicates()
            .sink { HotkeyManager.shared.register($0) }
            .store(in: &cancellables)
    }

    /// Nobody sees the seconds while the screen is off or another user is logged in.
    private func observeDisplaySleep() {
        let center = NSWorkspace.shared.notificationCenter
        let changes: [(Notification.Name, Bool)] = [
            (NSWorkspace.screensDidSleepNotification, true),
            (NSWorkspace.screensDidWakeNotification, false),
            (NSWorkspace.sessionDidResignActiveNotification, true),
            (NSWorkspace.sessionDidBecomeActiveNotification, false),
        ]
        for (name, asleep) in changes {
            center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.engine.setDisplayAsleep(asleep)
                }
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
        popoverContent.rootView = AnyView(TimerPopoverView(engine: engine).environmentObject(store))
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()

        removeEventMonitor()
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.closePopover()
        }
        addKeyMonitor()
    }

    private func closePopover() {
        popover.performClose(nil)
        removeEventMonitor()
        removeKeyMonitor()
    }

    private func removeEventMonitor() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    // MARK: - Popover keys

    private func addKeyMonitor() {
        removeKeyMonitor()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, popover.isShown,
                  let window = popover.contentViewController?.view.window,
                  event.window === window else { return event }
            return handlePopoverKey(event) ? nil : event
        }
    }

    private func removeKeyMonitor() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
    }

    /// Space starts or pauses, ←/→ nudge the time (⇧ for 5), 1–9 pick a preset.
    private func handlePopoverKey(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])
        if flags == .command {
            switch event.charactersIgnoringModifiers?.lowercased() {
            case ",": openSettings(); return true
            case "q": NSApp.terminate(nil); return true
            default:  return false
            }
        }
        // The custom time field takes its own typing.
        if event.window?.firstResponder is NSTextView { return false }
        guard flags.isSubset(of: .shift) else { return false }

        let code = Int(event.keyCode)
        let isIdle = engine.state == .idle
        switch code {
        case kVK_Space:
            withAnimation(.spring(duration: 0.25)) { engine.toggleFromStatusBar() }
        case kVK_Return, kVK_ANSI_KeypadEnter:
            guard isIdle else { return false }
            withAnimation(.spring(duration: 0.25)) { engine.start() }
        case kVK_LeftArrow, kVK_RightArrow:
            guard isIdle else { return false }
            let step = (flags.contains(.shift) ? 5 : 1) * (code == kVK_LeftArrow ? -1 : 1)
            withAnimation(.spring(duration: 0.2)) {
                engine.selectedMinutes = PomodoroSegment.clampMinutes(engine.selectedMinutes + step)
            }
        case kVK_Escape:
            closePopover()
        default:
            guard isIdle, let digit = event.charactersIgnoringModifiers.flatMap(Int.init),
                  (1...9).contains(digit), store.prefs.presets.indices.contains(digit - 1) else { return false }
            withAnimation(.spring(duration: 0.2)) {
                engine.selectedMinutes = store.prefs.presets[digit - 1]
            }
        }
        return true
    }

    // MARK: - Shortcuts

    private func performHotkey(_ action: HotkeyAction) {
        switch action {
        case .toggle:
            engine.toggleFromStatusBar()
        case .openPopover:
            if popover.isShown { closePopover() } else { openPopover() }
        case .stop:
            engine.cancel()
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

        let w = GlassWindow.make(
            size: NSSize(width: 280, height: 160),
            minSize: NSSize(width: 200, height: 120),
            resizable: true,
            level: .floating,
            autosaveName: "ElapsedTimerWindow",
            content: TimerWindowView(engine: engine, onClose: { [weak self] in
                self?.timerWindow?.close()
            })
            .environmentObject(store)
        )
        w.delegate = self

        NSApp.activate(ignoringOtherApps: true)
        w.makeKeyAndOrderFront(nil)
        timerWindow = w
    }

    // MARK: - Settings Window

    func openSettings() {
        closePopover()
        if settingsWindow == nil {
            // Floats so it can't get lost behind other apps: there's no Dock icon to bring it back.
            let w = GlassWindow.make(
                size: NSSize(width: 380, height: 460),
                resizable: false,
                level: .floating,
                content: SettingsView(audio: audio, onClose: { [weak self] in
                    self?.settingsWindow?.close()
                })
                .environmentObject(store)
            )
            w.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
            w.delegate = self
            settingsWindow = w
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    // MARK: - URL scheme

    /// elapsed://start, start?min=25, start?until=14:30, toggle, stop, snooze, playlist?name=Pomodoro
    func application(_ application: NSApplication, open urls: [URL]) {
        guard isLaunched else {
            pendingURLs += urls
            return
        }
        urls.forEach(handleURL)
    }

    private func handleURL(_ url: URL) {
        guard url.scheme?.lowercased() == "elapsed" else { return }
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let action = (url.host ?? components?.path ?? "")
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            .lowercased()
        let items = components?.queryItems ?? []
        func param(_ name: String) -> String? {
            items.first { $0.name.lowercased() == name }?.value
        }

        switch action {
        case "start":
            if let until = param("until") {
                if case .until(let date)? = TimeInputParser.parse("@" + until) {
                    engine.start(until: date)
                }
            } else if let text = param("min") {
                if case .minutes(let minutes)? = TimeInputParser.parse(text) {
                    engine.start(minutes: minutes)
                }
            } else {
                engine.start()
            }
        case "toggle":
            engine.toggleFromStatusBar()
        case "stop":
            engine.cancel()
        case "snooze":
            engine.snooze()
        case "playlist":
            if let name = param("name") { engine.startPlaylist(named: name) }
        default:
            break
        }
    }

    // MARK: - Notifications

    private func setupNotifications() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
        registerNotificationCategories()

        store.$prefs
            .map(\.snoozeMinutes)
            .removeDuplicates()
            .dropFirst()
            .sink { [weak self] _ in self?.registerNotificationCategories() }
            .store(in: &cancellables)
    }

    private func registerNotificationCategories() {
        let stop = UNNotificationAction(identifier: Notice.stop, title: "Stop")
        let snooze = UNNotificationAction(identifier: Notice.snooze, title: "+\(store.prefs.snoozeMinutes) min")
        let next = UNNotificationAction(identifier: Notice.next, title: "Next segment")
        UNUserNotificationCenter.current().setNotificationCategories([
            UNNotificationCategory(identifier: Notice.doneCategory, actions: [stop, snooze], intentIdentifiers: []),
            UNNotificationCategory(identifier: Notice.segmentCategory, actions: [next, snooze, stop], intentIdentifiers: []),
        ])
    }

    private func sendNotification(_ completion: TimerCompletion) {
        guard store.prefs.notifications else { return }
        let content = UNMutableNotificationContent()
        let label = completion.label

        if let next = completion.next {
            content.title = label.isEmpty ? "Segment complete" : "\(label) finished"
            content.body = completion.autoAdvanced
                ? "\(next.label) started · \(next.minutes) min"
                : "Next: \(next.label) · \(next.minutes) min"
            if !completion.autoAdvanced {
                content.categoryIdentifier = Notice.segmentCategory
            }
        } else {
            content.title = "Timer Complete"
            content.body = label.isEmpty ? "Your timer has finished" : "\(label) session finished"
            content.categoryIdentifier = Notice.doneCategory
        }
        // The alarm is the sound; the banner stays quiet.
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: Notice.id, content: content, trigger: nil)
        )
    }

    private func handleNotificationAction(_ identifier: String) {
        switch identifier {
        case Notice.stop:
            if engine.state == .finished { engine.cancel() }
        case Notice.snooze:
            engine.snooze()
        case Notice.next:
            if engine.state == .finished && engine.hasMoreSegments { engine.advancePlaylist() }
        case UNNotificationDefaultActionIdentifier:
            openPopover()
        default:
            break
        }
    }
}

extension AppDelegate: NSPopoverDelegate {
    func popoverDidClose(_ notification: Notification) {
        popoverContent.rootView = Self.popoverPlaceholder
        removeEventMonitor()
        removeKeyMonitor()
    }
}

extension AppDelegate: NSWindowDelegate {
    /// Closed windows are let go so they stop observing the timer; the timer window's frame is autosaved.
    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        if window === timerWindow { timerWindow = nil }
        if window === settingsWindow { settingsWindow = nil }
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let identifier = response.actionIdentifier
        await MainActor.run {
            self.handleNotificationAction(identifier)
        }
    }
}
