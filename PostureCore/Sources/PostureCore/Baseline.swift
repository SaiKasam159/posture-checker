import Foundation

/// The user's own "sitting well" position, captured during calibration.
/// Everything is judged relative to this, so the camera can be at any angle.
public struct Baseline: Equatable, Codable, Sendable {
    public var headY: Double
    public var faceWidth: Double
    public var faceWidthFraction: Double
    /// Nil when the shoulders weren't visible during calibration. The head checks still work without them.
    public var shoulderTiltDegrees: Double?
    public var neckRatio: Double?

    public init(
        headY: Double,
        faceWidth: Double,
        faceWidthFraction: Double,
        shoulderTiltDegrees: Double? = nil,
        neckRatio: Double? = nil
    ) {
        self.headY = headY
        self.faceWidth = faceWidth
        self.faceWidthFraction = faceWidthFraction
        self.shoulderTiltDegrees = shoulderTiltDegrees
        self.neckRatio = neckRatio
    }

    public static let minimumSamples = 4

    /// Averages the frames collected during calibration.
    /// Frames without a face are skipped. Returns nil if too few usable frames remain.
    /// The shoulder numbers are only kept if shoulders showed up in at least half of those frames.
    public static func average(of metrics: [PostureMetrics]) -> Baseline? {
        let usable = metrics.filter(\.isUsableForCalibration)
        guard usable.count >= minimumSamples else { return nil }
        let count = Double(usable.count)

        func mean(_ values: [Double]) -> Double? {
            values.count * 2 >= usable.count ? values.reduce(0, +) / Double(values.count) : nil
        }
        return Baseline(
            headY: usable.compactMap(\.headY).reduce(0, +) / count,
            faceWidth: usable.compactMap(\.faceWidth).reduce(0, +) / count,
            faceWidthFraction: usable.compactMap(\.faceWidthFraction).reduce(0, +) / count,
            shoulderTiltDegrees: mean(usable.compactMap(\.shoulderTiltDegrees)),
            neckRatio: mean(usable.compactMap(\.neckRatio).filter { $0 > 0 })
        )
    }
}

public extension PostureMetrics {
    /// True when the frame has the face, which is all calibration strictly needs.
    var isUsableForCalibration: Bool {
        guard headY != nil, let w = faceWidth, let f = faceWidthFraction else { return false }
        return w > 0 && f > 0
    }
}
