import Foundation

/// Time-domain preprocessing transforms applied before frequency analysis.
///
/// Each transform is a small, deterministic, side-effect-free operation on a
/// `Double` sample buffer, applied in the fixed order mandated by `ALGORITHM`
/// §8: DC-offset removal → clipping detection → band-pass filtering → peak
/// normalization → windowing. (Band-pass filtering and windowing live in their
/// own types.) Working in `Double` matches the deterministic-precision rule for
/// all DSP computation.
public enum SignalPreprocessing {

    /// Removes the DC offset by subtracting the mean sample value
    /// (`ALGORITHM` §8, step 1).
    ///
    /// - Parameter samples: The input signal.
    /// - Returns: The signal with its mean removed. An empty input returns empty.
    public static func removeDCOffset(_ samples: [Double]) -> [Double] {
        guard !samples.isEmpty else { return samples }
        let mean = samples.reduce(0, +) / Double(samples.count)
        return samples.map { $0 - mean }
    }

    /// Reports whether the signal contains clipping (`ALGORITHM` §8, step 2).
    ///
    /// A clipped candidate must be rejected before normalization
    /// (`ALGORITHM` §10.4). The threshold is a provisional, configurable tuning
    /// parameter (see ``DSPConstants/clippingThreshold``).
    ///
    /// - Parameters:
    ///   - samples: The input signal.
    ///   - threshold: The absolute amplitude at or above which a sample counts
    ///     as clipped.
    /// - Returns: `true` if any sample's magnitude reaches the threshold.
    public static func isClipped(
        _ samples: [Double],
        threshold: Double = DSPConstants.clippingThreshold
    ) -> Bool {
        samples.contains { abs($0) >= threshold }
    }

    /// Peak-normalizes the signal so its maximum absolute amplitude is 1.0
    /// (`ALGORITHM` §10.2).
    ///
    /// The waveform shape is preserved while amplitude bias is removed. The peak
    /// magnitude used as the divisor — i.e. the pre-normalization peak — is
    /// returned alongside the result, since it is itself a meaningful measurement.
    ///
    /// - Parameter samples: The input signal.
    /// - Returns: A tuple of the normalized signal and the peak magnitude used.
    ///   If the signal is all zeros (or empty), it is returned unchanged with a
    ///   peak of `0`.
    public static func peakNormalized(_ samples: [Double]) -> (normalized: [Double], peak: Double) {
        let peak = samples.reduce(0.0) { Swift.max($0, abs($1)) }
        guard peak > 0 else { return (samples, 0) }
        return (samples.map { $0 / peak }, peak)
    }
}
