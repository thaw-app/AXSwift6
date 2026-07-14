import Cocoa
import Foundation

extension UIElement {
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

}
