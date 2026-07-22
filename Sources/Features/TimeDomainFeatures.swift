import Foundation

/// Time-domain acoustic features (`ALGORITHM` §14).
///
/// These operate on the normalized, band-pass-filtered signal (before Hann
/// windowing, which would distort the temporal envelope). Peak Amplitude is the
/// exception noted below.
public enum TimeDomainFeatures {

    /// Peak Amplitude: the maximum absolute sample value (`ALGORITHM` §14.4).
    ///
    /// - Important: §14.4's formula states the maximum of the *normalized*
    ///   waveform, but peak normalization forces that to a constant 1.0, which
    ///   contradicts the feature's stated purpose (rejecting weak events) and its
    ///   "Normalized (0–1)" unit (§15.6). Per project decision, Peak Amplitude is
    ///   measured on the filtered signal **immediately before** normalization —
    ///   i.e. the magnitude used as the normalization divisor. See backlog BL-1's
    ///   sibling documentation task (BL-2) to correct §14.4.
    ///
    /// - Parameter filteredSignal: The band-pass-filtered signal, before
    ///   normalization.
    /// - Returns: The maximum absolute amplitude, or `0` for an empty signal.
    public static func peakAmplitude(of filteredSignal: [Double]) -> Double {
        filteredSignal.reduce(0.0) { Swift.max($0, abs($1)) }
    }

    /// RMS Energy: the root-mean-square of the signal (`ALGORITHM` §14.5).
    ///
    /// - Parameter signal: The normalized signal over the analysis window.
    /// - Returns: The RMS energy, or `0` for an empty signal.
    public static func rmsEnergy(of signal: [Double]) -> Double {
        guard !signal.isEmpty else { return 0 }
        let sumOfSquares = signal.reduce(0) { $0 + $1 * $1 }
        return (sumOfSquares / Double(signal.count)).squareRoot()
    }

    /// Zero Crossing Rate: sign changes per sample (`ALGORITHM` §14.10, §15.6).
    ///
    /// Counts strict sign changes (transitions through zero) and divides by the
    /// window length, yielding crossings per sample.
    ///
    /// - Parameter signal: The normalized signal over the analysis window.
    /// - Returns: The zero-crossing rate in crossings per sample, or `0` when
    ///   fewer than two samples are present.
    public static func zeroCrossingRate(of signal: [Double]) -> Double {
        guard signal.count > 1 else { return 0 }
        var crossings = 0
        for index in 1..<signal.count where signal[index - 1] * signal[index] < 0 {
            crossings += 1
        }
        return Double(crossings) / Double(signal.count)
    }
}
