import XCTest
@testable import PostureCore

private let aspect = 4.0 / 3.0

/// A person sitting well: level shoulders 0.6 apart, face centre 0.24 above them, face a fifth of the frame wide.
/// `faceWidth` is a fraction of the frame width. Pass nil to hide the face, `shoulders: false` for a hoodie.
private func sample(
    tiltDegrees: Double = 0,
    headAboveShoulders: Double = 0.24,
    shoulderY: Double = 0.4,
    faceWidth: Double? = 0.2,
    shoulders: Bool = true
) -> PoseSample {
    let half = 0.3
    let rad = tiltDegrees * .pi / 180
    let centre = Point(x: 0.66, y: shoulderY)
    return PoseSample(
        face: faceWidth.map { Face(center: Point(x: centre.x, y: shoulderY + headAboveShoulders), width: $0 * aspect) },
        shoulders: shoulders ? Shoulders(
            a: Point(x: centre.x - half * cos(rad), y: centre.y - half * sin(rad)),
            b: Point(x: centre.x + half * cos(rad), y: centre.y + half * sin(rad))
        ) : nil,
        frameAspect: aspect
    )
}

private func baseline(from s: PoseSample) -> Baseline {
    Baseline.average(of: Array(repeating: PostureMetrics(sample: s)!, count: 4))!
}

private let good = sample()
private let goodBaseline = baseline(from: good)

final class MetricsTests: XCTestCase {
    func testLevelShouldersHaveZeroTilt() {
        let m = PostureMetrics(sample: good)!
        XCTAssertEqual(m.shoulderTiltDegrees!, 0, accuracy: 1e-9)
        XCTAssertEqual(m.neckRatio!, 0.4, accuracy: 1e-9)
        XCTAssertEqual(m.faceWidthFraction!, 0.2, accuracy: 1e-9)
    }

    func testTiltIsMeasuredAndIgnoresShoulderOrder() {
        let s = sample(tiltDegrees: 12)
        var swapped = s
        swapped.shoulders = Shoulders(a: s.shoulders!.b, b: s.shoulders!.a)
        XCTAssertEqual(PostureMetrics(sample: s)!.shoulderTiltDegrees!, 12, accuracy: 1e-9)
        XCTAssertEqual(PostureMetrics(sample: swapped)!.shoulderTiltDegrees!, 12, accuracy: 1e-9)
    }

    func testFaceAloneIsEnough() {
        let m = PostureMetrics(sample: sample(shoulders: false))!
        XCTAssertNotNil(m.headY)
        XCTAssertNil(m.shoulderTiltDegrees)
        XCTAssertNil(m.neckRatio)
    }

    func testNothingVisibleOrJunkShouldersAreRejected() {
        XCTAssertNil(PostureMetrics(sample: sample(faceWidth: nil, shoulders: false)))
        let p = Point(x: 0.5, y: 0.5)
        XCTAssertNil(PostureMetrics(sample: PoseSample(face: nil, shoulders: Shoulders(a: p, b: p), frameAspect: aspect)))
    }
}

final class BaselineTests: XCTestCase {
    func testNeedsEnoughFramesWithAFace() {
        let complete = PostureMetrics(sample: good)!
        let noFace = PostureMetrics(sample: sample(faceWidth: nil))!
        XCTAssertNil(Baseline.average(of: [complete, complete, complete, noFace, noFace]))
        XCTAssertNotNil(Baseline.average(of: [complete, complete, complete, complete, noFace]))
    }

    func testAveragesFrames() {
        let a = PostureMetrics(sample: sample(tiltDegrees: 2))!
        let b = PostureMetrics(sample: sample(tiltDegrees: 4))!
        XCTAssertEqual(Baseline.average(of: [a, b, a, b])!.shoulderTiltDegrees!, 3, accuracy: 1e-9)
    }

    func testCalibratesWithoutShoulders() {
        let b = baseline(from: sample(shoulders: false))
        XCTAssertNil(b.shoulderTiltDegrees)
        XCTAssertNil(b.neckRatio)
        XCTAssertEqual(b.headY, 0.64, accuracy: 1e-9)
    }

    func testShouldersSeenInOnlyAFewFramesAreNotTrusted() {
        let with = PostureMetrics(sample: good)!
        let without = PostureMetrics(sample: sample(shoulders: false))!
        XCTAssertNil(Baseline.average(of: [with, without, without, without, without])!.shoulderTiltDegrees)
        XCTAssertNotNil(Baseline.average(of: [with, with, without, without])!.shoulderTiltDegrees)
    }
}

final class AssessmentTests: XCTestCase {
    private func assess(_ s: PoseSample, against b: Baseline = goodBaseline, sensitivity: Double = 1) -> Assessment {
        Assessment.assess(PostureMetrics(sample: s)!, against: b, thresholds: Thresholds(sensitivity: sensitivity))
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
        XCTAssertEqual(a.shoulderTiltChangeDegrees!, -10, accuracy: 1e-9)
    }

    func testHeadSinkingTowardShouldersCountsAsSlouching() {
        // Head 25% lower relative to the shoulders, shoulders unmoved.
        let a = assess(sample(headAboveShoulders: 0.18))
        XCTAssertTrue(a.isSlouching)
        XCTAssertEqual(a.slouchReason, .headSunk)
    }

    func testWholeUpperBodyDroppingCountsAsSlouching() {
        XCTAssertFalse(assess(sample(shoulderY: 0.34)).isSlouching)
        let a = assess(sample(shoulderY: 0.22))
        XCTAssertTrue(a.isSlouching)
        XCTAssertEqual(a.slouchReason, .headDropped)
    }

    func testSittingTallerIsNotSlouching() {
        XCTAssertFalse(assess(sample(headAboveShoulders: 0.3, shoulderY: 0.45)).isSlouching)
    }

    func testHoodieHidingShouldersStillCatchesTheHeadDropping() {
        let a = assess(sample(shoulderY: 0.22, shoulders: false))
        XCTAssertTrue(a.isSlouching)
        XCTAssertEqual(a.slouchReason, .headDropped)
        XCTAssertNil(a.shoulderTiltChangeDegrees)
        XCTAssertFalse(assess(sample(shoulders: false)).isSlouching)
    }

    func testCalibratedWithoutShouldersIgnoresThemLater() {
        let headOnly = baseline(from: sample(shoulders: false))
        XCTAssertFalse(assess(sample(tiltDegrees: 20), against: headOnly).isSlouching)
        XCTAssertTrue(assess(sample(shoulderY: 0.22), against: headOnly).isSlouching)
        XCTAssertTrue(assess(sample(faceWidth: 0.3), against: headOnly).isTooClose)
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
        e.baseline = baseline(from: leaning)
        XCTAssertEqual(feed(e, leaning, from: 12.5, to: 40).slouchLevel, .ok)
    }
}

// MARK: Camera move detection

/// Small repeatable random source so the fake rooms are the same on every run.
private struct Dice {
    var state: UInt64
    mutating func next() -> Float {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return Float((state >> 33) % 256)
    }
}

private let cols = SceneSignature.columns, rows = SceneSignature.rows

/// A room full of detail: every cell a different brightness.
private func room(seed: UInt64) -> [Float] {
    var dice = Dice(state: seed)
    return (0..<(cols * rows)).map { _ in dice.next() }
}

/// Blanks out a person-shaped column: from `top` down to the bottom, between two columns.
private func scene(_ luma: [Float], personColumns: Range<Int>? = 26..<38, top: Int = 12) -> SceneSignature {
    var masked = [Bool](repeating: false, count: luma.count)
    if let personColumns {
        for y in top..<rows { for x in personColumns { masked[y * cols + x] = true } }
    }
    return SceneSignature(luma: luma, masked: masked)
}

private func shifted(_ luma: [Float], by dx: Int) -> [Float] {
    (0..<luma.count).map { i in
        let x = i % cols, y = i / cols
        return luma[y * cols + (x + dx + cols) % cols]
    }
}

final class SceneSignatureTests: XCTestCase {
    func testSameRoomUnderDifferentLightAndNoiseIsUnchanged() {
        let a = room(seed: 1)
        var dice = Dice(state: 99)
        let dimmerAndNoisy = a.map { $0 * 0.7 + 20 + (dice.next() / 255 - 0.5) * 8 }
        XCTAssertLessThanOrEqual(SceneSignature.changedFraction(scene(a), scene(dimmerAndNoisy))!, 0.05)
    }

    func testMovedCameraChangesNearlyEverything() {
        let a = room(seed: 1)
        XCTAssertGreaterThanOrEqual(SceneSignature.changedFraction(scene(a), scene(shifted(a, by: 4)))!, 0.9)
        XCTAssertGreaterThanOrEqual(SceneSignature.changedFraction(scene(a), scene(room(seed: 2)))!, 0.9)
    }

    func testSomethingChangingInOneCornerIsNotAMove() {
        let a = room(seed: 1)
        var tv = a
        var dice = Dice(state: 7)
        for y in 0..<16 { for x in 0..<16 { tv[y * cols + x] = dice.next() } }
        let fraction = SceneSignature.changedFraction(scene(a), scene(tv))!
        XCTAssertGreaterThan(fraction, 0)
        XCTAssertLessThan(fraction, 0.3)
    }

    func testPersonMovingAroundIsNotAMove() {
        let a = room(seed: 1)
        // The person leans left and sinks: a different part of the room is hidden, but the room is the same.
        var leaned = scene(a, personColumns: 18..<32, top: 20)
        for i in 0..<leaned.luma.count where leaned.masked[i] { leaned.luma[i] = 128 }
        XCTAssertLessThanOrEqual(SceneSignature.changedFraction(scene(a), leaned)!, 0.05)
    }

    func testBlankWallGivesNoAnswer() {
        let wall = [Float](repeating: 180, count: cols * rows)
        XCTAssertNil(SceneSignature.changedFraction(scene(wall), scene(wall.map { $0 + 3 })))
    }
}

final class CameraMoveDetectorTests: XCTestCase {
    /// Feeds the same picture at two frames a second and reports whether a move was announced.
    private func hold(_ d: inout CameraMoveDetector, _ s: SceneSignature, from start: Double, to end: Double) -> Int {
        var fired = 0
        var time = start
        while time <= end {
            if d.update(s, at: time) { fired += 1 }
            time += 0.5
        }
        return fired
    }

    func testSteadyCameraNeverFires() {
        var d = CameraMoveDetector()
        XCTAssertEqual(hold(&d, scene(room(seed: 1)), from: 0, to: 120), 0)
        XCTAssertFalse(d.isSuspended(at: 120))
    }

    func testMoveFiresOnceAfterTheNewViewSettles() {
        var d = CameraMoveDetector()
        let before = scene(room(seed: 1)), after = scene(room(seed: 2))
        _ = hold(&d, before, from: 0, to: 10)
        XCTAssertEqual(hold(&d, after, from: 10.5, to: 12), 0, "still settling")
        XCTAssertTrue(d.isSuspended(at: 12))
        XCTAssertEqual(hold(&d, after, from: 12.5, to: 14), 1)
        XCTAssertFalse(d.isSuspended(at: 14))
        XCTAssertEqual(hold(&d, after, from: 14.5, to: 60), 0)
    }

    func testBriefDisturbanceDoesNotFire() {
        var d = CameraMoveDetector()
        let before = scene(room(seed: 1))
        _ = hold(&d, before, from: 0, to: 10)
        XCTAssertEqual(hold(&d, scene(room(seed: 2)), from: 10.5, to: 11), 0)
        XCTAssertEqual(hold(&d, before, from: 11.5, to: 30), 0)
        XCTAssertFalse(d.isSuspended(at: 12))
    }

    func testCameraStillBeingCarriedDoesNotFireAndStopsHoldingAlertsBack() {
        var d = CameraMoveDetector()
        _ = hold(&d, scene(room(seed: 1)), from: 0, to: 10)
        var fired = 0
        var time = 10.5, seed: UInt64 = 100
        while time <= 40 {
            if d.update(scene(room(seed: seed)), at: time) { fired += 1 }
            seed += 1
            time += 0.5
        }
        XCTAssertEqual(fired, 0)
        XCTAssertTrue(d.isSuspended(at: 13))
        XCTAssertFalse(d.isSuspended(at: 40))
    }

    func testMoveWhileNobodyIsThereStillFires() {
        var d = CameraMoveDetector()
        _ = hold(&d, scene(room(seed: 1)), from: 0, to: 10)
        XCTAssertEqual(hold(&d, scene(room(seed: 2), personColumns: nil), from: 10.5, to: 15), 1)
    }
}
