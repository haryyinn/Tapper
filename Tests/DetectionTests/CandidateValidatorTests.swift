import XCTest

@testable import Detection

final class CandidateValidatorTests: XCTestCase {

    // At 1000 Hz one sample is one millisecond. Signal Duration uses the 0.10
    // activity threshold on the normalized signal.
    private let sampleRate = 1000.0
    private let validator = CandidateValidator()

    /// Normalized signal with a 10 ms active span (indices 1…11).
    private let normalizedTenMilliseconds = [0.0] + [Double](repeating: 1.0, count: 11) + [0.0]

    /// Filtered signal with RMS 0.05.
    private let filteredStrong = [Double](repeating: 0.05, count: 13)

    private let cleanDCRemoved = [0.1, 0.2, 0.1]

    func testValidCandidatePasses() {
        let reason = validator.rejectionReason(
            dcRemovedSignal: cleanDCRemoved,
            filteredSignal: filteredStrong,
            normalizedSignal: normalizedTenMilliseconds,
            sampleRate: sampleRate,
            noiseFloorRMS: 0.01
        )
        XCTAssertNil(reason)
    }

    func testClippingIsRejectedFirst() {
        let reason = validator.rejectionReason(
            dcRemovedSignal: [0.5, 0.995],
            filteredSignal: [0.0],  // would also fail RMS
            normalizedSignal: [0.0],  // would also fail duration
            sampleRate: sampleRate,
            noiseFloorRMS: nil
        )
        XCTAssertEqual(reason, .clipped)
    }

    func testTooShortDurationIsRejected() {
        let reason = validator.rejectionReason(
            dcRemovedSignal: cleanDCRemoved,
            filteredSignal: filteredStrong,
            normalizedSignal: [0.0, 1.0, 0.0],  // 0 ms active span
            sampleRate: sampleRate,
            noiseFloorRMS: 0.01
        )
        XCTAssertEqual(reason, .durationBelowMinimum)
    }

    func testTooLongDurationIsRejected() {
        let thirtyMilliseconds = [0.0] + [Double](repeating: 1.0, count: 31)
        let reason = validator.rejectionReason(
            dcRemovedSignal: cleanDCRemoved,
            filteredSignal: filteredStrong,
            normalizedSignal: thirtyMilliseconds,
            sampleRate: sampleRate,
            noiseFloorRMS: 0.01
        )
        XCTAssertEqual(reason, .durationAboveMaximum)
    }

    func testWeakRMSIsRejected() {
        let reason = validator.rejectionReason(
            dcRemovedSignal: cleanDCRemoved,
            filteredSignal: [Double](repeating: 0.001, count: 13),
            normalizedSignal: normalizedTenMilliseconds,
            sampleRate: sampleRate,
            noiseFloorRMS: 0.0001
        )
        XCTAssertEqual(reason, .rmsBelowMinimum)
    }

    func testInsufficientSNRIsRejected() {
        let reason = validator.rejectionReason(
            dcRemovedSignal: cleanDCRemoved,
            filteredSignal: [Double](repeating: 0.02, count: 13),  // RMS 0.02
            normalizedSignal: normalizedTenMilliseconds,
            sampleRate: sampleRate,
            noiseFloorRMS: 0.015  // SNR ≈ 1.33 < 2
        )
        XCTAssertEqual(reason, .snrBelowMinimum)
    }

    func testMissingNoiseFloorRejectsFailSafe() {
        let reason = validator.rejectionReason(
            dcRemovedSignal: cleanDCRemoved,
            filteredSignal: filteredStrong,
            normalizedSignal: normalizedTenMilliseconds,
            sampleRate: sampleRate,
            noiseFloorRMS: nil
        )
        XCTAssertEqual(reason, .snrBelowMinimum)
    }

    func testZeroNoiseFloorPassesSNR() {
        let reason = validator.rejectionReason(
            dcRemovedSignal: cleanDCRemoved,
            filteredSignal: filteredStrong,
            normalizedSignal: normalizedTenMilliseconds,
            sampleRate: sampleRate,
            noiseFloorRMS: 0.0
        )
        XCTAssertNil(reason)
    }
}
