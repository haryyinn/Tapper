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

    /// Every accepted sample for this zone, in normalized feature space and in
    /// chronological order (`DATA_MODELS` §7.5, ADR-015).
    ///
    /// The statistics above are derived from these; the samples are retained
    /// because mean and covariance can be recomputed from them while the
    /// reverse is impossible. Empty for profiles written before ADR-015.
    public let samples: [[Double]]

    /// The k-Nearest Neighbour acceptance radius for this zone
    /// (`ALGORITHM` §17.23.7), or `nil` when no samples are stored.
    public let neighbourRadius: Double?

    /// Creates a zone profile.
    ///
    /// - Parameters:
    ///   - zone: The calibrated zone.
    ///   - meanVector: The zone's mean feature vector.
    ///   - covarianceMatrix: The regularized covariance matrix.
    ///   - inverseCovarianceMatrix: The inverse of the regularized covariance.
    ///   - threshold: The acceptance and ambiguity thresholds.
    ///   - samples: The accepted normalized samples for this zone.
    ///   - neighbourRadius: The k-NN acceptance radius, if samples are stored.
    public init(
        zone: InteractionZone,
        meanVector: MeanVector,
        covarianceMatrix: CovarianceMatrix,
        inverseCovarianceMatrix: InverseCovarianceMatrix,
        threshold: ThresholdModel,
        samples: [[Double]] = [],
        neighbourRadius: Double? = nil
    ) {
        self.zone = zone
        self.meanVector = meanVector
        self.covarianceMatrix = covarianceMatrix
        self.inverseCovarianceMatrix = inverseCovarianceMatrix
        self.threshold = threshold
        self.samples = samples
        self.neighbourRadius = neighbourRadius
    }

    /// Whether this zone carries the labelled samples k-Nearest Neighbour needs.
    public var supportsNearestNeighbour: Bool {
        !samples.isEmpty && neighbourRadius != nil
    }
}

extension ZoneProfile {

    /// Decodes a zone profile, tolerating profiles written before ADR-015.
    ///
    /// Older profiles carry no `samples` or `neighbourRadius`. They decode with
    /// those fields empty, remain valid for Mahalanobis recognition, and report
    /// ``supportsNearestNeighbour`` as `false` rather than appearing complete.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            zone: try container.decode(InteractionZone.self, forKey: .zone),
            meanVector: try container.decode(MeanVector.self, forKey: .meanVector),
            covarianceMatrix: try container.decode(
                CovarianceMatrix.self, forKey: .covarianceMatrix),
            inverseCovarianceMatrix: try container.decode(
                InverseCovarianceMatrix.self, forKey: .inverseCovarianceMatrix),
            threshold: try container.decode(ThresholdModel.self, forKey: .threshold),
            samples: try container.decodeIfPresent([[Double]].self, forKey: .samples) ?? [],
            neighbourRadius: try container.decodeIfPresent(
                Double.self, forKey: .neighbourRadius)
        )
    }
}
