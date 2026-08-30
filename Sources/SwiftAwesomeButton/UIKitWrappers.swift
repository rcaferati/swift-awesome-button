#if canImport(UIKit)
  import SwiftUI
  import UIKit

  @MainActor
  private final class HostedButtonContainment {
    let hostingController = UIHostingController(rootView: AnyView(EmptyView()))
    private(set) weak var parentViewController: UIViewController?

    init() {
      hostingController.view.backgroundColor = .clear
    }

    func update(rootView: AnyView) {
      hostingController.rootView = rootView
    }

    func attach(to owner: UIControl, parent: UIViewController) {
      if parentViewController === parent, hostingController.view.superview === owner {
        return
      }
      detach()
      parent.addChild(hostingController)
      let hostedView = hostingController.view!
      hostedView.translatesAutoresizingMaskIntoConstraints = false
      hostedView.backgroundColor = .clear
      hostedView.isAccessibilityElement = false
      hostedView.accessibilityElementsHidden = true
      owner.addSubview(hostedView)
      NSLayoutConstraint.activate([
        hostedView.topAnchor.constraint(equalTo: owner.topAnchor),
        hostedView.leadingAnchor.constraint(equalTo: owner.leadingAnchor),
        hostedView.trailingAnchor.constraint(equalTo: owner.trailingAnchor),
        hostedView.bottomAnchor.constraint(equalTo: owner.bottomAnchor),
      ])
      hostingController.didMove(toParent: parent)
      parentViewController = parent
    }

    func detach() {
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
  private func discoverViewController(from view: UIView) -> UIViewController? {
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
  private func isAwesomeButtonActivationKey(_ key: UIKey) -> Bool {
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

  /// A programmatic UIKit control that hosts ``AwesomeButton`` while preserving native
  /// target-action, mutable configuration, intrinsic sizing, and view-controller containment.
  public final class AwesomeButtonControl: UIControl {
    /// The complete mutable configuration rendered by the control.
    public struct Configuration {
      /// The optional string label; `nil` presents placeholder content.
      public var child: String?
      /// Receives accepted activation and optional progress completion ownership.
      public var onPress: AwesomeButtonPressCallback?
      /// Runs after an eligible long press.
      public var onLongPress: (() -> Void)?
      /// Prevents new interactions and cancels active touch ownership when committed.
      public var disabled: Bool
      /// An explicit face width, or `nil` for intrinsic label-row measurement.
      public var width: CGFloat?
      /// Face height before the resolved raise/depth layer is added.
      public var height: CGFloat
      /// Horizontal label-row padding.
      public var paddingHorizontal: CGFloat?
      /// Additional padding above the label row.
      public var paddingTop: CGFloat?
      /// Additional padding below the label row.
      public var paddingBottom: CGFloat?
      /// Hosted SwiftUI content before the label in the intrinsic content row.
      public var before: AnyView?
      /// Hosted SwiftUI content after the label in the intrinsic content row.
      public var after: AnyView?
      /// Hosted SwiftUI face overlay that does not contribute to intrinsic width.
      public var extra: AnyView?
      /// Expands to the control's proposed layout width.
      public var stretch: Bool
      /// Direct visual overrides merged over environment defaults.
      public var style: AwesomeButtonStyle?
      /// Face-content opacity at full press, normalized to `0...1`.
      public var activeOpacity: Double
      /// The minimum interval, in seconds, between accepted activations.
      public var debouncedPressTime: TimeInterval
      /// Enables one-shot asynchronous completion ownership.
      public var progress: Bool
      /// Controls only the visual busy overlay.
      public var showProgressBar: Bool
      /// The automatic progress duration in seconds.
      public var progressLoadingTime: TimeInterval
      /// Animates intrinsic size updates when motion is allowed.
      public var animateSize: Bool
      /// Animates changes to the string child when motion is allowed.
      public var textTransition: Bool
      /// The delay, in milliseconds, between text-transition slots.
      public var textTransitionSlotStaggerMs: Int
      /// Enables placeholder shimmer when motion is allowed.
      public var animatedPlaceholder: Bool
      /// Emits one light impact for an accepted physical press.
      public var hapticOnPress: Bool
      /// An explicit accessibility label for custom or ambiguous content.
      public var accessibilityLabel: String?
      /// Additional accessibility activation guidance.
      public var accessibilityHint: String?
      /// The localized name of the optional long-press action.
      public var accessibilityLongPressLabel: String?
      /// Runs at the accepted physical press boundary.
      public var onPressIn: (() -> Void)?
      /// Runs once at the physical release boundary.
      public var onPressOut: (() -> Void)?
      /// Runs synchronously after pressed state is committed.
      public var onPressedIn: (() -> Void)?
      /// Runs when the release transition settles.
      public var onPressedOut: (() -> Void)?
      /// Runs once when progress begins.
      public var onProgressStart: (() -> Void)?
      /// Runs once after progress completion settles.
      public var onProgressEnd: (() -> Void)?

      /// Creates a complete direct-button value configuration.
      public init(
        child: String? = nil,
        onPress: AwesomeButtonPressCallback? = nil,
        onLongPress: (() -> Void)? = nil,
        disabled: Bool = false,
        width: CGFloat? = nil,
        height: CGFloat = 52,
        paddingHorizontal: CGFloat? = nil,
        paddingTop: CGFloat? = nil,
        paddingBottom: CGFloat? = nil,
        before: AnyView? = nil,
        after: AnyView? = nil,
        extra: AnyView? = nil,
        stretch: Bool = false,
        style: AwesomeButtonStyle? = nil,
        activeOpacity: Double = 1,
        debouncedPressTime: TimeInterval = 0,
        progress: Bool = false,
        showProgressBar: Bool = true,
        progressLoadingTime: TimeInterval = 3,
        animateSize: Bool = true,
        textTransition: Bool = false,
        textTransitionSlotStaggerMs: Int = 7,
        animatedPlaceholder: Bool = true,
        hapticOnPress: Bool = true,
        accessibilityLabel: String? = nil,
        accessibilityHint: String? = nil,
        accessibilityLongPressLabel: String? = nil,
        onPressIn: (() -> Void)? = nil,
        onPressOut: (() -> Void)? = nil,
        onPressedIn: (() -> Void)? = nil,
        onPressedOut: (() -> Void)? = nil,
        onProgressStart: (() -> Void)? = nil,
        onProgressEnd: (() -> Void)? = nil
      ) {
        self.child = child
        self.onPress = onPress
        self.onLongPress = onLongPress
        self.disabled = disabled
        self.width = width
        self.height = height
        self.paddingHorizontal = paddingHorizontal
        self.paddingTop = paddingTop
        self.paddingBottom = paddingBottom
        self.before = before
        self.after = after
        self.extra = extra
        self.stretch = stretch
        self.style = style
        self.activeOpacity = activeOpacity
        self.debouncedPressTime = debouncedPressTime
        self.progress = progress
        self.showProgressBar = showProgressBar
        self.progressLoadingTime = progressLoadingTime
        self.animateSize = animateSize
        self.textTransition = textTransition
        self.textTransitionSlotStaggerMs = textTransitionSlotStaggerMs
        self.animatedPlaceholder = animatedPlaceholder
        self.hapticOnPress = hapticOnPress
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityHint = accessibilityHint
        self.accessibilityLongPressLabel = accessibilityLongPressLabel
        self.onPressIn = onPressIn
        self.onPressOut = onPressOut
        self.onPressedIn = onPressedIn
        self.onPressedOut = onPressedOut
        self.onProgressStart = onProgressStart
        self.onProgressEnd = onProgressEnd
      }
    }

    /// The current value configuration. Assign a modified copy to update the existing control.
    public var configuration: Configuration {
      didSet {
        synchronizeHostEligibility()
        normalizeHighlightedState()
        rebuildRoot()
      }
    }

    private let containment = HostedButtonContainment()
    internal let nativeBridge = AwesomeButtonNativeControlBridge()
    private weak var explicitParentViewController: UIViewController?
    private var isApplyingInternalHighlight = false
    private var keyboardActivationArmed = false
    private var lastIntrinsicLayoutWidth: CGFloat?

    internal var hostedViewController: UIViewController { containment.hostingController }
    internal var attachedParentViewController: UIViewController? {
      containment.parentViewController
    }

    /// Controls native and hosted interaction eligibility together.
    public override var isEnabled: Bool {
      didSet {
        synchronizeHostEligibility()
        normalizeHighlightedState()
        rebuildRoot()
      }
    }

    /// Mirrors external UIKit highlighting into the hosted press presentation.
    public override var isHighlighted: Bool {
      didSet {
        guard isApplyingInternalHighlight == false else {
          return
        }
        normalizeHighlightedState()
        rebuildRoot()
      }
    }

    /// Creates a programmatic UIKit control from a mutable value configuration.
    public init(configuration: Configuration) {
      self.configuration = configuration
      super.init(frame: .zero)
      configureBridge()
      observeSystemAdaptation()
      rebuildRoot()
    }

    deinit {
      NotificationCenter.default.removeObserver(self)
    }

    /// Creates a programmatic UIKit control from direct button options.
    public convenience init(
      child: String? = nil,
      onPress: AwesomeButtonPressCallback? = nil,
      onLongPress: (() -> Void)? = nil,
      disabled: Bool = false,
      width: CGFloat? = nil,
      height: CGFloat = 52,
      paddingHorizontal: CGFloat? = nil,
      paddingTop: CGFloat? = nil,
      paddingBottom: CGFloat? = nil,
      before: AnyView? = nil,
      after: AnyView? = nil,
      extra: AnyView? = nil,
      stretch: Bool = false,
      style: AwesomeButtonStyle? = nil,
      activeOpacity: Double = 1,
      debouncedPressTime: TimeInterval = 0,
      progress: Bool = false,
      showProgressBar: Bool = true,
      progressLoadingTime: TimeInterval = 3,
      animateSize: Bool = true,
      textTransition: Bool = false,
      textTransitionSlotStaggerMs: Int = 7,
      animatedPlaceholder: Bool = true,
      hapticOnPress: Bool = true,
      accessibilityLabel: String? = nil,
      accessibilityHint: String? = nil,
      accessibilityLongPressLabel: String? = nil,
      onPressIn: (() -> Void)? = nil,
      onPressOut: (() -> Void)? = nil,
      onPressedIn: (() -> Void)? = nil,
      onPressedOut: (() -> Void)? = nil,
      onProgressStart: (() -> Void)? = nil,
      onProgressEnd: (() -> Void)? = nil
    ) {
      self.init(
        configuration: Configuration(
          child: child,
          onPress: onPress,
          onLongPress: onLongPress,
          disabled: disabled,
          width: width,
          height: height,
          paddingHorizontal: paddingHorizontal,
          paddingTop: paddingTop,
          paddingBottom: paddingBottom,
          before: before,
          after: after,
          extra: extra,
          stretch: stretch,
          style: style,
          activeOpacity: activeOpacity,
          debouncedPressTime: debouncedPressTime,
          progress: progress,
          showProgressBar: showProgressBar,
          progressLoadingTime: progressLoadingTime,
          animateSize: animateSize,
          textTransition: textTransition,
          textTransitionSlotStaggerMs: textTransitionSlotStaggerMs,
          animatedPlaceholder: animatedPlaceholder,
          hapticOnPress: hapticOnPress,
          accessibilityLabel: accessibilityLabel,
          accessibilityHint: accessibilityHint,
          accessibilityLongPressLabel: accessibilityLongPressLabel,
          onPressIn: onPressIn,
          onPressOut: onPressOut,
          onPressedIn: onPressedIn,
          onPressedOut: onPressedOut,
          onProgressStart: onProgressStart,
          onProgressEnd: onProgressEnd
        )
      )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
      fatalError("AwesomeButtonControl supports programmatic initialization only")
    }

    /// Attaches the stable hosting controller to a UIKit view-controller owner.
    public func attach(to parentViewController: UIViewController) {
      explicitParentViewController = parentViewController
      containment.attach(to: self, parent: parentViewController)
      nativeBridge.setInteractionMounted(true)
      rebuildRoot()
    }

    /// Detaches the hosting controller and silently cancels component-owned work.
    public func detachFromParentViewController() {
      explicitParentViewController = nil
      nativeBridge.setInteractionMounted(false)
      containment.detach()
    }

    /// Completes the current one-shot progress run for target-action consumers.
    public func completeProgress(_ completion: (() -> Void)? = nil) {
      nativeBridge.completeProgress(completion)
    }

    /// The resolved package intrinsic size, including depth and the 44-point minimum target.
    public override var intrinsicContentSize: CGSize {
      resolvedIntrinsicContentSize()
    }

    /// Returns resolved intrinsic geometry within a proposed UIKit size.
    public override func sizeThatFits(_ size: CGSize) -> CGSize {
      let intrinsic = resolvedIntrinsicContentSize()
      let width =
        configuration.stretch && size.width.isFinite && size.width > 0
        ? size.width
        : intrinsic.width
      return CGSize(
        width: width,
        height: resolvedIntrinsicContentSize(constrainedWidth: width).height
      )
    }

    /// Invalidates intrinsic height when the effective layout width changes.
    public override func layoutSubviews() {
      super.layoutSubviews()
      guard bounds.width.isFinite, bounds.width > 0 else { return }
      if lastIntrinsicLayoutWidth.map({ abs($0 - bounds.width) > 0.5 }) ?? true {
        lastIntrinsicLayoutWidth = bounds.width
        invalidateIntrinsicContentSize()
      }
    }

    /// Reconciles hosting-controller containment when window ownership changes.
    public override func didMoveToWindow() {
      super.didMoveToWindow()
      reconcileContainment()
    }

    /// Reconciles hosting-controller containment when the view hierarchy changes.
    public override func didMoveToSuperview() {
      super.didMoveToSuperview()
      if window != nil {
        reconcileContainment()
      }
    }

    /// Rebuilds Dynamic Type-dependent content when the relevant trait changes.
    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
      super.traitCollectionDidChange(previousTraitCollection)
      if previousTraitCollection?.preferredContentSizeCategory
        != traitCollection.preferredContentSizeCategory
      {
        rebuildRoot()
      }
    }

    private func observeSystemAdaptation() {
      NotificationCenter.default.addObserver(
        self,
        selector: #selector(systemAdaptationDidChange),
        name: UIAccessibility.reduceMotionStatusDidChangeNotification,
        object: nil
      )
    }

    @objc private func systemAdaptationDidChange() {
      rebuildRoot()
    }

    /// Performs one atomic native accessibility activation.
    public override func accessibilityActivate() -> Bool {
      nativeBridge.performAtomicActivation()
    }

    /// Refreshes dynamic accessibility state before announcing focus.
    public override func accessibilityElementDidBecomeFocused() {
      updateAccessibilityState()
      super.accessibilityElementDidBecomeFocused()
    }

    @objc private func performAccessibilityLongPress() -> Bool {
      nativeBridge.performAtomicLongPressActivation()
    }

    internal func handleKeyboardActivationBegan() {
      guard keyboardActivationArmed == false,
        isEnabled,
        configuration.disabled == false,
        configuration.child != nil,
        nativeBridge.componentIsBusy == false
      else { return }
      keyboardActivationArmed = true
      setHighlightedFromBridge(true)
    }

    @discardableResult
    internal func handleKeyboardActivationEnded(cancelled: Bool = false) -> Bool {
      guard keyboardActivationArmed else { return false }
      keyboardActivationArmed = false
      setHighlightedFromBridge(false)
      return cancelled ? false : nativeBridge.performAtomicActivation()
    }

    /// Arms Space or Return keyboard activation and its highlighted presentation.
    public override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
      if presses.contains(where: { $0.key.map(isAwesomeButtonActivationKey) == true }) {
        handleKeyboardActivationBegan()
      } else {
        super.pressesBegan(presses, with: event)
      }
    }

    /// Commits an armed Space or Return keyboard activation.
    public override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
      if presses.contains(where: { $0.key.map(isAwesomeButtonActivationKey) == true }) {
        _ = handleKeyboardActivationEnded()
      } else {
        super.pressesEnded(presses, with: event)
      }
    }

    /// Cancels an armed keyboard activation without dispatching it.
    public override func pressesCancelled(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
      if keyboardActivationArmed {
        _ = handleKeyboardActivationEnded(cancelled: true)
      }
      super.pressesCancelled(presses, with: event)
    }

    private func configureBridge() {
      nativeBridge.control = self
      nativeBridge.setHighlighted = { [weak self] highlighted in
        self?.setHighlightedFromBridge(highlighted)
      }
      nativeBridge.invalidateIntrinsicSize = { [weak self] in
        self?.invalidateIntrinsicContentSize()
      }
      nativeBridge.accessibilityStateDidChange = { [weak self] in
        self?.updateAccessibilityState()
      }
    }

    private func rebuildRoot() {
      synchronizeHostEligibility()
      let value = configuration
      let button = AwesomeButton(
        child: value.child,
        onPress: value.onPress,
        onLongPress: value.onLongPress,
        disabled: value.disabled || isEnabled == false,
        width: value.width,
        height: value.height,
        paddingHorizontal: value.paddingHorizontal,
        paddingTop: value.paddingTop,
        paddingBottom: value.paddingBottom,
        before: value.before,
        after: value.after,
        extra: value.extra,
        stretch: value.stretch,
        style: value.style,
        activeOpacity: value.activeOpacity,
        debouncedPressTime: value.debouncedPressTime,
        progress: value.progress,
        showProgressBar: value.showProgressBar,
        progressLoadingTime: value.progressLoadingTime,
        animateSize: value.animateSize,
        textTransition: value.textTransition,
        textTransitionSlotStaggerMs: value.textTransitionSlotStaggerMs,
        animatedPlaceholder: value.animatedPlaceholder,
        hapticOnPress: value.hapticOnPress,
        accessibilityLabel: value.accessibilityLabel,
        accessibilityHint: value.accessibilityHint,
        accessibilityLongPressLabel: value.accessibilityLongPressLabel,
        onPressIn: value.onPressIn,
        onPressOut: value.onPressOut,
        onPressedIn: value.onPressedIn,
        onPressedOut: value.onPressedOut,
        onProgressStart: value.onProgressStart,
        onProgressEnd: value.onProgressEnd
      )
      .environment(
        \.awesomeButtonNativeControlContext,
        AwesomeButtonNativeControlContext(
          bridge: nativeBridge,
          externallyHighlighted: isHighlighted
        )
      )
      containment.update(rootView: AnyView(button))
      invalidateIntrinsicContentSize()
      updateAccessibilityState()
    }

    private func resolvedIntrinsicContentSize(constrainedWidth: CGFloat? = nil) -> CGSize {
      let style = resolvedVisualStyle(
        AwesomeButtonThemeData.fallbackStyle.merge(configuration.style))
      let width = AwesomeButtonNormalization.optional(configuration.width)
      let height = AwesomeButtonNormalization.required(configuration.height, fallback: 52)
      let paddingHorizontal = AwesomeButtonNormalization.optional(configuration.paddingHorizontal)
      let paddingTop = AwesomeButtonNormalization.optional(configuration.paddingTop)
      let paddingBottom = AwesomeButtonNormalization.optional(configuration.paddingBottom)
      let desiredWidth =
        width.map { max(44, $0) }
        ?? max(44, max(height, nativeBridge.measuredAutoWidth ?? height))
      let layoutWidth = constrainedWidth ?? (bounds.width > 0 ? bounds.width : nil)
      let availableFaceWidth: CGFloat? =
        if configuration.stretch {
          layoutWidth
        } else if let width {
          layoutWidth.map { min(width, $0) } ?? width
        } else {
          layoutWidth.map { min(desiredWidth, $0) } ?? desiredWidth
        }
      let faceHeight = awesomeButtonUIKitFaceHeight(
        configuredHeight: height,
        style: style,
        child: configuration.child,
        availableFaceWidth: availableFaceWidth,
        paddingHorizontal: paddingHorizontal,
        paddingTop: paddingTop,
        paddingBottom: paddingBottom,
        traitCollection: traitCollection
      )
      let totalHeight = max(44, faceHeight + max(0, style.raiseAmount ?? 0))
      if configuration.stretch {
        return CGSize(width: UIView.noIntrinsicMetric, height: totalHeight)
      }
      if let width {
        return CGSize(width: max(44, width), height: totalHeight)
      }
      return CGSize(
        width: desiredWidth,
        height: totalHeight
      )
    }

    private func normalizeHighlightedState() {
      if configuration.disabled || isEnabled == false || configuration.child == nil
        || nativeBridge.componentIsBusy, isHighlighted
      {
        setHighlightedFromBridge(false)
      }
    }

    private func updateAccessibilityState() {
      let label = configuration.accessibilityLabel ?? configuration.child
      isAccessibilityElement = label != nil
      self.accessibilityLabel = label
      if nativeBridge.componentIsBusy {
        accessibilityValue = AwesomeButtonLocalization.busyState
      } else if configuration.child == nil, label != nil {
        accessibilityValue = AwesomeButtonLocalization.placeholderState
      } else {
        accessibilityValue = nil
      }
      let unavailable =
        isEnabled == false || configuration.disabled || configuration.child == nil
        || nativeBridge.componentIsBusy
      let hasOrdinaryActivation =
        configuration.onPress != nil || nativeBridge.hasConsumerActivationSink(physical: false)
      self.accessibilityHint =
        unavailable == false && hasOrdinaryActivation
        ? configuration.accessibilityHint
        : nil
      accessibilityTraits = unavailable ? [.button, .notEnabled] : [.button]
      if unavailable == false, configuration.onLongPress != nil {
        accessibilityCustomActions = [
          UIAccessibilityCustomAction(
            name: configuration.accessibilityLongPressLabel
              ?? AwesomeButtonLocalization.longPressAction,
            target: self,
            selector: #selector(performAccessibilityLongPress)
          )
        ]
      } else {
        accessibilityCustomActions = nil
      }
    }

    private func synchronizeHostEligibility() {
      nativeBridge.updateHostEligibility(
        isEnabled && configuration.disabled == false && configuration.child != nil
      )
    }

    private func setHighlightedFromBridge(_ highlighted: Bool) {
      guard isHighlighted != highlighted else {
        return
      }
      isApplyingInternalHighlight = true
      isHighlighted = highlighted
      isApplyingInternalHighlight = false
    }

    private func reconcileContainment() {
      guard window != nil else {
        nativeBridge.setInteractionMounted(false)
        containment.detach()
        return
      }
      if let parent = explicitParentViewController ?? discoverViewController(from: self) {
        containment.attach(to: self, parent: parent)
        nativeBridge.setInteractionMounted(true)
        rebuildRoot()
      } else {
        nativeBridge.setInteractionMounted(false)
        containment.detach()
        #if DEBUG
          debugPrint(
            "AwesomeButtonControl requires attach(to:) when no UIViewController is discoverable")
        #endif
      }
    }
  }

  /// A programmatic UIKit control that hosts ``ThemedButton`` with the same native control,
  /// mutable-configuration, sizing, and containment guarantees as ``AwesomeButtonControl``.
  public final class ThemedButtonControl: UIControl {
    /// The complete mutable themed-button configuration rendered by the control.
    public struct Configuration {
      /// The optional string label; `nil` presents placeholder content.
      public var child: String?
      /// A caller-supplied theme definition, which precedes registry selection.
      public var config: ThemeDefinition?
      /// An optional built-in registry index.
      public var index: Int?
      /// An optional built-in theme name.
      public var name: ThemeName?
      /// The requested semantic or social variant.
      public var type: ButtonVariant
      /// The requested named size.
      public var size: ButtonSize
      /// Requests flat styling unless disabled styling overrides it.
      public var flat: Bool
      /// Removes visual paint while retaining interaction geometry.
      public var transparent: Bool
      /// Animates changes to the string child when motion is allowed.
      public var textTransition: Bool
      /// The delay, in milliseconds, between text-transition slots.
      public var textTransitionSlotStaggerMs: Int
      /// Enables placeholder shimmer when motion is allowed.
      public var animatedPlaceholder: Bool
      /// Emits one light impact for an accepted physical press.
      public var hapticOnPress: Bool
      /// An explicit accessibility label for custom or ambiguous content.
      public var accessibilityLabel: String?
      /// Additional accessibility activation guidance.
      public var accessibilityHint: String?
      /// The localized name of the optional long-press action.
      public var accessibilityLongPressLabel: String?
      /// Receives accepted activation and optional progress completion ownership.
      public var onPress: AwesomeButtonPressCallback?
      /// Runs after an eligible long press.
      public var onLongPress: (() -> Void)?
      /// Prevents new interactions and selects disabled styling.
      public var disabled: Bool
      /// An explicit width that precedes automatic and themed widths.
      public var width: CGFloat?
      /// Measures the hosted label row rather than using themed width.
      public var autoWidth: Bool
      /// Explicit face height before the resolved raise/depth layer is added.
      public var height: CGFloat?
      /// Explicit horizontal label-row padding.
      public var paddingHorizontal: CGFloat?
      /// Explicit additional padding above the label row.
      public var paddingTop: CGFloat?
      /// Explicit additional padding below the label row.
      public var paddingBottom: CGFloat?
      /// Hosted SwiftUI content before the label in the intrinsic content row.
      public var before: AnyView?
      /// Hosted SwiftUI content after the label in the intrinsic content row.
      public var after: AnyView?
      /// Hosted SwiftUI face overlay that does not contribute to intrinsic width.
      public var extra: AnyView?
      /// Expands to the control's proposed layout width.
      public var stretch: Bool
      /// Explicit visual overrides applied after theme, variant, and size values.
      public var style: AwesomeButtonStyle?
      /// Face-content opacity at full press, normalized to `0...1`.
      public var activeOpacity: Double
      /// The minimum interval, in seconds, between accepted activations.
      public var debouncedPressTime: TimeInterval
      /// Enables one-shot asynchronous completion ownership.
      public var progress: Bool
      /// Controls only the visual busy overlay.
      public var showProgressBar: Bool
      /// The automatic progress duration in seconds.
      public var progressLoadingTime: TimeInterval
      /// Animates intrinsic size updates when motion is allowed.
      public var animateSize: Bool
      /// Runs at the accepted physical press boundary.
      public var onPressIn: (() -> Void)?
      /// Runs once at the physical release boundary.
      public var onPressOut: (() -> Void)?
      /// Runs synchronously after pressed state is committed.
      public var onPressedIn: (() -> Void)?
      /// Runs when the release transition settles.
      public var onPressedOut: (() -> Void)?
      /// Runs once when progress begins.
      public var onProgressStart: (() -> Void)?
      /// Runs once after progress completion settles.
      public var onProgressEnd: (() -> Void)?

      /// Creates a complete themed-button value configuration.
      public init(
        child: String? = nil,
        config: ThemeDefinition? = nil,
        index: Int? = nil,
        name: ThemeName? = nil,
        type: ButtonVariant = .primary,
        size: ButtonSize = .medium,
        flat: Bool = false,
        transparent: Bool = false,
        textTransition: Bool = false,
        textTransitionSlotStaggerMs: Int = 7,
        animatedPlaceholder: Bool = true,
        hapticOnPress: Bool = true,
        accessibilityLabel: String? = nil,
        accessibilityHint: String? = nil,
        accessibilityLongPressLabel: String? = nil,
        onPress: AwesomeButtonPressCallback? = nil,
        onLongPress: (() -> Void)? = nil,
        disabled: Bool = false,
        width: CGFloat? = nil,
        autoWidth: Bool = false,
        height: CGFloat? = nil,
        paddingHorizontal: CGFloat? = nil,
        paddingTop: CGFloat? = nil,
        paddingBottom: CGFloat? = nil,
        before: AnyView? = nil,
        after: AnyView? = nil,
        extra: AnyView? = nil,
        stretch: Bool = false,
        style: AwesomeButtonStyle? = nil,
        activeOpacity: Double = 1,
        debouncedPressTime: TimeInterval = 0,
        progress: Bool = false,
        showProgressBar: Bool = true,
        progressLoadingTime: TimeInterval = 3,
        animateSize: Bool = true,
        onPressIn: (() -> Void)? = nil,
        onPressOut: (() -> Void)? = nil,
        onPressedIn: (() -> Void)? = nil,
        onPressedOut: (() -> Void)? = nil,
        onProgressStart: (() -> Void)? = nil,
        onProgressEnd: (() -> Void)? = nil
      ) {
        self.child = child
        self.config = config
        self.index = index
        self.name = name
        self.type = type
        self.size = size
        self.flat = flat
        self.transparent = transparent
        self.textTransition = textTransition
        self.textTransitionSlotStaggerMs = textTransitionSlotStaggerMs
        self.animatedPlaceholder = animatedPlaceholder
        self.hapticOnPress = hapticOnPress
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityHint = accessibilityHint
        self.accessibilityLongPressLabel = accessibilityLongPressLabel
        self.onPress = onPress
        self.onLongPress = onLongPress
        self.disabled = disabled
        self.width = width
        self.autoWidth = autoWidth
        self.height = height
        self.paddingHorizontal = paddingHorizontal
        self.paddingTop = paddingTop
        self.paddingBottom = paddingBottom
        self.before = before
        self.after = after
        self.extra = extra
        self.stretch = stretch
        self.style = style
        self.activeOpacity = activeOpacity
        self.debouncedPressTime = debouncedPressTime
        self.progress = progress
        self.showProgressBar = showProgressBar
        self.progressLoadingTime = progressLoadingTime
        self.animateSize = animateSize
        self.onPressIn = onPressIn
        self.onPressOut = onPressOut
        self.onPressedIn = onPressedIn
        self.onPressedOut = onPressedOut
        self.onProgressStart = onProgressStart
        self.onProgressEnd = onProgressEnd
      }
    }

    /// The current value configuration. Assign a modified copy to update the existing control.
    public var configuration: Configuration {
      didSet {
        synchronizeHostEligibility()
        normalizeHighlightedState()
        rebuildRoot()
      }
    }

    private let containment = HostedButtonContainment()
    internal let nativeBridge = AwesomeButtonNativeControlBridge()
    private weak var explicitParentViewController: UIViewController?
    private var isApplyingInternalHighlight = false
    private var keyboardActivationArmed = false
    private var lastIntrinsicLayoutWidth: CGFloat?

    internal var hostedViewController: UIViewController { containment.hostingController }
    internal var attachedParentViewController: UIViewController? {
      containment.parentViewController
    }

    /// Controls native and hosted interaction eligibility together.
    public override var isEnabled: Bool {
      didSet {
        synchronizeHostEligibility()
        normalizeHighlightedState()
        rebuildRoot()
      }
    }

    /// Mirrors external UIKit highlighting into the hosted press presentation.
    public override var isHighlighted: Bool {
      didSet {
        guard isApplyingInternalHighlight == false else {
          return
        }
        normalizeHighlightedState()
        rebuildRoot()
      }
    }

    /// Creates a programmatic themed UIKit control from a value configuration.
    public init(configuration: Configuration) {
      self.configuration = configuration
      super.init(frame: .zero)
      configureBridge()
      observeSystemAdaptation()
      rebuildRoot()
    }

    deinit {
      NotificationCenter.default.removeObserver(self)
    }

    /// Creates a programmatic themed UIKit control from themed button options.
    public convenience init(
      child: String? = nil,
      config: ThemeDefinition? = nil,
      index: Int? = nil,
      name: ThemeName? = nil,
      type: ButtonVariant = .primary,
      size: ButtonSize = .medium,
      flat: Bool = false,
      transparent: Bool = false,
      textTransition: Bool = false,
      textTransitionSlotStaggerMs: Int = 7,
      animatedPlaceholder: Bool = true,
      hapticOnPress: Bool = true,
      accessibilityLabel: String? = nil,
      accessibilityHint: String? = nil,
      accessibilityLongPressLabel: String? = nil,
      onPress: AwesomeButtonPressCallback? = nil,
      onLongPress: (() -> Void)? = nil,
      disabled: Bool = false,
      width: CGFloat? = nil,
      autoWidth: Bool = false,
      height: CGFloat? = nil,
      paddingHorizontal: CGFloat? = nil,
      paddingTop: CGFloat? = nil,
      paddingBottom: CGFloat? = nil,
      before: AnyView? = nil,
      after: AnyView? = nil,
      extra: AnyView? = nil,
      stretch: Bool = false,
      style: AwesomeButtonStyle? = nil,
      activeOpacity: Double = 1,
      debouncedPressTime: TimeInterval = 0,
      progress: Bool = false,
      showProgressBar: Bool = true,
      progressLoadingTime: TimeInterval = 3,
      animateSize: Bool = true,
      onPressIn: (() -> Void)? = nil,
      onPressOut: (() -> Void)? = nil,
      onPressedIn: (() -> Void)? = nil,
      onPressedOut: (() -> Void)? = nil,
      onProgressStart: (() -> Void)? = nil,
      onProgressEnd: (() -> Void)? = nil
    ) {
      self.init(
        configuration: Configuration(
          child: child,
          config: config,
          index: index,
          name: name,
          type: type,
          size: size,
          flat: flat,
          transparent: transparent,
          textTransition: textTransition,
          textTransitionSlotStaggerMs: textTransitionSlotStaggerMs,
          animatedPlaceholder: animatedPlaceholder,
          hapticOnPress: hapticOnPress,
          accessibilityLabel: accessibilityLabel,
          accessibilityHint: accessibilityHint,
          accessibilityLongPressLabel: accessibilityLongPressLabel,
          onPress: onPress,
          onLongPress: onLongPress,
          disabled: disabled,
          width: width,
          autoWidth: autoWidth,
          height: height,
          paddingHorizontal: paddingHorizontal,
          paddingTop: paddingTop,
          paddingBottom: paddingBottom,
          before: before,
          after: after,
          extra: extra,
          stretch: stretch,
          style: style,
          activeOpacity: activeOpacity,
          debouncedPressTime: debouncedPressTime,
          progress: progress,
          showProgressBar: showProgressBar,
          progressLoadingTime: progressLoadingTime,
          animateSize: animateSize,
          onPressIn: onPressIn,
          onPressOut: onPressOut,
          onPressedIn: onPressedIn,
          onPressedOut: onPressedOut,
          onProgressStart: onProgressStart,
          onProgressEnd: onProgressEnd
        )
      )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
      fatalError("ThemedButtonControl supports programmatic initialization only")
    }

    /// Attaches the stable hosting controller to a UIKit view-controller owner.
    public func attach(to parentViewController: UIViewController) {
      explicitParentViewController = parentViewController
      containment.attach(to: self, parent: parentViewController)
      nativeBridge.setInteractionMounted(true)
      rebuildRoot()
    }

    /// Detaches the hosting controller and silently cancels component-owned work.
    public func detachFromParentViewController() {
      explicitParentViewController = nil
      nativeBridge.setInteractionMounted(false)
      containment.detach()
    }

    /// Completes the current one-shot progress run for target-action consumers.
    public func completeProgress(_ completion: (() -> Void)? = nil) {
      nativeBridge.completeProgress(completion)
    }

    /// The resolved package intrinsic size, including depth and the 44-point minimum target.
    public override var intrinsicContentSize: CGSize {
      resolvedIntrinsicContentSize()
    }

    /// Returns resolved themed geometry within a proposed UIKit size.
    public override func sizeThatFits(_ size: CGSize) -> CGSize {
      let intrinsic = resolvedIntrinsicContentSize()
      let width =
        configuration.stretch && size.width.isFinite && size.width > 0
        ? size.width
        : intrinsic.width
      return CGSize(
        width: width,
        height: resolvedIntrinsicContentSize(constrainedWidth: width).height
      )
    }

    /// Invalidates intrinsic height when the effective layout width changes.
    public override func layoutSubviews() {
      super.layoutSubviews()
      guard bounds.width.isFinite, bounds.width > 0 else { return }
      if lastIntrinsicLayoutWidth.map({ abs($0 - bounds.width) > 0.5 }) ?? true {
        lastIntrinsicLayoutWidth = bounds.width
        invalidateIntrinsicContentSize()
      }
    }

    /// Reconciles hosting-controller containment when window ownership changes.
    public override func didMoveToWindow() {
      super.didMoveToWindow()
      reconcileContainment()
    }

    /// Reconciles hosting-controller containment when the view hierarchy changes.
    public override func didMoveToSuperview() {
      super.didMoveToSuperview()
      if window != nil {
        reconcileContainment()
      }
    }

    /// Rebuilds Dynamic Type-dependent content when the relevant trait changes.
    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
      super.traitCollectionDidChange(previousTraitCollection)
      if previousTraitCollection?.preferredContentSizeCategory
        != traitCollection.preferredContentSizeCategory
      {
        rebuildRoot()
      }
    }

    private func observeSystemAdaptation() {
      NotificationCenter.default.addObserver(
        self,
        selector: #selector(systemAdaptationDidChange),
        name: UIAccessibility.reduceMotionStatusDidChangeNotification,
        object: nil
      )
    }

    @objc private func systemAdaptationDidChange() {
      rebuildRoot()
    }

    /// Performs one atomic native accessibility activation.
    public override func accessibilityActivate() -> Bool {
      nativeBridge.performAtomicActivation()
    }

    /// Refreshes dynamic accessibility state before announcing focus.
    public override func accessibilityElementDidBecomeFocused() {
      updateAccessibilityState()
      super.accessibilityElementDidBecomeFocused()
    }

    @objc private func performAccessibilityLongPress() -> Bool {
      nativeBridge.performAtomicLongPressActivation()
    }

    internal func handleKeyboardActivationBegan() {
      guard keyboardActivationArmed == false,
        isEnabled,
        configuration.disabled == false,
        configuration.child != nil,
        nativeBridge.componentIsBusy == false
      else { return }
      keyboardActivationArmed = true
      setHighlightedFromBridge(true)
    }

    @discardableResult
    internal func handleKeyboardActivationEnded(cancelled: Bool = false) -> Bool {
      guard keyboardActivationArmed else { return false }
      keyboardActivationArmed = false
      setHighlightedFromBridge(false)
      return cancelled ? false : nativeBridge.performAtomicActivation()
    }

    /// Arms Space or Return keyboard activation and its highlighted presentation.
    public override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
      if presses.contains(where: { $0.key.map(isAwesomeButtonActivationKey) == true }) {
        handleKeyboardActivationBegan()
      } else {
        super.pressesBegan(presses, with: event)
      }
    }

    /// Commits an armed Space or Return keyboard activation.
    public override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
      if presses.contains(where: { $0.key.map(isAwesomeButtonActivationKey) == true }) {
        _ = handleKeyboardActivationEnded()
      } else {
        super.pressesEnded(presses, with: event)
      }
    }

    /// Cancels an armed keyboard activation without dispatching it.
    public override func pressesCancelled(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
      if keyboardActivationArmed {
        _ = handleKeyboardActivationEnded(cancelled: true)
      }
      super.pressesCancelled(presses, with: event)
    }

    private func configureBridge() {
      nativeBridge.control = self
      nativeBridge.setHighlighted = { [weak self] highlighted in
        self?.setHighlightedFromBridge(highlighted)
      }
      nativeBridge.invalidateIntrinsicSize = { [weak self] in
        self?.invalidateIntrinsicContentSize()
      }
      nativeBridge.accessibilityStateDidChange = { [weak self] in
        self?.updateAccessibilityState()
      }
    }

    private func rebuildRoot() {
      synchronizeHostEligibility()
      let value = configuration
      let button = ThemedButton(
        child: value.child,
        config: value.config,
        index: value.index,
        name: value.name,
        type: value.type,
        size: value.size,
        flat: value.flat,
        transparent: value.transparent,
        textTransition: value.textTransition,
        textTransitionSlotStaggerMs: value.textTransitionSlotStaggerMs,
        animatedPlaceholder: value.animatedPlaceholder,
        hapticOnPress: value.hapticOnPress,
        accessibilityLabel: value.accessibilityLabel,
        accessibilityHint: value.accessibilityHint,
        accessibilityLongPressLabel: value.accessibilityLongPressLabel,
        onPress: value.onPress,
        onLongPress: value.onLongPress,
        disabled: value.disabled || isEnabled == false,
        width: value.width,
        autoWidth: value.autoWidth,
        height: value.height,
        paddingHorizontal: value.paddingHorizontal,
        paddingTop: value.paddingTop,
        paddingBottom: value.paddingBottom,
        before: value.before,
        after: value.after,
        extra: value.extra,
        stretch: value.stretch,
        style: value.style,
        activeOpacity: value.activeOpacity,
        debouncedPressTime: value.debouncedPressTime,
        progress: value.progress,
        showProgressBar: value.showProgressBar,
        progressLoadingTime: value.progressLoadingTime,
        animateSize: value.animateSize,
        onPressIn: value.onPressIn,
        onPressOut: value.onPressOut,
        onPressedIn: value.onPressedIn,
        onPressedOut: value.onPressedOut,
        onProgressStart: value.onProgressStart,
        onProgressEnd: value.onProgressEnd
      )
      .environment(
        \.awesomeButtonNativeControlContext,
        AwesomeButtonNativeControlContext(
          bridge: nativeBridge,
          externallyHighlighted: isHighlighted
        )
      )
      containment.update(rootView: AnyView(button))
      invalidateIntrinsicContentSize()
      updateAccessibilityState()
    }

    private func resolvedIntrinsicContentSize(constrainedWidth: CGFloat? = nil) -> CGSize {
      let value = configuration
      let theme = resolveThemeSelection(config: value.config, index: value.index, name: value.name)
      let variant = resolveButtonType(
        theme: theme, disabled: value.disabled || isEnabled == false, flat: value.flat,
        type: value.type)
      let buttonStyle = theme.buttons[variant] ?? theme.buttons[.primary] ?? ThemeButtonStyle()
      let sizeStyle =
        theme.size[value.size] ?? theme.size[.medium] ?? ThemeSizeStyle(width: 200, height: 60)
      let presentation = resolveThemedButtonPresentation(
        buttonStyle: buttonStyle,
        sizeStyle: sizeStyle,
        transparent: value.transparent,
        width: value.width,
        autoWidth: value.autoWidth,
        height: value.height,
        paddingHorizontal: value.paddingHorizontal,
        paddingTop: value.paddingTop,
        paddingBottom: value.paddingBottom,
        stretch: value.stretch,
        style: value.style
      )
      let faceHeight = awesomeButtonUIKitFaceHeight(
        configuredHeight: max(0, presentation.height),
        style: presentation.style,
        child: value.child,
        availableFaceWidth: {
          let desiredWidth =
            presentation.width.map { max(44, $0) }
            ?? max(
              44, max(presentation.height, nativeBridge.measuredAutoWidth ?? presentation.height))
          let layoutWidth = constrainedWidth ?? (bounds.width > 0 ? bounds.width : nil)
          if value.stretch {
            return layoutWidth
          }
          if let width = presentation.width {
            return layoutWidth.map { min(width, $0) } ?? width
          }
          return layoutWidth.map { min(desiredWidth, $0) } ?? desiredWidth
        }(),
        paddingHorizontal: presentation.paddingHorizontal,
        paddingTop: presentation.paddingTop,
        paddingBottom: presentation.paddingBottom,
        traitCollection: traitCollection
      )
      let totalHeight = max(44, faceHeight + max(0, presentation.style.raiseAmount ?? 0))
      if value.stretch {
        return CGSize(width: UIView.noIntrinsicMetric, height: totalHeight)
      }
      if let width = presentation.width {
        return CGSize(width: max(44, width), height: totalHeight)
      }
      return CGSize(
        width: max(
          44, max(presentation.height, nativeBridge.measuredAutoWidth ?? presentation.height)),
        height: totalHeight
      )
    }

    private func normalizeHighlightedState() {
      if configuration.disabled || isEnabled == false || configuration.child == nil
        || nativeBridge.componentIsBusy, isHighlighted
      {
        setHighlightedFromBridge(false)
      }
    }

    private func updateAccessibilityState() {
      let label = configuration.accessibilityLabel ?? configuration.child
      isAccessibilityElement = label != nil
      self.accessibilityLabel = label
      if nativeBridge.componentIsBusy {
        accessibilityValue = AwesomeButtonLocalization.busyState
      } else if configuration.child == nil, label != nil {
        accessibilityValue = AwesomeButtonLocalization.placeholderState
      } else {
        accessibilityValue = nil
      }
      let unavailable =
        isEnabled == false || configuration.disabled || configuration.child == nil
        || nativeBridge.componentIsBusy
      let hasOrdinaryActivation =
        configuration.onPress != nil || nativeBridge.hasConsumerActivationSink(physical: false)
      self.accessibilityHint =
        unavailable == false && hasOrdinaryActivation
        ? configuration.accessibilityHint
        : nil
      accessibilityTraits = unavailable ? [.button, .notEnabled] : [.button]
      if unavailable == false, configuration.onLongPress != nil {
        accessibilityCustomActions = [
          UIAccessibilityCustomAction(
            name: configuration.accessibilityLongPressLabel
              ?? AwesomeButtonLocalization.longPressAction,
            target: self,
            selector: #selector(performAccessibilityLongPress)
          )
        ]
      } else {
        accessibilityCustomActions = nil
      }
    }

    private func synchronizeHostEligibility() {
      nativeBridge.updateHostEligibility(
        isEnabled && configuration.disabled == false && configuration.child != nil
      )
    }

    private func setHighlightedFromBridge(_ highlighted: Bool) {
      guard isHighlighted != highlighted else {
        return
      }
      isApplyingInternalHighlight = true
      isHighlighted = highlighted
      isApplyingInternalHighlight = false
    }

    private func reconcileContainment() {
      guard window != nil else {
        nativeBridge.setInteractionMounted(false)
        containment.detach()
        return
      }
      if let parent = explicitParentViewController ?? discoverViewController(from: self) {
        containment.attach(to: self, parent: parent)
        nativeBridge.setInteractionMounted(true)
        rebuildRoot()
      } else {
        nativeBridge.setInteractionMounted(false)
        containment.detach()
        #if DEBUG
          debugPrint(
            "ThemedButtonControl requires attach(to:) when no UIViewController is discoverable")
        #endif
      }
    }
  }
#endif
