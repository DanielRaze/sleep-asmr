import AVFoundation
import AppKit
import SwiftUI

struct MainView: View {
    @StateObject private var viewModel = MonitoringViewModel()

    private var scoreProgress: Double {
        guard viewModel.useCumulativeScoring else { return 0 }
        let threshold = max(viewModel.scoreTriggerThreshold, 0.01)
        return min(max(viewModel.sleepinessScore / threshold, 0), 1)
    }

    var body: some View {
        HStack(spacing: 0) {
            CameraPreviewSection(viewModel: viewModel, scoreProgress: scoreProgress)
                .frame(minWidth: 520, maxWidth: .infinity, minHeight: 540, maxHeight: .infinity)
                .background(
                    LinearGradient(
                        colors: [
                            Color(red: 0.12, green: 0.11, blue: 0.29),
                            Color(red: 0.02, green: 0.06, blue: 0.16)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Divider()

            ControlPanelSection(viewModel: viewModel)
                .frame(width: 340)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.72))
        }
        .frame(minWidth: 920, minHeight: 620)
        .onChange(of: viewModel.delaySeconds) { _, newValue in
            let clamped = min(max(newValue, 30), 1800)
            if clamped != newValue {
                viewModel.delaySeconds = clamped
            }
        }
        .onChange(of: viewModel.isPowerSavingEnabled) { _, _ in
            viewModel.refreshSamplingMode()
        }
        .onAppear {
            viewModel.runInitialPermissionFlowIfNeeded()
            viewModel.refreshPermissionsStatus()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            viewModel.refreshPermissionsStatus()
        }
        .alert("Перезапуск рекомендуется", isPresented: $viewModel.showRestartPrompt) {
            Button("Перезапустить сейчас") {
                viewModel.restartApplication()
            }
            Button("Позже", role: .cancel) {}
        } message: {
            Text(viewModel.permissionsInfoText ?? "Разрешения были запрошены. Перезапуск нужен, чтобы все сервисы стабильно применились.")
        }
        .background(WindowCloseToTrayBehavior())
    }
}

struct CameraPreviewSection: View {
    @ObservedObject var viewModel: MonitoringViewModel
    let scoreProgress: Double

    var body: some View {
        ZStack {
            CameraPreviewView(session: viewModel.cameraManager.session)
                .ignoresSafeArea()

            VStack {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.analysisModeText)
                            .font(.headline)
                            .foregroundStyle(.white)

                        HStack(spacing: 8) {
                            Circle()
                                .fill(viewModel.isMonitoring ? Color.green : Color.gray)
                                .frame(width: 8, height: 8)
                            Text(viewModel.statusText)
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.92))
                        }
                    }

                    Spacer()

                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.2), lineWidth: 6)

                        Circle()
                            .trim(from: 0.0, to: scoreProgress)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.02, green: 0.71, blue: 0.83),
                                        Color(red: 0.55, green: 0.36, blue: 0.96)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                style: StrokeStyle(lineWidth: 6, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .animation(.spring(duration: 0.25), value: scoreProgress)

                        Image(systemName: "eye.slash.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.white)
                    }
                    .frame(width: 44, height: 44)
                    .help("Скоринг: \(Int(viewModel.sleepinessScore * 100))% из \(Int(viewModel.scoreTriggerThreshold * 100))%")
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                .padding()

                Spacer()

                if let error = viewModel.errorMessage {
                    NotificationBanner(text: error, icon: "exclamationmark.triangle.fill", color: .red)
                } else if let missingPerm = viewModel.missingPermissionsText {
                    NotificationBanner(text: missingPerm, icon: "lock.fill", color: .orange)
                }
            }
        }
    }
}

struct ControlPanelSection: View {
    @ObservedObject var viewModel: MonitoringViewModel

    var body: some View {
        VStack(spacing: 0) {
            Text("Управление")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()

            Divider()

            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 12) {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                viewModel.toggleMonitoring()
                            }
                        }) {
                            Text(viewModel.isMonitoring ? "Остановить" : "Начать мониторинг")
                                .font(.system(size: 14, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(viewModel.isMonitoring ? .red : .accentColor)
                        .controlSize(.large)

                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Таймер до выключения")
                                Spacer()
                                Text(formattedDelay(viewModel.delaySeconds))
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                            .font(.system(size: 13))

                            Slider(value: $viewModel.delaySeconds, in: 30...1800, step: 1)
                                .disabled(viewModel.isMonitoring)
                        }
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    VStack(alignment: .leading, spacing: 16) {
                        Text("Поведение системы")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Toggle("Выключать дисплей при сне", isOn: $viewModel.shouldSleepDisplayOnTrigger)
                            .toggleStyle(.switch)

                        Toggle("Режим энергосбережения", isOn: $viewModel.isPowerSavingEnabled)
                            .toggleStyle(.switch)

                        Toggle("Накопительный скоринг", isOn: $viewModel.useCumulativeScoring)
                            .toggleStyle(.switch)
                            .help("Если включено, закрытие глаз учитывается накопительно")
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    VStack(alignment: .leading, spacing: 16) {
                        Text("Тонкая настройка алгоритма")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Toggle("Игнорировать краткие открытия", isOn: $viewModel.allowBriefEyeOpenings)
                            .toggleStyle(.switch)

                        if viewModel.allowBriefEyeOpenings {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Допуск")
                                    Spacer()
                                    Text("\(Int(viewModel.briefOpeningToleranceSeconds)) сек")
                                        .foregroundStyle(.secondary)
                                        .monospacedDigit()
                                }
                                .font(.system(size: 12))

                                Slider(value: $viewModel.briefOpeningToleranceSeconds, in: 1...10, step: 1)
                            }
                            .padding(.leading, 8)
                            .padding(.top, 4)
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }

                        if viewModel.useCumulativeScoring {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Порог скоринга")
                                    Spacer()
                                    Text("\(Int(viewModel.scoreTriggerThreshold * 100))%")
                                        .foregroundStyle(.secondary)
                                        .monospacedDigit()
                                }
                                .font(.system(size: 12))

                                Slider(value: $viewModel.scoreTriggerThreshold, in: 0.90...0.995, step: 0.005)
                            }
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    if let missing = viewModel.missingPermissionsText {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(missing)
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.orange)

                            HStack(spacing: 8) {
                                Button("Запросить снова") {
                                    viewModel.requestMissingPermissions()
                                }
                                .buttonStyle(.bordered)

                                Button("Камера") {
                                    viewModel.openCameraPrivacySettings()
                                }
                                .buttonStyle(.bordered)

                                Button("Accessibility") {
                                    viewModel.openAccessibilityPrivacySettings()
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(NSColor.controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
                .padding()
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

struct NotificationBanner: View {
    let text: String
    let icon: String
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.primary)
            Spacer()
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.horizontal)
        .padding(.bottom, 20)
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

struct WindowCloseToTrayBehavior: NSViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                window.isReleasedWhenClosed = false
                window.delegate = context.coordinator
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            if let window = nsView.window {
                window.isReleasedWhenClosed = false
                if window.delegate !== context.coordinator {
                    window.delegate = context.coordinator
                }
            }
        }
    }

    final class Coordinator: NSObject, NSWindowDelegate {
        func windowShouldClose(_ sender: NSWindow) -> Bool {
            sender.orderOut(nil)
            return false
        }
    }
}
