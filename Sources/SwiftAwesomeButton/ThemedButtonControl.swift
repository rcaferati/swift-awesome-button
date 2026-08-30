#if canImport(UIKit)
  import SwiftUI
  import UIKit

  /// A programmatic UIKit control that hosts ``ThemedButton`` with the same native control,
  /// mutable-configuration, sizing, and containment guarantees as ``AwesomeButtonControl``.
  public final class ThemedButtonControl: UIControl, UIKitButtonHostOwnerAdapter {
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
      /// The requested semantic or social variant; `.flat` remains visually flat while disabled.
      public var type: ButtonVariant
      /// The requested named size.
      public var size: ButtonSize
      /// Requests flat visual styling, including while disabled.
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
        rebuildRoot()
      }
    }

    private lazy var hostCoordinator = UIKitButtonHostCoordinator(adapter: self)

    internal var nativeBridge: AwesomeButtonNativeControlBridge { hostCoordinator.nativeBridge }
    internal var hostedViewController: UIViewController { hostCoordinator.hostingController }
    internal var attachedParentViewController: UIViewController? {
      hostCoordinator.parentViewController
    }

    /// Controls native and hosted interaction eligibility together.
    public override var isEnabled: Bool {
      didSet {
        rebuildRoot()
      }
    }

    /// Mirrors external UIKit highlighting into the hosted press presentation.
    public override var isHighlighted: Bool {
      didSet {
        hostCoordinator.externalHighlightDidChange()
      }
    }

    /// Creates a programmatic themed UIKit control from a value configuration.
    public init(configuration: Configuration) {
      self.configuration = configuration
      super.init(frame: .zero)
      rebuildRoot()
    }

    deinit {
      MainActor.assumeIsolated {
        hostCoordinator.teardown()
      }
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
      hostCoordinator.attach(to: parentViewController)
      rebuildRoot()
    }

    /// Detaches the hosting controller and silently cancels component-owned work.
    public func detachFromParentViewController() {
      hostCoordinator.detachFromParentViewController()
    }

    /// Completes the current one-shot progress run for target-action consumers.
    public func completeProgress(_ completion: (() -> Void)? = nil) {
      hostCoordinator.completeProgress(completion)
    }

    /// The resolved package intrinsic size, including depth and the 44-point minimum target.
    public override var intrinsicContentSize: CGSize {
      hostCoordinator.intrinsicContentSize
    }

    /// Returns resolved themed geometry within a proposed UIKit size.
    public override func sizeThatFits(_ size: CGSize) -> CGSize {
      hostCoordinator.sizeThatFits(size)
    }

    /// Invalidates intrinsic height when the effective layout width changes.
    public override func layoutSubviews() {
      super.layoutSubviews()
      hostCoordinator.layoutDidChange()
    }

    /// Reconciles hosting-controller containment when window ownership changes.
    public override func didMoveToWindow() {
      super.didMoveToWindow()
      hostCoordinator.didMoveToWindow()
    }

    /// Reconciles hosting-controller containment when the view hierarchy changes.
    public override func didMoveToSuperview() {
      super.didMoveToSuperview()
      hostCoordinator.didMoveToSuperview()
    }

    /// Rebuilds Dynamic Type-dependent content when the relevant trait changes.
    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
      super.traitCollectionDidChange(previousTraitCollection)
      hostCoordinator.traitCollectionDidChange(previousTraitCollection)
    }

    /// Performs one atomic native accessibility activation.
    public override func accessibilityActivate() -> Bool {
      hostCoordinator.performAccessibilityActivation()
    }

    /// Refreshes dynamic accessibility state before announcing focus.
    public override func accessibilityElementDidBecomeFocused() {
      hostCoordinator.refreshAccessibilityForFocus()
      super.accessibilityElementDidBecomeFocused()
    }

    internal func handleKeyboardActivationBegan() {
      hostCoordinator.handleKeyboardActivationBegan()
    }

    @discardableResult
    internal func handleKeyboardActivationEnded(cancelled: Bool = false) -> Bool {
      hostCoordinator.handleKeyboardActivationEnded(cancelled: cancelled)
    }

    /// Arms Space or Return keyboard activation and its highlighted presentation.
    public override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
      if hostCoordinator.pressesBegan(presses, event: event) == false {
        super.pressesBegan(presses, with: event)
      }
    }

    /// Commits an armed Space or Return keyboard activation.
    public override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
      if hostCoordinator.pressesEnded(presses, event: event) == false {
        super.pressesEnded(presses, with: event)
      }
    }

    /// Cancels an armed keyboard activation without dispatching it.
    public override func pressesCancelled(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
      hostCoordinator.pressesCancelled(presses, event: event)
      super.pressesCancelled(presses, with: event)
    }

    private func rebuildRoot() {
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
      hostCoordinator.update(
        rootView: AnyView(button),
        state: UIKitButtonHostState(
          isEnabled: isEnabled,
          isConfigurationDisabled: value.disabled,
          hasContent: value.child != nil,
          stretches: value.stretch,
          accessibilityLabel: value.accessibilityLabel ?? value.child,
          accessibilityHint: value.accessibilityHint,
          accessibilityLongPressLabel: value.accessibilityLongPressLabel,
          hasOrdinaryActivation: value.onPress != nil,
          hasLongPress: value.onLongPress != nil
        )
      )
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

    internal var hostControl: UIControl { self }

    internal func hostSetHighlighted(_ highlighted: Bool) {
      isHighlighted = highlighted
    }

    internal func hostSystemAdaptationDidChange() {
      rebuildRoot()
    }

    internal func hostIntrinsicContentSize(constrainedWidth: CGFloat?) -> CGSize {
      resolvedIntrinsicContentSize(constrainedWidth: constrainedWidth)
    }
  }
#endif
