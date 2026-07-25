import Foundation
import XCTest

@testable import Calibration
@testable import Commands
@testable import Configuration

final class ConfigurationModelTests: XCTestCase {

    // MARK: Schema version

    func testCurrentSchemaVersionIsSupported() {
        XCTAssertEqual(SchemaVersion.current, "1.0")
        XCTAssertTrue(SchemaVersion.isSupported("1.0"))
    }

    func testOtherSchemaVersionsAreUnsupported() {
        XCTAssertFalse(SchemaVersion.isSupported("0.9"))
        XCTAssertFalse(SchemaVersion.isSupported("2.0"))
        XCTAssertFalse(SchemaVersion.isSupported(""))
    }

    // MARK: Preferences

    func testDefaultPreferencesMatchDocumentedDefaults() {
        let defaults = UserPreferences.defaults
        XCTAssertFalse(defaults.diagnosticsEnabled)
        XCTAssertEqual(defaults.loggingLevel, .info)
        XCTAssertFalse(defaults.launchAtLogin, "ADR-008: launch at login is off by default")
        XCTAssertFalse(defaults.automaticUpdates)
    }

    // MARK: Serialization contract (`DATA_MODELS` §13.12)

    func testPreferencesRoundTripDeterministically() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let preferences = UserPreferences(
            diagnosticsEnabled: true, loggingLevel: .warning, launchAtLogin: true,
            automaticUpdates: false)

        let first = try encoder.encode(preferences)
        let second = try encoder.encode(preferences)
        XCTAssertEqual(first, second, "identical state must serialize identically")

        let decoded = try JSONDecoder().decode(UserPreferences.self, from: first)
        XCTAssertEqual(decoded, preferences)
    }

    func testLogLevelEncodesAsReadableString() throws {
        let data = try JSONEncoder().encode(["level": LogLevel.critical])
        let json = try XCTUnwrap(String(data: data, encoding: .utf8))
        XCTAssertTrue(json.contains("critical"), "human-readable config: \(json)")
    }

    func testBindingsRoundTripPreservingOrderAndIdentifiers() throws {
        let first = CommandBinding(
            zone: .topLeft, command: Command(type: .shellCommand, target: "echo one"))
        let second = CommandBinding(
            zone: .bottomRight, command: Command(type: .keyboardShortcut, target: "command+c"))
        let stored = PersistedCommandBindings(bindings: [first, second])

        let data = try JSONEncoder().encode(stored)
        let decoded = try JSONDecoder().decode(PersistedCommandBindings.self, from: data)

        XCTAssertEqual(decoded.schemaVersion, "1.0")
        XCTAssertEqual(decoded.bindings, [first, second], "order and identifiers preserved")
        XCTAssertEqual(decoded.bindings[0].command.id, first.command.id)
    }

    func testZoneEncodesAsReadableString() throws {
        let data = try JSONEncoder().encode(["zone": InteractionZone.bottomLeft])
        let json = try XCTUnwrap(String(data: data, encoding: .utf8))
        XCTAssertTrue(json.contains("bottomLeft"), "human-readable config: \(json)")
    }

    func testBindingLookupByZone() {
        let binding = CommandBinding(
            zone: .topRight, command: Command(type: .appleScript, target: "return 1"))
        let stored = PersistedCommandBindings(bindings: [binding])
        XCTAssertEqual(stored.binding(for: .topRight), binding)
        XCTAssertNil(stored.binding(for: .topLeft))
    }

    func testDefaultBindingsAreEmpty() {
        XCTAssertTrue(PersistedCommandBindings.defaults.bindings.isEmpty)
        XCTAssertEqual(PersistedCommandBindings.defaults.schemaVersion, "1.0")
    }
}
