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
    displayedText: String?
) -> ButtonTextUpdatePlan {
    let previousText = displayedText ?? currentTarget

    if textTransitionEnabled == false ||
        nextText == nil ||
        nextText?.isEmpty == true {
        return .assign(nextText)
    }

    if nextText == currentTarget {
        return .keep
    }

    guard let nextText, let previousText, previousText.isEmpty == false else {
        return .assign(nextText)
    }

    return .transition(source: previousText, target: nextText)
}
