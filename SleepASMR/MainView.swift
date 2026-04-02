import AVFoundation
import SwiftUI

struct MainView: View {
    @StateObject private var viewModel = MonitoringViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Sleep ASMR")
                .font(.title2.bold())

            CameraPreviewView(session: viewModel.cameraManager.session)
                .frame(height: 260)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(.quaternary, lineWidth: 1)
                }

            Text(viewModel.statusText)
                .font(.headline)

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .font(.subheadline)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Задержка: \(formattedDelay(viewModel.delaySeconds))")
                Slider(value: $viewModel.delaySeconds, in: 30...1800, step: 1)
                HStack {
                    Text("30 сек")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("30 мин")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 8) {
                    Text("Секунды:")
                    TextField("Сек", value: $viewModel.delaySeconds, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 120)
                }
            }

            Toggle("Выключить экран при срабатывании", isOn: $viewModel.shouldSleepDisplayOnTrigger)

            Button(viewModel.isMonitoring ? "Стоп" : "Старт") {
                viewModel.toggleMonitoring()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onChange(of: viewModel.delaySeconds) { _, newValue in
            let clamped = min(max(newValue, 30), 1800)
            if clamped != newValue {
                viewModel.delaySeconds = clamped
            }
        }
    }

    private func formattedDelay(_ seconds: Double) -> String {
        let total = Int(seconds)
        if total < 60 {
            return "\(total) сек"
        }

        let minutes = total / 60
        let sec = total % 60
        if sec == 0 {
            return "\(minutes) мин"
        }
        return "\(minutes) мин \(sec) сек"
    }
}

struct CameraPreviewView: NSViewRepresentable {
    let session: AVCaptureSession

    func makeNSView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        return view
    }

    func updateNSView(_ nsView: PreviewView, context: Context) {
        nsView.previewLayer.session = session
    }
}

final class PreviewView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer = previewLayer
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        previewLayer.frame = bounds
    }

    let previewLayer: AVCaptureVideoPreviewLayer = {
        let layer = AVCaptureVideoPreviewLayer()
        layer.videoGravity = .resizeAspectFill
        return layer
    }()
}
