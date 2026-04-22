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
    private(set) var inputConfiguration: AwesomeButtonResolvedConfiguration?
    private var currentWidthMode: ButtonWidthMode?
    private var lastAcceptedPressAt: Date?
    private var isTouchActive = false
    private var isTouchInside = false
    private var currentTextTarget: String?
    private var completionConsumed = false
    private var delayedWidthWorkItem: DispatchWorkItem?
    private var delayedTextWorkItem: DispatchWorkItem?
    private var delayedClipAlignmentResetWorkItem: DispatchWorkItem?
    private var deferredProgressPressWorkItem: DispatchWorkItem?
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

    private struct DeferredAutoWidthTransition {
        let configuration: AwesomeButtonResolvedConfiguration
        let previousWidthMode: ButtonWidthMode?
    }

    // MARK: - Lifecycle

    init(measurementService: AutoWidthMeasurementService = .shared) {
        self.measurementService = measurementService
    }

    func cleanup() {
        cancelReleaseTracking()
        clearDeferredAutoWidthTransition()
        isPressed = false
        pressProgress = 0
        delayedWidthWorkItem?.cancel()
        delayedTextWorkItem?.cancel()
        delayedClipAlignmentResetWorkItem?.cancel()
        cancelProgressWork(resetState: true)
        textTransitionController?.stop()
        resetStyleTransition()
        isTouchActive = false
        isTouchInside = false
        contentClipAlignment = .center
    }

    deinit {
        delayedWidthWorkItem?.cancel()
        delayedTextWorkItem?.cancel()
        delayedClipAlignmentResetWorkItem?.cancel()
        deferredProgressPressWorkItem?.cancel()
        releaseSettleWorkItem?.cancel()
        progressContentAnimation?.stop()
        progressActivityAnimation?.stop()
        progressOverlayAnimation?.stop()
        progressValueAnimation?.stop()
        textTransitionController?.stop()
        styleTransitionKickoffWorkItem?.cancel()
        deferredAutoWidthTransition = nil
    }

    // MARK: - Rendered Configuration / Style

    func update(configuration nextConfiguration: AwesomeButtonResolvedConfiguration) {
        inputConfiguration = nextConfiguration
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

    // MARK: - Touch / Release

    func handleTouchChange(isInside: Bool) {
        guard let configuration = renderedConfiguration,
              configuration.isEffectivelyDisabled == false,
              isBusy == false else {
            return
        }

        isTouchActive = true
        isTouchInside = isInside

        if isInside {
            armPressIfNeeded(configuration: configuration)
        } else if isPressed {
            releaseVisual(configuration: configuration, notifyPressOut: true)
        }
    }

    func handleTouchEnd(isInside: Bool) {
        guard let configuration = renderedConfiguration, configuration.isEffectivelyDisabled == false else {
            return
        }

        defer {
            isTouchActive = false
            isTouchInside = false
        }

        if isBusy {
            return
        }

        if isInside && isPressed {
            configuration.onPressOut?()
            if shouldAcceptDebouncedPress(configuration: configuration) {
                lastAcceptedPressAt = Date()
                if configuration.progress {
                    if configuration.onPress != nil {
                        startProgress(configuration: configuration)
                    } else {
                        releaseVisual(configuration: configuration, notifyPressOut: false)
                    }
                } else {
                    configuration.onPress?(nil)
                    releaseVisual(configuration: configuration, notifyPressOut: false)
                }
            } else {
                releaseVisual(configuration: configuration, notifyPressOut: false)
            }
        } else {
            releaseVisual(configuration: configuration, notifyPressOut: isPressed)
        }
    }

    func handleLongPress() {
        guard let configuration = renderedConfiguration,
              configuration.isEffectivelyDisabled == false,
              isBusy == false else {
            return
        }

        configuration.onLongPress?()
    }

    private func shouldAcceptDebouncedPress(configuration: AwesomeButtonResolvedConfiguration) -> Bool {
        guard configuration.debouncedPressTime > 0, let lastAcceptedPressAt else {
            return true
        }

        return Date().timeIntervalSince(lastAcceptedPressAt) >= configuration.debouncedPressTime
    }

    private func armPressIfNeeded(configuration: AwesomeButtonResolvedConfiguration) {
        guard isPressed == false else {
            return
        }

        cancelReleaseTracking()
        clearDeferredAutoWidthTransition()
        isPressed = true
        let pressInDuration = configuration.style.pressInAnimationDuration ?? configuration.style.animationDuration ?? 0.14
        let pressCurve = configuration.style.animationCurve ?? .easeOutCubic
        withAnimation(pressCurve.animation(duration: pressInDuration)) {
            pressProgress = 1
        }
        #if canImport(UIKit)
        if configuration.hapticOnPress {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        #endif
        configuration.onPressIn?()
        configuration.onPressedIn?()
    }

    private func releaseVisual(
        configuration: AwesomeButtonResolvedConfiguration,
        notifyPressOut: Bool,
        onComplete: (() -> Void)? = nil
    ) {
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
        releaseGeneration += 1
        activeReleaseGeneration = releaseGeneration
        pendingReleaseConfiguration = configuration
        pendingReleaseCompletion = onComplete
        withAnimation(.interpolatingSpring(stiffness: 280, damping: 20)) {
            pressProgress = 0
        }

        if releaseNeedsVisualSettle {
            scheduleReleaseCompletion(for: releaseGeneration)
        } else {
            completeReleaseIfNeeded(observedPressProgress: 0, expectedGeneration: releaseGeneration)
        }
    }

    // MARK: - Progress

    private func startProgress(configuration: AwesomeButtonResolvedConfiguration) {
        cancelProgressWork(resetState: false)
        progressRunID += 1
        let runID = progressRunID
        completionConsumed = false
        isBusy = true
        cancelReleaseTracking()
        clearDeferredAutoWidthTransition()
        isPressed = true
        pressProgress = 1
        showProgressVisuals = true
        resetProgressVisualState(unmount: false)
        progressOverlayOpacity = 1
        configuration.onProgressStart?()

        animateProgressSwapIn(runID: runID)
        startProgressFill(duration: configuration.progressLoadingTime, runID: runID)

        let workItem = DispatchWorkItem { [weak self] in
            guard let self, self.progressRunID == runID, self.isBusy else {
                return
            }
            configuration.onPress?(AwesomeButtonProgressHandle { [weak self] callback in
                Task { @MainActor in
                    self?.completeProgress(callback, runID: runID)
                }
            })
            self.deferredProgressPressWorkItem = nil
        }
        deferredProgressPressWorkItem = workItem
        DispatchQueue.main.async(execute: workItem)
    }

    private func completeProgress(_ completion: (() -> Void)?, runID: Int) {
        guard renderedConfiguration != nil, isBusy, completionConsumed == false, progressRunID == runID else {
            return
        }

        completionConsumed = true

        animateProgressFillCompletion(runID: runID) { [weak self] in
            guard let self, self.progressRunID == runID else {
                return
            }
            self.animateProgressSwapOut(runID: runID) { [weak self] in
                guard let self,
                      let configuration = self.renderedConfiguration,
                      self.progressRunID == runID else {
                    return
                }
                self.releaseVisual(configuration: configuration, notifyPressOut: false) { [weak self] in
                    guard let self, self.progressRunID == runID else {
                        return
                    }
                    self.isBusy = false
                    self.showProgressVisuals = false
                    self.resetProgressVisualState(unmount: false)
                    completion?()
                    configuration.onProgressEnd?()
                }
            }
        }
    }

    private func cancelProgressWork(resetState: Bool) {
        progressRunID += 1
        deferredProgressPressWorkItem?.cancel()
        deferredProgressPressWorkItem = nil
        clearDeferredAutoWidthTransition()
        progressContentAnimation?.stop()
        progressContentAnimation = nil
        progressActivityAnimation?.stop()
        progressActivityAnimation = nil
        progressOverlayAnimation?.stop()
        progressOverlayAnimation = nil
        progressValueAnimation?.stop()
        progressValueAnimation = nil
        completionConsumed = true

        if resetState {
            self.isBusy = false
            self.showProgressVisuals = false
            self.resetProgressVisualState(unmount: true)
        }
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
        progressValueAnimation = runProgressAnimation(
            durationMs: max(0, Int((duration * 1000).rounded())),
            fromValue: 0,
            toValue: 1,
            curve: { $0 }
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
        }
    }

    private func animateProgressSwapIn(runID: Int) {
        progressContentAnimation?.stop()
        progressActivityAnimation?.stop()

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

    private func applyHeightUpdate(_ configuration: AwesomeButtonResolvedConfiguration, previousWidthMode: ButtonWidthMode?) {
        let shouldSnap = shouldSnapWidthBridge(previous: previousWidthMode, next: configuration.widthMode)
        if shouldSnap || configuration.animateSize == false {
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
           shouldAnimateStyleTransition(from: previousConfiguration, to: configuration) {
            startStyleTransition(from: currentVisualStyle(from: previousConfiguration), to: configuration.style)
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

    private func currentVisualStyle(from configuration: AwesomeButtonResolvedConfiguration) -> AwesomeButtonStyle {
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
        currentConfiguration.disabled == nextConfiguration.disabled &&
            currentConfiguration.style.visualSignature != nextConfiguration.style.visualSignature
    }

    private func startStyleTransition(from sourceStyle: AwesomeButtonStyle, to targetStyle: AwesomeButtonStyle) {
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
        let resolvedStyle = resolvedVisualStyle(style)
        let curve = resolvedStyle.animationCurve ?? AwesomeButtonThemeData.fallbackStyle.animationCurve ?? .easeOutCubic
        return curve.animation(duration: resolvedStyle.animationDuration ?? AwesomeButtonThemeData.fallbackStyle.animationDuration)
    }

    // MARK: - Width / Text

    private func applyWidthAndTextUpdate(_ configuration: AwesomeButtonResolvedConfiguration, previousWidthMode: ButtonWidthMode?) {
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
            if shouldSnapWidthBridge(previous: previousWidthMode, next: .fixed) || configuration.animateSize == false {
                resolvedWidth = configuration.width
            } else if abs((resolvedWidth ?? 0) - (configuration.width ?? 0)) >= 0.5 {
                withAnimation(sizeAnimation()) {
                    resolvedWidth = configuration.width
                }
            }
            syncTextTransitionState(configuration)
        case .auto:
            let targetWidth = configuration.measurementSignature.map {
                measurementService.measureWidth(for: $0)
            }
            let currentWidth = shouldSnapWidthBridge(previous: previousWidthMode, next: .auto) ? nil : resolvedWidth
            let plan = resolveAutoWidthTextUpdatePlan(
                isEligible: configuration.isAutoWidthTextEligible,
                targetText: configuration.childText,
                currentWidth: currentWidth,
                targetWidth: targetWidth,
                displayedText: displayedText,
                animateSize: configuration.animateSize,
                textTransition: configuration.textTransition,
                slotStaggerMs: configuration.textTransitionSlotStaggerMs
            )
            executeAutoWidthTextUpdatePlan(plan, configuration: configuration)
        }
    }

    private func executeAutoWidthTextUpdatePlan(
        _ plan: AutoWidthTextUpdatePlan,
        configuration: AwesomeButtonResolvedConfiguration
    ) {
        if case .fallbackToTextSync = plan {
            contentClipAlignment = .center
            resolvedWidth = nil
            syncTextTransitionState(configuration)
            return
        }

        sizeRunID += 1
        let runID = sizeRunID

        switch plan {
        case .fallbackToTextSync:
            return
        case let .initial(targetText, targetWidth):
            contentClipAlignment = .center
            currentTextTarget = targetText
            resolvedWidth = targetWidth
            displayedText = targetText
        case let .textOnly(sourceText, targetText, animateText):
            contentClipAlignment = .center
            currentTextTarget = targetText
            if animateText {
                runStringTransition(from: sourceText, to: targetText, runID: runID)
            } else {
                displayedText = targetText
            }
        case let .growFirst(sourceText, targetText, targetWidth, timing, animateSize, animateText):
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
        case let .shrinkLast(sourceText, targetText, targetWidth, timing, animateSize, animateText):
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
        case let .assign(nextText):
            currentTextTarget = nextText
            displayedText = nextText
        case .keep:
            return
        case let .transition(sourceText, targetText):
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
        textTransitionController = runTextTransition(
            fromText: source,
            targetText: target,
            slotStaggerMs: renderedConfiguration?.textTransitionSlotStaggerMs ??
                inputConfiguration?.textTransitionSlotStaggerMs ??
                defaultTextTransitionSlotStaggerMs
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
              abs(observedPressProgress) <= 0.001 else {
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
        completion?()
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
            measurementService.measureWidth(for: $0)
        }
        return shouldDeferReleaseAutoWidthTransition(
            isReleaseActive: activeReleaseGeneration != nil,
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
