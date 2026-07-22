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

    /// Attack Time: the interval from signal onset to peak, in milliseconds
    /// (`ALGORITHM` §14.11).
    ///
    /// Onset is the first sample whose magnitude reaches `onsetThreshold`, a
    /// provisional fraction of the normalized peak (the specification does not
    /// define the onset point).
    ///
    /// - Parameters:
    ///   - signal: The normalized signal over the analysis window.
    ///   - sampleRate: The sample rate, in hertz.
    ///   - onsetThreshold: The onset amplitude threshold.
    /// - Returns: The attack time in milliseconds, or `0` if no onset is found.
    public static func attackTime(
        of signal: [Double],
        sampleRate: Double,
        onsetThreshold: Double = FeatureConstants.attackOnsetThreshold
    ) -> Double {
        guard !signal.isEmpty, sampleRate > 0 else { return 0 }
        guard let peakIndex = signal.indices.max(by: { abs(signal[$0]) < abs(signal[$1]) }),
            let onsetIndex = signal.indices.first(where: { abs(signal[$0]) >= onsetThreshold }),
            peakIndex >= onsetIndex
        else { return 0 }
        return Double(peakIndex - onsetIndex) / sampleRate * 1000
    }

    /// Decay Time: the interval from peak until the signal falls below the
    /// offset threshold, in milliseconds (`ALGORITHM` §14.12).
    ///
    /// If the signal never falls below `offsetThreshold` after the peak, the end
    /// of the window is used.
    ///
    /// - Parameters:
    ///   - signal: The normalized signal over the analysis window.
    ///   - sampleRate: The sample rate, in hertz.
    ///   - offsetThreshold: The offset amplitude threshold.
    /// - Returns: The decay time in milliseconds.
    public static func decayTime(
        of signal: [Double],
        sampleRate: Double,
        offsetThreshold: Double = FeatureConstants.decayOffsetThreshold
    ) -> Double {
        guard !signal.isEmpty, sampleRate > 0 else { return 0 }
        guard let peakIndex = signal.indices.max(by: { abs(signal[$0]) < abs(signal[$1]) })
        else { return 0 }
        var decayEnd = signal.count - 1
        if peakIndex < signal.count - 1 {
            for index in (peakIndex + 1)..<signal.count where abs(signal[index]) < offsetThreshold {
                decayEnd = index
                break
            }
        }
        return Double(decayEnd - peakIndex) / sampleRate * 1000
    }

    /// Signal Duration: the interval during which the signal stays above the
    /// activity threshold, in milliseconds (`ALGORITHM` §14.13).
    ///
    /// Measured from the first to the last sample whose magnitude reaches
    /// `energyThreshold`, a provisional fraction of the normalized peak (the
    /// specification does not define the threshold).
    ///
    /// - Parameters:
    ///   - signal: The normalized signal over the analysis window.
    ///   - sampleRate: The sample rate, in hertz.
    ///   - energyThreshold: The activity amplitude threshold.
    /// - Returns: The duration in milliseconds, or `0` if no active samples exist.
    public static func signalDuration(
        of signal: [Double],
        sampleRate: Double,
        energyThreshold: Double = FeatureConstants.durationEnergyThreshold
    ) -> Double {
        guard !signal.isEmpty, sampleRate > 0 else { return 0 }
        guard let firstActive = signal.indices.first(where: { abs(signal[$0]) >= energyThreshold }),
            let lastActive = signal.indices.last(where: { abs(signal[$0]) >= energyThreshold })
        else { return 0 }
        return Double(lastActive - firstActive) / sampleRate * 1000
    }
}
