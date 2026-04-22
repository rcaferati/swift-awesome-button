import SwiftUI

public typealias AwesomeButtonPressCallback = (AwesomeButtonProgressHandle?) -> Void

public enum AwesomeButtonAnimationCurve: String, CaseIterable, Sendable {
    case easeOutCubic
    case easeOut
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

public final class AwesomeButtonProgressHandle {
    private let completion: (((() -> Void)?) -> Void)

    internal init(completion: @escaping (((() -> Void)?) -> Void)) {
        self.completion = completion
    }

    public func callAsFunction(_ callback: (() -> Void)? = nil) {
        completion(callback)
    }
}

public struct AwesomeButtonStyle {
    public var backgroundColor: Color?
    public var backgroundActive: Color?
    public var backgroundPlaceholder: Color?
    public var backgroundProgress: Color?
    public var depthColor: Color?
    public var shadowColor: Color?
    public var activityColor: Color?
    public var pressedOverlayColor: Color?
    public var foregroundColor: Color?
    public var textSize: CGFloat?
    public var textLineHeight: CGFloat?
    public var textFontFamily: String?
    public var borderRadius: CGFloat?
    public var borderWidth: CGFloat?
    public var borderColor: Color?
    public var raiseAmount: CGFloat?
    public var contentGap: CGFloat?
    /// Duration of the release animation (press-up). The press-down commit is
    /// driven by `pressInAnimationDuration` and defaults to zero so the pressed
    /// visual appears on the very next frame.
    public var animationDuration: TimeInterval?
    /// Curve of the release animation. See `animationDuration` for context.
    public var animationCurve: AwesomeButtonAnimationCurve?
    /// Duration of the press-down commit. Defaults to `0` so the pressed look
    /// (face offset, color swap, shadow shift) appears immediately — that's
    /// critical for the button to feel as reactive as a native UIControl.
    /// Set a small positive value if you want a brief ease-out on press-in.
    public var pressInAnimationDuration: TimeInterval?
    public var disabledBackgroundColor: Color?
    public var disabledDepthColor: Color?
    public var disabledShadowColor: Color?
    public var disabledForegroundColor: Color?
    public var disabledBorderColor: Color?

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

public struct AwesomeButtonThemeData {
    public var style: AwesomeButtonStyle

    public init(style: AwesomeButtonStyle) {
        self.style = style
    }

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
        pressInAnimationDuration: 0,
        disabledBackgroundColor: Color(red: 0.722, green: 0.776, blue: 0.859),
        disabledDepthColor: Color(red: 0.596, green: 0.663, blue: 0.761),
        disabledShadowColor: Color.black.opacity(0.10),
        disabledForegroundColor: Color(red: 0.973, green: 0.980, blue: 0.988),
        disabledBorderColor: .clear
    )

    public static let fallback = AwesomeButtonThemeData(style: fallbackStyle)

    public func merge(style override: AwesomeButtonStyle?) -> AwesomeButtonThemeData {
        AwesomeButtonThemeData(style: style.merge(override))
    }
}

private struct AwesomeButtonThemeDataKey: EnvironmentKey {
    static let defaultValue: AwesomeButtonThemeData = .fallback
}

public extension EnvironmentValues {
    var awesomeButtonThemeData: AwesomeButtonThemeData {
        get { self[AwesomeButtonThemeDataKey.self] }
        set { self[AwesomeButtonThemeDataKey.self] = newValue }
    }
}

public extension View {
    func awesomeButtonTheme(_ themeData: AwesomeButtonThemeData) -> some View {
        environment(\.awesomeButtonThemeData, themeData)
    }
}

public enum ThemeName: String, CaseIterable, Sendable {
    case basic
    case bojack
    case cartman
    case mysterion
    case c137
    case rick
    case summer
    case bruce
}

public enum ButtonVariant: String, CaseIterable, Sendable {
    case primary
    case secondary
    case anchor
    case danger
    case disabled
    case flat
    case x
    case messenger
    case facebook
    case github
    case linkedin
    case whatsapp
    case reddit
    case pinterest
    case youtube
}

public enum ButtonSize: String, CaseIterable, Sendable {
    case icon
    case small
    case medium
    case large
}

public struct ThemeButtonStyle {
    public var activityColor: Color?
    public var backgroundActive: Color?
    public var backgroundColor: Color?
    public var backgroundDarker: Color?
    public var backgroundPlaceholder: Color?
    public var backgroundProgress: Color?
    public var backgroundShadow: Color?
    public var borderColor: Color?
    public var borderRadius: CGFloat?
    public var borderBottomLeftRadius: CGFloat?
    public var borderBottomRightRadius: CGFloat?
    public var borderTopLeftRadius: CGFloat?
    public var borderTopRightRadius: CGFloat?
    public var borderWidth: CGFloat?
    public var height: CGFloat?
    public var paddingBottom: CGFloat?
    public var paddingHorizontal: CGFloat?
    public var paddingTop: CGFloat?
    public var raiseLevel: CGFloat?
    public var textColor: Color?
    public var textFontFamily: String?
    public var textLineHeight: CGFloat?
    public var textSize: CGFloat?
    public var width: CGFloat?

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

public struct ThemeSizeStyle: Equatable {
    public var width: CGFloat
    public var height: CGFloat
    public var textSize: CGFloat?
    public var paddingHorizontal: CGFloat?

    public init(width: CGFloat, height: CGFloat, textSize: CGFloat? = nil, paddingHorizontal: CGFloat? = nil) {
        self.width = width
        self.height = height
        self.textSize = textSize
        self.paddingHorizontal = paddingHorizontal
    }
}

public struct ThemeDefinition {
    public var title: String
    public var background: Color
    public var color: Color
    public var buttons: [ButtonVariant: ThemeButtonStyle]
    public var size: [ButtonSize: ThemeSizeStyle]

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

public struct RegisteredThemeDefinition {
    public var title: String
    public var background: Color
    public var color: Color
    public var buttons: [ButtonVariant: ThemeButtonStyle]
    public var size: [ButtonSize: ThemeSizeStyle]
    public var name: ThemeName
    public var next: Bool
    public var prev: Bool

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
