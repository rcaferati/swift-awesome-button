# Changelog

All notable package changes are documented here. This file describes the
unreleased engineering-hardening work; it does not declare a release or change
the package version.

## Unreleased

### Added

- Package-owned regression coverage for callback freshness, cancellation,
  progress ownership, accessibility, Reduced Motion, layout, SwiftUI lifecycle,
  and the public UIKit controls.
- Public documentation for the complete exported SwiftUI and UIKit surface,
  plus a DocC catalog.
- An arm64 iOS Simulator compiler API baseline for the `v1.0.0` public surface,
  checksum validation, current-source comparison, and an isolated known-break
  canary.
- Package-only formatting, strict-concurrency, documentation, coverage,
  source-distribution, and release-preflight checks.

### Changed

- Live view configuration is no longer retained behind a lossy transition
  signature. Callbacks and rendered content follow the latest committed SwiftUI
  update while release and progress completion dependencies remain scoped to
  the transition that accepted them.
- Long holds without an `onLongPress` handler preserve ordinary tap activation.
- Disabled, busy, placeholder, removal, and ownership-loss transitions cancel
  active input deterministically.
- Auto width measures the one rendered content row, including `before`, label,
  `after`, padding, and border. The `extra` overlay does not determine intrinsic
  width.
- Public theme dimensions and pressed-overlay configuration now participate in
  rendering and sizing according to the documented precedence rules.
- `AwesomeButtonControl` and `ThemedButtonControl` remain supported public
  surfaces and now provide complete target-action, state, sizing, configuration,
  keyboard, and accessibility integration.
- Public state descriptions are localized; minimum targets, large text, RTL,
  assistive activation, and Reduce Motion use native Apple mechanisms while
  preserving logical state and callback ordering.
- Swift 5 strict-concurrency and Swift 6 diagnostic builds are warning-free with
  warnings treated as errors.

### Compatibility

- The public UIKit wrappers are retained. No UIKit removal or SwiftUI-only
  migration is planned by this work.
- Haptics remain an Apple-only extension. Their use does not alter shared button
  state, callbacks, or accessibility semantics.
- The compiler API comparison uses `v1.0.0` as its reviewed baseline. Seven
  exact defaulted-initializer expansions are allowlisted as source-compatible
  and ABI-breaking until the next immutable release baseline; all other API
  breakages fail.

Historical `v1.0.0` details remain in
[`RELEASE_NOTES_1.0.0.md`](RELEASE_NOTES_1.0.0.md).
