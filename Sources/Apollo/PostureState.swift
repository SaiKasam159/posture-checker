import Combine
import Foundation

/// Posture signal the UI renders against. `PostureMonitor` (the real
/// backend, in PostureMonitor.swift/PostureMonitorAdapter.swift) and
/// `MockPostureSource` (for UI-only iteration without a camera) both
/// publish this.
enum PostureState: Equatable {
    case good
    case slouching(seconds: TimeInterval)
    case alert
}

/// Shaped to match the real `PostureMonitor`'s actual API (see
/// PostureMonitorAdapter.swift) rather than the other way around —
/// `isPaused` is read-only with a `setPaused` method, and `sensitivity`
/// is the backend's real continuous knob (not "seconds"), because that's
/// what the production object already looks like.
protocol PostureSource: AnyObject {
    var statePublisher: AnyPublisher<PostureState, Never> { get }
    var isPaused: Bool { get }
    func setPaused(_ paused: Bool)
    /// Backend's scale: 1 is default, higher reacts to smaller movements,
    /// lower is more forgiving. See `Thresholds(sensitivity:)` in PostureCore.
    var sensitivity: Double { get set }
}

/// Cycles through the states on a timer so the overlay/character work can be
/// built and demoed without a camera. Not used by `AppDelegate` by default
/// anymore (the real `PostureMonitor` is), but kept for pure UI iteration —
/// swap it back in in `AppDelegate.setUpOverlay()` if you need to work on
/// the UI without a working camera pipeline.
final class MockPostureSource: PostureSource, ObservableObject {
    @Published private var state: PostureState = .good

    @Published private(set) var isPaused: Bool = UserDefaults.standard.bool(forKey: "monitoringPaused") {
        didSet { UserDefaults.standard.set(isPaused, forKey: "monitoringPaused") }
    }

    @Published var sensitivity: Double = {
        let stored = UserDefaults.standard.double(forKey: "mockSensitivity")
        return stored > 0 ? stored : 1
    }() {
        didSet { UserDefaults.standard.set(sensitivity, forKey: "mockSensitivity") }
    }

    var statePublisher: AnyPublisher<PostureState, Never> {
        $state.eraseToAnyPublisher()
    }

    func setPaused(_ paused: Bool) {
        isPaused = paused
    }

    private var timer: Timer?
    private var slouchStart: Date?

    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        guard !isPaused else { return }
        let threshold = 10 / sensitivity.clamped(to: 0.25...4)
        switch state {
        case .good:
            slouchStart = Date()
            state = .slouching(seconds: 0)
        case .slouching(let seconds):
            let elapsed = seconds + 1
            state = elapsed >= threshold ? .alert : .slouching(seconds: elapsed)
        case .alert:
            slouchStart = nil
            state = .good
        }
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
