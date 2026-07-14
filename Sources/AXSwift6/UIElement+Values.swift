import Cocoa
import Foundation

extension UIElement {
// MARK: Attribute helpers

// Checks if the value is an AXValue and if so, unwraps it.
// If the value is an AXUIElement, wraps it in UIElement.
func unpackAXValue(_ value: AnyObject) -> Any {
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
func packAXValue(_ value: Any) -> AnyObject {
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

}
