import Accelerate

/// Computes the magnitude spectrum of a real signal via a fixed-size FFT
/// (`ALGORITHM` §13).
///
/// Wraps `vDSP.DiscreteFourierTransform` (Accelerate). The transform plan is
/// created once and reused. Real input shorter than the transform size is
/// zero-padded, matching the specification's use of a 2048-point FFT over a
/// 1920-sample analysis window.
public final class FourierTransform {

    /// The transform size in samples (e.g. 2048).
    public let size: Int

    /// The sample rate used to derive bin frequencies, in hertz.
    public let sampleRate: Double

    private let transform: vDSP.DiscreteFourierTransform<Double>

    /// Creates a Fourier transform of the given size.
    ///
    /// - Parameters:
    ///   - size: The transform size in samples.
    ///   - sampleRate: The sample rate, in hertz.
    /// - Throws: An error if the platform cannot create a transform of `size`.
    public init(size: Int, sampleRate: Double) throws {
        self.size = size
        self.sampleRate = sampleRate
        self.transform = try vDSP.DiscreteFourierTransform(
            previous: nil,
            count: size,
            direction: .forward,
            transformType: .complexComplex,
            ofType: Double.self
        )
    }

    /// Computes the one-sided magnitude spectrum of a real signal.
    ///
    /// Input shorter than ``size`` is zero-padded; input longer than ``size`` is
    /// truncated to the first ``size`` samples.
    ///
    /// - Parameter signal: The real input signal.
    /// - Returns: The magnitude spectrum from DC through Nyquist.
    public func magnitudeSpectrum(of signal: [Double]) -> FFTResult {
        var real = signal
        if real.count < size {
            real.append(contentsOf: [Double](repeating: 0, count: size - real.count))
        } else if real.count > size {
            real = Array(real.prefix(size))
        }
        let imaginary = [Double](repeating: 0, count: size)
        let output = transform.transform(real: real, imaginary: imaginary)

        let binCount = size / 2 + 1
        let magnitudes = (0..<binCount).map { index in
            (output.real[index] * output.real[index]
                + output.imaginary[index] * output.imaginary[index]).squareRoot()
        }
        return FFTResult(
            magnitudes: magnitudes,
            binCount: binCount,
            frequencyResolution: sampleRate / Double(size)
        )
    }
}
