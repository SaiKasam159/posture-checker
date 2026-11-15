import AVFoundation
import Combine
import Foundation
import PostureCore

/// The one object the UI needs. It runs the camera, detection and timing, and publishes the result.
///
/// For the character layer, watch `slouchLevel` and `distanceLevel`:
/// `.ok` means nothing on screen, `.warning` means the character walks on, `.alarm` means it yells.
final class PostureMonitor: ObservableObject {
    enum CalibrationState: Equatable {
        case idle
        case collecting(progress: Double)
        case failed(String)
    }

    let camera = CameraManager()

    @Published private(set) var slouchLevel: AlertLevel = .ok
    @Published private(set) var distanceLevel: AlertLevel = .ok
    @Published private(set) var personPresent = false
    @Published private(set) var assessment: Assessment?
    @Published private(set) var detectionIssue: DetectionIssue?
    /// The latest landmarks, for drawing over the preview.
    @Published private(set) var lastSample: PoseSample?
    @Published private(set) var frameAspect = 4.0 / 3.0

    @Published private(set) var isCalibrated = false
    @Published private(set) var calibration: CalibrationState = .idle
    /// Set after calibrating if the user seems to be sitting very close to the camera.
    @Published private(set) var calibrationNote: String?

    @Published private(set) var isPaused = false
    @Published var sensitivity: Double {
        didSet {
            UserDefaults.standard.set(sensitivity, forKey: Self.sensitivityKey)
            engine.thresholds = Thresholds(sensitivity: sensitivity)
        }
    }

    private let engine = PostureEngine()
    private let detector = PoseDetector()
    private var calibrationSamples: [PostureMetrics] = []
    private var calibrationDeadline: TimeInterval = 0
    private var cancellables: Set<AnyCancellable> = []

    private static let sensitivityKey = "sensitivity"
    private static let calibrationFrames = 6
    private static let calibrationTimeout: TimeInterval = 10

    init() {
        let saved = UserDefaults.standard.double(forKey: Self.sensitivityKey)
        sensitivity = saved > 0 ? saved : 1
        engine.thresholds = Thresholds(sensitivity: sensitivity)

        camera.onFrame = { [weak self, detector] buffer in
            let detection = detector.detect(in: buffer)
            DispatchQueue.main.async { self?.handle(detection) }
        }
        // Each camera sees the user from a different place, so each keeps its own calibration.
        camera.$selectedDeviceID
            .removeDuplicates()
            .sink { [weak self] id in self?.loadBaseline(forCamera: id) }
            .store(in: &cancellables)
        // The menu bar icon reads camera state through this object, so pass its changes on.
        camera.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        camera.start()
    }

    // MARK: Controls

    func startCalibration() {
        calibrationSamples = []
        calibrationNote = nil
        calibrationDeadline = ProcessInfo.processInfo.systemUptime + Self.calibrationTimeout
        calibration = .collecting(progress: 0)
    }

    func setPaused(_ paused: Bool) {
        isPaused = paused
        if paused {
            camera.stop()
            engine.resetTracking()
            calibration = .idle
            slouchLevel = .ok
            distanceLevel = .ok
            personPresent = false
            assessment = nil
            lastSample = nil
            detectionIssue = nil
        } else {
            camera.start()
        }
    }

    // MARK: Frames

    private func handle(_ detection: Detection) {
        guard !isPaused else { return }
        let now = ProcessInfo.processInfo.systemUptime

        frameAspect = detection.aspect
        lastSample = detection.sample
        detectionIssue = detection.issue

        if case .collecting = calibration {
            collectCalibrationFrame(detection, now: now)
        }

        let output = engine.ingest(detection.sample, at: now)
        personPresent = output.personPresent
        assessment = output.assessment
        slouchLevel = output.slouchLevel
        distanceLevel = output.distanceLevel
    }

    private func collectCalibrationFrame(_ detection: Detection, now: TimeInterval) {
        if let sample = detection.sample, let metrics = PostureMetrics(sample: sample), metrics.isUsableForCalibration {
            calibrationSamples.append(metrics)
        }

        if calibrationSamples.count >= Self.calibrationFrames, let baseline = Baseline.average(of: calibrationSamples) {
            engine.baseline = baseline
            isCalibrated = true
            calibration = .idle
            saveBaseline(baseline)
            if let cm = DistanceEstimator.estimateCm(faceWidthFraction: baseline.faceWidthFraction),
               cm < DistanceEstimator.comfortableMinimumCm {
                calibrationNote = "You look close to the camera (roughly \(Int(cm)) cm). If the camera is on your screen, sit at arm's length and recalibrate."
            }
        } else if now > calibrationDeadline {
            let reason: String
            if let issue = detection.issue {
                reason = issue.message
            } else if detection.sample?.head == nil {
                reason = "Can't see your head"
            } else {
                reason = "Can't see your face clearly"
            }
            calibration = .failed("\(reason). Move so your head and both shoulders are in view, then try again.")
        } else {
            calibration = .collecting(progress: Double(calibrationSamples.count) / Double(Self.calibrationFrames))
        }
    }

    // MARK: Saved calibration

    private func baselineKey(_ cameraID: String) -> String { "baseline.\(cameraID)" }

    private func loadBaseline(forCamera id: String?) {
        var baseline: Baseline?
        if let id, let data = UserDefaults.standard.data(forKey: baselineKey(id)) {
            baseline = try? JSONDecoder().decode(Baseline.self, from: data)
        }
        engine.baseline = baseline
        isCalibrated = baseline != nil
        calibration = .idle
        calibrationNote = nil
        slouchLevel = .ok
        distanceLevel = .ok
    }

    private func saveBaseline(_ baseline: Baseline) {
        guard let id = camera.selectedDeviceID, let data = try? JSONEncoder().encode(baseline) else { return }
        UserDefaults.standard.set(data, forKey: baselineKey(id))
    }

    // MARK: Text for the UI

    var menuBarSymbol: String {
        if isPaused { return "pause.circle" }
        if camera.authorization != .authorized || !isCalibrated { return "questionmark.circle" }
        switch max(slouchLevel, distanceLevel) {
        case .ok: return "figure.walk"
        case .warning: return "exclamationmark.triangle"
        case .alarm: return "exclamationmark.triangle.fill"
        }
    }

    var statusText: String {
        if isPaused { return "Paused" }
        switch camera.authorization {
        case .authorized: break
        case .notDetermined: return "Waiting for camera access"
        default: return "Camera access is off"
        }
        if camera.devices.isEmpty { return "No camera found" }
        if case .collecting = calibration { return "Calibrating. Hold still." }
        if let detectionIssue { return detectionIssue.message }
        if !isCalibrated { return "Not calibrated yet" }

        var problems: [String] = []
        if slouchLevel > .ok, let assessment {
            problems.append("Slouching (\(assessment.slouchReason.label))")
        }
        if distanceLevel > .ok {
            problems.append("Too close to the screen")
        }
        if !problems.isEmpty {
            let prefix = max(slouchLevel, distanceLevel) == .alarm ? "Alarm" : "Warning"
            return "\(prefix): " + problems.joined(separator: ", ")
        }

        if let assessment, assessment.isSlouching {
            return "Slouch spotted (\(assessment.slouchReason.label)). Waiting to see if it lasts."
        }
        if let assessment, assessment.isTooClose {
            return "Leaning in. Waiting to see if it lasts."
        }
        return "Posture looks good"
    }
}

extension SlouchReason {
    var label: String {
        switch self {
        case .shouldersTilted: return "shoulders tilted"
        case .headSunk: return "head sunk toward shoulders"
        case .headDropped: return "head dropped"
        }
    }
}
