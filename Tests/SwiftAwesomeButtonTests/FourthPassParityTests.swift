import SwiftUI
import XCTest

@testable import SwiftAwesomeButton

@MainActor
final class FourthPassParityTests: XCTestCase {
  func testNumericNormalizationUsesAbsenceFallbacksAndSafeBounds() {
    XCTAssertNil(AwesomeButtonNormalization.optional(.nan))
    XCTAssertNil(AwesomeButtonNormalization.optional(.infinity))
    XCTAssertEqual(AwesomeButtonNormalization.optional(-4), 0)
    XCTAssertEqual(AwesomeButtonNormalization.optional(0), 0)
    XCTAssertEqual(AwesomeButtonNormalization.required(.nan, fallback: 52), 52)
    XCTAssertEqual(AwesomeButtonNormalization.required(-8, fallback: 52), 0)
    XCTAssertNil(AwesomeButtonNormalization.optionalDuration(.infinity))
    XCTAssertEqual(AwesomeButtonNormalization.requiredDuration(.nan, fallback: 3), 3)
    XCTAssertEqual(AwesomeButtonNormalization.requiredDuration(-1, fallback: 3), 0)
    XCTAssertEqual(AwesomeButtonNormalization.opacity(.nan), 1)
    XCTAssertEqual(AwesomeButtonNormalization.opacity(-0.1), 0)
    XCTAssertEqual(AwesomeButtonNormalization.opacity(1.1), 1)
    XCTAssertEqual(AwesomeButtonNormalization.stagger(-7), 0)
  }

  func testInvalidOptionalOverrideContinuesThemePrecedenceWhileNegativeWinsAsZero() {
    let base = AwesomeButtonStyle(
      textSize: 18,
      borderRadius: 12,
      animationDuration: 0.4
    )
    let invalidOverride = AwesomeButtonStyle(
      textSize: .nan,
      borderRadius: -.infinity,
      animationDuration: .infinity
    )
    let resolved = base.merge(AwesomeButtonNormalization.style(invalidOverride))

    XCTAssertEqual(resolved.textSize, 18)
    XCTAssertEqual(resolved.borderRadius, 12)
    XCTAssertEqual(resolved.animationDuration, 0.4)

    let zeroed = base.merge(
      AwesomeButtonNormalization.style(
        AwesomeButtonStyle(textSize: -1, borderRadius: -2, animationDuration: -3)
      ))
    XCTAssertEqual(zeroed.textSize, 0)
    XCTAssertEqual(zeroed.borderRadius, 0)
    XCTAssertEqual(zeroed.animationDuration, 0)
  }

  func testThemedDimensionsFollowCanonicalOrderAndNormalizeInputs() {
    let variant = ThemeButtonStyle(height: 54, paddingHorizontal: 11, width: 130)
    let size = ThemeSizeStyle(width: 200, height: 60, textSize: 15, paddingHorizontal: 17)

    let fixed = resolveThemedButtonPresentation(
      buttonStyle: variant,
      sizeStyle: size,
      transparent: false,
      width: 0,
      autoWidth: true,
      height: 0,
      paddingHorizontal: 0,
      paddingTop: -1,
      paddingBottom: .nan,
      stretch: false,
      style: nil
    )
    XCTAssertEqual(fixed.width, 0)
    XCTAssertEqual(fixed.height, 0)
    XCTAssertEqual(fixed.paddingHorizontal, 0)
    XCTAssertEqual(fixed.paddingTop, 0)
    XCTAssertNil(fixed.paddingBottom)

    let absent = resolveThemedButtonPresentation(
      buttonStyle: variant,
      sizeStyle: size,
      transparent: false,
      width: .nan,
      autoWidth: false,
      height: .infinity,
      paddingHorizontal: .nan,
      paddingTop: nil,
      paddingBottom: nil,
      stretch: false,
      style: nil
    )
    XCTAssertEqual(absent.width, 130)
    XCTAssertEqual(absent.height, 54)
    XCTAssertEqual(absent.paddingHorizontal, 11)

    let auto = resolveThemedButtonPresentation(
      buttonStyle: variant,
      sizeStyle: size,
      transparent: false,
      width: nil,
      autoWidth: true,
      height: nil,
      paddingHorizontal: nil,
      paddingTop: nil,
      paddingBottom: nil,
      stretch: false,
      style: nil
    )
    XCTAssertNil(auto.width)

    let stretch = resolveThemedButtonPresentation(
      buttonStyle: variant,
      sizeStyle: size,
      transparent: false,
      width: 99,
      autoWidth: false,
      height: nil,
      paddingHorizontal: nil,
      paddingTop: nil,
      paddingBottom: nil,
      stretch: true,
      style: nil
    )
    XCTAssertNil(stretch.width)
  }

  func testCanonicalPressTimingFallbackOverrideAndZeroStagger() {
    XCTAssertEqual(
      resolvedPressInAnimationTiming(style: AwesomeButtonStyle()),
      AwesomeButtonAnimationTiming(duration: 0.14, curve: .easeOutCubic)
    )
    XCTAssertEqual(
      resolvedPressInAnimationTiming(
        style: AwesomeButtonStyle(animationDuration: 0.4, pressInAnimationDuration: nil)
      ).duration,
      0.4
    )
    XCTAssertEqual(
      resolvedPressInAnimationTiming(
        style: AwesomeButtonStyle(animationDuration: 0.4, pressInAnimationDuration: 0.03)
      ).duration,
      0.03
    )
    XCTAssertEqual(normalizeTextTransitionSlotStaggerMs(-1), 0)
  }

  func testThemedTransitionDurationMatchesTheOwningChange() {
    XCTAssertEqual(
      resolveThemedStyleTransitionDuration(
        hadPreviousContext: true,
        sameThemeSource: true,
        sameTransparent: true,
        variantChanged: true,
        reduceMotion: false,
        styleDuration: 0.37
      ),
      0.2
    )
    XCTAssertEqual(
      resolveThemedStyleTransitionDuration(
        hadPreviousContext: true,
        sameThemeSource: true,
        sameTransparent: true,
        variantChanged: false,
        reduceMotion: false,
        styleDuration: 0.37
      ),
      0.37
    )
    XCTAssertEqual(
      resolveThemedStyleTransitionDuration(
        hadPreviousContext: true,
        sameThemeSource: false,
        sameTransparent: true,
        variantChanged: true,
        reduceMotion: false,
        styleDuration: 0.37
      ),
      0
    )
    XCTAssertEqual(
      resolveThemedStyleTransitionDuration(
        hadPreviousContext: true,
        sameThemeSource: true,
        sameTransparent: true,
        variantChanged: false,
        reduceMotion: true,
        styleDuration: 0.37
      ),
      0
    )
  }

  func testThemedStyleTimingUsesVariantAndSameVariantDurations() {
    let sourceContext = AwesomeButtonStyleTransitionContext(
      sourceSignature: 42,
      variant: ButtonVariant.primary.rawValue,
      transparent: false
    )
    let source = pass4Configuration(
      style: AwesomeButtonStyle(backgroundColor: .red, textSize: 12),
      styleTransitionContext: sourceContext
    )
    let sameVariant = pass4Configuration(
      style: AwesomeButtonStyle(
        backgroundColor: .blue,
        textSize: 16,
        animationDuration: 0.37
      ),
      styleTransitionContext: sourceContext
    )
    let changedVariant = pass4Configuration(
      style: AwesomeButtonStyle(
        backgroundColor: .green,
        textSize: 18,
        animationDuration: 0.37
      ),
      styleTransitionContext: AwesomeButtonStyleTransitionContext(
        sourceSignature: 42,
        variant: ButtonVariant.secondary.rawValue,
        transparent: false
      )
    )

    XCTAssertEqual(
      resolvedStyleTransitionTiming(from: source, to: sameVariant),
      AwesomeButtonAnimationTiming(duration: 0.37, curve: .easeOut)
    )
    XCTAssertEqual(
      resolvedStyleTransitionTiming(from: sameVariant, to: changedVariant),
      AwesomeButtonAnimationTiming(duration: 0.2, curve: .easeOut)
    )
  }

  func testThemedStyleTimingSnapsAcrossThemeSourcesAndReducedMotion() {
    let source = pass4Configuration(
      style: AwesomeButtonStyle(backgroundColor: .red, textSize: 12),
      styleTransitionContext: AwesomeButtonStyleTransitionContext(
        sourceSignature: 1,
        variant: ButtonVariant.primary.rawValue,
        transparent: false
      )
    )
    let changedSource = pass4Configuration(
      style: AwesomeButtonStyle(backgroundColor: .blue, textSize: 16),
      styleTransitionContext: AwesomeButtonStyleTransitionContext(
        sourceSignature: 2,
        variant: ButtonVariant.primary.rawValue,
        transparent: false
      )
    )
    let reducedMotion = pass4Configuration(
      style: AwesomeButtonStyle(backgroundColor: .blue, textSize: 16),
      styleTransitionContext: source.styleTransitionContext,
      reduceMotion: true
    )

    XCTAssertNil(resolvedStyleTransitionTiming(from: source, to: changedSource))
    XCTAssertNil(resolvedStyleTransitionTiming(from: source, to: reducedMotion))
  }

  func testTypographyBumpPeaksAtFourPercentAndSettlesAtEndpoints() {
    XCTAssertEqual(
      awesomeButtonTypographyTransitionScale(
        sourceTextSize: 12,
        targetTextSize: 16,
        progress: 0,
        animateSize: true,
        reduceMotion: false
      ),
      1,
      accuracy: 0.0001
    )
    XCTAssertEqual(
      awesomeButtonTypographyTransitionScale(
        sourceTextSize: 12,
        targetTextSize: 16,
        progress: 0.5,
        animateSize: true,
        reduceMotion: false
      ),
      1.04,
      accuracy: 0.0001
    )
    XCTAssertEqual(
      awesomeButtonTypographyTransitionScale(
        sourceTextSize: 12,
        targetTextSize: 16,
        progress: 1,
        animateSize: true,
        reduceMotion: false
      ),
      1,
      accuracy: 0.0001
    )
  }

  func testTypographyFrameInterpolatesFontSizeLineHeightAndDynamicTypeInputs() {
    let frame = resolvedAwesomeButtonTypographyFrame(
      sourceStyle: AwesomeButtonStyle(textSize: 12, textLineHeight: 18),
      targetStyle: AwesomeButtonStyle(textSize: 16, textLineHeight: 24),
      progress: 0.5,
      animateSize: true,
      reduceMotion: false
    )

    XCTAssertEqual(frame.textSize, 14, accuracy: 0.0001)
    XCTAssertEqual(frame.lineHeight, 21, accuracy: 0.0001)
    XCTAssertEqual(frame.scale, 1.04, accuracy: 0.0001)
    XCTAssertGreaterThan(
      awesomeButtonScaledTextSize(frame.textSize, dynamicTypeSize: .accessibility3),
      awesomeButtonScaledTextSize(frame.textSize, dynamicTypeSize: .large)
    )
    XCTAssertGreaterThan(
      awesomeButtonScaledTextSize(frame.lineHeight, dynamicTypeSize: .accessibility3),
      awesomeButtonScaledTextSize(frame.lineHeight, dynamicTypeSize: .large)
    )
  }

  func testTypographyFrameSnapsToTargetWhenSizeAnimationIsDisabledOrMotionIsReduced() {
    let source = AwesomeButtonStyle(textSize: 12, textLineHeight: 18)
    let target = AwesomeButtonStyle(textSize: 16, textLineHeight: 24)
    let sizeOptOut = resolvedAwesomeButtonTypographyFrame(
      sourceStyle: source,
      targetStyle: target,
      progress: 0.5,
      animateSize: false,
      reduceMotion: false
    )
    let reducedMotion = resolvedAwesomeButtonTypographyFrame(
      sourceStyle: source,
      targetStyle: target,
      progress: 0.5,
      animateSize: true,
      reduceMotion: true
    )

    XCTAssertEqual(
      sizeOptOut,
      AwesomeButtonTypographyFrame(
        textSize: 16,
        lineHeight: 24,
        fontFamily: nil,
        scale: 1
      ))
    XCTAssertEqual(reducedMotion, sizeOptOut)
  }

  func testTypographyBumpIsDisabledForEqualSizesSizeOptOutAndReducedMotion() {
    XCTAssertEqual(
      awesomeButtonTypographyTransitionScale(
        sourceTextSize: 14,
        targetTextSize: 14,
        progress: 0.5,
        animateSize: true,
        reduceMotion: false
      ),
      1
    )
    XCTAssertEqual(
      awesomeButtonTypographyTransitionScale(
        sourceTextSize: 12,
        targetTextSize: 16,
        progress: 0.5,
        animateSize: false,
        reduceMotion: false
      ),
      1
    )
    XCTAssertEqual(
      awesomeButtonTypographyTransitionScale(
        sourceTextSize: 12,
        targetTextSize: 16,
        progress: 0.5,
        animateSize: true,
        reduceMotion: true
      ),
      1
    )
  }

  func testPhysicalHapticOccursAfterPressInAndPressedCommitBeforePressedIn() {
    var events: [String] = []
    var controller: AwesomeButtonController!
    controller = AwesomeButtonController(hapticFeedback: {
      XCTAssertTrue(controller.isPressed)
      events.append("haptic")
    })
    let configuration = pass4Configuration(
      hapticOnPress: true,
      onPressIn: {
        XCTAssertFalse(controller.isPressed)
        events.append("in")
      },
      onPressedIn: {
        XCTAssertTrue(controller.isPressed)
        events.append("pressed-in")
      }
    )

    controller.update(configuration: configuration)
    controller.handleTouchChange(isInside: true, configuration: configuration)

    XCTAssertEqual(events, ["in", "haptic", "pressed-in"])
    controller.cleanup()
  }

  func testHapticRequestCountsForReentrantInvalidationCancellationRepeatAndAtomicInput() {
    var hapticCount = 0
    var controller: AwesomeButtonController!
    var disabledConfiguration: AwesomeButtonResolvedConfiguration!
    controller = AwesomeButtonController(hapticFeedback: { hapticCount += 1 })
    disabledConfiguration = pass4Configuration(disabled: true, hapticOnPress: true)
    let invalidating = pass4Configuration(
      hapticOnPress: true,
      onPressIn: { controller.refreshLiveConfiguration(disabledConfiguration) }
    )
    controller.update(configuration: invalidating)
    controller.handleTouchChange(isInside: true, configuration: invalidating)
    XCTAssertEqual(hapticCount, 0)
    XCTAssertFalse(controller.isPressed)

    controller.cleanup()
    controller = AwesomeButtonController(hapticFeedback: { hapticCount += 1 })
    let accepted = pass4Configuration(hapticOnPress: true)
    controller.update(configuration: accepted)
    controller.handleTouchChange(isInside: true, configuration: accepted)
    controller.handleTouchEnd(isInside: false, configuration: accepted)
    controller.handleTouchChange(isInside: true, configuration: accepted)
    controller.handleTouchEnd(isInside: false, configuration: accepted)
    XCTAssertEqual(hapticCount, 2)

    let beforeAtomic = hapticCount
    XCTAssertTrue(controller.activateAtomically(configuration: accepted))
    XCTAssertEqual(hapticCount, beforeAtomic)
    controller.cleanup()
  }
}

private func pass4Configuration(
  disabled: Bool = false,
  hapticOnPress: Bool = false,
  onPressIn: (() -> Void)? = nil,
  onPressedIn: (() -> Void)? = nil,
  style: AwesomeButtonStyle = AwesomeButtonThemeData.fallbackStyle,
  styleTransitionContext: AwesomeButtonStyleTransitionContext? = nil,
  reduceMotion: Bool = false
) -> AwesomeButtonResolvedConfiguration {
  AwesomeButtonResolvedConfiguration(
    childText: "Button",
    labelView: nil,
    beforeView: nil,
    afterView: nil,
    extraView: nil,
    onPress: { _ in },
    onLongPress: nil,
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
    progress: false,
    showProgressBar: true,
    progressLoadingTime: 3,
    animateSize: false,
    textTransition: false,
    textTransitionSlotStaggerMs: 7,
    animatedPlaceholder: true,
    hapticOnPress: hapticOnPress,
    onPressIn: onPressIn,
    onPressOut: nil,
    onPressedIn: onPressedIn,
    onPressedOut: nil,
    onProgressStart: nil,
    onProgressEnd: nil,
    styleTransitionContext: styleTransitionContext,
    reduceMotion: reduceMotion
  )
}
