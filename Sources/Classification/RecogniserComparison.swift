import Calibration
import Features
import Foundation

/// Constants specific to the k-Nearest Neighbour recogniser (`ALGORITHM`
/// §17.23).
public enum NearestNeighbourConstants {

    /// Neighbours considered per decision (§17.23.4).
    public static let k = 3

    /// Minimum advantage the winning zone's vote share must hold over the
    /// runner-up, as a fraction of total vote weight (§17.23.7 condition 2).
    ///
    /// - Important: This is **not** ``ThresholdModel/ambiguityMargin``. That
    ///   value is an absolute Mahalanobis distance difference; this one is a
    ///   dimensionless share of vote weight. The two are not interchangeable,
    ///   and §17.23.7 does not state which is intended, so this constant is
    ///   declared separately rather than reusing a value with different units.
    ///   It is reported in every comparison so the figure behind a result is
    ///   always visible.
    public static let voteMargin = 0.10
}

/// Runs both recognisers over one observation and reports where they agree.
///
/// Exists so a validation run can measure the two approaches on **identical**
/// feature vectors: any difference in the results is then attributable to the
/// recogniser alone, not to a different tap, a different frame, or a different
/// normalization.
///
/// Comparison only. Neither recogniser can observe the other, and running this
/// changes no runtime behaviour: the Mahalanobis result it reports is computed
/// exactly as ``ZoneClassifier`` computes it in production.
public struct RecogniserComparison: Sendable {

    /// Both recognisers' verdicts for one observation.
    public struct Result: Sendable {

        /// The Mahalanobis verdict — the current production recogniser.
        public let mahalanobis: ClassificationOutcome

        /// The k-NN verdict, or `nil` when the profile predates ADR-015 and
        /// carries no labelled samples.
        ///
        /// `nil` means "could not be evaluated" and is deliberately distinct
        /// from an `unknown` verdict, so an unmigrated profile is reported
        /// rather than silently counted as a k-NN failure.
        public let nearestNeighbour: ClassificationOutcome?

        /// The neighbours behind the k-NN verdict, nearest first.
        public let neighbours: [NeighbourReference]

        /// The vote margin applied to the k-NN decision.
        public let voteMargin: Double

        /// Whether both recognisers reached the same zone.
        ///
        /// `nil` when k-NN could not be evaluated. Both reporting `unknown`
        /// counts as agreement: they agree the tap is unrecognised.
        public var agrees: Bool? {
            nearestNeighbour.map { $0.zone == mahalanobis.zone }
        }

        /// Creates a comparison result.
        public init(
            mahalanobis: ClassificationOutcome,
            nearestNeighbour: ClassificationOutcome?,
            neighbours: [NeighbourReference],
            voteMargin: Double
        ) {
            self.mahalanobis = mahalanobis
            self.nearestNeighbour = nearestNeighbour
            self.neighbours = neighbours
            self.voteMargin = voteMargin
        }
    }

    private let mahalanobis: ZoneClassifier
    private let nearestNeighbour: NearestNeighbourClassifier
    private let voteMargin: Double

    /// Creates a comparison.
    ///
    /// - Parameters:
    ///   - mahalanobis: The production recogniser.
    ///   - nearestNeighbour: The k-NN recogniser.
    ///   - voteMargin: The k-NN vote margin. Defaults to
    ///     ``NearestNeighbourConstants/voteMargin``.
    public init(
        mahalanobis: ZoneClassifier = ZoneClassifier(),
        nearestNeighbour: NearestNeighbourClassifier = NearestNeighbourClassifier(
            k: NearestNeighbourConstants.k),
        voteMargin: Double = NearestNeighbourConstants.voteMargin
    ) {
        self.mahalanobis = mahalanobis
        self.nearestNeighbour = nearestNeighbour
        self.voteMargin = voteMargin
    }

    /// Classifies one observation with both recognisers.
    ///
    /// - Parameters:
    ///   - featureVector: The observed features. Both recognisers receive this
    ///     same vector.
    ///   - profiles: The calibrated zone profiles.
    ///   - normalization: The profile's global normalization transform.
    ///   - timestamp: The classification timestamp.
    /// - Returns: Both verdicts and the neighbours behind the k-NN result.
    public func compare(
        featureVector: FeatureVector,
        profiles: [ZoneProfile],
        normalization: NormalizationParameters,
        at timestamp: Date
    ) -> Result {
        let statistical = mahalanobis.classify(
            featureVector: featureVector, profiles: profiles, normalization: normalization,
            at: timestamp)

        guard profiles.contains(where: \.supportsNearestNeighbour) else {
            return Result(
                mahalanobis: statistical, nearestNeighbour: nil, neighbours: [],
                voteMargin: voteMargin)
        }

        let knn = nearestNeighbour.classify(
            featureVector: featureVector, profiles: profiles, normalization: normalization,
            ambiguityMargin: voteMargin, at: timestamp)

        return Result(
            mahalanobis: statistical, nearestNeighbour: knn.outcome,
            neighbours: knn.neighbours, voteMargin: voteMargin)
    }
}
