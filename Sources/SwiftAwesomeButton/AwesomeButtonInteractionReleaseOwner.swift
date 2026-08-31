import SwiftUI

internal struct AwesomeButtonInteractionInput {
  let isEffectivelyDisabled: Bool
  let isBusy: Bool
  let debouncedPressTime: TimeInterval
  let hapticOnPress: Bool
  let reduceMotion: Bool
  let externallyHighlighted: Bool
  let pressTiming: AwesomeButtonAnimationTiming

  init(configuration: AwesomeButtonResolvedConfiguration, isBusy: Bool) {
    isEffectivelyDisabled = configuration.isEffectivelyDisabled
    self.isBusy = isBusy
    debouncedPressTime = configuration.debouncedPressTime
    hapticOnPress = configuration.hapticOnPress
    reduceMotion = configuration.reduceMotion
    #if canImport(UIKit)
      externallyHighlighted = configuration.externallyHighlighted
    #else
      externallyHighlighted = false
    #endif
    pressTiming = resolvedPressInAnimationTiming(style: configuration.style)
  }
}

internal struct AwesomeButtonReleaseSnapshot {
  let style: AwesomeButtonStyle
  let reduceMotion: Bool
  let onPressedOut: (() -> Void)?
}

internal enum AwesomeButtonPressTransition {
  case immediate
  case timed(AwesomeButtonAnimationTiming)
  case releaseSpring
}

internal enum AwesomeButtonInteractionCommand {
  case touchDidBegin(generation: Int)
  case touchDidEnd(generation: Int)
  case dispatchPressIn(generation: Int)
  case commitPressed(generation: Int, haptic: Bool)
  case dispatchPressedIn(generation: Int)
  case dispatchPressOut(generation: Int)
  case dispatchLongPress(generation: Int)
  case validateActivation(generation: Int)
  case routeActivation(generation: Int, physicalLifecycle: Bool)
  case cancelPhysicalTracking(generation: Int)
  case clearDeferredSize(generation: Int)
  case setPressPresentation(
    generation: Int,
    isPressed: Bool,
    progress: CGFloat,
    transition: AwesomeButtonPressTransition
  )
  case releaseCompleted(
    generation: Int,
    releaseGeneration: Int,
    snapshot: AwesomeButtonReleaseSnapshot,
    completion: (() -> Void)?
  )
  case settleProgressReducedMotion(generation: Int)

  var generation: Int {
    switch self {
    case .touchDidBegin(let generation),
      .touchDidEnd(let generation),
      .dispatchPressIn(let generation),
      .commitPressed(let generation, _),
      .dispatchPressedIn(let generation),
      .dispatchPressOut(let generation),
      .dispatchLongPress(let generation),
      .validateActivation(let generation),
      .routeActivation(let generation, _),
      .cancelPhysicalTracking(let generation),
      .clearDeferredSize(let generation),
      .setPressPresentation(let generation, _, _, _),
      .releaseCompleted(let generation, _, _, _),
      .settleProgressReducedMotion(let generation):
      return generation
    }
  }
}

@MainActor
internal final class AwesomeButtonInteractionReleaseOwner {
  private weak var sink: AwesomeButtonControllerCommandSink?
  private var latestInput: AwesomeButtonInteractionInput?
  private var lastAcceptedPressAt: Date?
  private var terminalContinuationWorkItem: DispatchWorkItem?
  private var releaseSettleWorkItem: DispatchWorkItem?
  private var reducedMotionSettlementWorkItem: DispatchWorkItem?
  private var pendingReleaseSnapshot: AwesomeButtonReleaseSnapshot?
  private var pendingReleaseCompletion: (() -> Void)?
  private var terminalReleaseGeneration: Int?
  private var externalHighlightApplied = false
  private(set) var generation = 0
  private(set) var releaseGeneration = 0
  private(set) var activeReleaseGeneration: Int?
  private(set) var isTouchActive = false
  private(set) var isTouchInside = false
  private(set) var isPressed = false
  private(set) var pressProgress: CGFloat = 0

  init(sink: AwesomeButtonControllerCommandSink) {
    self.sink = sink
  }

  var hasTerminalRelease: Bool {
    terminalReleaseGeneration != nil
  }

  func connect(to sink: AwesomeButtonControllerCommandSink) {
    self.sink = sink
  }

  func configurationDidChange(
    _ input: AwesomeButtonInteractionInput,
    shouldApplyExternalHighlight: Bool = true
  ) {
    latestInput = input
    if shouldApplyExternalHighlight {
      applyExternalHighlight(input: input)
    }
    scheduleReducedMotionSettlementIfNeeded(input: input)
  }

  func handleTouchChange(isInside: Bool, input: AwesomeButtonInteractionInput) {
    latestInput = input
    guard input.isEffectivelyDisabled == false, input.isBusy == false else { return }
    if isInside == false {
      handleTouchEnd(isInside: false, input: input)
      return
    }

    let isInterruptingRelease = terminalReleaseGeneration != nil || activeReleaseGeneration != nil
    if isTouchActive == false, terminalReleaseGeneration != nil {
      invalidateTerminalAndRelease()
      isPressed = false
    }

    isTouchActive = true
    isTouchInside = true
    _ = sink?.receive(.touchDidBegin(generation: generation))
    armPress(preserveDeferredSize: isInterruptingRelease)
  }

  func handleTouchEnd(isInside: Bool, input: AwesomeButtonInteractionInput) {
    latestInput = input
    guard isTouchActive else { return }

    isTouchActive = false
    isTouchInside = false
    generation += 1
    let generation = generation
    terminalReleaseGeneration = generation
    _ = sink?.receive(.touchDidEnd(generation: generation))
    guard let releaseSnapshot = sink?.snapshotRelease(generation: generation) else {
      return
    }
    let shouldNotifyPressOut = isPressed || pressProgress > 0.001
    if shouldNotifyPressOut,
      sink?.receive(.dispatchPressOut(generation: generation)) != .accepted
    {
      return
    }

    enqueueTerminal(generation: generation) { [weak self] in
      guard let self, let live = self.latestInput else { return }
      guard isInside, live.isBusy == false, live.isEffectivelyDisabled == false, self.isPressed
      else {
        self.cancelPhysicalTracking(generation: generation)
        self.releaseVisual(snapshot: releaseSnapshot)
        return
      }
      guard self.sink?.receive(.validateActivation(generation: generation)) == .accepted,
        self.shouldAcceptDebouncedPress(input: live)
      else {
        self.cancelPhysicalTracking(generation: generation)
        self.releaseVisual(snapshot: releaseSnapshot)
        return
      }

      self.lastAcceptedPressAt = Date()
      switch self.sink?.receive(
        .routeActivation(generation: generation, physicalLifecycle: true)
      ) {
      case .directActivation:
        self.enqueueTerminal(generation: generation) { [weak self] in
          self?.releaseVisual(snapshot: releaseSnapshot)
        }
      case .progressStarted:
        break
      case .unmounted, .stale:
        break
      default:
        self.cancelPhysicalTracking(generation: generation)
        self.releaseVisual(snapshot: releaseSnapshot)
      }
    }
  }

  func handleLongPress() {
    guard isTouchActive, latestInput?.isEffectivelyDisabled == false,
      latestInput?.isBusy == false
    else { return }
    _ = sink?.receive(.dispatchLongPress(generation: generation))
  }

  func activateAtomically(input: AwesomeButtonInteractionInput) -> Bool {
    latestInput = input
    guard input.isEffectivelyDisabled == false, input.isBusy == false,
      shouldAcceptDebouncedPress(input: input),
      sink?.receive(.validateActivation(generation: generation)) == .accepted
    else { return false }
    lastAcceptedPressAt = Date()
    switch sink?.receive(.routeActivation(generation: generation, physicalLifecycle: false)) {
    case .directActivation, .progressStarted:
      return true
    default:
      return false
    }
  }

  func activateLongPressAtomically(input: AwesomeButtonInteractionInput) -> Bool {
    latestInput = input
    guard input.isEffectivelyDisabled == false, input.isBusy == false else { return false }
    return sink?.receive(.dispatchLongPress(generation: generation)) == .accepted
  }

  func startRelease(
    snapshot: AwesomeButtonReleaseSnapshot,
    completion: (() -> Void)?
  ) {
    releaseVisual(snapshot: snapshot, completion: completion)
  }

  func progressDidStart() {
    terminalReleaseGeneration = nil
    terminalContinuationWorkItem = nil
    cancelRelease()
  }

  func completeReleaseIfNeeded(
    observedPressProgress: CGFloat,
    expectedGeneration: Int? = nil
  ) {
    guard let activeReleaseGeneration,
      expectedGeneration == nil || activeReleaseGeneration == expectedGeneration,
      isPressed == false,
      isTouchActive == false,
      abs(observedPressProgress) <= 0.001
    else { return }

    let snapshot = pendingReleaseSnapshot
    let completion = pendingReleaseCompletion
    releaseSettleWorkItem?.cancel()
    releaseSettleWorkItem = nil
    self.activeReleaseGeneration = nil
    pendingReleaseSnapshot = nil
    pendingReleaseCompletion = nil
    guard let snapshot else { return }
    _ = sink?.receive(
      .releaseCompleted(
        generation: generation,
        releaseGeneration: activeReleaseGeneration,
        snapshot: snapshot,
        completion: completion
      )
    )
  }

  func cancelRelease() {
    releaseSettleWorkItem?.cancel()
    releaseSettleWorkItem = nil
    activeReleaseGeneration = nil
    pendingReleaseSnapshot = nil
    pendingReleaseCompletion = nil
  }

  func isCurrent(_ generation: Int) -> Bool {
    self.generation == generation
  }

  func cleanup() {
    generation += 1
    terminalContinuationWorkItem?.cancel()
    terminalContinuationWorkItem = nil
    terminalReleaseGeneration = nil
    cancelRelease()
    reducedMotionSettlementWorkItem?.cancel()
    reducedMotionSettlementWorkItem = nil
    isTouchActive = false
    isTouchInside = false
    isPressed = false
    pressProgress = 0
    externalHighlightApplied = false
    latestInput = nil
    sink = nil
  }

  private func armPress(preserveDeferredSize: Bool) {
    guard isPressed == false else { return }
    cancelRelease()
    if preserveDeferredSize == false {
      _ = sink?.receive(.clearDeferredSize(generation: generation))
    }

    guard sink?.receive(.dispatchPressIn(generation: generation)) == .accepted else {
      cancelGestureAfterRevalidation()
      return
    }
    guard let input = latestInput, input.isEffectivelyDisabled == false, input.isBusy == false,
      isTouchActive, isTouchInside
    else {
      cancelGestureAfterRevalidation()
      return
    }

    isPressed = true
    guard
      sink?.receive(
        .commitPressed(generation: generation, haptic: input.hapticOnPress)
      ) == .accepted
    else {
      cancelGestureAfterRevalidation()
      return
    }
    guard sink?.receive(.dispatchPressedIn(generation: generation)) == .accepted else {
      cancelGestureAfterRevalidation()
      return
    }
    guard let current = latestInput, current.isEffectivelyDisabled == false,
      current.isBusy == false, isTouchActive, isTouchInside, isPressed
    else {
      cancelGestureAfterRevalidation()
      return
    }

    pressProgress = 1
    _ = sink?.receive(
      .setPressPresentation(
        generation: generation,
        isPressed: true,
        progress: 1,
        transition: current.reduceMotion ? .immediate : .timed(current.pressTiming)
      )
    )
  }

  private func cancelGestureAfterRevalidation() {
    guard isTouchActive, let input = latestInput else { return }
    handleTouchEnd(isInside: false, input: input)
  }

  private func releaseVisual(
    snapshot: AwesomeButtonReleaseSnapshot,
    completion: (() -> Void)? = nil
  ) {
    terminalReleaseGeneration = nil
    guard isPressed || pressProgress > 0.001 || activeReleaseGeneration != nil else {
      completion?()
      return
    }

    let releaseNeedsVisualSettle = pressProgress > 0.001
    isPressed = false
    cancelRelease()

    if snapshot.reduceMotion {
      pressProgress = 0
      _ = sink?.receive(
        .setPressPresentation(
          generation: generation,
          isPressed: false,
          progress: 0,
          transition: .immediate
        )
      )
      _ = sink?.receive(
        .releaseCompleted(
          generation: generation,
          releaseGeneration: releaseGeneration,
          snapshot: snapshot,
          completion: completion
        )
      )
      return
    }

    releaseGeneration += 1
    let releaseGeneration = releaseGeneration
    activeReleaseGeneration = releaseGeneration
    pendingReleaseSnapshot = snapshot
    pendingReleaseCompletion = completion
    pressProgress = 0
    _ = sink?.receive(
      .setPressPresentation(
        generation: generation,
        isPressed: false,
        progress: 0,
        transition: .releaseSpring
      )
    )
    if releaseNeedsVisualSettle {
      scheduleReleaseCompletion(releaseGeneration: releaseGeneration)
    } else {
      completeReleaseIfNeeded(
        observedPressProgress: 0,
        expectedGeneration: releaseGeneration
      )
    }
  }

  private func scheduleReleaseCompletion(releaseGeneration: Int) {
    releaseSettleWorkItem?.cancel()
    let workItem = DispatchWorkItem { [weak self] in
      self?.completeReleaseIfNeeded(
        observedPressProgress: 0,
        expectedGeneration: releaseGeneration
      )
    }
    releaseSettleWorkItem = workItem
    DispatchQueue.main.asyncAfter(
      deadline: .now() + releaseSpringSettleDuration,
      execute: workItem
    )
  }

  private func enqueueTerminal(generation: Int, action: @escaping () -> Void) {
    let workItem = DispatchWorkItem { [weak self] in
      guard let self, self.generation == generation else { return }
      action()
    }
    terminalContinuationWorkItem = workItem
    DispatchQueue.main.async(execute: workItem)
  }

  private func invalidateTerminalAndRelease() {
    generation += 1
    terminalContinuationWorkItem?.cancel()
    terminalContinuationWorkItem = nil
    terminalReleaseGeneration = nil
    cancelRelease()
  }

  private func shouldAcceptDebouncedPress(input: AwesomeButtonInteractionInput) -> Bool {
    guard input.debouncedPressTime > 0, let lastAcceptedPressAt else { return true }
    return Date().timeIntervalSince(lastAcceptedPressAt) >= input.debouncedPressTime
  }

  private func cancelPhysicalTracking(generation: Int) {
    _ = sink?.receive(
      AwesomeButtonInteractionCommand.cancelPhysicalTracking(generation: generation)
    )
  }

  private func applyExternalHighlight(input: AwesomeButtonInteractionInput) {
    guard isTouchActive == false, input.isBusy == false else { return }
    let shouldHighlight = input.externallyHighlighted && input.isEffectivelyDisabled == false
    guard shouldHighlight != externalHighlightApplied else { return }
    externalHighlightApplied = shouldHighlight
    isPressed = shouldHighlight
    pressProgress = shouldHighlight ? 1 : 0
    _ = sink?.receive(
      .setPressPresentation(
        generation: generation,
        isPressed: shouldHighlight,
        progress: shouldHighlight ? 1 : 0,
        transition: input.reduceMotion
          ? .immediate
          : shouldHighlight ? .timed(input.pressTiming) : .releaseSpring
      )
    )
  }

  private func scheduleReducedMotionSettlementIfNeeded(input: AwesomeButtonInteractionInput) {
    guard input.reduceMotion else {
      reducedMotionSettlementWorkItem?.cancel()
      reducedMotionSettlementWorkItem = nil
      return
    }
    reducedMotionSettlementWorkItem?.cancel()
    let generation = generation
    let workItem = DispatchWorkItem { [weak self] in
      guard let self, self.generation == generation, self.latestInput?.reduceMotion == true else {
        return
      }
      self.reducedMotionSettlementWorkItem = nil
      if let releaseGeneration = self.activeReleaseGeneration {
        self.releaseSettleWorkItem?.cancel()
        self.releaseSettleWorkItem = nil
        self.pressProgress = 0
        _ = self.sink?.receive(
          .setPressPresentation(
            generation: generation,
            isPressed: false,
            progress: 0,
            transition: .immediate
          )
        )
        self.completeReleaseIfNeeded(
          observedPressProgress: 0,
          expectedGeneration: releaseGeneration
        )
      } else {
        _ = self.sink?.receive(.settleProgressReducedMotion(generation: generation))
      }
    }
    reducedMotionSettlementWorkItem = workItem
    DispatchQueue.main.async(execute: workItem)
  }
}
