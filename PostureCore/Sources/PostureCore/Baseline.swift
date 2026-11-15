import Foundation

/// The user's own "sitting well" position, captured during calibration.
/// Everything is judged relative to this, so the camera can be at any angle.
public struct Baseline: Equatable, Codable, Sendable {
    public var shoulderTiltDegrees: Double
    public var shoulderWidth: Double
    public var neckRatio: Double
    public var headY: Double
    public var faceWidthFraction: Double

    public init(
        shoulderTiltDegrees: Double,
        shoulderWidth: Double,
        neckRatio: Double,
        headY: Double,
        faceWidthFraction: Double
    ) {
        self.shoulderTiltDegrees = shoulderTiltDegrees
        self.shoulderWidth = shoulderWidth
        self.neckRatio = neckRatio
        self.headY = headY
        self.faceWidthFraction = faceWidthFraction
    }

    public static let minimumSamples = 4

    /// Averages the frames collected during calibration.
    /// Frames missing the head or face are skipped. Returns nil if too few usable frames remain.
    public static func average(of metrics: [PostureMetrics]) -> Baseline? {
        var tilt = 0.0, width = 0.0, neck = 0.0, headY = 0.0, face = 0.0
        var count = 0.0
        for m in metrics {
            guard let n = m.neckRatio, let h = m.headY, let f = m.faceWidthFraction, n > 0, f > 0 else { continue }
            tilt += m.shoulderTiltDegrees
            width += m.shoulderWidth
            neck += n
            headY += h
            face += f
            count += 1
        }
        guard Int(count) >= minimumSamples else { return nil }
        return Baseline(
            shoulderTiltDegrees: tilt / count,
            shoulderWidth: width / count,
            neckRatio: neck / count,
            headY: headY / count,
            faceWidthFraction: face / count
        )
    }
}

public extension PostureMetrics {
    /// True when the frame has everything calibration needs.
    var isUsableForCalibration: Bool {
        guard let n = neckRatio, let f = faceWidthFraction, headY != nil else { return false }
        return n > 0 && f > 0
    }
}
