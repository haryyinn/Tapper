import Foundation
import XCTest

@testable import Commands

/// These providers run real (harmless) processes: shell `exit` codes and the
/// `/usr/bin/true` / `/usr/bin/false` utilities.
final class ShellCommandProviderTests: XCTestCase {

    private let provider = ShellCommandProvider()

    func testHandlesShellCommandType() {
        XCTAssertEqual(provider.commandType, .shellCommand)
    }

    func testZeroExitSucceeds() {
        let result = provider.execute(Command(type: .shellCommand, target: "exit 0"))
        XCTAssertTrue(result.succeeded)
        XCTAssertNil(result.errorMessage)
    }

    func testNonZeroExitFails() {
        let result = provider.execute(Command(type: .shellCommand, target: "exit 7"))
        XCTAssertFalse(result.succeeded)
        XCTAssertEqual(result.errorMessage, CommandExecutionError.nonZeroExit(7).description)
    }
}

final class ExecutableProviderTests: XCTestCase {

    private let provider = ExecutableProvider()

    func testHandlesApplicationType() {
        XCTAssertEqual(provider.commandType, .application)
    }

    func testExecutableExitingZeroSucceeds() {
        let result = provider.execute(Command(type: .application, target: "/usr/bin/true"))
        XCTAssertTrue(result.succeeded)
    }

    func testExecutableExitingNonZeroFails() {
        let result = provider.execute(Command(type: .application, target: "/usr/bin/false"))
        XCTAssertFalse(result.succeeded)
        XCTAssertEqual(result.errorMessage, CommandExecutionError.nonZeroExit(1).description)
    }

    func testMissingExecutableFailsToLaunch() {
        let result = provider.execute(Command(type: .application, target: "/no/such/executable"))
        XCTAssertFalse(result.succeeded)
        XCTAssertNotNil(result.errorMessage)
    }
}
