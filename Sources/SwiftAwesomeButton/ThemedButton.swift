import SwiftUI

internal struct ResolvedThemedButtonPresentation {
  let style: AwesomeButtonStyle
  let width: CGFloat?
  let height: CGFloat
  let paddingHorizontal: CGFloat?
  let paddingTop: CGFloat?
  let paddingBottom: CGFloat?
}

@MainActor
internal final class ThemedButtonStyleTransitionController: ObservableObject {
  @Published private(set) var progress: CGFloat = 1
  private(set) var sourceStyle: AwesomeButtonStyle?
  private(set) var targetStyle: AwesomeButtonStyle?

  func frame(for proposedTarget: AwesomeButtonStyle) -> AwesomeButtonStyle {
    guard let sourceStyle, let targetStyle else {
      return proposedTarget
    }
    return interpolateAwesomeButtonStyle(sourceStyle, targetStyle, progress: progress)
  }

  private var previousSourceSignature: Int?
  private var previousVariant: String?
  private var previousTransparent: Bool?

  func update(
    target: AwesomeButtonStyle,
    sourceSignature: Int,
    variant: ButtonVariant,
    transparent: Bool,
    reduceMotion: Bool = false
  ) {
    let hadPreviousContext = previousSourceSignature != nil
    let sameThemeSource = previousSourceSignature == sourceSignature
    let sameTransparent = previousTransparent == transparent
    let variantChanged = previousVariant != variant.rawValue
    previousSourceSignature = sourceSignature
    previousVariant = variant.rawValue
    previousTransparent = transparent

    guard targetStyle?.visualSignature != target.visualSignature else {
      return
    }
    guard targetStyle != nil else {
      sourceStyle = target
      targetStyle = target
      progress = 1
      return
    }

    let current = frame(for: target)
    sourceStyle = current
    targetStyle = target
    let duration = resolveThemedStyleTransitionDuration(
      hadPreviousContext: hadPreviousContext,
      sameThemeSource: sameThemeSource,
      sameTransparent: sameTransparent,
      variantChanged: variantChanged,
      reduceMotion: reduceMotion,
      styleDuration: target.animationDuration ?? 0.14
    )
    if duration == 0 {
      sourceStyle = target
      progress = 1
      return
    }
    progress = 0
    withAnimation(.easeOut(duration: duration)) {
      progress = 1
    }
  }
}

internal func resolveThemedStyleTransitionDuration(
  hadPreviousContext: Bool,
  sameThemeSource: Bool,
  sameTransparent: Bool,
  variantChanged: Bool,
  reduceMotion: Bool,
  styleDuration: TimeInterval
) -> TimeInterval {
  guard hadPreviousContext,
    sameThemeSource,
    sameTransparent,
    !reduceMotion
  else { return 0 }
  if variantChanged {
    return 0.2
  }
  return AwesomeButtonNormalization.requiredDuration(styleDuration, fallback: 0.14)
}

private struct ThemedButtonTransitionTaskID: Hashable {
  let styleSignature: Int
  let sourceSignature: Int
  let variant: String
  let transparent: Bool
  let reduceMotion: Bool
}

internal func themedButtonSourceSignature(
  config: ThemeDefinition?,
  index: Int?,
  name: ThemeName?
) -> Int {
  var hasher = Hasher()
  if let config {
    hasher.combine("config")
    hasher.combine(config.title)
    for variant in ButtonVariant.allCases {
      hasher.combine(variant.rawValue)
      guard let style = config.buttons[variant] else {
        hasher.combine(false)
        continue
      }
      hasher.combine(true)
      let normalized = AwesomeButtonNormalization.themeStyle(style)
      hasher.combine(themeButtonStyleToAwesomeButtonStyle(normalized).visualSignature)
      hasher.combine(normalized.width)
      hasher.combine(normalized.height)
      hasher.combine(normalized.paddingHorizontal)
      hasher.combine(normalized.paddingTop)
      hasher.combine(normalized.paddingBottom)
    }
    for size in ButtonSize.allCases {
      hasher.combine(size.rawValue)
      guard let definition = config.size[size] else {
        hasher.combine(false)
        continue
      }
      hasher.combine(true)
      let normalized = AwesomeButtonNormalization.sizeStyle(definition)
      hasher.combine(normalized.width)
      hasher.combine(normalized.height)
      hasher.combine(normalized.textSize)
      hasher.combine(normalized.paddingHorizontal)
    }
  } else if let name {
    hasher.combine("name")
    hasher.combine(name.rawValue)
  } else {
    hasher.combine("index")
    hasher.combine(index ?? 0)
  }
  return hasher.finalize()
}

internal func resolveThemedButtonPresentation(
  buttonStyle: ThemeButtonStyle,
  sizeStyle: ThemeSizeStyle,
  transparent: Bool,
  width: CGFloat?,
  autoWidth: Bool,
  height: CGFloat?,
  paddingHorizontal: CGFloat?,
  paddingTop: CGFloat?,
  paddingBottom: CGFloat?,
  stretch: Bool,
  style: AwesomeButtonStyle?
) -> ResolvedThemedButtonPresentation {
  let normalizedButtonStyle = AwesomeButtonNormalization.themeStyle(buttonStyle)
  let normalizedSizeStyle = AwesomeButtonNormalization.sizeStyle(sizeStyle)
  let resolvedButtonStyle =
    transparent
    ? normalizedButtonStyle.merge(transparentStyles)
    : normalizedButtonStyle
  let sizeFallback = AwesomeButtonStyle(
    textSize: resolvedButtonStyle.textSize == nil ? normalizedSizeStyle.textSize : nil
  )
  let effectiveStyle =
    themeButtonStyleToAwesomeButtonStyle(themePaletteForInterpolation(resolvedButtonStyle))
    .merge(sizeFallback)
    .merge(AwesomeButtonNormalization.style(style))
  let resolvedWidth: CGFloat?
  if stretch {
    resolvedWidth = nil
  } else if let width = AwesomeButtonNormalization.optional(width) {
    resolvedWidth = width
  } else if autoWidth {
    resolvedWidth = nil
  } else {
    resolvedWidth = resolvedButtonStyle.width ?? normalizedSizeStyle.width
  }

  return ResolvedThemedButtonPresentation(
    style: effectiveStyle,
    width: resolvedWidth,
    height: AwesomeButtonNormalization.optional(height) ?? resolvedButtonStyle.height
      ?? normalizedSizeStyle.height,
    paddingHorizontal: AwesomeButtonNormalization.optional(paddingHorizontal)
      ?? resolvedButtonStyle.paddingHorizontal
      ?? normalizedSizeStyle.paddingHorizontal,
    paddingTop: AwesomeButtonNormalization.optional(paddingTop) ?? resolvedButtonStyle.paddingTop,
    paddingBottom: AwesomeButtonNormalization.optional(paddingBottom)
      ?? resolvedButtonStyle.paddingBottom
  )
}

internal func resolveThemeSelection(
  config: ThemeDefinition?,
  index: Int?,
  name: ThemeName?
) -> RegisteredThemeDefinition {
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

/// A SwiftUI button that resolves a theme, semantic variant, and named size natively.
public struct ThemedButton: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @StateObject private var styleTransitionController = ThemedButtonStyleTransitionController()
  private let childText: String?
  private let labelView: AnyView?
  private let beforeView: AnyView?
  private let afterView: AnyView?
  private let extraView: AnyView?

  /// A caller-supplied theme definition, which takes precedence over registry selection.
  public let config: ThemeDefinition?
  /// An optional built-in registry index.
  public let index: Int?
  /// An optional built-in theme name.
  public let name: ThemeName?
  /// The requested semantic or social variant.
  public let type: ButtonVariant
  /// The requested named size.
  public let size: ButtonSize
  /// Requests the flat variant unless disabled styling overrides it.
  public let flat: Bool
  /// Removes face, depth, shadow, and border paint while retaining interaction geometry.
  public let transparent: Bool
  /// Animates changes to the string child when motion is allowed.
  public let textTransition: Bool
  /// The delay, in milliseconds, between adjacent text-transition slots.
  public let textTransitionSlotStaggerMs: Int
  /// Enables placeholder shimmer when motion is allowed.
  public let animatedPlaceholder: Bool
  /// Emits one light Apple-platform impact for an accepted physical press.
  public let hapticOnPress: Bool
  /// An explicit assistive-technology label for custom or ambiguous content.
  public let accessibilityLabel: String?
  /// Additional assistive-technology activation guidance.
  public let accessibilityHint: String?
  /// The localized name of the optional long-press action.
  public let accessibilityLongPressLabel: String?
  /// Receives accepted activation and optional progress completion ownership.
  public let onPress: AwesomeButtonPressCallback?
  /// Runs after an eligible physical or accessible long press.
  public let onLongPress: (() -> Void)?
  /// Prevents new interactions and selects disabled styling.
  public let disabled: Bool
  /// An explicit width that takes precedence over automatic and themed widths.
  public let width: CGFloat?
  /// Measures the rendered label row instead of using variant or size width.
  public let autoWidth: Bool
  /// Explicit face height before the resolved raise/depth layer is added.
  public let height: CGFloat?
  /// Explicit horizontal label-row padding.
  public let paddingHorizontal: CGFloat?
  /// Explicit additional padding above the label row.
  public let paddingTop: CGFloat?
  /// Explicit additional padding below the label row.
  public let paddingBottom: CGFloat?
  /// Expands to the maximum width proposed by the parent.
  public let stretch: Bool
  /// Explicit visual overrides applied after theme, variant, and size values.
  public let style: AwesomeButtonStyle?
  /// Face-content opacity at full press, normalized to `0...1`.
  public let activeOpacity: Double
  /// The minimum interval, in seconds, between accepted activations.
  public let debouncedPressTime: TimeInterval
  /// Enables one-shot asynchronous completion ownership.
  public let progress: Bool
  /// Controls only the busy overlay, not progress lifecycle semantics.
  public let showProgressBar: Bool
  /// The automatic progress duration in seconds.
  public let progressLoadingTime: TimeInterval
  /// Animates intrinsic size changes when motion is allowed.
  public let animateSize: Bool
  /// Runs at the accepted physical press boundary.
  public let onPressIn: (() -> Void)?
  /// Runs once when an owned physical press reaches release.
  public let onPressOut: (() -> Void)?
  /// Runs synchronously after pressed state is committed.
  public let onPressedIn: (() -> Void)?
  /// Runs when the release transition settles.
  public let onPressedOut: (() -> Void)?
  /// Runs once when progress begins.
  public let onProgressStart: (() -> Void)?
  /// Runs once after accepted progress completion settles.
  public let onProgressEnd: (() -> Void)?

  /// Creates a themed button whose primary label is an optional string.
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
    accessibilityLabel: String? = nil,
    accessibilityHint: String? = nil,
    accessibilityLongPressLabel: String? = nil,
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
    self.accessibilityLabel = accessibilityLabel
    self.accessibilityHint = accessibilityHint
    self.accessibilityLongPressLabel = accessibilityLongPressLabel
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

  /// Creates a themed button with arbitrary SwiftUI label content.
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
    accessibilityLabel: String? = nil,
    accessibilityHint: String? = nil,
    accessibilityLongPressLabel: String? = nil,
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
    self.accessibilityLabel = accessibilityLabel
    self.accessibilityHint = accessibilityHint
    self.accessibilityLongPressLabel = accessibilityLongPressLabel
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

  /// The SwiftUI representation of the resolved themed configuration.
  public var body: some View {
    let theme = resolveTheme()
    let buttonType = resolveButtonType(theme: theme, disabled: disabled, flat: flat, type: type)
    let buttonStyle = theme.buttons[buttonType] ?? theme.buttons[.primary] ?? ThemeButtonStyle()
    let sizeStyle =
      theme.size[size] ?? theme.size[.medium] ?? ThemeSizeStyle(width: 200, height: 60)
    let presentation = resolveThemedButtonPresentation(
      buttonStyle: buttonStyle,
      sizeStyle: sizeStyle,
      transparent: transparent,
      width: width,
      autoWidth: autoWidth,
      height: height,
      paddingHorizontal: paddingHorizontal,
      paddingTop: paddingTop,
      paddingBottom: paddingBottom,
      stretch: stretch,
      style: style
    )
    let sourceSignature = themedButtonSourceSignature(
      config: config,
      index: index,
      name: name
    )
    let renderedStyle = styleTransitionController.frame(for: presentation.style)

    Group {
      if let childText {
        AwesomeButton(
          child: childText,
          onPress: onPress,
          onLongPress: onLongPress,
          disabled: disabled,
          width: presentation.width,
          height: presentation.height,
          paddingHorizontal: presentation.paddingHorizontal,
          paddingTop: presentation.paddingTop,
          paddingBottom: presentation.paddingBottom,
          before: beforeView,
          after: afterView,
          extra: extraView,
          stretch: stretch,
          style: renderedStyle,
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
          accessibilityLabel: accessibilityLabel,
          accessibilityHint: accessibilityHint,
          accessibilityLongPressLabel: accessibilityLongPressLabel,
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
          width: presentation.width,
          height: presentation.height,
          paddingHorizontal: presentation.paddingHorizontal,
          paddingTop: presentation.paddingTop,
          paddingBottom: presentation.paddingBottom,
          before: beforeView,
          after: afterView,
          extra: extraView,
          stretch: stretch,
          style: renderedStyle,
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
          accessibilityLabel: accessibilityLabel,
          accessibilityHint: accessibilityHint,
          accessibilityLongPressLabel: accessibilityLongPressLabel,
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
          width: presentation.width,
          height: presentation.height,
          paddingHorizontal: presentation.paddingHorizontal,
          paddingTop: presentation.paddingTop,
          paddingBottom: presentation.paddingBottom,
          before: beforeView,
          after: afterView,
          extra: extraView,
          stretch: stretch,
          style: renderedStyle,
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
          accessibilityLabel: accessibilityLabel,
          accessibilityHint: accessibilityHint,
          accessibilityLongPressLabel: accessibilityLongPressLabel,
          onPressIn: onPressIn,
          onPressOut: onPressOut,
          onPressedIn: onPressedIn,
          onPressedOut: onPressedOut,
          onProgressStart: onProgressStart,
          onProgressEnd: onProgressEnd
        )
      }
    }
    .awesomeButtonTheme(AwesomeButtonThemeData(style: renderedStyle))
    .environment(\.awesomeButtonStyleFramesArePreInterpolated, true)
    .task(
      id: ThemedButtonTransitionTaskID(
        styleSignature: presentation.style.visualSignature,
        sourceSignature: sourceSignature,
        variant: buttonType.rawValue,
        transparent: transparent,
        reduceMotion: reduceMotion
      )
    ) {
      styleTransitionController.update(
        target: presentation.style,
        sourceSignature: sourceSignature,
        variant: buttonType,
        transparent: transparent,
        reduceMotion: reduceMotion
      )
    }
  }

  private func resolveTheme() -> RegisteredThemeDefinition {
    resolveThemeSelection(config: config, index: index, name: name)
  }
}
