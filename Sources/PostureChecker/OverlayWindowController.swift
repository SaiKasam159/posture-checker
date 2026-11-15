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

        // NSHostingView sizes to its content's ideal size by default, which
        // left it collapsed in AppKit's origin corner (bottom-left) instead
        // of covering the screen. Pin it to the window's full content frame
        // and let it track future resizes.
        contentView.frame = window.contentLayoutRect
        contentView.autoresizingMask = [.width, .height]
        window.contentView = contentView

        self.init(window: window)
    }

    func show() {
        window?.orderFrontRegardless()
    }
}
