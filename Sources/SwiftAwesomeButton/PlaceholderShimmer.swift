import SwiftUI

internal let placeholderLoopDuration: Double = 3.223

internal func shouldRunPlaceholderAnimation(animated: Bool, measuredWidth: CGFloat) -> Bool {
    animated && measuredWidth > 0
}

internal func placeholderLoopPhase(
    elapsed: Double,
    duration: Double = placeholderLoopDuration
) -> Double {
    guard duration > 0 else {
        return 0
    }

    let wrappedElapsed = elapsed.truncatingRemainder(dividingBy: duration)
    return max(0, min(wrappedElapsed / duration, 1))
}

internal func snappedPlaceholderMeasurementWidth(_ width: CGFloat) -> CGFloat {
    max(0, width.rounded(.toNearestOrAwayFromZero))
}

internal func placeholderShimmerWidth(width: CGFloat) -> CGFloat {
    max(0, width * 0.4)
}

internal struct PlaceholderShimmerVisibleSegment: Equatable {
    let leadingX: CGFloat
    let width: CGFloat
}

private func interpolatePlaceholderValue(
    from start: CGFloat,
    to end: CGFloat,
    progress: Double
) -> CGFloat {
    let clampedProgress = max(0, min(progress, 1))
    return start + ((end - start) * CGFloat(clampedProgress))
}

internal func placeholderShimmerLeadingX(
    phase: Double,
    laneWidth: CGFloat,
    bandWidth: CGFloat
) -> CGFloat {
    guard laneWidth > 0, bandWidth > 0 else {
        return 0
    }

    let clampedPhase = max(0, min(phase, 1))
    let startX = -bandWidth
    let centerX = (laneWidth - bandWidth) / 2
    let endX = laneWidth

    if clampedPhase <= 0.25 {
        return interpolatePlaceholderValue(
            from: startX,
            to: centerX,
            progress: clampedPhase / 0.25
        )
    }

    if clampedPhase <= 0.5 {
        return interpolatePlaceholderValue(
            from: centerX,
            to: endX,
            progress: (clampedPhase - 0.25) / 0.25
        )
    }

    if clampedPhase <= 0.75 {
        return interpolatePlaceholderValue(
            from: endX,
            to: centerX,
            progress: (clampedPhase - 0.5) / 0.25
        )
    }

    return interpolatePlaceholderValue(
        from: centerX,
        to: startX,
        progress: (clampedPhase - 0.75) / 0.25
    )
}

internal func placeholderVisibleShimmerSegment(
    phase: Double,
    laneWidth: CGFloat,
    bandWidth: CGFloat
) -> PlaceholderShimmerVisibleSegment {
    guard laneWidth > 0, bandWidth > 0 else {
        return PlaceholderShimmerVisibleSegment(leadingX: 0, width: 0)
    }

    let virtualLeft = placeholderShimmerLeadingX(
        phase: phase,
        laneWidth: laneWidth,
        bandWidth: bandWidth
    )
    let virtualRight = virtualLeft + bandWidth
    let visibleLeft = min(max(0, virtualLeft), laneWidth)
    let visibleRight = min(max(0, virtualRight), laneWidth)
    let visibleWidth = max(0, visibleRight - visibleLeft)

    return PlaceholderShimmerVisibleSegment(
        leadingX: visibleLeft,
        width: visibleWidth
    )
}

internal struct PlaceholderFace: View {
    let tint: Color
    let height: CGFloat
    let animated: Bool

    var body: some View {
        GeometryReader { proxy in
            let placeholderWidth = snappedPlaceholderMeasurementWidth(proxy.size.width * 0.55)
            let placeholderHeight = min(height, proxy.size.height)
            let canAnimate = shouldRunPlaceholderAnimation(
                animated: animated,
                measuredWidth: placeholderWidth
            )

            ZStack {
                Rectangle()
                    .fill(tint)

                if canAnimate {
                    TimelineView(.animation) { context in
                        let phase = placeholderLoopPhase(
                            elapsed: context.date.timeIntervalSinceReferenceDate
                        )
                        let bandWidth = placeholderShimmerWidth(width: placeholderWidth)
                        let segment = placeholderVisibleShimmerSegment(
                            phase: phase,
                            laneWidth: placeholderWidth,
                            bandWidth: bandWidth
                        )

                        ZStack(alignment: .leading) {
                            if segment.width > 0 {
                                Rectangle()
                                    .fill(Color.black.opacity(0.2))
                                    .frame(width: segment.width, height: placeholderHeight)
                                    .offset(x: segment.leadingX)
                            }
                        }
                        .frame(
                            width: placeholderWidth,
                            height: placeholderHeight,
                            alignment: .leading
                        )
                    }
                    .frame(width: placeholderWidth, height: placeholderHeight)
                }
            }
            .frame(width: placeholderWidth, height: placeholderHeight)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
