import XCTest
import SwiftUI
@testable import SwiftAwesomeButton

final class MeasurementAndBehaviorTests: XCTestCase {
    func testShellPresentationVectorArithmeticPreservesComponents() {
        let lhs = AwesomeButtonShellPresentationVector(width: 120, height: 52, pressProgress: 0.25, styleTransitionProgress: 0.4)
        let rhs = AwesomeButtonShellPresentationVector(width: 40, height: 8, pressProgress: 0.5, styleTransitionProgress: 0.35)

        let sum = lhs + rhs
        XCTAssertEqual(sum.width, 160, accuracy: 0.0001)
        XCTAssertEqual(sum.height, 60, accuracy: 0.0001)
        XCTAssertEqual(sum.pressProgress, 0.75, accuracy: 0.0001)
        XCTAssertEqual(sum.styleTransitionProgress, 0.75, accuracy: 0.0001)

        let difference = lhs - rhs
        XCTAssertEqual(difference.width, 80, accuracy: 0.0001)
        XCTAssertEqual(difference.height, 44, accuracy: 0.0001)
        XCTAssertEqual(difference.pressProgress, -0.25, accuracy: 0.0001)
        XCTAssertEqual(difference.styleTransitionProgress, 0.05, accuracy: 0.0001)
    }

    func testShellPresentationVectorScaleAffectsAllComponents() {
        var vector = AwesomeButtonShellPresentationVector(width: 120, height: 52, pressProgress: 0.25, styleTransitionProgress: 0.4)

        vector.scale(by: 0.5)

        XCTAssertEqual(vector.width, 60, accuracy: 0.0001)
        XCTAssertEqual(vector.height, 26, accuracy: 0.0001)
        XCTAssertEqual(vector.pressProgress, 0.125, accuracy: 0.0001)
        XCTAssertEqual(vector.styleTransitionProgress, 0.2, accuracy: 0.0001)
    }

    func testShellPresentationVectorMagnitudeIncludesAllComponents() {
        let vector = AwesomeButtonShellPresentationVector(width: 3, height: 4, pressProgress: 2, styleTransitionProgress: 5)

        XCTAssertEqual(vector.magnitudeSquared, 54, accuracy: 0.0001)
    }

    func testInterpolateAwesomeButtonStyleInterpolatesVisualFields() {
        let from = AwesomeButtonStyle(
            backgroundColor: .red,
            depthColor: .red,
            foregroundColor: .white,
            borderRadius: 4,
            borderWidth: 0,
            borderColor: .red,
            raiseAmount: 6
        )
        let to = AwesomeButtonStyle(
            backgroundColor: .blue,
            depthColor: .blue,
            foregroundColor: .black,
            borderRadius: 12,
            borderWidth: 2,
            borderColor: .blue,
            raiseAmount: 10
        )

        let mid = interpolateAwesomeButtonStyle(from, to, progress: 0.5)
        let expectedBackground = interpolateColor(
            resolvedVisualStyle(from).backgroundColor,
            resolvedVisualStyle(to).backgroundColor,
            progress: 0.5
        )
        let expectedBorder = interpolateColor(
            resolvedVisualStyle(from).borderColor,
            resolvedVisualStyle(to).borderColor,
            progress: 0.5
        )

        XCTAssertTrue(colorsEqual(mid.backgroundColor, expectedBackground))
        XCTAssertTrue(colorsEqual(mid.borderColor, expectedBorder))
        XCTAssertEqual(mid.borderWidth ?? -1, 1, accuracy: 0.0001)
        XCTAssertEqual(mid.borderRadius ?? -1, 8, accuracy: 0.0001)
        XCTAssertEqual(mid.raiseAmount ?? -1, 8, accuracy: 0.0001)
    }

    func testResolvedVisualStyleDoesNotInjectFallbackDisabledFillIntoTransparentFlatButtons() {
        let style = AwesomeButtonStyle(
            backgroundColor: .clear,
            depthColor: .clear,
            shadowColor: .clear,
            foregroundColor: .white,
            borderWidth: 0,
            borderColor: .clear,
            raiseAmount: 0
        )

        let resolved = resolvedVisualStyle(style)

        XCTAssertTrue(colorsEqual(resolved.backgroundColor, .clear))
        XCTAssertNil(resolved.disabledBackgroundColor)
        XCTAssertNil(resolved.disabledDepthColor)
        XCTAssertNil(resolved.disabledShadowColor)
    }

    func testVisualPressProgressClampsReleaseOvershoot() {
        XCTAssertEqual(clampedVisualPressProgress(-0.12), 0, accuracy: 0.0001)
        XCTAssertEqual(clampedVisualPressProgress(0.5), 0.5, accuracy: 0.0001)
        XCTAssertEqual(clampedVisualPressProgress(1.2), 1, accuracy: 0.0001)
    }

    func testGeometryPressProgressAllowsBoundedReleaseOvershoot() {
        XCTAssertEqual(shellGeometryPressProgress(-0.12), -0.12, accuracy: 0.0001)
        XCTAssertEqual(shellGeometryPressProgress(-1), releaseGeometryPressProgressFloor, accuracy: 0.0001)
        XCTAssertEqual(shellGeometryPressProgress(1.2), 1, accuracy: 0.0001)
    }

    func testShellMetricsLockFaceAndDepthToResolvedShellWidth() {
        let metrics = resolveAwesomeButtonShellMetrics(width: 240, height: 52)

        XCTAssertEqual(metrics.shellWidth, 240, accuracy: 0.0001)
        XCTAssertEqual(metrics.shellHeight, 52, accuracy: 0.0001)
        XCTAssertEqual(metrics.faceWidth, metrics.shellWidth, accuracy: 0.0001)
        XCTAssertEqual(metrics.depthWidth, metrics.shellWidth, accuracy: 0.0001)
        XCTAssertEqual(metrics.shadowWidth, 240 * 0.98, accuracy: 0.0001)
    }

    func testGrowAndShrinkFlowsResolveCorrectly() {
        XCTAssertEqual(resolveAutoWidthTextFlow(currentWidth: nil, targetWidth: 68), .initial)
        XCTAssertEqual(resolveAutoWidthTextFlow(currentWidth: 68, targetWidth: 68), .textOnly)
        XCTAssertEqual(resolveAutoWidthTextFlow(currentWidth: 68, targetWidth: 220), .growFirst)
        XCTAssertEqual(resolveAutoWidthTextFlow(currentWidth: 220, targetWidth: 68), .shrinkLast)
    }

    func testWidthModeBridgeSnapsAcrossModes() {
        XCTAssertTrue(shouldSnapWidthBridge(previous: nil, next: .auto))
        XCTAssertTrue(shouldSnapWidthBridge(previous: .fixed, next: .auto))
        XCTAssertFalse(shouldSnapWidthBridge(previous: .fixed, next: .fixed))
    }

    func testFixedSizeAnimationDurationRemainsAt175ms() {
        XCTAssertEqual(sizeAnimationDuration, 0.175, accuracy: 0.0001)
    }

    func testDefaultTextTransitionSlotStaggerIs7ms() {
        XCTAssertEqual(defaultTextTransitionSlotStaggerMs, 7)
    }

    func testPlaceholderLoopDurationMatchesFlutter() {
        XCTAssertEqual(placeholderLoopDuration, 3.223, accuracy: 0.0001)
    }

    func testPlaceholderAnimationRequiresAnimatedFlagAndPositiveWidth() {
        XCTAssertFalse(shouldRunPlaceholderAnimation(animated: false, measuredWidth: 100))
        XCTAssertFalse(shouldRunPlaceholderAnimation(animated: true, measuredWidth: 0))
        XCTAssertTrue(shouldRunPlaceholderAnimation(animated: true, measuredWidth: 100))
    }

    func testPlaceholderLoopPhaseWrapsAcrossRepeatedCycles() {
        XCTAssertEqual(placeholderLoopPhase(elapsed: 0), 0, accuracy: 0.0001)
        XCTAssertEqual(placeholderLoopPhase(elapsed: placeholderLoopDuration * 0.5), 0.5, accuracy: 0.0001)
        XCTAssertEqual(placeholderLoopPhase(elapsed: placeholderLoopDuration), 0, accuracy: 0.0001)
        XCTAssertEqual(placeholderLoopPhase(elapsed: placeholderLoopDuration * 1.25), 0.25, accuracy: 0.0001)
        XCTAssertEqual(placeholderLoopPhase(elapsed: placeholderLoopDuration * 3.75), 0.75, accuracy: 0.0001)
    }

    func testPlaceholderShimmerWidthUsesFortyPercentOfLaneWidth() {
        let width: CGFloat = 100

        XCTAssertEqual(placeholderShimmerWidth(width: width), 40, accuracy: 0.0001)
    }

    func testPlaceholderShimmerLeadingXPingPongsAcrossLane() {
        let laneWidth: CGFloat = 100
        let bandWidth = placeholderShimmerWidth(width: laneWidth)

        XCTAssertEqual(
            placeholderShimmerLeadingX(phase: 0.0, laneWidth: laneWidth, bandWidth: bandWidth),
            -40,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            placeholderShimmerLeadingX(phase: 0.25, laneWidth: laneWidth, bandWidth: bandWidth),
            30,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            placeholderShimmerLeadingX(phase: 0.5, laneWidth: laneWidth, bandWidth: bandWidth),
            100,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            placeholderShimmerLeadingX(phase: 0.75, laneWidth: laneWidth, bandWidth: bandWidth),
            30,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            placeholderShimmerLeadingX(phase: 1.0, laneWidth: laneWidth, bandWidth: bandWidth),
            -40,
            accuracy: 0.0001
        )
    }

    func testPlaceholderVisibleShimmerSegmentClipsVirtualPathToLane() {
        let laneWidth: CGFloat = 100
        let bandWidth = placeholderShimmerWidth(width: laneWidth)

        XCTAssertEqual(
            placeholderVisibleShimmerSegment(
                phase: 0.0,
                laneWidth: laneWidth,
                bandWidth: bandWidth
            ),
            PlaceholderShimmerVisibleSegment(leadingX: 0, width: 0)
        )
        XCTAssertEqual(
            placeholderVisibleShimmerSegment(
                phase: 0.25,
                laneWidth: laneWidth,
                bandWidth: bandWidth
            ),
            PlaceholderShimmerVisibleSegment(leadingX: 30, width: 40)
        )
        XCTAssertEqual(
            placeholderVisibleShimmerSegment(
                phase: 0.5,
                laneWidth: laneWidth,
                bandWidth: bandWidth
            ),
            PlaceholderShimmerVisibleSegment(leadingX: 100, width: 0)
        )
        XCTAssertEqual(
            placeholderVisibleShimmerSegment(
                phase: 0.75,
                laneWidth: laneWidth,
                bandWidth: bandWidth
            ),
            PlaceholderShimmerVisibleSegment(leadingX: 30, width: 40)
        )
        XCTAssertEqual(
            placeholderVisibleShimmerSegment(
                phase: 1.0,
                laneWidth: laneWidth,
                bandWidth: bandWidth
            ),
            PlaceholderShimmerVisibleSegment(leadingX: 0, width: 0)
        )
    }

    func testPlaceholderVisibleShimmerSegmentGrowsAndShrinksAtEdges() {
        let laneWidth: CGFloat = 100
        let bandWidth = placeholderShimmerWidth(width: laneWidth)

        let enteringLeft = placeholderVisibleShimmerSegment(
            phase: 0.125,
            laneWidth: laneWidth,
            bandWidth: bandWidth
        )
        XCTAssertEqual(enteringLeft.leadingX, 0, accuracy: 0.0001)
        XCTAssertEqual(enteringLeft.width, 35, accuracy: 0.0001)

        let exitingRight = placeholderVisibleShimmerSegment(
            phase: 0.375,
            laneWidth: laneWidth,
            bandWidth: bandWidth
        )
        XCTAssertEqual(exitingRight.leadingX, 65, accuracy: 0.0001)
        XCTAssertEqual(exitingRight.width, 35, accuracy: 0.0001)
    }

    func testPlaceholderVisibleShimmerSegmentStaysInsideLaneForSampledPhases() {
        let laneWidth: CGFloat = 100
        let bandWidth = placeholderShimmerWidth(width: laneWidth)
        let phases = stride(from: 0.0, through: 1.0, by: 0.025)

        for phase in phases {
            let segment = placeholderVisibleShimmerSegment(
                phase: phase,
                laneWidth: laneWidth,
                bandWidth: bandWidth
            )

            XCTAssertGreaterThanOrEqual(segment.leadingX, 0, "phase: \(phase)")
            XCTAssertGreaterThanOrEqual(segment.width, 0, "phase: \(phase)")
            XCTAssertLessThanOrEqual(segment.leadingX + segment.width, laneWidth, "phase: \(phase)")
        }
    }

    func testPlaceholderShimmerHelpersHandleZeroWidthGracefully() {
        XCTAssertEqual(placeholderShimmerWidth(width: 0), 0, accuracy: 0.0001)
        XCTAssertEqual(
            placeholderShimmerLeadingX(phase: 0.5, laneWidth: 0, bandWidth: 0),
            0,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            placeholderVisibleShimmerSegment(phase: 0.5, laneWidth: 0, bandWidth: 40),
            PlaceholderShimmerVisibleSegment(leadingX: 0, width: 0)
        )
        XCTAssertEqual(
            placeholderVisibleShimmerSegment(phase: 0.5, laneWidth: 100, bandWidth: 0),
            PlaceholderShimmerVisibleSegment(leadingX: 0, width: 0)
        )
    }

    func testAutoWidthTextTransitionGrowTimingTracksTextDuration() {
        let sourceText = "Launch"
        let targetText = "View analytics dashboard"
        let timing = resolveAutoWidthTextTransitionTiming(
            fromText: sourceText,
            targetText: targetText,
            flow: .growFirst
        )
        let timeline = getTextTransitionTimeline(fromText: sourceText, targetText: targetText)
        let totalDuration = Double(timeline.totalDurationMs) / 1000

        XCTAssertEqual(timing.widthDelay, 0, accuracy: 0.0001)
        XCTAssertEqual(timing.textDelay, totalDuration * 0.3, accuracy: 0.0001)
        XCTAssertEqual(
            timing.widthDuration,
            totalDuration,
            accuracy: 0.0001
        )
    }

    func testAutoWidthTextTransitionShrinkTimingTracksTextDuration() {
        let sourceText = "View analytics dashboard"
        let targetText = "Launch"
        let timing = resolveAutoWidthTextTransitionTiming(
            fromText: sourceText,
            targetText: targetText,
            flow: .shrinkLast
        )
        let timeline = getTextTransitionTimeline(fromText: sourceText, targetText: targetText)
        let totalDuration = Double(timeline.totalDurationMs) / 1000

        XCTAssertEqual(timing.textDelay, 0, accuracy: 0.0001)
        XCTAssertEqual(timing.widthDelay, totalDuration * 0.3, accuracy: 0.0001)
        XCTAssertEqual(
            timing.widthDuration,
            totalDuration,
            accuracy: 0.0001
        )
    }

    func testAutoWidthTextTransitionTimingUsesConfiguredSlotStagger() {
        let sourceText = "Launch"
        let targetText = "View analytics dashboard"
        let timing = resolveAutoWidthTextTransitionTiming(
            fromText: sourceText,
            targetText: targetText,
            flow: .growFirst,
            slotStaggerMs: 12
        )
        let timeline = getTextTransitionTimeline(
            fromText: sourceText,
            targetText: targetText,
            slotStaggerMs: 12
        )
        let totalDuration = Double(timeline.totalDurationMs) / 1000

        XCTAssertEqual(timing.widthDelay, 0, accuracy: 0.0001)
        XCTAssertEqual(timing.textDelay, totalDuration * 0.3, accuracy: 0.0001)
        XCTAssertEqual(timing.widthDuration, totalDuration, accuracy: 0.0001)
    }

    @MainActor
    func testPlaceholderConfigurationsAreEffectivelyDisabledAndSuppressInteraction() {
        var pressedCount = 0
        var longPressCount = 0
        let controller = AwesomeButtonController()
        let configuration = makeResolvedConfiguration(
            text: nil,
            animateSize: false,
            textTransition: false,
            onPress: { _ in
                pressedCount += 1
            },
            onLongPress: {
                longPressCount += 1
            }
        )

        XCTAssertTrue(configuration.isEffectivelyDisabled)

        controller.update(configuration: configuration)
        controller.handleTouchChange(isInside: true)
        controller.handleTouchEnd(isInside: true)
        controller.handleLongPress()

        XCTAssertEqual(pressedCount, 0)
        XCTAssertEqual(longPressCount, 0)
        XCTAssertFalse(controller.isPressed)
        XCTAssertEqual(controller.pressProgress, 0, accuracy: 0.0001)
        XCTAssertFalse(controller.isBusy)
    }

    @MainActor
    func testGrowPathKeepsViewportCenteredDuringAutoWidthTextTransition() {
        let controller = AwesomeButtonController()
        controller.update(configuration: makeResolvedConfiguration(text: "Launch", animateSize: false, textTransition: true))
        let shortWidth = controller.resolvedWidth

        controller.update(configuration: makeResolvedConfiguration(text: "View analytics dashboard", animateSize: true, textTransition: true))

        XCTAssertEqual(controller.contentClipAlignment, .center)
        XCTAssertGreaterThan(controller.resolvedWidth ?? 0, shortWidth ?? 0)
    }

    @MainActor
    func testGrowPathStartsTextAfterConfiguredDelay() {
        let controller = AwesomeButtonController()
        let sourceText = "Launch"
        let targetText = "View analytics dashboard"
        controller.update(configuration: makeResolvedConfiguration(text: sourceText, animateSize: false, textTransition: true))

        controller.update(configuration: makeResolvedConfiguration(text: targetText, animateSize: true, textTransition: true))
        let growTiming = resolveAutoWidthTextTransitionTiming(
            fromText: sourceText,
            targetText: targetText,
            flow: .growFirst
        )

        let preTextExpectation = expectation(description: "text remains unchanged before grow text delay")
        DispatchQueue.main.asyncAfter(deadline: .now() + max(0.01, growTiming.textDelay * 0.5)) {
            XCTAssertEqual(controller.displayedText, sourceText)
            preTextExpectation.fulfill()
        }

        let transitionExpectation = expectation(description: "text transition begins after grow text delay")
        DispatchQueue.main.asyncAfter(deadline: .now() + growTiming.textDelay + 0.08) {
            XCTAssertNotEqual(controller.displayedText, sourceText)
            transitionExpectation.fulfill()
        }

        waitForExpectations(timeout: growTiming.textDelay + 0.25)
    }

    @MainActor
    func testShrinkPathUsesLeadingViewportUntilWidthSequenceCompletes() {
        let controller = AwesomeButtonController()
        let sourceText = "View analytics dashboard"
        let targetText = "Launch"
        let shrinkTiming = resolveAutoWidthTextTransitionTiming(
            fromText: sourceText,
            targetText: targetText,
            flow: .shrinkLast
        )
        controller.update(configuration: makeResolvedConfiguration(text: sourceText, animateSize: false, textTransition: true))
        let longWidth = controller.resolvedWidth

        controller.update(configuration: makeResolvedConfiguration(text: targetText, animateSize: true, textTransition: true))

        XCTAssertEqual(controller.contentClipAlignment, .leading)
        XCTAssertEqual(controller.resolvedWidth, longWidth)

        let preShrinkExpectation = expectation(description: "width remains unchanged before shrink delay")
        DispatchQueue.main.asyncAfter(deadline: .now() + max(0.01, shrinkTiming.widthDelay * 0.5)) {
            XCTAssertEqual(controller.resolvedWidth, longWidth)
            preShrinkExpectation.fulfill()
        }

        let shrinkExpectation = expectation(description: "width updates after shrink delay")
        DispatchQueue.main.asyncAfter(deadline: .now() + shrinkTiming.widthDelay + 0.08) {
            XCTAssertLessThan(controller.resolvedWidth ?? 0, longWidth ?? 0)
            shrinkExpectation.fulfill()
        }

        let resetExpectation = expectation(description: "content clip alignment resets to center")
        DispatchQueue.main.asyncAfter(deadline: .now() + shrinkTiming.widthDelay + shrinkTiming.widthDuration + 0.05) {
            XCTAssertEqual(controller.contentClipAlignment, .center)
            resetExpectation.fulfill()
        }

        waitForExpectations(timeout: shrinkTiming.widthDelay + shrinkTiming.widthDuration + 0.2)
    }

    @MainActor
    func testDeferredAutoWidthTextTransitionDoesNotDrainFromSameRunLoopAfterReleaseVisual() {
        let controller = AwesomeButtonController()
        let slotStaggerMs = 4
        let sourceText = "View analytics dashboard"
        let targetText = "Launch"
        let sourceConfiguration = makeResolvedConfiguration(
            text: sourceText,
            animateSize: false,
            textTransition: true,
            textTransitionSlotStaggerMs: slotStaggerMs
        )
        let targetConfiguration = makeResolvedConfiguration(
            text: targetText,
            animateSize: true,
            textTransition: true,
            textTransitionSlotStaggerMs: slotStaggerMs
        )

        controller.update(configuration: sourceConfiguration)
        let longWidth = controller.resolvedWidth
        controller.handleTouchChange(isInside: true)
        controller.handleTouchEnd(isInside: true)
        controller.update(configuration: targetConfiguration)

        let noDrainExpectation = expectation(description: "deferred update stays frozen on next run loop")
        DispatchQueue.main.async {
            XCTAssertEqual(controller.displayedText, sourceText)
            XCTAssertEqual(controller.resolvedWidth ?? 0, longWidth ?? 0, accuracy: 0.0001)
            XCTAssertEqual(controller.renderedConfiguration?.childText, sourceText)
            XCTAssertEqual(controller.inputConfiguration?.childText, targetText)
            noDrainExpectation.fulfill()
        }

        waitForExpectations(timeout: 0.2)
    }

    @MainActor
    func testDeferredAutoWidthTextTransitionDrainsOnlyAfterExplicitReleaseCompletion() {
        let controller = AwesomeButtonController()
        let slotStaggerMs = 4
        let sourceText = "View analytics dashboard"
        let targetText = "Launch"
        let sourceConfiguration = makeResolvedConfiguration(
            text: sourceText,
            animateSize: false,
            textTransition: true,
            textTransitionSlotStaggerMs: slotStaggerMs
        )
        let targetConfiguration = makeResolvedConfiguration(
            text: targetText,
            animateSize: true,
            textTransition: true,
            textTransitionSlotStaggerMs: slotStaggerMs
        )
        let timing = resolveAutoWidthTextTransitionTiming(
            fromText: sourceText,
            targetText: targetText,
            flow: .shrinkLast,
            slotStaggerMs: slotStaggerMs
        )

        controller.update(configuration: sourceConfiguration)
        let longWidth = controller.resolvedWidth
        controller.handleTouchChange(isInside: true)
        controller.handleTouchEnd(isInside: true)
        controller.update(configuration: targetConfiguration)

        XCTAssertEqual(controller.renderedConfiguration?.childText, sourceText)
        XCTAssertEqual(controller.inputConfiguration?.childText, targetText)
        XCTAssertEqual(controller.resolvedWidth ?? 0, longWidth ?? 0, accuracy: 0.0001)

        controller.completeReleaseIfNeeded(observedPressProgress: 0)

        XCTAssertEqual(controller.renderedConfiguration?.childText, targetText)
        XCTAssertEqual(controller.contentClipAlignment, .leading)
        XCTAssertEqual(controller.resolvedWidth ?? 0, longWidth ?? 0, accuracy: 0.0001)

        let widthExpectation = expectation(description: "width update starts only after explicit release completion")
        DispatchQueue.main.asyncAfter(deadline: .now() + timing.widthDelay + 0.08) {
            XCTAssertLessThan(controller.resolvedWidth ?? 0, longWidth ?? 0)
            widthExpectation.fulfill()
        }

        waitForExpectations(timeout: timing.widthDelay + timing.widthDuration + 0.2)
    }

    @MainActor
    func testRenderedConfigurationStaysFrozenWhileReleaseDefersEligibleUpdate() {
        let controller = AwesomeButtonController()
        let sourceConfiguration = makeResolvedConfiguration(
            text: "View analytics dashboard",
            animateSize: false,
            textTransition: true
        )
        let targetConfiguration = makeResolvedConfiguration(
            text: "Launch",
            animateSize: true,
            textTransition: true
        )

        controller.update(configuration: sourceConfiguration)
        controller.handleTouchChange(isInside: true)
        controller.handleTouchEnd(isInside: true)
        controller.update(configuration: targetConfiguration)

        XCTAssertEqual(controller.renderedConfiguration?.childText, "View analytics dashboard")
        XCTAssertEqual(controller.inputConfiguration?.childText, "Launch")
        XCTAssertEqual(controller.displayedText, "View analytics dashboard")
    }

    @MainActor
    func testNonEligibleUpdatesAreNotDeferredDuringRelease() {
        let controller = AwesomeButtonController()
        let sourceConfiguration = makeResolvedConfiguration(
            text: "View analytics dashboard",
            animateSize: false,
            textTransition: true
        )
        let fixedTargetConfiguration = makeResolvedConfiguration(
            text: "Launch",
            width: 220,
            animateSize: true,
            textTransition: false
        )

        controller.update(configuration: sourceConfiguration)
        controller.handleTouchChange(isInside: true)
        controller.handleTouchEnd(isInside: true)
        controller.update(configuration: fixedTargetConfiguration)

        XCTAssertEqual(controller.displayedText, "Launch")
        XCTAssertEqual(controller.resolvedWidth ?? 0, 220, accuracy: 0.0001)
    }

    @MainActor
    func testNewPressDuringReleaseInvalidatesReleaseGenerationAndKeepsDeferredStateFrozen() {
        let controller = AwesomeButtonController()
        let slotStaggerMs = 4
        let sourceText = "View analytics dashboard"
        let targetText = "Launch"
        let sourceConfiguration = makeResolvedConfiguration(
            text: sourceText,
            animateSize: false,
            textTransition: true,
            textTransitionSlotStaggerMs: slotStaggerMs
        )
        let targetConfiguration = makeResolvedConfiguration(
            text: targetText,
            animateSize: true,
            textTransition: true,
            textTransitionSlotStaggerMs: slotStaggerMs
        )
        controller.update(configuration: sourceConfiguration)
        controller.handleTouchChange(isInside: true)
        controller.handleTouchEnd(isInside: true)
        controller.update(configuration: targetConfiguration)
        controller.handleTouchChange(isInside: true)

        controller.completeReleaseIfNeeded(observedPressProgress: 0)

        XCTAssertEqual(controller.renderedConfiguration?.childText, sourceText)
        XCTAssertEqual(controller.inputConfiguration?.childText, targetText)
        XCTAssertEqual(controller.displayedText, sourceText)
        XCTAssertTrue(controller.isPressed)
    }

    @MainActor
    func testDeferredAutoWidthTextTransitionCoalescesToLatestUpdateAfterExplicitReleaseCompletion() {
        let controller = AwesomeButtonController()
        let slotStaggerMs = 4
        let sourceText = "Configure automation settings"
        let intermediateText = "Profile"
        let latestText = "Queue"
        let sourceConfiguration = makeResolvedConfiguration(
            text: sourceText,
            animateSize: false,
            textTransition: true,
            textTransitionSlotStaggerMs: slotStaggerMs
        )
        let intermediateConfiguration = makeResolvedConfiguration(
            text: intermediateText,
            animateSize: true,
            textTransition: true,
            textTransitionSlotStaggerMs: slotStaggerMs
        )
        let latestConfiguration = makeResolvedConfiguration(
            text: latestText,
            animateSize: true,
            textTransition: true,
            textTransitionSlotStaggerMs: slotStaggerMs
        )
        let latestTiming = resolveAutoWidthTextTransitionTiming(
            fromText: sourceText,
            targetText: latestText,
            flow: .shrinkLast,
            slotStaggerMs: slotStaggerMs
        )

        controller.update(configuration: sourceConfiguration)
        controller.handleTouchChange(isInside: true)
        controller.handleTouchEnd(isInside: true)
        controller.update(configuration: intermediateConfiguration)
        controller.update(configuration: latestConfiguration)

        XCTAssertEqual(controller.renderedConfiguration?.childText, sourceText)
        XCTAssertEqual(controller.inputConfiguration?.childText, latestText)

        controller.completeReleaseIfNeeded(observedPressProgress: 0)

        XCTAssertEqual(controller.renderedConfiguration?.childText, latestText)

        let completionExpectation = expectation(description: "latest deferred update wins")
        DispatchQueue.main.asyncAfter(deadline: .now() + latestTiming.widthDelay + latestTiming.widthDuration + 0.15) {
            XCTAssertEqual(controller.displayedText, latestText)
            completionExpectation.fulfill()
        }

        waitForExpectations(timeout: latestTiming.widthDelay + latestTiming.widthDuration + 0.35)
    }

    func testMeasurementServiceCachesByWidthAffectingSignature() {
        let service = AutoWidthMeasurementService.shared
        let short = AutoWidthMeasurementSignature(
            text: "Open",
            textFontFamily: nil,
            textSize: 14,
            textLineHeight: 20,
            paddingHorizontal: 16,
            borderWidth: 0
        )
        let long = AutoWidthMeasurementSignature(
            text: "Open analytics dashboard",
            textFontFamily: nil,
            textSize: 14,
            textLineHeight: 20,
            paddingHorizontal: 16,
            borderWidth: 0
        )

        let shortWidth = service.measureWidth(for: short)
        let cachedShortWidth = service.measureWidth(for: short)
        let longWidth = service.measureWidth(for: long)

        XCTAssertEqual(shortWidth, cachedShortWidth)
        XCTAssertGreaterThan(longWidth, shortWidth)
    }

    func testProgressHandleCallsCompletion() {
        let expectation = expectation(description: "progress handle completion")
        let handle = AwesomeButtonProgressHandle { callback in
            callback?()
        }
        handle {
            expectation.fulfill()
        }
        waitForExpectations(timeout: 0.1)
    }

    @MainActor
    func testStyleOnlyConfigurationUpdateStartsVisualTransition() {
        let controller = AwesomeButtonController()
        let sourceConfiguration = makeResolvedConfiguration(
            text: "Primary",
            width: 200,
            animateSize: false,
            textTransition: false,
            style: AwesomeButtonStyle(
                backgroundColor: .red,
                depthColor: .red,
                foregroundColor: .white,
                borderColor: .red
            )
        )
        let targetConfiguration = makeResolvedConfiguration(
            text: "Secondary",
            width: 200,
            animateSize: false,
            textTransition: false,
            style: AwesomeButtonStyle(
                backgroundColor: .blue,
                depthColor: .blue,
                foregroundColor: .black,
                borderColor: .blue
            )
        )

        controller.update(configuration: sourceConfiguration)
        controller.update(configuration: targetConfiguration)

        XCTAssertEqual(controller.styleTransitionProgress, 0, accuracy: 0.0001)
        XCTAssertNotNil(controller.styleTransitionSourceStyle)
        XCTAssertEqual(controller.renderedConfiguration?.style.visualSignature, targetConfiguration.style.visualSignature)

        let kickoffExpectation = expectation(description: "style transition kickoff")
        DispatchQueue.main.async {
            XCTAssertEqual(controller.styleTransitionProgress, 1, accuracy: 0.0001)
            kickoffExpectation.fulfill()
        }

        waitForExpectations(timeout: 0.1)
    }
}

private func makeResolvedConfiguration(
    text: String?,
    width: CGFloat? = nil,
    stretch: Bool = false,
    animateSize: Bool,
    textTransition: Bool,
    textTransitionSlotStaggerMs: Int = defaultTextTransitionSlotStaggerMs,
    style: AwesomeButtonStyle = AwesomeButtonThemeData.fallbackStyle,
    onPress: AwesomeButtonPressCallback? = nil,
    onLongPress: (() -> Void)? = nil,
    onPressOut: (() -> Void)? = nil,
    onPressedOut: (() -> Void)? = nil
) -> AwesomeButtonResolvedConfiguration {
    AwesomeButtonResolvedConfiguration(
        childText: text,
        labelView: nil,
        beforeView: nil,
        afterView: nil,
        extraView: nil,
        onPress: onPress,
        onLongPress: onLongPress,
        disabled: false,
        width: width,
        height: 60,
        paddingHorizontal: 16,
        paddingTop: 0,
        paddingBottom: 0,
        stretch: stretch,
        style: style,
        activeOpacity: 1,
        debouncedPressTime: 0,
        progress: false,
        showProgressBar: true,
        progressLoadingTime: 3,
        animateSize: animateSize,
        textTransition: textTransition,
        textTransitionSlotStaggerMs: textTransitionSlotStaggerMs,
        animatedPlaceholder: false,
        hapticOnPress: false,
        onPressIn: nil,
        onPressOut: onPressOut,
        onPressedIn: nil,
        onPressedOut: onPressedOut,
        onProgressStart: nil,
        onProgressEnd: nil
    )
}
