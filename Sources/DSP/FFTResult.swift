/// The magnitude output of a Fast Fourier Transform (`DATA_MODELS` §5.6).
///
/// Contains the one-sided magnitude spectrum (bins from DC through Nyquist).
/// Phase is intentionally excluded, as it is not used by the recognition
/// algorithm (`ALGORITHM` §13.3).
public struct FFTResult: Sendable, Equatable {

    /// Magnitude for each bin, from DC (index 0) through Nyquist.
    public let magnitudes: [Double]

    /// The number of magnitude bins.
    public let binCount: Int

    /// The frequency represented by each bin, in hertz.
    public let frequencyResolution: Double

    /// Creates an FFT result.
    ///
    /// - Parameters:
    ///   - magnitudes: The one-sided magnitude spectrum.
    ///   - binCount: The number of magnitude bins.
    ///   - frequencyResolution: The frequency spacing between bins, in hertz.
    public init(magnitudes: [Double], binCount: Int, frequencyResolution: Double) {
        self.magnitudes = magnitudes
        self.binCount = binCount
        self.frequencyResolution = frequencyResolution
    }
}
