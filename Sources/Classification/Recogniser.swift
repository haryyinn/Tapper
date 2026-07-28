import Calibration
import Features
import Foundation

/// Constants specific to the k-Nearest Neighbour recogniser (`ALGORITHM`
/// §17.23).
public enum NearestNeighbourConstants {

    /// Neighbours considered per decision by default (§17.23.4).
    public static let k = 3

    /// Minimum advantage the winning zone's vote share must hold over the
    /// runner-up, as a fraction of total vote weight (§17.23.7 condition 2).
    ///
    /// - Important: This is **not** ``ThresholdModel/ambiguityMargin``. That
    ///   value is an absolute Mahalanobis distance difference; this one is a
    ///   dimensionless share of vote weight. The two are not interchangeable,
    ///   and §17.23.7 does not state which is intended, so this constant is
    ///   declared separately rather than reusing a value with different units.
    ///   It is recorded in every exported verdict so the figure behind a result
    ///   is always visible. See BACKLOG BL-14.
    public static let voteMargin = 0.10
}

/// One recogniser's verdict for one observation.
public struct RecogniserVerdict: Sendable, Equatable {

    /// The classification outcome.
    public let outcome: ClassificationOutcome

    /// The neighbours behind the decision, nearest first. Empty for recognisers
    /// that do not consult individual samples.
    public let neighbours: [NeighbourReference]

    /// Creates a verdict.
    public init(outcome: ClassificationOutcome, neighbours: [NeighbourReference] = []) {
        self.outcome = outcome
        self.neighbours = neighbours
    }

    /// The distance the decision was tested against its acceptance radius.
    public var distance: Double { outcome.distance }

    /// The acceptance radius applied.
    public var acceptanceRadius: Double { outcome.acceptanceThreshold }

    /// How far inside the acceptance radius the observation fell. Negative when
    /// the observation was outside it (`ALGORITHM` §17.25.6).
    public var acceptanceMargin: Double { acceptanceRadius - distance }

    /// Whether the observation was accepted as a zone.
    public var accepted: Bool { outcome.status == .success }
}

/// A deterministic mapping from a feature vector to a classification outcome,
/// given a calibration profile (`ALGORITHM` §17.25).
///
/// A conforming type is **constructed against a profile** and then classifies
/// many observations. Everything derivable from the profile — centroids, radii,
/// inverted covariances — is computed during construction, so that a latency
/// measurement reflects classification and not model preparation (§17.25.4).
/// Without this, a recogniser that rebuilt its model per call would appear
/// slower for a reason unrelated to its merits.
public protocol Recogniser: Sendable {

    /// Stable identifier used in reports (`ALGORITHM` §17.25.2).
    var identifier: String { get }

    /// Classifies one observation.
    ///
    /// - Parameters:
    ///   - featureVector: The observed features, in raw units. The recogniser
    ///     applies the profile's normalization itself.
    ///   - timestamp: The classification timestamp.
    /// - Returns: The verdict.
    func classify(_ featureVector: FeatureVector, at timestamp: Date) -> RecogniserVerdict
}

/// The production recogniser (`ALGORITHM` §17.13), wrapped for benchmarking.
///
/// It delegates to ``ZoneClassifier`` unchanged, so a benchmark reports exactly
/// what production would decide.
public struct MahalanobisRecogniser: Recogniser {

    public let identifier = "mahalanobis"

    private let classifier: ZoneClassifier
    private let profiles: [ZoneProfile]
    private let normalization: NormalizationParameters

    /// Creates a Mahalanobis recogniser bound to a profile.
    public init(
        profiles: [ZoneProfile], normalization: NormalizationParameters,
        classifier: ZoneClassifier = ZoneClassifier()
    ) {
        self.profiles = profiles
        self.normalization = normalization
        self.classifier = classifier
    }

    public func classify(_ featureVector: FeatureVector, at timestamp: Date) -> RecogniserVerdict {
        RecogniserVerdict(
            outcome: classifier.classify(
                featureVector: featureVector, profiles: profiles,
                normalization: normalization, at: timestamp))
    }
}

/// Assigns an observation to the zone whose mean sample is closest
/// (`ALGORITHM` §17.24).
///
/// The simplest recogniser that uses the stored samples, and therefore the
/// baseline any more elaborate recogniser must justify itself against. It
/// estimates no covariance, so nothing is inverted and no regularization is
/// needed.
public struct NearestCentroidRecogniser: Recogniser {

    public let identifier = "nearest-centroid"

    /// A zone's centroid and acceptance radius, computed once at construction.
    private struct Model: Sendable {
        let zone: InteractionZone
        let centroid: [Double]
        let radius: Double
        let ambiguityMargin: Double
    }

    private let models: [Model]

    /// Creates a nearest-centroid recogniser bound to a profile.
    ///
    /// - Parameters:
    ///   - profiles: The calibrated zones. Zones without stored samples are
    ///     skipped: their centroid cannot be recomputed from a mean vector
    ///     alone without also assuming the spread.
    ///   - normalization: Retained for symmetry with the other recognisers;
    ///     stored samples are already normalized.
    ///   - multiplier: The threshold multiplier `k` of §17.24.3.
    public init(
        profiles: [ZoneProfile], normalization: NormalizationParameters, multiplier: Double
    ) {
        self.normalization = normalization
        self.models = profiles.compactMap { profile in
            guard !profile.samples.isEmpty else { return nil }
            let centroid = Self.centroid(of: profile.samples)
            let distances = profile.samples.map { EuclideanDistance.distance($0, centroid) }
            return Model(
                zone: profile.zone,
                centroid: centroid,
                radius: Self.threshold(from: distances, multiplier: multiplier),
                ambiguityMargin: profile.threshold.ambiguityMargin)
        }
    }

    private let normalization: NormalizationParameters

    /// Whether this recogniser has a usable model.
    public var isUsable: Bool { !models.isEmpty }

    public func classify(_ featureVector: FeatureVector, at timestamp: Date) -> RecogniserVerdict {
        guard featureVector.isValid, !models.isEmpty else {
            return RecogniserVerdict(outcome: Self.unknown(at: timestamp))
        }
        let observation = normalization.normalize(featureVector.values)

        // Deterministic ordering: distance first, canonical zone order on ties.
        let ranked =
            models
            .map { (model: $0, distance: EuclideanDistance.distance(observation, $0.centroid)) }
            .sorted { lhs, rhs in
                if lhs.distance != rhs.distance { return lhs.distance < rhs.distance }
                return Self.order(of: lhs.model.zone) < Self.order(of: rhs.model.zone)
            }

        let best = ranked[0]
        let runnerUp = ranked.count > 1 ? ranked[1].distance : nil
        let confidence = Self.confidence(distance: best.distance, radius: best.model.radius)

        let status: RecognitionStatus
        if best.distance > best.model.radius {
            status = .unknown
        } else if let second = runnerUp, second - best.distance < best.model.ambiguityMargin {
            status = .ambiguous
        } else {
            status = .success
        }

        return RecogniserVerdict(
            outcome: ClassificationOutcome(
                status: status,
                zone: status == .success ? best.model.zone : .unknown,
                distance: best.distance,
                confidence: confidence,
                acceptanceThreshold: best.model.radius,
                secondBestDistance: runnerUp,
                timestamp: timestamp))
    }

    private static func centroid(of samples: [[Double]]) -> [Double] {
        guard let width = samples.first?.count else { return [] }
        var sum = [Double](repeating: 0, count: width)
        for sample in samples where sample.count == width {
            for index in 0..<width { sum[index] += sample[index] }
        }
        return sum.map { $0 / Double(samples.count) }
    }

    /// The `mean + k·σ` threshold, matching §17.18 and using the sample
    /// standard deviation, as ``ZoneProfileGenerator`` does.
    private static func threshold(from distances: [Double], multiplier: Double) -> Double {
        guard !distances.isEmpty else { return 0 }
        let mean = distances.reduce(0, +) / Double(distances.count)
        guard distances.count > 1 else { return mean }
        let variance =
            distances.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(distances.count - 1)
        return mean + multiplier * variance.squareRoot()
    }

    /// Diagnostic confidence on the scale of §17.17: 100% at the centroid,
    /// falling to 0% at the acceptance radius.
    private static func confidence(distance: Double, radius: Double) -> Double {
        guard radius > 0 else { return 0 }
        return Swift.max(0, Swift.min(100, (1 - distance / radius) * 100))
    }

    private static func order(of zone: InteractionZone) -> Int {
        InteractionZone.calibratable.firstIndex(of: zone) ?? Int.max
    }

    private static func unknown(at timestamp: Date) -> ClassificationOutcome {
        ClassificationOutcome(
            status: .unknown, zone: .unknown, distance: .infinity, confidence: 0,
            acceptanceThreshold: 0, secondBestDistance: nil, timestamp: timestamp)
    }
}

/// Distance-weighted k-Nearest Neighbour (`ALGORITHM` §17.23), wrapped for
/// benchmarking at a configurable k.
///
/// - Note: At k = 1 the weighted vote is degenerate — the single neighbour holds
///   the entire vote weight — so the vote-margin condition is always satisfied
///   and only distance acceptance governs rejection (§17.25.2).
public struct NearestNeighbourRecogniser: Recogniser {

    public let identifier: String

    private let classifier: NearestNeighbourClassifier
    private let profiles: [ZoneProfile]
    private let normalization: NormalizationParameters
    private let voteMargin: Double

    /// Creates a k-NN recogniser bound to a profile.
    ///
    /// - Parameters:
    ///   - profiles: The calibrated zones.
    ///   - normalization: The profile's normalization transform.
    ///   - k: Neighbours to consider.
    ///   - voteMargin: The vote margin of §17.23.7.
    ///   - identifier: The benchmark identifier. Defaults to the §17.25.2 name
    ///     for this k.
    public init(
        profiles: [ZoneProfile],
        normalization: NormalizationParameters,
        k: Int,
        voteMargin: Double = NearestNeighbourConstants.voteMargin,
        identifier: String? = nil
    ) {
        self.profiles = profiles
        self.normalization = normalization
        self.voteMargin = voteMargin
        self.classifier = NearestNeighbourClassifier(k: k)
        self.identifier = identifier ?? (k == 1 ? "knn-1" : "knn-\(k)-weighted")
    }

    /// Whether any zone carries the labelled samples this recogniser needs.
    public var isUsable: Bool { profiles.contains(where: \.supportsNearestNeighbour) }

    public func classify(_ featureVector: FeatureVector, at timestamp: Date) -> RecogniserVerdict {
        let result = classifier.classify(
            featureVector: featureVector, profiles: profiles, normalization: normalization,
            ambiguityMargin: voteMargin, at: timestamp)
        return RecogniserVerdict(outcome: result.outcome, neighbours: result.neighbours)
    }
}
