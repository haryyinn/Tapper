import DSP
import Foundation

/// Runs the full feature-extraction pipeline for one analysis frame.
///
/// The stages execute in the fixed order mandated by `ALGORITHM` §8 / §16:
/// DC-offset removal → clipping detection → band-pass filter → peak
/// normalization → time-domain features → Hann window → FFT → spectral features
/// → `FeatureVector`. Time-domain features are computed on the normalized signal
/// (before windowing); Peak Amplitude uses the pre-normalization peak (see
/// ``TimeDomainFeatures/peakAmplitude(of:)``).
///
/// A clipped frame is rejected (`ALGORITHM` §10.4) and yields `nil`. Structural
/// validation of the produced vector (`ALGORITHM` §15.11) is left to the
/// consumer via ``FeatureVector/validate()``.
public struct FeatureExtractionPipeline {

    /// The expected frame length, in samples.
    public let frameSize: Int

    /// The sample rate, in hertz.
    public let sampleRate: Double

    private let filter: ButterworthBandpass
    private let hannWindow: HannWindow
    private let fourierTransform: FourierTransform
    private let clippingThreshold: Double

    /// Creates a feature-extraction pipeline.
    ///
    /// - Parameters:
    ///   - frameSize: The analysis frame length, in samples.
    ///   - fftSize: The FFT size, in samples (≥ `frameSize`).
    ///   - sampleRate: The sample rate, in hertz.
    ///   - filter: The band-pass filter to apply.
    ///   - clippingThreshold: The clipping-rejection threshold.
    /// - Throws: An error if the FFT of `fftSize` cannot be created.
    public init(
        frameSize: Int,
        fftSize: Int,
        sampleRate: Double,
        filter: ButterworthBandpass,
        clippingThreshold: Double = DSPConstants.clippingThreshold
    ) throws {
        self.frameSize = frameSize
        self.sampleRate = sampleRate
        self.filter = filter
        self.hannWindow = HannWindow(size: frameSize)
        self.fourierTransform = try FourierTransform(size: fftSize, sampleRate: sampleRate)
        self.clippingThreshold = clippingThreshold
    }

    /// The Version 1 pipeline: 1920-sample frames, 2048-point FFT, 48 kHz,
    /// and the Version 1 band-pass filter.
    ///
    /// - Throws: An error if the FFT cannot be created.
    public static func v1() throws -> FeatureExtractionPipeline {
        try FeatureExtractionPipeline(
            frameSize: 1920,
            fftSize: 2048,
            sampleRate: 48_000,
            filter: .v1
        )
    }

    /// Extracts a feature vector from one self-contained frame.
    ///
    /// The frame is treated as the whole observation: it is preprocessed from
    /// zero filter state and measured with ``measure(eventWindow:noiseFloorRMS:)``.
    /// Runtime recognition measures onset-anchored event windows instead
    /// (`ALGORITHM` §23.4.1); this entry point serves offline tooling and tests.
    ///
    /// - Parameter samples: The frame's samples, in `Double`. Its count must
    ///   equal ``frameSize``.
    /// - Returns: The extracted ``FeatureVector``, or `nil` if the frame is
    ///   clipped or its decay cannot be estimated.
    public func extract(from samples: [Double]) -> FeatureVector? {
        precondition(samples.count == frameSize, "frame length must equal frameSize")

        let dcRemoved = SignalPreprocessing.removeDCOffset(samples)
        guard !SignalPreprocessing.isClipped(dcRemoved, threshold: clippingThreshold) else {
            return nil
        }
        return measure(eventWindow: filter.process(dcRemoved), noiseFloorRMS: nil).featureVector
    }

    /// Measures the ten features of one event window (`ALGORITHM` §14.1.1).
    ///
    /// Time-domain features are computed on the peak-normalized window (before
    /// windowing); spectral features on its Hann-windowed spectrum. Signal
    /// Duration is the decay-based estimate of §14.13, computed on the
    /// pre-normalization window so the noise floor shares its scale.
    ///
    /// - Parameters:
    ///   - eventWindow: The band-pass-filtered, pre-normalization event window.
    ///     At most ``frameSize`` samples; a shorter window is measured as it
    ///     is.
    ///   - noiseFloorRMS: The ambient noise floor on the same scale, if known.
    /// - Returns: The decay estimate and, when the estimator did not decline,
    ///   the feature vector.
    public func measure(eventWindow: [Double], noiseFloorRMS: Double?) -> EventMeasurement {
        precondition(eventWindow.count <= frameSize, "event window exceeds frameSize")

        let decay = DecayEstimator().estimate(
            eventWindow, sampleRate: sampleRate, noiseFloorRMS: noiseFloorRMS)
        guard let decay else { return EventMeasurement(decay: nil, featureVector: nil) }

        let (normalized, peak) = SignalPreprocessing.peakNormalized(eventWindow)

        // Time-domain features (on the normalized, pre-window signal).
        let rmsEnergy = TimeDomainFeatures.rmsEnergy(of: normalized)
        let zeroCrossingRate = TimeDomainFeatures.zeroCrossingRate(of: normalized)
        let attackTime = TimeDomainFeatures.attackTime(of: normalized, sampleRate: sampleRate)
        let decayTime = TimeDomainFeatures.decayTime(of: normalized, sampleRate: sampleRate)

        // Spectral features (on the Hann-windowed FFT magnitude spectrum). A
        // shorter window is tapered over the samples present; the FFT pads.
        let window =
            normalized.count == frameSize
            ? hannWindow.apply(to: normalized)
            : HannWindow(size: normalized.count).apply(to: normalized)
        let spectrum = Spectrum(fftResult: fourierTransform.magnitudeSpectrum(of: window.samples))
        let spectralCentroid = SpectralFeatures.spectralCentroid(spectrum)
        let spectralBandwidth = SpectralFeatures.spectralBandwidth(
            spectrum, centroid: spectralCentroid)
        let spectralRollOff = SpectralFeatures.spectralRollOff(spectrum)
        let dominantFrequency = SpectralFeatures.dominantFrequency(spectrum)

        let vector = FeatureVector(
            peakAmplitude: peak,
            rmsEnergy: rmsEnergy,
            spectralCentroid: spectralCentroid,
            spectralBandwidth: spectralBandwidth,
            spectralRollOff: spectralRollOff,
            dominantFrequency: dominantFrequency,
            zeroCrossingRate: zeroCrossingRate,
            attackTime: attackTime,
            decayTime: decayTime,
            signalDuration: decay.durationMilliseconds
        )
        return EventMeasurement(decay: decay, featureVector: vector)
    }
}

/// The measurement of one event window.
public struct EventMeasurement: Sendable, Equatable {

    /// The decay estimate, or `nil` if the estimator declined (§14.13.6).
    public let decay: DecayEstimate?

    /// The feature vector, present exactly when `decay` is.
    public let featureVector: FeatureVector?

    /// Creates a measurement.
    public init(decay: DecayEstimate?, featureVector: FeatureVector?) {
        self.decay = decay
        self.featureVector = featureVector
    }
}
