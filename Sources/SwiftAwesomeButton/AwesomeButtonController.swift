import SwiftUI

#if canImport(UIKit)
  import UIKit
#endif

@MainActor
internal protocol AwesomeButtonControllerCommandSink: AnyObject {
  func receive(_ command: AwesomeButtonStyleTransitionCommand)
    -> AwesomeButtonControllerCommandDisposition
  func receive(_ command: AwesomeButtonSizeTextCommand)
    -> AwesomeButtonControllerCommandDisposition
  func receive(_ command: AwesomeButtonProgressCommand)
    -> AwesomeButtonControllerCommandDisposition
  func snapshotProgressEnd(generation: Int) -> (() -> Void)?
  func receive(_ command: AwesomeButtonInteractionCommand)
    -> AwesomeButtonControllerCommandDisposition
  func snapshotRelease(generation: Int) -> AwesomeButtonReleaseSnapshot?
}

internal enum AwesomeButtonControllerCommandDisposition {
  case accepted
  case stale
  case ineligible
  case unmounted
  case directActivation
  case progressStarted
}

@MainActor
internal final class AwesomeButtonController: ObservableObject, AwesomeButtonControllerCommandSink {
  @Published private(set) var renderedConfiguration: AwesomeButtonResolvedConfiguration?
  @Published var displayedText: String?
  @Published var resolvedWidth: CGFloat?
  @Published var resolvedHeight: CGFloat = 52
  @Published var measuredContentHeight: CGFloat = 0
  @Published var isPressed = false
  @Published var pressProgress: CGFloat = 0
  @Published var isBusy = false
  @Published var showProgressVisuals = false
  @Published var contentClipAlignment: ContentClipAlignment = .center
  @Published var contentTransitionValue: CGFloat = 1
  @Published var activityTransitionValue: CGFloat = 0
  @Published var progressOverlayOpacity: CGFloat = 0
  @Published var progressValue: CGFloat = 0
  @Published var styleTransitionProgress: CGFloat = 1
  @Published private(set) var styleTransitionSourceStyle: AwesomeButtonStyle?

  private let measurementService: AutoWidthMeasurementService
  private let hapticFeedback: () -> Void
  internal static var hapticFeedbackTestOverride: (() -> Void)?
  private(set) var inputConfiguration: AwesomeButtonResolvedConfiguration?
  private(set) var isMounted = true
  private var deferredAutoWidthTransition: DeferredAutoWidthTransition?
  private lazy var styleTransitionOwner = AwesomeButtonStyleTransitionOwner(sink: self)
  private lazy var sizeTextOwner = AwesomeButtonSizeTextOwner(
    measurementService: measurementService,
    sink: self
  )
  private lazy var progressOwner = AwesomeButtonProgressOwner(sink: self)
  private lazy var interactionReleaseOwner = AwesomeButtonInteractionReleaseOwner(sink: self)

  internal var isTouchActive: Bool { interactionReleaseOwner.isTouchActive }
  internal var isTouchInside: Bool { interactionReleaseOwner.isTouchInside }
  internal var releaseGeneration: Int { interactionReleaseOwner.releaseGeneration }
  private var activeReleaseGeneration: Int? {
    interactionReleaseOwner.activeReleaseGeneration
  }
  private var terminalReleaseGeneration: Int? {
    interactionReleaseOwner.hasTerminalRelease ? interactionReleaseOwner.generation : nil
  }

  private struct DeferredAutoWidthTransition {
    let token: Int
    let configuration: AwesomeButtonResolvedConfiguration
    let previousWidthMode: ButtonWidthMode?
  }

  // MARK: - Lifecycle

  init(
    measurementService: AutoWidthMeasurementService = .shared,
    hapticFeedback: (() -> Void)? = nil
  ) {
    self.measurementService = measurementService
    self.hapticFeedback =
      hapticFeedback ?? Self.hapticFeedbackTestOverride ?? {
        #if canImport(UIKit)
          UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
      }
  }

  func cleanup() {
    inputConfiguration?.nativeControlBridge?.teardown()
    isMounted = false
    interactionReleaseOwner.cleanup()
    clearDeferredAutoWidthTransition()
    isPressed = false
    pressProgress = 0
    sizeTextOwner.cleanup()
    progressOwner.cleanup()
    isBusy = false
    showProgressVisuals = false
    contentTransitionValue = 1
    activityTransitionValue = 0
    progressOverlayOpacity = 0
    progressValue = 0
    styleTransitionOwner.cleanup()
    styleTransitionSourceStyle = nil
    styleTransitionProgress = 1
    contentClipAlignment = .center
    inputConfiguration = nil
  }

  // MARK: - Rendered Configuration / Style

  func update(configuration nextConfiguration: AwesomeButtonResolvedConfiguration) {
    isMounted = true
    styleTransitionOwner.connect(to: self)
    sizeTextOwner.connect(to: self)
    progressOwner.connect(to: self)
    interactionReleaseOwner.connect(to: self)
    refreshLiveConfiguration(nextConfiguration)
    let previousConfiguration = renderedConfiguration
    let previousWidthMode = sizeTextOwner.currentWidthMode
    if renderedConfiguration == nil {
      commitRenderedConfiguration(nextConfiguration, previousWidthMode: previousWidthMode)
      return
    }

    let nextSizeInput = AwesomeButtonSizeTextInput(configuration: nextConfiguration)
    let targetWidth = sizeTextOwner.measuredTargetWidth(for: nextSizeInput)
    let shouldDefer = shouldDeferReleaseAutoWidthTransition(
      isReleaseActive: activeReleaseGeneration != nil || terminalReleaseGeneration != nil,
      currentConfiguration: previousConfiguration,
      nextConfiguration: nextConfiguration,
      previousWidthMode: previousWidthMode,
      currentWidth: resolvedWidth,
      targetWidth: targetWidth
    )
    if let token = sizeTextOwner.beginDeferral(if: shouldDefer) {
      deferredAutoWidthTransition = DeferredAutoWidthTransition(
        token: token,
        configuration: nextConfiguration,
        previousWidthMode: previousWidthMode
      )
      return
    }

    deferredAutoWidthTransition = nil
    commitRenderedConfiguration(nextConfiguration, previousWidthMode: previousWidthMode)
  }

  func refreshLiveConfiguration(
    _ configuration: AwesomeButtonResolvedConfiguration,
    applyVisualUpdates: Bool = true
  ) {
    inputConfiguration = configuration
    configuration.nativeControlBridge?.updateAtomicHandlers(
      activation: { [weak self] in
        self?.activateAtomically(
          configuration: self?.inputConfiguration ?? configuration
        ) ?? false
      },
      longPress: { [weak self] in
        self?.activateLongPressAtomically(
          configuration: self?.inputConfiguration ?? configuration
        ) ?? false
      }
    )
    configuration.nativeControlBridge?.updateEligibility(
      configuration.isEffectivelyDisabled == false && isBusy == false,
      isBusy: isBusy
    )
    progressOwner.connect(to: self)
    progressOwner.configurationDidChange(
      AwesomeButtonProgressInput(configuration: configuration)
    )
    interactionReleaseOwner.connect(to: self)
    interactionReleaseOwner.configurationDidChange(
      AwesomeButtonInteractionInput(configuration: configuration, isBusy: isBusy),
      shouldApplyExternalHighlight: applyVisualUpdates
    )
  }

  // MARK: - Touch / Release

  func handleTouchChange(
    isInside: Bool,
    configuration: AwesomeButtonResolvedConfiguration
  ) {
    guard isMounted else { return }
    refreshLiveConfiguration(configuration)
    interactionReleaseOwner.handleTouchChange(
      isInside: isInside,
      input: AwesomeButtonInteractionInput(configuration: configuration, isBusy: isBusy)
    )
  }

  func handleTouchChange(isInside: Bool) {
    guard let inputConfiguration else { return }
    handleTouchChange(isInside: isInside, configuration: inputConfiguration)
  }

  func handleTouchEnd(
    isInside: Bool,
    configuration: AwesomeButtonResolvedConfiguration
  ) {
    guard isMounted, isTouchActive else { return }
    refreshLiveConfiguration(configuration)
    interactionReleaseOwner.handleTouchEnd(
      isInside: isInside,
      input: AwesomeButtonInteractionInput(configuration: configuration, isBusy: isBusy)
    )
  }

  func handleTouchEnd(isInside: Bool) {
    guard let inputConfiguration else { return }
    handleTouchEnd(isInside: isInside, configuration: inputConfiguration)
  }

  func handleLongPress(configuration: AwesomeButtonResolvedConfiguration) {
    guard isMounted else { return }
    refreshLiveConfiguration(configuration)
    interactionReleaseOwner.handleLongPress()
  }

  func handleLongPress() {
    guard let inputConfiguration else { return }
    handleLongPress(configuration: inputConfiguration)
  }

  @discardableResult
  func activateAtomically(configuration: AwesomeButtonResolvedConfiguration) -> Bool {
    guard isMounted else { return false }
    refreshLiveConfiguration(configuration)
    return interactionReleaseOwner.activateAtomically(
      input: AwesomeButtonInteractionInput(configuration: configuration, isBusy: isBusy)
    )
  }

  @discardableResult
  func activateLongPressAtomically(configuration: AwesomeButtonResolvedConfiguration) -> Bool {
    guard isMounted else { return false }
    refreshLiveConfiguration(configuration)
    return interactionReleaseOwner.activateLongPressAtomically(
      input: AwesomeButtonInteractionInput(configuration: configuration, isBusy: isBusy)
    )
  }

  func handleTouchSurfaceDismantle() {
    inputConfiguration?.nativeControlBridge?.teardown()
    isMounted = false
    interactionReleaseOwner.cleanup()
    clearDeferredAutoWidthTransition()
    sizeTextOwner.cleanup()
    progressOwner.cleanup()
    styleTransitionOwner.cleanup()
    inputConfiguration = nil

    DispatchQueue.main.async { [weak self] in
      guard let self, self.isMounted == false else { return }
      self.cleanup()
    }
  }

  func snapshotRelease(generation: Int) -> AwesomeButtonReleaseSnapshot? {
    guard isMounted, interactionReleaseOwner.isCurrent(generation),
      let configuration = inputConfiguration
    else { return nil }
    return AwesomeButtonReleaseSnapshot(
      style: configuration.style,
      reduceMotion: configuration.reduceMotion,
      onPressedOut: configuration.onPressedOut
    )
  }

  func receive(_ command: AwesomeButtonInteractionCommand)
    -> AwesomeButtonControllerCommandDisposition
  {
    guard isMounted else { return .unmounted }
    guard interactionReleaseOwner.isCurrent(command.generation) else { return .stale }

    switch command {
    case .touchDidBegin:
      inputConfiguration?.nativeControlBridge?.touchDidBegin()
      return .accepted

    case .touchDidEnd:
      inputConfiguration?.nativeControlBridge?.touchDidEnd()
      return .accepted

    case .dispatchPressIn:
      guard let live = inputConfiguration, live.isEffectivelyDisabled == false, isBusy == false
      else { return .ineligible }
      live.onPressIn?()
      return validateInteractionBoundary(generation: command.generation)

    case .commitPressed(_, let haptic):
      isPressed = true
      if haptic {
        hapticFeedback()
      }
      return validateInteractionBoundary(generation: command.generation)

    case .dispatchPressedIn:
      guard let live = inputConfiguration, live.isEffectivelyDisabled == false, isBusy == false
      else { return .ineligible }
      live.onPressedIn?()
      return validateInteractionBoundary(generation: command.generation)

    case .dispatchPressOut:
      inputConfiguration?.onPressOut?()
      guard isMounted, interactionReleaseOwner.isCurrent(command.generation) else {
        return isMounted ? .stale : .unmounted
      }
      return .accepted

    case .dispatchLongPress:
      guard let live = inputConfiguration, live.isEffectivelyDisabled == false, isBusy == false,
        let handler = live.onLongPress
      else { return .ineligible }
      handler()
      return validateInteractionBoundary(generation: command.generation)

    case .validateActivation:
      guard let live = inputConfiguration, live.isEffectivelyDisabled == false, isBusy == false,
        live.hasActivationSink
      else { return .ineligible }
      return .accepted

    case .routeActivation(_, let physicalLifecycle):
      guard let live = inputConfiguration, live.isEffectivelyDisabled == false, isBusy == false,
        live.hasActivationSink
      else { return .ineligible }
      if live.progress {
        startProgress(configuration: live, physicalLifecycle: physicalLifecycle)
        return .progressStarted
      }

      live.onPress?(nil)
      guard isMounted, interactionReleaseOwner.isCurrent(command.generation) else {
        return isMounted ? .stale : .unmounted
      }
      if let bridge = live.nativeControlBridge {
        switch bridge.dispatchAcceptedActivation(physical: physicalLifecycle) {
        case .dispatched:
          break
        case .mountedIneligible:
          bridge.cancelPhysicalTracking()
          return .ineligible
        case .unmounted:
          cleanup()
          return .unmounted
        }
      }
      return .directActivation

    case .cancelPhysicalTracking:
      inputConfiguration?.nativeControlBridge?.cancelPhysicalTracking()
      return .accepted

    case .clearDeferredSize:
      clearDeferredAutoWidthTransition()
      return .accepted

    case .setPressPresentation(_, let pressed, let progress, let transition):
      isPressed = pressed
      switch transition {
      case .immediate:
        pressProgress = progress
      case .timed(let timing):
        withAnimation(timing.curve.animation(duration: timing.duration)) {
          pressProgress = progress
        }
      case .releaseSpring:
        withAnimation(
          .interpolatingSpring(
            stiffness: awesomeButtonReleaseSpringStiffness,
            damping: awesomeButtonReleaseSpringDamping
          )
        ) {
          pressProgress = progress
        }
      }
      return .accepted

    case .releaseCompleted(_, let releaseGeneration, let snapshot, let completion):
      guard interactionReleaseOwner.releaseGeneration == releaseGeneration else {
        return .stale
      }
      snapshot.onPressedOut?()
      guard isMounted, interactionReleaseOwner.isCurrent(command.generation) else {
        return isMounted ? .stale : .unmounted
      }
      completion?()
      guard isMounted, interactionReleaseOwner.isCurrent(command.generation) else {
        return isMounted ? .stale : .unmounted
      }
      drainDeferredAutoWidthTransitionIfNeeded()
      return .accepted

    case .settleProgressReducedMotion:
      progressOwner.settleForReducedMotion()
      return .accepted
    }
  }

  private func validateInteractionBoundary(
    generation: Int
  ) -> AwesomeButtonControllerCommandDisposition {
    guard isMounted, interactionReleaseOwner.isCurrent(generation) else {
      return isMounted ? .stale : .unmounted
    }
    guard let live = inputConfiguration, live.isEffectivelyDisabled == false, isBusy == false else {
      return .ineligible
    }
    return .accepted
  }

  // MARK: - Progress

  private func startProgress(
    configuration: AwesomeButtonResolvedConfiguration,
    physicalLifecycle: Bool
  ) {
    clearDeferredAutoWidthTransition()
    interactionReleaseOwner.progressDidStart()
    progressOwner.start(
      input: AwesomeButtonProgressInput(configuration: configuration),
      physicalLifecycle: physicalLifecycle
    )
  }

  func snapshotProgressEnd(generation: Int) -> (() -> Void)? {
    guard isMounted, progressOwner.isCurrent(generation) else { return nil }
    return inputConfiguration?.onProgressEnd
  }

  func receive(_ command: AwesomeButtonProgressCommand)
    -> AwesomeButtonControllerCommandDisposition
  {
    guard isMounted else { return .unmounted }
    guard progressOwner.isCurrent(command.generation) else { return .stale }

    switch command {
    case .setPresentation(_, let value):
      isBusy = value.isBusy
      showProgressVisuals = value.showProgressVisuals
      contentTransitionValue = value.contentTransitionValue
      activityTransitionValue = value.activityTransitionValue
      progressOverlayOpacity = value.progressOverlayOpacity
      progressValue = value.progressValue
      if let isPressed = value.isPressed {
        self.isPressed = isPressed
      }
      if let pressProgress = value.pressProgress {
        self.pressProgress = pressProgress
      }
      inputConfiguration?.nativeControlBridge?.updateEligibility(
        inputConfiguration?.isEffectivelyDisabled == false && value.isBusy == false,
        isBusy: value.isBusy
      )
      if let configuration = inputConfiguration {
        interactionReleaseOwner.configurationDidChange(
          AwesomeButtonInteractionInput(configuration: configuration, isBusy: value.isBusy)
        )
      }
      return .accepted

    case .dispatchProgressStart:
      guard let live = inputConfiguration, live.isEffectivelyDisabled == false else {
        return .ineligible
      }
      live.onProgressStart?()
      guard isMounted, progressOwner.isCurrent(command.generation), progressOwner.isBusy,
        let current = inputConfiguration, current.isEffectivelyDisabled == false
      else {
        return isMounted ? .ineligible : .unmounted
      }
      return .accepted

    case .dispatchActivation(_, let handle, let physicalLifecycle):
      guard let live = inputConfiguration,
        live.isEffectivelyDisabled == false,
        live.hasActivationSink
      else {
        inputConfiguration?.nativeControlBridge?.cancelPhysicalTracking()
        return .ineligible
      }

      live.nativeControlBridge?.prepareProgressHandle(handle)
      live.onPress?(handle)
      guard isMounted, progressOwner.isCurrent(command.generation), progressOwner.isBusy else {
        return isMounted ? .stale : .unmounted
      }
      if let bridge = live.nativeControlBridge {
        switch bridge.dispatchAcceptedActivation(physical: physicalLifecycle) {
        case .dispatched:
          return .accepted
        case .mountedIneligible:
          bridge.cancelPhysicalTracking()
          return .ineligible
        case .unmounted:
          cleanup()
          return .unmounted
        }
      }
      return .accepted

    case .requestRelease(_, let physicalLifecycle):
      guard let snapshot = snapshotRelease(generation: interactionReleaseOwner.generation) else {
        return .ineligible
      }
      let generation = command.generation
      if physicalLifecycle {
        interactionReleaseOwner.startRelease(
          snapshot: snapshot,
          completion: { [weak self] in
            self?.progressOwner.releaseDidFinish(generation: generation)
          }
        )
      } else {
        isPressed = false
        pressProgress = 0
        progressOwner.releaseDidFinish(generation: generation)
      }
      return .accepted

    case .finishCompletion(_, let snapshot):
      inputConfiguration?.nativeControlBridge?.updateEligibility(
        inputConfiguration?.isEffectivelyDisabled == false
      )
      snapshot.completion?()
      guard isMounted, progressOwner.isCurrent(command.generation) else {
        return isMounted ? .stale : .unmounted
      }
      snapshot.onProgressEnd?()
      guard isMounted, progressOwner.isCurrent(command.generation) else {
        return isMounted ? .stale : .unmounted
      }
      inputConfiguration?.nativeControlBridge?.progressDidEnd()
      return .accepted

    case .finishRollback(_, let onProgressEnd):
      inputConfiguration?.nativeControlBridge?.updateEligibility(
        inputConfiguration?.isEffectivelyDisabled == false
      )
      onProgressEnd?()
      guard isMounted, progressOwner.isCurrent(command.generation) else {
        return isMounted ? .stale : .unmounted
      }
      inputConfiguration?.nativeControlBridge?.progressDidEnd()
      return .accepted

    }
  }

  // MARK: - Rendered Configuration / Style

  private func commitRenderedConfiguration(
    _ configuration: AwesomeButtonResolvedConfiguration,
    previousWidthMode: ButtonWidthMode?
  ) {
    if let previousConfiguration = renderedConfiguration,
      shouldAnimateStyleTransition(from: previousConfiguration, to: configuration)
    {
      styleTransitionOwner.start(
        from: currentVisualStyle(from: previousConfiguration),
        to: configuration.style
      )
    } else {
      styleTransitionOwner.reset()
    }

    renderedConfiguration = configuration

    if displayedText == nil {
      displayedText = configuration.childText
    }

    sizeTextOwner.update(
      input: AwesomeButtonSizeTextInput(configuration: configuration),
      previousWidthMode: previousWidthMode,
      presentation: AwesomeButtonSizeTextPresentation(
        displayedText: displayedText,
        resolvedWidth: resolvedWidth,
        resolvedHeight: resolvedHeight
      )
    )
  }

  private func currentVisualStyle(from configuration: AwesomeButtonResolvedConfiguration)
    -> AwesomeButtonStyle
  {
    guard let sourceStyle = styleTransitionSourceStyle, styleTransitionProgress < 1 else {
      return resolvedVisualStyle(configuration.style)
    }

    return interpolateAwesomeButtonStyle(
      sourceStyle,
      configuration.style,
      progress: styleTransitionProgress
    )
  }

  private func shouldAnimateStyleTransition(
    from currentConfiguration: AwesomeButtonResolvedConfiguration,
    to nextConfiguration: AwesomeButtonResolvedConfiguration
  ) -> Bool {
    shouldAnimateResolvedStyleTransition(
      from: currentConfiguration,
      to: nextConfiguration
    )
  }

  func receive(_ command: AwesomeButtonStyleTransitionCommand)
    -> AwesomeButtonControllerCommandDisposition
  {
    guard isMounted else { return .unmounted }
    guard styleTransitionOwner.isCurrent(command.generation) else { return .stale }

    switch command {
    case .prepare(_, let sourceStyle):
      styleTransitionSourceStyle = sourceStyle
      styleTransitionProgress = 0
    case .animate(_, let timing):
      withAnimation(timing.curve.animation(duration: timing.duration)) {
        styleTransitionProgress = 1
      }
    case .reset:
      styleTransitionSourceStyle = nil
      styleTransitionProgress = 1
    }
    return .accepted
  }

  func updateMeasuredAutoWidth(
    _ measuredWidth: CGFloat,
    configuration: AwesomeButtonResolvedConfiguration
  ) {
    refreshLiveConfiguration(configuration)
    sizeTextOwner.updateMeasuredAutoWidth(
      measuredWidth,
      input: AwesomeButtonSizeTextInput(configuration: configuration),
      currentWidth: resolvedWidth
    )
  }

  func updateMeasuredContentHeight(
    _ measuredHeight: CGFloat,
    configuration: AwesomeButtonResolvedConfiguration
  ) {
    refreshLiveConfiguration(configuration)
    sizeTextOwner.updateMeasuredContentHeight(
      measuredHeight,
      input: AwesomeButtonSizeTextInput(configuration: configuration),
      currentHeight: measuredContentHeight
    )
  }

  func receive(_ command: AwesomeButtonSizeTextCommand)
    -> AwesomeButtonControllerCommandDisposition
  {
    guard isMounted else { return .unmounted }
    guard sizeTextOwner.isCurrent(command.generation) else { return .stale }

    switch command {
    case .setDisplayedText(_, let value):
      displayedText = value
    case .setWidth(_, let value, let transition):
      apply(transition: transition) {
        self.resolvedWidth = value
      }
    case .setHeight(_, let value, let transition):
      apply(transition: transition) {
        self.resolvedHeight = value
      }
    case .setMeasuredContentHeight(_, let value, let transition):
      apply(transition: transition) {
        self.measuredContentHeight = value
      }
    case .setClipAlignment(_, let value):
      contentClipAlignment = value
    case .reportMeasuredAutoWidth(_, let value):
      inputConfiguration?.nativeControlBridge?.measuredWidthDidChange(value)
    }
    return .accepted
  }

  private func apply(
    transition: AwesomeButtonSizeTransition,
    update: () -> Void
  ) {
    switch transition {
    case .immediate:
      update()
    case .animated(let duration):
      withAnimation(sizeAnimation(duration: duration)) {
        update()
      }
    }
  }

  // MARK: - Release Deferral

  func completeReleaseIfNeeded(observedPressProgress: CGFloat, expectedGeneration: Int? = nil) {
    interactionReleaseOwner.completeReleaseIfNeeded(
      observedPressProgress: observedPressProgress,
      expectedGeneration: expectedGeneration
    )
  }

  private func clearDeferredAutoWidthTransition() {
    deferredAutoWidthTransition = nil
    sizeTextOwner.clearDeferral()
  }

  private func drainDeferredAutoWidthTransitionIfNeeded() {
    guard let token = sizeTextOwner.consumeDeferralToken(),
      let deferredAutoWidthTransition,
      deferredAutoWidthTransition.token == token
    else {
      return
    }

    self.deferredAutoWidthTransition = nil
    commitRenderedConfiguration(
      deferredAutoWidthTransition.configuration,
      previousWidthMode: deferredAutoWidthTransition.previousWidthMode
    )
  }
}
