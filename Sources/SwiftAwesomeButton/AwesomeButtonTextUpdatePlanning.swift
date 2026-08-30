import Foundation

internal enum ButtonTextUpdatePlan: Equatable {
  case assign(String?)
  case keep
  case transition(source: String, target: String)
}

internal func resolveButtonTextUpdatePlan(
  textTransitionEnabled: Bool,
  nextText: String?,
  currentTarget: String?,
  displayedText: String?,
  transitionActive: Bool = false
) -> ButtonTextUpdatePlan {
  let previousText = displayedText ?? currentTarget

  if textTransitionEnabled == false || nextText == nil || nextText?.isEmpty == true {
    return .assign(nextText)
  }

  if nextText == currentTarget {
    if transitionActive || nextText == displayedText {
      return .keep
    }

    guard let nextText, let previousText, previousText.isEmpty == false else {
      return .assign(nextText)
    }
    return .transition(source: previousText, target: nextText)
  }

  guard let nextText, let previousText, previousText.isEmpty == false else {
    return .assign(nextText)
  }

  return .transition(source: previousText, target: nextText)
}
