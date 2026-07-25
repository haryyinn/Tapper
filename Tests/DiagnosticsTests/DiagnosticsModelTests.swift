import Foundation
import XCTest

@testable import Configuration
@testable import Diagnostics

final class DiagnosticsModelTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_000)

    private func record(message: String) -> DiagnosticsRecord {
        DiagnosticsRecord(timestamp: now, level: .info, category: .recognition, message: message)
    }

    // MARK: DiagnosticsRecord

    func testValidRecordPassesValidation() {
        XCTAssertTrue(record(message: "candidate rejected: durationAboveMaximum").isValid)
    }

    func testEmptyMessageIsInvalid() {
        XCTAssertFalse(record(message: "").isValid)
        XCTAssertFalse(record(message: "   \n ").isValid)
    }

    func testRecordsCarryDistinctIdentifiers() {
        XCTAssertNotEqual(record(message: "a").id, record(message: "a").id)
    }

    func testRecordRoundTripsDeterministically() throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        let original = record(message: "zone classified")

        let first = try encoder.encode(original)
        XCTAssertEqual(first, try encoder.encode(original))

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        XCTAssertEqual(try decoder.decode(DiagnosticsRecord.self, from: first), original)
    }

    func testCategoryEncodesAsReadableString() throws {
        let data = try JSONEncoder().encode(["category": DiagnosticsCategory.command])
        let json = try XCTUnwrap(String(data: data, encoding: .utf8))
        XCTAssertTrue(json.contains("command"), json)
    }

    func testEveryDocumentedCategoryExists() {
        XCTAssertEqual(
            Set(DiagnosticsCategory.allCases.map(\.rawValue)),
            [
                "audio", "dsp", "calibration", "classification", "recognition", "runtime",
                "storage",
                "command",
            ]
        )
    }

    // MARK: PerformanceMetrics

    private func metrics(
        processing: TimeInterval = 0.05,
        dsp: TimeInterval = 0.01,
        classification: TimeInterval = 0.002,
        cpu: Double = 3.5,
        memory: Double = 42
    ) -> PerformanceMetrics {
        PerformanceMetrics(
            processingLatency: processing, dspLatency: dsp, classificationLatency: classification,
            cpuUsage: cpu, memoryUsage: memory)
    }

    func testValidMetricsPass() {
        XCTAssertTrue(metrics().isValid)
    }

    func testNegativeLatencyIsInvalid() {
        XCTAssertFalse(metrics(processing: -0.1).isValid)
        XCTAssertFalse(metrics(dsp: -0.1).isValid)
        XCTAssertFalse(metrics(classification: -0.1).isValid)
    }

    func testCPUOutsideRangeIsInvalid() {
        XCTAssertFalse(metrics(cpu: -1).isValid)
        XCTAssertFalse(metrics(cpu: 101).isValid)
        XCTAssertTrue(metrics(cpu: 0).isValid)
        XCTAssertTrue(metrics(cpu: 100).isValid)
    }

    func testNegativeMemoryIsInvalid() {
        XCTAssertFalse(metrics(memory: -1).isValid)
    }

    func testNonFiniteValuesAreInvalid() {
        XCTAssertFalse(metrics(processing: .nan).isValid)
        XCTAssertFalse(metrics(memory: .infinity).isValid)
    }
}
