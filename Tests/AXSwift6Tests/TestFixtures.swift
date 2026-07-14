import ApplicationServices
import AXSwift6
import Testing

enum TestFixtures {
    static func currentApplication() -> UIElement {
        UIElement(AXUIElementCreateApplication(getpid()))
    }

    static func currentApplicationOrSkip() throws -> Application {
        try #require(Application(forKnownProcessID: getpid()))
    }

    /// AX errors commonly returned when the test runner lacks Accessibility trust.
    static let acceptableAttributeErrors: Set<AXError> = [
        .apiDisabled,
        .cannotComplete,
        .failure,
        .notImplemented,
        .invalidUIElement,
        .attributeUnsupported,
        .illegalArgument,
    ]

    static let acceptableNotificationErrors: Set<AXError> = [
        .notificationUnsupported,
        .invalidUIElement,
        .apiDisabled,
        .cannotComplete,
        .failure,
        .notImplemented,
    ]
}
