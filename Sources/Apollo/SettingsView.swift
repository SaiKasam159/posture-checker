import SwiftUI
import StoreKit

struct SettingsView: View {
    @State private var selectedCamera = "Built-in Camera"
    @State private var sensitivity: Double = 10
    @State private var isPaused = false
    @State private var cameraAuthorized = false
    @AppStorage("selectedCharacterID") private var selectedCharacterID = CharacterCatalog.defaultID

    @ObservedObject var subscriptionManager: SubscriptionManager
    @State private var showPaywall = false

    let cameras = ["Built-in Camera", "External Monitor Camera"]
    var onShowOnboarding: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Apollo")
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)

            if !cameraAuthorized {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Camera access needed")
                        .font(.subheadline.bold())
                        .foregroundStyle(Theme.textPrimary)
                    Text("Apollo watches your webcam locally to detect slouching. Video never leaves your device.")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                    Button("Grant Camera Access") {
                        CameraPermission.request { granted in
                            cameraAuthorized = granted
                            if !granted {
                                CameraPermission.openSystemSettings()
                            }
                        }
                    }
                    .tint(Theme.accent)
                }
                Divider().background(Theme.divider)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Camera")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
                Picker("", selection: $selectedCamera) {
                    ForEach(cameras, id: \.self) { Text($0) }
                }
                .labelsHidden()
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Sensitivity — alert after \(Int(sensitivity))s slouched")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
                Slider(value: $sensitivity, in: 3...30, step: 1)
                    .tint(Theme.accent)
            }

            Toggle("Pause monitoring", isOn: $isPaused)
                .tint(Theme.accent)
                .foregroundStyle(Theme.textPrimary)
                .help("Temporarily stops watching without quitting the app.")

            Divider().background(Theme.divider)

            VStack(alignment: .leading, spacing: 6) {
                Text("Character")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
                CharacterPickerView(selectedID: $selectedCharacterID)
            }

            Divider().background(Theme.divider)

            subscriptionSection

            Divider().background(Theme.divider)

            Button("Recalibrate") {
                // Hook up to backend calibration routine once available.
            }
            .foregroundStyle(Theme.textPrimary)
            .help("Resets your \"good posture\" baseline to how you're sitting right now.")

            Button("Show Welcome Guide Again") {
                onShowOnboarding()
            }
            .foregroundStyle(Theme.textPrimary)

            Divider().background(Theme.divider)

            Button("Quit Apollo") {
                NSApp.terminate(nil)
            }
            .foregroundStyle(.red)
        }
        .padding(16)
        .frame(width: 300)
        .background(Theme.background)
        .preferredColorScheme(.dark)
        .onAppear {
            CameraPermission.request { granted in
                cameraAuthorized = granted
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(subscriptionManager: subscriptionManager)
        }
    }

    @ViewBuilder
    private var subscriptionSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Subscription")
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)

            if subscriptionManager.isSubscribed {
                HStack {
                    Circle().fill(.green).frame(width: 6, height: 6)
                    Text("Apollo Premium active")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textPrimary)
                }
                // Apple's own subscriptions page handles cancellation, plan
                // changes, and billing problems. We never build any of that.
                Button("Manage Subscription") {
                    SubscriptionManager.openManageSubscriptions()
                }
                .foregroundStyle(Theme.textPrimary)
            } else {
                Text("Not subscribed")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                Button("Subscribe") {
                    showPaywall = true
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
                .foregroundStyle(.black)
            }
        }
    }
}

#Preview {
    SettingsView(subscriptionManager: SubscriptionManager())
}
