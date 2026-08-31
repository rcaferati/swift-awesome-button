import SwiftUI
import UIKit
import XCTest

@testable import SwiftAwesomeButton

@MainActor
final class ThirdPassAccessibilityTests: XCTestCase {
  func testAtomicDefaultAndLongActivationDoNotFabricatePhysicalLifecycle() {
    let controller = AwesomeButtonController()
    var events: [String] = []
    let configuration = pass3Configuration(
      onPress: { _ in events.append("press") },
      onLongPress: { events.append("long") },
      onPressIn: { events.append("in") },
      onPressOut: { events.append("out") },
      onPressedIn: { events.append("pressed-in") },
      onPressedOut: { events.append("pressed-out") }
    )
    controller.update(configuration: configuration)

    XCTAssertTrue(controller.activateAtomically(configuration: configuration))
    XCTAssertTrue(controller.activateLongPressAtomically(configuration: configuration))
    XCTAssertEqual(events, ["press", "long"])
    XCTAssertFalse(controller.isPressed)
    XCTAssertEqual(controller.pressProgress, 0)
  }

  func testReducedMotionAtomicProgressKeepsOwnershipAndCompletesOnce() throws {
    let controller = AwesomeButtonController()
    var events: [String] = []
    var handle: AwesomeButtonProgressHandle?
    let configuration = pass3Configuration(
      progress: true,
      reduceMotion: true,
      onPress: {
        events.append("press")
        handle = $0
      },
      onPressedOut: { events.append("pressed-out") },
      onProgressStart: { events.append("start") },
      onProgressEnd: { events.append("end") }
    )
    controller.update(configuration: configuration)

    XCTAssertTrue(controller.activateAtomically(configuration: configuration))
    spinPass3RunLoop()
    XCTAssertTrue(controller.isBusy)
    XCTAssertEqual(controller.progressValue, 1)
    XCTAssertEqual(controller.progressOverlayOpacity, 1)

    (try XCTUnwrap(handle)) { events.append("completion") }
    (try XCTUnwrap(handle)) { events.append("duplicate") }
    spinPass3RunLoop()

    XCTAssertEqual(events, ["start", "press", "completion", "end"])
    XCTAssertFalse(controller.isBusy)
    XCTAssertEqual(controller.pressProgress, 0)
  }

  func testEnablingReducedMotionSettlesAcceptedProgressWithoutReplayingCallbacks() throws {
    let controller = AwesomeButtonController()
    var events: [String] = []
    var handle: AwesomeButtonProgressHandle?
    let animated = pass3Configuration(
      progress: true,
      onPress: {
        events.append("press")
        handle = $0
      },
      onProgressStart: { events.append("start") },
      onProgressEnd: { events.append("end") }
    )
    let reduced = pass3Configuration(
      progress: true,
      reduceMotion: true,
      onPress: {
        events.append("replacement-press")
        handle = $0
      },
      onProgressStart: { events.append("replacement-start") },
      onProgressEnd: { events.append("replacement-end") }
    )
    controller.update(configuration: animated)
    XCTAssertTrue(controller.activateAtomically(configuration: animated))
    spinPass3RunLoop(0.03)

    (try XCTUnwrap(handle)) { events.append("completion") }
    controller.update(configuration: reduced)
    spinPass3RunLoop()

    XCTAssertEqual(events, ["start", "press", "completion", "end"])
    XCTAssertFalse(controller.isBusy)
    XCTAssertEqual(controller.progressValue, 0)
    XCTAssertEqual(controller.progressOverlayOpacity, 0)
  }

  func testUIKitOwnsOneAccessibleElementAndAtomicKeyboardActions() {
    var events: [String] = []
    let control = AwesomeButtonControl(
      child: "Visible",
      onPress: { _ in events.append("press") },
      onLongPress: { events.append("long") },
      hapticOnPress: false,
      accessibilityLabel: "Save draft",
      accessibilityHint: "Saves this draft",
      accessibilityLongPressLabel: "Show options",
      onPressIn: { events.append("in") },
      onPressOut: { events.append("out") }
    )
    let host = hostPass3Control(control)
    defer { host.window.isHidden = true }

    XCTAssertTrue(control.isAccessibilityElement)
    XCTAssertEqual(control.accessibilityLabel, "Save draft")
    XCTAssertEqual(control.accessibilityHint, "Saves this draft")
    XCTAssertEqual(control.accessibilityCustomActions?.map(\.name), ["Show options"])
    XCTAssertTrue(control.hostedViewController.view.accessibilityElementsHidden)
    XCTAssertTrue(control.accessibilityActivate())
    XCTAssertEqual(events, ["press"])

    control.handleKeyboardActivationBegan()
    control.handleKeyboardActivationBegan()
    XCTAssertTrue(control.handleKeyboardActivationEnded())
    XCTAssertFalse(control.handleKeyboardActivationEnded())
    XCTAssertEqual(events, ["press", "press"])

    XCTAssertTrue(control.nativeBridge.performAtomicLongPressActivation())
    XCTAssertEqual(events, ["press", "press", "long"])
  }

  func testUIKitPlaceholderAndDisabledStateRemoveActionsImmediately() {
    let control = AwesomeButtonControl(
      child: nil,
      onPress: { _ in XCTFail("placeholder activated") },
      hapticOnPress: false,
      accessibilityHint: "Must not be announced while unavailable"
    )
    let host = hostPass3Control(control)
    defer { host.window.isHidden = true }

    XCTAssertFalse(control.isAccessibilityElement)
    XCTAssertFalse(control.accessibilityActivate())

    var value = control.configuration
    value.accessibilityLabel = "Loading account"
    control.configuration = value
    spinPass3RunLoop()
    XCTAssertTrue(control.isAccessibilityElement)
    XCTAssertEqual(control.accessibilityValue, AwesomeButtonLocalization.placeholderState)
    XCTAssertNil(control.accessibilityHint)
    XCTAssertTrue(control.accessibilityTraits.contains(.notEnabled))
    XCTAssertNil(control.accessibilityCustomActions)
    XCTAssertFalse(control.accessibilityActivate())
  }

  func testPublicSwiftUISurfaceUsesMinimumFootprintAndScaledBodyTypography() {
    let button = AwesomeButton(
      child: "Readable label",
      onPress: { _ in },
      width: 20,
      height: 20,
      style: AwesomeButtonStyle(raiseAmount: 0),
      hapticOnPress: false,
      accessibilityLabel: "Readable action",
      accessibilityHint: "Performs the action"
    )
    XCTAssertEqual(button.accessibilityLabel, "Readable action")
    XCTAssertEqual(button.accessibilityHint, "Performs the action")

    let hosting = UIHostingController(
      rootView:
        button
        .environment(\.dynamicTypeSize, .accessibility3)
    )
    let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 240))
    window.rootViewController = hosting
    window.makeKeyAndVisible()
    hosting.view.layoutIfNeeded()
    spinPass3RunLoop()

    XCTAssertGreaterThanOrEqual(hosting.view.intrinsicContentSize.width, 44)
    XCTAssertGreaterThan(
      awesomeButtonScaledTextSize(14, dynamicTypeSize: .accessibility3),
      awesomeButtonScaledTextSize(14, dynamicTypeSize: .large)
    )
    XCTAssertFalse(
      pass3Descendants(of: ButtonTouchSurfaceView.self, in: hosting.view).contains {
        $0.isAccessibilityElement
      })
    window.isHidden = true
  }

  func testThemedSwiftUIAndUIKitSurfacesForwardCanonicalAccessibilityOptions() {
    let themed = ThemedButton(
      child: "Visible",
      accessibilityLabel: "Themed action",
      accessibilityHint: "Runs themed action",
      accessibilityLongPressLabel: "Themed options",
      onPress: { _ in }
    )
    XCTAssertEqual(themed.accessibilityLabel, "Themed action")
    XCTAssertEqual(themed.accessibilityHint, "Runs themed action")
    XCTAssertEqual(themed.accessibilityLongPressLabel, "Themed options")

    var events: [String] = []
    let control = ThemedButtonControl(
      child: "Visible",
      hapticOnPress: false,
      accessibilityLabel: "Themed UIKit action",
      accessibilityHint: "Runs UIKit action",
      accessibilityLongPressLabel: "Themed UIKit options",
      onPress: { _ in events.append("press") },
      onLongPress: { events.append("long") }
    )
    let host = hostPass3ThemedControl(control)
    defer { host.window.isHidden = true }

    XCTAssertEqual(control.accessibilityLabel, "Themed UIKit action")
    XCTAssertEqual(control.accessibilityHint, "Runs UIKit action")
    XCTAssertEqual(control.accessibilityCustomActions?.map(\.name), ["Themed UIKit options"])
    XCTAssertTrue(control.accessibilityActivate())
    XCTAssertTrue(control.nativeBridge.performAtomicLongPressActivation())
    XCTAssertEqual(events, ["press", "long"])
  }

  func testUIKitLargeTextHeightAccountsForWrappingAtTheAvailableFaceWidth() {
    let traits = UITraitCollection(
      preferredContentSizeCategory: .accessibilityExtraExtraExtraLarge
    )
    let style = AwesomeButtonStyle(
      textSize: 14,
      textLineHeight: 20,
      borderWidth: 1
    )
    let wide = awesomeButtonUIKitFaceHeight(
      configuredHeight: 52,
      style: style,
      child: "A label that must wrap at accessibility sizes",
      availableFaceWidth: 400,
      paddingHorizontal: 16,
      paddingTop: 0,
      paddingBottom: 0,
      traitCollection: traits
    )
    let narrow = awesomeButtonUIKitFaceHeight(
      configuredHeight: 52,
      style: style,
      child: "A label that must wrap at accessibility sizes",
      availableFaceWidth: 100,
      paddingHorizontal: 16,
      paddingTop: 0,
      paddingBottom: 0,
      traitCollection: traits
    )

    XCTAssertGreaterThan(narrow, wide)
    XCTAssertGreaterThanOrEqual(narrow, 44)
  }
}

@MainActor
private func pass3Configuration(
  progress: Bool = false,
  reduceMotion: Bool = false,
  onPress: AwesomeButtonPressCallback? = { _ in },
  onLongPress: (() -> Void)? = nil,
  onPressIn: (() -> Void)? = nil,
  onPressOut: (() -> Void)? = nil,
  onPressedIn: (() -> Void)? = nil,
  onPressedOut: (() -> Void)? = nil,
  onProgressStart: (() -> Void)? = nil,
  onProgressEnd: (() -> Void)? = nil
) -> AwesomeButtonResolvedConfiguration {
  AwesomeButtonResolvedConfiguration(
    childText: "Button",
    labelView: nil,
    beforeView: nil,
    afterView: nil,
    extraView: nil,
    onPress: onPress,
    onLongPress: onLongPress,
    disabled: false,
    width: nil,
    height: 52,
    paddingHorizontal: 16,
    paddingTop: 0,
    paddingBottom: 0,
    stretch: false,
    style: AwesomeButtonThemeData.fallbackStyle,
    activeOpacity: 1,
    debouncedPressTime: 0,
    progress: progress,
    showProgressBar: true,
    progressLoadingTime: 1,
    animateSize: true,
    textTransition: true,
    textTransitionSlotStaggerMs: 7,
    animatedPlaceholder: true,
    hapticOnPress: false,
    onPressIn: onPressIn,
    onPressOut: onPressOut,
    onPressedIn: onPressedIn,
    onPressedOut: onPressedOut,
    onProgressStart: onProgressStart,
    onProgressEnd: onProgressEnd,
    reduceMotion: reduceMotion
  )
}

@MainActor
private struct Pass3HostedControl {
  let window: UIWindow
}

@MainActor
private func hostPass3Control(_ control: AwesomeButtonControl) -> Pass3HostedControl {
  let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
  let parent = UIViewController()
  window.rootViewController = parent
  window.makeKeyAndVisible()
  control.frame = CGRect(x: 20, y: 100, width: 300, height: 90)
  parent.view.addSubview(control)
  control.attach(to: parent)
  parent.view.layoutIfNeeded()
  spinPass3RunLoop()
  return Pass3HostedControl(window: window)
}

@MainActor
private func hostPass3ThemedControl(_ control: ThemedButtonControl) -> Pass3HostedControl {
  let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
  let parent = UIViewController()
  window.rootViewController = parent
  window.makeKeyAndVisible()
  control.frame = CGRect(x: 20, y: 100, width: 300, height: 90)
  parent.view.addSubview(control)
  control.attach(to: parent)
  parent.view.layoutIfNeeded()
  spinPass3RunLoop()
  return Pass3HostedControl(window: window)
}

@MainActor
private func spinPass3RunLoop(_ duration: TimeInterval = 0.12) {
  RunLoop.main.run(until: Date().addingTimeInterval(duration))
}

@MainActor
private func pass3Descendants<T: UIView>(of type: T.Type, in view: UIView) -> [T] {
  var values = view is T ? [view as! T] : []
  for subview in view.subviews {
    values.append(contentsOf: pass3Descendants(of: type, in: subview))
  }
  return values
}
