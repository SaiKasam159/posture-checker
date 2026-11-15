import Combine
import PostureCore

/// `PostureMonitor` already has everything `PostureSource` needs
/// (`isPaused`/`setPaused`, `sensitivity`) — this just adds the one thing
/// the UI layer wants that the backend doesn't otherwise expose: a single
/// combined `PostureState` instead of separate `slouchLevel`/`distanceLevel`.
extension PostureMonitor: PostureSource {
    var statePublisher: AnyPublisher<PostureState, Never> {
        Publishers.CombineLatest($slouchLevel, $distanceLevel)
            .map { slouch, distance in
                switch max(slouch, distance) {
                case .ok: return PostureState.good
                case .warning: return .slouching(seconds: 0)
                case .alarm: return .alert
                }
            }
            .eraseToAnyPublisher()
    }
}
