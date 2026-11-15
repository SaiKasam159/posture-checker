import SwiftUI
import StoreKit

struct SettingsView: View {
    @ObservedObject var postureSource: PostureMonitor
    @ObservedObject var subscriptionManager: SubscriptionManager

    @AppStorage("selectedCharacterID") private var selectedCharacterID = CharacterCatalog.defaultID
    @State private var showPaywall = false

    var onShowOnboarding: () -> Void = {}
    var onChangeCharacter: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("APOLLO")
                .font(Theme.pixelFont(14))
                .foregroundStyle(Theme.textPrimary)

            if postureSource.camera.authorization != .authorized {
                VStack(alignment: .leading, spacing: 6) {
                    Text("CAMERA ACCESS NEEDED")
                        .font(Theme.pixelFont(11))
                        .foregroundStyle(Theme.textPrimary)
                    Text("Apollo watches your webcam locally to detect slouching. Video never leaves your device.")
                        .font(Theme.pixelFont(9, weight: .regular))
                        .foregroundStyle(Theme.textSecondary)
                    Button("GRANT ACCESS") {
                        if postureSource.camera.authorization == .denied {
                            CameraPermission.openSystemSettings()
                        } else {
                            postureSource.camera.start()
                        }
                    }
                    .buttonStyle(PixelButtonStyle())
                }
                Divider().background(Theme.divider)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("CAMERA")
                    .font(Theme.pixelFont(9))
                    .foregroundStyle(Theme.textSecondary)
                if postureSource.camera.devices.isEmpty {
                    Text("No camera detected")
                        .font(Theme.pixelFont(9, weight: .regular))
                        .foregroundStyle(Theme.textSecondary)
                } else {
                    Picker("", selection: cameraSelection) {
                        ForEach(postureSource.camera.devices) { device in
                            Text(device.name).tag(device.id)
                        }
                    }
                    .labelsHidden()
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("SENSITIVITY")
                    .font(Theme.pixelFont(9))
                    .foregroundStyle(Theme.textSecondary)
                Text("Higher reacts to smaller slouches. Lower is more forgiving.")
                    .font(Theme.pixelFont(8, weight: .regular))
                    .foregroundStyle(Theme.textSecondary)
                Slider(value: $postureSource.sensitivity, in: 0.25...4, step: 0.25)
                    .tint(Theme.accent)
            }

            Toggle(
                "PAUSE MONITORING",
                isOn: Binding(
                    get: { postureSource.isPaused },
                    set: { postureSource.setPaused($0) }
                )
            )
            .toggleStyle(.switch)
            .tint(Theme.accent)
            .font(Theme.pixelFont(10))
            .foregroundStyle(Theme.textPrimary)
            .help("Temporarily stops watching without quitting the app.")

            Divider().background(Theme.divider)

            VStack(alignment: .leading, spacing: 6) {
                Text("CHARACTER")
                    .font(Theme.pixelFont(9))
                    .foregroundStyle(Theme.textSecondary)
                Button {
                    onChangeCharacter()
                } label: {
                    HStack {
                        Text(CharacterCatalog.option(for: selectedCharacterID).preview)
                            .font(.system(size: 22))
                        VStack(alignment: .leading, spacing: 1) {
                            Text(CharacterCatalog.option(for: selectedCharacterID).name.uppercased())
                                .font(Theme.pixelFont(10))
                            Text("CHANGE CHARACTER")
                                .font(Theme.pixelFont(8, weight: .regular))
                                .foregroundStyle(Theme.textSecondary)
                        }
                        Spacer()
                    }
                }
                .buttonStyle(PixelButtonStyle(fill: Theme.surface, textColor: Theme.textPrimary))
            }

            Divider().background(Theme.divider)

            subscriptionSection

            Divider().background(Theme.divider)

            VStack(alignment: .leading, spacing: 6) {
                Button("RECALIBRATE") {
                    postureSource.startCalibration()
                }
                .buttonStyle(PixelButtonStyle(fill: Theme.surface, textColor: Theme.textPrimary))
                .help("Resets your \"good posture\" baseline to how you're sitting right now.")

                Text(postureSource.statusText)
                    .font(Theme.pixelFont(8, weight: .regular))
                    .foregroundStyle(Theme.textSecondary)
            }

            Button("SHOW ONBOARDING AGAIN") {
                onShowOnboarding()
            }
            .buttonStyle(PixelButtonStyle(fill: Theme.surface, textColor: Theme.textPrimary))

            Divider().background(Theme.divider)

            Button("QUIT APOLLO") {
                NSApp.terminate(nil)
            }
            .buttonStyle(PixelButtonStyle(fill: Theme.surface, textColor: .red))
        }
        .padding(16)
        .frame(width: 300)
        .background(Theme.background)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showPaywall) {
            PaywallView(subscriptionManager: subscriptionManager)
        }
    }

    private var cameraSelection: Binding<String> {
        Binding(
            get: { postureSource.camera.selectedDeviceID ?? "" },
            set: { postureSource.camera.select(deviceID: $0) }
        )
    }

    @ViewBuilder
    private var subscriptionSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("SUBSCRIPTION")
                .font(Theme.pixelFont(9))
                .foregroundStyle(Theme.textSecondary)

            if subscriptionManager.isSubscribed {
                HStack {
                    Circle().fill(.green).frame(width: 6, height: 6)
                    Text("Apollo Premium active")
                        .font(Theme.pixelFont(10, weight: .regular))
                        .foregroundStyle(Theme.textPrimary)
                }
                // Apple's own subscriptions page handles cancellation, plan
                // changes, and billing problems. We never build any of that.
                Button("MANAGE SUBSCRIPTION") {
                    SubscriptionManager.openManageSubscriptions()
                }
                .buttonStyle(PixelButtonStyle(fill: Theme.surface, textColor: Theme.textPrimary))
            } else {
                Text("Not subscribed")
                    .font(Theme.pixelFont(10, weight: .regular))
                    .foregroundStyle(Theme.textSecondary)
                Button("SUBSCRIBE") {
                    showPaywall = true
                }
                .buttonStyle(PixelButtonStyle())
            }
        }
    }
}

#Preview {
    SettingsView(postureSource: PostureMonitor(), subscriptionManager: SubscriptionManager())
}
