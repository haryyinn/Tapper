import Foundation
import XCTest

@testable import Detection

final class CooldownGateTests: XCTestCase {

    private let start = Date(timeIntervalSince1970: 1000)

    func testInactiveBeforeAnyRecognition() {
        let gate = CooldownGate(duration: 0.1)
        XCTAssertFalse(gate.isActive(at: start))
    }

    func testActiveWithinDuration() {
        var gate = CooldownGate(duration: 0.1)
        gate.recordRecognition(at: start)
        XCTAssertTrue(gate.isActive(at: start))
        XCTAssertTrue(gate.isActive(at: start.addingTimeInterval(0.099)))
    }

    func testInactiveAtExactDurationBoundary() {
        var gate = CooldownGate(duration: 0.1)
        gate.recordRecognition(at: start)
        XCTAssertFalse(gate.isActive(at: start.addingTimeInterval(0.1)))
        XCTAssertFalse(gate.isActive(at: start.addingTimeInterval(0.5)))
    }

    func testNewRecognitionRestartsCooldown() {
        var gate = CooldownGate(duration: 0.1)
        gate.recordRecognition(at: start)
        gate.recordRecognition(at: start.addingTimeInterval(0.2))
        XCTAssertTrue(gate.isActive(at: start.addingTimeInterval(0.25)))
        // Clear of the 0.3 s boundary, where (start + 0.3) − (start + 0.2)
        // rounds to just under 0.1 s.
        XCTAssertFalse(gate.isActive(at: start.addingTimeInterval(0.35)))
    }

    func testDefaultDurationIsDocumentedValue() {
        XCTAssertEqual(CooldownGate().duration, 0.100)
    }
}
