import AppKit
import SwiftUI

final class OnboardingWindowController: NSWindowController {
    convenience init(
        startPage: Int = 0,
        title: String = "Welcome to Apollo",
        finalButtonLabel: String = "GET STARTED",
        onFinish: @escaping () -> Void
    ) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 580),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = title
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: .darkAqua)
        window.contentView = NSHostingView(
            rootView: OnboardingView(startPage: startPage, finalButtonLabel: finalButtonLabel, onFinish: onFinish)
        )

        self.init(window: window)
    }

    func show() {
        window?.center()
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
