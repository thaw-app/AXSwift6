import AppKit
import os

/// Optional synchronous breadcrumbs around the batch-result Foundation bridge.
/// The handler receives metadata only, never accessibility attribute values.
public enum AXBatchDiagnostics {
    private struct State {
        var handler: (@Sendable (String) -> Void)?
        var sequence: UInt64 = 0
    }

    private static let state = OSAllocatedUnfairLock(initialState: State())

    public static var handler: (@Sendable (String) -> Void)? {
        get { state.withLock { $0.handler } }
        set { state.withLock { $0.handler = newValue } }
    }

    static func begin(pid: pid_t, attributes: [String], result: CFArray?) -> (id: UInt64, handler: @Sendable (String) -> Void)? {
        let ticket = state.withLock { state -> (UInt64, @Sendable (String) -> Void)? in
            guard let handler = state.handler else { return nil }
            state.sequence &+= 1
            return (state.sequence, handler)
        }
        guard let (id, handler) = ticket else { return nil }
        let bundle = NSRunningApplication(processIdentifier: pid)?.bundleIdentifier ?? "unknown"
        let typeID = result.map { CFGetTypeID($0) }
        let count = result.flatMap { CFGetTypeID($0) == CFArrayGetTypeID() ? CFArrayGetCount($0) : nil }
        let names = attributes.prefix(16).map {
            String($0.prefix(80)).replacingOccurrences(of: "\n", with: " ").replacingOccurrences(of: "\r", with: " ")
        }.joined(separator: ",")
        handler("AXBatchBridge id=\(id) phase=before uptime=\(ProcessInfo.processInfo.systemUptime) ownerPID=\(pid) bundle=\(bundle) requested=\(attributes.count) attributes=\(names) resultType=\(typeID.map(String.init) ?? "nil") expectedType=\(CFArrayGetTypeID()) count=\(count.map(String.init) ?? "n/a")")
        return (id, handler)
    }
}
