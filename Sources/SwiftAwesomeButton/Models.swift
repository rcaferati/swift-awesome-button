import SwiftUI

/// The activation callback; progress mode supplies a one-shot completion handle.
public typealias AwesomeButtonPressCallback = (AwesomeButtonProgressHandle?) -> Void

/// Curves available for press-down and direct style transitions.
public enum AwesomeButtonAnimationCurve: String, CaseIterable, Sendable {
  /// A cubic ease-out curve with a fast response and soft arrival.
  case easeOutCubic
  /// The platform ease-out curve.
  case easeOut
  /// A constant-rate transition.
  case linear

  internal var animation: Animation {
    switch self {
    case .easeOutCubic:
      return .timingCurve(0.33, 1, 0.68, 1, duration: 0.14)
    case .easeOut:
      return .easeOut(duration: 0.14)
    case .linear:
      return .linear(duration: 0.14)
    }
  }
}

/// A one-shot completion handle owned by an accepted progress activation.
public final class AwesomeButtonProgressHandle {
  private let completion: (((() -> Void)?) -> Void)

  internal init(completion: @escaping (((() -> Void)?) -> Void)) {
    self.completion = completion
  }

  /// Requests completion and optionally runs a callback at the accepted completion boundary.
  public func callAsFunction(_ callback: (() -> Void)? = nil) {
    completion(callback)
  }
}

/// Optional visual overrides for a direct or resolved themed button.
public struct AwesomeButtonStyle: Sendable {
  /// The resting face color.
  public var backgroundColor: Color?
  /// The face color while pressed.
  public var backgroundActive: Color?
  /// The face color used for placeholder content.
  public var backgroundPlaceholder: Color?
  /// The face color used while progress is active.
  public var backgroundProgress: Color?
  /// The lower depth-layer color.
  public var depthColor: Color?
  /// The ambient shadow color.
  public var shadowColor: Color?
  /// The spinner and progress-indicator color.
  public var activityColor: Color?
  /// The overlay color blended over the face while pressed.
  public var pressedOverlayColor: Color?
  /// The label and icon color.
  public var foregroundColor: Color?
  /// The label font size in points.
  public var textSize: CGFloat?
  /// The fixed label line height in points.
  public var textLineHeight: CGFloat?
  /// The PostScript name of an optional custom label font.
  public var textFontFamily: String?
  /// The fallback radius used by corners without a physical override.
  public var borderRadius: CGFloat?
  /// Physical bottom-left corner radius. This value does not mirror in RTL.
  public var borderBottomLeftRadius: CGFloat?
  /// Physical bottom-right corner radius. This value does not mirror in RTL.
  public var borderBottomRightRadius: CGFloat?
  /// Physical top-left corner radius. This value does not mirror in RTL.
  public var borderTopLeftRadius: CGFloat?
  /// Physical top-right corner radius. This value does not mirror in RTL.
  public var borderTopRightRadius: CGFloat?
  /// The inset border width in points.
  public var borderWidth: CGFloat?
  /// The inset border color.
  public var borderColor: Color?
  /// The resting separation between the face and depth layers.
  public var raiseAmount: CGFloat?
  /// The spacing between `before`, label, and `after` content.
  public var contentGap: CGFloat?
  /// Duration for direct resolved-style changes and the fallback press-down duration.
  /// Release remains controlled by the package's native spring.
  public var animationDuration: TimeInterval?
  /// Curve for direct resolved-style changes and press-down. Release ignores this field.
  public var animationCurve: AwesomeButtonAnimationCurve?
  /// Optional duration of the press-down commit. When absent, ``animationDuration``
  /// owns the fallback; the package fallback is 140 ms.
  public var pressInAnimationDuration: TimeInterval?
  /// The disabled face color.
  public var disabledBackgroundColor: Color?
  /// The disabled depth-layer color.
  public var disabledDepthColor: Color?
  /// The disabled shadow color.
  public var disabledShadowColor: Color?
  /// The disabled label and icon color.
  public var disabledForegroundColor: Color?
  /// The disabled border color.
  public var disabledBorderColor: Color?

  /// Creates a sparse style whose non-`nil` values override lower-precedence sources.
  public init(
    backgroundColor: Color? = nil,
    backgroundActive: Color? = nil,
    backgroundPlaceholder: Color? = nil,
    backgroundProgress: Color? = nil,
    depthColor: Color? = nil,
    shadowColor: Color? = nil,
    activityColor: Color? = nil,
    pressedOverlayColor: Color? = nil,
    foregroundColor: Color? = nil,
    textSize: CGFloat? = nil,
    textLineHeight: CGFloat? = nil,
    textFontFamily: String? = nil,
    borderRadius: CGFloat? = nil,
    borderBottomLeftRadius: CGFloat? = nil,
    borderBottomRightRadius: CGFloat? = nil,
    borderTopLeftRadius: CGFloat? = nil,
    borderTopRightRadius: CGFloat? = nil,
    borderWidth: CGFloat? = nil,
    borderColor: Color? = nil,
    raiseAmount: CGFloat? = nil,
    contentGap: CGFloat? = nil,
    animationDuration: TimeInterval? = nil,
    animationCurve: AwesomeButtonAnimationCurve? = nil,
    pressInAnimationDuration: TimeInterval? = nil,
    disabledBackgroundColor: Color? = nil,
    disabledDepthColor: Color? = nil,
    disabledShadowColor: Color? = nil,
    disabledForegroundColor: Color? = nil,
    disabledBorderColor: Color? = nil
  ) {
    self.backgroundColor = backgroundColor
    self.backgroundActive = backgroundActive
    self.backgroundPlaceholder = backgroundPlaceholder
    self.backgroundProgress = backgroundProgress
    self.depthColor = depthColor
    self.shadowColor = shadowColor
    self.activityColor = activityColor
    self.pressedOverlayColor = pressedOverlayColor
    self.foregroundColor = foregroundColor
    self.textSize = textSize
    self.textLineHeight = textLineHeight
    self.textFontFamily = textFontFamily
    self.borderRadius = borderRadius
    self.borderBottomLeftRadius = borderBottomLeftRadius
    self.borderBottomRightRadius = borderBottomRightRadius
    self.borderTopLeftRadius = borderTopLeftRadius
    self.borderTopRightRadius = borderTopRightRadius
    self.borderWidth = borderWidth
    self.borderColor = borderColor
    self.raiseAmount = raiseAmount
    self.contentGap = contentGap
    self.animationDuration = animationDuration
    self.animationCurve = animationCurve
    self.pressInAnimationDuration = pressInAnimationDuration
    self.disabledBackgroundColor = disabledBackgroundColor
    self.disabledDepthColor = disabledDepthColor
    self.disabledShadowColor = disabledShadowColor
    self.disabledForegroundColor = disabledForegroundColor
    self.disabledBorderColor = disabledBorderColor
  }

  /// Returns this style with every non-`nil` field from `other` applied over it.
  public func merge(_ other: AwesomeButtonStyle?) -> AwesomeButtonStyle {
    guard let other else {
      return self
    }

    return AwesomeButtonStyle(
      backgroundColor: other.backgroundColor ?? backgroundColor,
      backgroundActive: other.backgroundActive ?? backgroundActive,
      backgroundPlaceholder: other.backgroundPlaceholder ?? backgroundPlaceholder,
      backgroundProgress: other.backgroundProgress ?? backgroundProgress,
      depthColor: other.depthColor ?? depthColor,
      shadowColor: other.shadowColor ?? shadowColor,
      activityColor: other.activityColor ?? activityColor,
      pressedOverlayColor: other.pressedOverlayColor ?? pressedOverlayColor,
      foregroundColor: other.foregroundColor ?? foregroundColor,
      textSize: other.textSize ?? textSize,
      textLineHeight: other.textLineHeight ?? textLineHeight,
      textFontFamily: other.textFontFamily ?? textFontFamily,
      borderRadius: other.borderRadius ?? borderRadius,
      borderBottomLeftRadius: other.borderBottomLeftRadius ?? borderBottomLeftRadius,
      borderBottomRightRadius: other.borderBottomRightRadius ?? borderBottomRightRadius,
      borderTopLeftRadius: other.borderTopLeftRadius ?? borderTopLeftRadius,
      borderTopRightRadius: other.borderTopRightRadius ?? borderTopRightRadius,
      borderWidth: other.borderWidth ?? borderWidth,
      borderColor: other.borderColor ?? borderColor,
      raiseAmount: other.raiseAmount ?? raiseAmount,
      contentGap: other.contentGap ?? contentGap,
      animationDuration: other.animationDuration ?? animationDuration,
      animationCurve: other.animationCurve ?? animationCurve,
      pressInAnimationDuration: other.pressInAnimationDuration ?? pressInAnimationDuration,
      disabledBackgroundColor: other.disabledBackgroundColor ?? disabledBackgroundColor,
      disabledDepthColor: other.disabledDepthColor ?? disabledDepthColor,
      disabledShadowColor: other.disabledShadowColor ?? disabledShadowColor,
      disabledForegroundColor: other.disabledForegroundColor ?? disabledForegroundColor,
      disabledBorderColor: other.disabledBorderColor ?? disabledBorderColor
    )
  }
}

/// Environment-provided defaults for direct ``AwesomeButton`` instances.
public struct AwesomeButtonThemeData: Sendable {
  /// The environment's base style.
  public var style: AwesomeButtonStyle

  /// Creates environment theme data from a base style.
  public init(style: AwesomeButtonStyle) {
    self.style = style
  }

  /// The package fallback used after all explicit and themed sources are exhausted.
  public static let fallbackStyle = AwesomeButtonStyle(
    backgroundColor: Color(red: 0.145, green: 0.388, blue: 0.922),
    backgroundPlaceholder: Color.black.opacity(0.15),
    backgroundProgress: Color.black.opacity(0.15),
    depthColor: Color(red: 0.114, green: 0.306, blue: 0.847),
    shadowColor: Color.black.opacity(0.15),
    activityColor: .white,
    pressedOverlayColor: Color.black.opacity(0.08),
    foregroundColor: .white,
    textSize: 14,
    textLineHeight: 20,
    borderRadius: 18,
    borderWidth: 0,
    borderColor: .clear,
    raiseAmount: 6,
    contentGap: 10,
    animationDuration: 0.14,
    animationCurve: .easeOutCubic,
    disabledBackgroundColor: Color(red: 0.722, green: 0.776, blue: 0.859),
    disabledDepthColor: Color(red: 0.596, green: 0.663, blue: 0.761),
    disabledShadowColor: Color.black.opacity(0.10),
    disabledForegroundColor: Color(red: 0.973, green: 0.980, blue: 0.988),
    disabledBorderColor: .clear
  )

  /// Theme data containing ``fallbackStyle``.
  public static let fallback = AwesomeButtonThemeData(style: fallbackStyle)

  /// Returns theme data with explicit style fields merged over its base.
  public func merge(style override: AwesomeButtonStyle?) -> AwesomeButtonThemeData {
    AwesomeButtonThemeData(style: style.merge(override))
  }
}

private struct AwesomeButtonThemeDataKey: EnvironmentKey {
  static let defaultValue: AwesomeButtonThemeData = .fallback
}

extension EnvironmentValues {
  public var awesomeButtonThemeData: AwesomeButtonThemeData {
    get { self[AwesomeButtonThemeDataKey.self] }
    set { self[AwesomeButtonThemeDataKey.self] = newValue }
  }
}

extension View {
  /// Supplies direct-button style defaults to this view hierarchy.
  public func awesomeButtonTheme(_ themeData: AwesomeButtonThemeData) -> some View {
    environment(\.awesomeButtonThemeData, themeData)
  }
}

/// Names of the built-in visual theme families.
public enum ThemeName: String, CaseIterable, Sendable {
  /// The neutral blue package theme.
  case basic
  /// The BoJack-inspired palette.
  case bojack
  /// The Cartman-inspired palette.
  case cartman
  /// The Mysterion-inspired palette.
  case mysterion
  /// The C-137-inspired palette.
  case c137
  /// The Rick-inspired palette.
  case rick
  /// The Summer-inspired palette.
  case summer
  /// The Bruce-inspired palette.
  case bruce
}

/// Semantic and social variants understood by themed buttons.
public enum ButtonVariant: String, CaseIterable, Sendable {
  /// The primary product action.
  case primary
  /// A lower-emphasis product action.
  case secondary
  /// A link-like or navigation action.
  case anchor
  /// A destructive or dangerous action.
  case danger
  /// The disabled visual variant, selected automatically by disabled state.
  case disabled
  /// A depth-free visual variant.
  case flat
  /// The canonical X social-network variant.
  case x
  /// The Messenger social-network variant.
  case messenger
  /// The Facebook social-network variant.
  case facebook
  /// The GitHub social-network variant.
  case github
  /// The LinkedIn social-network variant.
  case linkedin
  /// The WhatsApp social-network variant.
  case whatsapp
  /// The Reddit social-network variant.
  case reddit
  /// The Pinterest social-network variant.
  case pinterest
  /// The YouTube social-network variant.
  case youtube
}

/// Named geometry presets for themed buttons.
public enum ButtonSize: String, CaseIterable, Sendable {
  /// A square icon control.
  case icon
  /// A compact text control.
  case small
  /// The default text control.
  case medium
  /// A prominent text control.
  case large
}

/// Sparse visual and geometry values stored by a theme variant.
public struct ThemeButtonStyle: Sendable {
  /// The spinner and progress-indicator color.
  public var activityColor: Color?
  /// The face color while pressed.
  public var backgroundActive: Color?
  /// The resting face color.
  public var backgroundColor: Color?
  /// The lower depth-layer color.
  public var backgroundDarker: Color?
  /// The placeholder face color.
  public var backgroundPlaceholder: Color?
  /// The progress face color.
  public var backgroundProgress: Color?
  /// The ambient shadow color.
  public var backgroundShadow: Color?
  /// The inset border color.
  public var borderColor: Color?
  /// The fallback radius for corners without a physical override.
  public var borderRadius: CGFloat?
  /// The physical bottom-left radius, which does not mirror in RTL.
  public var borderBottomLeftRadius: CGFloat?
  /// The physical bottom-right radius, which does not mirror in RTL.
  public var borderBottomRightRadius: CGFloat?
  /// The physical top-left radius, which does not mirror in RTL.
  public var borderTopLeftRadius: CGFloat?
  /// The physical top-right radius, which does not mirror in RTL.
  public var borderTopRightRadius: CGFloat?
  /// The inset border width in points.
  public var borderWidth: CGFloat?
  /// The themed face height in points.
  public var height: CGFloat?
  /// Additional label-row padding below its content.
  public var paddingBottom: CGFloat?
  /// Horizontal label-row padding.
  public var paddingHorizontal: CGFloat?
  /// Additional label-row padding above its content.
  public var paddingTop: CGFloat?
  /// The themed separation between face and depth layers.
  public var raiseLevel: CGFloat?
  /// The label and icon color.
  public var textColor: Color?
  /// The PostScript name of an optional custom label font.
  public var textFontFamily: String?
  /// The fixed label line height in points.
  public var textLineHeight: CGFloat?
  /// The label font size in points.
  public var textSize: CGFloat?
  /// The themed fixed width in points.
  public var width: CGFloat?

  /// Creates sparse theme values that participate in precedence resolution.
  public init(
    borderRadius: CGFloat? = nil,
    borderBottomLeftRadius: CGFloat? = nil,
    borderBottomRightRadius: CGFloat? = nil,
    borderTopLeftRadius: CGFloat? = nil,
    borderTopRightRadius: CGFloat? = nil,
    height: CGFloat? = nil,
    paddingBottom: CGFloat? = nil,
    paddingHorizontal: CGFloat? = nil,
    paddingTop: CGFloat? = nil,
    raiseLevel: CGFloat? = nil,
    backgroundActive: Color? = nil,
    backgroundColor: Color? = nil,
    backgroundDarker: Color? = nil,
    backgroundPlaceholder: Color? = nil,
    backgroundProgress: Color? = nil,
    backgroundShadow: Color? = nil,
    textColor: Color? = nil,
    borderWidth: CGFloat? = nil,
    borderColor: Color? = nil,
    activityColor: Color? = nil,
    textFontFamily: String? = nil,
    textLineHeight: CGFloat? = nil,
    textSize: CGFloat? = nil,
    width: CGFloat? = nil
  ) {
    self.borderRadius = borderRadius
    self.borderBottomLeftRadius = borderBottomLeftRadius
    self.borderBottomRightRadius = borderBottomRightRadius
    self.borderTopLeftRadius = borderTopLeftRadius
    self.borderTopRightRadius = borderTopRightRadius
    self.height = height
    self.paddingBottom = paddingBottom
    self.paddingHorizontal = paddingHorizontal
    self.paddingTop = paddingTop
    self.raiseLevel = raiseLevel
    self.backgroundActive = backgroundActive
    self.backgroundColor = backgroundColor
    self.backgroundDarker = backgroundDarker
    self.backgroundPlaceholder = backgroundPlaceholder
    self.backgroundProgress = backgroundProgress
    self.backgroundShadow = backgroundShadow
    self.textColor = textColor
    self.borderWidth = borderWidth
    self.borderColor = borderColor
    self.activityColor = activityColor
    self.textFontFamily = textFontFamily
    self.textLineHeight = textLineHeight
    self.textSize = textSize
    self.width = width
  }

  /// Returns this style with every non-`nil` field from `other` applied over it.
  public func merge(_ other: ThemeButtonStyle?) -> ThemeButtonStyle {
    guard let other else {
      return self
    }

    return ThemeButtonStyle(
      borderRadius: other.borderRadius ?? borderRadius,
      borderBottomLeftRadius: other.borderBottomLeftRadius ?? borderBottomLeftRadius,
      borderBottomRightRadius: other.borderBottomRightRadius ?? borderBottomRightRadius,
      borderTopLeftRadius: other.borderTopLeftRadius ?? borderTopLeftRadius,
      borderTopRightRadius: other.borderTopRightRadius ?? borderTopRightRadius,
      height: other.height ?? height,
      paddingBottom: other.paddingBottom ?? paddingBottom,
      paddingHorizontal: other.paddingHorizontal ?? paddingHorizontal,
      paddingTop: other.paddingTop ?? paddingTop,
      raiseLevel: other.raiseLevel ?? raiseLevel,
      backgroundActive: other.backgroundActive ?? backgroundActive,
      backgroundColor: other.backgroundColor ?? backgroundColor,
      backgroundDarker: other.backgroundDarker ?? backgroundDarker,
      backgroundPlaceholder: other.backgroundPlaceholder ?? backgroundPlaceholder,
      backgroundProgress: other.backgroundProgress ?? backgroundProgress,
      backgroundShadow: other.backgroundShadow ?? backgroundShadow,
      textColor: other.textColor ?? textColor,
      borderWidth: other.borderWidth ?? borderWidth,
      borderColor: other.borderColor ?? borderColor,
      activityColor: other.activityColor ?? activityColor,
      textFontFamily: other.textFontFamily ?? textFontFamily,
      textLineHeight: other.textLineHeight ?? textLineHeight,
      textSize: other.textSize ?? textSize,
      width: other.width ?? width
    )
  }
}

/// Geometry and typography supplied by a named size preset.
public struct ThemeSizeStyle: Equatable, Sendable {
  /// The preset fixed width in points.
  public var width: CGFloat
  /// The preset face height in points.
  public var height: CGFloat
  /// An optional preset label font size in points.
  public var textSize: CGFloat?
  /// Optional preset horizontal label padding.
  public var paddingHorizontal: CGFloat?

  /// Creates a named-size geometry record.
  public init(
    width: CGFloat, height: CGFloat, textSize: CGFloat? = nil, paddingHorizontal: CGFloat? = nil
  ) {
    self.width = width
    self.height = height
    self.textSize = textSize
    self.paddingHorizontal = paddingHorizontal
  }
}

/// A complete theme family containing variant and size records.
public struct ThemeDefinition: Sendable {
  /// The user-facing theme title.
  public var title: String
  /// The recommended showcase background color.
  public var background: Color
  /// The recommended showcase foreground color.
  public var color: Color
  /// Variant-specific values keyed by semantic variant.
  public var buttons: [ButtonVariant: ThemeButtonStyle]
  /// Named geometry values keyed by size.
  public var size: [ButtonSize: ThemeSizeStyle]

  /// Creates a complete theme family.
  public init(
    title: String,
    background: Color,
    color: Color,
    buttons: [ButtonVariant: ThemeButtonStyle],
    size: [ButtonSize: ThemeSizeStyle]
  ) {
    self.title = title
    self.background = background
    self.color = color
    self.buttons = buttons
    self.size = size
  }
}

/// A theme family enriched with registry navigation metadata.
public struct RegisteredThemeDefinition: Sendable {
  /// The user-facing theme title.
  public var title: String
  /// The recommended showcase background color.
  public var background: Color
  /// The recommended showcase foreground color.
  public var color: Color
  /// Variant-specific theme values.
  public var buttons: [ButtonVariant: ThemeButtonStyle]
  /// Named size values.
  public var size: [ButtonSize: ThemeSizeStyle]
  /// The registry name for this theme.
  public var name: ThemeName
  /// Whether the registry contains a subsequent theme.
  public var next: Bool
  /// Whether the registry contains a preceding theme.
  public var prev: Bool

  /// Creates a registry result with deterministic navigation metadata.
  public init(
    title: String,
    background: Color,
    color: Color,
    buttons: [ButtonVariant: ThemeButtonStyle],
    size: [ButtonSize: ThemeSizeStyle],
    name: ThemeName,
    next: Bool,
    prev: Bool
  ) {
    self.title = title
    self.background = background
    self.color = color
    self.buttons = buttons
    self.size = size
    self.name = name
    self.next = next
    self.prev = prev
  }
}
