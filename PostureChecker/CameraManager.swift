import AVFoundation
import Combine

struct CameraDevice: Identifiable, Equatable {
    let id: String
    let name: String
}

/// Owns the capture session: finds cameras, lets the user pick one, and hands out frames at a low rate.
final class CameraManager: NSObject, ObservableObject {
    @Published private(set) var devices: [CameraDevice] = []
    @Published private(set) var selectedDeviceID: String?
    @Published private(set) var authorization = AVCaptureDevice.authorizationStatus(for: .video)

    let session = AVCaptureSession()

    /// Called on a background queue for each frame we analyse. Set once before `start()`.
    var onFrame: ((CVPixelBuffer) -> Void)?
    /// Seconds between analysed frames. The rest are dropped to save battery.
    var frameInterval: TimeInterval = 0.5

    private let sessionQueue = DispatchQueue(label: "PostureChecker.camera.session")
    private let videoQueue = DispatchQueue(label: "PostureChecker.camera.video")
    private let output = AVCaptureVideoDataOutput()
    private let discovery = AVCaptureDevice.DiscoverySession(
        deviceTypes: [.builtInWideAngleCamera, .external, .continuityCamera],
        mediaType: .video,
        position: .unspecified
    )
    private var lastFrameTime: TimeInterval = 0
    private var wantsRunning = false
    private var observers: [NSObjectProtocol] = []

    private static let preferredDeviceKey = "preferredCameraID"

    override init() {
        super.init()
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: videoQueue)

        let center = NotificationCenter.default
        for name in [AVCaptureDevice.wasConnectedNotification, AVCaptureDevice.wasDisconnectedNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.refreshDevices()
            })
        }
        refreshDevices()
    }

    deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
    }

    /// Asks for camera access if needed, then starts capturing.
    func start() {
        wantsRunning = true
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            authorization = .authorized
            configureSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.authorization = granted ? .authorized : .denied
                    self.refreshDevices()
                    if granted, self.wantsRunning { self.configureSession() }
                }
            }
        case let status:
            authorization = status
        }
    }

    /// Stops capturing, which turns the camera light off.
    func stop() {
        wantsRunning = false
        sessionQueue.async { [session] in
            if session.isRunning { session.stopRunning() }
        }
    }

    func select(deviceID: String) {
        guard deviceID != selectedDeviceID, devices.contains(where: { $0.id == deviceID }) else { return }
        UserDefaults.standard.set(deviceID, forKey: Self.preferredDeviceKey)
        selectedDeviceID = deviceID
        if wantsRunning, authorization == .authorized { configureSession() }
    }

    private func refreshDevices() {
        devices = discovery.devices.map { CameraDevice(id: $0.uniqueID, name: $0.localizedName) }

        // The saved choice wins whenever that camera is plugged in. Otherwise fall back without forgetting it.
        let preferred = UserDefaults.standard.string(forKey: Self.preferredDeviceKey)
        let systemDefault = AVCaptureDevice.systemPreferredCamera?.uniqueID
        let pick = [preferred, selectedDeviceID, systemDefault, devices.first?.id]
            .compactMap { $0 }
            .first { id in devices.contains { $0.id == id } }

        if pick != selectedDeviceID {
            selectedDeviceID = pick
            if wantsRunning, authorization == .authorized { configureSession() }
        }
    }

    private func configureSession() {
        guard let deviceID = selectedDeviceID else { return }
        sessionQueue.async { [self] in
            let alreadyUsing = session.inputs.contains { ($0 as? AVCaptureDeviceInput)?.device.uniqueID == deviceID }
            if !alreadyUsing {
                guard let device = AVCaptureDevice(uniqueID: deviceID),
                      let input = try? AVCaptureDeviceInput(device: device) else { return }
                session.beginConfiguration()
                session.inputs.forEach(session.removeInput)
                if session.canAddInput(input) { session.addInput(input) }
                if session.outputs.isEmpty, session.canAddOutput(output) { session.addOutput(output) }
                // Small frames are plenty for finding shoulders and a face.
                if session.canSetSessionPreset(.vga640x480) { session.sessionPreset = .vga640x480 }
                session.commitConfiguration()
            }
            if wantsRunning, !session.isRunning { session.startRunning() }
        }
    }
}

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastFrameTime >= frameInterval,
              let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        lastFrameTime = now
        onFrame?(buffer)
    }
}
