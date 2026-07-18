import Cocoa
import Foundation

extension UIElement {
// MARK: - Attributes

/// Returns the list of all attributes.
///
/// Does not include parameterized attributes.
public func attributes() throws -> [Attribute] {
    let attrs = try attributesAsStrings()
    for attr in attrs where Attribute(rawValue: attr) == nil {
        axLog.debug("Unrecognized attribute: \(attr, privacy: .public)")
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
func fetchMultiAttrValues(_ attributes: [String]) throws -> [AnyObject] {
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
func packMultiAttrValues<Attr>(_ attributes: [Attr],
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
func checkMultiAttrValue(_ value: AnyObject) throws -> Bool {
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

}
