import SwiftUI
import XCTest
@testable import SwiftAwesomeButton

final class ControllerPlanningTests: XCTestCase {
    func testDisabledTextTransitionAssignsImmediately() {
        XCTAssertEqual(
            resolveButtonTextUpdatePlan(
                textTransitionEnabled: false,
                nextText: "Next",
                currentTarget: "Current",
                displayedText: "Current"
            ),
            .assign("Next")
        )
    }

    func testNilAndEmptyTextAssignImmediately() {
        XCTAssertEqual(
            resolveButtonTextUpdatePlan(
                textTransitionEnabled: true,
                nextText: nil,
                currentTarget: "Current",
                displayedText: "Current"
            ),
            .assign(nil)
        )
        XCTAssertEqual(
            resolveButtonTextUpdatePlan(
                textTransitionEnabled: true,
                nextText: "",
                currentTarget: "Current",
                displayedText: "Current"
            ),
            .assign("")
        )
    }

    func testSameTargetKeepsCurrentTextState() {
        XCTAssertEqual(
            resolveButtonTextUpdatePlan(
                textTransitionEnabled: true,
                nextText: "Current",
                currentTarget: "Current",
                displayedText: "Partial"
            ),
            .keep
        )
    }

    func testChangedNonEmptyTextTransitionsFromDisplayedText() {
        XCTAssertEqual(
            resolveButtonTextUpdatePlan(
                textTransitionEnabled: true,
                nextText: "Next",
                currentTarget: "Current",
                displayedText: "Visible"
            ),
            .transition(source: "Visible", target: "Next")
        )
    }

    func testIneligibleAutoWidthPlanFallsBackToTextSync() {
        XCTAssertEqual(
            resolveAutoWidthTextUpdatePlan(
                isEligible: false,
                targetText: "Launch",
                currentWidth: nil,
                targetWidth: 120,
                displayedText: nil,
                animateSize: true,
                textTransition: true,
                slotStaggerMs: 7
            ),
            .fallbackToTextSync
        )
    }

    func testInitialAutoWidthPlanSetsTextAndWidthImmediately() {
        XCTAssertEqual(
            resolveAutoWidthTextUpdatePlan(
                isEligible: true,
                targetText: "Launch",
                currentWidth: nil,
                targetWidth: 120,
                displayedText: nil,
                animateSize: true,
                textTransition: true,
                slotStaggerMs: 7
            ),
            .initial(targetText: "Launch", targetWidth: 120)
        )
    }

    func testEqualAutoWidthPlanUsesTextOnlyTransition() {
        XCTAssertEqual(
            resolveAutoWidthTextUpdatePlan(
                isEligible: true,
                targetText: "Open",
                currentWidth: 120,
                targetWidth: 120.25,
                displayedText: "Save",
                animateSize: true,
                textTransition: true,
                slotStaggerMs: 7
            ),
            .textOnly(sourceText: "Save", targetText: "Open", animateText: true)
        )
    }

    func testLargerAutoWidthPlanGrowsBeforeTextTransition() {
        let expectedTiming = resolveAutoWidthTextTransitionTiming(
            fromText: "Launch",
            targetText: "View analytics dashboard",
            flow: .growFirst,
            slotStaggerMs: 7
        )

        XCTAssertEqual(
            resolveAutoWidthTextUpdatePlan(
                isEligible: true,
                targetText: "View analytics dashboard",
                currentWidth: 80,
                targetWidth: 240,
                displayedText: "Launch",
                animateSize: true,
                textTransition: true,
                slotStaggerMs: 7
            ),
            .growFirst(
                sourceText: "Launch",
                targetText: "View analytics dashboard",
                targetWidth: 240,
                timing: expectedTiming,
                animateSize: true,
                animateText: true
            )
        )
    }

    func testSmallerAutoWidthPlanShrinksAfterTextTransition() {
        let expectedTiming = resolveAutoWidthTextTransitionTiming(
            fromText: "View analytics dashboard",
            targetText: "Launch",
            flow: .shrinkLast,
            slotStaggerMs: 7
        )

        XCTAssertEqual(
            resolveAutoWidthTextUpdatePlan(
                isEligible: true,
                targetText: "Launch",
                currentWidth: 240,
                targetWidth: 80,
                displayedText: "View analytics dashboard",
                animateSize: true,
                textTransition: true,
                slotStaggerMs: 7
            ),
            .shrinkLast(
                sourceText: "View analytics dashboard",
                targetText: "Launch",
                targetWidth: 80,
                timing: expectedTiming,
                animateSize: true,
                animateText: true
            )
        )
    }

    func testReleaseDefersOnlyEligibleAutoWidthGrowOrShrink() {
        let current = makePlanningConfiguration(
            text: "Launch",
            animateSize: false,
            textTransition: true
        )
        let next = makePlanningConfiguration(
            text: "View analytics dashboard",
            animateSize: true,
            textTransition: true
        )

        XCTAssertTrue(
            shouldDeferReleaseAutoWidthTransition(
                isReleaseActive: true,
                currentConfiguration: current,
                nextConfiguration: next,
                previousWidthMode: .auto,
                currentWidth: 80,
                targetWidth: 240
            )
        )
    }

    func testReleaseDoesNotDeferFixedOrStretchUpdates() {
        let current = makePlanningConfiguration(
            text: "Launch",
            animateSize: false,
            textTransition: true
        )

        XCTAssertFalse(
            shouldDeferReleaseAutoWidthTransition(
                isReleaseActive: true,
                currentConfiguration: current,
                nextConfiguration: makePlanningConfiguration(
                    text: "View analytics dashboard",
                    width: 240,
                    animateSize: true,
                    textTransition: true
                ),
                previousWidthMode: .auto,
                currentWidth: 80,
                targetWidth: 240
            )
        )
        XCTAssertFalse(
            shouldDeferReleaseAutoWidthTransition(
                isReleaseActive: true,
                currentConfiguration: current,
                nextConfiguration: makePlanningConfiguration(
                    text: "View analytics dashboard",
                    stretch: true,
                    animateSize: true,
                    textTransition: true
                ),
                previousWidthMode: .auto,
                currentWidth: 80,
                targetWidth: 240
            )
        )
    }

    func testReleaseDoesNotDeferSizeAffectingConfigurationChanges() {
        let current = makePlanningConfiguration(
            text: "Launch",
            animateSize: false,
            textTransition: true
        )

        XCTAssertFalse(
            shouldDeferReleaseAutoWidthTransition(
                isReleaseActive: true,
                currentConfiguration: current,
                nextConfiguration: makePlanningConfiguration(
                    text: "View analytics dashboard",
                    height: 68,
                    animateSize: true,
                    textTransition: true
                ),
                previousWidthMode: .auto,
                currentWidth: 80,
                targetWidth: 240
            )
        )
        XCTAssertFalse(
            shouldDeferReleaseAutoWidthTransition(
                isReleaseActive: true,
                currentConfiguration: current,
                nextConfiguration: makePlanningConfiguration(
                    text: "View analytics dashboard",
                    paddingHorizontal: 24,
                    animateSize: true,
                    textTransition: true
                ),
                previousWidthMode: .auto,
                currentWidth: 80,
                targetWidth: 240
            )
        )
        XCTAssertFalse(
            shouldDeferReleaseAutoWidthTransition(
                isReleaseActive: true,
                currentConfiguration: current,
                nextConfiguration: makePlanningConfiguration(
                    text: "View analytics dashboard",
                    animateSize: true,
                    textTransition: true,
                    style: AwesomeButtonStyle(textSize: 18)
                ),
                previousWidthMode: .auto,
                currentWidth: 80,
                targetWidth: 240
            )
        )
    }

    func testReleaseDoesNotDeferTextOnlyAutoWidthUpdates() {
        let current = makePlanningConfiguration(
            text: "Launch",
            animateSize: false,
            textTransition: true
        )
        let next = makePlanningConfiguration(
            text: "Open",
            animateSize: true,
            textTransition: true
        )

        XCTAssertFalse(
            shouldDeferReleaseAutoWidthTransition(
                isReleaseActive: true,
                currentConfiguration: current,
                nextConfiguration: next,
                previousWidthMode: .auto,
                currentWidth: 120,
                targetWidth: 120.25
            )
        )
    }
}

private func makePlanningConfiguration(
    text: String?,
    width: CGFloat? = nil,
    stretch: Bool = false,
    height: CGFloat = 60,
    paddingHorizontal: CGFloat = 16,
    animateSize: Bool,
    textTransition: Bool,
    style: AwesomeButtonStyle = AwesomeButtonThemeData.fallbackStyle
) -> AwesomeButtonResolvedConfiguration {
    AwesomeButtonResolvedConfiguration(
        childText: text,
        labelView: nil,
        beforeView: nil,
        afterView: nil,
        extraView: nil,
        onPress: nil,
        onLongPress: nil,
        disabled: false,
        width: width,
        height: height,
        paddingHorizontal: paddingHorizontal,
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
        textTransitionSlotStaggerMs: defaultTextTransitionSlotStaggerMs,
        animatedPlaceholder: false,
        hapticOnPress: false,
        onPressIn: nil,
        onPressOut: nil,
        onPressedIn: nil,
        onPressedOut: nil,
        onProgressStart: nil,
        onProgressEnd: nil
    )
}
