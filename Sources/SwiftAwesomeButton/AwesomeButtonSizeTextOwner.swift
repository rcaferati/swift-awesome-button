import SwiftUI

internal struct AwesomeButtonSizeTextInput {
  let childText: String?
  let widthMode: ButtonWidthMode
  let width: CGFloat?
  let height: CGFloat
  let animateSize: Bool
  let textTransition: Bool
  let textTransitionSlotStaggerMs: Int
  let reduceMotion: Bool
  let isAutoWidthTextEligible: Bool
  let measurementSignature: AutoWidthMeasurementSignature?

  init(configuration: AwesomeButtonResolvedConfiguration) {
    childText = configuration.childText
    widthMode = configuration.widthMode
    width = configuration.width
    height = configuration.height
    animateSize = configuration.animateSize
    textTransition = configuration.textTransition
    textTransitionSlotStaggerMs = configuration.textTransitionSlotStaggerMs
    reduceMotion = configuration.reduceMotion
    isAutoWidthTextEligible = configuration.isAutoWidthTextEligible
    measurementSignature = configuration.measurementSignature
  }
}

internal struct AwesomeButtonSizeTextPresentation {
  let displayedText: String?
  let resolvedWidth: CGFloat?
  let resolvedHeight: CGFloat
}

internal enum AwesomeButtonSizeTransition {
  case immediate
  case animated(duration: TimeInterval)
}

internal enum AwesomeButtonSizeTextCommand {
  case setDisplayedText(generation: Int, value: String?)
  case setWidth(generation: Int, value: CGFloat?, transition: AwesomeButtonSizeTransition)
  case setHeight(generation: Int, value: CGFloat, transition: AwesomeButtonSizeTransition)
  case setMeasuredContentHeight(
    generation: Int,
    value: CGFloat,
    transition: AwesomeButtonSizeTransition
  )
  case setClipAlignment(generation: Int, value: ContentClipAlignment)
  case reportMeasuredAutoWidth(generation: Int, value: CGFloat)

  var generation: Int {
    switch self {
    case .setDisplayedText(let generation, _),
      .setWidth(let generation, _, _),
      .setHeight(let generation, _, _),
      .setMeasuredContentHeight(let generation, _, _),
      .setClipAlignment(let generation, _),
      .reportMeasuredAutoWidth(let generation, _):
      return generation
    }
  }
}

@MainActor
internal final class AwesomeButtonSizeTextOwner {
  private let measurementService: AutoWidthMeasurementService
  private weak var sink: AwesomeButtonControllerCommandSink?
  private var delayedWidthWorkItem: DispatchWorkItem?
  private var delayedTextWorkItem: DispatchWorkItem?
  private var delayedClipAlignmentResetWorkItem: DispatchWorkItem?
  private var textTransitionController: TextTransitionControlling?
  private var textTransitionIsActive = false
  private var latestInput: AwesomeButtonSizeTextInput?
  private var currentTextTarget: String?
  private(set) var currentWidthMode: ButtonWidthMode?
  private(set) var generation = 0
  private var deferralToken = 0
  private var activeDeferralToken: Int?

  init(
    measurementService: AutoWidthMeasurementService,
    sink: AwesomeButtonControllerCommandSink
  ) {
    self.measurementService = measurementService
    self.sink = sink
  }

  func connect(to sink: AwesomeButtonControllerCommandSink) {
    self.sink = sink
  }

  func update(
    input: AwesomeButtonSizeTextInput,
    previousWidthMode: ButtonWidthMode?,
    presentation: AwesomeButtonSizeTextPresentation
  ) {
    let preservesTextTransition = shouldPreserveTextTransition(for: input)
    cancelGeometryWork()
    if !preservesTextTransition {
      cancelTextWork()
      generation += 1
    }
    latestInput = input
    currentWidthMode = input.widthMode
    activeDeferralToken = nil
    let generation = generation

    applyHeight(
      input: input,
      previousWidthMode: previousWidthMode,
      presentation: presentation,
      generation: generation
    )
    applyWidthAndText(
      input: input,
      previousWidthMode: previousWidthMode,
      presentation: presentation,
      generation: generation,
      preservesTextTransition: preservesTextTransition
    )
  }

  func beginDeferral(if shouldDefer: Bool) -> Int? {
    guard shouldDefer else {
      activeDeferralToken = nil
      return nil
    }

    deferralToken += 1
    activeDeferralToken = deferralToken
    return deferralToken
  }

  func measuredTargetWidth(for input: AwesomeButtonSizeTextInput) -> CGFloat? {
    input.measurementSignature.map {
      max(input.height, measurementService.measureWidth(for: $0))
    }
  }

  func consumeDeferralToken() -> Int? {
    defer { activeDeferralToken = nil }
    return activeDeferralToken
  }

  func clearDeferral() {
    activeDeferralToken = nil
  }

  func updateMeasuredAutoWidth(
    _ measuredWidth: CGFloat,
    input: AwesomeButtonSizeTextInput,
    currentWidth: CGFloat?
  ) {
    latestInput = input

    // Plain-string auto width is resolved from the accepted target label before
    // its transition begins. The rendered row contains temporary scramble
    // frames while that transition is active, so treating those measurements as
    // new targets would continuously retarget the width animation. Arbitrary
    // content and auxiliary-slot rows have no deterministic string signature and
    // continue to use their single rendered row as the source of truth.
    if input.isAutoWidthTextEligible, input.measurementSignature != nil {
      return
    }

    let targetWidth = max(input.height, measuredWidth)
    guard targetWidth.isFinite, targetWidth > 0 else { return }
    _ = sink?.receive(.reportMeasuredAutoWidth(generation: generation, value: targetWidth))
    guard input.widthMode == .auto else { return }

    guard let currentWidth else {
      _ = sink?.receive(
        .setWidth(generation: generation, value: targetWidth, transition: .immediate)
      )
      return
    }
    guard abs(currentWidth - targetWidth) >= 0.5 else { return }
    let transition: AwesomeButtonSizeTransition =
      input.animateSize && input.reduceMotion == false
      ? .animated(duration: sizeAnimationDuration)
      : .immediate
    _ = sink?.receive(
      .setWidth(generation: generation, value: targetWidth, transition: transition)
    )
  }

  func updateMeasuredContentHeight(
    _ measuredHeight: CGFloat,
    input: AwesomeButtonSizeTextInput,
    currentHeight: CGFloat
  ) {
    latestInput = input
    guard measuredHeight.isFinite, measuredHeight >= 0 else { return }
    let target = max(input.height, measuredHeight)
    guard abs(currentHeight - target) >= 0.5 else { return }
    let transition: AwesomeButtonSizeTransition =
      input.animateSize && input.reduceMotion == false
      ? .animated(duration: sizeAnimationDuration)
      : .immediate
    _ = sink?.receive(
      .setMeasuredContentHeight(
        generation: generation,
        value: target,
        transition: transition
      )
    )
  }

  func isCurrent(_ generation: Int) -> Bool {
    self.generation == generation
  }

  func cleanup() {
    generation += 1
    cancelTransitionWork()
    activeDeferralToken = nil
    latestInput = nil
    currentWidthMode = nil
    currentTextTarget = nil
    sink = nil
  }

  private func applyHeight(
    input: AwesomeButtonSizeTextInput,
    previousWidthMode: ButtonWidthMode?,
    presentation: AwesomeButtonSizeTextPresentation,
    generation: Int
  ) {
    let shouldSnap = shouldSnapWidthBridge(previous: previousWidthMode, next: input.widthMode)
    let transition: AwesomeButtonSizeTransition =
      shouldSnap || input.animateSize == false || input.reduceMotion
      ? .immediate
      : .animated(duration: sizeAnimationDuration)
    if transition.isImmediate || abs(presentation.resolvedHeight - input.height) >= 0.5 {
      _ = sink?.receive(
        .setHeight(generation: generation, value: input.height, transition: transition)
      )
    }
  }

  private func applyWidthAndText(
    input: AwesomeButtonSizeTextInput,
    previousWidthMode: ButtonWidthMode?,
    presentation: AwesomeButtonSizeTextPresentation,
    generation: Int,
    preservesTextTransition: Bool
  ) {
    switch input.widthMode {
    case .stretch:
      setClip(.center, generation: generation)
      setWidth(nil, transition: .immediate, generation: generation)
      if !preservesTextTransition {
        syncText(input: input, displayedText: presentation.displayedText, generation: generation)
      }
    case .fixed:
      setClip(.center, generation: generation)
      let shouldSnap = shouldSnapWidthBridge(previous: previousWidthMode, next: .fixed)
      if shouldSnap || input.animateSize == false || input.reduceMotion {
        setWidth(input.width, transition: .immediate, generation: generation)
      } else if abs((presentation.resolvedWidth ?? 0) - (input.width ?? 0)) >= 0.5 {
        setWidth(
          input.width,
          transition: .animated(duration: sizeAnimationDuration),
          generation: generation
        )
      }
      if !preservesTextTransition {
        syncText(input: input, displayedText: presentation.displayedText, generation: generation)
      }
    case .auto:
      let targetWidth = input.measurementSignature.map {
        max(input.height, measurementService.measureWidth(for: $0))
      }
      if let targetWidth {
        _ = sink?.receive(
          .reportMeasuredAutoWidth(generation: generation, value: targetWidth)
        )
      }
      if preservesTextTransition {
        if let targetWidth,
          abs((presentation.resolvedWidth ?? 0) - targetWidth) >= 0.5
        {
          setWidth(
            targetWidth,
            transition: input.animateSize && !input.reduceMotion
              ? .animated(duration: sizeAnimationDuration)
              : .immediate,
            generation: generation
          )
        }
        return
      }
      let currentWidth =
        shouldSnapWidthBridge(previous: previousWidthMode, next: .auto)
        ? nil
        : presentation.resolvedWidth
      let plan = resolveAutoWidthTextUpdatePlan(
        isEligible: input.isAutoWidthTextEligible,
        targetText: input.childText,
        currentWidth: currentWidth,
        targetWidth: targetWidth,
        displayedText: presentation.displayedText,
        animateSize: input.animateSize && input.reduceMotion == false,
        textTransition: input.textTransition && input.reduceMotion == false,
        slotStaggerMs: input.textTransitionSlotStaggerMs
      )
      execute(plan: plan, input: input, presentation: presentation, generation: generation)
    }
  }

  private func execute(
    plan: AutoWidthTextUpdatePlan,
    input: AwesomeButtonSizeTextInput,
    presentation: AwesomeButtonSizeTextPresentation,
    generation: Int
  ) {
    switch plan {
    case .fallbackToTextSync:
      setClip(.center, generation: generation)
      setWidth(
        max(input.height, presentation.resolvedWidth ?? 0),
        transition: .immediate,
        generation: generation
      )
      syncText(input: input, displayedText: presentation.displayedText, generation: generation)
    case .initial(let targetText, let targetWidth):
      setClip(.center, generation: generation)
      currentTextTarget = targetText
      setWidth(targetWidth, transition: .immediate, generation: generation)
      setText(targetText, generation: generation)
    case .textOnly(let sourceText, let targetText, let animateText):
      setClip(.center, generation: generation)
      currentTextTarget = targetText
      if animateText {
        runStringTransition(from: sourceText, to: targetText, generation: generation)
      } else {
        setText(targetText, generation: generation)
      }
    case .growFirst(
      let sourceText,
      let targetText,
      let targetWidth,
      let timing,
      let animateSize,
      let animateText
    ):
      setClip(.center, generation: generation)
      currentTextTarget = targetText
      setWidth(
        targetWidth,
        transition: animateSize
          ? .animated(duration: animateText ? timing.widthDuration : sizeAnimationDuration)
          : .immediate,
        generation: generation
      )
      scheduleText(
        sourceText: sourceText,
        targetText: targetText,
        animateText: animateText,
        delay: animateSize ? (animateText ? timing.textDelay : sizeAnimationDuration) : 0,
        generation: generation
      )
    case .shrinkLast(
      let sourceText,
      let targetText,
      let targetWidth,
      let timing,
      let animateSize,
      let animateText
    ):
      currentTextTarget = targetText
      if animateText {
        setClip(.leading, generation: generation)
        runStringTransition(
          from: sourceText,
          to: targetText,
          generation: generation,
          onComplete: { [weak self] in
            guard let self, self.generation == generation, animateSize == false else { return }
            self.setClip(.center, generation: generation)
          }
        )
        scheduleWidth(
          targetWidth,
          animate: animateSize,
          delay: animateSize ? timing.widthDelay : 0,
          duration: timing.widthDuration,
          generation: generation
        )
        if animateSize {
          scheduleClipReset(
            delay: timing.widthDelay + timing.widthDuration,
            generation: generation
          )
        }
      } else {
        setClip(.center, generation: generation)
        setText(targetText, generation: generation)
        setWidth(
          targetWidth,
          transition: animateSize
            ? .animated(duration: sizeAnimationDuration)
            : .immediate,
          generation: generation
        )
      }
    }
  }

  private func syncText(
    input: AwesomeButtonSizeTextInput,
    displayedText: String?,
    generation: Int
  ) {
    switch resolveButtonTextUpdatePlan(
      textTransitionEnabled: input.textTransition,
      nextText: input.childText,
      currentTarget: currentTextTarget,
      displayedText: displayedText,
      transitionActive: textTransitionIsActive
    ) {
    case .assign(let nextText):
      currentTextTarget = nextText
      setText(nextText, generation: generation)
    case .keep:
      return
    case .transition(let sourceText, let targetText):
      currentTextTarget = targetText
      runStringTransition(from: sourceText, to: targetText, generation: generation)
    }
  }

  private func scheduleText(
    sourceText: String,
    targetText: String,
    animateText: Bool,
    delay: TimeInterval,
    generation: Int
  ) {
    if animateText {
      textTransitionIsActive = true
    }
    let workItem = DispatchWorkItem { [weak self] in
      guard let self, self.generation == generation else { return }
      self.delayedTextWorkItem = nil
      if animateText {
        self.runStringTransition(from: sourceText, to: targetText, generation: generation)
      } else {
        self.textTransitionIsActive = false
        self.setText(targetText, generation: generation)
      }
    }
    delayedTextWorkItem = workItem
    DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
  }

  private func scheduleWidth(
    _ width: CGFloat,
    animate: Bool,
    delay: TimeInterval,
    duration: TimeInterval,
    generation: Int
  ) {
    let workItem = DispatchWorkItem { [weak self] in
      guard let self, self.generation == generation else { return }
      self.setWidth(
        width,
        transition: animate ? .animated(duration: duration) : .immediate,
        generation: generation
      )
    }
    delayedWidthWorkItem = workItem
    DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
  }

  private func scheduleClipReset(delay: TimeInterval, generation: Int) {
    let workItem = DispatchWorkItem { [weak self] in
      guard let self, self.generation == generation else { return }
      self.setClip(.center, generation: generation)
    }
    delayedClipAlignmentResetWorkItem = workItem
    DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
  }

  private func runStringTransition(
    from source: String,
    to target: String,
    generation: Int,
    onComplete: (() -> Void)? = nil
  ) {
    guard let latestInput else { return }
    if latestInput.reduceMotion {
      textTransitionIsActive = false
      setText(target, generation: generation)
      onComplete?()
      return
    }
    textTransitionIsActive = true
    textTransitionController = runTextTransition(
      fromText: source,
      targetText: target,
      slotStaggerMs: latestInput.textTransitionSlotStaggerMs
    ) { [weak self] current in
      guard let self, self.generation == generation else { return }
      self.setText(current, generation: generation)
    } onComplete: { [weak self] in
      guard let self, self.generation == generation else { return }
      self.textTransitionIsActive = false
      self.textTransitionController = nil
      self.setText(target, generation: generation)
      onComplete?()
    }
  }

  private func setText(_ text: String?, generation: Int) {
    _ = sink?.receive(.setDisplayedText(generation: generation, value: text))
  }

  private func setWidth(
    _ width: CGFloat?,
    transition: AwesomeButtonSizeTransition,
    generation: Int
  ) {
    _ = sink?.receive(
      .setWidth(generation: generation, value: width, transition: transition)
    )
  }

  private func setClip(_ alignment: ContentClipAlignment, generation: Int) {
    _ = sink?.receive(.setClipAlignment(generation: generation, value: alignment))
  }

  private func shouldPreserveTextTransition(for input: AwesomeButtonSizeTextInput) -> Bool {
    guard textTransitionIsActive,
      input.textTransition,
      !input.reduceMotion,
      input.childText == currentTextTarget,
      input.widthMode == latestInput?.widthMode,
      input.textTransitionSlotStaggerMs == latestInput?.textTransitionSlotStaggerMs
    else { return false }
    return true
  }

  private func cancelGeometryWork() {
    delayedWidthWorkItem?.cancel()
    delayedWidthWorkItem = nil
    delayedClipAlignmentResetWorkItem?.cancel()
    delayedClipAlignmentResetWorkItem = nil
  }

  private func cancelTextWork() {
    delayedTextWorkItem?.cancel()
    delayedTextWorkItem = nil
    textTransitionController?.stop()
    textTransitionController = nil
    textTransitionIsActive = false
  }

  private func cancelTransitionWork() {
    cancelGeometryWork()
    cancelTextWork()
  }
}

extension AwesomeButtonSizeTransition {
  fileprivate var isImmediate: Bool {
    if case .immediate = self { return true }
    return false
  }
}
