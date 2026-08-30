import SwiftUI

#if canImport(UIKit)
  import UIKit

  internal struct ButtonTouchSurface: UIViewRepresentable {
    let isDisabled: Bool
    let onConfigurationUpdate: () -> Void
    let onTouchChange: (Bool) -> Void
    let onTouchEnd: (Bool) -> Void
    let onLongPress: (() -> Void)?
    let onDismantle: () -> Void

    func makeUIView(context: Context) -> ButtonTouchSurfaceView {
      let view = ButtonTouchSurfaceView()
      view.backgroundColor = .clear
      view.isOpaque = false
      return view
    }

    func updateUIView(_ uiView: ButtonTouchSurfaceView, context: Context) {
      onConfigurationUpdate()
      uiView.update(
        isDisabled: isDisabled,
        onTouchChange: onTouchChange,
        onTouchEnd: onTouchEnd,
        onLongPress: onLongPress,
        onDismantle: onDismantle
      )
    }

    static func dismantleUIView(_ uiView: ButtonTouchSurfaceView, coordinator: ()) {
      uiView.dismantle()
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
    private var onTouchChange: ((Bool) -> Void)?
    private var onTouchEnd: ((Bool) -> Void)?
    private var onLongPress: (() -> Void)?
    private var onDismantle: (() -> Void)?
    private(set) var isTouchActive = false
    private(set) var didDispatchLongPress = false
    private var longPressEligibleAtStart = false
    private var longPressDisarmed = false
    private var interactionDisabled = true

    private lazy var pressRecognizer: PressTouchRecognizer = {
      let recognizer = PressTouchRecognizer()
      recognizer.delegate = self
      recognizer.onTouchBegan = { [weak self] in
        self?.beginTouch()
      }
      recognizer.onTouchMoved = { [weak self] isInside in
        self?.moveTouch(isInside: isInside)
      }
      recognizer.onTouchEnded = { [weak self] isInside in
        self?.endTouch(isInside: isInside)
      }
      recognizer.onTouchCancelled = { [weak self] in
        self?.cancelActiveTouch(silently: false)
      }
      return recognizer
    }()

    private lazy var longPressRecognizer: UILongPressGestureRecognizer = {
      let recognizer = UILongPressGestureRecognizer(
        target: self, action: #selector(handleLongPress(_:)))
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

    func update(
      isDisabled: Bool,
      onTouchChange: @escaping (Bool) -> Void,
      onTouchEnd: @escaping (Bool) -> Void,
      onLongPress: (() -> Void)?,
      onDismantle: @escaping () -> Void
    ) {
      self.onTouchChange = onTouchChange
      self.onTouchEnd = onTouchEnd
      self.onDismantle = onDismantle

      if isTouchActive, longPressEligibleAtStart, onLongPress == nil {
        longPressDisarmed = true
      }
      self.onLongPress = onLongPress

      if isDisabled {
        cancelActiveTouch(silently: false)
      }

      interactionDisabled = isDisabled
      pressRecognizer.isEnabled = !isDisabled
      if isTouchActive == false {
        longPressRecognizer.isEnabled = !isDisabled && onLongPress != nil
      }
      isUserInteractionEnabled = !isDisabled
    }

    func beginTouch() {
      guard interactionDisabled == false, isTouchActive == false else {
        return
      }

      isTouchActive = true
      didDispatchLongPress = false
      longPressEligibleAtStart = onLongPress != nil
      longPressDisarmed = false
      onTouchChange?(true)
    }

    func moveTouch(isInside: Bool) {
      guard isTouchActive else {
        return
      }

      if isInside {
        onTouchChange?(true)
      } else {
        cancelActiveTouch(silently: false)
      }
    }

    func endTouch(isInside: Bool) {
      guard isTouchActive else {
        return
      }

      let shouldActivate = isInside && didDispatchLongPress == false
      clearTouchBookkeeping()
      onTouchEnd?(shouldActivate)
      refreshRecognizerAvailability()
    }

    func cancelActiveTouch(silently: Bool) {
      guard isTouchActive else {
        return
      }

      clearTouchBookkeeping()
      if silently == false {
        onTouchEnd?(false)
      }
      refreshRecognizerAvailability()
    }

    func dispatchLongPressIfEligible() {
      guard isTouchActive,
        longPressEligibleAtStart,
        longPressDisarmed == false,
        didDispatchLongPress == false,
        let onLongPress
      else {
        return
      }

      didDispatchLongPress = true
      onLongPress()
    }

    func dismantle() {
      cancelActiveTouch(silently: true)
      onDismantle?()
      onTouchChange = nil
      onTouchEnd = nil
      onLongPress = nil
      onDismantle = nil
      interactionDisabled = true
    }

    @objc
    private func handleLongPress(_ recognizer: UILongPressGestureRecognizer) {
      guard recognizer.state == .began else {
        return
      }

      dispatchLongPressIfEligible()
    }

    private func clearTouchBookkeeping() {
      isTouchActive = false
      didDispatchLongPress = false
      longPressEligibleAtStart = false
      longPressDisarmed = false
    }

    private func refreshRecognizerAvailability() {
      longPressRecognizer.isEnabled = interactionDisabled == false && onLongPress != nil
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

      if abs(dx) > Self.cancelMovementThreshold || abs(dy) > Self.cancelMovementThreshold {
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
