import Foundation
import XCTest

@testable import Commands

/// AppleScript is exercised with self-contained scripts that target no other
/// application, so no Automation permission is required. These run on the main
/// thread (the XCTest default), as `NSAppleScript` expects.
final class AppleScriptProviderTests: XCTestCase {

    private let provider = AppleScriptProvider()

    func testHandlesAppleScriptType() {
        XCTAssertEqual(provider.commandType, .appleScript)
    }

    func testSelfContainedScriptSucceeds() {
        let result = provider.execute(Command(type: .appleScript, target: "return 2 + 2"))
        XCTAssertTrue(result.succeeded)
        XCTAssertNil(result.errorMessage)
    }

    func testInvalidScriptFails() {
        let result = provider.execute(
            Command(type: .appleScript, target: "this is not valid applescript !!"))
        XCTAssertFalse(result.succeeded)
        XCTAssertNotNil(result.errorMessage)
    }
}

final class ShortcutsProviderTests: XCTestCase {

    // Live `shortcuts run` execution is integration-only (needs a real shortcut
    // and a user session); the unit test covers the handled type.
    func testHandlesShortcutType() {
        XCTAssertEqual(ShortcutsProvider().commandType, .shortcut)
    }
}
