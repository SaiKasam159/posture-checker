import AVFoundation

/// Real connected cameras, for the settings picker. Which camera actually
/// gets used for capture is the backend's job — this just lists devices and
/// persists the user's choice under a shared UserDefaults key the backend
/// can read.
enum CameraCatalog {
    static let selectedCameraIDKey = "selectedCameraUniqueID"

    /// `AVCaptureDevice.DiscoverySession`'s `.external` device type needs
    /// macOS 14; using the older enumeration API keeps this working on our
    /// macOS 13 minimum target and still lists externally connected cameras.
    static func availableCameras() -> [AVCaptureDevice] {
        AVCaptureDevice.devices(for: .video)
    }
}
