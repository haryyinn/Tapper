import Calibration
import Features
import Foundation

/// Classifies a feature vector against calibrated zone profiles
/// (`ALGORITHM` §17–§18).
///
/// The decision is deterministic: normalize the observation with the global
/// transform, compute the Mahalanobis distance to each zone, rank ascending
/// (breaking exact ties by canonical zone order, §18.11), then apply threshold
/// acceptance (§17.17) and ambiguity detection (§18.10). On insufficient
/// confidence or ambiguity the result is `unknown`/`ambiguous` and no zone is
/// recognized (§18.12).
public struct ZoneClassifier: Sendable {

    /// Creates a classifier.
    public init() {}

    /// Classifies a feature vector.
    ///
    /// - Parameters:
    ///   - featureVector: The observed features.
    ///   - profiles: The calibrated zone profiles.
    ///   - normalization: The global normalization transform from calibration.
    ///   - timestamp: The classification timestamp.
    /// - Returns: The complete classification outcome.
    public func classify(
        featureVector: FeatureVector,
        profiles: [ZoneProfile],
        normalization: NormalizationParameters,
        at timestamp: Date
    ) -> ClassificationOutcome {
        // Invalid input or model -> Unknown (§18.12).
        guard featureVector.isValid, !profiles.isEmpty else {
            return ClassificationOutcome(
                status: .unknown, zone: .unknown, distance: .infinity, confidence: 0,
                acceptanceThreshold: 0, secondBestDistance: nil, timestamp: timestamp)
        }

        let observation = normalization.normalize(featureVector.values)
        let ranked =
            profiles
            .map { profile in
                (
                    profile: profile,
                    distance: MahalanobisDistance.distance(
                        vector: observation,
                        mean: profile.meanVector.values,
                        inverseCovariance: profile.inverseCovarianceMatrix.values)
                )
            }
            .sorted { lhs, rhs in
                if lhs.distance != rhs.distance { return lhs.distance < rhs.distance }
                return order(of: lhs.profile.zone) < order(of: rhs.profile.zone)
            }

        let best = ranked[0]
        let bestDistance = best.distance
        let acceptanceThreshold = best.profile.threshold.acceptanceThreshold
        let ambiguityMargin = best.profile.threshold.ambiguityMargin
        let secondBestDistance = ranked.count > 1 ? ranked[1].distance : nil
        let confidence = self.confidence(distance: bestDistance, threshold: acceptanceThreshold)

        // No zone within threshold -> Unknown (§17.17, §18.12).
        guard bestDistance <= acceptanceThreshold else {
            return ClassificationOutcome(
                status: .unknown, zone: .unknown, distance: bestDistance, confidence: confidence,
                acceptanceThreshold: acceptanceThreshold, secondBestDistance: secondBestDistance,
                timestamp: timestamp)
        }

        // Ambiguous when the best and second-best are too close (§18.10).
        if let second = secondBestDistance, second - bestDistance < ambiguityMargin {
            return ClassificationOutcome(
                status: .ambiguous, zone: .unknown, distance: bestDistance, confidence: confidence,
                acceptanceThreshold: acceptanceThreshold, secondBestDistance: secondBestDistance,
                timestamp: timestamp)
        }

        return ClassificationOutcome(
            status: .success, zone: best.profile.zone, distance: bestDistance,
            confidence: confidence, acceptanceThreshold: acceptanceThreshold,
            secondBestDistance: secondBestDistance, timestamp: timestamp)
    }

    /// Diagnostic confidence, 100·(1 − distance/threshold) clamped to 0–100
    /// (`ALGORITHM` §17.19).
    private func confidence(distance: Double, threshold: Double) -> Double {
        guard threshold > 0 else { return 0 }
        let value = 100 * (1 - distance / threshold)
        return Swift.min(100, Swift.max(0, value))
    }

    /// The canonical order index used for deterministic tie-breaking (§18.11).
    private func order(of zone: InteractionZone) -> Int {
        InteractionZone.calibratable.firstIndex(of: zone) ?? Int.max
    }
}
