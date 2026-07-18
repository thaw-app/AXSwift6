import Cocoa
import os

/// Shared logger for the library's diagnostic output. Kept at `.debug`/`.error`
/// so it stays out of the default console unless the user opts in, rather than
/// writing unconditionally to stdout.
let axLog = Logger(subsystem: "AXSwift6", category: "AXSwift6")

@discardableResult
public func checkIsProcessTrusted(prompt: Bool = false) -> Bool {
    let opts = ["AXTrustedCheckOptionPrompt": prompt] as CFDictionary
    return AXIsProcessTrustedWithOptions(opts)
}
