import Foundation
import XCTest

@testable import Configuration
@testable import Runtime

final class RuntimeModelTests: XCTestCase {

    // MARK: RuntimeState

    func testPublicStatesMatchDocumentedEnumeration() {
        XCTAssertEqual(
            Set(RuntimeState.allCases.map(\.rawValue)),
            ["idle", "listening", "processing", "cooldown", "calibrating", "error"]
        )
    }

    // MARK: RuntimeConfiguration

    func testConfigurationDerivedFromPreferences() {
        let preferences = UserPreferences(
            diagnosticsEnabled: true, loggingLevel: .warning, launchAtLogin: false,
            automaticUpdates: false)
        let configuration = RuntimeConfiguration(
            preferences: preferences, cooldownDuration: 0.1)

        XCTAssertTrue(configuration.diagnosticsEnabled)
        XCTAssertEqual(configuration.loggingLevel, .warning)
        XCTAssertEqual(configuration.cooldownDuration, 0.1)
        XCTAssertTrue(configuration.recognitionEnabled)
        XCTAssertTrue(configuration.isValid)
    }

    func testNonPositiveCooldownIsInvalid() {
        let configuration = RuntimeConfiguration(
            diagnosticsEnabled: false, cooldownDuration: 0, recognitionEnabled: true,
            loggingLevel: .info)
        XCTAssertFalse(configuration.isValid)
    }

    // MARK: EngineStatus

    func testEngineIsHealthyOnlyWhenReady() {
        XCTAssertTrue(
            EngineStatus(state: .listening, microphoneAvailable: true, profileLoaded: true).healthy)
        XCTAssertFalse(
            EngineStatus(state: .listening, microphoneAvailable: false, profileLoaded: true).healthy
        )
        XCTAssertFalse(
            EngineStatus(state: .listening, microphoneAvailable: true, profileLoaded: false).healthy
        )
        XCTAssertFalse(
            EngineStatus(state: .error, microphoneAvailable: true, profileLoaded: true).healthy)
    }

    // MARK: RuntimeStatistics

    func testZeroStatisticsAreValid() {
        XCTAssertTrue(RuntimeStatistics.zero.isValid)
        XCTAssertEqual(RuntimeStatistics.zero.recognitionsProcessed, 0)
    }

    func testNegativeOrNonFiniteStatisticsAreInvalid() {
        XCTAssertFalse(
            RuntimeStatistics(
                recognitionsProcessed: -1, rejectedCandidates: 0, averageLatency: 0, uptime: 0
            ).isValid)
        XCTAssertFalse(
            RuntimeStatistics(
                recognitionsProcessed: 0, rejectedCandidates: 0, averageLatency: .nan, uptime: 0
            ).isValid)
        XCTAssertFalse(
            RuntimeStatistics(
                recognitionsProcessed: 0, rejectedCandidates: 0, averageLatency: -1, uptime: 0
            ).isValid)
    }
}
