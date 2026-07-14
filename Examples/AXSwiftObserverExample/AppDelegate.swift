import AppKit
import AXSwift6
import os

/// Watches Finder for window creation and related accessibility notifications.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let logger = Logger(subsystem: "AXSwift6.Example", category: "Observer")
    private var observer: Observer?
    private let batcher = NotificationBatcher()

    func applicationDidFinishLaunching(_: Notification) {
        guard UIElement.isProcessTrusted(withPrompt: true) else {
            logger.error("No accessibility API permission; exiting")
            NSApp.terminate(nil)
            return
        }

        guard let app = Application.allForBundleID("com.apple.finder").first else {
            logger.error("Finder is not running")
            NSApp.terminate(nil)
            return
        }

        do {
            try startWatcher(app)
        } catch {
            logger.error("Could not watch app [\(String(describing: app), privacy: .public)]: \(String(describing: error), privacy: .public)")
            NSApp.terminate(nil)
        }
    }

    private func startWatcher(_ app: Application) throws {
        let batcher = batcher
        let logger = logger

        observer = app.createObserver { observer, element, event, info in
            let elementDesc: String
            if let role = try? element.role(), role == .window {
                let title = (try? element.attribute(.title) as String?) ?? "<untitled>"
                elementDesc = "\(element) \"\(title)\""
            } else {
                elementDesc = "\(element)"
            }

            logger.info(
                "\(String(describing: event), privacy: .public) on \(elementDesc, privacy: .public); info: \(String(describing: info ?? [:]), privacy: .public)"
            )

            if event == .windowCreated {
                do {
                    try observer.addNotification(.uiElementDestroyed, forElement: element)
                    try observer.addNotification(.moved, forElement: element)
                } catch {
                    logger.error(
                        "Could not watch [\(String(describing: element), privacy: .public)]: \(String(describing: error), privacy: .public)"
                    )
                }
            }

            batcher.scheduleSeparator()
        }

        guard let observer else {
            throw AXError.failure
        }

        try observer.addNotification(.windowCreated, forElement: app)
        try observer.addNotification(.mainWindowChanged, forElement: app)
    }
}

/// Groups simultaneous accessibility callbacks behind a single console separator.
private final class NotificationBatcher: Sendable {
    private let lock = OSAllocatedUnfairLock(initialState: false)

    func scheduleSeparator() {
        let shouldSchedule = lock.withLock { pending -> Bool in
            if pending { return false }
            pending = true
            return true
        }
        guard shouldSchedule else { return }

        DispatchQueue.main.async { [lock] in
            print("---")
            lock.withLock { $0 = false }
        }
    }
}

@main
enum AXSwiftObserverExampleMain {
    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.setActivationPolicy(.accessory)
        application.delegate = delegate
        application.run()
    }
}
