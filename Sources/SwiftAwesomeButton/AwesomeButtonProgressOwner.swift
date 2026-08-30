import SwiftUI

internal struct AwesomeButtonProgressInput {
  let isEffectivelyDisabled: Bool
  let progressLoadingTime: TimeInterval
  let reduceMotion: Bool

  init(configuration: AwesomeButtonResolvedConfiguration) {
    isEffectivelyDisabled = configuration.isEffectivelyDisabled
    progressLoadingTime = configuration.progressLoadingTime
    reduceMotion = configuration.reduceMotion
  }
}

internal struct AwesomeButtonProgressCompletionSnapshot {
  let completion: (() -> Void)?
  let onProgressEnd: (() -> Void)?
}

internal struct AwesomeButtonProgressPresentation {
  let isBusy: Bool
  let showProgressVisuals: Bool
  let contentTransitionValue: CGFloat
  let activityTransitionValue: CGFloat
  let progressOverlayOpacity: CGFloat
  let progressValue: CGFloat
  let isPressed: Bool?
  let pressProgress: CGFloat?
}

internal enum AwesomeButtonProgressCommand {
  case setPresentation(generation: Int, value: AwesomeButtonProgressPresentation)
  case dispatchProgressStart(generation: Int)
  case dispatchActivation(
    generation: Int,
    handle: AwesomeButtonProgressHandle,
    physicalLifecycle: Bool
  )
  case requestRelease(generation: Int, physicalLifecycle: Bool)
  case finishCompletion(generation: Int, snapshot: AwesomeButtonProgressCompletionSnapshot)
  case finishRollback(generation: Int, onProgressEnd: (() -> Void)?)

  var generation: Int {
    switch self {
    case .setPresentation(let generation, _),
      .dispatchProgressStart(let generation),
      .dispatchActivation(let generation, _, _),
      .requestRelease(let generation, _),
      .finishCompletion(let generation, _),
      .finishRollback(let generation, _):
      return generation
    }
  }
}

@MainActor
internal final class AwesomeButtonProgressOwner {
  private weak var sink: AwesomeButtonControllerCommandSink?
  private var deferredActivationWorkItem: DispatchWorkItem?
  private var completionWorkItem: DispatchWorkItem?
  private var eligibilityRevalidationWorkItem: DispatchWorkItem?
  private var contentAnimation: ProgressAnimationControlling?
  private var activityAnimation: ProgressAnimationControlling?
  private var overlayAnimation: ProgressAnimationControlling?
  private var valueAnimation: ProgressAnimationControlling?
  private var latestInput: AwesomeButtonProgressInput?
  private var completionConsumed = true
  private var hasPhysicalLifecycle = true
  private var pendingCompletionSnapshot: AwesomeButtonProgressCompletionSnapshot?
  private(set) var generation = 0
  private(set) var isBusy = false

  init(sink: AwesomeButtonControllerCommandSink) {
    self.sink = sink
  }

  func connect(to sink: AwesomeButtonControllerCommandSink) {
    self.sink = sink
  }

  func configurationDidChange(_ input: AwesomeButtonProgressInput) {
    latestInput = input
    scheduleRollbackIfNeeded(input: input)
  }

  func start(
    input: AwesomeButtonProgressInput,
    physicalLifecycle: Bool
  ) {
    cancelWork(resetState: false)
    generation += 1
    let generation = generation
    latestInput = input
    completionConsumed = false
    isBusy = true
    hasPhysicalLifecycle = physicalLifecycle
    sendPresentation(
      generation: generation,
      isBusy: true,
      showProgressVisuals: true,
      content: 1,
      activity: 0,
      overlay: 1,
      progress: 0,
      isPressed: physicalLifecycle,
      pressProgress: physicalLifecycle ? 1 : 0
    )

    guard sink?.receive(.dispatchProgressStart(generation: generation)) == .accepted else {
      rollback(generation: generation)
      return
    }

    animateSwapIn(generation: generation)
    startFill(duration: input.progressLoadingTime, generation: generation)

    let workItem = DispatchWorkItem { [weak self, weak sink] in
      guard let self, self.isCurrent(generation), self.isBusy else { return }
      let handle = AwesomeButtonProgressHandle { [weak self] callback in
        if Thread.isMainThread {
          MainActor.assumeIsolated {
            self?.acceptCompletion(callback, generation: generation)
          }
        } else {
          DispatchQueue.main.sync {
            MainActor.assumeIsolated {
              self?.acceptCompletion(callback, generation: generation)
            }
          }
        }
      }
      let disposition = sink?.receive(
        .dispatchActivation(
          generation: generation,
          handle: handle,
          physicalLifecycle: physicalLifecycle
        )
      )
      guard disposition == .accepted else {
        if self.completionConsumed == false {
          self.rollback(generation: generation)
        }
        return
      }
      self.deferredActivationWorkItem = nil
    }
    deferredActivationWorkItem = workItem
    DispatchQueue.main.async(execute: workItem)
  }

  func acceptCompletion(_ completion: (() -> Void)?, generation: Int) {
    guard isCurrent(generation), isBusy, completionConsumed == false,
      latestInput?.isEffectivelyDisabled == false
    else { return }

    completionConsumed = true
    eligibilityRevalidationWorkItem?.cancel()
    eligibilityRevalidationWorkItem = nil
    let snapshot = AwesomeButtonProgressCompletionSnapshot(
      completion: completion,
      onProgressEnd: sink?.snapshotProgressEnd(generation: generation)
    )
    pendingCompletionSnapshot = snapshot
    let workItem = DispatchWorkItem { [weak self] in
      guard let self, self.isCurrent(generation), self.isBusy else { return }
      self.executeCompletion(snapshot, generation: generation)
    }
    completionWorkItem?.cancel()
    completionWorkItem = workItem
    DispatchQueue.main.async(execute: workItem)
  }

  func releaseDidFinish(generation: Int) {
    guard isCurrent(generation), isBusy else { return }
    if let snapshot = pendingCompletionSnapshot {
      finish(snapshot: snapshot, generation: generation)
    } else {
      finishRollback(generation: generation)
    }
  }

  func settleForReducedMotion() {
    guard isBusy, latestInput?.reduceMotion == true else { return }
    stopAnimations()
    let generation = generation
    if completionConsumed, pendingCompletionSnapshot != nil {
      sendPresentation(
        generation: generation,
        isBusy: true,
        showProgressVisuals: true,
        content: 1,
        activity: 0,
        overlay: 0,
        progress: 1
      )
      requestRelease(generation: generation)
    } else {
      sendPresentation(
        generation: generation,
        isBusy: true,
        showProgressVisuals: true,
        content: 0,
        activity: 1,
        overlay: 1,
        progress: 1
      )
    }
  }

  func isCurrent(_ generation: Int) -> Bool {
    self.generation == generation
  }

  func cleanup() {
    cancelWork(resetState: true)
    latestInput = nil
    sink = nil
  }

  private func executeCompletion(
    _ snapshot: AwesomeButtonProgressCompletionSnapshot,
    generation: Int
  ) {
    animateFillCompletion(generation: generation) { [weak self] in
      guard let self, self.isCurrent(generation) else { return }
      self.animateSwapOut(generation: generation) { [weak self] in
        guard let self, self.isCurrent(generation), self.isBusy else { return }
        self.pendingCompletionSnapshot = snapshot
        self.requestRelease(generation: generation)
      }
    }
  }

  private func requestRelease(generation: Int) {
    let disposition = sink?.receive(
      .requestRelease(generation: generation, physicalLifecycle: hasPhysicalLifecycle)
    )
    if disposition != .accepted, disposition != .stale {
      cancelWork(resetState: true)
    }
  }

  private func finish(
    snapshot: AwesomeButtonProgressCompletionSnapshot,
    generation: Int
  ) {
    guard isCurrent(generation) else { return }
    isBusy = false
    pendingCompletionSnapshot = nil
    sendPresentation(
      generation: generation,
      isBusy: false,
      showProgressVisuals: false,
      content: 1,
      activity: 0,
      overlay: 0,
      progress: 0,
      isPressed: false,
      pressProgress: 0
    )
    _ = sink?.receive(.finishCompletion(generation: generation, snapshot: snapshot))
    completionWorkItem = nil
  }

  private func rollback(generation: Int) {
    guard isCurrent(generation), isBusy, completionConsumed == false else { return }
    completionConsumed = true
    eligibilityRevalidationWorkItem?.cancel()
    eligibilityRevalidationWorkItem = nil
    stopAnimations()
    pendingCompletionSnapshot = AwesomeButtonProgressCompletionSnapshot(
      completion: nil,
      onProgressEnd: sink?.snapshotProgressEnd(generation: generation)
    )
    requestRelease(generation: generation)
  }

  private func finishRollback(generation: Int) {
    guard isCurrent(generation), isBusy else { return }
    let progressEnd = pendingCompletionSnapshot?.onProgressEnd
    isBusy = false
    pendingCompletionSnapshot = nil
    sendPresentation(
      generation: generation,
      isBusy: false,
      showProgressVisuals: false,
      content: 1,
      activity: 0,
      overlay: 0,
      progress: 0,
      isPressed: false,
      pressProgress: 0
    )
    _ = sink?.receive(.finishRollback(generation: generation, onProgressEnd: progressEnd))
  }

  private func scheduleRollbackIfNeeded(input: AwesomeButtonProgressInput) {
    guard isBusy, completionConsumed == false, input.isEffectivelyDisabled,
      eligibilityRevalidationWorkItem == nil
    else { return }

    let generation = generation
    let workItem = DispatchWorkItem { [weak self] in
      guard let self else { return }
      self.eligibilityRevalidationWorkItem = nil
      self.rollback(generation: generation)
    }
    eligibilityRevalidationWorkItem = workItem
    DispatchQueue.main.async(execute: workItem)
  }

  private func cancelWork(resetState: Bool) {
    generation += 1
    deferredActivationWorkItem?.cancel()
    deferredActivationWorkItem = nil
    completionWorkItem?.cancel()
    completionWorkItem = nil
    eligibilityRevalidationWorkItem?.cancel()
    eligibilityRevalidationWorkItem = nil
    pendingCompletionSnapshot = nil
    stopAnimations()
    completionConsumed = true
    if resetState {
      isBusy = false
      sendPresentation(
        generation: generation,
        isBusy: false,
        showProgressVisuals: false,
        content: 1,
        activity: 0,
        overlay: 0,
        progress: 0,
        isPressed: false,
        pressProgress: 0
      )
    }
  }

  private func startFill(duration: TimeInterval, generation: Int) {
    valueAnimation?.stop()
    guard latestInput?.reduceMotion == false else {
      updateProgress(1, generation: generation)
      valueAnimation = nil
      return
    }
    valueAnimation = runProgressAnimation(
      durationMs: max(0, Int((duration * 1000).rounded())),
      fromValue: 0,
      toValue: 1,
      curve: { $0 },
      onUpdate: { [weak self] value in
        guard let self, self.isCurrent(generation) else { return }
        self.updateProgress(value, generation: generation)
      },
      onComplete: { [weak self] in
        guard let self, self.isCurrent(generation) else { return }
        self.valueAnimation = nil
      }
    )
  }

  private func animateSwapIn(generation: Int) {
    contentAnimation?.stop()
    activityAnimation?.stop()
    guard latestInput?.reduceMotion == false else {
      updateContent(0, generation: generation)
      updateActivity(1, generation: generation)
      return
    }
    contentAnimation = runProgressAnimation(
      durationMs: progressSwapDurationMs,
      fromValue: 1,
      toValue: 0,
      curve: progressSwapCurveValue,
      onUpdate: { [weak self] value in
        self?.updateContent(value, generation: generation)
      },
      onComplete: { [weak self] in
        guard let self, self.isCurrent(generation) else { return }
        self.contentAnimation = nil
      }
    )
    activityAnimation = runProgressAnimation(
      durationMs: progressSwapDurationMs,
      fromValue: 0,
      toValue: 1,
      curve: progressSwapCurveValue,
      onUpdate: { [weak self] value in
        self?.updateActivity(value, generation: generation)
      },
      onComplete: { [weak self] in
        guard let self, self.isCurrent(generation) else { return }
        self.activityAnimation = nil
      }
    )
  }

  private func animateFillCompletion(generation: Int, completion: @escaping () -> Void) {
    valueAnimation?.stop()
    guard latestInput?.reduceMotion == false else {
      updateProgress(1, generation: generation)
      completion()
      return
    }
    if currentProgressValue >= 1 {
      updateProgress(1, generation: generation)
      completion()
      return
    }
    valueAnimation = runProgressAnimation(
      durationMs: progressFillCompletionDurationMs,
      fromValue: currentProgressValue,
      toValue: 1,
      curve: progressCompletionCurveValue,
      onUpdate: { [weak self] value in
        self?.updateProgress(value, generation: generation)
      },
      onComplete: { [weak self] in
        guard let self, self.isCurrent(generation) else { return }
        self.valueAnimation = nil
        completion()
      }
    )
  }

  private func animateSwapOut(generation: Int, completion: @escaping () -> Void) {
    contentAnimation?.stop()
    activityAnimation?.stop()
    overlayAnimation?.stop()
    guard latestInput?.reduceMotion == false else {
      updateContent(1, generation: generation)
      updateActivity(0, generation: generation)
      updateOverlay(0, generation: generation)
      completion()
      return
    }

    var pendingCompletions = 3
    let finishOne = { [weak self] in
      pendingCompletions -= 1
      if pendingCompletions == 0, self?.isCurrent(generation) == true {
        completion()
      }
    }
    contentAnimation = runProgressAnimation(
      durationMs: progressSwapDurationMs,
      fromValue: currentContentValue,
      toValue: 1,
      curve: progressSwapCurveValue,
      onUpdate: { [weak self] value in
        self?.updateContent(value, generation: generation)
      },
      onComplete: { [weak self] in
        guard let self, self.isCurrent(generation) else { return }
        self.contentAnimation = nil
        finishOne()
      }
    )
    activityAnimation = runProgressAnimation(
      durationMs: progressSwapDurationMs,
      fromValue: currentActivityValue,
      toValue: 0,
      curve: progressSwapCurveValue,
      onUpdate: { [weak self] value in
        self?.updateActivity(value, generation: generation)
      },
      onComplete: { [weak self] in
        guard let self, self.isCurrent(generation) else { return }
        self.activityAnimation = nil
        finishOne()
      }
    )
    overlayAnimation = runProgressAnimation(
      durationMs: progressOverlayFadeDurationMs,
      delayMs: progressOverlayFadeDelayMs,
      fromValue: currentOverlayValue,
      toValue: 0,
      curve: progressCompletionCurveValue,
      onUpdate: { [weak self] value in
        self?.updateOverlay(value, generation: generation)
      },
      onComplete: { [weak self] in
        guard let self, self.isCurrent(generation) else { return }
        self.overlayAnimation = nil
        finishOne()
      }
    )
  }

  private var currentContentValue: CGFloat = 1
  private var currentActivityValue: CGFloat = 0
  private var currentOverlayValue: CGFloat = 0
  private var currentProgressValue: CGFloat = 0

  private func updateContent(_ value: CGFloat, generation: Int) {
    guard isCurrent(generation) else { return }
    currentContentValue = value
    sendPresentation(generation: generation, content: value)
  }

  private func updateActivity(_ value: CGFloat, generation: Int) {
    guard isCurrent(generation) else { return }
    currentActivityValue = value
    sendPresentation(generation: generation, activity: value)
  }

  private func updateOverlay(_ value: CGFloat, generation: Int) {
    guard isCurrent(generation) else { return }
    currentOverlayValue = value
    sendPresentation(generation: generation, overlay: value)
  }

  private func updateProgress(_ value: CGFloat, generation: Int) {
    guard isCurrent(generation) else { return }
    currentProgressValue = value
    sendPresentation(generation: generation, progress: value)
  }

  private func sendPresentation(
    generation: Int,
    isBusy: Bool? = nil,
    showProgressVisuals: Bool? = nil,
    content: CGFloat? = nil,
    activity: CGFloat? = nil,
    overlay: CGFloat? = nil,
    progress: CGFloat? = nil,
    isPressed: Bool? = nil,
    pressProgress: CGFloat? = nil
  ) {
    if let content { currentContentValue = content }
    if let activity { currentActivityValue = activity }
    if let overlay { currentOverlayValue = overlay }
    if let progress { currentProgressValue = progress }
    _ = sink?.receive(
      .setPresentation(
        generation: generation,
        value: AwesomeButtonProgressPresentation(
          isBusy: isBusy ?? self.isBusy,
          showProgressVisuals: showProgressVisuals ?? self.isBusy,
          contentTransitionValue: content ?? currentContentValue,
          activityTransitionValue: activity ?? currentActivityValue,
          progressOverlayOpacity: overlay ?? currentOverlayValue,
          progressValue: progress ?? currentProgressValue,
          isPressed: isPressed,
          pressProgress: pressProgress
        )
      )
    )
  }

  private func stopAnimations() {
    contentAnimation?.stop()
    activityAnimation?.stop()
    overlayAnimation?.stop()
    valueAnimation?.stop()
    contentAnimation = nil
    activityAnimation = nil
    overlayAnimation = nil
    valueAnimation = nil
  }
}
