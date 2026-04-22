import SwiftUI
import XCTest
@testable import SwiftAwesomeButton

final class ThemeResolutionTests: XCTestCase {
    func testThemeFallsBackToBasicForInvalidIndex() {
        let theme = getTheme(index: 99)
        XCTAssertEqual(theme.name, .basic)
        XCTAssertEqual(theme.title, "Basic Theme")
    }

    func testThemeResolvesByName() {
        let theme = getTheme(name: .rick)
        XCTAssertEqual(theme.name, .rick)
        XCTAssertEqual(theme.title, "Rick Theme")
    }

    func testSocialVariantsExistOnBuiltInThemes() {
        let theme = getTheme(name: .basic)
        XCTAssertNotNil(theme.buttons[.x])
        XCTAssertNotNil(theme.buttons[.facebook])
        XCTAssertNotNil(theme.buttons[.github])
        XCTAssertNotNil(theme.buttons[.youtube])
    }

    func testDisabledAndFlatTypeResolution() {
        let theme = getTheme(name: .basic)
        XCTAssertEqual(resolveButtonType(theme: ThemeDefinition(title: theme.title, background: theme.background, color: theme.color, buttons: theme.buttons, size: theme.size), disabled: true, flat: false, type: .primary), .disabled)
        XCTAssertEqual(resolveButtonType(theme: ThemeDefinition(title: theme.title, background: theme.background, color: theme.color, buttons: theme.buttons, size: theme.size), disabled: false, flat: true, type: .danger), .flat)
    }
}
