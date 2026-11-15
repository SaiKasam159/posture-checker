import SwiftUI

struct SettingsView: View {
    @State private var selectedCamera = "Built-in Camera"
    @State private var sensitivity: Double = 10
    @State private var isPaused = false
    @State private var cameraAuthorized = false

    let cameras = ["Built-in Camera", "External Monitor Camera"]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Posture Checker")
                .font(.headline)

            if !cameraAuthorized {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Camera access needed")
                        .font(.subheadline.bold())
                    Text("Posture Checker watches your webcam locally to detect slouching. Video never leaves your device.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Grant Camera Access") {
                        CameraPermission.request { granted in
                            cameraAuthorized = granted
                            if !granted {
                                CameraPermission.openSystemSettings()
                            }
                        }
                    }
                }
                Divider()
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Camera")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Picker("", selection: $selectedCamera) {
                    ForEach(cameras, id: \.self) { Text($0) }
                }
                .labelsHidden()
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Sensitivity — alert after \(Int(sensitivity))s slouched")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Slider(value: $sensitivity, in: 3...30, step: 1)
            }

            Toggle("Pause monitoring", isOn: $isPaused)

            Divider()

            Button("Recalibrate") {
                // Hook up to backend calibration routine once available.
            }

            Divider()

            Button("Quit Posture Checker") {
                NSApp.terminate(nil)
            }
            .foregroundStyle(.red)
        }
        .padding(16)
        .frame(width: 280)
        .onAppear {
            CameraPermission.request { granted in
                cameraAuthorized = granted
            }
        }
    }
}

#Preview {
    SettingsView()
}
