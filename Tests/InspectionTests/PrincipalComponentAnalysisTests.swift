import XCTest

@testable import Inspection

/// Tests the offline PCA projection (ADR-016 §5).
///
/// Expected values are analytic and stated in the test that uses them.
final class PrincipalComponentAnalysisTests: XCTestCase {

    /// Points (±2, 0) and (0, ±1) have mean 0 and sample covariance
    /// [[8/3, 0], [0, 2/3]], so the eigenvalues are 8/3 and 2/3 and the first
    /// component is the x axis. The first component therefore carries
    /// (8/3)/(10/3) = 80% of the variance.
    func testKnownCovarianceGivesKnownComponents() throws {
        let pca = try XCTUnwrap(
            PrincipalComponentAnalysis(fitting: [[2, 0], [-2, 0], [0, 1], [0, -1]]))

        XCTAssertEqual(pca.eigenvalues[0], 8.0 / 3.0, accuracy: 1e-12)
        XCTAssertEqual(pca.eigenvalues[1], 2.0 / 3.0, accuracy: 1e-12)
        XCTAssertEqual(abs(pca.components[0][0]), 1.0, accuracy: 1e-12)
        XCTAssertEqual(abs(pca.components[0][1]), 0.0, accuracy: 1e-12)
        XCTAssertEqual(pca.capturedVariance(through: 1), 0.8, accuracy: 1e-12)
        XCTAssertEqual(pca.capturedVariance(through: 2), 1.0, accuracy: 1e-12)
    }

    /// Data varying in one dimension only puts all variance on the first
    /// component. The integers 0…9 have sample variance 55/6.
    func testVarianceAlongOneAxis() throws {
        let pca = try XCTUnwrap(
            PrincipalComponentAnalysis(fitting: (0..<10).map { [Double($0), 5, -2] }))

        XCTAssertEqual(pca.capturedVariance(through: 1), 1.0, accuracy: 1e-12)
        XCTAssertEqual(pca.eigenvalues[0], 55.0 / 6.0, accuracy: 1e-9)
        XCTAssertEqual(pca.mean[0], 4.5, accuracy: 1e-12)
        XCTAssertEqual(abs(pca.components[0][0]), 1.0, accuracy: 1e-9)
    }

    /// Data along the diagonal puts the first component on (1,1)/√2.
    func testVarianceAlongDiagonal() throws {
        let pca = try XCTUnwrap(
            PrincipalComponentAnalysis(
                fitting: (0..<20).map { [Double($0) * 0.1, Double($0) * 0.1] })
        )

        XCTAssertEqual(abs(pca.components[0][0]), 1 / 2.0.squareRoot(), accuracy: 1e-9)
        XCTAssertEqual(abs(pca.components[0][1]), 1 / 2.0.squareRoot(), accuracy: 1e-9)
        XCTAssertEqual(pca.capturedVariance(through: 1), 1.0, accuracy: 1e-9)
    }

    /// Components are orthonormal, eigenvalues descend, and their sum equals
    /// the total variance of the input — the three properties a correct
    /// eigendecomposition of a covariance matrix must have.
    func testComponentsAreOrthonormalAndPreserveTotalVariance() throws {
        var seed = 7.0
        func next() -> Double {
            seed = (seed * 1_103_515_245 + 12345).truncatingRemainder(dividingBy: 2_147_483_648)
            return seed / 2_147_483_648
        }
        let data = (0..<40).map { _ in (0..<5).map { _ in next() * 10 } }
        let pca = try XCTUnwrap(PrincipalComponentAnalysis(fitting: data))

        for component in pca.components {
            XCTAssertEqual(component.reduce(0) { $0 + $1 * $1 }, 1.0, accuracy: 1e-9)
        }
        for (index, first) in pca.components.enumerated() {
            for second in pca.components[(index + 1)...] {
                XCTAssertEqual(
                    zip(first, second).reduce(0) { $0 + $1.0 * $1.1 }, 0.0, accuracy: 1e-9)
            }
        }
        XCTAssertEqual(pca.eigenvalues, pca.eigenvalues.sorted(by: >))

        var totalVariance = 0.0
        for dimension in 0..<5 {
            let column = data.map { $0[dimension] }
            let mean = column.reduce(0, +) / Double(column.count)
            totalVariance +=
                column.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(column.count - 1)
        }
        XCTAssertEqual(pca.totalVariance, totalVariance, accuracy: 1e-9)
    }

    /// An eigenvector is defined only up to sign, so the sign is fixed by
    /// convention. Without it two runs on identical data could produce mirrored
    /// plots.
    func testProjectionIsDeterministic() throws {
        let data = (0..<20).map { [Double($0), Double($0) * -0.5, 3.0] }
        let first = try XCTUnwrap(PrincipalComponentAnalysis(fitting: data))
        let second = try XCTUnwrap(PrincipalComponentAnalysis(fitting: data))

        XCTAssertEqual(first.components, second.components)
        XCTAssertEqual(first.eigenvalues, second.eigenvalues)
    }

    /// The mean projects to the origin, since projection centres first.
    func testMeanProjectsToOrigin() throws {
        let pca = try XCTUnwrap(
            PrincipalComponentAnalysis(fitting: (0..<12).map { [Double($0), Double($0 % 4), 1.0] }))
        let projected = pca.project(pca.mean, onto: 2)

        XCTAssertEqual(projected[0], 0.0, accuracy: 1e-9)
        XCTAssertEqual(projected[1], 0.0, accuracy: 1e-9)
    }

    /// Inputs that cannot define a covariance are refused rather than producing
    /// a meaningless projection.
    func testDegenerateInputsAreRefused() {
        XCTAssertNil(PrincipalComponentAnalysis(fitting: []))
        XCTAssertNil(PrincipalComponentAnalysis(fitting: [[1, 2]]))
        XCTAssertNil(PrincipalComponentAnalysis(fitting: [[1, 2], [1, 2, 3]]))
    }

    /// A diagonal matrix is already decomposed, so Jacobi must return it
    /// unchanged rather than rotating it.
    func testDiagonalMatrixIsUnchanged() {
        let (values, _) = PrincipalComponentAnalysis.symmetricEigen(
            [[5, 0, 0], [0, 3, 0], [0, 0, 1]])
        XCTAssertEqual(values.sorted(by: >), [5, 3, 1])
    }

    /// The classic 2×2 case: [[2,1],[1,2]] has eigenvalues 3 and 1.
    func testSymmetricEigenOnKnownMatrix() {
        let (values, _) = PrincipalComponentAnalysis.symmetricEigen([[2, 1], [1, 2]])
        let sorted = values.sorted(by: >)
        XCTAssertEqual(sorted[0], 3.0, accuracy: 1e-12)
        XCTAssertEqual(sorted[1], 1.0, accuracy: 1e-12)
    }
}
