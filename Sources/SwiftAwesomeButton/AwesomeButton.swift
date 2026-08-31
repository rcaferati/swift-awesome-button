import SwiftUI

private struct AwesomeButtonStyleTransitionContextKey: EnvironmentKey {
  static let defaultValue: AwesomeButtonStyleTransitionContext? = nil
}

extension EnvironmentValues {
  var awesomeButtonStyleTransitionContext: AwesomeButtonStyleTransitionContext? {
    get { self[AwesomeButtonStyleTransitionContextKey.self] }
    set { self[AwesomeButtonStyleTransitionContextKey.self] = newValue }
  }
}

/// A SwiftUI control with a raised face, native interaction ownership, and optional progress.
public struct AwesomeButton: View {
  private let childText: String?
  private let labelView: AnyView?
  private let beforeView: AnyView?
  private let afterView: AnyView?
  private let extraView: AnyView?

  /// Receives an accepted activation and, in progress mode, its one-shot completion handle.
  public let onPress: AwesomeButtonPressCallback?
  /// Runs after an eligible physical or accessible long press.
  public let onLongPress: (() -> Void)?
  /// Prevents new interactions and cancels a currently owned gesture when committed.
  public let disabled: Bool
  /// An explicit face width, or `nil` to measure the rendered label row.
  public let width: CGFloat?
  /// Face height before the resolved raise/depth layer is added.
  public let height: CGFloat
  /// Horizontal padding applied to the label row.
  public let paddingHorizontal: CGFloat?
  /// Additional padding above the label row.
  public let paddingTop: CGFloat?
  /// Additional padding below the label row.
  public let paddingBottom: CGFloat?
  /// Expands the button to the maximum width proposed by its parent.
  public let stretch: Bool
  /// Direct visual overrides merged over the environment theme.
  public let style: AwesomeButtonStyle?
  /// Face-content opacity at full press, normalized to the closed range `0...1`.
  public let activeOpacity: Double
  /// The minimum interval, in seconds, between accepted activations.
  public let debouncedPressTime: TimeInterval
  /// Enables one-shot asynchronous completion ownership for accepted activations.
  public let progress: Bool
  /// Controls the busy overlay without changing progress lifecycle semantics.
  public let showProgressBar: Bool
  /// The automatic progress duration, in seconds, before a supplied handle completes it sooner.
  public let progressLoadingTime: TimeInterval
  /// Animates intrinsic size changes when motion is allowed.
  public let animateSize: Bool
  /// Animates changes to the string child when motion is allowed.
  public let textTransition: Bool
  /// The delay, in milliseconds, between adjacent text-transition slots.
  public let textTransitionSlotStaggerMs: Int
  /// Enables the placeholder shimmer when motion is allowed.
  public let animatedPlaceholder: Bool
  /// Emits one light Apple-platform impact for an accepted physical press.
  public let hapticOnPress: Bool
  /// An explicit assistive-technology label, required when custom content has no useful label.
  public let accessibilityLabel: String?
  /// Additional assistive-technology guidance for activation.
  public let accessibilityHint: String?
  /// The localized name of the optional long-press action.
  public let accessibilityLongPressLabel: String?
  /// Runs at the accepted physical press boundary before pressed state is committed.
  public let onPressIn: (() -> Void)?
  /// Runs once when an owned physical press reaches its release boundary.
  public let onPressOut: (() -> Void)?
  /// Runs synchronously after pressed state is committed.
  public let onPressedIn: (() -> Void)?
  /// Runs when the release transition reaches its resting state.
  public let onPressedOut: (() -> Void)?
  /// Runs once when a progress lifecycle begins.
  public let onProgressStart: (() -> Void)?
  /// Runs once after the accepted progress completion callback settles.
  public let onProgressEnd: (() -> Void)?

  @Environment(\.awesomeButtonThemeData) private var themeData
  @Environment(\.awesomeButtonStyleTransitionContext) private var styleTransitionContext
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  #if canImport(UIKit)
    @Environment(\.awesomeButtonNativeControlContext) private var nativeControlContext
  #endif
  @StateObject private var controller = AwesomeButtonController()

  /// Creates a button whose primary label is an optional string.
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
    accessibilityLabel: String? = nil,
    accessibilityHint: String? = nil,
    accessibilityLongPressLabel: String? = nil,
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
    self.accessibilityLabel = accessibilityLabel
    self.accessibilityHint = accessibilityHint
    self.accessibilityLongPressLabel = accessibilityLongPressLabel
    self.onPressIn = onPressIn
    self.onPressOut = onPressOut
    self.onPressedIn = onPressedIn
    self.onPressedOut = onPressedOut
    self.onProgressStart = onProgressStart
    self.onProgressEnd = onProgressEnd
  }

  /// Creates a button with arbitrary SwiftUI label content.
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
    accessibilityLabel: String? = nil,
    accessibilityHint: String? = nil,
    accessibilityLongPressLabel: String? = nil,
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
    self.accessibilityLabel = accessibilityLabel
    self.accessibilityHint = accessibilityHint
    self.accessibilityLongPressLabel = accessibilityLongPressLabel
    self.onPressIn = onPressIn
    self.onPressOut = onPressOut
    self.onPressedIn = onPressedIn
    self.onPressedOut = onPressedOut
    self.onProgressStart = onProgressStart
    self.onProgressEnd = onProgressEnd
  }

  /// The SwiftUI representation of the resolved button configuration.
  public var body: some View {
    let normalizedThemeStyle =
      AwesomeButtonNormalization.style(themeData.style) ?? AwesomeButtonStyle()
    let resolvedStyle = normalizedThemeStyle.merge(AwesomeButtonNormalization.style(style))
    let configuration = AwesomeButtonResolvedConfiguration(
      childText: childText,
      labelView: labelView,
      beforeView: beforeView,
      afterView: afterView,
      extraView: extraView,
      onPress: onPress,
      onLongPress: onLongPress,
      disabled: disabled,
      width: AwesomeButtonNormalization.optional(width),
      height: AwesomeButtonNormalization.required(height, fallback: 52),
      paddingHorizontal: AwesomeButtonNormalization.optional(paddingHorizontal) ?? 16,
      paddingTop: AwesomeButtonNormalization.optional(paddingTop) ?? 0,
      paddingBottom: AwesomeButtonNormalization.optional(paddingBottom) ?? 0,
      stretch: stretch,
      style: resolvedStyle,
      activeOpacity: AwesomeButtonNormalization.opacity(activeOpacity),
      debouncedPressTime: AwesomeButtonNormalization.requiredDuration(
        debouncedPressTime, fallback: 0),
      progress: progress,
      showProgressBar: showProgressBar,
      progressLoadingTime: AwesomeButtonNormalization.requiredDuration(
        progressLoadingTime, fallback: 3),
      animateSize: animateSize,
      textTransition: textTransition,
      textTransitionSlotStaggerMs: normalizeTextTransitionSlotStaggerMs(
        textTransitionSlotStaggerMs),
      animatedPlaceholder: animatedPlaceholder,
      hapticOnPress: hapticOnPress,
      accessibilityLabel: accessibilityLabel,
      accessibilityHint: accessibilityHint,
      accessibilityLongPressLabel: accessibilityLongPressLabel,
      onPressIn: onPressIn,
      onPressOut: onPressOut,
      onPressedIn: onPressedIn,
      onPressedOut: onPressedOut,
      onProgressStart: onProgressStart,
      onProgressEnd: onProgressEnd,
      animatesResolvedStyleChanges: true,
      styleTransitionContext: styleTransitionContext,
      reduceMotion: reduceMotion,
      dynamicTypeSize: dynamicTypeSize,
      nativeControlBridge: nativeControlContext?.bridge,
      externallyHighlighted: nativeControlContext?.externallyHighlighted ?? false
    )
    return AwesomeButtonBody(
      controller: controller,
      configuration: configuration,
      targetWidth: controller.resolvedWidth
        ?? (configuration.widthMode == .auto ? configuration.height : configuration.width),
      targetHeight: controller.resolvedHeight,
      targetPressProgress: controller.pressProgress
    )
    .task(id: configuration.signature) {
      controller.update(configuration: configuration)
    }
  }
}
