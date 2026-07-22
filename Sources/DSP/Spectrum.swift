/// A frequency spectrum with an explicit frequency axis (`DATA_MODELS` §5.7).
///
/// Provides a convenient representation for spectral feature computation
/// (centroid, bandwidth, roll-off, dominant frequency). Frequencies are
/// monotonically increasing and aligned one-to-one with magnitudes.
public struct Spectrum: Sendable, Equatable {

    /// The frequency of each bin, in hertz, monotonically increasing.
    public let frequencies: [Double]

    /// The magnitude of each bin, aligned with ``frequencies``.
    public let magnitudes: [Double]

    /// Creates a spectrum.
    ///
    /// - Parameters:
    ///   - frequencies: The bin frequencies, in hertz.
    ///   - magnitudes: The bin magnitudes.
    public init(frequencies: [Double], magnitudes: [Double]) {
        self.frequencies = frequencies
        self.magnitudes = magnitudes
    }

    /// Builds a spectrum from an ``FFTResult`` by materializing the frequency axis.
    ///
    /// - Parameter fftResult: The FFT magnitude output.
    public init(fftResult: FFTResult) {
        let frequencies = (0..<fftResult.magnitudes.count).map {
            Double($0) * fftResult.frequencyResolution
        }
        self.init(frequencies: frequencies, magnitudes: fftResult.magnitudes)
    }
}
