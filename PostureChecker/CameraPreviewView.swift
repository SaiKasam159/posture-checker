import AVFoundation
import SwiftUI

/// Live camera picture, mirrored like a selfie view.
struct CameraPreviewView: NSViewRepresentable {
    let session: AVCaptureSession

    func makeNSView(context: Context) -> PreviewHostView {
        PreviewHostView(session: session)
    }

    func updateNSView(_ view: PreviewHostView, context: Context) {
        view.applyMirroring()
    }
}

final class PreviewHostView: NSView {
    private let previewLayer: AVCaptureVideoPreviewLayer

    init(session: AVCaptureSession) {
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        super.init(frame: .zero)
        wantsLayer = true
        previewLayer.videoGravity = .resizeAspect
        layer?.addSublayer(previewLayer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        previewLayer.frame = bounds
        CATransaction.commit()
        applyMirroring()
    }

    /// The connection is rebuilt when the camera changes, so this is reapplied on every update.
    func applyMirroring() {
        guard let connection = previewLayer.connection, connection.isVideoMirroringSupported else { return }
        connection.automaticallyAdjustsVideoMirroring = false
        connection.isVideoMirrored = true
    }
}
