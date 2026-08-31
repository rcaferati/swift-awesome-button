import SwiftUI
import XCTest

@testable import SwiftAwesomeButton

@MainActor
final class PublicSurfaceIntegrityTests: XCTestCase {
  func testPressedFaceUsesExplicitActiveThenAlphaCompositedOverlay() {
    let background = Color(red: 0, green: 0, blue: 1)
    let overlay = Color(red: 1, green: 0, blue: 0, opacity: 0.5)
    let composited = resolvedPressedFaceColor(
      style: AwesomeButtonStyle(pressedOverlayColor: overlay),
      restingBackground: background
    )
    XCTAssertTrue(colorsEqual(composited, Color(red: 0.5, green: 0, blue: 0.5)))

    let explicit = Color(red: 0, green: 1, blue: 0)
    XCTAssertTrue(
      colorsEqual(
        resolvedPressedFaceColor(
          style: AwesomeButtonStyle(
            backgroundActive: explicit,
            pressedOverlayColor: overlay
          ),
          restingBackground: background
        ),
        explicit
      )
    )
  }

  func testPhysicalThemeCornersReachStyleAndMapCorrectlyInLTRAndRTL() {
    let themeStyle = ThemeButtonStyle(
      borderRadius: 20,
      borderBottomLeftRadius: 3,
      borderBottomRightRadius: 4,
      borderTopLeftRadius: 1,
      borderTopRightRadius: 2
    )
    let style = themeButtonStyleToAwesomeButtonStyle(themeStyle)
    XCTAssertEqual(style.borderTopLeftRadius, 1)
    XCTAssertEqual(style.borderTopRightRadius, 2)
    XCTAssertEqual(style.borderBottomLeftRadius, 3)
    XCTAssertEqual(style.borderBottomRightRadius, 4)

    let ltr = resolvedCornerRadii(style: style, layoutDirection: .leftToRight)
    XCTAssertEqual(ltr.topLeft, 1)
    XCTAssertEqual(ltr.topRight, 2)
    XCTAssertEqual(ltr.bottomLeft, 3)
    XCTAssertEqual(ltr.bottomRight, 4)

    let rtl = resolvedCornerRadii(style: style, layoutDirection: .rightToLeft)
    XCTAssertEqual(rtl.topLeft, 1)
    XCTAssertEqual(rtl.topRight, 2)
    XCTAssertEqual(rtl.bottomLeft, 3)
    XCTAssertEqual(rtl.bottomRight, 4)
  }

  func testProgressTravelEntersFromTheLogicalLeadingEdge() {
    XCTAssertEqual(
      awesomeButtonProgressOffset(progress: 0.25, width: 100, layoutDirection: .leftToRight),
      -75
    )
    XCTAssertEqual(
      awesomeButtonProgressOffset(progress: 0.25, width: 100, layoutDirection: .rightToLeft),
      75
    )
    XCTAssertEqual(
      awesomeButtonProgressOffset(progress: 1, width: 100, layoutDirection: .rightToLeft),
      0
    )
  }

  func testThemedDimensionPrecedenceCoversEveryWidthConflictAndHeightSource() {
    let variant = ThemeButtonStyle(
      height: 71,
      paddingBottom: 5,
      paddingHorizontal: 17,
      paddingTop: 3,
      textSize: 19,
      width: 173
    )
    let size = ThemeSizeStyle(width: 211, height: 61, textSize: 15, paddingHorizontal: 23)

    XCTAssertNil(presentation(variant, size, width: 140, autoWidth: true, stretch: true).width)
    XCTAssertEqual(presentation(variant, size, width: 140, autoWidth: true).width, 140)
    XCTAssertNil(presentation(variant, size, autoWidth: true).width)
    XCTAssertEqual(presentation(variant, size).width, 173)
    XCTAssertEqual(presentation(ThemeButtonStyle(), size).width, 211)

    XCTAssertEqual(presentation(variant, size, height: 88).height, 88)
    XCTAssertEqual(presentation(variant, size).height, 71)
    XCTAssertEqual(presentation(ThemeButtonStyle(), size).height, 61)
    XCTAssertEqual(presentation(variant, size).paddingHorizontal, 17)
    XCTAssertEqual(presentation(variant, size, paddingHorizontal: 31).paddingHorizontal, 31)
    XCTAssertEqual(presentation(variant, size).style.textSize, 19)
    XCTAssertEqual(presentation(ThemeButtonStyle(), size).style.textSize, 15)
  }

  func testAwesomeButtonStyleFieldLedgerSurvivesResolutionAndInterpolation() {
    let style = AwesomeButtonStyle(
      backgroundColor: .red,
      backgroundActive: .orange,
      backgroundPlaceholder: .yellow,
      backgroundProgress: .green,
      depthColor: .blue,
      shadowColor: .purple,
      activityColor: .pink,
      pressedOverlayColor: .cyan.opacity(0.4),
      foregroundColor: .white,
      textSize: 21,
      textLineHeight: 25,
      textFontFamily: "Avenir",
      borderRadius: 9,
      borderBottomLeftRadius: 1,
      borderBottomRightRadius: 2,
      borderTopLeftRadius: 3,
      borderTopRightRadius: 4,
      borderWidth: 5,
      borderColor: .mint,
      raiseAmount: 7,
      contentGap: 11,
      animationDuration: 0.31,
      animationCurve: .linear,
      pressInAnimationDuration: 0.07,
      disabledBackgroundColor: .gray,
      disabledDepthColor: .brown,
      disabledShadowColor: .black,
      disabledForegroundColor: .indigo,
      disabledBorderColor: .teal
    )
    let resolved = resolvedVisualStyle(style)
    XCTAssertTrue(colorsEqual(resolved.backgroundColor, .red))
    XCTAssertTrue(colorsEqual(resolved.backgroundActive, .orange))
    XCTAssertTrue(colorsEqual(resolved.backgroundPlaceholder, .yellow))
    XCTAssertTrue(colorsEqual(resolved.backgroundProgress, .green))
    XCTAssertTrue(colorsEqual(resolved.depthColor, .blue))
    XCTAssertTrue(colorsEqual(resolved.shadowColor, .purple))
    XCTAssertTrue(colorsEqual(resolved.activityColor, .pink))
    XCTAssertTrue(colorsEqual(resolved.pressedOverlayColor, .cyan.opacity(0.4)))
    XCTAssertTrue(colorsEqual(resolved.foregroundColor, .white))
    XCTAssertEqual(resolved.textSize, 21)
    XCTAssertEqual(resolved.textLineHeight, 25)
    XCTAssertEqual(resolved.textFontFamily, "Avenir")
    XCTAssertEqual(resolved.borderRadius, 9)
    XCTAssertEqual(resolved.borderBottomLeftRadius, 1)
    XCTAssertEqual(resolved.borderBottomRightRadius, 2)
    XCTAssertEqual(resolved.borderTopLeftRadius, 3)
    XCTAssertEqual(resolved.borderTopRightRadius, 4)
    XCTAssertEqual(resolved.borderWidth, 5)
    XCTAssertTrue(colorsEqual(resolved.borderColor, .mint))
    XCTAssertEqual(resolved.raiseAmount, 7)
    XCTAssertEqual(resolved.contentGap, 11)
    XCTAssertEqual(resolved.animationDuration, 0.31)
    XCTAssertEqual(resolved.animationCurve, .linear)
    XCTAssertEqual(resolved.pressInAnimationDuration, 0.07)
    XCTAssertTrue(colorsEqual(resolved.disabledBackgroundColor, .gray))
    XCTAssertTrue(colorsEqual(resolved.disabledDepthColor, .brown))
    XCTAssertTrue(colorsEqual(resolved.disabledShadowColor, .black))
    XCTAssertTrue(colorsEqual(resolved.disabledForegroundColor, .indigo))
    XCTAssertTrue(colorsEqual(resolved.disabledBorderColor, .teal))

    let midpoint = interpolateAwesomeButtonStyle(AwesomeButtonStyle(), style, progress: 1)
    XCTAssertEqual(midpoint.visualSignature, resolved.visualSignature)
  }

  func testThemeButtonStyleFieldLedgerReachesStyleOrPresentationOwner() {
    let theme = ThemeButtonStyle(
      borderRadius: 10,
      borderBottomLeftRadius: 1,
      borderBottomRightRadius: 2,
      borderTopLeftRadius: 3,
      borderTopRightRadius: 4,
      height: 70,
      paddingBottom: 5,
      paddingHorizontal: 6,
      paddingTop: 7,
      raiseLevel: 8,
      backgroundActive: .red,
      backgroundColor: .orange,
      backgroundDarker: .yellow,
      backgroundPlaceholder: .green,
      backgroundProgress: .blue,
      backgroundShadow: .purple,
      textColor: .pink,
      borderWidth: 9,
      borderColor: .cyan,
      activityColor: .mint,
      textFontFamily: "Avenir",
      textLineHeight: 22,
      textSize: 18,
      width: 190
    )
    let resolved = presentation(theme, ThemeSizeStyle(width: 200, height: 60))
    XCTAssertEqual(resolved.width, 190)
    XCTAssertEqual(resolved.height, 70)
    XCTAssertEqual(resolved.paddingHorizontal, 6)
    XCTAssertEqual(resolved.paddingTop, 7)
    XCTAssertEqual(resolved.paddingBottom, 5)
    XCTAssertEqual(resolved.style.raiseAmount, 8)
    XCTAssertEqual(resolved.style.borderWidth, 9)
    XCTAssertEqual(resolved.style.textFontFamily, "Avenir")
    XCTAssertEqual(resolved.style.textLineHeight, 22)
    XCTAssertEqual(resolved.style.textSize, 18)
    XCTAssertTrue(colorsEqual(resolved.style.backgroundActive, .red))
    XCTAssertTrue(colorsEqual(resolved.style.backgroundColor, .orange))
    XCTAssertTrue(colorsEqual(resolved.style.depthColor, .yellow))
    XCTAssertTrue(colorsEqual(resolved.style.backgroundPlaceholder, .green))
    XCTAssertTrue(colorsEqual(resolved.style.backgroundProgress, .blue))
    XCTAssertTrue(colorsEqual(resolved.style.shadowColor, .purple))
    XCTAssertTrue(colorsEqual(resolved.style.foregroundColor, .pink))
    XCTAssertTrue(colorsEqual(resolved.style.borderColor, .cyan))
    XCTAssertTrue(colorsEqual(resolved.style.activityColor, .mint))
  }

  func testTimingFieldsOwnPressAndDirectStyleButNotReleaseSpring() {
    let style = AwesomeButtonStyle(
      animationDuration: 0.4,
      animationCurve: .linear,
      pressInAnimationDuration: 0.05
    )
    XCTAssertEqual(
      resolvedPressInAnimationTiming(style: style),
      AwesomeButtonAnimationTiming(duration: 0.05, curve: .linear)
    )
    XCTAssertEqual(
      resolvedDirectStyleAnimationTiming(style: style),
      AwesomeButtonAnimationTiming(duration: 0.4, curve: .linear)
    )
    XCTAssertEqual(awesomeButtonReleaseSpringStiffness, 280)
    XCTAssertEqual(awesomeButtonReleaseSpringDamping, 20)
  }

  func testInternalStyleAnimationOptOutSuppressesAResolvedTransition() {
    let current = makeConfiguration(
      style: AwesomeButtonStyle(backgroundColor: .red),
      animatesResolvedStyleChanges: true
    )
    let direct = makeConfiguration(
      style: AwesomeButtonStyle(backgroundColor: .blue),
      animatesResolvedStyleChanges: true
    )
    let suppressed = makeConfiguration(
      style: AwesomeButtonStyle(backgroundColor: .blue),
      animatesResolvedStyleChanges: false
    )

    XCTAssertTrue(shouldAnimateResolvedStyleTransition(from: current, to: direct))
    XCTAssertFalse(shouldAnimateResolvedStyleTransition(from: current, to: suppressed))
  }

  private func presentation(
    _ buttonStyle: ThemeButtonStyle,
    _ sizeStyle: ThemeSizeStyle,
    width: CGFloat? = nil,
    autoWidth: Bool = false,
    height: CGFloat? = nil,
    paddingHorizontal: CGFloat? = nil,
    stretch: Bool = false
  ) -> ResolvedThemedButtonPresentation {
    resolveThemedButtonPresentation(
      buttonStyle: buttonStyle,
      sizeStyle: sizeStyle,
      transparent: false,
      width: width,
      autoWidth: autoWidth,
      height: height,
      paddingHorizontal: paddingHorizontal,
      paddingTop: nil,
      paddingBottom: nil,
      stretch: stretch,
      style: nil
    )
  }
}

private func makeConfiguration(
  style: AwesomeButtonStyle,
  animatesResolvedStyleChanges: Bool
) -> AwesomeButtonResolvedConfiguration {
  AwesomeButtonResolvedConfiguration(
    childText: "Button",
    labelView: nil,
    beforeView: nil,
    afterView: nil,
    extraView: nil,
    onPress: { _ in },
    onLongPress: nil,
    disabled: false,
    width: 180,
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
    animateSize: true,
    textTransition: false,
    textTransitionSlotStaggerMs: 7,
    animatedPlaceholder: true,
    hapticOnPress: false,
    onPressIn: nil,
    onPressOut: nil,
    onPressedIn: nil,
    onPressedOut: nil,
    onProgressStart: nil,
    onProgressEnd: nil,
    animatesResolvedStyleChanges: animatesResolvedStyleChanges
  )
}
