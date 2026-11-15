import CoreVideo
import PostureCore

/// Shrinks a camera frame down to the small greyscale grid that `CameraMoveDetector` compares.
enum SceneSampler {
    /// Returns nil if the frame isn't in the brightness-plus-colour layout we ask the camera for.
    static func signature(from buffer: CVPixelBuffer, person: PersonRegion?) -> SceneSignature? {
        let format = CVPixelBufferGetPixelFormatType(buffer)
        guard format == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
            || format == kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange else { return nil }

        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        // Plane 0 is brightness, one byte per pixel.
        guard let base = CVPixelBufferGetBaseAddressOfPlane(buffer, 0) else { return nil }
        let width = CVPixelBufferGetWidthOfPlane(buffer, 0)
        let height = CVPixelBufferGetHeightOfPlane(buffer, 0)
        let stride = CVPixelBufferGetBytesPerRowOfPlane(buffer, 0)
        let pixels = base.assumingMemoryBound(to: UInt8.self)

        let columns = SceneSignature.columns, rows = SceneSignature.rows
        // Each cell is the average of a 5x5 spread of pixels, which irons out sensor noise.
        let taps = 5
        guard width >= columns * taps, height >= rows * taps else { return nil }

        var luma = [Float](repeating: 0, count: columns * rows)
        var masked = [Bool](repeating: false, count: columns * rows)
        for gy in 0..<rows {
            // Row 0 of the grid is the top of the picture; `PersonRegion` measures from the bottom.
            let yFromBottom = 1 - (Double(gy) + 0.5) / Double(rows)
            for gx in 0..<columns {
                var sum = 0
                for ty in 0..<taps {
                    let py = (gy * taps + ty) * height / (rows * taps)
                    for tx in 0..<taps {
                        let px = (gx * taps + tx) * width / (columns * taps)
                        sum += Int(pixels[py * stride + px])
                    }
                }
                let i = gy * columns + gx
                luma[i] = Float(sum) / Float(taps * taps)
                if let person {
                    let x = (Double(gx) + 0.5) / Double(columns)
                    masked[i] = x >= person.minX && x <= person.maxX && yFromBottom <= person.top
                }
            }
        }
        return SceneSignature(luma: luma, masked: masked)
    }
}
