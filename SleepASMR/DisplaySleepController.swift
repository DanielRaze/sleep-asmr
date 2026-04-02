import Foundation
import IOKit.pwr_mgt

final class DisplaySleepController {
    enum SleepError: Error, LocalizedError {
        case commandFailed(Int32)
        case commandLaunchFailed(Error)
        case lockCommandFailed

        var errorDescription: String? {
            switch self {
            case .commandFailed(let status):
                return "Не удалось выключить экран. Код завершения pmset: \(status)."
            case .commandLaunchFailed(let error):
                return "Не удалось запустить pmset: \(error.localizedDescription)"
            case .lockCommandFailed:
                return "Экран выключен, но заблокировать сессию не удалось."
            }
        }
    }

    // Храним ID assertions, если приложение когда-либо добавит их в будущем.
    private var appAssertionIDs: [IOPMAssertionID] = []

    func sleepDisplayNow() -> Result<Void, SleepError> {
        releaseAppAssertionsIfNeeded()
        let sleepResult = runCommand(
            executable: "/usr/bin/pmset",
            arguments: ["displaysleepnow"]
        )

        switch sleepResult {
        case .failure(let error):
            return .failure(error)
        case .success:
            break
        }

        // Блокируем пользовательскую сессию, чтобы после пробуждения был экран логина.
        if !lockSession() {
            return .failure(.lockCommandFailed)
        }

        return .success(())
    }

    private func lockSession() -> Bool {
        let cgSessionPath = "/System/Library/CoreServices/Menu Extras/User.menu/Contents/Resources/CGSession"
        let cgResult = runCommand(executable: cgSessionPath, arguments: ["-suspend"])
        if case .success = cgResult {
            return true
        }

        // Fallback для некоторых конфигураций, где CGSession недоступен.
        let appleScript = "tell application \"System Events\" to keystroke \"q\" using {control down, command down}"
        let osascriptResult = runCommand(executable: "/usr/bin/osascript", arguments: ["-e", appleScript])
        if case .success = osascriptResult {
            return true
        }

        return false
    }

    private func runCommand(executable: String, arguments: [String]) -> Result<Void, SleepError> {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return .failure(.commandLaunchFailed(error))
        }

        guard process.terminationStatus == 0 else {
            return .failure(.commandFailed(process.terminationStatus))
        }

        return .success(())
    }

    private func releaseAppAssertionsIfNeeded() {
        for assertionID in appAssertionIDs {
            IOPMAssertionRelease(assertionID)
        }
        appAssertionIDs.removeAll()
    }
}
