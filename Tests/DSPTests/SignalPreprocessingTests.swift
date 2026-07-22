import XCTest

@testable import DSP

final class SignalPreprocessingTests: XCTestCase {

    private let accuracy = 1e-12

    // MARK: DC offset removal

    func testRemoveDCOffsetCentersSignal() {
        let result = SignalPreprocessing.removeDCOffset([1, 2, 3])
        XCTAssertEqual(result, [-1, 0, 1])
    }

    func testRemoveDCOffsetOfConstantSignalIsZero() {
        let result = SignalPreprocessing.removeDCOffset([5, 5, 5, 5])
        for value in result {
            XCTAssertEqual(value, 0, accuracy: accuracy)
        }
    }

    func testRemoveDCOffsetOfEmptyIsEmpty() {
        XCTAssertEqual(SignalPreprocessing.removeDCOffset([]), [])
    }

    // MARK: Clipping detection

    func testSignalBelowThresholdIsNotClipped() {
        XCTAssertFalse(SignalPreprocessing.isClipped([0.5, -0.98, 0.1], threshold: 0.99))
    }

    func testSignalAtThresholdIsClipped() {
        XCTAssertTrue(SignalPreprocessing.isClipped([0.5, 0.99], threshold: 0.99))
    }

    func testNegativeFullScaleIsClipped() {
        XCTAssertTrue(SignalPreprocessing.isClipped([-1.0, 0.2], threshold: 0.99))
    }

    func testDefaultClippingThresholdIsUsed() {
        // Default threshold is DSPConstants.clippingThreshold (0.99).
        XCTAssertTrue(SignalPreprocessing.isClipped([0.995]))
        XCTAssertFalse(SignalPreprocessing.isClipped([0.98]))
    }

    // MARK: Peak normalization

    func testPeakNormalizationScalesToUnitPeak() {
        let (normalized, peak) = SignalPreprocessing.peakNormalized([0.2, -0.4, 0.1])
        XCTAssertEqual(peak, 0.4, accuracy: accuracy)
        XCTAssertEqual(normalized[0], 0.5, accuracy: accuracy)
        XCTAssertEqual(normalized[1], -1.0, accuracy: accuracy)
        XCTAssertEqual(normalized[2], 0.25, accuracy: accuracy)
    }

    func testPeakNormalizationReportsPreNormalizationPeak() {
        let (_, peak) = SignalPreprocessing.peakNormalized([0.3, -0.7, 0.5])
        XCTAssertEqual(peak, 0.7, accuracy: accuracy)
    }

    func testAlreadyNormalizedSignalIsUnchanged() {
        let (normalized, peak) = SignalPreprocessing.peakNormalized([1.0, -0.5, 0.25])
        XCTAssertEqual(peak, 1.0, accuracy: accuracy)
        XCTAssertEqual(normalized, [1.0, -0.5, 0.25])
    }

    func testAllZeroSignalReturnsUnchangedWithZeroPeak() {
        let (normalized, peak) = SignalPreprocessing.peakNormalized([0, 0, 0])
        XCTAssertEqual(peak, 0)
        XCTAssertEqual(normalized, [0, 0, 0])
    }

    func testEmptySignalReturnsEmptyWithZeroPeak() {
        let (normalized, peak) = SignalPreprocessing.peakNormalized([])
        XCTAssertEqual(peak, 0)
        XCTAssertEqual(normalized, [])
    }
}
