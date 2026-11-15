import Foundation

/// A tiny greyscale picture of the room, with the person blanked out.
/// Comparing two of these tells us whether the camera moved, as opposed to the person moving.
public struct SceneSignature: Sendable {
    public static let columns = 64
    public static let rows = 48
    static let blockSize = 8

    /// Brightness 0...255 per cell, row by row from the top.
    public var luma: [Float]
    /// True for cells covered by the person. Those are ignored.
    public var masked: [Bool]

    public init(luma: [Float], masked: [Bool]) {
        precondition(luma.count == Self.columns * Self.rows && masked.count == luma.count)
        self.luma = luma
        self.masked = masked
    }

    /// Splits the picture into blocks and returns the share of them that no longer match, 0...1.
    ///
    /// Each block is compared by pattern, not brightness, so lights and auto-exposure don't count.
    /// Voting by block means a TV or someone walking past changes a few blocks, while moving the
    /// camera changes nearly all of them. Blank areas (a plain wall) can't vote.
    /// Returns nil when there isn't enough visible, textured background to judge.
    public static func changedFraction(_ a: SceneSignature, _ b: SceneSignature) -> Double? {
        let bs = blockSize
        // Brightness variance below this is treated as a blank surface.
        let flatVariance = 16.0
        var informative = 0
        var changed = 0

        for by in 0..<(rows / bs) {
            for bx in 0..<(columns / bs) {
                var n = 0.0, sa = 0.0, sb = 0.0, saa = 0.0, sbb = 0.0, sab = 0.0
                for y in (by * bs)..<((by + 1) * bs) {
                    for x in (bx * bs)..<((bx + 1) * bs) {
                        let i = y * columns + x
                        if a.masked[i] || b.masked[i] { continue }
                        let va = Double(a.luma[i]), vb = Double(b.luma[i])
                        n += 1
                        sa += va; sb += vb
                        saa += va * va; sbb += vb * vb; sab += va * vb
                    }
                }
                guard n >= Double(bs * bs) / 2 else { continue }
                let varA = saa / n - (sa / n) * (sa / n)
                let varB = sbb / n - (sb / n) * (sb / n)

                if varA < flatVariance || varB < flatVariance {
                    // Blank in both: nothing to compare. Blank in one and clearly textured in the other: changed.
                    if max(varA, varB) >= flatVariance * 2 {
                        informative += 1
                        changed += 1
                    }
                    continue
                }
                informative += 1
                let correlation = (sab / n - (sa / n) * (sb / n)) / (varA * varB).squareRoot()
                if correlation < 0.5 { changed += 1 }
            }
        }
        guard informative >= 6 else { return nil }
        return Double(changed) / Double(informative)
    }
}

/// Watches the background and reports when the camera has been moved to a new spot and left there.
public struct CameraMoveDetector: Sendable {
    /// At least this share of the background must change to count as a move.
    public var movedFraction = 0.6
    /// At or below this share, the scene is the same one we remembered.
    public var sameFraction = 0.3
    /// Frame-to-frame change at or below this means the camera has stopped moving.
    public var settledFraction = 0.2
    /// How long the new view must hold still before we accept it.
    public var settleTime: TimeInterval = 2
    /// How often the remembered scene is refreshed, so slow lighting changes don't add up.
    public var refreshInterval: TimeInterval = 20
    /// Alerts are held back for at most this long after the scene starts to differ.
    public var maxSuspension: TimeInterval = 6

    private var reference: SceneSignature?
    private var referenceTime: TimeInterval = 0
    private var previous: SceneSignature?
    private var differentSince: TimeInterval?
    private var settledSince: TimeInterval?

    public init() {}

    /// Forget the remembered scene. The next frame becomes the new reference.
    public mutating func reset() {
        reference = nil
        previous = nil
        differentSince = nil
        settledSince = nil
    }

    /// True while the view has recently changed and posture readings can't be trusted yet.
    public func isSuspended(at time: TimeInterval) -> Bool {
        guard let differentSince else { return false }
        return time - differentSince < maxSuspension
    }

    /// Returns true once, when the camera has moved and settled in a new position.
    public mutating func update(_ signature: SceneSignature, at time: TimeInterval) -> Bool {
        defer { previous = signature }
        guard let reference else {
            self.reference = signature
            referenceTime = time
            return false
        }

        guard let versusReference = SceneSignature.changedFraction(signature, reference) else {
            differentSince = nil
            settledSince = nil
            return false
        }
        if versusReference <= sameFraction {
            differentSince = nil
            settledSince = nil
            if time - referenceTime >= refreshInterval {
                self.reference = signature
                referenceTime = time
            }
            return false
        }
        // In between: not clearly the same, not clearly moved. Wait for a clearer frame.
        guard versusReference >= movedFraction else { return false }

        if differentSince == nil { differentSince = time }

        if let previous, let versusPrevious = SceneSignature.changedFraction(signature, previous),
           versusPrevious <= settledFraction {
            if settledSince == nil { settledSince = time }
        } else {
            settledSince = nil
        }

        if let settledSince, time - settledSince >= settleTime {
            self.reference = signature
            referenceTime = time
            differentSince = nil
            self.settledSince = nil
            return true
        }
        return false
    }
}
