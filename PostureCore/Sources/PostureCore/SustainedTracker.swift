import Foundation

/// What the UI should be doing. `warning` is "character walks on", `alarm` is "character yells".
public enum AlertLevel: Int, Comparable, Sendable {
    case ok
    case warning
    case alarm

    public static func < (lhs: AlertLevel, rhs: AlertLevel) -> Bool { lhs.rawValue < rhs.rawValue }
}

/// Turns a flickering "bad right now" signal into a steady alert level.
/// A problem has to last before it counts, and a short break doesn't restart the clock.
public struct SustainedTracker: Sendable {
    public struct Timing: Equatable, Sendable {
        /// How long the problem must last before the warning.
        public var warnAfter: TimeInterval
        /// How long the warning is ignored before it becomes an alarm.
        public var alarmAfter: TimeInterval
        /// Breaks shorter than this don't reset the countdown to the warning.
        public var lapseTolerance: TimeInterval
        /// How long the user must be back to good before the alert clears.
        public var recoverAfter: TimeInterval

        public init(warnAfter: TimeInterval, alarmAfter: TimeInterval, lapseTolerance: TimeInterval, recoverAfter: TimeInterval) {
            self.warnAfter = warnAfter
            self.alarmAfter = alarmAfter
            self.lapseTolerance = lapseTolerance
            self.recoverAfter = recoverAfter
        }

        public static let slouch = Timing(warnAfter: 8, alarmAfter: 12, lapseTolerance: 1.5, recoverAfter: 2)
        /// Longer fuse than slouching, so leaning in to read something for a few seconds is ignored.
        public static let distance = Timing(warnAfter: 15, alarmAfter: 15, lapseTolerance: 2, recoverAfter: 2)
    }

    public var timing: Timing
    public private(set) var level: AlertLevel = .ok

    private var badSince: TimeInterval?
    private var lastBad: TimeInterval?
    private var goodSince: TimeInterval?
    private var warningSince: TimeInterval?

    public init(timing: Timing) {
        self.timing = timing
    }

    public mutating func reset() {
        level = .ok
        badSince = nil
        lastBad = nil
        goodSince = nil
        warningSince = nil
    }

    @discardableResult
    public mutating func update(isBad: Bool, at time: TimeInterval) -> AlertLevel {
        if isBad {
            goodSince = nil
            if badSince == nil { badSince = time }
            lastBad = time
        } else if goodSince == nil {
            goodSince = time
        }

        switch level {
        case .ok:
            if !isBad, let lastBad, time - lastBad > timing.lapseTolerance {
                badSince = nil
                self.lastBad = nil
            }
            if isBad, let badSince, time - badSince >= timing.warnAfter {
                level = .warning
                warningSince = time
            }
        case .warning, .alarm:
            if let goodSince, time - goodSince >= timing.recoverAfter {
                reset()
            } else if level == .warning, isBad, let warningSince, time - warningSince >= timing.alarmAfter {
                level = .alarm
            }
        }
        return level
    }
}
