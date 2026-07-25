import ApplicationServices
import Testing

@testable import AXSwift6

/// These tests mutate `UIElement.defaultMessagingTimeout`, which is process-global,
/// so they must not run alongside each other.
@Suite("DefaultMessagingTimeout", .serialized)
struct DefaultMessagingTimeoutTests {
    @Test("Opt-in: unset, new elements keep the system default")
    func isOptIn() {
        #expect(UIElement.defaultMessagingTimeout == 0)
        #expect(UIElement(AXUIElementCreateApplication(getpid())).currentMessagingTimeout == 0)
    }

    @Test("Negative values clamp to zero")
    func clampsNegativeValues() {
        defer { UIElement.defaultMessagingTimeout = 0 }

        UIElement.defaultMessagingTimeout = -5
        #expect(UIElement.defaultMessagingTimeout == 0)
    }

    @Test("Applied to newly created elements")
    func appliedToNewElements() {
        defer { UIElement.defaultMessagingTimeout = 0 }

        UIElement.defaultMessagingTimeout = 0.25
        // A fresh native reference, so this cannot reuse existing storage.
        let element = UIElement(AXUIElementCreateApplication(getpid()))
        #expect(element.currentMessagingTimeout == 0.25)
    }

    @Test("Does not retime elements that already have storage")
    func doesNotRetimeExistingStorage() {
        defer { UIElement.defaultMessagingTimeout = 0 }

        let native = AXUIElementCreateApplication(getpid())
        let first = UIElement(native)
        #expect(first.currentMessagingTimeout == 0)

        UIElement.defaultMessagingTimeout = 0.25
        // Same native reference: shares `first`'s storage, so it keeps that timeout.
        let second = UIElement(native)
        #expect(second.currentMessagingTimeout == 0)
        #expect(first.currentMessagingTimeout == 0)
    }
}
