import DSP
import Features

/// Validates an extracted event before it is classified
/// (`ALGORITHM` §22.5 / §23.5).
///
/// Checks execute in the fixed §23.5 order and the first failure produces the
/// corresponding ``RejectionReason`` (§19.18). Absolute measures (RMS, SNR)
/// use the filtered, pre-normalization event window; the duration measure is
/// the decay-based Signal Duration of §14.13.
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

    /// Validates an extracted event, returning the first failing check's
    /// reason.
    ///
    /// Every input is measured over the onset-anchored event window
    /// (`ALGORITHM` §23.4.1), never over the frame that triggered detection.
    /// Order: clipping, decay measurability, minimum duration, maximum duration
    /// (uncensored only, §19.6), minimum RMS, minimum SNR.
    ///
    /// SNR handling is fail-safe: with no noise-floor estimate yet, the
    /// candidate is rejected (`ALGORITHM` — on uncertainty, do nothing). A zero
    /// noise floor (measured silence) passes the SNR check, since any signal in
    /// silence has unbounded SNR.
    ///
    /// - Parameters:
    ///   - dcRemovedWindow: The DC-removed event window, for the clipping check
    ///     (clipping is detected before filtering, `ALGORITHM` §8).
    ///   - filteredWindow: The band-pass-filtered, pre-normalization window.
    ///   - decay: The window's decay estimate, or `nil` if the estimator
    ///     declined.
    ///   - noiseFloorRMS: The current noise-floor estimate, or `nil` if none.
    /// - Returns: The rejection reason, or `nil` when the event is valid.
    public func rejectionReason(
        dcRemovedWindow: [Double],
        filteredWindow: [Double],
        decay: DecayEstimate?,
        noiseFloorRMS: Double?
    ) -> RejectionReason? {
        if SignalPreprocessing.isClipped(dcRemovedWindow, threshold: clippingThreshold) {
            return .clipped
        }
        guard let decay else { return .decayNotMeasurable }
        let duration = decay.durationMilliseconds
        if duration < minimumDurationMilliseconds { return .durationBelowMinimum }
        // A censored duration is unknown, not excessive (§14.13.5): it may
        // never alone reject an event against an upper bound.
        if !decay.isCensored, duration > maximumDurationMilliseconds {
            return .durationAboveMaximum
        }
        let rms = TimeDomainFeatures.rmsEnergy(of: filteredWindow)
        if rms < minimumRMSEnergy { return .rmsBelowMinimum }
        guard let floor = noiseFloorRMS else { return .snrBelowMinimum }
        if floor > 0, rms / floor < minimumSNR { return .snrBelowMinimum }
        return nil
    }
}
