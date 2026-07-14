import Cocoa
import Foundation

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
public func == (lhs: UIElement, rhs: UIElement) -> Bool {
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
