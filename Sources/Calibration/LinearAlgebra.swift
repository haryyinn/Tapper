/// Deterministic dense linear-algebra operations for statistical model
/// generation, in 64-bit precision.
///
/// Internal to the Calibration module. Matrix inversion uses Cholesky
/// decomposition, whose success is exactly the positive-definite requirement
/// (`ALGORITHM` §17.21, `DATA_MODELS` §8.4).
enum LinearAlgebra {

    /// Computes the Cholesky factor `L` of a symmetric matrix `a`, where
    /// `a = L·Lᵀ` and `L` is lower-triangular.
    ///
    /// - Parameter a: A symmetric matrix, row-major.
    /// - Returns: The lower-triangular factor, or `nil` if `a` is not positive
    ///   definite (a non-positive pivot is encountered).
    static func cholesky(_ a: [[Double]]) -> [[Double]]? {
        let n = a.count
        var l = [[Double]](repeating: [Double](repeating: 0, count: n), count: n)
        for i in 0..<n {
            for j in 0...i {
                var sum = a[i][j]
                for k in 0..<j { sum -= l[i][k] * l[j][k] }
                if i == j {
                    guard sum > 0 else { return nil }
                    l[i][i] = sum.squareRoot()
                } else {
                    l[i][j] = sum / l[j][j]
                }
            }
        }
        return l
    }

    /// Inverts a lower-triangular matrix by forward substitution.
    ///
    /// - Parameter l: A lower-triangular matrix with nonzero diagonal.
    /// - Returns: The lower-triangular inverse.
    static func invertLowerTriangular(_ l: [[Double]]) -> [[Double]] {
        let n = l.count
        var inverse = [[Double]](repeating: [Double](repeating: 0, count: n), count: n)
        for i in 0..<n {
            inverse[i][i] = 1 / l[i][i]
            for j in 0..<i {
                var sum = 0.0
                for k in j..<i { sum += l[i][k] * inverse[k][j] }
                inverse[i][j] = -sum / l[i][i]
            }
        }
        return inverse
    }

    /// Inverts a symmetric positive-definite matrix via its Cholesky factor.
    ///
    /// With `a = L·Lᵀ`, `a⁻¹ = (L⁻¹)ᵀ·(L⁻¹)`.
    ///
    /// - Parameter a: A symmetric matrix, row-major.
    /// - Returns: The inverse, or `nil` if `a` is not positive definite.
    static func invertPositiveDefinite(_ a: [[Double]]) -> [[Double]]? {
        guard let l = cholesky(a) else { return nil }
        let lowerInverse = invertLowerTriangular(l)
        let n = a.count
        var inverse = [[Double]](repeating: [Double](repeating: 0, count: n), count: n)
        for i in 0..<n {
            for j in 0..<n {
                var sum = 0.0
                for k in max(i, j)..<n { sum += lowerInverse[k][i] * lowerInverse[k][j] }
                inverse[i][j] = sum
            }
        }
        return inverse
    }
}
