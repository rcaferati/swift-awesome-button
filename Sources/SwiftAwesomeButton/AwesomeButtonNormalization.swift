import SwiftUI

internal enum AwesomeButtonNormalization {
  static func optional(_ value: CGFloat?) -> CGFloat? {
    guard let value, value.isFinite else { return nil }
    return max(0, value)
  }

  static func required(_ value: CGFloat, fallback: CGFloat) -> CGFloat {
    guard value.isFinite else { return max(0, fallback) }
    return max(0, value)
  }

  static func optionalDuration(_ value: TimeInterval?) -> TimeInterval? {
    guard let value, value.isFinite else { return nil }
    return max(0, value)
  }

  static func requiredDuration(_ value: TimeInterval, fallback: TimeInterval) -> TimeInterval {
    guard value.isFinite else { return max(0, fallback) }
    return max(0, value)
  }

  static func opacity(_ value: Double, fallback: Double = 1) -> Double {
    guard value.isFinite else { return min(1, max(0, fallback)) }
    return min(1, max(0, value))
  }

  static func stagger(_ value: Int) -> Int {
    max(0, value)
  }

  static func style(_ value: AwesomeButtonStyle?) -> AwesomeButtonStyle? {
    guard let value else { return nil }
    return AwesomeButtonStyle(
      backgroundColor: value.backgroundColor,
      backgroundActive: value.backgroundActive,
      backgroundPlaceholder: value.backgroundPlaceholder,
      backgroundProgress: value.backgroundProgress,
      depthColor: value.depthColor,
      shadowColor: value.shadowColor,
      activityColor: value.activityColor,
      pressedOverlayColor: value.pressedOverlayColor,
      foregroundColor: value.foregroundColor,
      textSize: optional(value.textSize),
      textLineHeight: optional(value.textLineHeight),
      textFontFamily: value.textFontFamily,
      borderRadius: optional(value.borderRadius),
      borderBottomLeftRadius: optional(value.borderBottomLeftRadius),
      borderBottomRightRadius: optional(value.borderBottomRightRadius),
      borderTopLeftRadius: optional(value.borderTopLeftRadius),
      borderTopRightRadius: optional(value.borderTopRightRadius),
      borderWidth: optional(value.borderWidth),
      borderColor: value.borderColor,
      raiseAmount: optional(value.raiseAmount),
      contentGap: optional(value.contentGap),
      animationDuration: optionalDuration(value.animationDuration),
      animationCurve: value.animationCurve,
      pressInAnimationDuration: optionalDuration(value.pressInAnimationDuration),
      disabledBackgroundColor: value.disabledBackgroundColor,
      disabledDepthColor: value.disabledDepthColor,
      disabledShadowColor: value.disabledShadowColor,
      disabledForegroundColor: value.disabledForegroundColor,
      disabledBorderColor: value.disabledBorderColor
    )
  }

  static func themeStyle(_ value: ThemeButtonStyle) -> ThemeButtonStyle {
    ThemeButtonStyle(
      borderRadius: optional(value.borderRadius),
      borderBottomLeftRadius: optional(value.borderBottomLeftRadius),
      borderBottomRightRadius: optional(value.borderBottomRightRadius),
      borderTopLeftRadius: optional(value.borderTopLeftRadius),
      borderTopRightRadius: optional(value.borderTopRightRadius),
      height: optional(value.height),
      paddingBottom: optional(value.paddingBottom),
      paddingHorizontal: optional(value.paddingHorizontal),
      paddingTop: optional(value.paddingTop),
      raiseLevel: optional(value.raiseLevel),
      backgroundActive: value.backgroundActive,
      backgroundColor: value.backgroundColor,
      backgroundDarker: value.backgroundDarker,
      backgroundPlaceholder: value.backgroundPlaceholder,
      backgroundProgress: value.backgroundProgress,
      backgroundShadow: value.backgroundShadow,
      textColor: value.textColor,
      borderWidth: optional(value.borderWidth),
      borderColor: value.borderColor,
      activityColor: value.activityColor,
      textFontFamily: value.textFontFamily,
      textLineHeight: optional(value.textLineHeight),
      textSize: optional(value.textSize),
      width: optional(value.width)
    )
  }

  static func sizeStyle(
    _ value: ThemeSizeStyle,
    fallback: ThemeSizeStyle = ThemeSizeStyle(width: 200, height: 60)
  ) -> ThemeSizeStyle {
    ThemeSizeStyle(
      width: required(value.width, fallback: fallback.width),
      height: required(value.height, fallback: fallback.height),
      textSize: optional(value.textSize),
      paddingHorizontal: optional(value.paddingHorizontal)
    )
  }
}
