import SwiftUI

internal enum ButtonWidthMode {
  case auto
  case fixed
  case stretch
}

internal enum AutoWidthTextFlow {
  case initial
  case textOnly
  case growFirst
  case shrinkLast
}

internal enum ContentClipAlignment: Equatable, Hashable {
  case center
  case leading

  var swiftUIAlignment: Alignment {
    switch self {
    case .center:
      return .center
    case .leading:
      return .leading
    }
  }
}

internal func resolveAutoWidthTextFlow(
  currentWidth: CGFloat?,
  targetWidth: CGFloat
) -> AutoWidthTextFlow {
  guard let currentWidth else {
    return .initial
  }

  if abs(currentWidth - targetWidth) < 0.5 {
    return .textOnly
  }

  return targetWidth > currentWidth ? .growFirst : .shrinkLast
}

internal func shouldSnapWidthBridge(previous: ButtonWidthMode?, next: ButtonWidthMode) -> Bool {
  guard let previous else {
    return true
  }

  return previous != next
}

internal struct AwesomeButtonResolvedConfiguration {
  let childText: String?
  let labelView: AnyView?
  let beforeView: AnyView?
  let afterView: AnyView?
  let extraView: AnyView?
  let onPress: AwesomeButtonPressCallback?
  let onLongPress: (() -> Void)?
  let disabled: Bool
  let width: CGFloat?
  let height: CGFloat
  let paddingHorizontal: CGFloat
  let paddingTop: CGFloat
  let paddingBottom: CGFloat
  let stretch: Bool
  let style: AwesomeButtonStyle
  let activeOpacity: Double
  let debouncedPressTime: TimeInterval
  let progress: Bool
  let showProgressBar: Bool
  let progressLoadingTime: TimeInterval
  let animateSize: Bool
  let textTransition: Bool
  let textTransitionSlotStaggerMs: Int
  let animatedPlaceholder: Bool
  let hapticOnPress: Bool
  let accessibilityLabel: String?
  let accessibilityHint: String?
  let accessibilityLongPressLabel: String?
  let onPressIn: (() -> Void)?
  let onPressOut: (() -> Void)?
  let onPressedIn: (() -> Void)?
  let onPressedOut: (() -> Void)?
  let onProgressStart: (() -> Void)?
  let onProgressEnd: (() -> Void)?
  let animatesResolvedStyleChanges: Bool
  let reduceMotion: Bool
  let dynamicTypeSize: DynamicTypeSize
  #if canImport(UIKit)
    let nativeControlBridge: AwesomeButtonNativeControlBridge?
    let externallyHighlighted: Bool
  #endif

  init(
    childText: String?,
    labelView: AnyView?,
    beforeView: AnyView?,
    afterView: AnyView?,
    extraView: AnyView?,
    onPress: AwesomeButtonPressCallback?,
    onLongPress: (() -> Void)?,
    disabled: Bool,
    width: CGFloat?,
    height: CGFloat,
    paddingHorizontal: CGFloat,
    paddingTop: CGFloat,
    paddingBottom: CGFloat,
    stretch: Bool,
    style: AwesomeButtonStyle,
    activeOpacity: Double,
    debouncedPressTime: TimeInterval,
    progress: Bool,
    showProgressBar: Bool,
    progressLoadingTime: TimeInterval,
    animateSize: Bool,
    textTransition: Bool,
    textTransitionSlotStaggerMs: Int,
    animatedPlaceholder: Bool,
    hapticOnPress: Bool,
    accessibilityLabel: String? = nil,
    accessibilityHint: String? = nil,
    accessibilityLongPressLabel: String? = nil,
    onPressIn: (() -> Void)?,
    onPressOut: (() -> Void)?,
    onPressedIn: (() -> Void)?,
    onPressedOut: (() -> Void)?,
    onProgressStart: (() -> Void)?,
    onProgressEnd: (() -> Void)?,
    animatesResolvedStyleChanges: Bool = true,
    reduceMotion: Bool = false,
    dynamicTypeSize: DynamicTypeSize = .large,
    nativeControlBridge: AwesomeButtonNativeControlBridge? = nil,
    externallyHighlighted: Bool = false
  ) {
    self.childText = childText
    self.labelView = labelView
    self.beforeView = beforeView
    self.afterView = afterView
    self.extraView = extraView
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
    self.animatesResolvedStyleChanges = animatesResolvedStyleChanges
    self.reduceMotion = reduceMotion
    self.dynamicTypeSize = dynamicTypeSize
    self.nativeControlBridge = nativeControlBridge
    self.externallyHighlighted = externallyHighlighted
  }

  @MainActor
  var hasActivationSink: Bool {
    if onPress != nil {
      return true
    }
    #if canImport(UIKit)
      return nativeControlBridge?.hasConsumerActivationSink() == true
    #else
      return false
    #endif
  }

  @MainActor
  var hasAtomicActivationSink: Bool {
    if onPress != nil {
      return true
    }
    #if canImport(UIKit)
      return nativeControlBridge?.hasConsumerActivationSink(physical: false) == true
    #else
      return false
    #endif
  }

  var widthMode: ButtonWidthMode {
    if stretch {
      return .stretch
    }

    if width != nil {
      return .fixed
    }

    return .auto
  }

  var isPlaceholder: Bool {
    childText == nil && labelView == nil
  }

  var isEffectivelyDisabled: Bool {
    disabled || isPlaceholder
  }

  var isAutoWidthTextEligible: Bool {
    guard let childText, !childText.isEmpty else {
      return false
    }

    return widthMode == .auto && labelView == nil && beforeView == nil && afterView == nil
      && extraView == nil
  }

  var signature: Int {
    var hasher = Hasher()
    hasher.combine(childText)
    hasher.combine(labelView != nil)
    hasher.combine(beforeView != nil)
    hasher.combine(afterView != nil)
    hasher.combine(extraView != nil)
    hasher.combine(disabled)
    hasher.combine(width)
    hasher.combine(height)
    hasher.combine(paddingHorizontal)
    hasher.combine(paddingTop)
    hasher.combine(paddingBottom)
    hasher.combine(stretch)
    hasher.combine(activeOpacity)
    hasher.combine(debouncedPressTime)
    hasher.combine(progress)
    hasher.combine(showProgressBar)
    hasher.combine(progressLoadingTime)
    hasher.combine(animateSize)
    hasher.combine(textTransition)
    hasher.combine(textTransitionSlotStaggerMs)
    hasher.combine(animatedPlaceholder)
    hasher.combine(hapticOnPress)
    hasher.combine(accessibilityLabel)
    hasher.combine(accessibilityHint)
    hasher.combine(accessibilityLongPressLabel)
    hasher.combine(reduceMotion)
    hasher.combine(dynamicTypeSize)
    hasher.combine(style.visualSignature)
    return hasher.finalize()
  }

  var measurementSignature: AutoWidthMeasurementSignature? {
    guard let childText, isAutoWidthTextEligible else {
      return nil
    }

    return AutoWidthMeasurementSignature(
      text: childText,
      textFontFamily: style.textFontFamily,
      textSize: style.textSize ?? 14,
      textLineHeight: style.textLineHeight,
      paddingHorizontal: paddingHorizontal,
      borderWidth: style.borderWidth ?? 0
    )
  }
}
