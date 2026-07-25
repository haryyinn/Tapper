import Foundation
import XCTest

@testable import Configuration
@testable import Diagnostics

final class DiagnosticsLogTests: XCTestCase {

    private func record(_ message: String, at seconds: TimeInterval = 0) -> DiagnosticsRecord {
        DiagnosticsRecord(
            timestamp: Date(timeIntervalSince1970: seconds), level: .info, category: .runtime,
            message: message)
    }

    func testDefaultCapacityMatchesDocumentedBufferSize() {
        XCTAssertEqual(DiagnosticsLog.defaultCapacity, 100)
        XCTAssertEqual(DiagnosticsLog().capacity, 100)
    }

    func testRecordsArePreservedInChronologicalInsertionOrder() {
        let log = DiagnosticsLog(capacity: 10)
        log.record(record("first", at: 1))
        log.record(record("second", at: 2))
        log.record(record("third", at: 3))
        XCTAssertEqual(log.records.map(\.message), ["first", "second", "third"])
    }

    func testOldestRecordsAreEvictedAtCapacity() {
        let log = DiagnosticsLog(capacity: 3)
        for index in 1...5 {
            log.record(record("event-\(index)", at: TimeInterval(index)))
        }
        XCTAssertEqual(log.count, 3)
        XCTAssertEqual(log.records.map(\.message), ["event-3", "event-4", "event-5"])
    }

    func testInvalidRecordsAreDiscardedAndReported() {
        let log = DiagnosticsLog(capacity: 5)
        XCTAssertFalse(log.record(record("")))
        XCTAssertTrue(log.record(record("valid")))
        XCTAssertEqual(log.records.map(\.message), ["valid"])
    }

    func testRemoveAllClearsBuffer() {
        let log = DiagnosticsLog(capacity: 5)
        log.record(record("a"))
        log.removeAll()
        XCTAssertEqual(log.count, 0)
        XCTAssertTrue(log.records.isEmpty)
    }

    func testConcurrentRecordingRetainsEveryRecord() {
        let log = DiagnosticsLog(capacity: 1_000)
        let iterations = 500
        DispatchQueue.concurrentPerform(iterations: iterations) { index in
            log.record(record("concurrent-\(index)", at: TimeInterval(index)))
        }
        XCTAssertEqual(log.count, iterations, "synchronized insertion must not lose records")
    }
}
