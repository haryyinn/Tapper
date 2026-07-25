/// A global per-feature z-score transform (`ALGORITHM` §15.7–15.8).
///
/// One transform is computed across **all** accepted calibration samples (every
/// zone) and stored in the calibration profile, then applied identically during
/// calibration and runtime classification. Bringing features onto a common
/// unit-variance scale is what makes the fixed regularization coefficient λ a
/// principled floor. Immutable.
public struct NormalizationParameters: Sendable, Equatable, Codable {

    /// The per-feature mean.
    public let means: [Double]

    /// The per-feature population standard deviation.
    public let standardDeviations: [Double]

    /// Creates a normalization transform.
    ///
    /// - Parameters:
    ///   - means: The per-feature means.
    ///   - standardDeviations: The per-feature standard deviations.
    public init(means: [Double], standardDeviations: [Double]) {
        self.means = means
        self.standardDeviations = standardDeviations
    }

    /// Computes the transform over all accepted samples using the population
    /// standard deviation.
    ///
    /// - Parameter samples: All accepted feature vectors, canonical order.
    /// - Returns: The fitted transform (empty if `samples` is empty).
    public static func compute(from samples: [[Double]]) -> NormalizationParameters {
        guard let first = samples.first else {
            return NormalizationParameters(means: [], standardDeviations: [])
        }
        let dimension = first.count
        let mean = FeatureStatistics.mean(of: samples)
        var variance = [Double](repeating: 0, count: dimension)
        for sample in samples {
            for index in 0..<dimension {
                let deviation = sample[index] - mean[index]
                variance[index] += deviation * deviation
            }
        }
        let standardDeviations = variance.map { ($0 / Double(samples.count)).squareRoot() }
        return NormalizationParameters(means: mean, standardDeviations: standardDeviations)
    }

    /// Applies the transform to a feature vector.
    ///
    /// A feature with (near-)zero variance is centered but not scaled, avoiding
    /// division by zero; the mandatory covariance regularization then keeps the
    /// model invertible.
    ///
    /// - Parameter vector: The feature vector, canonical order.
    /// - Returns: The normalized vector.
    public func normalize(_ vector: [Double]) -> [Double] {
        vector.indices.map { index in
            let mean = index < means.count ? means[index] : 0
            let standardDeviation = index < standardDeviations.count ? standardDeviations[index] : 1
            let centered = vector[index] - mean
            return standardDeviation > 1e-12 ? centered / standardDeviation : centered
        }
    }
}
