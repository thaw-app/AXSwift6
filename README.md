# AXSwift6

Fork of [stonerl/AXSwift](https://github.com/stonerl/AXSwift) for [Thaw](https://github.com/thaw-app) on modern macOS.

AXSwift6 is Thaw's concurrency-safe replacement for the original `AXSwift` module on macOS 26 and later. Accessibility handles are `Sendable`; the package serializes access to the underlying unannotated `AXUIElement` references.

AXSwift is a Swift wrapper for macOS's C-based accessibility client APIs. Working with these APIs is error-prone and a huge pain, so AXSwift makes everything easier:

- Modern API that's 100% Swift
- Explicit error handling
- Complete coverage of the underlying C API
- Better documentation than Apple's, which is pretty poor

This framework is intended as a focused wrapper and does not maintain an accessibility object model. It serializes access to each underlying accessibility handle so those handles can safely cross Swift concurrency domains. Beyond that synchronization, it only translates data types and error codes.

## Requirements

- macOS 26+
- Swift 6 toolchain

## Using AXSwift6

In your `Package.swift`:

```swift
.package(url: "https://github.com/thaw-app/AXSwift6.git", from: "0.4.0"),
```

Then add the product to your target:

```swift
.product(name: "AXSwift6", package: "AXSwift6"),
```

```swift
import AXSwift6
```

## Examples

Sample usage lives in [AXSwiftExample](AXSwiftExample/AppDelegate.swift) and [AXSwiftObserverExample](AXSwiftObserverExample/AppDelegate.swift) (not package targets).
