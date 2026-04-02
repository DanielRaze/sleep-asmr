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
            NSColor(calibratedRed: 0.10, green: 0.14, blue: 0.20, alpha: 1),
            NSColor(calibratedRed: 0.03, green: 0.06, blue: 0.10, alpha: 1)
        ])

        let rounded = NSBezierPath(roundedRect: rect, xRadius: size * 0.22, yRadius: size * 0.22)
        bg?.draw(in: rounded, angle: -38)

        let eyeOuterRect = NSRect(x: size * 0.14, y: size * 0.26, width: size * 0.72, height: size * 0.48)
        let outer = NSBezierPath()
        outer.move(to: NSPoint(x: eyeOuterRect.minX, y: eyeOuterRect.midY))
        outer.curve(
            to: NSPoint(x: eyeOuterRect.maxX, y: eyeOuterRect.midY),
            controlPoint1: NSPoint(x: eyeOuterRect.minX + size * 0.18, y: eyeOuterRect.maxY),
            controlPoint2: NSPoint(x: eyeOuterRect.maxX - size * 0.18, y: eyeOuterRect.maxY)
        )
        outer.curve(
            to: NSPoint(x: eyeOuterRect.minX, y: eyeOuterRect.midY),
            controlPoint1: NSPoint(x: eyeOuterRect.maxX - size * 0.18, y: eyeOuterRect.minY),
            controlPoint2: NSPoint(x: eyeOuterRect.minX + size * 0.18, y: eyeOuterRect.minY)
        )
        outer.close()

        NSColor.white.withAlphaComponent(0.90).setFill()
        outer.fill()

        let irisRect = NSRect(x: size * 0.35, y: size * 0.34, width: size * 0.30, height: size * 0.30)
        let iris = NSBezierPath(ovalIn: irisRect)
        NSColor(calibratedRed: 0.16, green: 0.64, blue: 0.92, alpha: 1).setFill()
        iris.fill()

        let pupilRect = NSRect(x: size * 0.43, y: size * 0.42, width: size * 0.14, height: size * 0.14)
        let pupil = NSBezierPath(ovalIn: pupilRect)
        NSColor(calibratedRed: 0.02, green: 0.07, blue: 0.12, alpha: 1).setFill()
        pupil.fill()

        let sparkRect = NSRect(x: size * 0.50, y: size * 0.50, width: size * 0.06, height: size * 0.06)
        let spark = NSBezierPath(ovalIn: sparkRect)
        NSColor.white.withAlphaComponent(0.92).setFill()
        spark.fill()

        image.unlockFocus()
        return image
    }
}
