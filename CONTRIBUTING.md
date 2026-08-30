# Contributing

SwiftAwesomeButton is an iOS-only Swift package with supported SwiftUI and UIKit
surfaces. Package behavior and tests belong in `Sources/SwiftAwesomeButton` and
`Tests/SwiftAwesomeButtonTests`. The `Examples/` source showcase is not an
automated test target.

## Supported validation environment

The hosted release-hardening gate uses macOS 26, Xcode 26.2, Swift 6.2, the iOS
26.2 Simulator SDK, and an iPhone 17 Pro simulator. The package manifest retains
Swift tools 5.10 and iOS 16 as its public compatibility floor. A local Xcode may
be used for development, but a toolchain difference must not be reported as the
hosted result.

## Before opening a pull request

Run the aggregate, non-publishing preflight from a clean tracked tree:

```sh
Scripts/release-preflight.sh
```

The clean-tree requirement matters: API-canary and source-archive checks use
`git archive HEAD`, so they must validate the exact reviewed commit rather than
an unstaged approximation. Before that final clean run, individual checks may be
used while iterating:

```sh
swift format lint --strict --recursive Sources Tests Package.swift

xcodebuild -scheme swift-awesome-button \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  test SWIFT_TREAT_WARNINGS_AS_ERRORS=YES

xcodebuild -scheme swift-awesome-button \
  -destination 'generic/platform=iOS Simulator' \
  build SWIFT_STRICT_CONCURRENCY=complete SWIFT_TREAT_WARNINGS_AS_ERRORS=YES

xcodebuild -scheme swift-awesome-button \
  -destination 'generic/platform=iOS Simulator' \
  build SWIFT_VERSION=6 SWIFT_STRICT_CONCURRENCY=complete \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES

Scripts/check-api-compatibility.sh
```

The aggregate also builds DocC with warnings as errors, verifies public symbol
documentation, exports informational `xccov` reports, validates SwiftPM product
boundaries, and runs the isolated API known-break canary. It never publishes,
tags, or modifies an API baseline.

Set `AWESOME_BUTTON_ARTIFACTS_DIR` when a caller needs to retain the result
bundle, coverage exports, DocC output, and manifest outside the repository:

```sh
AWESOME_BUTTON_ARTIFACTS_DIR=/absolute/output/path \
  Scripts/release-preflight.sh
```

`AWESOME_BUTTON_SIMULATOR_NAME` and `AWESOME_BUTTON_SIMULATOR_OS` may select an
installed simulator. CI supplies the pinned values explicitly.

## Public API changes

Do not regenerate or hand-edit the checked-in compiler baseline to make a diff
disappear. A deliberate public API change requires:

1. source and binary compatibility classification;
2. a changelog and migration explanation;
3. the behavior or architecture decision authorizing the change;
4. review of the compiler diff and, only when unavoidable, exact digester
   allowlist entries with removal conditions.

Raw compiler output is canonicalized by clearing only its machine-specific
`ABIRoot.tool_arguments`; exported ABI nodes are never filtered. See
[`API_COMPATIBILITY.md`](API_COMPATIBILITY.md). The baseline may only be
replaced in a separately reviewed task tied to an immutable release tag and
recorded Xcode, Swift, SDK, target, and checksum provenance.

## Documentation and performance

Every user-authored public symbol needs a meaningful documentation summary.
Exemptions, if genuinely necessary, use precise symbol identifiers and written
rationales in `DocumentationExemptions.json`; stale or broad exemptions fail.

Performance tests are reproducible evidence, not timing gates. Record hardware,
OS, toolchain, build mode, warmup, repetitions, median, and dispersion in
[`PERFORMANCE.md`](PERFORMANCE.md). Do not add a threshold or public performance
claim without stable repeated evidence and a separately reviewed policy.

## Runtime verification

Automated XCTest remains package-owned. VoiceOver, Switch Control, Full Keyboard
Access, RTL, large text, Reduce Motion, and haptics also require the manual
runtime evidence defined by the cross-platform parity review; unit coverage is
not a substitute for assistive-technology validation.
