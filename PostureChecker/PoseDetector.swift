import CoreVideo
import PostureCore
import Vision

/// Where the person is in the frame, as fractions of the frame (x from the left, y from the bottom).
/// Everything between `minX` and `maxX`, from `top` down to the bottom edge, is treated as "person".
struct PersonRegion {
    var minX: Double
    var maxX: Double
    var top: Double
}

struct Detection {
    /// Nil when neither a face nor shoulders were found.
    var sample: PoseSample?
    var person: PersonRegion?
    /// Frame width divided by height.
    var aspect: Double
}

/// Finds the face and shoulders in a camera frame using Apple's on-device Vision framework.
/// Use from one queue only.
final class PoseDetector {
    private let bodyRequest = VNDetectHumanBodyPoseRequest()
    private let faceRequest = VNDetectFaceRectanglesRequest()

    func detect(in buffer: CVPixelBuffer) -> Detection {
        let aspect = Double(CVPixelBufferGetWidth(buffer)) / Double(max(CVPixelBufferGetHeight(buffer), 1))
        let handler = VNImageRequestHandler(cvPixelBuffer: buffer, orientation: .up, options: [:])
        do {
            try handler.perform([bodyRequest, faceRequest])
        } catch {
            return Detection(sample: nil, person: nil, aspect: aspect)
        }

        // With several people in view, take whoever is biggest in the frame.
        let faceBox = (faceRequest.results ?? []).map(\.boundingBox).max { $0.width < $1.width }
        let face = faceBox.map {
            Face(center: Point(x: Double($0.midX) * aspect, y: Double($0.midY)), width: Double($0.width) * aspect)
        }

        // Loose clothing makes Vision less sure about shoulders. When a face confirms where the
        // shoulders ought to be we accept weaker guesses; without one we stay strict.
        let minimumConfidence: Float = face == nil ? 0.3 : 0.15
        var shoulders: Shoulders?
        var widest = 0.0
        for body in bodyRequest.results ?? [] {
            guard let joints = try? body.recognizedPoints(.all),
                  let left = point(joints[.leftShoulder], aspect: aspect, minimumConfidence: minimumConfidence),
                  let right = point(joints[.rightShoulder], aspect: aspect, minimumConfidence: minimumConfidence) else { continue }
            let width = abs(left.x - right.x)
            guard width > widest, isPlausible(left, right, under: face) else { continue }
            widest = width
            shoulders = Shoulders(a: left, b: right)
        }

        guard face != nil || shoulders != nil else {
            return Detection(sample: nil, person: nil, aspect: aspect)
        }
        return Detection(
            sample: PoseSample(face: face, shoulders: shoulders, frameAspect: aspect),
            person: personRegion(faceBox: faceBox, shoulders: shoulders, aspect: aspect),
            aspect: aspect
        )
    }

    /// Vision gives 0...1 on both axes with y up. We stretch x by the aspect ratio so angles are true.
    private func point(_ joint: VNRecognizedPoint?, aspect: Double, minimumConfidence: Float) -> Point? {
        guard let joint, joint.confidence >= minimumConfidence else { return nil }
        return Point(x: Double(joint.location.x) * aspect, y: Double(joint.location.y))
    }

    /// Rejects shoulder guesses that can't belong to this face: above it, off to one side, or the wrong size.
    private func isPlausible(_ left: Point, _ right: Point, under face: Face?) -> Bool {
        guard let face else { return true }
        let width = abs(left.x - right.x)
        let minX = min(left.x, right.x), maxX = max(left.x, right.x)
        return left.y < face.center.y && right.y < face.center.y
            && width > face.width * 1.2 && width < face.width * 5
            && face.center.x > minX - width * 0.3 && face.center.x < maxX + width * 0.3
    }

    /// A generous outline of the person, used to ignore them when looking at the background.
    private func personRegion(faceBox: CGRect?, shoulders: Shoulders?, aspect: Double) -> PersonRegion {
        var minX = 1.0, maxX = 0.0, top = 0.0
        if let faceBox {
            // Shoulders are usually a little under three face widths across.
            minX = Double(faceBox.midX) - Double(faceBox.width) * 1.8
            maxX = Double(faceBox.midX) + Double(faceBox.width) * 1.8
            top = Double(faceBox.maxY) + Double(faceBox.height) * 0.5
        }
        if let shoulders {
            let a = shoulders.a.x / aspect, b = shoulders.b.x / aspect
            let width = abs(a - b)
            minX = min(minX, min(a, b) - width * 0.25)
            maxX = max(maxX, max(a, b) + width * 0.25)
            if faceBox == nil {
                top = max(shoulders.a.y, shoulders.b.y) + abs(shoulders.a.x - shoulders.b.x) * 0.9
            }
        }
        return PersonRegion(minX: minX, maxX: maxX, top: top)
    }
}
