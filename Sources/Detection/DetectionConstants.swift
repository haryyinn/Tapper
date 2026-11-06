import Foundation

/// Configurable constants governing candidate detection and validation.
///
/// The specifications name these parameters but do not fix values
/// (`ALGORITHM` §27.6; project context §18). Unless noted otherwise they are
/// **provisional implementation defaults** — approved for the initial
/// implementation and expected to be tuned during Phase 9 empirical validation
/// against the ≥80% accuracy gate. The binding requirement is deterministic
/// behavior for a given value, not that any particular value is "correct."
public enum DetectionConstants {

    /// Minimum peak magnitude of the filtered (pre-normalization) signal for a
    /// frame to become a candidate ("Detection Threshold", `ALGORITHM` §23.4 /
    /// §27.6). Provisional.
    public static let detectionPeakThreshold = 0.05

    /// Minimum RMS energy of the filtered signal ("Minimum RMS Energy",
    /// §19.5 / §23.5 / §27.6). Provisional.
    public static let minimumRMSEnergy = 0.01

    /// Minimum candidate-to-noise-floor RMS ratio, linear (≈6 dB)
    /// ("Minimum SNR", §23.5 / §27.6). Provisional.
    public static let minimumSNR = 2.0

    /// Exponential-moving-average smoothing factor for the ambient noise-floor
    /// estimate (§19.17; the estimation method is unspecified — the EMA over
    /// non-candidate frame RMS is the approved implementation). Provisional.
    public static let noiseFloorSmoothing = 0.05

    /// Minimum candidate signal duration, in milliseconds (§23.5). Provisional.
    public static let minimumCandidateDurationMilliseconds = 2.0

    /// Maximum candidate signal duration, in milliseconds ("Maximum Candidate
    /// Duration", §19.6 / §23.5 / §27.6). Provisional.
    public static let maximumCandidateDurationMilliseconds = 25.0

    /// Cooldown after a successful recognition, in seconds.
    ///
    /// **Documented default** (not provisional): `ALGORITHM` §27.9 specifies
    /// 100 ms, which takes precedence over `DSP_PARAMETERS` §13's 200 ms.
    /// User-adjustable within the documented 100–500 ms range.
    public static let cooldownDuration: TimeInterval = 0.100

    // MARK: Event localisation and extraction (ALGORITHM §23.4.1, ADR-017)

    /// Event-window length, in samples (70 ms at 48 kHz). Set from CP-2
    /// hardware data (`ALGORITHM` §23.4.1): long enough for the median tap to
    /// decay past the −25 dB fit target.
    public static let eventWindowSamples = 3360

    /// FFT size for the event window's spectrum (≥ ``eventWindowSamples``).
    public static let eventFFTSize = 4096

    /// Analysis-frame length for detection, in samples (40 ms, `ALGORITHM`
    /// §11).
    public static let detectionFrameSamples = 1920

    /// Samples kept before the localised onset, in samples (1 ms). Provisional.
    public static let eventPreRollSamples = 48

    /// How far before the peak the onset may lie, in samples (10 ms).
    /// Provisional.
    public static let maximumOnsetLookBackSamples = 480

    /// How far after the detected frame's peak the event peak may lie, in
    /// samples (10 ms). Provisional.
    public static let maximumAttackSamples = 480

    /// Filter warm-up preceding the event window, in samples (10 ms), so the
    /// band-pass start-up transient never falls inside it. Provisional.
    public static let filterWarmUpSamples = 480

    /// Longest run below the onset fraction tolerated while walking back from
    /// the peak, in samples (one period of the 300 Hz passband edge). The walk
    /// passes zero crossings of the attack but stops at a quiet gap, so earlier
    /// unrelated sound is not taken as the onset. Provisional.
    public static let onsetGapSamples = 160

    /// Refractory interval after an extracted event window, in samples
    /// (100 ms, equal to the documented cooldown, §27.9). Within it a
    /// detection no louder than the event is that event's decaying ring, not a
    /// new tap. Provisional.
    public static let refractorySamples = 4800
}
