# Swift Awesome Button 1.1.0

Swift Awesome Button 1.1.0 makes interaction, progress, sizing, and text transitions more
predictable across SwiftUI and UIKit while expanding native accessibility and package-quality
coverage.

## Highlights

- Keeps callbacks and rendered content current across SwiftUI updates while preserving
  transition-scoped release and progress completion behavior.
- Strengthens cancellation, long-press handling, one-shot progress completion, Reduce Motion,
  Dynamic Type, RTL, keyboard, and assistive activation behavior.
- Stabilizes auto-width and label choreography and animates package-owned typography without stale
  frames, reversal, or overshoot.
- Retains complete `UIControl` target-action, state, sizing, configuration, keyboard, and
  accessibility integration.
- Adds compiler API, DocC, strict-concurrency, package-boundary, coverage, and regression gates.

## Compatibility

- SwiftUI and UIKit remain supported public surfaces.
- New initializer options are defaulted and source-compatible for SwiftPM consumers, which rebuild
  the package from source.
- Haptics remain an Apple-only extension without changing button state, callbacks, or accessibility
  semantics.

## Verification

- `Scripts/release-preflight.sh` — passed.
- 139 simulator tests and strict Swift 5 and Swift 6 builds — passed.
- Compiler API comparison and canary, 319/319 DocC coverage, formatting, and package-boundary checks
  — passed.

## Installation

```swift
.package(
  url: "https://github.com/rcaferati/swift-awesome-button.git",
  from: "1.1.0"
)
```

## Full Changelog

See [v1.0.0...v1.1.0](https://github.com/rcaferati/swift-awesome-button/compare/v1.0.0...v1.1.0).
