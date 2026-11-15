import AppKit
import Combine
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var overlayController: OverlayWindowController?
    private var onboardingController: OnboardingWindowController?
    private var postureSource = MockPostureSource()
    private var subscriptionManager: SubscriptionManager!
    private var cancellable: AnyCancellable?

    private let hasCompletedOnboardingKey = "hasCompletedOnboarding"

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory) // no Dock icon, menu bar only

        subscriptionManager = SubscriptionManager()
        setUpStatusItem()
        setUpOverlay()
        postureSource.start()

        if !UserDefaults.standard.bool(forKey: hasCompletedOnboardingKey) {
            showOnboarding()
        }
    }

    private func showOnboarding() {
        let controller = OnboardingWindowController { [weak self] in
            UserDefaults.standard.set(true, forKey: self?.hasCompletedOnboardingKey ?? "hasCompletedOnboarding")
            self?.onboardingController?.close()
            self?.onboardingController = nil
        }
        controller.show()
        onboardingController = controller
    }

    private func setUpStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "figure.stand", accessibilityDescription: "Apollo")
        item.button?.action = #selector(togglePopover)
        item.button?.target = self
        statusItem = item

        let popover = NSPopover()
        popover.behavior = .transient
        popover.appearance = NSAppearance(named: .darkAqua)
        popover.contentViewController = NSHostingController(
            rootView: SettingsView(
                postureSource: postureSource,
                subscriptionManager: subscriptionManager,
                onShowOnboarding: { [weak self] in self?.showOnboarding() }
            )
        )
        self.popover = popover
    }

    private func setUpOverlay() {
        let characterView = CharacterOverlayHostView(postureSource: postureSource)
        let hostingView = NSHostingView(rootView: characterView)
        let controller = OverlayWindowController(contentView: hostingView)
        controller.show()
        overlayController = controller
    }

    @objc private func togglePopover() {
        guard let button = statusItem?.button, let popover else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
}

/// Bridges the mock posture publisher into the SwiftUI character view.
private struct CharacterOverlayHostView: View {
    @ObservedObject var postureSource: MockPostureSource
    @State private var state: PostureState = .good

    var body: some View {
        CharacterOverlayView(state: state)
            .onReceive(postureSource.statePublisher) { newState in
                state = newState
            }
    }
}
