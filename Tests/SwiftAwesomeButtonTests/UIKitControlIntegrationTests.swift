import SwiftUI
import UIKit
import XCTest

@testable import SwiftAwesomeButton

@MainActor
final class UIKitControlIntegrationTests: XCTestCase {
  private var retainedTargets: [AnyObject] = []

  override func tearDown() {
    AwesomeButtonController.hapticFeedbackTestOverride = nil
    super.tearDown()
  }

  func testAwesomeButtonControlUsesExactHapticOrdering() throws {
    var events: [String] = []
    AwesomeButtonController.hapticFeedbackTestOverride = { events.append("haptic") }
    let control = AwesomeButtonControl(
      child: "Haptic",
      onPressIn: { events.append("in") },
      onPressedIn: { events.append("pressed-in") }
    )
    let recorder = ControlEventRecorder(events: { events.append($0) })
    retainedTargets.append(recorder)
    control.addTarget(recorder, action: #selector(ControlEventRecorder.touchDown), for: .touchDown)
    let hosted = host(control)
    defer { withExtendedLifetime(hosted) {} }

    try touchSurface(in: control).beginTouch()

    XCTAssertEqual(events, ["down", "in", "haptic", "pressed-in"])
  }

  func testThemedButtonControlUsesExactHapticOrdering() throws {
    var events: [String] = []
    AwesomeButtonController.hapticFeedbackTestOverride = { events.append("haptic") }
    let control = ThemedButtonControl(
      child: "Haptic",
      onPressIn: { events.append("in") },
      onPressedIn: { events.append("pressed-in") }
    )
    let recorder = ControlEventRecorder(events: { events.append($0) })
    retainedTargets.append(recorder)
    control.addTarget(recorder, action: #selector(ControlEventRecorder.touchDown), for: .touchDown)
    let hosted = host(control)
    defer { withExtendedLifetime(hosted) {} }

    try touchSurface(in: control).beginTouch()

    XCTAssertEqual(events, ["down", "in", "haptic", "pressed-in"])
  }

  func testUIKitControlsNormalizeInvalidGeometryBeforeIntrinsicSizing() {
    let direct = AwesomeButtonControl(
      child: "Direct",
      width: .nan,
      height: .infinity,
      paddingHorizontal: -.infinity,
      paddingTop: -8,
      paddingBottom: .nan,
      style: AwesomeButtonStyle(
        textSize: .nan,
        borderWidth: -2,
        raiseAmount: .infinity
      ),
      hapticOnPress: false
    )
    let themed = ThemedButtonControl(
      child: "Themed",
      hapticOnPress: false,
      width: .nan,
      height: .infinity,
      paddingHorizontal: -4,
      style: AwesomeButtonStyle(borderWidth: .nan, raiseAmount: -8)
    )

    XCTAssertTrue(direct.intrinsicContentSize.width.isFinite)
    XCTAssertTrue(direct.intrinsicContentSize.height.isFinite)
    XCTAssertGreaterThanOrEqual(direct.intrinsicContentSize.width, 44)
    XCTAssertGreaterThanOrEqual(direct.intrinsicContentSize.height, 44)
    XCTAssertTrue(themed.intrinsicContentSize.width.isFinite)
    XCTAssertTrue(themed.intrinsicContentSize.height.isFinite)
    XCTAssertGreaterThanOrEqual(themed.intrinsicContentSize.width, 44)
    XCTAssertGreaterThanOrEqual(themed.intrinsicContentSize.height, 44)
  }

  func testExistingInitializerConfigurationReplacementAndMixedEventOrder() throws {
    var events: [String] = []
    let control = AwesomeButtonControl(
      child: "A",
      onPress: { _ in events.append("closure-A") },
      hapticOnPress: false
    )
    let originalHostedController = control.hostedViewController
    let recorder = ControlEventRecorder(events: { events.append($0) })
    retainedTargets.append(recorder)
    defer { withExtendedLifetime(recorder) {} }
    control.addTarget(recorder, action: #selector(ControlEventRecorder.touchDown), for: .touchDown)
    control.addTarget(
      recorder, action: #selector(ControlEventRecorder.touchUp), for: .touchUpInside)
    control.addTarget(
      recorder, action: #selector(ControlEventRecorder.primary), for: .primaryActionTriggered)
    let dualAction = UIAction(identifier: UIAction.Identifier("dual")) { _ in
      events.append("dual")
    }
    control.addAction(dualAction, for: [.touchUpInside, .primaryActionTriggered])
    let action = UIAction(identifier: UIAction.Identifier("extra-primary")) { _ in
      events.append("ui-action")
    }
    control.addAction(action, for: .primaryActionTriggered)
    let host = host(control)

    var configuration = control.configuration
    configuration.child = "B"
    configuration.onPress = { _ in events.append("closure-B") }
    control.configuration = configuration
    configuration.child = "C"
    configuration.onPress = { _ in events.append("closure-C") }
    control.configuration = configuration
    spinMainRunLoop()

    XCTAssertTrue(control.hostedViewController === originalHostedController)
    let surface = try touchSurface(in: control)
    surface.beginTouch()
    XCTAssertTrue(control.isHighlighted)
    surface.endTouch(isInside: true)
    spinMainRunLoop(0.05)

    XCTAssertEqual(
      events,
      ["down", "closure-C", "up", "dual", "primary", "dual", "ui-action"]
    )
    XCTAssertFalse(control.isHighlighted)
    XCTAssertNotNil(host.window.rootViewController)
  }

  func testSelectorOnlyConsumerUsesLiveConfigurationDuringHold() throws {
    var events: [String] = []
    let control = AwesomeButtonControl(child: "A", hapticOnPress: false)
    let originalHostedController = control.hostedViewController
    let recorder = ControlEventRecorder(events: { events.append($0) })
    retainedTargets.append(recorder)
    control.addTarget(recorder, action: #selector(ControlEventRecorder.touchDown), for: .touchDown)
    control.addTarget(
      recorder, action: #selector(ControlEventRecorder.touchUp), for: .touchUpInside)
    control.addTarget(recorder, action: #selector(ControlEventRecorder.cancel), for: .touchCancel)
    control.addTarget(
      recorder, action: #selector(ControlEventRecorder.primary), for: .primaryActionTriggered)
    let hosted = host(control)
    defer { withExtendedLifetime(hosted) {} }

    let surface = try touchSurface(in: control)
    surface.beginTouch()
    var replacement = control.configuration
    replacement.child = "B"
    replacement.style = AwesomeButtonStyle(backgroundColor: .blue)
    control.configuration = replacement
    spinMainRunLoop()
    surface.endTouch(isInside: true)
    spinMainRunLoop(0.05)

    XCTAssertTrue(control.hostedViewController === originalHostedController)
    XCTAssertEqual(events, ["down", "up", "primary"])
  }

  func testLongPressCancellationDebounceAndReenableEventMatrix() throws {
    var events: [String] = []
    let control = AwesomeButtonControl(
      child: "Events",
      onPress: { _ in events.append("press") },
      onLongPress: { events.append("long") },
      debouncedPressTime: 10,
      hapticOnPress: false
    )
    let recorder = ControlEventRecorder(events: { events.append($0) })
    retainedTargets.append(recorder)
    defer { withExtendedLifetime(recorder) {} }
    control.addTarget(recorder, action: #selector(ControlEventRecorder.touchDown), for: .touchDown)
    control.addTarget(
      recorder, action: #selector(ControlEventRecorder.touchUp), for: .touchUpInside)
    control.addTarget(recorder, action: #selector(ControlEventRecorder.cancel), for: .touchCancel)
    control.addTarget(
      recorder, action: #selector(ControlEventRecorder.primary), for: .primaryActionTriggered)
    let hosted = host(control)
    defer { withExtendedLifetime(hosted) {} }

    var surface = try touchSurface(in: control)
    surface.beginTouch()
    surface.endTouch(isInside: true)
    spinMainRunLoop(0.05)
    XCTAssertEqual(events, ["down", "press", "up", "primary"])

    events.removeAll()
    surface = try touchSurface(in: control)
    surface.beginTouch()
    surface.endTouch(isInside: true)
    spinMainRunLoop(0.05)
    XCTAssertEqual(events, ["down", "cancel"])

    events.removeAll()
    var replacement = control.configuration
    replacement.debouncedPressTime = 0
    control.configuration = replacement
    spinMainRunLoop()
    surface = try touchSurface(in: control)
    surface.beginTouch()
    surface.dispatchLongPressIfEligible()
    surface.endTouch(isInside: true)
    spinMainRunLoop(0.05)
    XCTAssertEqual(events, ["down", "long", "cancel"])

    events.removeAll()
    surface = try touchSurface(in: control)
    surface.beginTouch()
    surface.endTouch(isInside: false)
    spinMainRunLoop(0.05)
    XCTAssertEqual(events, ["down", "cancel"])

    events.removeAll()
    surface = try touchSurface(in: control)
    surface.beginTouch()
    replacement = control.configuration
    replacement.child = nil
    control.configuration = replacement
    spinMainRunLoop(0.05)
    XCTAssertEqual(events, ["down", "cancel"])
    XCTAssertFalse(control.isHighlighted)

    replacement.child = "Events"
    control.configuration = replacement
    spinMainRunLoop()

    events.removeAll()
    surface = try touchSurface(in: control)
    surface.beginTouch()
    control.isEnabled = false
    spinMainRunLoop(0.05)
    XCTAssertEqual(events, ["down", "cancel"])
    XCTAssertFalse(control.isHighlighted)

    control.isEnabled = true
    spinMainRunLoop()
    events.removeAll()
    surface = try touchSurface(in: control)
    surface.beginTouch()
    surface.endTouch(isInside: true)
    spinMainRunLoop(0.05)
    XCTAssertEqual(events, ["down", "press", "up", "primary"])
  }

  func testLiveUIActionRegistryControlsEligibilityWithoutConfigurationReplacement() throws {
    var events: [String] = []
    let control = AwesomeButtonControl(child: "Registry", hapticOnPress: false)
    control.addAction(UIAction { _ in events.append("down") }, for: .touchDown)
    control.addAction(UIAction { _ in events.append("cancel") }, for: .touchCancel)
    let first = UIAction(identifier: UIAction.Identifier("first")) { _ in events.append("first") }
    let second = UIAction(identifier: UIAction.Identifier("second")) { _ in events.append("second")
    }
    control.addAction(first, for: .primaryActionTriggered)
    let hosted = host(control)
    defer { withExtendedLifetime(hosted) {} }

    var surface = try touchSurface(in: control)
    surface.beginTouch()
    control.removeAction(identifiedBy: first.identifier, for: .primaryActionTriggered)
    control.addAction(second, for: .primaryActionTriggered)
    surface.endTouch(isInside: true)
    spinMainRunLoop(0.05)
    XCTAssertEqual(events, ["down", "second"])

    events.removeAll()
    surface = try touchSurface(in: control)
    surface.beginTouch()
    control.removeAction(identifiedBy: second.identifier, for: .primaryActionTriggered)
    surface.endTouch(isInside: true)
    spinMainRunLoop(0.05)
    XCTAssertEqual(events, ["down", "cancel"])
  }

  func testConsumerHandlerOnlyProgressStoresHandleBeforeEventsAndCompletesOnce() throws {
    var events: [String] = []
    let completionExpectation = expectation(description: "progress completed")
    let control = AwesomeButtonControl(
      child: "Progress",
      progress: true,
      progressLoadingTime: 0,
      hapticOnPress: false,
      onProgressStart: { events.append("start") },
      onProgressEnd: {
        events.append("end")
        completionExpectation.fulfill()
      }
    )
    let recorder = ControlEventRecorder(events: { events.append($0) })
    retainedTargets.append(recorder)
    defer { withExtendedLifetime(recorder) {} }
    let progressTarget = ProgressCompletionTarget(
      control: control,
      onPrimary: { events.append("primary") },
      onCompletion: { events.append("completion") }
    )
    retainedTargets.append(progressTarget)
    defer { withExtendedLifetime(progressTarget) {} }
    control.addTarget(recorder, action: #selector(ControlEventRecorder.touchDown), for: .touchDown)
    control.addTarget(
      recorder, action: #selector(ControlEventRecorder.touchUp), for: .touchUpInside)
    control.addTarget(
      progressTarget, action: #selector(ProgressCompletionTarget.primary),
      for: .primaryActionTriggered)
    let hosted = host(control)
    defer { withExtendedLifetime(hosted) {} }

    let surface = try touchSurface(in: control)
    surface.beginTouch()
    surface.endTouch(isInside: true)
    wait(for: [completionExpectation], timeout: 1.5)

    XCTAssertEqual(events, ["down", "start", "up", "primary", "completion", "end"])
    control.completeProgress { events.append("duplicate") }
    spinMainRunLoop(0.1)
    XCTAssertFalse(events.contains("duplicate"))
  }

  func testProgressRegistryReplacementAtDeferredDeliveryUsesNewestUIAction() throws {
    var events: [String] = []
    let completionExpectation = expectation(description: "replacement progress completed")
    var control: AwesomeButtonControl!
    let oldIdentifier = UIAction.Identifier("old-progress")
    let newIdentifier = UIAction.Identifier("new-progress")
    control = AwesomeButtonControl(
      child: "Progress",
      progress: true,
      progressLoadingTime: 0,
      hapticOnPress: false,
      onProgressStart: {
        events.append("start")
        control.removeAction(identifiedBy: oldIdentifier, for: .primaryActionTriggered)
        control.addAction(
          UIAction(identifier: newIdentifier) { _ in
            events.append("new")
            control.completeProgress { events.append("completion") }
          },
          for: .primaryActionTriggered
        )
      },
      onProgressEnd: {
        events.append("end")
        completionExpectation.fulfill()
      }
    )
    control.addAction(UIAction { _ in events.append("down") }, for: .touchDown)
    control.addAction(UIAction { _ in events.append("up") }, for: .touchUpInside)
    control.addAction(
      UIAction(identifier: oldIdentifier) { _ in events.append("old") },
      for: .primaryActionTriggered
    )
    let hosted = host(control)
    defer { withExtendedLifetime(hosted) {} }

    let surface = try touchSurface(in: control)
    surface.beginTouch()
    surface.endTouch(isInside: true)
    wait(for: [completionExpectation], timeout: 1.5)

    XCTAssertEqual(events, ["down", "start", "up", "new", "completion", "end"])
  }

  func testProgressRemovalInsidePrimaryCancelsQueuedCompletion() throws {
    var events: [String] = []
    let control = AwesomeButtonControl(
      child: "Progress",
      progress: true,
      progressLoadingTime: 0,
      hapticOnPress: false,
      onProgressStart: { events.append("start") },
      onProgressEnd: { events.append("end") }
    )
    control.addAction(UIAction { _ in events.append("down") }, for: .touchDown)
    control.addAction(UIAction { _ in events.append("up") }, for: .touchUpInside)
    control.addAction(
      UIAction { [weak control] _ in
        events.append("primary")
        control?.completeProgress { events.append("completion") }
        control?.removeFromSuperview()
      }, for: .primaryActionTriggered)
    let hosted = host(control)
    defer { withExtendedLifetime(hosted) {} }

    let surface = try touchSurface(in: control)
    surface.beginTouch()
    surface.endTouch(isInside: true)
    spinMainRunLoop(1)

    XCTAssertEqual(events, ["down", "start", "up", "primary"])
    XCTAssertFalse(control.isHighlighted)
  }

  func testReentrantRemovalSuppressesLaterPackageOwnedEventBoundaries() throws {
    var events: [String] = []
    var control: AwesomeButtonControl!
    control = AwesomeButtonControl(
      child: "Remove",
      onPress: { _ in
        events.append("closure")
        control.removeFromSuperview()
      },
      hapticOnPress: false
    )
    let recorder = ControlEventRecorder(events: { events.append($0) })
    retainedTargets.append(recorder)
    defer { withExtendedLifetime(recorder) {} }
    control.addTarget(recorder, action: #selector(ControlEventRecorder.touchDown), for: .touchDown)
    control.addTarget(
      recorder, action: #selector(ControlEventRecorder.touchUp), for: .touchUpInside)
    control.addTarget(
      recorder, action: #selector(ControlEventRecorder.primary), for: .primaryActionTriggered)
    let hosted = host(control)
    defer { withExtendedLifetime(hosted) {} }

    let surface = try touchSurface(in: control)
    surface.beginTouch()
    surface.endTouch(isInside: true)
    spinMainRunLoop(0.1)
    XCTAssertEqual(events, ["down", "closure"])
  }

  func testReentrantDisablementCancelsLaterEventBoundariesAndSettlesOnce() throws {
    var events: [String] = []
    var control: AwesomeButtonControl!
    control = AwesomeButtonControl(
      child: "Disable",
      onPress: { _ in
        events.append("closure")
        var disabled = control.configuration
        disabled.disabled = true
        control.configuration = disabled
      },
      hapticOnPress: false,
      onPressOut: { events.append("out") },
      onPressedOut: { events.append("settled") }
    )
    control.addAction(UIAction { _ in events.append("down") }, for: .touchDown)
    control.addAction(UIAction { _ in events.append("up") }, for: .touchUpInside)
    control.addAction(UIAction { _ in events.append("cancel") }, for: .touchCancel)
    control.addAction(UIAction { _ in events.append("primary") }, for: .primaryActionTriggered)
    let hosted = host(control)
    defer { withExtendedLifetime(hosted) {} }

    let surface = try touchSurface(in: control)
    surface.beginTouch()
    surface.endTouch(isInside: true)
    spinMainRunLoop(1)

    XCTAssertEqual(events, ["down", "out", "closure", "cancel", "settled"])
    XCTAssertFalse(control.isHighlighted)
  }

  func testRemovalInsideTouchUpFinishesThatBatchButSuppressesPrimary() throws {
    var events: [String] = []
    let control = AwesomeButtonControl(child: "Remove", hapticOnPress: false)
    let recorder = ControlEventRecorder(events: { events.append($0) })
    retainedTargets.append(recorder)
    defer { withExtendedLifetime(recorder) {} }
    control.addTarget(recorder, action: #selector(ControlEventRecorder.touchDown), for: .touchDown)
    control.addAction(
      UIAction { [weak control] _ in
        events.append("remove-up")
        control?.removeFromSuperview()
      }, for: .touchUpInside)
    control.addTarget(
      recorder, action: #selector(ControlEventRecorder.primary), for: .primaryActionTriggered)
    let hosted = host(control)
    defer { withExtendedLifetime(hosted) {} }

    let surface = try touchSurface(in: control)
    surface.beginTouch()
    surface.endTouch(isInside: true)
    spinMainRunLoop(0.1)
    XCTAssertEqual(events, ["down", "remove-up"])
  }

  func testExternalHighlightDoesNotDispatchLifecycleOrActivation() {
    var events: [String] = []
    let control = AwesomeButtonControl(
      child: "Highlight",
      onPress: { _ in events.append("press") },
      hapticOnPress: false,
      onPressIn: { events.append("in") },
      onPressOut: { events.append("out") }
    )
    let hosted = host(control)
    defer { withExtendedLifetime(hosted) {} }

    control.isHighlighted = true
    spinMainRunLoop()
    XCTAssertTrue(control.isHighlighted)
    control.isHighlighted = false
    spinMainRunLoop(0.05)
    XCTAssertFalse(control.isHighlighted)
    XCTAssertEqual(events, [])

    control.isEnabled = false
    control.isHighlighted = true
    XCTAssertFalse(control.isHighlighted)

    control.isEnabled = true
    var placeholder = control.configuration
    placeholder.child = nil
    control.configuration = placeholder
    control.isHighlighted = true
    XCTAssertFalse(control.isHighlighted)
  }

  func testConsumerHighlightIsRejectedWhileProgressOwnsInteraction() throws {
    var handle: AwesomeButtonProgressHandle?
    let control = AwesomeButtonControl(
      child: "Busy",
      onPress: { handle = $0 },
      progress: true,
      progressLoadingTime: 0,
      hapticOnPress: false
    )
    let hosted = host(control)
    defer { withExtendedLifetime(hosted) {} }

    let surface = try touchSurface(in: control)
    surface.beginTouch()
    surface.endTouch(isInside: true)
    spinMainRunLoop(0.1)
    XCTAssertNotNil(handle)
    XCTAssertTrue(control.nativeBridge.componentIsBusy)

    control.isHighlighted = true
    XCTAssertFalse(control.isHighlighted)

    handle?()
    spinMainRunLoop(1)
    XCTAssertFalse(control.nativeBridge.componentIsBusy)
  }

  func testFixedAutoStretchAndThemedIntrinsicSizingInvalidateOnConfiguration() {
    let control = AwesomeButtonControl(child: "Short", width: 180, height: 52, hapticOnPress: false)
    let hosted = host(control)
    defer { withExtendedLifetime(hosted) {} }
    XCTAssertEqual(control.intrinsicContentSize.width, 180, accuracy: 0.5)
    XCTAssertEqual(control.intrinsicContentSize.height, 58, accuracy: 0.5)

    var auto = control.configuration
    auto.width = nil
    auto.child = "A much longer button label"
    auto.before = AnyView(Color.clear.frame(width: 24, height: 1))
    auto.after = AnyView(Color.clear.frame(width: 18, height: 1))
    control.configuration = auto
    spinMainRunLoop(0.1)
    XCTAssertGreaterThan(control.intrinsicContentSize.width, 180)

    let autoWidthWithSlots = control.intrinsicContentSize.width
    auto.extra = AnyView(Color.clear.frame(width: 500, height: 1))
    control.configuration = auto
    spinMainRunLoop(0.1)
    XCTAssertEqual(control.intrinsicContentSize.width, autoWidthWithSlots, accuracy: 0.5)

    var stretch = control.configuration
    stretch.stretch = true
    control.configuration = stretch
    XCTAssertEqual(control.intrinsicContentSize.width, UIView.noIntrinsicMetric)
    XCTAssertEqual(control.sizeThatFits(CGSize(width: 320, height: 100)).width, 320)

    let themed = ThemedButtonControl(
      configuration: .init(
        child: "Theme",
        config: ThemeDefinition(
          title: "Test",
          background: .clear,
          color: .clear,
          buttons: [.primary: ThemeButtonStyle(height: 71, raiseLevel: 8, width: 173)],
          size: [.medium: ThemeSizeStyle(width: 211, height: 61)]
        ),
        hapticOnPress: false
      )
    )
    let themedHost = host(themed)
    defer { withExtendedLifetime(themedHost) {} }
    XCTAssertEqual(themed.intrinsicContentSize.width, 173, accuracy: 0.5)
    XCTAssertEqual(themed.intrinsicContentSize.height, 79, accuracy: 0.5)
  }

  func testThemedControlSelectorAndUIActionConsumersKeepUIKitContract() throws {
    var selectorEvents: [String] = []
    let selectorControl = ThemedButtonControl(
      child: "Theme A", hapticOnPress: false, autoWidth: true)
    let originalHostedController = selectorControl.hostedViewController
    let recorder = ControlEventRecorder(events: { selectorEvents.append($0) })
    retainedTargets.append(recorder)
    selectorControl.addTarget(
      recorder, action: #selector(ControlEventRecorder.touchDown), for: .touchDown)
    selectorControl.addTarget(
      recorder, action: #selector(ControlEventRecorder.touchUp), for: .touchUpInside)
    selectorControl.addTarget(
      recorder, action: #selector(ControlEventRecorder.primary), for: .primaryActionTriggered)
    let selectorHost = host(selectorControl)
    defer { withExtendedLifetime(selectorHost) {} }

    var replacement = selectorControl.configuration
    replacement.child = "Theme C"
    replacement.type = .secondary
    selectorControl.configuration = replacement
    spinMainRunLoop()
    var surface = try touchSurface(in: selectorControl)
    surface.beginTouch()
    surface.endTouch(isInside: true)
    spinMainRunLoop(0.05)
    XCTAssertTrue(selectorControl.hostedViewController === originalHostedController)
    XCTAssertEqual(selectorEvents, ["down", "up", "primary"])

    var actionEvents: [String] = []
    let completionExpectation = expectation(description: "themed UIAction progress completed")
    let actionControl = ThemedButtonControl(
      child: "Theme Progress",
      hapticOnPress: false,
      autoWidth: true,
      progress: true,
      progressLoadingTime: 0,
      onProgressStart: { actionEvents.append("start") },
      onProgressEnd: {
        actionEvents.append("end")
        completionExpectation.fulfill()
      }
    )
    actionControl.addAction(UIAction { _ in actionEvents.append("down") }, for: .touchDown)
    actionControl.addAction(UIAction { _ in actionEvents.append("up") }, for: .touchUpInside)
    actionControl.addAction(
      UIAction { [weak actionControl] _ in
        actionEvents.append("primary")
        actionControl?.completeProgress { actionEvents.append("completion") }
      }, for: .primaryActionTriggered)
    let actionHost = host(actionControl)
    defer { withExtendedLifetime(actionHost) {} }

    surface = try touchSurface(in: actionControl)
    surface.beginTouch()
    surface.endTouch(isInside: true)
    wait(for: [completionExpectation], timeout: 1.5)
    XCTAssertEqual(actionEvents, ["down", "start", "up", "primary", "completion", "end"])
  }

  func testThemedControlCompletesMediumLargeSmallLabelAndSizeCycles() {
    let control = ThemedButtonControl(
      child: "Medium",
      size: .medium,
      textTransition: true,
      hapticOnPress: false
    )
    let originalHostedController = control.hostedViewController
    let hosted = host(control)
    defer { withExtendedLifetime(hosted) {} }

    XCTAssertEqual(control.accessibilityLabel, "Medium")
    XCTAssertEqual(control.intrinsicContentSize.width, 200, accuracy: 0.5)

    var large = control.configuration
    large.child = "Large"
    large.size = .large
    control.configuration = large
    spinMainRunLoop(0.35)

    XCTAssertTrue(control.hostedViewController === originalHostedController)
    XCTAssertEqual(control.accessibilityLabel, "Large")
    XCTAssertEqual(control.intrinsicContentSize.width, 250, accuracy: 0.5)

    var small = control.configuration
    small.child = "Small"
    small.size = .small
    control.configuration = small
    spinMainRunLoop(0.35)

    XCTAssertTrue(control.hostedViewController === originalHostedController)
    XCTAssertEqual(control.accessibilityLabel, "Small")
    XCTAssertEqual(control.intrinsicContentSize.width, 120, accuracy: 0.5)
  }

  func testContainmentAttachDetachReparentAndDiscovery() {
    let firstParent = UIViewController()
    let secondParent = UIViewController()
    let control = AwesomeButtonControl(child: "Attach", hapticOnPress: false)

    control.attach(to: firstParent)
    XCTAssertTrue(control.attachedParentViewController === firstParent)
    XCTAssertTrue(control.hostedViewController.parent === firstParent)
    control.attach(to: secondParent)
    XCTAssertTrue(control.attachedParentViewController === secondParent)
    XCTAssertNil(firstParent.children.first { $0 === control.hostedViewController })
    control.detachFromParentViewController()
    XCTAssertNil(control.attachedParentViewController)
    XCTAssertNil(control.hostedViewController.parent)
    XCTAssertTrue(control.intrinsicContentSize.height > 0)

    let discoveryControl = AwesomeButtonControl(child: "Discover", hapticOnPress: false)
    let host = host(discoveryControl, attachExplicitly: false)
    XCTAssertTrue(discoveryControl.attachedParentViewController === host.parent)
  }

  func testHostCoordinatorDoesNotRetainControlsAfterTeardown() {
    weak var releasedDirectControl: AwesomeButtonControl?
    weak var releasedDirectHost: UIViewController?
    weak var releasedThemedControl: ThemedButtonControl?
    weak var releasedThemedHost: UIViewController?

    autoreleasepool {
      let direct = AwesomeButtonControl(child: "Direct", hapticOnPress: false)
      let directHost = host(direct)
      releasedDirectControl = direct
      releasedDirectHost = direct.hostedViewController
      direct.detachFromParentViewController()
      direct.removeFromSuperview()
      directHost.window.isHidden = true
      directHost.window.rootViewController = nil

      let themed = ThemedButtonControl(child: "Themed", hapticOnPress: false)
      let themedHost = host(themed)
      releasedThemedControl = themed
      releasedThemedHost = themed.hostedViewController
      themed.detachFromParentViewController()
      themed.removeFromSuperview()
      themedHost.window.isHidden = true
      themedHost.window.rootViewController = nil
    }

    spinMainRunLoop()
    XCTAssertNil(releasedDirectControl)
    XCTAssertNil(releasedDirectHost)
    XCTAssertNil(releasedThemedControl)
    XCTAssertNil(releasedThemedHost)
  }

  func testRemovalDuringHeldGestureIsSilentAfterTouchDown() throws {
    var events: [String] = []
    let control = AwesomeButtonControl(
      child: "Remove",
      onPress: { _ in events.append("press") },
      hapticOnPress: false,
      onPressOut: { events.append("out") }
    )
    let recorder = ControlEventRecorder(events: { events.append($0) })
    retainedTargets.append(recorder)
    defer { withExtendedLifetime(recorder) {} }
    control.addTarget(recorder, action: #selector(ControlEventRecorder.touchDown), for: .touchDown)
    control.addTarget(recorder, action: #selector(ControlEventRecorder.cancel), for: .touchCancel)
    let hosted = host(control)
    defer { withExtendedLifetime(hosted) {} }

    let surface = try touchSurface(in: control)
    surface.beginTouch()
    control.removeFromSuperview()
    spinMainRunLoop(0.1)
    XCTAssertEqual(events, ["down"])
    XCTAssertFalse(control.isHighlighted)
  }
}

@MainActor
private struct HostedControl {
  let window: UIWindow
  let parent: UIViewController
}

@MainActor
@discardableResult
private func host(
  _ control: UIControl,
  attachExplicitly: Bool = true
) -> HostedControl {
  installPackageEventDispatcher(on: control)
  let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
  let parent = UIViewController()
  window.rootViewController = parent
  window.makeKeyAndVisible()
  control.frame = CGRect(x: 20, y: 100, width: 300, height: 90)
  parent.view.addSubview(control)
  if attachExplicitly {
    if let control = control as? AwesomeButtonControl {
      control.attach(to: parent)
    } else if let control = control as? ThemedButtonControl {
      control.attach(to: parent)
    }
  }
  parent.view.layoutIfNeeded()
  spinMainRunLoop()
  return HostedControl(window: window, parent: parent)
}

@MainActor
private func installPackageEventDispatcher(on control: UIControl) {
  let dispatch: (UIControl, UIControl.Event) -> Void = { control, event in
    control.enumerateEventHandlers { action, targetAction, registeredEvents, _ in
      guard registeredEvents.intersection(event).isEmpty == false else {
        return
      }
      if let action {
        control.sendAction(action)
      } else if let (target, selector) = targetAction,
        let target = target as? NSObject
      {
        target.perform(selector, with: control)
      }
    }
  }
  if let control = control as? AwesomeButtonControl {
    control.nativeBridge.eventDispatcher = dispatch
  } else if let control = control as? ThemedButtonControl {
    control.nativeBridge.eventDispatcher = dispatch
  }
}

@MainActor
private func touchSurface(in control: UIControl) throws -> ButtonTouchSurfaceView {
  guard let surface = descendant(of: ButtonTouchSurfaceView.self, in: control) else {
    throw UIKitControlTestError.touchSurfaceMissing
  }
  return surface
}

@MainActor
private func descendant<T: UIView>(of type: T.Type, in view: UIView) -> T? {
  if let match = view as? T {
    return match
  }
  for subview in view.subviews {
    if let match = descendant(of: type, in: subview) {
      return match
    }
  }
  return nil
}

@MainActor
private func spinMainRunLoop(_ duration: TimeInterval = 0.02) {
  RunLoop.main.run(until: Date().addingTimeInterval(duration))
}

private enum UIKitControlTestError: Error {
  case touchSurfaceMissing
}

private final class ControlEventRecorder: NSObject {
  private let events: (String) -> Void

  init(events: @escaping (String) -> Void) {
    self.events = events
  }

  @objc func touchDown(_ sender: UIControl) { events("down") }
  @objc func touchUp(_ sender: UIControl) { events("up") }
  @objc func cancel(_ sender: UIControl) { events("cancel") }
  @objc func primary(_ sender: UIControl) { events("primary") }
  @objc func dual(_ sender: UIControl) { events("dual") }
}

@MainActor
private final class ProgressCompletionTarget: NSObject {
  weak var control: AwesomeButtonControl?
  private let onPrimary: () -> Void
  private let onCompletion: () -> Void

  init(
    control: AwesomeButtonControl,
    onPrimary: @escaping () -> Void,
    onCompletion: @escaping () -> Void
  ) {
    self.control = control
    self.onPrimary = onPrimary
    self.onCompletion = onCompletion
  }

  @objc func primary(_ sender: UIControl) {
    onPrimary()
    control?.completeProgress(onCompletion)
  }
}
