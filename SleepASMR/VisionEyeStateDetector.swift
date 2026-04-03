import CoreGraphics
import Vision

final class VisionEyeStateDetector {
    enum EyeState {
        case open
        case closed
        case notDetected
    }

    private let sequenceHandler = VNSequenceRequestHandler()
    private var smoothedOpenness: CGFloat?
    private var previousState: EyeState = .notDetected

    // Гистерезис снижает ложные переключения при щуре.
    private let closedThreshold: CGFloat = 0.115
    private let openThreshold: CGFloat = 0.155
    private let smoothingAlpha: CGFloat = 0.28

    func detectEyeState(in pixelBuffer: CVPixelBuffer) -> EyeState {
        let request = VNDetectFaceLandmarksRequest()

        do {
            try sequenceHandler.perform([request], on: pixelBuffer, orientation: .up)
        } catch {
            previousState = .notDetected
            return .notDetected
        }

        guard let observations = request.results as? [VNFaceObservation],
              let face = observations.first,
              let landmarks = face.landmarks else {
                        previousState = .notDetected
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
            previousState = .notDetected
            return .notDetected
        }

        let averageOpenness = opennessValues.reduce(0, +) / CGFloat(opennessValues.count)
        let smooth: CGFloat
        if let prev = smoothedOpenness {
            smooth = prev + smoothingAlpha * (averageOpenness - prev)
        } else {
            smooth = averageOpenness
        }
        smoothedOpenness = smooth

        let state: EyeState
        switch previousState {
        case .closed:
            state = smooth >= openThreshold ? .open : .closed
        case .open:
            state = smooth <= closedThreshold ? .closed : .open
        case .notDetected:
            state = smooth <= closedThreshold ? .closed : .open
        }

        previousState = state
        return state
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
