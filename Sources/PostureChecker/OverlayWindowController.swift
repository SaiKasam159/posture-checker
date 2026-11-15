import AppKit
import SwiftUI

/// Transparent, click-through, always-on-top window the character lives in.
/// Covers the full screen but only the character/text draw anything —
/// everything else passes clicks straight through to whatever's underneath.
final class OverlayWindowController: NSWindowController {
    convenience init(contentView: NSView) {
        guard let screenFrame = NSScreen.main?.frame else {
            fatalError("No main screen available")
        }

        let window = NSWindow(
            contentRect: screenFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .statusBar
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        window.contentView = contentView

        self.init(window: window)
    }

    func show() {
        window?.orderFrontRegardless()
    }
}
