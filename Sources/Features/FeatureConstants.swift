/// Constants used by feature extraction.
public enum FeatureConstants {

    /// Fraction of total spectral energy defining the spectral roll-off point.
    ///
    /// Specified as 85% by `ALGORITHM` §14.8. This is a documented algorithmic
    /// value, not a provisional tuning parameter.
    public static let spectralRollOffEnergyFraction = 0.85

    /// Amplitude (as a fraction of the normalized peak) marking signal onset for
    /// Attack Time.
    ///
    /// `ALGORITHM` §14.11 does not specify the onset point. This is a
    /// **provisional implementation default** to be validated in Phase 9;
    /// determinism, not this specific value, is the requirement.
    public static let attackOnsetThreshold = 0.10

    /// Amplitude (as a fraction of the normalized peak) marking signal offset for
    /// Decay Time.
    ///
    /// `ALGORITHM` §14.12 refers to an unquantified "ambient noise floor". This
    /// is a **provisional implementation default** to be validated in Phase 9.
    public static let decayOffsetThreshold = 0.10
}
