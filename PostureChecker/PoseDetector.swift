import CoreVideo
import PostureCore
import Vision

enum DetectionIssue: Equatable {
    case noPerson
    case shouldersNotVisible

    var message: String {
        switch self {
        case .noPerson: return "Can't see anyone"
        case .shouldersNotVisible: return "Can't see both shoulders"
        }
    }
}

struct Detection {
    var sample: PoseSample?
    var issue: DetectionIssue?
    /// Frame width divided by height.
    var aspect: Double
}

/// Finds shoulders, head and face in a camera frame using Apple's on-device Vision framework.
/// Use from one queue only.
final class PoseDetector {
    private let bodyRequest = VNDetectHumanBodyPoseRequest()
    private let faceRequest = VNDetectFaceRectanglesRequest()
    private let minimumConfidence: Float = 0.3

    func detect(in buffer: CVPixelBuffer) -> Detection {
        let aspect = Double(CVPixelBufferGetWidth(buffer)) / Double(max(CVPixelBufferGetHeight(buffer), 1))
        let handler = VNImageRequestHandler(cvPixelBuffer: buffer, orientation: .up, options: [:])
        do {
            try handler.perform([bodyRequest, faceRequest])
        } catch {
            return Detection(sample: nil, issue: .noPerson, aspect: aspect)
        }

        let faces = faceRequest.results ?? []
        // With several people in view, take whoever is biggest in the frame.
        let faceWidth = faces.map { Double($0.boundingBox.width) }.max()

        var best: PoseSample?
        var bestWidth = 0.0
        for body in bodyRequest.results ?? [] {
            guard let joints = try? body.recognizedPoints(.all),
                  let left = point(joints[.leftShoulder], aspect: aspect),
                  let right = point(joints[.rightShoulder], aspect: aspect) else { continue }
            let width = abs(left.x - right.x)
            guard width > bestWidth else { continue }
            bestWidth = width

            var head = point(joints[.nose], aspect: aspect)
            if head == nil,
               let leftEar = point(joints[.leftEar], aspect: aspect),
               let rightEar = point(joints[.rightEar], aspect: aspect) {
                head = Point(x: (leftEar.x + rightEar.x) / 2, y: (leftEar.y + rightEar.y) / 2)
            }
            best = PoseSample(shoulderA: left, shoulderB: right, head: head, faceWidthFraction: faceWidth)
        }

        if let best {
            return Detection(sample: best, issue: nil, aspect: aspect)
        }
        let someoneThere = !(bodyRequest.results ?? []).isEmpty || !faces.isEmpty
        return Detection(sample: nil, issue: someoneThere ? .shouldersNotVisible : .noPerson, aspect: aspect)
    }

    /// Vision gives 0...1 on both axes with y up. We stretch x by the aspect ratio so angles are true.
    private func point(_ joint: VNRecognizedPoint?, aspect: Double) -> Point? {
        guard let joint, joint.confidence >= minimumConfidence else { return nil }
        return Point(x: Double(joint.location.x) * aspect, y: Double(joint.location.y))
    }
}
