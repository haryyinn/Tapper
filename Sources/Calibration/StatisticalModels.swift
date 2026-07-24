/// The centroid of a zone's calibration feature vectors (`DATA_MODELS` §8.3).
///
/// Values follow the canonical `FeatureVector` ordering. Immutable.
public struct MeanVector: Sendable, Equatable {

    /// The mean value of each feature.
    public let values: [Double]

    /// Creates a mean vector.
    ///
    /// - Parameter values: The per-feature means, in canonical order.
    public init(values: [Double]) {
        self.values = values
    }
}

/// A square, symmetric feature covariance matrix (`DATA_MODELS` §8.4).
///
/// Stored row-major. Immutable.
public struct CovarianceMatrix: Sendable, Equatable {

    /// The matrix rows.
    public let values: [[Double]]

    /// Creates a covariance matrix.
    ///
    /// - Parameter values: The matrix rows, row-major.
    public init(values: [[Double]]) {
        self.values = values
    }

    /// The matrix dimension (number of rows), or `0` if empty.
    public var dimension: Int { values.count }
}

/// The inverse of a (regularized) covariance matrix (`DATA_MODELS` §8.5).
///
/// Computed once during calibration and reused at runtime; never recomputed
/// during recognition. Immutable.
public struct InverseCovarianceMatrix: Sendable, Equatable {

    /// The inverse matrix rows, row-major.
    public let values: [[Double]]

    /// Creates an inverse covariance matrix.
    ///
    /// - Parameter values: The matrix rows, row-major.
    public init(values: [[Double]]) {
        self.values = values
    }

    /// The matrix dimension (number of rows), or `0` if empty.
    public var dimension: Int { values.count }
}

/// The acceptance criteria for a statistical match (`DATA_MODELS` §8.6).
///
/// Immutable.
public struct ThresholdModel: Sendable, Equatable {

    /// Maximum Mahalanobis distance for acceptance (`ALGORITHM` §17.17).
    public let acceptanceThreshold: Double

    /// Minimum best-vs-second-best distance separation below which a match is
    /// ambiguous (`ALGORITHM` §18.10).
    public let ambiguityMargin: Double

    /// Creates a threshold model.
    ///
    /// - Parameters:
    ///   - acceptanceThreshold: Maximum accepted Mahalanobis distance.
    ///   - ambiguityMargin: Minimum required separation between candidates.
    public init(acceptanceThreshold: Double, ambiguityMargin: Double) {
        self.acceptanceThreshold = acceptanceThreshold
        self.ambiguityMargin = ambiguityMargin
    }
}
