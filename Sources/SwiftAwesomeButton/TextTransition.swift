import Foundation
#if canImport(QuartzCore)
import QuartzCore
#endif

internal let defaultTextTransitionSlotStaggerMs = 7
internal let defaultTextTransitionRandomizeStartStaggerMs = defaultTextTransitionSlotStaggerMs
internal let defaultTextTransitionExpandStaggerMs = defaultTextTransitionSlotStaggerMs
internal let textTransitionPostRandomizeHoldMs = 10
internal let defaultTextTransitionCollapseStaggerMs = defaultTextTransitionSlotStaggerMs
internal let textTransitionRefreshMs = 16

private enum LetterWidthGroup {
    case narrow
    case average
    case wide
}

private let narrowLowercaseLetters = Array("iljtfr")
private let averageLowercaseLetters = Array("acesuvxznho")
private let wideLowercaseLetters = Array("mwdbpqgy")
private let lowercaseLetters = Array("abcdefghijklmnopqrstuvwxyz")
private let uppercaseLetters = lowercaseLetters.map {
    Character(String($0).uppercased())
}
private let narrowUppercaseLetters = narrowLowercaseLetters.map {
    Character(String($0).uppercased())
}
private let averageUppercaseLetters = averageLowercaseLetters.map {
    Character(String($0).uppercased())
}
private let wideUppercaseLetters = wideLowercaseLetters.map {
    Character(String($0).uppercased())
}
private let digits = Array("0123456789")
private let symbols = Array("#%&^+=-")

internal struct TextTransitionTimeline {
    let sourceLength: Int
    let targetLength: Int
    let maxLength: Int
    let slotStaggerMs: Int
    let lastSourceRandomizeStartMs: Int
    let lastRandomizeStartMs: Int
    let collapseStartMs: Int
    let totalDurationMs: Int
}

internal struct AutoWidthTextTransitionTiming {
    let widthDelay: TimeInterval
    let textDelay: TimeInterval
    let widthDuration: TimeInterval
}

internal protocol TextTransitionControlling: AnyObject {
    func stop()
}

internal final class NoopTextTransitionController: TextTransitionControlling {
    func stop() {}
}

internal func normalizeTextTransitionSlotStaggerMs(_ slotStaggerMs: Int) -> Int {
    max(1, slotStaggerMs)
}

internal func getTextTransitionRandomizeStartMs(
    index: Int,
    sourceLength: Int,
    targetLength: Int,
    slotStaggerMs: Int
) -> Int? {
    let slotStaggerMs = normalizeTextTransitionSlotStaggerMs(slotStaggerMs)

    if index < sourceLength {
        return index * slotStaggerMs
    }

    if index < targetLength {
        let lastSourceStartMs = sourceLength > 0 ? (sourceLength - 1) * slotStaggerMs : 0
        return lastSourceStartMs + ((index - sourceLength + 1) * slotStaggerMs)
    }

    return nil
}

internal func getTextTransitionTimeline(
    fromText: String,
    targetText: String,
    slotStaggerMs: Int = defaultTextTransitionSlotStaggerMs
) -> TextTransitionTimeline {
    let sourceLength = fromText.count
    let targetLength = targetText.count
    let maxLength = max(sourceLength, targetLength)
    let normalizedSlotStaggerMs = normalizeTextTransitionSlotStaggerMs(slotStaggerMs)
    let lastSourceRandomizeStartMs = sourceLength > 0 ? (sourceLength - 1) * normalizedSlotStaggerMs : 0
    let lastRandomizeStartMs = maxLength == 0 ? 0 : (getTextTransitionRandomizeStartMs(
        index: maxLength - 1,
        sourceLength: sourceLength,
        targetLength: targetLength,
        slotStaggerMs: normalizedSlotStaggerMs
    ) ?? 0)
    let collapseStartMs = lastRandomizeStartMs + textTransitionPostRandomizeHoldMs
    let totalDurationMs = maxLength == 0 ? 0 : collapseStartMs + ((maxLength - 1) * normalizedSlotStaggerMs)

    return TextTransitionTimeline(
        sourceLength: sourceLength,
        targetLength: targetLength,
        maxLength: maxLength,
        slotStaggerMs: normalizedSlotStaggerMs,
        lastSourceRandomizeStartMs: lastSourceRandomizeStartMs,
        lastRandomizeStartMs: lastRandomizeStartMs,
        collapseStartMs: collapseStartMs,
        totalDurationMs: totalDurationMs
    )
}

internal func getTextTransitionCollapseMs(index: Int, timeline: TextTransitionTimeline) -> Int {
    if timeline.targetLength >= timeline.sourceLength {
        return timeline.collapseStartMs + (index * timeline.slotStaggerMs)
    }

    let extraCount = timeline.sourceLength - timeline.targetLength

    if index >= timeline.targetLength {
        let extraIndex = index - timeline.targetLength
        let reverseExtraIndex = max(0, (extraCount - 1) - extraIndex)
        return timeline.collapseStartMs + (reverseExtraIndex * timeline.slotStaggerMs)
    }

    return timeline.collapseStartMs + (extraCount * timeline.slotStaggerMs) + (index * timeline.slotStaggerMs)
}

private func getLetterWidthGroup(character: Character) -> LetterWidthGroup? {
    guard let lowercasedCharacter = String(character).lowercased().first else {
        return nil
    }

    if narrowLowercaseLetters.contains(lowercasedCharacter) {
        return .narrow
    }

    if averageLowercaseLetters.contains(lowercasedCharacter) {
        return .average
    }

    if wideLowercaseLetters.contains(lowercasedCharacter) {
        return .wide
    }

    return nil
}

internal func getTextTransitionCharset(character: Character) -> [Character]? {
    if character.isWhitespace {
        return nil
    }

    if character.isNumber {
        return digits
    }

    if character.isLetter, character.isUppercase {
        switch getLetterWidthGroup(character: character) {
        case .narrow:
            return narrowUppercaseLetters
        case .average:
            return averageUppercaseLetters
        case .wide:
            return wideUppercaseLetters
        case nil:
            return uppercaseLetters
        }
    }

    if character.isLetter, character.isLowercase {
        switch getLetterWidthGroup(character: character) {
        case .narrow:
            return narrowLowercaseLetters
        case .average:
            return averageLowercaseLetters
        case .wide:
            return wideLowercaseLetters
        case nil:
            return lowercaseLetters
        }
    }

    return symbols
}

internal func getRandomTransitionCharacter(
    character: Character,
    random: () -> Double = { Double.random(in: 0..<1) }
) -> Character {
    guard let charset = getTextTransitionCharset(character: character) else {
        return character
    }

    let index = min(charset.count - 1, Int((random() * Double(charset.count)).rounded(.down)))
    return charset[index]
}

internal func buildTextTransitionFrame(
    fromText: String,
    targetText: String,
    elapsedMs: Int,
    slotStaggerMs: Int = defaultTextTransitionSlotStaggerMs,
    random: () -> Double = { Double.random(in: 0..<1) }
) -> String {
    if fromText.isEmpty {
        return targetText
    }

    if fromText == targetText {
        return targetText
    }

    if elapsedMs <= 0 {
        return fromText
    }

    let timeline = getTextTransitionTimeline(
        fromText: fromText,
        targetText: targetText,
        slotStaggerMs: slotStaggerMs
    )
    if elapsedMs >= timeline.totalDurationMs {
        return targetText
    }

    let source = Array(fromText).map(String.init)
    let target = Array(targetText).map(String.init)

    return (0..<timeline.maxLength).map { index in
        let randomizeStartMs = getTextTransitionRandomizeStartMs(
            index: index,
            sourceLength: timeline.sourceLength,
            targetLength: timeline.targetLength,
            slotStaggerMs: timeline.slotStaggerMs
        )
        let collapseMs = getTextTransitionCollapseMs(index: index, timeline: timeline)
        let sourceCharacter = index < source.count ? source[index] : ""
        let targetCharacter = index < target.count ? target[index] : ""
        let randomSourceCharacter = index >= timeline.sourceLength ? targetCharacter : sourceCharacter

        if randomizeStartMs == nil || elapsedMs < randomizeStartMs! {
            return sourceCharacter
        }

        if elapsedMs >= collapseMs {
            return targetCharacter
        }

        guard let transitionCharacter = randomSourceCharacter.first else {
            return ""
        }

        return String(getRandomTransitionCharacter(character: transitionCharacter, random: random))
    }.joined()
}

internal func resolveAutoWidthTextTransitionTiming(
    fromText: String,
    targetText: String,
    flow: AutoWidthTextFlow,
    slotStaggerMs: Int = defaultTextTransitionSlotStaggerMs
) -> AutoWidthTextTransitionTiming {
    let timeline = getTextTransitionTimeline(
        fromText: fromText,
        targetText: targetText,
        slotStaggerMs: slotStaggerMs
    )
    let totalDuration = Double(timeline.totalDurationMs) / 1000
    let startOffset = totalDuration * 0.3

    switch flow {
    case .growFirst:
        return AutoWidthTextTransitionTiming(
            widthDelay: 0,
            textDelay: startOffset,
            widthDuration: totalDuration
        )
    case .shrinkLast:
        return AutoWidthTextTransitionTiming(
            widthDelay: startOffset,
            textDelay: 0,
            widthDuration: totalDuration
        )
    case .initial, .textOnly:
        return AutoWidthTextTransitionTiming(widthDelay: 0, textDelay: 0, widthDuration: 0)
    }
}

internal final class FrameTextTransitionController: TextTransitionControlling {
    private let timeline: TextTransitionTimeline
    private let fromText: String
    private let targetText: String
    private let onUpdate: (String) -> Void
    private let onComplete: (() -> Void)?
    private let random: () -> Double
    private var displayLink: CADisplayLink?
    private var startTimestamp: CFTimeInterval?
    private var lastPublishedValue: String?
    private lazy var proxy: DisplayLinkProxy = {
        let proxy = DisplayLinkProxy()
        proxy.controller = self
        return proxy
    }()

    init(
        timeline: TextTransitionTimeline,
        fromText: String,
        targetText: String,
        onUpdate: @escaping (String) -> Void,
        onComplete: (() -> Void)?,
        random: @escaping () -> Double
    ) {
        self.timeline = timeline
        self.fromText = fromText
        self.targetText = targetText
        self.onUpdate = onUpdate
        self.onComplete = onComplete
        self.random = random
    }

    func start() {
        stop()
        startTimestamp = nil
        lastPublishedValue = nil
        let displayLink = CADisplayLink(target: proxy, selector: #selector(DisplayLinkProxy.handleTick(_:)))
        displayLink.add(to: .main, forMode: .common)
        self.displayLink = displayLink
    }

    func stop() {
        displayLink?.invalidate()
        displayLink = nil
    }

    fileprivate func tick(timestamp: CFTimeInterval) {
        if startTimestamp == nil {
            startTimestamp = timestamp
        }
        let elapsedMs = min(
            timeline.totalDurationMs,
            Int((timestamp - (startTimestamp ?? timestamp)) * 1000)
        )

        let nextValue = buildTextTransitionFrame(
            fromText: fromText,
            targetText: targetText,
            elapsedMs: elapsedMs,
            slotStaggerMs: timeline.slotStaggerMs,
            random: random
        )

        if nextValue != lastPublishedValue {
            lastPublishedValue = nextValue
            onUpdate(nextValue)
        }

        if elapsedMs >= timeline.totalDurationMs {
            onComplete?()
            stop()
            return
        }
    }
}

private final class DisplayLinkProxy: NSObject {
    weak var controller: FrameTextTransitionController?

    @objc func handleTick(_ displayLink: CADisplayLink) {
        controller?.tick(timestamp: displayLink.timestamp)
    }
}

@discardableResult
internal func runTextTransition(
    fromText: String,
    targetText: String,
    slotStaggerMs: Int = defaultTextTransitionSlotStaggerMs,
    onUpdate: @escaping (String) -> Void,
    onComplete: (() -> Void)? = nil,
    random: @escaping () -> Double = { Double.random(in: 0..<1) }
) -> TextTransitionControlling {
    let timeline = getTextTransitionTimeline(
        fromText: fromText,
        targetText: targetText,
        slotStaggerMs: slotStaggerMs
    )
    if fromText.isEmpty || targetText.isEmpty || fromText == targetText {
        onUpdate(targetText)
        onComplete?()
        return NoopTextTransitionController()
    }

    let controller = FrameTextTransitionController(
        timeline: timeline,
        fromText: fromText,
        targetText: targetText,
        onUpdate: onUpdate,
        onComplete: onComplete,
        random: random
    )
    controller.start()
    return controller
}
