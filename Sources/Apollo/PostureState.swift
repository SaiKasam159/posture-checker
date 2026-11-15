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
}

/// Cycles through the states on a timer so the overlay/character work can be
/// built and demoed before the real posture detection backend exists.
final class MockPostureSource: PostureSource, ObservableObject {
    @Published private var state: PostureState = .good
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
        switch state {
        case .good:
            slouchStart = Date()
            state = .slouching(seconds: 0)
        case .slouching(let seconds):
            let elapsed = seconds + 1
            state = elapsed >= 10 ? .alert : .slouching(seconds: elapsed)
        case .alert:
            slouchStart = nil
            state = .good
        }
    }
}
