import AppKit
import SwiftUI

final class OnboardingWindowController: NSWindowController {
    convenience init(onFinish: @escaping () -> Void) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 540),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "Welcome to Posture Checker"
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: OnboardingView(onFinish: onFinish))

        self.init(window: window)
    }

    func show() {
        window?.center()
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
