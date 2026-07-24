import XCTest

@testable import Calibration

final class LinearAlgebraTests: XCTestCase {

    private let accuracy = 1e-12

    private func assertMatrix(
        _ actual: [[Double]], _ expected: [[Double]], accuracy: Double,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(actual.count, expected.count, file: file, line: line)
        for (row, expectedRow) in zip(actual, expected) {
            XCTAssertEqual(row.count, expectedRow.count, file: file, line: line)
            for (value, expectedValue) in zip(row, expectedRow) {
                XCTAssertEqual(value, expectedValue, accuracy: accuracy, file: file, line: line)
            }
        }
    }

    func testCholeskyFactorization() {
        let l = try XCTUnwrap(LinearAlgebra.cholesky([[4, 2], [2, 3]]))
        assertMatrix(l, [[2, 0], [1, 2.0.squareRoot()]], accuracy: accuracy)
    }

    func testCholeskyRejectsNonPositiveDefinite() {
        XCTAssertNil(LinearAlgebra.cholesky([[1, 2], [2, 1]]))
    }

    func testInvertPositiveDefiniteTwoByTwo() {
        let inverse = try XCTUnwrap(LinearAlgebra.invertPositiveDefinite([[4, 2], [2, 3]]))
        assertMatrix(inverse, [[0.375, -0.25], [-0.25, 0.5]], accuracy: accuracy)
    }

    func testInverseTimesOriginalIsIdentity() {
        let matrix = [[4.0, 1, 1], [1, 3, 0], [1, 0, 2]]
        let inverse = try XCTUnwrap(LinearAlgebra.invertPositiveDefinite(matrix))
        for i in 0..<3 {
            for j in 0..<3 {
                let entry = (0..<3).reduce(0.0) { $0 + inverse[i][$1] * matrix[$1][j] }
                XCTAssertEqual(entry, i == j ? 1 : 0, accuracy: 1e-12)
            }
        }
    }

    func testInvertRejectsNonPositiveDefinite() {
        XCTAssertNil(LinearAlgebra.invertPositiveDefinite([[1, 2], [2, 1]]))
    }
}
