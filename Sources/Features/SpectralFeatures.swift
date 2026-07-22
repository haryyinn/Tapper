import DSP
import Foundation

/// Frequency-domain acoustic features computed from a ``DSP/Spectrum``
/// (`ALGORITHM` §14).
public enum SpectralFeatures {

    /// Spectral Centroid: the magnitude-weighted mean frequency (`ALGORITHM` §14.6).
    ///
    /// - Parameter spectrum: The magnitude spectrum.
    /// - Returns: The centroid in hertz, or `0` when the spectrum has no energy.
    public static func spectralCentroid(_ spectrum: Spectrum) -> Double {
        let totalMagnitude = spectrum.magnitudes.reduce(0, +)
        guard totalMagnitude > 0 else { return 0 }
        let weighted = zip(spectrum.frequencies, spectrum.magnitudes)
            .reduce(0) { $0 + $1.0 * $1.1 }
        return weighted / totalMagnitude
    }

    /// Spectral Bandwidth: the magnitude-weighted spread about the centroid
    /// (`ALGORITHM` §14.7).
    ///
    /// Uses the standard second-moment definition
    /// `√(Σ(fᵢ − centroid)²·Aᵢ / ΣAᵢ)`.
    ///
    /// - Parameters:
    ///   - spectrum: The magnitude spectrum.
    ///   - centroid: The spectral centroid, in hertz.
    /// - Returns: The bandwidth in hertz, or `0` when the spectrum has no energy.
    public static func spectralBandwidth(_ spectrum: Spectrum, centroid: Double) -> Double {
        let totalMagnitude = spectrum.magnitudes.reduce(0, +)
        guard totalMagnitude > 0 else { return 0 }
        let weightedVariance = zip(spectrum.frequencies, spectrum.magnitudes)
            .reduce(0.0) { accumulated, pair in
                let deviation = pair.0 - centroid
                return accumulated + deviation * deviation * pair.1
            }
        return (weightedVariance / totalMagnitude).squareRoot()
    }

    /// Spectral Roll-off: the frequency below which a fraction of the spectral
    /// energy is contained (`ALGORITHM` §14.8).
    ///
    /// - Note: "Spectral energy" is interpreted as the sum of squared magnitudes
    ///   (Σ|Aᵢ|²), the standard definition of energy. If a magnitude-sum
    ///   interpretation were intended instead, only this computation changes.
    ///
    /// - Parameters:
    ///   - spectrum: The magnitude spectrum.
    ///   - energyFraction: The fraction of total energy (default 85%,
    ///     ``FeatureConstants/spectralRollOffEnergyFraction``).
    /// - Returns: The roll-off frequency in hertz, or `0` when the spectrum has
    ///   no energy.
    public static func spectralRollOff(
        _ spectrum: Spectrum,
        energyFraction: Double = FeatureConstants.spectralRollOffEnergyFraction
    ) -> Double {
        let energies = spectrum.magnitudes.map { $0 * $0 }
        let totalEnergy = energies.reduce(0, +)
        guard totalEnergy > 0 else { return 0 }
        let target = energyFraction * totalEnergy
        var cumulative = 0.0
        for index in spectrum.frequencies.indices {
            cumulative += energies[index]
            if cumulative >= target { return spectrum.frequencies[index] }
        }
        return spectrum.frequencies.last ?? 0
    }

    /// Dominant Frequency: the frequency of the maximum-magnitude bin
    /// (`ALGORITHM` §14.9).
    ///
    /// - Parameter spectrum: The magnitude spectrum.
    /// - Returns: The dominant frequency in hertz, or `0` for an empty spectrum.
    public static func dominantFrequency(_ spectrum: Spectrum) -> Double {
        guard
            let peakIndex = spectrum.magnitudes.indices.max(by: {
                spectrum.magnitudes[$0] < spectrum.magnitudes[$1]
            })
        else { return 0 }
        return spectrum.frequencies[peakIndex]
    }
}
