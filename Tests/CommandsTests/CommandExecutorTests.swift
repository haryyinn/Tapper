import Foundation
import XCTest

@testable import Commands

/// A stateless test double that returns a preconfigured outcome.
private struct StubProvider: CommandProvider {
    let commandType: CommandType
    let succeeds: Bool
    func execute(_ command: Command) -> CommandResult {
        succeeds
            ? .success(commandID: command.id, at: Date(timeIntervalSince1970: 1))
            : .failure(
                commandID: command.id, at: Date(timeIntervalSince1970: 1),
                error: .scriptError("stub"))
    }
}

final class CommandExecutorTests: XCTestCase {

    private let date = Date(timeIntervalSince1970: 5)

    func testDispatchesToMatchingProvider() {
        let executor = CommandExecutor(providers: [
            StubProvider(commandType: .shellCommand, succeeds: true)
        ])
        let command = Command(type: .shellCommand, target: "x")
        let result = executor.execute(command, at: date)
        XCTAssertTrue(result.succeeded)
        XCTAssertEqual(result.commandID, command.id)
    }

    func testUnsupportedTypeYieldsFailure() {
        let executor = CommandExecutor(providers: [
            StubProvider(commandType: .shellCommand, succeeds: true)
        ])
        let command = Command(type: .custom, target: "x")
        let result = executor.execute(command, at: date)
        XCTAssertFalse(result.succeeded)
        XCTAssertEqual(
            result.errorMessage, CommandExecutionError.unsupportedType(.custom).description)
    }

    func testProviderFailurePropagates() {
        let executor = CommandExecutor(providers: [
            StubProvider(commandType: .appleScript, succeeds: false)
        ])
        let result = executor.execute(Command(type: .appleScript, target: "x"), at: date)
        XCTAssertFalse(result.succeeded)
        XCTAssertEqual(result.errorMessage, CommandExecutionError.scriptError("stub").description)
    }

    func testSupportedTypesReflectRegisteredProviders() {
        let executor = CommandExecutor(providers: [
            StubProvider(commandType: .shellCommand, succeeds: true),
            StubProvider(commandType: .application, succeeds: true),
        ])
        XCTAssertEqual(executor.supportedTypes, [.shellCommand, .application])
    }
}

final class CommandQueueTests: XCTestCase {

    func testEnqueueDequeueIsFIFO() {
        var queue = CommandQueue()
        let first = Command(type: .shellCommand, target: "a")
        let second = Command(type: .shellCommand, target: "b")
        XCTAssertTrue(queue.enqueue(first))
        XCTAssertTrue(queue.enqueue(second))
        XCTAssertEqual(queue.dequeue(), first)
        XCTAssertEqual(queue.dequeue(), second)
        XCTAssertNil(queue.dequeue())
    }

    func testInvalidCommandIsRejected() {
        var queue = CommandQueue()
        XCTAssertFalse(queue.enqueue(Command(type: .shellCommand, target: "")))
        XCTAssertTrue(queue.isEmpty)
    }

    func testDequeueRemovesSoNoCommandRepeats() {
        var queue = CommandQueue()
        let command = Command(type: .shellCommand, target: "a")
        queue.enqueue(command)
        XCTAssertEqual(queue.dequeue(), command)
        XCTAssertNil(queue.dequeue())
    }
}
