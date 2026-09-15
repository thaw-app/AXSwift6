import ApplicationServices
import os
import Testing
@testable import AXSwift6

@Suite(.serialized)
struct AXBatchDiagnosticsTests {
    @Test func recordsTypesWithoutBridgingOpaqueResultOrLoggingValues() {
        let messages = OSAllocatedUnfairLock(initialState: [String]())
        AXBatchDiagnostics.handler = { message in messages.withLock { $0.append(message) } }
        defer { AXBatchDiagnostics.handler = nil }

        let raw = AXUIElementCreateApplication(getpid())
        // Simulate a malformed AX reply without invoking Foundation's bridge.
        let malformed = unsafeBitCast(raw, to: CFArray.self)
        let ticket = AXBatchDiagnostics.begin(pid: getpid(), attributes: ["AXChildren"], result: malformed)
        #expect(ticket != nil)
        let logged = messages.withLock { $0.joined(separator: "\n") }
        #expect(logged.contains("resultType=\(AXUIElementGetTypeID())"))
        #expect(logged.contains("count=n/a"))

        let values = ["private-window-title"] as CFArray
        _ = AXBatchDiagnostics.begin(pid: getpid(), attributes: ["AXTitle"], result: values)
        #expect(messages.withLock { !$0.joined().contains("private-window-title") })
        #expect(messages.withLock { $0.last?.contains("count=1") == true })
    }
}
