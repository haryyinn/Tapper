import CoreGraphics
import XCTest

@testable import Commands

final class KeyboardShortcutParserTests: XCTestCase {

    func testParsesKeyWithoutModifiers() {
        let shortcut = KeyboardShortcutParser.parse("c")
        XCTAssertEqual(shortcut, KeyboardShortcut(keyCode: 8, modifiers: []))
    }

    func testParsesSingleModifier() {
        let shortcut = KeyboardShortcutParser.parse("command+c")
        XCTAssertEqual(shortcut, KeyboardShortcut(keyCode: 8, modifiers: .maskCommand))
    }

    func testParsesMultipleModifiersCaseInsensitively() {
        let shortcut = KeyboardShortcutParser.parse("Command+Shift+A")
        XCTAssertEqual(
            shortcut, KeyboardShortcut(keyCode: 0, modifiers: [.maskCommand, .maskShift]))
    }

    func testModifierAliasesAreAccepted() {
        XCTAssertEqual(
            KeyboardShortcutParser.parse("cmd+opt+ctrl+4"),
            KeyboardShortcut(
                keyCode: 21, modifiers: [.maskCommand, .maskAlternate, .maskControl]))
    }

    func testNamedKeysParse() {
        XCTAssertEqual(
            KeyboardShortcutParser.parse("command+space"),
            KeyboardShortcut(keyCode: 49, modifiers: .maskCommand))
    }

    func testUnknownKeyFails() {
        XCTAssertNil(KeyboardShortcutParser.parse("command+£"))
    }

    func testUnknownModifierFails() {
        XCTAssertNil(KeyboardShortcutParser.parse("hyper+c"))
    }

    func testEmptyStringFails() {
        XCTAssertNil(KeyboardShortcutParser.parse(""))
    }
}

final class KeyboardShortcutProviderTests: XCTestCase {

    // The live CGEvent post is integration-only (it would inject a real
    // keystroke and requires Accessibility). Only the deterministic
    // parse-failure path is unit-tested, since it never posts an event.
    func testHandlesKeyboardShortcutType() {
        XCTAssertEqual(KeyboardShortcutProvider().commandType, .keyboardShortcut)
    }

    func testUnparseableTargetFailsWithoutPosting() {
        let result = KeyboardShortcutProvider().execute(
            Command(type: .keyboardShortcut, target: "hyper+nonsense"))
        XCTAssertFalse(result.succeeded)
        XCTAssertEqual(
            result.errorMessage,
            CommandExecutionError.invalidTarget("hyper+nonsense").description)
    }
}
