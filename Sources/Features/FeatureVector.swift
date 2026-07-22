/// The canonical numerical representation of an acoustic tap
/// (`DATA_MODELS` §6.6).
///
/// Aggregates the ten features in their fixed canonical order. Values are stored
/// raw, in their physical units; per-feature normalization using calibration
/// statistics is a classification-time concern (`ALGORITHM` §15.7–15.8), not a
/// feature-extraction concern. Immutable and free of runtime metadata.
public struct FeatureVector: Sendable, Equatable {

    /// Peak amplitude (normalized, 0–1).
    public let peakAmplitude: Double
    /// RMS energy (normalized, 0–1).
    public let rmsEnergy: Double
    /// Spectral centroid, in hertz.
    public let spectralCentroid: Double
    /// Spectral bandwidth, in hertz.
    public let spectralBandwidth: Double
    /// Spectral roll-off, in hertz.
    public let spectralRollOff: Double
    /// Dominant frequency, in hertz.
    public let dominantFrequency: Double
    /// Zero crossing rate, in crossings per sample.
    public let zeroCrossingRate: Double
    /// Attack time, in milliseconds.
    public let attackTime: Double
    /// Decay time, in milliseconds.
    public let decayTime: Double
    /// Signal duration, in milliseconds.
    public let signalDuration: Double

    /// Creates a feature vector in canonical order (`DATA_MODELS` §6.6).
    public init(
        peakAmplitude: Double,
        rmsEnergy: Double,
        spectralCentroid: Double,
        spectralBandwidth: Double,
        spectralRollOff: Double,
        dominantFrequency: Double,
        zeroCrossingRate: Double,
        attackTime: Double,
        decayTime: Double,
        signalDuration: Double
    ) {
        self.peakAmplitude = peakAmplitude
        self.rmsEnergy = rmsEnergy
        self.spectralCentroid = spectralCentroid
        self.spectralBandwidth = spectralBandwidth
        self.spectralRollOff = spectralRollOff
        self.dominantFrequency = dominantFrequency
        self.zeroCrossingRate = zeroCrossingRate
        self.attackTime = attackTime
        self.decayTime = decayTime
        self.signalDuration = signalDuration
    }
}

/// A validation failure for a ``FeatureVector`` (`DATA_MODELS` §6.8,
/// `ALGORITHM` §15.11).
public enum FeatureVectorValidationError: Error, Equatable {

    /// A value was NaN or infinite.
    case nonFiniteValue

    /// Peak amplitude or RMS energy fell outside `[0, 1]`.
    case amplitudeOutOfRange

    /// A spectral feature was negative.
    case negativeSpectralValue

    /// Attack or decay time was negative.
    case negativeTemporalValue

    /// Signal duration was not greater than zero.
    case nonPositiveSignalDuration
}

extension FeatureVector {

    /// Validates the vector against the canonical rules (`DATA_MODELS` §6.8,
    /// `ALGORITHM` §15.11).
    ///
    /// - Throws: ``FeatureVectorValidationError`` if any element is invalid.
    public func validate() throws {
        let values = [
            peakAmplitude, rmsEnergy, spectralCentroid, spectralBandwidth, spectralRollOff,
            dominantFrequency, zeroCrossingRate, attackTime, decayTime, signalDuration,
        ]
        guard values.allSatisfy(\.isFinite) else {
            throw FeatureVectorValidationError.nonFiniteValue
        }
        guard (0...1).contains(peakAmplitude), (0...1).contains(rmsEnergy) else {
            throw FeatureVectorValidationError.amplitudeOutOfRange
        }
        guard
            spectralCentroid >= 0, spectralBandwidth >= 0, spectralRollOff >= 0,
            dominantFrequency >= 0
        else {
            throw FeatureVectorValidationError.negativeSpectralValue
        }
        guard attackTime >= 0, decayTime >= 0 else {
            throw FeatureVectorValidationError.negativeTemporalValue
        }
        guard signalDuration > 0 else {
            throw FeatureVectorValidationError.nonPositiveSignalDuration
        }
    }

    /// Whether the vector satisfies ``validate()``.
    public var isValid: Bool {
        do {
            try validate()
            return true
        } catch {
            return false
        }
    }
}
