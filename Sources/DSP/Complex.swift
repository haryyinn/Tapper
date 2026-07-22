import Foundation

/// A minimal complex-number helper used only for IIR filter coefficient design.
///
/// Internal to the DSP module: the recognition pipeline processes real `Double`
/// samples. Complex arithmetic is needed solely to place filter poles and zeros.
struct Complex: Equatable {

    var real: Double
    var imaginary: Double

    init(_ real: Double, _ imaginary: Double = 0) {
        self.real = real
        self.imaginary = imaginary
    }

    static func + (lhs: Complex, rhs: Complex) -> Complex {
        Complex(lhs.real + rhs.real, lhs.imaginary + rhs.imaginary)
    }

    static func - (lhs: Complex, rhs: Complex) -> Complex {
        Complex(lhs.real - rhs.real, lhs.imaginary - rhs.imaginary)
    }

    static func * (lhs: Complex, rhs: Complex) -> Complex {
        Complex(
            lhs.real * rhs.real - lhs.imaginary * rhs.imaginary,
            lhs.real * rhs.imaginary + lhs.imaginary * rhs.real
        )
    }

    static func / (lhs: Complex, rhs: Complex) -> Complex {
        let denominator = rhs.real * rhs.real + rhs.imaginary * rhs.imaginary
        return Complex(
            (lhs.real * rhs.real + lhs.imaginary * rhs.imaginary) / denominator,
            (lhs.imaginary * rhs.real - lhs.real * rhs.imaginary) / denominator
        )
    }

    /// The magnitude (modulus).
    var magnitude: Double { (real * real + imaginary * imaginary).squareRoot() }

    /// The principal square root.
    func squareRoot() -> Complex {
        let modulus = magnitude
        let realPart = ((modulus + real) / 2).squareRoot()
        let sign = imaginary < 0 ? -1.0 : 1.0
        let imaginaryPart = ((modulus - real) / 2).squareRoot() * sign
        return Complex(realPart, imaginaryPart)
    }
}
