import Foundation
import XCTest

@testable import Configuration
@testable import Diagnostics

final class DiagnosticsLoggerTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 500)

    func testEnabledLoggerRecordsAtOrAboveMinimumLevel() {
        let log = DiagnosticsLog(capacity: 20)
        let logger = DiagnosticsLogger(log: log, diagnosticsEnabled: true, minimumLevel: .info)

        logger.record(.debug, category: .dsp, "too verbose", at: now)
        logger.record(.info, category: .dsp, "kept info", at: now)
        logger.record(.warning, category: .audio, "kept warning", at: now)

        XCTAssertEqual(log.records.map(\.message), ["kept info", "kept warning"])
    }

    func testDisabledLoggerStillRecordsErrors() {
        let log = DiagnosticsLog(capacity: 20)
        let logger = DiagnosticsLogger(log: log, diagnosticsEnabled: false, minimumLevel: .debug)

        logger.record(.info, category: .runtime, "dropped", at: now)
        logger.record(.warning, category: .runtime, "dropped too", at: now)
        logger.record(.error, category: .storage, "kept error", at: now)
        logger.record(.critical, category: .storage, "kept critical", at: now)

        XCTAssertEqual(log.records.map(\.message), ["kept error", "kept critical"])
    }

    func testShouldRecordReflectsPreferences() {
        let enabled = DiagnosticsLogger(
            log: DiagnosticsLog(), diagnosticsEnabled: true, minimumLevel: .warning)
        XCTAssertFalse(enabled.shouldRecord(.info))
        XCTAssertTrue(enabled.shouldRecord(.warning))
        XCTAssertTrue(enabled.shouldRecord(.critical))

        let disabled = DiagnosticsLogger(log: DiagnosticsLog(), diagnosticsEnabled: false)
        XCTAssertFalse(disabled.shouldRecord(.warning))
        XCTAssertTrue(disabled.shouldRecord(.error))
    }

    func testLoggerReadsPreferencesWithoutModifyingThem() {
        let preferences = UserPreferences(
            diagnosticsEnabled: true, loggingLevel: .warning, launchAtLogin: false,
            automaticUpdates: false)
        let log = DiagnosticsLog(capacity: 10)
        let logger = DiagnosticsLogger(log: log, preferences: preferences)

        logger.record(.info, category: .recognition, "below threshold", at: now)
        logger.record(.warning, category: .recognition, "at threshold", at: now)

        XCTAssertEqual(log.records.map(\.message), ["at threshold"])
        XCTAssertEqual(
            preferences,
            UserPreferences(
                diagnosticsEnabled: true, loggingLevel: .warning, launchAtLogin: false,
                automaticUpdates: false),
            "diagnostics must not modify configuration")
    }

    func testRecordedEntriesCarryCategoryLevelAndTimestamp() {
        let log = DiagnosticsLog(capacity: 5)
        let logger = DiagnosticsLogger(log: log, diagnosticsEnabled: true, minimumLevel: .debug)
        logger.record(.error, category: .command, "execution failed", at: now)

        let entry = try? XCTUnwrap(log.records.first)
        XCTAssertEqual(entry?.level, .error)
        XCTAssertEqual(entry?.category, .command)
        XCTAssertEqual(entry?.timestamp, now)
        XCTAssertEqual(entry?.message, "execution failed")
    }

    func testEmptyMessageIsDiscardedWithoutThrowing() {
        let log = DiagnosticsLog(capacity: 5)
        let logger = DiagnosticsLogger(log: log, diagnosticsEnabled: true, minimumLevel: .debug)
        logger.record(.info, category: .runtime, "", at: now)
        XCTAssertTrue(log.records.isEmpty, "invalid records are discarded, never propagated")
    }
}
