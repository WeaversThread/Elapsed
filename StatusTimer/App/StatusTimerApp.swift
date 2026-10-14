import SwiftUI

@main
struct StatusTimerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Settings…") { appDelegate.openSettings() }
                    .keyboardShortcut(",", modifiers: .command)
            }
        }
    }
}
