/// The reason a candidate was rejected during validation.
///
/// Every rejected candidate carries a rejection reason (`ALGORITHM` §19.18).
/// The cases mirror the validation order of `ALGORITHM` §23.5, plus the
/// feature-vector integrity check of §22.7.
public enum RejectionReason: Sendable, Equatable {

    /// The waveform contained clipped samples (`ALGORITHM` §19.16).
    case clipped

    /// The signal duration was below the configured minimum (§23.5).
    case durationBelowMinimum

    /// The uncensored signal duration exceeded the configured maximum
    /// (§19.6, §23.5). A censored duration never produces this reason.
    case durationAboveMaximum

    /// The decay estimator declined to measure the event (§14.13.6), for
    /// example because it does not decay. Distinct from a duration outside
    /// the limits.
    case decayNotMeasurable

    /// The RMS energy was below the configured minimum (§19.5, §23.5).
    case rmsBelowMinimum

    /// The signal-to-noise ratio was below the configured minimum (§23.5).
    case snrBelowMinimum

    /// The extracted feature vector failed structural validation (§22.7).
    case invalidFeatureVector
}
