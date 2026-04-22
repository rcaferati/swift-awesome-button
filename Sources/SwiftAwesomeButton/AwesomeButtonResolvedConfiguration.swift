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
    let onPressIn: (() -> Void)?
    let onPressOut: (() -> Void)?
    let onPressedIn: (() -> Void)?
    let onPressedOut: (() -> Void)?
    let onProgressStart: (() -> Void)?
    let onProgressEnd: (() -> Void)?

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

        return widthMode == .auto &&
            labelView == nil &&
            beforeView == nil &&
            afterView == nil &&
            extraView == nil
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
        hasher.combine(style.sizeSignature)
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
