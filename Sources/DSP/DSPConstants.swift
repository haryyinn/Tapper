/// Provisional, configurable tuning constants for the DSP pipeline.
///
/// These are **implementation defaults, not algorithmic truths**. They are
/// intended to be validated (and likely adjusted) during Phase 9 empirical
/// evaluation. The binding requirement is deterministic behavior for a given
/// value — not that any particular value is "correct."
public enum DSPConstants {

    /// Amplitude at or above which a sample is treated as clipped.
    ///
    /// Clipping is detected before normalization; clipped candidates are
    /// rejected (`ALGORITHM` §8 / §10.4). The specifications require the check
    /// but do not fix a threshold, so this is a provisional, configurable value.
    public static let clippingThreshold = 0.99
}
