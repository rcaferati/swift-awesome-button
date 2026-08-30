import SwiftUI

#if canImport(UIKit)
  import UIKit
#endif

@MainActor
internal final class AwesomeButtonController: ObservableObject {
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
  private var currentWidthMode: ButtonWidthMode?
  private var lastAcceptedPressAt: Date?
  private(set) var isTouchActive = false
  private(set) var isTouchInside = false
  private(set) var isMounted = true
  private var currentTextTarget: String?
  private var completionConsumed = false
  private var delayedWidthWorkItem: DispatchWorkItem?
  private var delayedTextWorkItem: DispatchWorkItem?
  private var delayedClipAlignmentResetWorkItem: DispatchWorkItem?
  private var deferredProgressPressWorkItem: DispatchWorkItem?
  private var progressCompletionWorkItem: DispatchWorkItem?
  private var reducedMotionSettlementWorkItem: DispatchWorkItem?
  private var progressEligibilityRevalidationWorkItem: DispatchWorkItem?
  private var terminalContinuationWorkItem: DispatchWorkItem?
  private var terminalReleaseGeneration: Int?
  private(set) var releaseGeneration = 0
  private var activeReleaseGeneration: Int?
  private var releaseSettleWorkItem: DispatchWorkItem?
  private var pendingReleaseConfiguration: AwesomeButtonResolvedConfiguration?
  private var pendingReleaseCompletion: (() -> Void)?
  private var deferredAutoWidthTransition: DeferredAutoWidthTransition?
  private var progressContentAnimation: ProgressAnimationControlling?
  private var progressActivityAnimation: ProgressAnimationControlling?
  private var progressOverlayAnimation: ProgressAnimationControlling?
  private var progressValueAnimation: ProgressAnimationControlling?
  private var textTransitionController: TextTransitionControlling?
  private var styleTransitionKickoffWorkItem: DispatchWorkItem?
  private var styleTransitionID = 0
  private var sizeRunID = 0
  private var progressRunID = 0
  private var progressHasPhysicalLifecycle = true
  private var pendingProgressCompletionSnapshot: ProgressCompletionSnapshot?
  private var terminalGeneration = 0
  private var externalHighlightApplied = false

  private struct DeferredAutoWidthTransition {
    let configuration: AwesomeButtonResolvedConfiguration
    let previousWidthMode: ButtonWidthMode?
  }

  private struct ProgressCompletionSnapshot {
    let completion: (() -> Void)?
    let onProgressEnd: (() -> Void)?
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
    terminalGeneration += 1
    terminalContinuationWorkItem?.cancel()
    terminalContinuationWorkItem = nil
    terminalReleaseGeneration = nil
    cancelReleaseTracking()
    clearDeferredAutoWidthTransition()
    isPressed = false
    pressProgress = 0
    delayedWidthWorkItem?.cancel()
    delayedTextWorkItem?.cancel()
    delayedClipAlignmentResetWorkItem?.cancel()
    cancelProgressWork(resetState: true)
    reducedMotionSettlementWorkItem?.cancel()
    reducedMotionSettlementWorkItem = nil
    textTransitionController?.stop()
    resetStyleTransition()
    isTouchActive = false
    isTouchInside = false
    contentClipAlignment = .center
    externalHighlightApplied = false
    inputConfiguration = nil
  }

  // MARK: - Rendered Configuration / Style

  func update(configuration nextConfiguration: AwesomeButtonResolvedConfiguration) {
    isMounted = true
    refreshLiveConfiguration(nextConfiguration)
    let previousConfiguration = renderedConfiguration
    let previousWidthMode = currentWidthMode
    if renderedConfiguration == nil {
      commitRenderedConfiguration(nextConfiguration, previousWidthMode: previousWidthMode)
      return
    }

    if shouldDeferAutoWidthTextTransitionUpdate(
      from: previousConfiguration,
      to: nextConfiguration,
      previousWidthMode: previousWidthMode
    ) {
      deferredAutoWidthTransition = DeferredAutoWidthTransition(
        configuration: nextConfiguration,
        previousWidthMode: previousWidthMode
      )
      return
    }

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
    scheduleProgressRollbackIfNeeded(configuration: configuration)
    if applyVisualUpdates {
      applyExternalHighlight(configuration: configuration)
    }
    scheduleReducedMotionSettlementIfNeeded(configuration: configuration)
  }

  // MARK: - Touch / Release

  func handleTouchChange(
    isInside: Bool,
    configuration: AwesomeButtonResolvedConfiguration
  ) {
    guard isMounted else {
      return
    }
    refreshLiveConfiguration(configuration)
    guard configuration.isEffectivelyDisabled == false,
      isBusy == false
    else {
      return
    }

    if isInside == false {
      handleTouchEnd(isInside: false, configuration: configuration)
      return
    }

    let isInterruptingRelease =
      terminalReleaseGeneration != nil || activeReleaseGeneration != nil
    if isTouchActive == false, terminalReleaseGeneration != nil {
      terminalGeneration += 1
      terminalContinuationWorkItem?.cancel()
      terminalContinuationWorkItem = nil
      terminalReleaseGeneration = nil
      cancelReleaseTracking()
      // The prior gesture already dispatched `onPressOut`, but its deferred terminal work
      // has not committed an activation or release. Start this native touch as a fresh
      // logical press while preserving the current visual depth.
      isPressed = false
    }

    isTouchActive = true
    isTouchInside = true
    configuration.nativeControlBridge?.touchDidBegin()
    armPressIfNeeded(
      configuration: configuration,
      preserveDeferredAutoWidthTransition: isInterruptingRelease
    )
  }

  func handleTouchChange(isInside: Bool) {
    guard let inputConfiguration else {
      return
    }
    handleTouchChange(isInside: isInside, configuration: inputConfiguration)
  }

  func handleTouchEnd(
    isInside: Bool,
    configuration: AwesomeButtonResolvedConfiguration
  ) {
    guard isMounted, isTouchActive else {
      return
    }
    refreshLiveConfiguration(configuration)

    // Native ownership is cleared before any eligibility guard or consumer callback. A
    // disabled/busy update must not strand controller bookkeeping or poison re-enablement.
    isTouchActive = false
    isTouchInside = false
    configuration.nativeControlBridge?.touchDidEnd()

    terminalGeneration += 1
    let generation = terminalGeneration
    let releaseSnapshot = configuration
    terminalReleaseGeneration = generation
    let shouldNotifyPressOut = isPressed || pressProgress > 0.001

    if shouldNotifyPressOut {
      configuration.onPressOut?()
    }

    enqueueTerminalContinuation(generation: generation) { [weak self] in
      guard let self, self.isMounted else {
        return
      }

      let liveConfiguration = self.inputConfiguration ?? configuration
      guard isInside,
        self.isBusy == false,
        liveConfiguration.isEffectivelyDisabled == false,
        self.isPressed
      else {
        liveConfiguration.nativeControlBridge?.cancelPhysicalTracking()
        self.releaseVisual(configuration: releaseSnapshot, notifyPressOut: false)
        return
      }

      guard self.shouldAcceptDebouncedPress(configuration: liveConfiguration) else {
        liveConfiguration.nativeControlBridge?.cancelPhysicalTracking()
        self.releaseVisual(configuration: releaseSnapshot, notifyPressOut: false)
        return
      }

      self.lastAcceptedPressAt = Date()
      if liveConfiguration.progress {
        guard liveConfiguration.hasActivationSink else {
          liveConfiguration.nativeControlBridge?.cancelPhysicalTracking()
          self.releaseVisual(configuration: releaseSnapshot, notifyPressOut: false)
          return
        }
        self.startProgress(configuration: liveConfiguration, physicalLifecycle: true)
        return
      }

      guard liveConfiguration.hasActivationSink else {
        liveConfiguration.nativeControlBridge?.cancelPhysicalTracking()
        self.releaseVisual(configuration: releaseSnapshot, notifyPressOut: false)
        return
      }

      liveConfiguration.onPress?(nil)
      guard self.isMounted, self.terminalGeneration == generation else {
        return
      }
      if let bridge = liveConfiguration.nativeControlBridge {
        switch bridge.dispatchAcceptedActivation(physical: true) {
        case .dispatched:
          break
        case .mountedIneligible:
          bridge.cancelPhysicalTracking()
          self.releaseVisual(configuration: releaseSnapshot, notifyPressOut: false)
          return
        case .unmounted:
          self.cleanup()
          return
        }
      }
      self.enqueueTerminalContinuation(generation: generation) { [weak self] in
        guard let self, self.isMounted else {
          return
        }
        self.releaseVisual(configuration: releaseSnapshot, notifyPressOut: false)
      }
    }
  }

  func handleTouchEnd(isInside: Bool) {
    guard let inputConfiguration else {
      return
    }
    handleTouchEnd(isInside: isInside, configuration: inputConfiguration)
  }

  func handleLongPress(configuration: AwesomeButtonResolvedConfiguration) {
    guard isMounted else {
      return
    }
    refreshLiveConfiguration(configuration)
    guard isTouchActive,
      configuration.isEffectivelyDisabled == false,
      isBusy == false
    else {
      return
    }

    configuration.onLongPress?()
  }

  func handleLongPress() {
    guard let inputConfiguration else {
      return
    }
    handleLongPress(configuration: inputConfiguration)
  }

  @discardableResult
  func activateAtomically(configuration: AwesomeButtonResolvedConfiguration) -> Bool {
    guard isMounted else { return false }
    refreshLiveConfiguration(configuration)
    let live = inputConfiguration ?? configuration
    guard live.isEffectivelyDisabled == false,
      isBusy == false,
      live.hasAtomicActivationSink,
      shouldAcceptDebouncedPress(configuration: live)
    else { return false }

    lastAcceptedPressAt = Date()
    if live.progress {
      startProgress(configuration: live, physicalLifecycle: false)
      return true
    }

    live.onPress?(nil)
    guard isMounted else { return true }
    if let bridge = live.nativeControlBridge {
      switch bridge.dispatchAcceptedActivation(physical: false) {
      case .dispatched: return true
      case .mountedIneligible, .unmounted: return false
      }
    }
    return true
  }

  @discardableResult
  func activateLongPressAtomically(configuration: AwesomeButtonResolvedConfiguration) -> Bool {
    guard isMounted else { return false }
    refreshLiveConfiguration(configuration)
    let live = inputConfiguration ?? configuration
    guard live.isEffectivelyDisabled == false,
      isBusy == false,
      let handler = live.onLongPress
    else { return false }
    handler()
    return isMounted
  }

  func handleTouchSurfaceDismantle() {
    // UIViewRepresentable dismantling occurs inside SwiftUI's graph update. Invalidate every
    // callback/timer owner synchronously, but defer @Published visual resets until that graph
    // transaction has unwound.
    inputConfiguration?.nativeControlBridge?.teardown()
    isMounted = false
    terminalGeneration += 1
    terminalContinuationWorkItem?.cancel()
    terminalContinuationWorkItem = nil
    terminalReleaseGeneration = nil
    cancelReleaseTracking()
    clearDeferredAutoWidthTransition()
    delayedWidthWorkItem?.cancel()
    delayedTextWorkItem?.cancel()
    delayedClipAlignmentResetWorkItem?.cancel()
    progressRunID += 1
    deferredProgressPressWorkItem?.cancel()
    deferredProgressPressWorkItem = nil
    progressCompletionWorkItem?.cancel()
    progressCompletionWorkItem = nil
    progressEligibilityRevalidationWorkItem?.cancel()
    progressEligibilityRevalidationWorkItem = nil
    stopProgressAnimations()
    textTransitionController?.stop()
    styleTransitionKickoffWorkItem?.cancel()
    isTouchActive = false
    isTouchInside = false
    inputConfiguration = nil

    DispatchQueue.main.async { [weak self] in
      guard let self, self.isMounted == false else {
        return
      }
      self.cleanup()
    }
  }

  private func shouldAcceptDebouncedPress(configuration: AwesomeButtonResolvedConfiguration) -> Bool
  {
    guard configuration.debouncedPressTime > 0, let lastAcceptedPressAt else {
      return true
    }

    return Date().timeIntervalSince(lastAcceptedPressAt) >= configuration.debouncedPressTime
  }

  private func armPressIfNeeded(
    configuration: AwesomeButtonResolvedConfiguration,
    preserveDeferredAutoWidthTransition: Bool = false
  ) {
    guard isPressed == false else {
      return
    }

    cancelReleaseTracking()
    if preserveDeferredAutoWidthTransition == false {
      clearDeferredAutoWidthTransition()
    }

    configuration.onPressIn?()
    guard isMounted,
      isTouchActive,
      isTouchInside,
      isPressed == false,
      isBusy == false
    else {
      cancelGestureAfterCallbackRevalidation(configuration: inputConfiguration ?? configuration)
      return
    }
    var liveConfiguration = inputConfiguration ?? configuration
    guard liveConfiguration.isEffectivelyDisabled == false else {
      cancelGestureAfterCallbackRevalidation(configuration: liveConfiguration)
      return
    }

    isPressed = true
    if liveConfiguration.hapticOnPress {
      hapticFeedback()
    }
    guard isMounted, isTouchActive, isTouchInside, isPressed else {
      cancelGestureAfterCallbackRevalidation(configuration: inputConfiguration ?? liveConfiguration)
      return
    }
    liveConfiguration = inputConfiguration ?? liveConfiguration
    guard liveConfiguration.isEffectivelyDisabled == false,
      isBusy == false
    else {
      cancelGestureAfterCallbackRevalidation(configuration: liveConfiguration)
      return
    }
    liveConfiguration.onPressedIn?()

    guard isMounted, isTouchActive, isTouchInside, isPressed else {
      cancelGestureAfterCallbackRevalidation(configuration: inputConfiguration ?? liveConfiguration)
      return
    }
    liveConfiguration = inputConfiguration ?? liveConfiguration
    guard liveConfiguration.isEffectivelyDisabled == false,
      isBusy == false
    else {
      cancelGestureAfterCallbackRevalidation(configuration: liveConfiguration)
      return
    }
    let pressTiming = resolvedPressInAnimationTiming(style: liveConfiguration.style)
    if liveConfiguration.reduceMotion {
      pressProgress = 1
    } else {
      withAnimation(pressTiming.curve.animation(duration: pressTiming.duration)) {
        pressProgress = 1
      }
    }
  }

  private func cancelGestureAfterCallbackRevalidation(
    configuration: AwesomeButtonResolvedConfiguration
  ) {
    guard isMounted, isTouchActive else { return }
    handleTouchEnd(isInside: false, configuration: configuration)
  }

  private func applyExternalHighlight(configuration: AwesomeButtonResolvedConfiguration) {
    guard isTouchActive == false, isBusy == false else {
      return
    }

    let shouldHighlight =
      configuration.externallyHighlighted && configuration.isEffectivelyDisabled == false
    guard shouldHighlight != externalHighlightApplied else {
      return
    }
    externalHighlightApplied = shouldHighlight
    isPressed = shouldHighlight
    if shouldHighlight {
      let timing = resolvedPressInAnimationTiming(style: configuration.style)
      if configuration.reduceMotion {
        pressProgress = 1
      } else {
        withAnimation(timing.curve.animation(duration: timing.duration)) {
          pressProgress = 1
        }
      }
    } else {
      if configuration.reduceMotion {
        pressProgress = 0
      } else {
        withAnimation(
          .interpolatingSpring(
            stiffness: awesomeButtonReleaseSpringStiffness,
            damping: awesomeButtonReleaseSpringDamping
          )
        ) {
          pressProgress = 0
        }
      }
    }
  }

  private func enqueueTerminalContinuation(
    generation: Int,
    action: @escaping () -> Void
  ) {
    let workItem = DispatchWorkItem { [weak self] in
      guard let self,
        self.isMounted,
        self.terminalGeneration == generation
      else {
        return
      }

      action()
    }
    terminalContinuationWorkItem = workItem
    DispatchQueue.main.async(execute: workItem)
  }

  private func releaseVisual(
    configuration: AwesomeButtonResolvedConfiguration,
    notifyPressOut: Bool,
    onComplete: (() -> Void)? = nil
  ) {
    terminalReleaseGeneration = nil
    guard isPressed || pressProgress > 0.001 || activeReleaseGeneration != nil else {
      if notifyPressOut {
        configuration.onPressOut?()
      }
      onComplete?()
      return
    }

    if notifyPressOut {
      configuration.onPressOut?()
    }

    let releaseNeedsVisualSettle = pressProgress > 0.001
    isPressed = false
    cancelReleaseTracking()
    if configuration.reduceMotion {
      pressProgress = 0
      configuration.onPressedOut?()
      guard isMounted else { return }
      onComplete?()
      guard isMounted else { return }
      drainDeferredAutoWidthTransitionIfNeeded()
      return
    }
    releaseGeneration += 1
    activeReleaseGeneration = releaseGeneration
    pendingReleaseConfiguration = configuration
    pendingReleaseCompletion = onComplete
    withAnimation(
      .interpolatingSpring(
        stiffness: awesomeButtonReleaseSpringStiffness,
        damping: awesomeButtonReleaseSpringDamping
      )
    ) {
      pressProgress = 0
    }

    if releaseNeedsVisualSettle {
      scheduleReleaseCompletion(for: releaseGeneration)
    } else {
      completeReleaseIfNeeded(observedPressProgress: 0, expectedGeneration: releaseGeneration)
    }
  }

  // MARK: - Progress

  private func startProgress(
    configuration: AwesomeButtonResolvedConfiguration,
    physicalLifecycle: Bool
  ) {
    terminalReleaseGeneration = nil
    cancelProgressWork(resetState: false)
    progressRunID += 1
    let runID = progressRunID
    completionConsumed = false
    isBusy = true
    progressHasPhysicalLifecycle = physicalLifecycle
    configuration.nativeControlBridge?.updateEligibility(false, isBusy: true)
    cancelReleaseTracking()
    clearDeferredAutoWidthTransition()
    isPressed = physicalLifecycle
    pressProgress = physicalLifecycle ? 1 : 0
    showProgressVisuals = true
    resetProgressVisualState(unmount: false)
    progressOverlayOpacity = 1
    configuration.onProgressStart?()
    guard isMounted, progressRunID == runID, isBusy else {
      return
    }

    animateProgressSwapIn(runID: runID)
    startProgressFill(duration: configuration.progressLoadingTime, runID: runID)

    let workItem = DispatchWorkItem { [weak self] in
      guard let self,
        self.isMounted,
        self.progressRunID == runID,
        self.isBusy
      else {
        return
      }

      let liveConfiguration = self.inputConfiguration ?? configuration
      guard liveConfiguration.isEffectivelyDisabled == false,
        liveConfiguration.hasActivationSink
      else {
        liveConfiguration.nativeControlBridge?.cancelPhysicalTracking()
        self.rollbackProgress(runID: runID)
        return
      }

      let handle = AwesomeButtonProgressHandle { [weak self] callback in
        if Thread.isMainThread {
          MainActor.assumeIsolated {
            self?.acceptProgressCompletion(callback, runID: runID)
          }
        } else {
          DispatchQueue.main.sync {
            MainActor.assumeIsolated {
              self?.acceptProgressCompletion(callback, runID: runID)
            }
          }
        }
      }
      liveConfiguration.nativeControlBridge?.prepareProgressHandle(handle)
      liveConfiguration.onPress?(handle)
      guard self.isMounted, self.progressRunID == runID, self.isBusy else {
        return
      }
      if let bridge = liveConfiguration.nativeControlBridge {
        switch bridge.dispatchAcceptedActivation(physical: physicalLifecycle) {
        case .dispatched:
          break
        case .mountedIneligible:
          bridge.cancelPhysicalTracking()
          if self.completionConsumed == false {
            self.rollbackProgress(runID: runID)
          }
          return
        case .unmounted:
          self.cleanup()
          return
        }
      }
      self.deferredProgressPressWorkItem = nil
    }
    deferredProgressPressWorkItem = workItem
    DispatchQueue.main.async(execute: workItem)
  }

  private func acceptProgressCompletion(_ completion: (() -> Void)?, runID: Int) {
    guard isMounted,
      inputConfiguration != nil,
      inputConfiguration?.isEffectivelyDisabled == false,
      isBusy,
      completionConsumed == false,
      progressRunID == runID
    else {
      return
    }

    completionConsumed = true
    progressEligibilityRevalidationWorkItem?.cancel()
    progressEligibilityRevalidationWorkItem = nil
    let snapshot = ProgressCompletionSnapshot(
      completion: completion,
      onProgressEnd: inputConfiguration?.onProgressEnd
    )
    pendingProgressCompletionSnapshot = snapshot
    let workItem = DispatchWorkItem { [weak self] in
      guard let self,
        self.isMounted,
        self.progressRunID == runID,
        self.isBusy
      else {
        return
      }

      self.executeProgressCompletion(snapshot, runID: runID)
    }
    progressCompletionWorkItem?.cancel()
    progressCompletionWorkItem = workItem
    DispatchQueue.main.async(execute: workItem)
  }

  private func executeProgressCompletion(
    _ snapshot: ProgressCompletionSnapshot,
    runID: Int
  ) {
    animateProgressFillCompletion(runID: runID) { [weak self] in
      guard let self, self.progressRunID == runID else {
        return
      }
      self.animateProgressSwapOut(runID: runID) { [weak self] in
        guard let self,
          self.isMounted,
          let configuration = self.inputConfiguration,
          self.progressRunID == runID
        else {
          return
        }
        self.finishProgressRun(snapshot, runID: runID, configuration: configuration)
      }
    }
  }

  private func finishProgressRun(
    _ snapshot: ProgressCompletionSnapshot,
    runID: Int,
    configuration: AwesomeButtonResolvedConfiguration
  ) {
    let finishProgress = { [weak self] in
      guard let self,
        self.isMounted,
        self.progressRunID == runID
      else {
        return
      }
      self.isBusy = false
      self.inputConfiguration?.nativeControlBridge?.updateEligibility(
        self.inputConfiguration?.isEffectivelyDisabled == false
      )
      self.showProgressVisuals = false
      self.resetProgressVisualState(unmount: false)
      self.pendingProgressCompletionSnapshot = nil
      snapshot.completion?()
      guard self.isMounted, self.progressRunID == runID else {
        return
      }
      snapshot.onProgressEnd?()
      self.inputConfiguration?.nativeControlBridge?.progressDidEnd()
      self.progressCompletionWorkItem = nil
    }
    if progressHasPhysicalLifecycle {
      releaseVisual(
        configuration: configuration,
        notifyPressOut: false,
        onComplete: finishProgress
      )
    } else {
      isPressed = false
      pressProgress = 0
      finishProgress()
    }
  }

  private func rollbackProgress(runID: Int) {
    guard isMounted,
      isBusy,
      completionConsumed == false,
      progressRunID == runID,
      let configuration = inputConfiguration
    else {
      return
    }

    completionConsumed = true
    progressEligibilityRevalidationWorkItem?.cancel()
    progressEligibilityRevalidationWorkItem = nil
    let progressEndSnapshot = configuration.onProgressEnd
    stopProgressAnimations()
    let finishRollback = { [weak self] in
      guard let self,
        self.isMounted,
        self.progressRunID == runID
      else {
        return
      }

      self.isBusy = false
      self.inputConfiguration?.nativeControlBridge?.updateEligibility(
        self.inputConfiguration?.isEffectivelyDisabled == false
      )
      self.showProgressVisuals = false
      self.resetProgressVisualState(unmount: false)
      progressEndSnapshot?()
      self.inputConfiguration?.nativeControlBridge?.progressDidEnd()
    }
    if progressHasPhysicalLifecycle {
      releaseVisual(configuration: configuration, notifyPressOut: false, onComplete: finishRollback)
    } else {
      isPressed = false
      pressProgress = 0
      finishRollback()
    }
  }

  private func cancelProgressWork(resetState: Bool) {
    progressRunID += 1
    deferredProgressPressWorkItem?.cancel()
    deferredProgressPressWorkItem = nil
    progressCompletionWorkItem?.cancel()
    progressCompletionWorkItem = nil
    pendingProgressCompletionSnapshot = nil
    progressEligibilityRevalidationWorkItem?.cancel()
    progressEligibilityRevalidationWorkItem = nil
    clearDeferredAutoWidthTransition()
    stopProgressAnimations()
    completionConsumed = true

    if resetState {
      self.isBusy = false
      self.showProgressVisuals = false
      self.resetProgressVisualState(unmount: true)
    }
  }

  private func scheduleProgressRollbackIfNeeded(
    configuration: AwesomeButtonResolvedConfiguration
  ) {
    guard isMounted,
      isBusy,
      completionConsumed == false,
      configuration.isEffectivelyDisabled,
      progressEligibilityRevalidationWorkItem == nil
    else {
      return
    }

    let runID = progressRunID
    let workItem = DispatchWorkItem { [weak self] in
      guard let self else {
        return
      }
      self.progressEligibilityRevalidationWorkItem = nil
      self.rollbackProgress(runID: runID)
    }
    progressEligibilityRevalidationWorkItem = workItem
    DispatchQueue.main.async(execute: workItem)
  }

  private func scheduleReducedMotionSettlementIfNeeded(
    configuration: AwesomeButtonResolvedConfiguration
  ) {
    guard configuration.reduceMotion else {
      reducedMotionSettlementWorkItem?.cancel()
      reducedMotionSettlementWorkItem = nil
      return
    }

    reducedMotionSettlementWorkItem?.cancel()
    let workItem = DispatchWorkItem { [weak self] in
      guard let self,
        self.isMounted,
        let liveConfiguration = self.inputConfiguration,
        liveConfiguration.reduceMotion
      else {
        return
      }
      self.reducedMotionSettlementWorkItem = nil

      if let releaseGeneration = self.activeReleaseGeneration {
        self.releaseSettleWorkItem?.cancel()
        self.releaseSettleWorkItem = nil
        self.pressProgress = 0
        self.completeReleaseIfNeeded(
          observedPressProgress: 0,
          expectedGeneration: releaseGeneration
        )
        return
      }

      if self.isBusy {
        self.stopProgressAnimations()
        if self.completionConsumed,
          let snapshot = self.pendingProgressCompletionSnapshot
        {
          self.contentTransitionValue = 1
          self.activityTransitionValue = 0
          self.progressOverlayOpacity = 0
          self.progressValue = 1
          self.finishProgressRun(
            snapshot,
            runID: self.progressRunID,
            configuration: liveConfiguration
          )
        } else {
          self.contentTransitionValue = 0
          self.activityTransitionValue = 1
          self.progressOverlayOpacity = liveConfiguration.showProgressBar ? 1 : 0
          self.progressValue = 1
          if self.progressHasPhysicalLifecycle {
            self.pressProgress = 1
          }
        }
        return
      }

      if self.isPressed {
        self.pressProgress = 1
      }
    }
    reducedMotionSettlementWorkItem = workItem
    DispatchQueue.main.async(execute: workItem)
  }

  private func stopProgressAnimations() {
    progressContentAnimation?.stop()
    progressContentAnimation = nil
    progressActivityAnimation?.stop()
    progressActivityAnimation = nil
    progressOverlayAnimation?.stop()
    progressOverlayAnimation = nil
    progressValueAnimation?.stop()
    progressValueAnimation = nil
  }

  private func resetProgressVisualState(unmount: Bool) {
    contentTransitionValue = 1
    activityTransitionValue = 0
    progressOverlayOpacity = 0
    progressValue = 0
    if unmount {
      showProgressVisuals = false
    }
  }

  private func startProgressFill(duration: TimeInterval, runID: Int) {
    progressValueAnimation?.stop()
    if inputConfiguration?.reduceMotion == true {
      progressValue = 1
      progressValueAnimation = nil
      return
    }
    progressValueAnimation = runProgressAnimation(
      durationMs: max(0, Int((duration * 1000).rounded())),
      fromValue: 0,
      toValue: 1,
      curve: { $0 },
      onUpdate: { [weak self] value in
        guard let self, self.progressRunID == runID else {
          return
        }
        self.progressValue = value
      },
      onComplete: { [weak self] in
        guard let self, self.progressRunID == runID else {
          return
        }
        self.progressValueAnimation = nil
      })
  }

  private func animateProgressSwapIn(runID: Int) {
    progressContentAnimation?.stop()
    progressActivityAnimation?.stop()
    if inputConfiguration?.reduceMotion == true {
      contentTransitionValue = 0
      activityTransitionValue = 1
      return
    }

    progressContentAnimation = runProgressAnimation(
      durationMs: progressSwapDurationMs,
      fromValue: contentTransitionValue,
      toValue: 0,
      curve: progressSwapCurveValue
    ) { [weak self] value in
      guard let self, self.progressRunID == runID else {
        return
      }
      self.contentTransitionValue = value
    } onComplete: { [weak self] in
      guard let self, self.progressRunID == runID else {
        return
      }
      self.progressContentAnimation = nil
    }

    progressActivityAnimation = runProgressAnimation(
      durationMs: progressSwapDurationMs,
      fromValue: activityTransitionValue,
      toValue: 1,
      curve: progressSwapCurveValue
    ) { [weak self] value in
      guard let self, self.progressRunID == runID else {
        return
      }
      self.activityTransitionValue = value
    } onComplete: { [weak self] in
      guard let self, self.progressRunID == runID else {
        return
      }
      self.progressActivityAnimation = nil
    }
  }

  private func animateProgressFillCompletion(runID: Int, completion: @escaping () -> Void) {
    progressValueAnimation?.stop()
    if inputConfiguration?.reduceMotion == true {
      progressValue = 1
      completion()
      return
    }
    if progressValue >= 1 {
      progressValue = 1
      completion()
      return
    }

    progressValueAnimation = runProgressAnimation(
      durationMs: progressFillCompletionDurationMs,
      fromValue: progressValue,
      toValue: 1,
      curve: progressCompletionCurveValue
    ) { [weak self] value in
      guard let self, self.progressRunID == runID else {
        return
      }
      self.progressValue = value
    } onComplete: { [weak self] in
      guard let self, self.progressRunID == runID else {
        return
      }
      self.progressValueAnimation = nil
      completion()
    }
  }

  private func animateProgressSwapOut(runID: Int, completion: @escaping () -> Void) {
    progressContentAnimation?.stop()
    progressActivityAnimation?.stop()
    progressOverlayAnimation?.stop()
    if inputConfiguration?.reduceMotion == true {
      contentTransitionValue = 1
      activityTransitionValue = 0
      progressOverlayOpacity = 0
      completion()
      return
    }

    var pendingCompletions = 3
    let finishOne = { [weak self] in
      pendingCompletions -= 1
      if pendingCompletions == 0, self?.progressRunID == runID {
        completion()
      }
    }

    progressContentAnimation = runProgressAnimation(
      durationMs: progressSwapDurationMs,
      fromValue: contentTransitionValue,
      toValue: 1,
      curve: progressSwapCurveValue
    ) { [weak self] value in
      guard let self, self.progressRunID == runID else {
        return
      }
      self.contentTransitionValue = value
    } onComplete: { [weak self] in
      guard let self, self.progressRunID == runID else {
        return
      }
      self.progressContentAnimation = nil
      finishOne()
    }

    progressActivityAnimation = runProgressAnimation(
      durationMs: progressSwapDurationMs,
      fromValue: activityTransitionValue,
      toValue: 0,
      curve: progressSwapCurveValue
    ) { [weak self] value in
      guard let self, self.progressRunID == runID else {
        return
      }
      self.activityTransitionValue = value
    } onComplete: { [weak self] in
      guard let self, self.progressRunID == runID else {
        return
      }
      self.progressActivityAnimation = nil
      finishOne()
    }

    progressOverlayAnimation = runProgressAnimation(
      durationMs: progressOverlayFadeDurationMs,
      delayMs: progressOverlayFadeDelayMs,
      fromValue: progressOverlayOpacity,
      toValue: 0,
      curve: progressCompletionCurveValue
    ) { [weak self] value in
      guard let self, self.progressRunID == runID else {
        return
      }
      self.progressOverlayOpacity = value
    } onComplete: { [weak self] in
      guard let self, self.progressRunID == runID else {
        return
      }
      self.progressOverlayAnimation = nil
      finishOne()
    }
  }

  // MARK: - Rendered Configuration / Style

  private func applyHeightUpdate(
    _ configuration: AwesomeButtonResolvedConfiguration, previousWidthMode: ButtonWidthMode?
  ) {
    let shouldSnap = shouldSnapWidthBridge(
      previous: previousWidthMode, next: configuration.widthMode)
    if shouldSnap || configuration.animateSize == false || configuration.reduceMotion {
      resolvedHeight = configuration.height
      return
    }

    if abs(resolvedHeight - configuration.height) >= 0.5 {
      withAnimation(sizeAnimation()) {
        resolvedHeight = configuration.height
      }
    }
  }

  private func commitRenderedConfiguration(
    _ configuration: AwesomeButtonResolvedConfiguration,
    previousWidthMode: ButtonWidthMode?
  ) {
    if let previousConfiguration = renderedConfiguration,
      shouldAnimateStyleTransition(from: previousConfiguration, to: configuration)
    {
      startStyleTransition(
        from: currentVisualStyle(from: previousConfiguration), to: configuration.style)
    } else {
      resetStyleTransition()
    }

    renderedConfiguration = configuration
    currentWidthMode = configuration.widthMode

    if displayedText == nil {
      displayedText = configuration.childText
      currentTextTarget = configuration.childText
    }

    applyHeightUpdate(configuration, previousWidthMode: previousWidthMode)
    applyWidthAndTextUpdate(configuration, previousWidthMode: previousWidthMode)
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

  private func startStyleTransition(
    from sourceStyle: AwesomeButtonStyle, to targetStyle: AwesomeButtonStyle
  ) {
    styleTransitionKickoffWorkItem?.cancel()
    styleTransitionID += 1
    let transitionID = styleTransitionID
    styleTransitionSourceStyle = resolvedVisualStyle(sourceStyle)
    styleTransitionProgress = 0

    let workItem = DispatchWorkItem { [weak self] in
      guard let self, self.styleTransitionID == transitionID else {
        return
      }

      withAnimation(self.styleTransitionAnimation(for: targetStyle)) {
        self.styleTransitionProgress = 1
      }
    }

    styleTransitionKickoffWorkItem = workItem
    DispatchQueue.main.async(execute: workItem)
  }

  private func resetStyleTransition() {
    styleTransitionKickoffWorkItem?.cancel()
    styleTransitionKickoffWorkItem = nil
    styleTransitionID += 1
    styleTransitionSourceStyle = nil
    styleTransitionProgress = 1
  }

  private func styleTransitionAnimation(for style: AwesomeButtonStyle) -> Animation {
    let timing = resolvedDirectStyleAnimationTiming(style: style)
    return timing.curve.animation(duration: timing.duration)
  }

  // MARK: - Width / Text

  private func applyWidthAndTextUpdate(
    _ configuration: AwesomeButtonResolvedConfiguration, previousWidthMode: ButtonWidthMode?
  ) {
    textTransitionController?.stop()
    delayedWidthWorkItem?.cancel()
    delayedTextWorkItem?.cancel()
    delayedClipAlignmentResetWorkItem?.cancel()

    switch configuration.widthMode {
    case .stretch:
      contentClipAlignment = .center
      resolvedWidth = nil
      syncTextTransitionState(configuration)
    case .fixed:
      contentClipAlignment = .center
      if shouldSnapWidthBridge(previous: previousWidthMode, next: .fixed)
        || configuration.animateSize == false || configuration.reduceMotion
      {
        resolvedWidth = configuration.width
      } else if abs((resolvedWidth ?? 0) - (configuration.width ?? 0)) >= 0.5 {
        withAnimation(sizeAnimation()) {
          resolvedWidth = configuration.width
        }
      }
      syncTextTransitionState(configuration)
    case .auto:
      let targetWidth = configuration.measurementSignature.map {
        max(configuration.height, measurementService.measureWidth(for: $0))
      }
      let currentWidth =
        shouldSnapWidthBridge(previous: previousWidthMode, next: .auto) ? nil : resolvedWidth
      let plan = resolveAutoWidthTextUpdatePlan(
        isEligible: configuration.isAutoWidthTextEligible,
        targetText: configuration.childText,
        currentWidth: currentWidth,
        targetWidth: targetWidth,
        displayedText: displayedText,
        animateSize: configuration.animateSize && configuration.reduceMotion == false,
        textTransition: configuration.textTransition && configuration.reduceMotion == false,
        slotStaggerMs: configuration.textTransitionSlotStaggerMs
      )
      executeAutoWidthTextUpdatePlan(plan, configuration: configuration)
    }
  }

  func updateMeasuredAutoWidth(
    _ measuredWidth: CGFloat,
    configuration: AwesomeButtonResolvedConfiguration
  ) {
    refreshLiveConfiguration(configuration)
    let targetWidth = max(configuration.height, measuredWidth)
    guard targetWidth.isFinite, targetWidth > 0 else {
      return
    }
    configuration.nativeControlBridge?.measuredWidthDidChange(targetWidth)

    guard configuration.widthMode == .auto else {
      return
    }

    guard let resolvedWidth else {
      self.resolvedWidth = targetWidth
      return
    }

    guard abs(resolvedWidth - targetWidth) >= 0.5 else {
      return
    }

    if configuration.animateSize && configuration.reduceMotion == false {
      withAnimation(sizeAnimation()) {
        self.resolvedWidth = targetWidth
      }
    } else {
      self.resolvedWidth = targetWidth
    }
  }

  func updateMeasuredContentHeight(
    _ measuredHeight: CGFloat,
    configuration: AwesomeButtonResolvedConfiguration
  ) {
    refreshLiveConfiguration(configuration)
    guard measuredHeight.isFinite, measuredHeight >= 0 else { return }
    let target = max(configuration.height, measuredHeight)
    guard abs(measuredContentHeight - target) >= 0.5 else { return }
    if configuration.animateSize && configuration.reduceMotion == false {
      withAnimation(sizeAnimation()) { measuredContentHeight = target }
    } else {
      measuredContentHeight = target
    }
  }

  private func executeAutoWidthTextUpdatePlan(
    _ plan: AutoWidthTextUpdatePlan,
    configuration: AwesomeButtonResolvedConfiguration
  ) {
    if case .fallbackToTextSync = plan {
      contentClipAlignment = .center
      resolvedWidth = max(configuration.height, resolvedWidth ?? 0)
      syncTextTransitionState(configuration)
      return
    }

    sizeRunID += 1
    let runID = sizeRunID

    switch plan {
    case .fallbackToTextSync:
      return
    case .initial(let targetText, let targetWidth):
      contentClipAlignment = .center
      currentTextTarget = targetText
      resolvedWidth = targetWidth
      displayedText = targetText
    case .textOnly(let sourceText, let targetText, let animateText):
      contentClipAlignment = .center
      currentTextTarget = targetText
      if animateText {
        runStringTransition(from: sourceText, to: targetText, runID: runID)
      } else {
        displayedText = targetText
      }
    case .growFirst(
      let sourceText, let targetText, let targetWidth, let timing, let animateSize, let animateText):
      contentClipAlignment = .center
      currentTextTarget = targetText
      if animateSize {
        if animateText {
          withAnimation(sizeAnimation(duration: timing.widthDuration)) {
            resolvedWidth = targetWidth
          }
        } else {
          withAnimation(sizeAnimation()) {
            resolvedWidth = targetWidth
          }
        }
      } else {
        resolvedWidth = targetWidth
      }

      if animateText {
        let workItem = DispatchWorkItem { [weak self] in
          guard let self, self.sizeRunID == runID else { return }
          self.runStringTransition(from: sourceText, to: targetText, runID: runID)
        }
        delayedTextWorkItem = workItem
        let delay = animateSize ? timing.textDelay : 0
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
      } else {
        let workItem = DispatchWorkItem { [weak self] in
          guard let self, self.sizeRunID == runID else { return }
          self.displayedText = targetText
        }
        delayedTextWorkItem = workItem
        let delay = animateSize ? sizeAnimationDuration : 0
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
      }
    case .shrinkLast(
      let sourceText, let targetText, let targetWidth, let timing, let animateSize, let animateText):
      currentTextTarget = targetText
      if animateText {
        contentClipAlignment = .leading
        runStringTransition(
          from: sourceText,
          to: targetText,
          runID: runID,
          onComplete: { [weak self] in
            guard let self, self.sizeRunID == runID, animateSize == false else { return }
            self.contentClipAlignment = .center
          }
        )
        let workItem = DispatchWorkItem { [weak self] in
          guard let self, self.sizeRunID == runID else { return }
          if animateSize {
            withAnimation(sizeAnimation(duration: timing.widthDuration)) {
              self.resolvedWidth = targetWidth
            }
          } else {
            self.resolvedWidth = targetWidth
          }
        }
        delayedWidthWorkItem = workItem
        let delay: TimeInterval = animateSize ? timing.widthDelay : 0
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
        if animateSize {
          let resetWorkItem = DispatchWorkItem { [weak self] in
            guard let self, self.sizeRunID == runID else { return }
            self.contentClipAlignment = .center
          }
          delayedClipAlignmentResetWorkItem = resetWorkItem
          DispatchQueue.main.asyncAfter(
            deadline: .now() + delay + timing.widthDuration,
            execute: resetWorkItem
          )
        }
      } else {
        contentClipAlignment = .center
        displayedText = targetText
        if animateSize {
          withAnimation(sizeAnimation()) {
            resolvedWidth = targetWidth
          }
        } else {
          resolvedWidth = targetWidth
        }
      }
    }
  }

  private func syncTextTransitionState(_ configuration: AwesomeButtonResolvedConfiguration) {
    contentClipAlignment = .center
    switch resolveButtonTextUpdatePlan(
      textTransitionEnabled: configuration.textTransition,
      nextText: configuration.childText,
      currentTarget: currentTextTarget,
      displayedText: displayedText
    ) {
    case .assign(let nextText):
      currentTextTarget = nextText
      displayedText = nextText
    case .keep:
      return
    case .transition(let sourceText, let targetText):
      sizeRunID += 1
      let runID = sizeRunID
      currentTextTarget = targetText
      runStringTransition(from: sourceText, to: targetText, runID: runID)
    }
  }

  private func runStringTransition(
    from source: String,
    to target: String,
    runID: Int,
    onComplete: (() -> Void)? = nil
  ) {
    if inputConfiguration?.reduceMotion == true {
      displayedText = target
      onComplete?()
      return
    }
    textTransitionController = runTextTransition(
      fromText: source,
      targetText: target,
      slotStaggerMs: renderedConfiguration?.textTransitionSlotStaggerMs ?? inputConfiguration?
        .textTransitionSlotStaggerMs ?? defaultTextTransitionSlotStaggerMs
    ) { [weak self] current in
      guard let self, self.sizeRunID == runID else { return }
      self.displayedText = current
    } onComplete: { [weak self] in
      guard let self, self.sizeRunID == runID else { return }
      self.displayedText = target
      onComplete?()
    }
  }

  // MARK: - Release Deferral

  private func cancelReleaseTracking() {
    releaseSettleWorkItem?.cancel()
    releaseSettleWorkItem = nil
    activeReleaseGeneration = nil
    pendingReleaseConfiguration = nil
    pendingReleaseCompletion = nil
  }

  private func scheduleReleaseCompletion(for generation: Int) {
    releaseSettleWorkItem?.cancel()
    let workItem = DispatchWorkItem { [weak self] in
      guard let self else {
        return
      }

      self.completeReleaseIfNeeded(observedPressProgress: 0, expectedGeneration: generation)
    }
    releaseSettleWorkItem = workItem
    DispatchQueue.main.asyncAfter(
      deadline: .now() + releaseSpringSettleDuration,
      execute: workItem
    )
  }

  func completeReleaseIfNeeded(observedPressProgress: CGFloat, expectedGeneration: Int? = nil) {
    guard activeReleaseGeneration != nil,
      expectedGeneration == nil || activeReleaseGeneration == expectedGeneration,
      isPressed == false,
      isTouchActive == false,
      abs(observedPressProgress) <= 0.001
    else {
      return
    }

    let completion = pendingReleaseCompletion
    let configuration = pendingReleaseConfiguration
    releaseSettleWorkItem?.cancel()
    releaseSettleWorkItem = nil
    activeReleaseGeneration = nil
    pendingReleaseCompletion = nil
    pendingReleaseConfiguration = nil
    configuration?.onPressedOut?()
    guard isMounted else {
      return
    }
    completion?()
    guard isMounted else {
      return
    }
    drainDeferredAutoWidthTransitionIfNeeded()
  }

  private func clearDeferredAutoWidthTransition() {
    deferredAutoWidthTransition = nil
  }

  private func shouldDeferAutoWidthTextTransitionUpdate(
    from currentConfiguration: AwesomeButtonResolvedConfiguration?,
    to nextConfiguration: AwesomeButtonResolvedConfiguration,
    previousWidthMode: ButtonWidthMode?
  ) -> Bool {
    let targetWidth = nextConfiguration.measurementSignature.map {
      max(nextConfiguration.height, measurementService.measureWidth(for: $0))
    }
    return shouldDeferReleaseAutoWidthTransition(
      isReleaseActive: activeReleaseGeneration != nil || terminalReleaseGeneration != nil,
      currentConfiguration: currentConfiguration,
      nextConfiguration: nextConfiguration,
      previousWidthMode: previousWidthMode,
      currentWidth: resolvedWidth,
      targetWidth: targetWidth
    )
  }

  private func drainDeferredAutoWidthTransitionIfNeeded() {
    guard let deferredAutoWidthTransition else {
      return
    }

    self.deferredAutoWidthTransition = nil
    commitRenderedConfiguration(
      deferredAutoWidthTransition.configuration,
      previousWidthMode: deferredAutoWidthTransition.previousWidthMode
    )
  }
}
