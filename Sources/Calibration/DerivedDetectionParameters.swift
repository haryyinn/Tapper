import Features
import Foundation

/// Detection parameters derived from a calibration's own samples
/// (`ALGORITHM` §19.6, `DATA_MODELS` §7.7; ADR-017 stage 5).
///
/// Runtime recognition uses these in place of the default constants, so the
/// gates fit the user's taps on this hardware. They contain no audio.
public struct DerivedDetectionParameters: Sendable, Equatable, Codable {

    /// The fixed limit used before derivation existed; a derived limit is
    /// never stricter than this.
    public static let durationFloorMilliseconds = 25.0

    /// Upper Signal Duration limit for uncensored events, in milliseconds.
    public let maximumSignalDurationMilliseconds: Double

    /// The number of samples the parameters were derived from.
    public let sampleCount: Int

    /// Creates derived parameters.
    public init(maximumSignalDurationMilliseconds: Double, sampleCount: Int) {
        self.maximumSignalDurationMilliseconds = maximumSignalDurationMilliseconds
        self.sampleCount = sampleCount
    }

    /// Derives the parameters from raw (unnormalized) feature vectors.
    ///
    /// The duration limit is Tukey's far-out fence, `Q3 + 3·IQR`, over Signal
    /// Duration, floored at ``durationFloorMilliseconds``. Censored durations
    /// participate at full weight (`ALGORITHM` §14.13.5).
    ///
    /// - Parameter samples: Raw feature vectors in ``FeatureVector/values``
    ///   order.
    /// - Returns: The derived parameters, or `nil` if there are no samples.
    public static func derive(fromRawSamples samples: [[Double]]) -> DerivedDetectionParameters? {
        let durations = samples.compactMap { sample -> Double? in
            sample.count == FeatureVector.dimension ? sample[FeatureVector.dimension - 1] : nil
        }.sorted()
        guard !durations.isEmpty else { return nil }
        let q1 = quantile(durations, 0.25)
        let q3 = quantile(durations, 0.75)
        let fence = q3 + 3 * (q3 - q1)
        return DerivedDetectionParameters(
            maximumSignalDurationMilliseconds: Swift.max(fence, durationFloorMilliseconds),
            sampleCount: durations.count)
    }

    /// Linear-interpolated quantile of sorted values.
    private static func quantile(_ sorted: [Double], _ q: Double) -> Double {
        guard sorted.count > 1 else { return sorted[0] }
        let position = q * Double(sorted.count - 1)
        let lower = Int(position.rounded(.down))
        let upper = Swift.min(lower + 1, sorted.count - 1)
        return sorted[lower] + (sorted[upper] - sorted[lower]) * (position - Double(lower))
    }
}
