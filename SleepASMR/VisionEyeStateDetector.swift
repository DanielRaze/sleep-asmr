import CoreGraphics
import Vision

final class VisionEyeStateDetector {
    enum EyeState {
        case open
        case closed
        case notDetected
    }

    private let sequenceHandler = VNSequenceRequestHandler()

    func detectEyeState(in pixelBuffer: CVPixelBuffer) -> EyeState {
        let request = VNDetectFaceLandmarksRequest()

        do {
            try sequenceHandler.perform([request], on: pixelBuffer, orientation: .up)
        } catch {
            return .notDetected
        }

        guard let observations = request.results as? [VNFaceObservation],
              let face = observations.first,
              let landmarks = face.landmarks else {
            return .notDetected
        }

        var opennessValues: [CGFloat] = []

        if let leftEye = landmarks.leftEye?.normalizedPoints {
            let value = eyeOpenness(from: leftEye)
            if value > 0 { opennessValues.append(value) }
        }

        if let rightEye = landmarks.rightEye?.normalizedPoints {
            let value = eyeOpenness(from: rightEye)
            if value > 0 { opennessValues.append(value) }
        }

        guard !opennessValues.isEmpty else {
            return .notDetected
        }

        let averageOpenness = opennessValues.reduce(0, +) / CGFloat(opennessValues.count)
        return averageOpenness < 0.18 ? .closed : .open
    }

    private func eyeOpenness(from points: [CGPoint]) -> CGFloat {
        guard points.count >= 6 else { return -1 }

        let minX = points.map(\.x).min() ?? 0
        let maxX = points.map(\.x).max() ?? 0
        let minY = points.map(\.y).min() ?? 0
        let maxY = points.map(\.y).max() ?? 0

        let width = maxX - minX
        let height = maxY - minY

        guard width > 0 else { return -1 }
        return height / width
    }
}
