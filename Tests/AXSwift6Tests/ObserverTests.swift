import ApplicationServices
import AXSwift6
import Testing

@Suite("Observer")
struct ObserverTests {
    @Test("Init records the process ID and application handle")
    func initRecordsProcessIDAndApplicationHandle() throws {
        let observer = try Observer(processID: getpid()) { _, _, _ in
            // No-op callback for construction coverage.
        }
        defer { observer.stop() }

        #expect(observer.pid == getpid())
        #expect(try observer.application.pid() == getpid())
    }

    @Test("Info-callback initializer constructs an observer")
    func infoCallbackInitializerConstructsObserver() throws {
        let observer = try Observer(processID: getpid()) { _, _, _, _ in
            // No-op info callback for construction coverage.
        }
        defer { observer.stop() }

        #expect(observer.pid == getpid())
    }

    @Test("Invalid process ID throws")
    func invalidProcessIDThrows() {
        #expect(throws: AXError.self) {
            try Observer(processID: -1) { _, _, _ in
                // No-op: construction should fail before the callback is used.
            }
        }
    }

    @Test("Duplicate notification registration is tolerated")
    func duplicateNotificationRegistrationIsTolerated() throws {
        let observer = try Observer(processID: getpid()) { _, _, _ in
            // No-op callback for notification registration coverage.
        }
        defer { observer.stop() }

        let app = try TestFixtures.currentApplicationOrSkip()
        do {
            try observer.addNotification(.applicationActivated, forElement: app)
            try observer.addNotification(.applicationActivated, forElement: app)
        } catch let error as AXError {
            #expect(TestFixtures.acceptableNotificationErrors.contains(error))
        }
    }

    @Test("Removing an unregistered notification is tolerated")
    func removingUnregisteredNotificationIsTolerated() throws {
        let observer = try Observer(processID: getpid()) { _, _, _ in
            // No-op callback for notification removal coverage.
        }
        defer { observer.stop() }

        let app = try TestFixtures.currentApplicationOrSkip()
        do {
            try observer.removeNotification(.windowCreated, forElement: app)
        } catch let error as AXError {
            #expect(TestFixtures.acceptableNotificationErrors.contains(error))
        }
    }

    @Test("System-wide element notifications are unsupported")
    func systemWideElementNotificationsAreUnsupported() throws {
        let observer = try Observer(processID: getpid()) { _, _, _ in
            // No-op callback for unsupported-notification coverage.
        }
        defer { observer.stop() }

        #expect(throws: AXError.self) {
            try observer.addNotification(.focusedUIElementChanged, forElement: systemWideElement)
        }
    }
}
