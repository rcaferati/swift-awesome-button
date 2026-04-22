import SwiftUI

public struct AwesomeButton: View {
    private let childText: String?
    private let labelView: AnyView?
    private let beforeView: AnyView?
    private let afterView: AnyView?
    private let extraView: AnyView?

    public let onPress: AwesomeButtonPressCallback?
    public let onLongPress: (() -> Void)?
    public let disabled: Bool
    public let width: CGFloat?
    public let height: CGFloat
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
    public let textTransition: Bool
    public let textTransitionSlotStaggerMs: Int
    public let animatedPlaceholder: Bool
    public let hapticOnPress: Bool
    public let onPressIn: (() -> Void)?
    public let onPressOut: (() -> Void)?
    public let onPressedIn: (() -> Void)?
    public let onPressedOut: (() -> Void)?
    public let onProgressStart: (() -> Void)?
    public let onProgressEnd: (() -> Void)?

    @Environment(\.awesomeButtonThemeData) private var themeData
    @StateObject private var controller = AwesomeButtonController()

    public init(
        child: String? = nil,
        onPress: AwesomeButtonPressCallback? = nil,
        onLongPress: (() -> Void)? = nil,
        disabled: Bool = false,
        width: CGFloat? = nil,
        height: CGFloat = 52,
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
        textTransition: Bool = false,
        textTransitionSlotStaggerMs: Int = 7,
        animatedPlaceholder: Bool = true,
        hapticOnPress: Bool = true,
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
        self.onPress = onPress
        self.onLongPress = onLongPress
        self.disabled = disabled
        self.width = width
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
        self.textTransition = textTransition
        self.textTransitionSlotStaggerMs = textTransitionSlotStaggerMs
        self.animatedPlaceholder = animatedPlaceholder
        self.hapticOnPress = hapticOnPress
        self.onPressIn = onPressIn
        self.onPressOut = onPressOut
        self.onPressedIn = onPressedIn
        self.onPressedOut = onPressedOut
        self.onProgressStart = onProgressStart
        self.onProgressEnd = onProgressEnd
    }

    public init(
        onPress: AwesomeButtonPressCallback? = nil,
        onLongPress: (() -> Void)? = nil,
        disabled: Bool = false,
        width: CGFloat? = nil,
        height: CGFloat = 52,
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
        textTransition: Bool = false,
        textTransitionSlotStaggerMs: Int = 7,
        animatedPlaceholder: Bool = true,
        hapticOnPress: Bool = true,
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
        self.onPress = onPress
        self.onLongPress = onLongPress
        self.disabled = disabled
        self.width = width
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
        self.textTransition = textTransition
        self.textTransitionSlotStaggerMs = textTransitionSlotStaggerMs
        self.animatedPlaceholder = animatedPlaceholder
        self.hapticOnPress = hapticOnPress
        self.onPressIn = onPressIn
        self.onPressOut = onPressOut
        self.onPressedIn = onPressedIn
        self.onPressedOut = onPressedOut
        self.onProgressStart = onProgressStart
        self.onProgressEnd = onProgressEnd
    }

    public var body: some View {
        let resolvedStyle = themeData.style.merge(style)
        let configuration = AwesomeButtonResolvedConfiguration(
            childText: childText,
            labelView: labelView,
            beforeView: beforeView,
            afterView: afterView,
            extraView: extraView,
            onPress: onPress,
            onLongPress: onLongPress,
            disabled: disabled,
            width: width,
            height: height,
            paddingHorizontal: paddingHorizontal ?? 16,
            paddingTop: paddingTop ?? 0,
            paddingBottom: paddingBottom ?? 0,
            stretch: stretch,
            style: resolvedStyle,
            activeOpacity: activeOpacity,
            debouncedPressTime: debouncedPressTime,
            progress: progress,
            showProgressBar: showProgressBar,
            progressLoadingTime: progressLoadingTime,
            animateSize: animateSize,
            textTransition: textTransition,
            textTransitionSlotStaggerMs: normalizeTextTransitionSlotStaggerMs(textTransitionSlotStaggerMs),
            animatedPlaceholder: animatedPlaceholder,
            hapticOnPress: hapticOnPress,
            onPressIn: onPressIn,
            onPressOut: onPressOut,
            onPressedIn: onPressedIn,
            onPressedOut: onPressedOut,
            onProgressStart: onProgressStart,
            onProgressEnd: onProgressEnd
        )
        let renderedConfiguration = controller.renderedConfiguration ?? configuration

        return AwesomeButtonBody(
            controller: controller,
            configuration: renderedConfiguration,
            targetWidth: controller.resolvedWidth,
            targetHeight: controller.resolvedHeight,
            targetPressProgress: controller.pressProgress
        )
        .task(id: configuration.signature) {
            controller.update(configuration: configuration)
        }
        .onDisappear {
            controller.cleanup()
        }
    }
}
