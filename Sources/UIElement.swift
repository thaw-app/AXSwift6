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

    private var nativeElementDescription: String {
        storage.withLock { String(describing: $0.element) }
    }

    private func withNativeElements<Result>(
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

    fileprivate func isEqual(to other: UIElement) -> Bool {
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

    // MARK: - Attributes

    /// Returns the list of all attributes.
    ///
    /// Does not include parameterized attributes.
    public func attributes() throws -> [Attribute] {
        let attrs = try attributesAsStrings()
        for attr in attrs where Attribute(rawValue: attr) == nil {
            print("Unrecognized attribute: \(attr)")
        }
        return attrs.compactMap({ Attribute(rawValue: $0) })
    }

    // This version is named differently so the caller doesn't have to specify the return type when
    // using the enum version.
    public func attributesAsStrings() throws -> [String] {
        var names: CFArray?
        let error = withNativeElement {
            AXUIElementCopyAttributeNames($0, &names)
        }

        if error == .noValue || error == .attributeUnsupported {
            return []
        }

        guard error == .success else {
            throw error
        }

        // We must first convert the CFArray to a native array, then downcast to an array of
        // strings.
        return names! as [AnyObject] as! [String]
    }

    /// Returns whether `attribute` is supported by this element.
    ///
    /// The `attribute` method returns nil for unsupported attributes and empty attributes alike,
    /// which is more convenient than dealing with exceptions (which are used for more serious
    /// errors). However, if you'd like to specifically test an attribute is actually supported, you
    /// can use this method.
    public func attributeIsSupported(_ attribute: Attribute) throws -> Bool {
        return try attributeIsSupported(attribute.rawValue)
    }

    public func attributeIsSupported(_ attribute: String) throws -> Bool {
        // Ask to copy 0 values, since we are only interested in the return code.
        var value: CFArray?
        let error = withNativeElement {
            AXUIElementCopyAttributeValues($0, attribute as CFString, 0, 0, &value)
        }

        if error == .attributeUnsupported {
            return false
        }

        if error == .noValue {
            return true
        }

        guard error == .success else {
            throw error
        }

        return true
    }

    /// Returns whether `attribute` is writeable.
    public func attributeIsSettable(_ attribute: Attribute) throws -> Bool {
        return try attributeIsSettable(attribute.rawValue)
    }

    public func attributeIsSettable(_ attribute: String) throws -> Bool {
        var settable: DarwinBoolean = false
        let error = withNativeElement {
            AXUIElementIsAttributeSettable($0, attribute as CFString, &settable)
        }

        if error == .noValue || error == .attributeUnsupported {
            return false
        }

        guard error == .success else {
            throw error
        }

        return settable.boolValue
    }

    /// Returns the value of `attribute`, if it exists.
    ///
    /// - parameter attribute: The name of a (non-parameterized) attribute.
    ///
    /// - returns: An optional containing the value of `attribute` as the desired type, or nil.
    ///            If `attribute` is an array, all values are returned.
    ///
    /// - throws: `AXError.illegalArgument` if the attribute cannot be converted to the requested
    ///           type. If you want to inspect the raw return type, ask for `Any`.
    public func attribute<T>(_ attribute: Attribute) throws -> T? {
        return try self.attribute(attribute.rawValue)
    }

    public func attribute<T>(_ attribute: String) throws -> T? {
        var value: AnyObject?
        let error = withNativeElement {
            AXUIElementCopyAttributeValue($0, attribute as CFString, &value)
        }

        if error == .noValue || error == .attributeUnsupported {
            return nil
        }

        guard error == .success else {
            throw error
        }

        guard let unpackedValue = (unpackAXValue(value!) as? T) else {
            throw AXError.illegalArgument
        }
        
        return unpackedValue
    }

    /// Sets the value of `attribute` to `value`.
    ///
    /// - warning: Unlike read-only methods, this method throws if the attribute doesn't exist.
    ///
    /// - throws:
    ///   - `Error.AttributeUnsupported`: `attribute` isn't supported.
    ///   - `Error.IllegalArgument`: `value` is an illegal value.
    ///   - `Error.Failure`: A temporary failure occurred.
    public func setAttribute(_ attribute: Attribute, value: Any) throws {
        try setAttribute(attribute.rawValue, value: value)
    }

    public func setAttribute(_ attribute: String, value: Any) throws {
        if let elementValue = value as? UIElement {
            let error = withNativeElements(elementValue) {
                AXUIElementSetAttributeValue(
                    $0,
                    attribute as CFString,
                    $1
                )
            }
            guard error == .success else {
                throw error
            }
            return
        }

        let packedValue = packAXValue(value)
        let error = withNativeElement {
            AXUIElementSetAttributeValue($0, attribute as CFString, packedValue)
        }

        guard error == .success else {
            throw error
        }
    }

    /// Gets multiple attributes of the element at once.
    ///
    /// - parameter attributes: An array of attribute names. Nonexistent attributes are ignored.
    ///
    /// - returns: A dictionary mapping provided parameter names to their values. Parameters which
    ///            don't exist or have no value will be absent.
    ///
    /// - throws: If there are any errors other than .NoValue or .AttributeUnsupported, it will
    ///           throw the first one it encounters.
    ///
    /// - note: Presumably you would use this API for performance, though it's not explicitly
    ///         documented by Apple that there is actually a difference.
    public func getMultipleAttributes(_ names: Attribute...) throws -> [Attribute: Any] {
        return try getMultipleAttributes(names)
    }

    public func getMultipleAttributes(_ attributes: [Attribute]) throws -> [Attribute: Any] {
        let values = try fetchMultiAttrValues(attributes.map({ $0.rawValue }))
        return try packMultiAttrValues(attributes, values: values)
    }

    public func getMultipleAttributes(_ attributes: [String]) throws -> [String: Any] {
        let values = try fetchMultiAttrValues(attributes)
        return try packMultiAttrValues(attributes, values: values)
    }

    // Helper: Gets list of values
    fileprivate func fetchMultiAttrValues(_ attributes: [String]) throws -> [AnyObject] {
        var valuesCF: CFArray?
        let error = withNativeElement {
            AXUIElementCopyMultipleAttributeValues(
                $0,
                attributes as CFArray,
                // keep going on errors (particularly NoValue)
                AXCopyMultipleAttributeOptions(rawValue: 0),
                &valuesCF
            )
        }

        guard error == .success else {
            throw error
        }

        return valuesCF! as [AnyObject]
    }

    // Helper: Packs names, values into dictionary
    fileprivate func packMultiAttrValues<Attr>(_ attributes: [Attr],
                                               values: [AnyObject]) throws -> [Attr: Any] {
        var result = [Attr: Any]()
        for (index, attribute) in attributes.enumerated() {
            if try checkMultiAttrValue(values[index]) {
                result[attribute] = unpackAXValue(values[index])
            }
        }
        return result
    }

    // Helper: Checks if value is present and not an error (throws on nontrivial errors).
    fileprivate func checkMultiAttrValue(_ value: AnyObject) throws -> Bool {
        // Check for null
        if value is NSNull {
            return false
        }

        // Check for error
        if CFGetTypeID(value) == AXValueGetTypeID() &&
            AXValueGetType(value as! AXValue).rawValue == kAXValueAXErrorType {
            var error: AXError = AXError.success
            AXValueGetValue(value as! AXValue, AXValueType(rawValue: kAXValueAXErrorType)!, &error)

            assert(error != .success)
            if error == .noValue || error == .attributeUnsupported {
                return false
            } else {
                throw error
            }
        }

        return true
    }

    // MARK: Array attributes

    /// Returns all the values of the attribute as an array of the given type.
    ///
    /// - parameter attribute: The name of the array attribute.
    ///
    /// - throws: `Error.IllegalArgument` if the attribute isn't an array.
    public func arrayAttribute<T>(_ attribute: Attribute) throws -> [T]? {
        return try arrayAttribute(attribute.rawValue)
    }

    public func arrayAttribute<T>(_ attribute: String) throws -> [T]? {
        guard let value: Any = try self.attribute(attribute) else {
            return nil
        }
        guard let array = value as? [AnyObject] else {
            // For consistency with the other array attribute APIs, throw if it's not an array.
            throw AXError.illegalArgument
        }
        return array.map({ unpackAXValue($0) as! T })
    }

    /// Returns a subset of values from an array attribute.
    ///
    /// - parameter attribute: The name of the array attribute.
    /// - parameter startAtIndex: The index of the array to start taking values from.
    /// - parameter maxValues: The maximum number of values you want.
    ///
    /// - returns: An array of up to `maxValues` values starting at `startAtIndex`.
    ///   - The array is empty if `startAtIndex` is out of range.
    ///   - `nil` if the attribute doesn't exist or has no value.
    ///
    /// - throws: `Error.IllegalArgument` if the attribute isn't an array.
    public func valuesForAttribute<T: AnyObject>
    (_ attribute: Attribute, startAtIndex index: Int, maxValues: Int) throws -> [T]? {
        return try valuesForAttribute(attribute.rawValue, startAtIndex: index, maxValues: maxValues)
    }

    public func valuesForAttribute<T: AnyObject>
    (_ attribute: String, startAtIndex index: Int, maxValues: Int) throws -> [T]? {
        var values: CFArray?
        let error = withNativeElement {
            AXUIElementCopyAttributeValues(
                $0, attribute as CFString, index, maxValues, &values
            )
        }

        if error == .noValue || error == .attributeUnsupported {
            return nil
        }

        guard error == .success else {
            throw error
        }

        let array = values! as [AnyObject]
        return array.map({ unpackAXValue($0) as! T })
    }

    /// Returns the number of values an array attribute has.
    /// - returns: The number of values, or `nil` if `attribute` isn't an array (or doesn't exist).
    public func valueCountForAttribute(_ attribute: Attribute) throws -> Int? {
        return try valueCountForAttribute(attribute.rawValue)
    }

    public func valueCountForAttribute(_ attribute: String) throws -> Int? {
        var count: Int = 0
        let error = withNativeElement {
            AXUIElementGetAttributeValueCount($0, attribute as CFString, &count)
        }

        if error == .attributeUnsupported || error == .illegalArgument {
            return nil
        }

        guard error == .success else {
            throw error
        }

        return count
    }

    // MARK: Parameterized attributes

    /// Returns a list of all parameterized attributes of the element.
    ///
    /// Parameterized attributes are attributes that require parameters to retrieve. For example,
    /// the cell contents of a spreadsheet might require the row and column of the cell you want.
    public func parameterizedAttributes() throws -> [Attribute] {
        return try parameterizedAttributesAsStrings().compactMap({ Attribute(rawValue: $0) })
    }

    public func parameterizedAttributesAsStrings() throws -> [String] {
        var names: CFArray?
        let error = withNativeElement {
            AXUIElementCopyParameterizedAttributeNames($0, &names)
        }

        if error == .noValue || error == .attributeUnsupported {
            return []
        }

        guard error == .success else {
            throw error
        }

        // We must first convert the CFArray to a native array, then downcast to an array of
        // strings.
        return names! as [AnyObject] as! [String]
    }

    /// Returns the value of the parameterized attribute `attribute` with parameter `param`.
    ///
    /// The expected type of `param` depends on the attribute. See the
    /// [NSAccessibility Informal Protocol Reference](https://developer.apple.com/library/mac/documentation/Cocoa/Reference/ApplicationKit/Protocols/NSAccessibility_Protocol/)
    /// for more info.
    public func parameterizedAttribute<T, U>(_ attribute: Attribute, param: U) throws -> T? {
        return try parameterizedAttribute(attribute.rawValue, param: param)
    }

    public func parameterizedAttribute<T, U>(_ attribute: String, param: U) throws -> T? {
        var value: AnyObject?
        let error = withNativeElement {
            AXUIElementCopyParameterizedAttributeValue(
                $0, attribute as CFString, param as AnyObject, &value
            )
        }

        if error == .noValue || error == .attributeUnsupported {
            return nil
        }

        guard error == .success else {
            throw error
        }

        return (unpackAXValue(value!) as! T)
    }

    // MARK: Attribute helpers

    // Checks if the value is an AXValue and if so, unwraps it.
    // If the value is an AXUIElement, wraps it in UIElement.
    fileprivate func unpackAXValue(_ value: AnyObject) -> Any {
        switch CFGetTypeID(value) {
        case AXUIElementGetTypeID():
            return UIElement(value as! AXUIElement)
        case AXValueGetTypeID():
            let type = AXValueGetType(value as! AXValue)
            switch type {
            case .axError:
                var result: AXError = .success
                let success = AXValueGetValue(value as! AXValue, type, &result)
                assert(success)
                return result
            case .cfRange:
                var result: CFRange = CFRange()
                let success = AXValueGetValue(value as! AXValue, type, &result)
                assert(success)
                return result
            case .cgPoint:
                var result: CGPoint = CGPoint.zero
                let success = AXValueGetValue(value as! AXValue, type, &result)
                assert(success)
                return result
            case .cgRect:
                var result: CGRect = CGRect.zero
                let success = AXValueGetValue(value as! AXValue, type, &result)
                assert(success)
                return result
            case .cgSize:
                var result: CGSize = CGSize.zero
                let success = AXValueGetValue(value as! AXValue, type, &result)
                assert(success)
                return result
            case .illegal:
                return value
            @unknown default:
                return value
            }
        default:
            return value
        }
    }

    // Checks if the value is one supported by AXValue and if so, wraps it.
    // If the value is a UIElement, unwraps it to an AXUIElement.
    fileprivate func packAXValue(_ value: Any) -> AnyObject {
        switch value {
        case var val as CFRange:
            return AXValueCreate(AXValueType(rawValue: kAXValueCFRangeType)!, &val)!
        case var val as CGPoint:
            return AXValueCreate(AXValueType(rawValue: kAXValueCGPointType)!, &val)!
        case var val as CGRect:
            return AXValueCreate(AXValueType(rawValue: kAXValueCGRectType)!, &val)!
        case var val as CGSize:
            return AXValueCreate(AXValueType(rawValue: kAXValueCGSizeType)!, &val)!
        default:
            return value as AnyObject // must be an object to pass to AX
        }
    }

    // MARK: - Actions

    /// Returns a list of actions that can be performed on the element.
    public func actions() throws -> [Action] {
        return try actionsAsStrings().compactMap({ Action(rawValue: $0) })
    }

    public func actionsAsStrings() throws -> [String] {
        var names: CFArray?
        let error = withNativeElement {
            AXUIElementCopyActionNames($0, &names)
        }

        if error == .noValue || error == .attributeUnsupported {
            return []
        }

        guard error == .success else {
            throw error
        }

        // We must first convert the CFArray to a native array, then downcast to an array of strings.
        return names! as [AnyObject] as! [String]
    }

    /// Returns the human-readable description of `action`.
    public func actionDescription(_ action: Action) throws -> String? {
        return try actionDescription(action.rawValue)
    }

    public func actionDescription(_ action: String) throws -> String? {
        var description: CFString?
        let error = withNativeElement {
            AXUIElementCopyActionDescription($0, action as CFString, &description)
        }

        if error == .noValue || error == .actionUnsupported {
            return nil
        }

        guard error == .success else {
            throw error
        }

        return description! as String
    }

    /// Performs the action `action` on the element, returning on success.
    ///
    /// - note: If the action times out, it might mean that the application is taking a long time to
    ///         actually perform the action. It doesn't necessarily mean that the action wasn't
    ///         performed.
    /// - throws: `Error.ActionUnsupported` if the action is not supported.
    public func performAction(_ action: Action) throws {
        try performAction(action.rawValue)
    }

    public func performAction(_ action: String) throws {
        let error = withNativeElement {
            AXUIElementPerformAction($0, action as CFString)
        }

        guard error == .success else {
            throw error
        }
    }

    // MARK: -

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

    // TODO: convenience functions for attributes
    // TODO: get any attribute as a UIElement or [UIElement] (or a subclass)
    // TODO: promoters
}

// MARK: - CustomStringConvertible

extension UIElement: CustomStringConvertible {
    public var description: String {
        var roleString: String
        var description: String?
        let pid = try? self.pid()
        do {
            let role = try self.role()
            roleString = role?.rawValue ?? "UIElementNoRole"

            switch role {
            case .some(.application):
                description = pid
                    .flatMap { NSRunningApplication(processIdentifier: $0) }
                    .flatMap { $0.bundleIdentifier } ?? ""
            case .some(.window):
                description = (try? attribute(.title) ?? "") ?? ""
            default:
                break
            }
        } catch AXError.invalidUIElement {
            roleString = "InvalidUIElement"
        } catch {
            roleString = "UnknownUIElement"
        }

        let pidString = (pid == nil) ? "??" : String(pid!)
        return "<\(roleString) \""
             + "\(description ?? nativeElementDescription)"
             + "\" (pid=\(pidString))>"
    }

    public var inspect: String {
        guard let attributeNames = try? attributes() else {
            return "InvalidUIElement"
        }
        guard let attributes = try? getMultipleAttributes(attributeNames) else {
            return "InvalidUIElement"
        }
        return "\(attributes)"
    }
}

// MARK: - Equatable

extension UIElement: Equatable {}
public func ==(lhs: UIElement, rhs: UIElement) -> Bool {
    lhs.isEqual(to: rhs)
}

// MARK: - Convenience getters

extension UIElement {
    /// Returns the role (type) of the element, if it reports one.
    ///
    /// Almost all elements report a role, but this could return nil for elements that aren't
    /// finished initializing.
    ///
    /// - seeAlso: [Roles](https://developer.apple.com/library/mac/documentation/AppKit/Reference/NSAccessibility_Protocol_Reference/index.html#//apple_ref/doc/constant_group/Roles)
    public func role() throws -> Role? {
        // should this be non-optional?
        if let str: String = try self.attribute(.role) {
            return Role(rawValue: str)
        } else {
            return nil
        }
    }

    /// - seeAlso: [Subroles](https://developer.apple.com/library/mac/documentation/AppKit/Reference/NSAccessibility_Protocol_Reference/index.html#//apple_ref/doc/constant_group/Subroles)
    public func subrole() throws -> Subrole? {
        if let str: String = try self.attribute(.subrole) {
            return Subrole(rawValue: str)
        } else {
            return nil
        }
    }
}
