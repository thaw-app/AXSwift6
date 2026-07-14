import ApplicationServices
import AXSwift6
import Testing

@Suite("Concurrency")
struct ConcurrencyTests {
    @Test("Public handles and constants are Sendable")
    func publicHandlesAndConstantsAreSendable() {
        requireSendableType(UIElement.self)
        requireSendableType(Observer.self)
        requireSendable(systemWideElement)
        requireSendable(Role.menuBarItem)
        requireSendable(Subrole.standardWindow)
        requireSendable(Attribute.extrasMenuBar)
        requireSendable(Action.press)
        requireSendable(AXNotification.valueChanged)
    }

    @Test("Independent handles keep independent timeout state")
    func independentHandlesKeepIndependentTimeoutState() throws {
        let first = UIElement(AXUIElementCreateApplication(getpid()))
        let second = UIElement(AXUIElementCreateApplication(getpid()))

        try first.setMessagingTimeout(0.1)
        try second.setMessagingTimeout(0.2)

        #expect(first.currentMessagingTimeout == 0.1)
        #expect(second.currentMessagingTimeout == 0.2)
    }

    @Test("Wrappers for the same native reference share synchronization state")
    func wrappersForSameNativeReferenceShareSynchronizationState() throws {
        let nativeElement = AXUIElementCreateApplication(getpid())
        let first = UIElement(nativeElement)
        let second = UIElement(nativeElement)

        try first.setMessagingTimeout(0.1)
        #expect(second.currentMessagingTimeout == 0.1)

        try second.setMessagingTimeout(0.2)
        #expect(first.currentMessagingTimeout == 0.2)
        #expect(first == second)
        _ = try? first.setAttribute(.focusedUIElement, value: second)
    }

    @Test("Messaging timeout is serialized across tasks")
    func messagingTimeoutIsSerializedAcrossTasks() async throws {
        let element = UIElement(AXUIElementCreateApplication(getpid()))

        try await withThrowingTaskGroup(of: Void.self) { group in
            for index in 0 ..< 100 {
                group.addTask {
                    try element.setMessagingTimeout(index.isMultiple(of: 2) ? 0.1 : 0.2)
                }
            }
            try await group.waitForAll()
        }

        #expect(element.currentMessagingTimeout == 0.1 || element.currentMessagingTimeout == 0.2)
    }

    @Test("Negative messaging timeout is normalized to zero")
    func negativeMessagingTimeoutIsNormalized() throws {
        let element = UIElement(AXUIElementCreateApplication(getpid()))

        try element.setMessagingTimeout(-1)

        #expect(element.currentMessagingTimeout == 0)
    }

    @Test("Concurrent reads use one handle safely")
    func concurrentReadsUseOneHandleSafely() async throws {
        let element = UIElement(AXUIElementCreateApplication(getpid()))

        try await withThrowingTaskGroup(of: pid_t.self) { group in
            for _ in 0 ..< 100 {
                group.addTask {
                    try element.pid()
                }
            }
            for try await pid in group {
                #expect(pid == getpid())
            }
        }
    }

    @Test("Ordered element locking does not deadlock")
    func orderedElementLockingDoesNotDeadlock() async {
        let first = UIElement(AXUIElementCreateApplication(getpid()))
        let second = UIElement(AXUIElementCreateApplication(getpid()))

        await withTaskGroup(of: Void.self) { group in
            for index in 0 ..< 100 {
                group.addTask {
                    let source = index.isMultiple(of: 2) ? first : second
                    let value = index.isMultiple(of: 2) ? second : first
                    _ = try? source.setAttribute(.focusedUIElement, value: value)
                    _ = source == value
                }
            }
            group.addTask {
                _ = try? first.setAttribute(.focusedUIElement, value: first)
                _ = first == second
            }
        }
    }

    @Test("Observer start and stop are idempotent")
    func observerStartAndStopAreIdempotent() throws {
        let observer = try Observer(processID: getpid()) { _, _, _ in
            // No-op: this test only exercises start/stop lifecycle.
        }

        observer.start()
        observer.start()
        observer.stop()
        observer.stop()
        observer.start()
        observer.stop()
    }

    @Test("Observer registry does not extend lifetime")
    func observerRegistryDoesNotExtendLifetime() throws {
        var observer: Observer? = try Observer(processID: getpid()) { _, _, _ in
            // No-op: lifetime is asserted via weak reference after release.
        }
        let weakObserver = WeakReference(observer)

        observer = nil

        #expect(weakObserver.value == nil)
    }
}

/// Compile-time Sendable witness; body intentionally empty.
private func requireSendable<T: Sendable>(_: T) {
    // Type constraint is the assertion.
}

/// Compile-time Sendable type witness; body intentionally empty.
private func requireSendableType<T: Sendable>(_: T.Type) {
    // Type constraint is the assertion.
}

private final class WeakReference<Value: AnyObject> {
    weak var value: Value?

    init(_ value: Value?) {
        self.value = value
    }
}
