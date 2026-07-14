import ApplicationServices
import AXSwift6
import Testing

@Suite("Error")
struct ErrorTests {
    @Test("AXError descriptions use the documented names", arguments: [
        (AXError.success, "AXError.Success"),
        (AXError.failure, "AXError.Failure"),
        (AXError.illegalArgument, "AXError.IllegalArgument"),
        (AXError.invalidUIElement, "AXError.InvalidUIElement"),
        (AXError.invalidUIElementObserver, "AXError.InvalidUIElementObserver"),
        (AXError.cannotComplete, "AXError.CannotComplete"),
        (AXError.attributeUnsupported, "AXError.AttributeUnsupported"),
        (AXError.actionUnsupported, "AXError.ActionUnsupported"),
        (AXError.notificationUnsupported, "AXError.NotificationUnsupported"),
        (AXError.notImplemented, "AXError.NotImplemented"),
        (AXError.notificationAlreadyRegistered, "AXError.NotificationAlreadyRegistered"),
        (AXError.notificationNotRegistered, "AXError.NotificationNotRegistered"),
        (AXError.apiDisabled, "AXError.APIDisabled"),
        (AXError.noValue, "AXError.NoValue"),
        (AXError.parameterizedAttributeUnsupported, "AXError.ParameterizedAttributeUnsupported"),
        (AXError.notEnoughPrecision, "AXError.NotEnoughPrecision"),
    ] as [(AXError, String)])
    func axErrorDescriptions(error: AXError, expected: String) {
        #expect(error.description == expected)
    }
}
