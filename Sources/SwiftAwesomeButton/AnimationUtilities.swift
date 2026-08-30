import SwiftUI

internal struct AwesomeButtonAnimationTiming: Equatable {
  let duration: TimeInterval
  let curve: AwesomeButtonAnimationCurve
}

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
