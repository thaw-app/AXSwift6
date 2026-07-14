import AppKit
import AXSwift6
import os

/// Demonstrates basic AXSwift6 queries against the frontmost app, Finder, and the system-wide element.
@MainActor
final class ApplicationDelegate: NSObject, NSApplicationDelegate {
    private let logger = Logger(subsystem: "AXSwift6.Example", category: "Application")

    func applicationDidFinishLaunching(_: Notification) {
        guard UIElement.isProcessTrusted(withPrompt: true) else {
            logger.error("No accessibility API permission; exiting")
            NSApp.terminate(nil)
            return
        }

        inspectFrontmostApplication()
        inspectFinder()
        inspectSystemWideElement()
        NSApp.terminate(nil)
    }

    private func inspectFrontmostApplication() {
        guard let running = NSWorkspace.shared.frontmostApplication else {
            logger.notice("No frontmost application")
            return
        }

        logger.info(
            "frontmost: \(running.localizedName ?? "<unnamed>", privacy: .public) pid=\(running.processIdentifier)"
        )

        guard let uiApp = Application(running) else {
            logger.error("Could not wrap frontmost application")
            return
        }

        logOptional("windows", try? uiApp.windows())
        logOptional("attributes", try? uiApp.attributes())
        logOptional("elementAt(0,0)", try? uiApp.elementAtPosition(0, 0))

        if let bundleIdentifier = running.bundleIdentifier {
            logger.info("bundleIdentifier: \(bundleIdentifier, privacy: .public)")
            if let windows = try? Application.allForBundleID(bundleIdentifier).first?.windows() {
                logOptional("windows(forBundle)", windows)
            }
        }
    }

    private func inspectFinder() {
        guard let app = Application.allForBundleID("com.apple.finder").first else {
            logger.error("Finder is not running")
            return
        }

        logger.info("finder: \(String(describing: app), privacy: .public)")
        logOptional("role", try? app.role())
        logOptional("windows", try? app.windows())
        logOptional("attributes", try? app.attributes())

        if let title: String = try? app.attribute(.title) {
            logger.info("title: \(title, privacy: .public)")
        }

        logOptional(
            "multi(strings)",
            try? app.getMultipleAttributes(["AXRole", "asdf", "AXTitle"])
        )
        logOptional("multi(enums)", try? app.getMultipleAttributes(.role, .title))

        guard let window = try? app.windows()?.first else { return }
        do {
            try window.setAttribute(.title, value: "my title")
            let newTitle: String? = try? window.attribute(.title)
            logger.info("title set; result = \(newTitle ?? "<none>", privacy: .public)")
        } catch {
            logger.error("error setting window title: \(String(describing: error), privacy: .public)")
        }
    }

    private func inspectSystemWideElement() {
        logger.info("system wide")
        logOptional("role", try? systemWideElement.role())
        logOptional("attributes", try? systemWideElement.attributes())
    }

    private func logOptional<T>(_ label: String, _ value: T?) {
        logger.info("\(label, privacy: .public): \(String(describing: value), privacy: .public)")
    }
}

@main
enum AXSwiftExampleMain {
    static func main() {
        let application = NSApplication.shared
        let delegate = ApplicationDelegate()
        application.setActivationPolicy(.accessory)
        application.delegate = delegate
        application.run()
    }
}
