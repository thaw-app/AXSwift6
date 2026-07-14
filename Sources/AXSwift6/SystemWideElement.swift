import Foundation
import Cocoa

/// A singleton for the system-wide element.
public let systemWideElement = SystemWideElement()

/// A `UIElement` for the system-wide accessibility element, which can be used to retrieve global,
/// application-inspecific parameters like the currently focused element.
public typealias SystemWideElement = UIElement

private extension UIElement {
    convenience init() {
        self.init(AXUIElementCreateSystemWide())
    }
}
