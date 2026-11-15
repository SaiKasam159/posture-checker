import AppKit
import PostureCore
import SwiftUI

/// Plain working panel for testing detection. It shows what the app sees and why it reacts.
/// The real UI and the characters replace this; they only need `PostureMonitor`.
struct DebugPanelView: View {
    @ObservedObject var monitor: PostureMonitor
    @ObservedObject private var camera: CameraManager

    init(monitor: PostureMonitor) {
        self.monitor = monitor
        self.camera = monitor.camera
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(monitor.statusText)
                .font(.headline)
                .foregroundStyle(statusColor)
                .fixedSize(horizontal: false, vertical: true)

            if camera.authorization == .authorized {
                if !monitor.isPaused {
                    preview
                    readouts
                }
                Divider()
                controls
            } else if camera.authorization != .notDetermined {
                Text("Posture Checker needs the camera to see how you're sitting. Video is analysed on this Mac and never saved or sent anywhere.")
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Open Camera Settings") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }

            Divider()
            HStack {
                if camera.authorization == .authorized {
                    Button(monitor.isPaused ? "Resume" : "Pause") {
                        monitor.setPaused(!monitor.isPaused)
                    }
                }
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
            }
        }
        .padding(14)
        .frame(width: 320)
    }

    private var statusColor: Color {
        switch max(monitor.slouchLevel, monitor.distanceLevel) {
        case .ok: return .primary
        case .warning: return .orange
        case .alarm: return .red
        }
    }

    // MARK: Preview

    private var preview: some View {
        CameraPreviewView(session: camera.session)
            .overlay {
                Canvas { context, size in
                    guard let sample = monitor.lastSample else { return }
                    // Mirrored to match the preview.
                    func place(_ p: PostureCore.Point) -> CGPoint {
                        CGPoint(x: (1 - p.x / monitor.frameAspect) * size.width, y: (1 - p.y) * size.height)
                    }
                    let a = place(sample.shoulderA), b = place(sample.shoulderB)
                    var line = Path()
                    line.move(to: a)
                    line.addLine(to: b)
                    context.stroke(line, with: .color(statusColor == .primary ? .green : statusColor), lineWidth: 3)
                    for p in [a, b] + (sample.head.map { [place($0)] } ?? []) {
                        let dot = CGRect(x: p.x - 4, y: p.y - 4, width: 8, height: 8)
                        context.fill(Path(ellipseIn: dot), with: .color(.white))
                    }
                }
            }
            .aspectRatio(monitor.frameAspect, contentMode: .fit)
            .background(.black)
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private var readouts: some View {
        if let a = monitor.assessment {
            VStack(alignment: .leading, spacing: 4) {
                ProgressView(value: min(a.slouchScore, 1.5), total: 1.5) {
                    Text("Slouch \(Int(a.slouchScore * 100))% of limit")
                        .font(.caption)
                }
                .tint(a.isSlouching ? .orange : .green)

                Text("Shoulder tilt \(a.shoulderTiltChangeDegrees, specifier: "%+.1f")° from your calibrated position")
                if let ratio = a.closenessRatio {
                    Text("Face \(ratio, specifier: "%.2f")x calibrated size\(a.estimatedDistanceCm.map { ", roughly \(Int($0)) cm away" } ?? "")")
                } else {
                    Text("Face not visible, so distance is unknown")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    // MARK: Controls

    private var controls: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("Camera", selection: Binding(
                get: { camera.selectedDeviceID ?? "" },
                set: { camera.select(deviceID: $0) }
            )) {
                ForEach(camera.devices) { device in
                    Text(device.name).tag(device.id)
                }
            }

            HStack {
                Text("Sensitivity")
                Slider(value: $monitor.sensitivity, in: 0.5...2)
            }

            if !monitor.isPaused {
                calibrationControls
            }
        }
    }

    @ViewBuilder
    private var calibrationControls: some View {
        switch monitor.calibration {
        case .collecting(let progress):
            ProgressView(value: progress) {
                Text("Hold still…").font(.caption)
            }
        case .idle, .failed:
            Text("Sit up straight at arm's length from the screen, then press the button.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button(monitor.isCalibrated ? "Recalibrate" : "Calibrate") {
                monitor.startCalibration()
            }
            if case .failed(let message) = monitor.calibration {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let note = monitor.calibrationNote {
                Text(note)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
