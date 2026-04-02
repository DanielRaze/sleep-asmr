import Combine
import Foundation

@MainActor
final class MonitoringViewModel: ObservableObject {
    @Published var isMonitoring = false
    @Published var shouldSleepDisplayOnTrigger = true
    @Published var delaySeconds: Double = 600
    @Published var statusText: String = "Готово к запуску"
    @Published var errorMessage: String?

    let cameraManager = CameraManager()

    private let detector = VisionEyeStateDetector()
    private let sleepController = DisplaySleepController()
    private let visionQueue = DispatchQueue(label: "sleepasmr.vision.queue", qos: .userInitiated)

    private var closedSince: Date?
    private var didTrigger = false

    init() {
        cameraManager.onFrame = { [weak self] pixelBuffer in
            guard let self else { return }
            self.visionQueue.async {
                let state = self.detector.detectEyeState(in: pixelBuffer)
                let now = Date()
                Task { @MainActor in
                    self.handle(eyeState: state, now: now)
                }
            }
        }
    }

    func toggleMonitoring() {
        isMonitoring ? stopMonitoring() : startMonitoring()
    }

    func startMonitoring() {
        statusText = "Проверка доступа к камере..."
        errorMessage = nil

        cameraManager.requestAccessAndConfigure { [weak self] result in
            guard let self else { return }
            Task { @MainActor in
                switch result {
                case .success:
                    self.closedSince = nil
                    self.didTrigger = false
                    self.isMonitoring = true
                    self.statusText = "Мониторинг запущен. Ожидание лица..."
                    self.cameraManager.startSession()
                case .failure(let error):
                    self.isMonitoring = false
                    self.statusText = "Мониторинг не запущен"
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func stopMonitoring() {
        cameraManager.stopSession()
        isMonitoring = false
        closedSince = nil
        didTrigger = false
        statusText = "Мониторинг остановлен"
    }

    private func handle(eyeState: VisionEyeStateDetector.EyeState, now: Date) {
        guard isMonitoring else { return }

        switch eyeState {
        case .open:
            closedSince = nil
            didTrigger = false
            statusText = "Глаза открыты"

        case .closed:
            if closedSince == nil {
                closedSince = now
            }

            guard let closedSince else {
                statusText = "Глаза закрыты"
                return
            }

            let elapsed = now.timeIntervalSince(closedSince)
            let remaining = max(0, delaySeconds - elapsed)

            if remaining > 0 {
                statusText = "Таймер: \(Int(remaining.rounded(.up))) сек до выключения"
            } else {
                triggerDisplaySleepIfNeeded()
            }

        case .notDetected:
            closedSince = nil
            didTrigger = false
            statusText = "Лицо не обнаружено"
        }
    }

    private func triggerDisplaySleepIfNeeded() {
        guard !didTrigger else {
            statusText = shouldSleepDisplayOnTrigger
                ? "Экран выключен, Mac заблокирован"
                : "Порог достигнут (выключение экрана отключено)"
            return
        }

        didTrigger = true

        guard shouldSleepDisplayOnTrigger else {
            statusText = "Порог достигнут (выключение экрана отключено)"
            return
        }

        switch sleepController.sleepDisplayNow() {
        case .success:
            statusText = "Экран выключен, Mac заблокирован"
        case .failure(let error):
            errorMessage = error.localizedDescription
            statusText = "Ошибка выключения/блокировки"
        }
    }
}
