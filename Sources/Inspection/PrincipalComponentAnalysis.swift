import Foundation

/// A principal component analysis of a set of vectors (ADR-016 §5).
///
/// Developer diagnostic only. Nothing in the recognition path uses this: it
/// exists so the labelled calibration dataset can be looked at, and it can
/// neither read nor alter a recogniser's behaviour.
///
/// PCA was chosen over t-SNE and UMAP because it is deterministic, has no
/// hyperparameters whose defaults would become unexamined heuristics, preserves
/// the global distances that are actually under investigation, and needs no
/// dependency. Its weakness — that a linear projection may not separate what a
/// non-linear one would — is made visible by reporting the variance it captures,
/// so a misleading picture is identifiable as one.
public struct PrincipalComponentAnalysis: Sendable {

    /// The mean of the input vectors, subtracted before projection.
    public let mean: [Double]

    /// Component vectors, most significant first. Each has unit length.
    public let components: [[Double]]

    /// Variance along each component, in the same order.
    public let eigenvalues: [Double]

    /// Total variance across all dimensions.
    public var totalVariance: Double { eigenvalues.reduce(0, +) }

    /// The fraction of total variance captured by the first `count` components.
    ///
    /// A two-dimensional plot showing a low value is not a faithful picture of
    /// the space the recogniser sees, and shall be read accordingly.
    public func capturedVariance(through count: Int) -> Double {
        guard totalVariance > 0 else { return 0 }
        return eigenvalues.prefix(count).reduce(0, +) / totalVariance
    }

    /// Fits a PCA to a set of equal-length vectors.
    ///
    /// - Parameter vectors: The input vectors. At least two are required.
    /// - Returns: The analysis, or `nil` if the input is too small or ragged.
    public init?(fitting vectors: [[Double]]) {
        guard vectors.count >= 2, let width = vectors.first?.count, width > 0,
            vectors.allSatisfy({ $0.count == width })
        else { return nil }

        var mean = [Double](repeating: 0, count: width)
        for vector in vectors {
            for index in 0..<width { mean[index] += vector[index] }
        }
        for index in 0..<width { mean[index] /= Double(vectors.count) }

        // Sample covariance, matching the estimator used elsewhere (n − 1).
        var covariance = [[Double]](repeating: [Double](repeating: 0, count: width), count: width)
        for vector in vectors {
            for row in 0..<width {
                let a = vector[row] - mean[row]
                for column in 0..<width {
                    covariance[row][column] += a * (vector[column] - mean[column])
                }
            }
        }
        let divisor = Double(vectors.count - 1)
        for row in 0..<width {
            for column in 0..<width { covariance[row][column] /= divisor }
        }

        let (values, vectorsOut) = Self.symmetricEigen(covariance)

        // Sort by descending eigenvalue; ties keep their index order so the
        // result is deterministic.
        let order = (0..<width).sorted { lhs, rhs in
            if values[lhs] != values[rhs] { return values[lhs] > values[rhs] }
            return lhs < rhs
        }
        self.mean = mean
        self.eigenvalues = order.map { values[$0] }
        self.components = order.map { index in
            let column = (0..<width).map { vectorsOut[$0][index] }
            return Self.signNormalized(column)
        }
    }

    /// Projects a vector onto the first `count` components.
    ///
    /// - Parameters:
    ///   - vector: The vector to project. Must match the fitted dimension.
    ///   - count: How many components to project onto.
    /// - Returns: The coordinates.
    public func project(_ vector: [Double], onto count: Int = 2) -> [Double] {
        precondition(vector.count == mean.count, "dimension mismatch")
        let centred = zip(vector, mean).map(-)
        return components.prefix(count).map { component in
            zip(centred, component).reduce(0) { $0 + $1.0 * $1.1 }
        }
    }

    // MARK: Eigendecomposition

    /// The cyclic Jacobi eigenvalue algorithm for a real symmetric matrix.
    ///
    /// Chosen for a 10×10 problem because it is short, deterministic, and needs
    /// no dependency. It converges unconditionally for symmetric input.
    ///
    /// - Returns: Eigenvalues, and eigenvectors as matrix columns.
    static func symmetricEigen(
        _ input: [[Double]], sweeps: Int = 100, tolerance: Double = 1e-12
    ) -> (values: [Double], vectors: [[Double]]) {
        let n = input.count
        var a = input
        var v = (0..<n).map { row in (0..<n).map { $0 == row ? 1.0 : 0.0 } }

        for _ in 0..<sweeps {
            // Sum of squares of the off-diagonal entries: zero means diagonal.
            var offDiagonal = 0.0
            for row in 0..<n {
                for column in (row + 1)..<n { offDiagonal += a[row][column] * a[row][column] }
            }
            if offDiagonal <= tolerance { break }

            for p in 0..<(n - 1) {
                for q in (p + 1)..<n where abs(a[p][q]) > tolerance {
                    // Rotation annihilating a[p][q].
                    let theta = (a[q][q] - a[p][p]) / (2 * a[p][q])
                    let t =
                        (theta >= 0 ? 1.0 : -1.0)
                        / (abs(theta) + (theta * theta + 1).squareRoot())
                    let c = 1 / (t * t + 1).squareRoot()
                    let s = t * c

                    for k in 0..<n {
                        let akp = a[k][p]
                        let akq = a[k][q]
                        a[k][p] = c * akp - s * akq
                        a[k][q] = s * akp + c * akq
                    }
                    for k in 0..<n {
                        let apk = a[p][k]
                        let aqk = a[q][k]
                        a[p][k] = c * apk - s * aqk
                        a[q][k] = s * apk + c * aqk
                    }
                    for k in 0..<n {
                        let vkp = v[k][p]
                        let vkq = v[k][q]
                        v[k][p] = c * vkp - s * vkq
                        v[k][q] = s * vkp + c * vkq
                    }
                }
            }
        }
        return ((0..<n).map { a[$0][$0] }, v)
    }

    /// Fixes each component's sign so repeated runs agree.
    ///
    /// An eigenvector is determined only up to sign; without this, two runs on
    /// identical data could produce mirrored plots. The convention is that the
    /// largest-magnitude entry is positive.
    private static func signNormalized(_ vector: [Double]) -> [Double] {
        guard let dominant = vector.max(by: { abs($0) < abs($1) }), dominant < 0 else {
            return vector
        }
        return vector.map(-)
    }
}
