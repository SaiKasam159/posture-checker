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

public struct Face: Equatable, Sendable {
    public var center: Point
    /// Width of the face box, in the same unit as `Point`.
    public var width: Double

    public init(center: Point, width: Double) {
        self.center = center
        self.width = width
    }
}

public struct Shoulders: Equatable, Sendable {
    public var a: Point
    public var b: Point

    public init(a: Point, b: Point) {
        self.a = a
        self.b = b
    }
}

/// What was found in one camera frame. Either part can be missing:
/// a hoodie or a tight camera angle hides shoulders, a turned head hides the face.
public struct PoseSample: Equatable, Sendable {
    public var face: Face?
    public var shoulders: Shoulders?
    /// Frame width divided by height.
    public var frameAspect: Double

    public init(face: Face?, shoulders: Shoulders?, frameAspect: Double) {
        self.face = face
        self.shoulders = shoulders
        self.frameAspect = frameAspect
    }
}

/// The numbers we judge posture on, derived from one `PoseSample`.
/// The head numbers need a face, the shoulder numbers need shoulders, and `neckRatio` needs both.
public struct PostureMetrics: Equatable, Sendable {
    public var headY: Double?
    public var faceWidth: Double?
    /// Face width as a fraction of the frame width. Used for the rough distance estimate.
    public var faceWidthFraction: Double?
    /// Angle of the shoulder line against horizontal. 0 means level.
    public var shoulderTiltDegrees: Double?
    /// Height of the head above the shoulder line, divided by shoulder width.
    /// It shrinks when the head sinks toward the shoulders.
    public var neckRatio: Double?

    public init(
        headY: Double? = nil,
        faceWidth: Double? = nil,
        faceWidthFraction: Double? = nil,
        shoulderTiltDegrees: Double? = nil,
        neckRatio: Double? = nil
    ) {
        self.headY = headY
        self.faceWidth = faceWidth
        self.faceWidthFraction = faceWidthFraction
        self.shoulderTiltDegrees = shoulderTiltDegrees
        self.neckRatio = neckRatio
    }

    /// Returns nil when the frame has neither a face nor usable shoulders.
    public init?(sample: PoseSample) {
        if let face = sample.face, face.width > 0 {
            headY = face.center.y
            faceWidth = face.width
            faceWidthFraction = sample.frameAspect > 0 ? face.width / sample.frameAspect : nil
        }

        if let s = sample.shoulders {
            // Order by x so the result doesn't depend on which shoulder is which, or on mirroring.
            let (left, right) = s.a.x <= s.b.x ? (s.a, s.b) : (s.b, s.a)
            let dx = right.x - left.x
            let dy = right.y - left.y
            let width = (dx * dx + dy * dy).squareRoot()
            // Two shoulders on the same spot means the detection is junk.
            if width > 1e-6 {
                shoulderTiltDegrees = atan2(dy, dx) * 180 / .pi
                if let headY {
                    neckRatio = (headY - (left.y + right.y) / 2) / width
                }
            }
        }

        if headY == nil && shoulderTiltDegrees == nil { return nil }
    }
}
