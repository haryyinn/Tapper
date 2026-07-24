/// The Mahalanobis distance metric (`ALGORITHM` §17.13).
///
/// Used both during calibration (outlier rejection, threshold generation) and
/// at runtime classification, so it lives in the Calibration module that owns
/// the statistical models.
public enum MahalanobisDistance {

    /// The squared Mahalanobis distance, D² = (x−μ)ᵀ·Σ⁻¹·(x−μ).
    ///
    /// - Parameters:
    ///   - vector: The observation, canonical order.
    ///   - mean: The zone mean vector.
    ///   - inverseCovariance: The inverse (regularized) covariance matrix.
    /// - Returns: The squared distance.
    public static func squared(
        vector: [Double],
        mean: [Double],
        inverseCovariance: [[Double]]
    ) -> Double {
        let deviation = zip(vector, mean).map(-)
        var result = 0.0
        for i in deviation.indices {
            for j in deviation.indices {
                result += deviation[i] * inverseCovariance[i][j] * deviation[j]
            }
        }
        return result
    }

    /// The Mahalanobis distance, √(D²), clamped at zero against floating-point
    /// round-off.
    ///
    /// - Parameters:
    ///   - vector: The observation, canonical order.
    ///   - mean: The zone mean vector.
    ///   - inverseCovariance: The inverse (regularized) covariance matrix.
    /// - Returns: The distance.
    public static func distance(
        vector: [Double],
        mean: [Double],
        inverseCovariance: [[Double]]
    ) -> Double {
        Swift.max(0, squared(vector: vector, mean: mean, inverseCovariance: inverseCovariance))
            .squareRoot()
    }
}
