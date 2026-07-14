import Cocoa
import Foundation
import os

/// Holds and interacts with any accessibility element.
///
/// This class wraps every operation that operates on AXUIElements.
///
/// - seeAlso: [OS X Accessibility Model](https://developer.apple.com/library/mac/documentation/Accessibility/Conceptual/AccessibilityMacOSX/OSXAXmodel.html)
///
/// Note that every operation involves IPC and is tied to the event loop of the target process. This
/// means that operations are synchronous and can hang until they time out. The default timeout is
/// 6 seconds, but it can be changed using `setMessagingTimeout(_:)` or the deprecated
/// `globalMessagingTimeout` property.
///
/// Every attribute- or action-related function has an enum version and a String version. This is
/// because certain processes might report attributes or actions not documented in the standard API.
/// These will be ignored by enum functions (and you can't specify them). Most users will want to
/// use the enum-based versions, but if you want to be exhaustive or use non-standard attributes and
/// actions, you can use the String versions.
///
/// ### Error handling
///
/// Unless otherwise specified, during reads, "missing data/attribute" errors are handled by
/// returning optionals as nil. During writes, missing attribute errors are thrown.
///
/// Other failures are all thrown, including if messaging fails or the underlying AXUIElement
/// becomes invalid.
///
/// #### Possible Errors
/// - `Error.APIDisabled`: The accessibility API is disabled. Your application must request and
///                        receive special permission from the user to be able to use these APIs.
/// - `Error.InvalidUIElement`: The UI element has become invalid, perhaps because it was destroyed.
/// - `Error.CannotComplete`: There is a problem with messaging, perhaps because the application is
///                           being unresponsive. This error will be thrown when a message times
///                           out.
/// - `Error.NotImplemented`: The process does not fully support the accessibility API.
/// - Anything included in the docs of the method you are calling.
///
/// Any undocumented errors thrown are bugs and should be reported.
///
/// - seeAlso: [AXUIElement.h reference](https://developer.apple.com/library/mac/documentation/ApplicationServices/Reference/AXUIElement_header_reference/)
public final class UIElement: Sendable {
    private struct RawElementState {
        let element: AXUIElement
        var messagingTimeout: Float = 0
    }

    /// ApplicationServices does not annotate `AXUIElement` as `Sendable`.
    /// This storage is the package's single audited escape hatch: all mutable
    /// state is private, every access uses `lock`, no reference escapes the
    /// synchronous operation, and no lock is held across suspension.
    private final class Storage: @unchecked Sendable {
        private let lock = OSAllocatedUnfairLock()
        private var state: RawElementState

        init(element: AXUIElement) {
            state = RawElementState(element: element)
        }

        func withLock<Result>(
            _ operation: (inout RawElementState) throws -> Result
        ) rethrows -> Result {
            lock.lock()
            defer { lock.unlock() }
            return try operation(&state)
        }
    }

    private final class WeakStorage: @unchecked Sendable {
        weak var value: Storage?

        init(_ value: Storage) {
            self.value = value
        }
    }

    private struct StorageRegistryState {
        var entries = [ObjectIdentifier: WeakStorage]()
        var insertionsSinceCleanup = 0
    }

    private static let storageRegistry = OSAllocatedUnfairLock(
        initialState: StorageRegistryState()
    )

    private let storage: Storage

    /// Create a UIElement from a raw AXUIElement object.
    ///
    /// The state and role of the AXUIElement is not checked.
    public init(_ nativeElement: AXUIElement) {
        // Since we are dealing with low-level C APIs, it never hurts to double check types.
        assert(CFGetTypeID(nativeElement) == AXUIElementGetTypeID(),
               "nativeElement is not an AXUIElement")

        let key = ObjectIdentifier(nativeElement)
        let candidate = Storage(element: nativeElement)
        storage = Self.storageRegistry.withLock { registry in
            if let storage = registry.entries[key]?.value {
                return storage
            }
            registry.entries[key] = WeakStorage(candidate)
            registry.insertionsSinceCleanup += 1
            if registry.insertionsSinceCleanup >= 256 {
                registry.entries = registry.entries.filter { $0.value.value != nil }
                registry.insertionsSinceCleanup = 0
            }
            return candidate
        }
    }

    @inline(__always)
    func withNativeElement<Result>(
        _ operation: (AXUIElement) throws -> Result
    ) rethrows -> Result {
        try storage.withLock { state in
            try operation(state.element)
        }
    }

    var nativeElementDescription: String {
        storage.withLock { String(describing: $0.element) }
    }

    func withNativeElements<Result>(
        _ other: UIElement,
        operation: (AXUIElement, AXUIElement) throws -> Result
    ) rethrows -> Result {
        if self === other || storage === other.storage {
            return try withNativeElement { element in
                try operation(element, element)
            }
        }

        let selfAddress = UInt(bitPattern: ObjectIdentifier(storage))
        let otherAddress = UInt(bitPattern: ObjectIdentifier(other.storage))
        if selfAddress < otherAddress {
            return try withNativeElement { element in
                try other.withNativeElement {
                    try operation(element, $0)
                }
            }
        }
        return try other.withNativeElement { element in
            try withNativeElement {
                try operation($0, element)
            }
        }
    }

    func isEqual(to other: UIElement) -> Bool {
        withNativeElements(other, operation: CFEqual)
    }

    /// Checks if the current process is a trusted accessibility client. If false, all APIs will
    /// throw errors.
    ///
    /// - parameter withPrompt: Whether to show the user a prompt if the process is untrusted. This
    ///                         happens asynchronously and does not affect the return value.
    public class func isProcessTrusted(withPrompt showPrompt: Bool = false) -> Bool {
        let options = [
            "AXTrustedCheckOptionPrompt": showPrompt as CFBoolean
        ]
        return AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    /// Timeout in seconds for all UIElement messages. Use this to control how long a method call
    /// can delay execution. The default is `0` which means to use the system default.
    @available(*, deprecated, message: "Use systemWideElement.setMessagingTimeout(_:) so errors can be handled.")
    public class var globalMessagingTimeout: Float {
        get { return systemWideElement.currentMessagingTimeout }
        set { try? systemWideElement.setMessagingTimeout(newValue) }
    }

    /// Returns the process ID of the application that the element is a part of.
    ///
    /// Throws only if the element is invalid (`Errors.InvalidUIElement`).
    public func pid() throws -> pid_t {
        var pid: pid_t = -1
        let error = withNativeElement {
            AXUIElementGetPid($0, &pid)
        }

        guard error == .success else {
            throw error
        }

        return pid
    }

    /// The timeout in seconds for all messages sent to this element. Use this to control how long a
    /// method call can delay execution. The default is `0`, which means to use the global timeout.
    ///
    /// - note: Applies to this native handle and other wrappers created from the same native
    ///         reference, not merely elements that compare equal.
    /// - seeAlso: `UIElement.globalMessagingTimeout`
    @available(*, deprecated, message: "Use setMessagingTimeout(_:) so errors can be handled.")
    public var messagingTimeout: Float {
        get {
            currentMessagingTimeout
        }
        set {
            do {
                try setMessagingTimeout(newValue)
            } catch AXError.invalidUIElement {
                // Preserve AXSwift's compatibility behavior: this error only
                // matters when a message is actually sent to the element.
            } catch {
                assertionFailure("Unexpected error setting messaging timeout: \(error)")
            }
        }
    }

    /// The timeout most recently applied to this element by this handle.
    public var currentMessagingTimeout: Float {
        storage.withLock { $0.messagingTimeout }
    }

    /// Sets the timeout for messages sent to this element.
    ///
    /// Unlike the compatibility property setter, this method reports failures
    /// to the caller instead of terminating the process.
    public func setMessagingTimeout(_ timeout: Float) throws {
        let normalizedTimeout = max(timeout, 0)
        try storage.withLock { state in
            let error = AXUIElementSetMessagingTimeout(
                state.element,
                normalizedTimeout
            )
            guard error == .success else {
                throw error
            }
            state.messagingTimeout = normalizedTimeout
        }
    }

    // Gets the element at the specified coordinates.
    // This can only be called on applications and the system-wide element, so it is internal here.
    public func elementAtPosition(_ x: Float, _ y: Float) throws -> UIElement? {
        var result: AXUIElement?
        let error = withNativeElement {
            AXUIElementCopyElementAtPosition($0, x, y, &result)
        }

        if error == .noValue {
            return nil
        }

        guard error == .success else {
            throw error
        }

        return UIElement(result!)
    }

}
