# Performance Evidence

Performance evidence is informational. It has no pull-request threshold and is
not a product-speed claim.

## Configuration and hosted-layout baseline

Captured on 2026-08-30 with:

- hardware: 14-core Apple M3 Max, 36 GB memory;
- host: macOS 26.6.2;
- toolchain: Xcode 26.0.1 (`17A400`), Apple Swift 6.2;
- runtime: iPhone 17 Pro, iOS 26.0 Simulator;
- build: Swift package Debug XCTest;
- test:
  `PerformanceBaselineTests.testRapidConfigurationAndHostedLayoutBenchmark`;
- scenario: repeatedly replace direct-button content and configuration, host the
  public UIKit surface in a test `UIWindow`, and force layout through the public
  view lifecycle;
- warmup: 5 repetitions;
- recorded repetitions: 25;
- work per repetition: 40 configuration and hosted-layout updates;
- median: 15.441 ms per repetition;
- median absolute deviation: 0.374 ms.

Run only the deterministic-record test with:

```sh
xcodebuild -scheme swift-awesome-button \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:SwiftAwesomeButtonTests/PerformanceBaselineTests/testRapidConfigurationAndHostedLayoutBenchmark \
  test
```

The same package test target also contains an XCTest `measure` case for themed
configuration updates. XCTest-collected measurements may vary with simulator
and runner load and therefore remain diagnostic output only.

## Interpretation

The baseline exercises public configuration propagation, hosted layout, and
intrinsic-size invalidation. It does not model production animation frame rate,
energy use, memory pressure, real-device GPU behavior, or assistive-technology
cost. Those need dedicated Instruments or device evidence before an optimization
or external claim is justified.

Future comparisons should preserve the scenario and record their full
environment, median, and dispersion. A change is actionable only after a
repeatable regression is observed and observable behavior remains covered by
tests.
