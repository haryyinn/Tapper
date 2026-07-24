import XCTest

@testable import Calibration

final class FeatureStatisticsTests: XCTestCase {

    private let accuracy = 1e-12

    func testMean() {
        XCTAssertEqual(FeatureStatistics.mean(of: [[1, 2], [3, 4], [5, 6]]), [3, 4])
        XCTAssertEqual(FeatureStatistics.mean(of: []), [])
    }

    func testSampleCovariance() {
        let vectors = [[1.0, 2], [3, 4], [5, 6]]
        let covariance = FeatureStatistics.covariance(
            of: vectors, mean: FeatureStatistics.mean(of: vectors))
        // Deviations ±2 in both features -> 1/(3-1)·Σ = [[4,4],[4,4]].
        XCTAssertEqual(covariance, [[4, 4], [4, 4]])
    }

    func testCovarianceOfSingleVectorIsZero() {
        let covariance = FeatureStatistics.covariance(of: [[1, 2]], mean: [1, 2])
        XCTAssertEqual(covariance, [[0, 0], [0, 0]])
    }

    func testRegularizationAddsLambdaToDiagonal() {
        let regularized = FeatureStatistics.regularized([[4, 4], [4, 4]], lambda: 1e-3)
        XCTAssertEqual(regularized[0][0], 4.001, accuracy: accuracy)
        XCTAssertEqual(regularized[1][1], 4.001, accuracy: accuracy)
        XCTAssertEqual(regularized[0][1], 4, accuracy: accuracy)
    }

    func testRegularizationRescuesRankDeficientCovariance() {
        // Identical samples produce a zero covariance; +λI must be invertible.
        let identical = [[1.0, 2, 3], [1, 2, 3], [1, 2, 3]]
        let covariance = FeatureStatistics.covariance(
            of: identical, mean: FeatureStatistics.mean(of: identical))
        let regularized = FeatureStatistics.regularized(covariance, lambda: 1e-3)
        XCTAssertNotNil(LinearAlgebra.invertPositiveDefinite(regularized))
    }
}
