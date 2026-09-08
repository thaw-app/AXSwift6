import ApplicationServices
import Testing
@testable import AXSwift6

/// Pins the shapes a batched read hands back.
///
/// These go through the unpacking directly rather than through a live element,
/// because the interesting cases are about which Core Foundation type came back
/// rather than about what any particular app answered, and a test runner
/// without Accessibility trust cannot read a real attribute at all.
@Suite("Batched attribute values")
struct AttributeValuesTests {
    private let element = UIElement(AXUIElementCreateApplication(getpid()))

    @Test("Children arrive as UIElement, the way arrayAttribute hands them back")
    func childrenPackAsUIElement() {
        let children: [AnyObject] = [
            AXUIElementCreateApplication(getpid()),
            AXUIElementCreateSystemWide(),
        ]

        // Through the packing the read itself uses, so a call site that stops
        // mapping the array is caught here rather than at a cast that fails
        // silently in front of a user.
        let packed = element.packAttributeValues([.children], values: [children as AnyObject])

        #expect((packed[.children] as? [UIElement])?.count == 2)
    }

    @Test("An absent attribute is missing rather than present and empty")
    func absentAttributeIsOmitted() {
        var error = AXError.noValue
        let noValue = AXValueCreate(AXValueType(rawValue: kAXValueAXErrorType)!, &error)!

        let packed = element.packAttributeValues(
            [.title, .identifier],
            values: [noValue as AnyObject, "thaw.item" as NSString]
        )

        #expect(packed[.title] == nil)
        #expect(packed[.identifier] as? String == "thaw.item")
    }

    @Test("One failed attribute does not cost the others")
    func oneFailureKeepsTheRest() {
        var error = AXError.cannotComplete
        let failure = AXValueCreate(AXValueType(rawValue: kAXValueAXErrorType)!, &error)!
        var rect = CGRect(x: 5, y: 6, width: 7, height: 8)
        let frame = AXValueCreate(AXValueType(rawValue: kAXValueCGRectType)!, &rect)!

        let packed = element.packAttributeValues(
            [.title, .frame],
            values: [failure as AnyObject, frame as AnyObject]
        )

        #expect(packed[.title] == nil)
        #expect(packed[.frame] as? CGRect == rect)
    }

    @Test("A wrapped rect still unpacks to CGRect")
    func rectUnpacksToCGRect() {
        var rect = CGRect(x: 1, y: 2, width: 3, height: 4)
        let value = AXValueCreate(AXValueType(rawValue: kAXValueCGRectType)!, &rect)!

        let unpacked = element.unpackAXValueOrArray(value as AnyObject)

        #expect(unpacked as? CGRect == rect)
    }

    @Test("A plain value passes through untouched")
    func plainValuePassesThrough() {
        let unpacked = element.unpackAXValueOrArray("Wi-Fi" as NSString)

        #expect(unpacked as? String == "Wi-Fi")
    }

    @Test("An array of plain values keeps its element type")
    func arrayOfPlainValuesKeepsElementType() {
        let raw: [AnyObject] = ["a" as NSString, "b" as NSString]

        let unpacked = element.unpackAXValueOrArray(raw as AnyObject)

        #expect(unpacked as? [String] == ["a", "b"])
    }
}
