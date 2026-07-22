/// Constants used by feature extraction.
public enum FeatureConstants {

    /// Fraction of total spectral energy defining the spectral roll-off point.
    ///
    /// Specified as 85% by `ALGORITHM` §14.8. This is a documented algorithmic
    /// value, not a provisional tuning parameter.
    public static let spectralRollOffEnergyFraction = 0.85
}
