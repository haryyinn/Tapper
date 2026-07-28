import Calibration
import Features
import XCTest

@testable import Classification

/// Characterization tests for the k-Nearest Neighbour recogniser
/// (`ALGORITHM` §17.23, ADR-015).
///
/// Every expected value below is hand-computed and stated in the test that uses
/// it, so a failure identifies which documented property broke rather than
/// merely reporting a changed number.
///
/// Fixtures vary **only** `spectralCentroid` and hold the other nine features
/// fixed, so a Euclidean distance in normalized space reduces to the difference
/// of two centroids and is computable by hand. Normalization is the identity
/// for the same reason. Amplitude features stay inside `0...1` so the vectors
/// pass ``FeatureVector/validate()``.
final class NearestNeighbourClassifierTests: XCTestCase {

    // MARK: Fixtures

    private let classifier = NearestNeighbourClassifier(k: 3)
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

    private func profile(
        _ zone: InteractionZone, centroids: [Double], multiplier: Double = 2.0
    ) -> ZoneProfile {
        let samples = centroids.map { sample(centroid: $0) }
        let identity = (0..<FeatureVector.dimension).map { row in
            (0..<FeatureVector.dimension).map { $0 == row ? 1.0 : 0.0 }
        }
        return ZoneProfile(
            zone: zone,
            meanVector: MeanVector(values: samples[0]),
            covarianceMatrix: CovarianceMatrix(values: identity),
            inverseCovarianceMatrix: InverseCovarianceMatrix(values: identity),
            threshold: ThresholdModel(acceptanceThreshold: 1e6, ambiguityMargin: 0.1),
            samples: samples,
            neighbourRadius: ZoneProfileGenerator.neighbourRadius(
                of: samples, multiplier: multiplier))
    }

    /// Four zones, five samples each, one hertz apart, one hundred hertz between
    /// zones. Acceptance radius is 1.0 (every leave-one-out nearest-neighbour
    /// distance is 1, so the standard deviation is 0).
    private var tightProfiles: [ZoneProfile] {
        zones.enumerated().map { index, zone in
            profile(zone, centroids: (0..<5).map { 1000 + Double(index) * 100 + Double($0) })
        }
    }

    /// Two adjacent zones ten hertz apart within and between clusters, so the
    /// k nearest neighbours of a probe between them are drawn from both.
    /// Acceptance radius is 10.0.
    private var overlappingProfiles: [ZoneProfile] {
        [
            profile(zones[0], centroids: [1000, 1010, 1020, 1030, 1040]),
            profile(zones[1], centroids: [1050, 1060, 1070, 1080, 1090]),
        ]
    }

    private func classify(
        centroid: Double, profiles: [ZoneProfile], ambiguityMargin: Double = 0.1
    ) -> (outcome: ClassificationOutcome, neighbours: [NeighbourReference]) {
        classifier.classify(
            featureVector: vector(centroid: centroid), profiles: profiles,
            normalization: identityNormalization, ambiguityMargin: ambiguityMargin,
            at: timestamp)
    }

    // MARK: Acceptance radius (§17.23.6)

    /// Leave-one-out nearest-neighbour distances are all 1, so mean + 2·σ = 1.
    func testAcceptanceRadiusOfUniformlySpacedSamples() {
        XCTAssertEqual(tightProfiles[0].neighbourRadius!, 1.0, accuracy: 1e-12)
    }

    /// Samples at 1000, 1010, 1030, 1060, 1100 give leave-one-out distances
    /// [10, 10, 20, 30, 40]: mean 22, sample standard deviation 13.0384048…,
    /// so mean + 2·σ = 48.0768096….
    func testAcceptanceRadiusWithNonZeroSpread() {
        let samples = [1000.0, 1010, 1030, 1060, 1100].map { sample(centroid: $0) }
        let radius = ZoneProfileGenerator.neighbourRadius(of: samples, multiplier: 2.0)
        XCTAssertEqual(radius!, 48.076809620810595, accuracy: 1e-9)
    }

    /// A single sample has no nearest neighbour, so no radius can be estimated.
    func testAcceptanceRadiusUndefinedForSingleSample() {
        XCTAssertNil(
            ZoneProfileGenerator.neighbourRadius(of: [sample(centroid: 1000)], multiplier: 2.0))
    }

    // MARK: Classification

    /// A probe at the centre of each cluster is recognised as that zone.
    func testProbeInsideEachClusterRecognisesThatZone() {
        let profiles = tightProfiles
        for (index, zone) in zones.enumerated() {
            let result = classify(
                centroid: 1000 + Double(index) * 100 + 2, profiles: profiles)
            XCTAssertEqual(result.outcome.status, .success, "\(zone.rawValue)")
            XCTAssertEqual(result.outcome.zone, zone)
            XCTAssertEqual(result.outcome.confidence, 100.0, accuracy: 1e-9)
            XCTAssertEqual(result.neighbours.count, 3)
        }
    }

    /// A probe between two samples of one cluster: nearest distances are
    /// 0.5, 0.5 and 1.5, all from the same zone, so the vote is unanimous and
    /// the reported distance is the nearest, 0.5.
    func testProbeBetweenSamplesOfOneCluster() {
        let result = classify(centroid: 1002.5, profiles: tightProfiles)
        XCTAssertEqual(result.outcome.status, .success)
        XCTAssertEqual(result.outcome.zone, zones[0])
        XCTAssertEqual(result.outcome.distance, 0.5, accuracy: 1e-12)
        XCTAssertEqual(result.outcome.confidence, 100.0, accuracy: 1e-9)
    }

    /// Distance acceptance overrides a unanimous vote: the three nearest
    /// samples are 46, 47 and 48 away and all belong to one zone, but 46
    /// exceeds that zone's radius of 1.0, so the observation is unknown.
    ///
    /// This is the fail-safe property (`DECISIONS` ADR-009): an unrecognised
    /// tap must not be forced into the nearest zone.
    func testObservationBeyondAcceptanceRadiusIsRejectedDespiteUnanimousVote() {
        let result = classify(centroid: 1050, profiles: tightProfiles)
        XCTAssertEqual(result.outcome.status, .unknown)
        XCTAssertEqual(result.outcome.zone, .unknown)
        XCTAssertEqual(result.outcome.distance, 46.0, accuracy: 1e-12)
    }

    /// A probe at 1045 sits 5 from `topLeft`'s 1040 and 5 from `topRight`'s
    /// 1050, then 15 from each of 1030 and 1060. Both pairs tie exactly, and
    /// canonical zone order (§18.11) awards each tie to `topLeft`, giving
    /// neighbours topLeft@5, topRight@5, topLeft@15.
    ///
    /// Weights 1/5, 1/5, 1/15 sum to 7/15; `topLeft` holds 4/15, a share of
    /// 4/7 = 0.571428…, against 3/7 = 0.428571…. The margin is 0.142857…,
    /// which clears an ambiguity margin of 0.10.
    ///
    /// The tie-break decides the winner here: awarding the 15-distance tie to
    /// `topRight` instead would reverse the result.
    func testWeightedVoteWithCanonicalTieBreak() {
        let result = classify(centroid: 1045, profiles: overlappingProfiles)
        XCTAssertEqual(result.outcome.status, .success)
        XCTAssertEqual(result.outcome.zone, zones[0])
        XCTAssertEqual(result.outcome.confidence, 400.0 / 7.0, accuracy: 1e-9)
        XCTAssertEqual(result.outcome.distance, 5.0, accuracy: 1e-12)

        XCTAssertEqual(result.neighbours.map(\.zone), [zones[0], zones[1], zones[0]])
        XCTAssertEqual(result.neighbours.map(\.distance), [5.0, 5.0, 15.0])
        XCTAssertEqual(result.neighbours[0].weight, 3.0 / 7.0, accuracy: 1e-9)
        XCTAssertEqual(result.neighbours[1].weight, 3.0 / 7.0, accuracy: 1e-9)
        XCTAssertEqual(result.neighbours[2].weight, 1.0 / 7.0, accuracy: 1e-9)
    }

    /// The same observation, with the margin raised above the vote's 0.142857…
    /// advantage, is ambiguous rather than assigned.
    func testVoteMarginBelowAmbiguityThresholdYieldsAmbiguous() {
        let result = classify(centroid: 1045, profiles: overlappingProfiles, ambiguityMargin: 0.20)
        XCTAssertEqual(result.outcome.status, .ambiguous)
        XCTAssertEqual(result.outcome.zone, .unknown)
    }

    // MARK: Determinism (§18.11)

    /// Identical inputs give identical output, and the order in which profiles
    /// are supplied does not affect the decision.
    func testClassificationIsDeterministicAndOrderIndependent() {
        let profiles = overlappingProfiles
        let first = classify(centroid: 1045, profiles: profiles)
        let second = classifier.classify(
            featureVector: vector(centroid: 1045), profiles: profiles.reversed(),
            normalization: identityNormalization, ambiguityMargin: 0.1, at: timestamp)
        XCTAssertEqual(first.outcome, second.outcome)
        XCTAssertEqual(first.neighbours, second.neighbours)
    }

    // MARK: Migration (ADR-015)

    /// A profile generated before ADR-015 carries no samples. k-NN must report
    /// that it cannot decide rather than guess from the statistical model.
    func testProfileWithoutSamplesCannotUseNearestNeighbour() {
        let legacy = tightProfiles.map {
            ZoneProfile(
                zone: $0.zone, meanVector: $0.meanVector, covarianceMatrix: $0.covarianceMatrix,
                inverseCovarianceMatrix: $0.inverseCovarianceMatrix, threshold: $0.threshold)
        }
        XCTAssertFalse(legacy.contains(where: \.supportsNearestNeighbour))

        let result = classifier.classify(
            featureVector: vector(centroid: 1002), profiles: legacy,
            normalization: identityNormalization, ambiguityMargin: 0.1, at: timestamp)
        XCTAssertEqual(result.outcome.status, .unknown)
        XCTAssertTrue(result.neighbours.isEmpty)
    }

    /// Mahalanobis classification is unaffected by the added samples: both
    /// recognisers read the same profile (ADR-015, non-destructive migration).
    func testMahalanobisStillClassifiesProfilesCarryingSamples() {
        let outcome = ZoneClassifier().classify(
            featureVector: vector(centroid: 1002), profiles: tightProfiles,
            normalization: identityNormalization, at: timestamp)
        XCTAssertEqual(outcome.zone, zones[0])
        XCTAssertEqual(outcome.status, .success)
    }

    /// An invalid feature vector is rejected before any distance is computed.
    func testInvalidFeatureVectorIsRejected() {
        let invalid = FeatureVector(
            peakAmplitude: 10, rmsEnergy: 0.1, spectralCentroid: 1002, spectralBandwidth: 500,
            spectralRollOff: 2000, dominantFrequency: 460, zeroCrossingRate: 0.15,
            attackTime: 1, decayTime: 5, signalDuration: 14)
        XCTAssertFalse(invalid.isValid)

        let result = classifier.classify(
            featureVector: invalid, profiles: tightProfiles,
            normalization: identityNormalization, ambiguityMargin: 0.1, at: timestamp)
        XCTAssertEqual(result.outcome.status, .unknown)
        XCTAssertTrue(result.neighbours.isEmpty)
    }
}
