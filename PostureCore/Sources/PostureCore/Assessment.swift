import Foundation

/// How far from the baseline counts as bad. These are starting values and need tuning on real setups.
public struct Thresholds: Equatable, Sendable {
    /// Shoulder line tilting this many degrees away from the baseline.
    public var shoulderTiltDegrees = 8.0
    /// Head-to-shoulder height shrinking by this fraction of the baseline.
    public var neckCompression = 0.18
    /// Head dropping in the frame by this many face widths. Half a face is roughly 7 to 8 cm.
    public var headDrop = 0.5
    /// Face appearing this many times wider than at calibration. 1.3 is roughly a quarter closer.
    public var closenessRatio = 1.3

    public init() {}

    /// Sensitivity 1 is the default. Higher reacts to smaller movements, lower is more forgiving.
    public init(sensitivity: Double) {
        let s = min(max(sensitivity, 0.25), 4)
        shoulderTiltDegrees /= s
        neckCompression /= s
        headDrop /= s
        closenessRatio = 1 + (closenessRatio - 1) / s
    }
}

public enum SlouchReason: String, Equatable, Sendable {
    case shouldersTilted
    case headSunk
    case headDropped
}

/// The verdict on a single moment. Timing (how long it has lasted) is handled by `SustainedTracker`.
public struct Assessment: Equatable, Sendable {
    /// 0 is the calibrated position. 1 or more counts as slouching.
    public var slouchScore: Double
    /// The measurement furthest from the baseline, whether or not it crosses the line.
    public var slouchReason: SlouchReason
    public var isSlouching: Bool { slouchScore >= 1 }

    /// Face width now divided by face width at calibration. Nil when the face isn't visible.
    public var closenessRatio: Double?
    public var isTooClose: Bool
    /// Rough distance from the camera. See `DistanceEstimator` for how rough.
    public var estimatedDistanceCm: Double?
    /// Nil when shoulders are hidden now or were hidden at calibration.
    public var shoulderTiltChangeDegrees: Double?

    /// Compares whatever is visible now against whatever was visible at calibration.
    /// With shoulders hidden it falls back to the head alone.
    public static func assess(_ m: PostureMetrics, against b: Baseline, thresholds t: Thresholds) -> Assessment {
        var worst = (reason: SlouchReason.headDropped, score: 0.0)
        func consider(_ reason: SlouchReason, _ score: Double) {
            if score > worst.score { worst = (reason, score) }
        }

        var tiltChange: Double?
        if let tilt = m.shoulderTiltDegrees, let baseTilt = b.shoulderTiltDegrees {
            tiltChange = tilt - baseTilt
            consider(.shouldersTilted, abs(tilt - baseTilt) / t.shoulderTiltDegrees)
        }
        if let neck = m.neckRatio, let baseNeck = b.neckRatio, baseNeck > 0 {
            consider(.headSunk, ((baseNeck - neck) / baseNeck) / t.neckCompression)
        }
        if let headY = m.headY, b.faceWidth > 0 {
            consider(.headDropped, ((b.headY - headY) / b.faceWidth) / t.headDrop)
        }

        var closeness: Double?
        if let width = m.faceWidth, b.faceWidth > 0 {
            closeness = width / b.faceWidth
        }

        return Assessment(
            slouchScore: worst.score,
            slouchReason: worst.reason,
            closenessRatio: closeness,
            isTooClose: (closeness ?? 0) >= t.closenessRatio,
            estimatedDistanceCm: m.faceWidthFraction.flatMap { DistanceEstimator.estimateCm(faceWidthFraction: $0) },
            shoulderTiltChangeDegrees: tiltChange
        )
    }
}

/// Turns face size in the frame into an approximate distance.
/// It assumes a typical webcam field of view and an average face width, so expect it to be off
/// by a fifth or more on some cameras. Use it for display and sanity checks, not for alerts.
public enum DistanceEstimator {
    public static let assumedHorizontalFOVDegrees = 65.0
    public static let assumedFaceWidthCm = 15.0
    /// Below this, the calibration position itself is probably too close to the screen.
    public static let comfortableMinimumCm = 45.0

    public static func estimateCm(
        faceWidthFraction: Double,
        horizontalFOVDegrees: Double = assumedHorizontalFOVDegrees,
        faceWidthCm: Double = assumedFaceWidthCm
    ) -> Double? {
        guard faceWidthFraction > 0 else { return nil }
        let frameWidthAtOneCm = 2 * tan(horizontalFOVDegrees * .pi / 360)
        return faceWidthCm / (frameWidthAtOneCm * faceWidthFraction)
    }
}
