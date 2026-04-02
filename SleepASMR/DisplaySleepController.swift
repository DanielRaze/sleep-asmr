import Foundation
import IOKit.pwr_mgt

final class DisplaySleepController {
    enum SleepError: Error, LocalizedError {
        case commandFailed(Int32)
        case commandLaunchFailed(Error)

        var errorDescription: String? {
            switch self {
            case .commandFailed(let status):
                return "Не удалось выключить экран. Код завершения pmset: \(status)."
            case .commandLaunchFailed(let error):
                return "Не удалось запустить pmset: \(error.localizedDescription)"
            }
        }
    }

    // Храним ID assertions, если приложение когда-либо добавит их в будущем.
    private var appAssertionIDs: [IOPMAssertionID] = []

    func sleepDisplayNow() -> Result<Void, SleepError> {
        releaseAppAssertionsIfNeeded()

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        process.arguments = ["displaysleepnow"]

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
