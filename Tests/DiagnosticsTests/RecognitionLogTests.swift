import Foundation
import XCTest

@testable import Calibration
@testable import Classification
@testable import Diagnostics

final class RecognitionLogTests: XCTestCase {

    private func outcome(
        _ zone: InteractionZone, at seconds: TimeInterval, status: RecognitionStatus = .success
    ) -> ClassificationOutcome {
        ClassificationOutcome(
            status: status,
            zone: zone,
            distance: 1.2,
            confidence: 60,
            acceptanceThreshold: 3,
            secondBestDistance: 4.5,
            timestamp: Date(timeIntervalSince1970: seconds)
        )
    }

    func testEntriesPreserveChronologicalOrder() {
        let log = RecognitionLog(capacity: 10)
        log.record(outcome(.topLeft, at: 1))
        log.record(outcome(.topRight, at: 2))
        log.record(outcome(.bottomLeft, at: 3))
        XCTAssertEqual(log.entries.map(\.zone), [.topLeft, .topRight, .bottomLeft])
        XCTAssertEqual(log.entries.map(\.timestamp.timeIntervalSince1970), [1, 2, 3])
    }

    func testOldestEntriesAreEvictedAtCapacity() {
        let log = RecognitionLog(capacity: 2)
        log.record(outcome(.topLeft, at: 1))
        log.record(outcome(.topRight, at: 2))
        log.record(outcome(.bottomRight, at: 3))
        XCTAssertEqual(log.count, 2)
        XCTAssertEqual(log.entries.map(\.zone), [.topRight, .bottomRight])
    }

    func testUnknownAndAmbiguousOutcomesAreRecorded() {
        let log = RecognitionLog(capacity: 10)
        log.record(outcome(.unknown, at: 1, status: .unknown))
        log.record(outcome(.unknown, at: 2, status: .ambiguous))
        XCTAssertEqual(log.entries.map(\.status), [.unknown, .ambiguous])
    }

    func testRemoveAllClearsHistory() {
        let log = RecognitionLog(capacity: 5)
        log.record(outcome(.topLeft, at: 1))
        log.removeAll()
        XCTAssertTrue(log.entries.isEmpty)
    }

    func testConcurrentRecordingRetainsEveryEntry() {
        let log = RecognitionLog(capacity: 1_000)
        DispatchQueue.concurrentPerform(iterations: 400) { index in
            log.record(outcome(.topLeft, at: TimeInterval(index)))
        }
        XCTAssertEqual(log.count, 400)
    }
}
