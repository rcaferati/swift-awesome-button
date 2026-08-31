import QuartzCore
import UIKit
import XCTest

@testable import SwiftAwesomeButton

@MainActor
final class PerformanceBaselineTests: XCTestCase {
  func testRapidConfigurationAndHostedLayoutBenchmark() {
    let control = AwesomeButtonControl(child: "A", hapticOnPress: false)
    let hosted = host(control)
    defer { withExtendedLifetime(hosted) {} }

    for _ in 0..<5 {
      exercise(control, iterations: 40)
    }

    var elapsedMilliseconds: [Double] = []
    for _ in 0..<25 {
      let start = CACurrentMediaTime()
      exercise(control, iterations: 40)
      elapsedMilliseconds.append((CACurrentMediaTime() - start) * 1_000)
    }

    let median = percentile50(elapsedMilliseconds)
    let deviations = elapsedMilliseconds.map { abs($0 - median) }
    let medianAbsoluteDeviation = percentile50(deviations)
    print(
      "PERF swift configuration+layout warmup=5 repetitions=25 updatesPerRepetition=40 "
        + "medianMs=\(String(format: "%.3f", median)) "
        + "madMs=\(String(format: "%.3f", medianAbsoluteDeviation))"
    )

    XCTAssertEqual(control.configuration.child, "A")
    XCTAssertTrue(control.intrinsicContentSize.width.isFinite)
    XCTAssertTrue(control.intrinsicContentSize.height.isFinite)
  }

  func testXCTestConfigurationUpdateMeasurement() {
    let control = ThemedButtonControl(child: "A", hapticOnPress: false)
    let hosted = host(control)
    defer { withExtendedLifetime(hosted) {} }

    measure(metrics: [XCTClockMetric()]) {
      exercise(control, iterations: 40)
    }
  }

  private func exercise(_ control: AwesomeButtonControl, iterations: Int) {
    for index in 0..<iterations {
      var configuration = control.configuration
      configuration.child = ["A", "B — updated", "C"][index % 3]
      configuration.width = [nil, 160, 220][index % 3]
      configuration.style = AwesomeButtonStyle(
        backgroundColor: index.isMultiple(of: 2) ? .blue : .purple,
        borderRadius: CGFloat(12 + (index % 8))
      )
      control.configuration = configuration
      control.setNeedsLayout()
      control.layoutIfNeeded()
    }
  }

  private func exercise(_ control: ThemedButtonControl, iterations: Int) {
    for index in 0..<iterations {
      var configuration = control.configuration
      configuration.child = ["A", "B — updated", "C"][index % 3]
      configuration.type = [.primary, .secondary, .x][index % 3]
      configuration.size = [.small, .medium, .large][index % 3]
      control.configuration = configuration
      control.setNeedsLayout()
      control.layoutIfNeeded()
    }
  }

  private func percentile50(_ values: [Double]) -> Double {
    let sorted = values.sorted()
    guard sorted.isEmpty == false else { return 0 }
    let midpoint = sorted.count / 2
    if sorted.count.isMultiple(of: 2) {
      return (sorted[midpoint - 1] + sorted[midpoint]) / 2
    }
    return sorted[midpoint]
  }

  private func host(_ control: UIControl) -> (UIWindow, UIViewController) {
    let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
    let parent = UIViewController()
    parent.view.frame = window.bounds
    window.rootViewController = parent
    window.makeKeyAndVisible()
    parent.view.addSubview(control)
    control.frame = CGRect(x: 20, y: 100, width: 240, height: 80)
    if let direct = control as? AwesomeButtonControl {
      direct.attach(to: parent)
    } else if let themed = control as? ThemedButtonControl {
      themed.attach(to: parent)
    }
    parent.view.layoutIfNeeded()
    return (window, parent)
  }
}
