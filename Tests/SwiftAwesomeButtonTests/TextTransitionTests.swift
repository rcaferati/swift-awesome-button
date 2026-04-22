import XCTest
@testable import SwiftAwesomeButton

final class TextTransitionTests: XCTestCase {
    private let lowercaseNarrowPool = Array("iljtfr")
    private let lowercaseAveragePool = Array("acesuvxznho")
    private let lowercaseWidePool = Array("mwdbpqgy")
    private let uppercaseNarrowPool = Array("ILJTFR")
    private let uppercaseAveragePool = Array("ACESUVXZNHO")
    private let uppercaseWidePool = Array("MWDBPQGY")

    func testExpandAndCollapseUseTheSamePerSlotCadence() {
        XCTAssertEqual(defaultTextTransitionSlotStaggerMs, 7)
        XCTAssertEqual(defaultTextTransitionRandomizeStartStaggerMs, 7)
        XCTAssertEqual(defaultTextTransitionExpandStaggerMs, 7)
        XCTAssertEqual(defaultTextTransitionCollapseStaggerMs, 7)
    }

    func testCustomSlotStaggerChangesTimeline() {
        let timeline = getTextTransitionTimeline(fromText: "aaaa", targetText: "aaaa aaaa", slotStaggerMs: 12)

        XCTAssertEqual(timeline.slotStaggerMs, 12)
        XCTAssertEqual(timeline.lastSourceRandomizeStartMs, 36)
        XCTAssertEqual(timeline.lastRandomizeStartMs, 96)
        XCTAssertEqual(timeline.collapseStartMs, 106)
        XCTAssertEqual(timeline.totalDurationMs, 202)
    }

    func testPreservesSpacesWhileScramblingAndUsesTheCorrectCharacterPools() {
        let frame = buildTextTransitionFrame(fromText: "A a0#", targetText: "B b1?", elapsedMs: 20, random: { 0.5 })

        XCTAssertEqual(Array(frame)[1], " ")
        XCTAssertTrue(uppercaseAveragePool.contains(getRandomTransitionCharacter(character: "A", random: { 0.4 })))
        XCTAssertTrue(lowercaseAveragePool.contains(getRandomTransitionCharacter(character: "z", random: { 0.4 })))
        XCTAssertTrue(String(getRandomTransitionCharacter(character: "4", random: { 0.4 })).range(of: "[0-9]", options: .regularExpression) != nil)
        XCTAssertTrue(String(getRandomTransitionCharacter(character: "#", random: { 0.4 })).range(of: "[#%&^+=-]", options: .regularExpression) != nil)
    }

    func testLetterRandomizationStaysInsideConfiguredWidthGroups() {
        XCTAssertTrue(lowercaseNarrowPool.contains(getRandomTransitionCharacter(character: "i", random: { 0.99 })))
        XCTAssertTrue(lowercaseAveragePool.contains(getRandomTransitionCharacter(character: "a", random: { 0.99 })))
        XCTAssertTrue(lowercaseWidePool.contains(getRandomTransitionCharacter(character: "m", random: { 0.99 })))

        XCTAssertTrue(uppercaseNarrowPool.contains(getRandomTransitionCharacter(character: "I", random: { 0.99 })))
        XCTAssertTrue(uppercaseAveragePool.contains(getRandomTransitionCharacter(character: "A", random: { 0.99 })))
        XCTAssertTrue(uppercaseWidePool.contains(getRandomTransitionCharacter(character: "M", random: { 0.99 })))
    }

    func testUnexpectedLettersFallBackToTheFullCasePool() {
        let lowercaseFallback = getRandomTransitionCharacter(character: "é", random: { 0.99 })
        let uppercaseFallback = getRandomTransitionCharacter(character: "É", random: { 0.99 })

        XCTAssertTrue(String(lowercaseFallback).range(of: "[a-z]", options: .regularExpression) != nil)
        XCTAssertTrue(String(uppercaseFallback).range(of: "[A-Z]", options: .regularExpression) != nil)
    }

    func testRandomizesCurrentSlotsFirstExpandsThenCollapsesLeftToRight() {
        let timeline = getTextTransitionTimeline(fromText: "hello", targetText: "welcome2")

        XCTAssertEqual(timeline.lastSourceRandomizeStartMs, 28)
        XCTAssertEqual(timeline.lastRandomizeStartMs, 49)
        XCTAssertEqual(timeline.collapseStartMs, 59)
        XCTAssertEqual(timeline.totalDurationMs, 108)
        XCTAssertEqual(getTextTransitionRandomizeStartMs(index: 4, sourceLength: 5, targetLength: 8, slotStaggerMs: 7), 28)
        XCTAssertEqual(getTextTransitionRandomizeStartMs(index: 5, sourceLength: 5, targetLength: 8, slotStaggerMs: 7), 35)
        XCTAssertEqual(getTextTransitionRandomizeStartMs(index: 7, sourceLength: 5, targetLength: 8, slotStaggerMs: 7), 49)

        XCTAssertEqual(buildTextTransitionFrame(fromText: "hello", targetText: "welcome2", elapsedMs: 34, random: { 0 }).count, 5)
        XCTAssertEqual(buildTextTransitionFrame(fromText: "hello", targetText: "welcome2", elapsedMs: 35, random: { 0 }).count, 6)
        XCTAssertEqual(buildTextTransitionFrame(fromText: "hello", targetText: "welcome2", elapsedMs: 49, random: { 0 }).count, 8)
        XCTAssertNotEqual(buildTextTransitionFrame(fromText: "hello", targetText: "welcome2", elapsedMs: 58, random: { 0 }).first, "w")
        XCTAssertEqual(buildTextTransitionFrame(fromText: "hello", targetText: "welcome2", elapsedMs: 59, random: { 0 }).first, "w")
    }

    func testCollapsesTrailingSourceSlotsFromTheRightBeforeResolvingAShorterTarget() {
        let timeline = getTextTransitionTimeline(fromText: "welcome2", targetText: "go")

        XCTAssertEqual(timeline.collapseStartMs, 59)
        XCTAssertEqual(timeline.totalDurationMs, 108)
        XCTAssertEqual(buildTextTransitionFrame(fromText: "welcome2", targetText: "go", elapsedMs: 34, random: { 0 }).count, 8)
        XCTAssertEqual(buildTextTransitionFrame(fromText: "welcome2", targetText: "go", elapsedMs: 66, random: { 0 }).count, 6)
        XCTAssertEqual(buildTextTransitionFrame(fromText: "welcome2", targetText: "go", elapsedMs: 94, random: { 0 }).count, 2)
        XCTAssertEqual(buildTextTransitionFrame(fromText: "welcome2", targetText: "go", elapsedMs: 107, random: { 0 }), "ga")
        XCTAssertEqual(
            buildTextTransitionFrame(fromText: "welcome2", targetText: "go", elapsedMs: timeline.totalDurationMs, random: { 0 }),
            "go"
        )
    }

    func testLongerTargetIntroducesOneNewSlotEvery7msByDefault() {
        let timeline = getTextTransitionTimeline(fromText: "aaaa", targetText: "aaaa aaaa")

        XCTAssertEqual(timeline.lastSourceRandomizeStartMs, 21)
        XCTAssertEqual(timeline.lastRandomizeStartMs, 56)
        XCTAssertEqual(timeline.collapseStartMs, 66)
        XCTAssertEqual(timeline.totalDurationMs, 122)
        XCTAssertEqual(buildTextTransitionFrame(fromText: "aaaa", targetText: "aaaa aaaa", elapsedMs: 27, random: { 0 }).count, 4)
        XCTAssertEqual(buildTextTransitionFrame(fromText: "aaaa", targetText: "aaaa aaaa", elapsedMs: 28, random: { 0 }).count, 5)
        XCTAssertEqual(buildTextTransitionFrame(fromText: "aaaa", targetText: "aaaa aaaa", elapsedMs: 56, random: { 0 }).count, 9)
    }

    func testInitialFrameStartsFromSourceText() {
        let frame = buildTextTransitionFrame(fromText: "Open", targetText: "Open analytics dashboard", elapsedMs: 0, random: { 0.1 })
        XCTAssertTrue(frame.hasPrefix("Open"))
    }

    func testRealTransitionFramePreservesWidthGroupsForMixedCaseLetters() {
        let frame = Array(buildTextTransitionFrame(
            fromText: "Launch",
            targetText: "View analytics dashboard",
            elapsedMs: 15,
            random: { 0 }
        ))

        XCTAssertTrue(uppercaseNarrowPool.contains(frame[0]))
        XCTAssertTrue(lowercaseAveragePool.contains(frame[1]))
    }

    func testScrambleFrameDoesNotResolveImmediatelyToTarget() {
        let frame = buildTextTransitionFrame(fromText: "welcome", targetText: "Mission#42", elapsedMs: 24, random: { 0.15 })
        XCTAssertNotEqual(frame, "Mission#42")
    }

    func testCompletedFrameMatchesTargetText() {
        let timeline = getTextTransitionTimeline(fromText: "Open", targetText: "Open analytics dashboard")
        let frame = buildTextTransitionFrame(fromText: "Open", targetText: "Open analytics dashboard", elapsedMs: timeline.totalDurationMs + 1, random: { 0.5 })
        XCTAssertEqual(frame, "Open analytics dashboard")
    }

    func testRandomTransitionCharacterMayMatchTheSourceCharacterLikeFlutter() {
        XCTAssertEqual(getRandomTransitionCharacter(character: "A", random: { 0 }), "A")
    }
}
