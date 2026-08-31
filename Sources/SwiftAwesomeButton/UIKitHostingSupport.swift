#if canImport(UIKit)
  import SwiftUI
  import UIKit

  @MainActor
  internal protocol UIKitButtonHostOwnerAdapter: AnyObject {
    var hostControl: UIControl { get }

    func hostSetHighlighted(_ highlighted: Bool)
    func hostSystemAdaptationDidChange()
    func hostIntrinsicContentSize(constrainedWidth: CGFloat?) -> CGSize
  }

  internal struct UIKitButtonHostState {
    let isEnabled: Bool
    let isConfigurationDisabled: Bool
    let hasContent: Bool
    let stretches: Bool
    let accessibilityLabel: String?
    let accessibilityHint: String?
    let accessibilityLongPressLabel: String?
    let hasOrdinaryActivation: Bool
    let hasLongPress: Bool

    var isHostEligible: Bool {
      isEnabled && isConfigurationDisabled == false && hasContent
    }
  }

  @MainActor
  internal final class UIKitButtonHostCoordinator: NSObject {
    let hostingController = UIHostingController(rootView: AnyView(EmptyView()))
    let nativeBridge = AwesomeButtonNativeControlBridge()

    private(set) weak var parentViewController: UIViewController?
    private weak var adapter: UIKitButtonHostOwnerAdapter?
    private weak var explicitParentViewController: UIViewController?
    private var observationTokens: [NSObjectProtocol] = []
    private var state: UIKitButtonHostState?
    private var keyboardActivationArmed = false
    private var isApplyingInternalHighlight = false
    private var lastIntrinsicLayoutWidth: CGFloat?
    private var isTornDown = false

    init(adapter: UIKitButtonHostOwnerAdapter) {
      self.adapter = adapter
      super.init()
      hostingController.view.backgroundColor = .clear
      configureBridge()
      observeSystemAdaptation()
    }

    func update(rootView: AnyView, state: UIKitButtonHostState) {
      guard isTornDown == false else { return }
      self.state = state
      synchronizeHostEligibility()
      normalizeHighlightedState()
      hostingController.rootView = rootView
      adapter?.hostControl.invalidateIntrinsicContentSize()
      updateAccessibilityState()
    }

    func attach(to parentViewController: UIViewController) {
      guard let control = adapter?.hostControl, isTornDown == false else { return }
      explicitParentViewController = parentViewController
      attach(control: control, parent: parentViewController)
      nativeBridge.setInteractionMounted(true)
    }

    func detachFromParentViewController() {
      explicitParentViewController = nil
      nativeBridge.setInteractionMounted(false)
      detachHostingController()
    }

    func completeProgress(_ completion: (() -> Void)?) {
      nativeBridge.completeProgress(completion)
    }

    var intrinsicContentSize: CGSize {
      adapter?.hostIntrinsicContentSize(constrainedWidth: nil) ?? .zero
    }

    func sizeThatFits(_ size: CGSize) -> CGSize {
      guard let adapter, let state else { return .zero }
      let intrinsic = adapter.hostIntrinsicContentSize(constrainedWidth: nil)
      let width =
        state.stretches && size.width.isFinite && size.width > 0
        ? size.width
        : intrinsic.width
      return CGSize(
        width: width,
        height: adapter.hostIntrinsicContentSize(constrainedWidth: width).height
      )
    }

    func layoutDidChange() {
      guard let control = adapter?.hostControl,
        control.bounds.width.isFinite,
        control.bounds.width > 0
      else { return }
      if lastIntrinsicLayoutWidth.map({ abs($0 - control.bounds.width) > 0.5 }) ?? true {
        lastIntrinsicLayoutWidth = control.bounds.width
        control.invalidateIntrinsicContentSize()
      }
    }

    func didMoveToWindow() {
      reconcileContainment()
    }

    func didMoveToSuperview() {
      guard adapter?.hostControl.window != nil else { return }
      reconcileContainment()
    }

    func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
      guard let control = adapter?.hostControl else { return }
      if previousTraitCollection?.preferredContentSizeCategory
        != control.traitCollection.preferredContentSizeCategory
      {
        adapter?.hostSystemAdaptationDidChange()
      }
    }

    func externalHighlightDidChange() {
      guard isApplyingInternalHighlight == false else { return }
      normalizeHighlightedState()
      adapter?.hostSystemAdaptationDidChange()
    }

    func performAccessibilityActivation() -> Bool {
      nativeBridge.performAtomicActivation()
    }

    func refreshAccessibilityForFocus() {
      updateAccessibilityState()
    }

    func handleKeyboardActivationBegan() {
      guard let state,
        keyboardActivationArmed == false,
        state.isHostEligible,
        nativeBridge.componentIsBusy == false
      else { return }
      keyboardActivationArmed = true
      setHighlightedFromBridge(true)
    }

    @discardableResult
    func handleKeyboardActivationEnded(cancelled: Bool = false) -> Bool {
      guard keyboardActivationArmed else { return false }
      keyboardActivationArmed = false
      setHighlightedFromBridge(false)
      return cancelled ? false : nativeBridge.performAtomicActivation()
    }

    func pressesBegan(_ presses: Set<UIPress>, event: UIPressesEvent?) -> Bool {
      guard presses.contains(where: { $0.key.map(isAwesomeButtonActivationKey) == true }) else {
        return false
      }
      handleKeyboardActivationBegan()
      return true
    }

    func pressesEnded(_ presses: Set<UIPress>, event: UIPressesEvent?) -> Bool {
      guard presses.contains(where: { $0.key.map(isAwesomeButtonActivationKey) == true }) else {
        return false
      }
      _ = handleKeyboardActivationEnded()
      return true
    }

    func pressesCancelled(_ presses: Set<UIPress>, event: UIPressesEvent?) {
      if keyboardActivationArmed {
        _ = handleKeyboardActivationEnded(cancelled: true)
      }
    }

    func teardown() {
      guard isTornDown == false else { return }
      isTornDown = true

      nativeBridge.setInteractionMounted(false)
      nativeBridge.teardown()
      keyboardActivationArmed = false
      isApplyingInternalHighlight = false
      observationTokens.forEach(NotificationCenter.default.removeObserver)
      observationTokens.removeAll()
      detachHostingController()
      lastIntrinsicLayoutWidth = nil
      state = nil
      adapter = nil
    }

    private func configureBridge() {
      nativeBridge.control = adapter?.hostControl
      nativeBridge.setHighlighted = { [weak self] highlighted in
        self?.setHighlightedFromBridge(highlighted)
      }
      nativeBridge.invalidateIntrinsicSize = { [weak self] in
        self?.adapter?.hostControl.invalidateIntrinsicContentSize()
      }
      nativeBridge.accessibilityStateDidChange = { [weak self] in
        self?.updateAccessibilityState()
      }
    }

    private func observeSystemAdaptation() {
      let token = NotificationCenter.default.addObserver(
        forName: UIAccessibility.reduceMotionStatusDidChangeNotification,
        object: nil,
        queue: .main
      ) { [weak self] _ in
        MainActor.assumeIsolated {
          self?.adapter?.hostSystemAdaptationDidChange()
        }
      }
      observationTokens.append(token)
    }

    private func synchronizeHostEligibility() {
      guard let state else { return }
      nativeBridge.updateHostEligibility(state.isHostEligible)
    }

    private func normalizeHighlightedState() {
      guard let state, let control = adapter?.hostControl else { return }
      if state.isHostEligible == false || nativeBridge.componentIsBusy, control.isHighlighted {
        setHighlightedFromBridge(false)
      }
    }

    private func updateAccessibilityState() {
      guard let state, let control = adapter?.hostControl else { return }
      let label = state.accessibilityLabel
      control.isAccessibilityElement = label != nil
      control.accessibilityLabel = label
      if nativeBridge.componentIsBusy {
        control.accessibilityValue = AwesomeButtonLocalization.busyState
      } else if state.hasContent == false, label != nil {
        control.accessibilityValue = AwesomeButtonLocalization.placeholderState
      } else {
        control.accessibilityValue = nil
      }

      let unavailable = state.isHostEligible == false || nativeBridge.componentIsBusy
      let hasOrdinaryActivation =
        state.hasOrdinaryActivation
        || nativeBridge.hasConsumerActivationSink(physical: false)
      control.accessibilityHint =
        unavailable == false && hasOrdinaryActivation ? state.accessibilityHint : nil
      control.accessibilityTraits = unavailable ? [.button, .notEnabled] : [.button]
      if unavailable == false, state.hasLongPress {
        control.accessibilityCustomActions = [
          UIAccessibilityCustomAction(
            name: state.accessibilityLongPressLabel
              ?? AwesomeButtonLocalization.longPressAction,
            target: self,
            selector: #selector(performAccessibilityLongPress)
          )
        ]
      } else {
        control.accessibilityCustomActions = nil
      }
    }

    @objc private func performAccessibilityLongPress() -> Bool {
      nativeBridge.performAtomicLongPressActivation()
    }

    private func setHighlightedFromBridge(_ highlighted: Bool) {
      guard let control = adapter?.hostControl, control.isHighlighted != highlighted else {
        return
      }
      isApplyingInternalHighlight = true
      adapter?.hostSetHighlighted(highlighted)
      isApplyingInternalHighlight = false
    }

    private func reconcileContainment() {
      guard let control = adapter?.hostControl else { return }
      guard control.window != nil else {
        nativeBridge.setInteractionMounted(false)
        detachHostingController()
        return
      }
      if let parent = explicitParentViewController ?? discoverViewController(from: control) {
        attach(control: control, parent: parent)
        nativeBridge.setInteractionMounted(true)
        adapter?.hostSystemAdaptationDidChange()
      } else {
        nativeBridge.setInteractionMounted(false)
        detachHostingController()
        #if DEBUG
          debugPrint(
            "\(type(of: control)) requires attach(to:) when no UIViewController is discoverable"
          )
        #endif
      }
    }

    private func attach(control: UIControl, parent: UIViewController) {
      if parentViewController === parent, hostingController.view.superview === control {
        return
      }
      detachHostingController()
      parent.addChild(hostingController)
      let hostedView = hostingController.view!
      hostedView.translatesAutoresizingMaskIntoConstraints = false
      hostedView.backgroundColor = .clear
      hostedView.isAccessibilityElement = false
      hostedView.accessibilityElementsHidden = true
      control.addSubview(hostedView)
      NSLayoutConstraint.activate([
        hostedView.topAnchor.constraint(equalTo: control.topAnchor),
        hostedView.leadingAnchor.constraint(equalTo: control.leadingAnchor),
        hostedView.trailingAnchor.constraint(equalTo: control.trailingAnchor),
        hostedView.bottomAnchor.constraint(equalTo: control.bottomAnchor),
      ])
      hostingController.didMove(toParent: parent)
      parentViewController = parent
    }

    private func detachHostingController() {
      guard hostingController.parent != nil || hostingController.view.superview != nil else {
        parentViewController = nil
        return
      }
      hostingController.willMove(toParent: nil)
      hostingController.view.removeFromSuperview()
      hostingController.removeFromParent()
      parentViewController = nil
    }
  }

  @MainActor
  internal func discoverViewController(from view: UIView) -> UIViewController? {
    var responder: UIResponder? = view
    while let current = responder?.next {
      if let viewController = current as? UIViewController {
        return viewController
      }
      responder = current
    }
    return nil
  }

  @MainActor
  internal func isAwesomeButtonActivationKey(_ key: UIKey) -> Bool {
    key.keyCode == .keyboardReturnOrEnter || key.keyCode == .keyboardSpacebar
  }

  @MainActor
  internal func awesomeButtonUIKitFaceHeight(
    configuredHeight: CGFloat,
    style: AwesomeButtonStyle,
    child: String?,
    availableFaceWidth: CGFloat?,
    paddingHorizontal: CGFloat?,
    paddingTop: CGFloat?,
    paddingBottom: CGFloat?,
    traitCollection: UITraitCollection
  ) -> CGFloat {
    let baseLineHeight =
      style.textLineHeight ?? AwesomeButtonThemeData.fallbackStyle.textLineHeight ?? 20
    let scaledLineHeight = UIFontMetrics(forTextStyle: .body).scaledValue(
      for: baseLineHeight,
      compatibleWith: traitCollection
    )
    let borderWidth = max(0, style.borderWidth ?? 0)
    let horizontalInsets = (max(0, paddingHorizontal ?? 16) * 2) + (borderWidth * 2)
    var contentHeight = scaledLineHeight
    if awesomeButtonUIKitUsesExpandedTextLayout(traitCollection.preferredContentSizeCategory),
      let child,
      child.isEmpty == false,
      let availableFaceWidth,
      availableFaceWidth.isFinite,
      availableFaceWidth > horizontalInsets
    {
      let baseTextSize = style.textSize ?? AwesomeButtonThemeData.fallbackStyle.textSize ?? 14
      let baseFont =
        style.textFontFamily.flatMap { UIFont(name: $0, size: baseTextSize) }
        ?? UIFont.systemFont(ofSize: baseTextSize, weight: .bold)
      let scaledFont = UIFontMetrics(forTextStyle: .body).scaledFont(
        for: baseFont,
        compatibleWith: traitCollection
      )
      let measured = (child as NSString).boundingRect(
        with: CGSize(
          width: max(1, availableFaceWidth - horizontalInsets),
          height: CGFloat.greatestFiniteMagnitude
        ),
        options: [.usesLineFragmentOrigin, .usesFontLeading],
        attributes: [.font: scaledFont],
        context: nil
      )
      let lineCount = max(1, ceil(measured.height / max(1, scaledFont.lineHeight)))
      contentHeight = max(contentHeight, lineCount * scaledLineHeight)
    }
    return max(
      44,
      max(
        configuredHeight,
        contentHeight + max(0, paddingTop ?? 0) + max(0, paddingBottom ?? 0) + (borderWidth * 2)
      )
    )
  }

  private func awesomeButtonUIKitUsesExpandedTextLayout(_ category: UIContentSizeCategory) -> Bool {
    switch category {
    case .extraLarge, .extraExtraLarge, .extraExtraExtraLarge,
      .accessibilityMedium, .accessibilityLarge, .accessibilityExtraLarge,
      .accessibilityExtraExtraLarge, .accessibilityExtraExtraExtraLarge:
      return true
    default:
      return false
    }
  }
#endif
