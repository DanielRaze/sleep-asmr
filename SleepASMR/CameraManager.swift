import AVFoundation
import Foundation

final class CameraManager: NSObject {
    enum CameraError: Error, LocalizedError {
        case accessDenied
        case cameraUnavailable
        case inputConfigurationFailed
        case outputConfigurationFailed

        var errorDescription: String? {
            switch self {
            case .accessDenied:
                return "Доступ к камере запрещен. Разрешите его в System Settings -> Privacy & Security -> Camera."
            case .cameraUnavailable:
                return "Камера недоступна. Проверьте, что FaceTime HD камера подключена и не занята другим приложением."
            case .inputConfigurationFailed:
                return "Не удалось настроить вход камеры."
            case .outputConfigurationFailed:
                return "Не удалось настроить видеопоток камеры."
            }
        }
    }

    let session = AVCaptureSession()
    var onFrame: ((CVPixelBuffer) -> Void)?

    private let sessionQueue = DispatchQueue(label: "sleepasmr.camera.session")
    private let outputQueue = DispatchQueue(label: "sleepasmr.camera.output")
    private let videoOutput = AVCaptureVideoDataOutput()
    private var isConfigured = false

    func requestAccessAndConfigure(completion: @escaping (Result<Void, CameraError>) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureIfNeeded(completion: completion)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                guard let self else { return }
                if granted {
                    self.configureIfNeeded(completion: completion)
                } else {
                    completion(.failure(.accessDenied))
                }
            }
        default:
            completion(.failure(.accessDenied))
        }
    }

    func startSession() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            guard self.isConfigured else { return }
            guard !self.session.isRunning else { return }
            self.session.startRunning()
        }
    }

    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            guard self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    private func configureIfNeeded(completion: @escaping (Result<Void, CameraError>) -> Void) {
        sessionQueue.async { [weak self] in
            guard let self else { return }

            if self.isConfigured {
                completion(.success(()))
                return
            }

            self.session.beginConfiguration()
            self.session.sessionPreset = .medium

            defer {
                self.session.commitConfiguration()
            }

            guard let camera = AVCaptureDevice.default(for: .video) else {
                completion(.failure(.cameraUnavailable))
                return
            }

            do {
                let input = try AVCaptureDeviceInput(device: camera)
                if self.session.canAddInput(input) {
                    self.session.addInput(input)
                } else {
                    completion(.failure(.inputConfigurationFailed))
                    return
                }
            } catch {
                completion(.failure(.inputConfigurationFailed))
                return
            }

            self.videoOutput.alwaysDiscardsLateVideoFrames = true
            self.videoOutput.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
            ]
            self.videoOutput.setSampleBufferDelegate(self, queue: self.outputQueue)

            guard self.session.canAddOutput(self.videoOutput) else {
                completion(.failure(.outputConfigurationFailed))
                return
            }

            self.session.addOutput(self.videoOutput)
            self.isConfigured = true
            completion(.success(()))
        }
    }
}

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        onFrame?(pixelBuffer)
    }
}
