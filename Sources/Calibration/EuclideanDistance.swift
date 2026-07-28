/// Euclidean distance in the normalized feature space (`ALGORITHM` §17.23.3).
///
/// Used by the k-Nearest Neighbour recogniser. Both operands must already be
/// normalized by the calibration profile's global transform, otherwise features
/// measured in hertz dominate features measured in normalized amplitude.
public enum EuclideanDistance {

    /// The distance between two equal-length vectors.
    ///
    /// - Parameters:
    ///   - lhs: The first vector.
    ///   - rhs: The second vector, of the same dimension.
    /// - Returns: The Euclidean distance.
    /// - Precondition: both vectors share the same dimension.
    public static func distance(_ lhs: [Double], _ rhs: [Double]) -> Double {
        precondition(lhs.count == rhs.count, "vectors must have equal dimension")
        var sum = 0.0
        for index in lhs.indices {
            let delta = lhs[index] - rhs[index]
            sum += delta * delta
        }
        return sum.squareRoot()
    }
}
