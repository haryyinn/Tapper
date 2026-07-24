import XCTest

@testable import Calibration
@testable import Features

final class StatisticalModelTests: XCTestCase {

    func testCalibratableZonesAreInCanonicalTieBreakOrder() {
        XCTAssertEqual(
            InteractionZone.calibratable,
            [.topLeft, .topRight, .bottomLeft, .bottomRight]
        )
        XCTAssertFalse(InteractionZone.calibratable.contains(.unknown))
    }

    func testFeatureVectorValuesUseCanonicalOrder() {
        let vector = FeatureVector(
            peakAmplitude: 1,
            rmsEnergy: 2,
            spectralCentroid: 3,
            spectralBandwidth: 4,
            spectralRollOff: 5,
            dominantFrequency: 6,
            zeroCrossingRate: 7,
            attackTime: 8,
            decayTime: 9,
            signalDuration: 10
        )
        XCTAssertEqual(vector.values, [1, 2, 3, 4, 5, 6, 7, 8, 9, 10])
        XCTAssertEqual(FeatureVector.dimension, 10)
    }

    func testMatrixDimensionReflectsRowCount() {
        let covariance = CovarianceMatrix(values: [[1, 0], [0, 1]])
        XCTAssertEqual(covariance.dimension, 2)
        XCTAssertEqual(CovarianceMatrix(values: []).dimension, 0)
    }

    func testModelsAreValueEquatable() {
        XCTAssertEqual(MeanVector(values: [1, 2]), MeanVector(values: [1, 2]))
        XCTAssertNotEqual(
            ThresholdModel(acceptanceThreshold: 3, ambiguityMargin: 0.5),
            ThresholdModel(acceptanceThreshold: 4, ambiguityMargin: 0.5)
        )
    }
}
