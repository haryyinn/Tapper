import XCTest

@testable import Calibration

final class ZoneProfileGeneratorTests: XCTestCase {

    // A tight 2-D cluster plus one clear outlier at [5, 5].
    private let clusterWithOutlier: [[Double]] = [
        [0, 0], [0.1, 0.1], [-0.1, -0.1], [0.1, -0.1], [-0.1, 0.1],
        [0.05, -0.05], [-0.05, 0.05], [0.0, 0.1], [0.1, 0.0], [5, 5],
    ]

    private let configuration = CalibrationConfiguration(
        samplesPerZone: 10,
        minimumRetainedSamples: 5,
        regularizationLambda: 1e-3,
        thresholdMultiplier: 2.0,
        ambiguityMargin: 0.5
    )

    func testGeneratesProfileAndRejectsOutlier() throws {
        let result = ZoneProfileGenerator.generate(
            zone: .topLeft, normalizedSamples: clusterWithOutlier, configuration: configuration)
        let profile = try result.get()

        XCTAssertEqual(profile.zone, .topLeft)
        // With the outlier rejected, the mean sits at the cluster centroid
        // (independently computed as [0.0111…, 0.0111…]), not pulled toward [5,5].
        XCTAssertEqual(profile.meanVector.values[0], 0.011111111111, accuracy: 1e-9)
        XCTAssertEqual(profile.meanVector.values[1], 0.011111111111, accuracy: 1e-9)
        // Independently computed acceptance threshold.
        XCTAssertEqual(profile.threshold.acceptanceThreshold, 2.189032393, accuracy: 1e-6)
        XCTAssertEqual(profile.threshold.ambiguityMargin, 0.5)
    }

    func testGeneratedInverseIsConsistentWithCovariance() throws {
        let profile = try ZoneProfileGenerator.generate(
            zone: .topLeft, normalizedSamples: clusterWithOutlier, configuration: configuration
        ).get()
        let covariance = profile.covarianceMatrix.values
        let inverse = profile.inverseCovarianceMatrix.values
        for i in 0..<2 {
            for j in 0..<2 {
                let entry = (0..<2).reduce(0.0) { $0 + inverse[i][$1] * covariance[$1][j] }
                XCTAssertEqual(entry, i == j ? 1 : 0, accuracy: 1e-9)
            }
        }
    }

    func testEmptyDatasetFails() {
        let result = ZoneProfileGenerator.generate(
            zone: .topLeft, normalizedSamples: [], configuration: configuration)
        XCTAssertEqual(result, .failure(.emptyDataset))
    }

    func testInsufficientRetainedSamplesFails() {
        let tooFew: [[Double]] = [[0, 0], [0.1, 0.1], [-0.1, -0.1]]
        let result = ZoneProfileGenerator.generate(
            zone: .topLeft, normalizedSamples: tooFew, configuration: configuration)
        XCTAssertEqual(result, .failure(.insufficientRetainedSamples(retained: 3, required: 5)))
    }
}
