import Foundation
import XCTest

@testable import Calibration
@testable import Commands
@testable import Configuration

final class BindingSaveGateTests: XCTestCase {

    private func binding(_ type: CommandType, _ target: String = "x") -> CommandBinding {
        CommandBinding(zone: .topLeft, command: Command(type: type, target: target))
    }

    func testShellCommandRequiresConfirmation() {
        XCTAssertTrue(BindingSaveGate.requiresConfirmation(binding(.shellCommand, "rm -rf /tmp/x")))
        XCTAssertTrue(BindingSaveGate.requiresConfirmation(binding(.shellCommand, "echo hello")))
    }

    func testOtherCommandTypesDoNotRequireConfirmation() {
        XCTAssertFalse(
            BindingSaveGate.requiresConfirmation(binding(.keyboardShortcut, "command+c")))
        XCTAssertFalse(BindingSaveGate.requiresConfirmation(binding(.appleScript, "return 1")))
        XCTAssertFalse(BindingSaveGate.requiresConfirmation(binding(.shortcut, "My Shortcut")))
        XCTAssertFalse(BindingSaveGate.requiresConfirmation(binding(.application, "/usr/bin/true")))
    }

    func testUnconfirmedShellSaveIsRejected() {
        XCTAssertThrowsError(
            try BindingSaveGate.checkSaveAllowed(binding(.shellCommand), userConfirmed: false)
        ) { error in
            XCTAssertEqual(error as? ConfigurationError, .confirmationRequired)
        }
    }

    func testConfirmedShellSaveIsAllowed() {
        XCTAssertNoThrow(
            try BindingSaveGate.checkSaveAllowed(binding(.shellCommand), userConfirmed: true))
    }

    func testNonShellSaveNeedsNoConfirmation() {
        XCTAssertNoThrow(
            try BindingSaveGate.checkSaveAllowed(binding(.keyboardShortcut), userConfirmed: false))
    }

    func testSetContainingAnyShellBindingRequiresConfirmation() {
        let bindings = PersistedCommandBindings(bindings: [
            CommandBinding(
                zone: .topLeft, command: Command(type: .keyboardShortcut, target: "command+c")),
            CommandBinding(
                zone: .topRight, command: Command(type: .shellCommand, target: "echo hi")),
        ])
        XCTAssertThrowsError(
            try BindingSaveGate.checkSaveAllowed(bindings, userConfirmed: false))
        XCTAssertNoThrow(try BindingSaveGate.checkSaveAllowed(bindings, userConfirmed: true))
    }
}

final class ConfigurationStoreSaveGateTests: XCTestCase {

    private var directory: URL!
    private var fileStore: AtomicFileStore!
    private var store: ConfigurationStore!

    override func setUpWithError() throws {
        directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("tapper-gate-\(UUID().uuidString)", isDirectory: true)
        fileStore = AtomicFileStore(directory: directory)
        store = ConfigurationStore(store: fileStore)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    private var shellBindings: PersistedCommandBindings {
        PersistedCommandBindings(bindings: [
            CommandBinding(
                zone: .topLeft, command: Command(type: .shellCommand, target: "echo hi"))
        ])
    }

    func testUnconfirmedShellBindingIsNotPersisted() {
        XCTAssertThrowsError(try store.save(shellBindings, userConfirmed: false)) { error in
            XCTAssertEqual(error as? ConfigurationError, .confirmationRequired)
        }
        XCTAssertFalse(fileStore.fileExists(ConfigurationStore.FileName.commandBindings))
    }

    func testConfirmedShellBindingIsPersisted() throws {
        try store.save(shellBindings, userConfirmed: true)
        XCTAssertEqual(store.loadCommandBindings(), .loaded(shellBindings))
    }

    func testNonShellBindingSavesWithoutConfirmation() throws {
        let bindings = PersistedCommandBindings(bindings: [
            CommandBinding(
                zone: .topLeft, command: Command(type: .keyboardShortcut, target: "command+c"))
        ])
        XCTAssertNoThrow(try store.save(bindings))
        XCTAssertEqual(store.loadCommandBindings(), .loaded(bindings))
    }
}
