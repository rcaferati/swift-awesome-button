import XCTest
@testable import SwiftAwesomeButton

@MainActor
final class ProgressParityTests: XCTestCase {
    func testProgressSwapCurveStartsEndsAndOvershoots() {
        XCTAssertEqual(progressSwapCurveValue(0), 0, accuracy: 0.0001)
        XCTAssertEqual(progressSwapCurveValue(1), 1, accuracy: 0.0001)

        let samples = stride(from: 0.0, through: 1.0, by: 0.01).map { progressSwapCurveValue(CGFloat($0)) }
        XCTAssertGreaterThan(samples.max() ?? 1, 1)
    }

    func testProgressOverlayOpacityHoldsThenFades() {
        XCTAssertEqual(progressOverlayOpacityValue(elapsedMs: 0), 1, accuracy: 0.0001)
        XCTAssertEqual(progressOverlayOpacityValue(elapsedMs: progressOverlayFadeDelayMs), 1, accuracy: 0.0001)
        XCTAssertLessThan(progressOverlayOpacityValue(elapsedMs: progressOverlayFadeDelayMs + 80), 1)
        XCTAssertGreaterThan(progressOverlayOpacityValue(elapsedMs: progressOverlayFadeDelayMs + 80), 0)
        XCTAssertEqual(
            progressOverlayOpacityValue(
                elapsedMs: progressOverlayFadeDelayMs + progressOverlayFadeDurationMs
            ),
            0,
            accuracy: 0.0001
        )
    }

    func testProgressStartDefersOnPressUntilVisualsMount() {
        let onPressExpectation = expectation(description: "deferred onPress")
        let controller = AwesomeButtonController()
        var pressCallCount = 0

        let configuration = makeProgressConfiguration(
            onPress: { handle in
                pressCallCount += 1
                XCTAssertNotNil(handle)
                XCTAssertTrue(controller.isBusy)
                XCTAssertTrue(controller.isPressed)
                XCTAssertTrue(controller.showProgressVisuals)
                onPressExpectation.fulfill()
            }
        )

        controller.update(configuration: configuration)
        controller.handleTouchChange(isInside: true)
        controller.handleTouchEnd(isInside: true)

        XCTAssertEqual(pressCallCount, 0)
        wait(for: [onPressExpectation], timeout: 0.2)
    }

    func testDuplicateProgressNextCallsAreIgnored() {
        let onPressExpectation = expectation(description: "progress onPress")
        let onProgressEndExpectation = expectation(description: "progress ends once")
        let controller = AwesomeButtonController()
        var capturedHandle: AwesomeButtonProgressHandle?
        var progressEndCount = 0

        let configuration = makeProgressConfiguration(
            onPress: { handle in
                capturedHandle = handle
                onPressExpectation.fulfill()
            },
            onProgressEnd: {
                progressEndCount += 1
                if progressEndCount == 1 {
                    onProgressEndExpectation.fulfill()
                }
            }
        )

        controller.update(configuration: configuration)
        controller.handleTouchChange(isInside: true)
        controller.handleTouchEnd(isInside: true)

        wait(for: [onPressExpectation], timeout: 0.2)
        capturedHandle?.callAsFunction()
        capturedHandle?.callAsFunction()
        scheduleReleaseCompletion(controller)

        wait(for: [onProgressEndExpectation], timeout: 1.2)
        XCTAssertEqual(progressEndCount, 1)
        XCTAssertFalse(controller.isBusy)
        XCTAssertFalse(controller.showProgressVisuals)
        XCTAssertEqual(controller.contentTransitionValue, 1, accuracy: 0.05)
        XCTAssertEqual(controller.activityTransitionValue, 0, accuracy: 0.05)
    }

    func testNoBarProgressStillCompletesAndSwaps() {
        let onPressExpectation = expectation(description: "progress no bar onPress")
        let onProgressEndExpectation = expectation(description: "progress no bar ends")
        let controller = AwesomeButtonController()
        var capturedHandle: AwesomeButtonProgressHandle?
        var progressEndCount = 0

        let configuration = makeProgressConfiguration(
            showProgressBar: false,
            onPress: { handle in
                capturedHandle = handle
                onPressExpectation.fulfill()
            },
            onProgressEnd: {
                progressEndCount += 1
                onProgressEndExpectation.fulfill()
            }
        )

        controller.update(configuration: configuration)
        controller.handleTouchChange(isInside: true)
        controller.handleTouchEnd(isInside: true)

        wait(for: [onPressExpectation], timeout: 0.2)
        XCTAssertTrue(controller.showProgressVisuals)
        capturedHandle?.callAsFunction()
        scheduleReleaseCompletion(controller)
        wait(for: [onProgressEndExpectation], timeout: 1.2)

        XCTAssertEqual(progressEndCount, 1)
        XCTAssertFalse(controller.isBusy)
        XCTAssertFalse(controller.showProgressVisuals)
    }
}

@MainActor
private func makeProgressConfiguration(
    showProgressBar: Bool = true,
    progressLoadingTime: TimeInterval = 1,
    onPress: AwesomeButtonPressCallback? = nil,
    onProgressEnd: (() -> Void)? = nil
) -> AwesomeButtonResolvedConfiguration {
    AwesomeButtonResolvedConfiguration(
        childText: "Progress",
        labelView: nil,
        beforeView: nil,
        afterView: nil,
        extraView: nil,
        onPress: onPress,
        onLongPress: nil,
        disabled: false,
        width: 200,
        height: 52,
        paddingHorizontal: 16,
        paddingTop: 0,
        paddingBottom: 0,
        stretch: false,
        style: AwesomeButtonThemeData.fallbackStyle,
        activeOpacity: 1,
        debouncedPressTime: 0,
        progress: true,
        showProgressBar: showProgressBar,
        progressLoadingTime: progressLoadingTime,
        animateSize: true,
        textTransition: false,
        textTransitionSlotStaggerMs: defaultTextTransitionSlotStaggerMs,
        animatedPlaceholder: true,
        hapticOnPress: false,
        onPressIn: nil,
        onPressOut: nil,
        onPressedIn: nil,
        onPressedOut: nil,
        onProgressStart: nil,
        onProgressEnd: onProgressEnd
    )
}

@MainActor
private func scheduleReleaseCompletion(_ controller: AwesomeButtonController) {
    let delayMs = progressFillCompletionDurationMs + progressSwapDurationMs + 150
    DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(delayMs)) {
        controller.completeReleaseIfNeeded(observedPressProgress: 0)
    }
}
