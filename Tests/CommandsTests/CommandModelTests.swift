import Foundation
import XCTest

@testable import Commands

final class CommandModelTests: XCTestCase {

    private let id = UUID()
    private let now = Date(timeIntervalSince1970: 100)

    // MARK: Command validation

    func testValidCommandPasses() {
        let command = Command(type: .shellCommand, target: "/usr/bin/true")
        XCTAssertNoThrow(try command.validate())
        XCTAssertTrue(command.isValid)
    }

    func testEmptyTargetFails() {
        let command = Command(type: .shellCommand, target: "")
        XCTAssertThrowsError(try command.validate()) { error in
            XCTAssertEqual(error as? CommandValidationError, .emptyTarget)
        }
    }

    func testEmptyParameterKeyFails() {
        let command = Command(type: .shellCommand, target: "x", parameters: ["": "v"])
        XCTAssertThrowsError(try command.validate()) { error in
            XCTAssertEqual(error as? CommandValidationError, .emptyParameterKey)
        }
    }

    // MARK: CommandResult

    func testSuccessFactoryHasNoErrorMessage() throws {
        let result = CommandResult.success(commandID: id, at: now)
        XCTAssertTrue(result.succeeded)
        XCTAssertNil(result.errorMessage)
        XCTAssertEqual(result.commandID, id)
        XCTAssertNoThrow(try result.validate())
    }

    func testFailureFactoryCarriesErrorDescription() throws {
        let result = CommandResult.failure(commandID: id, at: now, error: .nonZeroExit(3))
        XCTAssertFalse(result.succeeded)
        XCTAssertEqual(result.errorMessage, CommandExecutionError.nonZeroExit(3).description)
        XCTAssertNoThrow(try result.validate())
    }

    func testErrorMessageOnSuccessFailsValidation() {
        let result = CommandResult(
            commandID: id, succeeded: true, completedAt: now, errorMessage: "oops")
        XCTAssertThrowsError(try result.validate()) { error in
            XCTAssertEqual(error as? CommandResultValidationError, .errorMessageOnSuccess)
        }
    }

    func testExecutionErrorDescriptionsAreStable() {
        XCTAssertEqual(
            CommandExecutionError.unsupportedType(.custom).description,
            "No provider registered for command type custom.")
        XCTAssertEqual(CommandExecutionError.permissionDenied.description, "Permission denied.")
    }
}
