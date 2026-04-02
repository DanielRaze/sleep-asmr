import Combine
import Foundation

@MainActor
final class MonitoringViewModel: ObservableObject {
    @Published var isMonitoring = false
    @Published var shouldSleepDisplayOnTrigger = true
    @Published var isPowerSavingEnabled = true
    @Published var allowBriefEyeOpenings = true
    @Published var briefOpeningToleranceSeconds: Double = 3
    @Published var delaySeconds: Double = 600
    @Published var statusText: String = "Готово к запуску"
    @Published var analysisModeText: String = "Экономный режим: редкая проверка"
    @Published var errorMessage: String?

    let cameraManager = CameraManager()

    private let detector = VisionEyeStateDetector()
    private let sleepController = DisplaySleepController()
    private let visionQueue = DispatchQueue(label: "sleepasmr.vision.queue", qos: .userInitiated)

    private let lowFrequencyInterval: TimeInterval = 0.8
    private let highFrequencyInterval: TimeInterval = 0.2

    private var closedSince: Date?
    private var briefOpeningStartedAt: Date?
    private var didTrigger = false

    init() {
        applySamplingMode(for: .notDetected)

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
                    self.briefOpeningStartedAt = nil
                    self.didTrigger = false
                    self.applySamplingMode(for: .notDetected)
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
        briefOpeningStartedAt = nil
        didTrigger = false
        statusText = "Мониторинг остановлен"
    }

    func refreshSamplingMode() {
        applySamplingMode(for: .notDetected)
    }

    private func handle(eyeState: VisionEyeStateDetector.EyeState, now: Date) {
        guard isMonitoring else { return }

        switch eyeState {
        case .open:
            applySamplingMode(for: .open)
            handleOpenEyes(now: now)

        case .closed:
            applySamplingMode(for: .closed)
            if closedSince == nil {
                closedSince = now
            }

            briefOpeningStartedAt = nil

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
            applySamplingMode(for: .notDetected)
            resetCloseTracking()
            statusText = "Лицо не обнаружено"
        }
    }

    private func handleOpenEyes(now: Date) {
        guard let closedSince else {
            resetCloseTracking()
            statusText = "Глаза открыты"
            return
        }

        guard allowBriefEyeOpenings else {
            resetCloseTracking()
            statusText = "Глаза открыты"
            return
        }

        if briefOpeningStartedAt == nil {
            briefOpeningStartedAt = now
        }

        guard let openedAt = briefOpeningStartedAt else {
            resetCloseTracking()
            statusText = "Глаза открыты"
            return
        }

        let openDuration = now.timeIntervalSince(openedAt)
        let tolerance = max(0.5, min(briefOpeningToleranceSeconds, 10))

        if openDuration <= tolerance {
            let elapsed = now.timeIntervalSince(closedSince)
            let remaining = max(0, delaySeconds - elapsed)
            statusText = "Краткое открытие глаз: \(Int(remaining.rounded(.up))) сек до выключения"
        } else {
            resetCloseTracking()
            statusText = "Глаза открыты"
        }
    }

    private func resetCloseTracking() {
        closedSince = nil
        briefOpeningStartedAt = nil
        didTrigger = false
    }

    private func applySamplingMode(for state: VisionEyeStateDetector.EyeState) {
        guard isPowerSavingEnabled else {
            cameraManager.updateFrameSamplingInterval(0)
            analysisModeText = "Точный режим: анализ каждого кадра"
            return
        }

        switch state {
        case .closed:
            cameraManager.updateFrameSamplingInterval(highFrequencyInterval)
            analysisModeText = "Экономный режим: частая проверка (глаза закрыты)"
        case .open, .notDetected:
            cameraManager.updateFrameSamplingInterval(lowFrequencyInterval)
            analysisModeText = "Экономный режим: редкая проверка"
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
