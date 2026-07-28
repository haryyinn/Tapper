import Calibration
import Features
import XCTest

@testable import Classification

/// Tests the recogniser benchmark and the recognisers it evaluates
/// (`ALGORITHM` §17.24, §17.25, ADR-016).
///
/// Fixtures vary only `spectralCentroid` and use the identity normalization, so
/// every distance reduces to a difference of two centroids and is computable by
/// hand. Expected values are stated in the test that uses them.
final class RecogniserBenchmarkTests: XCTestCase {

    private let timestamp = Date(timeIntervalSince1970: 0)
    private let zones = InteractionZone.calibratable

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

    /// Four zones, five samples each one hertz apart, one hundred hertz between
    /// zones. Zone 0's samples are 1000…1004.
    private func makeProfiles(withSamples: Bool = true) -> [ZoneProfile] {
        let identity = (0..<FeatureVector.dimension).map { row in
            (0..<FeatureVector.dimension).map { $0 == row ? 1.0 : 0.0 }
        }
        return zones.enumerated().map { index, zone in
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

    // MARK: Nearest centroid (§17.24)

    /// Zone 0's samples are 1000…1004, so its centroid is 1002 and the
    /// distances to it are [2, 1, 0, 1, 2]: mean 1.2, sample standard deviation
    /// √0.7 = 0.83666…, giving a radius of 1.2 + 2·0.83666… = 2.873320….
    func testNearestCentroidRadiusAndCentre() {
        let recogniser = NearestCentroidRecogniser(
            profiles: makeProfiles(), normalization: identityNormalization, multiplier: 2.0)
        let verdict = recogniser.classify(vector(centroid: 1002), at: timestamp)

        XCTAssertEqual(verdict.outcome.status, .success)
        XCTAssertEqual(verdict.outcome.zone, zones[0])
        XCTAssertEqual(verdict.distance, 0.0, accuracy: 1e-12)
        XCTAssertEqual(verdict.acceptanceRadius, 2.8733200530681511, accuracy: 1e-9)
        XCTAssertEqual(verdict.outcome.confidence, 100.0, accuracy: 1e-9)
    }

    /// A probe 2 from the centroid is inside the radius of 2.873320…, leaving a
    /// margin of 0.873320….
    func testNearestCentroidAcceptsInsideRadius() {
        let recogniser = NearestCentroidRecogniser(
            profiles: makeProfiles(), normalization: identityNormalization, multiplier: 2.0)
        let verdict = recogniser.classify(vector(centroid: 1004), at: timestamp)

        XCTAssertTrue(verdict.accepted)
        XCTAssertEqual(verdict.outcome.zone, zones[0])
        XCTAssertEqual(verdict.distance, 2.0, accuracy: 1e-12)
        XCTAssertEqual(verdict.acceptanceMargin, 0.8733200530681511, accuracy: 1e-9)
    }

    /// A probe 4 from the centroid exceeds the radius, so it is unknown and its
    /// acceptance margin is negative.
    func testNearestCentroidRejectsOutsideRadius() {
        let recogniser = NearestCentroidRecogniser(
            profiles: makeProfiles(), normalization: identityNormalization, multiplier: 2.0)
        let verdict = recogniser.classify(vector(centroid: 1006), at: timestamp)

        XCTAssertEqual(verdict.outcome.status, .unknown)
        XCTAssertFalse(verdict.accepted)
        XCTAssertLessThan(verdict.acceptanceMargin, 0)
    }

    /// A zone without stored samples has no centroid to compute, so the
    /// recogniser reports itself unusable rather than inventing one.
    func testNearestCentroidUnusableWithoutSamples() {
        let recogniser = NearestCentroidRecogniser(
            profiles: makeProfiles(withSamples: false), normalization: identityNormalization,
            multiplier: 2.0)
        XCTAssertFalse(recogniser.isUsable)
        XCTAssertEqual(
            recogniser.classify(vector(centroid: 1002), at: timestamp).outcome.status, .unknown)
    }

    // MARK: k-NN at several k (§17.25.2)

    /// Each k yields its documented identifier and consults exactly k
    /// neighbours.
    func testNearestNeighbourIdentifiersAndNeighbourCounts() {
        let profiles = makeProfiles()
        let expected = [1: "knn-1", 3: "knn-3-weighted", 5: "knn-5-weighted"]
        for (k, identifier) in expected {
            let recogniser = NearestNeighbourRecogniser(
                profiles: profiles, normalization: identityNormalization, k: k)
            XCTAssertEqual(recogniser.identifier, identifier)

            let verdict = recogniser.classify(vector(centroid: 1002), at: timestamp)
            XCTAssertEqual(verdict.neighbours.count, k, "k=\(k)")
            XCTAssertEqual(verdict.outcome.zone, zones[0], "k=\(k)")
        }
    }

    /// At k = 1 the single neighbour holds the entire vote weight, so
    /// confidence is always 100% and the vote margin cannot reject
    /// (`ALGORITHM` §17.25.2).
    func testNearestNeighbourAtKOneHasDegenerateVote() {
        let recogniser = NearestNeighbourRecogniser(
            profiles: makeProfiles(), normalization: identityNormalization, k: 1)
        for centroid in [1000.0, 1002.4, 1003.9] {
            let verdict = recogniser.classify(vector(centroid: centroid), at: timestamp)
            XCTAssertEqual(verdict.outcome.confidence, 100.0, accuracy: 1e-9)
        }
    }

    // MARK: Benchmark (§17.25)

    /// The standard set is exactly the five recognisers of §17.25.2, in
    /// reporting order.
    func testStandardBenchmarkMembership() {
        let benchmark = RecogniserBenchmark.standard(
            profiles: makeProfiles(), normalization: identityNormalization,
            configuration: .v1)
        XCTAssertEqual(
            benchmark.identifiers,
            ["mahalanobis", "nearest-centroid", "knn-1", "knn-3-weighted", "knn-5-weighted"])
    }

    /// Against a profile predating ADR-015, recognisers needing labelled
    /// samples are omitted rather than reported as failing, so "not evaluated"
    /// stays distinguishable from "evaluated and rejected".
    func testBenchmarkOmitsSampleBasedRecognisersForUnmigratedProfile() {
        let benchmark = RecogniserBenchmark.standard(
            profiles: makeProfiles(withSamples: false), normalization: identityNormalization,
            configuration: .v1)
        XCTAssertEqual(benchmark.identifiers, ["mahalanobis"])
    }

    /// Every recogniser is measured on the same observation, and the results
    /// are stable across repeated evaluation.
    func testBenchmarkEvaluatesEveryRecogniserDeterministically() {
        let benchmark = RecogniserBenchmark.standard(
            profiles: makeProfiles(), normalization: identityNormalization,
            configuration: .v1)

        let first = benchmark.evaluate(vector(centroid: 1002.4), at: timestamp)
        let second = benchmark.evaluate(vector(centroid: 1002.4), at: timestamp)

        XCTAssertEqual(first.count, 5)
        XCTAssertEqual(first.map(\.identifier), second.map(\.identifier))
        XCTAssertEqual(first.map(\.verdict), second.map(\.verdict))
    }

    /// The benchmark's Mahalanobis entry reports exactly what the production
    /// classifier decides, so measuring cannot misrepresent production.
    func testBenchmarkMahalanobisMatchesProductionClassifier() {
        let profiles = makeProfiles()
        let observation = vector(centroid: 1002)

        let production = ZoneClassifier().classify(
            featureVector: observation, profiles: profiles,
            normalization: identityNormalization, at: timestamp)
        let benchmark = RecogniserBenchmark.standard(
            profiles: profiles, normalization: identityNormalization, configuration: .v1)
        let measured = benchmark.evaluate(observation, at: timestamp)
            .first { $0.identifier == "mahalanobis" }

        XCTAssertEqual(measured?.verdict.outcome, production)
    }
}
