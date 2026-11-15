import Combine
import Foundation

/// Posture signal the UI renders against. The backend (camera + detection)
/// will eventually publish this; for now `MockPostureSource` drives it so
/// the UI can be built and demoed independently.
enum PostureState: Equatable {
    case good
    case slouching(seconds: TimeInterval)
    case alert
}

protocol PostureSource: AnyObject {
    var statePublisher: AnyPublisher<PostureState, Never> { get }
    /// Stops/resumes monitoring without quitting the app. Settings' "Pause
    /// monitoring" toggle talks directly to this — whatever the real
    /// backend becomes needs this same switch.
    var isPaused: Bool { get set }
    /// Seconds of continuous slouching before `.alert` fires. Settings'
    /// sensitivity slider talks directly to this.
    var slouchThresholdSeconds: TimeInterval { get set }
}

/// Cycles through the states on a timer so the overlay/character work can be
/// built and demoed before the real posture detection backend exists.
final class MockPostureSource: PostureSource, ObservableObject {
    @Published private var state: PostureState = .good

    @Published var isPaused: Bool = UserDefaults.standard.bool(forKey: "monitoringPaused") {
        didSet { UserDefaults.standard.set(isPaused, forKey: "monitoringPaused") }
    }

    @Published var slouchThresholdSeconds: TimeInterval = {
        let stored = UserDefaults.standard.double(forKey: "slouchThresholdSeconds")
        return stored > 0 ? stored : 10
    }() {
        didSet { UserDefaults.standard.set(slouchThresholdSeconds, forKey: "slouchThresholdSeconds") }
    }

    var statePublisher: AnyPublisher<PostureState, Never> {
        $state.eraseToAnyPublisher()
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
        switch state {
        case .good:
            slouchStart = Date()
            state = .slouching(seconds: 0)
        case .slouching(let seconds):
            let elapsed = seconds + 1
            state = elapsed >= slouchThresholdSeconds ? .alert : .slouching(seconds: elapsed)
        case .alert:
            slouchStart = nil
            state = .good
        }
    }
}
