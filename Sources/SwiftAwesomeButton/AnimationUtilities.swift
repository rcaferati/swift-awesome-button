import SwiftUI

internal struct AwesomeButtonAnimationTiming: Equatable {
  let duration: TimeInterval
  let curve: AwesomeButtonAnimationCurve
}

internal struct AwesomeButtonStyleTransitionContext: Hashable {
  let sourceSignature: Int
  let variant: String
  let transparent: Bool
}

internal struct AwesomeButtonTypographyFrame: Equatable {
  let textSize: CGFloat
  let lineHeight: CGFloat
  let fontFamily: String?
  let scale: CGFloat
}

internal let awesomeButtonTypographyBumpAmount: CGFloat = 0.04

internal let awesomeButtonReleaseSpringStiffness: CGFloat = 280
internal let awesomeButtonReleaseSpringDamping: CGFloat = 20

internal func resolvedPressInAnimationTiming(style: AwesomeButtonStyle)
  -> AwesomeButtonAnimationTiming
{
  let style = AwesomeButtonNormalization.style(style) ?? AwesomeButtonStyle()
  let fallback = AwesomeButtonThemeData.fallbackStyle
  return AwesomeButtonAnimationTiming(
    duration: style.pressInAnimationDuration ?? style.animationDuration ?? fallback
      .animationDuration ?? 0.14,
    curve: style.animationCurve ?? fallback.animationCurve ?? .easeOutCubic
  )
}

internal func resolvedDirectStyleAnimationTiming(style: AwesomeButtonStyle)
  -> AwesomeButtonAnimationTiming
{
  let style = AwesomeButtonNormalization.style(style) ?? AwesomeButtonStyle()
  let fallback = AwesomeButtonThemeData.fallbackStyle
  return AwesomeButtonAnimationTiming(
    duration: style.animationDuration ?? fallback.animationDuration ?? 0.14,
    curve: style.animationCurve ?? fallback.animationCurve ?? .easeOutCubic
  )
}

internal func shouldAnimateResolvedStyleTransition(
  from currentConfiguration: AwesomeButtonResolvedConfiguration,
  to nextConfiguration: AwesomeButtonResolvedConfiguration
) -> Bool {
  nextConfiguration.animatesResolvedStyleChanges && nextConfiguration.reduceMotion == false
    && currentConfiguration.disabled == nextConfiguration.disabled
    && currentConfiguration.style.visualSignature != nextConfiguration.style.visualSignature
}

internal func resolvedStyleTransitionTiming(
  from currentConfiguration: AwesomeButtonResolvedConfiguration,
  to nextConfiguration: AwesomeButtonResolvedConfiguration
) -> AwesomeButtonAnimationTiming? {
  guard
    shouldAnimateResolvedStyleTransition(
      from: currentConfiguration,
      to: nextConfiguration
    )
  else { return nil }

  switch (
    currentConfiguration.styleTransitionContext,
    nextConfiguration.styleTransitionContext
  ) {
  case (nil, nil):
    return resolvedDirectStyleAnimationTiming(style: nextConfiguration.style)
  case (let currentContext?, let nextContext?):
    let duration = resolveThemedStyleTransitionDuration(
      hadPreviousContext: true,
      sameThemeSource: currentContext.sourceSignature == nextContext.sourceSignature,
      sameTransparent: currentContext.transparent == nextContext.transparent,
      variantChanged: currentContext.variant != nextContext.variant,
      reduceMotion: nextConfiguration.reduceMotion,
      styleDuration: nextConfiguration.style.animationDuration ?? 0.14
    )
    guard duration > 0 else { return nil }
    return AwesomeButtonAnimationTiming(duration: duration, curve: .easeOut)
  case (.some, nil), (nil, .some):
    return nil
  }
}

internal func awesomeButtonTypographyTransitionScale(
  sourceTextSize: CGFloat?,
  targetTextSize: CGFloat?,
  progress: CGFloat,
  animateSize: Bool,
  reduceMotion: Bool
) -> CGFloat {
  guard animateSize, !reduceMotion,
    let sourceTextSize,
    let targetTextSize,
    abs(sourceTextSize - targetTextSize) >= 0.001
  else { return 1 }

  let progress = max(0, min(progress, 1))
  return 1 + (awesomeButtonTypographyBumpAmount * sin(.pi * progress))
}

internal func resolvedAwesomeButtonTypographyFrame(
  sourceStyle: AwesomeButtonStyle?,
  targetStyle: AwesomeButtonStyle,
  progress: CGFloat,
  animateSize: Bool,
  reduceMotion: Bool
) -> AwesomeButtonTypographyFrame {
  let targetStyle = resolvedVisualStyle(targetStyle)
  let sourceStyle = sourceStyle.map(resolvedVisualStyle)
  let effectiveStyle: AwesomeButtonStyle
  if animateSize, !reduceMotion, let sourceStyle {
    effectiveStyle = interpolateAwesomeButtonStyle(
      sourceStyle,
      targetStyle,
      progress: max(0, min(progress, 1))
    )
  } else {
    effectiveStyle = targetStyle
  }

  return AwesomeButtonTypographyFrame(
    textSize: effectiveStyle.textSize ?? 14,
    lineHeight: effectiveStyle.textLineHeight ?? 20,
    fontFamily: effectiveStyle.textFontFamily,
    scale: awesomeButtonTypographyTransitionScale(
      sourceTextSize: sourceStyle?.textSize,
      targetTextSize: targetStyle.textSize,
      progress: progress,
      animateSize: animateSize,
      reduceMotion: reduceMotion
    )
  )
}

private struct AnimatableCompletionObserver: AnimatableModifier {
  var targetValue: CGFloat
  var epsilon: CGFloat
  var onComplete: () -> Void
  var animatableData: CGFloat {
    didSet {
      notifyIfCompleted()
    }
  }

  init(
    observedValue: CGFloat,
    targetValue: CGFloat,
    epsilon: CGFloat = 0.001,
    onComplete: @escaping () -> Void
  ) {
    self.targetValue = targetValue
    self.epsilon = epsilon
    self.onComplete = onComplete
    self.animatableData = observedValue
  }

  func body(content: Content) -> some View {
    content
      .onAppear {
        notifyIfCompleted()
      }
  }

  private func notifyIfCompleted() {
    guard abs(animatableData - targetValue) <= epsilon else {
      return
    }

    DispatchQueue.main.async {
      onComplete()
    }
  }
}

extension View {
  fileprivate func onAnimatableCompletion(
    of value: CGFloat,
    target targetValue: CGFloat,
    epsilon: CGFloat = 0.001,
    perform action: @escaping () -> Void
  ) -> some View {
    modifier(
      AnimatableCompletionObserver(
        observedValue: value,
        targetValue: targetValue,
        epsilon: epsilon,
        onComplete: action
      )
    )
  }
}

internal func resolvedCurveValue(_ curve: AwesomeButtonAnimationCurve, progress: CGFloat) -> CGFloat
{
  let value = max(0, min(progress, 1))

  switch curve {
  case .easeOutCubic:
    return 1 - pow(1 - value, 3)
  case .easeOut:
    return 1 - pow(1 - value, 2)
  case .linear:
    return value
  }
}
