import AVFoundation
import SwiftUI

struct MainView: View {
    @StateObject private var viewModel = MonitoringViewModel()

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.11, blue: 0.17),
                    Color(red: 0.05, green: 0.09, blue: 0.13)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .center, spacing: 12) {
                    Circle()
                        .fill(.white.opacity(0.08))
                        .frame(width: 40, height: 40)
                        .overlay {
                            Image(systemName: "eye.circle.fill")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(Color(red: 0.55, green: 0.84, blue: 0.98))
                        }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Sleep ASMR")
                            .font(.system(size: 27, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("Мониторинг закрытия глаз")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.75))
                    }
                }

                CameraPreviewView(session: viewModel.cameraManager.session)
                    .frame(height: 250)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(.white.opacity(0.12), lineWidth: 1)
                    }
                    .shadow(color: .black.opacity(0.35), radius: 12, x: 0, y: 8)

                VStack(alignment: .leading, spacing: 8) {
                    Text(viewModel.statusText)
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)

                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .foregroundStyle(Color(red: 1.0, green: 0.58, blue: 0.58))
                            .font(.subheadline)
                    }
                }
                .padding(14)
                .background(.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 10) {
                    Text("Задержка: \(formattedDelay(viewModel.delaySeconds))")
                        .foregroundStyle(.white)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))

                    Slider(value: $viewModel.delaySeconds, in: 30...1800, step: 1)
                        .tint(Color(red: 0.55, green: 0.84, blue: 0.98))

                    HStack {
                        Text("30 сек")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.75))
                        Spacer()
                        Text("30 мин")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.75))
                    }

                    HStack(spacing: 8) {
                        Text("Секунды")
                            .foregroundStyle(.white.opacity(0.88))
                        TextField("Сек", value: $viewModel.delaySeconds, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 120)
                    }
                }
                .padding(14)
                .background(.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                Toggle("Выключить экран при срабатывании", isOn: $viewModel.shouldSleepDisplayOnTrigger)
                    .toggleStyle(.switch)
                    .foregroundStyle(.white)

                Button(viewModel.isMonitoring ? "Стоп" : "Старт") {
                    viewModel.toggleMonitoring()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(Color(red: 0.24, green: 0.63, blue: 0.96))
            }
            .padding(22)
        }
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
