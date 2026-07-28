import Calibration
import Foundation

/// A point to be inspected in feature space.
public struct InspectionPoint: Sendable {

    /// How the point arose.
    public enum Kind: String, Sendable {
        /// A labelled sample stored in the calibration profile.
        case calibration
        /// A validation tap the recogniser assigned to the expected zone.
        case correct
        /// A validation tap assigned to the wrong zone.
        case misclassified
        /// A validation tap that was not recognised.
        case unknown
    }

    /// The zone this point belongs to: its label for a calibration sample, the
    /// expected zone for a validation tap.
    public let zone: String

    /// The zone a recogniser reported, when the point came from validation.
    public let reportedZone: String?

    /// The point's kind.
    public let kind: Kind

    /// The normalized feature vector.
    public let vector: [Double]

    /// Creates an inspection point.
    public init(zone: String, reportedZone: String?, kind: Kind, vector: [Double]) {
        self.zone = zone
        self.reportedZone = reportedZone
        self.kind = kind
        self.vector = vector
    }
}

/// Geometric statistics over the labelled calibration dataset (ADR-016 §5).
///
/// Answers the questions that summary statistics cannot: do these zones
/// overlap, is a given tap an outlier or a separate cluster, and how much of the
/// structure survives a two-dimensional view. It reports geometry and makes no
/// recommendation.
public struct FeatureSpaceReport: Sendable {

    /// Per-zone spread about its own centroid.
    public struct ZoneSummary: Sendable {
        public let zone: String
        public let count: Int
        public let meanRadius: Double
        public let maximumRadius: Double
        /// Samples further than `mean + 2σ` from their own centroid.
        public let outliers: Int
    }

    /// How two zones relate.
    public struct ZonePair: Sendable {
        public let first: String
        public let second: String
        /// Distance between the two centroids.
        public let centroidDistance: Double
        /// Sum of the two zones' mean radii. When this exceeds the centroid
        /// distance, the clusters' typical extents reach past each other.
        public let combinedSpread: Double
        /// `centroidDistance / combinedSpread`. Below 1 indicates overlap.
        public var separation: Double {
            combinedSpread > 0 ? centroidDistance / combinedSpread : .infinity
        }
    }

    public let zones: [ZoneSummary]
    public let pairs: [ZonePair]

    /// Builds the report from labelled calibration samples.
    ///
    /// - Parameter samplesByZone: Normalized samples, keyed by zone name.
    public static func make(samplesByZone: [String: [[Double]]]) -> FeatureSpaceReport {
        let ordered = InteractionZone.calibratable.map(\.rawValue)
            .filter { samplesByZone[$0]?.isEmpty == false }

        var centroids: [String: [Double]] = [:]
        var summaries: [ZoneSummary] = []
        for zone in ordered {
            guard let samples = samplesByZone[zone], !samples.isEmpty else { continue }
            let centroid = Self.centroid(of: samples)
            centroids[zone] = centroid
            let radii = samples.map { EuclideanDistance.distance($0, centroid) }
            let mean = radii.reduce(0, +) / Double(radii.count)
            let sigma =
                radii.count > 1
                ? (radii.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(radii.count - 1))
                    .squareRoot() : 0
            summaries.append(
                ZoneSummary(
                    zone: zone, count: samples.count, meanRadius: mean,
                    maximumRadius: radii.max() ?? 0,
                    outliers: radii.filter { $0 > mean + 2 * sigma }.count))
        }

        var pairs: [ZonePair] = []
        for (index, first) in ordered.enumerated() {
            for second in ordered.dropFirst(index + 1) {
                guard let a = centroids[first], let b = centroids[second],
                    let sa = summaries.first(where: { $0.zone == first }),
                    let sb = summaries.first(where: { $0.zone == second })
                else { continue }
                pairs.append(
                    ZonePair(
                        first: first, second: second,
                        centroidDistance: EuclideanDistance.distance(a, b),
                        combinedSpread: sa.meanRadius + sb.meanRadius))
            }
        }
        return FeatureSpaceReport(zones: summaries, pairs: pairs)
    }

    private static func centroid(of samples: [[Double]]) -> [Double] {
        guard let width = samples.first?.count else { return [] }
        var sum = [Double](repeating: 0, count: width)
        for sample in samples where sample.count == width {
            for index in 0..<width { sum[index] += sample[index] }
        }
        return sum.map { $0 / Double(samples.count) }
    }
}
