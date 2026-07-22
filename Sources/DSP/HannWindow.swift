import Foundation

/// Generates and applies a Hann window (`ALGORITHM` §12).
///
/// Uses the symmetric Hann definition `w[n] = 0.5·(1 − cos(2πn/(N−1)))`, so the
/// first and last coefficients are zero. Coefficients are computed once and
/// reused, keeping application deterministic and allocation-light.
public struct HannWindow: Sendable, Equatable {

    /// The window length in samples.
    public let size: Int

    private let coefficients: [Double]

    /// Creates a Hann window of the given length.
    ///
    /// - Parameter size: The window length in samples. Must be positive.
    public init(size: Int) {
        precondition(size > 0, "Hann window size must be positive")
        self.size = size
        if size == 1 {
            self.coefficients = [1]
        } else {
            let denominator = Double(size - 1)
            self.coefficients = (0..<size).map {
                0.5 * (1 - cos(2 * .pi * Double($0) / denominator))
            }
        }
    }

    /// Applies the window to a frame of samples.
    ///
    /// - Parameter samples: The frame to window. Its count must equal ``size``.
    /// - Returns: The windowed samples wrapped in a ``Window``.
    public func apply(to samples: [Double]) -> Window {
        precondition(samples.count == size, "frame length must equal the window size")
        let windowed = zip(samples, coefficients).map { $0 * $1 }
        return Window(samples: windowed, windowFunction: .hann, frameSize: size)
    }
}
