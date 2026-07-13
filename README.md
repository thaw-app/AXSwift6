# AXSwift6

Fork of [stonerl/AXSwift](https://github.com/stonerl/AXSwift) for [Thaw](https://github.com/thaw-app) on macOS 27.

Thaw on macOS 26 continues to use the original `AXSwift` module; this package publishes a separate `AXSwift6` module so both can coexist.

AXSwift is a Swift wrapper for macOS's C-based accessibility client APIs. Working with these APIs is error-prone and a huge pain, so AXSwift makes everything easier:

- Modern API that's 100% Swift
- Explicit error handling
- Complete coverage of the underlying C API
- Better documentation than Apple's, which is pretty poor

This framework is intended as a basic wrapper, and doesn't keep any state or do any "magic". That's up to you!

## Requirements

- macOS 27+
- Swift 6.4 toolchain (package uses Swift 5 language mode)

## Using AXSwift6

In your `Package.swift`:

```swift
.package(url: "https://github.com/thaw-app/AXSwift6.git", from: "0.3.2"),
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
