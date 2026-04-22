import SwiftUI

internal func shouldDeferReleaseAutoWidthTransition(
    isReleaseActive: Bool,
    currentConfiguration: AwesomeButtonResolvedConfiguration?,
    nextConfiguration: AwesomeButtonResolvedConfiguration,
    previousWidthMode: ButtonWidthMode?,
    currentWidth: CGFloat?,
    targetWidth: CGFloat?
) -> Bool {
    guard isReleaseActive,
          let currentConfiguration,
          previousWidthMode == .auto,
          nextConfiguration.widthMode == .auto,
          currentConfiguration.isAutoWidthTextEligible,
          currentConfiguration.textTransition,
          nextConfiguration.isAutoWidthTextEligible,
          nextConfiguration.textTransition,
          nextConfiguration.animateSize,
          currentConfiguration.height == nextConfiguration.height,
          currentConfiguration.paddingHorizontal == nextConfiguration.paddingHorizontal,
          currentConfiguration.paddingTop == nextConfiguration.paddingTop,
          currentConfiguration.paddingBottom == nextConfiguration.paddingBottom,
          currentConfiguration.style.sizeSignature == nextConfiguration.style.sizeSignature,
          currentConfiguration.childText != nextConfiguration.childText,
          let targetWidth else {
        return false
    }

    let flow = resolveAutoWidthTextFlow(
        currentWidth: currentWidth,
        targetWidth: targetWidth
    )
    return flow == .growFirst || flow == .shrinkLast
}
