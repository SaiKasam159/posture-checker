import SwiftUI

@main
struct PostureCheckerApp: App {
    @StateObject private var monitor = PostureMonitor()

    var body: some Scene {
        MenuBarExtra {
            DebugPanelView(monitor: monitor)
        } label: {
            Image(systemName: monitor.menuBarSymbol)
        }
        .menuBarExtraStyle(.window)
    }
}
