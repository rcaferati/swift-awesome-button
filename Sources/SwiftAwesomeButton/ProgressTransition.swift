import Foundation
import CoreGraphics

internal let progressSwapDurationMs = 300
internal let progressFillCompletionDurationMs = 120
internal let progressOverlayFadeDelayMs = 120
internal let progressOverlayFadeDurationMs = 160
internal let progressTransitionRefreshMs = 16

internal func progressCompletionCurveValue(_ t: CGFloat) -> CGFloat {
    let value = max(0, min(t, 1))
    return 1 - pow(1 - value, 3)
}

internal func progressSwapCurveValue(_ t: CGFloat) -> CGFloat {
    let value = max(0, min(t, 1))
    let p = 1.2 * CGFloat.pi
    return 1 - pow(cos(value * CGFloat.pi / 2), 3) * cos(value * p)
}

internal func progressOverlayOpacityValue(elapsedMs: Int) -> CGFloat {
    if elapsedMs <= progressOverlayFadeDelayMs {
        return 1
    }

    if elapsedMs >= progressOverlayFadeDelayMs + progressOverlayFadeDurationMs {
        return 0
    }

    let localElapsed = elapsedMs - progressOverlayFadeDelayMs
    let progress = CGFloat(localElapsed) / CGFloat(progressOverlayFadeDurationMs)
    return 1 - progressCompletionCurveValue(progress)
}

internal protocol ProgressAnimationControlling: AnyObject {
    func stop()
}

internal final class NoopProgressAnimationController: ProgressAnimationControlling {
    func stop() {}
}

internal final class FrameProgressAnimationController: ProgressAnimationControlling {
    private let durationMs: Int
    private let delayMs: Int
    private let fromValue: CGFloat
    private let toValue: CGFloat
    private let curve: (CGFloat) -> CGFloat
    private let onUpdate: (CGFloat) -> Void
    private let onComplete: (() -> Void)?
    private var timer: Timer?
    private var startDate: Date?

    init(
        durationMs: Int,
        delayMs: Int,
        fromValue: CGFloat,
        toValue: CGFloat,
        curve: @escaping (CGFloat) -> CGFloat,
        onUpdate: @escaping (CGFloat) -> Void,
        onComplete: (() -> Void)?
    ) {
        self.durationMs = max(0, durationMs)
        self.delayMs = max(0, delayMs)
        self.fromValue = fromValue
        self.toValue = toValue
        self.curve = curve
        self.onUpdate = onUpdate
        self.onComplete = onComplete
    }

    func start() {
        startDate = Date()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: Double(progressTransitionRefreshMs) / 1000.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(timer!, forMode: .common)
        tick()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        guard let startDate else {
            return
        }

        let elapsedMs = Int(Date().timeIntervalSince(startDate) * 1000)
        if elapsedMs < delayMs {
            onUpdate(fromValue)
            return
        }

        if durationMs == 0 {
            onUpdate(toValue)
            onComplete?()
            stop()
            return
        }

        let localElapsed = elapsedMs - delayMs
        if localElapsed >= durationMs {
            onUpdate(toValue)
            onComplete?()
            stop()
            return
        }

        let progress = CGFloat(localElapsed) / CGFloat(durationMs)
        let transformed = curve(progress)
        onUpdate(fromValue + ((toValue - fromValue) * transformed))
    }
}

@discardableResult
internal func runProgressAnimation(
    durationMs: Int,
    delayMs: Int = 0,
    fromValue: CGFloat,
    toValue: CGFloat,
    curve: @escaping (CGFloat) -> CGFloat,
    onUpdate: @escaping (CGFloat) -> Void,
    onComplete: (() -> Void)? = nil
) -> ProgressAnimationControlling {
    if durationMs == 0 && delayMs == 0 {
        onUpdate(toValue)
        onComplete?()
        return NoopProgressAnimationController()
    }

    let controller = FrameProgressAnimationController(
        durationMs: durationMs,
        delayMs: delayMs,
        fromValue: fromValue,
        toValue: toValue,
        curve: curve,
        onUpdate: onUpdate,
        onComplete: onComplete
    )
    controller.start()
    return controller
}
