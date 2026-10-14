import ServiceManagement
import SwiftUI

@main
struct StatusTimerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        // Register as login item for auto-start
        try? SMAppService.mainApp.register()
    }

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
