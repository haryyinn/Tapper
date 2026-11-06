import Features
import Foundation

/// Aggregate localisation and decay telemetry over extracted events
/// (`ALGORITHM` §14.13.4, ADR-017 §5). Diagnostic only.
public struct EventStatistics: Sendable, Equatable {

    /// Number of events summarised.
    public let count: Int

    /// Median decay time constant τ, in milliseconds.
    public let medianTimeConstantMilliseconds: Double

    /// 10th and 90th percentile of τ, in milliseconds.
    public let timeConstantP10Milliseconds: Double
    public let timeConstantP90Milliseconds: Double

    /// Median coefficient of determination of the decay fits.
    public let medianCoefficientOfDetermination: Double

    /// Median fitted range, in decibels.
    public let medianFitRangeDB: Double

    /// Fraction of events whose decay was censored (§14.13.5).
    public let censoredFraction: Double

    /// Fraction of events meeting the high-confidence criteria (§14.13.4).
    public let highConfidenceFraction: Double

    /// Median onset position relative to the detecting frame's peak, in
    /// samples.
    public let medianOnsetOffsetSamples: Double

    /// Pearson correlation between Decay Time and Signal Duration (feature
    /// slots 8 and 9), or `nil` if undefined. The collinearity gate of the
    /// measurement plan escalates when `|r| > 0.95`.
    public let decayDurationCorrelation: Double?

    /// Summarises events, or returns `nil` if there are none.
    ///
    /// - Parameter events: Each event's telemetry and feature vector.
    public static func make(from events: [(EventTelemetry, FeatureVector)]) -> EventStatistics? {
        guard !events.isEmpty else { return nil }
        let telemetry = events.map(\.0)
        let taus = telemetry.map(\.decay.timeConstantMilliseconds).sorted()
        let count = Double(events.count)
        return EventStatistics(
            count: events.count,
            medianTimeConstantMilliseconds: quantile(taus, 0.5),
            timeConstantP10Milliseconds: quantile(taus, 0.1),
            timeConstantP90Milliseconds: quantile(taus, 0.9),
            medianCoefficientOfDetermination: quantile(
                telemetry.map(\.decay.coefficientOfDetermination).sorted(), 0.5),
            medianFitRangeDB: quantile(telemetry.map(\.decay.fitRangeDB).sorted(), 0.5),
            censoredFraction: Double(telemetry.filter(\.decay.isCensored).count) / count,
            highConfidenceFraction: Double(telemetry.filter(\.decay.isHighConfidence).count)
                / count,
            medianOnsetOffsetSamples: quantile(
                telemetry.map { Double($0.onsetOffsetSamples) }.sorted(), 0.5),
            decayDurationCorrelation: pearson(
                events.map(\.1.decayTime), events.map(\.1.signalDuration)))
    }

    /// Linear-interpolated quantile of sorted values.
    private static func quantile(_ sorted: [Double], _ q: Double) -> Double {
        guard sorted.count > 1 else { return sorted.first ?? 0 }
        let position = q * Double(sorted.count - 1)
        let lower = Int(position.rounded(.down))
        let upper = Swift.min(lower + 1, sorted.count - 1)
        let fraction = position - Double(lower)
        return sorted[lower] + (sorted[upper] - sorted[lower]) * fraction
    }

    /// Pearson correlation, or `nil` when either series has no variance.
    private static func pearson(_ x: [Double], _ y: [Double]) -> Double? {
        guard x.count > 1 else { return nil }
        let n = Double(x.count)
        let meanX = x.reduce(0, +) / n
        let meanY = y.reduce(0, +) / n
        var covariance = 0.0
        var varianceX = 0.0
        var varianceY = 0.0
        for (a, b) in zip(x, y) {
            covariance += (a - meanX) * (b - meanY)
            varianceX += (a - meanX) * (a - meanX)
            varianceY += (b - meanY) * (b - meanY)
        }
        guard varianceX > 0, varianceY > 0 else { return nil }
        return covariance / (varianceX * varianceY).squareRoot()
    }
}
