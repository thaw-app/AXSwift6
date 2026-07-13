import ApplicationServices
import AXSwift6
import XCTest

final class ConcurrencyTests: XCTestCase {
    func testPublicHandlesAndConstantsAreSendable() {
        requireSendableType(UIElement.self)
        requireSendableType(Observer.self)
        requireSendable(systemWideElement)
        requireSendable(Role.menuBarItem)
        requireSendable(Subrole.standardWindow)
        requireSendable(Attribute.extrasMenuBar)
        requireSendable(Action.press)
        requireSendable(AXNotification.valueChanged)
    }

    func testIndependentHandlesKeepIndependentTimeoutState() throws {
        let first = UIElement(AXUIElementCreateApplication(getpid()))
        let second = UIElement(AXUIElementCreateApplication(getpid()))

        try first.setMessagingTimeout(0.1)
        try second.setMessagingTimeout(0.2)

        XCTAssertEqual(first.currentMessagingTimeout, 0.1)
        XCTAssertEqual(second.currentMessagingTimeout, 0.2)
    }

    func testWrappersForSameNativeReferenceShareSynchronizationState() throws {
        let nativeElement = AXUIElementCreateApplication(getpid())
        let first = UIElement(nativeElement)
        let second = UIElement(nativeElement)

        try first.setMessagingTimeout(0.1)
        XCTAssertEqual(second.currentMessagingTimeout, 0.1)

        try second.setMessagingTimeout(0.2)
        XCTAssertEqual(first.currentMessagingTimeout, 0.2)
        XCTAssertEqual(first, second)
        _ = try? first.setAttribute(.focusedUIElement, value: second)
    }

    func testMessagingTimeoutIsSerializedAcrossTasks() async throws {
        let element = UIElement(AXUIElementCreateApplication(getpid()))

        try await withThrowingTaskGroup(of: Void.self) { group in
            for index in 0 ..< 100 {
                group.addTask {
                    try element.setMessagingTimeout(index.isMultiple(of: 2) ? 0.1 : 0.2)
                }
            }
            try await group.waitForAll()
        }

        XCTAssertTrue(element.currentMessagingTimeout == 0.1 || element.currentMessagingTimeout == 0.2)
    }

    func testNegativeMessagingTimeoutIsNormalized() throws {
        let element = UIElement(AXUIElementCreateApplication(getpid()))

        try element.setMessagingTimeout(-1)

        XCTAssertEqual(element.currentMessagingTimeout, 0)
    }

    func testConcurrentReadsUseOneHandleSafely() async throws {
        let element = UIElement(AXUIElementCreateApplication(getpid()))

        try await withThrowingTaskGroup(of: pid_t.self) { group in
            for _ in 0 ..< 100 {
                group.addTask {
                    try element.pid()
                }
            }
            for try await pid in group {
                XCTAssertEqual(pid, getpid())
            }
        }
    }

    func testOrderedElementLockingDoesNotDeadlock() async {
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
                _ = first == first
            }
        }
    }

    func testObserverStartAndStopAreIdempotent() throws {
        let observer = try Observer(processID: getpid()) { _, _, _ in }

        observer.start()
        observer.start()
        observer.stop()
        observer.stop()
        observer.start()
        observer.stop()
    }

    func testObserverRegistryDoesNotExtendLifetime() throws {
        var observer: Observer? = try Observer(processID: getpid()) { _, _, _ in }
        let weakObserver = WeakReference(observer)

        observer = nil

        XCTAssertNil(weakObserver.value)
    }

    func testMenuBarItemRoleIsRecognized() {
        XCTAssertEqual(Role(rawValue: "AXMenuBarItem"), .menuBarItem)
    }

    private func requireSendable<T: Sendable>(_: T) {}
    private func requireSendableType<T: Sendable>(_: T.Type) {}
}

private final class WeakReference<Value: AnyObject> {
    weak var value: Value?

    init(_ value: Value?) {
        self.value = value
    }
}
