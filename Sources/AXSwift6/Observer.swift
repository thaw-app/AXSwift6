import Cocoa
import Foundation
import Darwin
import os

/// Observers watch for events on an application's UI elements.
///
/// Events are received as part of the application's default run loop.
///
/// - seeAlso: `UIElement` for a list of exceptions that can be thrown.
public final class Observer: Sendable {
    public typealias Callback = @Sendable (_ observer: Observer,
                                           _ element: UIElement,
                                           _ notification: AXNotification) -> Void
    public typealias CallbackWithInfo = @Sendable (_ observer: Observer,
                                                   _ element: UIElement,
                                                   _ notification: AXNotification,
                                                   _ info: [String: AnyObject]?) -> Void

    private struct State {
        let axObserver: AXObserver
        let callback: Callback?
        let callbackWithInfo: CallbackWithInfo?
        let runLoop: CFRunLoop
        var isStarted = false
    }

    /// `AXObserver` and `CFRunLoop` are imported without Sendable annotations.
    /// They never escape this synchronized storage, and callbacks are copied
    /// out before client code is invoked.
    private final class Storage: @unchecked Sendable {
        private let lock = OSAllocatedUnfairLock()
        private var state: State

        init(state: State) {
            self.state = state
        }

        func withLock<Result>(
            _ operation: (inout State) throws -> Result
        ) rethrows -> Result {
            lock.lock()
            defer { lock.unlock() }
            return try operation(&state)
        }
    }

    public let pid: pid_t
    private let storage: Storage

    public var application: Application {
        Application(forKnownProcessID: pid)!
    }

    /// Creates and starts an observer on the given `processID`.
    public init(processID: pid_t, callback: @escaping Callback) throws {
        var axObserver: AXObserver?
        let error = AXObserverCreate(processID, internalCallback, &axObserver)

        guard error == .success else {
            throw error
        }
        guard let axObserver else {
            throw AXError.failure
        }

        pid = processID
        storage = Storage(
            state: State(
                axObserver: axObserver,
                callback: callback,
                callbackWithInfo: nil,
                runLoop: CFRunLoopGetCurrent()
            )
        )
        ObserverRegistry.register(self, for: axObserver)

        start()
    }

    /// Creates and starts an observer on the given `processID`.
    ///
    /// Use this initializer if you want the extra user info provided with notifications.
    /// - seeAlso: [UserInfo Keys for Posting Accessibility Notifications](https://developer.apple.com/library/mac/documentation/AppKit/Reference/NSAccessibility_Protocol_Reference/index.html#//apple_ref/doc/constant_group/UserInfo_Keys_for_Posting_Accessibility_Notifications)
    public init(processID: pid_t, callback: @escaping CallbackWithInfo) throws {
        var axObserver: AXObserver?
        let error = AXObserverCreateWithInfoCallback(processID, internalInfoCallback, &axObserver)

        guard error == .success else {
            throw error
        }
        guard let axObserver else {
            throw AXError.failure
        }

        pid = processID
        storage = Storage(
            state: State(
                axObserver: axObserver,
                callback: nil,
                callbackWithInfo: callback,
                runLoop: CFRunLoopGetCurrent()
            )
        )
        ObserverRegistry.register(self, for: axObserver)

        start()
    }

    deinit {
        stop()
        storage.withLock { ObserverRegistry.unregister($0.axObserver) }
    }

    /// Starts watching for events. You don't need to call this method unless you use `stop()`.
    ///
    /// If the observer has already been started, this method does nothing.
    public func start() {
        storage.withLock { state in
            guard !state.isStarted else { return }
            CFRunLoopAddSource(
                state.runLoop,
                AXObserverGetRunLoopSource(state.axObserver),
                CFRunLoopMode.defaultMode
            )
            state.isStarted = true
        }
    }

    /// Stops sending events to your callback until the next call to `start`.
    ///
    /// If the observer has already been started, this method does nothing.
    ///
    /// - important: Events will still be queued in the target process until the Observer is started
    ///              again or destroyed. If you don't want them, create a new Observer.
    public func stop() {
        storage.withLock { state in
            guard state.isStarted else { return }
            CFRunLoopRemoveSource(
                state.runLoop,
                AXObserverGetRunLoopSource(state.axObserver),
                CFRunLoopMode.defaultMode
            )
            state.isStarted = false
        }
    }

    /// Adds a notification for the observer to watch.
    ///
    /// - parameter notification: The name of the notification to watch for.
    /// - parameter forElement: The element to watch for the notification on. Must belong to the
    ///                         application this observer was created on.
    /// - seeAlso: [Notificatons](https://developer.apple.com/library/mac/documentation/AppKit/Reference/NSAccessibility_Protocol_Reference/index.html#//apple_ref/c/data/NSAccessibilityAnnouncementRequestedNotification)
    /// - note: The underlying API returns an error if the notification is already added, but that
    ///         error is not passed on for consistency with `start()` and `stop()`.
    /// - throws: `Error.NotificationUnsupported`: The element does not support notifications (note
    ///           that the system-wide element does not support notifications).
    public func addNotification(_ notification: AXNotification,
                                forElement element: UIElement) throws {
        let error = storage.withLock { state in
            element.withNativeElement {
                AXObserverAddNotification(
                    state.axObserver,
                    $0,
                    notification.rawValue as CFString,
                    nil
                )
            }
        }
        guard error == .success || error == .notificationAlreadyRegistered else {
            throw error
        }
    }

    /// Removes a notification from the observer.
    ///
    /// - parameter notification: The name of the notification to stop watching.
    /// - parameter forElement: The element to stop watching the notification on.
    /// - note: The underlying API returns an error if the notification is not present, but that
    ///         error is not passed on for consistency with `start()` and `stop()`.
    /// - throws: `Error.NotificationUnsupported`: The element does not support notifications (note
    ///           that the system-wide element does not support notifications).
    public func removeNotification(_ notification: AXNotification,
                                   forElement element: UIElement) throws {
        let error = storage.withLock { state in
            element.withNativeElement {
                AXObserverRemoveNotification(
                    state.axObserver,
                    $0,
                    notification.rawValue as CFString
                )
            }
        }
        guard error == .success || error == .notificationNotRegistered else {
            throw error
        }
    }

    fileprivate func deliver(_ element: UIElement, notification: AXNotification) {
        let callback = storage.withLock { $0.callback }
        callback?(self, element, notification)
    }

    fileprivate func deliver(_ element: UIElement,
                             notification: AXNotification,
                             info: [String: AnyObject]?) {
        let callback = storage.withLock { $0.callbackWithInfo }
        callback?(self, element, notification, info)
    }
}

private final class WeakObserver: @unchecked Sendable {
    weak var value: Observer?

    init(_ value: Observer) {
        self.value = value
    }
}

private enum ObserverRegistry {
    private static let observers = OSAllocatedUnfairLock(
        initialState: [ObjectIdentifier: WeakObserver]()
    )

    static func register(_ observer: Observer, for axObserver: AXObserver) {
        let key = ObjectIdentifier(axObserver)
        observers.withLock {
            $0[key] = WeakObserver(observer)
        }
    }

    static func unregister(_ axObserver: AXObserver) {
        let key = ObjectIdentifier(axObserver)
        _ = observers.withLock {
            $0.removeValue(forKey: key)
        }
    }

    static func observer(for axObserver: AXObserver) -> Observer? {
        let key = ObjectIdentifier(axObserver)
        return observers.withLock { registry -> Observer? in
            guard let observer = registry[key]?.value else {
                registry.removeValue(forKey: key)
                return nil
            }
            return observer
        }
    }
}

private func internalCallback(_ axObserver: AXObserver,
                              axElement: AXUIElement,
                              notification: CFString,
                              userData _: UnsafeMutableRawPointer?) {
    guard let observer = ObserverRegistry.observer(for: axObserver) else { return }
    let element = UIElement(axElement)
    guard let notif = AXNotification(rawValue: notification as String) else {
        NSLog("Unknown AX notification %s received", notification as String)
        return
    }
    observer.deliver(element, notification: notif)
}

private func internalInfoCallback(_ axObserver: AXObserver,
                                  axElement: AXUIElement,
                                  notification: CFString,
                                  cfInfo: CFDictionary,
                                  userData _: UnsafeMutableRawPointer?) {
    guard let observer = ObserverRegistry.observer(for: axObserver) else { return }
    let element = UIElement(axElement)
    let info = cfInfo as NSDictionary? as? [String: AnyObject]
    guard let notif = AXNotification(rawValue: notification as String) else {
        NSLog("Unknown AX notification %s received", notification as String)
        return
    }
    observer.deliver(element, notification: notif, info: info)
}
