/// Configurable parameters governing statistical model generation.
///
/// Stored within the calibration profile so a profile records the exact
/// parameters it was built with (including the regularization coefficient λ).
public struct CalibrationConfiguration: Sendable, Equatable {

    /// Accepted samples collected per zone (`ALGORITHM` §27.10: 20).
    public let samplesPerZone: Int

    /// Minimum samples that must survive outlier rejection to generate a profile.
    ///
    /// Set well above the dimensionality (d + 1 = 11) so the covariance stays
    /// estimable; below this the calibration workflow requests more samples.
    public let minimumRetainedSamples: Int

    /// Diagonal-loading coefficient λ for mandatory regularization Σ' = Σ + λI.
    public let regularizationLambda: Double

    /// Multiplier k in the `mean + k·σ` threshold formulation
    /// (`ALGORITHM` §17.18, configurable multiplier).
    public let thresholdMultiplier: Double

    /// Minimum best-vs-second-best Mahalanobis separation below which a match is
    /// ambiguous (`ALGORITHM` §18.10).
    public let ambiguityMargin: Double

    /// Creates a calibration configuration.
    public init(
        samplesPerZone: Int,
        minimumRetainedSamples: Int,
        regularizationLambda: Double,
        thresholdMultiplier: Double,
        ambiguityMargin: Double
    ) {
        self.samplesPerZone = samplesPerZone
        self.minimumRetainedSamples = minimumRetainedSamples
        self.regularizationLambda = regularizationLambda
        self.thresholdMultiplier = thresholdMultiplier
        self.ambiguityMargin = ambiguityMargin
    }

    /// The Version 1 configuration with the approved defaults: 20 samples/zone,
    /// 15 retained minimum, λ = 1e-3, threshold multiplier 2.0, ambiguity
    /// margin 0.5.
    public static let v1 = CalibrationConfiguration(
        samplesPerZone: 20,
        minimumRetainedSamples: 15,
        regularizationLambda: 1e-3,
        thresholdMultiplier: 2.0,
        ambiguityMargin: 0.5
    )
}

/// A failure encountered while generating a statistical model
/// (`CALIBRATION` §7.13, §9.8).
public enum CalibrationError: Error, Equatable {

    /// No samples were provided for the zone.
    case emptyDataset

    /// Too few samples survived outlier rejection to build a stable model.
    case insufficientRetainedSamples(retained: Int, required: Int)

    /// The regularized covariance was not positive definite (inversion failed).
    case singularCovariance
}
