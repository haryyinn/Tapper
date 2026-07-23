import DSP
import Features

/// Validates a detected candidate before feature processing continues
/// (`ALGORITHM` §22.5 / §23.5).
///
/// Checks execute in the fixed §23.5 order — clipping, minimum duration,
/// maximum duration, minimum RMS, minimum SNR — and the first failure produces
/// the corresponding ``RejectionReason`` (§19.18). Absolute measures (RMS, SNR)
/// use the filtered, pre-normalization signal; the duration measure reuses the
/// Signal Duration feature on the normalized signal (§19.6).
public struct CandidateValidator: Sendable, Equatable {

    /// Minimum signal duration, in milliseconds.
    public let minimumDurationMilliseconds: Double

    /// Maximum signal duration, in milliseconds.
    public let maximumDurationMilliseconds: Double

    /// Minimum RMS energy of the filtered signal.
    public let minimumRMSEnergy: Double

    /// Minimum candidate-to-noise-floor RMS ratio (linear).
    public let minimumSNR: Double

    /// Amplitude at or above which a sample counts as clipped.
    public let clippingThreshold: Double

    /// Creates a validator with the configured thresholds.
    ///
    /// - Parameters:
    ///   - minimumDurationMilliseconds: Minimum signal duration.
    ///   - maximumDurationMilliseconds: Maximum signal duration.
    ///   - minimumRMSEnergy: Minimum filtered-signal RMS.
    ///   - minimumSNR: Minimum linear SNR versus the noise floor.
    ///   - clippingThreshold: Clipping detection threshold.
    public init(
        minimumDurationMilliseconds: Double = DetectionConstants
            .minimumCandidateDurationMilliseconds,
        maximumDurationMilliseconds: Double = DetectionConstants
            .maximumCandidateDurationMilliseconds,
        minimumRMSEnergy: Double = DetectionConstants.minimumRMSEnergy,
        minimumSNR: Double = DetectionConstants.minimumSNR,
        clippingThreshold: Double = DSPConstants.clippingThreshold
    ) {
        self.minimumDurationMilliseconds = minimumDurationMilliseconds
        self.maximumDurationMilliseconds = maximumDurationMilliseconds
        self.minimumRMSEnergy = minimumRMSEnergy
        self.minimumSNR = minimumSNR
        self.clippingThreshold = clippingThreshold
    }

    /// Validates a candidate, returning the first failing check's reason.
    ///
    /// SNR handling is fail-safe: with no noise-floor estimate yet, the
    /// candidate is rejected (`ALGORITHM` — on uncertainty, do nothing). A zero
    /// noise floor (measured silence) passes the SNR check, since any signal in
    /// silence has unbounded SNR.
    ///
    /// - Parameters:
    ///   - dcRemovedSignal: The DC-removed signal, used for the clipping check
    ///     (clipping is detected before filtering, `ALGORITHM` §8).
    ///   - filteredSignal: The band-pass-filtered, pre-normalization signal.
    ///   - normalizedSignal: The peak-normalized signal, for the duration check.
    ///   - sampleRate: The sample rate, in hertz.
    ///   - noiseFloorRMS: The current noise-floor estimate, or `nil` if none.
    /// - Returns: The rejection reason, or `nil` when the candidate is valid.
    public func rejectionReason(
        dcRemovedSignal: [Double],
        filteredSignal: [Double],
        normalizedSignal: [Double],
        sampleRate: Double,
        noiseFloorRMS: Double?
    ) -> RejectionReason? {
        if SignalPreprocessing.isClipped(dcRemovedSignal, threshold: clippingThreshold) {
            return .clipped
        }
        let duration = TimeDomainFeatures.signalDuration(
            of: normalizedSignal, sampleRate: sampleRate)
        if duration < minimumDurationMilliseconds { return .durationBelowMinimum }
        if duration > maximumDurationMilliseconds { return .durationAboveMaximum }
        let rms = TimeDomainFeatures.rmsEnergy(of: filteredSignal)
        if rms < minimumRMSEnergy { return .rmsBelowMinimum }
        guard let floor = noiseFloorRMS else { return .snrBelowMinimum }
        if floor > 0, rms / floor < minimumSNR { return .snrBelowMinimum }
        return nil
    }
}
