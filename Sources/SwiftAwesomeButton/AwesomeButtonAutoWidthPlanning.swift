import SwiftUI

extension AutoWidthTextTransitionTiming: Equatable {
    static func == (lhs: AutoWidthTextTransitionTiming, rhs: AutoWidthTextTransitionTiming) -> Bool {
        lhs.widthDelay == rhs.widthDelay &&
            lhs.textDelay == rhs.textDelay &&
            lhs.widthDuration == rhs.widthDuration
    }
}

internal enum AutoWidthTextUpdatePlan: Equatable {
    case fallbackToTextSync
    case initial(targetText: String, targetWidth: CGFloat)
    case textOnly(sourceText: String, targetText: String, animateText: Bool)
    case growFirst(
        sourceText: String,
        targetText: String,
        targetWidth: CGFloat,
        timing: AutoWidthTextTransitionTiming,
        animateSize: Bool,
        animateText: Bool
    )
    case shrinkLast(
        sourceText: String,
        targetText: String,
        targetWidth: CGFloat,
        timing: AutoWidthTextTransitionTiming,
        animateSize: Bool,
        animateText: Bool
    )
}

internal func resolveAutoWidthTextUpdatePlan(
    isEligible: Bool,
    targetText: String?,
    currentWidth: CGFloat?,
    targetWidth: CGFloat?,
    displayedText: String?,
    animateSize: Bool,
    textTransition: Bool,
    slotStaggerMs: Int
) -> AutoWidthTextUpdatePlan {
    guard isEligible, let targetText, let targetWidth else {
        return .fallbackToTextSync
    }

    let sourceText = displayedText ?? targetText
    let flow = resolveAutoWidthTextFlow(
        currentWidth: currentWidth,
        targetWidth: targetWidth
    )

    switch flow {
    case .initial:
        return .initial(targetText: targetText, targetWidth: targetWidth)
    case .textOnly:
        return .textOnly(
            sourceText: sourceText,
            targetText: targetText,
            animateText: textTransition
        )
    case .growFirst:
        return .growFirst(
            sourceText: sourceText,
            targetText: targetText,
            targetWidth: targetWidth,
            timing: resolveAutoWidthTextTransitionTiming(
                fromText: sourceText,
                targetText: targetText,
                flow: .growFirst,
                slotStaggerMs: slotStaggerMs
            ),
            animateSize: animateSize,
            animateText: textTransition
        )
    case .shrinkLast:
        return .shrinkLast(
            sourceText: sourceText,
            targetText: targetText,
            targetWidth: targetWidth,
            timing: resolveAutoWidthTextTransitionTiming(
                fromText: sourceText,
                targetText: targetText,
                flow: .shrinkLast,
                slotStaggerMs: slotStaggerMs
            ),
            animateSize: animateSize,
            animateText: textTransition
        )
    }
}
