# API Compatibility

`API/SwiftAwesomeButton-v1.0.0-arm64-apple-ios-simulator.json` is the reviewed compiler API baseline for the package's `v1.0.0` tag (`c296ea3d3167fec16eae45c749124f832359b702`). The baseline is single-architecture so concurrent arm64/x86_64 compiler jobs cannot corrupt one output file. `Scripts/normalize-api-baseline.swift` clears only `ABIRoot.tool_arguments`, which contains machine-specific DerivedData and output paths rather than exported API; tag, toolchain, SDK, target, and checksum provenance remain recorded here and in the hosted candidate artifact.

## Provenance

- Source: immutable `v1.0.0` Git archive
- Target: `arm64-apple-ios16.0-simulator`
- Local generation evidence: Xcode 26.0.1 (`17A400`), Apple Swift 6.2 (`swiftlang-6.2.0.19.9`), iOS Simulator SDK 26.0
- Required release/CI comparison: Xcode 26.2, Swift 6.2, iOS Simulator SDK 26.2 on `macos-26`
- SHA-256: `f862d4b216ee22b37b622eee3bfecf68b10ade57285b50c06a2130fd62416256`
- Sidecar: `API/SwiftAwesomeButton-v1.0.0-arm64-apple-ios-simulator.json.sha256`

The local baseline makes the gate executable before the first hosted run. It is not pinned-toolchain completion evidence: the first hosted Xcode 26.2 run must regenerate the same tag baseline as a review artifact, record its checksum, and replace this baseline in a separately reviewed commit if the compiler representation differs. Until then, hosted baseline provenance remains pending.

## Generation

From an isolated checkout of `v1.0.0`, run:

```sh
xcodebuild -scheme swift-awesome-button \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath <temporary-directory>/baseline-derived-data \
  clean build \
  ONLY_ACTIVE_ARCH=YES \
  ARCHS=arm64 \
  OTHER_SWIFT_FLAGS='$(inherited) -emit-digester-baseline-path <absolute-output-path>'
```

Canonicalize the raw compiler result, validate it before installation, compute
its sidecar, and review the complete diff:

```sh
swift Scripts/normalize-api-baseline.swift <absolute-output-path>
swift Scripts/validate-api-baseline.swift <absolute-output-path>
```

CI generates a candidate in runner-temporary storage and never rewrites the
checked baseline.

## Comparison policy

`Scripts/check-api-compatibility.sh` validates the JSON and checksum before invoking the compiler comparison. `Scripts/test-api-compatibility-gate.sh` proves the gate by restricting `AwesomeButtonStyle.merge` in an isolated clean-tree archive: the mutated library must compile normally and then fail for an API-digester diagnostic naming that declaration.

## Reviewed compatibility allowlist

`api-breakage-allowlist.txt` contains seven exact compiler diagnostics. It has no
wildcards and is validated for empty, malformed, or duplicate rows before every
comparison. All seven describe defaulted initializer expansion: existing source
call expressions remain valid because the added parameters have defaults, but
the old mangled initializer entry points are not binary-compatible. SwiftPM
consumers rebuild this source package; no prebuilt binary compatibility is
claimed.

| ID / exact allowlist row | Authorized change | Compatibility and migration | Removal condition |
| --- | --- | --- | --- |
| `SWI-ABI-01`, line 1: string-child `AwesomeButton.init` | Pass 3 accessibility parameters | Source-compatible defaulted `accessibilityLabel`, `accessibilityHint`, and `accessibilityLongPressLabel`; ABI-breaking initializer replacement. Existing calls require no migration. | Reset after the next immutable release tag establishes this initializer as baseline. |
| `SWI-ABI-02`, line 2: generic-label `AwesomeButton.init` | Pass 3 accessibility parameters | Same classification and no-call-site migration as `SWI-ABI-01`. | Same next-release baseline reset. |
| `SWI-ABI-03`, line 3: `AwesomeButtonControl.init` | Pass 2 supported UIKit integration and Pass 3 accessibility | Source-compatible defaulted accessibility expansion; ABI-breaking initializer replacement. Existing UIKit calls require no migration. | Same next-release baseline reset. |
| `SWI-ABI-04`, line 4: `AwesomeButtonStyle.init` | Pass 4 physical-corner parity | Source-compatible defaulted physical-corner fields; ABI-breaking initializer replacement. Existing style construction requires no migration. | Same next-release baseline reset. |
| `SWI-ABI-05`, line 5: string-child `ThemedButton.init` | Pass 3 accessibility parameters | Source-compatible defaulted accessibility expansion; ABI-breaking initializer replacement. Existing calls require no migration. | Same next-release baseline reset. |
| `SWI-ABI-06`, line 6: generic-label `ThemedButton.init` | Pass 3 accessibility parameters | Same classification and no-call-site migration as `SWI-ABI-05`. | Same next-release baseline reset. |
| `SWI-ABI-07`, line 7: `ThemedButtonControl.init` | Pass 2 supported UIKit integration and Pass 3 accessibility | Source-compatible defaulted accessibility expansion; ABI-breaking initializer replacement. Existing UIKit calls require no migration. | Same next-release baseline reset. |

The compiler report and this review are also summarized in `CHANGELOG.md`.
Adding, broadening, or regenerating an allowlist row requires a separate review
that updates this table. CI never creates the allowlist.
