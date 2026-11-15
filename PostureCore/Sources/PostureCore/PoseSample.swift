import Foundation

/// A point in the camera frame. Y points up and runs 0...1 over the frame height.
/// X uses the same unit, so it runs 0...aspectRatio. That keeps angles and distances true.
public struct Point: Equatable, Codable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

/// The landmarks found in one camera frame.
public struct PoseSample: Equatable, Sendable {
    public var shoulderA: Point
    public var shoulderB: Point
    /// Nose, or the midpoint of the ears when the nose isn't visible.
    public var head: Point?
    /// Width of the face box as a fraction of the frame width. Bigger means closer to the camera.
    public var faceWidthFraction: Double?

    public init(shoulderA: Point, shoulderB: Point, head: Point? = nil, faceWidthFraction: Double? = nil) {
        self.shoulderA = shoulderA
        self.shoulderB = shoulderB
        self.head = head
        self.faceWidthFraction = faceWidthFraction
    }
}

/// The numbers we judge posture on, derived from one `PoseSample`.
public struct PostureMetrics: Equatable, Sendable {
    /// Angle of the shoulder line against horizontal. 0 means level.
    public var shoulderTiltDegrees: Double
    public var shoulderWidth: Double
    /// Height of the head above the shoulder line, divided by shoulder width.
    /// It shrinks when the head sinks toward the shoulders.
    public var neckRatio: Double?
    public var headY: Double?
    public var faceWidthFraction: Double?

    public init(
        shoulderTiltDegrees: Double,
        shoulderWidth: Double,
        neckRatio: Double? = nil,
        headY: Double? = nil,
        faceWidthFraction: Double? = nil
    ) {
        self.shoulderTiltDegrees = shoulderTiltDegrees
        self.shoulderWidth = shoulderWidth
        self.neckRatio = neckRatio
        self.headY = headY
        self.faceWidthFraction = faceWidthFraction
    }

    /// Returns nil when the two shoulders sit on the same spot, which means the detection is junk.
    public init?(sample: PoseSample) {
        // Order by x so the result doesn't depend on which shoulder is which, or on mirroring.
        let (left, right) = sample.shoulderA.x <= sample.shoulderB.x
            ? (sample.shoulderA, sample.shoulderB)
            : (sample.shoulderB, sample.shoulderA)
        let dx = right.x - left.x
        let dy = right.y - left.y
        let width = (dx * dx + dy * dy).squareRoot()
        guard width > 1e-6 else { return nil }

        let midY = (left.y + right.y) / 2
        self.shoulderTiltDegrees = atan2(dy, dx) * 180 / .pi
        self.shoulderWidth = width
        self.neckRatio = sample.head.map { ($0.y - midY) / width }
        self.headY = sample.head?.y
        self.faceWidthFraction = sample.faceWidthFraction
    }
}
