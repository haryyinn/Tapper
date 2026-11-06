import Foundation
import XCTest

@testable import Calibration
@testable import Features

final class DerivedDetectionParametersTests: XCTestCase {

    /// A raw sample whose Signal Duration (slot 9) is `duration`.
    private func sample(duration: Double) -> [Double] {
        [0.4, 0.1, 700, 50, 800, 700, 0.03, 1, 0.3, duration]
    }

    func testLimitIsTukeyFarFenceOverSignalDuration() throws {
        // Durations 30, 35, 40, 45, 50: Q1 35, Q3 45, IQR 10 → 45 + 30 = 75 ms.
        let derived = try XCTUnwrap(
            DerivedDetectionParameters.derive(
                fromRawSamples: [30, 35, 40, 45, 50].map { sample(duration: $0) }))
        XCTAssertEqual(derived.maximumSignalDurationMilliseconds, 75, accuracy: 1e-12)
        XCTAssertEqual(derived.sampleCount, 5)
    }

    func testLimitIsNeverStricterThanTheFloor() throws {
        let derived = try XCTUnwrap(
            DerivedDetectionParameters.derive(
                fromRawSamples: [5, 6, 7, 8].map { sample(duration: $0) }))
        XCTAssertEqual(
            derived.maximumSignalDurationMilliseconds,
            DerivedDetectionParameters.durationFloorMilliseconds)
    }

    func testNoSamplesDeriveNothing() {
        XCTAssertNil(DerivedDetectionParameters.derive(fromRawSamples: []))
    }

    func testProfileWithoutDerivedParametersStillDecodes() throws {
        // A stored profile that predates the field must decode (and then be
        // refused by version), not fail as corrupt data.
        let profile = CalibrationProfile(
            id: UUID(), algorithmVersion: "2.0", deviceIdentifier: "d",
            createdAt: Date(timeIntervalSince1970: 0), zones: [],
            normalization: NormalizationParameters(means: [], standardDeviations: []),
            configuration: .v1)
        let encoder = JSONEncoder()
        let data = try encoder.encode(profile)
        let json = try XCTUnwrap(String(data: data, encoding: .utf8))
        XCTAssertFalse(json.contains("derivedDetection"))
        let decoded = try JSONDecoder().decode(CalibrationProfile.self, from: data)
        XCTAssertNil(decoded.derivedDetection)
    }
}
