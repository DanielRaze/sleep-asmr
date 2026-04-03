import AppKit
import SwiftUI

@main
struct SleepASMRApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        NSApplication.shared.applicationIconImage = AppIconFactory.makeIcon()
    }

    var body: some Scene {
        WindowGroup {
            MainView()
                .frame(minWidth: 760, minHeight: 760)
        }
        .defaultSize(width: 860, height: 820)
        .windowResizability(.contentSize)

        MenuBarExtra("Sleep ASMR", systemImage: "eye.fill") {
            Button("Показать окно") {
                NSApp.activate(ignoringOtherApps: true)
                if let mainWindow = NSApp.windows.first {
                    mainWindow.makeKeyAndOrderFront(nil)
                }
            }

            Divider()

            Button("Выход") {
                NSApp.terminate(nil)
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}

enum AppIconFactory {
    static func makeIcon(size: CGFloat = 512) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()

        let rect = NSRect(x: 0, y: 0, width: size, height: size)
        let bg = NSGradient(colors: [
            NSColor(calibratedRed: 0.12, green: 0.11, blue: 0.29, alpha: 1),
            NSColor(calibratedRed: 0.01, green: 0.04, blue: 0.10, alpha: 1)
        ])

        let rounded = NSBezierPath(roundedRect: rect, xRadius: size * 0.22, yRadius: size * 0.22)
        bg?.draw(in: rounded, angle: -45)

        NSColor.white.withAlphaComponent(0.10).setStroke()
        rounded.lineWidth = max(2, size * 0.006)
        rounded.stroke()

        let accent = NSGradient(colors: [
            NSColor(calibratedRed: 0.02, green: 0.71, blue: 0.83, alpha: 1),
            NSColor(calibratedRed: 0.55, green: 0.36, blue: 0.96, alpha: 1)
        ])

        // Closed-eye arc.
        let eye = NSBezierPath()
        eye.move(to: NSPoint(x: size * 0.30, y: size * 0.45))
        eye.curve(
            to: NSPoint(x: size * 0.70, y: size * 0.45),
            controlPoint1: NSPoint(x: size * 0.40, y: size * 0.35),
            controlPoint2: NSPoint(x: size * 0.60, y: size * 0.35)
        )
        eye.lineWidth = max(16, size * 0.052)
        eye.lineCapStyle = .round
        accent?.draw(in: eye, angle: 0)

        // Eyelashes.
        let lash1 = NSBezierPath()
        lash1.move(to: NSPoint(x: size * 0.38, y: size * 0.42))
        lash1.line(to: NSPoint(x: size * 0.35, y: size * 0.34))
        lash1.lineWidth = max(9, size * 0.026)
        lash1.lineCapStyle = .round
        accent?.draw(in: lash1, angle: 0)

        let lash2 = NSBezierPath()
        lash2.move(to: NSPoint(x: size * 0.50, y: size * 0.40))
        lash2.line(to: NSPoint(x: size * 0.50, y: size * 0.31))
        lash2.lineWidth = max(9, size * 0.026)
        lash2.lineCapStyle = .round
        accent?.draw(in: lash2, angle: 0)

        let lash3 = NSBezierPath()
        lash3.move(to: NSPoint(x: size * 0.62, y: size * 0.42))
        lash3.line(to: NSPoint(x: size * 0.65, y: size * 0.34))
        lash3.lineWidth = max(9, size * 0.026)
        lash3.lineCapStyle = .round
        accent?.draw(in: lash3, angle: 0)

        // Decorative wave lines in the top-right area.
        let wave1 = NSBezierPath()
        wave1.move(to: NSPoint(x: size * 0.66, y: size * 0.67))
        wave1.curve(
            to: NSPoint(x: size * 0.80, y: size * 0.67),
            controlPoint1: NSPoint(x: size * 0.70, y: size * 0.70),
            controlPoint2: NSPoint(x: size * 0.75, y: size * 0.64)
        )
        wave1.lineWidth = max(5, size * 0.014)
        wave1.lineCapStyle = .round
        NSColor(calibratedRed: 0.02, green: 0.64, blue: 0.81, alpha: 0.85).setStroke()
        wave1.stroke()

        let wave2 = NSBezierPath()
        wave2.move(to: NSPoint(x: size * 0.61, y: size * 0.60))
        wave2.curve(
            to: NSPoint(x: size * 0.83, y: size * 0.60),
            controlPoint1: NSPoint(x: size * 0.68, y: size * 0.66),
            controlPoint2: NSPoint(x: size * 0.76, y: size * 0.54)
        )
        wave2.lineWidth = max(8, size * 0.02)
        wave2.lineCapStyle = .round
        NSColor(calibratedRed: 0.55, green: 0.36, blue: 0.96, alpha: 0.9).setStroke()
        wave2.stroke()

        image.unlockFocus()
        return image
    }
}
