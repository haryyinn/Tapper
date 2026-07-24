import Foundation
import XCTest

@testable import Calibration
@testable import Classification
@testable import Features

final class ZoneClassifierTests: XCTestCase {

    private let classifier = ZoneClassifier()
    private let timestamp = Date(timeIntervalSince1970: 42)
    // Identity normalization: normalize(x) = x.
    private let identityNormalization = NormalizationParameters(
        means: [Double](repeating: 0, count: 10),
        standardDeviations: [Double](repeating: 1, count: 10))

    /// A valid observation; only `rms` and `spectralCentroid` are varied so
    /// Euclidean distances stay hand-checkable.
    private func observation(rms: Double = 0.32, centroid: Double = 1500) -> FeatureVector {
        FeatureVector(
            peakAmplitude: 0.5, rmsEnergy: rms, spectralCentroid: centroid, spectralBandwidth: 800,
            spectralRollOff: 4000, dominantFrequency: 1200, zeroCrossingRate: 0.1, attackTime: 2,
            decayTime: 5, signalDuration: 10)
    }

    /// A zone profile with identity inverse covariance (Mahalanobis = Euclidean)
    /// and the given mean, which differs from the observation only in `rms`
    /// (index 1) and `centroid` (index 2).
    private func profile(
        _ zone: InteractionZone, rms: Double, centroid: Double = 1500, threshold: Double = 3.0,
        margin: Double = 0.5
    ) -> ZoneProfile {
        let mean = [0.5, rms, centroid, 800, 4000, 1200, 0.1, 2, 5, 10]
        let identity = (0..<10).map { i in (0..<10).map { j in i == j ? 1.0 : 0.0 } }
        return ZoneProfile(
            zone: zone,
            meanVector: MeanVector(values: mean),
            covarianceMatrix: CovarianceMatrix(values: identity),
            inverseCovarianceMatrix: InverseCovarianceMatrix(values: identity),
            threshold: ThresholdModel(acceptanceThreshold: threshold, ambiguityMargin: margin))
    }

    private func classify(_ vector: FeatureVector, _ profiles: [ZoneProfile])
        -> ClassificationOutcome
    {
        classifier.classify(
            featureVector: vector, profiles: profiles, normalization: identityNormalization,
            at: timestamp)
    }

    func testSuccessSelectsNearestZone() {
        // d_TL = |0.32-0.30| = 0.02; d_TR = |0.32-1.0| = 0.68; separation 0.66 ≥ 0.5.
        let outcome = classify(
            observation(), [profile(.topLeft, rms: 0.30), profile(.topRight, rms: 1.0)])
        XCTAssertEqual(outcome.status, .success)
        XCTAssertEqual(outcome.zone, .topLeft)
        XCTAssertEqual(outcome.distance, 0.02, accuracy: 1e-9)
        XCTAssertEqual(outcome.secondBestDistance ?? -1, 0.68, accuracy: 1e-9)
        // Confidence = 100·(1 − 0.02/3).
        XCTAssertEqual(outcome.confidence, 100 * (1 - 0.02 / 3), accuracy: 1e-9)
        XCTAssertEqual(outcome.timestamp, timestamp)
    }

    func testNoZoneWithinThresholdIsUnknown() {
        // Observation centroid 3000 is 1500 away from both zones (> threshold 3).
        let outcome = classify(
            observation(centroid: 3000),
            [profile(.topLeft, rms: 0.30), profile(.topRight, rms: 1.0)])
        XCTAssertEqual(outcome.status, .unknown)
        XCTAssertEqual(outcome.zone, .unknown)
        XCTAssertEqual(outcome.confidence, 0, accuracy: 1e-9)
    }

    func testCloseCandidatesAreAmbiguous() {
        // Observation rms 0.5 is equidistant (0.2) from zones at 0.3 and 0.7.
        let outcome = classify(
            observation(rms: 0.5), [profile(.topLeft, rms: 0.30), profile(.topRight, rms: 0.70)])
        XCTAssertEqual(outcome.status, .ambiguous)
        XCTAssertEqual(outcome.zone, .unknown)
        XCTAssertEqual(outcome.distance, 0.2, accuracy: 1e-9)
    }

    func testInvalidFeatureVectorIsUnknown() {
        let invalid = FeatureVector(
            peakAmplitude: 1.5, rmsEnergy: 0.3, spectralCentroid: 1500, spectralBandwidth: 800,
            spectralRollOff: 4000, dominantFrequency: 1200, zeroCrossingRate: 0.1, attackTime: 2,
            decayTime: 5, signalDuration: 10)
        let outcome = classify(invalid, [profile(.topLeft, rms: 0.30)])
        XCTAssertEqual(outcome.status, .unknown)
        XCTAssertEqual(outcome.zone, .unknown)
    }

    func testEmptyProfilesIsUnknown() {
        XCTAssertEqual(classify(observation(), []).status, .unknown)
    }

    func testConfidenceIsClampedToRange() {
        let outcome = classify(observation(), [profile(.topLeft, rms: 0.32)])  // distance 0
        XCTAssertEqual(outcome.confidence, 100, accuracy: 1e-9)
    }

    func testClassificationIsDeterministic() {
        let profiles = [profile(.topLeft, rms: 0.30), profile(.topRight, rms: 1.0)]
        XCTAssertEqual(classify(observation(), profiles), classify(observation(), profiles))
    }
}
