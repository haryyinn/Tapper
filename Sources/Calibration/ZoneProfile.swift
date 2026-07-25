/// The finalized statistical model for a single interaction zone
/// (`DATA_MODELS` §7.5, §8.8).
///
/// Consumed by the classification engine at runtime. Immutable: a zone profile
/// is generated once from calibration data and never adapted in place.
public struct ZoneProfile: Sendable, Equatable, Codable {

    /// The calibrated zone this profile represents.
    public let zone: InteractionZone

    /// The zone's mean feature vector.
    public let meanVector: MeanVector

    /// The regularized covariance matrix (Σ' = Σ + λI).
    public let covarianceMatrix: CovarianceMatrix

    /// The inverse of the regularized covariance matrix.
    public let inverseCovarianceMatrix: InverseCovarianceMatrix

    /// The acceptance and ambiguity thresholds.
    public let threshold: ThresholdModel

    /// Creates a zone profile.
    ///
    /// - Parameters:
    ///   - zone: The calibrated zone.
    ///   - meanVector: The zone's mean feature vector.
    ///   - covarianceMatrix: The regularized covariance matrix.
    ///   - inverseCovarianceMatrix: The inverse of the regularized covariance.
    ///   - threshold: The acceptance and ambiguity thresholds.
    public init(
        zone: InteractionZone,
        meanVector: MeanVector,
        covarianceMatrix: CovarianceMatrix,
        inverseCovarianceMatrix: InverseCovarianceMatrix,
        threshold: ThresholdModel
    ) {
        self.zone = zone
        self.meanVector = meanVector
        self.covarianceMatrix = covarianceMatrix
        self.inverseCovarianceMatrix = inverseCovarianceMatrix
        self.threshold = threshold
    }
}
