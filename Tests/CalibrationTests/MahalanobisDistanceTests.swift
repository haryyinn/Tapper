import XCTest

@testable import Calibration

final class MahalanobisDistanceTests: XCTestCase {

    private let accuracy = 1e-12

    func testIdentityCovarianceEqualsEuclidean() {
        let distance = MahalanobisDistance.distance(
            vector: [3, 4], mean: [0, 0], inverseCovariance: [[1, 0], [0, 1]])
        XCTAssertEqual(distance, 5, accuracy: accuracy)
    }

    func testDiagonalCovarianceScalesPerFeature() {
        // Σ = diag(4, 1) -> Σ⁻¹ = diag(0.25, 1); D² = 0.25·4 + 1·9 = 10.
        let distance = MahalanobisDistance.distance(
            vector: [2, 3], mean: [0, 0], inverseCovariance: [[0.25, 0], [0, 1]])
        XCTAssertEqual(distance, 10.0.squareRoot(), accuracy: accuracy)
    }

    func testSquaredMatchesDistanceSquared() {
        let squared = MahalanobisDistance.squared(
            vector: [2, 3], mean: [0, 0], inverseCovariance: [[0.25, 0], [0, 1]])
        XCTAssertEqual(squared, 10, accuracy: accuracy)
    }

    func testZeroDeviationIsZeroDistance() {
        let distance = MahalanobisDistance.distance(
            vector: [1, 2], mean: [1, 2], inverseCovariance: [[5, 1], [1, 5]])
        XCTAssertEqual(distance, 0, accuracy: accuracy)
    }
}
