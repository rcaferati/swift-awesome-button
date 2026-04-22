import SwiftUI

internal let sizeAnimationDuration: Double = 0.175
internal let releaseSpringSettleDuration: Double = 0.24
internal let releaseGeometryPressProgressFloor: CGFloat = -0.25

internal func clampedVisualPressProgress(_ progress: CGFloat) -> CGFloat {
    max(0, min(progress, 1))
}

internal func shellGeometryPressProgress(_ progress: CGFloat) -> CGFloat {
    max(releaseGeometryPressProgressFloor, min(progress, 1))
}

internal struct AwesomeButtonShellMetrics: Equatable, Hashable {
    let shellWidth: CGFloat
    let shellHeight: CGFloat
    let faceWidth: CGFloat
    let depthWidth: CGFloat
    let shadowWidth: CGFloat
}

internal struct AwesomeButtonShellPresentationVector: VectorArithmetic, Equatable {
    var width: CGFloat
    var height: CGFloat
    var pressProgress: CGFloat
    var styleTransitionProgress: CGFloat

    static var zero: AwesomeButtonShellPresentationVector {
        AwesomeButtonShellPresentationVector(width: 0, height: 0, pressProgress: 0, styleTransitionProgress: 0)
    }

    static func + (
        lhs: AwesomeButtonShellPresentationVector,
        rhs: AwesomeButtonShellPresentationVector
    ) -> AwesomeButtonShellPresentationVector {
        AwesomeButtonShellPresentationVector(
            width: lhs.width + rhs.width,
            height: lhs.height + rhs.height,
            pressProgress: lhs.pressProgress + rhs.pressProgress,
            styleTransitionProgress: lhs.styleTransitionProgress + rhs.styleTransitionProgress
        )
    }

    static func - (
        lhs: AwesomeButtonShellPresentationVector,
        rhs: AwesomeButtonShellPresentationVector
    ) -> AwesomeButtonShellPresentationVector {
        AwesomeButtonShellPresentationVector(
            width: lhs.width - rhs.width,
            height: lhs.height - rhs.height,
            pressProgress: lhs.pressProgress - rhs.pressProgress,
            styleTransitionProgress: lhs.styleTransitionProgress - rhs.styleTransitionProgress
        )
    }

    mutating func scale(by rhs: Double) {
        let scale = CGFloat(rhs)
        width *= scale
        height *= scale
        pressProgress *= scale
        styleTransitionProgress *= scale
    }

    var magnitudeSquared: Double {
        Double((width * width) + (height * height) + (pressProgress * pressProgress) + (styleTransitionProgress * styleTransitionProgress))
    }
}

internal func resolveAwesomeButtonShellMetrics(width: CGFloat, height: CGFloat) -> AwesomeButtonShellMetrics {
    let shellWidth = max(0, width)
    let shellHeight = max(0, height)
    return AwesomeButtonShellMetrics(
        shellWidth: shellWidth,
        shellHeight: shellHeight,
        faceWidth: shellWidth,
        depthWidth: shellWidth,
        shadowWidth: max(shellWidth * 0.98, 0)
    )
}

internal func sizeAnimation(duration: Double = sizeAnimationDuration) -> Animation {
    .timingCurve(0.6, 0.3, 0.35, 0.9, duration: duration)
}
