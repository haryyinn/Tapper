import XCTest

@testable import Detection

final class NoiseFloorEstimatorTests: XCTestCase {

    private let accuracy = 1e-12

    func testNoEstimateBeforeFirstObservation() {
        XCTAssertNil(NoiseFloorEstimator().currentRMS)
    }

    func testFirstObservationSeedsEstimate() {
        var estimator = NoiseFloorEstimator(smoothing: 0.05)
        estimator.update(withFrameRMS: 0.02)
        XCTAssertEqual(estimator.currentRMS ?? -1, 0.02, accuracy: accuracy)
    }

    func testSubsequentObservationsFollowEMA() {
        var estimator = NoiseFloorEstimator(smoothing: 0.05)
        estimator.update(withFrameRMS: 0.02)
        estimator.update(withFrameRMS: 0.04)
        // 0.05 · 0.04 + 0.95 · 0.02 = 0.021.
        XCTAssertEqual(estimator.currentRMS ?? -1, 0.021, accuracy: accuracy)
    }

    func testInvalidObservationsAreIgnored() {
        var estimator = NoiseFloorEstimator(smoothing: 0.05)
        estimator.update(withFrameRMS: 0.02)
        estimator.update(withFrameRMS: -1)
        estimator.update(withFrameRMS: .nan)
        estimator.update(withFrameRMS: .infinity)
        XCTAssertEqual(estimator.currentRMS ?? -1, 0.02, accuracy: accuracy)
    }

    func testDefaultSmoothingIsApprovedValue() {
        XCTAssertEqual(NoiseFloorEstimator().smoothing, 0.05)
    }
}
