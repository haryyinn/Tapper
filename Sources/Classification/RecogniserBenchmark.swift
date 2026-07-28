import Calibration
import Features
import Foundation

/// One recogniser's measured result for one observation (`ALGORITHM` §17.25.6).
public struct RecogniserMeasurement: Sendable {

    /// The benchmark identifier of the recogniser.
    public let identifier: String

    /// Its verdict.
    public let verdict: RecogniserVerdict

    /// Classification latency, in microseconds. Model preparation is excluded
    /// by construction (§17.25.4).
    public let latencyMicroseconds: Double

    /// Creates a measurement.
    public init(identifier: String, verdict: RecogniserVerdict, latencyMicroseconds: Double) {
        self.identifier = identifier
        self.verdict = verdict
        self.latencyMicroseconds = latencyMicroseconds
    }
}

/// Evaluates a set of recognisers on identical observations (`ALGORITHM` §17.25).
///
/// A **measurement facility**. Its results are reported and never acted upon:
/// nothing here selects, promotes, or disables a recogniser, and the production
/// recogniser is unaffected by anything measured (ADR-016).
///
/// Every recogniser is constructed once, against the profile, before any
/// measurement is taken, so reported latency reflects classification alone.
public struct RecogniserBenchmark: Sendable {

    /// The recognisers evaluated, in reporting order.
    public let recognisers: [any Recogniser]

    /// Creates a benchmark over an explicit set.
    public init(recognisers: [any Recogniser]) {
        self.recognisers = recognisers
    }

    /// The Version 1 benchmark set (`ALGORITHM` §17.25.2).
    ///
    /// Recognisers requiring labelled samples are omitted when the profile
    /// predates ADR-015, so that "not evaluated" stays distinguishable from
    /// "evaluated and rejected" (`DATA_MODELS` §7.13a).
    ///
    /// - Parameters:
    ///   - profiles: The calibrated zones.
    ///   - normalization: The profile's normalization transform.
    ///   - configuration: Supplies the threshold multiplier for §17.24.3.
    /// - Returns: The benchmark.
    public static func standard(
        profiles: [ZoneProfile],
        normalization: NormalizationParameters,
        configuration: CalibrationConfiguration
    ) -> RecogniserBenchmark {
        var set: [any Recogniser] = [
            MahalanobisRecogniser(profiles: profiles, normalization: normalization)
        ]

        let centroid = NearestCentroidRecogniser(
            profiles: profiles, normalization: normalization,
            multiplier: configuration.thresholdMultiplier)
        if centroid.isUsable { set.append(centroid) }

        for k in [1, 3, 5] {
            let knn = NearestNeighbourRecogniser(
                profiles: profiles, normalization: normalization, k: k)
            if knn.isUsable { set.append(knn) }
        }
        return RecogniserBenchmark(recognisers: set)
    }

    /// The identifiers of every recogniser evaluated.
    public var identifiers: [String] { recognisers.map(\.identifier) }

    /// Evaluates every recogniser on the same feature vector.
    ///
    /// The identical instance is passed to each, so any difference between
    /// their verdicts is attributable to the recogniser alone (§17.25.3).
    ///
    /// - Parameters:
    ///   - featureVector: The observation.
    ///   - timestamp: The classification timestamp.
    /// - Returns: One measurement per recogniser, in reporting order.
    public func evaluate(
        _ featureVector: FeatureVector, at timestamp: Date
    ) -> [RecogniserMeasurement] {
        recognisers.map { recogniser in
            let started = DispatchTime.now().uptimeNanoseconds
            let verdict = recogniser.classify(featureVector, at: timestamp)
            let elapsed = DispatchTime.now().uptimeNanoseconds - started
            return RecogniserMeasurement(
                identifier: recogniser.identifier, verdict: verdict,
                latencyMicroseconds: Double(elapsed) / 1000.0)
        }
    }
}
