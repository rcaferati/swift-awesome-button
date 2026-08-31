import SwiftUI
import UIKit
import XCTest

@testable import SwiftAwesomeButton

@MainActor
final class NativeFirstPassInteractionTests: XCTestCase {
  func testTouchSurfaceHoldWithoutHandlerRemainsAnOrdinaryActivation() {
    let surface = ButtonTouchSurfaceView()
    var activations: [Bool] = []
    let longPresses = 0
    configure(
      surface,
      onTouchEnd: { activations.append($0) },
      onLongPress: nil
    )

    surface.beginTouch()
    surface.dispatchLongPressIfEligible()
    surface.endTouch(isInside: true)

    XCTAssertEqual(activations, [true])
    XCTAssertEqual(longPresses, 0)
    XCTAssertFalse(surface.isTouchActive)
  }

  func testTouchSurfaceSuppressesTapOnlyAfterLongPressActuallyDispatches() {
    let surface = ButtonTouchSurfaceView()
    var activations: [Bool] = []
    var longPresses = 0
    configure(
      surface,
      onTouchEnd: { activations.append($0) },
      onLongPress: { longPresses += 1 }
    )

    surface.beginTouch()
    surface.dispatchLongPressIfEligible()
    surface.dispatchLongPressIfEligible()
    surface.endTouch(isInside: true)

    XCTAssertEqual(longPresses, 1)
    XCTAssertEqual(activations, [false])
  }

  func testTouchSurfaceHandlerAdditionRemovalAndReplacementAreMonotonicPerTouch() {
    let surface = ButtonTouchSurfaceView()
    var events: [String] = []

    configure(surface, onTouchEnd: { events.append($0 ? "tap" : "cancel") })
    surface.beginTouch()
    configure(
      surface,
      onTouchEnd: { events.append($0 ? "tap" : "cancel") },
      onLongPress: { events.append("late") }
    )
    surface.dispatchLongPressIfEligible()
    surface.endTouch(isInside: true)
    XCTAssertEqual(events, ["tap"])

    events.removeAll()
    configure(
      surface,
      onTouchEnd: { events.append($0 ? "tap" : "cancel") },
      onLongPress: { events.append("A") }
    )
    surface.beginTouch()
    configure(
      surface,
      onTouchEnd: { events.append($0 ? "tap" : "cancel") },
      onLongPress: { events.append("B") }
    )
    surface.dispatchLongPressIfEligible()
    surface.endTouch(isInside: true)
    XCTAssertEqual(events, ["B", "cancel"])

    events.removeAll()
    configure(
      surface,
      onTouchEnd: { events.append($0 ? "tap" : "cancel") },
      onLongPress: { events.append("A") }
    )
    surface.beginTouch()
    configure(surface, onTouchEnd: { events.append($0 ? "tap" : "cancel") })
    configure(
      surface,
      onTouchEnd: { events.append($0 ? "tap" : "cancel") },
      onLongPress: { events.append("B") }
    )
    surface.dispatchLongPressIfEligible()
    surface.endTouch(isInside: true)
    XCTAssertEqual(events, ["tap"])
  }

  func testTouchSurfaceDisablementCancelsOnceAndReenableStartsCleanly() {
    let surface = ButtonTouchSurfaceView()
    var endings: [Bool] = []
    configure(surface, onTouchEnd: { endings.append($0) })

    surface.beginTouch()
    configure(surface, isDisabled: true, onTouchEnd: { endings.append($0) })
    configure(surface, isDisabled: true, onTouchEnd: { endings.append($0) })

    XCTAssertEqual(endings, [false])
    XCTAssertFalse(surface.isTouchActive)

    configure(surface, onTouchEnd: { endings.append($0) })
    surface.beginTouch()
    surface.endTouch(isInside: true)

    XCTAssertEqual(endings, [false, true])
  }

  func testTouchSurfaceDismantleIsSilentAndIdempotent() {
    let surface = ButtonTouchSurfaceView()
    var endings = 0
    var dismantles = 0
    surface.update(
      isDisabled: false,
      onTouchChange: { _ in },
      onTouchEnd: { _ in endings += 1 },
      onLongPress: nil,
      onDismantle: { dismantles += 1 }
    )

    surface.beginTouch()
    surface.dismantle()
    surface.dismantle()

    XCTAssertEqual(endings, 0)
    XCTAssertEqual(dismantles, 1)
    XCTAssertFalse(surface.isTouchActive)
  }

  func testControllerUsesLatestCallbacksAndReleaseStartSnapshot() {
    let controller = AwesomeButtonController()
    var events: [String] = []
    let configurationA = makeConfiguration(
      onPress: { _ in events.append("press-A") },
      onPressIn: { events.append("in-A") },
      onPressOut: { events.append("out-A") },
      onPressedOut: { events.append("pressed-out-A") }
    )
    let configurationB = makeConfiguration(
      onPress: { _ in events.append("press-B") },
      onPressIn: { events.append("in-B") },
      onPressOut: { events.append("out-B") },
      onPressedOut: { events.append("pressed-out-B") }
    )

    controller.update(configuration: configurationA)
    controller.handleTouchChange(isInside: true, configuration: configurationA)
    controller.refreshLiveConfiguration(configurationB)
    controller.handleTouchEnd(isInside: true, configuration: configurationB)
    spinMainRunLoop()
    controller.refreshLiveConfiguration(configurationA)
    controller.completeReleaseIfNeeded(observedPressProgress: 0)

    XCTAssertEqual(
      events,
      ["in-A", "out-B", "press-B", "pressed-out-B"]
    )
    XCTAssertFalse(controller.isPressed)
    XCTAssertFalse(controller.isTouchActive)
  }

  func testControllerRapidReplacementUsesFinalConfigurationWithoutReplay() {
    let controller = AwesomeButtonController()
    var events: [String] = []
    let configurationA = makeConfiguration(onPress: { _ in events.append("A") })
    let configurationB = makeConfiguration(onPress: { _ in events.append("B") })
    let configurationC = makeConfiguration(onPress: { _ in events.append("C") })

    controller.update(configuration: configurationA)
    controller.refreshLiveConfiguration(configurationB)
    controller.refreshLiveConfiguration(configurationC)
    controller.handleTouchChange(isInside: true, configuration: configurationC)
    controller.handleTouchEnd(isInside: true, configuration: configurationC)
    spinMainRunLoop()
    controller.completeReleaseIfNeeded(observedPressProgress: 0)

    XCTAssertEqual(events, ["C"])
  }

  func testPressInBoundaryUsesLatestCommittedPressedInCallback() {
    let controller = AwesomeButtonController()
    var events: [String] = []
    var configurationB: AwesomeButtonResolvedConfiguration!
    let configurationA = makeConfiguration(
      onPressIn: {
        events.append("in-A")
        controller.refreshLiveConfiguration(configurationB)
      },
      onPressedIn: { events.append("pressed-in-A") }
    )
    configurationB = makeConfiguration(
      onPressIn: { events.append("in-B") },
      onPressedIn: { events.append("pressed-in-B") }
    )

    controller.update(configuration: configurationA)
    controller.handleTouchChange(isInside: true, configuration: configurationA)

    XCTAssertEqual(events, ["in-A", "pressed-in-B"])
  }

  func testNewTouchAtDeferredTerminalBoundaryStartsAFreshLifecycle() {
    let controller = AwesomeButtonController()
    var events: [String] = []
    let configurationA = makeConfiguration(
      onPress: { _ in events.append("press-A") },
      onPressIn: { events.append("in-A") },
      onPressOut: { events.append("out-A") },
      onPressedIn: { events.append("pressed-in-A") },
      onPressedOut: { events.append("pressed-out-A") }
    )
    let configurationB = makeConfiguration(
      onPress: { _ in events.append("press-B") },
      onPressIn: { events.append("in-B") },
      onPressOut: { events.append("out-B") },
      onPressedIn: { events.append("pressed-in-B") },
      onPressedOut: { events.append("pressed-out-B") }
    )

    controller.update(configuration: configurationA)
    controller.handleTouchChange(isInside: true, configuration: configurationA)
    controller.handleTouchEnd(isInside: true, configuration: configurationA)
    controller.handleTouchChange(isInside: true, configuration: configurationB)
    spinMainRunLoop()

    XCTAssertEqual(
      events,
      ["in-A", "pressed-in-A", "out-A", "in-B", "pressed-in-B"]
    )
    XCTAssertTrue(controller.isTouchActive)

    controller.handleTouchEnd(isInside: true, configuration: configurationB)
    spinMainRunLoop()
    controller.completeReleaseIfNeeded(observedPressProgress: 0)

    XCTAssertEqual(
      events,
      [
        "in-A", "pressed-in-A", "out-A",
        "in-B", "pressed-in-B", "out-B", "press-B", "pressed-out-B",
      ]
    )
  }

  func testControllerMountedDisablementCancelsAndReenableActivatesCleanly() {
    let controller = AwesomeButtonController()
    var events: [String] = []
    let enabled = makeConfiguration(
      onPress: { _ in events.append("press") },
      onPressOut: { events.append("out") },
      onPressedOut: { events.append("pressed-out") }
    )
    let disabled = makeConfiguration(
      onPress: { _ in events.append("disabled-press") },
      disabled: true,
      onPressOut: { events.append("out") },
      onPressedOut: { events.append("pressed-out") }
    )

    controller.update(configuration: enabled)
    controller.handleTouchChange(isInside: true, configuration: enabled)
    controller.handleTouchEnd(isInside: false, configuration: disabled)
    spinMainRunLoop()
    controller.completeReleaseIfNeeded(observedPressProgress: 0)

    XCTAssertEqual(events, ["out", "pressed-out"])
    XCTAssertFalse(controller.isPressed)
    XCTAssertFalse(controller.isTouchActive)

    controller.refreshLiveConfiguration(enabled)
    controller.handleTouchChange(isInside: true, configuration: enabled)
    controller.handleTouchEnd(isInside: true, configuration: enabled)
    spinMainRunLoop()
    controller.completeReleaseIfNeeded(observedPressProgress: 0)

    XCTAssertEqual(events, ["out", "pressed-out", "out", "press", "pressed-out"])
  }

  func testControllerCleanupDuringTouchAndReleaseIsSilent() {
    let controller = AwesomeButtonController()
    var events: [String] = []
    let configuration = makeConfiguration(
      onPress: { _ in events.append("press") },
      onPressIn: { events.append("in") },
      onPressOut: { events.append("out") },
      onPressedOut: { events.append("pressed-out") }
    )

    controller.update(configuration: configuration)
    controller.handleTouchChange(isInside: true, configuration: configuration)
    controller.cleanup()
    controller.handleTouchEnd(isInside: true, configuration: configuration)
    spinMainRunLoop()
    controller.completeReleaseIfNeeded(observedPressProgress: 0)

    XCTAssertEqual(events, ["in"])
    XCTAssertFalse(controller.isMounted)
    XCTAssertFalse(controller.isTouchActive)
  }

  func testReentrantTeardownAtEveryOrdinaryConsumerBoundaryStopsLaterDispatch() {
    var events: [String] = []

    var controller = AwesomeButtonController()
    var configuration: AwesomeButtonResolvedConfiguration!
    configuration = makeConfiguration(
      onPress: { _ in events.append("press") },
      onPressIn: {
        events.append("in")
        controller.cleanup()
      },
      onPressOut: { events.append("out") },
      onPressedIn: { events.append("pressed-in") },
      onPressedOut: { events.append("pressed-out") }
    )
    controller.update(configuration: configuration)
    controller.handleTouchChange(isInside: true, configuration: configuration)
    XCTAssertEqual(events, ["in"])

    events.removeAll()
    controller = AwesomeButtonController()
    configuration = makeConfiguration(
      onPress: { _ in events.append("press") },
      onPressIn: { events.append("in") },
      onPressOut: { events.append("out") },
      onPressedIn: {
        events.append("pressed-in")
        controller.cleanup()
      },
      onPressedOut: { events.append("pressed-out") }
    )
    controller.update(configuration: configuration)
    controller.handleTouchChange(isInside: true, configuration: configuration)
    controller.handleTouchEnd(isInside: true, configuration: configuration)
    spinMainRunLoop()
    XCTAssertEqual(events, ["in", "pressed-in"])

    events.removeAll()
    controller = AwesomeButtonController()
    configuration = makeConfiguration(
      onPress: { _ in events.append("press") },
      onPressIn: { events.append("in") },
      onPressOut: {
        events.append("out")
        controller.cleanup()
      },
      onPressedOut: { events.append("pressed-out") }
    )
    controller.update(configuration: configuration)
    controller.handleTouchChange(isInside: true, configuration: configuration)
    controller.handleTouchEnd(isInside: true, configuration: configuration)
    spinMainRunLoop()
    XCTAssertEqual(events, ["in", "out"])

    events.removeAll()
    controller = AwesomeButtonController()
    configuration = makeConfiguration(
      onPress: { _ in
        events.append("press")
        controller.cleanup()
      },
      onPressIn: { events.append("in") },
      onPressOut: { events.append("out") },
      onPressedOut: { events.append("pressed-out") }
    )
    controller.update(configuration: configuration)
    controller.handleTouchChange(isInside: true, configuration: configuration)
    controller.handleTouchEnd(isInside: true, configuration: configuration)
    spinMainRunLoop()
    XCTAssertEqual(events, ["in", "out", "press"])

    events.removeAll()
    controller = AwesomeButtonController()
    configuration = makeConfiguration(
      onLongPress: {
        events.append("long")
        controller.cleanup()
      },
      onPressIn: { events.append("in") },
      onPressOut: { events.append("out") },
      onPressedOut: { events.append("pressed-out") }
    )
    controller.update(configuration: configuration)
    controller.handleTouchChange(isInside: true, configuration: configuration)
    controller.handleLongPress(configuration: configuration)
    controller.handleTouchEnd(isInside: false, configuration: configuration)
    spinMainRunLoop()
    XCTAssertEqual(events, ["in", "long"])
  }

  func testDeferredProgressPressUsesLatestCallbackAndRollsBackWhenAbsent() {
    let controller = AwesomeButtonController()
    var events: [String] = []
    let onPressExpectation = expectation(description: "latest progress callback")
    let configurationA = makeConfiguration(
      onPress: { _ in events.append("A") },
      progress: true,
      onProgressStart: { events.append("start") },
      onProgressEnd: { events.append("end") }
    )
    let configurationB = makeConfiguration(
      onPress: { _ in
        events.append("B")
        onPressExpectation.fulfill()
      },
      progress: true,
      onProgressStart: { events.append("start-B") },
      onProgressEnd: { events.append("end-B") }
    )

    controller.update(configuration: configurationA)
    controller.handleTouchChange(isInside: true, configuration: configurationA)
    controller.handleTouchEnd(isInside: true, configuration: configurationA)
    controller.refreshLiveConfiguration(configurationB)
    wait(for: [onPressExpectation], timeout: 0.3)
    XCTAssertEqual(events, ["start-B", "B"])

    controller.cleanup()
    events.removeAll()

    let rollbackController = AwesomeButtonController()
    let rollbackExpectation = expectation(description: "missing progress callback rolls back")
    let progressConfiguration = makeConfiguration(
      onPress: { _ in events.append("obsolete") },
      progress: true,
      onProgressStart: { events.append("start") },
      onProgressEnd: {
        events.append("end")
        rollbackExpectation.fulfill()
      }
    )
    let missingConfiguration = makeConfiguration(
      onPress: nil,
      progress: true,
      onProgressEnd: {
        events.append("end")
        rollbackExpectation.fulfill()
      }
    )

    rollbackController.update(configuration: progressConfiguration)
    rollbackController.handleTouchChange(isInside: true, configuration: progressConfiguration)
    rollbackController.handleTouchEnd(isInside: true, configuration: progressConfiguration)
    DispatchQueue.main.async {
      rollbackController.refreshLiveConfiguration(missingConfiguration)
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
      rollbackController.completeReleaseIfNeeded(observedPressProgress: 0)
    }
    wait(for: [rollbackExpectation], timeout: 0.5)
    XCTAssertEqual(events, ["start", "end"])
    XCTAssertFalse(rollbackController.isBusy)
  }

  func testProgressCompletionSnapshotsAcceptedCallbacksAndDefersExecution() {
    let controller = AwesomeButtonController()
    var events: [String] = []
    var capturedHandle: AwesomeButtonProgressHandle?
    let onPressExpectation = expectation(description: "progress callback")
    let completionExpectation = expectation(description: "progress completion")
    let configurationA = makeConfiguration(
      onPress: { handle in
        events.append("press")
        capturedHandle = handle
        onPressExpectation.fulfill()
      },
      progress: true,
      onPressedOut: { events.append("pressed-out-A") },
      onProgressEnd: {
        events.append("end-A")
        completionExpectation.fulfill()
      }
    )
    let configurationB = makeConfiguration(
      onPress: { _ in events.append("press-B") },
      progress: true,
      onPressedOut: { events.append("pressed-out-B") },
      onProgressEnd: { events.append("end-B") }
    )

    controller.update(configuration: configurationA)
    controller.handleTouchChange(isInside: true, configuration: configurationA)
    controller.handleTouchEnd(isInside: true, configuration: configurationA)
    wait(for: [onPressExpectation], timeout: 0.3)

    capturedHandle?.callAsFunction {
      events.append("completion")
    }
    capturedHandle?.callAsFunction {
      events.append("duplicate")
    }
    XCTAssertEqual(events, ["press"])
    controller.refreshLiveConfiguration(configurationB)
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
      controller.completeReleaseIfNeeded(observedPressProgress: 0)
    }

    wait(for: [completionExpectation], timeout: 1)
    XCTAssertEqual(
      events,
      ["press", "pressed-out-B", "completion", "end-A"]
    )
  }

  func testSynchronousProgressCompletionThenTeardownCancelsQueuedWork() {
    let controller = AwesomeButtonController()
    var events: [String] = []
    let onPressExpectation = expectation(description: "progress callback returns")
    let configuration = makeConfiguration(
      onPress: { handle in
        events.append("press")
        handle?.callAsFunction { events.append("completion") }
        handle?.callAsFunction { events.append("duplicate") }
        controller.cleanup()
        events.append("press-return")
        onPressExpectation.fulfill()
      },
      progress: true,
      onPressedOut: { events.append("pressed-out") },
      onProgressEnd: { events.append("end") }
    )

    controller.update(configuration: configuration)
    controller.handleTouchChange(isInside: true, configuration: configuration)
    controller.handleTouchEnd(isInside: true, configuration: configuration)
    wait(for: [onPressExpectation], timeout: 0.3)
    spinMainRunLoop(0.6)

    XCTAssertEqual(events, ["press", "press-return"])
  }

  func testProgressStartMountedInvalidationRollsBackExactlyOnce() {
    let controller = AwesomeButtonController()
    var events: [String] = []
    let rollbackExpectation = expectation(description: "progress rollback")
    var disabledConfiguration: AwesomeButtonResolvedConfiguration!
    let configuration = makeConfiguration(
      onPress: { _ in events.append("obsolete") },
      progress: true,
      onProgressStart: {
        events.append("start")
        controller.refreshLiveConfiguration(disabledConfiguration)
      },
      onProgressEnd: {
        events.append("end")
        rollbackExpectation.fulfill()
      }
    )
    disabledConfiguration = makeConfiguration(
      onPress: { _ in events.append("disabled-press") },
      disabled: true,
      progress: true,
      onProgressEnd: {
        events.append("end")
        rollbackExpectation.fulfill()
      }
    )

    controller.update(configuration: configuration)
    controller.handleTouchChange(isInside: true, configuration: configuration)
    controller.handleTouchEnd(isInside: true, configuration: configuration)
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
      controller.completeReleaseIfNeeded(observedPressProgress: 0)
    }
    wait(for: [rollbackExpectation], timeout: 0.5)

    XCTAssertEqual(events, ["start", "end"])
    XCTAssertFalse(controller.isBusy)
  }

  func testMountedInvalidationAfterProgressDispatchRollsBackAndRejectsCompletion() {
    let controller = AwesomeButtonController()
    var events: [String] = []
    var capturedHandle: AwesomeButtonProgressHandle?
    let pressExpectation = expectation(description: "progress callback")
    let rollbackExpectation = expectation(description: "progress rollback")
    let enabledConfiguration = makeConfiguration(
      onPress: { handle in
        events.append("press")
        capturedHandle = handle
        pressExpectation.fulfill()
      },
      progress: true,
      onProgressStart: { events.append("start") },
      onProgressEnd: {
        events.append("end")
        rollbackExpectation.fulfill()
      }
    )
    let disabledConfiguration = makeConfiguration(
      disabled: true,
      progress: true,
      onProgressEnd: {
        events.append("end")
        rollbackExpectation.fulfill()
      }
    )

    controller.update(configuration: enabledConfiguration)
    controller.handleTouchChange(isInside: true, configuration: enabledConfiguration)
    controller.handleTouchEnd(isInside: true, configuration: enabledConfiguration)
    wait(for: [pressExpectation], timeout: 0.3)

    controller.refreshLiveConfiguration(disabledConfiguration)
    capturedHandle?.callAsFunction { events.append("completion") }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
      controller.completeReleaseIfNeeded(observedPressProgress: 0)
    }
    wait(for: [rollbackExpectation], timeout: 0.5)

    XCTAssertEqual(events, ["start", "press", "end"])
    XCTAssertFalse(controller.isBusy)
  }

  func testConfigurationSignatureIncludesPreviouslyOmittedVisualFields() {
    let first = makeConfiguration(
      style: AwesomeButtonStyle(
        pressedOverlayColor: .red,
        disabledShadowColor: .black
      )
    )
    let second = makeConfiguration(
      style: AwesomeButtonStyle(
        pressedOverlayColor: .blue,
        disabledShadowColor: .white
      )
    )

    XCTAssertNotEqual(first.signature, second.signature)
  }

  func testCurrentContentModeWinsOverControllerTransitionText() {
    XCTAssertNil(
      resolvedAwesomeButtonDisplayText(
        childText: nil,
        transitionText: "Obsolete text"
      )
    )
    XCTAssertEqual(
      resolvedAwesomeButtonDisplayText(
        childText: "Current text",
        transitionText: nil
      ),
      "Current text"
    )
    XCTAssertEqual(
      resolvedAwesomeButtonDisplayText(
        childText: "Target text",
        transitionText: "Transition frame"
      ),
      "Transition frame"
    )
  }

  func testHostedGenericAndAuxiliaryContentDriveAutoWidthButExtraDoesNot() throws {
    let model = HostedGenericButtonModel()
    let host = host(HostedGenericButtonHarness(model: model))
    defer { host.teardown() }

    spinMainRunLoop(0.12)
    let surface = try XCTUnwrap(findTouchSurface(in: host.controller.view))
    let shortWidth = surface.bounds.width
    XCTAssertGreaterThanOrEqual(shortWidth, 52)

    model.label = "A substantially wider custom label"
    spinMainRunLoop(0.12)
    let longWidth = surface.bounds.width
    XCTAssertGreaterThan(longWidth, shortWidth)

    model.beforeWidth = 24
    model.afterWidth = 30
    spinMainRunLoop(0.12)
    let auxiliaryWidth = surface.bounds.width
    XCTAssertGreaterThan(auxiliaryWidth, longWidth)

    model.extraWidth = 240
    spinMainRunLoop(0.12)
    XCTAssertEqual(surface.bounds.width, auxiliaryWidth, accuracy: 1)
  }

  func testHostedPlaceholderAndChangingStringContentNeverCollapseBelowFaceHeight() throws {
    let model = HostedStringButtonModel()
    let host = host(HostedStringButtonHarness(model: model))
    defer { host.teardown() }

    spinMainRunLoop(0.12)
    let surface = try XCTUnwrap(findTouchSurface(in: host.controller.view))
    XCTAssertGreaterThanOrEqual(surface.bounds.width, 52)

    model.child = "A much wider value"
    spinMainRunLoop(0.12)
    let expandedWidth = surface.bounds.width
    XCTAssertGreaterThan(expandedWidth, 52)

    model.child = nil
    spinMainRunLoop(0.12)
    XCTAssertGreaterThanOrEqual(surface.bounds.width, 52)
  }

  func testHostedAnimatedStringAutoWidthMovesMonotonicallyBetweenEndpoints() throws {
    let model = HostedStringButtonModel()
    model.child = "Launch"
    model.textTransition = true
    let host = host(HostedStringButtonHarness(model: model))
    defer { host.teardown() }

    spinMainRunLoop(0.12)
    let surface = try XCTUnwrap(findTouchSurface(in: host.controller.view))
    let shortWidth = surface.bounds.width

    model.animateSize = true
    model.child = "View analytics dashboard"
    let growthSamples = sampleTouchSurfaceWidths(in: host.controller, duration: 0.55)
    let longWidth = try XCTUnwrap(growthSamples.last)

    XCTAssertGreaterThan(longWidth, shortWidth)
    assertMonotonic(
      growthSamples,
      direction: .increasing,
      lowerBound: shortWidth,
      upperBound: longWidth
    )

    model.child = "Launch"
    let shrinkSamples = sampleTouchSurfaceWidths(in: host.controller, duration: 0.55)
    let settledShortWidth = try XCTUnwrap(shrinkSamples.last)

    XCTAssertEqual(settledShortWidth, shortWidth, accuracy: 1)
    assertMonotonic(
      shrinkSamples,
      direction: .decreasing,
      lowerBound: settledShortWidth,
      upperBound: longWidth
    )
  }

  func testHostedDisablePlaceholderAndRemovalCancelOrTeardownWithCurrentClosures() throws {
    let model = HostedStringButtonModel()
    let host = host(HostedStringButtonHarness(model: model))
    defer { host.teardown() }

    spinMainRunLoop(0.12)
    var surface = try XCTUnwrap(findTouchSurface(in: host.controller.view))
    surface.beginTouch()
    model.disabled = true
    spinMainRunLoop(0.55)
    XCTAssertEqual(model.events, ["in-A", "out-A", "pressed-out-A"])

    model.disabled = false
    model.callbackVersion = "B"
    spinMainRunLoop(0.12)
    surface = try XCTUnwrap(findTouchSurface(in: host.controller.view))
    surface.beginTouch()
    model.child = nil
    spinMainRunLoop(0.55)
    XCTAssertEqual(
      model.events,
      ["in-A", "out-A", "pressed-out-A", "in-B", "out-B", "pressed-out-B"]
    )

    model.child = "Ready"
    model.callbackVersion = "C"
    spinMainRunLoop(0.12)
    surface = try XCTUnwrap(findTouchSurface(in: host.controller.view))
    surface.beginTouch()
    model.mounted = false
    spinMainRunLoop(0.55)
    XCTAssertEqual(
      model.events,
      [
        "in-A", "out-A", "pressed-out-A",
        "in-B", "out-B", "pressed-out-B",
        "in-C",
      ]
    )
  }

  func testHostedSizingModeChangePreservesActiveTouchAndUsesCurrentCallbacks() throws {
    let model = HostedStringButtonModel()
    let host = host(HostedStringButtonHarness(model: model))
    defer { host.teardown() }

    spinMainRunLoop(0.12)
    let originalSurface = try XCTUnwrap(findTouchSurface(in: host.controller.view))
    originalSurface.beginTouch()

    model.callbackVersion = "B"
    model.stretch = true
    spinMainRunLoop(0.12)

    let updatedSurface = try XCTUnwrap(findTouchSurface(in: host.controller.view))
    XCTAssertTrue(originalSurface === updatedSurface)
    XCTAssertTrue(updatedSurface.isTouchActive)

    updatedSurface.endTouch(isInside: true)
    spinMainRunLoop(0.55)
    XCTAssertEqual(
      model.events,
      ["in-A", "out-B", "press-B", "pressed-out-B"]
    )
  }

  private func configure(
    _ surface: ButtonTouchSurfaceView,
    isDisabled: Bool = false,
    onTouchEnd: @escaping (Bool) -> Void = { _ in },
    onLongPress: (() -> Void)? = nil
  ) {
    surface.update(
      isDisabled: isDisabled,
      onTouchChange: { _ in },
      onTouchEnd: onTouchEnd,
      onLongPress: onLongPress,
      onDismantle: {}
    )
  }

  private func spinMainRunLoop(_ duration: TimeInterval = 0.05) {
    let expectation = expectation(description: "main run loop advances")
    DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
      expectation.fulfill()
    }
    wait(for: [expectation], timeout: duration + 0.5)
  }

  private enum WidthDirection {
    case increasing
    case decreasing
  }

  private func sampleTouchSurfaceWidths(
    in controller: UIViewController,
    duration: TimeInterval,
    interval: TimeInterval = 1.0 / 120.0
  ) -> [CGFloat] {
    let deadline = Date().addingTimeInterval(duration)
    var samples: [CGFloat] = []

    while Date() < deadline {
      controller.view.setNeedsLayout()
      controller.view.layoutIfNeeded()
      if let surface = findTouchSurface(in: controller.view) {
        samples.append(surface.bounds.width)
      }
      RunLoop.main.run(until: Date().addingTimeInterval(interval))
    }

    controller.view.setNeedsLayout()
    controller.view.layoutIfNeeded()
    if let surface = findTouchSurface(in: controller.view) {
      samples.append(surface.bounds.width)
    }
    return samples
  }

  private func assertMonotonic(
    _ samples: [CGFloat],
    direction: WidthDirection,
    lowerBound: CGFloat,
    upperBound: CGFloat,
    tolerance: CGFloat = 1
  ) {
    XCTAssertGreaterThan(samples.count, 2)
    for sample in samples {
      XCTAssertGreaterThanOrEqual(sample, lowerBound - tolerance)
      XCTAssertLessThanOrEqual(sample, upperBound + tolerance)
    }
    for (previous, next) in zip(samples, samples.dropFirst()) {
      switch direction {
      case .increasing:
        XCTAssertGreaterThanOrEqual(next + tolerance, previous)
      case .decreasing:
        XCTAssertLessThanOrEqual(next - tolerance, previous)
      }
    }
  }

  private func host<Content: View>(_ content: Content) -> HostedView {
    let controller = UIHostingController(rootView: content)
    let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
    window.rootViewController = controller
    window.makeKeyAndVisible()
    controller.view.frame = window.bounds
    controller.view.setNeedsLayout()
    controller.view.layoutIfNeeded()
    return HostedView(window: window, controller: controller)
  }

  private func findTouchSurface(in view: UIView) -> ButtonTouchSurfaceView? {
    if let surface = view as? ButtonTouchSurfaceView {
      return surface
    }

    for subview in view.subviews {
      if let result = findTouchSurface(in: subview) {
        return result
      }
    }

    return nil
  }
}

@MainActor
private final class HostedGenericButtonModel: ObservableObject {
  @Published var label = "Go"
  @Published var beforeWidth: CGFloat = 0
  @Published var afterWidth: CGFloat = 0
  @Published var extraWidth: CGFloat = 0
}

private struct HostedGenericButtonHarness: View {
  @ObservedObject var model: HostedGenericButtonModel

  var body: some View {
    AwesomeButton(
      onPress: { _ in },
      before: model.beforeWidth > 0
        ? AnyView(Color.clear.frame(width: model.beforeWidth, height: 12))
        : nil,
      after: model.afterWidth > 0
        ? AnyView(Color.clear.frame(width: model.afterWidth, height: 12))
        : nil,
      extra: model.extraWidth > 0
        ? AnyView(Color.clear.frame(width: model.extraWidth, height: 12))
        : nil,
      animateSize: false,
      hapticOnPress: false,
      label: {
        Text(model.label)
          .fixedSize(horizontal: true, vertical: false)
      })
  }
}

@MainActor
private final class HostedStringButtonModel: ObservableObject {
  @Published var child: String? = "Ready"
  @Published var disabled = false
  @Published var mounted = true
  @Published var callbackVersion = "A"
  @Published var stretch = false
  @Published var animateSize = false
  @Published var textTransition = false
  var events: [String] = []
}

private struct HostedStringButtonHarness: View {
  @ObservedObject var model: HostedStringButtonModel

  @ViewBuilder
  var body: some View {
    let version = model.callbackVersion
    if model.mounted {
      AwesomeButton(
        child: model.child,
        onPress: { _ in model.events.append("press-\(version)") },
        disabled: model.disabled,
        stretch: model.stretch,
        animateSize: model.animateSize,
        textTransition: model.textTransition,
        hapticOnPress: false,
        onPressIn: { model.events.append("in-\(version)") },
        onPressOut: { model.events.append("out-\(version)") },
        onPressedOut: { model.events.append("pressed-out-\(version)") }
      )
    }
  }
}

@MainActor
private struct HostedView {
  let window: UIWindow
  let controller: UIViewController

  func teardown() {
    window.isHidden = true
    window.rootViewController = nil
  }
}

@MainActor
private func makeConfiguration(
  childText: String? = "Button",
  onPress: AwesomeButtonPressCallback? = { _ in },
  onLongPress: (() -> Void)? = nil,
  disabled: Bool = false,
  style: AwesomeButtonStyle = AwesomeButtonThemeData.fallbackStyle,
  progress: Bool = false,
  onPressIn: (() -> Void)? = nil,
  onPressOut: (() -> Void)? = nil,
  onPressedIn: (() -> Void)? = nil,
  onPressedOut: (() -> Void)? = nil,
  onProgressStart: (() -> Void)? = nil,
  onProgressEnd: (() -> Void)? = nil
) -> AwesomeButtonResolvedConfiguration {
  AwesomeButtonResolvedConfiguration(
    childText: childText,
    labelView: nil,
    beforeView: nil,
    afterView: nil,
    extraView: nil,
    onPress: onPress,
    onLongPress: onLongPress,
    disabled: disabled,
    width: nil,
    height: 52,
    paddingHorizontal: 16,
    paddingTop: 0,
    paddingBottom: 0,
    stretch: false,
    style: style,
    activeOpacity: 1,
    debouncedPressTime: 0,
    progress: progress,
    showProgressBar: true,
    progressLoadingTime: 1,
    animateSize: false,
    textTransition: false,
    textTransitionSlotStaggerMs: defaultTextTransitionSlotStaggerMs,
    animatedPlaceholder: true,
    hapticOnPress: false,
    onPressIn: onPressIn,
    onPressOut: onPressOut,
    onPressedIn: onPressedIn,
    onPressedOut: onPressedOut,
    onProgressStart: onProgressStart,
    onProgressEnd: onProgressEnd
  )
}
