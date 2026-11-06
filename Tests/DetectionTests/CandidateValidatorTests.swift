import DSP
import XCTest

@testable import Detection

final class CandidateValidatorTests: XCTestCase {

    private let validator = CandidateValidator()

    /// Filtered event window with RMS 0.05.
    private let filteredStrong = [Double](repeating: 0.05, count: 13)

    private let cleanDCRemoved = [0.1, 0.2, 0.1]

    /// A decay estimate whose −20 dB duration is `duration` milliseconds.
    private func decay(durationMilliseconds duration: Double, censored: Bool = false)
        -> DecayEstimate
    {
        DecayEstimate(
            timeConstantMilliseconds: duration / log(10.0), fitRangeDB: 20,
            coefficientOfDetermination: 0.999, pointCount: 20, isCensored: censored)
    }

    private func reason(
        dcRemoved: [Double]? = nil, filtered: [Double]? = nil,
        decay: DecayEstimate?, noiseFloorRMS: Double?
    ) -> RejectionReason? {
        validator.rejectionReason(
            dcRemovedWindow: dcRemoved ?? cleanDCRemoved,
            filteredWindow: filtered ?? filteredStrong,
            decay: decay,
            noiseFloorRMS: noiseFloorRMS)
    }

    func testValidCandidatePasses() {
        XCTAssertNil(reason(decay: decay(durationMilliseconds: 10), noiseFloorRMS: 0.01))
    }

    func testClippingIsRejectedFirst() {
        XCTAssertEqual(
            reason(dcRemoved: [0.5, 0.995], filtered: [0.0], decay: nil, noiseFloorRMS: nil),
            .clipped)
    }

    func testDeclinedDecayIsRejectedDistinctly() {
        XCTAssertEqual(reason(decay: nil, noiseFloorRMS: 0.01), .decayNotMeasurable)
    }

    func testTooShortDurationIsRejected() {
        XCTAssertEqual(
            reason(decay: decay(durationMilliseconds: 1), noiseFloorRMS: 0.01),
            .durationBelowMinimum)
    }

    func testTooLongUncensoredDurationIsRejected() {
        XCTAssertEqual(
            reason(decay: decay(durationMilliseconds: 30), noiseFloorRMS: 0.01),
            .durationAboveMaximum)
    }

    func testCensoredDurationIsNeverRejectedForLength() {
        // §14.13.5: a censored duration is unknown, not excessive.
        XCTAssertNil(
            reason(decay: decay(durationMilliseconds: 80, censored: true), noiseFloorRMS: 0.01))
    }

    func testWeakRMSIsRejected() {
        XCTAssertEqual(
            reason(
                filtered: [Double](repeating: 0.001, count: 13),
                decay: decay(durationMilliseconds: 10), noiseFloorRMS: 0.0001),
            .rmsBelowMinimum)
    }

    func testInsufficientSNRIsRejected() {
        XCTAssertEqual(
            reason(
                filtered: [Double](repeating: 0.02, count: 13),  // RMS 0.02
                decay: decay(durationMilliseconds: 10),
                noiseFloorRMS: 0.015),  // SNR ≈ 1.33 < 2
            .snrBelowMinimum)
    }

    func testMissingNoiseFloorRejectsFailSafe() {
        XCTAssertEqual(
            reason(decay: decay(durationMilliseconds: 10), noiseFloorRMS: nil), .snrBelowMinimum)
    }

    func testZeroNoiseFloorPassesSNR() {
        XCTAssertNil(reason(decay: decay(durationMilliseconds: 10), noiseFloorRMS: 0.0))
    }
}
