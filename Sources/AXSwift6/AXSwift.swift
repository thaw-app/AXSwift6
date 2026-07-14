import Cocoa

@discardableResult
public func checkIsProcessTrusted(prompt: Bool = false) -> Bool {
    let opts = ["AXTrustedCheckOptionPrompt": prompt] as CFDictionary
    return AXIsProcessTrustedWithOptions(opts)
}
