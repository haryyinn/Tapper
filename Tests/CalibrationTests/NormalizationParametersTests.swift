import XCTest

@testable import Calibration

final class NormalizationParametersTests: XCTestCase {

    private let accuracy = 1e-9

    func testComputesGlobalMeanAndPopulationStd() {
        let parameters = NormalizationParameters.compute(from: [[0, 10], [2, 20], [4, 30]])
        XCTAssertEqual(parameters.means[0], 2, accuracy: accuracy)
        XCTAssertEqual(parameters.means[1], 20, accuracy: accuracy)
        // Population std: sqrt((4+0+4)/3), sqrt((100+0+100)/3).
        XCTAssertEqual(parameters.standardDeviations[0], (8.0 / 3).squareRoot(), accuracy: accuracy)
        XCTAssertEqual(
            parameters.standardDeviations[1], (200.0 / 3).squareRoot(), accuracy: accuracy)
    }

    func testNormalizeCentersAndScales() {
        let parameters = NormalizationParameters(means: [2, 20], standardDeviations: [2, 10])
        XCTAssertEqual(parameters.normalize([4, 40]), [1, 2])
        XCTAssertEqual(parameters.normalize([2, 20]), [0, 0])
    }

    func testZeroVarianceFeatureIsCenteredNotScaled() {
        let parameters = NormalizationParameters(means: [5], standardDeviations: [0])
        // No division by zero; the feature is only centered.
        XCTAssertEqual(parameters.normalize([8]), [3])
    }

    func testEmptySamplesProduceEmptyTransform() {
        let parameters = NormalizationParameters.compute(from: [])
        XCTAssertTrue(parameters.means.isEmpty)
        XCTAssertTrue(parameters.standardDeviations.isEmpty)
    }
}
