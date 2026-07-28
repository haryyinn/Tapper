import Calibration
import Features
import Foundation

/// One stored sample considered during a k-Nearest Neighbour decision.
///
/// Reported so a decision can be explained by naming the samples that produced
/// it (`ALGORITHM` §17.23).
public struct NeighbourReference: Sendable, Equatable {

    /// The label of the stored sample.
    public let zone: InteractionZone

    /// Its distance from the observation, in normalized feature space.
    public let distance: Double

    /// Its share of the total vote weight.
    public let weight: Double

    /// Creates a neighbour reference.
    public init(zone: InteractionZone, distance: Double, weight: Double) {
        self.zone = zone
        self.distance = distance
        self.weight = weight
    }
}

/// Classifies an observation against the labelled samples stored in the
/// calibration profile (`ALGORITHM` §17.23, ADR-015).
///
/// Deterministic: neighbour selection and vote ties are broken by the canonical
/// zone order (§18.11), so identical inputs always yield identical output. It
/// estimates no parameters, represents zones the user taps in more than one way,
/// and accepts new samples in constant time.
public struct NearestNeighbourClassifier: Sendable {

    /// Number of neighbours considered.
    public let k: Int

    /// Guards against division by zero when an observation coincides exactly
    /// with a stored sample.
    private let epsilon: Double

    /// Creates a classifier.
    ///
    /// - Parameters:
    ///   - k: Neighbours to consider. Defaults to 3 (`ALGORITHM` §17.23.4).
    ///   - epsilon: Weight-stabilising constant.
    public init(k: Int = 3, epsilon: Double = 1e-9) {
        precondition(k > 0, "k must be positive")
        self.k = k
        self.epsilon = epsilon
    }

    /// Classifies a feature vector against the profile's stored samples.
    ///
    /// Returns `unknown` when the profile carries no samples, when the
    /// observation lies outside the winning zone's acceptance radius, or when
    /// the vote margin is not met — honouring the fail-safe principle
    /// (`DECISIONS` ADR-009).
    ///
    /// - Parameters:
    ///   - featureVector: The observed features.
    ///   - profiles: The calibrated zone profiles.
    ///   - normalization: The profile's global normalization transform.
    ///   - ambiguityMargin: Minimum winning-share advantage over the runner-up,
    ///     as a fraction of total weight.
    ///   - timestamp: The classification timestamp.
    /// - Returns: The outcome, plus the neighbours that produced it.
    public func classify(
        featureVector: FeatureVector,
        profiles: [ZoneProfile],
        normalization: NormalizationParameters,
        ambiguityMargin: Double,
        at timestamp: Date
    ) -> (outcome: ClassificationOutcome, neighbours: [NeighbourReference]) {
        let usable = profiles.filter(\.supportsNearestNeighbour)
        guard featureVector.isValid, !usable.isEmpty else {
            return (unknownOutcome(at: timestamp), [])
        }

        let observation = normalization.normalize(featureVector.values)

        // Every stored sample, paired with its label.
        var scored: [(zone: InteractionZone, distance: Double)] = []
        for profile in usable {
            for sample in profile.samples where sample.count == observation.count {
                scored.append(
                    (profile.zone, EuclideanDistance.distance(observation, sample)))
            }
        }
        guard !scored.isEmpty else { return (unknownOutcome(at: timestamp), []) }

        // Deterministic ordering: distance first, canonical zone order on ties.
        scored.sort { lhs, rhs in
            if lhs.distance != rhs.distance { return lhs.distance < rhs.distance }
            return order(of: lhs.zone) < order(of: rhs.zone)
        }

        let selected = Array(scored.prefix(k))
        var weightByZone: [InteractionZone: Double] = [:]
        var neighbours: [NeighbourReference] = []
        var totalWeight = 0.0
        for entry in selected {
            let weight = 1.0 / (entry.distance + epsilon)
            weightByZone[entry.zone, default: 0] += weight
            totalWeight += weight
        }
        for entry in selected {
            let weight = 1.0 / (entry.distance + epsilon)
            neighbours.append(
                NeighbourReference(
                    zone: entry.zone, distance: entry.distance,
                    weight: totalWeight > 0 ? weight / totalWeight : 0))
        }

        // Winner by total weight, canonical order on ties.
        let ranked = weightByZone.sorted { lhs, rhs in
            if lhs.value != rhs.value { return lhs.value > rhs.value }
            return order(of: lhs.key) < order(of: rhs.key)
        }
        guard let winner = ranked.first, totalWeight > 0 else {
            return (unknownOutcome(at: timestamp), neighbours)
        }

        let winningShare = winner.value / totalWeight
        let runnerUpShare = ranked.count > 1 ? ranked[1].value / totalWeight : 0
        let nearestOfWinner =
            selected.filter { $0.zone == winner.key }.map(\.distance).min() ?? .infinity
        let radius =
            usable.first { $0.zone == winner.key }?.neighbourRadius ?? .infinity
        let confidence = winningShare * 100

        // Rejection policy (§17.23.7): distance acceptance, then vote margin.
        let status: RecognitionStatus
        if nearestOfWinner > radius {
            status = .unknown
        } else if winningShare - runnerUpShare < ambiguityMargin {
            status = .ambiguous
        } else {
            status = .success
        }

        return (
            ClassificationOutcome(
                status: status,
                zone: status == .success ? winner.key : .unknown,
                distance: nearestOfWinner,
                confidence: confidence,
                acceptanceThreshold: radius,
                secondBestDistance: ranked.count > 1
                    ? selected.filter { $0.zone == ranked[1].key }.map(\.distance).min() : nil,
                timestamp: timestamp
            ),
            neighbours
        )
    }

    private func unknownOutcome(at timestamp: Date) -> ClassificationOutcome {
        ClassificationOutcome(
            status: .unknown, zone: .unknown, distance: .infinity, confidence: 0,
            acceptanceThreshold: 0, secondBestDistance: nil, timestamp: timestamp)
    }

    /// Canonical zone order, used to break ties deterministically (§18.11).
    private func order(of zone: InteractionZone) -> Int {
        InteractionZone.calibratable.firstIndex(of: zone) ?? Int.max
    }
}
