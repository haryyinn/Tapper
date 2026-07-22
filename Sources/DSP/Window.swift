/// A windowed audio segment immediately before frequency-domain transformation
/// (`DATA_MODELS` §5.4).
///
/// Immutable; produced by applying a window function to one analysis frame.
public struct Window: Sendable, Equatable {

    /// The windowed samples.
    public let samples: [Double]

    /// The window function that was applied.
    public let windowFunction: WindowFunction

    /// The number of samples in the frame.
    public let frameSize: Int

    /// Creates a window.
    ///
    /// - Parameters:
    ///   - samples: The windowed samples.
    ///   - windowFunction: The window function applied.
    ///   - frameSize: The number of samples in the frame.
    public init(samples: [Double], windowFunction: WindowFunction, frameSize: Int) {
        self.samples = samples
        self.windowFunction = windowFunction
        self.frameSize = frameSize
    }
}
