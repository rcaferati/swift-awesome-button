import SwiftUI

public struct ThemedButton: View {
    private let childText: String?
    private let labelView: AnyView?
    private let beforeView: AnyView?
    private let afterView: AnyView?
    private let extraView: AnyView?

    public let config: ThemeDefinition?
    public let index: Int?
    public let name: ThemeName?
    public let type: ButtonVariant
    public let size: ButtonSize
    public let flat: Bool
    public let transparent: Bool
    public let textTransition: Bool
    public let textTransitionSlotStaggerMs: Int
    public let animatedPlaceholder: Bool
    public let hapticOnPress: Bool
    public let onPress: AwesomeButtonPressCallback?
    public let onLongPress: (() -> Void)?
    public let disabled: Bool
    public let width: CGFloat?
    public let autoWidth: Bool
    public let height: CGFloat?
    public let paddingHorizontal: CGFloat?
    public let paddingTop: CGFloat?
    public let paddingBottom: CGFloat?
    public let stretch: Bool
    public let style: AwesomeButtonStyle?
    public let activeOpacity: Double
    public let debouncedPressTime: TimeInterval
    public let progress: Bool
    public let showProgressBar: Bool
    public let progressLoadingTime: TimeInterval
    public let animateSize: Bool
    public let onPressIn: (() -> Void)?
    public let onPressOut: (() -> Void)?
    public let onPressedIn: (() -> Void)?
    public let onPressedOut: (() -> Void)?
    public let onProgressStart: (() -> Void)?
    public let onProgressEnd: (() -> Void)?

    public init(
        child: String? = nil,
        config: ThemeDefinition? = nil,
        index: Int? = nil,
        name: ThemeName? = nil,
        type: ButtonVariant = .primary,
        size: ButtonSize = .medium,
        flat: Bool = false,
        transparent: Bool = false,
        textTransition: Bool = false,
        textTransitionSlotStaggerMs: Int = 7,
        animatedPlaceholder: Bool = true,
        hapticOnPress: Bool = true,
        onPress: AwesomeButtonPressCallback? = nil,
        onLongPress: (() -> Void)? = nil,
        disabled: Bool = false,
        width: CGFloat? = nil,
        autoWidth: Bool = false,
        height: CGFloat? = nil,
        paddingHorizontal: CGFloat? = nil,
        paddingTop: CGFloat? = nil,
        paddingBottom: CGFloat? = nil,
        before: AnyView? = nil,
        after: AnyView? = nil,
        extra: AnyView? = nil,
        stretch: Bool = false,
        style: AwesomeButtonStyle? = nil,
        activeOpacity: Double = 1,
        debouncedPressTime: TimeInterval = 0,
        progress: Bool = false,
        showProgressBar: Bool = true,
        progressLoadingTime: TimeInterval = 3,
        animateSize: Bool = true,
        onPressIn: (() -> Void)? = nil,
        onPressOut: (() -> Void)? = nil,
        onPressedIn: (() -> Void)? = nil,
        onPressedOut: (() -> Void)? = nil,
        onProgressStart: (() -> Void)? = nil,
        onProgressEnd: (() -> Void)? = nil
    ) {
        self.childText = child
        self.labelView = nil
        self.beforeView = before
        self.afterView = after
        self.extraView = extra
        self.config = config
        self.index = index
        self.name = name
        self.type = type
        self.size = size
        self.flat = flat
        self.transparent = transparent
        self.textTransition = textTransition
        self.textTransitionSlotStaggerMs = textTransitionSlotStaggerMs
        self.animatedPlaceholder = animatedPlaceholder
        self.hapticOnPress = hapticOnPress
        self.onPress = onPress
        self.onLongPress = onLongPress
        self.disabled = disabled
        self.width = width
        self.autoWidth = autoWidth
        self.height = height
        self.paddingHorizontal = paddingHorizontal
        self.paddingTop = paddingTop
        self.paddingBottom = paddingBottom
        self.stretch = stretch
        self.style = style
        self.activeOpacity = activeOpacity
        self.debouncedPressTime = debouncedPressTime
        self.progress = progress
        self.showProgressBar = showProgressBar
        self.progressLoadingTime = progressLoadingTime
        self.animateSize = animateSize
        self.onPressIn = onPressIn
        self.onPressOut = onPressOut
        self.onPressedIn = onPressedIn
        self.onPressedOut = onPressedOut
        self.onProgressStart = onProgressStart
        self.onProgressEnd = onProgressEnd
    }

    public init(
        config: ThemeDefinition? = nil,
        index: Int? = nil,
        name: ThemeName? = nil,
        type: ButtonVariant = .primary,
        size: ButtonSize = .medium,
        flat: Bool = false,
        transparent: Bool = false,
        textTransition: Bool = false,
        textTransitionSlotStaggerMs: Int = 7,
        animatedPlaceholder: Bool = true,
        hapticOnPress: Bool = true,
        onPress: AwesomeButtonPressCallback? = nil,
        onLongPress: (() -> Void)? = nil,
        disabled: Bool = false,
        width: CGFloat? = nil,
        autoWidth: Bool = false,
        height: CGFloat? = nil,
        paddingHorizontal: CGFloat? = nil,
        paddingTop: CGFloat? = nil,
        paddingBottom: CGFloat? = nil,
        before: AnyView? = nil,
        after: AnyView? = nil,
        extra: AnyView? = nil,
        stretch: Bool = false,
        style: AwesomeButtonStyle? = nil,
        activeOpacity: Double = 1,
        debouncedPressTime: TimeInterval = 0,
        progress: Bool = false,
        showProgressBar: Bool = true,
        progressLoadingTime: TimeInterval = 3,
        animateSize: Bool = true,
        onPressIn: (() -> Void)? = nil,
        onPressOut: (() -> Void)? = nil,
        onPressedIn: (() -> Void)? = nil,
        onPressedOut: (() -> Void)? = nil,
        onProgressStart: (() -> Void)? = nil,
        onProgressEnd: (() -> Void)? = nil,
        @ViewBuilder label: () -> some View
    ) {
        self.childText = nil
        self.labelView = AnyView(label())
        self.beforeView = before
        self.afterView = after
        self.extraView = extra
        self.config = config
        self.index = index
        self.name = name
        self.type = type
        self.size = size
        self.flat = flat
        self.transparent = transparent
        self.textTransition = textTransition
        self.textTransitionSlotStaggerMs = textTransitionSlotStaggerMs
        self.animatedPlaceholder = animatedPlaceholder
        self.hapticOnPress = hapticOnPress
        self.onPress = onPress
        self.onLongPress = onLongPress
        self.disabled = disabled
        self.width = width
        self.autoWidth = autoWidth
        self.height = height
        self.paddingHorizontal = paddingHorizontal
        self.paddingTop = paddingTop
        self.paddingBottom = paddingBottom
        self.stretch = stretch
        self.style = style
        self.activeOpacity = activeOpacity
        self.debouncedPressTime = debouncedPressTime
        self.progress = progress
        self.showProgressBar = showProgressBar
        self.progressLoadingTime = progressLoadingTime
        self.animateSize = animateSize
        self.onPressIn = onPressIn
        self.onPressOut = onPressOut
        self.onPressedIn = onPressedIn
        self.onPressedOut = onPressedOut
        self.onProgressStart = onProgressStart
        self.onProgressEnd = onProgressEnd
    }

    public var body: some View {
        let theme = resolveTheme()
        let buttonType = resolveButtonType(theme: theme, disabled: disabled, flat: flat, type: type)
        let buttonStyle = theme.buttons[buttonType] ?? theme.buttons[.primary] ?? ThemeButtonStyle()
        let resolvedButtonStyle = transparent ? buttonStyle.merge(transparentStyles) : buttonStyle
        let sizeStyle = theme.size[size] ?? theme.size[.medium] ?? ThemeSizeStyle(width: 200, height: 60)
        let effectiveStyle = themeButtonStyleToAwesomeButtonStyle(themePaletteForInterpolation(resolvedButtonStyle))
            .merge(AwesomeButtonStyle(textSize: sizeStyle.textSize))
            .merge(style)
        let resolvedWidth: CGFloat? = {
            if stretch {
                return width
            }
            if autoWidth && width == nil {
                return nil
            }
            return width ?? sizeStyle.width
        }()

        Group {
            if let childText {
                AwesomeButton(
                    child: childText,
                    onPress: onPress,
                    onLongPress: onLongPress,
                    disabled: disabled,
                    width: resolvedWidth,
                    height: height ?? sizeStyle.height,
                    paddingHorizontal: paddingHorizontal ?? sizeStyle.paddingHorizontal ?? resolvedButtonStyle.paddingHorizontal,
                    paddingTop: paddingTop ?? resolvedButtonStyle.paddingTop,
                    paddingBottom: paddingBottom ?? resolvedButtonStyle.paddingBottom,
                    before: beforeView,
                    after: afterView,
                    extra: extraView,
                    stretch: stretch,
                    style: effectiveStyle,
                    activeOpacity: activeOpacity,
                    debouncedPressTime: debouncedPressTime,
                    progress: progress,
                    showProgressBar: showProgressBar,
                    progressLoadingTime: progressLoadingTime,
                    animateSize: animateSize,
                    textTransition: textTransition,
                    textTransitionSlotStaggerMs: textTransitionSlotStaggerMs,
                    animatedPlaceholder: animatedPlaceholder,
                    hapticOnPress: hapticOnPress,
                    onPressIn: onPressIn,
                    onPressOut: onPressOut,
                    onPressedIn: onPressedIn,
                    onPressedOut: onPressedOut,
                    onProgressStart: onProgressStart,
                    onProgressEnd: onProgressEnd
                )
            } else if let labelView {
                AwesomeButton(
                    onPress: onPress,
                    onLongPress: onLongPress,
                    disabled: disabled,
                    width: resolvedWidth,
                    height: height ?? sizeStyle.height,
                    paddingHorizontal: paddingHorizontal ?? sizeStyle.paddingHorizontal ?? resolvedButtonStyle.paddingHorizontal,
                    paddingTop: paddingTop ?? resolvedButtonStyle.paddingTop,
                    paddingBottom: paddingBottom ?? resolvedButtonStyle.paddingBottom,
                    before: beforeView,
                    after: afterView,
                    extra: extraView,
                    stretch: stretch,
                    style: effectiveStyle,
                    activeOpacity: activeOpacity,
                    debouncedPressTime: debouncedPressTime,
                    progress: progress,
                    showProgressBar: showProgressBar,
                    progressLoadingTime: progressLoadingTime,
                    animateSize: animateSize,
                    textTransition: textTransition,
                    textTransitionSlotStaggerMs: textTransitionSlotStaggerMs,
                    animatedPlaceholder: animatedPlaceholder,
                    hapticOnPress: hapticOnPress,
                    onPressIn: onPressIn,
                    onPressOut: onPressOut,
                    onPressedIn: onPressedIn,
                    onPressedOut: onPressedOut,
                    onProgressStart: onProgressStart,
                    onProgressEnd: onProgressEnd,
                    label: { labelView }
                )
            } else {
                AwesomeButton(
                    onPress: onPress,
                    onLongPress: onLongPress,
                    disabled: disabled,
                    width: resolvedWidth,
                    height: height ?? sizeStyle.height,
                    paddingHorizontal: paddingHorizontal ?? sizeStyle.paddingHorizontal ?? resolvedButtonStyle.paddingHorizontal,
                    paddingTop: paddingTop ?? resolvedButtonStyle.paddingTop,
                    paddingBottom: paddingBottom ?? resolvedButtonStyle.paddingBottom,
                    before: beforeView,
                    after: afterView,
                    extra: extraView,
                    stretch: stretch,
                    style: effectiveStyle,
                    activeOpacity: activeOpacity,
                    debouncedPressTime: debouncedPressTime,
                    progress: progress,
                    showProgressBar: showProgressBar,
                    progressLoadingTime: progressLoadingTime,
                    animateSize: animateSize,
                    textTransition: textTransition,
                    textTransitionSlotStaggerMs: textTransitionSlotStaggerMs,
                    animatedPlaceholder: animatedPlaceholder,
                    hapticOnPress: hapticOnPress,
                    onPressIn: onPressIn,
                    onPressOut: onPressOut,
                    onPressedIn: onPressedIn,
                    onPressedOut: onPressedOut,
                    onProgressStart: onProgressStart,
                    onProgressEnd: onProgressEnd
                )
            }
        }
        .awesomeButtonTheme(AwesomeButtonThemeData(style: effectiveStyle))
    }

    private func resolveTheme() -> RegisteredThemeDefinition {
        if let config {
            return RegisteredThemeDefinition(
                title: config.title,
                background: config.background,
                color: config.color,
                buttons: config.buttons,
                size: config.size,
                name: name ?? .basic,
                next: false,
                prev: false
            )
        }

        if let name {
            return getTheme(name: name)
        }

        return getTheme(index: index ?? 0)
    }
}
