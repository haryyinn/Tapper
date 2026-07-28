import Calibration
import Features
import XCTest

@testable import Classification

/// Tests that the dual-recogniser comparison reports both verdicts for the same
/// observation and distinguishes "k-NN unavailable" from "k-NN says unknown"
/// (ADR-015).
final class RecogniserComparisonTests: XCTestCase {

    private let timestamp = Date(timeIntervalSince1970: 0)

    private func sample(centroid: Double) -> [Double] {
        [0.20, 0.10, centroid, 500, 2000, 460, 0.15, 1.0, 5.0, 14.0]
    }

    private func vector(centroid: Double) -> FeatureVector {
        let values = sample(centroid: centroid)
        return FeatureVector(
            peakAmplitude: values[0], rmsEnergy: values[1], spectralCentroid: values[2],
            spectralBandwidth: values[3], spectralRollOff: values[4],
            dominantFrequency: values[5], zeroCrossingRate: values[6], attackTime: values[7],
            decayTime: values[8], signalDuration: values[9])
    }

    private var identityNormalization: NormalizationParameters {
        NormalizationParameters(
            means: [Double](repeating: 0, count: FeatureVector.dimension),
            standardDeviations: [Double](repeating: 1, count: FeatureVector.dimension))
    }

    private func profiles(withSamples: Bool) -> [ZoneProfile] {
        let identity = (0..<FeatureVector.dimension).map { row in
            (0..<FeatureVector.dimension).map { $0 == row ? 1.0 : 0.0 }
        }
        return InteractionZone.calibratable.enumerated().map { index, zone in
            let samples = (0..<5).map { sample(centroid: 1000 + Double(index) * 100 + Double($0)) }
            return ZoneProfile(
                zone: zone,
                meanVector: MeanVector(values: samples[0]),
                covarianceMatrix: CovarianceMatrix(values: identity),
                inverseCovarianceMatrix: InverseCovarianceMatrix(values: identity),
                threshold: ThresholdModel(acceptanceThreshold: 1e6, ambiguityMargin: 0.5),
                samples: withSamples ? samples : [],
                neighbourRadius: withSamples
                    ? ZoneProfileGenerator.neighbourRadius(of: samples, multiplier: 2.0) : nil)
        }
    }

    /// Both recognisers report a verdict for the same vector, and a matching
    /// pair is recorded as agreement.
    func testBothRecognisersReportVerdictsForTheSameObservation() {
        let result = RecogniserComparison().compare(
            featureVector: vector(centroid: 1002), profiles: profiles(withSamples: true),
            normalization: identityNormalization, at: timestamp)

        XCTAssertEqual(result.mahalanobis.zone, InteractionZone.calibratable[0])
        XCTAssertEqual(result.nearestNeighbour?.zone, InteractionZone.calibratable[0])
        XCTAssertEqual(result.agrees, true)
        XCTAssertEqual(result.neighbours.count, 3)
        XCTAssertEqual(result.voteMargin, NearestNeighbourConstants.voteMargin)
    }

    /// A profile without labelled samples yields no k-NN verdict at all, which
    /// is distinct from a verdict of `unknown`: an unmigrated profile must be
    /// reported, never counted as a k-NN failure.
    func testUnmigratedProfileYieldsNoNearestNeighbourVerdict() {
        let result = RecogniserComparison().compare(
            featureVector: vector(centroid: 1002), profiles: profiles(withSamples: false),
            normalization: identityNormalization, at: timestamp)

        XCTAssertNil(result.nearestNeighbour)
        XCTAssertNil(result.agrees)
        XCTAssertTrue(result.neighbours.isEmpty)
        XCTAssertEqual(result.mahalanobis.zone, InteractionZone.calibratable[0])
    }

    /// The Mahalanobis verdict is identical to what ``ZoneClassifier`` produces
    /// alone, so running the comparison cannot change production behaviour.
    func testMahalanobisVerdictMatchesStandaloneClassifier() {
        let observation = vector(centroid: 1002)
        let zones = profiles(withSamples: true)

        let standalone = ZoneClassifier().classify(
            featureVector: observation, profiles: zones,
            normalization: identityNormalization, at: timestamp)
        let compared = RecogniserComparison().compare(
            featureVector: observation, profiles: zones,
            normalization: identityNormalization, at: timestamp)

        XCTAssertEqual(standalone, compared.mahalanobis)
    }

    /// The k-NN vote margin is a share of vote weight and must not be taken
    /// from the profile's Mahalanobis ambiguity margin, which is an absolute
    /// distance (see ``NearestNeighbourConstants/voteMargin``).
    func testVoteMarginIsIndependentOfProfileAmbiguityMargin() {
        let zones = profiles(withSamples: true)
        XCTAssertEqual(zones[0].threshold.ambiguityMargin, 0.5)
        XCTAssertNotEqual(NearestNeighbourConstants.voteMargin, 0.5)

        let result = RecogniserComparison().compare(
            featureVector: vector(centroid: 1002), profiles: zones,
            normalization: identityNormalization, at: timestamp)
        XCTAssertEqual(result.voteMargin, 0.10)
    }
}
