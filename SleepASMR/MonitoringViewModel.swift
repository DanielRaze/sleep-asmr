import AppKit
import AVFoundation
import ApplicationServices
import Combine
import Foundation

@MainActor
final class MonitoringViewModel: ObservableObject {
    @Published var isMonitoring = false
    @Published var shouldSleepDisplayOnTrigger = true
    @Published var isPowerSavingEnabled = true
    @Published var allowBriefEyeOpenings = true
    @Published var useCumulativeScoring = true
    @Published var briefOpeningToleranceSeconds: Double = 3
    @Published var scoreTriggerThreshold: Double = 0.985
    @Published var delaySeconds: Double = 600
    @Published var statusText: String = "Готово к запуску"
    @Published var analysisModeText: String = "Экономный режим: редкая проверка"
    @Published var sleepinessScore: Double = 0
    @Published var errorMessage: String?
    @Published var permissionsInfoText: String?
    @Published var showRestartPrompt = false
    @Published var hasAllPermissions = false
    @Published var missingPermissionsText: String?

    let cameraManager = CameraManager()

    private let detector = VisionEyeStateDetector()
    private let sleepController = DisplaySleepController()
    private let visionQueue = DispatchQueue(label: "sleepasmr.vision.queue", qos: .userInitiated)

    private let lowFrequencyInterval: TimeInterval = 0.8
    private let highFrequencyInterval: TimeInterval = 0.2
    private let initialPermissionFlowKey = "sleepasmr.didRunInitialPermissionFlow"
    private var currentClosedEpisodeStart: Date?
    private var wasMissingPermissions = false

    private var closedSince: Date?
    private var briefOpeningStartedAt: Date?
    private var lastScoreUpdateAt: Date?
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

    func refreshPermissionsStatus() {
        let cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
        let cameraGranted = cameraStatus == .authorized
        let accessibilityGranted = AXIsProcessTrusted()

        hasAllPermissions = cameraGranted && accessibilityGranted

        var missing: [String] = []
        if !cameraGranted {
            missing.append("Камера")
        }
        if !accessibilityGranted {
            missing.append("Accessibility")
        }

        missingPermissionsText = missing.isEmpty
            ? nil
            : "Не хватает разрешений: \(missing.joined(separator: ", "))."

        if !hasAllPermissions {
            wasMissingPermissions = true
        } else if wasMissingPermissions {
            // После выдачи разрешений в работающем приложении рекомендуем перезапуск.
            permissionsInfoText = "Разрешения выданы. Рекомендуется перезапустить приложение."
            showRestartPrompt = true
            wasMissingPermissions = false
        }
    }

    func runInitialPermissionFlowIfNeeded() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: initialPermissionFlowKey) else { return }
        defaults.set(true, forKey: initialPermissionFlowKey)

        Task {
            let cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
            var requestedAnyPermission = false
            var cameraMessage = "Камера: уже настроено"

            switch cameraStatus {
            case .authorized:
                cameraMessage = "Камера: доступ уже разрешен"
            case .notDetermined:
                requestedAnyPermission = true
                let granted = await requestCameraAccess()
                cameraMessage = granted ? "Камера: доступ выдан" : "Камера: доступ не выдан"
            case .denied, .restricted:
                cameraMessage = "Камера: доступ запрещен"
            @unknown default:
                cameraMessage = "Камера: неизвестный статус"
            }

            let accessibilityWasTrusted = AXIsProcessTrusted()
            var accessibilityMessage = "Accessibility: уже настроено"
            if !accessibilityWasTrusted {
                requestedAnyPermission = true
                requestAccessibilityPrompt()
                accessibilityMessage = "Accessibility: откройте системный диалог и разрешите доступ"
            } else {
                accessibilityMessage = "Accessibility: доступ уже разрешен"
            }

            permissionsInfoText = "\(cameraMessage). \(accessibilityMessage)."
            if requestedAnyPermission {
                showRestartPrompt = true
            }

            refreshPermissionsStatus()
        }
    }

    func requestMissingPermissions() {
        let cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)

        if cameraStatus == .notDetermined {
            Task {
                _ = await requestCameraAccess()
                refreshPermissionsStatus()
            }
        }

        if !AXIsProcessTrusted() {
            requestAccessibilityPrompt()
        }

        refreshPermissionsStatus()
    }

    func openCameraPrivacySettings() {
        openPrivacySettings(anchor: "Privacy_Camera")
    }

    func openAccessibilityPrivacySettings() {
        openPrivacySettings(anchor: "Privacy_Accessibility")
    }

    func restartApplication() {
        let appPath = Bundle.main.bundlePath
        let reopen = Process()
        reopen.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        reopen.arguments = [appPath]
        try? reopen.run()
        NSApp.terminate(nil)
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
                    self.currentClosedEpisodeStart = nil
                    self.briefOpeningStartedAt = nil
                    self.lastScoreUpdateAt = nil
                    self.sleepinessScore = 0
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
        currentClosedEpisodeStart = nil
        briefOpeningStartedAt = nil
        lastScoreUpdateAt = nil
        sleepinessScore = 0
        didTrigger = false
        statusText = "Мониторинг остановлен"
    }

    func refreshSamplingMode() {
        applySamplingMode(for: .notDetected)
    }

    private func handle(eyeState: VisionEyeStateDetector.EyeState, now: Date) {
        guard isMonitoring else { return }
        updateCumulativeScore(for: eyeState, now: now)

        switch eyeState {
        case .open:
            applySamplingMode(for: .open)
            handleOpenEyes(now: now)

        case .closed:
            applySamplingMode(for: .closed)
            if closedSince == nil {
                closedSince = now
            }
            if currentClosedEpisodeStart == nil {
                currentClosedEpisodeStart = now
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
                if canTriggerByScore(now: now) {
                    triggerDisplaySleepIfNeeded()
                }
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
            if canTriggerByScore(now: now) {
                triggerDisplaySleepIfNeeded()
            }
        } else {
            resetCloseTracking()
            statusText = "Глаза открыты"
        }
    }

    private func resetCloseTracking() {
        closedSince = nil
        currentClosedEpisodeStart = nil
        briefOpeningStartedAt = nil
        didTrigger = false
    }

    private func canTriggerByScore(now: Date) -> Bool {
        guard useCumulativeScoring else { return false }
        guard sleepinessScore >= scoreTriggerThreshold else { return false }

        // Защита от ложного досрочного срабатывания:
        // даже при высоком скоре требуем минимальное время непрерывной фазы сна.
        guard let episodeStart = currentClosedEpisodeStart else { return false }
        let episodeDuration = now.timeIntervalSince(episodeStart)
        let minimumRequired = min(max(15, delaySeconds * 0.55), 300)
        return episodeDuration >= minimumRequired
    }

    private func updateCumulativeScore(for state: VisionEyeStateDetector.EyeState, now: Date) {
        guard useCumulativeScoring else {
            sleepinessScore = 0
            lastScoreUpdateAt = now
            return
        }

        guard let last = lastScoreUpdateAt else {
            lastScoreUpdateAt = now
            return
        }

        let dt = max(0, min(now.timeIntervalSince(last), 1.5))
        lastScoreUpdateAt = now

        // Нормируем динамику под выбранную задержку.
        // При непрерывно закрытых глазах скор ~= 100% примерно за delaySeconds.
        let base = max(delaySeconds, 30)
        let gainClosedPerSec = 1.0 / base
        let decayOpenPerSec = 2.4 / base
        let decayNotDetectedPerSec = 3.0 / base
        let decayBriefOpenPerSec = 0.6 / base

        let delta: Double
        switch state {
        case .closed:
            delta = gainClosedPerSec * dt
        case .open:
            if allowBriefEyeOpenings, briefOpeningStartedAt != nil, closedSince != nil {
                delta = -decayBriefOpenPerSec * dt
            } else {
                delta = -decayOpenPerSec * dt
            }
        case .notDetected:
            delta = -decayNotDetectedPerSec * dt
        }

        sleepinessScore = min(1, max(0, sleepinessScore + delta))
    }

    private func requestCameraAccess() async -> Bool {
        await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .video) { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    private func requestAccessibilityPrompt() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [key: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    private func openPrivacySettings(anchor: String) {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)") else {
            return
        }
        NSWorkspace.shared.open(url)
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
