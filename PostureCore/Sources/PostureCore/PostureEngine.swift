import Foundation

/// Feed it one `PoseSample` per analysed frame and it tells you what the UI should show.
/// It has no camera or Vision code, so it can be tested with made-up samples.
public final class PostureEngine {
    public struct Output: Equatable, Sendable {
        public var personPresent: Bool
        /// Nil until calibrated, or when nobody is in view.
        public var assessment: Assessment?
        public var slouchLevel: AlertLevel
        public var distanceLevel: AlertLevel
    }

    public var baseline: Baseline? {
        didSet { resetTracking() }
    }
    public var thresholds: Thresholds

    /// How much each new frame moves the smoothed value. 1 means no smoothing.
    public var smoothing = 0.5
    /// A gap this long between frames (sleep, pause) wipes the timers so stale history can't fire an alert.
    public var maxGap: TimeInterval = 5

    private var slouchTracker: SustainedTracker
    private var distanceTracker: SustainedTracker
    private var smoothed: PostureMetrics?
    private var lastUpdate: TimeInterval?

    public init(
        baseline: Baseline? = nil,
        thresholds: Thresholds = Thresholds(),
        slouchTiming: SustainedTracker.Timing = .slouch,
        distanceTiming: SustainedTracker.Timing = .distance
    ) {
        self.baseline = baseline
        self.thresholds = thresholds
        self.slouchTracker = SustainedTracker(timing: slouchTiming)
        self.distanceTracker = SustainedTracker(timing: distanceTiming)
    }

    public func resetTracking() {
        slouchTracker.reset()
        distanceTracker.reset()
        smoothed = nil
        lastUpdate = nil
    }

    /// Pass nil when no person was found in the frame.
    public func ingest(_ sample: PoseSample?, at time: TimeInterval) -> Output {
        if let lastUpdate, time - lastUpdate > maxGap {
            resetTracking()
        }
        lastUpdate = time

        guard let sample, let raw = PostureMetrics(sample: sample) else {
            // Nobody there: let any alert clear, as if they had sat up.
            smoothed = nil
            return Output(
                personPresent: false,
                assessment: nil,
                slouchLevel: slouchTracker.update(isBad: false, at: time),
                distanceLevel: distanceTracker.update(isBad: false, at: time)
            )
        }

        let metrics = smooth(raw)
        smoothed = metrics

        guard let baseline else {
            return Output(personPresent: true, assessment: nil, slouchLevel: .ok, distanceLevel: .ok)
        }

        let assessment = Assessment.assess(metrics, against: baseline, thresholds: thresholds)
        return Output(
            personPresent: true,
            assessment: assessment,
            slouchLevel: slouchTracker.update(isBad: assessment.isSlouching, at: time),
            distanceLevel: distanceTracker.update(isBad: assessment.isTooClose, at: time)
        )
    }

    private func smooth(_ new: PostureMetrics) -> PostureMetrics {
        guard let old = smoothed else { return new }
        let a = smoothing
        func blend(_ o: Double, _ n: Double) -> Double { o + a * (n - o) }
        func blend(_ o: Double?, _ n: Double?) -> Double? {
            guard let n else { return nil }
            guard let o else { return n }
            return blend(o, n)
        }
        return PostureMetrics(
            shoulderTiltDegrees: blend(old.shoulderTiltDegrees, new.shoulderTiltDegrees),
            shoulderWidth: blend(old.shoulderWidth, new.shoulderWidth),
            neckRatio: blend(old.neckRatio, new.neckRatio),
            headY: blend(old.headY, new.headY),
            faceWidthFraction: blend(old.faceWidthFraction, new.faceWidthFraction)
        )
    }
}
