/// Deterministic descriptive statistics over collections of feature vectors.
///
/// Internal to the Calibration module; operates on canonical-order `[Double]`
/// feature vectors.
enum FeatureStatistics {

    /// The per-feature mean, μ = (1/N)·Σxᵢ (`ALGORITHM` §17.4).
    ///
    /// - Parameter vectors: The feature vectors (all the same length).
    /// - Returns: The mean vector, or an empty array if `vectors` is empty.
    static func mean(of vectors: [[Double]]) -> [Double] {
        guard let first = vectors.first else { return [] }
        let count = vectors.count
        let dimension = first.count
        var sum = [Double](repeating: 0, count: dimension)
        for vector in vectors {
            for index in 0..<dimension { sum[index] += vector[index] }
        }
        return sum.map { $0 / Double(count) }
    }

    /// The sample covariance, Σ = 1/(N−1)·Σ(xᵢ−μ)(xᵢ−μ)ᵀ (`ALGORITHM` §17.7).
    ///
    /// - Parameters:
    ///   - vectors: The feature vectors.
    ///   - mean: The per-feature mean.
    /// - Returns: The covariance matrix. With fewer than two vectors, a zero
    ///   matrix of the mean's dimension is returned.
    static func covariance(of vectors: [[Double]], mean: [Double]) -> [[Double]] {
        let dimension = mean.count
        let zero = [[Double]](repeating: [Double](repeating: 0, count: dimension), count: dimension)
        guard vectors.count > 1 else { return zero }
        var covariance = zero
        for vector in vectors {
            let deviation = zip(vector, mean).map(-)
            for i in 0..<dimension {
                for j in 0..<dimension { covariance[i][j] += deviation[i] * deviation[j] }
            }
        }
        let denominator = Double(vectors.count - 1)
        for i in 0..<dimension {
            for j in 0..<dimension { covariance[i][j] /= denominator }
        }
        return covariance
    }

    /// Applies mandatory diagonal loading, Σ' = Σ + λI (`ALGORITHM` §17.21;
    /// project decision: regularization is mandatory and deterministic).
    ///
    /// - Parameters:
    ///   - matrix: The covariance matrix.
    ///   - lambda: The diagonal loading coefficient.
    /// - Returns: The regularized matrix.
    static func regularized(_ matrix: [[Double]], lambda: Double) -> [[Double]] {
        var result = matrix
        for i in matrix.indices { result[i][i] += lambda }
        return result
    }
}
