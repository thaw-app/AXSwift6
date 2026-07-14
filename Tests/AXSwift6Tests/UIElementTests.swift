import ApplicationServices
import AXSwift6
import Testing

@Suite("UIElement")
struct UIElementTests {
    @Test("Trust helpers agree for the current process")
    func trustHelpersAgreeForCurrentProcess() {
        #expect(checkIsProcessTrusted() == UIElement.isProcessTrusted())
        #expect(checkIsProcessTrusted(prompt: false) == UIElement.isProcessTrusted(withPrompt: false))
    }

    @Test("pid() returns the current process ID")
    func pidReturnsCurrentProcessID() throws {
        #expect(try TestFixtures.currentApplication().pid() == getpid())
    }

    @Test("role() reports application for the current process element when readable")
    func roleReportsApplicationForCurrentProcessElementWhenReadable() throws {
        do {
            #expect(try TestFixtures.currentApplication().role() == .application)
        } catch let error as AXError {
            #expect(TestFixtures.acceptableAttributeErrors.contains(error))
        }
    }

    @Test("description includes the process ID")
    func descriptionIncludesProcessID() {
        let description = TestFixtures.currentApplication().description
        #expect(description.contains("pid=\(getpid())"))
    }

    @Test("inspect returns a diagnostic string")
    func inspectReturnsDiagnosticString() {
        #expect(!TestFixtures.currentApplication().inspect.isEmpty)
    }

    @Test("Distinct system-wide handles are equal")
    func distinctSystemWideHandlesAreEqual() {
        let first = systemWideElement
        let second = UIElement(AXUIElementCreateSystemWide())
        #expect(first == second)
    }

    @Test("systemWideElement messaging timeout can be set")
    func systemWideElementMessagingTimeoutCanBeSet() throws {
        try systemWideElement.setMessagingTimeout(0.05)
        #expect(systemWideElement.currentMessagingTimeout == 0.05)
        try systemWideElement.setMessagingTimeout(0)
    }

    @Test("Unknown attribute returns nil or a documented AXError")
    func unknownAttributeReturnsNilOrDocumentedError() throws {
        do {
            let value: String? = try TestFixtures.currentApplication()
                .attribute("AXDefinitelyNotARealAttribute_xyz")
            #expect(value == nil)
        } catch let error as AXError {
            #expect(TestFixtures.acceptableAttributeErrors.contains(error))
        }
    }

    @Test("Type-mismatched attribute throws illegalArgument when readable")
    func typeMismatchedAttributeThrowsIllegalArgumentWhenReadable() {
        do {
            let _: Int? = try TestFixtures.currentApplication().attribute(.role)
            Issue.record("Expected AXError.illegalArgument when the role attribute is readable")
        } catch let error as AXError {
            #expect(
                error == .illegalArgument
                    || TestFixtures.acceptableAttributeErrors.contains(error)
            )
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    @Test("arrayAttribute on a non-array attribute throws when readable")
    func arrayAttributeOnNonArrayAttributeThrowsWhenReadable() {
        do {
            let _: [String]? = try TestFixtures.currentApplication().arrayAttribute(.role)
            Issue.record("Expected an AXError when treating role as an array attribute")
        } catch let error as AXError {
            #expect(
                error == .illegalArgument
                    || TestFixtures.acceptableAttributeErrors.contains(error)
            )
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    @Test("getMultipleAttributes ignores missing names when readable")
    func getMultipleAttributesIgnoresMissingNamesWhenReadable() throws {
        do {
            let result = try TestFixtures.currentApplication().getMultipleAttributes([
                "AXRole",
                "AXNonexistentAttribute_xyz",
            ])
            if let role = result["AXRole"] as? String {
                #expect(role == Role.application.rawValue)
            }
            #expect(result["AXNonexistentAttribute_xyz"] == nil)
        } catch let error as AXError {
            #expect(TestFixtures.acceptableAttributeErrors.contains(error))
        }
    }

    @Test("attributes() returns names or throws for the current process")
    func attributesReturnsNamesOrThrows() throws {
        do {
            let names = try TestFixtures.currentApplication().attributes()
            #expect(!names.isEmpty)
            #expect(names.contains(.role))
        } catch let error as AXError {
            #expect(TestFixtures.acceptableAttributeErrors.contains(error))
        }
    }

    @Test("actions() returns a list or throws for the current process")
    func actionsReturnsListOrThrows() throws {
        do {
            let actions = try TestFixtures.currentApplication().actions()
            #expect(Set(actions.map(\.rawValue)).count == actions.count)
        } catch let error as AXError {
            #expect(TestFixtures.acceptableAttributeErrors.contains(error))
        }
    }

    @Test("attributeIsSupported reports role support when readable")
    func attributeIsSupportedReportsRoleSupportWhenReadable() throws {
        do {
            #expect(try TestFixtures.currentApplication().attributeIsSupported(.role))
        } catch let error as AXError {
            #expect(TestFixtures.acceptableAttributeErrors.contains(error))
        }
    }

    @Test("Zero messaging timeout resets tracked timeout")
    func zeroMessagingTimeoutResetsTrackedTimeout() throws {
        let element = TestFixtures.currentApplication()
        try element.setMessagingTimeout(0.25)
        #expect(element.currentMessagingTimeout == 0.25)
        try element.setMessagingTimeout(0)
        #expect(element.currentMessagingTimeout == 0)
    }

    @Test("Distinct application handles for the same PID are equal")
    func distinctApplicationHandlesForSamePIDAreEqual() {
        let first = TestFixtures.currentApplication()
        let second = TestFixtures.currentApplication()
        #expect(first == second)
    }
}
