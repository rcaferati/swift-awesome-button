import SwiftUI
#if canImport(UIKit)
import UIKit

internal struct ButtonTouchSurface: UIViewRepresentable {
    let isDisabled: Bool
    let onTouchChange: (Bool) -> Void
    let onTouchEnd: (Bool) -> Void
    let onLongPress: () -> Void

    func makeUIView(context: Context) -> ButtonTouchSurfaceView {
        let view = ButtonTouchSurfaceView()
        view.backgroundColor = .clear
        view.isOpaque = false
        return view
    }

    func updateUIView(_ uiView: ButtonTouchSurfaceView, context: Context) {
        uiView.onTouchChange = onTouchChange
        uiView.onTouchEnd = onTouchEnd
        uiView.onLongPress = onLongPress
        uiView.isUserInteractionEnabled = !isDisabled
    }
}

// UIView-backed touch surface.
//
// This view DOES NOT subclass UIControl. That matters: UIScrollView's
// `touchesShouldCancel(in:)` returns `false` by default for UIControl
// descendants, which means that if we claimed the touch via UIControl
// tracking, the enclosing scroll view could never reclaim it — vertical
// drags on the button would be silently swallowed. By staying a plain
// UIView and driving press state from a cooperative custom gesture
// recognizer, a finger that starts on the button and drags vertically
// cleanly hands off to the scroll view.
internal final class ButtonTouchSurfaceView: UIView, UIGestureRecognizerDelegate {
    var onTouchChange: ((Bool) -> Void)?
    var onTouchEnd: ((Bool) -> Void)?
    var onLongPress: (() -> Void)?

    private var didTriggerLongPress = false

    private lazy var pressRecognizer: PressTouchRecognizer = {
        let recognizer = PressTouchRecognizer()
        recognizer.delegate = self
        recognizer.onTouchBegan = { [weak self] in
            self?.didTriggerLongPress = false
            self?.onTouchChange?(true)
        }
        recognizer.onTouchMoved = { [weak self] isInside in
            self?.onTouchChange?(isInside)
        }
        recognizer.onTouchEnded = { [weak self] isInside in
            guard let self else { return }
            let didLongPress = self.didTriggerLongPress
            self.didTriggerLongPress = false
            self.onTouchEnd?(didLongPress ? false : isInside)
        }
        recognizer.onTouchCancelled = { [weak self] in
            self?.didTriggerLongPress = false
            self?.onTouchEnd?(false)
        }
        return recognizer
    }()

    private lazy var longPressRecognizer: UILongPressGestureRecognizer = {
        let recognizer = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        recognizer.minimumPressDuration = 0.5
        recognizer.cancelsTouchesInView = false
        recognizer.delaysTouchesBegan = false
        recognizer.delegate = self
        return recognizer
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        addGestureRecognizer(pressRecognizer)
        addGestureRecognizer(longPressRecognizer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc
    private func handleLongPress(_ recognizer: UILongPressGestureRecognizer) {
        guard recognizer.state == .began else {
            return
        }

        didTriggerLongPress = true
        onLongPress?()
    }

    // Allow our press and long-press recognizers to coexist with each other and
    // with any enclosing gesture recognizers (notably UIScrollView's pan). The
    // press recognizer self-cancels on movement past its threshold, which
    // yields control to the scroll view's pan so scrolling can proceed while
    // the button cleanly releases its visual state.
    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        true
    }
}

// Custom press-down recognizer.
//
// Emits onTouchBegan immediately on finger contact (no minimumPressDuration,
// no delay). Emits onTouchMoved with an in-bounds flag for each movement
// sample. Self-cancels when the finger moves beyond `cancelMovementThreshold`
// in any direction — that threshold mirrors UIScrollView's default pan slop,
// so by the time we self-cancel the enclosing scroll view's pan is ready to
// take over and begin scrolling.
private final class PressTouchRecognizer: UIGestureRecognizer {
    // Matches UIScrollView's default pan slop. When the finger moves more than
    // this, we treat the gesture as a pan and yield to the enclosing scroll
    // view so vertical (or horizontal) drags over the button scroll the page.
    private static let cancelMovementThreshold: CGFloat = 10

    var onTouchBegan: (() -> Void)?
    var onTouchMoved: ((Bool) -> Void)?
    var onTouchEnded: ((Bool) -> Void)?
    var onTouchCancelled: (() -> Void)?

    private var trackedTouch: UITouch?
    private var startLocation: CGPoint = .zero

    override init(target: Any?, action: Selector?) {
        super.init(target: target, action: action)
        cancelsTouchesInView = false
        delaysTouchesBegan = false
        delaysTouchesEnded = false
    }

    convenience init() {
        self.init(target: nil, action: nil)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)

        guard trackedTouch == nil,
              let touch = touches.first,
              let view
        else {
            return
        }

        trackedTouch = touch
        startLocation = touch.location(in: view)
        state = .began
        onTouchBegan?()
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)

        guard let tracked = trackedTouch,
              touches.contains(tracked),
              let view
        else {
            return
        }

        let location = tracked.location(in: view)
        let dx = location.x - startLocation.x
        let dy = location.y - startLocation.y

        if abs(dx) > Self.cancelMovementThreshold ||
           abs(dy) > Self.cancelMovementThreshold {
            trackedTouch = nil
            state = .cancelled
            onTouchCancelled?()
            return
        }

        state = .changed
        onTouchMoved?(view.bounds.contains(location))
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesEnded(touches, with: event)

        guard let tracked = trackedTouch,
              touches.contains(tracked),
              let view
        else {
            return
        }

        let isInside = view.bounds.contains(tracked.location(in: view))
        trackedTouch = nil
        state = .ended
        onTouchEnded?(isInside)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesCancelled(touches, with: event)

        guard let tracked = trackedTouch,
              touches.contains(tracked)
        else {
            return
        }

        trackedTouch = nil
        state = .cancelled
        onTouchCancelled?()
    }

    override func reset() {
        super.reset()
        trackedTouch = nil
        startLocation = .zero
    }
}

#endif
