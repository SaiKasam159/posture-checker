import SwiftUI
import StoreKit
import AVFoundation

struct SettingsView: View {
    @ObservedObject var postureSource: MockPostureSource
    @ObservedObject var subscriptionManager: SubscriptionManager

    @State private var availableCameras: [AVCaptureDevice] = []
    @State private var selectedCameraID: String = UserDefaults.standard.string(forKey: CameraCatalog.selectedCameraIDKey) ?? ""
    @State private var cameraAuthorized = false
    @AppStorage("selectedCharacterID") private var selectedCharacterID = CharacterCatalog.defaultID
    @State private var showPaywall = false

    var onShowOnboarding: () -> Void = {}
    var onChangeCharacter: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("APOLLO")
                .font(Theme.pixelFont(14))
                .foregroundStyle(Theme.textPrimary)

            if !cameraAuthorized {
                VStack(alignment: .leading, spacing: 6) {
                    Text("CAMERA ACCESS NEEDED")
                        .font(Theme.pixelFont(11))
                        .foregroundStyle(Theme.textPrimary)
                    Text("Apollo watches your webcam locally to detect slouching. Video never leaves your device.")
                        .font(Theme.pixelFont(9, weight: .regular))
                        .foregroundStyle(Theme.textSecondary)
                    Button("GRANT ACCESS") {
                        CameraPermission.request { granted in
                            cameraAuthorized = granted
                            if !granted {
                                CameraPermission.openSystemSettings()
                            }
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
                if availableCameras.isEmpty {
                    Text("No camera detected")
                        .font(Theme.pixelFont(9, weight: .regular))
                        .foregroundStyle(Theme.textSecondary)
                } else {
                    Picker("", selection: $selectedCameraID) {
                        ForEach(availableCameras, id: \.uniqueID) { device in
                            Text(device.localizedName).tag(device.uniqueID)
                        }
                    }
                    .labelsHidden()
                    .onChange(of: selectedCameraID) { newValue in
                        UserDefaults.standard.set(newValue, forKey: CameraCatalog.selectedCameraIDKey)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("SENSITIVITY — ALERT AFTER \(Int(postureSource.slouchThresholdSeconds))S SLOUCHED")
                    .font(Theme.pixelFont(9))
                    .foregroundStyle(Theme.textSecondary)
                Slider(
                    value: $postureSource.slouchThresholdSeconds,
                    in: 3...30,
                    step: 1
                )
                .tint(Theme.accent)
            }

            Toggle("PAUSE MONITORING", isOn: $postureSource.isPaused)
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

            Button("RECALIBRATE") {
                // Hook up to backend calibration routine once available.
            }
            .buttonStyle(PixelButtonStyle(fill: Theme.surface, textColor: Theme.textPrimary))
            .help("Resets your \"good posture\" baseline to how you're sitting right now.")

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
        .onAppear {
            CameraPermission.request { granted in
                cameraAuthorized = granted
            }
            availableCameras = CameraCatalog.availableCameras()
            if selectedCameraID.isEmpty || !availableCameras.contains(where: { $0.uniqueID == selectedCameraID }) {
                selectedCameraID = availableCameras.first?.uniqueID ?? ""
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(subscriptionManager: subscriptionManager)
        }
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
    SettingsView(postureSource: MockPostureSource(), subscriptionManager: SubscriptionManager())
}
