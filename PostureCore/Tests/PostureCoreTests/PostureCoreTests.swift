import XCTest
@testable import PostureCore

/// A person sitting well: level shoulders 0.4 apart, head 0.24 above them, face a fifth of the frame wide.
private func sample(
    tiltDegrees: Double = 0,
    headAboveShoulders: Double = 0.24,
    shoulderY: Double = 0.4,
    faceWidth: Double? = 0.2
) -> PoseSample {
    let half = 0.2
    let rad = tiltDegrees * .pi / 180
    let centre = Point(x: 0.66, y: shoulderY)
    return PoseSample(
        shoulderA: Point(x: centre.x - half * cos(rad), y: centre.y - half * sin(rad)),
        shoulderB: Point(x: centre.x + half * cos(rad), y: centre.y + half * sin(rad)),
        head: Point(x: centre.x, y: shoulderY + headAboveShoulders),
        faceWidthFraction: faceWidth
    )
}

private let good = sample()
private let goodBaseline = Baseline.average(of: Array(repeating: PostureMetrics(sample: good)!, count: 4))!

final class MetricsTests: XCTestCase {
    func testLevelShouldersHaveZeroTilt() {
        let m = PostureMetrics(sample: good)!
        XCTAssertEqual(m.shoulderTiltDegrees, 0, accuracy: 1e-9)
        XCTAssertEqual(m.shoulderWidth, 0.4, accuracy: 1e-9)
        XCTAssertEqual(m.neckRatio!, 0.6, accuracy: 1e-9)
    }

    func testTiltIsMeasuredAndIgnoresShoulderOrder() {
        let s = sample(tiltDegrees: 12)
        let swapped = PoseSample(shoulderA: s.shoulderB, shoulderB: s.shoulderA, head: s.head, faceWidthFraction: s.faceWidthFraction)
        XCTAssertEqual(PostureMetrics(sample: s)!.shoulderTiltDegrees, 12, accuracy: 1e-9)
        XCTAssertEqual(PostureMetrics(sample: swapped)!.shoulderTiltDegrees, 12, accuracy: 1e-9)
    }

    func testCoincidentShouldersAreRejected() {
        let p = Point(x: 0.5, y: 0.5)
        XCTAssertNil(PostureMetrics(sample: PoseSample(shoulderA: p, shoulderB: p)))
    }
}

final class BaselineTests: XCTestCase {
    func testNeedsEnoughCompleteFrames() {
        let complete = PostureMetrics(sample: good)!
        let noFace = PostureMetrics(sample: sample(faceWidth: nil))!
        XCTAssertNil(Baseline.average(of: [complete, complete, complete, noFace, noFace]))
        XCTAssertNotNil(Baseline.average(of: [complete, complete, complete, complete, noFace]))
    }

    func testAveragesFrames() {
        let a = PostureMetrics(sample: sample(tiltDegrees: 2))!
        let b = PostureMetrics(sample: sample(tiltDegrees: 4))!
        XCTAssertEqual(Baseline.average(of: [a, b, a, b])!.shoulderTiltDegrees, 3, accuracy: 1e-9)
    }
}

final class AssessmentTests: XCTestCase {
    private func assess(_ s: PoseSample, sensitivity: Double = 1) -> Assessment {
        Assessment.assess(PostureMetrics(sample: s)!, against: goodBaseline, thresholds: Thresholds(sensitivity: sensitivity))
    }

    func testBaselinePositionIsFine() {
        let a = assess(good)
        XCTAssertEqual(a.slouchScore, 0, accuracy: 1e-9)
        XCTAssertFalse(a.isSlouching)
        XCTAssertFalse(a.isTooClose)
        XCTAssertEqual(a.closenessRatio!, 1, accuracy: 1e-9)
    }

    func testTiltedShouldersCountAsSlouching() {
        XCTAssertFalse(assess(sample(tiltDegrees: 5)).isSlouching)
        let a = assess(sample(tiltDegrees: -10))
        XCTAssertTrue(a.isSlouching)
        XCTAssertEqual(a.slouchReason, .shouldersTilted)
        XCTAssertEqual(a.shoulderTiltChangeDegrees, -10, accuracy: 1e-9)
    }

    func testHeadSinkingTowardShouldersCountsAsSlouching() {
        // Head 25% lower relative to the shoulders, shoulders unmoved.
        let a = assess(sample(headAboveShoulders: 0.18))
        XCTAssertTrue(a.isSlouching)
        XCTAssertEqual(a.slouchReason, .headSunk)
    }

    func testWholeUpperBodyDroppingCountsAsSlouching() {
        let a = assess(sample(shoulderY: 0.3))
        XCTAssertTrue(a.isSlouching)
        XCTAssertEqual(a.slouchReason, .headDropped)
    }

    func testSittingTallerIsNotSlouching() {
        XCTAssertFalse(assess(sample(headAboveShoulders: 0.3, shoulderY: 0.45)).isSlouching)
    }

    func testCloseness() {
        XCTAssertFalse(assess(sample(faceWidth: 0.24)).isTooClose)
        XCTAssertTrue(assess(sample(faceWidth: 0.27)).isTooClose)
        XCTAssertFalse(assess(sample(faceWidth: nil)).isTooClose)
    }

    func testHigherSensitivityTriggersSooner() {
        XCTAssertFalse(assess(sample(tiltDegrees: 5), sensitivity: 1).isSlouching)
        XCTAssertTrue(assess(sample(tiltDegrees: 5), sensitivity: 2).isSlouching)
        XCTAssertFalse(assess(sample(tiltDegrees: 10), sensitivity: 0.5).isSlouching)
    }

    func testDistanceEstimateIsPlausibleAndShrinksAsFaceGrows() {
        let far = DistanceEstimator.estimateCm(faceWidthFraction: 0.2)!
        let near = DistanceEstimator.estimateCm(faceWidthFraction: 0.4)!
        XCTAssertEqual(far, 58.9, accuracy: 0.5)
        XCTAssertEqual(near, far / 2, accuracy: 1e-9)
        XCTAssertNil(DistanceEstimator.estimateCm(faceWidthFraction: 0))
    }
}

final class SustainedTrackerTests: XCTestCase {
    private let timing = SustainedTracker.Timing(warnAfter: 8, alarmAfter: 12, lapseTolerance: 1.5, recoverAfter: 2)

    /// Runs `isBad` at two frames a second from `start` to `end` and returns the final level.
    @discardableResult
    private func run(_ t: inout SustainedTracker, from start: Double, to end: Double, isBad: Bool) -> AlertLevel {
        var time = start
        while time <= end {
            t.update(isBad: isBad, at: time)
            time += 0.5
        }
        return t.level
    }

    func testBriefProblemDoesNothing() {
        var t = SustainedTracker(timing: timing)
        XCTAssertEqual(run(&t, from: 0, to: 2, isBad: true), .ok)
        XCTAssertEqual(run(&t, from: 2.5, to: 30, isBad: false), .ok)
    }

    func testSustainedProblemWarnsThenAlarms() {
        var t = SustainedTracker(timing: timing)
        XCTAssertEqual(run(&t, from: 0, to: 7.5, isBad: true), .ok)
        XCTAssertEqual(run(&t, from: 8, to: 19.5, isBad: true), .warning)
        XCTAssertEqual(run(&t, from: 20, to: 25, isBad: true), .alarm)
    }

    func testCorrectingClearsTheWarning() {
        var t = SustainedTracker(timing: timing)
        run(&t, from: 0, to: 10, isBad: true)
        XCTAssertEqual(t.level, .warning)
        XCTAssertEqual(run(&t, from: 10.5, to: 12, isBad: false), .warning, "not yet good for long enough")
        XCTAssertEqual(run(&t, from: 12.5, to: 13, isBad: false), .ok)
    }

    func testCorrectingClearsTheAlarm() {
        var t = SustainedTracker(timing: timing)
        run(&t, from: 0, to: 25, isBad: true)
        XCTAssertEqual(t.level, .alarm)
        XCTAssertEqual(run(&t, from: 25.5, to: 28, isBad: false), .ok)
    }

    func testOneGoodFrameDoesNotRestartTheCountdown() {
        var t = SustainedTracker(timing: timing)
        run(&t, from: 0, to: 5, isBad: true)
        t.update(isBad: false, at: 5.5)
        XCTAssertEqual(run(&t, from: 6, to: 8, isBad: true), .warning)
    }

    func testLongBreakRestartsTheCountdown() {
        var t = SustainedTracker(timing: timing)
        run(&t, from: 0, to: 5, isBad: true)
        run(&t, from: 5.5, to: 8, isBad: false)
        XCTAssertEqual(run(&t, from: 8.5, to: 14, isBad: true), .ok)
        XCTAssertEqual(run(&t, from: 14.5, to: 17, isBad: true), .warning)
    }

    func testAfterRecoveryTheNextWarningTakesTheFullTimeAgain() {
        var t = SustainedTracker(timing: timing)
        run(&t, from: 0, to: 10, isBad: true)
        run(&t, from: 10.5, to: 14, isBad: false)
        XCTAssertEqual(t.level, .ok)
        XCTAssertEqual(run(&t, from: 14.5, to: 20, isBad: true), .ok)
    }
}

final class PostureEngineTests: XCTestCase {
    private func feed(_ e: PostureEngine, _ s: PoseSample?, from start: Double, to end: Double) -> PostureEngine.Output {
        var out = e.ingest(s, at: start)
        var time = start + 0.5
        while time <= end {
            out = e.ingest(s, at: time)
            time += 0.5
        }
        return out
    }

    func testUncalibratedEngineNeverAlerts() {
        let e = PostureEngine()
        let out = feed(e, sample(tiltDegrees: 30), from: 0, to: 60)
        XCTAssertTrue(out.personPresent)
        XCTAssertNil(out.assessment)
        XCTAssertEqual(out.slouchLevel, .ok)
    }

    func testSlouchEscalatesAndClears() {
        let e = PostureEngine(baseline: goodBaseline)
        XCTAssertEqual(feed(e, good, from: 0, to: 5).slouchLevel, .ok)
        XCTAssertEqual(feed(e, sample(headAboveShoulders: 0.15), from: 5.5, to: 16).slouchLevel, .warning)
        XCTAssertEqual(feed(e, sample(headAboveShoulders: 0.15), from: 16.5, to: 30).slouchLevel, .alarm)
        XCTAssertEqual(feed(e, good, from: 30.5, to: 35).slouchLevel, .ok)
    }

    func testQuickLeanInIsIgnoredButStayingCloseIsNot() {
        let e = PostureEngine(baseline: goodBaseline)
        let close = sample(faceWidth: 0.32)
        XCTAssertEqual(feed(e, close, from: 0, to: 3).distanceLevel, .ok)
        XCTAssertEqual(feed(e, good, from: 3.5, to: 10).distanceLevel, .ok)
        XCTAssertEqual(feed(e, close, from: 10.5, to: 24).distanceLevel, .ok)
        XCTAssertEqual(feed(e, close, from: 24.5, to: 30).distanceLevel, .warning)
        XCTAssertEqual(feed(e, close, from: 30.5, to: 45).distanceLevel, .alarm)
    }

    func testWalkingAwayClearsTheAlert() {
        let e = PostureEngine(baseline: goodBaseline)
        XCTAssertEqual(feed(e, sample(tiltDegrees: 15), from: 0, to: 12).slouchLevel, .warning)
        let out = feed(e, nil, from: 12.5, to: 16)
        XCTAssertFalse(out.personPresent)
        XCTAssertEqual(out.slouchLevel, .ok)
    }

    func testGapInFramesWipesTheTimers() {
        let e = PostureEngine(baseline: goodBaseline)
        let slouched = sample(tiltDegrees: 15)
        XCTAssertEqual(feed(e, slouched, from: 0, to: 7).slouchLevel, .ok)
        // Laptop slept for ten minutes. Still slouched on wake, but the clock starts again.
        XCTAssertEqual(feed(e, slouched, from: 600, to: 605).slouchLevel, .ok)
        XCTAssertEqual(feed(e, slouched, from: 605.5, to: 609).slouchLevel, .warning)
    }

    func testNewBaselineResetsAlerts() {
        let e = PostureEngine(baseline: goodBaseline)
        let leaning = sample(tiltDegrees: 15)
        XCTAssertEqual(feed(e, leaning, from: 0, to: 12).slouchLevel, .warning)
        e.baseline = Baseline.average(of: Array(repeating: PostureMetrics(sample: leaning)!, count: 4))
        XCTAssertEqual(feed(e, leaning, from: 12.5, to: 40).slouchLevel, .ok)
    }
}
